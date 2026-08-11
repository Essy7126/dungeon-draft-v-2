extends GutTest

const INVENTORY_PATH := "res://artifacts/extended_terrain_catalog/asset_inventory.json"
const WATER_PATH := "res://data/terrain/eau.tres"


func before_each() -> void:
	ArenaCatalogService.reset_cache()
	ArenaValidator.clear_cache()


func test_asset_inventory_maps_the_five_announced_roles_without_renaming() -> void:
	assert_true(FileAccess.file_exists(INVENTORY_PATH))
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(INVENTORY_PATH))
	assert_true(parsed is Dictionary)
	assert_eq(parsed.mapping_verdict, "UNAMBIGUOUS_FOR_REQUESTED_FIVE")
	assert_eq(parsed.role_mapping, {
		"neutral": "res://tools/labs/dynamic_arena/assets/raw/neutre.png",
		"poison": "res://tools/labs/dynamic_arena/assets/raw/poison.png",
		"steam": "res://tools/labs/dynamic_arena/assets/raw/vapeur.png",
		"electrified_water": "res://tools/labs/dynamic_arena/assets/raw/électrique.png",
		"vortex": "res://tools/labs/dynamic_arena/assets/raw/vortex.png",
	})
	assert_eq((parsed.assets as Array).size(), 10)
	for asset in parsed.assets:
		assert_eq(int(asset.width), 1024, asset.name)
		assert_eq(int(asset.height), 1024, asset.name)
		assert_true(asset.has_alpha, asset.name)
		assert_eq(str(asset.sha256).length(), 64, asset.name)
		assert_true(ResourceLoader.exists(asset.resource_path), asset.resource_path)
		assert_true(load(asset.resource_path) is Texture2D, asset.resource_path)


func test_catalogs_keep_permanent_surface_reaction_and_spatial_families_separate() -> void:
	var neutral := ArenaCatalogService.terrain(&"neutral")
	assert_not_null(neutral)
	assert_true(neutral.base_texture.resource_path.ends_with("normalized/neutral.png"))
	assert_eq(neutral.cell_type, GridData.CellType.NORMAL)
	assert_true(neutral.walkable)
	for surface_id in [&"steam", &"poison", &"electrified_water"]:
		var visual := ArenaCatalogService.surface_visual(surface_id)
		assert_not_null(visual, str(surface_id))
		assert_not_null(visual.texture, str(surface_id))
	assert_eq(
		ArenaCatalogService.surface_visual(&"steam").category,
		ArenaSurfaceVisualDefinition.Category.TEMPORARY_SURFACE
	)
	assert_eq(
		ArenaCatalogService.surface_visual(&"electrified_water").category,
		ArenaSurfaceVisualDefinition.Category.VISUAL_REACTION
	)
	var vortex := ArenaCatalogService.interactive(&"vortex")
	assert_not_null(vortex)
	assert_true(vortex.editor_placeable)
	assert_false(vortex.runtime_supported)
	assert_false(vortex.is_production_certified())


func test_neutral_is_paintable_and_available_as_a_base_terrain() -> void:
	var arena := _arena_fixture()
	var cell := Vector2i(2, 2)
	assert_true(ArenaDynamicEditingService.paint_terrain(arena, cell, &"neutral"))
	var painted := arena.get_cell_definition(cell)
	assert_eq(painted.terrain_id, &"neutral")
	assert_eq(painted.cell_type, GridData.CellType.NORMAL)
	assert_true(painted.defined)
	assert_true(painted.playable)
	assert_true(ArenaModularVisualProfile.new().terrain_ids.has(&"neutral"))
	var plan := ArenaTerrainRenderPlanService.entry_for(arena, cell)
	assert_true(plan.visible)
	assert_true(str(plan.texture_path).ends_with("normalized/neutral.png"))


