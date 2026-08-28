extends Node
## Kinematic player projectiles: cannon shells (ballistic, wind, ground hits)
## and turret rounds (linear, lattice-only). No physics bodies. The world owns
## the collider authority; the manager advances and asks the world per step.

const SHELL_GRAVITY: float = 19.6
const WIND_X: float = 0.5
const WIND_Z: float = 0.2

var shells: Array = []
var turrets: Array = []
var world: Node

func fire_shell(pos: Vector3, vel: Vector3) -> void:
	shells.append({ 'pos': pos, 'prev': pos, 'vel': vel, 'life': 0.0 })

func fire_turret(pos: Vector3, dir: Vector3) -> void:
	turrets.append({ 'pos': pos, 'prev': pos, 'vel': dir * 170.0, 'life': 0.0 })

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
		var dead := false
		if s['life'] > 5.5:
			dead = true
		else:
			var hit: Dictionary = hit_agent.call(s['pos'], s['prev'])
			if hit['hit']:
				impact.call(hit)
				dead = true
		if dead:
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
		var dead := false
		if s['life'] > 1.1:
			dead = true
		else:
			var hit: Dictionary = hit_agent.call(s['pos'], s['prev'])
			if hit['hit']:
				impact.call(hit)
				dead = true
		if dead:
			turrets.remove_at(i)
		else:
			i += 1