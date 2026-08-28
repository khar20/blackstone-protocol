extends Node3D
## World owner: builds the deterministic terrain mesh, environment, dust, rock
## scatter, mission corridor, settlements, mining nodes and boss zones; owns
## collider tables, projectile handling and combat routing. World state lives
## here so missions/upgrades survive a player respawn.

const PRIMITIVES = preload("res://scripts/world/primitives.gd")
const OUTPOST = preload("res://scripts/world/outpost.gd")
const MINING_NODE = preload("res://scripts/world/mining_node.gd")
const BOSS_ZONE = preload("res://scripts/world/boss.gd")
const PROJECTILE_MGR = preload("res://scripts/world/projectile_mgr.gd")
const DEBRIS = preload("res://scripts/world/debris.gd")

const WORLD_SIZE := 2600
const SEG := 300

var sky_peace := Color(0xb5aea0)
var sky_combat := Color(0x1a1916)
var fog_near_peace := 70.0
var fog_far_peace := 520.0
var fog_near_combat := 30.0
var fog_far_combat := 320.0
var sun_color_peace := Color(0xf5e9ce)
var sun_color_combat := Color(0x1a1916)

var outpost_colliders: Array = []
var rock_colliders: Array = []
var settlements: Array = []
var mining_nodes: Array = []
var tutorial_node: Node
var boss_zones: Array = []
var monolith: Node
var projectile_mgr: Node
var player: Node
var fx: Node
var hud: Node
var camera: Node

var _env: Environment
var _sun: DirectionalLight3D
var _scar: MeshInstance3D
var _scar_material: StandardMaterial3D
var _scar_radius := 0.0
var _scar_target := 0.0
var _dust: GPUParticles3D

func _ready() -> void:
	_build_terrain()
	_build_environment()
	_build_scar()
	_build_dust()
	spawn_rocks()
	_build_corridor()
	spawn_outposts()
	spawn_mining_nodes()
	spawn_boss_zones()
	projectile_mgr = PROJECTILE_MGR.new()
	projectile_mgr.world = self
	add_child(projectile_mgr)

func _physics_process(delta: float) -> void:
	_update_zones(delta)
	projectile_mgr.process_step(delta)
	for n in mining_nodes:
		n.update_node(delta)
	_update_environment(delta)
	_update_settlement_proximity()

# ---- terrain geometry -------------------------------------------------------

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var step := WORLD_SIZE / float(SEG)
	var half := WORLD_SIZE * 0.5
	var n: int = SEG + 1
	var h_arr := PackedFloat32Array()
	h_arr.resize(n * n)
	for z in n:
		for x in n:
			var wx := -half + x * step
			var wz := -half + z * step
			h_arr[z * n + x] = TERRAIN.get_effective_ground_height(wx, wz)
	for z in n:
		for x in n:
			var wx := -half + x * step
			var wz := -half + z * step
			var h: float = h_arr[z * n + x]
			var b := clampf(TERRAIN.biome_field(wx, wz), 0.0, TERRAIN.BIOMES.size() - 0.001)
			var idx := int(floor(b))
			var frac := TERRAIN.smooth(b - idx)
			var c1: Color = TERRAIN.BIOMES[idx]['base']
			var c2: Color = TERRAIN.BIOMES[mini(idx + 1, TERRAIN.BIOMES.size() - 1)]['base']
			var col := c1.lerp(c2, frac)
			var speck := 0.92 + TERRAIN.value_noise2(wx * 0.15, wz * 0.15, 555) * 0.16
			if h > 12.0:
				col = col.lerp(TERRAIN.BIOMES[4]['alt'], minf(1.0, (h - 12.0) / 14.0))
			col = Color(col.r * speck, col.g * speck, col.b * speck)
			var nx := h_arr[maxi(z - 1, 0) * n + x] - h_arr[mini(z + 1, n - 1) * n + x]
			var nz := h_arr[z * n + maxi(x - 1, 0)] - h_arr[z * n + mini(x + 1, n - 1)]
			st.set_normal(Vector3(nx, 2.0 * step, nz).normalized())
			st.set_color(col)
			st.add_vertex(Vector3(wx, h, wz))
	for z in SEG:
		for x in SEG:
			var i0 := z * n + x
			var i1 := i0 + 1
			var i2 := i0 + n
			var i3 := i0 + n + 1
			st.add_index(i0)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i3)
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)

