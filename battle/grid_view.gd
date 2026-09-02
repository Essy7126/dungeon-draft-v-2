# battle/grid_view.gd
# ============================================================
# GRID VIEW — Affichage de la grille (top-down carré).
# LIT les données de GridData, ne les modifie jamais.
# ============================================================

extends Node2D

const CELL_SIZE = 64
const HIGHLIGHT_MARKER := preload("res://battle/combat_highlight_marker.gd")

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
var _cell_feedback_markers: Dictionary = {}
var _hovered: Vector2i = Vector2i(-1, -1)
var show_terrain_colors: bool = false
var show_grid_lines: bool = false

signal cell_clicked(grid_pos: Vector2i)
signal cell_hovered(grid_pos: Vector2i)

func setup(grid_data: GridData) -> void:
	grid = grid_data
	_cell_feedback_markers.clear()
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

func highlight(
	positions: Array,
	color: Color,
	marker: StringName = &""
	) -> void:
	for pos in positions:
		_highlights[pos] = HIGHLIGHT_MARKER.entry(color, marker)
	queue_redraw()


func get_highlight_snapshot() -> Dictionary:
	return _highlights.duplicate(true)

func clear_highlights() -> void:
	_highlights.clear()
	queue_redraw()


# --- Feedback de ciblage (couche au-dessus du hover) ---

func set_cell_feedback_marker(
	cell: Vector2i,
	is_valid_target: bool,
	color: Color = Color(0.97, 0.97, 0.91, 0.94)
	) -> void:
	if grid == null or not grid.is_valid(cell):
		return
	_cell_feedback_markers[cell] = HIGHLIGHT_MARKER.feedback_entry(
		is_valid_target,
		color,
	)
	queue_redraw()


func clear_cell_feedback_marker(cell: Vector2i) -> void:
	if not _cell_feedback_markers.erase(cell):
		return
	queue_redraw()


func clear_cell_feedback_markers() -> void:
	if _cell_feedback_markers.is_empty():
		return
	_cell_feedback_markers.clear()
	queue_redraw()


func get_cell_feedback_snapshot() -> Dictionary:
	return _cell_feedback_markers.duplicate(true)

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
				var highlight_value = _highlights[pos]
				draw_rect(
					rect,
					HIGHLIGHT_MARKER.color_of(highlight_value),
					true,
				)
				HIGHLIGHT_MARKER.draw(
					self,
					rect.get_center(),
					HIGHLIGHT_MARKER.marker_of(highlight_value),
					CELL_SIZE * 0.32,
				)

			# Effet de terrain dynamique : toujours, avec couleur propre a l'effet.
			var stored_effect = grid.get_effect(pos)
			if stored_effect != null:
				var effect_color := Color(1, 0.8, 0.2, 0.26)
				if stored_effect.has("data") and stored_effect["data"].has("data"):
					var effect_data: TerrainEffectData = stored_effect["data"]["data"]
					if effect_data != null:
						effect_color = effect_data.color
						effect_color.a = 0.34
				draw_rect(rect, effect_color, true)

			# Survol souris : toujours.
			if pos == _hovered and grid.is_valid(_hovered):
				draw_rect(rect, Color(1, 1, 1, 0.10), true)

			# Liseré de grille : optionnel.
			if show_grid_lines:
				draw_rect(rect, Color(1, 1, 1, 0.10), false)

	# Le feedback de cible est volontairement dessine apres portees, effets,
	# hover et grille afin que sa forme reste lisible avec n'importe quelle teinte.
	for cell in _cell_feedback_markers:
		if cell is Vector2i and grid.is_valid(cell):
			HIGHLIGHT_MARKER.draw_feedback(
				self,
				grid_to_world(cell),
				_cell_feedback_markers[cell],
				CELL_SIZE * 0.36,
			)
	
