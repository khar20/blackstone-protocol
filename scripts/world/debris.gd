extends Node3D
## Placeholder rock/debris chunks: six spinning cubes that shatter the monolith
## lattice on kill. Visual only (blocks have no colliders).

const PRIMITIVES = preload("res://scripts/world/primitives.gd")

var _blocks: Array = []
var _mesh: Mesh
var _life: float = 0.0
var extra_velocity := Vector3.ZERO

func init_debris(at: Vector3, color: Color, bounce: float = 1.0) -> void:
	position = at
	_mesh = PRIMITIVES.box_mesh([
		{ 'min': Vector3.ZERO, 'max': Vector3(0.8, 0.8, 0.8), 'color': color },
	])
	for i in 6:
		var b := MeshInstance3D.new()
		b.mesh = _mesh
		b.position = Vector3(randf_range(-0.5, 0.5), randf_range(0.4, 1.6), randf_range(-0.5, 0.5))
		b.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))
		b.scale = Vector3(randf_range(0.2, 0.6), randf_range(0.2, 0.6), randf_range(0.2, 0.6)) * bounce
		add_child(b)
		_blocks.append({ 'node': b, 'vel': Vector3(randf_range(-2, 2), randf_range(2, 6), randf_range(-2, 2)) + extra_velocity, 'spin': Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4)) })

func _process(delta: float) -> void:
	_life += delta
	if _life > 3.0:
		queue_free()
		return
	for blk in _blocks:
		var b: MeshInstance3D = blk['node']
		var vel: Vector3 = blk['vel']
		vel.y -= 9.8 * delta
		b.position += vel * delta
		b.rotation += (blk['spin'] as Vector3) * delta
		if b.position.y < 0.2:
			vel.y = absf(vel.y) * 0.4
			b.position.y = 0.2
		blk['vel'] = vel