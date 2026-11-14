@tool
extends "res://addons/dialogic/Modules/DefaultLayoutParts/Layer_VN_Choices/vn_choice_layer.gd"
## Keep choices above the subtitles, using Dialogic's existing choice buttons.


func _ready() -> void:
	connect("resized", _refresh_layout)
	get_choices().minimum_size_changed.connect(_refresh_layout)
	_watch_subtitles.call_deferred()
	_refresh_layout()


func _watch_subtitles() -> void:
	for text in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		var box := text.get_parent() as Control
		if box != null and not box.item_rect_changed.is_connected(_refresh_layout):
			box.item_rect_changed.connect(_refresh_layout)
	_refresh_layout()


func _apply_export_overrides() -> void:
	super._apply_export_overrides()
	var sounds := get_button_sound()
	sounds.sound_pressed = null
	sounds.sound_hover = null
	sounds.sound_focus = null
	for child in get_choices().get_children():
		if child is DialogicNode_ChoiceButton:
			child.alignment = HORIZONTAL_ALIGNMENT_CENTER
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_layout()


func _refresh_layout() -> void:
	if not is_inside_tree():
		return
	var choices := get_choices()
	var viewport_size: Vector2 = get("size")
	var factor := minf(1.0, minf(viewport_size.x / 640.0, viewport_size.y / 360.0))
	if factor <= 0.0:
		return
	var width := minf(1120.0, viewport_size.x / factor * 0.84)
	var subtitle_top := viewport_size.y - 166.0 * factor
	if not Engine.is_editor_hint():
		for text in get_tree().get_nodes_in_group("dialogic_dialog_text"):
			var box := text.get_parent() as Control
			if box != null:
				subtitle_top = minf(subtitle_top, box.get_global_rect().position.y - 8.0 * factor)
	choices.set_anchors_preset(Control.PRESET_TOP_LEFT)
	choices.size = Vector2(width, choices.get_combined_minimum_size().y)
	factor = minf(factor, maxf(1.0, subtitle_top - 40.0 * factor) / maxf(1.0, choices.size.y))
	choices.scale = Vector2.ONE * factor
	choices.position = Vector2((viewport_size.x - choices.size.x * factor) * 0.5, subtitle_top - 28.0 * factor - choices.size.y * factor).round()
