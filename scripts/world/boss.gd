extends Node3D
## Zone-triggered encounter: erupts only when the player enters the territory;
## predictive shard volleys + radial shockwave while active. Mirrors the JS
## Monolith/BossZone classes in sample.html; reward numbers kept verbatim.

const PRIMITIVES = preload("res://scripts/world/primitives.gd")

const CRYSTAL_ALBEDO := Color(0xcfc8b8)
const CRYSTAL_EMISSIVE := Color(0xd9a441)
const RING_COL := Color(0xd9a441)

var zone_center := Vector3.ZERO
var world: Node
var state: String = 'idle'
var eruption_t := 0.0
var collapse_t := 0.0
var cooldown_t := 0.0
var volley_timer: float
var shockwave_timer: float
var shockwave_active := false
var shockwave_radius := 0.0
var shockwave_prev := 0.0
var ring: MeshInstance3D
var ring_mat: StandardMaterial3D
var monolith: Node
var shards: Array = []

func setup(center: Vector3, w: Node) -> void:
	zone_center = center
	world = w
	monolith = Monolith.new()
	add_child(monolith)
	monolith.setup(center, world)
	volley_timer = TERRAIN.BOSS['volleyInterval']
	shockwave_timer = TERRAIN.BOSS['shockwaveInterval']
	ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = RING_COL
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color.a = 0.35
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.mesh = PRIMITIVES.ring_mesh(Vector3.ZERO, 0.0001, 1.0, 0.0, 48, RING_COL)
	ring_mesh.mesh.surface_set_material(0, ring_mat)
	ring_mesh.rotation.x = -PI / 2
	ring_mesh.visible = false
	add_child(ring_mesh)
	ring = ring_mesh

func engaged() -> bool:
	return state == 'erupting' or state == 'active' or state == 'collapse'

func reset_run() -> void:
	state = 'idle'
	eruption_t = 0.0
	collapse_t = 0.0
	cooldown_t = 0.0
	shockwave_active = false
	shockwave_radius = 0.0
	ring.visible = false
	for s in shards:
		s.queue_free()
	shards.clear()
	monolith.reset_run()

func update(dt: float, player_pos: Vector3, player_vel: Vector3) -> void:
	var in_zone: bool = player_pos.distance_to(zone_center) < TERRAIN.BOSS['zoneRadius']
	match state:
		'idle':
			if in_zone:
				state = 'erupting'
				eruption_t = 0.0
				monolith.erupt()
				world.fx.show_banner('MONOLITH ERUPTING')
				SFX.shockwave_slam()
				world.fx.recoil(0.9)
		'erupting':
			eruption_t += dt / TERRAIN.BOSS['eruptionSeconds']
			monolith.set_eruption_progress(eruption_t)
			world.fx.recoil(0.08)
			if eruption_t >= 1.0:
				state = 'active'
		'active':
			monolith.face_toward(player_pos, dt)
			_update_attacks(dt, player_pos, player_vel)
			if monolith.health_frac() <= 0.001 or \
					(not in_zone and player_pos.distance_to(zone_center) > TERRAIN.BOSS['zoneRadius'] * 2):
				state = 'collapse'
				collapse_t = 0.0
		'collapse':
			collapse_t += dt
			if collapse_t > 1.0:
				monolith.collapse()
				GAME.cargo += TERRAIN.BOSS['rewardCrystals']
				world.set_target_dot('frag')
				world.fx.show_banner('MONOLITH NEUTRALIZED')
				SFX.monolith_neutralized()
				world.fx.recoil(0.8)
				state = 'cooldown'
				cooldown_t = TERRAIN.BOSS['respawnCooldown']
		'cooldown':
			cooldown_t -= dt
			if cooldown_t <= 0.0:
				state = 'idle'
	ring.visible = shockwave_active
	_update_shards(dt, player_pos)

