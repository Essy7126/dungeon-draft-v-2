extends GutTest

const ROOT := "res://artifacts/studio_2_0/room_integration_pipeline"
const MAIN_RUN_PATH := "res://data/runs/first_run.tres"
const MAIN_ROOM_PATH := "res://data/rooms/first_run_room_01.tres"
const TEST_ROOM_PATH := "res://data/rooms/test_waves/first_run_room_01_waves.tres"

var _runtime_result_existed_before_suite := false
var _runtime_result_before_suite := ""


func before_all() -> void:
	_runtime_result_existed_before_suite = FileAccess.file_exists(
		ArenaDirectTestService.LAST_RESULT_PATH
	)
	if _runtime_result_existed_before_suite:
		_runtime_result_before_suite = FileAccess.get_file_as_string(
			ArenaDirectTestService.LAST_RESULT_PATH
		)
	_remove_tree(ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))


func after_all() -> void:
	_restore_runtime_result_fixture()
	_remove_tree(ROOT)


func test_all_room_properties_have_an_integration_policy() -> void:
	var room_report := RoomIntegrationFieldPolicy.coverage_report(RoomData.new())
	var arena_report := RoomIntegrationFieldPolicy.coverage_report(ArenaDefinition.new())
	assert_true(room_report.ok, str(room_report.unknown))
	assert_true(arena_report.ok, str(arena_report.unknown))
	assert_gt((arena_report.classified as Dictionary).size(), 30)
	assert_eq(
		RoomIntegrationFieldPolicy.classification_for(&"encounter_definition"),
		RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
	)
	assert_eq(
		RoomIntegrationFieldPolicy.classification_for(&"cells"),
		RoomIntegrationFieldPolicy.ARENA_OWNED
	)
	assert_eq(
		RoomIntegrationFieldPolicy.classification_for(&"room_name"),
		RoomIntegrationFieldPolicy.IDENTITY_OWNED
	)
	assert_eq(
		RoomIntegrationFieldPolicy.classification_for(&"room_index"),
		RoomIntegrationFieldPolicy.RUN_OWNED
	)
	assert_eq(
		RoomIntegrationFieldPolicy.classification_for(&"future_unclassified_field"),
		RoomIntegrationFieldPolicy.UNKNOWN
	)


