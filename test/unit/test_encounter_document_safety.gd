extends GutTest

## Régressions propres au chantier documentaire. Aucune écriture de gameplay
## sous res:// : toutes les fixtures sont possédées sous user://.
const ROOT := "user://dungeon_draft_studio/encounter_document_safety"
const TEST_RECOVERY_ROOT := ROOT + "/recoveries"
const TEST_CONTEXT_TRANSACTION_ROOT := ROOT + "/context_transactions"
var _serial := 0
var _owned_room_draft_paths := PackedStringArray()


func before_each() -> void:
	_cleanup_owned_room_drafts()
	_owned_room_draft_paths.clear()
	_remove_tree(ROOT)


func after_each() -> void:
	_cleanup_owned_room_drafts()
	_owned_room_draft_paths.clear()
	_remove_tree(ROOT)


func _fixture() -> Dictionary:
	_serial += 1
	var root := ROOT.path_join("%d_%d" % [Time.get_ticks_usec(), _serial])
	for folder in [root, root.path_join("a"), root.path_join("b")]:
		assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)), OK)
	var unit := UnitData.new()
	unit.unit_id = &"document_fixture"
	unit.unit_name = "Fixture"
	unit.team = 1
	var unit_path := root.path_join("unit.tres")
	assert_eq(ResourceSaver.save(unit, unit_path), OK)
	unit = ResourceLoader.load(unit_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var paths := [root.path_join("a/same.tres"), root.path_join("b/same.tres")]
	var encounters: Array[EncounterDefinition] = []
	for path in paths:
		var encounter := EncounterDefinition.new()
		encounter.roster_units = [unit]
		encounter.roster_counts = PackedInt32Array([1])
		encounter.living_enemy_cap = 1
		encounter.formation_profiles = [&"line"]
		assert_eq(ResourceSaver.save(encounter, path), OK)
		assert_true(_assign_serialized_test_uid(path), path)
		encounters.append(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP))
	var layout := RoomGridLayout.new()
	layout.layout_id = &"document_fixture"
	layout.logical_size = Vector2i(8, 8)
	layout.layout_rows = PackedStringArray([
		"........", "........", "........", "........",
		"........", "........", "........", "........"])
	var run := RunData.new()
	run.run_name = "Partie documentaire"
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 2
	for index in range(2):
		var room := RoomData.new()
		room.room_name = "Salle %d" % index
		room.grid_layout = layout
		room.hero_spawn_zone = [Vector2i(0, 0)]
		room.enemy_spawn_zone = [Vector2i(7, 7)]
		room.minimum_wave_count = 1
		room.maximum_wave_count = 2
		room.encounter_definition = encounters[0]
		for encounter in encounters:
			var wave := RoomWaveData.new()
			wave.wave_name = "Vague %d" % room.waves.size()
			wave.encounter_definition = encounter
			room.waves.append(wave)
		var path := root.path_join("room_%d.tres" % index)
		assert_eq(ResourceSaver.save(room, path), OK)
		assert_true(_assign_serialized_test_uid(path), path)
		paths.append(path)
		run.rooms.append(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP))
	var run_path := root.path_join("run.tres")
	assert_eq(ResourceSaver.save(run, run_path), OK)
	assert_true(_assign_serialized_test_uid(run_path), run_path)
	paths.append(run_path)
	run = ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	return {"root": root, "run": run, "path": run_path, "paths": paths}


func _session(fixture: Dictionary) -> EncounterEditSession:
	var session := EncounterEditSession.new()
	session.recovery_root = TEST_RECOVERY_ROOT
	assert_true(session.open(fixture.run, fixture.path))
	return session


func _hashes(paths: Array) -> Dictionary:
	var result := {}
	for path in paths:
		result[path] = FileAccess.get_sha256(path)
	return result


func _ui(fixture: Dictionary) -> EncounterStudioMain:
	var context := StudioProjectContext.new()
	assert_true(context.request_run(fixture.run).ok)
	var ui := EncounterStudioMain.new()
	ui.setup(null, null, context)
	ui.session.recovery_root = TEST_RECOVERY_ROOT
	add_child_autofree(ui)
	await wait_process_frames(2)
	return ui


func test_content_fingerprint_undo_redo_and_preferences() -> void:
	var ui := await _ui(_fixture())
	var session := ui.session
	var opening := session.document_fingerprint()
	ui._set_property(session.current_encounter(), &"living_enemy_cap", 3, "Modifier")
	assert_true(session.is_dirty())
	assert_true(ui.history_undo())
	assert_eq(session.document_fingerprint(), opening)
	assert_false(session.is_dirty(), "La liste dirty ne décide plus de la propreté")
	assert_true(ui.history_redo())
	assert_true(session.is_dirty())
	session.confirm_draft_saved()
	assert_false(session.is_dirty())
	assert_true(ui.history_undo())
	assert_true(session.is_dirty())
	assert_true(ui.history_redo())
	assert_false(session.is_dirty())
	ui.seed_spin.value += 42
	ui.properties_tabs.current_tab = 1
	ui.set_guided(false)
	session.select(1, 1)
	assert_false(session.is_dirty())
	await wait_process_frames(2)


func test_prepare_for_close_writes_recovery_for_dirty_canonical_session() -> void:
	var ui := await _ui(_fixture())
	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 3, "Modifier")
	assert_true(ui.session.is_dirty())
	var result := ui.prepare_for_close()
	assert_true(result.ok, str(result))
	assert_true(str(result.get("path", "")).begins_with(
		TEST_RECOVERY_ROOT
	))
	assert_false(ui.session.is_dirty())
	assert_false(ui.project_context.is_dirty(&"encounter"))


