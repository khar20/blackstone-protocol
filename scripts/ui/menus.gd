class_name Menus
extends CanvasLayer
## Title screen, pause menu, transient controls overlay, and shared flow:
## DEPLOY → intro dialogue → beginPlay; pause/resume; redeploy click on the
## center message. GAME.state drives what is visible; the world keeps running
## but player sim gates on state == 'PLAYING'.

const ICONS_RES = preload("res://scripts/ui/icons.gd")
const DIALOGUE_RES = preload("res://scripts/ui/dialogue.gd")
const CRT_RES = preload("res://scripts/ui/crt_overlay.gd")

var player: Node
var fx: Node
var hud: Node
var dialogue: Node
var garage: Node

var _title: PanelContainer
var _pause: PanelContainer
var _controls: PanelContainer
var _controls_pinned := false
var _controls_timer := 0.0

func _ready() -> void:
	_build()

func _build() -> void:
	_title = _menu_screen(_assign_title_START)
	_pause = _menu_screen(_assign_pause_START)
	_controls = _controls_screen()
	CRT_RES.attach(_title)
	CRT_RES.attach(_pause)
	CRT_RES.attach(_controls)
	_show_game(bool(GAME.state == 'PLAYING'))

func _menu_screen(content: Callable) -> PanelContainer:
	var sc := PanelContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Color('#0e0c0a'), 0.88); sb.content_margin_left=24; sb.content_margin_right=24
	sc.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 24)
	content.call(vb)
	sc.add_child(vb)
	add_child(sc)
	return sc

func _assign_title_START(vb: VBoxContainer) -> void:
	var em := TextureRect.new()
	em.texture = ICONS_RES.fetch('emblem')
	em.custom_minimum_size = Vector2(64, 64)
	em.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	vb.add_child(em)
	var t := Label.new()
	t.text = 'BLACKSTONE PROTOCOL'
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color('#ffe0a3'))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	nav.add_child(_menu_btn('DEPLOY', func() -> void: _on_deploy()))
	nav.add_child(_menu_btn('CONTROLS', func() -> void: _show_controls(true)))
	nav.add_child(_menu_btn('RESET', _reset_game))
	nav.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(nav)

func _assign_pause_START(vb: VBoxContainer) -> void:
	var t := Label.new()
	t.text = 'SYSTEM PAUSED'
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color('#ffe0a3'))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	nav.add_child(_menu_btn('RESUME', toggle_pause))
	nav.add_child(_menu_btn('CONTROLS', func() -> void: _show_controls(true)))
	nav.add_child(_menu_btn('ABORT', _open_title))
	nav.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(nav)

func _menu_btn(label: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.custom_minimum_size = Vector2(300, 42)
	b.pressed.connect(cb)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Color('#1a160f'), 0.9); style.border_color = Color('#d9a05b'); style.set_border_width_all(1)
	style.corner_radius_top_left=4; style.corner_radius_top_right=4; style.corner_radius_bottom_left=4; style.corner_radius_bottom_right=4
	style.content_margin_left=12; style.content_margin_right=12; style.content_margin_top=6; style.content_margin_bottom=6
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate(); hover.bg_color = Color(Color('#d9a05b'), 0.22); hover.border_color = Color('#ffe0a3')
	b.add_theme_stylebox_override("hover", hover)
	var press := style.duplicate(); press.bg_color = Color(Color('#d9a05b'), 0.35)
	b.add_theme_stylebox_override("pressed", press)
	return b

func _controls_screen() -> PanelContainer:
	var sc := PanelContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE)
	sc.anchor_top = 0.5
	sc.anchor_bottom = 0.5
	sc.offset_top = -180
	sc.offset_bottom = 180
	sc.offset_left = -300
	sc.offset_right = 300
	sc.visible = false
	sc.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	var t := Label.new()
	t.text = 'FIELD CONTROLS'
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", Color('#ffe0a3'))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var lines: Array = [
		['W / A / S / D', 'DRIVE · STEER'],
		['SPACE', 'DRIFT-BRAKE'],
		['MOUSE', 'LOOK · HOLD LMB FIRE · RMB OPTIC'],
		['E', 'DOCK / DEPART TERMINAL'],
		['F', 'HOLD TO MINE'],
		['R', 'RELOAD / SWEET-SPOT'],
		['V', 'TOGGLE VIEW'],
		['TAB / WHEEL', 'CYCLE WEAPON'],
		['ESC', 'PAUSE']
	]
	for pair in lines:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 12)
		var k := Label.new()
		k.text = pair[0]
		k.add_theme_font_size_override("font_size", 11)
		k.add_theme_color_override("font_color", Color('#d9a05b'))
		k.custom_minimum_size = Vector2(150, 0)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var d := Label.new()
		d.text = pair[1]
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_color_override("font_color", Color('#dcd5c5'))
		r.add_child(k)
		r.add_child(d)
		vb.add_child(r)
	sc.add_child(vb)
	add_child(sc)
	return sc

func _show_game(playing: bool) -> void:
	_title.visible = GAME.state == 'TITLE'
	_pause.visible = GAME.state == 'PAUSED'
	if hud:
		hud.visible = playing
	if not playing:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_initial() -> void:
	_show_game(GAME.state == 'PLAYING')

func _on_deploy() -> void:
	SFX.ui_blip()
	if dialogue:
		_title.visible = false
		dialogue.open(DIALOGUE_RES.INTRO_PAGES, begin_play)

func begin_play() -> void:
	if GAME.mission_phase == 'intro':
		GAME.mission_phase = 'mine'
	GAME.state = 'PLAYING'
	_show_controls(false)
	_show_game(true)

func toggle_pause() -> void:
	if GAME.state == 'PLAYING':
		GAME.state = 'PAUSED'
		SFX.panel_open()
	elif GAME.state == 'PAUSED':
		GAME.state = 'PLAYING'
		SFX.panel_close()
	_show_game(GAME.state == 'PLAYING')

func _open_title() -> void:
	GAME.state = 'TITLE'
	_show_controls(false)
	_show_game(false)

func _reset_game() -> void:
	_restart_world()

func _restart_world() -> void:
	GAME.reset_run()
	if player:
		player.reset_player()
	GAME.mission_phase = 'intro'
	GAME.mission_warn_timer = 0.0
	GAME.mission_was_outside = false
	GAME.compass_angle = 0.0
	if world:
		world.reset_world()
	_show_game(false)

var world: Node

func redeploy() -> void:
	if not player:
		return
	player.respawn_at_start()
	if fx:
		fx.hide_center_message()
	_show_game(true)

func _show_controls(pinned: bool) -> void:
	_controls_pinned = pinned
	_controls.visible = true
	if not pinned:
		_controls_timer = 8.0
	else:
		_controls_timer = 0.0

func _close_controls() -> void:
	_controls.visible = false
	_controls_pinned = false
	_controls_timer = 0.0

func _process(delta: float) -> void:
	if _controls_timer > 0.0:
		_controls_timer -= delta
		if not _controls_pinned and _controls_timer <= 0.0:
			_close_controls()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _controls.visible and not _controls_pinned:
			_close_controls()
			get_viewport().set_input_as_handled()
			return
		if _controls_pinned and event.keycode == KEY_ESCAPE:
			_close_controls()
			get_viewport().set_input_as_handled()
			return
		if GAME.state == 'TITLE':
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and _controls_pinned:
		_close_controls()
		get_viewport().set_input_as_handled()