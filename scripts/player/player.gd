extends Node3D
## Player tank: kinematic movement, collisions, cannon/turret/mining — an exact
## port of updatePlayerMovement / resolveCollisions / updateMiningInput /
## fireMainCannon / updateTurretFire / handleReloadPress from sample.html.
## No physics bodies; the world owns collider tables.

const TANK_MODEL = preload("res://scripts/player/tank_model.gd")
const PRIMITIVES = preload("res://scripts/world/primitives.gd")

const WORLD_BOUND := 1250.0
const MAX_MINING_RANGE := 26.0
const SHELL_SPEED := 98.0
const SHELL_GRAVITY := 19.6
const MOUSE_SENS := 0.0022
const BASE_FOV := 56.0
const ADS_FOV := 22.0

var world: Node
var camera: Node3D
var fx: Node
var hud: Node
var garage: Node

var tank: Node3D
var alive := true
var vel := Vector3.ZERO
var hull_yaw := 0.0
var chamber: int = 6
var max_chamber: int = 6
var reloading := false
var reload_timer := 0.0
var overheated := false
var turret_firing := false
var turret_fire_timer := 0.0
var active_weapon: String = 'cannon'
var aiming := false
var is_drifting := false
var in_panel := false
var dialogue := false
var is_turret_aligned := true
var current_aim_point := Vector3.ZERO
var aim_yaw := 0.0
var aim_pitch := 0.12
var _cannon_yaw := 0.0
var _cannon_pitch := 0.0
var collision_radius := 2.6

var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _mining_ring: MeshInstance3D
var _ring_mat: StandardMaterial3D

func _ready() -> void:
	tank = TANK_MODEL.new()
	add_child(tank)
	_build_mining_fx()

func _build_mining_fx() -> void:
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.albedo_color = Color(0xd9a05b)
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.albedo_color.a = 0.55
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam = MeshInstance3D.new()
	_beam.mesh = PRIMITIVES.box_mesh([{ 'min': Vector3(-0.03, -0.03, 0), 'max': Vector3(0.03, 0.03, 1), 'color': Color(0xd9a05b) }])
	_beam.visible = false
	add_child(_beam)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = Color(0xd9a05b)
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color.a = 0.3
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mining_ring = MeshInstance3D.new()
	_mining_ring.mesh = PRIMITIVES.ring_mesh(Vector3.ZERO, MAX_MINING_RANGE - 0.2, MAX_MINING_RANGE, 0.0, 48, Color(0xd9a05b))
	_mining_ring.mesh.surface_set_material(0, _ring_mat)
	_mining_ring.rotation.x = -PI / 2
	_mining_ring.visible = false
	add_child(_mining_ring)

func _physics_process(delta: float) -> void:
	if alive and not in_panel and not dialogue and GAME.state == 'PLAYING':
		_update_movement(delta)
		_update_turret_fire(delta)
		_update_mining(delta)
		if reloading:
			reload_timer += delta
	_update_visuals(delta)
	_update_mining_fx(delta)
	tank.turret_pivot.rotation.y = _cannon_yaw
	tank.gun_pitch.rotation.x = -_cannon_pitch

# ---- movement (sample.html updatePlayerMovement) ---------------------------