func test_legacy_room_migration_is_one_undoable_action() -> void:
	var ui := await _ui(_fixture())
	var room := ui.session.current_room()
	room.waves.clear()
	room.minimum_wave_count = 0
	room.maximum_wave_count = 0
	ui.session.confirm_draft_saved()
	var history_before := ui.history_current_index()
	ui._migrate_current_room()
	await wait_process_frames(2)
	assert_eq(room.waves.size(), 1)
	assert_eq(room.minimum_wave_count, 1)
	assert_eq(room.maximum_wave_count, 1)
	assert_eq(ui.history_current_index(), history_before + 1)
	assert_true(ui.history_undo())
	await wait_process_frames(2)
	assert_true(room.waves.is_empty())
	assert_eq(room.minimum_wave_count, 0)
	assert_eq(room.maximum_wave_count, 0)
	assert_true(ui.history_redo())
	await wait_process_frames(2)
	assert_eq(room.waves.size(), 1)
	assert_eq(room.minimum_wave_count, 1)
	assert_eq(room.maximum_wave_count, 1)


func test_fingerprint_tracks_sharing_wave_order_new_paths_and_unmarked_changes() -> void:
	var session := _session(_fixture())
	var baseline := session.document_fingerprint()
	var other := _session({"run": session.source_run, "path": session.source_run_path})
	assert_eq(other.document_fingerprint(), baseline)
	var shared := session.current_encounter()
	session.current_wave().encounter_definition = EncounterCopyService.copy_encounter(shared)
	assert_true(session.is_dirty(), "Même contenu mais nouveau lien indépendant")
	session.current_wave().encounter_definition = shared
	assert_false(session.is_dirty())
	session.current_room().waves.reverse()
	assert_true(session.is_dirty())
	session.current_room().waves.reverse()
	assert_false(session.is_dirty())
	session.new_resource_paths[shared] = ROOT.path_join("new.tres")
	assert_true(session.is_dirty())
	session.new_resource_paths.clear()
	session.working_run.run_name += " modifiée sans callback"
	assert_true(session.is_dirty())
	assert_true(EncounterSaveService.build_plan(session).paths.has(session.source_run_path))


func test_open_and_room_transitions_all_four_decisions() -> void:
	for change_run in [false, true]:
		for decision in [&"SAVE", &"DRAFT", &"DISCARD", &"CANCEL"]:
			var fixture := _fixture()
			var ui := await _ui(fixture)
			var destination := _fixture() if change_run else fixture
			var original := ui.session.working_run
			ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 3, "Modifier")
			var fingerprint := ui.session.document_fingerprint()
			var history_index := ui.history_current_index()
			var before := _hashes(fixture.paths)
			assert_false(ui.open_run(destination.path) if change_run else ui._request_room(1))
			assert_same(ui.session.working_run, original)
			assert_eq(ui.project_context.active_room_index, 0)
			var result := ui.project_context.resolve_pending_transition(decision)
			assert_true(result.ok, str(result))
			if decision == &"CANCEL":
				assert_same(ui.session.working_run, original)
				assert_eq(ui.session.document_fingerprint(), fingerprint)
				assert_eq(ui.history_current_index(), history_index)
				assert_eq(ui.session.selected_room_index, 0)
			else:
				assert_eq(ui.session.source_run_path, destination.path)
				assert_eq(ui.session.selected_room_index, 0 if change_run else 1)
				assert_eq(ui.project_context.active_run.resource_path, destination.path)
				assert_eq(ui.project_context.active_room_index, ui.session.selected_room_index)
				assert_false(ui.session.is_dirty())
			if decision != &"SAVE":
				assert_eq(_hashes(fixture.paths), before)
			await wait_process_frames(2)
			ui.free()


func test_context_bar_and_queued_navigation_do_not_bypass_decision() -> void:
	var fixture := _fixture()
	var ui := await _ui(fixture)
	ui.session.current_encounter().living_enemy_cap = 4 # Aucun callback UI.
	assert_false(ui.project_context.request_room(1).ok)
	assert_eq(ui.session.selected_room_index, 0)
	assert_true(ui.project_context.resolve_pending_transition(&"DRAFT").ok)
	assert_eq(ui.session.selected_room_index, 1)
	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 5, "Modifier")
	var seed_before := ui.seed_spin.value
	ui.apply_state_snapshot({"run_path": fixture.path, "room_index": 0, "seed": 98})
	assert_eq(ui.session.selected_room_index, 1)
	assert_eq(ui.seed_spin.value, seed_before)
	assert_true(ui.project_context.resolve_pending_transition(&"CANCEL").ok)
	assert_eq(ui.session.selected_room_index, 1)
	assert_eq(ui.seed_spin.value, seed_before)
	await wait_process_frames(2)


func test_missing_and_failed_handlers_keep_current_document() -> void:
	var ui := await _ui(_fixture())
	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 4, "Modifier")
	var fingerprint := ui.session.document_fingerprint()
	assert_false(ui._request_room(1))
	ui.project_context.unregister_transition_handler(&"encounter")
	assert_false(ui.project_context.resolve_pending_transition(&"DRAFT").ok)
	assert_eq(ui.session.document_fingerprint(), fingerprint)
	ui.project_context.register_transition_handler(&"encounter",
		func(): return {"ok": false}, func(): return {"ok": false}, func(): return {"ok": false})
	for decision in [&"SAVE", &"DRAFT", &"DISCARD"]:
		assert_false(ui.project_context.resolve_pending_transition(decision).ok)
		assert_eq(ui.session.selected_room_index, 0)
		assert_eq(ui.session.document_fingerprint(), fingerprint)
	assert_true(ui.project_context.resolve_pending_transition(&"CANCEL").ok)
	await wait_process_frames(2)


