extends GutTest

const PERMANENT_IDS: Array[StringName] = [
	&"stone", &"neutral", &"water", &"ice", &"lava", &"poison",
	&"steam", &"electrified_water",
]
const ROUNDTRIP_PATH := (
	"user://dungeon_draft_studio/tests/permanent_tile_alignment_roundtrip.tres"
)


class GridViewFixture:
	extends Node2D
	var arena: ArenaDefinition

	func _init(value: ArenaDefinition) -> void:
		arena = value

	func get_cell_polygon(cell: Vector2i) -> PackedVector2Array:
		return GridTransformService.cell_polygon(
			cell, arena.grid_origin, arena.axis_x, arena.axis_y
		)


func before_each() -> void:
	ArenaCatalogService.reset_cache()
	ArenaTerrainRenderPlanService.clear_cache()


func after_all() -> void:
	var absolute := ProjectSettings.globalize_path(ROUNDTRIP_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func test_01_neutral_exists_in_catalog() -> void:
	var definition := ArenaCatalogService.terrain(&"neutral")
	assert_not_null(definition)
	assert_eq(definition.stable_id, &"neutral")
	assert_true(definition.dynamic_catalog)


func test_02_stone_exists_in_catalog() -> void:
	var definition := ArenaCatalogService.terrain(&"stone")
	assert_not_null(definition)
	assert_eq(definition.stable_id, &"stone")
	assert_true(definition.dynamic_catalog)


func test_03_neutral_and_stone_textures_are_reloadable() -> void:
	for terrain_id in [&"neutral", &"stone"]:
		var texture := ArenaTerrainRegistry.texture_for(terrain_id)
		assert_not_null(texture, str(terrain_id))
		assert_true(ResourceLoader.exists(texture.resource_path), str(terrain_id))
		assert_true(load(texture.resource_path) is Texture2D, str(terrain_id))


func test_04_catalog_distinguishes_active_and_informational_entries() -> void:
	var entries := ArenaPermanentTerrainPaintService \
		.get_paintable_permanent_terrains(_arena_fixture(), true)
	assert_eq(
		entries.size(),
		ArenaPermanentTerrainPaintService.get_placeable_terrain_definitions().size() + 1
	)
	assert_eq(
		entries.filter(func(value): return value.enabled).size(),
		ArenaPermanentTerrainPaintService.get_placeable_terrain_definitions().size()
	)
	var void_entry: Dictionary = entries.filter(func(value):
		return StringName(value.stable_id) == &"void"
	)[0]
	assert_false(void_entry.enabled)
	assert_eq(void_entry.reason_code, &"topology_tool_required")


func test_05_all_permanent_tiles_share_the_normalized_projection_contract() -> void:
	for terrain_id in PERMANENT_IDS:
		var contract := ArenaTileProjectionService.texture_contract(
			ArenaTerrainRegistry.texture_for(terrain_id)
		)
		assert_true(contract.valid, "%s: %s" % [terrain_id, contract])
		assert_eq(contract.size, Vector2i(256, 128), str(terrain_id))


func test_06_neutral_has_no_special_offset_or_transform() -> void:
	var polygon := PackedVector2Array([
		Vector2(0, -32), Vector2(64, 0), Vector2(0, 32), Vector2(-64, 0),
	])
	var neutral_transform := ArenaTileProjectionService.sprite_transform(
		ArenaTerrainRegistry.texture_for(&"neutral"), polygon, Vector2.ZERO
	)
	var stone_transform := ArenaTileProjectionService.sprite_transform(
		ArenaTerrainRegistry.texture_for(&"stone"), polygon, Vector2.ZERO
	)
	assert_eq(neutral_transform, stone_transform)
	assert_eq(neutral_transform.origin, stone_transform.origin)


func test_07_normalized_useful_bounds_are_identical() -> void:
	var expected := Rect2i(0, 0, 256, 128)
	for terrain_id in PERMANENT_IDS:
		var contract := ArenaTileProjectionService.texture_contract(
			ArenaTerrainRegistry.texture_for(terrain_id)
		)
		assert_eq(contract.alpha_bounds, expected, str(terrain_id))


func test_08_neutral_2_by_2_pattern_has_four_exact_render_nodes() -> void:
	var arena := _arena_fixture(Vector2i(2, 2))
	for cell in _declared_cells(arena):
		assert_true(ArenaDynamicEditingService.paint_permanent_terrain(
			arena, cell, &"neutral"
		))
	var rendered := _render(arena)
	assert_eq(rendered.report.rendered_terrain_node_count, 4)
	assert_eq(rendered.report.rendered_by_terrain_id.get("neutral", 0), 4)
	for value in rendered.report.cells.values():
		assert_eq(value.duplication_count, 1)


func test_09_mixed_stone_neutral_edges_keep_one_shared_geometry() -> void:
	var arena := _arena_fixture(Vector2i(3, 2))
	for cell in _declared_cells(arena):
		var terrain_id := &"neutral" if (cell.x + cell.y) % 2 == 0 else &"stone"
		ArenaDynamicEditingService.paint_terrain(arena, cell, terrain_id)
	var rendered := _render(arena)
	assert_eq(rendered.report.rendered_terrain_node_count, 6)
	assert_eq(rendered.report.rendered_by_terrain_id.get("neutral", 0), 3)
	assert_eq(rendered.report.rendered_by_terrain_id.get("stone", 0), 3)
	var transforms := []
	for value in rendered.report.cells.values():
		transforms.append(value.transform)
	for transform in transforms:
		assert_eq(transform, transforms[0])


func test_10_brush_paints_neutral_into_working_copy() -> void:
	_assert_brush_mutation(&"neutral", Vector2i(1, 1))


func test_11_brush_paints_stone_into_working_copy() -> void:
	var arena := _arena_fixture()
	ArenaDynamicEditingService.paint_terrain(arena, Vector2i(1, 1), &"neutral")
	assert_true(ArenaDynamicEditingService.paint_permanent_terrain(
		arena, Vector2i(1, 1), &"stone"
	))
	assert_eq(arena.get_cell_definition(Vector2i(1, 1)).terrain_id, &"stone")


func test_12_brush_paints_water_when_active() -> void:
	_assert_brush_mutation(&"water", Vector2i(1, 1))


func test_13_brush_paints_ice_when_active() -> void:
	_assert_brush_mutation(&"ice", Vector2i(1, 1))


func test_14_lava_is_dangerous_walkable_and_paintable() -> void:
	var arena := _arena_fixture()
	var paintability := ArenaPermanentTerrainPaintService.paintability(
		arena, &"lava"
	)
	assert_true(paintability.enabled)
	assert_true(paintability.walkable)
	assert_true(ArenaDynamicEditingService.paint_permanent_terrain(
		arena, Vector2i(1, 1), &"lava"
	))
	assert_eq(arena.get_cell_definition(Vector2i(1, 1)).terrain_id, &"lava")


func test_15_every_active_dropdown_entry_is_effectively_paintable() -> void:
	var arena := _arena_fixture()
	var entries := ArenaPermanentTerrainPaintService \
		.get_paintable_permanent_terrains(arena, true)
	var cell := Vector2i(1, 1)
	for entry in entries:
		if not bool(entry.enabled):
			continue
		var terrain_id := StringName(entry.stable_id)
		if arena.get_cell_definition(cell).terrain_id == terrain_id:
			ArenaDynamicEditingService.paint_terrain(arena, cell, &"neutral")
		assert_true(
			ArenaDynamicEditingService.paint_permanent_terrain(arena, cell, terrain_id),
			str(terrain_id)
		)
		assert_eq(arena.get_cell_definition(cell).terrain_id, terrain_id)


func test_16_non_paintable_entries_are_disabled_in_both_dropdowns() -> void:
	var studio := ArenaStudioMain.new()
	studio.terrain_option = OptionButton.new()
	studio.dynamic_terrain_option = OptionButton.new()
	studio.arena = _arena_fixture()
	studio.call("_refresh_permanent_terrain_options")
	for option in [studio.terrain_option, studio.dynamic_terrain_option]:
		assert_gt(option.item_count, PERMANENT_IDS.size())
		for index in range(option.item_count):
			if option.is_item_separator(index):
				continue
			var terrain_id := StringName(option.get_item_metadata(index))
			var paintable := ArenaPermanentTerrainPaintService.can_paint(
				studio.arena, terrain_id
			)
			assert_eq(not option.is_item_disabled(index), paintable, str(terrain_id))
		assert_false(_option_has_active_id(option, &"wall"))
		assert_false(_option_has_active_id(option, &"hole"))
		assert_false(_option_has_active_id(option, &"shadow"))
		assert_false(_option_has_active_id(option, &"rune"))
	studio.terrain_option.free()
	studio.dynamic_terrain_option.free()
	studio.free()


func test_17_undo_redo_restores_permanent_terrain() -> void:
	var session := ArenaEditSession.new()
	assert_true(session.open(_arena_fixture(), "", true, "permanent_brush_history"))
	var cell := Vector2i(1, 1)
	var before := session.working_arena.to_snapshot()
	assert_true(ArenaDynamicEditingService.paint_permanent_terrain(
		session.working_arena, cell, &"water"
	))
	var after := session.working_arena.to_snapshot()
	assert_true(session.commit("Peindre water", before, after))
	assert_true(session.history.undo())
	assert_eq(session.working_arena.get_cell_definition(cell).terrain_id, &"stone")
	assert_true(session.history.redo())
	assert_eq(session.working_arena.get_cell_definition(cell).terrain_id, &"water")


func test_17b_special_floor_auto_enables_hybrid_and_right_click_restores_base() -> void:
	var arena := _arena_fixture()
	arena.visual_mode = ArenaDefinition.VisualMode.PAINTED
	arena.modular_visual_profile.base_terrain_id = &"stone"
	var special := TerrainPlaceableCatalogService.entry_by_id(
		arena, &"floor:lava", true
	).get("definition") as TerrainPlaceableDefinition
	assert_not_null(special)
	assert_true(ArenaDynamicEditingService.apply_placeable(
		arena, special, Vector2i(1, 1), false
	))
	assert_eq(arena.visual_mode, ArenaDefinition.VisualMode.HYBRID)
	assert_eq(
		arena.modular_visual_profile.hybrid_floor_policy,
		ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS
	)
	assert_eq(arena.get_cell_definition(Vector2i(1, 1)).terrain_id, &"lava")
	assert_true(ArenaDynamicEditingService.apply_placeable(
		arena, special, Vector2i(1, 1), true
	))
	assert_eq(arena.get_cell_definition(Vector2i(1, 1)).terrain_id, &"stone")


func test_17c_ordinary_floor_on_painted_map_requires_explicit_all_defined_activation() -> void:
	var arena := _arena_fixture()
	arena.visual_mode = ArenaDefinition.VisualMode.PAINTED
	var ordinary := TerrainPlaceableCatalogService.entry_by_id(
		arena, &"floor:neutral", true
	).get("definition") as TerrainPlaceableDefinition
	assert_not_null(ordinary)
	assert_false(ArenaDynamicEditingService.apply_placeable(
		arena, ordinary, Vector2i(1, 1), false
	))
	assert_eq(arena.visual_mode, ArenaDefinition.VisualMode.PAINTED)
	assert_eq(arena.get_cell_definition(Vector2i(1, 1)).terrain_id, &"stone")


func test_18_canvas_entries_follow_the_working_copy_after_refresh() -> void:
	var arena := _arena_fixture()
	var canvas := ArenaStudioCanvas.new()
	canvas.set_arena(arena)
	var cell := Vector2i(1, 1)
	assert_true(ArenaDynamicEditingService.paint_permanent_terrain(
		arena, cell, &"neutral"
	))
	canvas.update_terrain_cells([cell])
	assert_eq(canvas._terrain_entries[cell].terrain_id, &"neutral")
	assert_string_contains(canvas._terrain_entries[cell].texture_path, "neutral.png")
	canvas.free()


func test_19_preview_assembly_matches_working_copy() -> void:
	var arena := _pattern_fixture()
	var preview := ArenaRuntimePreview.new()
	add_child_autofree(preview)
	preview.set_arena(arena, false)
	assert_true(preview.rebuild_now())
	var parity := preview.parity_with_runtime()
	assert_true(parity.ok, str(parity))
	assert_eq(
		(preview.preview_signature.terrains as Dictionary).size(),
		_declared_cells(arena).size()
	)


func test_20_direct_test_copy_preserves_cells_textures_and_fingerprint() -> void:
	var arena := _pattern_fixture()
	var prepared := ArenaDirectTestService.prepare(arena, null, &"no_characters")
	assert_true(prepared.ok, str(prepared))
	if not bool(prepared.get("ok", false)):
		return
	var request := prepared.request as Dictionary
	var temporary := ResourceLoader.load(
		request.arena_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	assert_not_null(temporary)
	assert_eq(request.working_fingerprint, request.temporary_fingerprint)
	assert_eq(_terrain_map(temporary), _terrain_map(arena))
	assert_eq(_texture_map(temporary), _texture_map(arena))
	assert_false(str(request.arena_path).begins_with("res://data/arenas/produced/"))
	assert_false(prepared.produced_bundle_loaded)
	assert_true(ArenaDirectTestService.cleanup_context(request))


func test_21_runtime_grid_and_renderer_match_working_copy() -> void:
	var arena := _pattern_fixture()
	var runtime := ArenaRuntimeProjectionService.build(arena)
	assert_not_null(runtime)
	for cell in _declared_cells(arena):
		assert_eq(
			runtime.grid.get_type(cell),
			arena.get_cell_definition(cell).cell_type,
			str(cell)
		)
	var rendered := _render(runtime.arena_projection)
	assert_eq(_rendered_terrain_map(rendered.report), _terrain_map(arena))


func test_22_save_reload_keeps_every_permanent_terrain() -> void:
	var arena := _pattern_fixture()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(ROUNDTRIP_PATH).get_base_dir()
	)
	assert_eq(ResourceSaver.save(arena, ROUNDTRIP_PATH), OK)
	var loaded := ResourceLoader.load(
		ROUNDTRIP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	assert_not_null(loaded)
	assert_eq(_terrain_map(loaded), _terrain_map(arena))
	assert_eq(_texture_map(loaded), _texture_map(arena))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ROUNDTRIP_PATH))


