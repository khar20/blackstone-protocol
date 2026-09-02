extends Node3D
## Mining nodes: deterministic-ish crystal flora placeholders grown from the
## kind spec. Harvest/yield math (16 * rate * (1 + lvl*0.28) * dt) lives in the
## player miner; this node only tracks pool, respawn and despawn visuals.

const PRIMITIVES = preload("res://scripts/world/primitives.gd")

var kind: String
var spec: Dictionary
var pool: float
var max_pool: float
var depleted := false
var respawn_timer := 0.0
var despawning := false
var despawn_y := 0.0

var _gem_mat: StandardMaterial3D
var _base_mat: StandardMaterial3D

func setup(k: String, at: Vector3, variant: int) -> void:
	kind = k
	spec = TERRAIN.NODE_TYPES[k]
	pool = spec['pool']
	max_pool = pool
	position = at
	_gem_mat = StandardMaterial3D.new()
	_gem_mat.albedo_color = spec['color']
	_gem_mat.emission_enabled = true
	_gem_mat.emission = spec['emissive']
	_gem_mat.emission_energy_multiplier = 0.75
	_gem_mat.roughness = 0.2
	_gem_mat.metallic = 0.9
	_base_mat = StandardMaterial3D.new()
	_base_mat.albedo_color = Color('#2b2824')
	_base_mat.emission_enabled = true
	_base_mat.emission = spec['emissive']
	_base_mat.emission_energy_multiplier = 0.35
	_base_mat.roughness = 0.3
	_base_mat.metallic = 0.85
	_build_variant(variant)

func _add_cone(c: Vector3, r: float, h: float, segs: int, mat: StandardMaterial3D, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = PRIMITIVES.cylinder_mesh(c, r * 0.18, r, -h * 0.5, h * 0.5, segs, mat.albedo_color)
	mi.position = Vector3.ZERO
	mi.scale = scale_v
	mi.mesh.surface_set_material(0, mat)
	add_child(mi)
	return mi

func _add_box(minv: Vector3, maxv: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = PRIMITIVES.box_mesh([{ 'min': minv, 'max': maxv, 'color': mat.albedo_color }])
	mi.mesh.surface_set_material(0, mat)
	add_child(mi)

func _build_variant(variant: int) -> void:
	match variant:
		0:
			_add_box(Vector3(-0.3, -0.8, -0.3), Vector3(0.3, 0.8, 0.3), _gem_mat)
			for i in 4:
				var a := TAU * float(i) / 4.0
				_add_cone(Vector3(cos(a) * 0.3, 0.0, sin(a) * 0.3), 0.2, 1.4, 5, _gem_mat)
		1:
			for i in 8:
				var a := TAU * float(i) / 8.0
				_add_cone(Vector3(cos(a) * 0.35, 0.0, sin(a) * 0.35), 0.18, 1.2 + float(i % 3) * 0.5, 5, _gem_mat)
		2:
			_add_box(Vector3(-0.35, -0.5, -0.35), Vector3(0.35, 0.5, 0.35), _base_mat)
			for i in 5:
				var a := TAU * float(i) / 5.0
				_add_cone(Vector3(cos(a) * 0.5, 0.0, sin(a) * 0.5), 0.22, 1.3, 5, _gem_mat)
		_:
			_add_cone(Vector3.ZERO, 0.55, 2.2, 5, _gem_mat)
			for i in 6:
				var a := TAU * float(i) / 6.0
				_add_cone(Vector3(cos(a) * 0.5, 0.0, sin(a) * 0.5), 0.16, 1.0, 4, _base_mat)

func update_node(dt: float) -> void:
	if despawning:
		despawn_y += dt * 1.8
		position.y = TERRAIN.get_effective_ground_height(position.x, position.z) - despawn_y
		scale = scale * maxf(0.0, 1.0 - dt * 1.2)
		if despawn_y > 3.5:
			despawning = false
			visible = false
	elif depleted:
		respawn_timer -= dt
		if respawn_timer <= 0.0:
			depleted = false
			pool = max_pool
			visible = true
			scale = Vector3.ONE

func deplete() -> void:
	depleted = true
	pool = 0.0
	despawning = true
	despawn_y = 0.0
	respawn_timer = 45.0
	SFX.node_depleted()

func reset_run() -> void:
	visible = true
	scale = Vector3.ONE
	depleted = false
	despawning = false
	respawn_timer = 0.0
	pool = max_pool