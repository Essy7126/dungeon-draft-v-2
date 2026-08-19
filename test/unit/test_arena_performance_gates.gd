extends GutTest

const LAZY_PRODUCTION_STAGING := (
	"user://dungeon_draft_studio/tests/performance/lazy_scene_build"
)
const REQUIRED_PHASES: Array[String] = [
	"open",
	"single_cell",
	"quick_preview",
	"validation",
]
const ALL_PHASES: Array[String] = [
	"open",
	"single_cell",
	"hundred_cells",
	"quick_preview",
	"validation",
	"art_geometry",
	"export_reference",
	"pan_zoom_1000_events",
	"cycle_average",
]


func after_each() -> void:
	ArenaTerrainRenderPlanService.clear_cache()
	ArenaValidator.clear_cache()
	ArenaTacticalMetricsService.clear_cache()
	ArenaVisualAssembler.clear_inspection_cache()
	if DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(LAZY_PRODUCTION_STAGING)
	):
		ArenaProductionTransactionService._remove_tree(LAZY_PRODUCTION_STAGING)


func test_14x14_keeps_every_existing_budget_without_relaxation() -> void:
	var thresholds := ArenaStudioPerformanceService.THRESHOLDS_MS
	assert_eq(float(thresholds.open_14x14), 500.0)
	assert_eq(float(thresholds.single_cell), 16.0)
	assert_eq(float(thresholds.quick_preview), 250.0)
	assert_eq(float(thresholds.validation), 500.0)
	var report := ArenaStudioPerformanceService.derive_fixture_gate(
		Vector2i(14, 14), _valid_measurements()
	)
	assert_true(report.ok, str(report))
	assert_true(report.measurement_valid)
	assert_eq(report.measurement_status, "MEASUREMENT_VALID")
	assert_true(report.slo_pass)
	assert_eq(report.slo_status, "SLO_PASS")
	assert_false(report.measurement_only)
	assert_eq(report.gate_mode, "required_slo")
	assert_eq(report.verdict, "PASS")
	assert_eq(report.required_slo_count, 4)
	assert_eq((report.thresholds_pass as Dictionary).size(), 4)
	for phase in REQUIRED_PHASES:
		assert_true(report.thresholds_pass[phase], str(report.thresholds_pass))
		assert_true(report.breakdown[phase].required_slo)
		assert_eq(report.breakdown[phase].comparison, "<")


func test_equal_to_a_required_budget_is_a_deterministic_slo_failure() -> void:
	var boundary_cases := {
		"open_ms": 500.0,
		"single_cell_ms": 16.0,
		"quick_preview_ms": 250.0,
		"validation_ms": 500.0,
	}
	for metric_key in boundary_cases:
		var measurements := _valid_measurements()
		measurements[metric_key] = boundary_cases[metric_key]
		var report := ArenaStudioPerformanceService.derive_fixture_gate(
			Vector2i(14, 14), measurements
		)
		assert_true(report.measurement_valid, metric_key)
		assert_false(report.slo_pass, metric_key)
		assert_false(report.ok, metric_key)
		assert_eq(report.verdict, "FAIL", metric_key)


func test_measurement_validity_and_slo_pass_are_independent_inputs_to_ok() -> void:
	var measurements := _valid_measurements()
	measurements.art_geometry_ms = NAN
	var report := ArenaStudioPerformanceService.derive_fixture_gate(
		Vector2i(14, 14), measurements
	)
	assert_false(report.measurement_valid)
	assert_true(report.slo_pass, "Les quatre mesures SLO restent sous budget.")
	assert_false(report.ok)
	assert_eq(report.verdict, "FAIL")
	assert_eq(report.breakdown.art_geometry.status, "INVALID")
	assert_true(report.measurement_errors.has("invalid_measurement:art_geometry_ms"))


