class_name CrtOverlay
## CRT scanline + grain from crt.gdshader, scoped to a single UI panel:
## attach() adds a screen-sampling ColorRect as the last child of a panel so
## only that panel's pixels get the effect (game world/camera untouched).
## Hidden panel = rect not drawn = shader not executed (zero cost, no UI).

const CRT_SHADER = preload("res://shaders/crt.gdshader")

static func attach(panel: Control) -> void:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = CRT_SHADER
	r.material = mat
	panel.add_child(r)
