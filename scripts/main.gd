extends Node
## Main scene controller: builds and wires the whole black-box — deterministic
## world, player tank, camera rig, and the holo UI layers. Everything the UI
## needs is threaded here so scripts stay loosely coupled.

const WORLD = preload("res://scripts/world/world.gd")
const PLAYER = preload("res://scripts/player/player.gd")
const CAMERA = preload("res://scripts/camera_ctrl.gd")
const MISSION = preload("res://scripts/mission.gd")
const EFFECTS = preload("res://scripts/ui/effects.gd")
const HUD = preload("res://scripts/ui/hud.gd")
const DIALOGUE = preload("res://scripts/ui/dialogue.gd")
const GARAGE = preload("res://scripts/ui/garage.gd")
const MENUS = preload("res://scripts/ui/menus.gd")
const CRT = preload("res://scripts/ui/crt_overlay.gd")

var world: Node
var player: Node
var camera: Node
var mission: Node
var effects: Node
var hud: Node
var dialogue: Node
var garage: Node
var menus: Node
var crt: Node

var _elapsed := 0.0

func _ready() -> void:
	world = WORLD.new()
	add_child(world)
	player = PLAYER.new()
	add_child(player)
	camera = CAMERA.new()
	add_child(camera)
	mission = MISSION.new()
	add_child(mission)
	effects = EFFECTS.new()
	add_child(effects)
	hud = HUD.new()
	add_child(hud)
	dialogue = DIALOGUE.new()
	add_child(dialogue)
	garage = GARAGE.new()
	add_child(garage)
	menus = MENUS.new()
	add_child(menus)
	crt = CRT.new()
	add_child(crt)
	_wire()

	menus.show_initial()

func _wire() -> void:
	world.player = player
	world.fx = effects
	world.hud = hud
	world.camera = camera
	player.world = world
	player.camera = camera
	player.fx = effects
	player.hud = hud
	player.garage = garage
	camera.player = player
	camera.world = world
	camera.fx = effects
	mission.player = player
	mission.world = world
	mission.hud = hud
	mission.fx = effects
	mission.garage = garage
	effects.player = player
	effects.camera = camera
	effects.world = world
	effects.hud = hud
	effects.dialogue = dialogue
	effects.garage = garage
	effects.menus = menus
	hud.player = player
	hud.world = world
	hud.fx = effects
	dialogue.player = player
	garage.player = player
	garage.hud = hud
	garage.fx = effects
	garage.dialogue = dialogue
	garage.world = world
	menus.player = player
	menus.fx = effects
	menus.hud = hud
	menus.dialogue = dialogue
	menus.garage = garage
	menus.world = world

func _process(delta: float) -> void:
	_elapsed += delta
	if camera and player:
		camera.update_camera(delta, _elapsed)
	if mission:
		mission.update(delta)