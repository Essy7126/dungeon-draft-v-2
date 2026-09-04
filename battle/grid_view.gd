# battle/grid_view.gd
# ============================================================
# GRID VIEW — Affichage de la grille (top-down carré).
# LIT les données de GridData, ne les modifie jamais.
# ============================================================

extends Node2D

const CELL_SIZE = 64
const INVALID_CELL := Vector2i(-1, -1)
const HIGHLIGHT_MARKER := preload("res://battle/combat_highlight_marker.gd")

# Les aplats indiquent une zone disponible sans masquer le terrain. La forme
# semantique et le contour portent l'information tactique principale.
const RANGE_FILL_ALPHA_SCALE := 0.52
const RANGE_FILL_ALPHA_MAX := 0.24
const RANGE_OUTLINE_ALPHA_MIN := 0.58
const RANGE_OUTLINE_ALPHA_MAX := 0.86
const RANGE_OUTLINE_WIDTH := 1.5
const HOVER_FILL_COLOR := Color(0.35, 0.88, 1.0, 0.10)
const HOVER_LINE_COLOR := Color(0.48, 0.94, 1.0, 0.92)
const HOVER_OUTLINE_WIDTH := 1.5
const SELECTED_FILL_COLOR := Color(1.0, 0.70, 0.18, 0.16)
const SELECTED_LINE_COLOR := Color(1.0, 0.78, 0.28, 1.0)
const SELECTED_OUTLINE_WIDTH := 2.5
const CURSOR_FILL_COLOR := Color(1.0, 0.96, 0.78, 0.08)
const CURSOR_LINE_COLOR := Color(1.0, 0.96, 0.78, 1.0)
const CURSOR_SHADOW_COLOR := Color(0.015, 0.02, 0.025, 0.9)
const CURSOR_LINE_WIDTH := 2.5
const CURSOR_SHADOW_WIDTH := 5.0
const TARGET_FILL_ALPHA_MAX := 0.14
const TARGET_OUTLINE_WIDTH := 3.0

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
var _hovered_cell: Vector2i = INVALID_CELL
var _selected_cell: Vector2i = INVALID_CELL
var _cursor_cell: Vector2i = INVALID_CELL
var show_terrain_colors: bool = false
var show_grid_lines: bool = false

signal cell_clicked(grid_pos: Vector2i)
signal cell_hovered(grid_pos: Vector2i)
signal spatial_cursor_released

func setup(grid_data: GridData) -> void:
	grid = grid_data
	_hovered_cell = INVALID_CELL
	_selected_cell = INVALID_CELL
	_cursor_cell = INVALID_CELL
	_highlights.clear()
	_cell_feedback_markers.clear()
	queue_redraw()


func get_hovered_cell() -> Vector2i:
	return _hovered_cell


func get_selected_cell() -> Vector2i:
	return _selected_cell


func set_selected_cell(cell: Vector2i) -> void:
	if grid == null or not grid.is_terrain_interactable(cell) \
			or _selected_cell == cell:
		return
	_selected_cell = cell
	queue_redraw()


func clear_selection() -> void:
	if _selected_cell == INVALID_CELL:
		return
	_selected_cell = INVALID_CELL
	queue_redraw()


## Focus spatial reserve au clavier et a la manette. Il ne modifie ni le
## survol souris, ni la cellule effectivement selectionnee.
func set_cursor_cell(cell: Vector2i) -> bool:
	if grid == null or not grid.is_terrain_interactable(cell):
		return false
	if _cursor_cell == cell:
		return true
	_cursor_cell = cell
	queue_redraw()
	return true


func clear_cursor() -> void:
	if _cursor_cell == INVALID_CELL:
		return
	_cursor_cell = INVALID_CELL
	queue_redraw()


func get_cursor_cell() -> Vector2i:
	return _cursor_cell


func _release_spatial_cursor_to_pointer() -> void:
	if _cursor_cell == INVALID_CELL:
		return
	clear_cursor()
	spatial_cursor_released.emit()

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
	if grid == null:
		return
	for pos in positions:
		if pos is Vector2i and grid.is_terrain_interactable(pos):
			_highlights[pos] = HIGHLIGHT_MARKER.entry(color, marker)
	queue_redraw()


func get_highlight_snapshot() -> Dictionary:
	return _highlights.duplicate(true)

func clear_highlights() -> void:
	if _highlights.is_empty():
		return
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

func update_hover(local_position: Vector2) -> Vector2i:
	var cell := _valid_cell_at(local_position)
	if cell != _hovered_cell:
		_hovered_cell = cell
		queue_redraw()
		cell_hovered.emit(cell)
	return cell


func click_at(local_position: Vector2) -> Vector2i:
	var cell := _valid_cell_at(local_position)
	if cell != INVALID_CELL:
		set_selected_cell(cell)
		cell_clicked.emit(cell)
	return cell


func _unhandled_input(event: InputEvent) -> void:
	if grid == null:
		return

	if event is InputEventMouseMotion:
		if not event.relative.is_zero_approx():
			_release_spatial_cursor_to_pointer()
		update_hover(get_local_mouse_position())

	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		click_at(get_local_mouse_position())


