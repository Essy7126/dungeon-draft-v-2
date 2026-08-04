class_name ForestArenaIntegrationDebugView
extends Node2D

const CATEGORY_COLORS := {
	ForestArenaIntegrationMap.CellCategory.PLAYABLE: Color(0.18, 0.88, 0.42, 0.22),
	ForestArenaIntegrationMap.CellCategory.BORDER: Color(1.0, 0.66, 0.14, 0.48),
	ForestArenaIntegrationMap.CellCategory.VOID: Color(0.72, 0.12, 0.18, 0.58),
}
const GRID_COLOR := Color(0.68, 0.93, 1.0, 0.62)

var config: ForestArenaIntegrationConfig = null
var map_model: ForestArenaIntegrationMap = null
var grid: GridData = null
var show_grid := false
var show_categories := false
var show_coordinates := false
var hovered_cell := Vector2i(-1, -1)


func configure(
		integration_config: ForestArenaIntegrationConfig,
		integration_map: ForestArenaIntegrationMap,
		grid_data: GridData
	) -> void:
	config = integration_config
	map_model = integration_map
	grid = grid_data
	queue_redraw()


func set_modes(grid_visible: bool, categories_visible: bool, coordinates_visible: bool) -> void:
	show_grid = grid_visible
	show_categories = categories_visible
	show_coordinates = coordinates_visible
	visible = show_grid or show_categories or show_coordinates
	queue_redraw()


func set_hovered_cell(cell: Vector2i) -> void:
	hovered_cell = cell
	queue_redraw()


func _draw() -> void:
	if config == null or map_model == null or grid == null:
		return
	for cell in map_model.all_cells():
		var polygon := config.cell_polygon(cell)
		if show_categories:
			draw_colored_polygon(polygon, CATEGORY_COLORS[map_model.get_category(cell)])
		if show_grid:
			_draw_outline(polygon, GRID_COLOR, 1.0)
		if show_coordinates:
			draw_string(
				ThemeDB.fallback_font, config.cell_to_screen(cell) + Vector2(-13, 3),
				"%d,%d" % [cell.x, cell.y], HORIZONTAL_ALIGNMENT_CENTER,
				26, 9, Color.WHITE
			)
		var state := map_model.get_state(cell)
		if show_categories and str(state.wall) != "NONE":
			draw_circle(config.cell_to_screen(cell), 7.0, Color("ff543f"))
		if show_categories:
			match str(state.special):
				"ALLY_SPAWN":
					draw_circle(config.cell_to_screen(cell), 5.0, Color("4aa8ff"))
				"ENEMY_SPAWN":
					draw_circle(config.cell_to_screen(cell), 5.0, Color("ff5d55"))
				"OBJECTIVE":
					draw_circle(config.cell_to_screen(cell), 5.0, Color("ffd75a"))
				"DECOR_ANCHOR":
					draw_circle(config.cell_to_screen(cell), 4.0, Color("76e49b"))
	if map_model.get_category(hovered_cell) == ForestArenaIntegrationMap.CellCategory.PLAYABLE:
		draw_colored_polygon(config.cell_polygon(hovered_cell), Color(0.2, 0.88, 1.0, 0.34))
		_draw_outline(config.cell_polygon(hovered_cell), Color(0.5, 0.96, 1.0), 2.0)
	if show_coordinates:
		for index in range(mini(config.calibration_cells.size(), config.calibration_pixels.size())):
			var predicted := config.cell_to_screen(config.calibration_cells[index])
			var measured := config.calibration_pixels[index]
			draw_line(predicted, measured, Color.RED, 2.0)
			draw_circle(measured, 3.5, Color.YELLOW)


func _draw_outline(polygon: PackedVector2Array, color: Color, width: float) -> void:
	if polygon.is_empty():
		return
	var closed := PackedVector2Array(polygon)
	closed.append(polygon[0])
	draw_polyline(closed, color, width, true)
