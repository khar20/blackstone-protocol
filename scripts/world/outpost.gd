extends Node3D
## Settlement placeholder: concrete platform + walls + beacon + holo ring, and
## the exact outpostColliders tables from sample.html (the collision behavior).

const PRIMITIVES = preload("res://scripts/world/primitives.gd")

const CONCRETE := Color(0x8a847a)
const DARK_STEEL := Color(0x24221f)
const AMBER := Color(0xd9a05b)
const HOLO := Color(0x5ea89e)

var settlement_name: String
var s_type: String
var dock_radius: float
var garage_marker := Vector3.ZERO
var ring: MeshInstance3D
var ring_mat: StandardMaterial3D

func setup(pos: Vector3, nm: String, tp: String, world: Node) -> void:
	settlement_name = nm
	s_type = tp
	position = Vector3(pos.x, TERRAIN.get_effective_ground_height(pos.x, pos.z), pos.z)
	dock_radius = 30.0 if tp == 'town' else 18.0
	garage_marker = Vector3(0, 0, 10.0 if tp == 'town' else 4.0)
	_build_structure()
	_build_ring()
	_build_colliders(world, pos)

func _solid(minv: Vector3, maxv: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = PRIMITIVES.box_mesh([{ 'min': minv, 'max': maxv, 'color': c }])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	if c == AMBER:
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 0.9
	mi.mesh.surface_set_material(0, mat)
	add_child(mi)

func _build_structure() -> void:
	if s_type == 'town':
		_solid(Vector3(-65, 0, -55), Vector3(65, 1.9, 55), CONCRETE)
		_solid(Vector3(-63, 1.9, -53), Vector3(63, 2.0, 53), DARK_STEEL)
		_solid(Vector3(-12, 2.0, 58), Vector3(12, 2.4, 62.4), DARK_STEEL)
		_solid(Vector3(-63, 2.0, -53), Vector3(-61.96, 12, -51.96), CONCRETE)
		_solid(Vector3(61.96, 2.0, -53), Vector3(63, 12, -51.96), CONCRETE)
		_solid(Vector3(-63, 2.0, -53), Vector3(-15.96, 12, -51.96), CONCRETE)
		_solid(Vector3(15.96, 2.0, -53), Vector3(63, 12, -51.96), CONCRETE)
		_solid(Vector3(-63, 2.0, 51.96), Vector3(-15.96, 12, 53), CONCRETE)
		_solid(Vector3(15.96, 2.0, 51.96), Vector3(63, 12, 53), CONCRETE)
		_solid(Vector3(-68, 0, -58), Vector3(-54, 20, -44), CONCRETE)
		_solid(Vector3(54, 0, -58), Vector3(68, 20, -44), CONCRETE)
		_solid(Vector3(-68, 0, 44), Vector3(-54, 20, 58), CONCRETE)
		_solid(Vector3(54, 0, 44), Vector3(68, 20, 58), CONCRETE)
		_solid(Vector3(-45, 2.0, -39), Vector3(-5, 18, -17), CONCRETE)
		_solid(Vector3(10, 2.0, -42), Vector3(40, 15, -24), CONCRETE)
		_solid(Vector3(37, 2.0, 5), Vector3(47, 32, 15), CONCRETE)
	else:
		_solid(Vector3(-23, 0, -26), Vector3(23, 1.9, 28), CONCRETE)
		_solid(Vector3(-23, 1.9, -26), Vector3(23, 2.0, 28), DARK_STEEL)
		_solid(Vector3(-23, 2.0, -17), Vector3(23, 14, -8), CONCRETE)
		_solid(Vector3(-23, 2.0, -8), Vector3(-17, 11, 26), CONCRETE)
		_solid(Vector3(17, 2.0, -8), Vector3(23, 11, 26), CONCRETE)
		_solid(Vector3(-23, 2.0, 21), Vector3(-7.5, 11, 26), CONCRETE)
		_solid(Vector3(7.5, 2.0, 21), Vector3(23, 11, 26), CONCRETE)

func _build_ring() -> void:
	ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = HOLO
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color.a = 0.35
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring = MeshInstance3D.new()
	var r: float = 9.0 if s_type == 'town' else 6.5
	ring.mesh = PRIMITIVES.ring_mesh(Vector3(0, 6.0, 4.0), r - 0.2, r, 0.0, 40, HOLO)
	ring.mesh.surface_set_material(0, ring_mat)
	add_child(ring)

func _build_colliders(world: Node, pos: Vector3) -> void:
	var gy := position.y
	if s_type == 'town':
		var town := [
			[-65, 65, -55, -51, gy + 14],
			[-65, -61, -55, 55, gy + 14],
			[61, 65, -55, 55, gy + 14],
			[-65, -14, 51, 55, gy + 14],
			[14, 65, 51, 55, gy + 14],
			[-68, -54, -58, -44, gy + 20],
			[54, 68, -58, -44, gy + 20],
			[-68, -54, 44, 58, gy + 20],
			[54, 68, 44, 58, gy + 20],
			[-45, -5, -39, -17, gy + 16],
			[10, 40, -42, -24, gy + 13],
			[37, 47, 5, 15, gy + 30],
		]
		for b in town:
			world.outpost_colliders.append({ 'minX': pos.x + b[0], 'maxX': pos.x + b[1], 'minZ': pos.z + b[2], 'maxZ': pos.z + b[3], 'maxY': b[4] })
	else:
		var small := [
			[-23, 23, -26, -8, gy + 14],
			[-23, -17, -10, 26, gy + 9],
			[17, 23, -10, 26, gy + 9],
			[-23, -7.5, 21, 26, gy + 9],
			[7.5, 23, 21, 26, gy + 9],
		]
		for b in small:
			world.outpost_colliders.append({ 'minX': pos.x + b[0], 'maxX': pos.x + b[1], 'minZ': pos.z + b[2], 'maxZ': pos.z + b[3], 'maxY': b[4] })