func test_update_preserves_main_and_test_gameplay_without_rewriting_run_sequence() -> void:
	for fixture in [
		{
			"name": "main",
			"source": load(MAIN_ROOM_PATH) as RoomData,
			"flow": RunData.RoomFlowMode.SINGLE_ENCOUNTER,
			"maximum": 1,
		},
		{
			"name": "test",
			"source": load(TEST_ROOM_PATH) as RoomData,
			"flow": RunData.RoomFlowMode.WAVE_CHAIN,
			"maximum": 10,
		},
	]:
		var directory := ROOT.path_join(str(fixture.name))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		var target := _gameplay_room(fixture.source as RoomData, "Salle conservée")
		var target_path := directory.path_join("room.tres")
		assert_eq(ResourceSaver.save(target, target_path), OK)
		var run_data := _run_fixture(
			ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
			int(fixture.flow), int(fixture.maximum), "Run %s" % fixture.name
		)
		var run_path := directory.path_join("run.tres")
		assert_eq(ResourceSaver.save(run_data, run_path), OK)
		var run_hash_before := FileAccess.get_sha256(run_path)
		var canonical_run := ResourceLoader.load(
			run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as RunData
		var gameplay_before := RoomIntegrationFieldPolicy.signature(
			canonical_run.rooms[0], RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
		)
		var produced := _arena_fixture("updated_%s" % fixture.name)
		produced.grid_origin += Vector2(17.0, 9.0)
		var produced_path := directory.path_join("produced.tres")
		assert_eq(ResourceSaver.save(produced, produced_path), OK)
		var result := ArenaProductionAttachmentService.attach_and_save(
			produced_path, canonical_run, ArenaProductionAttachmentService.UPDATE, 0
		)
		assert_true(result.ok, str(result))
		assert_true(result.preserved_gameplay)
		assert_false(result.run_saved)
		assert_false(result.copy_on_write)
		assert_eq(result.integrated_room_path, target_path)
		assert_eq(FileAccess.get_sha256(run_path), run_hash_before)
		var reloaded_run := ResourceLoader.load(
			run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as RunData
		assert_eq(reloaded_run.rooms[0].resource_path, target_path)
		assert_eq(reloaded_run.room_flow_mode, int(fixture.flow))
		assert_eq(
			RoomIntegrationFieldPolicy.signature(
				reloaded_run.rooms[0], RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
			),
			gameplay_before
		)
		assert_eq((reloaded_run.rooms[0] as ArenaDefinition).grid_origin, produced.grid_origin)
		if int(fixture.flow) == RunData.RoomFlowMode.SINGLE_ENCOUNTER:
			assert_true(reloaded_run.rooms[0].waves.is_empty())
		else:
			assert_gt(reloaded_run.rooms[0].waves.size(), 0)


func test_update_shared_room_creates_run_specific_copy_and_protects_other_run() -> void:
	var directory := ROOT.path_join("shared")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var target := _gameplay_room(load(MAIN_ROOM_PATH) as RoomData, "Salle partagée")
	var target_path := directory.path_join("shared_room.tres")
	assert_eq(ResourceSaver.save(target, target_path), OK)
	var loaded_target := ResourceLoader.load(
		target_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RoomData
	var run_a := _run_fixture(loaded_target, RunData.RoomFlowMode.SINGLE_ENCOUNTER, 1, "Run A")
	var run_b := _run_fixture(loaded_target, RunData.RoomFlowMode.SINGLE_ENCOUNTER, 1, "Run B")
	var run_a_path := directory.path_join("run_a.tres")
	var run_b_path := directory.path_join("run_b.tres")
	assert_eq(ResourceSaver.save(run_a, run_a_path), OK)
	assert_eq(ResourceSaver.save(run_b, run_b_path), OK)
	var run_b_hash := FileAccess.get_sha256(run_b_path)
	var target_hash := FileAccess.get_sha256(target_path)
	var graph := _shared_graph(target_path, run_a_path, run_b_path)
	var produced := _arena_fixture("shared_update")
	var produced_path := directory.path_join("produced.tres")
	assert_eq(ResourceSaver.save(produced, produced_path), OK)
	var canonical_a := ResourceLoader.load(
		run_a_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	var gameplay_before := RoomIntegrationFieldPolicy.signature(
		canonical_a.rooms[0], RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
	)
	var result := ArenaProductionAttachmentService.attach_and_save(
		produced_path, canonical_a, ArenaProductionAttachmentService.UPDATE, 0, graph
	)
	assert_true(result.ok, str(result))
	assert_true(result.copy_on_write)
	assert_true(result.run_saved)
	assert_ne(result.integrated_room_path, target_path)
	assert_true(ResourceLoader.exists(result.integrated_room_path))
	assert_eq(FileAccess.get_sha256(target_path), target_hash)
	assert_eq(FileAccess.get_sha256(run_b_path), run_b_hash)
	var reloaded_a := ResourceLoader.load(
		run_a_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	var reloaded_b := ResourceLoader.load(
		run_b_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	assert_eq(reloaded_a.rooms[0].resource_path, result.integrated_room_path)
	assert_eq(reloaded_b.rooms[0].resource_path, target_path)
	assert_eq(
		RoomIntegrationFieldPolicy.signature(
			reloaded_a.rooms[0], RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
		),
		gameplay_before
	)


func test_replace_is_advanced_reference_replacement_and_never_deletes_old_file() -> void:
	var directory := ROOT.path_join("replace")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var target := _gameplay_room(load(MAIN_ROOM_PATH) as RoomData, "Ancienne salle")
	var target_path := directory.path_join("old_room.tres")
	assert_eq(ResourceSaver.save(target, target_path), OK)
	var replacement := RoomIntegrationFieldPolicy.merge_arena_into_room(
		_arena_fixture("replacement"), target
	)
	replacement.room_name = "Nouvelle salle complète"
	var replacement_path := directory.path_join("replacement.tres")
	assert_eq(ResourceSaver.save(replacement, replacement_path), OK)
	var run_data := _run_fixture(
		ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		RunData.RoomFlowMode.SINGLE_ENCOUNTER, 1, "Run Replace"
	)
	var run_path := directory.path_join("run.tres")
	assert_eq(ResourceSaver.save(run_data, run_path), OK)
	var canonical := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	var result := ArenaProductionAttachmentService.attach_and_save(
		replacement_path, canonical, ArenaProductionAttachmentService.REPLACE, 0
	)
	assert_true(result.ok, str(result))
	assert_false(result.preserved_gameplay)
	var reloaded := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	assert_eq(reloaded.rooms[0].resource_path, replacement_path)
	assert_true(FileAccess.file_exists(target_path))
	var service := ArenaRunAuthoringService.new()
	assert_true(service.open(reloaded))
	assert_true(service.update_room(0, reloaded.rooms[0]).requires_room_integration_service)
	assert_false(service.update_room(0, target).ok)


func test_invalid_final_run_is_refused_and_run_file_is_rolled_back() -> void:
	var directory := ROOT.path_join("rollback")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var target := _gameplay_room(load(MAIN_ROOM_PATH) as RoomData, "Salle valide")
	var target_path := directory.path_join("room.tres")
	assert_eq(ResourceSaver.save(target, target_path), OK)
	var run_data := _run_fixture(
		ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		RunData.RoomFlowMode.SINGLE_ENCOUNTER, 1, "Run Rollback"
	)
	var run_path := directory.path_join("run.tres")
	assert_eq(ResourceSaver.save(run_data, run_path), OK)
	var run_hash_before := FileAccess.get_sha256(run_path)
	# Une nouvelle salle sans rencontre rendrait volontairement cette run
	# SINGLE_ENCOUNTER invalide. Le service écrit via staging puis restaure.
	var invalid_produced := _arena_fixture("invalid_insert")
	invalid_produced.encounter_definition = null
	invalid_produced.minimum_wave_count = 2
	invalid_produced.maximum_wave_count = 2
	var produced_path := directory.path_join("invalid_produced.tres")
	assert_eq(ResourceSaver.save(invalid_produced, produced_path), OK)
	var canonical := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	var result := ArenaProductionAttachmentService.attach_and_save(
		produced_path, canonical, ArenaProductionAttachmentService.INSERT_AFTER, 0
	)
	assert_false(result.ok, str(result))
	assert_true(str(result.error).contains("invalide"))
	assert_eq(FileAccess.get_sha256(run_path), run_hash_before)
	var reloaded := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	assert_eq(reloaded.rooms.size(), 1)
	assert_eq(reloaded.rooms[0].resource_path, target_path)


func test_one_click_service_produces_updates_reloads_and_journals_fixture() -> void:
	var directory := ROOT.path_join("one_click")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var target := _gameplay_room(load(MAIN_ROOM_PATH) as RoomData, "Salle one-click")
	var target_path := directory.path_join("room.tres")
	assert_eq(ResourceSaver.save(target, target_path), OK)
	var run_data := _run_fixture(
		ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		RunData.RoomFlowMode.SINGLE_ENCOUNTER, 1, "Run One Click"
	)
	var run_path := directory.path_join("run.tres")
	assert_eq(ResourceSaver.save(run_data, run_path), OK)
	var canonical := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	var arena := _arena_fixture("one_click_arena")
	var runtime_proof := _fixture_runtime_scene_contract_proof(arena)
	var production_destination := directory.path_join("production")
	var plan := ArenaIntegrationService.plan(
		arena, canonical, ArenaProductionAttachmentService.UPDATE, 0,
		production_destination, null,
		{"runtime_scene_result": runtime_proof}
	)
	assert_true(plan.ok, str(plan))
	assert_true(plan.can_integrate, str(plan.run_validation_errors))
	assert_true(plan.preserved_gameplay)
	var result := ArenaIntegrationService.integrate_with_options(
		arena, canonical, ArenaProductionAttachmentService.UPDATE, 0,
		production_destination, null, {}, {
			"gate_options": {"runtime_scene_result": runtime_proof},
		}
	)
	assert_true(result.ok, str(result))
	assert_eq(result.status, &"ROOM_INTEGRATED")
	assert_true(FileAccess.file_exists(result.journal_path))
	var journal = JSON.parse_string(FileAccess.get_file_as_string(result.journal_path))
	assert_true(journal is Dictionary)
	assert_eq(str(journal.get("state", "")), "COMMITTED")
	assert_eq(int(result.target_index), 0)
	assert_eq((result.reloaded_run as RunData).rooms[0].resource_path, target_path)
	assert_eq(result.integrated_room_path, target_path)


func test_produce_without_integrating_requires_no_run_and_changes_no_run_data() -> void:
	var directory := ROOT.path_join("produce_only")
	var production_destination := directory.path_join("production")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var arena := _arena_fixture("produce_only")
	var plan := ArenaIntegrationService.plan(
		arena, null, ArenaProductionAttachmentService.NONE, -1,
		production_destination
	)
	assert_true(plan.ok, str(plan))
	assert_true(plan.can_integrate, str(plan))
	assert_eq(plan.action, ArenaProductionAttachmentService.NONE)
	assert_true(str(plan.run_path).is_empty())
	var result := ArenaIntegrationService.integrate(
		arena, null, ArenaProductionAttachmentService.NONE, -1,
		production_destination
	)
	assert_true(result.ok, str(result))
	assert_eq(result.status, &"ROOM_PRODUCED")
	assert_eq(result.attachment.action, ArenaProductionAttachmentService.NONE)
	assert_true(FileAccess.file_exists(result.integrated_room_path))
	assert_null(result.reloaded_run)


func test_combined_transaction_failure_before_attachment_leaves_run_and_bundle_unchanged() -> void:
	var directory := ROOT.path_join("atomic_before_attachment")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var target := _gameplay_room(load(MAIN_ROOM_PATH) as RoomData, "Atomic before")
	var target_path := directory.path_join("room.tres")
	assert_eq(ResourceSaver.save(target, target_path), OK)
	var run_data := _run_fixture(
		ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		RunData.RoomFlowMode.SINGLE_ENCOUNTER, 1, "Atomic Before Run"
	)
	var run_path := directory.path_join("run.tres")
	assert_eq(ResourceSaver.save(run_data, run_path), OK)
	var run_before := FileAccess.get_sha256(run_path)
	var room_before := FileAccess.get_sha256(target_path)
	var production_destination := directory.path_join("production")
	var arena := _arena_fixture("atomic_before")
	var result := ArenaIntegrationService.integrate_with_options(
		arena,
		ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		ArenaProductionAttachmentService.UPDATE, 0, production_destination,
		null, {}, {
			"failure_step": "before_attachment",
			"gate_options": {
				"runtime_scene_result": _fixture_runtime_scene_contract_proof(arena),
			},
		}
	)
	assert_false(result.ok, str(result))
	assert_eq(result.status, &"INTEGRATION_ROLLED_BACK")
	assert_true(result.production_rollback.ok, str(result.production_rollback))
	assert_false(DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(production_destination)
	))
	assert_eq(FileAccess.get_sha256(run_path), run_before)
	assert_eq(FileAccess.get_sha256(target_path), room_before)


func test_combined_transaction_failure_after_attachment_restores_room_run_and_bundle() -> void:
	var directory := ROOT.path_join("atomic_after_attachment")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var target := _gameplay_room(load(MAIN_ROOM_PATH) as RoomData, "Atomic after")
	var target_path := directory.path_join("room.tres")
	assert_eq(ResourceSaver.save(target, target_path), OK)
	var run_data := _run_fixture(
		ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		RunData.RoomFlowMode.SINGLE_ENCOUNTER, 1, "Atomic After Run"
	)
	var run_path := directory.path_join("run.tres")
	assert_eq(ResourceSaver.save(run_data, run_path), OK)
	var run_before := FileAccess.get_sha256(run_path)
	var room_before := FileAccess.get_sha256(target_path)
	var production_destination := directory.path_join("production")
	var arena := _arena_fixture("atomic_after")
	var result := ArenaIntegrationService.integrate_with_options(
		arena,
		ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		ArenaProductionAttachmentService.UPDATE, 0, production_destination,
		null, {}, {
			"failure_step": "after_attachment",
			"gate_options": {
				"runtime_scene_result": _fixture_runtime_scene_contract_proof(arena),
			},
		}
	)
	assert_false(result.ok, str(result))
	assert_eq(result.status, &"INTEGRATION_ROLLED_BACK")
	assert_true(result.attachment_rollback.ok, str(result.attachment_rollback))
	assert_true(result.production_rollback.ok, str(result.production_rollback))
	assert_false(DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(production_destination)
	))
	assert_eq(FileAccess.get_sha256(run_path), run_before)
	assert_eq(FileAccess.get_sha256(target_path), room_before)


func test_guided_pipeline_emits_structured_events_for_every_step() -> void:
	var directory := ROOT.path_join("diagnostics_nominal")
	var destination := directory.path_join("production")
	var diagnostics_root := directory.path_join("diagnostics")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var result := ArenaIntegrationService.integrate_with_options(
		_arena_fixture("diagnostics_nominal"),
		null,
		ArenaProductionAttachmentService.NONE,
		-1,
		destination,
		null,
		{},
		{
			"pipeline_diagnostics": {
				"diagnostic_root": diagnostics_root,
			},
		}
	)
	assert_true(result.ok, str(result))
	var pipeline: Dictionary = result.pipeline
	assert_true(FileAccess.file_exists(str(pipeline.event_log_path)))
	var events: Array = pipeline.events
	for step in ["PLAN", "JOURNAL", "PRODUCTION", "ATTACHMENT", "FINALIZE"]:
		var started := _pipeline_event(events, "step_started", step)
		var completed := _pipeline_event(events, "step_completed", step)
		assert_false(started.is_empty(), "%s started" % step)
		assert_false(completed.is_empty(), "%s completed" % step)
		assert_eq(str(completed.get("error", "")), "", "%s error" % step)
		for event in [started, completed]:
			assert_true(event.has("duration_ms"), "%s duration" % step)
			assert_true(event.get("context") is Dictionary, "%s context" % step)
			assert_true(event.get("files") is Array, "%s files" % step)
			assert_true(
				event.get("fingerprints") is Dictionary,
				"%s fingerprints" % step
			)
			assert_eq(
				str((event.context as Dictionary).get("action", "")),
				str(ArenaProductionAttachmentService.NONE),
				"%s action context" % step
			)
	assert_true(str(FileAccess.get_file_as_string(
		str(pipeline.event_log_path)
	)).contains("step_completed"))


func test_guided_pipeline_watchdog_reports_a_synchronous_overrun() -> void:
	var directory := ROOT.path_join("diagnostics_watchdog")
	var monitor := ArenaGuidedPipelineDiagnosticsService.new({
		"diagnostic_root": directory,
		"step_timeouts_ms": {"BLOCKING_FIXTURE": 20},
	})
	monitor.begin_step(
		&"BLOCKING_FIXTURE",
		{"fixture": "synchronous_overrun"},
		[],
		{},
		monitor.timeout_for(&"BLOCKING_FIXTURE")
	)
	OS.delay_msec(200)
	var checkpoint := monitor.end_step(&"BLOCKING_FIXTURE", true)
	assert_true(checkpoint.timed_out, str(checkpoint))
	assert_false(str(checkpoint.watchdog_dump_path).is_empty())
	assert_true(FileAccess.file_exists(str(checkpoint.watchdog_dump_path)))
	assert_true(FileAccess.file_exists(str(checkpoint.diagnostic_dump_path)))
	var event_log := FileAccess.get_file_as_string(monitor.event_log_path)
	assert_true(event_log.contains("pipeline_heartbeat"), event_log)
	assert_true(event_log.contains("step_timeout_watchdog"), event_log)
	var failed := _pipeline_event(
		monitor.events, "step_failed", "BLOCKING_FIXTURE"
	)
	assert_true(failed.get("timed_out", false), str(failed))


func test_guided_pipeline_timeout_rolls_back_and_writes_diagnostic_dump() -> void:
	var directory := ROOT.path_join("diagnostics_timeout")
	var destination := directory.path_join("production")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var fake_time := {"usec": 1_000}
	var monitor := ArenaGuidedPipelineDiagnosticsService.new({
		"diagnostic_root": directory.path_join("diagnostics"),
		"clock_usec": func() -> int: return int(fake_time.usec),
		"step_timeouts_ms": {"PRODUCTION": 1},
	})
	monitor.step_started.connect(func(event: Dictionary) -> void:
		if str(event.get("step", "")) == "PRODUCTION":
			fake_time["usec"] = 3_000
	)
	var result := ArenaIntegrationService.integrate_with_options(
		_arena_fixture("diagnostics_timeout"),
		null,
		ArenaProductionAttachmentService.NONE,
		-1,
		destination,
		null,
		{},
		{"pipeline_monitor": monitor}
	)
	assert_false(result.ok, str(result))
	assert_eq(result.status, &"STEP_TIMEOUT")
	assert_true(result.production_rollback.ok, str(result.production_rollback))
	assert_false(DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(destination)
	))
	var timeout_journal: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(str(result.journal_path))
	) as Dictionary
	assert_eq(str(timeout_journal.get("state", "")), "STEP_TIMEOUT")
	assert_true(FileAccess.file_exists(str(result.diagnostic_dump_path)))
	var dump_value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(str(result.diagnostic_dump_path))
	)
	assert_true(dump_value is Dictionary)
	var dump := dump_value as Dictionary
	assert_eq(str(dump.get("step", "")), "PRODUCTION")
	assert_true((dump.get("git_status", {}) as Dictionary).get("read_only", false))
	assert_true(dump.get("scene_tree") is Dictionary)
	assert_true(dump.get("locks") is Array)
	assert_true(dump.get("transactions") is Array)
	assert_true(dump.get("staging") is Array)
	assert_true(dump.get("recovery") is Array)
	assert_true(dump.get("last_signal_received") is Dictionary)
	var failed := _pipeline_event(
		(result.pipeline as Dictionary).events,
		"step_failed",
		"PRODUCTION"
	)
	assert_true(failed.get("timed_out", false), str(failed))


func test_guided_pipeline_interruption_before_attachment_rolls_back_cleanly() -> void:
	var directory := ROOT.path_join("diagnostics_interruption")
	var destination := directory.path_join("production")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var monitor := ArenaGuidedPipelineDiagnosticsService.new({
		"diagnostic_root": directory.path_join("diagnostics"),
	})
	monitor.step_completed.connect(func(event: Dictionary) -> void:
		if str(event.get("step", "")) == "PRODUCTION":
			monitor.request_interrupt("fixture_requested_interrupt")
	)
	var result := ArenaIntegrationService.integrate_with_options(
		_arena_fixture("diagnostics_interruption"),
		null,
		ArenaProductionAttachmentService.NONE,
		-1,
		destination,
		null,
		{},
		{"pipeline_monitor": monitor}
	)
	assert_false(result.ok, str(result))
	assert_eq(result.status, &"PIPELINE_INTERRUPTED")
	assert_eq(str(result.error), "fixture_requested_interrupt")
	assert_true(result.production_rollback.ok, str(result.production_rollback))
	assert_false(DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(destination)
	))
	var interruption_journal: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(str(result.journal_path))
	) as Dictionary
	assert_eq(
		str(interruption_journal.get("state", "")),
		"PIPELINE_INTERRUPTED"
	)
	assert_true(FileAccess.file_exists(str(result.diagnostic_dump_path)))
	var failed := _pipeline_event(
		(result.pipeline as Dictionary).events,
		"step_failed",
		"ATTACHMENT"
	)
	assert_true(failed.get("interrupted", false), str(failed))


