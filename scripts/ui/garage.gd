class_name Garage
extends CanvasLayer
## Outpost terminal panel. buildGarageItems / renderGarage / garageMove /
## garageConfirm / openGarage / closeGarage port. AUTO-CANNON stores a level
## with no gameplay effect (verbatim source quirk).

## outpost terminal panel ...

const ICONS_RES = preload("res://scripts/ui/icons.gd")
const CRT_RES = preload("res://scripts/ui/crt_overlay.gd")

var player: Node
var hud: Node
var fx: Node
var dialogue: Node
var world: Node

var _panel: PanelContainer
var _title: Label
var _cargo: Label
var _rows: VBoxContainer
var _items: Array = []
var _index := 0

func _ready() -> void:
	_build()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5; _panel.anchor_right = 0.5; _panel.anchor_top = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left = -280; _panel.offset_right = 280; _panel.offset_top = -250; _panel.offset_bottom = 250
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Color('#1a160f'), 0.92); sb.border_color = Color(Color('#d9a05b'), 0.7)
	sb.set_border_width_all(1); sb.corner_radius_top_left=6; sb.corner_radius_top_right=6; sb.corner_radius_bottom_left=6; sb.corner_radius_bottom_right=6
	sb.content_margin_left=14; sb.content_margin_right=14; sb.content_margin_top=12; sb.content_margin_bottom=12
	_panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 10)
	_title = Label.new(); _title.add_theme_font_size_override("font_size", 15); _title.add_theme_color_override("font_color", Color('#ffe0a3')); _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cargo = Label.new(); _cargo.add_theme_font_size_override("font_size", 14); _cargo.add_theme_color_override("font_color", Color('#ffe0a3')); _cargo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows = VBoxContainer.new(); _rows.add_theme_constant_override("separation", 2)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(500, 380); scroll.add_child(_rows)
	vb.add_child(_title); vb.add_child(_cargo); vb.add_child(scroll)
	_panel.add_child(vb); add_child(_panel); CRT_RES.attach(_panel); visible = false

func open(_from_mission: bool = false) -> void:
	if not player:
		return
	player.in_panel = true
	player.vel = Vector3.ZERO
	_input_backup_mouse()
	visible = true
	if hud:
		hud.set_target_dot('docked')
	if world and world.near_settlement:
		_title.text = world.near_settlement.name
	_items = _build_items()
	_index = 0
	_render()

func close() -> void:
	if not player:
		return
	player.in_panel = false
	visible = false
	if GAME.state == 'PLAYING':
		if GAME.mission_phase == 'upgrades':
			GAME.mission_phase = 'delivery_brief'
			if fx:
				fx.open_upgrades_dialogue()
		_restore_mouse()
	SFX.panel_close()

func _input_backup_mouse() -> void:
	_mouse_backup = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _restore_mouse() -> void:
	Input.mouse_mode = _mouse_backup

var _mouse_backup := Input.MOUSE_MODE_CAPTURED

func _cost(level: int, base: float) -> int:
	return roundi(base * (1.0 + level * 1.4))

func _build_items() -> Array:
	var items: Array = []
	items.append({
		'icon': 'wrench', 'title': 'REPAIR HULL %d%%' % roundi(GAME.hull / GAME.max_hull * 100.0),
		'cost': roundi((GAME.max_hull - GAME.hull) * 2.0), 'disabled': GAME.hull >= GAME.max_hull,
		'action': func() -> void: GAME.hull = GAME.max_hull
	})
	items.append({
		'icon': 'shell', 'title': 'RESTOCK AMMO',
		'cost': (GAME.MAX_CHAMBER - player.chamber) * 12, 'disabled': player.chamber >= GAME.MAX_CHAMBER,
		'action': func() -> void: player.chamber = GAME.MAX_CHAMBER
	})
	items.append(_upgrade('cannon', 'CANNON DMG', 60))
	items.append(_upgrade('armor', 'ARMOR PLATING', 55, true, true))
	items.append(_upgrade('arc', 'TRAVERSE SLEW', 65))
	items.append(_upgrade('turret', 'AUTO-CANNON', 55))
	items.append(_upgrade('cooling', 'COOLING', 50))
	items.append(_upgrade('drift', 'DRIFT THRUSTERS', 50))
	items.append(_upgrade('reload', 'AUTOLOADER', 50))
	items.append(_upgrade('mining', 'MINING YIELD', 45))
	items.append({ 'icon': 'exit', 'title': 'DEPART DOCK', 'cost': -1, 'disabled': false,
		'action': func() -> void: close() })
	return items

