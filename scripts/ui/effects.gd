extends CanvasLayer
## Non-HUD screen effects: mission banner, center message overlay (with click
## handler), damage flash, hitmarker, and the dual reticle (cannon ballistic
## impact circle + turret crosshair + reload/mining rings).

const AMBER := Color(0xd9a05b)
const AMBER_BRIGHT := Color(0xffe0a3)
const BEIGE := Color(0xdcd5c5)

const DIALOGUE_RES = preload("res://scripts/ui/dialogue.gd")

var player: Node
var camera: Camera3D
var world: Node
var hud: Node
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
var _cannon_circle: Control
var _center_box: PanelContainer
var _center_title: Label
var _center_sub: Label
var _center_hint: Label

func _ready() -> void:
	_build()

func _build() -> void:
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 16)
	_banner.add_theme_color_override("font_color", AMBER_BRIGHT)
	_banner.add_theme_constant_override("outline_size", 4)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_banner.modulate.a = 0.0
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.5
	_banner.anchor_bottom = 0.5
	_banner.offset_left = -300
	_banner.offset_right = 300
	_banner.offset_top = -140
	_banner.offset_bottom = -110
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_banner)

	_flash = ColorRect.new()
	_flash.anchor_right = 1.0
	_flash.anchor_bottom = 1.0
	_flash.color = Color(1, 0.9, 0.7, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_hitmarker = _make_cross()
	add_child(_hitmarker)

	_reticle = _make_reticle()
	add_child(_reticle)
	_cannon_circle = _make_ring()
	add_child(_cannon_circle)

	_center_box = PanelContainer.new()
	_center_box.anchor_left = 0.5
	_center_box.anchor_right = 0.5
	_center_box.anchor_top = 0.5
	_center_box.anchor_bottom = 0.5
	_center_box.offset_left = -220
	_center_box.offset_right = 220
	_center_box.offset_top = -90
	_center_box.offset_bottom = 10
	_center_box.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_center_title = Label.new()
	_center_title.add_theme_font_size_override("font_size", 18)
	_center_title.add_theme_color_override("font_color", AMBER_BRIGHT)
	_center_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_sub = Label.new()
	_center_sub.add_theme_font_size_override("font_size", 12)
	_center_sub.add_theme_color_override("font_color", BEIGE)
	_center_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_hint = Label.new()
	_center_hint.add_theme_font_size_override("font_size", 10)
	_center_hint.add_theme_color_override("font_color", AMBER)
	_center_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_center_title)
	vb.add_child(_center_sub)
	vb.add_child(_center_hint)
	_center_box.add_child(vb)
	add_child(_center_box)
	_center_box.gui_input.connect(func(ev: InputEvent) -> void:
		if _center_box.visible and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if menus:
				menus.redeploy())

func _make_cross() -> TextureRect:
	var tx := TextureRect.new()
	tx.anchor_left = 0.5
	tx.anchor_right = 0.5
	tx.anchor_top = 0.5
	tx.anchor_bottom = 0.5
	tx.offset_left = -7
	tx.offset_right = 7
	tx.offset_top = -7
	tx.offset_bottom = 7
	tx.modulate.a = 0.0
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 5:
		img.set_pixel(7, 1 + i * 2, AMBER_BRIGHT)
	img.set_pixel(7, 7, AMBER_BRIGHT)
	for i in 5:
		img.set_pixel(1 + i * 2, 7, AMBER_BRIGHT)
	tx.texture = ImageTexture.create_from_image(img)
	return tx

func _make_reticle() -> Control:
	var r := Control.new()
	r.anchor_left = 0.5
	r.anchor_right = 0.5
	r.anchor_top = 0.5
	r.anchor_bottom = 0.5
	r.offset_left = -22
	r.offset_right = 22
	r.offset_top = -22
	r.offset_bottom = 22
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.draw.connect(func() -> void: _draw_reticle(r))
	return r

