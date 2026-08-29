extends GutTest

class FixtureGraph extends StudioReferenceGraphService:
	var roots: Array[RunData] = []
	func _discover_runs() -> Array[RunData]:
		return roots


func _fixture() -> Dictionary:
	var path := "user://dungeon_draft_studio/encounter_g1/%d" % Time.get_ticks_usec()
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)), OK)
	var unit := UnitData.new()
	unit.unit_name = "Garde de test"
	unit.unit_id = &"g1_guard"
	unit.team = 1
	var encounter := EncounterDefinition.new()
	encounter.roster_units = [unit]
	encounter.roster_counts = PackedInt32Array([1])
	encounter.living_enemy_cap = 1
	encounter.formation_profiles = [&"line"]
	assert_eq(ResourceSaver.save(encounter, path.path_join("encounter.tres")), OK)
	encounter = load(path.path_join("encounter.tres"))
	var layout := RoomGridLayout.new()
	layout.logical_size = Vector2i(8, 8)
	layout.layout_rows = PackedStringArray(["........", "........", "........", "........", "........", "........", "........", "........"])
	var room := ArenaDefinition.new()
	room.set_identity("Cour des gardes", "cour_g1")
	room.visual_mode = ArenaDefinition.VisualMode.MODULAR
	room.theme_id = &"dynamic_default"
	room.modular_visual_profile = ArenaModularVisualProfile.new()
	room.grid_size = Vector2i(8, 8)
	for y in 8:
		for x in 8:
			ArenaTerrainRegistry.configure_cell(room.ensure_cell(Vector2i(x, y)), &"stone")
	ArenaEditingService.prepare_automatically(room)
	room.room_name = "Cour des gardes"
	room.grid_layout = layout
	room.hero_spawn_zone = [Vector2i(0, 0)]
	room.enemy_spawn_zone = [Vector2i(7, 7)]
	room.encounter_definition = encounter
	room.minimum_wave_count = 1
	room.maximum_wave_count = 2
	for index in 2:
		var wave := RoomWaveData.new()
		wave.wave_name = "Affrontement %d" % (index + 1)
		wave.encounter_definition = encounter
		room.waves.append(wave)
	assert_eq(ResourceSaver.save(room, path.path_join("room.tres")), OK)
	var run := RunData.new()
	run.run_name = "Partie G1"
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 2
	run.rooms = [load(path.path_join("room.tres"))]
	assert_eq(ResourceSaver.save(run, path.path_join("run.tres")), OK)
	run = load(path.path_join("run.tres"))
	var graph := FixtureGraph.new()
	graph.roots = [run]
	return {"run": run, "graph": graph}


func _workspace(fixture: Dictionary) -> StudioWorkspace:
	var context := StudioProjectContext.new()
	assert_true(context.request_run(fixture.run).ok)
	var workspace := StudioWorkspace.new()
	workspace.arena_auto_load_enabled = false
	workspace.arena_production_planning_enabled = false
	workspace.setup(null, null, context, fixture.graph)
	add_child_autofree(workspace)
	await wait_process_frames(3)
	assert_true(fixture.graph.scan().ok)
	await wait_process_frames(2)
	return workspace


func _nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_nodes(child))
	return result


func _document_state(ui: EncounterStudioMain) -> Dictionary:
	return {"fingerprint": ui.session.document_fingerprint(), "dirty": ui.session.is_dirty(),
		"history": ui.history_entries(), "index": ui.history_current_index(),
		"room": ui.session.selected_room_index, "wave": ui.session.selected_wave_index}


func _other_documents(workspace: StudioWorkspace) -> Dictionary:
	var terrain := workspace.arena_studio
	var items := workspace.item_studio
	return {"terrain": ArenaEditSession.fingerprint(terrain.arena.to_snapshot()),
		"terrain_dirty": terrain.dirty, "terrain_history": terrain.history_entries(),
		"zoom": terrain.canvas.zoom, "pan": terrain.canvas.pan,
		"selection": terrain.canvas.selected_cells.duplicate(),
		"items": items.document.current_fingerprint(), "items_dirty": items.document.is_dirty(),
		"items_history": items.history_entries()}