func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = sky_peace
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0xd9d3bf)
	_env.ambient_light_energy = 1.05
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_light_color = sky_peace
	_env.fog_depth_begin = fog_near_peace
	_env.fog_depth_end = fog_far_peace
	_env.glow_enabled = true
	_env.glow_intensity = 0.35
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.light_color = sun_color_peace
	_sun.light_energy = 0.95
	_sun.rotation_degrees = Vector3(-57.0, 20.0, 0.0)
	_sun.shadow_enabled = true
	add_child(_sun)

func _build_scar() -> void:
	_scar_material = StandardMaterial3D.new()
	_scar_material.albedo_color = Color(0x12100d)
	_scar_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_scar_material.albedo_color.a = 0.0
	_scar_material.roughness = 1.0
	_scar = MeshInstance3D.new()
	_scar.mesh = PRIMITIVES.ring_mesh(Vector3.ZERO, 0.0001, 1.0, 0.0, 36, Color(0x12100d))
	_scar.mesh.surface_set_material(0, _scar_material)
	_scar.rotation.x = -PI / 2
	_scar.position.y = 0.05
	add_child(_scar)

func _build_dust() -> void:
	_dust = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(1, 0, 0.5)
	pm.spread = 10.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.5
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(800, 16, 800)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0xd9a05b)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.4
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = PRIMITIVES.box_mesh([{ 'min': Vector3(-0.2, -0.2, -0.2), 'max': Vector3(0.2, 0.2, 0.2), 'color': Color(0xd9a05b) }])
	mi.mesh.surface_set_material(0, m)
	_dust.process_material = pm
	_dust.draw_pass_1 = mi.mesh
	_dust.amount = 450
	_dust.lifetime = 12.0
	_dust.emitting = true
	add_child(_dust)

func spawn_rocks() -> void:
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0x48443b)
	rock_mat.roughness = 0.9
	for i in 170:
		var x := (randf() - 0.5) * 1900.0
		var z := (randf() - 0.5) * 1900.0
		var near_outpost := false
		for o in TERRAIN.OUTPOST_COORDS:
			if Vector2(x - float(o['x']), z - float(o['z'])).length() < float(o['flatR']) - 5.0:
				near_outpost = true
		if near_outpost:
			continue
		var scl := 1.4 + randf() * 3.2
		var mi := MeshInstance3D.new()
		mi.mesh = PRIMITIVES.box_mesh([{ 'min': Vector3(-scl, -scl, -scl), 'max': Vector3(scl, scl, scl), 'color': Color(0x48443b) }])
		mi.mesh.surface_set_material(0, rock_mat)
		mi.position = Vector3(x, TERRAIN.get_effective_ground_height(x, z) + scl * 0.4, z)
		mi.rotation = Vector3(randf() * 2.0, randf() * 2.0, randf() * 2.0)
		add_child(mi)
		rock_colliders.append({ 'x': x, 'z': z, 'r': scl * 0.85 })

func _build_corridor() -> void:
	var r: Vector3 = TERRAIN.mission_route()
	var r_len := r.length()
	var px := -r.z / r_len
	var pz := r.x / r_len
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0xd9a05b)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.22
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side in [-1.0, 1.0]:
		for i in range(0, 81, 3):
			var f := float(i) / 80.0
			var x: float = float(TERRAIN.MISSION['start']['x']) + r.x * f + px * side * TERRAIN.MISSION['halfWidth']
			var z: float = float(TERRAIN.MISSION['start']['z']) + r.z * f + pz * side * TERRAIN.MISSION['halfWidth']
			var mi := MeshInstance3D.new()
			mi.mesh = PRIMITIVES.box_mesh([{ 'min': Vector3(-1.2, 0, -0.3), 'max': Vector3(1.2, 0.3, 0.3), 'color': Color(0xd9a05b) }])
			mi.mesh.surface_set_material(0, mat)
			mi.position = Vector3(x, TERRAIN.get_effective_ground_height(x, z) + 0.35, z)
			mi.rotation.y = atan2(r.x, r.z)
			add_child(mi)

