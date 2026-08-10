extends Node2D

@export var accent := Color("53d2ff")
@export var body_color := Color("203849")
@export var display_name := "CASTER"
@export var scale_factor := 1.0


func configure(label_text: String, color: Color, body: Color = Color("203849")) -> void:
	display_name = label_text
	accent = color
	body_color = body
	queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var s := scale_factor
	var shadow := PackedVector2Array()
	for index in 32:
		var angle := TAU * float(index) / 32.0
		shadow.append(Vector2(cos(angle) * 25.0 * s, sin(angle) * 9.0 * s + 5.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.42))
	var aura := accent
	aura.a = 0.12
	draw_circle(Vector2(0.0, -25.0) * s, 29.0 * s, aura)
	var cloak := PackedVector2Array([
		Vector2(-17.0, 3.0) * s,
		Vector2(-13.0, -38.0) * s,
		Vector2(13.0, -38.0) * s,
		Vector2(18.0, 3.0) * s,
		Vector2(0.0, 12.0) * s,
	])
	draw_colored_polygon(cloak, body_color)
	draw_polyline(PackedVector2Array([cloak[0], cloak[1], cloak[2], cloak[3]]), Color(accent, 0.72), 2.0 * s, true)
	draw_circle(Vector2(0.0, -48.0) * s, 12.0 * s, Color("d8c4ae"))
	draw_arc(Vector2(0.0, -48.0) * s, 13.0 * s, PI, TAU, 18, accent, 3.0 * s, true)
	draw_line(Vector2(-10.0, -26.0) * s, Vector2(-25.0, -6.0) * s, Color(accent, 0.76), 3.0 * s, true)
	draw_line(Vector2(10.0, -26.0) * s, Vector2(25.0, -6.0) * s, Color(accent, 0.76), 3.0 * s, true)
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	draw_string(font, Vector2(-text_size.x * 0.5, 29.0), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.9, 0.96, 0.72))
