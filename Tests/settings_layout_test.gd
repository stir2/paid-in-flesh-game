extends SceneTree
## Exercises the same Settings instance while hidden, open, resized and paused.
## Settings writes use the test runner's isolated user:// directory.
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for frame in 5:
		await process_frame
func verify(settings: Control, label: String) -> void:
	var bounds := settings.get_global_rect()
	var paper: Rect2 = settings._paper.get_global_rect()
	check(bounds.grow(1).encloses(paper), label + ": Settings clipped")
	check(bounds.get_center().distance_to(paper.get_center()) < 1, label + ": Settings not centered")
func _initialize() -> void:
	call_deferred("run")
func click_button(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
func run() -> void:
	var game := root.get_node("GameController")
	game.day = 3
	game.window_history["day1_tutorial_skipped"] = true
	var host = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	for path in [host.MENU_SCENE, host.HOUSE_SCENE, "res://Scenes/Boss/boss_arena.tscn"]:
		host.change_scene(path)
		await settle()
		var from_pause: bool = path != host.MENU_SCENE
		var settings: Control = host.pause_menu.get_node("SettingsPanel") if from_pause else host.active_scene.get_node("SettingsPanel")
		for stretched in [false, true]:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if stretched else Window.CONTENT_SCALE_MODE_DISABLED
			root.content_scale_size = Vector2i(1920,1080) if stretched else Vector2i.ZERO
			for dimensions in [Vector2i(1920,1080),Vector2i(824,789),Vector2i(320,568),Vector2i(2560,1080),Vector2i(3840,2160),Vector2i(640,360),Vector2i(1920,1080)]:
				root.size = dimensions
				await settle()
				if from_pause:
					host.pause_menu.toggle()
					host.pause_menu.get_node("%SettingsButton").pressed.emit()
				else:
					click_button(host.active_scene.get_node("%SettingsButton"))
				await settle()
				check(settings.is_visible_in_tree(), "Settings button did not open visible Settings")
				verify(settings, "Open %s %s" % [path, dimensions])
				root.size = Vector2i(dimensions.y, dimensions.x)
				await settle()
				verify(settings, "Resize while visible")
				var escape := InputEventKey.new()
				escape.physical_keycode = KEY_ESCAPE
				escape.pressed = true
				settings._input(escape)
				check(not settings.visible, "Escape did not close Settings")
				check(paused == from_pause, "Settings changed pause ownership")
				if from_pause:
					check(host.pause_menu.panel.visible, "Settings did not return to pause")
				root.size = dimensions
				settings.open()
				await settle()
				verify(settings, "Immediate reopen after hidden resize")
				settings.close()
				if from_pause:
					host.pause_menu.resume()
	paused = false
	host.free()
	await settle()
	print("Settings reopen/resize: %d checks; failures=%d" % [checks,failures])
	quit(1 if failures else 0)