# ---- spawn ----------------------------------------------------------------

func spawn_outposts() -> void:
	for coord in TERRAIN.OUTPOST_COORDS:
		var o := OUTPOST.new()
		add_child(o)
		o.setup(Vector3(float(coord['x']), 0.0, float(coord['z'])), coord['name'], coord['type'], self)
		settlements.append(o)

func spawn_mining_nodes() -> void:
	var kinds: Array = ['amber', 'amber', 'amber', 'obsidian', 'obsidian', 'prism']
	for i in 90:
		var kind: String = kinds[randi() % kinds.size()]
		var p := _random_world_point()
		var attempts := 0
		while _near_outpost(p) and attempts < 20:
			p = _random_world_point()
			attempts += 1
		_spawn_node(kind, Vector3(p.x, TERRAIN.get_effective_ground_height(p.x, p.y), p.y), randi() % 4)
	var s: float = float(TERRAIN.MISSION['start']['x']) - 55.0
	var nz: float = float(TERRAIN.MISSION['start']['z']) + 100.0
	var tp := Vector3(s, TERRAIN.get_effective_ground_height(s, nz), nz)
	tutorial_node = _spawn_node('amber', tp, 0)

func _spawn_node(kind: String, p: Vector3, variant: int) -> Node3D:
	var n := MINING_NODE.new()
	add_child(n)
	n.setup(kind, p, variant)
	mining_nodes.append(n)
	return n

func _random_world_point() -> Vector2:
	var a := randf() * TAU
	var rr := 80.0 + randf() * 1070.0
	return Vector2(sin(a) * rr, cos(a) * rr)

func _near_outpost(p: Vector2) -> bool:
	for o in TERRAIN.OUTPOST_COORDS:
		if p.distance_to(Vector2(float(o['x']), float(o['z']))) < float(o['flatR']) + 10.0:
			return true
	return false

func spawn_boss_zones() -> void:
	var r: Vector3 = TERRAIN.mission_route()
	var ang := atan2(r.z, r.x) + PI / 2.0
	var spots := [0.35, 0.7]
	for i in spots.size():
		var off: float = (1.0 if i == 0 else -1.0) * (70.0 + randf() * 90.0)
		var cx: float = float(TERRAIN.MISSION['start']['x']) + r.x * spots[i] + cos(ang) * off
		var cz: float = float(TERRAIN.MISSION['start']['z']) + r.z * spots[i] + sin(ang) * off
		var z := BOSS_ZONE.new()
		add_child(z)
		z.setup(Vector3(cx, 0.0, cz), self)
		boss_zones.append(z)

# ---- per-frame updates -----------------------------------------------------

func _update_zones(delta: float) -> void:
	if player and player.alive and GAME.state == 'PLAYING' and not player.in_panel and not player.dialogue:
		for z in boss_zones:
			z.update(delta, player.position, player.vel)
	monolith = focused_monolith()
	if player:
		_resolve_monolith_collisions(delta)

func focused_monolith() -> Node:
	var best: Node = null
	var bd := INF
	for z in boss_zones:
		var mn: Node = z.monolith
		if mn.is_active():
			var d: float = mn.global_position.distance_to(player.global_position) if player else 1.0
			if d < bd:
				bd = d
				best = mn
	return best

func _update_environment(delta: float) -> void:
	var in_combat: bool = monolith != null and monolith.is_active() and monolith.get_parent().engaged()
	var target_sky: Color = sky_combat if in_combat else sky_peace
	_env.background_color = _env.background_color.lerp(target_sky, delta * 0.8)
	_env.fog_light_color = _env.fog_light_color.lerp(target_sky, delta * 0.8)
	_env.fog_depth_begin = lerpf(_env.fog_depth_begin, fog_near_combat if in_combat else fog_near_peace, delta * 0.8)
	_env.fog_depth_end = lerpf(_env.fog_depth_end, fog_far_combat if in_combat else fog_far_peace, delta * 0.8)
	_sun.light_color = _sun.light_color.lerp(sun_color_combat if in_combat else sun_color_peace, delta * 0.8)
	_scar_target = TERRAIN.BOSS['grid']['y'] * TERRAIN.BOSS['cellSize'] * 2.1 if (in_combat and monolith) else 0.0
	_scar_radius = lerpf(_scar_radius, _scar_target, delta * 1.2)
	if in_combat and monolith:
		_scar.position = Vector3(monolith.position.x, TERRAIN.get_effective_ground_height(monolith.position.x, monolith.position.z) + 0.05, monolith.position.z)
	_scar.scale = Vector3(maxf(0.001, _scar_radius), 1.0, maxf(0.001, _scar_radius))
	_scar_material.albedo_color.a = minf(0.65, _scar_radius / maxf(_scar_target, 0.001) * 0.65)

