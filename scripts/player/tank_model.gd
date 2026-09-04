extends Node3D
## Placeholder tank: colored blocks with named pivots for the turret, gun
## pitch, barrel tip, side autocannon and mining nozzle. Player drives the
## pivots' angles each frame; swap in real 3D models later without touching
## gameplay (anchors stay). Meshes live in tank.tscn; script holds references.

@onready var turret_pivot: Node3D = $turret_pivot
@onready var gun_pitch: Node3D = $turret_pivot/gun_pitch
@onready var barrel_tip: Node3D = $turret_pivot/gun_pitch/barrel_tip
@onready var side_turret: Node3D = $side_turret
@onready var side_tip: Node3D = $side_turret/side_tip
@onready var mining_nozzle: Node3D = $mining_nozzle
@onready var optic_mount: Node3D = $turret_pivot/optic_mount
@onready var muzzle_light: OmniLight3D = $turret_pivot/gun_pitch/barrel_tip/MuzzleLight
