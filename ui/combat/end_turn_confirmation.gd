class_name EndTurnConfirmation
extends CanvasLayer

signal confirmed(skip_future: bool)
signal cancelled

var _root: Control
var _message: Label
var _skip_checkbox: CheckBox
var _confirm_button: Button
var _cancel_button: Button


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func present(unit: Unit) -> void:
	if unit == null:
		return
	var remaining: Array[String] = []
	if unit.current_ap > 0:
		remaining.append("%d PA" % unit.current_ap)
	if unit.current_mp > 0:
		remaining.append("%d PM" % unit.current_mp)
	_message.text = (
		"Il reste %s à %s.\nPasser quand même son tour ?"
		% [" et ".join(remaining), unit.unit_name]
	)
	_root.show()
	_confirm_button.grab_focus()


func dismiss() -> bool:
	if not is_open():
		return false
	_root.hide()
	cancelled.emit()
	return true


func is_open() -> bool:
	return is_instance_valid(_root) and _root.visible


func get_snapshot() -> Dictionary:
	return {
		"visible": is_open(),
		"message": _message.text if is_instance_valid(_message) else "",
		"skip_future": (
			_skip_checkbox.button_pressed
			if is_instance_valid(_skip_checkbox)
			else false
		),
	}


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.008, 0.012, 0.018, 0.66)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 260.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.052, 0.98)
	style.border_color = Color(0.74, 0.58, 0.26, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	style.shadow_size = 14
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(content)

	var title := Label.new()
	title.text = "FIN DE TOUR"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 17)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)

	_skip_checkbox = CheckBox.new()
	_skip_checkbox.text = "Ne plus demander pendant ce combat"
	_skip_checkbox.focus_mode = Control.FOCUS_ALL
	_skip_checkbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(_skip_checkbox)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	content.add_child(buttons)

	_confirm_button = Button.new()
	_confirm_button.text = "PASSER LE TOUR"
	_confirm_button.custom_minimum_size = Vector2(190.0, 48.0)
	_confirm_button.focus_mode = Control.FOCUS_ALL
	_confirm_button.pressed.connect(_on_confirmed)
	buttons.add_child(_confirm_button)

	_cancel_button = Button.new()
	_cancel_button.text = "CONTINUER À JOUER"
	_cancel_button.custom_minimum_size = Vector2(190.0, 48.0)
	_cancel_button.focus_mode = Control.FOCUS_ALL
	_cancel_button.pressed.connect(dismiss)
	buttons.add_child(_cancel_button)
	_confirm_button.focus_neighbor_right = _confirm_button.get_path_to(_cancel_button)
	_cancel_button.focus_neighbor_left = _cancel_button.get_path_to(_confirm_button)
	_root.hide()


func _on_confirmed() -> void:
	if not is_open():
		return
	_root.hide()
	confirmed.emit(_skip_checkbox.button_pressed)