func test_destination_panel_tour_and_window_terms_are_unambiguous() -> void:
	var context := StudioProjectContext.new()
	assert_true(context.initialize(MAIN_RUN_PATH, &"elf").ok)
	var graph := StudioReferenceGraphService.new()
	assert_true(graph.scan(true).ok)
	var shell := DungeonDraftStudioMain.new()
	shell.setup(null, null, context, graph)
	add_child_autofree(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(shell.detach_button.text.contains("fenêtre"))
	assert_true(shell.detach_button.tooltip_text.contains("fenêtre"))
	assert_eq(shell.produce_button.text, "Intégrer à la run")
	var studio := shell.arena_studio
	assert_not_null(studio.destination_panel)
	assert_true(studio.destination_resolve_button.visible)
	assert_true(studio.destination_details_text.text.contains(
		"Dossier de production déjà présent"
	))
	studio.show_production_wizard()
	# The wizard has now initialized all candidate fields. This installs an
	# exact, current unit-fixture contract proof; it is not evidence of an E2E
	# battle-scene boot.
	assert_true(_install_fixture_runtime_scene_contract_proof(
		studio._production_candidate()
	))
	studio._refresh_production_wizard()
	var bundle_resolution := (
		studio._production_last_plan.get("production", {}) as Dictionary
	).get("bundle_resolution", {}) as Dictionary
	var bundle_files := bundle_resolution.get("files", []) as Array
	assert_gt(bundle_files.size(), 0)
	assert_true(studio.production_resolution_text.text.contains(
		"Fichiers présents (%d)" % bundle_files.size()
	))
	for expected_name in [
		"arena.tres",
		"arena_principal.tres",
		"modular_visual_profile.tres",
		"production_manifest.json",
	]:
		assert_true(studio.production_resolution_text.text.contains(expected_name))
	assert_true((studio.production_resolution_buttons[
		ArenaBundleResolutionService.VERSION_ALONGSIDE
	] as Button).visible)
	assert_false((studio.production_resolution_buttons[
		ArenaBundleResolutionService.VERSION_ALONGSIDE
	] as Button).disabled)
	studio.production_dialog.hide()
	# Isolate the UI policy from the deliberately frozen, incomplete
	# room_01_forest production bundle present in the repository.
	studio.arena.arena_id = &"room_integration_ui_fixture"
	assert_true(_install_fixture_runtime_scene_contract_proof(
		studio._destination_candidate()
	))
	studio._refresh_destination_panel()
	assert_false(studio.destination_panel.get_parent() is ScrollContainer)
	assert_eq(
		StringName(studio.destination_action_option.get_selected_metadata()),
		ArenaProductionAttachmentService.UPDATE
	)
	assert_true(studio.destination_integrate_button.text.contains(
		"Vérifier et intégrer dans Principale"
	))
	assert_false(
		studio.destination_integrate_button.disabled,
		studio._gate_blocking_text(studio._destination_last_plan)
	)
	assert_true(studio.destination_integrate_button.text.contains("avertissement"))
	assert_true(studio.destination_details_text.text.contains(
		"Pourquoi l'intégration est-elle indisponible ?"
	) or studio.destination_details_text.text.contains("ARÈNE PRÊTE À INTÉGRER"))
	assert_true(studio.destination_summary_label.text.contains("gameplay conservé"))
	assert_true(studio.destination_details_text.text.contains("ArenaDefinition finale"))
	var targets := PackedStringArray()
	var all_text := ""
	for page in ArenaStudioGuidedTour.PAGES:
		targets.append(str(page.target))
		all_text += " " + str(page.title) + " " + str(page.body)
	for expected in [
		"run", "room", "arena", "grid", "tiles", "walls_spawns", "art_export",
		"art_import", "views", "validate", "test", "destination", "integrate",
	]:
		assert_true(targets.has(expected), expected)
	assert_true(all_text.contains("rencontre"))
	assert_true(all_text.contains("vagues"))
	studio.guided_tour.start(&"destination")
	assert_eq(studio.guided_tour.current_target(), &"destination")
	studio.guided_tour.hide()
	shell.set_detached_state(true)
	assert_true(shell.detach_button.text.begins_with("Réint"))
	assert_true(shell.detach_button.text.contains("fenêtre"))
	_restore_runtime_result_fixture()


func _arena_fixture(identifier: String) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Fixture %s" % identifier, identifier)
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(12, 9)
	arena.grid_origin = Vector2.ZERO
	arena.axis_x = Vector2(32.0, 16.0)
	arena.axis_y = Vector2(-32.0, 16.0)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	ArenaEditingService.prepare_automatically(arena)
	var objective := ArenaObjectiveDefinition.new()
	objective.objective_id = &"integration_goal"
	objective.cell = Vector2i(6, 4)
	arena.objectives.append(objective)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _fixture_runtime_scene_contract_proof(arena: ArenaDefinition) -> Dictionary:
	# Preuve synthétique limitée à cette fixture unitaire : elle vérifie le
	# contrat du gate avec la scène/fingerprint/topologie courants, sans prétendre
	# qu'un boot E2E de la scène de bataille a été exécuté par ce test.
	var fingerprint := ArenaSnapshotService.arena_fingerprint(arena)
	var topology: Dictionary = ArenaTopologySignatureService.build(arena)
	var topology_hash := str(topology.get("topology_hash", ""))
	var visible_floor_hash := str(topology.get("visible_floor_hash", ""))
	var battle_scene_path := arena.battle_scene.resource_path \
		if arena != null and arena.battle_scene != null else ""
	var configuration := &"UNIT_FIXTURE_CONTRACT"
	return {
		"ok": true,
		"proof_kind": "UNIT_FIXTURE_CONTRACT_PROOF",
		"fixture_only": true,
		"e2e_boot_performed": false,
		"runtime_scene_inspected": true,
		"script_parse_ok": true,
		"scene_instantiated": true,
		"runtime_ready": true,
		"grid_ready": true,
		"pathfinder_ready": true,
		"render_ready": true,
		"spawn_ready": true,
		"cleanup_ok": true,
		"produced_bundle_loaded": false,
		"configuration": str(configuration),
		"expected_battle_scene_path": battle_scene_path,
		"battle_scene_path": battle_scene_path,
		"working_fingerprint": fingerprint,
		"temporary_fingerprint": fingerprint,
		"runtime_fingerprint": fingerprint,
		"fingerprints_identical": true,
		"working_topology_hash": topology_hash,
		"temporary_topology_hash": topology_hash,
		"runtime_topology_hash": topology_hash,
		"topology_hashes_identical": true,
		"expected_floor_hash": visible_floor_hash,
		"rendered_floor_hash": visible_floor_hash,
		"runtime_probe_key": ArenaDirectTestService.probe_key(
			fingerprint, topology_hash, battle_scene_path, configuration
		),
		"errors": [],
		"warnings": ["fixture_contract_proof_not_e2e_boot"],
	}


func _install_fixture_runtime_scene_contract_proof(arena: ArenaDefinition) -> bool:
	if arena == null:
		return false
	var absolute_path := ProjectSettings.globalize_path(
		ArenaDirectTestService.LAST_RESULT_PATH
	)
	var directory_error := DirAccess.make_dir_recursive_absolute(
		absolute_path.get_base_dir()
	)
	if directory_error != OK:
		return false
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(
		_fixture_runtime_scene_contract_proof(arena), "\t", false
	))
	file.close()
	return true


