extends GutTest

const IsoProjectionScript = preload("res://battle/iso/iso_projection.gd")

var projection: IsoProjection


func before_each() -> void:
	projection = IsoProjectionScript.new()


func test_grid_to_world_convertit_plusieurs_cellules() -> void:
	assert_eq(projection.grid_to_world(Vector2i(0, 0)), Vector2(0.0, 0.0))
	assert_eq(projection.grid_to_world(Vector2i(1, 0)), Vector2(64.0, 32.0))
	assert_eq(projection.grid_to_world(Vector2i(0, 1)), Vector2(-64.0, 32.0))
	assert_eq(projection.grid_to_world(Vector2i(3, 2)), Vector2(64.0, 160.0))
	assert_eq(projection.grid_to_world(Vector2i(7, 4)), Vector2(192.0, 352.0))


func test_aller_retour_grid_world_grid() -> void:
	var cells := [
		Vector2i(0, 0),
		Vector2i(1, 5),
		Vector2i(4, 2),
		Vector2i(9, 7),
	]
	for cell in cells:
		assert_eq(projection.world_to_grid(projection.grid_to_world(cell)), cell)


func test_aller_retour_des_quatre_coins_de_la_grille() -> void:
	var corners := [
		Vector2i(0, 0),
		Vector2i(9, 0),
		Vector2i(0, 7),
		Vector2i(9, 7),
	]
	for corner in corners:
		assert_eq(projection.world_to_grid(projection.grid_to_world(corner)), corner)
	assert_eq(projection.get_map_bounds(10, 8), Rect2(-512.0, -32.0, 1152.0, 576.0))


func test_coordonnees_negatives() -> void:
	var expected := {
		Vector2i(-1, 0): Vector2(-64.0, -32.0),
		Vector2i(0, -1): Vector2(64.0, -32.0),
		Vector2i(-3, -2): Vector2(-64.0, -160.0),
		Vector2i(-4, 2): Vector2(-384.0, -64.0),
	}
	for cell in expected:
		var world_pos: Vector2 = expected[cell]
		assert_eq(projection.grid_to_world(cell), world_pos)
		assert_eq(projection.world_to_grid(world_pos), cell)


func test_origine_non_nulle() -> void:
	projection.grid_origin = Vector2(320.0, 180.0)
	assert_eq(projection.grid_to_world(Vector2i(0, 0)), Vector2(320.0, 180.0))
	assert_eq(projection.grid_to_world(Vector2i(2, 1)), Vector2(384.0, 276.0))
	assert_eq(projection.world_to_grid(Vector2(384.0, 276.0)), Vector2i(2, 1))
	assert_eq(
		projection.get_map_bounds(10, 8),
		Rect2(-192.0, 148.0, 1152.0, 576.0)
	)


func test_clics_proches_des_quatre_bordures_restent_dans_la_cellule() -> void:
	var cell := Vector2i(3, 2)
	var center := projection.grid_to_world(cell)
	var points_inside := [
		center + Vector2(31.9, -15.9),
		center + Vector2(31.9, 15.9),
		center + Vector2(-31.9, 15.9),
		center + Vector2(-31.9, -15.9),
		center + Vector2(0.0, -31.9),
		center + Vector2(63.9, 0.0),
		center + Vector2(0.0, 31.9),
		center + Vector2(-63.9, 0.0),
	]
	for point in points_inside:
		assert_eq(projection.world_to_grid(point), cell)
