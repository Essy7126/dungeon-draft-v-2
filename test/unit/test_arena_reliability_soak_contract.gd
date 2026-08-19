extends GutTest

const EXPECTED := {
	"strokes": 100,
	"transforms": 100,
	"decorations": 20,
	"previews": 20,
	"tester_probes": 20,
	"rooms": 20,
	"production_updates": 10,
}


func test_exact_counts_and_stable_cleanup_pass_without_wall_clock_budget() -> void:
	var before := _snapshot(100, 20, 50, 0, 40, 12, 1, 1, 1_000_000)
	var after := before.duplicate(true)
	after.object_count += 3
	after.resource_count += 1
	after.memory_static_bytes += 4096
	var samples := {
		"previews": [
			_snapshot(103, 21, 50, 0, 40, 12, 1, 1, 1_004_096),
			_snapshot(103, 21, 50, 0, 40, 12, 1, 1, 1_004_096),
			_snapshot(104, 21, 50, 0, 40, 12, 1, 1, 1_008_192),
			_snapshot(104, 21, 50, 0, 40, 12, 1, 1, 1_008_192),
			_snapshot(103, 21, 50, 0, 40, 12, 1, 1, 1_004_096),
		],
	}
	var report := ArenaSoakMetrics.evaluate(
		before,
		after,
		samples,
		{"previews": [2.0, 2.2, 2.1, 2.3, 2.0]},
		EXPECTED,
		EXPECTED,
		true
	)
	assert_true(report.ok, str(report))
	assert_eq(report.verdict, "PASS")
	assert_true(report.shutdown_diagnostics_included == false)
	assert_eq(int(report.arena_in_process_delta.orphan_node_count), 0)
	assert_eq((report.warnings as Array).size(), 3)


func test_missing_operation_and_fixture_cleanup_are_blocking() -> void:
	var completed := EXPECTED.duplicate(true)
	completed.previews = 19
	var report := ArenaSoakMetrics.evaluate(
		_snapshot(),
		_snapshot(),
		{},
		{},
		EXPECTED,
		completed,
		false
	)
	assert_false(report.ok)
	assert_true(_has_classification(report.errors, "FIXTURE_CLEANUP_FAILED"))
	assert_true(_has_classification(report.errors, "OPERATION_COUNT_MISMATCH"))


func test_orphan_and_continuous_growth_are_arena_failures() -> void:
	var before := _snapshot()
	var after := _snapshot()
	after.orphan_node_count = 1
	var samples: Array[Dictionary] = []
	for index in range(5):
		samples.append(_snapshot(
			100 + index,
			20,
			50,
			0,
			40,
			12,
			1,
			1,
			1_000_000
		))
	var report := ArenaSoakMetrics.evaluate(
		before,
		after,
		{"rooms": samples},
		{"rooms": [1.0, 1.0, 1.0, 1.0, 1.0]},
		EXPECTED,
		EXPECTED,
		true
	)
	assert_false(report.ok)
	assert_true(_has_classification(report.errors, "RESIDUAL_ARENA_OBJECT"))
	assert_true(_has_classification(report.errors, "CONTINUOUS_GROWTH"))
	assert_eq(
		str((report.continuous_growth_findings as Array)[0].phase),
		"rooms"
	)


func test_relative_latency_degradation_is_detected_without_absolute_slo() -> void:
	var report := ArenaSoakMetrics.evaluate(
		_snapshot(),
		_snapshot(),
		{},
		{"production_updates": [1.0, 2.0, 3.0, 20.0, 30.0]},
		EXPECTED,
		EXPECTED,
		true
	)
	assert_false(report.ok)
	assert_true(_has_classification(
		report.errors, "CONTINUOUS_LATENCY_DEGRADATION"
	))
	assert_true(report.latencies.production_updates.continuous_degradation)


func test_short_or_plateauing_series_is_not_called_a_continuous_leak() -> void:
	var short := [
		_snapshot(1), _snapshot(2), _snapshot(3), _snapshot(4),
	]
	assert_true(ArenaSoakMetrics.continuous_growth(short).is_empty())
	var plateau := [
		_snapshot(1), _snapshot(2), _snapshot(2), _snapshot(3), _snapshot(3),
	]
	assert_true(ArenaSoakMetrics.continuous_growth(plateau).is_empty())


func test_transform_history_memory_retention_is_explicit_but_other_growth_gates() -> void:
	var memory_only: Array[Dictionary] = []
	for index in range(5):
		memory_only.append(_snapshot(
			100,
			20,
			50,
			0,
			40,
			12,
			1,
			1,
			1_000_000 + index * 128 * 1024
		))
	var retained_report := ArenaSoakMetrics.evaluate(
		_snapshot(),
		_snapshot(),
		{"transforms": memory_only},
		{"transforms": [1.0, 1.0, 1.0, 1.0, 1.0]},
		EXPECTED,
		EXPECTED,
		true
	)
	assert_true(retained_report.ok, str(retained_report))
	assert_eq(
		retained_report.expected_phase_retention.transforms
			.excluded_from_continuous_growth,
		["memory_static_bytes"]
	)

	var object_growth := memory_only.duplicate(true)
	for index in range(object_growth.size()):
		object_growth[index].object_count = 100 + index
	var leaking_report := ArenaSoakMetrics.evaluate(
		_snapshot(),
		_snapshot(),
		{"transforms": object_growth},
		{"transforms": [1.0, 1.0, 1.0, 1.0, 1.0]},
		EXPECTED,
		EXPECTED,
		true
	)
	assert_false(leaking_report.ok)
	assert_true(_has_classification(
		leaking_report.errors, "CONTINUOUS_GROWTH"
	))


func test_global_arena_cache_growth_is_never_treated_as_expected_retention() -> void:
	var samples: Array[Dictionary] = []
	for index in range(5):
		var snapshot := _snapshot()
		snapshot.arena_visual_inspection_cache_size = index
		samples.append(snapshot)
	var report := ArenaSoakMetrics.evaluate(
		_snapshot(),
		_snapshot(),
		{"production_updates": samples},
		{"production_updates": [1.0, 1.0, 1.0, 1.0, 1.0]},
		EXPECTED,
		EXPECTED,
		true
	)
	assert_false(report.ok)
	assert_true(_has_growth_metric(
		report.continuous_growth_findings,
		"arena_visual_inspection_cache_size"
	))


func _snapshot(
		objects := 100,
		resources := 20,
		nodes := 50,
		orphans := 0,
		tree_nodes := 40,
		signals := 12,
		subviewports := 1,
		windows := 1,
		static_memory := 1_000_000
	) -> Dictionary:
	return {
		"object_count": objects,
		"resource_count": resources,
		"node_count": nodes,
		"orphan_node_count": orphans,
		"tree_node_count": tree_nodes,
		"signal_connection_count": signals,
		"subviewport_count": subviewports,
		"window_count": windows,
		"memory_static_bytes": static_memory,
		"render_video_memory_bytes": 2_000_000,
		"arena_render_plan_cache_size": 0,
		"arena_tactical_cache_size": 0,
		"arena_visual_inspection_cache_size": 0,
	}


func _has_classification(errors: Array, classification: String) -> bool:
	for error_value in errors:
		if str((error_value as Dictionary).get("classification", "")) \
				== classification:
			return true
	return false


func _has_growth_metric(findings: Array, metric: String) -> bool:
	for finding_value in findings:
		if str((finding_value as Dictionary).get("metric", "")) == metric:
			return true
	return false
