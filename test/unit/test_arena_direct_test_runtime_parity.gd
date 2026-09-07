extends GutTest

const FOREST_PATH := "res://data/arenas/room_01_forest.tres"


func test_direct_test_profiles_are_real_and_distinct() -> void:
	var empty := ArenaDirectTestConfiguration.resolve(&"no_characters")
	assert_true(empty.allow_empty_heroes)
	assert_false(empty.spawn_heroes)
	assert_false(empty.spawn_enemies)
	assert_false(empty.deployment_enabled)
	assert_false(empty.combat_enabled)
	assert_false(empty.hud_enabled)

	var trio := ArenaDirectTestConfiguration.resolve(&"hero_trio")
	assert_true(trio.spawn_heroes)
	assert_false(trio.spawn_enemies)
	assert_false(trio.deployment_enabled)
	assert_false(trio.combat_enabled)
	assert_eq(trio.applied_mode, "hero_preview")

	var encounter := ArenaDirectTestConfiguration.resolve(&"real_encounter")
	assert_true(encounter.spawn_heroes)
	assert_true(encounter.spawn_enemies)
	assert_true(encounter.deployment_enabled)
	assert_true(encounter.combat_enabled)
	assert_true(encounter.hud_enabled)
	assert_eq(encounter.applied_mode, "full_combat")

	var terrains := ArenaDirectTestConfiguration.resolve(&"terrains")
	assert_eq(terrains.applied_mode, "terrain_overlay")
	assert_true(terrains.draw_logic_types)
	assert_true(terrains.draw_void_cells)
	assert_false(terrains.spawn_heroes)
	assert_false(terrains.spawn_enemies)

	var full_run := ArenaDirectTestConfiguration.resolve(&"full_run")
	assert_eq(full_run, ArenaDirectTestConfiguration.resolve(&"full_run"))
	assert_eq(full_run.applied_mode, "full_combat")


func test_arena_definition_uses_only_studio_2_floor_renderer() -> void:
	var arena := _hybrid_working_copy()
	assert_not_null(arena)
	var battle_script := load("res://battle/battle.gd") as GDScript
	var battle = battle_script.new()
	battle.room_data = arena
	battle._setup_arena_visuals()
	assert_null(battle.get("_arena_feature_renderer"))
	assert_null(battle.get_node_or_null("ArenaTilesLayer"))
	battle.free()


func test_assembler_renders_one_floor_node_per_plan_cell_under_dedicated_parent() -> void:
	var arena := _hybrid_working_copy()
	assert_not_null(arena)
	var grid := ArenaRuntimeBridge.build_grid(arena)
	assert_not_null(grid)
	var root := Node2D.new()
	add_child_autofree(root)
	var grid_view := PaintedGridView.new()
	grid_view.configure(
		arena.painted_map_visual_data,
		arena.grid_layout,
		arena.hero_spawn_zone,
		arena.enemy_spawn_zone
	)
	grid_view.setup(grid)
	root.add_child(grid_view)
	var floor_parent := Node2D.new()
	floor_parent.name = "ArenaTilesLayer"
	floor_parent.y_sort_enabled = false
	root.add_child(floor_parent)
	var world := Node2D.new()
	world.name = "YSortedWorld"
	world.y_sort_enabled = true
	root.add_child(world)
	var assembly := ArenaVisualAssembler.assemble(
		arena, grid, Pathfinder.new(grid), grid_view, world, root, true, floor_parent
	)
	var plan := ArenaTerrainRenderPlanService.build(arena)
	var renderer := assembly.get("renderer") as ArenaTerrainVisualRenderer
	assert_not_null(renderer)
	var actual := renderer.actual_render_report()
	assert_eq(
		int(actual.rendered_terrain_node_count),
		int(plan.expected_terrain_cell_count)
	)
	assert_eq(floor_parent.get_child_count(), int(plan.expected_terrain_cell_count))
	assert_false(floor_parent.y_sort_enabled)
	for child in floor_parent.get_children():
		assert_true(child.has_meta("arena_cell"))
		assert_true(child.has_meta("grid_cell"))
		assert_eq(child.get_parent(), floor_parent)
	var misplaced_floor_nodes := 0
	for child in world.get_children():
		if child.name.begins_with("ArenaTerrain_"):
			misplaced_floor_nodes += 1
	assert_eq(misplaced_floor_nodes, 0)


func test_preview_and_runtime_share_painted_camera_framing() -> void:
	var arena := _hybrid_working_copy()
	assert_not_null(arena)
	var preview := ArenaRuntimePreview.new()
	preview.size = Vector2(960, 540)
	add_child_autofree(preview)
	await wait_process_frames(2)
	preview.set_arena(arena)
	assert_true(preview.rebuild_now())
	var expected := ArenaCameraFramingService.painted_framing(
		arena.painted_map_visual_data,
		Vector2(preview.viewport.size),
		arena.painted_map_visual_data.presentation_profile
	)
	assert_true(expected.ok)
	assert_eq(preview.camera.position, expected.position)
	assert_eq(preview.camera.zoom, expected.zoom)
	var floor_parent := preview.world_root.get_node_or_null("ArenaTilesLayer") as Node2D
	assert_not_null(floor_parent)
	assert_false(floor_parent.y_sort_enabled)
	var renderer := preview.assembly.get("renderer") as ArenaTerrainVisualRenderer
	assert_not_null(renderer)
	for cell in (renderer.actual_render_report().cells as Dictionary).values():
		assert_true(bool((cell as Dictionary).visible))


