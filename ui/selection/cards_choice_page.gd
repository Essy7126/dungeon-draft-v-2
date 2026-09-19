extends VBoxContainer
## One decision: alternatives at left, selected impact always visible at right.
signal chosen(id: String)


func configure(title: String, prompt: String, options: Array, selected: String) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 12)
	text(self, title, 26)
	text(self, prompt, 18)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	add_child(columns)
	var choices := ScrollContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.size_flags_stretch_ratio = 0.8
	choices.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(choices)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	choices.add_child(list)
	var current: Dictionary = { }
	for option: Dictionary in options:
		var button := Button.new()
		button.name = "Choice_" + str(option.id)
		button.text = str(option.title)
		if option.get("icon") is Texture2D:
			button.icon = option.icon
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 34)
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.toggle_mode = true
		button.button_pressed = str(option.id) == selected
		button.pressed.connect(
			func():
				chosen.emit(str(option.id)),
		)
		list.add_child(button)
		if str(option.id) == selected:
			current = option
	var detail := ScrollContainer.new()
	detail.name = "ChoiceImpact"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_stretch_ratio = 1.2
	detail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(detail)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	detail.add_child(body)
	if not current.is_empty():
		if current.get("icon") is Texture2D:
			var icon := TextureRect.new()
			icon.texture = current.icon
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(64, 64)
			body.add_child(icon)
		text(body, str(current.title), 23)
		text(body, str(current.get("impact", "")), 19)
		if not str(current.get("details", "")).is_empty():
			text(body, str(current.details), 16)


static func text(parent: Node, value: String, font_size := 18) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