func test_32x32_and_64x64_are_measurement_only_without_artificial_true_slos() -> void:
	for size in [Vector2i(32, 32), Vector2i(64, 64)]:
		var report := ArenaStudioPerformanceService.derive_fixture_gate(
			size, _valid_measurements()
		)
		assert_true(report.ok, str(size))
		assert_true(report.measurement_valid, str(size))
		assert_true(report.measurement_only, str(size))
		assert_null(report.slo_pass, str(size))
		assert_eq(report.slo_status, "NOT_APPLICABLE")
		assert_eq(report.gate_mode, "measurement_only")
		assert_eq(report.verdict, "MEASUREMENT_ONLY")
		assert_eq(report.required_slo_count, 0)
		assert_true((report.budgets_ms as Dictionary).is_empty())
		assert_true((report.thresholds_pass as Dictionary).is_empty())
		for phase in ALL_PHASES:
			var phase_report := report.breakdown[phase] as Dictionary
			assert_true(phase_report.measurement_valid, "%s:%s" % [size, phase])
			assert_false(phase_report.required_slo, "%s:%s" % [size, phase])
			assert_null(phase_report.budget_ms, "%s:%s" % [size, phase])
			assert_null(phase_report.slo_pass, "%s:%s" % [size, phase])
			assert_eq(phase_report.status, "MEASUREMENT_ONLY")


func test_render_plan_checks_each_distinct_texture_once_and_invalidates_on_paint() -> void:
	var arena := _arena_fixture(Vector2i(4, 4))
	ArenaTerrainRenderPlanService.clear_cache()
	var first := ArenaTerrainRenderPlanService.build(arena)
	assert_true(first.ok, str(first.errors))
	assert_false(first.cache_hit)
	assert_eq(first.visual_contract_checks, 1)
	assert_eq(first.visual_contract_reuses, 15)
	var cached := ArenaTerrainRenderPlanService.build(arena)
	assert_true(cached.cache_hit)
	assert_eq(cached.expected_floor_hash, first.expected_floor_hash)

	ArenaTerrainRegistry.configure_cell(
		arena.get_cell_definition(Vector2i(1, 1)), &"water"
	)
	var repainted := ArenaTerrainRenderPlanService.build(arena)
	assert_false(repainted.cache_hit)
	assert_eq(_terrain_in_plan(repainted, Vector2i(1, 1)), &"water")
	assert_lte(int(repainted.visual_contract_checks), 2)
	assert_eq(
		int(repainted.visual_contract_checks) + int(repainted.visual_contract_reuses),
		16
	)


func test_automatic_preparation_publishes_one_runtime_projection() -> void:
	var arena := _arena_fixture(Vector2i(8, 8))
	ArenaRuntimeBridge.begin_instrumentation()
	var result := ArenaEditingService.prepare_automatically(arena)
	var counters := ArenaRuntimeBridge.end_instrumentation()
	assert_true(result.ok, str(result))
	assert_eq(int(counters.sync_runtime_resources), 1, str(counters))
	assert_eq(int(counters.grid_data_builds), 1, str(counters))
	assert_not_null(arena.grid_layout)
	assert_eq(arena.grid_layout.logical_size, arena.grid_size)
	assert_gt(int(result.connected), 0)
	var breakdown := result.breakdown_ms as Dictionary
	for phase in [
		"ensure_cells", "safety_border", "encounter_resolution",
		"spawn_proposal", "runtime_sync", "grid_build", "connectivity", "total",
	]:
		assert_true(breakdown.has(phase), phase)
		assert_gte(float(breakdown[phase]), 0.0, phase)


func test_lazy_battle_scene_resolution_preserves_first_sync_output() -> void:
	var painted := ArenaDefinition.new()
	assert_null(painted.battle_scene)
	assert_true(ArenaRuntimeBridge.sync_runtime_resources(painted))
	assert_not_null(painted.battle_scene)
	assert_eq(
		painted.battle_scene.resource_path,
		ArenaDefinition.DEFAULT_BATTLE_SCENE
	)

	var modular := _arena_fixture(Vector2i(4, 4))
	var eager_reference := _arena_fixture(Vector2i(4, 4))
	eager_reference.battle_scene = load(
		ArenaDefinition.DEFAULT_BATTLE_SCENE
	) as PackedScene
	assert_null(modular.battle_scene)
	assert_true(ArenaRuntimeBridge.sync_runtime_resources(modular))
	assert_true(ArenaRuntimeBridge.sync_runtime_resources(eager_reference))
	assert_eq(
		modular.battle_scene.resource_path,
		ArenaDefinition.MODULAR_BATTLE_SCENE
	)
	assert_eq(modular.to_snapshot(), eager_reference.to_snapshot())


