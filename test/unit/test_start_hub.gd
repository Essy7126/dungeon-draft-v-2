extends GutTest

const HubNavigationGridScript = preload("res://hub/hub_navigation_grid.gd")
const HubGridOverlayScript = preload("res://hub/hub_grid_overlay.gd")
const START_HUB_SCENE: PackedScene = preload("res://hub/StartHub.tscn")


func test_projection_du_hub_conserve_orientation_et_aller_retour() -> void:
	var grid := HubNavigationGridScript.new()
	var overlay := HubGridOverlayScript.new()
	add_child_autofree(overlay)
	grid.rebuild()
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


func test_navigation_autorise_huit_directions_sans_couper_les_angles() -> void:
	var grid := HubNavigationGridScript.new()
	grid.rebuild()
	var origin := Vector2i(8, 12)
	assert_true(grid.is_walkable(origin))
	var neighbors := grid.get_neighbors(origin)
	assert_eq(neighbors.size(), 8)
	assert_has(neighbors, origin + Vector2i(1, 1))
	assert_true(grid.can_traverse(origin, origin + Vector2i(1, 1)))
	assert_almost_eq(
		grid.get_path_cost([origin, origin + Vector2i(1, 1)]),
		HubNavigationGrid.DIAGONAL_COST,
		0.00001,
	)
	grid.blocked_cells = [origin + Vector2i.RIGHT]
	grid.rebuild()
	assert_false(
		grid.can_traverse(origin, origin + Vector2i(1, 1)),
		"une diagonale ne traverse pas le coin d'une cellule bloquee",
	)


func test_obstacles_calibres_et_marqueurs_praticables() -> void:
	var hub := START_HUB_SCENE.instantiate()
	add_child_autofree(hub)
	await get_tree().process_frame
	var grid_node: HubNavigationGridNode = hub.get_node("NavigationGrid")
	var grid: HubNavigationGrid = grid_node.model
	var navigation_region: HubNavigationRegion2D = hub.get_node(
		"WorldRoot/NavigationRegion2D"
	)
	assert_true(grid.is_blocked(Vector2i(0, 0)), "mur/zone hors sol")
	assert_true(grid.is_blocked(Vector2i(2, 8)), "table strategique")
	assert_true(grid.is_blocked(Vector2i(8, 2)), "comptoir")
	assert_true(grid.is_blocked(Vector2i(11, 19)), "cristal gauche")
	assert_true(grid.is_blocked(Vector2i(19, 11)), "cristal droit")
	for blocked_world_position in [
		Vector2(100.0, 500.0),
		Vector2(560.0, 950.0),
		Vector2(1450.0, 950.0),
		Vector2(500.0, 1800.0),
		Vector2(1550.0, 1800.0),
		Vector2(640.0, 1152.0),
	]:
		assert_false(
			navigation_region.is_world_position_navigable(blocked_world_position),
			"obstacle monde exclu : %s" % blocked_world_position,
		)
	for marker_name in [
		"PlayerSpawn",
		"MerchantApproach",
		"StrategyTableApproach",
		"DungeonPortalApproach",
	]:
		var marker: HubTechnicalMarker = grid_node.get_node(marker_name)
		assert_true(grid.is_walkable(marker.cell), "%s doit rester praticable" % marker_name)
		assert_true(
			navigation_region.is_world_position_navigable(marker.global_position),
			"%s doit etre dans le polygone navigable" % marker_name,
		)