func test_context_rollback_preserves_external_write_and_durable_original() -> void:
	var path := ROOT.path_join("context_owned.txt")
	assert_true(_write_text(path, "original"))
	var handlers := {
		&"alpha": _context_handlers(func():
			assert_true(_write_text(path, "studio"))
			return {"ok": true}
	),
		&"zeta": _context_handlers(func():
			assert_true(_write_text(path, "external"))
			return {"ok": false, "error": "injected"}
	),
	}
	var result := StudioContextTransitionTransactionService.execute(
		StudioProjectContext.ACTION_SAVE,
		{&"alpha": {"path": path}, &"zeta": {}},
		handlers,
		{"transaction_root": TEST_CONTEXT_TRANSACTION_ROOT}
	)
	assert_false(result.ok, str(result))
	assert_eq(result.status, &"ROLLBACK_CONFLICT", str(result))
	assert_true(result.rollback_conflict, str(result))
	assert_true(result.transaction_retained, str(result))
	assert_eq(FileAccess.get_file_as_string(path), "external")
	var backups := result.transaction.get("backups", []) as Array
	assert_eq(backups.size(), 1, str(result))
	if backups.size() == 1:
		var backup_path := str((backups[0] as Dictionary).get("backup_path", ""))
		assert_true(FileAccess.file_exists(backup_path), str(result))
		assert_eq(FileAccess.get_file_as_string(backup_path), "original")
	assert_true(FileAccess.file_exists(str(result.transaction.manifest_path)))


func test_context_rollback_removes_unchanged_studio_created_target() -> void:
	var path := ROOT.path_join("context_created.txt")
	var handlers := {
		&"alpha": _context_handlers(func():
			assert_true(_write_text(path, "studio"))
			return {"ok": true}
	),
		&"zeta": _context_handlers(func():
			return {"ok": false, "error": "injected"}
	),
	}
	var result := StudioContextTransitionTransactionService.execute(
		StudioProjectContext.ACTION_SAVE,
		{&"alpha": {"path": path}, &"zeta": {}},
		handlers,
		{"transaction_root": TEST_CONTEXT_TRANSACTION_ROOT}
	)
	assert_false(result.ok, str(result))
	assert_eq(result.status, &"TRANSACTION_FAILED", str(result))
	assert_true(result.rollback.ok, str(result))
	assert_false(FileAccess.file_exists(path))
	assert_false(result.transaction_retained)
	assert_false(FileAccess.file_exists(str(result.transaction.manifest_path)))


func test_failed_context_handler_restores_only_its_explicit_owned_state() -> void:
	var path := ROOT.path_join("context_partial_owned.txt")
	assert_true(_write_text(path, "original"))
	var handlers := {
		&"alpha": _context_handlers(func():
			assert_true(_write_text(path, "studio-partial"))
			return {
				"ok": false,
				"error": "injected_partial_failure",
				"owned_file_states": {
					path: {
						"exists": true,
						"sha256": FileAccess.get_sha256(path),
					},
				},
			}
	),
	}
	var result := StudioContextTransitionTransactionService.execute(
		StudioProjectContext.ACTION_SAVE,
		{&"alpha": {"path": path}},
		handlers,
		{"transaction_root": TEST_CONTEXT_TRANSACTION_ROOT}
	)
	assert_false(result.ok, str(result))
	assert_eq(result.status, &"TRANSACTION_FAILED", str(result))
	assert_true(result.rollback.ok, str(result))
	assert_eq(FileAccess.get_file_as_string(path), "original")


func test_failed_context_handler_without_contract_preserves_its_write() -> void:
	var path := ROOT.path_join("context_partial_unclaimed.txt")
	assert_true(_write_text(path, "original"))
	var handlers := {
		&"alpha": _context_handlers(func():
			assert_true(_write_text(path, "unclaimed-partial"))
			return {"ok": false, "error": "injected_partial_failure"}
	),
	}
	var result := StudioContextTransitionTransactionService.execute(
		StudioProjectContext.ACTION_SAVE,
		{&"alpha": {"path": path}},
		handlers,
		{"transaction_root": TEST_CONTEXT_TRANSACTION_ROOT}
	)
	assert_false(result.ok, str(result))
	assert_eq(result.status, &"ROLLBACK_CONFLICT", str(result))
	assert_eq(FileAccess.get_file_as_string(path), "unclaimed-partial")
	assert_true(result.transaction_retained, str(result))


func test_canonical_draft_is_verified_and_recoverable_with_new_wave() -> void:
	var session := _session(_fixture())
	session.add_wave()
	var fingerprint := session.document_fingerprint()
	var result := EncounterSaveService.save_draft(session)
	assert_true(result.ok, str(result))
	assert_false(session.is_dirty())
	var restored := EncounterEditSession.new()
	restored.recovery_root = TEST_RECOVERY_ROOT
	var recovery := EncounterSaveService.restore_latest(restored)
	assert_true(recovery.ok, str(recovery))
	assert_eq(restored.document_fingerprint(), fingerprint)
	assert_eq(restored.working_run.rooms[0].waves.size(), 3)


