extends Node
## Regression check for the menu flow: DEPLOY must dismiss the title menu,
## open the intro dialogue (rendered/input-first above the menu), then flip
## GAME.state to PLAYING when the dialogue closes.
## Run: godot --headless res://tests/deploy_flow_test.tscn

var _fails := 0

func check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error('ASSERT FAILED: ' + msg)

func _ready() -> void:
	var main: Node3D = load('res://scenes/main.tscn').instantiate()
	get_tree().root.call_deferred('add_child', main)
	await get_tree().process_frame
	await get_tree().process_frame

	var menus := main.get_child(7)
	var dialogue := main.get_child(8)

	check(dialogue.get_index() > menus.get_index(),
		'dialogue layered above menus (input/z order)')
	check(GAME.state == 'TITLE', 'initial state is TITLE')
	check(menus._title.visible, 'title menu visible on boot')
	check(not dialogue.visible, 'dialogue hidden on boot')

	var btn: Button = null
	for child in menus._title.find_children('*', 'Button', true, false):
		if child.text == 'DEPLOY':
			btn = child
			break
	check(btn != null, 'DEPLOY button exists')
	if btn == null:
		_finish()
		return
	btn.pressed.emit()

	check(not menus._title.visible, 'title menu dismissed on DEPLOY')
	check(dialogue.visible, 'intro dialogue opened after DEPLOY')
	check(GAME.state == 'TITLE', 'still TITLE during intro dialogue')

	var guard := 0
	while dialogue.visible and guard < 16:
		dialogue.advance()
		guard += 1
	check(not dialogue.visible, 'intro dialogue closed')
	check(guard == 4, 'intro has two typewriter pages (%d advances)' % guard)
	check(GAME.state == 'PLAYING', 'GAME.state flips to PLAYING after intro')
	check(not menus._title.visible, 'title stays hidden once playing')

	_finish()

func _finish() -> void:
	if _fails > 0:
		push_error('%d assertion(s) failed' % _fails)
		get_tree().quit(1)
	else:
		print('DEPLOY FLOW OK')
		get_tree().quit(0)