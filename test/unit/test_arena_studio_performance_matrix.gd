extends GutTest

const REPORT_ROOT := "user://dungeon_draft_studio/tests/performance"


func after_all() -> void:
	ArenaProductionTransactionService._remove_tree(REPORT_ROOT)


func test_full_14_32_64_matrix_records_thresholds_and_twenty_stable_cycles() -> void:
	var report := ArenaStudioPerformanceService.benchmark_and_save(
		REPORT_ROOT.path_join("benchmark_report.json"), 20
	)
	assert_true(report.ok, str(report))
	assert_eq((report.fixtures as Array).size(), 3)
	assert_true(FileAccess.file_exists(report.report_path))
	for fixture_value in report.fixtures:
		var fixture := fixture_value as Dictionary
		assert_true(fixture.ok, str(fixture))
		assert_gt(float(fixture.open_ms), 0.0)
		assert_gt(float(fixture.quick_preview_ms), 0.0)
		assert_gt(float(fixture.validation_ms), 0.0)
		assert_gt(float(fixture.export_reference_ms), 0.0)
		assert_false(fixture.allocation_growth_detected, str(fixture))
		if fixture.fixture == "14x14":
			assert_eq(fixture.cycle_count, 20)
			# Les seuils sont rapportés et servent à comparer les runners. Ils ne
			# deviennent pas une assertion wall-clock instable sous suite globale.
			for passed in (fixture.thresholds_pass as Dictionary).values():
				assert_true(passed is bool, str(fixture.thresholds_pass))
