extends GutTest

const IsoGridViewScript = preload("res://battle/iso/iso_grid_view.gd")
const EPSILON := 0.001

var grid: GridData
var view: IsoGridView


func before_each() -> void:
	grid = GridData.new(20, 14)
	view = IsoGridViewScript.new()
	add_child_autofree(view)
	view.setup(grid)


func test_round_trip_des_cellules_representatives() -> void:
	var cells := [
		Vector2i(0, 0),
		Vector2i(19, 0),
		Vector2i(0, 13),
		Vector2i(19, 13),
		Vector2i(5, 5),
		Vector2i(10, 7),
		Vector2i(18, 12),
	]
	for cell in cells:
		assert_eq(view.local_to_grid(view.grid_to_local(cell)), cell)


func test_round_trip_geometrique_des_coordonnees_negatives() -> void:
	var cells := [
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(-4, 2),
		Vector2i(3, -5),
	]
	for cell in cells:
		assert_eq(view.local_to_grid(view.grid_to_local(cell)), cell)
		assert_false(grid.is_valid(cell))


func test_orientation_des_axes_logiques() -> void:
	var origin := view.grid_to_local(Vector2i.ZERO)
	var positive_x := view.grid_to_local(Vector2i(1, 0))
	var positive_y := view.grid_to_local(Vector2i(0, 1))
	assert_gt(positive_x.x, origin.x, "+X doit aller vers la droite")
	assert_gt(positive_x.y, origin.y, "+X doit aller vers le bas")
	assert_lt(positive_y.x, origin.x, "+Y doit aller vers la gauche")
	assert_gt(positive_y.y, origin.y, "+Y doit aller vers le bas")


func test_points_clairement_interieurs_au_losange() -> void:
	for cell in [Vector2i(0, 0), Vector2i(5, 5), Vector2i(18, 12)]:
		var center := view.grid_to_local(cell)
		var polygon := view.get_cell_polygon(cell)
		var inside_points := [
			center,
			center.lerp(polygon[0], 0.35),
			center.lerp(polygon[1], 0.35),
			center.lerp(polygon[2], 0.35),
			center.lerp(polygon[3], 0.35),
		]
		for point in inside_points:
			assert_eq(view.local_to_grid(point), cell)


func test_bounds_contiennent_les_polygones_des_quatre_extremes() -> void:
	var bounds := view.get_map_bounds()
	var extreme_cells := [
		Vector2i(0, 0),
		Vector2i(19, 0),
		Vector2i(0, 13),
		Vector2i(19, 13),
	]
	for cell in extreme_cells:
		for point in view.get_cell_polygon(cell):
			assert_true(point.x >= bounds.position.x - EPSILON)
			assert_true(point.y >= bounds.position.y - EPSILON)
			assert_true(point.x <= bounds.end.x + EPSILON)
			assert_true(point.y <= bounds.end.y + EPSILON)


func test_tileset_isometrique_utilise_un_footprint_64_par_32() -> void:
	var tile_set := view.get_geometry_layer().tile_set
	assert_not_null(tile_set)
	assert_eq(tile_set.tile_size, Vector2i(64, 32))
	assert_eq(tile_set.tile_shape, TileSet.TILE_SHAPE_ISOMETRIC)
	assert_eq(tile_set.tile_layout, TileSet.TILE_LAYOUT_DIAMOND_DOWN)


func test_interactions_visuelles_ne_modifient_pas_grid_data() -> void:
	var terrain_cell := Vector2i(1, 1)
	var effect_cell := Vector2i(2, 2)
	grid.set_type(terrain_cell, GridData.CellType.WALL)
	grid.set_effect(effect_cell, "test", {"duration": 3})
	var type_before := grid.get_type(terrain_cell)
	var effect_before: Dictionary = grid.get_effect(effect_cell).duplicate(true)

	view.update_hover(view.grid_to_local(Vector2i(3, 3)))
	view.click_at(view.grid_to_local(Vector2i(4, 4)))
	view.set_selected_cell(Vector2i(5, 5))
	view.highlight([Vector2i(6, 6), Vector2i(7, 7)], Color.RED)
	view.clear_highlights()

	assert_eq(grid.get_type(terrain_cell), type_before)
	assert_eq(grid.get_effect(effect_cell), effect_before)
	assert_false(grid.has_unit(Vector2i(3, 3)))
	assert_false(grid.has_unit(Vector2i(4, 4)))
	assert_false(grid.has_unit(Vector2i(5, 5)))


func test_transform_du_tilemaplayer_ne_casse_pas_les_conversions() -> void:
	var layer := view.get_geometry_layer()
	layer.position = Vector2(137.0, -42.0)
	layer.rotation = 0.17
	layer.scale = Vector2(1.25, 0.80)

	for cell in [
		Vector2i(0, 0),
		Vector2i(19, 13),
		Vector2i(10, 7),
		Vector2i(-2, 3),
	]:
		assert_eq(view.local_to_grid(view.grid_to_local(cell)), cell)
