extends GutTest

const FOREST_ROOM := "res://data/rooms/first_run_room_01.tres"
const VOLCANO_ROOM := "res://data/rooms/room_05_volcano.tres"
const SPACE_ROOM := "res://data/rooms/room_06_space.tres"
const TEST_RESOURCE := "res://output/tests/arena_studio_v1/arena_roundtrip.tres"


func after_each() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_RESOURCE)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func test_grid_transform_cellule_position_et_aller_retour_asymetrique() -> void:
	var origin := Vector2(217.35, -83.2)
	var axis_x := Vector2(37.8, 19.25)
	var axis_y := Vector2(-31.4, 16.6)
	assert_true(GridTransformService.is_invertible(axis_x, axis_y))
	for cell in [
		Vector2i(-5, -3), Vector2i.ZERO, Vector2i(7, 2), Vector2i(63, 63),
	]:
		var position := GridTransformService.cell_to_position(cell, origin, axis_x, axis_y)
		assert_eq(
			GridTransformService.position_to_cell(position, origin, axis_x, axis_y),
			cell
		)


func test_grid_transform_vue_zoom_pan_et_test_du_losange() -> void:
	var origin := Vector2(100, 80)
	var axis_x := Vector2(40, 18)
	var axis_y := Vector2(-34, 20)
	var cell := Vector2i(3, 4)
	var center := GridTransformService.cell_to_position(cell, origin, axis_x, axis_y)
	var pan := Vector2(-45, 128)
	var zoom := 2.75
	var view := GridTransformService.image_to_view(center, pan, zoom)
	assert_almost_eq(GridTransformService.view_to_image(view, pan, zoom), center, Vector2(0.001, 0.001))
	assert_eq(
		GridTransformService.view_to_cell(view, pan, zoom, origin, axis_x, axis_y),
		cell
	)
	assert_true(GridTransformService.is_point_in_cell(center, cell, origin, axis_x, axis_y))
	assert_false(GridTransformService.is_point_in_cell(center + axis_x * 0.61, cell, origin, axis_x, axis_y))


func test_grid_transform_refuse_axes_colineaires_et_reste_stable() -> void:
	assert_false(GridTransformService.is_invertible(Vector2(40, 20), Vector2(80, 40.00001)))
	assert_eq(
		GridTransformService.position_to_cell(
			Vector2.ZERO, Vector2.ZERO, Vector2(40, 20), Vector2(80, 40.00001)
		),
		GridTransformService.INVALID_CELL
	)
	var axis_x := Vector2(37.0, 19.0)
	var axis_y := Vector2(-31.0, 21.0)
	assert_eq(
		GridTransformService.position_to_cell(
			GridTransformService.cell_to_position(Vector2i(6000, -4000), Vector2(10000, -10000), axis_x, axis_y),
			Vector2(10000, -10000), axis_x, axis_y
		),
		Vector2i(6000, -4000)
	)


func test_calibration_multipoint_retrouve_transformation_affine() -> void:
	var cells: Array[Vector2i] = [
		Vector2i.ZERO, Vector2i(5, 0), Vector2i(0, 5), Vector2i(7, 3),
		Vector2i(2, 8), Vector2i(9, 9),
	]
	var positions: Array[Vector2] = []
	for cell in cells:
		positions.append(GridTransformService.cell_to_position(
			cell, Vector2(300, 120), Vector2(35, 17), Vector2(-33, 18)
		))
	var fit := GridTransformService.fit_affine(cells, positions)
	assert_true(fit.ok)
	assert_almost_eq(fit.origin, Vector2(300, 120), Vector2(0.001, 0.001))
	assert_almost_eq(fit.axis_x, Vector2(35, 17), Vector2(0.001, 0.001))
	assert_almost_eq(fit.axis_y, Vector2(-33, 18), Vector2(0.001, 0.001))
	assert_lt(fit.rms_error, 0.001)


func test_bordure_rectangle_epaisseurs_et_idempotence() -> void:
	var cells := _rectangle_cells(Vector2i(6, 5))
	var one := ArenaBoundaryService.compute_outer_border(cells, Vector2i(6, 5), 1)
	var two := ArenaBoundaryService.compute_outer_border(cells, Vector2i(6, 5), 2)
	assert_eq(one.size(), 18)
	assert_eq(two.size(), 28)
	assert_eq(one, ArenaBoundaryService.compute_outer_border(cells, Vector2i(6, 5), 1))