func _update_attacks(dt: float, player_pos: Vector3, player_vel: Vector3) -> void:
	var apex: Vector3 = monolith.position
	apex.y += TERRAIN.BOSS['grid']['y'] * TERRAIN.BOSS['cellSize'] * 0.85
	volley_timer -= dt
	if volley_timer <= 0.0:
		volley_timer = TERRAIN.BOSS['volleyInterval'] * (0.8 + randf() * 0.4)
		var flight: float = player_pos.distance_to(apex) / TERRAIN.BOSS['shardSpeed']
		var predicted: Vector3 = player_pos + player_vel * (flight * 0.5)
		for i in TERRAIN.BOSS['shardsPerVolley']:
			var sv: Vector3 = (predicted - apex).normalized()
			sv.x += (randf() - 0.5) * 0.14
			sv.y += 0.05 + randf() * 0.08
			sv.z += (randf() - 0.5) * 0.14
			sv = sv.normalized() * TERRAIN.BOSS['shardSpeed']
			var origin: Vector3 = apex + Vector3((randf() - 0.5) * 2.0, 0.0, (randf() - 0.5) * 2.0)
			_spawn_shard(origin, sv)
		world.fx.recoil(0.18)
	shockwave_timer -= dt
	if shockwave_timer <= 0.0 and monolith.health_frac() < 0.9:
		shockwave_timer = TERRAIN.BOSS['shockwaveInterval']
		shockwave_active = true
		shockwave_radius = 2.0
		shockwave_prev = 0.0
		ring.position = Vector3(apex.x, TERRAIN.get_effective_ground_height(apex.x, apex.z) + 0.15, apex.z)
		SFX.shockwave_slam()
		world.fx.recoil(0.3)
	if shockwave_active:
		var prev := shockwave_prev
		shockwave_prev = shockwave_radius
		shockwave_radius += TERRAIN.BOSS['shockwaveSpeed'] * dt
		ring.scale = Vector3.ONE * shockwave_radius
		var dist := Vector2(player_pos.x - ring.position.x, player_pos.z - ring.position.z).length()
		if dist >= prev and dist <= shockwave_radius and dist > 0.1:
			var falloff := maxf(1.0 - dist / TERRAIN.BOSS['shockwaveMaxRadius'], 0.25)
			var nx := (player_pos.x - ring.position.x) / dist
			var nz := (player_pos.z - ring.position.z) / dist
			var kb: float = TERRAIN.BOSS['shockwaveImpulse'] / 1000.0 * falloff
			world.player_vel_add(nx * kb, nz * kb)
			world.damage_player(6)
			world.fx.recoil(0.55)
		if shockwave_radius >= TERRAIN.BOSS['shockwaveMaxRadius']:
			shockwave_active = false

func _spawn_shard(pos: Vector3, vel: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = PRIMITIVES.box_mesh([{ 'min': Vector3(-0.35, -0.35, -0.35), 'max': Vector3(0.35, 0.35, 0.35), 'color': Color(0xd9a441) }])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0xd9a441)
	mat.emission_enabled = true
	mat.emission = Color(0xd9a441)
	mat.emission_energy_multiplier = 1.5
	mi.mesh.surface_set_material(0, mat)
	mi.position = pos
	add_child(mi)
	shards.append({ 'node': mi, 'vel': vel, 'life': 0.0 })

func _update_shards(dt: float, player_pos: Vector3) -> void:
	var i: int = 0
	while i < shards.size():
		var s: Dictionary = shards[i]
		s['life'] += dt
		var vel: Vector3 = s['vel']
		vel.y -= 19.6 * dt
		vel += Vector3(0.5, 0.0, 0.2) * dt
		var mi: MeshInstance3D = s['node']
		mi.position += vel * dt
		mi.rotation.x += dt * 3.0
		mi.rotation.y += dt * 4.0
		s['vel'] = vel
		var dead := false
		if mi.position.distance_to(player_pos) < 2.6:
			world.damage_player(TERRAIN.BOSS['shardDamage'])
			SFX.shard_impact()
			dead = true
		elif mi.position.y <= TERRAIN.get_effective_ground_height(mi.position.x, mi.position.z):
			dead = true
		elif s['life'] > 6.0:
			dead = true
		if dead:
			mi.queue_free()
			shards.remove_at(i)
		else:
			i += 1