func test_23_existing_permanent_tiles_keep_the_same_visual_contract() -> void:
	for terrain_id in [&"stone", &"water", &"ice", &"lava"]:
		var definition := ArenaCatalogService.terrain(terrain_id)
		assert_not_null(definition)
		assert_true(ArenaTileProjectionService.texture_contract(
			definition.base_texture
		).valid, str(terrain_id))


func test_24_grid_polygons_stay_aligned_with_render_polygons() -> void:
	var arena := _pattern_fixture()
	var rendered := _render(arena)
	for cell in _declared_cells(arena):
		var key := "%d,%d" % [cell.x, cell.y]
		assert_eq(
			rendered.report.cells[key].polygon,
			GridTransformService.cell_polygon(
				cell, arena.grid_origin, arena.axis_x, arena.axis_y
			),
			key
		)


func test_25_selection_uses_the_same_cell_polygon_as_tiles() -> void:
	var arena := _arena_fixture()
	var cell := Vector2i(1, 1)
	var plan_polygon: PackedVector2Array = (
		ArenaTerrainRenderPlanService.entry_for(arena, cell).polygon
	)
	var selection_polygon := GridTransformService.cell_polygon(
		cell, arena.grid_origin, arena.axis_x, arena.axis_y
	)
	assert_eq(plan_polygon, selection_polygon)