func test_room_draft_success_failure_sharing_and_context_exclusion() -> void:
	var fixture := _fixture()
	var ui := await _ui(fixture)
	var draft := ArenaDefinition.new()
	draft.arena_id = StringName("document_%d" % Time.get_ticks_usec())
	_track_room_draft(draft)
	RoomDraftAuthority.isolate_gameplay_into(draft, fixture.run.rooms[0])
	assert_true(ui.open_room_draft(draft, fixture.run))
	ui.session.current_encounter().living_enemy_cap = 3
	assert_true(ui.session.is_dirty())
	var original := ui.session.document_fingerprint()
	assert_true(ui.refresh_draft_context(_fixture().run))
	assert_eq(ui.session.document_fingerprint(), original)
	var before := _hashes(fixture.paths)
	var result := ui.save_room_draft()
	assert_true(result.ok, str(result))
	assert_false(ui.session.is_dirty())
	var restored := RoomDraftSaveService.load_draft(str(draft.arena_id))
	assert_true(restored.ok, str(restored))
	assert_same(restored.room.encounter_definition, restored.room.waves[0].encounter_definition)
	assert_eq(_hashes(fixture.paths), before)
	ui.session.current_encounter().living_enemy_cap = 4
	# Une cible occupée par un dossier force un vrai échec d'écriture.
	draft.arena_id = StringName("blocked_%d" % Time.get_ticks_usec())
	_track_room_draft(draft)
	var blocked_path := RoomDraftSaveService.draft_path(str(draft.arena_id))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_path))
	assert_false(ui._request_room(1) if not ui.session.room_draft_mode else ui.open_run(_fixture().path))
	assert_false(ui.project_context.resolve_pending_transition(&"DRAFT").ok)
	assert_same(ui.session.draft_room, draft)
	assert_true(ui.session.is_dirty())
	assert_true(ui.project_context.resolve_pending_transition(&"CANCEL").ok)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_path))
	await wait_process_frames(2)


func test_rollback_basename_collision_restores_both_existing_files() -> void:
	var fixture := _fixture()
	var session := _session(fixture)
	session.current_room().waves[0].encounter_definition.living_enemy_cap = 3
	session.current_room().waves[1].encounter_definition.living_enemy_cap = 4
	var before := _hashes(fixture.paths)
	var fingerprint := session.document_fingerprint()
	var result := EncounterSaveService.save(session, {"fail_after_write": 2})
	assert_false(result.ok)
	assert_eq(result.error, "injected_write_failure", str(result))
	assert_true(result.get("rollback", {}).get("ok", false), str(result))
	assert_eq(_hashes(fixture.paths), before)
	assert_eq(session.document_fingerprint(), fingerprint)
	assert_true(session.is_dirty())
	var entries: Array = result.get("rollback", {}).get("entries", [])
	assert_eq(entries.size(), 2)
	if entries.size() == 2:
		assert_ne(entries[0].backup, entries[1].backup)


func test_rollback_removes_only_created_files_and_keeps_dirty_working_copy() -> void:
	for fail_after in [1, 2, 3]:
		var fixture := _fixture()
		var session := _session(fixture)
		var encounter := session.duplicate_current_encounter()
		var new_path: String = fixture.root.path_join("created.tres")
		session.new_resource_paths[encounter] = new_path
		session.current_room().waves[1].encounter_definition.living_enemy_cap = 4
		var before := _hashes(fixture.paths)
		var fingerprint := session.document_fingerprint()
		var result := EncounterSaveService.save(session, {"fail_after_write": fail_after})
		assert_false(result.ok)
		assert_eq(result.error, "injected_write_failure", str(result))
		assert_true(result.get("rollback", {}).get("ok", false), str(result))
		assert_eq(_hashes(fixture.paths), before)
		assert_false(FileAccess.file_exists(new_path))
		assert_eq(session.document_fingerprint(), fingerprint)
		assert_true(session.is_dirty())


func test_rollback_preserves_third_party_file_and_keeps_durable_backup() -> void:
	var fixture := _fixture()
	var session := _session(fixture)
	session.current_room().waves[0].encounter_definition.living_enemy_cap = 3
	session.current_room().waves[1].encounter_definition.living_enemy_cap = 4
	var original_hashes := _hashes(fixture.paths)
	var external_bytes := "écriture tierce déterministe".to_utf8_buffer()
	var hook_state := {}
	var hook := func(written_path: String, write_index: int, _record: Dictionary) -> Dictionary:
		if write_index != 1:
			return {"ok": true}
		var file := FileAccess.open(written_path, FileAccess.WRITE)
		if file == null:
			return {"ok": false}
		file.store_buffer(external_bytes)
		file.flush()
		file.close()
		hook_state["path"] = written_path
		hook_state["sha256"] = FileAccess.get_sha256(written_path)
		return {"ok": true}
	var result := EncounterSaveService.save(session, {
		"after_write_hook": hook,
		"fail_after_write": 2,
	})
	assert_false(result.ok, str(result))
	assert_eq(result.error, "injected_write_failure", str(result))
	assert_eq(result.status, &"ROLLBACK_CONFLICT", str(result))
	assert_true(result.rollback_conflict, str(result))
	assert_true(result.rollback.skipped_external_change, str(result))
	assert_true(FileAccess.file_exists(str(result.rollback_report)), str(result))
	var external_path := str(hook_state.get("path", ""))
	assert_false(external_path.is_empty(), str(result))
	assert_eq(FileAccess.get_sha256(external_path), hook_state.get("sha256", ""))
	assert_eq(FileAccess.get_file_as_bytes(external_path), external_bytes)
	var conflict_entries: Array = (result.rollback.entries as Array).filter(
		func(entry): return bool(entry.get("conflict", false))
	)
	assert_eq(conflict_entries.size(), 1, str(result.rollback))
	if conflict_entries.size() == 1:
		var entry := conflict_entries[0] as Dictionary
		assert_true(FileAccess.file_exists(str(entry.backup)), str(entry))
		assert_eq(FileAccess.get_sha256(str(entry.backup)), original_hashes[external_path])
	# L'autre fichier, encore possédé par le Studio, a bien été restauré.
	for path in fixture.paths:
		if path != external_path:
			assert_eq(FileAccess.get_sha256(path), original_hashes[path], path)


