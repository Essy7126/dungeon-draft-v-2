extends GutTest

const REPORT_ROOT := "user://dungeon_draft_studio/tests/performance"


func after_all() -> void:
	ArenaProductionTransactionService._remove_tree(REPORT_ROOT)


func test_full_14_32_64_matrix_records_thresholds_and_twenty_stable_cycles() -> void:
	var report := ArenaStudioPerformanceService.benchmark_and_save(
		REPORT_ROOT.path_join("benchmark_report.json"), 20
	)
	print("ARENA_PERFORMANCE_MATRIX_JSON=%s" % JSON.stringify(report))
	assert_true(report.ok, str(report))
	assert_true(report.measurement_valid, str(report))
	assert_true(report.slo_pass, str(report))
	assert_eq(report.verdict, "PASS")
	assert_eq(report.required_slo_fixtures, 1)
	assert_eq(report.measurement_only_fixtures, 2)
	assert_eq((report.fixtures as Array).size(), 3)
	assert_true(FileAccess.file_exists(report.report_path))
	for fixture_value in report.fixtures:
		var fixture := fixture_value as Dictionary
		assert_true(fixture.ok, str(fixture))
		assert_true(fixture.measurement_valid, str(fixture))
		assert_has(fixture, "slo_pass")
		assert_has(fixture, "breakdown")
		assert_gt(float(fixture.open_ms), 0.0)
		assert_gt(float(fixture.quick_preview_ms), 0.0)
		assert_gt(float(fixture.validation_ms), 0.0)
		assert_gt(float(fixture.export_reference_ms), 0.0)
		assert_false(fixture.allocation_growth_detected, str(fixture))
		if fixture.fixture == "14x14":
			assert_eq(fixture.cycle_count, 20)
			assert_false(fixture.measurement_only)
			assert_eq(fixture.gate_mode, "required_slo")
			assert_true(fixture.slo_pass, str(fixture))
			assert_eq(fixture.verdict, "PASS")
			for passed in (fixture.thresholds_pass as Dictionary).values():
				assert_true(passed, str(fixture.thresholds_pass))
		else:
			assert_true(fixture.measurement_only)
			assert_eq(fixture.gate_mode, "measurement_only")
			assert_null(fixture.slo_pass)
			assert_eq(fixture.verdict, "MEASUREMENT_ONLY")
			assert_true((fixture.thresholds_pass as Dictionary).is_empty())