func test_26_highlights_use_the_same_cell_polygon_as_tiles() -> void:
	var arena := _arena_fixture()
	for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		assert_eq(
			ArenaTerrainRenderPlanService.entry_for(arena, cell).polygon,
			GridTransformService.cell_polygon(
				cell, arena.grid_origin, arena.axis_x, arena.axis_y
			)
		)


func test_27_temporary_water_restores_the_exact_neutral_base() -> void:
	var arena := _arena_fixture()
	var cell := Vector2i(1, 1)
	ArenaDynamicEditingService.paint_permanent_terrain(arena, cell, &"neutral")
	var runtime := ArenaRuntimeProjectionService.build(arena)
	var water := load("res://data/terrain/eau.tres") as TerrainEffectData
	assert_true(runtime.apply_terrain_effect(cell, water).changed)
	for _tick in range(water.duration):
		runtime.terrain_effects.tick_all_effects()
	assert_eq(runtime.terrain_effects.get_surface_id(cell), &"none")
	assert_eq(runtime.arena_projection.get_cell_definition(cell).terrain_id, &"neutral")
	assert_string_contains(
		ArenaTerrainRenderPlanService.entry_for(
			runtime.arena_projection, cell
		).texture_path,
		"neutral.png"
	)


func _assert_brush_mutation(terrain_id: StringName, cell: Vector2i) -> void:
	var arena := _arena_fixture()
	assert_true(ArenaPermanentTerrainPaintService.can_paint(arena, terrain_id))
	assert_true(ArenaDynamicEditingService.paint_permanent_terrain(
		arena, cell, terrain_id
	))
	assert_eq(arena.get_cell_definition(cell).terrain_id, terrain_id)