func test_publish_stages_under_recovery_and_preserves_canonical_uids() -> void:
	var fixture := _fixture()
	var session := _session(fixture)
	session.current_room().waves[0].encounter_definition.living_enemy_cap = 3
	session.current_room().waves[1].encounter_definition.living_enemy_cap = 4
	var plan := EncounterSaveService.build_plan(session)
	assert_true(plan.ok, str(plan))
	var opening_hashes := _hashes(fixture.paths)
	var opening_states := {}
	for entry in plan.entries:
		opening_states[entry.path] = EncounterSaveService._file_fingerprint(entry.path)
	var stage_state := {"paths": []}
	var stage_hook := func(
			stage_path: String, target_path: String, _index: int, _record: Dictionary
		) -> Dictionary:
		(stage_state.paths as Array).append(stage_path)
		assert_true(stage_path.begins_with(TEST_RECOVERY_ROOT + "/"), stage_path)
		assert_ne(stage_path, target_path)
		assert_true(FileAccess.file_exists(stage_path), stage_path)
		# Tous les stages sont produits avant le premier commit canonique.
		assert_eq(_hashes(fixture.paths), opening_hashes)
		return {"ok": true}
	var result := EncounterSaveService.save(session, {"after_stage_hook": stage_hook})
	assert_true(result.ok, str(result))
	assert_eq((stage_state.paths as Array).size(), plan.entries.size())
	for entry in plan.entries:
		var before := opening_states[entry.path] as Dictionary
		var after := EncounterSaveService._file_fingerprint(entry.path)
		assert_eq(after.uid, before.uid, str(entry.path))
		assert_false(str(after.uid).is_empty(), "La fixture doit exercer un UID réel")
	assert_true(_encounter_sidecars(fixture.root).is_empty(), str(result))


func test_commit_conflict_before_quarantine_never_overwrites_external_bytes() -> void:
	var fixture := _fixture()
	var session := _session(fixture)
	session.current_encounter().living_enemy_cap = 4
	var target := str(EncounterSaveService.build_plan(session).entries[0].path)
	var before := _hashes(fixture.paths)
	var external_bytes := "concurrent avant quarantaine".to_utf8_buffer()
	var hook := func(path: String, index: int, phase: StringName, _record: Dictionary) -> Dictionary:
		if index == 1 and phase == &"BEFORE_QUARANTINE":
			var file := FileAccess.open(path, FileAccess.WRITE)
			assert_not_null(file)
			if file != null:
				file.store_buffer(external_bytes)
				file.flush()
				file.close()
		return {"ok": true}
	var result := EncounterSaveService.save(session, {"before_commit_hook": hook})
	assert_false(result.ok, str(result))
	assert_eq(result.error, "external_conflict_before_commit", str(result))
	assert_eq(result.status, &"ROLLBACK_CONFLICT", str(result))
	assert_eq(FileAccess.get_file_as_bytes(target), external_bytes)
	for path in fixture.paths:
		if path != target:
			assert_eq(FileAccess.get_sha256(path), before[path], path)
	assert_true(FileAccess.file_exists(str(result.rollback_report)), str(result))
	assert_true(_encounter_sidecars(fixture.root).is_empty(), str(result.cleanup))


func test_commit_conflict_after_quarantine_preserves_external_and_original() -> void:
	var fixture := _fixture()
	var session := _session(fixture)
	session.current_encounter().living_enemy_cap = 4
	var target := str(EncounterSaveService.build_plan(session).entries[0].path)
	var initial := EncounterSaveService._file_fingerprint(target)
	var external_bytes := "concurrent après quarantaine".to_utf8_buffer()
	var hook := func(path: String, index: int, phase: StringName, _record: Dictionary) -> Dictionary:
		if index == 1 and phase == &"AFTER_QUARANTINE":
			var file := FileAccess.open(path, FileAccess.WRITE)
			assert_not_null(file)
			if file != null:
				file.store_buffer(external_bytes)
				file.flush()
				file.close()
		return {"ok": true}
	var result := EncounterSaveService.save(session, {"before_commit_hook": hook})
	assert_false(result.ok, str(result))
	assert_eq(result.error, "external_conflict_after_quarantine", str(result))
	assert_eq(result.status, &"ROLLBACK_CONFLICT", str(result))
	assert_eq(FileAccess.get_file_as_bytes(target), external_bytes)
	var entry := result.rollback.entries[0] as Dictionary
	assert_true(FileAccess.file_exists(str(entry.backup)), str(entry))
	assert_eq(EncounterSaveService._file_fingerprint(str(entry.backup)), initial)
	assert_true(FileAccess.file_exists(str(entry.quarantine)), str(entry))
	assert_eq(EncounterSaveService._file_fingerprint(str(entry.quarantine)), initial)
	# Le stage voisin est possédé et nettoyé ; l'original en quarantaine reste
	# volontairement durable tant qu'une cible tierce occupe le chemin canonique.
	var sidecars := _encounter_sidecars(fixture.root)
	assert_eq(sidecars, PackedStringArray([str(entry.quarantine)]), str(sidecars))


func test_new_target_created_during_commit_is_never_overwritten() -> void:
	var fixture := _fixture()
	var session := _session(fixture)
	var encounter := session.duplicate_current_encounter()
	var target: String = fixture.root.path_join("concurrent_new.tres")
	session.new_resource_paths[encounter] = target
	encounter.living_enemy_cap = 4
	var external_bytes := "nouvelle cible tierce".to_utf8_buffer()
	var hook := func(path: String, _index: int, phase: StringName, _record: Dictionary) -> Dictionary:
		# Injection après le dernier test d'absence, au bord du renommage no-clobber.
		if path == target and phase == &"BEFORE_STAGE_RENAME":
			var file := FileAccess.open(path, FileAccess.WRITE)
			assert_not_null(file)
			if file != null:
				file.store_buffer(external_bytes)
				file.flush()
				file.close()
		return {"ok": true}
	var result := EncounterSaveService.save(session, {"before_commit_hook": hook})
	assert_false(result.ok, str(result))
	assert_eq(result.error, "external_conflict_during_commit", str(result))
	assert_eq(result.status, &"ROLLBACK_CONFLICT", str(result))
	assert_eq(FileAccess.get_file_as_bytes(target), external_bytes)


