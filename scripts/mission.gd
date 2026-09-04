extends Node
## Mission state machine — port of updateMission() and the flow hooks from
## sample.html. Deliberately preserves the source's dead phase: closing the
## upgrade garage sets 'delivery_brief' but nothing ever advances 'delivery_brief'
## to 'delivery'; the corridor + MISSION COMPLETE path is only reachable via the
## redeploy-after-fail route (see AGENTS.md "known verbatim quirks").

var world: Node
var player: Node
var hud: Node
var fx: Node
var garage: Node

func _get_target() -> Vector3:
	var p: Dictionary = TERRAIN.MISSION
	if GAME.mission_phase == 'mine' and world and world.tutorial_node:
		return world.tutorial_node.position
	if GAME.mission_phase == 'return':
		return Vector3(float(p['start']['x']), 0.0, float(p['start']['z']) + 8.0)
	return Vector3(float(p['dest']['x']), 0.0, float(p['dest']['z']))

func update(dt: float) -> void:
	if not player:
		return
	var p: Dictionary = TERRAIN.MISSION
	var target := _get_target()
	if player.camera:
			var yaw_to_target: float = atan2(target.x - player.position.x, target.z - player.position.z)
			var diff: float = yaw_to_target - player.aim_yaw
			while diff > PI:
				diff -= TAU
			while diff < -PI:
				diff += TAU
			GAME.compass_angle += (diff * 180.0 / PI - GAME.compass_angle) * minf(1.0, dt * 10.0)
			if GAME.compass_angle > 180.0:
				GAME.compass_angle -= 360.0
			elif GAME.compass_angle < -180.0:
				GAME.compass_angle += 360.0
			if hud:
				hud.set_compass(GAME.compass_angle)

	var r: Dictionary = _mission_route()
	var len2: float = r['dx'] * r['dx'] + r['dz'] * r['dz']
	var t: float = ((player.position.x - float(p['start']['x'])) * r['dx'] + (player.position.z - float(p['start']['z'])) * r['dz']) / len2
	if hud:
		hud.set_route_fill(clampf(t, 0.0, 1.0))

	if GAME.mission_phase != 'delivery':
		if hud:
			hud.set_corridor_warning(false, 0.0)
		if GAME.mission_phase == 'return':
			var d_start: float = player.position.distance_to(Vector3(float(p['start']['x']), 0.0, float(p['start']['z'])))
			if d_start < 40.0 and world and world.near_settlement:
				GAME.mission_phase = 'upgrades'
				if garage:
					garage.open(true)
				if fx:
					fx.open_upgrades_dialogue()
		return

	var dist_to_dest: float = player.position.distance_to(Vector3(float(p['dest']['x']), 0.0, float(p['dest']['z'])))
	if dist_to_dest < float(p['arriveRadius']):
		GAME.mission_phase = 'complete'
		GAME.cargo += 2000.0
		if fx:
			fx.show_banner('MISSION COMPLETE')
		SFX.reload_success(0.5)
		if hud:
			hud.set_corridor_warning(false, 0.0)
		return

	var outside: bool = TERRAIN.mission_corridor_dist(player.position.x, player.position.z) > float(p['halfWidth'])
	if outside:
		if not GAME.mission_was_outside:
			SFX.overheat()
			GAME.mission_warn_timer = 0.0
		GAME.mission_warn_timer += dt
		var frac: float = minf(1.0, GAME.mission_warn_timer / float(p['failTime']))
		if hud:
			hud.set_corridor_warning(true, frac)
		if GAME.mission_warn_timer >= float(p['failTime']):
			GAME.mission_phase = 'failed'
			if fx:
				fx.show_center_message('MISSION FAILED', 'LEFT THE MISSION ZONE', 'CLICK TO RESTART AT GATEWAY BASTION')
			if hud:
				hud.set_corridor_warning(false, 0.0)
	else:
		GAME.mission_warn_timer = 0.0
		if hud:
			hud.set_corridor_warning(false, 0.0)
	GAME.mission_was_outside = outside

func _mission_route() -> Dictionary:
	var p: Dictionary = TERRAIN.MISSION
	return {
		'dx': float(p['dest']['x']) - float(p['start']['x']),
		'dz': float(p['dest']['z']) - float(p['start']['z']),
	}