func _update_movement(delta: float) -> void:
	var accel := 22.0
	var steer_rate := 1.35
	var drift_kick: float = 8.5 + GAME.drift_level * 1.6
	var grip: float = 1.6 + GAME.drift_level * 0.4

	var throttle := 0.0
	if Input.is_key_pressed(KEY_W):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S):
		throttle -= 0.65

	var steer := 0.0
	if Input.is_key_pressed(KEY_A):
		steer += 1.0
	if Input.is_key_pressed(KEY_D):
		steer -= 1.0

	var wants_drift_brake := Input.is_key_pressed(KEY_SPACE)
	is_drifting = wants_drift_brake and vel.length() > 3.5

	if wants_drift_brake:
		throttle = 0.0
		grip *= 0.28
		steer_rate *= 1.85
		vel *= pow(0.55, delta)
		if randf() < 0.3:
			SFX.drift_skid()

	var fwd := Vector3(sin(hull_yaw), 0.0, cos(hull_yaw))
	var right := Vector3(cos(hull_yaw), 0.0, -sin(hull_yaw))
	var signed_speed := vel.dot(fwd)

	var steer_src := signed_speed if signed_speed != 0.0 else throttle
	if steer_src == 0.0:
		steer_src = 1.0
	var speed_factor: float = clampf(abs(signed_speed) / 4.0, 0.0, 1.0) * signf(steer_src)
	hull_yaw += steer * steer_rate * delta * speed_factor

	vel += fwd * (throttle * accel * delta)
	var speed := vel.length()

	if abs(steer) > 0.0 and speed > 2.5:
		var kick_src := signed_speed if signed_speed != 0.0 else 1.0
		vel += right * (-steer * drift_kick * delta * signf(kick_src))

	var lat := vel.dot(right)
	vel += right * (-lat * minf(1.0, grip * delta))

	vel *= pow(0.28, delta)
	if vel.length() > GAME.max_speed:
		vel = vel.normalized() * GAME.max_speed

	position += vel * delta
	var r := Vector2(position.x, position.z).length()
	if r > WORLD_BOUND:
		position *= WORLD_BOUND / r
		vel *= 0.2

	if world:
		world.resolve_collisions(delta)

	var ground_y := TERRAIN.get_effective_ground_height(position.x, position.z)
	position.y = lerpf(position.y, ground_y, delta * 12)

# ---- visual follow / turret aim (updatePlayerMovement part 2) -------------

func _update_visuals(delta: float) -> void:
	var fwd := Vector3(sin(hull_yaw), 0.0, cos(hull_yaw))
	var right := Vector3(cos(hull_yaw), 0.0, -sin(hull_yaw))
	tank.position = Vector3(position.x, position.y, position.z)
	tank.rotation.y = hull_yaw
	var sd := 2.4
	var h_f := TERRAIN.get_effective_ground_height(position.x + fwd.x * sd, position.z + fwd.z * sd)
	var h_b := TERRAIN.get_effective_ground_height(position.x - fwd.x * sd, position.z - fwd.z * sd)
	var h_l := TERRAIN.get_effective_ground_height(position.x + right.x * sd, position.z + right.z * sd)
	var h_r := TERRAIN.get_effective_ground_height(position.x - right.x * sd, position.z - right.z * sd)
	tank.rotation.x = lerpf(tank.rotation.x, atan2(h_b - h_f, sd * 2), delta * 8)
	tank.rotation.z = lerpf(tank.rotation.z, atan2(h_l - h_r, sd * 2), delta * 8)

	if camera:
		_update_turret_aim(delta)
		tank.side_turret.rotation.y = aim_yaw
	tank.muzzle_light.light_energy = lerpf(tank.muzzle_light.light_energy, 0.0, delta * 8)

func _update_turret_aim(delta: float) -> void:
	var anchor := position + Vector3(0, 1.8, 0.2)
	var d := Vector3(sin(aim_yaw) * cos(aim_pitch), sin(aim_pitch), cos(aim_yaw) * cos(aim_pitch))
	current_aim_point = anchor + d * 200.0

	var local_aim := tank.to_local(current_aim_point)
	var desired_local_yaw := clampf(atan2(local_aim.x, local_aim.z), -GAME.arc_limit, GAME.arc_limit)
	var aim_dist := maxf(1.0, Vector2(local_aim.x, local_aim.z).length())
	var aim_height := local_aim.y
	var v2 := SHELL_SPEED * SHELL_SPEED
	var disc := v2 * v2 - SHELL_GRAVITY * (SHELL_GRAVITY * aim_dist * aim_dist + 2.0 * aim_height * v2)
	var direct_pitch := atan2(aim_height, aim_dist)
	var ballistic_pitch := atan2(v2 - sqrt(maxf(disc, 0.0)), SHELL_GRAVITY * aim_dist) if disc >= 0.0 else direct_pitch
	var desired_pitch := clampf(ballistic_pitch, -0.2, 0.45)

	var yaw_diff := desired_local_yaw - _cannon_yaw
	var pitch_diff := desired_pitch - _cannon_pitch
	var max_yaw_step: float = GAME.turret_slew_rate * delta
	var max_pitch_step: float = 1.8 * delta

	if abs(yaw_diff) <= max_yaw_step:
		_cannon_yaw = desired_local_yaw
	else:
		_cannon_yaw += signf(yaw_diff) * max_yaw_step
	if abs(pitch_diff) <= max_pitch_step:
		_cannon_pitch = desired_pitch
	else:
		_cannon_pitch += signf(pitch_diff) * max_pitch_step

	is_turret_aligned = abs(yaw_diff) < 0.035 and abs(pitch_diff) < 0.035

