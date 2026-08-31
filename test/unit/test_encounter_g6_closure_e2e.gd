extends GutTest

const ROOT := "res://artifacts/encounter_g6_closure_e2e"
const RUN_ROOT := "res://data/runs/__g6_closure_e2e"


func _fixture() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RUN_ROOT))
	var arena := ArenaDefinition.new()
	arena.set_identity("Salle E2E G6", "salle_e2e_g6")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(8, 8)
	for y in arena.grid_size.y:
		for x in arena.grid_size.x:
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), &"stone")
	ArenaEditingService.prepare_automatically(arena)
	arena.encounter_definition = null
	arena.waves.clear()
	arena.minimum_wave_count = 0
	arena.maximum_wave_count = 1
	var room_path := ROOT.path_join("source_room.tres")
	assert_eq(ResourceSaver.save(arena, room_path), OK)
	var run := RunData.new()
	run.run_name = "Partie E2E G6"
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 1
	run.rooms = [ResourceLoader.load(room_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)]
	var run_path := RUN_ROOT.path_join("source_run.tres")
	assert_eq(ResourceSaver.save(run, run_path), OK)
	return {"run_path": run_path, "room_path": room_path}


func _button(root: Node, text: String) -> Button:
	for node in _descendants(root):
		if node is Button and node.text == text:
			return node
	return null


func _card(ui: EncounterStudioMain, code: StringName) -> EncounterDiagnosticCard:
	for candidate in ui.validation_cards_box.get_children():
		if candidate.message != null and candidate.message.code == code:
			return candidate
	return null


func _validation_codes(messages: Array) -> Array[String]:
	var codes: Array[String] = []
	for message in messages:
		if message != null and message.severity == StudioValidationMessage.Severity.ERROR:
			codes.append(str(message.code))
	return codes


func _runtime_proof(arena: ArenaDefinition) -> Dictionary:
	var fingerprint := ArenaSnapshotService.arena_fingerprint(arena)
	var topology: Dictionary = ArenaTopologySignatureService.build(arena)
	var topology_hash := str(topology.get("topology_hash", ""))
	var projection := ArenaRuntimeBridge.build_runtime_projection(arena)
	var scene_path := projection.battle_scene.resource_path \
		if projection != null and projection.battle_scene != null else ""
	var configuration := &"closure_e2e"
	return {
		"ok": true,
		"probe_pending": false,
		"runtime_scene_inspected": true,
		"produced_bundle_loaded": false,
		"configuration": str(configuration),
		"working_fingerprint": fingerprint,
		"temporary_fingerprint": fingerprint,
		"runtime_fingerprint": fingerprint,
		"fingerprints_identical": true,
		"working_topology_hash": topology_hash,
		"temporary_topology_hash": topology_hash,
		"runtime_topology_hash": topology_hash,
		"topology_hashes_identical": true,
		"expected_battle_scene_path": scene_path,
		"battle_scene_path": scene_path,
		"runtime_probe_key": ArenaDirectTestService.probe_key(
			fingerprint, topology_hash, scene_path, configuration
		),
		"script_parse_ok": true,
		"scene_instantiated": true,
		"runtime_ready": true,
		"grid_ready": true,
		"pathfinder_ready": true,
		"render_ready": true,
		"spawn_ready": true,
		"cleanup_ok": true,
	}


