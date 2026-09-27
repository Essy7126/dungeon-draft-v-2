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


static func surface(selected := false, padding := 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("403329") if selected else Color("28221e")
	style.border_color = GOLD if selected else Color("51443a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(padding)
	return style


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
	node.add_theme_color_override("font_disabled_color", Color("a3988b"))
	node.add_theme_stylebox_override("normal", surface(selected, 9))
	node.add_theme_stylebox_override("hover", surface(true, 9))
	node.add_theme_stylebox_override("pressed", surface(true, 9))
	node.add_theme_stylebox_override("disabled", surface(false, 9))
	var focus := surface(true, 0)
	focus.bg_color = Color.TRANSPARENT
	focus.set_border_width_all(2)
	node.add_theme_stylebox_override("focus", focus)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func column(parent: Node, width := 0, scroll := true) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if parent is HBoxContainer else Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", surface())
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