func test_bordure_forme_l_irreguliere_et_trou_interieur() -> void:
	var l_shape: Array[Vector2i] = []
	for cell in _rectangle_cells(Vector2i(6, 6)):
		if cell.x <= 1 or cell.y >= 4:
			l_shape.append(cell)
	var l_border := ArenaBoundaryService.compute_outer_border(l_shape, Vector2i(6, 6), 1)
	assert_false(l_border.is_empty())
	assert_true(l_border.has(Vector2i(0, 0)))
	assert_true(l_border.has(Vector2i(5, 5)))
	var with_hole := _rectangle_cells(Vector2i(7, 7))
	with_hole.erase(Vector2i(3, 3))
	var border := ArenaBoundaryService.compute_outer_border(with_hole, Vector2i(7, 7), 1)
	assert_eq(border.size(), 24)
	for neighbor in [Vector2i(2, 3), Vector2i(4, 3), Vector2i(3, 2), Vector2i(3, 4)]:
		assert_false(border.has(neighbor), "Le trou ferme ne doit pas devenir l'exterieur.")


func test_import_foret_volcan_espace_preserve_runtime_a_zero_pixel() -> void:
	for path in [FOREST_ROOM, VOLCANO_ROOM, SPACE_ROOM]:
		var room := load(path) as RoomData
		var imported := ArenaLegacyImporter.import_room(path)
		assert_not_null(imported, path)
		assert_eq(imported.grid_size, room.grid_layout.logical_size)
		for y in range(imported.grid_size.y):
			for x in range(imported.grid_size.x):
				var cell := Vector2i(x, y)
				assert_almost_eq(
					imported.painted_map_visual_data.cell_to_image(cell),
					room.painted_map_visual_data.cell_to_image(cell),
					Vector2(0.001, 0.001),
					"%s %s" % [path, cell]
				)
				assert_eq(
					imported.grid_layout.resolved_cell_type(cell),
					room.grid_layout.resolved_cell_type(cell),
					"%s %s" % [path, cell]
				)
		assert_eq(imported.hero_spawn_zone, room.hero_spawn_zone)
		assert_eq(imported.enemy_spawn_zone, room.enemy_spawn_zone)
		assert_eq(imported.battle_scene.resource_path, room.battle_scene.resource_path)


func test_preparation_automatique_bordure_spawns_navigation_et_los_reels() -> void:
	var arena := _valid_arena()
	var result := ArenaEditingService.prepare_automatically(arena)
	assert_true(result.ok)
	assert_eq(arena.border_cells().size(), 32)
	assert_eq(arena.playable_cells().size(), 48)
	assert_gte(arena.hero_spawn_zone.size(), 3)
	assert_gte(arena.enemy_spawn_zone.size(), 3)
	var grid := ArenaRuntimeBridge.build_grid(arena)
	var pathfinder := Pathfinder.new(grid)
	var from := arena.hero_spawn_zone[0]
	var to := arena.enemy_spawn_zone[0]
	assert_gt(pathfinder.find_path(from, to).size(), 1)
	assert_true(pathfinder.has_line_of_sight(from, to))
	var line := pathfinder.trace_line(from, to)
	if line.size() > 2:
		var blocker := line[line.size() / 2]
		ArenaEditingService.set_obstacle(
			arena, blocker, ArenaObstacleDefinition.Preset.FULL_WALL
		)
		grid = ArenaRuntimeBridge.build_grid(arena)
		pathfinder = Pathfinder.new(grid)
		assert_false(pathfinder.has_line_of_sight(from, to))
		assert_eq(pathfinder.first_line_blocker(from, to), blocker)


func test_validation_map_vide_spawn_bordure_obstacle_et_grille_invalide() -> void:
	var empty := ArenaDefinition.new()
	empty.arena_id = &""
	empty.background_path = ""
	empty.axis_y = empty.axis_x
	var report := ArenaValidator.validate(empty, false)
	var codes := report.messages.map(func(entry): return entry.code)
	for code in [&"missing_id", &"missing_background", &"non_invertible_grid", &"no_playable_cell", &"missing_heroes"]:
		assert_true(codes.has(code), str(code))
	var arena := _valid_arena()
	ArenaEditingService.prepare_automatically(arena)
	var spawn := arena.spawns[0]
	spawn.cell = arena.border_cells()[0]
	report = ArenaValidator.validate(arena, false)
	assert_true(report.messages.any(func(entry): return entry.code == &"spawn_on_border"))
	spawn.cell = arena.playable_cells()[0]
	ArenaEditingService.set_obstacle(arena, spawn.cell, ArenaObstacleDefinition.Preset.FULL_WALL)
	report = ArenaValidator.validate(arena, false)
	assert_true(report.messages.any(func(entry): return entry.code == &"spawn_blocked"))


