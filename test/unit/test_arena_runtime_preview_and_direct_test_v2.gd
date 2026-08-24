extends GutTest

const FOREST_PATH := "res://data/arenas/room_01_forest.tres"
const MAIN_RUN_PATH := "res://data/runs/first_run.tres"

class RuntimeSceneFixture extends Node2D:
	var arena_assembly := {}
	var grid: GridData = null
	var room_data: ArenaDefinition = null
	var camera: Camera2D = null
	var _direct_test_options := {}


func test_game_preview_is_run_aware_when_exact_context_is_available() -> void:
	var arena := _hybrid_working_copy()
	var run := load(MAIN_RUN_PATH) as RunData
	assert_not_null(arena)
	assert_not_null(run)
	assert_not_null(run.content_profile)
	assert_not_null(arena.encounter_definition)
	var preview := ArenaRuntimePreview.new()
	preview.size = Vector2(960, 540)
	add_child_autofree(preview)
	await wait_process_frames(2)
	preview.set_arena(arena)
	preview.set_runtime_context(run)
	preview.set_view_mode(ArenaRuntimePreview.ViewMode.GAME)
	assert_true(preview.rebuild_now())
	var fidelity := preview.fidelity_report()
	assert_eq(fidelity.fidelity, "EXACT")
	assert_eq(fidelity.hero_source, "RunHeroResolver")
	assert_eq(fidelity.hero_count, 3)
	assert_eq(
		fidelity.enemy_count,
		arena.encounter_definition.get_initial_enemy_count()
	)
	assert_true(fidelity.errors.is_empty())
	assert_string_contains(preview.fidelity_badge.text, "EXACT")


func test_game_preview_labels_fixture_fallback_instead_of_silent_enemy() -> void:
	var arena := _hybrid_working_copy()
	var preview := ArenaRuntimePreview.new()
	preview.size = Vector2(960, 540)
	add_child_autofree(preview)
	await wait_process_frames(2)
	preview.set_arena(arena)
	preview.set_runtime_context(null)
	preview.set_view_mode(ArenaRuntimePreview.ViewMode.GAME)
	assert_true(preview.rebuild_now())
	var fidelity := preview.fidelity_report()
	assert_eq(fidelity.fidelity, "QUICK")
	assert_eq(fidelity.hero_source, "explicit_fixture")
	assert_string_contains(fidelity.label, "FIXTURES EXPLICITES")
	assert_true(fidelity.errors.has("Aucune partie active."))