func _restore_runtime_result_fixture() -> void:
	var absolute_path := ProjectSettings.globalize_path(
		ArenaDirectTestService.LAST_RESULT_PATH
	)
	if _runtime_result_existed_before_suite:
		DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
		var file := FileAccess.open(absolute_path, FileAccess.WRITE)
		if file != null:
			file.store_string(_runtime_result_before_suite)
			file.close()
	elif FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _gameplay_room(source: RoomData, name: String) -> RoomData:
	var room := RoomData.new()
	room.room_name = name
	room.encounter_definition = source.encounter_definition
	room.waves.assign(source.waves)
	room.minimum_wave_count = source.minimum_wave_count
	room.maximum_wave_count = source.maximum_wave_count
	room.ultimate_reward_base_chance = source.ultimate_reward_base_chance
	room.ultimate_reward_min_gain_per_wave = source.ultimate_reward_min_gain_per_wave
	room.ultimate_reward_max_gain_per_wave = source.ultimate_reward_max_gain_per_wave
	room.enemies.assign(source.enemies)
	return room


func _run_fixture(
		room: RoomData,
		flow_mode: int,
		maximum_waves: int,
		name: String
	) -> RunData:
	var run_data := RunData.new()
	run_data.run_name = name
	run_data.room_flow_mode = flow_mode
	run_data.maximum_waves_per_room = maximum_waves
	run_data.rooms = [room]
	return run_data


func _shared_graph(room_path: String, run_a_path: String, run_b_path: String) -> StudioReferenceGraphService:
	var graph := StudioReferenceGraphService.new()
	graph.nodes[room_path] = {"kind": &"ROOM", "path": room_path}
	graph.nodes[run_a_path] = {"kind": &"RUN", "path": run_a_path}
	graph.nodes[run_b_path] = {"kind": &"RUN", "path": run_b_path}
	graph.incoming[room_path] = [
		{"from": run_a_path, "to": room_path},
		{"from": run_b_path, "to": room_path},
	]
	return graph


func _pipeline_event(
		events: Array,
		event_name: String,
		step: String
	) -> Dictionary:
	for value in events:
		if value is Dictionary \
				and str(value.get("event", "")) == event_name \
				and str(value.get("step", "")) == step:
			return (value as Dictionary).duplicate(true)
	return {}


func _remove_tree(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return true
	for file_name in directory.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))
	for child in directory.get_directories():
		_remove_tree(path.path_join(child))
	DirAccess.remove_absolute(absolute)
	return true
