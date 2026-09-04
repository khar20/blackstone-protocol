extends CanvasLayer
## HUD port: systems/hull bar, cargo + resource tally, weapon chamber/heat,
## compass + route bar, zone warning, boss readout, target dot, dock prompt,
## turret alignment. Node tree lives in scenes/ui/hud.tscn; script binds refs
## and polls GAME/player/world readouts (matches updateHUD()).

const AMBER := Color('#d9a05b')
const AMBER_BRIGHT := Color('#ffe0a3')

const ICONS_RES = preload("res://scripts/ui/icons.gd")

var player: Node
var world: Node
var fx: Node

@onready var _hull_fill: TextureRect = $HullPanel/Row/HullFill
@onready var _cargo_val: Label = $CargoPanel/VB/Top/CargoVal
@onready var _res_amber: Label = $CargoPanel/VB/Res/ResAmber
@onready var _res_obsidian: Label = $CargoPanel/VB/Res/ResObsidian
@onready var _res_prism: Label = $CargoPanel/VB/Res/ResPrism
@onready var _chamber_row: HBoxContainer = $ChamberPanel/Row/ChamberWrap/ChamberRow
@onready var _chamber_wrap: Control = $ChamberPanel/Row/ChamberWrap
@onready var _heat_fill: TextureRect = $ChamberPanel/Row/HeatWrap/HV/HeatFill
@onready var _heat_wrap: Control = $ChamberPanel/Row/HeatWrap
@onready var _mode_icon: TextureRect = $ChamberPanel/Row/ModeIcon
@onready var _compass: TextureRect = $Compass
@onready var _route_fill: TextureRect = $Route/Row/RouteFill
@onready var _dock_prompt: Label = $DockPrompt
@onready var _turret_status: TextureRect = $TurretStatus
@onready var _zone_warning: PanelContainer = $ZoneWarning
@onready var _zone_bar: TextureRect = $ZoneWarning/VB/Row/ZoneBar
@onready var _boss: PanelContainer = $Boss
@onready var _boss_code: Label = $Boss/Row/BossCode
@onready var _boss_hp: TextureRect = $Boss/Row/BossHp
@onready var _target_dot: TextureRect = $TargetPanel/Row/TargetDot
@onready var _core_fill: TextureRect = $TargetPanel/Row/CoreFill
@onready var _mining_hint: Label = $MiningHint

var _last_hull := -1.0
var _last_cargo := -1
var _last_amber := -1
var _last_obsidian := -1
var _last_prism := -1
var _last_loaded := -1
var _last_weapon := ''
var _last_heat := -1.0
var _last_aligned := true

func _ready() -> void:
	_mode_icon.texture = ICONS_RES.fetch('cannon')
	_compass.texture = _compass_texture()
	_turret_status.texture = _turret_texture()
	_hull_fill.texture = _white()
	_heat_fill.texture = _white()
	_route_fill.texture = _white()
	_zone_bar.texture = _white()
	_target_dot.texture = _white()
	_core_fill.texture = _white()
	_boss_hp.texture = _white()

func _white() -> Texture2D:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.WHITE)
	return ImageTexture.create_from_image(img)

func _compass_texture() -> Texture2D:
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for a in 40:
		for b in 40:
			var rr := Vector2(a - 20, b - 20).length()
			if rr >= 5.0 and rr <= 15.0:
				img.set_pixel(a, b, Color(Color('#d9a05b'), 0.55))
			elif rr <= 3.0:
				img.set_pixel(a, b, AMBER)
	return ImageTexture.create_from_image(img)

func _turret_texture() -> Texture2D:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for px in 20:
		for py in 20:
			var d := Vector2(px - 10, py - 10).length()
			if d >= 8.0 and d <= 9.0 and px >= 10:
				img.set_pixel(px, py, Color(Color('#ffe0a3'), 0.9))
	return ImageTexture.create_from_image(img)

func _chamber_color(loaded: bool) -> Color:
	return AMBER_BRIGHT if loaded else Color(Color('#807866'), 0.5)

