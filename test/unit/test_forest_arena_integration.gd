extends GutTest

const LAB_SCENE := preload(
	"res://tools/labs/forest_arena_integration/ForestArenaIntegrationTest.tscn"
)
const CONFIG: ForestArenaIntegrationConfig = preload(
	"res://tools/labs/forest_arena_integration/forest_arena_integration_config.tres"
)
const MODEL_SCRIPT := preload(
	"res://tools/labs/forest_arena_integration/forest_arena_integration_map.gd"
)
const CAPTURE_DIR := "res://artifacts/labs/forest_arena_integration/testv1"
const CAPTURE_FILES := [
	"source_forest_background_v3.png", "map_reference_comparison.png",
	"map_logic_comparison.png", "painted_background_only.png",
	"dynamic_grid_only.png", "overlay_alignment.png",
	"overlay_alignment_corners.png", "playable_border_void_debug.png",
	"border_removed_debug.png", "neutral_tiles.png", "fire_tiles.png",
	"water_tiles.png", "ice_tiles.png", "surface_interactions.png",
	"static_walls.png", "dynamic_wall.png", "pathfinding_center.png",
	"pathfinding_border.png", "los_blocked.png", "projectile_blocked.png",
	"units_on_arena.png", "final_forest_arena_test.png",
]


func test_chargement_image_json_references_et_projection() -> void:
	assert_eq(CONFIG.validation_errors(), PackedStringArray())
	assert_eq(CONFIG.background_texture.get_size(), Vector2(1672, 941))
	assert_true(FileAccess.file_exists(CONFIG.map_definition_path))
	for file_name in [
		"map_definition.json", "map_reference.png", "map_clean.png",
		"map_logic.png", "map_debug.png",
	]:
		assert_true(FileAccess.file_exists(
			"res://tools/arena_map_editor/testv1/" + file_name
		), file_name)
	var model := _new_model()
	assert_eq(model.validation_errors(), PackedStringArray())
	assert_eq(model.grid_size, Vector2i(14, 15))
	assert_eq(model.document.to_dict().projection.tile_width, 64)
	assert_eq(model.document.to_dict().projection.tile_height, 32)


func test_categories_conservent_void_et_derivent_exactement_la_couronne() -> void:
	var model := _new_model()
	assert_eq(model.cells_in_category(ForestArenaIntegrationMap.CellCategory.PLAYABLE).size(), 151)
	assert_eq(model.cells_in_category(ForestArenaIntegrationMap.CellCategory.BORDER).size(), 47)
	assert_eq(model.cells_in_category(ForestArenaIntegrationMap.CellCategory.VOID).size(), 12)
	assert_eq(model.get_category(Vector2i(0, 0)), ForestArenaIntegrationMap.CellCategory.VOID)
	assert_eq(model.get_category(Vector2i(2, 0)), ForestArenaIntegrationMap.CellCategory.BORDER)
	assert_eq(model.get_category(Vector2i(1, 1)), ForestArenaIntegrationMap.CellCategory.PLAYABLE)
	assert_eq(model.get_category(Vector2i(11, 1)), ForestArenaIntegrationMap.CellCategory.VOID)
	assert_eq(model.get_category(Vector2i(13, 14)), ForestArenaIntegrationMap.CellCategory.BORDER)


func test_spawns_objectif_ancres_et_absence_de_mur_json_sont_exacts() -> void:
	var model := _new_model()
	assert_eq(model.special_cells("ALLY_SPAWN"), [Vector2i(2, 7), Vector2i(3, 7)])
	assert_eq(model.special_cells("ENEMY_SPAWN"), [Vector2i(8, 2), Vector2i(9, 2)])
	assert_eq(model.special_cells("OBJECTIVE"), [Vector2i(6, 4)])
	assert_eq(model.special_cells("DECOR_ANCHOR"), [Vector2i(1, 4), Vector2i(10, 5)])
	assert_eq(model.static_wall_cells(), [])
	for special in ["ALLY_SPAWN", "ENEMY_SPAWN", "OBJECTIVE"]:
		for cell in model.special_cells(special):
			assert_eq(model.get_category(cell), ForestArenaIntegrationMap.CellCategory.PLAYABLE)