func test_direct_test_preparation_proves_working_temp_runtime_identity() -> void:
	var arena := _hybrid_working_copy()
	var run := load(MAIN_RUN_PATH) as RunData
	var source_fingerprint := ArenaSnapshotService.room_fingerprint(arena)
	var prepared := ArenaDirectTestService.prepare(arena, run, &"real_encounter")
	assert_true(prepared.ok, str(prepared))
	if not prepared.get("ok", false):
		return
	var request := prepared.request as Dictionary
	assert_eq(request.contract_version, 4)
	assert_true(request.arena_path.begins_with(ArenaDirectTestService.WORK_ROOT + "/"))
	assert_false(request.arena_path.begins_with("res://data/arenas/produced/"))
	assert_true(FileAccess.file_exists(request.arena_path))
	assert_true(FileAccess.file_exists(request.run_path))
	assert_true(request.exact_run_content)
	assert_false(request.fixture_fallback)
	assert_eq(request.camera_mode, "STUDIO_MATCH")
	assert_eq(request.expected_battle_scene_path, arena.battle_scene.resource_path)
	assert_false(str(request.runtime_probe_key).is_empty())
	assert_eq(request.working_fingerprint, request.temporary_fingerprint)
	assert_eq(request.working_fingerprint, request.runtime_fingerprint)
	assert_eq(request.working_topology_hash, request.temporary_topology_hash)
	assert_eq(request.working_topology_hash, request.runtime_topology_hash)
	assert_true(request.topology_hashes_identical)
	assert_false(str(request.generation_id).is_empty())
	var temporary := ResourceLoader.load(
		request.arena_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ArenaDefinition
	assert_not_null(temporary)
	assert_eq(
		ArenaSnapshotService.arena_fingerprint(temporary),
		request.working_fingerprint
	)
	assert_eq(ArenaSnapshotService.room_fingerprint(arena), source_fingerprint)
	assert_false(prepared.produced_bundle_loaded)
	assert_true(ArenaDirectTestService.cleanup_context(request))
	assert_false(FileAccess.file_exists(request.arena_path))
	assert_false(FileAccess.file_exists(ArenaDirectTestService.REQUEST_PATH))


func test_runtime_probe_reports_exact_scene_tree_contract() -> void:
	var arena := _hybrid_working_copy()
	assert_not_null(arena)
	var fixture := RuntimeSceneFixture.new()
	add_child_autofree(fixture)
	fixture.room_data = arena
	fixture.grid = ArenaRuntimeBridge.build_grid(arena)
	var grid_view := PaintedGridView.new()
	grid_view.configure(
		arena.painted_map_visual_data,
		arena.grid_layout,
		arena.hero_spawn_zone,
		arena.enemy_spawn_zone
	)
	grid_view.setup(fixture.grid)
	fixture.add_child(grid_view)
	var floor := Node2D.new()
	floor.name = "ArenaTilesLayer"
	floor.y_sort_enabled = false
	fixture.add_child(floor)
	var world := Node2D.new()
	world.name = "YSortedWorld"
	world.y_sort_enabled = true
	fixture.add_child(world)
	fixture.arena_assembly = ArenaVisualAssembler.assemble(
		arena, fixture.grid, Pathfinder.new(fixture.grid), grid_view,
		world, fixture, true, floor
	)
	fixture.camera = Camera2D.new()
	fixture.add_child(fixture.camera)
	fixture._direct_test_options = ArenaDirectTestConfiguration.resolve(
		&"real_encounter"
	)
	var fingerprint := ArenaSnapshotService.arena_fingerprint(arena)
	var request := {
		"contract_version": 3,
		"configuration": "real_encounter",
		"working_fingerprint": fingerprint,
		"temporary_fingerprint": fingerprint,
		"working_topology_hash": ArenaTopologySignatureService.build(arena).topology_hash,
		"expected_floor_cells": ArenaTerrainRenderPlanService.build(arena).expected_floor_cells,
		"removed_cells": ArenaTopologySignatureService.build(arena).removed_cells,
	}
	var result := ArenaDirectTestProbe.inspect_runtime_scene(
		fixture,
		request,
		{
			"produced_bundle_loaded": false,
			"topology_hashes_identical": true,
		}
	)
	assert_true(result.ok, str(result))
	assert_true(result.runtime_scene_inspected)
	assert_eq(result.floor_layer_count, 1)
	assert_eq(result.floor_renderer_count, 1)
	assert_true(result.floor_y_sort_valid)
	assert_eq(result.duplicate_tile_count, 0)
	assert_eq(result.misplaced_floor_node_count, 0)
	assert_true(result.configuration_consumed)
	assert_eq(result.camera_mode, "STUDIO_MATCH")
	assert_true(result.fingerprints_identical)
	assert_true(result.topology_hashes_identical)
	assert_true(result.unexpected_cells.is_empty())
	assert_true(result.missing_cells.is_empty())
	assert_true(result.removed_cells_rendered.is_empty())
	assert_false(result.produced_bundle_loaded)


func _hybrid_working_copy() -> ArenaDefinition:
	var source := load(FOREST_PATH) as ArenaDefinition
	if source == null:
		return null
	var session := ArenaEditSession.new()
	if not session.open(source, FOREST_PATH, false, "phase_9_runtime_parity"):
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
