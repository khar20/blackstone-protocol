extends Node
## Kinematic player projectiles: cannon shells (ballistic, wind, ground hits)
## and turret rounds (linear, lattice-only). No physics bodies. Placeholder
## visuals: one shared cube+tracer mesh per round (vertex colors, unshaded),
## oriented along the velocity each step. The world owns the collider
## authority; the manager advances and asks the world per step.

const PRIMITIVES = preload("res://scripts/world/primitives.gd")

const SHELL_GRAVITY: float = 19.6
const WIND_X: float = 0.5
const WIND_Z: float = 0.2

var shells: Array = []
var turrets: Array = []
var world: Node

var _round_mesh: Mesh

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_round_mesh = PRIMITIVES.box_mesh([
		{ 'min': Vector3(-0.12, -0.12, -0.12), 'max': Vector3(0.12, 0.12, 0.12), 'color': Color(0xffe0a3) },
		{ 'min': Vector3(-0.035, -0.035, 0.12), 'max': Vector3(0.035, 0.035, 1.7), 'color': Color(0xd9a05b) },
	])
	_round_mesh.surface_set_material(0, mat)

func fire_shell(pos: Vector3, vel: Vector3) -> void:
	shells.append({ 'pos': pos, 'prev': pos, 'vel': vel, 'life': 0.0, 'node': _spawn_round(pos, vel) })

func fire_turret(pos: Vector3, dir: Vector3) -> void:
	turrets.append({ 'pos': pos, 'prev': pos, 'vel': dir * 170.0, 'life': 0.0, 'node': _spawn_round(pos, dir * 170.0) })

func _spawn_round(pos: Vector3, vel: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _round_mesh
	add_child(mi)
	mi.position = pos
	_orient_round(mi, vel)
	return mi

func _orient_round(mi: MeshInstance3D, vel: Vector3) -> void:
	var dir := vel.normalized()
	if absf(dir.dot(Vector3.UP)) < 0.99:
		mi.look_at(mi.global_position + dir, Vector3.UP)

func process_step(delta: float) -> void:
	_step_shells(delta)
	_step_turrets(delta)

func _step_shells(delta: float) -> void:
	var hit_agent: Callable = Callable(world, 'shell_hit')
	var impact: Callable = Callable(world, 'on_shell_impact')
	var i: int = 0
	while i < shells.size():
		var s: Dictionary = shells[i]
		s['life'] += delta
		var vel: Vector3 = s['vel']
		vel.y -= SHELL_GRAVITY * delta
		vel += Vector3(WIND_X, 0.0, WIND_Z) * delta
		s['vel'] = vel
		s['prev'] = s['pos']
		s['pos'] += vel * delta
		var node: MeshInstance3D = s['node']
		node.position = s['pos']
		_orient_round(node, vel)
		var dead := false
		if s['life'] > 5.5:
			dead = true
		else:
			var hit: Dictionary = hit_agent.call(s['pos'], s['prev'])
			if hit['hit']:
				impact.call(hit)
				dead = true
		if dead:
			node.queue_free()
			shells.remove_at(i)
		else:
			i += 1

func _step_turrets(delta: float) -> void:
	var hit_agent: Callable = Callable(world, 'turret_hit')
	var impact: Callable = Callable(world, 'on_turret_impact')
	var i: int = 0
	while i < turrets.size():
		var s: Dictionary = turrets[i]
		s['life'] += delta
		s['prev'] = s['pos']
		s['pos'] += s['vel'] * delta
		var node: MeshInstance3D = s['node']
		node.position = s['pos']
		_orient_round(node, s['vel'])
		var dead := false
		if s['life'] > 1.1:
			dead = true
		else:
			var hit: Dictionary = hit_agent.call(s['pos'], s['prev'])
			if hit['hit']:
				impact.call(hit)
				dead = true
		if dead:
			node.queue_free()
			turrets.remove_at(i)
		else:
			i += 1
