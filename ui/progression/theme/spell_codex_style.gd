extends RefCounted
## Instance-only overrides: shared combat and menu themes remain immutable.

const BODY := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf")
const BOLD := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Bold.otf")
const DISPLAY := preload("res://asset/ui/recraft_hud_v1/fonts/cinzel/Cinzel-Variable.ttf")
const INK := Color("121d20")
const SURFACE := Color("18272a")
const BORDER := Color("42514e")
const GOLD := Color("d6b77c")
const TEXT := Color("f0ebdc")
const MUTED := Color("a6b4ad")


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
	control.add_theme_color_override("font_hover_color", TEXT)
	control.add_theme_color_override("font_pressed_color", GOLD)
	control.add_theme_stylebox_override("normal", box(INK, BORDER, 5, 9))
	control.add_theme_stylebox_override("hover", box(Color("30423e"), GOLD, 5, 9))
	control.add_theme_stylebox_override("pressed", box(Color("314237"), GOLD, 5, 9))
	control.add_theme_stylebox_override("disabled", box(Color("202b2a"), BORDER, 5, 9))
	var focus := box(Color.TRANSPARENT, Color("f0dfae"), 5)
	focus.set_border_width_all(2)
	control.add_theme_stylebox_override("focus", focus)


static func selected(control: Button, active: bool) -> void:
	control.set_pressed_no_signal(active)
	control.add_theme_stylebox_override("normal", box(Color("2c3b36") if active else INK, GOLD if active else BORDER, 5, 9))


static func label(control: Label, heading: bool = false) -> void:
	control.add_theme_font_override("font", DISPLAY if heading else BODY)
	control.add_theme_color_override("font_color", TEXT if heading else MUTED)