func test_rendu_genere_une_seule_dalle_par_playable_et_aucune_sur_bord_void() -> void:
	var lab := _new_lab()
	assert_eq(lab._base_tiles.size(), 151)
	assert_eq(lab._surface_tiles.size(), 151)
	assert_eq(lab.dynamic_base_tiles.get_child_count(), 151)
	assert_eq(lab.dynamic_surface_tiles.get_child_count(), 152, "151 surfaces + PathLine")
	for cell in lab.map_model.all_cells():
		var should_have_tile := lab.map_model.get_category(cell) \
				== ForestArenaIntegrationMap.CellCategory.PLAYABLE
		assert_eq(lab._base_tiles.has(cell), should_have_tile, str(cell))
		assert_eq(lab._surface_tiles.has(cell), should_have_tile, str(cell))


func test_projection_round_trip_ancres_et_absence_de_derive_excessive() -> void:
	assert_lt(CONFIG.calibration_mean_error(), 1.0)
	assert_lt(CONFIG.calibration_max_error(), 1.0)
	for cell in [
		Vector2i(0, 0), Vector2i(13, 0), Vector2i(0, 14),
		Vector2i(13, 14), Vector2i(7, 7), Vector2i(3, 4),
		Vector2i(10, 9), Vector2i(1, 12), Vector2i(12, 1),
	]:
		assert_eq(CONFIG.screen_to_cell(CONFIG.cell_to_screen(cell)), cell, str(cell))
	assert_eq(CONFIG.geometry_match, "GEOMETRY_MATCH_WITH_CALIBRATION")


func test_surface_neutral_fire_water_ice_interactions_et_refus_hors_playable() -> void:
	var lab := _new_lab()
	var cell := Vector2i(5, 10)
	assert_eq(lab.get_surface_effect(cell), CellSurfaceState.DynamicSurface.NONE)
	assert_true(lab.apply_surface_effect(cell, CellSurfaceState.DynamicSurface.FIRE).handled)
	assert_eq(lab.get_surface_effect(cell), CellSurfaceState.DynamicSurface.FIRE)
	var steam := lab.apply_surface_effect(cell, CellSurfaceState.DynamicSurface.WATER)
	assert_true(steam.handled)
	assert_true(steam.steam)
	assert_eq(lab.get_surface_effect(cell), CellSurfaceState.DynamicSurface.NONE)
	assert_true(lab.apply_surface_effect(cell, CellSurfaceState.DynamicSurface.WATER).handled)
	assert_true(lab.apply_surface_effect(cell, CellSurfaceState.DynamicSurface.ICE).handled)
	assert_eq(lab.get_surface_effect(cell), CellSurfaceState.DynamicSurface.ICE)
	assert_false(lab.apply_surface_effect(Vector2i(2, 0), CellSurfaceState.DynamicSurface.FIRE).handled)
	assert_false(lab.apply_surface_effect(Vector2i(11, 1), CellSurfaceState.DynamicSurface.FIRE).handled)
	assert_false(lab.clear_surface_effect(Vector2i(2, 0)))


func test_grid_pathfinding_exclut_border_void_et_detourne_un_mur_dynamique() -> void:
	var lab := _new_lab()
	for border in lab.map_model.cells_in_category(ForestArenaIntegrationMap.CellCategory.BORDER):
		assert_false(lab.grid.is_walkable(border), str(border))
	for void_cell in lab.map_model.cells_in_category(ForestArenaIntegrationMap.CellCategory.VOID):
		assert_false(lab.grid.is_walkable(void_cell), str(void_cell))
	assert_eq(lab.compute_path(Vector2i(2, 7), Vector2i(2, 0)), [])
	var from := Vector2i(2, 7)
	var to := Vector2i(8, 7)
	var direct := lab.compute_path(from, to)
	assert_false(direct.is_empty())
	assert_not_null(lab.place_dynamic_wall(Vector2i(5, 7)))
	var detour := lab.compute_path(from, to)
	assert_gt(detour.size(), direct.size())
	assert_false(detour.has(Vector2i(5, 7)))
	assert_true(lab.remove_dynamic_wall(Vector2i(5, 7)))
	assert_eq(lab.compute_path(from, to).size(), direct.size())


func test_mur_dynamique_bloque_los_projectiles_et_se_retire_proprement() -> void:
	var lab := _new_lab()
	var from := Vector2i(2, 7)
	var to := Vector2i(8, 7)
	assert_true(lab.has_line_of_sight(from, to))
	assert_true(lab.has_projectile_path(from, to))
	var wall := lab.place_dynamic_wall(Vector2i(5, 7))
	assert_not_null(wall)
	assert_false(lab.has_line_of_sight(from, to))
	assert_false(lab.has_projectile_path(from, to))
	assert_null(lab.place_dynamic_wall(Vector2i(2, 0)), "BORDER")
	assert_null(lab.place_dynamic_wall(Vector2i(11, 1)), "VOID")
	assert_null(lab.place_dynamic_wall(Vector2i(2, 7)), "spawn")
	assert_true(lab.remove_dynamic_wall(Vector2i(5, 7)))
	assert_true(lab.has_line_of_sight(from, to))
	assert_true(lab.has_projectile_path(from, to))


