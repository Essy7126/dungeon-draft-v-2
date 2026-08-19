extends GutTest

const FOREST_PATH := "res://data/arenas/room_01_forest.tres"


class StrictRuntimeFixture extends Node2D:
	var arena_assembly := {}
	var grid: GridData = null
	var pathfinder: Pathfinder = null
	var room_data: ArenaDefinition = null
	var camera: Camera2D = null
	var units: Array = []
	var _direct_test_options := {}
	var _deployment: Node = null
	var runtime_ready_state := true


func test_probe_reports_typed_runtime_contract() -> void:
	var arena := _hybrid_working_copy()
	assert_not_null(arena)
	var fixture := _runtime_fixture(arena, &"no_characters")
	var result := ArenaRuntimeSceneProbeService.inspect(
		fixture,
		_request_for(arena, &"no_characters"),
		{"produced_bundle_loaded": false, "topology_hashes_identical": true},
	)
	assert_true(result.ok, str(result))
	assert_true(result.scene_instantiated)
	assert_true(result.script_parse_ok)
	assert_true(result.runtime_ready)
	assert_true(result.runtime_contract_enforced)
	assert_true(result.grid_ready)
	assert_true(result.pathfinder_ready)
	assert_true(result.render_ready)
	assert_true(result.spawn_ready)
	assert_false(result.produced_bundle_loaded)
	assert_true(result.errors is Array)
	assert_true(result.warnings is Array)
	assert_gte(float(result.duration_ms), 0.0)
	assert_eq(
		ArenaDirectTestProbe.inspect_runtime_scene(
			fixture,
			_request_for(arena, &"no_characters"),
			{"produced_bundle_loaded": false, "topology_hashes_identical": true},
		).rendered_floor_hash,
		result.rendered_floor_hash,
	)


func test_probe_blocks_when_pathfinder_is_missing_after_runtime_ready() -> void:
	var arena := _hybrid_working_copy()
	var fixture := _runtime_fixture(arena, &"no_characters")
	fixture.pathfinder = null
	var result := ArenaRuntimeSceneProbeService.inspect(
		fixture,
		_request_for(arena, &"no_characters"),
		{"produced_bundle_loaded": false, "topology_hashes_identical": true},
	)
	assert_false(result.ok)
	assert_false(result.pathfinder_ready)
	assert_true(_has_code(result.errors, &"PATHFINDER_NOT_READY"), str(result))


func test_probe_verifies_requested_hero_and_enemy_spawns() -> void:
	var arena := _hybrid_working_copy()
	var fixture := _runtime_fixture(arena, &"spawns")
	var hero := Unit.new()
	hero.team = 0
	var enemy := Unit.new()
	enemy.team = 1
	fixture.units = [hero, enemy]
	var request := _request_for(arena, &"spawns")
	var provenance := {
		"produced_bundle_loaded": false,
		"topology_hashes_identical": true,
	}
	var ready := ArenaRuntimeSceneProbeService.inspect(
		fixture, request, provenance
	)
	assert_true(ready.ok, str(ready))
	assert_true(ready.spawn_ready)
	assert_eq(int(ready.spawn_report.hero_count), 1)
	assert_eq(int(ready.spawn_report.enemy_count), 1)

	fixture.units = [hero]
	var missing_enemy := ArenaRuntimeSceneProbeService.inspect(
		fixture, request, provenance
	)
	assert_false(missing_enemy.ok)
	assert_false(missing_enemy.spawn_ready)
	assert_true(_has_code(missing_enemy.errors, &"SPAWN_NOT_READY"))


func test_probe_rejects_any_produced_bundle_provenance() -> void:
	var arena := _hybrid_working_copy()
	var fixture := _runtime_fixture(arena, &"no_characters")
	var result := ArenaRuntimeSceneProbeService.inspect(
		fixture,
		_request_for(arena, &"no_characters"),
		{"produced_bundle_loaded": true, "topology_hashes_identical": true},
	)
	assert_false(result.ok)
	assert_true(result.produced_bundle_loaded)
	assert_true(_has_code(result.errors, &"PRODUCED_BUNDLE_LOADED"))


func test_probe_null_scene_returns_structured_failure() -> void:
	var result := ArenaRuntimeSceneProbeService.inspect(null)
	assert_false(result.ok)
	assert_false(result.scene_instantiated)
	assert_false(result.runtime_scene_inspected)
	assert_true(_has_code(result.errors, &"SCENE_NOT_INSTANTIATED"))


func _runtime_fixture(
		arena: ArenaDefinition,
		configuration: StringName
	) -> StrictRuntimeFixture:
	var fixture := StrictRuntimeFixture.new()
	add_child_autofree(fixture)
	fixture.room_data = arena
	fixture.grid = ArenaRuntimeBridge.build_grid(arena)
	fixture.pathfinder = Pathfinder.new(fixture.grid)
	fixture._direct_test_options = ArenaDirectTestConfiguration.resolve(configuration)

	var grid_view := PaintedGridView.new()
	grid_view.configure(
		arena.painted_map_visual_data,
		arena.grid_layout,
		arena.hero_spawn_zone,
		arena.enemy_spawn_zone,
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
		arena,
		fixture.grid,
		fixture.pathfinder,
		grid_view,
		world,
		fixture,
		true,
		floor,
	)
	fixture.camera = Camera2D.new()
	fixture.add_child(fixture.camera)
	return fixture


func _request_for(
		arena: ArenaDefinition,
		configuration: StringName
	) -> Dictionary:
	var fingerprint := ArenaSnapshotService.arena_fingerprint(arena)
	var topology := ArenaTopologySignatureService.build(arena)
	var plan := ArenaTerrainRenderPlanService.build(arena)
	return {
		"contract_version": ArenaDirectTestService.CONTRACT_VERSION,
		"configuration": str(configuration),
		"expected_battle_scene_path": arena.battle_scene.resource_path,
		"runtime_probe_key": ArenaDirectTestService.probe_key(
			fingerprint,
			str(topology.topology_hash),
			arena.battle_scene.resource_path,
			configuration,
		),
		"working_fingerprint": fingerprint,
		"temporary_fingerprint": fingerprint,
		"working_topology_hash": str(topology.topology_hash),
		"expected_floor_cells": plan.expected_floor_cells,
		"removed_cells": topology.removed_cells,
		"arena_path": arena.resource_path,
	}


func _hybrid_working_copy() -> ArenaDefinition:
	var source := load(FOREST_PATH) as ArenaDefinition
	if source == null:
		return null
	var session := ArenaEditSession.new()
	if not session.open(source, FOREST_PATH, false, "runtime_scene_probe"):
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
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _has_code(diagnostics: Array, code: StringName) -> bool:
	for value in diagnostics:
		if value is Dictionary and StringName(value.get("code", &"")) == code:
			return true
	return false
