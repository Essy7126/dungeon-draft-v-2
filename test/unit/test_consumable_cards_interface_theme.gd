extends GutTest
const D := preload("res://ui/expedition/player_dossier_skin.gd")


func _channel(value: float) -> float:
	return value / 12.92 if value <= .04045 else pow((value + .055) / 1.055, 2.4)


func _light(color: Color) -> float:
	return .2126 * _channel(color.r) + .7152 * _channel(color.g) + .0722 * _channel(color.b)


func _contrast(a: Color, b: Color) -> float:
	return (maxf(_light(a), _light(b)) + .05) / (minf(_light(a), _light(b)) + .05)


func test_button_text_remains_readable_in_all_interaction_states() -> void:
	for kind in ["secondary", "selected", "primary"]:
		var button := Button.new()
		D.button(button, kind == "selected")
		if kind == "primary":
			D.primary_button(button)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var color_key: String = "font_color" if state == "normal" else "font_" + state + "_color"
			var foreground := button.get_theme_color(color_key)
			var background: StyleBoxFlat = button.get_theme_stylebox(state)
			assert_gte(_contrast(foreground, background.bg_color), 4.5, kind + ": " + state)
		var focus: StyleBoxFlat = button.get_theme_stylebox("focus")
		assert_eq(focus.bg_color.a, 0.0, "Focus does not hide the button")
		button.free()


func test_field_hint_and_selected_tabs_have_readable_contrast() -> void:
	var skin := D.interface_theme()
	var field: StyleBoxFlat = skin.get_stylebox("normal", "LineEdit")
	assert_gte(_contrast(skin.get_color("font_placeholder_color", "LineEdit"), field.bg_color), 4.5)
	var tab: StyleBoxFlat = skin.get_stylebox("tab_selected", "TabContainer")
	assert_gte(_contrast(skin.get_color("font_selected_color", "TabContainer"), tab.bg_color), 4.5)
	var inactive: StyleBoxFlat = skin.get_stylebox("tab_unselected", "TabContainer")
	assert_gt(
		tab.border_width_bottom,
		inactive.border_width_bottom,
		"Active tab also has a structural cue",
	)


func test_hud_captions_are_passive_idempotent_and_removed_on_classic_return() -> void:
	var captions := preload("res://ui/expedition/card_hud_labels.gd")
	var buttons: Array = []
	for index in 4:
		var button := Button.new()
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		buttons.append(button)
	captions.apply(buttons)
	captions.apply(buttons)
	for button: Button in buttons:
		assert_eq(button.get_child_count(), 1, "Resizing does not duplicate captions")
		assert_eq(button.get_child(0).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	captions.clear(buttons)
	for button: Button in buttons:
		assert_eq(button.get_child_count(), 0)
		assert_eq(button.vertical_icon_alignment, VERTICAL_ALIGNMENT_CENTER)
		button.free()
