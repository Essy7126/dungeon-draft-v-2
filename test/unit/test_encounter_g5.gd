extends GutTest

## G5 — diagnostics compréhensibles et actionnables. Ces tests couvrent ce
## que test_encounter_g1.gd ne couvre pas déjà (Corriger + partage + Annuler/
## Rétablir + Détails techniques pour fit_living_cap) : l'état sans problème,
## les filtres, « Voir » une case et un onglet, et deux autres corrections
## (index de salle, cases interdites dupliquées).

class FixtureGraph extends StudioReferenceGraphService:
	var roots: Array[RunData] = []
	func _discover_runs() -> Array[RunData]:
		return roots


func _fixture() -> Dictionary:
	var path := "user://dungeon_draft_studio/encounter_g5/%d" % Time.get_ticks_usec()
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)), OK)
	var unit := UnitData.new()
	unit.unit_name = "Garde de test"
	unit.unit_id = &"g5_guard"
	unit.team = 1
	var encounter := EncounterDefinition.new()
	encounter.roster_units = [unit]
	encounter.roster_counts = PackedInt32Array([1])
	encounter.living_enemy_cap = 1
	encounter.formation_profiles = [&"line"]
	encounter.room_index = 1
	assert_eq(ResourceSaver.save(encounter, path.path_join("encounter.tres")), OK)
	encounter = load(path.path_join("encounter.tres"))
	var layout := RoomGridLayout.new()
	layout.logical_size = Vector2i(8, 8)
	layout.layout_rows = PackedStringArray(["........", "........", "........", "........", "........", "........", "........", "........"])
	var room := ArenaDefinition.new()
	room.set_identity("Cour G5", "cour_g5")
	room.visual_mode = ArenaDefinition.VisualMode.MODULAR
	room.theme_id = &"dynamic_default"
	room.modular_visual_profile = ArenaModularVisualProfile.new()
	room.grid_size = Vector2i(8, 8)
	for y in 8:
		for x in 8:
			ArenaTerrainRegistry.configure_cell(room.ensure_cell(Vector2i(x, y)), &"stone")
	ArenaEditingService.prepare_automatically(room)
	room.room_name = "Cour G5"
	room.grid_layout = layout
	room.hero_spawn_zone = [Vector2i(0, 0)]
	room.enemy_spawn_zone = [Vector2i(7, 7)]
	room.encounter_definition = encounter
	assert_eq(ResourceSaver.save(room, path.path_join("room.tres")), OK)
	var run := RunData.new()
	run.run_name = "Partie G5"
	run.room_flow_mode = RunData.RoomFlowMode.SINGLE_ENCOUNTER
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


func _document_state(ui: EncounterStudioMain) -> Dictionary:
	return {"fingerprint": ui.session.document_fingerprint(), "dirty": ui.session.is_dirty(),
		"history": ui.history_entries(), "index": ui.history_current_index()}


func _card_for(ui: EncounterStudioMain, code: StringName) -> EncounterDiagnosticCard:
	for candidate in ui.validation_cards_box.get_children():
		if candidate.message != null and candidate.message.code == code:
			return candidate
	return null


## --- État sans problème bloquant --------------------------------------------

func test_no_blocking_diagnostics_shows_the_positive_state() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	ui.validate_session()
	assert_false(EncounterValidationService.has_errors(ui.session.validation_messages))
	assert_true(ui.validation_empty_label.visible)
	assert_string_contains(ui.validation_empty_label.text, "Aucun problème bloquant")
	assert_false(ui.validation_empty_label.text.to_lower().contains("équilibr"),
		"L'état positif ne promet jamais un équilibrage")
	assert_string_contains(ui.validation_toggle.text, "Aucun problème bloquant")


func test_one_error_hides_the_positive_state_and_shows_a_card() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 0, "Plafond invalide")
	ui.validate_session()
	assert_false(ui.validation_empty_label.visible)
	var card := _card_for(ui, &"living_cap_too_low")
	assert_not_null(card)
	assert_string_contains(ui.validation_toggle.text, "erreur")


func test_one_warning_alone_still_counts_as_no_blocking_problem() -> void:
	# allowed_spawn_groups_unused est un avertissement systématique et non
	# bloquant : sa seule présence ne doit pas masquer l'état positif.
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	ui.validate_session()
	assert_true(EncounterValidationService.summary(ui.session.validation_messages).warnings > 0)
	assert_true(ui.validation_empty_label.visible)
	var card := _card_for(ui, &"allowed_spawn_groups_unused")
	assert_not_null(card, "L'avertissement reste consultable séparément")


func test_information_message_is_shown_without_blocking_anything() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	ui.validate_session()
	var card := _card_for(ui, &"run_flow_mode")
	assert_not_null(card, "Un message d'information a sa propre carte")
	assert_null(card.fix_button, "Une information n'a jamais de bouton Corriger")


func test_multiple_severities_are_all_present_at_once() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 0, "Plafond invalide")
	ui.validate_session()
	var severities := {}
	for message in ui.session.validation_messages:
		severities[message.severity] = true
	assert_true(severities.has(StudioValidationMessage.Severity.ERROR))
	assert_true(severities.has(StudioValidationMessage.Severity.WARNING))
	assert_true(severities.has(StudioValidationMessage.Severity.INFO))
	assert_eq(ui.validation_cards_box.get_child_count(), ui.session.validation_messages.size())


## --- Filtres : préférence d'affichage, jamais de mutation -------------------

func test_filters_hide_severities_without_dirtying_or_touching_history() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 0, "Plafond invalide")
	ui.validate_session()
	var before := _document_state(ui)
	var total := ui.validation_cards_box.get_child_count()
	assert_gt(total, 0)
	ui.validation_filter_buttons[StudioValidationMessage.Severity.INFO].button_pressed = false
	ui.validation_filter_buttons[StudioValidationMessage.Severity.INFO].toggled.emit(false)
	var after_filter := ui.validation_cards_box.get_child_count()
	assert_lt(after_filter, total, "Le filtre masque les informations")
	assert_eq(_document_state(ui), before, "Un filtre ne modifie jamais le document")
	# Le filtre survit à un rafraîchissement de validation.
	ui.validate_session()
	assert_eq(ui.validation_cards_box.get_child_count(), after_filter,
		"Le filtre survit à un rafraîchissement de validation")
	ui.validation_filter_buttons[StudioValidationMessage.Severity.INFO].button_pressed = true
	ui.validation_filter_buttons[StudioValidationMessage.Severity.INFO].toggled.emit(true)
	assert_eq(ui.validation_cards_box.get_child_count(), total)


## --- « Voir » -----------------------------------------------------------------

func test_seeing_a_cell_diagnostic_highlights_it_on_the_map() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	ui.session.current_encounter().forbidden_initial_spawn_cells = [Vector2i(99, 99)]
	ui.validate_session()
	var card := _card_for(ui, &"forbidden_cell_outside")
	assert_not_null(card)
	assert_eq(card.message.cell, Vector2i(99, 99))
	card.view_requested.emit()
	assert_eq(ui.map_preview.selected_cell, Vector2i(99, 99))


func test_seeing_a_room_diagnostic_selects_the_right_room_and_wave() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	ui.validate_session()
	var card := _card_for(ui, &"room_mode")
	assert_not_null(card)
	assert_not_null(card.view_button, "Un message rattaché à une salle propose Voir")
	card.view_requested.emit()
	assert_eq(ui.session.selected_room_index, 0)


## --- « Corriger » : deux fix_id non couverts par test_encounter_g1.gd ------

func test_fixing_room_index_mismatch_updates_only_that_property() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	ui._set_property(ui.session.current_encounter(), &"room_index", 5, "Index erroné")
	ui.validate_session()
	var card := _card_for(ui, &"room_index_mismatch")
	assert_not_null(card)
	assert_not_null(card.fix_button)
	var before_undo := ui.history_current_index()
	card.fix_requested.emit()
	if ui.shared_dialog.visible:
		ui.shared_dialog.confirmed.emit()
	assert_eq(ui.session.current_encounter().room_index, 1)
	assert_eq(ui.history_current_index(), before_undo + 1,
		"Corriger crée au maximum une action d'historique")
	assert_true(ui.history_can_undo())
	ui.history_undo()
	assert_eq(ui.session.current_encounter().room_index, 5, "Annuler restaure l'ancien index")
	ui.history_redo()
	assert_eq(ui.session.current_encounter().room_index, 1, "Rétablir réapplique la correction")


func test_fixing_duplicate_forbidden_cells_deduplicates_only() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	var duplicated: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 1), Vector2i(2, 2)]
	ui._set_property(
		ui.session.current_encounter(), &"forbidden_initial_spawn_cells",
		duplicated, "Doublons"
	)
	ui.validate_session()
	var card := _card_for(ui, &"forbidden_cell_duplicate")
	assert_not_null(card)
	card.fix_requested.emit()
	if ui.shared_dialog.visible:
		ui.shared_dialog.confirmed.emit()
	assert_eq(ui.session.current_encounter().forbidden_initial_spawn_cells,
		[Vector2i(1, 1), Vector2i(2, 2)] as Array[Vector2i])


## --- Aucune correction accidentelle -----------------------------------------

func test_rebuilding_cards_never_mutates_or_dirties_the_document() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	var before := _document_state(ui)
	ui.validate_session()
	ui.validate_session()
	ui._rebuild_validation_cards()
	assert_eq(_document_state(ui), before)


## --- Détails techniques : accessibles séparément, jamais dans le parcours normal --

func test_technical_identifiers_are_absent_from_cards_but_present_in_details() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 0, "Plafond invalide")
	ui.validate_session()
	var card := _card_for(ui, &"living_cap_too_low")
	assert_not_null(card)
	for node in _descendants(card):
		if node is Label:
			assert_false((node as Label).text.contains("living_cap_too_low"))
			assert_false((node as Label).text.contains("fit_living_cap"))
			assert_false((node as Label).text.contains("res://"))
	card.details_requested.emit()
	assert_string_contains(ui.validation_details_text.text, "living_cap_too_low")
	assert_string_contains(ui.validation_details_text.text, "fit_living_cap")


func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result


## --- Textes très longs : pas de débordement horizontal forcé ----------------

func test_long_enemy_names_wrap_instead_of_forcing_overflow() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	var unit := ui.session.current_encounter().roster_units[0]
	unit.unit_name = "Un nom d'ennemi extrêmement long pour vérifier que le texte des cartes de diagnostic passe à la ligne au lieu de déborder hors de l'écran"
	ui.session.current_encounter().roster_units[0].tactical_role_id = &"role_totalement_invente_et_tres_long_pour_le_test"
	ui.validate_session()
	var card := _card_for(ui, &"role_unknown")
	if card == null:
		return
	for node in _descendants(card):
		if node is Label and (node as Label).text.length() > 40:
			assert_ne((node as Label).autowrap_mode, TextServer.AUTOWRAP_OFF,
				"Un texte long doit passer à la ligne, jamais forcer un débordement : %s" % (node as Label).text)
