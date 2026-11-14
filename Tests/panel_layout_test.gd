extends SceneTree
## Run with an isolated APPDATA/LOCALAPPDATA; autoloads may write settings.
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 10:
		await process_frame

func contained(control: Control, bounds: Rect2, message: String) -> void:
	check(bounds.grow(1).encloses(control.get_global_rect()), message + " clipped: " + str(control.get_global_rect()))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := root.get_node("GameController")
	game.day = 3
	game.window_history["day1_tutorial_skipped"] = true
	var host = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	host.change_scene(host.HOUSE_SCENE)
	await settle()
	var house = host.active_scene
	var candidates: Array = []
	for i in 15:
		var worker := Villager.new()
		worker.id = i + 1
		worker.display_name = "Traveler %d" % i
		candidates.append(worker)
	house._on_victim_choice_requested(candidates)
	house.sacrifice_modal.hide()
	var dialogue_base := DialogicLayoutBase.new()
	root.add_child(dialogue_base)
	var subtitles = load("res://Dialogue/UI/subtitle_layer.tscn").instantiate()
	dialogue_base.add_child(subtitles)
	var choices = load("res://Dialogue/UI/choice_layer.tscn").instantiate()
	dialogue_base.add_child(choices)
	await settle()
	for i in 3:
		var button := Button.new()
		button.text = "A longer response that needs to wrap inside its choice button."
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 48
		choices.get_choices().add_child(button)
	for stretched in [false, true]:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if stretched else Window.CONTENT_SCALE_MODE_DISABLED
		root.content_scale_size = Vector2i(1920, 1080) if stretched else Vector2i.ZERO
		for dimensions in [Vector2i(320,568), Vector2i(640,360), Vector2i(873,491), Vector2i(720,1280), Vector2i(1920,1080), Vector2i(3440,1440), Vector2i(3840,2160)]:
			root.size = dimensions
			subtitles.size = root.get_visible_rect().size
			choices.size = subtitles.size
			await settle()
			var bounds := root.get_visible_rect()
			house.sleep_dialog.dialog_text = "Banked Flesh: 12 / 12. The toll is met.\n\nRations left after feeding the village: 10."
			house.sleep_dialog.popup_centered(Vector2i(680, 240))
			house._fit_house_ui()
			await settle()
			check(bounds.encloses(Rect2(Vector2(house.sleep_dialog.position), Vector2(house.sleep_dialog.size))), "Sleep confirmation clipped")
			house.sleep_dialog.hide()
			contained(house.get_node("UI/TopHUD"), bounds, "House HUD")
			for panel in [house.RoomPanel.STAIRS, house.RoomPanel.DESK, house.RoomPanel.WINDOW]:
				house.set_panel(panel)
				await settle()
				var actions: Control = house.get_node(["Panels/StairsPanel/CenterBox", "Panels/DeskPanel/CenterBox", "Panels/WindowPanel/WindowActions"][panel])
				contained(actions, bounds, "Room actions")
				for button in [house.left_nav_btn, house.right_nav_btn]:
					if button.visible:
						contained(button, bounds, "Navigation")
						check(not actions.get_global_rect().intersects(button.get_global_rect()), "Navigation overlaps room actions")
			for modal in [house.refugee_modal, house.sacrifice_modal]:
				modal.show()
				house._center_modal(modal)
				await settle()
				contained(modal, bounds, "House modal")
				check(modal.get_global_rect().get_center().distance_to(bounds.get_center()) < 1.5, "House modal not centered")
				modal.hide()
			for text in ["A short line.", "The village needs food and the toll must be paid. Return to the entrance to bank the Flesh you carry before ending the day."]:
				subtitles.dialog_text.text = text
				subtitles._refresh_layout()
				await settle()
				contained(subtitles.get_node("Subtitles/Frame"), bounds, "Subtitle frame")
				contained(choices.get_choices(), bounds, "Dialogue choices")
				check(choices.get_choices().get_global_rect().end.y < subtitles.get_node("Subtitles/Frame").get_global_rect().position.y, "Choices overlap subtitle frame")
	dialogue_base.free()
	host.change_scene("res://Scenes/Boss/boss_arena.tscn")
	await settle()
	var boss = host.active_scene
	boss._result_title.text = "The Chief has fallen"
	boss._result.show()
	for dimensions in [Vector2i(320,568), Vector2i(640,360), Vector2i(873,491), Vector2i(1920,1080)]:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.content_scale_size = Vector2i.ZERO
		root.size = dimensions
		await settle()
		contained(boss._result, root.get_visible_rect(), "Boss results")
	host.free()
	await settle()
	print("Panel layout: %d checks; failures=%d" % [checks, failures])
	quit(1 if failures else 0)
