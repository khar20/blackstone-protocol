extends PanelContainer
## Reusable semi-transparent holo panel: ultra-thin frame, corner ticks,
## dashed accent strip. Applied directly to every HUD/menu panel node.

const AMBER := Color(0xd9a05b)
const AMBER_DIM := Color(0xd9a05b, 0.45)
const BEIGE := Color(0xdcd5c5)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	if ResourceLoader.exists("res://ui/theme/blackstone_theme.tres"):
		theme = load("res://ui/theme/blackstone_theme.tres")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0x120f0a, 0.72)
	sb.border_color = AMBER_DIM
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	add_theme_stylebox_override("panel", sb)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var t := 6.0
	draw_line(Vector2(2.0, t), Vector2(2.0, 2.0), AMBER, 1.5)
	draw_line(Vector2(2.0, 2.0), Vector2(t, 2.0), AMBER, 1.5)
	draw_line(Vector2(w - 2.0, h - t), Vector2(w - 2.0, h - 2.0), AMBER, 1.5)
	draw_line(Vector2(w - 2.0, h - 2.0), Vector2(w - t, h - 2.0), AMBER, 1.5)
	var dash := 4.0
	var x := 12.0
	while x < w - 8.0:
		draw_line(Vector2(x, h - 5.5), Vector2(x + dash, h - 5.5), AMBER, 1.0)
		x += dash * 2.0