func test_sauvegarde_rechargement_schema_migration_et_absence_de_perte() -> void:
	var arena := _valid_arena()
	ArenaEditingService.prepare_automatically(arena)
	arena.production_notes = "Test de fidelite"
	assert_eq(ArenaSerializer.save_canonical(arena, TEST_RESOURCE), OK)
	var restored := ArenaSerializer.load_canonical(TEST_RESOURCE)
	assert_not_null(restored)
	assert_eq(restored.to_snapshot(), arena.to_snapshot())
	var legacy := arena.to_snapshot()
	legacy["schema_version"] = 0
	legacy.erase("border_thickness")
	var migrated := ArenaMigrationService.migrate_snapshot(legacy)
	assert_true(migrated.ok)
	assert_true(migrated.changed)
	assert_eq(migrated.snapshot.schema_version, ArenaDefinition.CURRENT_SCHEMA_VERSION)
	assert_eq(ArenaMigrationService.migrate_snapshot(migrated.snapshot).snapshot, migrated.snapshot)


func test_runtime_generation_deterministe_idempotente_et_64_par_64() -> void:
	var arena := _valid_arena(Vector2i(64, 64))
	ArenaEditingService.prepare_automatically(arena)
	var first := ArenaRuntimeBridge.runtime_signature(arena)
	var second := ArenaRuntimeBridge.runtime_signature(arena)
	assert_eq(first, second)
	assert_eq(first.size, Vector2i(64, 64))
	assert_eq(first.centers.size(), 4096)
	assert_eq(first.types.size(), 4096)


func test_outils_rectangle_remplissage_selection_obstacle_terrain_et_spawn() -> void:
	var arena := _valid_arena(Vector2i(6, 5))
	var canvas := ArenaStudioCanvas.new()
	add_child_autofree(canvas)
	canvas.set_arena(arena)
	assert_eq(
		canvas._rectangle_cells(Vector2i(1, 1), Vector2i(3, 2)).size(),
		6
	)
	for y in range(arena.grid_size.y):
		assert_true(ArenaEditingService.set_cell_state(arena, Vector2i(3, y), &"remove"))
	assert_eq(canvas._contiguous_cells(Vector2i.ZERO).size(), 15)
	assert_eq(canvas._contiguous_cells(Vector2i(3, 0)).size(), 5)

	canvas.zoom = 1.0
	canvas.pan = Vector2.ZERO
	canvas.set_tool(ArenaStudioCanvas.Tool.ADD_CELL)
	canvas.brush_shape = ArenaStudioCanvas.BrushShape.MULTI_SELECT
	for index in range(2):
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.shift_pressed = index > 0
		event.position = GridTransformService.cell_to_position(
			Vector2i(index + 1, 1), arena.grid_origin, arena.axis_x, arena.axis_y
		)
		canvas._handle_mouse_button(event)
	assert_eq(canvas.selected_cells, [Vector2i(1, 1), Vector2i(2, 1)])

	assert_true(ArenaEditingService.set_obstacle(
		arena, Vector2i(1, 2), ArenaObstacleDefinition.Preset.FULL_WALL
	))
	assert_true(arena.obstacle_at(Vector2i(1, 2)).blocks_line_of_sight)
	assert_true(ArenaEditingService.set_terrain(
		arena, Vector2i(2, 2), GridData.CellType.LAVA
	))
	assert_eq(arena.get_cell_definition(Vector2i(2, 2)).cell_type, GridData.CellType.LAVA)
	assert_true(ArenaEditingService.place_spawn(
		arena, Vector2i(2, 3), ArenaSpawnDefinition.Kind.HERO_1
	))
	assert_eq(arena.spawns_at(Vector2i(2, 3)).size(), 1)
	assert_true(ArenaEditingService.set_cell_state(arena, Vector2i(5, 4), &"remove"))
	assert_null(arena.get_cell_definition(Vector2i(5, 4)))


