extends GutTest

## G6 — finition visuelle et accessibilité. Ces tests couvrent uniquement ce
## que G5 (test_encounter_g5.gd) et le rapport S0 ne couvrent pas déjà :
## préservation du focus clavier après reconstruction du panneau, hiérarchie
## visuelle des actions destructrices, et cohérence des hauteurs de boutons.
## Le contraste des couleurs est vérifié par mesure de pixels réels sur les
## captures (méthode documentée dans encounter_g6_validation.md), pas ici :
## GUT ne rend pas de pixels comparables à une vraie capture GPU.

class FixtureGraph extends StudioReferenceGraphService:
	var roots: Array[RunData] = []
	func _discover_runs() -> Array[RunData]:
		return roots


func _fixture() -> Dictionary:
	var path := "user://dungeon_draft_studio/encounter_g6/%d" % Time.get_ticks_usec()
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)), OK)
	var unit := UnitData.new()
	unit.unit_name = "Garde de test"
	unit.unit_id = &"g6_guard"
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
	room.set_identity("Cour G6", "cour_g6")
	room.visual_mode = ArenaDefinition.VisualMode.MODULAR
	room.theme_id = &"dynamic_default"
	room.modular_visual_profile = ArenaModularVisualProfile.new()
	room.grid_size = Vector2i(8, 8)
	for y in 8:
		for x in 8:
			ArenaTerrainRegistry.configure_cell(room.ensure_cell(Vector2i(x, y)), &"stone")
	ArenaEditingService.prepare_automatically(room)
	room.room_name = "Cour G6"
	room.grid_layout = layout
	room.hero_spawn_zone = [Vector2i(0, 0)]
	room.enemy_spawn_zone = [Vector2i(7, 7)]
	room.encounter_definition = encounter
	assert_eq(ResourceSaver.save(room, path.path_join("room.tres")), OK)
	var run := RunData.new()
	run.run_name = "Partie G6"
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


func _card_for(ui: EncounterStudioMain, code: StringName) -> EncounterDiagnosticCard:
	for candidate in ui.validation_cards_box.get_children():
		if candidate.message != null and candidate.message.code == code:
			return candidate
	return null


## --- Focus clavier survit à une reconstruction du panneau -------------------

func test_focus_returns_to_a_stable_anchor_after_correcting_a_diagnostic() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	ui._set_property(ui.session.current_encounter(), &"living_enemy_cap", 0, "Plafond invalide")
	ui.validate_session()
	var card := _card_for(ui, &"living_cap_too_low")
	assert_not_null(card)
	assert_not_null(card.fix_button)
	card.fix_button.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), card.fix_button)
	card.fix_requested.emit()
	if ui.shared_dialog.visible:
		ui.shared_dialog.confirmed.emit()
	await wait_process_frames(2)
	# Le bouton d'origine a été détruit par la reconstruction des cartes :
	# le focus doit avoir été reporté sur le bouton qui replie/déplie le
	# panneau (ancrage stable), jamais silencieusement perdu.
	assert_eq(get_viewport().gui_get_focus_owner(), ui.validation_toggle,
		"Le focus est reporté sur un ancrage stable après reconstruction du panneau")


func test_focus_outside_the_panel_is_left_untouched_by_a_rebuild() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	ui.validate_session()
	ui.catalog_search.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), ui.catalog_search)
	ui.validate_session()
	assert_eq(get_viewport().gui_get_focus_owner(), ui.catalog_search,
		"Un rafraîchissement ne doit jamais voler le focus d'un contrôle hors du panneau")


## --- Hiérarchie des actions : destructif identifiable, jamais dominant -----

func test_destructive_actions_are_visually_distinct_but_not_dominant() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	var remove_wave_button: Button = null
	for node in _descendants(ui):
		if node is Button and node.text == "Supprimer":
			remove_wave_button = node
			break
	assert_not_null(remove_wave_button, "Le bouton Supprimer un affrontement existe")
	assert_eq(
		remove_wave_button.get_theme_color("font_color"),
		EncounterVisualConstants.COLOR_DESTRUCTIVE
	)
	# Pas de fond plein ni de taille agrandie : seule la couleur du texte
	# distingue l'action, elle ne doit pas dominer l'écran.
	assert_false(remove_wave_button.has_theme_stylebox_override("normal"))
	assert_eq(remove_wave_button.custom_minimum_size.y, float(EncounterVisualConstants.BUTTON_MIN_HEIGHT))


func test_removing_an_enemy_uses_the_same_destructive_style() -> void:
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	await wait_process_frames(2)
	var remove_button: Button = null
	for node in _descendants(ui):
		if node is Button and node.text == "Retirer" \
				and node.tooltip_text.contains("complètement"):
			remove_button = node
			break
	assert_not_null(remove_button, "Le bouton Retirer un ennemi de la composition existe")
	assert_eq(
		remove_button.get_theme_color("font_color"),
		EncounterVisualConstants.COLOR_DESTRUCTIVE
	)


## --- Cohérence des hauteurs de boutons ---------------------------------------

func test_toolbar_buttons_meet_the_shared_minimum_height() -> void:
	# Une action principale (ex. « Créer le premier affrontement ») peut
	# légitimement être plus grande que la base commune — c'est la hiérarchie
	# voulue par G6 (§18). Ce qui ne doit jamais arriver, c'est un bouton
	# construit par _add_button plus PETIT que la base commune.
	var workspace := await _workspace(_fixture())
	var ui := workspace.encounter_studio
	var checked := 0
	var exact_baseline := 0
	for node in _descendants(ui):
		if node is Button and node.custom_minimum_size.y > 0:
			assert_true(node.custom_minimum_size.y >= float(EncounterVisualConstants.BUTTON_MIN_HEIGHT),
				"Bouton plus petit que la base commune : " + node.text)
			checked += 1
			if node.custom_minimum_size.y == float(EncounterVisualConstants.BUTTON_MIN_HEIGHT):
				exact_baseline += 1
	assert_gt(checked, 5, "Un nombre représentatif de boutons a été vérifié")
	assert_gt(exact_baseline, 5, "La majorité des boutons secondaires partage la même base")


func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result
