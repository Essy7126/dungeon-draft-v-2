extends GutTest

const LAB_SCENE := preload(
	"res://tools/labs/forest_dynamic_grid/ForestDynamicTest.tscn"
)
const ROOM_PATH := "res://data/rooms/first_run_room_01.tres"
const PRODUCTION_SCENE := "res://data/rooms/maps/painted_battle.tscn"
const CAPTURE_DIR := "res://artifacts/labs/forest_dynamic_grid"
const CAPTURE_FILES := [
	"forest_original.png",
	"forest_dynamic_neutral_grid.png",
	"forest_full_grid_alignment.png",
	"forest_with_static_walls.png",
	"forest_fire_cells.png",
	"forest_water_cells.png",
	"forest_ice_cells.png",
	"forest_surface_interactions.png",
	"forest_pathfinding.png",
	"forest_units_and_walls.png",
	"forest_final_overview.png",
]


func test_scene_est_isolee_et_contient_les_couches_demandees() -> void:
	var room := load(ROOM_PATH) as RoomData
	assert_eq(room.battle_scene.resource_path, PRODUCTION_SCENE)
	var lab := _new_lab()
	for path in [
		"ForestBackground", "BaseTileLayer", "SurfaceStateLayer",
		"DynamicWallLayer", "DynamicWallLayer/Units",
		"DynamicWallLayer/ForegroundOcclusion", "GridDebug", "UI",
	]:
		assert_not_null(lab.get_node_or_null(path), path)
	assert_true((lab.get_node("DynamicWallLayer") as Node2D).y_sort_enabled)
	assert_true((lab.get_node("DynamicWallLayer/Units") as Node2D).y_sort_enabled)
	assert_eq(lab._hero_marker.get_parent(), lab.get_node("DynamicWallLayer"))
	assert_eq(lab._enemy_marker.get_parent(), lab.get_node("DynamicWallLayer"))


func test_calibration_forest_stricte_et_conversion_unique_sans_derive() -> void:
	var lab := _new_lab()
	assert_eq(lab.visual_data.grid_origin, Vector2(688, 164.97778))
	assert_eq(lab.visual_data.axis_x, Vector2(34.4, 17.066667))
	assert_eq(lab.visual_data.axis_y, Vector2(-34.4, 17.066667))
	for y in range(14):
		for x in range(14):
			var cell := Vector2i(x, y)
			assert_eq(lab.visual_data.image_to_cell(lab.visual_data.cell_to_image(cell)), cell)
	for cell in lab.room_layout.walkable_cells():
		var tile := lab._base_tiles[cell] as Polygon2D
		assert_eq(tile.position, lab.visual_data.cell_to_image(cell), str(cell))
		assert_eq(tile.texture, lab.background_sprite.texture, str(cell))
		assert_eq(tile.uv, lab.visual_data.cell_polygon(cell), str(cell))
		assert_eq(tile.color.a, 1.0, str(cell))
	assert_eq(lab.background_sprite.modulate, Color.WHITE)


func test_topologie_generee_exclusivement_depuis_roomdata_griddata() -> void:
	var lab := _new_lab()
	assert_eq(lab.grid.cols, 14)
	assert_eq(lab.grid.rows, 14)
	assert_eq(lab.room_layout.walkable_cells().size(), 153)
	assert_eq(lab.room_layout.blocked_cells().size(), 11)
	assert_eq(lab.room_layout.void_cells().size(), 32)
	assert_eq(lab._base_tiles.size(), 153)
	assert_eq(lab._surface_tiles.size(), 153)
	assert_eq(lab.surface_service.state_count(), 153)
	for cell in lab.room_layout.void_cells():
		assert_false(lab._base_tiles.has(cell), str(cell))
		assert_false(lab._surface_tiles.has(cell), str(cell))
		assert_false(lab.surface_service.has_state(cell), str(cell))
	for cell in lab.room_layout.blocked_cells():
		assert_false(lab._base_tiles.has(cell), str(cell))


