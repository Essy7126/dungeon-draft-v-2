extends Node2D

const TILE_HALF := Vector2(48.0, 24.0)

@export var grid_size := Vector2i(9, 7)

var highlight_cells: Array[Vector2i] = []
var highlight_color := Color("ff9f32")


func grid_to_local(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x - cell.y) * TILE_HALF.x,
		float(cell.x + cell.y) * TILE_HALF.y
	)


func set_highlights(cells: Array[Vector2i], color: Color) -> void:
	highlight_cells = cells.duplicate()
	highlight_color = color
	queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	# Ombre generale du plateau.
	var board_center := grid_to_local(Vector2i(grid_size.x / 2, grid_size.y / 2))
	_draw_ellipse_polygon(board_center + Vector2(0.0, 34.0), 390.0, 174.0, Color(0.0, 0.0, 0.0, 0.42), 48)
	for diagonal in range(grid_size.x + grid_size.y - 1):
		for x in grid_size.x:
			var y := diagonal - x
			if y < 0 or y >= grid_size.y:
				continue
			var cell := Vector2i(x, y)
			var center := grid_to_local(cell)
			var diamond := _diamond(center)
			var checker := (x + y) % 2
			var base := Color("172a36") if checker == 0 else Color("1b303c")
			var edge := Color(0.29, 0.49, 0.59, 0.34)
			draw_colored_polygon(diamond.slice(0, 4), base)
			draw_polyline(diamond, edge, 1.35, true)
			if highlight_cells.has(cell):
				var fill := highlight_color
				fill.a = 0.13
				var outline := highlight_color
				outline.a = 0.82
				draw_colored_polygon(diamond.slice(0, 4), fill)
				draw_polyline(diamond, outline, 2.2, true)
		# Fin liseré le long des diagonales pour conserver la lecture iso.
		if diagonal % 2 == 0:
			var shimmer := Color(0.38, 0.7, 0.78, 0.025)
			draw_line(
				grid_to_local(Vector2i(maxi(0, diagonal - grid_size.y + 1), mini(diagonal, grid_size.y - 1))),
				grid_to_local(Vector2i(mini(diagonal, grid_size.x - 1), maxi(0, diagonal - grid_size.x + 1))),
				shimmer,
				2.0,
				true
			)


func _diamond(center: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -TILE_HALF.y),
		center + Vector2(TILE_HALF.x, 0.0),
		center + Vector2(0.0, TILE_HALF.y),
		center + Vector2(-TILE_HALF.x, 0.0),
		center + Vector2(0.0, -TILE_HALF.y),
	])


func _draw_ellipse_polygon(
		center: Vector2,
		radius_x: float,
		radius_y: float,
		color: Color,
		segments: int
) -> void:
	var points := PackedVector2Array()
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_colored_polygon(points, color)