func test_stage_hook_failure_leaves_catalog_byte_for_byte_unchanged() -> void:
	var fixture := _fixture()
	var session := _session(fixture)
	session.current_encounter().living_enemy_cap = 5
	var before := _hashes(fixture.paths)
	var hook_state := {}
	var hook := func(path: String, _target: String, _index: int, _record: Dictionary) -> Dictionary:
		hook_state["stage_path"] = path
		return {"ok": false}
	var result := EncounterSaveService.save(session, {"after_stage_hook": hook})
	assert_false(result.ok, str(result))
	assert_eq(result.error, "injected_stage_hook_failure", str(result))
	var stage_path := str(hook_state.get("stage_path", ""))
	assert_true(stage_path.begins_with(TEST_RECOVERY_ROOT + "/"), stage_path)
	assert_eq(_hashes(fixture.paths), before)
	assert_true(_encounter_sidecars(fixture.root).is_empty())


func test_success_requires_external_references_and_clean_reopen() -> void:
	var fixture := _fixture()
	var session := _session(fixture)
	session.current_encounter().living_enemy_cap = 4
	var before := _hashes(fixture.paths)
	var failed := EncounterSaveService.save(session, {"fail_reopen": true})
	assert_false(failed.ok)
	assert_eq(failed.error, "working_copy_reopen_failed", str(failed))
	assert_true(failed.get("rollback", {}).get("ok", false))
	assert_eq(_hashes(fixture.paths), before)
	assert_true(session.is_dirty())
	# Le rollback peut changer le mtime ; recharger les sources avant une
	# nouvelle transaction tout en reprenant la modification explicitement.
	session = _session(fixture)
	session.current_encounter().living_enemy_cap = 4
	var result := EncounterSaveService.save(session)
	assert_true(result.ok, str(result))
	assert_false(session.is_dirty())
	assert_eq(session.current_encounter().living_enemy_cap, 4)
	var run := ResourceLoader.load(fixture.path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RunData
	assert_eq(run.rooms[0].resource_path, fixture.paths[2])
	assert_eq(run.rooms[0].waves[0].encounter_definition.resource_path, fixture.paths[0])


func test_unsafe_paths_and_new_file_collision_are_blocked_before_write() -> void:
	var fixture := _fixture()
	var session := _session(fixture)
	var encounter := session.duplicate_current_encounter()
	var before := _hashes(fixture.paths)
	for path in ["C:/absolute.tres", "res://../escape.tres", "user://bad.exe", fixture.paths[1]]:
		session.new_resource_paths[encounter] = path
		assert_false(EncounterSaveService.save(session).ok)
		assert_eq(_hashes(fixture.paths), before)


func test_room_draft_decisions_complete_the_requested_opening() -> void:
	for decision in [&"SAVE", &"DRAFT"]:
		var fixture := _fixture()
		var ui := await _ui(fixture)
		var draft := ArenaDefinition.new()
		draft.arena_id = StringName("transition_%d" % Time.get_ticks_usec())
		_track_room_draft(draft)
		RoomDraftAuthority.isolate_gameplay_into(draft, fixture.run.rooms[0])
		assert_true(ui.open_room_draft(draft, fixture.run))
		ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 3, "Modifier")
		var before := _hashes(fixture.paths)
		assert_false(ui.open_run(fixture.path))
		var result := ui.project_context.resolve_pending_transition(decision)
		assert_true(result.ok, str(result))
		assert_false(ui.session.room_draft_mode)
		assert_false(ui.session.is_dirty())
		assert_eq(ui.session.source_run_path, fixture.path)
		assert_eq(ui.project_context.active_run.resource_path, fixture.path)
		assert_true(RoomDraftSaveService.load_draft(str(draft.arena_id)).ok)
		assert_eq(_hashes(fixture.paths), before)
		await wait_process_frames(2)
		ui.free()


func test_tree_cancel_and_navigation_success_keep_visible_selection_consistent() -> void:
	var fixture := _fixture()
	var ui := await _ui(fixture)
	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 3, "Modifier")
	var target := ui.run_tree.get_root().get_first_child().get_next()
	target.select(0)
	ui._on_tree_selected()
	await wait_process_frames(2)
	assert_true(ui.project_context.has_pending_transition())
	assert_eq(int(ui.run_tree.get_selected().get_metadata(0)), 0)
	var index := ui.history_current_index()
	assert_true(ui.project_context.resolve_pending_transition(&"CANCEL").ok)
	assert_eq(int(ui.run_tree.get_selected().get_metadata(0)), 0)
	assert_eq(ui.history_current_index(), index)
	ui.apply_state_snapshot({"run_path": fixture.path, "room_index": 1, "wave_index": 1, "seed": 98})
	assert_true(ui.project_context.resolve_pending_transition(&"DRAFT").ok)
	assert_eq(ui.session.selected_room_index, 1)
	assert_eq(ui.session.selected_wave_index, 1)
	assert_eq(ui.seed_spin.value, 98.0)
	assert_eq(ui.project_context.active_room_index, 1)
	assert_eq(int(ui.run_tree.get_selected().get_metadata(0)), 1)
	await wait_process_frames(2)


func test_other_domain_failure_restores_encounter_and_history() -> void:
	var fixture := _fixture()
	var ui := await _ui(fixture)
	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 3, "Modifier")
	var before := ui.session.document_fingerprint()
	var history_index := ui.history_current_index()
	var original := ui.session.current_encounter()
	ui.project_context.register_transition_handler(&"z_failure",
		func(): return {"ok": false}, func(): return {"ok": false}, func(): return {"ok": false})
	ui.project_context.set_dirty(&"z_failure", true)
	var disk_before := _hashes(fixture.paths)
	for decision in [&"DRAFT", &"SAVE", &"DISCARD"]:
		assert_false(ui._request_room(1))
		assert_false(ui.project_context.resolve_pending_transition(decision).ok)
		assert_true(ui.session.is_dirty())
		assert_eq(ui.session.document_fingerprint(), before)
		assert_same(ui.session.current_encounter(), original)
		assert_eq(ui.history_current_index(), history_index)
		assert_eq(ui.session.selected_room_index, 0)
		assert_eq(_hashes(fixture.paths), disk_before)
		assert_true(ui.project_context.resolve_pending_transition(&"CANCEL").ok)
	await wait_process_frames(2)