func test_neutral_keeps_exact_identity_through_direct_test_copy_and_render_plan() -> void:
	var arena := _arena_fixture()
	arena.modular_visual_profile.base_terrain_id = &"neutral"
	assert_true(ArenaDynamicEditingService.paint_terrain(
		arena, Vector2i(2, 2), &"neutral"
	))
	var working_fingerprint := ArenaSnapshotService.arena_fingerprint(arena)
	var prepared := ArenaDirectTestService.prepare(arena, null, &"no_characters")
	assert_true(prepared.ok, str(prepared))
	if not bool(prepared.get("ok", false)):
		return
	var request := prepared.request as Dictionary
	assert_true(str(request.arena_path).begins_with(
		ArenaDirectTestService.WORK_ROOT + "/"
	))
	assert_false(str(request.arena_path).begins_with(
		"res://data/arenas/produced/"
	))
	assert_true(request.fingerprints_identical)
	assert_eq(request.working_fingerprint, working_fingerprint)
	assert_eq(request.working_fingerprint, request.temporary_fingerprint)
	assert_eq(request.working_fingerprint, request.runtime_fingerprint)
	var temporary := ResourceLoader.load(
		request.arena_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	assert_not_null(temporary)
	if temporary != null:
		assert_eq(temporary.modular_visual_profile.base_terrain_id, &"neutral")
		assert_eq(temporary.get_cell_definition(Vector2i(2, 2)).terrain_id, &"neutral")
		var plan := ArenaTerrainRenderPlanService.entry_for(
			temporary, Vector2i(2, 2)
		)
		assert_true(plan.visible)
		assert_true(str(plan.texture_path).ends_with("normalized/neutral.png"))
	assert_false(prepared.produced_bundle_loaded)
	assert_true(ArenaDirectTestService.cleanup_context(request))


func test_coverage_matrix_reports_only_observed_gameplay() -> void:
	var report := ArenaTileGameplayCoverageService.build()
	assert_eq((report.entries as Array).size(), 8)
	var neutral := ArenaTileGameplayCoverageService.entry(&"neutral")
	assert_eq(neutral.category, "permanent_terrain")
	assert_true(neutral.runtime_supported)
	assert_true(neutral.production_placeable)
	var steam := ArenaTileGameplayCoverageService.entry(&"steam")
	assert_eq(steam.category, "temporary_surface")
	assert_eq(steam.duration, 2)
	assert_eq(steam.damage, 0)
	assert_eq(steam.visual_terrain_id, "steam")
	var electric := ArenaTileGameplayCoverageService.entry(&"electrified_water")
	assert_eq(electric.category, "visual_reaction")
	assert_eq(electric.damage, TerrainSurfaceRuntimeService.REACTION_DAMAGE)
	assert_eq(electric.duration, 0)
	assert_false(electric.runtime_supported)
	assert_true(electric.visual_event_supported)
	assert_false(electric.canonical_producer_present)
	var poison := ArenaTileGameplayCoverageService.entry(&"poison")
	assert_false(poison.runtime_supported)
	assert_eq(poison.canonical_resource, "")
	assert_false(ResourceLoader.exists("res://data/terrain/poison.tres"))
	var lava := ArenaTileGameplayCoverageService.entry(&"lava")
	assert_eq(lava.cell_type, GridData.CellType.WALL)
	assert_eq(lava.runtime_surface_cell_type, GridData.CellType.LAVA)
	assert_false(lava.runtime_supported)
	assert_false(lava.production_placeable)


func test_steam_reaction_uses_canonical_duration_and_visual_without_mutation() -> void:
	var state := ArenaRuntimeProjectionService.build(_arena_fixture())
	var cell := Vector2i(2, 2)
	var fire := load("res://data/terrain/lave.tres") as TerrainEffectData
	var water := load(WATER_PATH) as TerrainEffectData
	var steam_resource := load("res://data/terrain/vapeur.tres") as TerrainEffectData
	var fingerprint := RoomDataSnapshotService.room_fingerprint(_arena_fixture())
	assert_true(state.apply_terrain_effect(cell, fire).changed)
	var result := state.apply_terrain_effect(cell, water)
	assert_eq(result.reaction, "steam")
	assert_eq(state.terrain_effects.get_surface_id(cell), &"steam")
	assert_eq(state.terrain_effects.get_visual_terrain_id(cell), &"steam")
	assert_eq(state.terrain_effects.get_remaining_duration(cell), 2)
	assert_eq(steam_resource.damage, 0)
	assert_true(steam_resource.blocks_vision)
	var visual := TerrainSurfaceVisualResolver.resolve(&"steam")
	assert_true(visual.ok)
	assert_true(str((visual.texture as Texture2D).resource_path).ends_with("vapeur.png"))
	assert_eq(fingerprint, RoomDataSnapshotService.room_fingerprint(_arena_fixture()))


func test_shock_rule_damages_cross_clears_water_and_emits_exact_fact() -> void:
	var grid := GridData.new(5, 5)
	var terrain := TerrainEffects.new(grid)
	assert_true(terrain.capture_base_state().ok)
	var center := Vector2i(2, 2)
	var unit := Unit.new("Shock fixture", 1, 100)
	assert_true(grid.place_unit(unit, center))
	assert_true(terrain.place_effect(center, load(WATER_PATH)).changed)
	var facts: Array[Dictionary] = []
	terrain.surface_reaction.connect(func(fact: Dictionary): facts.append(fact))
	var lightning := TerrainEffectData.new()
	lightning.effect_name = "foudre"
	lightning.surface_id = &"lightning"
	lightning.visual_terrain_id = &""
	lightning.duration = 0
	var result := terrain.place_effect(center, lightning)
	assert_eq(result.reaction, "shock")
	assert_eq(unit.current_hp, 80)
	assert_eq(terrain.get_surface_id(center), &"none")
	assert_eq(facts.size(), 1)
	assert_eq(facts[0].reaction, &"shock")
	assert_eq(facts[0].result_surface, &"none")
	assert_eq(facts[0].duration, 0)


func test_shock_event_uses_electrified_visual_for_one_rendered_frame() -> void:
	var state := ArenaRuntimeProjectionService.build(_arena_fixture())
	var root := Node2D.new()
	add_child_autofree(root)
	var floor_layer := Node2D.new()
	root.add_child(floor_layer)
	var dynamic_layer := Node2D.new()
	root.add_child(dynamic_layer)
	var grid_view := PaintedGridView.new()
	grid_view.configure(
		state.visual_data, state.layout, state.hero_spawns, state.enemy_spawns
	)
	grid_view.setup(state.grid)
	root.add_child(grid_view)
	var adapter := DynamicSurfaceVisualAdapter.new()
	root.add_child(adapter)
	adapter.configure(state.terrain_effects.runtime_service, grid_view, dynamic_layer)
	var cell := Vector2i(2, 2)
	assert_true(state.apply_terrain_effect(cell, load(WATER_PATH)).changed)
	var lightning := TerrainEffectData.new()
	lightning.effect_name = "foudre"
	lightning.surface_id = &"lightning"
	var result := state.apply_terrain_effect(cell, lightning)
	assert_eq(result.reaction, "shock")
	var reaction_node := adapter.node_for_cell(cell)
	assert_not_null(reaction_node)
	assert_eq(reaction_node.get_meta("renderer_role"), &"surface_reaction")
	assert_eq(reaction_node.get_meta("visual_terrain_id"), &"electrified_water")
	var render_report := adapter.renderer.actual_render_report()
	assert_true(str(render_report.cells["2,2"].texture_path).ends_with("électrique.png"))
	await wait_process_frames(3)
	assert_null(adapter.node_for_cell(cell))


func test_vortex_pair_round_trip_is_authorable_but_runtime_and_production_blocked() -> void:
	var arena := _arena_fixture()
	assert_true(ArenaDynamicEditingService.place_vortex_pair(
		arena, Vector2i(1, 1), Vector2i(3, 3)
	))
	assert_eq(arena.vortex_pairs.size(), 1)
	assert_eq(arena.vortex_pairs[0].pair_id, &"vortex_pair_001")
	assert_false(arena.vortex_pairs[0].runtime_enabled)
	var restored := ArenaDefinition.new()
	assert_true(restored.restore_snapshot(arena.to_snapshot()))
	assert_eq(restored.vortex_pairs.size(), 1)
	assert_eq(restored.vortex_pairs[0].entry_cell, Vector2i(1, 1))
	assert_eq(restored.vortex_pairs[0].exit_cell, Vector2i(3, 3))
	var report := ArenaValidator.validate(arena, false)
	assert_true(report.messages.any(func(value):
		return value.code == &"vortex_runtime_uncertified"
	))
	var direct := ArenaDirectTestService.prepare(arena, null, &"terrains")
	assert_false(direct.ok)
	assert_eq(direct.error, "vortex_runtime_uncertified")
	assert_false(direct.produced_bundle_loaded)
	assert_true(ArenaDynamicEditingService.remove_special(arena, Vector2i(1, 1)))
	assert_true(arena.vortex_pairs.is_empty())


func test_new_stored_fields_are_explicitly_classified() -> void:
	var runtime_coverage := ArenaRuntimeFieldCoverageService.scan()
	assert_true(runtime_coverage.production_gate_valid, str(runtime_coverage.unknown))
	assert_true((runtime_coverage.entries as Array).any(func(value):
		return value.key == "ArenaDefinition.vortex_pairs" \
			and value.classification == "FUTURE_EXPLICIT"
	))
	var integration_coverage := RoomIntegrationFieldPolicy.coverage_report(
		ArenaDefinition.new()
	)
	assert_true(integration_coverage.ok, str(integration_coverage.unknown))
	assert_eq(integration_coverage.classified.vortex_pairs, "ARENA_OWNED")


func _arena_fixture() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Extended terrain fixture", "extended_terrain_fixture")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"forest"
	arena.grid_size = Vector2i(5, 5)
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = &"forest"
	arena.modular_visual_profile.hybrid_floor_policy = (
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena
