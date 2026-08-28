extends GutTest

## Régressions propres au chantier documentaire. Aucune écriture de gameplay
## sous res:// : toutes les fixtures sont possédées sous user://.
const ROOT := "user://dungeon_draft_studio/encounter_document_safety"
var _serial := 0


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
		paths.append(path)
		run.rooms.append(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP))
	var run_path := root.path_join("run.tres")
	assert_eq(ResourceSaver.save(run, run_path), OK)
	paths.append(run_path)
	run = ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	return {"root": root, "run": run, "path": run_path, "paths": paths}


func _session(fixture: Dictionary) -> EncounterEditSession:
	var session := EncounterEditSession.new()
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


func test_canonical_draft_is_verified_and_recoverable_with_new_wave() -> void:
	var session := _session(_fixture())
	session.add_wave()
	var fingerprint := session.document_fingerprint()
	var result := EncounterSaveService.save_draft(session)
	assert_true(result.ok, str(result))
	assert_false(session.is_dirty())
	var restored := EncounterEditSession.new()
	var recovery := EncounterSaveService.restore_latest(restored)
	assert_true(recovery.ok, str(recovery))
	assert_eq(restored.document_fingerprint(), fingerprint)
	assert_eq(restored.working_run.rooms[0].waves.size(), 3)


func test_room_draft_success_failure_sharing_and_context_exclusion() -> void:
	var fixture := _fixture()
	var ui := await _ui(fixture)
	var draft := ArenaDefinition.new()
	draft.arena_id = StringName("document_%d" % Time.get_ticks_usec())
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
	var touched: Array[Dictionary] = [{"path": path, "initial": original,
		"backup": fixture.root.path_join("missing_backup.tres")}]
	var result := EncounterSaveService._restore_backups(touched)
	assert_false(result.ok)
	assert_true(FileAccess.file_exists(path))
	assert_eq(EncounterSaveService._file_fingerprint(path), original)
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