func test_rollback_failure_is_reported_without_deleting_preexisting_target() -> void:
	var fixture := _fixture()
	var path: String = fixture.paths[0]
	var original := EncounterSaveService._file_fingerprint(path)
	var studio := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EncounterDefinition
	studio.living_enemy_cap = 5
	assert_eq(ResourceSaver.save(studio, path), OK)
	var owned := EncounterSaveService._file_fingerprint(path)
	assert_ne(owned, original)
	var touched: Array[Dictionary] = [{"path": path, "initial": original,
		"owned": owned, "backup": fixture.root.path_join("missing_backup.tres")}]
	var result := EncounterSaveService._restore_backups(touched)
	assert_false(result.ok)
	assert_false(result.conflict)
	assert_eq(result.status, &"ROLLBACK_FAILED")
	assert_true(FileAccess.file_exists(path))
	assert_eq(EncounterSaveService._file_fingerprint(path), owned)
	assert_ne(result.entries[0].code, OK)


func test_action_labels_dispatch_and_layout_at_both_resolutions() -> void:
	var fixture := _fixture()
	var context := StudioProjectContext.new()
	assert_true(context.request_run(fixture.run).ok)
	var workspace := StudioWorkspace.new()
	workspace.arena_auto_load_enabled = false
	workspace.arena_production_planning_enabled = false
	workspace.setup(null, null, context, StudioReferenceGraphService.new())
	add_child_autofree(workspace)
	await wait_process_frames(3)
	workspace.tabs.current_tab = 1
	workspace.encounter_studio._set_property(
		workspace.encounter_studio.session.current_encounter(), &"living_enemy_cap", 3, "Modifier")
	workspace._refresh_history_controls()
	assert_eq(workspace.save_button.text, "Publier les rencontres")
	assert_false(workspace.save_button.tooltip_text.contains("Aucune partie"))
	workspace._global_save()
	assert_true(workspace.encounter_studio.save_dialog.visible)
	assert_eq(workspace.encounter_studio.save_dialog.ok_button_text, "Publier les rencontres")
	workspace.encounter_studio.save_dialog.hide()
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = resolution
		workspace.size = resolution
		workspace._apply_toolbar_responsive()
		await wait_process_frames(3)
		for button in [workspace.save_button, workspace.undo_button, workspace.redo_button,
				workspace.validate_button, workspace.test_button, workspace.history_button]:
			assert_true(button.is_visible_in_tree())
			assert_true(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(button.get_global_rect()), button.text)
		var local_buttons := workspace.encounter_studio.find_children("*", "Button", true, false)
		for button in local_buttons:
			if button.is_visible_in_tree():
				assert_false(button.text in ["Sauvegarder", "Annuler", "Rétablir", "Valider", "▶ Tester"])
		await _capture(workspace, "canonical", resolution)
	assert_true(workspace.encounter_studio.session.discard())
	workspace.encounter_studio._refresh_all()
	var draft := ArenaDefinition.new()
	draft.arena_id = StringName("labels_%d" % Time.get_ticks_usec())
	_track_room_draft(draft)
	RoomDraftAuthority.isolate_gameplay_into(draft, fixture.run.rooms[0])
	workspace.arena_studio._set_arena(draft, false, "document_labels")
	workspace.arena_studio.set_inspector_drawer_open(false)
	draft = workspace.arena_studio.room_draft()
	assert_true(workspace.encounter_studio.open_room_draft(draft, fixture.run))
	workspace._refresh_history_controls()
	assert_eq(workspace.save_button.text, "Enregistrer le brouillon")
	assert_eq(workspace.test_button.text, "Tester")
	assert_eq(workspace.produce_button.text, "Intégrer à la partie")
	assert_false(workspace.produce_button.disabled)
	var before := _hashes(fixture.paths)
	workspace._global_save()
	assert_true(RoomDraftSaveService.has_draft(str(draft.arena_id)))
	assert_eq(_hashes(fixture.paths), before)
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = resolution
		workspace.size = resolution
		workspace._apply_toolbar_responsive()
		await wait_process_frames(3)
		for button in [workspace.save_button, workspace.validate_button, workspace.test_button, workspace.produce_button]:
			assert_true(button.is_visible_in_tree())
			assert_true(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(button.get_global_rect()), button.text)
		await _capture(workspace, "room_draft", resolution)
	workspace.free()
	await wait_process_frames(3)


