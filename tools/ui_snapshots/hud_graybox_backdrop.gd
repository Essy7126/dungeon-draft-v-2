class_name HudGrayboxBackdrop
extends Control

const TARGET_MARKER := preload("res://battle/combat_highlight_marker.gd")

var state_id: StringName = &"idle":
	set(value):
		state_id = value
		queue_redraw()

var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("16191d"))
	_draw_room_volume()
	_draw_board()
	_draw_units()
	_draw_targeting_feedback()


func _draw_room_volume() -> void:
	var horizon := size.y * 0.48
	draw_colored_polygon(
		PackedVector2Array([
			Vector2.ZERO,
			Vector2(size.x, 0.0),
			Vector2(size.x, horizon),
			Vector2(0.0, horizon),
		]),
		Color("20242a")
	)
	for index in range(7):
		var x := size.x * (0.08 + float(index) * 0.14)
		var tower_height := size.y * (0.12 + float(index % 3) * 0.035)
		draw_rect(
			Rect2(Vector2(x, horizon - tower_height), Vector2(size.x * 0.075, tower_height)),
			Color("292e34")
		)
		draw_line(
			Vector2(x, horizon - tower_height),
			Vector2(x + size.x * 0.075, horizon - tower_height),
			Color("424950"),
			2.0
		)
	var glow_center := Vector2(size.x * 0.52, size.y * 0.34)
	for ring in range(9, 0, -1):
		var alpha := 0.006 * float(10 - ring)
		draw_circle(glow_center, size.x * 0.035 * float(ring), Color(0.72, 0.74, 0.70, alpha))


func _draw_board() -> void:
	var geometry := _board_geometry()
	var tile_width: float = geometry.tile_width
	var tile_height: float = geometry.tile_height
	for row in range(7):
		for column in range(11):
			if _tile_missing(column, row):
				continue
			var center := _tile_center(column, row, geometry)
			var points := PackedVector2Array([
				center + Vector2(0.0, -tile_height * 0.5),
				center + Vector2(tile_width * 0.5, 0.0),
				center + Vector2(0.0, tile_height * 0.5),
				center + Vector2(-tile_width * 0.5, 0.0),
			])
			var lightness := 0.22 + float((column + row) % 2) * 0.025
			var tile_color := Color(lightness, lightness + 0.01, lightness, 1.0)
			draw_colored_polygon(points, tile_color)
			draw_polyline(points + PackedVector2Array([points[0]]), Color("5a6065"), 1.0, true)


func _draw_units() -> void:
	var geometry := _board_geometry()
	_draw_unit(_tile_center(4, 4, geometry), false, "A")
	_draw_unit(_tile_center(7, 2, geometry), true, "S")
	_draw_unit(_tile_center(8, 4, geometry), true, "S")


func _draw_unit(center: Vector2, enemy: bool, glyph: String) -> void:
	var radius := clampf(size.x / 90.0, 13.0, 23.0)
	var active_enemy := state_id == &"enemy_turn" and enemy
	var outline := Color("f1f1ec") if active_enemy else Color("a5aaad")
	draw_circle(center + Vector2(0.0, radius * 0.75), radius * 0.9, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(center, radius + 4.0, outline)
	draw_circle(center, radius, Color("32373c") if enemy else Color("d2d2ca"))
	var text_color := Color("eeeeea") if enemy else Color("292c2f")
	if _font != null:
		var glyph_width := radius * 1.2
		draw_string(
			_font,
			center + Vector2(-glyph_width * 0.5, radius * 0.35),
			glyph,
			HORIZONTAL_ALIGNMENT_CENTER,
			glyph_width,
			int(radius * 1.05),
			text_color
		)


func _draw_targeting_feedback() -> void:
	if state_id not in [&"targeting_valid", &"targeting_invalid", &"resolving"]:
		return
	var geometry := _board_geometry()
	var selected := _tile_center(7, 2, geometry)
	var valid := state_id != &"targeting_invalid"
	var target_center := selected if valid else _tile_center(9, 0, geometry)
	var radius := clampf(size.x / 72.0, 17.0, 30.0)
	if state_id == &"targeting_invalid":
		TARGET_MARKER.draw(
			self, target_center, TARGET_MARKER.TARGET_INVALID, radius * 1.35
		)
	elif state_id == &"resolving":
		for ring in range(3):
			draw_arc(
				target_center,
				radius + float(ring) * 5.0,
				0.0,
				TAU,
				32,
				Color(0.92, 0.92, 0.88, 0.9 - float(ring) * 0.22),
				2.0
			)
		draw_circle(target_center, radius * 0.55, Color(1.0, 1.0, 0.96, 0.88))
	else:
		TARGET_MARKER.draw(
			self, target_center, TARGET_MARKER.TARGET_VALID, radius * 1.35
		)


func _board_geometry() -> Dictionary:
	var tile_width := clampf(size.x / 15.5, 58.0, 112.0)
	var tile_height := tile_width * 0.46
	return {
		"origin": Vector2(size.x * 0.5, size.y * 0.22),
		"tile_width": tile_width,
		"tile_height": tile_height,
	}


func _tile_center(column: int, row: int, geometry: Dictionary) -> Vector2:
	var tile_width: float = geometry.tile_width
	var tile_height: float = geometry.tile_height
	var origin: Vector2 = geometry.origin
	return origin + Vector2(
		(float(column - row) - 2.0) * tile_width * 0.5,
		float(column + row) * tile_height * 0.5
	)


func _tile_missing(column: int, row: int) -> bool:
	return Vector2i(column, row) in [
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0),
		Vector2i(10, 0), Vector2i(10, 6), Vector2i(0, 6),
	]
