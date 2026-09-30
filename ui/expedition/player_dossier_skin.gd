extends RefCounted
## Quiet surfaces, large illustrations, stable information hierarchy for player windows.
const FONT = preload(
	"res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf"
)
const GOLD := Color("dbb98f")
const INK := Color("191512")
const PAPER := Color("f0e7dc")
const MUTED := Color("bcb0a3")
const GREEN := Color("c9c7a5")
const GAIN := Color("a9d29d")
const LOSS := Color("eeaa99")
const PRIMARY := Color("d2af80")
const PRIMARY_INK := Color("241a12")


static func surface(selected := false, padding := 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("403329") if selected else Color("28221e")
	style.border_color = GOLD if selected else Color("51443a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(padding)
	return style


static func framed_surface(padding := 14) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = preload("res://asset/ui/player_materials/umber_panel.svg")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 24)
		style.set_content_margin(side, padding)
	return style


static func card_material(node: Control) -> void:
	if node.has_node("CardMaterial"):
		return
	var texture := NinePatchRect.new()
	texture.name = "CardMaterial"
	texture.texture = preload("res://asset/ui/player_materials/umber_card.svg")
	texture.patch_margin_left = 24
	texture.patch_margin_top = 24
	texture.patch_margin_right = 24
	texture.patch_margin_bottom = 24
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.self_modulate.a = .45
	node.add_child(texture)
	node.move_child(texture, 0)
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.offset_left = 3
	texture.offset_top = 4
	texture.offset_right = -3
	texture.offset_bottom = -3


static func label(parent: Node, value: String, extent := 17, tint := PAPER) -> Label:
	var node := Label.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", extent)
	node.add_theme_color_override("font_color", tint)
	parent.add_child(node)
	return node


static func button(node: Button, selected := false) -> void:
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", 16)
	node.add_theme_color_override("font_color", GOLD if selected else PAPER)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_disabled_color", Color("b6a99b"))
	node.add_theme_color_override("font_pressed_color", PAPER)
	node.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	node.add_theme_color_override("font_focus_color", GOLD)
	node.add_theme_stylebox_override("normal", surface(selected, 9))
	node.add_theme_stylebox_override("hover", surface(true, 9))
	var pressed := surface(true, 9)
	pressed.bg_color = Color("34271e")
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("hover_pressed", surface(true, 9))
	node.add_theme_stylebox_override("disabled", surface(false, 9))
	var focus := surface(true, 0)
	focus.bg_color = Color.TRANSPARENT
	focus.set_border_width_all(2)
	node.add_theme_stylebox_override("focus", focus)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func primary_button(node: Button) -> void:
	button(node)
	node.set_meta("action_emphasis", "primary")
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var style := surface(false, 9)
		style.bg_color = {
			"normal": PRIMARY,
			"hover": Color("e4c69e"),
			"pressed": Color("b89468"),
			"hover_pressed": Color("c5a071"),
		}[state]
		style.border_color = Color("f4d8ae")
		style.border_width_top = 2
		style.border_width_bottom = 2
		node.add_theme_stylebox_override(state, style)
	for key in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_hover_pressed_color",
		"font_focus_color",
	]:
		node.add_theme_color_override(key, PRIMARY_INK)
	var focus := surface(true, 0)
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("fff3d9")
	focus.set_border_width_all(2)
	node.add_theme_stylebox_override("focus", focus)


static func navigation_button(node: Button, active: bool) -> void:
	button(node, active)
	node.set_meta("action_emphasis", "navigation")
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var selected: bool = active or state in ["pressed", "hover_pressed"]
		var style := surface(selected or state == "hover", 9)
		style.border_width_bottom = 3 if selected else 1
		style.border_color = GOLD if selected else Color("665344")
		node.add_theme_stylebox_override(state, style)


static func window_surface(padding := 20) -> StyleBoxTexture:
	var style := framed_surface(padding)
	style.modulate_color = Color("c8c2bc")
	return style


static func interface_theme(base: Theme = null) -> Theme:
	var result: Theme = base.duplicate() if base != null else Theme.new()
	for kind in ["VScrollBar", "HScrollBar"]:
		var track := surface(false, 0)
		track.bg_color = Color("191613")
		track.set_border_width_all(0)
		track.set_content_margin_all(4)
		result.set_stylebox("scroll", kind, track)
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			var handle := surface(false, 0)
			handle.bg_color = GOLD if state != "grabber" else Color("9b8268")
			handle.set_border_width_all(0)
			handle.set_content_margin_all(4)
			result.set_stylebox(state, kind, handle)
	for kind in ["TabContainer", "TabBar"]:
		result.set_font("font", kind, FONT)
		result.set_font_size("font_size", kind, 17)
		for state in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled"]:
			var tab := surface(state in ["tab_selected", "tab_hovered"], 6)
			tab.border_width_bottom = 3 if state == "tab_selected" else 1
			result.set_stylebox(state, kind, tab)
		result.set_color("font_selected_color", kind, GOLD)
		result.set_color("font_unselected_color", kind, PAPER)
		result.set_color("font_hovered_color", kind, Color.WHITE)
	var inset := StyleBoxEmpty.new()
	inset.content_margin_top = 4
	result.set_stylebox("panel", "TabContainer", inset)
	var field := surface(false, 8)
	field.bg_color = Color("1c1815")
	result.set_stylebox("normal", "LineEdit", field)
	var focus := surface(true, 8)
	focus.bg_color = Color.TRANSPARENT
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "LineEdit", focus)
	result.set_font("font", "LineEdit", FONT)
	result.set_font_size("font_size", "LineEdit", 16)
	result.set_color("font_color", "LineEdit", PAPER)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	return result


static func column(parent: Node, width := 0, scroll := true) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if parent is HBoxContainer else Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", framed_surface())
	parent.add_child(panel)
	var host: Node = panel
	if scroll:
		var scroller := ScrollContainer.new()
		scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroller.follow_focus = true
		panel.add_child(scroller)
		host = scroller
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	host.add_child(box)
	return box


static func image(parent: Node, texture: Texture2D, extent := 64) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.custom_minimum_size = Vector2(extent, extent)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art


static func metric(parent: Node, title: String, value: String, tint := GOLD) -> void:
	var box := column(parent, 0, false)
	label(box, title, 14, MUTED)
	label(box, value, 24, tint)


static func passive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		passive(child)