func test_scene_respecte_la_hierarchie_et_reutilise_visuel_elfe() -> void:
	var hub := START_HUB_SCENE.instantiate()
	add_child_autofree(hub)
	await get_tree().process_frame
	assert_not_null(hub.get_node("HubController"))
	assert_not_null(hub.get_node("WorldRoot/Background"))
	assert_not_null(hub.get_node("WorldRoot/GridOverlay"))
	assert_not_null(hub.get_node("WorldRoot/NavigationRegion2D"))
	assert_not_null(hub.get_node("WorldRoot/SortableWorld/Player"))
	assert_not_null(hub.get_node("WorldRoot/Foreground"))
	assert_not_null(hub.get_node("NavigationGrid"))
	assert_not_null(hub.get_node("CameraRig/Camera2D"))
	assert_not_null(hub.get_node("HubUI"))
	var player := hub.get_node("WorldRoot/SortableWorld/Player")
	assert_eq(player.scene_file_path, "res://characters/elf/ElfIsoUnitView.tscn")
	assert_true(player is ElfIsoUnitView)
	assert_almost_eq(player.render_display_scale, 0.47, 0.0001)
	assert_eq(player.render_sprite.scale, Vector2(0.47, 0.47))
	assert_not_null(player.get_node("CharacterViewport/CharacterWorld/CharacterPivot/ElfVisual3D"))
	var archivist: HubArchivist = hub.get_node("WorldRoot/SortableWorld/Archivist")
	assert_eq(archivist.occupied_cell, Vector2i(5, 11))
	assert_eq(archivist.position, Vector2(640.0, 1152.0))
	assert_eq(archivist.approach_cells, [
		Vector2i(4, 11), Vector2i(5, 10), Vector2i(6, 11), Vector2i(5, 12),
	])
	assert_eq(archivist.get_model_scale(), Vector3.ONE)
	assert_eq(archivist.model.position, Vector3(0.0, 0.950803, 0.0))
	assert_almost_eq(archivist.render_display_scale, 0.60, 0.0001)
	assert_eq(archivist.render_sprite.scale, Vector2(0.60, 0.60))
	assert_eq(archivist.click_area.collision_layer, 1)
	assert_eq(archivist.click_area.collision_mask, 0)
	var click_shape := archivist.click_collision.shape as RectangleShape2D
	assert_not_null(click_shape)
	assert_eq(click_shape.size, Vector2(250.0, 300.0))
	assert_eq(archivist.click_area.position, Vector2(14.0, -145.0))
	assert_almost_eq(archivist.get_facing_yaw_degrees(), 55.0, 0.001)
	var background: Sprite2D = hub.get_node("WorldRoot/Background")
	assert_eq(background.texture.get_size(), Vector2(2048.0, 2048.0))


func test_debug_est_masque_par_defaut_et_f1_est_le_seul_toggle() -> void:
	var hub := START_HUB_SCENE.instantiate()
	add_child_autofree(hub)
	await get_tree().process_frame
	var controller: StartHubController = hub.get_node("HubController")
	var overlay: HubGridOverlay = hub.get_node("WorldRoot/GridOverlay")
	var navigation_region: HubNavigationRegion2D = hub.get_node(
		"WorldRoot/NavigationRegion2D"
	)
	var panel: Control = hub.get_node("HubUI/DebugPanel")
	assert_false(controller.is_debug_enabled())
	assert_false(overlay.visible)
	assert_false(overlay.debug_visible)
	assert_false(navigation_region.debug_visible)
	assert_false(panel.visible)
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for marker in hub.get_node("NavigationGrid").get_children():
		if marker is HubTechnicalMarker:
			assert_false(marker.visible)
	for control in panel.find_children("*", "Control", true, false):
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var f1 := InputEventKey.new()
	f1.keycode = KEY_F1
	f1.pressed = true
	controller._unhandled_input(f1)
	assert_true(controller.is_debug_enabled())
	assert_true(overlay.visible)
	assert_true(overlay.debug_visible)
	assert_true(navigation_region.debug_visible)
	assert_true(panel.visible)
	controller._unhandled_input(f1)
	assert_false(controller.is_debug_enabled())
	assert_false(overlay.visible)
	assert_false(navigation_region.debug_visible)
	assert_false(panel.visible)


func test_coordonnees_des_quatre_marqueurs() -> void:
	var hub := START_HUB_SCENE.instantiate()
	add_child_autofree(hub)
	await get_tree().process_frame
	var grid_node := hub.get_node("NavigationGrid")
	assert_eq(grid_node.get_node("PlayerSpawn").cell, Vector2i(14, 14))
	assert_eq(grid_node.get_node("MerchantApproach").cell, Vector2i(10, 5))
	assert_eq(grid_node.get_node("StrategyTableApproach").cell, Vector2i(5, 10))
	assert_eq(grid_node.get_node("DungeonPortalApproach").cell, Vector2i(2, 2))
	assert_eq(grid_node.get_node("ArchivistCell").cell, Vector2i(5, 11))
	var approach_cells := [
		Vector2i(4, 11), Vector2i(5, 10), Vector2i(6, 11), Vector2i(5, 12),
	]
	var approach_names := [
		"ArchivistApproachNorthWest",
		"ArchivistApproachNorthEast",
		"ArchivistApproachSouthEast",
		"ArchivistApproachSouthWest",
	]
	var approach_positions := PackedVector2Array()
	for index in range(approach_names.size()):
		var marker: HubTechnicalMarker = grid_node.get_node(approach_names[index])
		assert_eq(marker.cell, approach_cells[index])
		approach_positions.append(marker.global_position)
	var archivist: HubArchivist = hub.get_node("WorldRoot/SortableWorld/Archivist")
	assert_eq(archivist.get_approach_world_positions(), approach_positions)
	assert_eq(grid_node.get_node("ArchivistLookTarget").cell, Vector2i(18, 18))
	assert_eq(
		grid_node.get_node("ArchivistLookTarget").position,
		Vector2(1024.0, 1792.0),
	)
