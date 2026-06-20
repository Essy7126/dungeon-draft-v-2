# battle/grid_view.gd
# ============================================================
# GRID VIEW — Affichage de la grille (top-down carré).
# LIT les données de GridData, ne les modifie jamais.
# ============================================================

extends Node2D

const CELL_SIZE = 64

const TYPE_COLORS = {
	GridData.CellType.NORMAL : Color(0.16, 0.16, 0.20),
	GridData.CellType.WALL   : Color(0.30, 0.26, 0.22),
	GridData.CellType.HOLE   : Color(0.04, 0.04, 0.07),
	GridData.CellType.LAVA   : Color(0.70, 0.22, 0.06),
	GridData.CellType.ICE    : Color(0.50, 0.75, 0.90),
	GridData.CellType.SHADOW : Color(0.10, 0.09, 0.16),
	GridData.CellType.RUNE   : Color(0.45, 0.14, 0.65),
}

var grid: GridData
var _highlights: Dictionary = {}
var _hovered: Vector2i = Vector2i(-1, -1)
var show_terrain_colors: bool = false
var show_grid_lines: bool = false

signal cell_clicked(grid_pos: Vector2i)
signal cell_hovered(grid_pos: Vector2i)

func setup(grid_data: GridData) -> void:
	grid = grid_data
	queue_redraw()

# --- Conversions ---

func grid_to_world(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * CELL_SIZE + CELL_SIZE / 2.0,
				   pos.y * CELL_SIZE + CELL_SIZE / 2.0)

func grid_to_corner(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / CELL_SIZE), int(world_pos.y / CELL_SIZE))

func get_pixel_size() -> Vector2:
	if grid == null:
		return Vector2.ZERO
	return Vector2(grid.cols * CELL_SIZE, grid.rows * CELL_SIZE)

# --- Highlights ---

func highlight(positions: Array, color: Color) -> void:
	for pos in positions:
		_highlights[pos] = color
	queue_redraw()

func clear_highlights() -> void:
	_highlights.clear()
	queue_redraw()

# --- Input souris ---

func _unhandled_input(event: InputEvent) -> void:
	if grid == null:
		return

	if event is InputEventMouseMotion:
		var cell = world_to_grid(get_local_mouse_position())
		if cell != _hovered:
			_hovered = cell
			queue_redraw()
			if grid.is_valid(cell):
				cell_hovered.emit(cell)

	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var cell = world_to_grid(get_local_mouse_position())
		if grid.is_valid(cell):
			cell_clicked.emit(cell)

# --- Dessin ---

func _draw() -> void:
	if grid == null:
		return

	for x in grid.cols:
		for y in grid.rows:
			var pos = Vector2i(x, y)
			var corner = grid_to_corner(pos)
			var rect = Rect2(corner, Vector2(CELL_SIZE, CELL_SIZE))

			# Sol/mur en rectangles : seulement si activé (debug sans TileMap).
			if show_terrain_colors:
				draw_rect(rect, TYPE_COLORS[grid.get_type(pos)], true)

			# Surbrillances de gameplay : toujours.
			if _highlights.has(pos):
				draw_rect(rect, _highlights[pos], true)

			# Effet de terrain dynamique : toujours.
			if grid.get_effect(pos) != null:
				draw_rect(rect, Color(1, 0.8, 0.2, 0.2), true)

			# Survol souris : toujours.
			if pos == _hovered and grid.is_valid(_hovered):
				draw_rect(rect, Color(1, 1, 1, 0.10), true)

			# Liseré de grille : optionnel.
			if show_grid_lines:
				draw_rect(rect, Color(1, 1, 1, 0.10), false)
	