# ---- weapons --------------------------------------------------------------

func fire_main_cannon() -> void:
	if chamber <= 0 or reloading:
		return
	if not alive or GAME.state != 'PLAYING' or in_panel or dialogue:
		return
	chamber -= 1
	var muzzle_world: Vector3 = tank.barrel_tip.global_position
	var dir: Vector3 = -tank.gun_pitch.global_transform.basis.z
	world.projectile_mgr.fire_shell(muzzle_world, dir * SHELL_SPEED)
	tank.muzzle_light.light_energy = 6.0
	var hull_fwd := Vector3(sin(hull_yaw), 0.0, cos(hull_yaw))
	vel += hull_fwd * (-4.2 - GAME.cannon_level * 0.35)
	if fx:
		fx.recoil(0.2)
	SFX.cannon_fire()
	if chamber == 0:
		start_reload_auto()

func start_reload_auto() -> void:
	if reloading:
		return
	reloading = true
	reload_timer = 0.0
	SFX.reload_start()

func handle_reload_press() -> void:
	if not alive or GAME.state != 'PLAYING':
		return
	if not reloading:
		if chamber == max_chamber:
			return
		start_reload_auto()
	else:
		var frac := reload_timer / GAME.reload_time
		if frac >= GAME.sweet_start and frac <= GAME.sweet_end:
			chamber = max_chamber
			reloading = false
			SFX.reload_success(frac)
		else:
			SFX.reload_fail(frac)

func _update_turret_fire(delta: float) -> void:
	if overheated:
		GAME.heat = maxf(0.0, GAME.heat - GAME.heat_cool_rate * 1.5 * delta)
		if GAME.heat <= GAME.max_heat * 0.25:
			overheated = false
		return
	if turret_firing and active_weapon == 'turret' and alive and not in_panel and GAME.state == 'PLAYING':
		turret_fire_timer -= delta
		if turret_fire_timer <= 0.0:
			turret_fire_timer = 0.085
			var origin: Vector3 = tank.side_tip.global_position
			var dir: Vector3 = -camera.global_transform.basis.z if camera else Vector3(0, 0, -1)
			world.projectile_mgr.fire_turret(origin, dir)
			SFX.turret_shot()
			GAME.heat = minf(GAME.max_heat, GAME.heat + 6.5)
			if GAME.heat >= GAME.max_heat:
				overheated = true
				SFX.overheat()
	else:
		GAME.heat = maxf(0.0, GAME.heat - GAME.heat_cool_rate * delta)

func toggle_weapon() -> void:
	if GAME.state != 'PLAYING':
		return
	active_weapon = 'turret' if active_weapon == 'cannon' else 'cannon'
	if hud:
		hud.on_weapon_switch(active_weapon)
	SFX.weapon_switch()

func toggle_view() -> void:
	if GAME.state != 'PLAYING':
		return
	if fx:
		fx.toggle_view()
	SFX.ui_blip()

# ---- mining (sample.html updateMiningInput) --------------------------------

func _update_mining(delta: float) -> void:
	var want_mine := Input.is_key_pressed(KEY_F) and alive and not in_panel and GAME.state == 'PLAYING' \
		and not dialogue and camera != null
	if not want_mine:
		return
	var closest: Node = null
	var closest_dist := INF
	var nodes: Array = world.mining_nodes
	if world.tutorial_node:
		nodes = nodes.duplicate()
		nodes.append(world.tutorial_node)
	for node in nodes:
		if node.depleted or node.despawning:
			continue
		var d: float = position.distance_to(node.position)
		if d > MAX_MINING_RANGE:
			continue
		var to_node: Vector3 = (node.position - camera.global_position).normalized()
		var cam_dir: Vector3 = -camera.global_transform.basis.z
		if to_node.dot(cam_dir) > 0.94 and d < closest_dist:
			closest = node
			closest_dist = d

	if closest:
		var nozzle_world: Vector3 = tank.mining_nozzle.global_position
		_beam_target = closest.position + Vector3(0, 1.8, 0)
		_beam_active = true
		_beam_source = nozzle_world

		var spec: Dictionary = closest.spec
		var yield_amt: float = 16.0 * spec['rate'] * (1.0 + GAME.mining_level * 0.28) * delta
		closest.pool -= yield_amt
		GAME.inventory[closest.kind] += yield_amt
		GAME.cargo += yield_amt * spec['value']

		if GAME.mission_phase == 'mine':
			GAME.mission_phase = 'return'
			if fx:
				fx.show_banner('NODE HARVESTED')
			SFX.ui_blip()

		if hud:
			hud.open_mining_circle(1.0 - closest.pool / closest.max_pool)

		if closest.pool <= 0.0:
			closest.deplete()
	else:
		_beam_active = false
	if hud:
		hud.set_mining_active(closest != null)
	_mining_ring.visible = true
	_mining_ring.position = Vector3(position.x, TERRAIN.get_effective_ground_height(position.x, position.z) + 0.1, position.z)
	_mining_ring.rotation.y = 0.0