func test_undo_redo_restaure_exactement_un_trait_groupe() -> void:
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	var target: Vector2i = studio.arena.playable_cells()[0]
	var before := studio.arena.to_snapshot()
	assert_true(ArenaEditingService.set_terrain(
		studio.arena, target, GridData.CellType.RUNE
	))
	var after := studio.arena.to_snapshot()
	studio._commit_change("Peindre un trait groupe", before, after)
	assert_eq(studio.arena.get_cell_definition(target).cell_type, GridData.CellType.RUNE)
	studio._fallback_undo.undo()
	assert_eq(studio.arena.to_snapshot(), before)
	studio._fallback_undo.redo()
	assert_eq(studio.arena.to_snapshot(), after)
	studio._fallback_undo.clear_history()
	ArenaSerializer.remove_recovery(studio.arena.arena_id)


func test_plugin_interface_modes_outils_activation_et_ancien_editeur_conserve() -> void:
	# Le mode guidé est persistant entre deux sessions : le test repart donc
	# explicitement des valeurs par défaut avant de l'observer.
	TerrainStudioUiStateService.clear_cache()
	TerrainStudioUiStateService.save_state(TerrainStudioUiStateService.default_state())
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	assert_not_null(studio.canvas)
	# La refonte Terrain remplace le sélecteur Création / Vérification / Avancé
	# par un unique interrupteur Mode guidé / Mode avancé.
	assert_true(bool(TerrainStudioUiStateService.default_state().guided))
	assert_not_null(studio.guided_toggle)
	assert_true(studio.is_guided())
	assert_eq(studio.tool_list.item_count, 11)
	assert_eq(studio.test_configuration_option.item_count, 14)
	assert_true(studio.get_node_or_null("ArenaStudioMain") == null)
	assert_true(FileAccess.file_exists("res://addons/dungeon_draft_arena_studio/plugin.cfg"))
	assert_true(FileAccess.file_exists("res://addons/dungeon_draft_arena_studio/arena_studio_plugin.gd"))
	assert_true(FileAccess.file_exists("res://addons/dungeon_draft_arena_studio/test/arena_studio_test_runner.tscn"))
	assert_true(FileAccess.file_exists("res://addons/dungeon_draft_arena_studio/test/arena_studio_runtime_smoke.tscn"))
	assert_true(FileAccess.file_exists("res://tools/arena_map_editor/ArenaMapEditor.tscn"))
	assert_true(FileAccess.file_exists("res://tools/arena_map_editor/testv1/map_definition.json"))
	var plugin_source := FileAccess.get_file_as_string(
		"res://addons/dungeon_draft_arena_studio/arena_studio_plugin.gd"
	)
	assert_true("_has_main_screen" in plugin_source)
	assert_true("_make_visible" in plugin_source)
	assert_true("Arena Studio" in plugin_source)


func test_rapport_exporte_json_markdown_definition_et_log() -> void:
	var arena := _valid_arena()
	ArenaEditingService.prepare_automatically(arena)
	var report := ArenaValidator.validate(arena, false)
	assert_true(report.is_valid(), report.to_markdown())
	var result := ArenaReportExporter.export_report(arena, report, "test ok")
	assert_true(result.ok)
	for file_name in ["validation_report.json", "validation_report.md", "arena_definition.json", "test_log.txt"]:
		assert_true(FileAccess.file_exists(str(result.directory).path_join(file_name)), file_name)


func _valid_arena(size := Vector2i(10, 8)) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Arene de test", "arena_studio_test")
	arena.background_path = "res://asset/map/painted/room_01_forest/forest_background_v2.webp"
	arena.source_image_size = Vector2i(1376, 768)
	arena.grid_size = size
	arena.grid_origin = Vector2(688, 164)
	arena.axis_x = Vector2(34.4, 17.1)
	arena.axis_y = Vector2(-34.2, 17.0)
	arena.calibration_cells = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]
	arena.calibration_pixels = [arena.grid_origin, arena.grid_origin + arena.axis_x, arena.grid_origin + arena.axis_y]
	for cell in _rectangle_cells(size):
		arena.ensure_cell(cell)
	return arena


func _rectangle_cells(size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(size.y):
		for x in range(size.x):
			result.append(Vector2i(x, y))
	return result