func _update_settlement_proximity() -> void:
	var best := -1
	var best_dist: float = INF
	for i in settlements.size():
		var s: Node = settlements[i]
		var marker: Vector3 = s.global_position + s.garage_marker
		var d: float = player.global_position.distance_to(marker) if player else 9999.0
		s.ring_mat.albedo_color.a = 0.8 if d < s.dock_radius else 0.35
		if d < s.dock_radius and d < best_dist:
			best_dist = d
			best = i
	near_settlement = settlements[best] if best >= 0 else null
	if hud:
		hud.set_dock_prompt(near_settlement != null and player and player.alive and GAME.state == 'PLAYING' and not player.in_panel)

var near_settlement: Node

func reset_world() -> void:
	for z in boss_zones:
		z.reset_run()
	for n in mining_nodes:
		n.reset_run()
	if tutorial_node:
		tutorial_node.reset_run()

func engaged_boss_zone() -> Node:
	if not player:
		return null
	for z in boss_zones:
		if z.engaged() and z.monolith.is_active():
			return z
	return null

func _resolve_monolith_collisions(_delta: float) -> void:
	if not player:
		return
	var pr: float = player.collision_radius
	for z in boss_zones:
		var m: Node = z.monolith
		if not m.is_active():
			continue
		for box in outpost_colliders:
			var er: float = m.collision_radius
			var cx: float = clampf(m.position.x, box['minX'], box['maxX'])
			var cz: float = clampf(m.position.z, box['minZ'], box['maxZ'])
			var dx: float = m.position.x - cx
			var dz: float = m.position.z - cz
			var dsq: float = dx * dx + dz * dz
			if dsq < er * er:
				var dd: float = maxf(sqrt(dsq), 0.001)
				m.position.x += (dx / dd) * (er - dd)
				m.position.z += (dz / dd) * (er - dd)
		var mdx: float = player.position.x - m.position.x
		var mdz: float = player.position.z - m.position.z
		var min_dist: float = pr + m.collision_radius
		var d_sq: float = mdx * mdx + mdz * mdz
		if d_sq < min_dist * min_dist:
			var dd: float = maxf(sqrt(d_sq), 0.001)
			var overlap: float = min_dist - dd
			var nx: float = mdx / dd
			var nz: float = mdz / dd
			player.position.x += nx * overlap
			player.position.z += nz * overlap
			player.vel = Vector3(nx * 22.0, 0.0, nz * 22.0)
			fx.recoil(0.4)
			SFX.shockwave_slam()
			damage_player(25)

# ---- combat routing --------------------------------------------------------

func resolve_collisions(delta: float) -> void:
	if not player:
		return
	var pr: float = player.collision_radius
	for box in outpost_colliders:
		if player.position.y > box['maxY']:
			continue
		var cx: float = clampf(player.position.x, box['minX'], box['maxX'])
		var cz: float = clampf(player.position.z, box['minZ'], box['maxZ'])
		var dx: float = player.position.x - cx
		var dz: float = player.position.z - cz
		var dsq: float = dx * dx + dz * dz
		if dsq < pr * pr:
			var dd: float = maxf(sqrt(dsq), 0.001)
			var overlap: float = pr - dd
			var nx: float = dx / dd
			var nz: float = dz / dd
			player.position.x += nx * overlap
			player.position.z += nz * overlap
			var dot: float = player.vel.x * nx + player.vel.z * nz
			if dot < 0.0:
				player.vel.x -= nx * dot
				player.vel.z -= nz * dot
	for rock in rock_colliders:
		var dx: float = player.position.x - rock['x']
		var dz: float = player.position.z - rock['z']
		var min_dist: float = pr + rock['r']
		var dsq: float = dx * dx + dz * dz
		if dsq < min_dist * min_dist:
			var dd: float = maxf(sqrt(dsq), 0.001)
			var overlap: float = min_dist - dd
			var nx: float = dx / dd
			var nz: float = dz / dd
			player.position.x += nx * overlap
			player.position.z += nz * overlap
			var dot: float = player.vel.x * nx + player.vel.z * nz
			if dot < 0.0:
				player.vel.x -= nx * dot
				player.vel.z -= nz * dot
	_resolve_monolith_collisions(delta)

