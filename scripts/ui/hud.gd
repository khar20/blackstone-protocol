extends CanvasLayer
## HUD port: systems/hull bar, cargo + resource tally, weapon chamber/heat,
## compass + route bar, zone warning, boss readout, target dot, dock prompt,
## turret alignment. Separate panel nodes built in code; per-frame polling of
## GAME/player/world readouts (matches updateHUD()).

const AMBER := Color(0xd9a05b)
const AMBER_BRIGHT := Color(0xffe0a3)

const ICONS_RES = preload("res://scripts/ui/icons.gd")

var player: Node
var world: Node
var fx: Node

var _hull_fill: TextureRect
var _cargo_val: Label
var _res_amber: Label
var _res_obsidian: Label
var _res_prism: Label
var _chamber_row: HBoxContainer
var _chamber_wrap: Control
var _heat_fill: TextureRect
var _heat_wrap: Control
var _mode_icon: TextureRect
var _compass: TextureRect
var _route_fill: TextureRect
var _dock_prompt: Label
var _turret_status: TextureRect
var _zone_warning: PanelContainer
var _zone_bar: TextureRect
var _boss: PanelContainer
var _boss_code: Label
var _boss_hp: TextureRect
var _target_dot: TextureRect
var _core_fill: TextureRect
var _mining_hint: Label

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
	_build()

func _build() -> void:
	_add_hull()
	_add_cargo()
	_add_chamber()
	_add_nav()
	_add_target()
	_add_zone()
	_add_boss()

func _panel(at_anchor: Vector2, off: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = at_anchor.x
	p.anchor_right = at_anchor.x
	p.anchor_top = at_anchor.y
	p.anchor_bottom = at_anchor.y
	p.offset_left = off.x
	p.offset_right = off.x + 210
	p.offset_top = off.y
	p.offset_bottom = off.y + 46
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0x120f0a, 0.6)
	sb.border_color = Color(0xd9a05b, 0.4)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	return p

func _bar_texture() -> TextureRect:
	var tx := TextureRect.new()
	tx.custom_minimum_size = Vector2(150, 6)
	tx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tx.stretch_mode = TextureRect.STRETCH_SCALE
	tx.modulate = AMBER
	tx.texture = _white()
	return tx

func _white() -> Texture2D:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.WHITE)
	return ImageTexture.create_from_image(img)

func _add_hull() -> void:
	var p := _panel(Vector2(0.14, 0.12), Vector2(-400, 0))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	_hull_fill = _bar_texture()
	r.add_child(_hull_fill)
	p.add_child(r)

