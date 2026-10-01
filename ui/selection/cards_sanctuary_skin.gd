extends RefCounted
## Painted presentation confined to Cards preparation. No gameplay definitions.
const FRAME := preload("res://assets/catabase/cards_drawn_v1/card_frame.png")
const PLATE := preload("res://assets/catabase/cards_sanctuary_v2/action_plate.png")
const DAIS := preload("res://assets/catabase/cards_sanctuary_v2/hero_dais.png")
const PROPS := {
	"class": preload("res://assets/catabase/cards_sanctuary_v2/class_seal.png"),
	"deck": preload("res://assets/catabase/cards_sanctuary_v2/deck_socle.png"),
	"elements": preload("res://assets/catabase/cards_sanctuary_v2/elements_socle.png"),
	"difficulty": preload("res://assets/catabase/cards_sanctuary_v2/difficulty_socle.png"),
}
const PROP_REGIONS := {
	"class": Rect2(116, 80, 1145, 1013),
	"deck": Rect2(70, 192, 1394, 746),
	"elements": Rect2(78, 138, 1395, 812),
	"difficulty": Rect2(171, 12, 1050, 1110),
}
const GOLD := Color("d8b776")
const FONT := preload("res://asset/ui/recraft_hud_v1/fonts/cinzel/Cinzel-Variable.ttf")
static var _plate: Texture2D
static var _frame: Texture2D


class Rule:
	extends Control

	func _draw() -> void:
		var center := size * .5
		var tint := Color("b69b67")
		draw_line(Vector2(0, center.y), center - Vector2(13, 0), tint, 1, true)
		draw_line(center + Vector2(13, 0), Vector2(size.x, center.y), tint, 1, true)
		draw_polyline(
			PackedVector2Array(
				[
					center + Vector2(0, -4),
					center + Vector2(4, 0),
					center + Vector2(0, 4),
					center + Vector2(-4, 0),
					center + Vector2(0, -4),
				]
			),
			tint,
			1,
			true,
		)


static func rule(parent: Node, rect: Rect2) -> Control:
	var line := Rule.new()
	line.position = rect.position
	line.size = rect.size
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	return line


static func crop(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	atlas.filter_clip = true
	return atlas


static func prop(kind: String) -> Texture2D:
	return crop(PROPS[kind], PROP_REGIONS[kind])


static func platform() -> Texture2D:
	return crop(DAIS, Rect2(14, 301, 1996, 444))


static func frame(accent := Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	if _frame == null:
		var image := FRAME.get_image()
		image.resize(192, 288, Image.INTERPOLATE_LANCZOS)
		_frame = ImageTexture.create_from_image(image)
	style.texture = _frame
	style.modulate_color = accent
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 24)
		style.set_content_margin(side, 24)
	return style


static func primary(button: Button) -> void:
	if _plate == null:
		var image := crop(PLATE, Rect2(38, 152, 2096, 390)).get_image()
		image.resize(512, 95, Image.INTERPOLATE_LANCZOS)
		_plate = ImageTexture.create_from_image(image)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := StyleBoxTexture.new()
		style.texture = _plate
		style.modulate_color = Color("fff2cf") if state == "hover" else Color("bcb4a4") if state == "disabled" else Color.WHITE
		for side in [SIDE_LEFT, SIDE_RIGHT]:
			style.set_texture_margin(side, 20)
			style.set_content_margin(side, 12)
		for side in [SIDE_TOP, SIDE_BOTTOM]:
			style.set_texture_margin(side, 7)
			style.set_content_margin(side, 6)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_font_override("font", FONT)
	button.add_theme_color_override("font_color", Color("f4e4bb"))
	button.add_theme_color_override("font_hover_color", Color("fff6dc"))
	button.add_theme_color_override("font_pressed_color", Color("f4e4bb"))
	button.add_theme_color_override("font_disabled_color", Color("a99d80"))
