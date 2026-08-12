extends GutTest


func before_each() -> void:
	ArenaCatalogService.reset_cache()


func test_terrain_catalog_preserves_historical_values_and_complete_active_set() -> void:
	assert_eq(ArenaTerrainRegistry.all_ids(true), [
		&"electrified_water", &"ice", &"lava", &"neutral", &"normal",
		&"poison", &"steam", &"stone", &"void", &"water",
	])
	var expected := {
		&"void": [GridData.CellType.HOLE, false, "", "101722"],
		&"normal": [GridData.CellType.NORMAL, true, "stone.png", "a8b5c3"],
		&"stone": [GridData.CellType.NORMAL, true, "stone.png", "a8b5c3"],
		&"neutral": [GridData.CellType.NORMAL, true, "neutral.png", "d1c29e"],
		&"water": [GridData.CellType.NORMAL, true, "water.png", "38c8ed"],
		&"ice": [GridData.CellType.ICE, true, "ice.png", "c8f4ff"],
		&"lava": [GridData.CellType.LAVA, true, "lava.png", "ff6537"],
		&"poison": [GridData.CellType.NORMAL, true, "poison.png", "6bc72e"],
		&"steam": [GridData.CellType.NORMAL, true, "steam.png", "bfbfbf"],
		&"electrified_water": [
			GridData.CellType.NORMAL, true, "electrified_water.png", "40bfff",
		],
	}
	for terrain_id in expected:
		var definition := ArenaTerrainRegistry.definition_for(terrain_id)
		var legacy := ArenaTerrainRegistry.get_entry(terrain_id)
		assert_not_null(definition, str(terrain_id))
		assert_true(definition.resource_path.ends_with("/%s.tres" % terrain_id))
		assert_eq(definition.schema_version, ArenaTerrainDefinition.CURRENT_SCHEMA_VERSION)
		assert_eq(legacy.cell_type, expected[terrain_id][0], str(terrain_id))
		assert_eq(legacy.walkable, expected[terrain_id][1], str(terrain_id))
		assert_true(str(legacy.visual).ends_with(expected[terrain_id][2]), str(terrain_id))
		assert_eq(str(legacy.color), expected[terrain_id][3], str(terrain_id))
	assert_eq(
		ArenaTerrainRegistry.terrain_id_for_lab_surface(DynamicCellState.Surface.STONE),
		&"stone"
	)
	assert_eq(
		ArenaTerrainRegistry.terrain_id_for_lab_surface(DynamicCellState.Surface.VOID),
		&"void"
	)


func test_wall_catalog_preserves_configs_variants_visuals_and_colors() -> void:
	assert_eq(ArenaWallRegistry.all_ids(), [&"fire", &"ice", &"normal"])
	var expected := {
		&"normal": [DynamicWall.WallVariant.BASE, &"base", "wall_base.png", "d3b69e"],
		&"fire": [DynamicWall.WallVariant.FIRE, &"fire", "wall_fire.png", "ff6b3b"],
		&"ice": [DynamicWall.WallVariant.ICE, &"ice", "wall_ice.png", "a8e8ff"],
	}
	for wall_id in expected:
		var definition := ArenaWallRegistry.definition_for(wall_id)
		var entry := ArenaWallRegistry.get_entry(wall_id)
		assert_not_null(definition)
		assert_eq(definition.variant, expected[wall_id][0])
		assert_eq(definition.wall_config.variant_id, expected[wall_id][1])
		assert_true(str(entry.visual).ends_with(expected[wall_id][2]))
		assert_eq(str(entry.color), expected[wall_id][3])
		assert_eq(ArenaWallRegistry.id_for_variant(definition.variant), wall_id)
		assert_eq(ArenaWallRegistry.id_for_config(definition.wall_config), wall_id)
	assert_eq(DynamicArenaLab.BASE_CONFIG, ArenaWallRegistry.config_for(&"normal"))
	assert_eq(DynamicArenaLab.FIRE_CONFIG, ArenaWallRegistry.config_for(&"fire"))
	assert_eq(DynamicArenaLab.ICE_CONFIG, ArenaWallRegistry.config_for(&"ice"))


func test_forest_theme_is_the_shared_surface_authority() -> void:
	var theme := ArenaCatalogService.theme(&"forest")
	assert_not_null(theme)
	assert_true(theme.validates().is_empty(), str(theme.validates()))
	assert_eq(theme.surface_configs.size(), 4)
	assert_eq(theme.surface_configs.map(func(value): return value.resource_path), [
		"res://battle/dynamic_terrain/surface_configs/forest_none.tres",
		"res://battle/dynamic_terrain/surface_configs/forest_fire.tres",
		"res://battle/dynamic_terrain/surface_configs/forest_water.tres",
		"res://battle/dynamic_terrain/surface_configs/forest_ice.tres",
	])
	var arena := _arena()
	var state := ArenaRuntimeProjectionService.build(arena)
	assert_not_null(state)
	assert_true(state.surface_resolution.ok, str(state.surface_resolution))
	assert_eq(state.surface_resolution.resolved_theme_id, &"forest")
	assert_true(state.surface_resolution.fallback_used)
	assert_eq(state.surface_service.configs.size(), 4)
	for config in theme.surface_configs:
		assert_eq(state.surface_service.configs.get(config.surface), config)


func test_unknown_theme_has_no_silent_forest_fallback() -> void:
	var arena := _arena()
	arena.theme_id = &"unknown_theme"
	var resolution := ArenaThemeRegistry.resolve(arena)
	assert_false(resolution.ok)
	assert_false(resolution.fallback_used)
	assert_true((resolution.surface_configs as Array).is_empty())
	assert_true(str(resolution.warning).begins_with("theme_without_surface_configuration"))
	var state := ArenaRuntimeProjectionService.build(arena)
	assert_eq(state.surface_service.configs.size(), 0)
	var report := ArenaValidator.validate(arena, false)
	assert_true(report.messages.any(func(value):
		return value.code == &"theme_surface_configuration_missing"
	))


func test_dynamic_lab_no_longer_owns_duplicate_catalog_tables() -> void:
	var source := FileAccess.get_file_as_string(
		"res://tools/labs/dynamic_arena/dynamic_arena_lab.gd"
	)
	for obsolete in [
		"const WALL_CONFIGS", "const TEXTURE_PATHS", "const SURFACE_COLORS",
		"const WALL_COLORS", "const SURFACE_ELEMENTS", "const SURFACE_TERRAIN_IDS",
	]:
		assert_false(obsolete in source, obsolete)
	assert_true("ArenaCatalogService.wall_for_variant" in source)
	assert_true("ArenaTerrainRegistry.terrain_id_for_lab_surface" in source)


func _arena() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Catalog fixture", "catalog_fixture")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(4, 3)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	_add_spawn(arena, ArenaSpawnDefinition.Kind.HERO_1, Vector2i(0, 0))
	_add_spawn(arena, ArenaSpawnDefinition.Kind.HERO_2, Vector2i(0, 1))
	_add_spawn(arena, ArenaSpawnDefinition.Kind.HERO_3, Vector2i(0, 2))
	_add_spawn(arena, ArenaSpawnDefinition.Kind.ENEMY, Vector2i(3, 1))
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _add_spawn(arena: ArenaDefinition, kind: int, cell: Vector2i) -> void:
	var spawn := ArenaSpawnDefinition.new()
	spawn.spawn_id = StringName("spawn_%d" % arena.spawns.size())
	spawn.kind = kind
	spawn.cell = cell
	spawn.facing = Vector2i.RIGHT if spawn.is_hero() else Vector2i.LEFT
	arena.spawns.append(spawn)
