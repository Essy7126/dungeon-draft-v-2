extends GutTest

const SnapshotRunner = preload("res://tools/ui_snapshots/ui_snapshot_runner.gd")


func test_registry_has_stable_unique_ids_and_explicit_blockers() -> void:
	var scenarios := UISnapshotRegistry.production_scenarios()
	var ids := {}
	var automated := 0
	var documented := 0
	for scenario in scenarios:
		var snapshot_id := scenario.snapshot_id()
		assert_false(ids.has(snapshot_id), "Duplicate snapshot id: %s" % snapshot_id)
		ids[snapshot_id] = true
		assert_false(scenario.scene_path.is_empty())
		assert_false(String(scenario.fixture_id).is_empty())
		if scenario.is_automated():
			automated += 1
		else:
			documented += 1
			assert_false(scenario.blocker.is_empty())
	assert_eq(scenarios.size(), 23)
	assert_eq(automated, 6)
	assert_eq(documented, 17)


func test_required_resolutions_and_main_scene_are_stable() -> void:
	assert_eq(
		SnapshotRunner.RESOLUTIONS,
		[Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
	)
	assert_eq(
		ProjectSettings.get_setting("application/run/main_scene"),
		"uid://bhxy4lh81uk3i"
	)
	var title_scene := ResourceUID.get_id_path(
		ResourceUID.text_to_id(str(ProjectSettings.get_setting("application/run/main_scene")))
	)
	assert_eq(title_scene, "res://ui/TitreEcran.tscn")


func test_before_after_scope_is_intentionally_limited_to_impacted_states() -> void:
	var automated_ids: Array[String] = []
	for scenario in UISnapshotRegistry.production_scenarios():
		if scenario.is_automated():
			automated_ids.append(scenario.snapshot_id())
	assert_has(automated_ids, "battle__deployment")
	assert_has(automated_ids, "combat_feedback__gallery")
	assert_has(automated_ids, "title__default")
	assert_has(automated_ids, "start_hub__idle")
	assert_has(automated_ids, "intro_cinematic__plan_05")
