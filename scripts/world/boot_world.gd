extends SceneTree
## Throwaway: boots the World node headless for ~10 frames to surface runtime
## errors in terrain/env/spawn paths. `godot --headless -s res://boot_world.gd`

var _frames := 0

func _initialize() -> void:
	var world_script: GDScript = load('res://scripts/world/world.gd')
	var w := Node3D.new()
	w.set_script(world_script)
	root.add_child(w)
	process_frame.connect(_tick)

func _tick() -> void:
	_frames += 1
	if _frames > 10:
		print('WORLD BOOT OK')
		quit(0)