func test_keep_painting_in_view_clamps_wide_offset_without_zooming() -> void:
	var visual := PaintedMapVisualData.new()
	visual.source_image_size = Vector2i(1920, 1200)
	var profile := BattlePresentationProfile.new()
	profile.camera_offset_adjustment = Vector2(160, 0)
	profile.camera_keep_painting_in_view = true
	profile.global_unit_scale_multiplier = 1.08
	var viewport := Vector2(1920, 1080)
	var result := ArenaCameraFramingService.painted_framing(visual, viewport, profile)
	assert_true(result.ok)
	assert_eq(result.position, Vector2(960, 600))
	assert_eq(result.zoom, Vector2.ONE)
	var visible_size: Vector2 = viewport / result.zoom
	var visible_rect := Rect2(result.position - visible_size * 0.5, visible_size)
	assert_true(Rect2(0, 0, 1920, 1200).encloses(visible_rect), "No side of the viewport exposes unpainted space")
	assert_eq(profile.camera_offset_adjustment, Vector2(160, 0), "Requested offset stays authored")
	assert_almost_eq(profile.global_unit_scale_multiplier, 1.08, 0.000001)


func test_keep_painting_in_view_uses_compact_slack_and_clamps_both_axes() -> void:
	var visual := PaintedMapVisualData.new()
	visual.source_image_size = Vector2i(1920, 1200)
	var profile := BattlePresentationProfile.new()
	profile.camera_offset_adjustment = Vector2(160, 90)
	profile.camera_keep_painting_in_view = true
	var viewport := Vector2(1200, 896)
	var result := ArenaCameraFramingService.painted_framing(visual, viewport, profile)
	assert_true(result.ok)
	assert_almost_eq(result.position.x - 960.0, 156.428571, 0.001)
	assert_almost_eq(result.position.y, 600.0, 0.001)
	assert_almost_eq(result.zoom.x, 896.0 / 1200.0, 0.000001)
	assert_eq(result.zoom.x, result.zoom.y)
	var visible_size: Vector2 = viewport / result.zoom
	var visible_rect := Rect2(result.position - visible_size * 0.5, visible_size)
	assert_true(visible_rect.position.x >= -0.001 and visible_rect.position.y >= -0.001)
	assert_true(visible_rect.end.x <= 1920.001 and visible_rect.end.y <= 1200.001, "Compact viewport stays within painting")


func test_painted_camera_offset_remains_unbounded_by_default() -> void:
	var visual := PaintedMapVisualData.new()
	visual.source_image_size = Vector2i(1920, 1200)
	visual.image_offset = Vector2(35, 70)
	visual.camera_offset = Vector2(25, -30)
	var profile := BattlePresentationProfile.new()
	assert_false(profile.camera_keep_painting_in_view)
	profile.camera_offset_adjustment = Vector2(160, 90)
	var result := ArenaCameraFramingService.painted_framing(visual, Vector2(1920, 1080), profile)
	assert_eq(result.position, Vector2(1180, 730), "Legacy offsets remain additive when disabled")
	assert_eq(result.zoom, Vector2.ONE)
	var without_profile := ArenaCameraFramingService.painted_framing(visual, Vector2(1920, 1080))
	assert_eq(without_profile.position, Vector2(1020, 640), "No-profile framing keeps the image origin and visual offset")


func test_game_manager_allows_empty_roster_only_for_direct_visual_test() -> void:
	var arena := _hybrid_working_copy()
	assert_not_null(arena)
	var run := RunData.new()
	run.rooms = [arena]
	run.default_seed = 1337
	assert_false(GameManager._prepare_preconfigured_run(run, []))
	assert_push_error("Aucun heros fourni pour le run preconfigure")
	assert_true(GameManager._prepare_preconfigured_run(run, [], true))
	assert_eq(GameManager.get_living_heroes().size(), 0)
	GameManager.cleanup_run_state()


func test_transient_studio_run_always_pins_its_seed() -> void:
	var source := RunData.new()
	source.default_seed = 424242
	source.randomize_seed_each_run = true
	var transient := ArenaDirectTestService._transient_run(
		source, _hybrid_working_copy()
	)
	assert_eq(transient.default_seed, 424242)
	assert_false(transient.randomize_seed_each_run)
	assert_true(source.randomize_seed_each_run, "le run de production reste inchangé")


func _hybrid_working_copy() -> ArenaDefinition:
	var source := load(FOREST_PATH) as ArenaDefinition
	if source == null:
		return null
	var session := ArenaEditSession.new()
	if not session.open(source, FOREST_PATH, false, "direct_test_parity"):
		return null
	var arena := session.working_arena
	ArenaEditingService.prepare_automatically(arena)
	arena.visual_mode = ArenaDefinition.VisualMode.HYBRID
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = arena.theme_id
	arena.modular_visual_profile.base_terrain_id = &"stone"
	arena.modular_visual_profile.hybrid_floor_policy = (
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	# La working copy metier ne porte plus les champs derives : le contrat
	# runtime se lit desormais sur sa projection.
	return ArenaRuntimeBridge.build_runtime_projection(arena)
