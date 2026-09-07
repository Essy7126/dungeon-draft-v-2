extends RefCounted
## Instance-only overrides: shared combat and menu themes remain immutable.

const BODY := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf")
const BOLD := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Bold.otf")
const DISPLAY := preload("res://asset/ui/character_selection/selection_title_font.tres")
const MATERIAL := preload("res://ui/selection/selection_ashen_surface.gd")
const INK := Color("191614")
const SURFACE := Color("25201c")
const BORDER := Color("665344")
const GOLD := Color("d1ae7b")
const TEXT := Color("f2e6d3")
const MUTED := Color("b9ad9c")


static func box(fill: Color, border: Color = BORDER, radius: int = 7, margin: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	return style


static func button(control: Button) -> void:
	control.add_theme_font_override("font", BOLD)
	control.add_theme_color_override("font_color", TEXT)
	control.add_theme_color_override("font_hover_color", Color("fff4df"))
	control.add_theme_color_override("font_pressed_color", GOLD)
	control.add_theme_color_override("font_disabled_color", Color("887c6c"))
	control.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.01, 0.85))
	control.add_theme_constant_override("shadow_offset_y", 1)
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.add_theme_stylebox_override("normal", box(Color.TRANSPARENT, BORDER, 5, 9))
	control.add_theme_stylebox_override("hover", box(Color.TRANSPARENT, GOLD, 5, 9))
	control.add_theme_stylebox_override("pressed", box(Color.TRANSPARENT, GOLD, 5, 9))
	control.add_theme_stylebox_override("hover_pressed", box(Color.TRANSPARENT, Color("e6c594"), 5, 9))
	control.add_theme_stylebox_override("disabled", box(Color.TRANSPARENT, Color("433a32"), 5, 9))
	var focus := box(Color.TRANSPARENT, Color("f0dbac"), 5)
	focus.set_border_width_all(2)
	control.add_theme_stylebox_override("focus", focus)
	if not control.has_node("AshenButtonMaterial"):
		var surface := MATERIAL.new()
		surface.name = "AshenButtonMaterial"
		surface.configure(&"button", SURFACE, BORDER)
		control.add_child(surface)


static func selected(control: Button, active: bool) -> void:
	control.set_pressed_no_signal(active)
	control.add_theme_stylebox_override("normal", box(Color.TRANSPARENT, GOLD if active else BORDER, 5, 9))
	var surface := control.get_node_or_null("AshenButtonMaterial")
	if surface != null:
		surface.set_selected(active, GOLD)


static func label(control: Label, heading: bool = false) -> void:
	control.add_theme_font_override("font", DISPLAY if heading else BODY)
	control.add_theme_color_override("font_color", TEXT if heading else MUTED)
	control.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.01, 0.7))
	control.add_theme_constant_override("shadow_offset_y", 1)


static func panel(control: Control, fill: Color = SURFACE, border: Color = BORDER, radius: int = 7, margin: int = 0) -> void:
	var style := box(Color.TRANSPARENT, border, radius, margin)
	style.shadow_color = Color(0.02, 0.015, 0.01, 0.32)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	control.add_theme_stylebox_override("panel", style)
	var surface := control.get_node_or_null("AshenMaterialLayer/MaterialSurface") as SelectionAshenSurface
	if surface == null:
		# The Node2D bridge keeps decorative material out of Container minimum-size calculations.
		var layer := Node2D.new()
		layer.name = "AshenMaterialLayer"
		layer.show_behind_parent = true
		control.add_child(layer)
		surface = MATERIAL.new()
		surface.name = "MaterialSurface"
		surface.configure(&"window", fill, border)
		var fit_surface := func():
			if is_instance_valid(surface):
				surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
				surface.size = control.size
		surface.ready.connect(fit_surface, CONNECT_ONE_SHOT)
		layer.add_child(surface)
		fit_surface.call()
		control.resized.connect(fit_surface)
	else:
		surface.configure(&"window", fill, border)


static func scroll(control: ScrollContainer) -> void:
	for bar in [control.get_v_scroll_bar(), control.get_h_scroll_bar()]:
		bar.add_theme_stylebox_override("scroll", box(Color("141210"), Color.TRANSPARENT, 3, 3))
		bar.add_theme_stylebox_override("grabber", box(Color("6b5640"), Color("907654"), 3, 3))
		bar.add_theme_stylebox_override("grabber_highlight", box(Color("a18257"), GOLD, 3, 3))
		bar.add_theme_stylebox_override("grabber_pressed", box(GOLD, Color("f0d5a0"), 3, 3))
