extends Button
## An illustrated, keyboard-accessible choice; the whole tile is the hit target.


func configure(title: String, description: String, art: Texture2D, selected := false) -> void:
	toggle_mode = true
	button_pressed = selected
	custom_minimum_size = Vector2(240, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_text = title + "\n" + description
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_top = 12
	box.offset_right = -14
	box.offset_bottom = -12
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.clip_contents = true
	add_child(box)
	var image := TextureRect.new()
	image.texture = art
	image.custom_minimum_size.y = 72
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(image)
	for value in [title, description]:
		var label := Label.new()
		label.text = value
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18 if value == title else 15)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
		if value == description:
			label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.max_lines_visible = 3
			label.clip_text = true
