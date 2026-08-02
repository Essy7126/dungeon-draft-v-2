extends GutTest

const HubNavigationGridScript = preload("res://hub/hub_navigation_grid.gd")
const HubGridOverlayScript = preload("res://hub/hub_grid_overlay.gd")
const START_HUB_SCENE: PackedScene = preload("res://hub/StartHub.tscn")


func test_projection_du_hub_conserve_orientation_et_aller_retour() -> void:
	var grid := HubNavigationGridScript.new()
	var overlay := HubGridOverlayScript.new()
	add_child_autofree(grid)
	add_child_autofree(overlay)
	overlay.setup(grid)
	var origin := overlay.cell_to_world(Vector2i.ZERO)
	var positive_x := overlay.cell_to_world(Vector2i.RIGHT)
	var positive_y := overlay.cell_to_world(Vector2i.DOWN)
	assert_eq(origin, Vector2(1024.0, 640.0))
	assert_gt(positive_x.x, origin.x)
	assert_gt(positive_x.y, origin.y)
	assert_lt(positive_y.x, origin.x)
	assert_gt(positive_y.y, origin.y)
	for cell in [Vector2i.ZERO, Vector2i(2, 2), Vector2i(10, 5), Vector2i(14, 14), Vector2i(19, 19)]:
		assert_eq(overlay.world_to_cell(overlay.cell_to_world(cell)), cell)
	assert_eq(
		overlay.screen_to_cell(overlay.cell_to_world(Vector2i(8, 8))),
		Vector2i(8, 8),
		"ecran -> cellule utilise le CanvasTransform courant"
	)


func test_navigation_reste_vector2i_et_strictement_orthogonale() -> void:
	var grid := HubNavigationGridScript.new()
	add_child_autofree(grid)
	grid.rebuild()
	var origin := Vector2i(8, 12)
	assert_true(grid.is_walkable(origin))
	for neighbor in grid.get_orthogonal_neighbors(origin):
		var distance := absi(origin.x - neighbor.x) + absi(origin.y - neighbor.y)
		assert_eq(distance, 1)


func test_obstacles_calibres_et_marqueurs_praticables() -> void:
	var hub := START_HUB_SCENE.instantiate()
	add_child_autofree(hub)
	await get_tree().process_frame
	var grid: HubNavigationGrid = hub.get_node("NavigationGrid")
	assert_true(grid.is_blocked(Vector2i(0, 0)), "mur/zone hors sol")
	assert_true(grid.is_blocked(Vector2i(2, 8)), "table strategique")
	assert_true(grid.is_blocked(Vector2i(8, 2)), "comptoir")
	assert_true(grid.is_blocked(Vector2i(11, 19)), "cristal gauche")
	assert_true(grid.is_blocked(Vector2i(19, 11)), "cristal droit")
	for marker_name in [
		"PlayerSpawn",
		"MerchantApproach",
		"StrategyTableApproach",
		"DungeonPortalApproach",
	]:
		var marker: HubTechnicalMarker = grid.get_node(marker_name)
		assert_true(grid.is_walkable(marker.cell), "%s doit rester praticable" % marker_name)


func test_scene_respecte_la_hierarchie_et_reutilise_visuel_elfe() -> void:
	var hub := START_HUB_SCENE.instantiate()
	add_child_autofree(hub)
	await get_tree().process_frame
	assert_not_null(hub.get_node("HubController"))
	assert_not_null(hub.get_node("WorldRoot/Background"))
	assert_not_null(hub.get_node("WorldRoot/GridOverlay"))
	assert_not_null(hub.get_node("WorldRoot/SortableWorld/Player"))
	assert_not_null(hub.get_node("WorldRoot/Foreground"))
	assert_not_null(hub.get_node("NavigationGrid"))
	assert_not_null(hub.get_node("CameraRig/Camera2D"))
	assert_not_null(hub.get_node("HubUI"))
	var player := hub.get_node("WorldRoot/SortableWorld/Player")
	assert_eq(player.scene_file_path, "res://hub/HubElfPreview.tscn")
	var sprite: Sprite2D = player.get_node("Sprite")
	assert_true(sprite.texture is AtlasTexture)
	assert_eq((sprite.texture as AtlasTexture).atlas.resource_path, "res://asset/Soldier.png")
	var background: Sprite2D = hub.get_node("WorldRoot/Background")
	assert_eq(background.texture.get_size(), Vector2(2048.0, 2048.0))


func test_coordonnees_des_quatre_marqueurs() -> void:
	var hub := START_HUB_SCENE.instantiate()
	add_child_autofree(hub)
	await get_tree().process_frame
	var grid := hub.get_node("NavigationGrid")
	assert_eq(grid.get_node("PlayerSpawn").cell, Vector2i(14, 14))
	assert_eq(grid.get_node("MerchantApproach").cell, Vector2i(10, 5))
	assert_eq(grid.get_node("StrategyTableApproach").cell, Vector2i(5, 10))
	assert_eq(grid.get_node("DungeonPortalApproach").cell, Vector2i(2, 2))
