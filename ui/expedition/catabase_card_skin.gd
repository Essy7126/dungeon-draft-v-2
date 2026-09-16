extends RefCounted
## Shared drawn card treatment. Rendering only: no changes to card rules.
const FRAME = preload("res://assets/catabase/cards_drawn_v1/card_frame.png")
const DECK = preload("res://assets/catabase/cards_drawn_v1/deck.png")
const FONT = preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf")
static var _frame_texture: Texture2D


static func frame(selected := false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	if _frame_texture == null:
		var image := FRAME.get_image()
		image.resize(128, 192, Image.INTERPOLATE_LANCZOS)
		_frame_texture = ImageTexture.create_from_image(image)
	style.texture = _frame_texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 18.0)
		style.set_content_margin(side, 8.0)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	# Texture corners are sampled at source size, then fitted to a narrow UI rim.
	style.modulate_color = Color("fff0b7") if selected else Color.WHITE
	return style


static func action(button: Button, compact := false) -> void:
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 12 if compact else 14)
	button.add_theme_color_override("font_color", Color("eee2c8"))
	button.add_theme_color_override("font_hover_color", Color("fff2ce"))
	button.add_theme_color_override("font_disabled_color", Color("929995"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("253f39") if state == "hover" else Color("172d28") if state == "pressed" else Color("101e1bd9")
		style.border_color = Color("d8b775") if state in ["hover", "focus", "pressed"] else Color("647568") if state == "disabled" else Color("78684a")
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		style.content_margin_left = 5
		style.content_margin_right = 5
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		if state == "focus": style.bg_color = Color.TRANSPARENT
		button.add_theme_stylebox_override(state, style)