func _make_ring() -> TextureRect:
	var tx := TextureRect.new()
	tx.offset_left = -16
	tx.offset_right = 16
	tx.offset_top = -16
	tx.offset_bottom = 16
	tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 32:
		for x in 32:
			var d := Vector2(x - 16, y - 16).length()
			if d >= 12.0 and d <= 15.0:
				img.set_pixel(x, y, Color(0xffe0a3, 0.8))
	tx.texture = ImageTexture.create_from_image(img)
	return tx

func _draw_reticle(r: Control) -> void:
	var c := Vector2(22, 22)
	var tl := 5.0
	r.draw_line(c + Vector2(-5, -tl), c + Vector2(-5, -2), AMBER, 1.5)
	r.draw_line(c + Vector2(5, -tl), c + Vector2(5, -2), AMBER, 1.5)
	r.draw_line(c + Vector2(-5, tl), c + Vector2(-5, 2), AMBER, 1.5)
	r.draw_line(c + Vector2(5, tl), c + Vector2(5, 2), AMBER, 1.5)
	r.draw_line(c + Vector2(-tl, -5), c + Vector2(-2, -5), AMBER, 1.5)
	r.draw_line(c + Vector2(-tl, 5), c + Vector2(-2, 5), AMBER, 1.5)
	r.draw_line(c + Vector2(tl, -5), c + Vector2(2, -5), AMBER, 1.5)
	r.draw_line(c + Vector2(tl, 5), c + Vector2(2, 5), AMBER, 1.5)
	r.draw_circle(c, 1.5, AMBER_BRIGHT)
	if _reload_frac >= 0.0 and not _in_sweet:
		r.draw_arc(c, 19, -PI / 2, -PI / 2 + TAU * _reload_frac, 48, AMBER, 2.5)
	elif _reload_frac >= 0.0:
		r.draw_arc(c, 19, -PI / 2, -PI / 2 + TAU * _reload_frac, 48, AMBER_BRIGHT, 2.5)
	if _mining_frac > 0.0:
		r.draw_arc(c, 20, -PI / 2, -PI / 2 + TAU * _mining_frac, 48, AMBER_BRIGHT, 2.5)

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

const SHELL_SPEED := 98.0
const GRAVITY := 19.6

func _ballistic_impact() -> Vector3:
	if not player:
		return Vector3.ZERO
	var muzzle: Vector3 = player.tank.barrel_tip.global_position
	var pos := muzzle
	var vel: Vector3 = -player.tank.gun_pitch.global_transform.basis.z * SHELL_SPEED
	var step := 1.0 / 30.0
	for i in 165:
		vel.y -= GRAVITY * step
		vel += Vector3(0.5, 0.0, 0.2) * step
		pos += vel * step
		if pos.y <= TERRAIN.get_effective_ground_height(pos.x, pos.z):
			break
		if world:
			var m: Dictionary = world.shell_hit(pos, pos - vel * step)
			if m['hit']:
				break
	return pos

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

	if player and player.active_weapon == 'cannon':
		var impact := _ballistic_impact()
		if camera:
			var pp: Vector2 = camera.unproject_position(impact)
			_cannon_circle.position = pp - Vector2(16, 16)
			var cam_dir: Vector3 = -camera.global_transform.basis.z
			var to_impact := impact - camera.global_position
			_cannon_circle.visible = to_impact.dot(cam_dir) > 0.0
	else:
		_cannon_circle.visible = false

func set_reload(frac: float, in_sweet: bool) -> void:
	_reload_frac = frac
	_in_sweet = in_sweet
	_reticle.queue_redraw()

func hide_reload() -> void:
	_reload_frac = -1.0
	_reticle.queue_redraw()

func set_mining_arc(frac: float, active: bool) -> void:
	_mining_frac = frac if active else 0.0
	_reticle.queue_redraw()

func _physics_process(delta: float) -> void:
	update(delta)