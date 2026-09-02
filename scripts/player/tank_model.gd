extends Node3D
## Simple placeholder tank: a few colored blocks with named pivots for the
## turret, gun pitch, barrel tip, side autocannon and mining nozzle. Player
## drives the pivots' angles each frame; swap in real 3D models later without
## touching gameplay (anchors stay).

const PRIMITIVES = preload("res://scripts/world/primitives.gd")

const HULL := Color('#3a3630')
const HULL_DARK := Color('#241f19')
const AMBER := Color('#d9a05b')
const STEEL := Color('#9aa0a4')

var turret_pivot: Node3D
var gun_pitch: Node3D
var barrel: MeshInstance3D
var barrel_tip: Node3D
var side_turret: Node3D
var side_tip: Node3D
var mining_nozzle: Node3D
var optic_mount: Node3D
var muzzle_light: OmniLight3D

func _solid(minv: Vector3, maxv: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = PRIMITIVES.box_mesh([{ 'min': minv, 'max': maxv, 'color': c }])
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if c == AMBER:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.7
	m.roughness = 0.55
	mi.mesh.surface_set_material(0, m)
	return mi

func _ready() -> void:
	add_child(_solid(Vector3(-1.7, -0.2, -2.4), Vector3(1.7, 0.6, 2.4), HULL))
	add_child(_solid(Vector3(-2.1, -0.55, -2.9), Vector3(2.1, -0.45, 2.9), HULL_DARK))

	turret_pivot = Node3D.new()
	turret_pivot.position = Vector3(0, 0.62, 0.1)
	add_child(turret_pivot)
	turret_pivot.add_child(_solid(Vector3(-1.0, -0.05, -1.0), Vector3(1.0, 0.55, 1.0), HULL))
	turret_pivot.add_child(_solid(Vector3(-0.5, 0.5, -0.9), Vector3(0.5, 0.7, 1.0), AMBER))

	gun_pitch = Node3D.new()
	gun_pitch.position = Vector3(0, 0.45, 0.55)
	turret_pivot.add_child(gun_pitch)
	barrel = _solid(Vector3(-0.16, -0.16, 0.4), Vector3(0.16, 0.16, 3.0), STEEL)
	gun_pitch.add_child(barrel)
	barrel_tip = Node3D.new()
	barrel_tip.position = Vector3(0, 0, 3.0)
	gun_pitch.add_child(barrel_tip)

	mining_nozzle = Node3D.new()
	mining_nozzle.position = Vector3(0, 0.35, 2.5)
	add_child(mining_nozzle)
	add_child(_solid(Vector3(-0.12, 0.3, 2.2), Vector3(0.12, 0.44, 2.6), AMBER))

	side_turret = Node3D.new()
	side_turret.position = Vector3(1.85, 0.72, -0.7)
	add_child(side_turret)
	side_turret.add_child(_solid(Vector3(-0.3, -0.18, -0.85), Vector3(0.3, 0.18, 0.85), HULL_DARK))
	side_turret.add_child(_solid(Vector3(-0.1, -0.1, 0.5), Vector3(0.1, 0.1, 1.2), STEEL))
	side_tip = Node3D.new()
	side_tip.position = Vector3(0, 0, 1.2)
	side_turret.add_child(side_tip)

	optic_mount = Node3D.new()
	optic_mount.position = Vector3(0, 0.75, 1.0)
	turret_pivot.add_child(optic_mount)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color('#f2c98a')
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 18.0
	barrel_tip.add_child(muzzle_light)