func _process(_delta: float) -> void:
	if not visible or not player:
		return
	var hull_frac := clampf(GAME.hull / maxf(GAME.max_hull, 1.0), 0.0, 1.0)
	if hull_frac != _last_hull:
		_last_hull = hull_frac
		_hull_fill.custom_minimum_size.x = 150.0 * hull_frac
		_hull_fill.modulate = Color(1, 0.5, 0.3) if GAME.hull < 30.0 else AMBER
	var cargo := floori(GAME.cargo)
	if cargo != _last_cargo:
		_last_cargo = cargo
		_cargo_val.text = '%04d' % cargo
	var amber := floori(GAME.inventory['amber'])
	if amber != _last_amber:
		_last_amber = amber
		_res_amber.text = '◉ %d' % amber
	var obsidian := floori(GAME.inventory['obsidian'])
	if obsidian != _last_obsidian:
		_last_obsidian = obsidian
		_res_obsidian.text = '◉ %d' % obsidian
	var prism := floori(GAME.inventory['prism'])
	if prism != _last_prism:
		_last_prism = prism
		_res_prism.text = '◉ %d' % prism
	var loaded := clampi(player.chamber, 0, GAME.MAX_CHAMBER)
	if loaded != _last_loaded:
		_last_loaded = loaded
		var cells := _chamber_row.get_children()
		for i in cells.size():
			cells[i].color = _chamber_color(i < loaded)
	var weapon: String = player.active_weapon
	if weapon != _last_weapon:
		_last_weapon = weapon
		_mode_icon.texture = ICONS_RES.fetch('auto' if weapon == 'turret' else 'cannon')
		_chamber_wrap.visible = weapon == 'cannon'
		_heat_wrap.visible = weapon == 'turret'
	if weapon == 'turret':
		var heat_frac := clampf(1.0 - GAME.heat / GAME.max_heat, 0.0, 1.0)
		if heat_frac != _last_heat:
			_last_heat = heat_frac
			_heat_fill.custom_minimum_size.x = 150.0 * heat_frac
			_heat_fill.modulate = Color(1, 0.7, 0.3) if player.overheated or GAME.heat / GAME.max_heat > 0.75 else AMBER
	if player.is_turret_aligned != _last_aligned:
		_last_aligned = player.is_turret_aligned
		_turret_status.modulate.a = 0.0 if player.is_turret_aligned else 0.8

	if player.reloading:
		var frac: float = player.reload_timer / maxf(GAME.reload_time, 0.001)
		var in_sweet: bool = frac >= GAME.sweet_start and frac <= GAME.sweet_end
		if fx:
			fx.set_reload(frac, in_sweet)
	elif fx:
		fx.hide_reload()

	var monolith: Node = null
	if world:
		var zz: Node = world.engaged_boss_zone()
		if zz:
			monolith = zz.monolith
	if monolith:
		var hf: float = monolith.health_frac()
		_target_dot.modulate = _dot_color(monolith, hf)
		_core_fill.custom_minimum_size.x = 150.0 * hf
	else:
		_target_dot.modulate = Color('#807866')
		_core_fill.custom_minimum_size.x = 0.0
	if monolith and monolith.is_active():
		_boss.visible = true
		_boss_code.text = monolith.code
		_boss_hp.custom_minimum_size.x = 180.0 * monolith.health_frac()
	else:
		_boss.visible = false

func _dot_color(monolith: Node, hf: float) -> Color:
	if world:
		var zz: Node = world.engaged_boss_zone()
		if zz == monolith.get_parent():
			return Color(1.0, 0.35, 0.2) if hf > 0.66 else Color(1.0, 0.75, 0.2)
	return Color('#d9a05b')

func set_compass(angle: float) -> void:
	_compass.rotation = deg_to_rad(angle)

func set_route_fill(frac: float) -> void:
	_route_fill.custom_minimum_size.x = 236.0 * frac

func set_target_dot(state: String) -> void:
	match state:
		'docked':
			_target_dot.modulate = Color(Color('#807866'), 0.3)
		'dormant':
			_target_dot.modulate = Color('#d9a05b')
		'engage':
			_target_dot.modulate = Color(1.0, 0.35, 0.2)
		'frag':
			_target_dot.modulate = Color(1.0, 0.75, 0.2)
		_:
			_target_dot.modulate = Color('#807866')

func set_dock_prompt(vis: bool) -> void:
	_dock_prompt.visible = vis

func set_corridor_warning(active: bool, frac: float) -> void:
	_zone_warning.visible = active
	if active:
		_zone_bar.custom_minimum_size.x = 256.0 * frac

func on_weapon_switch(weapon: String) -> void:
	set_target_dot('')
	_mode_icon.texture = ICONS_RES.fetch('auto' if weapon == 'turret' else 'cannon')

func set_mining_active(active: bool) -> void:
	_mining_hint.visible = active

func open_mining_circle(frac: float) -> void:
	if fx:
		fx.set_mining_arc(frac, true)