func _valid_cell_at(local_position: Vector2) -> Vector2i:
	var candidate := world_to_grid(local_position)
	if grid != null and grid.is_terrain_interactable(candidate):
		return candidate
	return INVALID_CELL

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
				draw_rect(rect, _range_fill_color(highlight_value), true)
				draw_rect(
					rect.grow(-1.0),
					_range_outline_color(highlight_value),
					false,
					RANGE_OUTLINE_WIDTH,
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

			# Liseré de grille : optionnel.
			if show_grid_lines:
				draw_rect(rect, Color(1, 1, 1, 0.10), false)

	# Les etats d'interaction restent independants. Leur ordre rend la selection
	# plus forte que le hover, puis le curseur clavier/manette plus prioritaire.
	if grid.is_terrain_interactable(_hovered_cell):
		var hovered_rect := Rect2(
			grid_to_corner(_hovered_cell), Vector2(CELL_SIZE, CELL_SIZE)
		)
		draw_rect(hovered_rect, HOVER_FILL_COLOR, true)
		draw_rect(
			hovered_rect.grow(-1.0),
			HOVER_LINE_COLOR,
			false,
			HOVER_OUTLINE_WIDTH,
		)

	if grid.is_terrain_interactable(_selected_cell):
		var selected_rect := Rect2(
			grid_to_corner(_selected_cell), Vector2(CELL_SIZE, CELL_SIZE)
		)
		draw_rect(selected_rect, SELECTED_FILL_COLOR, true)
		draw_rect(
			selected_rect.grow(-2.0),
			SELECTED_LINE_COLOR,
			false,
			SELECTED_OUTLINE_WIDTH,
		)

	if grid.is_terrain_interactable(_cursor_cell):
		_draw_cursor_rect(Rect2(
			grid_to_corner(_cursor_cell), Vector2(CELL_SIZE, CELL_SIZE)
		))

	# Le feedback de cible est volontairement dessine en dernier : la cible
	# primaire et son symbole restent dominants sur toutes les portees.
	for cell in _cell_feedback_markers:
		if cell is Vector2i and grid.is_valid(cell):
			var feedback_rect := Rect2(
				grid_to_corner(cell), Vector2(CELL_SIZE, CELL_SIZE)
			).grow(-2.0)
			var feedback_value := _cell_feedback_markers[cell] as Dictionary
			var feedback_color := HIGHLIGHT_MARKER.color_of(feedback_value)
			draw_rect(
				feedback_rect,
				_with_alpha(feedback_color, minf(
					feedback_color.a * 0.16, TARGET_FILL_ALPHA_MAX
				)),
				true,
			)
			draw_rect(
				feedback_rect,
				_with_alpha(feedback_color, maxf(feedback_color.a, 0.86)),
				false,
				TARGET_OUTLINE_WIDTH,
			)
			HIGHLIGHT_MARKER.draw_feedback(
				self,
				grid_to_world(cell),
				feedback_value,
				CELL_SIZE * 0.42,
			)


func _range_fill_color(value) -> Color:
	var color := HIGHLIGHT_MARKER.color_of(value)
	color.a = minf(color.a * RANGE_FILL_ALPHA_SCALE, RANGE_FILL_ALPHA_MAX)
	return color


func _range_outline_color(value) -> Color:
	var color := HIGHLIGHT_MARKER.color_of(value)
	if color.a <= 0.0:
		return Color.TRANSPARENT
	color = color.lightened(0.16)
	color.a = clampf(
		color.a * 1.65,
		RANGE_OUTLINE_ALPHA_MIN,
		RANGE_OUTLINE_ALPHA_MAX,
	)
	return color


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))


func _draw_cursor_rect(rect: Rect2) -> void:
	draw_rect(rect, CURSOR_FILL_COLOR, true)
	var inset_rect := rect.grow(-4.0)
	var corners := PackedVector2Array([
		inset_rect.position,
		Vector2(inset_rect.end.x, inset_rect.position.y),
		inset_rect.end,
		Vector2(inset_rect.position.x, inset_rect.end.y),
	])
	_draw_cursor_corners(corners, inset_rect.get_center())


func _draw_cursor_corners(
	polygon: PackedVector2Array,
	center: Vector2
	) -> void:
	if polygon.size() < 3:
		return
	for index in polygon.size():
		var corner := polygon[index]
		var previous := polygon[(index - 1 + polygon.size()) % polygon.size()]
		var next := polygon[(index + 1) % polygon.size()]
		for endpoint in [corner.lerp(previous, 0.27), corner.lerp(next, 0.27)]:
			draw_line(
				corner, endpoint, CURSOR_SHADOW_COLOR, CURSOR_SHADOW_WIDTH, true
			)
			draw_line(
				corner, endpoint, CURSOR_LINE_COLOR, CURSOR_LINE_WIDTH, true
			)
	draw_circle(center, 3.8, CURSOR_SHADOW_COLOR)
	draw_circle(center, 2.2, CURSOR_LINE_COLOR)
