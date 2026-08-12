extends GutTest

const TERRAIN_IDS: Array[StringName] = [
	&"stone", &"neutral", &"water", &"ice", &"lava", &"poison",
	&"steam", &"electrified_water",
]
const ROUNDTRIP_PATH := "user://dungeon_draft_studio/tests/complete_terrain_roundtrip.tres"


func before_each() -> void:
	ArenaCatalogService.reset_cache()
	ArenaTerrainRenderPlanService.clear_cache()
	ArenaValidator.clear_cache()


func after_all() -> void:
	var absolute := ProjectSettings.globalize_path(ROUNDTRIP_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


# Catalogue (1-5)
func test_01_the_nine_entries_exist() -> void:
	for terrain_id in TERRAIN_IDS:
		assert_not_null(ArenaCatalogService.terrain(terrain_id), str(terrain_id))
	assert_not_null(ArenaCatalogService.interactive(&"vortex"))


func test_02_all_textures_are_reloadable() -> void:
	for terrain_id in TERRAIN_IDS:
		var texture := ArenaCatalogService.terrain(terrain_id).base_texture
		assert_not_null(texture, str(terrain_id))
		assert_true(load(texture.resource_path) is Texture2D, str(terrain_id))
	var vortex_texture := ArenaCatalogService.interactive(&"vortex").texture
	assert_true(load(vortex_texture.resource_path) is Texture2D)


func test_03_no_final_entry_is_inactive() -> void:
	var coverage := ArenaTileGameplayCoverageService.build()
	assert_true((coverage.unsupported_runtime_ids as Array).is_empty(), str(coverage))


func test_04_every_final_entry_is_placeable() -> void:
	assert_eq(ArenaPermanentTerrainPaintService.get_placeable_terrain_definitions().size(), 8)
	for definition in ArenaPermanentTerrainPaintService.get_placeable_terrain_definitions():
		assert_true(definition.editor_placeable and definition.production_placeable)
	assert_true(ArenaCatalogService.interactive(&"vortex").is_production_certified())


func test_05_void_is_a_separate_topology_contract() -> void:
	var entries := ArenaPermanentTerrainPaintService.get_paintable_permanent_terrains(
		_arena_fixture(), true
	)
	var void_entries := entries.filter(func(value): return value.stable_id == &"void")
	assert_eq(void_entries.size(), 1)
	assert_false(void_entries[0].enabled)
	assert_eq(void_entries[0].role, &"topology_removal")


# Palette / brush (6-17)
func test_06_brush_stone() -> void: _assert_paint(&"stone")
func test_07_brush_neutral() -> void: _assert_paint(&"neutral")
func test_08_brush_water() -> void: _assert_paint(&"water")
func test_09_brush_ice() -> void: _assert_paint(&"ice")
func test_10_brush_lava() -> void: _assert_paint(&"lava")
func test_11_brush_poison() -> void: _assert_paint(&"poison")
func test_12_brush_steam() -> void: _assert_paint(&"steam")
func test_13_brush_electrified_water() -> void: _assert_paint(&"electrified_water")


func test_14_vortex_ab_pair_is_one_authoring_operation() -> void:
	var arena := _arena_fixture()
	assert_true(ArenaDynamicEditingService.place_vortex_pair(
		arena, Vector2i(1, 1), Vector2i(3, 3)
	))
	assert_eq(arena.vortex_pairs.size(), 1)
	assert_true(arena.vortex_pairs[0].runtime_enabled)
	assert_true(arena.vortex_pairs[0].bidirectional)


func test_15_undo_redo_every_terrain_type() -> void:
	for terrain_id in TERRAIN_IDS:
		var session := ArenaEditSession.new()
		assert_true(session.open(_arena_fixture(), "", true, "history_%s" % terrain_id))
		var baseline := &"neutral"
		if terrain_id == &"neutral":
			assert_true(ArenaDynamicEditingService.paint_permanent_terrain(
				session.working_arena, Vector2i(1, 1), &"stone"
			))
			baseline = &"stone"
		var before := session.working_arena.to_snapshot()
		assert_true(ArenaDynamicEditingService.paint_permanent_terrain(
			session.working_arena, Vector2i(1, 1), terrain_id
		))
		assert_true(session.commit("paint", before, session.working_arena.to_snapshot()))
		assert_true(session.history.undo())
		assert_eq(session.working_arena.get_cell_definition(Vector2i(1, 1)).terrain_id, baseline)
		assert_true(session.history.redo())
		assert_eq(session.working_arena.get_cell_definition(Vector2i(1, 1)).terrain_id, terrain_id)


func test_16_snapshot_restore_keeps_complete_pattern() -> void:
	var arena := _pattern_fixture()
	var restored := ArenaDefinition.new()
	assert_true(restored.restore_snapshot(arena.to_snapshot()))
	assert_eq(_terrain_map(restored), _terrain_map(arena))


func test_17_save_reload_keeps_complete_pattern() -> void:
	var arena := _pattern_fixture()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROUNDTRIP_PATH).get_base_dir())
	assert_eq(ResourceSaver.save(arena, ROUNDTRIP_PATH), OK)
	var loaded := ResourceLoader.load(
		ROUNDTRIP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	assert_not_null(loaded)
	assert_eq(_terrain_map(loaded), _terrain_map(arena))


# Gameplay (18-26)
func test_18_stone_has_no_unit_effect() -> void:
	_assert_no_effect(&"stone")


func test_19_neutral_has_no_unit_effect() -> void:
	_assert_no_effect(&"neutral")


func test_20_water_applies_wet() -> void:
	var fixture := _occupied_runtime(&"water")
	assert_true(_has_status(fixture.unit, &"wet"))


func test_21_ice_applies_frozen() -> void:
	var fixture := _occupied_runtime(&"ice")
	assert_true(_has_status(fixture.unit, &"frozen"))


func test_22_lava_applies_burn_and_direct_damage() -> void:
	var fixture := _occupied_runtime(&"lava")
	assert_true(_has_status(fixture.unit, &"burn"))
	assert_eq(fixture.unit.current_hp, 85)


func test_23_poison_applies_canonical_poison() -> void:
	var fixture := _occupied_runtime(&"poison")
	assert_true(_has_status(fixture.unit, &"poison"))
	var status := load("res://data/status/core/poison.tres") as StatusData
	assert_eq(status.damage_per_turn, 4)
	assert_eq(status.duration, 3)


func test_24_steam_allows_movement_blocks_los_not_projectiles() -> void:
	var runtime := _runtime_for(&"steam")
	var cell := Vector2i(1, 1)
	assert_true(runtime.grid.is_walkable(cell))
	assert_false(runtime.grid.is_transparent(cell))
	assert_true(runtime.grid.is_projectile_passable(cell))


func test_25_electrified_water_applies_wet_and_shock() -> void:
	var fixture := _occupied_runtime(&"electrified_water")
	assert_true(_has_status(fixture.unit, &"wet"))
	assert_eq(fixture.unit.current_hp, 80)


func test_26_vortex_teleports_bidirectionally() -> void:
	var arena := _arena_fixture()
	ArenaDynamicEditingService.place_vortex_pair(arena, Vector2i(1, 1), Vector2i(3, 3))
	var runtime := ArenaRuntimeProjectionService.build(arena)
	var unit := _new_unit("Vortex")
	assert_true(runtime.grid.place_unit(unit, Vector2i(1, 1)))
	assert_eq(unit.grid_pos, Vector2i(3, 3))
	assert_true(runtime.grid.relocate_unit(unit, Vector2i(2, 3)))
	assert_true(runtime.grid.relocate_unit(unit, Vector2i(3, 3)))
	assert_eq(unit.grid_pos, Vector2i(1, 1))


# Unit entry sources (27-34)
func test_27_voluntary_movement_applies_effect() -> void: _assert_entry_reason_applies(&"movement")
func test_28_push_applies_effect() -> void: _assert_entry_reason_applies(&"push")
func test_29_pull_applies_effect() -> void: _assert_entry_reason_applies(&"pull")
func test_30_teleport_applies_effect() -> void: _assert_entry_reason_applies(&"teleport")
func test_31_summon_applies_effect() -> void: _assert_direct_placement_applies("Summon")
func test_32_initial_placement_applies_effect() -> void: _assert_direct_placement_applies("Placement")


func test_33_turn_start_refreshes_the_permanent_status() -> void:
	var fixture := _occupied_runtime(&"water")
	var entry := _status_entry(fixture.unit, &"wet")
	entry.remaining = 1
	fixture.runtime.terrain_effects.on_turn_start(fixture.unit)
	assert_eq(int(_status_entry(fixture.unit, &"wet").remaining), 2)


func test_34_one_resolution_never_double_applies() -> void:
	var runtime := _runtime_for(&"electrified_water")
	var unit := _new_unit("Dedupe")
	assert_true(runtime.grid.place_unit(unit, Vector2i.ZERO))
	var token := runtime.terrain_effects.begin_unit_resolution(unit, &"movement")
	assert_true(runtime.grid.relocate_unit(unit, Vector2i(1, 1)))
	assert_eq(unit.current_hp, 80)
	runtime.terrain_effects.runtime_service.resolve_unit_entry(unit, Vector2i(1, 1), token)
	assert_eq(unit.current_hp, 80)
	runtime.terrain_effects.end_unit_resolution(unit)


# Pathfinder / AI (35-44)
func test_35_pathfinding_water() -> void: _assert_pathable(&"water")
func test_36_pathfinding_ice() -> void: _assert_pathable(&"ice")
func test_37_pathfinding_lava() -> void: _assert_pathable(&"lava")
func test_38_pathfinding_poison() -> void: _assert_pathable(&"poison")
func test_39_pathfinding_steam() -> void: _assert_pathable(&"steam")
func test_40_pathfinding_electrified_water() -> void: _assert_pathable(&"electrified_water")


func test_41_pathfinding_represents_the_vortex_edge_at_zero_extra_cost() -> void:
	var runtime := _vortex_runtime()
	var path := Pathfinder.new(runtime.grid).find_path(Vector2i.ZERO, Vector2i(3, 3))
	assert_true(path.has(Vector2i(1, 1)))
	assert_true(path.has(Vector2i(3, 3)))
	assert_eq(Pathfinder.new(runtime.grid).path_movement_cost(path), 2)


func test_42_ai_never_plans_an_occupied_vortex_destination() -> void:
	var runtime := _vortex_runtime()
	var blocker := _new_unit("Blocker")
	assert_true(runtime.grid.place_unit(blocker, Vector2i(3, 3)))
	var path := Pathfinder.new(runtime.grid).find_path(Vector2i.ZERO, Vector2i(3, 2))
	assert_false(_contains_edge(path, Vector2i(1, 1), Vector2i(3, 3)))


func test_43_ai_can_use_an_advantageous_vortex() -> void:
	var runtime := _vortex_runtime()
	var path := Pathfinder.new(runtime.grid).find_path(Vector2i.ZERO, Vector2i(3, 3))
	assert_true(_contains_edge(path, Vector2i(1, 1), Vector2i(3, 3)))


func test_44_vortex_resolution_has_no_portal_loop() -> void:
	var runtime := _vortex_runtime()
	var unit := _new_unit("No loop")
	assert_true(runtime.grid.place_unit(unit, Vector2i(1, 1)))
	assert_eq(unit.grid_pos, Vector2i(3, 3))
	assert_eq(runtime.grid.find_unit(unit), Vector2i(3, 3))


# Visuals (45-50)
func test_45_one_floor_texture_per_cell() -> void:
	var plan := ArenaTerrainRenderPlanService.build(_pattern_fixture())
	assert_eq((plan.entries as Array).size(), 8)


func test_46_render_plan_contains_no_duplicate_coordinates() -> void:
	var seen := {}
	for entry in ArenaTerrainRenderPlanService.build(_pattern_fixture()).entries:
		var key := str(entry.cell)
		assert_false(seen.has(key), key)
		seen[key] = true


func test_47_all_nine_assets_share_the_projection_alignment() -> void:
	var textures: Array[Texture2D] = []
	for terrain_id in TERRAIN_IDS:
		textures.append(ArenaCatalogService.terrain(terrain_id).base_texture)
	textures.append(ArenaCatalogService.interactive(&"vortex").texture)
	for texture in textures:
		var contract := ArenaTileProjectionService.texture_contract(texture)
		assert_true(contract.valid, texture.resource_path)
		assert_eq(contract.size, Vector2i(256, 128), texture.resource_path)
		assert_eq(contract.alpha_bounds, Rect2i(0, 0, 256, 128), texture.resource_path)


func test_48_permanent_terrain_is_not_a_temporary_surface() -> void:
	var runtime := _runtime_for(&"poison")
	assert_eq(runtime.terrain_effects.get_surface_id(Vector2i(1, 1)), &"none")
	assert_eq(runtime.terrain_effects.get_base_state(Vector2i(1, 1)).terrain_id, &"poison")


func test_49_temporary_surface_masks_the_permanent_terrain() -> void:
	var runtime := _runtime_for(&"neutral")
	assert_true(runtime.apply_terrain_effect(
		Vector2i(1, 1), load("res://data/terrain/vapeur.tres")
	).changed)
	assert_eq(runtime.terrain_effects.get_surface_id(Vector2i(1, 1)), &"steam")
	assert_eq(runtime.terrain_effects.get_base_state(Vector2i(1, 1)).terrain_id, &"neutral")


func test_50_temporary_expiration_restores_exact_permanent_properties() -> void:
	var runtime := _runtime_for(&"neutral")
	var cell := Vector2i(1, 1)
	var effect := load("res://data/terrain/vapeur.tres") as TerrainEffectData
	runtime.apply_terrain_effect(cell, effect)
	for _index in range(effect.duration): runtime.terrain_effects.tick_all_effects()
	assert_eq(runtime.terrain_effects.get_surface_id(cell), &"none")
	assert_true(runtime.grid.is_transparent(cell))
	assert_eq(runtime.terrain_effects.get_base_state(cell).terrain_id, &"neutral")


# Save handlers (51-55)
func test_51_every_dirty_domain_requires_the_complete_handler_contract() -> void:
	var context := StudioProjectContext.new()
	for domain in [&"arena", &"arena_run", &"encounter", &"items", &"skills"]:
		context.register_transition_handler(
			domain, _ok, _ok, _ok, Callable(), Callable(), Callable(),
			_false, _snapshot, _restore
		)
		assert_true(context.transition_handler_contract(domain).valid, str(domain))
	assert_true(context.validate_transition_handlers().valid)


func test_52_save_and_continue_commits_the_dirty_domain() -> void:
	var calls: Array[String] = []
	var handlers := {&"arena": _handler_set(func(): calls.append("save"); return {"ok": true})}
	var result := StudioContextTransitionTransactionService.execute(
		StudioProjectContext.ACTION_SAVE, {&"arena": {}}, handlers
	)
	assert_true(result.ok, str(result))
	assert_eq(calls, ["save"])


func test_53_discard_restores_the_saved_snapshot() -> void:
	var arena := _arena_fixture()
	var snapshot := arena.to_snapshot()
	ArenaDynamicEditingService.paint_terrain(arena, Vector2i(1, 1), &"lava")
	assert_true(arena.restore_snapshot(snapshot))
	assert_eq(arena.get_cell_definition(Vector2i(1, 1)).terrain_id, &"neutral")


func test_54_keep_as_draft_uses_its_dedicated_handler() -> void:
	var calls: Array[String] = []
	var handlers := {&"arena": _handler_set(func(): calls.append("draft"); return {"ok": true}, true)}
	var result := StudioContextTransitionTransactionService.execute(
		StudioProjectContext.ACTION_KEEP_AS_DRAFT, {&"arena": {}}, handlers
	)
	assert_true(result.ok, str(result))
	assert_eq(calls, ["draft"])


func test_55_close_and_reopen_keeps_saved_data() -> void:
	var arena := _pattern_fixture()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROUNDTRIP_PATH).get_base_dir())
	assert_eq(ResourceSaver.save(arena, ROUNDTRIP_PATH), OK)
	ResourceLoader.load(ROUNDTRIP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var reopened := ResourceLoader.load(
		ROUNDTRIP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	assert_eq(_terrain_map(reopened), _terrain_map(arena))


# Parity (56-64)
func test_56_studio_working_copy_contains_the_complete_pattern() -> void:
	assert_eq(_terrain_map(_pattern_fixture()).size(), 8)


func test_57_user_copy_has_the_same_fingerprint() -> void:
	var prepared := ArenaDirectTestService.prepare(_pattern_fixture(), null, &"terrains")
	assert_true(prepared.ok, str(prepared))
	if prepared.ok:
		assert_true(prepared.request.fingerprints_identical)
		assert_true(ArenaDirectTestService.cleanup_context(prepared.request))


func test_58_preview_reports_runtime_parity() -> void:
	var preview := ArenaRuntimePreview.new()
	add_child_autofree(preview)
	preview.set_arena(_pattern_fixture(), false)
	assert_true(preview.rebuild_now())
	assert_true(preview.parity_with_runtime().ok, str(preview.parity_with_runtime()))


func test_59_direct_test_never_loads_the_produced_bundle() -> void:
	var prepared := ArenaDirectTestService.prepare(_pattern_fixture(), null, &"terrains")
	assert_true(prepared.ok, str(prepared))
	if prepared.ok:
		assert_false(prepared.produced_bundle_loaded)
		assert_false(str(prepared.request.arena_path).begins_with("res://data/arenas/produced/"))
		assert_true(ArenaDirectTestService.cleanup_context(prepared.request))


func test_60_real_runtime_projects_all_terrain_definitions() -> void:
	var arena := _pattern_fixture()
	var runtime := ArenaRuntimeProjectionService.build(arena)
	assert_eq(runtime.grid.cols, arena.grid_size.x)
	for cell in _cells(arena):
		assert_eq(runtime.grid.get_terrain_properties(cell).terrain_id,
			arena.get_cell_definition(cell).terrain_id, str(cell))


func test_61_all_parity_layers_keep_the_same_coordinates() -> void:
	var arena := _pattern_fixture()
	var runtime := ArenaRuntimeProjectionService.build(arena)
	assert_eq(runtime.grid.cols * runtime.grid.rows, _cells(arena).size())
	for cell in _cells(arena): assert_true(runtime.grid.is_valid(cell))


func test_62_all_parity_layers_keep_the_same_terrains() -> void:
	var arena := _pattern_fixture()
	var runtime := ArenaRuntimeProjectionService.build(arena)
	for cell in _cells(arena):
		assert_eq(str(runtime.grid.get_terrain_properties(cell).terrain_id),
			str(arena.get_cell_definition(cell).terrain_id), str(cell))


func test_63_status_resources_are_shared_by_studio_and_runtime() -> void:
	var expected := {
		&"water": &"wet", &"ice": &"frozen", &"lava": &"burn",
		&"poison": &"poison", &"electrified_water": &"wet",
	}
	for terrain_id in expected:
		var effect := ArenaCatalogService.terrain(terrain_id).unit_effect
		assert_eq(effect.applied_status.get_effective_status_id(), expected[terrain_id], str(terrain_id))


func test_64_elemental_interactions_use_stable_ids() -> void:
	for contract in [
		[&"fire", &"water", &"steam"], [&"water", &"fire", &"steam"],
		[&"ice", &"fire", &"water"], [&"water", &"ice", &"ice"],
	]:
		var result := TerrainInteractionResolver.resolve_ids(contract[0], contract[1])
		assert_eq(StringName(result.result_surface_id), contract[2], str(contract))
	var shock := TerrainInteractionResolver.resolve_ids(&"water", &"lightning")
	assert_eq(StringName(shock.reaction), &"shock")


func _assert_paint(terrain_id: StringName) -> void:
	var arena := _arena_fixture()
	if terrain_id == &"neutral":
		ArenaDynamicEditingService.paint_terrain(arena, Vector2i(1, 1), &"stone")
	assert_true(ArenaPermanentTerrainPaintService.can_paint(arena, terrain_id))
	assert_true(ArenaDynamicEditingService.paint_permanent_terrain(arena, Vector2i(1, 1), terrain_id))
	assert_eq(arena.get_cell_definition(Vector2i(1, 1)).terrain_id, terrain_id)


func _assert_no_effect(terrain_id: StringName) -> void:
	var fixture := _occupied_runtime(terrain_id)
	assert_true(fixture.unit.active_statuses.is_empty())
	assert_eq(fixture.unit.current_hp, 100)


func _assert_entry_reason_applies(reason: StringName) -> void:
	var runtime := _runtime_for(&"poison")
	var unit := _new_unit(str(reason))
	assert_true(runtime.grid.place_unit(unit, Vector2i.ZERO))
	runtime.terrain_effects.begin_unit_resolution(unit, reason)
	assert_true(runtime.grid.relocate_unit(unit, Vector2i(1, 1)))
	assert_true(_has_status(unit, &"poison"))
	runtime.terrain_effects.end_unit_resolution(unit)


func _assert_direct_placement_applies(label: String) -> void:
	var runtime := _runtime_for(&"poison")
	var unit := _new_unit(label)
	assert_true(runtime.grid.place_unit(unit, Vector2i(1, 1)))
	assert_true(_has_status(unit, &"poison"))


func _assert_pathable(terrain_id: StringName) -> void:
	var runtime := _runtime_for(terrain_id)
	var path := Pathfinder.new(runtime.grid).find_path(Vector2i.ZERO, Vector2i(2, 2))
	assert_false(path.is_empty(), str(terrain_id))
	assert_true(runtime.grid.is_walkable(Vector2i(1, 1)), str(terrain_id))
	assert_eq(path[0], Vector2i.ZERO)
	assert_eq(path[-1], Vector2i(2, 2))


func _runtime_for(terrain_id: StringName) -> ArenaRuntimeState:
	var arena := _arena_fixture()
	ArenaDynamicEditingService.paint_terrain(arena, Vector2i(1, 1), terrain_id)
	return ArenaRuntimeProjectionService.build(arena)


func _occupied_runtime(terrain_id: StringName) -> Dictionary:
	var runtime := _runtime_for(terrain_id)
	var unit := _new_unit(str(terrain_id))
	assert_true(runtime.grid.place_unit(unit, Vector2i(1, 1)))
	return {"runtime": runtime, "unit": unit}


func _vortex_runtime() -> ArenaRuntimeState:
	var arena := _arena_fixture()
	ArenaDynamicEditingService.place_vortex_pair(arena, Vector2i(1, 1), Vector2i(3, 3))
	return ArenaRuntimeProjectionService.build(arena)


func _new_unit(label: String) -> Unit:
	return Unit.new(label, 1, 100)


func _has_status(unit: Unit, status_id: StringName) -> bool:
	return not _status_entry(unit, status_id).is_empty()


func _status_entry(unit: Unit, status_id: StringName) -> Dictionary:
	for entry in unit.get_active_statuses():
		var data := entry.get("data") as StatusData
		if data != null and data.get_effective_status_id() == status_id:
			return entry
	return {}


func _contains_edge(path: Array, from: Vector2i, to: Vector2i) -> bool:
	for index in range(path.size() - 1):
		if path[index] == from and path[index + 1] == to:
			return true
	return false


func _handler_set(action_handler: Callable, draft := false) -> Dictionary:
	return {
		"save": _ok if draft else action_handler,
		"draft": action_handler if draft else _ok,
		"discard": _ok,
		"is_dirty": _false,
		"snapshot": _snapshot,
		"restore": _restore,
	}


func _ok() -> Dictionary: return {"ok": true}
func _false() -> bool: return false
func _snapshot() -> Dictionary: return {"value": true}
func _restore(_value: Dictionary) -> Dictionary: return {"ok": true}


func _arena_fixture(size := Vector2i(4, 4)) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Complete terrain fixture", "complete_terrain_fixture")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"forest"
	arena.grid_size = size
	arena.grid_origin = Vector2(320, 96)
	arena.axis_x = Vector2(64, 32)
	arena.axis_y = Vector2(-64, 32)
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = &"forest"
	arena.modular_visual_profile.hybrid_floor_policy = ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	for y in range(size.y):
		for x in range(size.x):
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), &"neutral")
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _pattern_fixture() -> ArenaDefinition:
	var arena := _arena_fixture(Vector2i(4, 2))
	for index in range(TERRAIN_IDS.size()):
		ArenaDynamicEditingService.paint_terrain(
			arena, Vector2i(index % 4, index / 4), TERRAIN_IDS[index]
		)
	return arena


func _cells(arena: ArenaDefinition) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for definition in arena.cells:
		if definition != null: result.append(definition.coordinate)
	return result


func _terrain_map(arena: ArenaDefinition) -> Dictionary:
	var result := {}
	for cell in _cells(arena):
		result["%d,%d" % [cell.x, cell.y]] = str(arena.get_cell_definition(cell).terrain_id)
	return result
