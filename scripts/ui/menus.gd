class_name Menus
extends CanvasLayer
## Title screen, pause menu, transient controls overlay, and shared flow:
## DEPLOY → intro dialogue → beginPlay; pause/resume; redeploy click on the
## center message. Node tree lives in scenes/ui/menus.tscn; script wires buttons
## and drives GAME.state/visibility.

const ICONS_RES = preload("res://scripts/ui/icons.gd")
const DIALOGUE_RES = preload("res://scripts/ui/dialogue.gd")
const CRT_RES = preload("res://scripts/ui/crt_overlay.gd")

var player: Node
var fx: Node
var hud: Node
var dialogue: Node
var garage: Node

@onready var _title: PanelContainer = $Title
@onready var _pause: PanelContainer = $Pause
@onready var _controls: PanelContainer = $Controls
var _controls_pinned := false
var _controls_timer := 0.0

func _ready() -> void:
	($Title/VB/Emblem as TextureRect).texture = ICONS_RES.fetch('emblem')
	connect_menu_signals()
	CRT_RES.attach(_title)
	CRT_RES.attach(_pause)
	CRT_RES.attach(_controls)
	_show_game(bool(GAME.state == 'PLAYING'))

func connect_menu_signals() -> void:
	($Title/VB/Nav/DeployBtn as Button).pressed.connect(_on_deploy)
	($Title/VB/Nav/ControlsBtn as Button).pressed.connect(func() -> void: _show_controls(true))
	($Title/VB/Nav/ResetBtn as Button).pressed.connect(_reset_game)
	($Pause/VB/Nav/ResumeBtn as Button).pressed.connect(toggle_pause)
	($Pause/VB/Nav/ControlsBtn as Button).pressed.connect(func() -> void: _show_controls(true))
	($Pause/VB/Nav/AbortBtn as Button).pressed.connect(_open_title)

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