func test_global_toggle_roundtrip_preserves_both_states_and_documents() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	assert_true(workspace.arena_studio._open_context_room(workspace.project_context.active_room()))
	workspace.arena_studio.show_editor()
	workspace.arena_studio.canvas.zoom = 1.7
	workspace.arena_studio.canvas.pan = Vector2(20, 30)
	workspace.arena_studio.canvas.selected_cells = [Vector2i(2, 2)]
	await wait_process_frames(2)
	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 2, "Édition G1")
	ui.session.select(0, 1)
	var before := _document_state(ui)
	var arena_before := workspace.arena_studio.get_workspace_state()
	var item_before := workspace.item_studio.get_state_snapshot()
	var other_before := _other_documents(workspace)
	for enabled in [false, true]:
		workspace.guided_toggle.button_pressed = enabled
		assert_eq(workspace.arena_studio.is_guided(), enabled)
		assert_eq(workspace.item_studio.guided, enabled)
		for tab in [0, 1, 2, 1]:
			workspace.tabs.current_tab = tab
			await wait_process_frames(1)
			assert_eq(workspace.guided_toggle.is_visible_in_tree(), tab != 1)
			assert_eq(workspace.guided_toggle.button_pressed, enabled)
			assert_eq(_document_state(ui), before)
			assert_eq(_other_documents(workspace), other_before)
	assert_eq(workspace.arena_studio.get_workspace_state(), arena_before)
	assert_eq(workspace.item_studio.get_state_snapshot(), item_before)


func test_analysis_controls_always_available_and_no_mode_contract() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	workspace.tabs.current_tab = 1
	assert_false(ui.has_method("set_guided"))
	assert_false(FileAccess.get_file_as_string("res://addons/dungeon_draft_arena_studio/encounter/ui/encounter_studio_main.gd").contains("guided"))
	assert_false(ui.get_property_list().any(func(property): return property.name == "guided"))
	assert_eq(ui.properties_tabs.current_tab, 0)
	ui.apply_state_snapshot({"run_path": ui.session.source_run_path, "properties_tab": 4})
	assert_eq(ui.properties_tabs.current_tab, 0, "Une préférence technique persistée ne s'ouvre pas par défaut")
	for tab in ui.properties_tabs.get_tab_count():
		assert_false(ui.properties_tabs.get_tab_title(tab).contains("Avanc"))
	ui.properties_tabs.current_tab = 3
	var labels := PackedStringArray()
	for node in _nodes(ui.analysis_presets):
		if node is Button:
			labels.append(node.text)
			assert_true(node.is_visible_in_tree())
			assert_false(node.disabled)
	assert_eq(labels, PackedStringArray(["10", "100", "1 000", "Annuler"]))
	var before := _document_state(ui)
	await ui.analyze_seeds(10)
	assert_eq(ui.analysis_result.completed, 10)
	assert_string_contains(ui.analysis_text.text, "10 valeurs de départ analysées")
	assert_false(ui.analysis_text.text.contains("{"))
	assert_eq(_document_state(ui), before)
	# Le bouton Annuler interrompt une vraie analyse en cours, au premier lot.
	ui.analyze_seeds(1000)
	ui.analysis_presets.get_child(ui.analysis_presets.get_child_count() - 1).pressed.emit()
	await wait_process_frames(3)
	assert_true(ui.analysis_result.cancelled)
	assert_lt(ui.analysis_result.completed, 1000)
	assert_eq(_document_state(ui), before)