func _write_runtime_proof(arena: ArenaDefinition) -> void:
	var absolute := ProjectSettings.globalize_path(ArenaDirectTestService.LAST_RESULT_PATH)
	assert_eq(DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()), OK)
	var file := FileAccess.open(ArenaDirectTestService.LAST_RESULT_PATH, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(JSON.stringify(_runtime_proof(arena), "  "))
	file.close()


func test_single_ui_journey_from_terrain_draft_to_reloaded_integration() -> void:
	var fixture := _fixture()
	var canonical_data_hash := FileAccess.get_sha256("res://data/runs/first_run.tres")
	var run := ResourceLoader.load(fixture.run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RunData
	var context := StudioProjectContext.new()
	assert_true(context.request_selection({"run": run, "room_index": 0}).ok)
	var workspace := StudioWorkspace.new()
	workspace.arena_auto_load_enabled = false
	workspace.arena_production_planning_enabled = false
	workspace.setup(null, null, context, StudioReferenceGraphService.new())
	add_child_autofree(workspace)
	await wait_process_frames(4)

	var terrain := workspace.arena_studio
	assert_true(terrain._open_context_room(context.active_room()))
	terrain.show_editor()
	workspace.create_encounters_button.pressed.emit()
	await wait_process_frames(3)
	var ui := workspace.encounter_studio
	assert_true(ui.is_room_draft_mode())
	assert_same(ui.session.draft_room, terrain.arena)

	var add_encounter := _button(ui, "Ajouter un affrontement")
	assert_not_null(add_encounter)
	add_encounter.pressed.emit()
	await wait_process_frames(2)
	assert_not_null(ui.session.current_encounter())

	assert_false(ui.enemy_catalog.is_empty())
	var searched_name := ui.enemy_catalog[0].unit_name
	ui.catalog_search.text = searched_name.substr(0, mini(5, searched_name.length()))
	ui.catalog_search.text_changed.emit(ui.catalog_search.text)
	await wait_process_frames(2)
	assert_gt(ui.catalog_cards_box.get_child_count(), 0)
	var catalog_card := ui.catalog_cards_box.get_child(0) as EncounterEnemyCard
	catalog_card._add_button.pressed.emit()
	await wait_process_frames(2)
	assert_eq(ui.session.current_encounter().roster_units.size(), 1)

	var roster_card: EncounterEnemyCard = null
	for node in _descendants(ui.composition_box):
		if node is EncounterEnemyCard and node._quantity_spin.visible:
			roster_card = node
			break
	assert_not_null(roster_card)
	roster_card._quantity_spin.value = 2
	await wait_process_frames(2)
	assert_eq(int(ui.session.current_encounter().roster_counts[0]), 2)
	ui.generate_placement_button.pressed.emit()
	await wait_process_frames(2)
	assert_false(ui.preview_result.is_empty())

	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 0, "Diagnostic E2E")
	ui.validate_session()
	var diagnostic := _card(ui, &"living_cap_too_low")
	assert_not_null(diagnostic)
	var before_view := ui.session.document_fingerprint()
	diagnostic.view_button.pressed.emit()
	assert_eq(ui.session.document_fingerprint(), before_view, "Voir ne corrige rien")
	diagnostic.fix_button.pressed.emit()
	if ui.shared_dialog.visible:
		ui.shared_dialog.confirmed.emit()
	await wait_process_frames(3)
	var corrected_cap := ui.session.current_encounter().living_enemy_cap
	assert_gte(corrected_cap, 2)
	workspace.undo_button.pressed.emit()
	await wait_process_frames(2)
	assert_eq(ui.session.current_encounter().living_enemy_cap, 0)
	workspace.redo_button.pressed.emit()
	await wait_process_frames(2)
	assert_eq(ui.session.current_encounter().living_enemy_cap, corrected_cap)

	workspace.save_button.pressed.emit()
	await wait_process_frames(3)
	var saved := RoomDraftSaveService.load_draft(ui._room_draft_session_key())
	assert_true(bool(saved.get("ok", false)), str(saved))
	var test_validation := EncounterValidationService.validate_session(
		ui.session, int(ui.seed_spin.value)
	)
	assert_false(EncounterValidationService.has_errors(test_validation),
		"Validation avant test direct : %s" % [_validation_codes(test_validation)])
	if EncounterValidationService.has_errors(test_validation):
		return

	workspace.test_button.pressed.emit()
	await wait_process_frames(3)
	assert_eq(str(ui.last_test_result.get("error", "")), "editor_play_api_missing")
	var request := ui.last_test_result.get("request", {}) as Dictionary
	var runtime_run := ResourceLoader.load(str(request.get("run_path", "")), "",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RunData
	assert_not_null(runtime_run)
	if runtime_run != null:
		assert_eq(runtime_run.rooms[0].waves.size(), 1)

	workspace.produce_button.pressed.emit()
	await wait_process_frames(4)
	assert_true(terrain.production_dialog.visible)
	terrain.production_destination_edit.text = ROOT.path_join(
		"produced_%d" % Time.get_ticks_usec()
	)
	for index in terrain.production_run_option.item_count:
		if terrain.production_run_option.get_item_tooltip(index) == fixture.run_path:
			terrain.production_run_option.select(index)
			break
	for index in terrain.production_action_option.item_count:
		if StringName(terrain.production_action_option.get_item_metadata(index)) \
				== ArenaProductionAttachmentService.UPDATE:
			terrain.production_action_option.select(index)
			break
	terrain.production_index_spin.value = 0
	terrain.publish_draft_gameplay_check.button_pressed = true
	terrain._art_alignment_decision = 1
	var candidate := terrain._production_candidate()
	var target_run := terrain._selected_production_run()
	assert_not_null(target_run)
	assert_eq(target_run.resource_path, fixture.run_path)
	var proof_build := ArenaDirectTestService.build_candidate(
		candidate, target_run, ArenaProductionAttachmentService.UPDATE, 0
	)
	assert_true(bool(proof_build.get("ok", false)), str(proof_build))
	_write_runtime_proof(proof_build.get("candidate") as ArenaDefinition)
	terrain._refresh_production_wizard()
	assert_true(bool(terrain._production_last_plan.get("can_integrate", false)),
		str(terrain._production_last_plan.get("gate_report", {})))
	terrain.production_dialog.get_ok_button().pressed.emit()
	await wait_process_frames(5)
	if terrain.integration_warning_dialog.visible:
		terrain.integration_warning_justification.text = "Parcours E2E automatisé de clôture G6"
		terrain.integration_warning_dialog.get_ok_button().pressed.emit()
	if terrain.integration_replace_dialog.visible:
		terrain.integration_replace_dialog.get_ok_button().pressed.emit()
	for frame in 900:
		if not terrain._integration_running and frame > 5:
			break
		await get_tree().process_frame
	assert_false(terrain._integration_running, "L'intégration UI doit terminer")

	var reloaded := ResourceLoader.load(fixture.run_path, "",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RunData
	assert_not_null(reloaded)
	assert_eq(reloaded.rooms.size(), 1)
	var integrated := reloaded.rooms[0] as ArenaDefinition
	assert_not_null(integrated)
	assert_eq(integrated.grid_size, Vector2i(8, 8))
	assert_eq(integrated.waves.size(), 1)
	assert_eq(integrated.waves[0].encounter_definition.roster_units.size(), 1)
	assert_eq(int(integrated.waves[0].encounter_definition.roster_counts[0]), 2)
	assert_eq(FileAccess.get_sha256("res://data/runs/first_run.tres"), canonical_data_hash)


func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result
