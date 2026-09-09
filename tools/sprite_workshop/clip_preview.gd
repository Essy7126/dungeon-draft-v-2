extends Control

var frames: Array[Texture2D] = []
var frame := 0
var anchor := Vector2(256, 320)
var display_scale := 0.35
var zoom := 1.0
var onion := false


func _draw() -> void:
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	var ground := Vector2(size.x * 0.5, size.y * 0.8)
	draw_line(Vector2(16, ground.y), Vector2(size.x - 16, ground.y), Color("455365"))
	draw_line(ground - Vector2(7, 0), ground + Vector2(7, 0), Color("edbe73"), 2)
	draw_line(ground - Vector2(0, 7), ground + Vector2(0, 7), Color("edbe73"), 2)
	if frames.is_empty():
		return
	var index := clampi(frame, 0, frames.size() - 1)
	if onion:
		if index > 0:
			_draw_frame(index - 1, ground, Color(0.4, 0.8, 1.0, 0.22))
		if index + 1 < frames.size():
			_draw_frame(index + 1, ground, Color(1.0, 0.6, 0.4, 0.22))
	_draw_frame(index, ground, Color.WHITE)


func _draw_frame(index: int, ground: Vector2, tint: Color) -> void:
	var scale_factor := display_scale * zoom
	draw_texture_rect(
		frames[index],
		Rect2(ground - anchor * scale_factor, frames[index].get_size() * scale_factor),
		false,
		tint,
	)


func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b2633")
	style.set_corner_radius_all(8)
	return style
