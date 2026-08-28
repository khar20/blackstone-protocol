extends CanvasLayer
## CRT scanline + grain overlay driven by the crt.gdshader shader on a full
## screen ColorRect (kept subtle).

const CRT_SHADER = preload("res://shaders/crt.gdshader")

func _ready() -> void:
	var r := ColorRect.new()
	r.show_behind_parent = false
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = CRT_SHADER
	r.material = mat
	add_child(r)