func _add_cargo() -> void:
	var p := _panel(Vector2(0.86, 0.12), Vector2(-210, 0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_cargo_val = _label('0000', 16, AMBER_BRIGHT)
	_cargo_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(_cargo_val)
	var res := HBoxContainer.new()
	res.add_theme_constant_override("separation", 10)
	_res_amber = _label('0', 11, _kind_color('amber'))
	_res_obsidian = _label('0', 11, _kind_color('obsidian'))
	_res_prism = _label('0', 11, _kind_color('prism'))
	res.add_child(_res_amber)
	res.add_child(_res_obsidian)
	res.add_child(_res_prism)
	vb.add_child(res)
	p.add_child(vb)

func _kind_color(kind: String) -> Color:	match kind:
		'amber': return Color(0xffe0a3)
		'obsidian': return Color(0xb0a8f0)
		_: return Color(0x9fd0ff)

func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _add_chamber() -> void:
	var p := _panel(Vector2(0.5, 0.13), Vector2(-105, 0))
	p.custom_minimum_size.y = 0
	p.offset_bottom = 0
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	_mode_icon = TextureRect.new()
	_mode_icon.texture = ICONS_RES.fetch('cannon')
	_mode_icon.custom_minimum_size = Vector2(18, 18)
	r.add_child(_mode_icon)
	_chamber_wrap = Control.new()
	_chamber_wrap.custom_minimum_size = Vector2(90, 18)
	_chamber_row = HBoxContainer.new()
	_chamber_row.add_theme_constant_override("separation", 3)
	_chamber_wrap.add_child(_chamber_row)
	for i in GAME.MAX_CHAMBER:
		var c := ColorRect.new()
		c.custom_minimum_size = Vector2(14, 14)
		c.color = _chamber_color(false)
		_chamber_row.add_child(c)
	r.add_child(_chamber_wrap)
	_heat_wrap = Control.new()
	_heat_wrap.visible = false
	var hv := VBoxContainer.new()
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	_heat_fill = _bar_texture()
	_heat_fill.custom_minimum_size = Vector2(110, 6)
	hv.add_child(_heat_fill)
	_heat_wrap.add_child(hv)
	_heat_wrap.custom_minimum_size = Vector2(110, 18)
	r.add_child(_heat_wrap)
	p.add_child(r)

func _chamber_color(loaded: bool) -> Color:
	return AMBER_BRIGHT if loaded else Color(0x807866, 0.5)

func _add_nav() -> void:
	_compass = TextureRect.new()
	_compass.anchor_left = 0.5
	_compass.anchor_top = 0.5
	_compass.offset_left = -20
	_compass.offset_top = -20
	_compass.offset_right = 20
	_compass.offset_bottom = 20
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var amber := Color(0xd9a05b)
	for a in 40:
		for b in 40:
			var d := Vector2(a - 20, b - 20)
			var rr := d.length()
			if rr >= 5.0 and rr <= 15.0:
				img.set_pixel(a, b, Color(0xd9a05b, 0.55))
			elif rr <= 3.0:
				img.set_pixel(a, b, amber)
	_compass.texture = ImageTexture.create_from_image(img)
	_compass.pivot_offset = Vector2(20, 20)
	add_child(_compass)

	var route := PanelContainer.new()
	route.anchor_left = 0.5
	route.anchor_top = 0.5
	route.offset_left = -120
	route.offset_top = 24
	route.offset_right = 120
	route.offset_bottom = 32
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0x000000, 0.5)
	route.add_theme_stylebox_override("panel", sb)
	_route_fill = TextureRect.new()
	_route_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_route_fill.stretch_mode = TextureRect.STRETCH_SCALE
	_route_fill.modulate = AMBER
	_route_fill.texture = _white()
	_route_fill.custom_minimum_size = Vector2(0, 4)
	_route_fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.add_child(_route_fill)
	route.add_child(row)
	add_child(route)

	_dock_prompt = _label('[ E ] DOCK', 12, AMBER_BRIGHT)
	_dock_prompt.anchor_left = 0.5
	_dock_prompt.anchor_top = 0.5
	_dock_prompt.offset_left = -60
	_dock_prompt.offset_top = 44
	_dock_prompt.offset_right = 60
	_dock_prompt.offset_bottom = 100
	_dock_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_prompt.visible = false
	add_child(_dock_prompt)

	_turret_status = TextureRect.new()
	_turret_status.anchor_left = 0.5
	_turret_status.anchor_top = 0.5
	_turret_status.offset_left = -14
	_turret_status.offset_top = 60
	_turret_status.offset_right = 14
	_turret_status.offset_bottom = 76
	var timg := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	timg.fill(Color(0, 0, 0, 0))
	for px in 20:
		for py in 20:
			var d := Vector2(px - 10, py - 10).length()
			if d >= 8.0 and d <= 9.0 and px >= 10:
				timg.set_pixel(px, py, Color(0xffe0a3, 0.9))
	_turret_status.texture = ImageTexture.create_from_image(timg)
	_turret_status.modulate.a = 0.0
	add_child(_turret_status)

	_mining_hint = _label('MINING', 11, AMBER_BRIGHT)
	_mining_hint.anchor_left = 0.5
	_mining_hint.anchor_top = 0.5
	_mining_hint.offset_left = -60
	_mining_hint.offset_top = 116
	_mining_hint.offset_right = 60
	_mining_hint.offset_bottom = 180
	_mining_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mining_hint.visible = false
	add_child(_mining_hint)

func _add_target() -> void:
	var p := _panel(Vector2(0.5, 0.9), Vector2(-105, -46))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	var dot := TextureRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.texture = _white()
	_target_dot = dot
	r.add_child(dot)
	_core_fill = _bar_texture()
	_core_fill.modulate = Color(0xffe0a3)
	_core_fill.custom_minimum_size = Vector2(150, 6)
	r.add_child(_core_fill)
	p.add_child(r)

func _add_zone() -> void:
	_zone_warning = PanelContainer.new()
	_zone_warning.anchor_left = 0.5
	_zone_warning.anchor_top = 0.5
	_zone_warning.offset_left = -130
	_zone_warning.offset_right = 130
	_zone_warning.offset_top = -130
	_zone_warning.offset_bottom = -80
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0x280a0a, 0.8)
	sb.border_color = Color(0xd8a05b)
	sb.set_border_width_all(1)
	_zone_warning.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	var l := _label('OUTSIDE MISSION ZONE', 12, Color(0xffb0a0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	_zone_bar = TextureRect.new()
	_zone_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_zone_bar.stretch_mode = TextureRect.STRETCH_SCALE
	_zone_bar.modulate = Color(0xff8070)
	_zone_bar.texture = _white()
	_zone_bar.custom_minimum_size = Vector2(0, 4)
	_zone_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.add_child(_zone_bar)
	vb.add_child(row)
	_zone_warning.add_child(vb)
	_zone_warning.visible = false
	add_child(_zone_warning)

func _add_boss() -> void:
	_boss = PanelContainer.new()
	_boss.anchor_left = 0.5
	_boss.anchor_right = 0.5
	_boss.anchor_top = 0.12
	_boss.anchor_bottom = 0.12
	_boss.offset_left = -160
	_boss.offset_right = 160
	_boss.offset_top = 0
	_boss.offset_bottom = 30
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0x120f0a, 0.7)
	sb.border_color = Color(0xd9a05b, 0.6)
	sb.set_border_width_all(1)
	_boss.add_theme_stylebox_override("panel", sb)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	_boss_code = _label('---', 11, Color(0xffe0a3))
	r.add_child(_boss_code)
	_boss_hp = _bar_texture()
	_boss_hp.modulate = Color(0xffe0a3)
	_boss_hp.custom_minimum_size = Vector2(180, 6)
	r.add_child(_boss_hp)
	_boss.add_child(r)
	_boss.visible = false
	add_child(_boss)

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
		_res_amber.text = str(amber)
	var obsidian := floori(GAME.inventory['obsidian'])
	if obsidian != _last_obsidian:
		_last_obsidian = obsidian
		_res_obsidian.text = str(obsidian)
	var prism := floori(GAME.inventory['prism'])
	if prism != _last_prism:
		_last_prism = prism
		_res_prism.text = str(prism)
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
		_target_dot.modulate = Color(0x807866)
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
	return Color(0xd9a05b)

func set_compass(angle: float) -> void:
	_compass.rotation = deg_to_rad(angle)

func set_route_fill(frac: float) -> void:
	_route_fill.custom_minimum_size.x = 236.0 * frac

func set_target_dot(state: String) -> void:
	match state:
		'docked':
			_target_dot.modulate = Color(0x807866, 0.3)
		'dormant':
			_target_dot.modulate = Color(0xd9a05b)
		'engage':
			_target_dot.modulate = Color(1.0, 0.35, 0.2)
		'frag':
			_target_dot.modulate = Color(1.0, 0.75, 0.2)
		_:
			_target_dot.modulate = Color(0x807866)

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