func test_validation_explanation_and_local_details_are_read_only() -> void:
	var workspace := await _workspace(_fixture())
	workspace.tabs.current_tab = 1
	var ui := workspace.encounter_studio
	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 0, "Plafond invalide")
	ui.session.confirm_draft_saved()
	ui.validate_session()
	var index := -1
	for i in ui.session.validation_messages.size():
		var message := ui.session.validation_messages[i]
		var explanation := EncounterPresentation.validation_explanation(message)
		assert_false(explanation.is_empty())
		assert_false(explanation.contains("res://"))
		assert_false(explanation.contains("user://"))
		assert_false(explanation.contains(str(message.code)))
		assert_false(explanation.contains("Avanc"))
		if message.code == &"living_cap_too_low":
			index = i
	assert_gte(index, 0)
	var before := _document_state(ui)
	var message := ui.session.validation_messages[index]
	var card: EncounterDiagnosticCard = null
	for candidate in ui.validation_cards_box.get_children():
		if candidate.message == message:
			card = candidate
			break
	assert_not_null(card, "Une carte de diagnostic existe pour ce message")
	assert_not_null(card.fix_button, "Le bouton Corriger existe pour un fix_id reconnu")
	card.details_requested.emit()
	assert_true(ui.validation_details_dialog.visible)
	assert_string_contains(ui.validation_details_text.text, str(message.code))
	assert_string_contains(ui.validation_details_text.text, ui.session.source_encounter().resource_path)
	assert_string_contains(ui.validation_details_text.text, "fit_living_cap")
	assert_eq(_document_state(ui), before)
	ui.validation_details_dialog.hide()
	# « Voir » ne doit jamais appliquer de correction, même si un fix_id existe.
	# Il peut légitimement changer la sélection (salle/affrontement affiché),
	# mais jamais le contenu, l'état modifié ni l'historique.
	card.view_requested.emit()
	var after_view := _document_state(ui)
	assert_eq(after_view.fingerprint, before.fingerprint, "Voir ne modifie pas le contenu")
	assert_eq(after_view.dirty, before.dirty, "Voir ne rend rien modifié")
	assert_eq(after_view.history, before.history, "Voir ne crée aucune action d'historique")
	assert_eq(after_view.index, before.index, "Voir ne déplace pas l'historique")
	assert_false(ui.shared_dialog.visible, "Voir ne déclenche jamais la protection de partage")
	# Seul « Corriger » applique la correction, en passant par la même protection.
	card.fix_requested.emit()
	assert_true(ui.shared_dialog.visible, "La correction conserve la confirmation de partage")
	ui.shared_dialog.hide()
	ui.shared_dialog.confirmed.emit()
	assert_eq(ui.session.current_encounter().living_enemy_cap, 1)
	assert_eq(ui.history_current_index(), int(before.index) + 1)


func test_presentation_has_named_lines_and_preserves_every_result() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	var report := ui.analysis_service._new_report(42, 10)
	report.completed = 10
	report.failures = 2
	report.success_rate_percent = 80.0
	report.formations = {"line": 8}
	report.formations_never_selected = ["split"]
	report.failure_reasons = {"incomplete_roster": 2}
	report.problem_seeds = [{"run_seed": 42, "effective_seed": 42, "reason": "incomplete_roster"}]
	var copy: Dictionary = report.duplicate(true)
	var text := ui._format_analysis(report)
	assert_eq(report, copy)
	assert_string_contains(text, "Ligne : 8")
	assert_string_contains(text, "Deux groupes")
	assert_string_contains(text, "Valeur 42 (effective 42)")
	assert_false(text.contains("incomplete_roster"))
	assert_false(text.contains("{"))
	assert_string_contains(ui.progression_text.text, "Ennemis au début : 1")
	assert_string_contains(ui.progression_text.text, "Cases praticables : 64")
	assert_false(ui.progression_text.text.contains("{"))
	var summary := ui._usage_summary(ui.session.current_encounter())
	assert_string_contains(ui._usage_text(summary), "Projet publié")
	assert_string_contains(ui._usage_text(summary), "Copie de travail")
	assert_false(ui._usage_text(summary).contains("{"))
	assert_string_contains(ui.technical_text.text, "Génération du graphe partagé : 1")
	for id in EncounterDefinition.FORMATION_IDS:
		assert_true(EncounterPresentation.FORMATION_DESCRIPTIONS.has(id))
		assert_false(EncounterPresentation.FORMATION_DESCRIPTIONS[id].contains(str(id)))
	for node in _nodes(ui.placement_box):
		if node is CheckBox:
			assert_false(node.tooltip_text.contains("Identifiant"))
	assert_string_contains(EncounterPresentation.validation_explanation(StudioValidationMessage.create(
		StudioValidationMessage.Severity.WARNING, &"allowed_spawn_groups_unused", "", "")), "pas encore utilisé pendant les combats")
	ui._show_operation_failure("Échec de test", {"error": "g1_internal_error", "path": "res://example.tres"})
	assert_false(ui.status_label.text.contains("g1_internal_error"))
	assert_false(ui.status_label.text.contains("res://"))
	assert_string_contains(ui.technical_text.text, "g1_internal_error")