func test_configuration_data_driven_feu_eau_glace_reste_praticable() -> void:
	var lab := _new_lab()
	for config in ForestDynamicTest.SURFACE_CONFIGS:
		assert_eq(config.validation_errors(), PackedStringArray(), config.display_name)
		assert_true(config.walkable)
		assert_eq(config.movement_cost, 1)
	assert_eq(ForestDynamicTest.FIRE_CONFIG.duration_turns, 2)
	assert_eq(ForestDynamicTest.FIRE_CONFIG.turn_start_damage, 2)
	assert_eq(ForestDynamicTest.WATER_CONFIG.duration_turns, 2)
	assert_eq(ForestDynamicTest.WATER_CONFIG.turn_start_damage, 0)
	assert_eq(ForestDynamicTest.ICE_CONFIG.duration_turns, 2)
	assert_eq(ForestDynamicTest.ICE_CONFIG.turn_start_damage, 0)
	for surface_color in ForestDynamicTest.SURFACE_MODULATES.values():
		assert_eq((surface_color as Color).a, 1.0, "surface dynamique opaque")


func test_table_centrale_des_interactions_est_complete() -> void:
	var none := CellSurfaceState.DynamicSurface.NONE
	var fire := CellSurfaceState.DynamicSurface.FIRE
	var water := CellSurfaceState.DynamicSurface.WATER
	var ice := CellSurfaceState.DynamicSurface.ICE
	_assert_interaction(none, fire, fire, false)
	_assert_interaction(none, water, water, false)
	_assert_interaction(none, ice, ice, false)
	_assert_interaction(fire, water, none, true)
	_assert_interaction(fire, ice, water, true)
	_assert_interaction(water, ice, ice, false)
	_assert_interaction(ice, fire, water, false)
	_assert_interaction(water, fire, none, true)


func test_surface_ne_modifie_jamais_le_terrain_de_base_ni_le_pathfinding() -> void:
	var lab := _new_lab()
	var cell := Vector2i(7, 8)
	var type_before := lab.grid.get_type(cell)
	var path_before := lab.pathfinder.find_path(Vector2i(7, 7), Vector2i(7, 9))
	for surface in [
		CellSurfaceState.DynamicSurface.FIRE,
		CellSurfaceState.DynamicSurface.WATER,
		CellSurfaceState.DynamicSurface.ICE,
	]:
		assert_true(lab.set_surface(cell, surface))
		assert_eq(lab.grid.get_type(cell), type_before)
		assert_true(lab.grid.is_walkable(cell))
		assert_eq(lab.surface_service.get_movement_cost(cell), 1)
		assert_eq(lab.pathfinder.find_path(Vector2i(7, 7), Vector2i(7, 9)), path_before)


func test_duree_degats_debut_tour_et_reset_surface() -> void:
	var lab := _new_lab()
	var cell := Vector2i(7, 8)
	assert_true(lab.set_surface(cell, CellSurfaceState.DynamicSurface.FIRE, "mage"))
	var state := lab.get_surface_state(cell)
	assert_eq(state.base_surface, CellSurfaceState.BaseSurface.FOREST_NEUTRAL)
	assert_eq(state.duration_turns, 2)
	assert_eq(state.source_unit, "mage")
	assert_eq(lab.get_turn_start_damage(cell), 2)
	lab.advance_turn()
	assert_eq(state.duration_turns, 1)
	lab.advance_turn()
	assert_eq(lab.get_surface(cell), CellSurfaceState.DynamicSurface.NONE)
	assert_null(lab.grid.get_effect(cell))
	assert_eq(state.base_surface, CellSurfaceState.BaseSurface.FOREST_NEUTRAL)


func test_six_murs_statiques_data_driven_remplacent_leurs_dalles_sans_spawn() -> void:
	var lab := _new_lab()
	assert_eq(ForestDynamicTest.TEST_DATA.validation_errors(), PackedStringArray())
	assert_eq(ForestDynamicTest.TEST_DATA.segment_two.size(), 2)
	assert_eq(ForestDynamicTest.TEST_DATA.segment_three.size(), 3)
	assert_eq(ForestDynamicTest.TEST_DATA.isolated_walls.size(), 1)
	assert_eq(lab.get_static_wall_cells().size(), 6)
	for cell in lab.get_static_wall_cells():
		assert_false(ForestDynamicTest.FOREST_ROOM.hero_spawn_zone.has(cell), str(cell))
		assert_false(ForestDynamicTest.FOREST_ROOM.enemy_spawn_zone.has(cell), str(cell))
		assert_eq(lab.grid.get_type(cell), GridData.CellType.NORMAL)
		assert_true(lab.grid.is_cell_dynamically_blocked(cell))
		assert_false(lab.grid.is_walkable(cell))
		assert_false((lab._base_tiles[cell] as CanvasItem).visible)
		var wall := lab._static_walls[cell] as StaticForestWall
		assert_false(wall.is_targetable())
		assert_false("hp" in wall)