func test_unites_restent_interieures_y_sort_et_refusent_la_couronne() -> void:
	var lab := _new_lab()
	assert_eq(lab.hero_cell, Vector2i(2, 7))
	assert_eq(lab.enemy_cell, Vector2i(8, 2))
	assert_true(lab.is_playable(lab.hero_cell))
	assert_true(lab.is_playable(lab.enemy_cell))
	assert_false(lab.move_hero_to(Vector2i(2, 0)))
	assert_false(lab.set_unit_cells(Vector2i(2, 0), lab.enemy_cell))
	assert_true(lab.y_sorted_world.y_sort_enabled)
	assert_true(lab.static_walls_layer.y_sort_enabled)
	assert_true(lab.dynamic_walls_layer.y_sort_enabled)
	assert_true(lab.units_layer.y_sort_enabled)
	assert_eq(lab._hero_unit.get_parent(), lab.units_layer)
	assert_eq(lab._hero_unit.position, CONFIG.cell_to_screen(lab.hero_cell))


func test_reset_retablit_surfaces_json_retire_murs_et_ne_fuit_pas_de_noeud() -> void:
	var lab := _new_lab()
	var initial_surface_count := 0
	for cell in lab._surface_tiles:
		if lab.get_surface_effect(cell) != CellSurfaceState.DynamicSurface.NONE:
			initial_surface_count += 1
	assert_eq(initial_surface_count, 21)
	var node_count_before := int(lab.get_quality_metrics().generated_nodes)
	assert_not_null(lab.place_dynamic_wall(Vector2i(5, 7)))
	lab.apply_surface_effect(Vector2i(5, 10), CellSurfaceState.DynamicSurface.FIRE)
	lab.reset_test()
	assert_eq(lab._dynamic_walls.size(), 0)
	assert_false(lab.grid.is_cell_dynamically_blocked(Vector2i(5, 7)))
	assert_eq(lab.get_surface_effect(Vector2i(5, 10)), CellSurfaceState.DynamicSurface.NONE)
	assert_eq(lab.get_surface_effect(Vector2i(9, 5)), CellSurfaceState.DynamicSurface.FIRE)
	await wait_process_frames(2)
	assert_lte(lab.get_quality_metrics().generated_nodes, node_count_before + 1)


func test_mesures_structurelles_et_scene_f6_isolee() -> void:
	var lab := _new_lab()
	var metrics: Dictionary = lab.get_quality_metrics()
	assert_eq(metrics.playable_tiles, 151)
	assert_eq(metrics.tiles_outside_source_image, 0)
	assert_eq(metrics.painted_lines_visible_in_playable_centers, 0)
	assert_gt(metrics.generated_nodes, 300)
	assert_gt(metrics.load_time_ms, 0.0)
	assert_true(FileAccess.file_exists(
		"res://tools/labs/forest_arena_integration/ForestArenaIntegrationTest.tscn"
	))
	var first_room := load("res://data/rooms/first_run_room_01.tres") as RoomData
	assert_eq(first_room.battle_scene.resource_path, "res://data/rooms/maps/painted_battle.tscn")


func test_les_22_captures_contractuelles_sont_presentes() -> void:
	for file_name in CAPTURE_FILES:
		var path := CAPTURE_DIR.path_join(file_name)
		assert_true(FileAccess.file_exists(path), file_name)
		if not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), file_name)
		assert_gte(image.get_width(), 1600, file_name)
		assert_gte(image.get_height(), 900, file_name)


func _new_model() -> ForestArenaIntegrationMap:
	var model := MODEL_SCRIPT.new() as ForestArenaIntegrationMap
	assert_true(model.load_from_path(CONFIG.map_definition_path, CONFIG.border_thickness))
	return model


func _new_lab() -> ForestArenaIntegrationTest:
	var lab := LAB_SCENE.instantiate() as ForestArenaIntegrationTest
	add_child_autofree(lab)
	assert_eq(lab.validation_errors, PackedStringArray())
	return lab