func player_vel_add(dx: float, dz: float) -> void:
	if player:
		player.vel.x += dx
		player.vel.z += dz

func damage_player(amount: int) -> void:
	if player:
		player.damage(amount)

func set_target_dot(state: String) -> void:
	if hud:
		hud.set_target_dot(state)

func shell_hit(pos: Vector3, prev: Vector3) -> Dictionary:
	var m := _test_lattice(pos, prev)
	if m['hit']:
		return { 'hit': true, 'kind': 'monolith', 'monolith': m['monolith'], 'point': m['point'] }
	for box in outpost_colliders:
		if pos.x >= box['minX'] and pos.x <= box['maxX'] and pos.z >= box['minZ'] and pos.z <= box['maxZ'] and pos.y <= box['maxY']:
			return { 'hit': true, 'kind': 'outpost', 'point': pos }
	if pos.y <= TERRAIN.get_effective_ground_height(pos.x, pos.z):
		var gy: float = TERRAIN.get_effective_ground_height(pos.x, pos.z)
		return { 'hit': true, 'kind': 'ground', 'point': Vector3(pos.x, gy, pos.z), 'impact': true }
	return { 'hit': false }

func on_shell_impact(hit: Dictionary) -> void:
	match hit['kind']:
		'monolith':
			hit['monolith'].handle_hit(hit['point'])
			if fx:
				fx.hit_marker()
			SFX.impact()
		_:
			spawn_fragment_burst(hit['point'], 2.5 if hit.get('impact', false) else 2.0, 3)
			SFX.impact()

func turret_hit(pos: Vector3, prev: Vector3) -> Dictionary:
	return _test_lattice(pos, prev)

func on_turret_impact(hit: Dictionary) -> void:
	hit['monolith'].handle_hit(hit['point'])
	if fx:
		fx.hit_marker()

func _test_lattice(pos: Vector3, _prev: Vector3) -> Dictionary:
	var best: Dictionary = { 'hit': false }
	for z in boss_zones:
		var m: Node = z.monolith
		if not m.is_active():
			continue
		var local: Vector3 = m.to_local(pos)
		for c in m.cells:
			if not c['alive']:
				continue
			var center: Vector3 = c['center']
			var half: Vector3 = c['half']
			if abs(local.x - center.x) <= half.x and abs(local.y - center.y) <= half.y and abs(local.z - center.z) <= half.z:
				if not best['hit'] or m.position.distance_to(pos) < 1.0:
					best = { 'hit': true, 'monolith': m, 'point': m.to_global(center) }
	return best

func spawn_fragment_burst(center: Vector3, _scale_base: float, count: int) -> void:
	for i in count:
		var d := DEBRIS.new()
		add_child(d)
		d.init_debris(center + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)), Color(0xd9a05b), 0.6)

func spawn_crystal_debris(world_center: Vector3, _half: Vector3, outward: Vector3) -> void:
	var d := DEBRIS.new()
	add_child(d)
	d.init_debris(world_center, Color(0xcfc8b8), 0.8)
	for b in d.get_children():
		b.position += outward * 0.1
	d.extra_velocity = outward

func spawn_burst_crystal_debris(center: Vector3, count: int, power: float) -> void:
	for i in count:
		var d := DEBRIS.new()
		add_child(d)
		d.init_debris(center + Vector3(randf_range(-3, 3), randf_range(-5, 5), randf_range(-3, 3)), Color(0xcfc8b8), 1.2)
		d.extra_velocity = Vector3(randf_range(-1, 1), randf(), randf_range(-1, 1)).normalized() * power