func test_lazy_battle_scene_snapshot_validation_and_projection_are_equivalent() -> void:
	var source := _arena_fixture(Vector2i(5, 5))
	assert_null(source.battle_scene)
	var state := ArenaRuntimeProjectionService.build(source)
	assert_not_null(state)
	if state != null:
		assert_not_null(state.arena_projection.battle_scene)
		if state.arena_projection.battle_scene != null:
			assert_eq(
				state.arena_projection.battle_scene.resource_path,
				ArenaDefinition.MODULAR_BATTLE_SCENE
			)
	assert_null(
		source.battle_scene,
		"Une projection ne doit pas muter la source canonique."
	)

	var report := ArenaValidator.validate(source, false)
	assert_false(report.messages.any(func(value):
		return value.code == &"runtime_scene_missing"
	))
	assert_eq(
		str(report.metrics.get("battle_scene", "")),
		ArenaDefinition.MODULAR_BATTLE_SCENE
	)

	var synchronized := _arena_fixture(Vector2i(5, 5))
	assert_true(ArenaRuntimeBridge.sync_runtime_resources(synchronized))
	var snapshot := synchronized.to_snapshot()
	var restored := ArenaDefinition.new()
	assert_true(restored.restore_snapshot(snapshot))
	assert_true(ArenaRuntimeBridge.sync_runtime_resources(restored))
	assert_eq(restored.to_snapshot(), snapshot)


func test_lazy_constructor_remains_compatible_with_production_bundle_build() -> void:
	var source := _arena_fixture(Vector2i(5, 4))
	assert_null(source.battle_scene)
	var preparation := ArenaEditingService.prepare_automatically(source)
	assert_true(preparation.ok, str(preparation))
	assert_not_null(source.battle_scene)
	if source.battle_scene != null:
		assert_eq(
			source.battle_scene.resource_path,
			ArenaDefinition.MODULAR_BATTLE_SCENE
		)
	var built := ArenaProductionService.build_staged_bundle(
		source,
		LAZY_PRODUCTION_STAGING,
		LAZY_PRODUCTION_STAGING
	)
	assert_true(built.ok, str(built))
	if built.get("ok", false):
		var manifest := built.get("manifest", {}) as Dictionary
		assert_eq(
			str(manifest.get("battle_scene", "")),
			ArenaDefinition.MODULAR_BATTLE_SCENE
		)


func test_injected_visual_derivations_match_cold_inspection_and_never_go_stale() -> void:
	var arena := _arena_fixture(Vector2i(4, 4))
	ArenaEditingService.prepare_automatically(arena)
	ArenaVisualAssembler.clear_inspection_cache()
	var cold := ArenaVisualAssembler.inspect(arena)
	var cold_snapshot := cold.to_dict()

	ArenaVisualAssembler.clear_inspection_cache()
	var state := ArenaRuntimeBridge.build_validation_state(arena)
	var plan := ArenaTerrainRenderPlanService.build(arena)
	var injected := ArenaVisualAssembler.inspect(arena, state, plan)
	assert_eq(injected.to_dict(), cold_snapshot)
	assert_eq(ArenaVisualAssembler.inspection_cache_size(), 0)

	ArenaTerrainRegistry.configure_cell(
		arena.get_cell_definition(Vector2i(1, 1)), &"water"
	)
	state = ArenaRuntimeBridge.build_validation_state(arena)
	plan = ArenaTerrainRenderPlanService.build(arena)
	var repainted := ArenaVisualAssembler.inspect(arena, state, plan)
	assert_ne(repainted.to_dict(), cold_snapshot)
	assert_eq(int(repainted.expected_by_terrain_id.get("water", 0)), 1)
	assert_eq(ArenaVisualAssembler.inspection_cache_size(), 0)


func test_injected_tactical_state_matches_cold_analysis_and_never_goes_stale() -> void:
	var arena := _arena_fixture(Vector2i(5, 5))
	ArenaEditingService.prepare_automatically(arena)
	ArenaTacticalMetricsService.clear_cache()
	var cold := ArenaTacticalMetricsService.analyze(arena)

	ArenaTacticalMetricsService.clear_cache()
	var state := ArenaRuntimeBridge.build_validation_state(arena)
	var injected := ArenaTacticalMetricsService.analyze(arena, state)
	assert_eq(injected, cold)
	assert_eq(ArenaTacticalMetricsService.cache_size(), 0)

	var before_accessible := int(injected.topology.accessible_cells)
	arena.get_cell_definition(Vector2i(2, 2)).playable = false
	state = ArenaRuntimeBridge.build_validation_state(arena)
	var changed := ArenaTacticalMetricsService.analyze(arena, state)
	assert_eq(int(changed.topology.accessible_cells), before_accessible - 1)
	assert_eq(ArenaTacticalMetricsService.cache_size(), 0)


