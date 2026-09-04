extends CanvasLayer
## Non-HUD screen effects: mission banner, center message overlay (with click
## handler), damage flash, hitmarker, and the dual reticle (cannon ballistic
## impact circle + turret crosshair + reload/mining rings).

const AMBER := Color('#d9a05b')
const AMBER_BRIGHT := Color('#ffe0a3')
const BEIGE := Color('#dcd5c5')

const DIALOGUE_RES = preload("res://scripts/ui/dialogue.gd")

var player: Node
var camera: Camera3D
var dialogue: Node
var garage: Node
var menus: Node

var _banner: Label
var _banner_timer := 0.0
var _flash: ColorRect
var _flash_t := 0.0
var _hitmarker: TextureRect
var _hit_t := 0.0
var _reticle: Control
var _reload_frac := -1.0
var _in_sweet := false
var _mining_frac := 0.0
var _cannon_circle: TextureRect
var _center_box: PanelContainer
@onready var _center_title: Label = $CenterBox/VB/Title
@onready var _center_sub: Label = $CenterBox/VB/Sub
@onready var _center_hint: Label = $CenterBox/VB/Hint

func _ready() -> void:
	_banner = $Banner
	_flash = $Flash
	_hitmarker = $Hitmarker
	_reticle = $Reticle
	_cannon_circle = $CannonCircle
	_center_box = $CenterBox
	_hitmarker.texture = _cross_texture()
	_cannon_circle.texture = _ring_texture()
	$Reticle.draw.connect(func() -> void: _draw_reticle($Reticle))
	$CenterBox.gui_input.connect(func(ev: InputEvent) -> void:
		if _center_box.visible and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if menus:
				menus.redeploy())

func _cross_texture() -> Texture2D:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 5:
		img.set_pixel(7, 1 + i * 2, AMBER_BRIGHT)
	img.set_pixel(7, 7, AMBER_BRIGHT)
	for i in 5:
		img.set_pixel(1 + i * 2, 7, AMBER_BRIGHT)
	return ImageTexture.create_from_image(img)

func _ring_texture() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 32:
		for x in 32:
			var d := Vector2(x - 16, y - 16).length()
			if d >= 12.0 and d <= 15.0:
				img.set_pixel(x, y, Color(Color('#ffe0a3'), 0.8))
	return ImageTexture.create_from_image(img)

func _draw_reticle(r: Control) -> void:
	var c := Vector2(22, 22)
	var tl := 6.0
	r.draw_line(c + Vector2(-5, -tl), c + Vector2(-5, -2), AMBER, 2.0)
	r.draw_line(c + Vector2(5, -tl), c + Vector2(5, -2), AMBER, 2.0)
	r.draw_line(c + Vector2(-5, tl), c + Vector2(-5, 2), AMBER, 2.0)
	r.draw_line(c + Vector2(5, tl), c + Vector2(5, 2), AMBER, 2.0)
	r.draw_line(c + Vector2(-tl, -5), c + Vector2(-2, -5), AMBER, 2.0)
	r.draw_line(c + Vector2(-tl, 5), c + Vector2(-2, 5), AMBER, 2.0)
	r.draw_line(c + Vector2(tl, -5), c + Vector2(2, -5), AMBER, 2.0)
	r.draw_line(c + Vector2(tl, 5), c + Vector2(2, 5), AMBER, 2.0)
	r.draw_circle(c, 2.0, AMBER_BRIGHT)
	if _reload_frac >= 0.0 and not _in_sweet:
		r.draw_arc(c, 19, -PI / 2, -PI / 2 + TAU * _reload_frac, 48, AMBER, 3.0)
	elif _reload_frac >= 0.0:
		r.draw_arc(c, 19, -PI / 2, -PI / 2 + TAU * _reload_frac, 48, AMBER_BRIGHT, 3.0)
	if _mining_frac > 0.0:
		r.draw_arc(c, 20, -PI / 2, -PI / 2 + TAU * _mining_frac, 48, AMBER_BRIGHT, 3.0)

func show_banner(text: String) -> void:
	_banner.text = text
	_banner_timer = 2.0
	_banner.modulate.a = 1.0

func flash() -> void:
	_flash.color.a = 0.3
	_flash_t = 0.001

func show_hitmarker() -> void:
	_hit_t = 0.001
	_hitmarker.modulate.a = 1.0

func show_center_message(title: String, sub: String, hint: String) -> void:
	_center_title.text = title
	_center_sub.text = sub
	_center_hint.text = hint
	_center_box.visible = true

func hide_center_message() -> void:
	_center_box.visible = false

func recoil(mag: float) -> void:
	if camera:
		camera.recoil(mag)

func toggle_view() -> void:
	if camera:
		camera.toggle_view()

func toggle_pause() -> void:
	if menus:
		menus.toggle_pause()

func close_panel() -> void:
	if garage:
		garage.close()

func open_upgrades_dialogue() -> void:
	if dialogue:
		dialogue.open(DIALOGUE_RES.UPGRADE_PAGES, null)

func update(dt: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= dt
		_banner.modulate.a = minf(1.0, _banner_timer) if _banner_timer < 1.0 else 1.0
		if _banner_timer <= 0.0:
			_banner.modulate.a = 0.0
	if _flash.color.a > 0.0:
		_flash_t -= dt
		if _flash_t <= 0.0:
			_flash.color.a -= dt * 1.2
			_flash.color.a = maxf(0.0, _flash.color.a)
	if _hitmarker.modulate.a > 0.0:
		_hit_t -= dt
		if _hit_t <= 0.0:
			_hitmarker.modulate.a -= dt * 4.5
			_hitmarker.modulate.a = maxf(0.0, _hitmarker.modulate.a)

	if player and player.alive and GAME.state == 'PLAYING' and player.active_weapon == 'cannon' and camera:
		var muzzle: Vector3 = player.tank.barrel_tip.global_position
		var impact: Vector3 = muzzle + player.tank.gun_pitch.global_transform.basis.z * 200.0
		var pp: Vector2 = camera.unproject_position(impact)
		_cannon_circle.position = pp - Vector2(16, 16)
		var to_impact := impact - camera.global_position
		_cannon_circle.visible = to_impact.dot(-camera.global_transform.basis.z) > 0.0
	else:
		_cannon_circle.visible = false

func set_reload(frac: float, in_sweet: bool) -> void:
	_reload_frac = frac
	_in_sweet = in_sweet
	_reticle.queue_redraw()

func hide_reload() -> void:
	if _reload_frac < 0.0:
		return
	_reload_frac = -1.0
	_reticle.queue_redraw()

func set_mining_arc(frac: float, active: bool) -> void:
	var f := frac if active else 0.0
	if f == _mining_frac:
		return
	_mining_frac = f
	_reticle.queue_redraw()

func _process(delta: float) -> void:
	update(delta)
