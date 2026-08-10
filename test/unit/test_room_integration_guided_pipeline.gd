extends GutTest

const ROOT := "res://artifacts/studio_2_0/room_integration_pipeline"
const MAIN_RUN_PATH := "res://data/runs/first_run.tres"
const MAIN_ROOM_PATH := "res://data/rooms/first_run_room_01.tres"
const TEST_ROOM_PATH := "res://data/rooms/test_waves/first_run_room_01_waves.tres"


func before_all() -> void:
	_remove_tree(ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))


func after_all() -> void:
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
	var production_destination := directory.path_join("production")
	var plan := ArenaIntegrationService.plan(
		arena, canonical, ArenaProductionAttachmentService.UPDATE, 0,
		production_destination
	)
	assert_true(plan.ok, str(plan))
	assert_true(plan.can_integrate, str(plan.run_validation_errors))
	assert_true(plan.preserved_gameplay)
	var result := ArenaIntegrationService.integrate(
		arena, canonical, ArenaProductionAttachmentService.UPDATE, 0,
		production_destination
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
	var result := ArenaIntegrationService.integrate_with_options(
		_arena_fixture("atomic_before"),
		ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		ArenaProductionAttachmentService.UPDATE, 0, production_destination,
		null, {}, {"failure_step": "before_attachment"}
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
	var result := ArenaIntegrationService.integrate_with_options(
		_arena_fixture("atomic_after"),
		ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		ArenaProductionAttachmentService.UPDATE, 0, production_destination,
		null, {}, {"failure_step": "after_attachment"}
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
	assert_false(studio.destination_panel.get_parent() is ScrollContainer)
	assert_eq(
		StringName(studio.destination_action_option.get_selected_metadata()),
		ArenaProductionAttachmentService.UPDATE
	)
	assert_true(studio.destination_integrate_button.text.contains("Intégrer dans Principale"))
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