func test_murs_bloquent_mouvement_los_projectiles_et_ia_les_contourne() -> void:
	var lab := _new_lab()
	var from := Vector2i(8, 7)
	var to := Vector2i(13, 7)
	var path := lab.pathfinder.find_path(from, to)
	assert_gt(path.size(), 0)
	assert_gt(path.size(), 6)
	for wall_cell in [Vector2i(10, 7), Vector2i(11, 7)]:
		assert_false(path.has(wall_cell))
	assert_false(lab.has_line_of_sight(from, to))
	assert_false(lab.has_projectile_path(from, to))
	var ai_path := lab.compute_ai_path()
	assert_gt(ai_path.size(), 1)
	for wall_cell in lab.get_static_wall_cells():
		assert_false(ai_path.has(wall_cell), str(wall_cell))


func test_spawns_gardent_une_dalle_et_aucun_mur() -> void:
	var lab := _new_lab()
	for cell in ForestDynamicTest.FOREST_ROOM.hero_spawn_zone \
			+ ForestDynamicTest.FOREST_ROOM.enemy_spawn_zone:
		assert_true(lab._base_tiles.has(cell), str(cell))
		assert_false(lab._static_walls.has(cell), str(cell))


func test_ancrage_unite_et_y_sort_derriere_devant_sans_derive() -> void:
	var lab := _new_lab()
	var wall_cell := Vector2i(4, 6)
	var behind := Vector2i(3, 5)
	var front := Vector2i(5, 7)
	assert_true(lab.is_unit_visually_behind_wall(behind, wall_cell))
	assert_true(lab.is_unit_visually_in_front_of_wall(front, wall_cell))
	lab.set_unit_cells(behind, front)
	assert_eq(lab._hero_marker.position, lab.visual_data.cell_to_image(behind))
	assert_eq(lab._enemy_marker.position, lab.visual_data.cell_to_image(front))
	assert_eq(lab.visual_data.image_to_cell(lab._hero_marker.position), behind)
	assert_true(lab.is_unit_hidden_by_tower(Vector2i(9, 3)))
	assert_false(lab.is_unit_hidden_by_tower(Vector2i(11, 6)))


func test_bords_void_obstacles_et_murs_refusent_les_surfaces() -> void:
	var lab := _new_lab()
	for cell in [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(4, 5), Vector2i(4, 6)]:
		assert_false(
			bool(lab.apply_surface_effect(
				cell, CellSurfaceState.DynamicSurface.FIRE, null
			).handled),
			str(cell)
		)
	assert_eq(lab.surface_service.state_count(), 153)


func test_cycles_repetes_et_resets_ne_laissent_aucun_etat_fantome() -> void:
	var lab := _new_lab()
	var cell := Vector2i(7, 8)
	var changed_count := [0]
	lab.surface_service.surface_changed.connect(
		func(_cell, _previous, _surface): changed_count[0] += 1
	)
	for _iteration in range(40):
		lab.set_surface(cell, CellSurfaceState.DynamicSurface.FIRE)
		lab.clear_surface(cell)
	assert_eq(changed_count[0], 80)
	assert_eq(lab.surface_service.state_count(), 153)
	lab.reset_test()
	assert_eq(lab.get_surface(cell), CellSurfaceState.DynamicSurface.NONE)
	assert_null(lab.grid.get_effect(cell))
	assert_eq(lab.get_static_wall_cells().size(), 6)


func test_onze_captures_contractuelles_sont_presentes() -> void:
	for file_name in CAPTURE_FILES:
		var path := CAPTURE_DIR.path_join(file_name)
		assert_true(FileAccess.file_exists(path), file_name)
		if not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), file_name)
		assert_eq(image.get_size(), Vector2i(1376, 768), file_name)


func _new_lab() -> ForestDynamicTest:
	var lab := LAB_SCENE.instantiate() as ForestDynamicTest
	add_child_autofree(lab)
	return lab


func _assert_interaction(current: int, incoming: int, expected: int, steam: bool) -> void:
	var result := TerrainInteractionResolver.resolve(current, incoming)
	assert_eq(int(result.surface), expected)
	assert_eq(bool(result.steam), steam)