func test_matrix_pass_requires_all_measurements_and_the_required_14x14_slos() -> void:
	var fixture_14 := _fixture_report(Vector2i(14, 14), "14x14")
	var fixture_32 := _fixture_report(Vector2i(32, 32), "32x32")
	var fixture_64 := _fixture_report(Vector2i(64, 64), "64x64")
	var passing := ArenaStudioPerformanceService.derive_matrix_gate([
		fixture_14, fixture_32, fixture_64,
	])
	assert_true(passing.measurement_valid)
	assert_eq(passing.measurement_status, "MEASUREMENT_VALID")
	assert_true(passing.slo_pass)
	assert_eq(passing.slo_status, "SLO_PASS")
	assert_true(passing.ok)
	assert_eq(passing.verdict, "PASS")
	assert_eq(passing.required_slo_fixtures, 1)
	assert_eq(passing.measurement_only_fixtures, 2)
	var no_required_gate := ArenaStudioPerformanceService.derive_matrix_gate([
		fixture_32, fixture_64,
	])
	assert_true(no_required_gate.measurement_valid)
	assert_false(no_required_gate.slo_pass)
	assert_false(no_required_gate.ok)
	assert_eq(no_required_gate.verdict, "FAIL")

	var failed_measurements := _valid_measurements()
	failed_measurements.quick_preview_ms = 250.0
	fixture_14 = ArenaStudioPerformanceService.derive_fixture_gate(
		Vector2i(14, 14), failed_measurements
	)
	fixture_14.fixture = "14x14"
	var failed_slo := ArenaStudioPerformanceService.derive_matrix_gate([
		fixture_14, fixture_32, fixture_64,
	])
	assert_true(failed_slo.measurement_valid)
	assert_false(failed_slo.slo_pass)
	assert_false(failed_slo.ok)
	assert_eq(failed_slo.verdict, "FAIL")
	assert_eq(failed_slo.failed_slo_fixtures, ["14x14"])

	var invalid_measurements := _valid_measurements()
	invalid_measurements.erase("cycle_average_ms")
	fixture_64 = ArenaStudioPerformanceService.derive_fixture_gate(
		Vector2i(64, 64), invalid_measurements
	)
	fixture_64.fixture = "64x64"
	var invalid_matrix := ArenaStudioPerformanceService.derive_matrix_gate([
		_fixture_report(Vector2i(14, 14), "14x14"), fixture_32, fixture_64,
	])
	assert_false(invalid_matrix.measurement_valid)
	assert_true(invalid_matrix.slo_pass)
	assert_false(invalid_matrix.ok)
	assert_eq(invalid_matrix.verdict, "FAIL")
	assert_eq(invalid_matrix.invalid_fixtures, ["64x64"])


func _fixture_report(size: Vector2i, fixture_id: String) -> Dictionary:
	var report := ArenaStudioPerformanceService.derive_fixture_gate(
		size, _valid_measurements()
	)
	report.fixture = fixture_id
	return report


func _valid_measurements() -> Dictionary:
	return {
		"open_ms": 499.0,
		"single_cell_ms": 15.0,
		"hundred_cells_ms": 40.0,
		"quick_preview_ms": 249.0,
		"validation_ms": 499.0,
		"art_geometry_ms": 30.0,
		"export_reference_ms": 45.0,
		"pan_zoom_1000_events_ms": 10.0,
		"cycle_average_ms": 20.0,
	}


func _arena_fixture(size: Vector2i) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Performance gate", "performance_gate")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = arena.theme_id
	arena.source_image_size = Vector2i(1280, 720)
	arena.grid_size = size
	arena.grid_origin = Vector2(640, 48)
	arena.axis_x = Vector2(16, 8)
	arena.axis_y = Vector2(-16, 8)
	for y in range(size.y):
		for x in range(size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	return arena


func _terrain_in_plan(plan: Dictionary, cell: Vector2i) -> StringName:
	for entry_value in plan.get("entries", []):
		var entry := entry_value as Dictionary
		if entry.get("cell", GridTransformService.INVALID_CELL) == cell:
			return StringName(entry.get("terrain_id", &""))
	return &""