func test_shared_choices_and_local_usages_remain_separate() -> void:
	for draft_mode in [false, true]:
		for choice in ["cancel", "shared", "duplicate"]:
			var fixture := _fixture()
			var workspace := await _workspace(fixture)
			var ui := workspace.encounter_studio
			if draft_mode:
				assert_true(workspace.arena_studio._open_context_room(fixture.run.rooms[0]))
				workspace.arena_studio.show_editor()
				workspace.create_encounters_button.pressed.emit()
				assert_same(ui.session.draft_room, workspace.arena_studio.room_draft())
			var before := _document_state(ui)
			var encounter := ui.session.current_encounter()
			var summary := ui._usage_summary(encounter)
			assert_eq(summary.published.usage_count, 2)
			assert_eq(summary.local.usage_count, 3 if draft_mode else 2)
			assert_eq(summary.local.scope, "room_draft" if draft_mode else "working_copy")
			ui._edit_encounter_property(&"living_enemy_cap", 5, "Plafond G1")
			assert_true(ui.shared_dialog.visible)
			assert_eq(ui.shared_dialog.ok_button_text, "Modifier la rencontre partagée")
			assert_eq(ui.shared_duplicate_button.text, "Dupliquer pour cet affrontement")
			assert_eq(ui.shared_dialog.cancel_button_text, "Annuler")
			ui.shared_dialog.hide()
			match choice:
				"cancel":
					ui.shared_dialog.canceled.emit()
					assert_eq(_document_state(ui), before)
				"shared":
					ui.shared_dialog.confirmed.emit()
					assert_same(ui.session.current_room().waves[1].encounter_definition, encounter)
					assert_eq(encounter.living_enemy_cap, 5)
				"duplicate":
					ui.shared_dialog.custom_action.emit(&"duplicate")
					assert_ne(ui.session.current_encounter(), encounter)
					assert_eq(ui.session.current_encounter().living_enemy_cap, 5)
					assert_eq(encounter.living_enemy_cap, 1)
			assert_eq(fixture.run.rooms[0].encounter_definition.living_enemy_cap, 1)
			assert_eq(fixture.graph.generation, 1)


func test_four_dirty_transition_decisions_keep_their_contract() -> void:
	for decision in [&"SAVE", &"DRAFT", &"DISCARD", &"CANCEL"]:
		var workspace := await _workspace(_fixture())
		var ui := workspace.encounter_studio
		ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 3, "Édition avant transition")
		var before := _document_state(ui)
		var destination := _fixture()
		assert_false(ui.open_run(destination.run.resource_path))
		assert_true(workspace.project_context.has_pending_transition())
		workspace.context_bar._resolve(decision)
		assert_false(workspace.context_bar.transition_dialog.visible)
		if decision == &"CANCEL":
			assert_eq(_document_state(ui), before)
		else:
			assert_eq(ui.session.source_run_path, destination.run.resource_path)
			assert_false(ui.session.is_dirty())
		assert_false(workspace.project_context.has_pending_transition())


func test_no_first_encounter_retains_terrain_and_primary_action() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	var draft := EncounterCopyService.copy_room(fixture.run.rooms[0])
	draft.waves.clear()
	draft.encounter_definition = null
	draft.enemies.clear()
	assert_true(ui.open_room_draft(draft, fixture.run))
	workspace.tabs.current_tab = 1
	await wait_process_frames(2)
	assert_not_null(ui.map_preview.grid)
	assert_eq(ui.properties_tabs.current_tab, 0)
	var create: Button
	for node in _nodes(ui.composition_box):
		if node is Button and node.text == "Créer le premier affrontement":
			create = node
	assert_not_null(create)
	assert_true(create.is_visible_in_tree())
	assert_false(create.disabled)
	create.pressed.emit()
	assert_not_null(ui.session.current_encounter())