var _beam_active := false
var _beam_source := Vector3.ZERO
var _beam_target := Vector3.ZERO

func _update_mining_fx(delta: float) -> void:
	_beam.visible = _beam_active
	_ring_mat.albedo_color.a = 0.3 if _beam_active else 0.0
	if _beam_active:
		var from: Vector3 = _beam_source
		var to: Vector3 = _beam_target
		_beam.global_position = from
		_beam.look_at(to, Vector3.UP)
		var beam_len := from.distance_to(to)
		_beam.scale = Vector3(1.0, 1.0, beam_len)
		_beam_mat.albedo_color.a = 0.55
	else:
		_beam_mat.albedo_color.a = lerpf(_beam_mat.albedo_color.a, 0.0, delta * 8)

# ---- damage / respawn ------------------------------------------------------

func damage(amount: int) -> void:
	if not alive or GAME.state != 'PLAYING':
		return
	GAME.hull = maxf(0, GAME.hull - float(amount))
	if fx:
		fx.flash()
	if GAME.hull <= 0:
		player_down()

func player_down() -> void:
	alive = false
	turret_firing = false
	aiming = false
	if fx:
		fx.show_center_message('UNIT DISABLED', 'HULL BREACH — RECOVERY SYSTEM STANDBY', 'CLICK TO REDEPLOY')

func reset_player() -> void:
	position = Vector3(0.0, TERRAIN.get_effective_ground_height(0.0, 10.0), 10.0)
	vel = Vector3.ZERO
	hull_yaw = 0.0
	aim_yaw = 0.0
	aim_pitch = 0.12
	_cannon_yaw = 0.0
	_cannon_pitch = 0.0
	GAME.hull = GAME.max_hull
	chamber = max_chamber
	reloading = false
	GAME.heat = 0.0
	overheated = false
	alive = true

func respawn_at_start() -> void:
	reset_player()
	var s: Dictionary = TERRAIN.MISSION['start']
	position = Vector3(float(s['x']), TERRAIN.get_effective_ground_height(float(s['x']), float(s['z']) + 8.0), float(s['z']) + 8.0)
	GAME.mission_warn_timer = 0.0
	if GAME.mission_phase == 'failed':
		GAME.mission_phase = 'delivery'

# ---- input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				handle_reload_press()
			KEY_V:
				toggle_view()
			KEY_TAB:
				toggle_weapon()
			KEY_E:
				if garage and GAME.state == 'PLAYING':
					if in_panel:
						close_panel()
					elif alive and not dialogue and world and world.near_settlement:
						garage.open(true)
			KEY_ESCAPE:
				if in_panel:
					close_panel()
				elif GAME.state == 'PLAYING' or GAME.state == 'PAUSED':
					if fx:
						fx.toggle_pause()
	if event is InputEventMouseButton:
		if GAME.state != 'PLAYING' or in_panel or dialogue:
			return
		if not alive:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if active_weapon == 'cannon':
					fire_main_cannon()
				else:
					turret_firing = true
			else:
				turret_firing = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			aiming = event.pressed
	if event is InputEventMouseMotion and GAME.state == 'PLAYING' and not in_panel and not dialogue:
		var s: float = MOUSE_SENS * 0.42 if aiming else MOUSE_SENS
		aim_yaw -= event.relative.x * s
		aim_pitch -= event.relative.y * s
		aim_pitch = clampf(aim_pitch, -0.45, 0.75)

func close_panel() -> void:
	if fx:
		fx.close_panel()