func _arena_fixture(size := Vector2i(4, 4)) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Permanent tile fixture", "permanent_tile_fixture")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"forest"
	arena.grid_size = size
	arena.grid_origin = Vector2(320, 96)
	arena.axis_x = Vector2(64, 32)
	arena.axis_y = Vector2(-64, 32)
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = &"forest"
	arena.modular_visual_profile.hybrid_floor_policy = (
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	for y in range(size.y):
		for x in range(size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _pattern_fixture() -> ArenaDefinition:
	var arena := _arena_fixture(Vector2i(5, 2))
	var ids := [&"stone", &"neutral", &"water", &"ice", &"stone"]
	for x in range(ids.size()):
		ArenaDynamicEditingService.paint_terrain(arena, Vector2i(x, 0), ids[x])
		ArenaDynamicEditingService.paint_terrain(arena, Vector2i(x, 1), ids[ids.size() - 1 - x])
	return arena


func _render(arena: ArenaDefinition) -> Dictionary:
	var owner := Node2D.new()
	add_child_autofree(owner)
	var grid_view := GridViewFixture.new(arena)
	owner.add_child(grid_view)
	var floor := Node2D.new()
	owner.add_child(floor)
	var renderer := ArenaTerrainVisualRenderer.new()
	owner.add_child(renderer)
	renderer.configure(grid_view, floor)
	renderer.render_plan(ArenaTerrainRenderPlanService.build(arena))
	return {"owner": owner, "renderer": renderer, "report": renderer.actual_render_report()}


func _terrain_map(arena: ArenaDefinition) -> Dictionary:
	var result := {}
	for cell in _declared_cells(arena):
		result["%d,%d" % [cell.x, cell.y]] = str(
			arena.get_cell_definition(cell).terrain_id
		)
	return result


func _texture_map(arena: ArenaDefinition) -> Dictionary:
	var result := {}
	for cell in _declared_cells(arena):
		result["%d,%d" % [cell.x, cell.y]] = str(
			ArenaTerrainRenderPlanService.entry_for(arena, cell).texture_path
		)
	return result


func _rendered_terrain_map(report: Dictionary) -> Dictionary:
	var result := {}
	for key in (report.cells as Dictionary):
		result[key] = str(report.cells[key].terrain_id)
	return result


func _option_has_active_id(option: OptionButton, terrain_id: StringName) -> bool:
	for index in range(option.item_count):
		if option.is_item_separator(index):
			continue
		if StringName(option.get_item_metadata(index)) == terrain_id:
			return not option.is_item_disabled(index)
	return false


func _declared_cells(arena: ArenaDefinition) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for definition in arena.cells:
		if definition != null:
			result.append(definition.coordinate)
	result.sort_custom(func(a: Vector2i, b: Vector2i):
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return result