class Monolith:
	extends Node3D

	var world: Node
	var cells: Array = []
	var max_cells: int = 0
	var code: String = ''
	var mesh: MeshInstance3D
	var material: StandardMaterial3D
	var collision_radius: float
	var _rng_seed := 0

	func _rng() -> float:
		_rng_seed = _si32(_rng_seed * 1664525 + 1013904223)
		return float((_rng_seed & 0xFFFFFFFF) >> 8 & 0xFFFFFF) / 16777216.0

	func setup(center: Vector3, w: Node) -> void:
		world = w
		collision_radius = TERRAIN.BOSS['grid']['x'] * TERRAIN.BOSS['cellSize'] * 0.5
		var cs := 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789'
		for i in 4:
			code += cs[randi() % cs.length()]
		code = 'MNX-' + code
		material = StandardMaterial3D.new()
		material.albedo_color = CRYSTAL_ALBEDO
		material.emission_enabled = true
		material.emission = CRYSTAL_EMISSIVE
		material.emission_energy_multiplier = 0.0
		material.roughness = 0.35
		mesh = MeshInstance3D.new()
		add_child(mesh)
		position = Vector3(center.x, -100.0, center.z)
		build_cells()
		rebuild_mesh()
		visible = false

	func health_frac() -> float:
		var alive := 0
		for c in cells:
			if c['alive']:
				alive += 1
		return float(alive) / maxf(float(max_cells), 1.0)

	func is_active() -> bool:
		return visible and health_frac() > 0.0

	func reset_run() -> void:
		visible = false
		position.y = -100.0
		build_cells()
		rebuild_mesh()

	func build_cells() -> void:
		cells.clear()
		var nx: int = TERRAIN.BOSS['grid']['x']
		var ny: int = TERRAIN.BOSS['grid']['y']
		var nz: int = TERRAIN.BOSS['grid']['z']
		var s: float = TERRAIN.BOSS['cellSize']
		_rng_seed = 424242
		for iy in ny:
			var taper := 1.0 - (float(iy) / ny) * 0.55
			for ix in nx:
				for iz in nz:
					if _rng() < 0.12:
						continue
					var half := Vector3(s * taper * (0.42 + _rng() * 0.12), s / 2.0, s * taper * (0.42 + _rng() * 0.12))
					var center := Vector3((ix - (nx - 1) / 2.0) * s * taper, s / 2.0 + iy * s, (iz - (nz - 1) / 2.0) * s * taper)
					cells.append({ 'center': center, 'half': half, 'alive': true })
		max_cells = cells.size()

	func erupt() -> void:
		visible = true
		var zx: Vector3 = zone_h()
		position.y = TERRAIN.get_effective_ground_height(zx.x, zx.z) - TERRAIN.BOSS['grid']['y'] * TERRAIN.BOSS['cellSize'] - 6.0

	func zone_h() -> Vector3:
		return Vector3(position.x, 0.0, position.z)

	func set_eruption_progress(t01: float) -> void:
		var base_y := TERRAIN.get_effective_ground_height(zone_h().x, zone_h().z)
		var eased := 1.0 - pow(1.0 - clampf(t01, 0.0, 1.0), 3.0)
		position.y = base_y - TERRAIN.BOSS['grid']['y'] * TERRAIN.BOSS['cellSize'] - 6.0 \
			+ eased * (TERRAIN.BOSS['grid']['y'] * TERRAIN.BOSS['cellSize'] + 6.0)
		material.emission_energy_multiplier = (1.0 - health_frac()) * 0.7

	func face_toward(tgt: Vector3, dt: float, speed: float = 0.4) -> void:
		var dx := tgt.x - position.x
		var dz := tgt.z - position.z
		var target_yaw := atan2(dx, dz)
		var delta := angle_difference(target_yaw, rotation.y)
		rotation.y += delta * minf(speed * dt, 1.0)

	func handle_hit(point: Vector3) -> bool:
		if not is_active():
			return false
		var local := to_local(point)
		var shed := 0
		for c in cells:
			if shed >= 3:
				break
			if not c['alive']:
				continue
			var center: Vector3 = c['center']
			if local.distance_to(center) < TERRAIN.BOSS['cellSize'] * 1.35:
				c['alive'] = false
				shed += 1
		if shed == 0:
			return true
		rebuild_mesh()
		material.emission_energy_multiplier = (1.0 - health_frac()) * 0.85
		return true

	func collapse() -> void:
		for c in cells:
			c['alive'] = false
		rebuild_mesh()
		visible = false
		build_cells()
		rebuild_mesh()
		material.emission_energy_multiplier = 0.0

	func rebuild_mesh() -> void:
		var alive_cells: Array = []
		for c in cells:
			if c['alive']:
				var h: Vector3 = c['half']
				var ct: Vector3 = c['center']
				alive_cells.append({ 'min': ct - h, 'max': ct + h, 'color': CRYSTAL_ALBEDO })
		if alive_cells.is_empty():
			mesh.mesh = null
			return
		var m := PRIMITIVES.box_mesh(alive_cells)
		m.surface_set_material(0, material)
		mesh.mesh = m

	static func angle_difference(target: float, current: float) -> float:
		var d := target - current
		while d > PI:
			d -= TAU
		while d < -PI:
			d += TAU
		return d

	static func _si32(v: int) -> int:
		v = v & 0xFFFFFFFF
		if v >= 0x80000000:
			v -= 0x100000000
		return v