func _upgrade(field: String, label: String, base: float, refill_hull: bool = false, refill_on_purchase: bool = false) -> Dictionary:
	var lvl := _level(field)
	return {
		'icon': _icon_for(field), 'title': label, 'pips': lvl,
		'cost': _cost(lvl, base), 'disabled': lvl >= 5,
		'field': field, 'base': base, 'refill_hull': refill_hull or refill_on_purchase
	}

func _level(field: String) -> int:
	match field:
		'cannon': return GAME.cannon_level
		'armor': return GAME.armor_level
		'arc': return GAME.arc_level
		'turret': return GAME.turret_level
		'cooling': return GAME.cooling_level
		'drift': return GAME.drift_level
		'reload': return GAME.reload_level
		'mining': return GAME.mining_level
	return 0

func _icon_for(field: String) -> String:
	match field:
		'cannon': return 'cannon'
		'armor': return 'shield'
		'arc': return 'arc'
		'turret': return 'auto'
		'cooling': return 'snow'
		'drift': return 'thrust'
		'reload': return 'cycle'
		'mining': return 'crystal'
	return 'crystal'

func _purchase(item: Dictionary) -> void:
	var field: String = item.get('field', '')
	if field != '':
		match field:
			'cannon': GAME.cannon_level += 1
			'armor': GAME.armor_level += 1
			'arc': GAME.arc_level += 1
			'turret': GAME.turret_level += 1
			'cooling': GAME.cooling_level += 1
			'drift': GAME.drift_level += 1
			'reload': GAME.reload_level += 1
			'mining': GAME.mining_level += 1
		GAME.recompute_stats()
		if item.get('refill_hull', false):
			GAME.hull = GAME.max_hull
	elif item['icon'] == 'wrench':
		GAME.hull = GAME.max_hull
	elif item['icon'] == 'shell':
		player.chamber = GAME.MAX_CHAMBER

func _render() -> void:
	_cargo.text = '%04d CR' % floori(GAME.cargo)
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	for i in _items.size():
		var it: Dictionary = _items[i]
		var row := _make_row(it, i == _index)
		_rows.add_child(row)

func _make_row(it: Dictionary, selected: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var ic := TextureRect.new()
	ic.texture = ICONS_RES.fetch(it['icon'])
	ic.custom_minimum_size = Vector2(18, 18)
	row.add_child(ic)
	var lbl := Label.new()
	lbl.text = it['title']
	lbl.add_theme_font_size_override("font_size", 12)
	if it['disabled']:
		lbl.add_theme_color_override("font_color", Color('#807866'))
	else:
		lbl.add_theme_color_override("font_color", Color('#dcd5c5'))
	lbl.custom_minimum_size = Vector2(220, 0)
	row.add_child(lbl)
	# ponytail: pips visibles sin libreria; usa texto para evitar nodos extra
	if it.has('pips'):
		var pips := Label.new()
		var lvl: int = int(it['pips'])
		pips.text = "●".repeat(lvl) + "○".repeat(5 - lvl)
		pips.add_theme_font_size_override("font_size", 10)
		pips.add_theme_color_override("font_color", Color('#d9a05b') if not it['disabled'] else Color(Color('#807866'), 0.6))
		pips.custom_minimum_size = Vector2(50, 0)
		row.add_child(pips)
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(50, 0)
		row.add_child(spacer)
	var cost := Label.new()
	cost.add_theme_font_size_override("font_size", 11)
	if int(it['cost']) < 0:
		cost.text = ''
	elif it['disabled']:
		cost.text = 'MAXED'
		cost.add_theme_color_override("font_color", Color('#807866'))
	else:
		cost.text = '%d CR' % int(it['cost'])
		cost.add_theme_color_override("font_color", Color('#d9a05b'))
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.custom_minimum_size = Vector2(90, 0)
	row.add_child(cost)
	if selected:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Color('#d9a05b'), 0.18)
		sb.border_color = Color('#d9a05b')
		sb.set_border_width_all(1)
		row.add_theme_stylebox_override("panel", sb)
	return row

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W:
				_move(-1)
				get_viewport().set_input_as_handled()
			KEY_S:
				_move(1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				_confirm()
				get_viewport().set_input_as_handled()
			KEY_E, KEY_ESCAPE:
				close()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_move(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move(1)

func _move(dir: int) -> void:
	_index = (_index + dir + _items.size()) % _items.size()
	SFX.ui_move()
	_render()

func _confirm() -> void:
	if _index >= _items.size():
		return
	var it: Dictionary = _items[_index]
	if String(it['title']) == 'DEPART DOCK':
		close()
		return
	if it['disabled']:
		SFX.unaffordable()
		return
	if int(it['cost']) < 0:
		return
	if GAME.cargo < float(it['cost']):
		SFX.unaffordable()
		return
	GAME.cargo -= float(it['cost'])
	_purchase(it)
	SFX.ui_blip()
	_items = _build_items()
	_render()