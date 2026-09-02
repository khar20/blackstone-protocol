class_name Dialogue
extends CanvasLayer
## Typewriter dialogue overlay. Pages carry title + lines; the E key (or click)
## advances. Open/advance/close mirror openDialogue/dialogueAdvance/closeDialogue.

static var INTRO_PAGES: Array = [
	{ 'title': 'INCOMING TRANSMISSION · BRIDGES COMMAND', 'lines': [
		'PRIORITY // BLACKSTONE PROTOCOL',
		'',
		'Operator. The frontier went quiet three days ago.',
		'Your unit is the last one still answering.',
		'',
		'Run the corridor. Gateway Bastion still has your resupply;',
		'Ironhaven Depot holds what is left of the relay grid.'
	]},
	{ 'title': 'FIRST DIRECTIVE', 'lines': [
		'Before you roll out, harvest the crystal cluster',
		'marked beside this outpost. Hold F on it.',
		'',
		'Your harvester feeds cargo directly as credit.',
		'You will need every credit where you are going.'
	]}
]

static var UPGRADE_PAGES: Array = [
	{ 'title': 'OUTPOST TERMINAL · DOCKING GUIDE', 'lines': [
		'Cargo harvested converts to credit at this terminal.',
		'',
		'W / S select a row · ENTER purchase · E depart.',
		'Repair the hull first, then armor and autoloader.',
		'The road ahead does not forgive a broken tread.'
	]}
]

static var DELIVERY_PAGES: Array = [
	{ 'title': 'INCOMING TRANSMISSION · BRIDGES COMMAND', 'lines': [
		'Stay between the beacons.',
		'Outside that line, recovery teams will not follow.',
		'',
		'Two colossal signatures are parked on your route.',
		'Command classifies them as terrain now.',
		'Punch through — or detour and lose the light.',
		'',
		'Deliver the protocol. Come back driving.'
	]}
]

const CRT_RES = preload("res://scripts/ui/crt_overlay.gd")

var player: Node
var _pages: Array = []
var _page := 0
var _on_close: Callable
var _typing_chars := 0
var _type_timer := 0.0
var _panel: PanelContainer
var _title: Label
var _body: Label
var _hint: Label

func _ready() -> void:
	_build()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5; _panel.anchor_right = 0.5; _panel.anchor_top = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left = -360; _panel.offset_right = 360; _panel.offset_top = -160; _panel.offset_bottom = 50
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Color('#1a160f'), 0.92); sb.border_color = Color(Color('#d9a05b'), 0.65)
	sb.set_border_width_all(1); sb.corner_radius_top_left=6; sb.corner_radius_top_right=6; sb.corner_radius_bottom_left=6; sb.corner_radius_bottom_right=6
	sb.content_margin_left=16; sb.content_margin_right=16; sb.content_margin_top=14; sb.content_margin_bottom=14
	_panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 14)
	_title = Label.new(); _title.add_theme_font_size_override("font_size", 13); _title.add_theme_color_override("font_color", Color('#ffe0a3')); _title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body = Label.new(); _body.add_theme_font_size_override("font_size", 14); _body.add_theme_color_override("font_color", Color('#dcd5c5')); _body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _body.custom_minimum_size = Vector2(680, 130)
	_hint = Label.new(); _hint.add_theme_font_size_override("font_size", 11); _hint.add_theme_color_override("font_color", Color('#d9a05b')); _hint.text = "[ E ]  CONTINUAR  ·  CLICK"
	vb.add_child(_title); vb.add_child(_body); vb.add_child(_hint)
	_panel.add_child(vb)
	_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if visible and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			advance())
	add_child(_panel); CRT_RES.attach(_panel); visible = false

func open(pages: Array, on_close: Callable = Callable()) -> void:
	_pages = pages
	_page = 0
	_on_close = on_close
	if player:
		player.dialogue = true
	visible = true
	_type_page()

func _type_page() -> void:
	var pg: Dictionary = _pages[_page]
	_title.text = String(pg['title'])
	_body.text = ''
	_typing_chars = 0
	_type_timer = 0.0

func advance() -> void:
	var pg: Dictionary = _pages[_page]
	var full := String('\n'.join(pg['lines']))
	if _typing_chars < full.length():
		_body.text = full
		_typing_chars = full.length()
		return
	_page += 1
	if _page >= _pages.size():
		close()
	else:
		_type_page()

func close() -> void:
	if player:
		player.dialogue = false
	visible = false
	var cb: Callable = _on_close
	_on_close = Callable()
	if cb.is_valid():
		cb.call()

func _process(delta: float) -> void:
	if not visible:
		return
	var pg: Dictionary = _pages[_page]
	var full := String('\n'.join(pg['lines']))
	_type_timer += delta
	while _type_timer >= 0.016 and _typing_chars < full.length():
		_typing_chars += 2
		_type_timer -= 0.016
	if _typing_chars >= full.length():
		_hint.visible = true
	else:
		_hint.visible = false
	if _typing_chars > 0:
		_body.text = full.substr(0, _typing_chars)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			advance()
			get_viewport().set_input_as_handled()