func _capture(_workspace: StudioWorkspace, label: String, resolution: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var gut_layer := get_tree().root.get_node_or_null("GutRunner/GutLayer") as CanvasLayer
	if gut_layer != null:
		gut_layer.hide()
	DisplayServer.warp_mouse(Vector2i(8, 8))
	assert_false(_workspace.project_context.has_pending_transition())
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var root := "res://artifacts/encounter_document_safety"
	assert_eq(image.save_png(root.path_join("%s_%dx%d.png" % [label, resolution.x, resolution.y])), OK)


func test_publish_after_confirmed_draft_and_new_external_file() -> void:
	var fixture := _fixture()
	var session := _session(fixture)
	var encounter := session.duplicate_current_encounter()
	var path: String = fixture.root.path_join("published_new.tres")
	session.new_resource_paths[encounter] = path
	encounter.living_enemy_cap = 4
	assert_true(EncounterSaveService.save_draft(session).ok)
	assert_false(session.is_dirty())
	assert_false(FileAccess.file_exists(path))
	var result := EncounterSaveService.save(session)
	assert_true(result.ok, str(result))
	assert_true(FileAccess.file_exists(path))
	assert_false(session.is_dirty())
	assert_eq(session.source_encounter().resource_path, path)


func test_room_draft_discard_restores_latest_confirmed_checkpoint() -> void:
	var ui := await _ui(_fixture())
	var draft := ArenaDefinition.new()
	draft.arena_id = StringName("checkpoint_%d" % Time.get_ticks_usec())
	_track_room_draft(draft)
	RoomDraftAuthority.isolate_gameplay_into(draft, ui.session.current_room())
	assert_true(ui.open_room_draft(draft, ui.project_context.active_run))
	ui.session.current_encounter().living_enemy_cap = 3
	assert_true(ui.save_room_draft().ok)
	ui.session.current_encounter().living_enemy_cap = 5
	assert_true(ui.session.discard())
	assert_eq(ui.session.current_encounter().living_enemy_cap, 3)
	assert_false(ui.session.is_dirty())


func test_recovery_preserves_sources_after_reordering_rooms_and_waves() -> void:
	var fixture := _fixture()
	var session := _session(fixture)
	session.working_run.rooms.reverse()
	session.current_room().waves.reverse()
	assert_true(EncounterSaveService.save_draft(session).ok)
	var restored := EncounterEditSession.new()
	restored.recovery_root = TEST_RECOVERY_ROOT
	assert_true(EncounterSaveService.restore_latest(restored).ok)
	assert_eq(restored.document_fingerprint(), session.document_fingerprint())
	assert_eq(restored.source_for(restored.current_room()).resource_path, fixture.paths[3])
	assert_eq(restored.source_encounter().resource_path, fixture.paths[1])
	var result := EncounterSaveService.save(restored)
	assert_true(result.ok, str(result))
	var run := ResourceLoader.load(fixture.path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RunData
	assert_eq(run.rooms[0].resource_path, fixture.paths[3])
	assert_eq(run.rooms[0].waves[0].encounter_definition.resource_path, fixture.paths[1])


func test_canonical_draft_failure_keeps_document_and_history() -> void:
	var ui := await _ui(_fixture())
	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 3, "Modifier")
	ui.session.new_resource_paths[ui.session.current_encounter()] = "res://../unsafe.tres"
	var fingerprint := ui.session.document_fingerprint()
	var history_index := ui.history_current_index()
	assert_false(ui._request_room(1))
	var result := ui.project_context.resolve_pending_transition(&"DRAFT")
	assert_false(result.ok)
	assert_eq(result.error, "unsafe_recovery_path")
	assert_eq(ui.session.document_fingerprint(), fingerprint)
	assert_eq(ui.history_current_index(), history_index)
	assert_eq(ui.session.selected_room_index, 0)
	assert_true(ui.session.is_dirty())
	assert_true(ui.project_context.resolve_pending_transition(&"CANCEL").ok)
	await wait_process_frames(2)


func _context_handlers(commit: Callable) -> Dictionary:
	return {
		"save": commit,
		"draft": commit,
		"discard": commit,
		"snapshot": func(): return {"value": "before"},
		"restore": func(_snapshot: Dictionary): return {"ok": true},
	}


func _write_text(path: String, content: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	) != OK:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	file.close()
	return true


func _assign_serialized_test_uid(path: String) -> bool:
	var uid := ResourceUID.create_id()
	if uid == ResourceUID.INVALID_ID or ResourceSaver.set_uid(path, uid) != OK:
		return false
	var contents := FileAccess.get_file_as_string(path)
	var line_end := contents.find("\n")
	if line_end < 0:
		return false
	var header := contents.substr(0, line_end)
	var marker := 'uid="'
	var marker_index := header.find(marker)
	var uid_text := ResourceUID.id_to_text(uid)
	if marker_index >= 0:
		var value_start := marker_index + marker.length()
		var value_end := header.find('"', value_start)
		if value_end <= value_start:
			return false
		header = header.substr(0, value_start) + uid_text + header.substr(value_end)
	else:
		var bracket_index := header.rfind("]")
		if bracket_index < 0:
			return false
		header = header.insert(bracket_index, ' uid="%s"' % uid_text)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(header + contents.substr(line_end))
	file.flush()
	file.close()
	return FileAccess.get_file_as_string(path).get_slice("\n", 0).contains(
		'uid="%s"' % uid_text
	)


func _track_room_draft(draft: ArenaDefinition) -> void:
	var path := RoomDraftSaveService.draft_path(str(draft.arena_id))
	if not _owned_room_draft_paths.has(path):
		_owned_room_draft_paths.append(path)


func _cleanup_owned_room_drafts() -> void:
	for path in _owned_room_draft_paths:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)
		elif DirAccess.dir_exists_absolute(absolute):
			# La seule fixture dossier est volontairement vide pour forcer l'échec.
			DirAccess.remove_absolute(absolute)


func _encounter_sidecars(path: String) -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open(path)
	if directory == null:
		return result
	for file_name in directory.get_files():
		if ".encounter_" in file_name:
			result.append(path.path_join(file_name))
	for child_name in directory.get_directories():
		result.append_array(_encounter_sidecars(path.path_join(child_name)))
	result.sort()
	return result


func _remove_tree(path: String) -> bool:
	if path != ROOT and not path.begins_with(ROOT + "/"):
		return false
	var directory := DirAccess.open(path)
	if directory == null:
		return not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))
	for file_name in directory.get_files():
		if DirAccess.remove_absolute(
			ProjectSettings.globalize_path(path.path_join(file_name))
		) != OK:
			return false
	for child_name in directory.get_directories():
		if not _remove_tree(path.path_join(child_name)):
			return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
