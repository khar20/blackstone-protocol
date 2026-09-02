extends Node
## Main scene controller: capas separadas en main.tscn (World/Player/Camera/Mission + UI).
## Ya no crea nodos con .new(); los recoge por $ y solo cablea dependencias.
## ponytail: wiring explicito es deuda minima; escena hace el trabajo pesado.

var world: Node
var player: Node
var camera: Node
var mission: Node
var effects: Node
var hud: Node
var dialogue: Node
var garage: Node
var menus: Node
var _loading: CanvasLayer
var _load_start := 0

func _ready() -> void:
	world = $World
	player = $Player
	camera = $Camera
	mission = $Mission
	effects = $Effects
	hud = $HUD
	garage = $Garage
	menus = $Menus
	dialogue = $Dialogue
	_wire()
	_build_loading()
	# ponytail: conectar a terrain_ready para ocultar loading sin polling
	if world and world.has_node("Terrain"):
		var tl = world.get_node("Terrain")
		if tl._built:
			_hide_loading()
		elif tl.has_signal("terrain_ready"):
			tl.terrain_ready.connect(_hide_loading)
		else:
			get_tree().create_timer(0.5).timeout.connect(_hide_loading)
	menus.show_initial()

func _build_loading() -> void:
	_loading = CanvasLayer.new()
	_loading.layer = 15 # por debajo de Menus(20)/Dialogue(21) para no tapar menu
	_loading.name = "LoadingOverlay"
	var bg := ColorRect.new()
	bg.color = Color(Color('#0e0c0a'), 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading.add_child(bg)
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = "GENERANDO TERRENO · 0%"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color('#ffe0a3'))
	_loading.add_child(lbl)
	add_child(_loading)
	# si estamos en TITLE, el menu tapa el loading; ocultarlo hasta PLAYING
	if GAME.state == 'TITLE':
		_loading.visible = false
	set_process(true)

func _process(_delta: float) -> void:
	# mostrar loading solo en PLAYING o cuando terreno aun no listo y no hay menu
	if _loading:
		_loading.visible = GAME.state == 'PLAYING' or not (menus and menus._title.visible)
		if world and world.has_node("Terrain"):
			var tl = world.get_node("Terrain")
			if tl and not tl._built and _loading.visible:
				var lbl = _loading.get_node_or_null("Label")
				if lbl:
					if _load_start == 0:
						_load_start = Time.get_ticks_msec()
					var est := clampf(float(Time.get_ticks_msec() - _load_start) / 2400.0, 0.0, 0.95)
					lbl.text = "GENERANDO TERRENO · %d%%" % int(est*100)
	# delegar a camera/mission tambien
	if camera and player:
		camera.update_camera(_delta)
	if mission:
		mission.update(_delta)

func _hide_loading() -> void:
	if _loading:
		_loading.queue_free()
		_loading = null

func _wire() -> void:
	world.player = player
	world.fx = effects
	world.hud = hud
	player.world = world
	player.camera = camera
	player.fx = effects
	player.hud = hud
	player.garage = garage
	camera.player = player
	camera.world = world
	mission.player = player
	mission.world = world
	mission.hud = hud
	mission.fx = effects
	mission.garage = garage
	effects.player = player
	effects.camera = camera
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
	garage.world = world
	menus.player = player
	menus.fx = effects
	menus.hud = hud
	menus.dialogue = dialogue
	menus.garage = garage
	menus.world = world
