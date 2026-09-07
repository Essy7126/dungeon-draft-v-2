extends CanvasLayer

signal option_selected(option_id: StringName)
signal declined

var _panel: PanelContainer
var _title: Label
var _body: Label
var _options: VBoxContainer
var _cancel: Button

func _ready() -> void:
	layer = 58
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.position = Vector2(-224, 86)
	_panel.custom_minimum_size = Vector2(448, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142626")
	style.border_color = Color("aa8b55")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	_title = Label.new()
	_title.add_theme_color_override("font_color", Color("eeddb7"))
	_title.add_theme_font_size_override("font_size", 22)
	column.add_child(_title)
	_body = Label.new()
	_body.custom_minimum_size.x = 404
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", Color("b8ccc4"))
	column.add_child(_body)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 7)
	column.add_child(_options)
	_cancel = Button.new()
	_cancel.text = "Passer"
	_cancel.custom_minimum_size.y = 36
	_cancel.pressed.connect(func() -> void: declined.emit())
	column.add_child(_cancel)
	_panel.hide()

func present(title: String, body: String, options: Dictionary, optional: bool = true) -> void:
	_title.text = title
	_body.text = body
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	for key in options:
		var button := Button.new()
		button.text = str(options[key])
		button.custom_minimum_size.y = 40
		button.pressed.connect(func() -> void: option_selected.emit(StringName(key)))
		_options.add_child(button)
	_cancel.visible = optional
	_panel.show()
	if _options.get_child_count() > 0:
		_options.get_child(0).grab_focus()
	elif optional:
		_cancel.grab_focus()

func close() -> void:
	_panel.hide()

func is_open() -> bool:
	return is_instance_valid(_panel) and _panel.visible

func can_decline() -> bool:
	return is_open() and _cancel.visible
