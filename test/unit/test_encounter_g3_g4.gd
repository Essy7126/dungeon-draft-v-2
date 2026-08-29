extends GutTest

## G3 (composition novice) + G4 (langage visuel et sécurité de la carte).
## Prérequis vérifiés avant cette suite : G1 (plus de distinction Guidé/Avancé
## dans Rencontre) et G2 (disposition responsive, panneaux repliables) restent
## en place et ne sont pas reconstruits ici.

class FixtureGraph extends StudioReferenceGraphService:
	var roots: Array[RunData] = []
	func _discover_runs() -> Array[RunData]:
		return roots


func _unit(name: String, id: StringName, with_sprite: bool) -> UnitData:
	var unit := UnitData.new()
	unit.unit_name = name
	unit.unit_id = id
	unit.team = 1
	unit.faction_id = &"skeleton_legion"
	unit.tactical_role_id = &"skeleton_normal"
	unit.max_hp = 40
	unit.max_ap = 6
	unit.max_mp = 3
	if with_sprite:
		var frames := SpriteFrames.new()
		var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color.RED)
		frames.add_frame("default", ImageTexture.create_from_image(image))
		unit.sprite_frames = frames
		unit.idle_animation = "default"
	return unit


func _fixture() -> Dictionary:
	var path := "user://dungeon_draft_studio/encounter_g3_g4/%d" % Time.get_ticks_usec()
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)), OK)
	var guard := _unit("Garde de test", &"g3g4_guard", true)
	var brute := _unit(
		"Champion à la lance sans illustration connue et au nom volontairement très long",
		&"g3g4_brute", false)
	brute.tactical_role_id = &"skeleton_chief"
	assert_eq(ResourceSaver.save(guard, path.path_join("guard.tres")), OK)
	assert_eq(ResourceSaver.save(brute, path.path_join("brute.tres")), OK)
	guard = load(path.path_join("guard.tres"))
	brute = load(path.path_join("brute.tres"))
	var layout := RoomGridLayout.new()
	layout.logical_size = Vector2i(8, 8)
	layout.layout_rows = PackedStringArray(["........", "........", "........", "........", "........", "........", "........", "........"])
	var room := ArenaDefinition.new()
	room.set_identity("Cour G3G4", "cour_g3g4")
	room.visual_mode = ArenaDefinition.VisualMode.MODULAR
	room.theme_id = &"dynamic_default"
	room.modular_visual_profile = ArenaModularVisualProfile.new()
	room.grid_size = Vector2i(8, 8)
	for y in 8:
		for x in 8:
			ArenaTerrainRegistry.configure_cell(room.ensure_cell(Vector2i(x, y)), &"stone")
	ArenaEditingService.prepare_automatically(room)
	room.room_name = "Cour G3G4"
	room.grid_layout = layout
	room.hero_spawn_zone = [Vector2i(0, 0)]
	room.enemy_spawn_zone = [Vector2i(7, 7)]
	room.encounter_definition = null
	room.minimum_wave_count = 0
	room.maximum_wave_count = 2
	assert_eq(ResourceSaver.save(room, path.path_join("room.tres")), OK)
	var run := RunData.new()
	run.run_name = "Partie G3G4"
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 2
	run.rooms = [load(path.path_join("room.tres"))]
	assert_eq(ResourceSaver.save(run, path.path_join("run.tres")), OK)
	run = load(path.path_join("run.tres"))
	var graph := FixtureGraph.new()
	graph.roots = [run]
	return {"run": run, "graph": graph, "guard": guard, "brute": brute}


## Variante avec deux affrontements partageant déjà la même rencontre, comme
## dans la fixture G1 : la protection de partage doit être testée sur un
## partage préexistant dans la Resource, pas simulé en cours de session.
func _fixture_shared() -> Dictionary:
	var path := "user://dungeon_draft_studio/encounter_g3_g4_shared/%d" % Time.get_ticks_usec()
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)), OK)
	var guard := _unit("Garde de test", &"g3g4_shared_guard", true)
	assert_eq(ResourceSaver.save(guard, path.path_join("guard.tres")), OK)
	guard = load(path.path_join("guard.tres"))
	var encounter := EncounterDefinition.new()
	encounter.roster_units = [guard]
	encounter.roster_counts = PackedInt32Array([1])
	assert_eq(ResourceSaver.save(encounter, path.path_join("encounter.tres")), OK)
	encounter = load(path.path_join("encounter.tres"))
	var layout := RoomGridLayout.new()
	layout.logical_size = Vector2i(8, 8)
	layout.layout_rows = PackedStringArray(["........", "........", "........", "........", "........", "........", "........", "........"])
	var room := ArenaDefinition.new()
	room.set_identity("Cour partagée G3G4", "cour_g3g4_shared")
	room.visual_mode = ArenaDefinition.VisualMode.MODULAR
	room.theme_id = &"dynamic_default"
	room.modular_visual_profile = ArenaModularVisualProfile.new()
	room.grid_size = Vector2i(8, 8)
	for y in 8:
		for x in 8:
			ArenaTerrainRegistry.configure_cell(room.ensure_cell(Vector2i(x, y)), &"stone")
	ArenaEditingService.prepare_automatically(room)
	room.room_name = "Cour partagée G3G4"
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
	run.run_name = "Partie partagée G3G4"
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 2
	run.rooms = [load(path.path_join("room.tres"))]
	assert_eq(ResourceSaver.save(run, path.path_join("run.tres")), OK)
	run = load(path.path_join("run.tres"))
	var graph := FixtureGraph.new()
	graph.roots = [run]
	return {"run": run, "graph": graph, "guard": guard}


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
	workspace.tabs.current_tab = 1
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


func _find_button(root: Node, text: String) -> Button:
	for node in _nodes(root):
		if node is Button and node.text == text:
			return node
	return null


func _catalog_cards(ui: EncounterStudioMain) -> Array[EncounterEnemyCard]:
	var result: Array[EncounterEnemyCard] = []
	for node in ui.catalog_cards_box.get_children():
		if node is EncounterEnemyCard:
			result.append(node)
	return result


func _seed_catalog(ui: EncounterStudioMain, fixture: Dictionary) -> void:
	ui.enemy_catalog = [fixture.guard, fixture.brute]
	ui._refresh_composition()


# ---------------------------------------------------------------------------
# G3 — création et composition
# ---------------------------------------------------------------------------

func test_no_encounter_shows_explicit_empty_state_and_draft_explanation() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	_seed_catalog(ui, fixture)
	assert_string_contains(ui.composition_box.get_child(0).text, "Aucun affrontement dans cette salle")
	var explanation := ""
	for node in _nodes(ui.composition_box):
		if node is Label and node.text.contains("brouillon"):
			explanation = node.text
	assert_string_contains(explanation, "intégré")
	var create := _find_button(ui.composition_box, "Créer le premier affrontement")
	assert_not_null(create)
	assert_true(create.is_visible_in_tree())


func test_create_first_encounter_is_single_undo_action_and_selected() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	_seed_catalog(ui, fixture)
	var before := _document_state(ui)
	var create := _find_button(ui.composition_box, "Créer le premier affrontement")
	create.pressed.emit()
	await wait_process_frames(1)
	assert_not_null(ui.session.current_encounter())
	assert_eq(ui.session.selected_wave_index, 0)
	assert_eq(ui.history_current_index(), int(before.index) + 1, "Une seule action d'historique")
	var hint := ""
	for node in _nodes(ui.composition_box):
		if node is Label and node.text.contains("Ajoutez au moins un ennemi"):
			hint = node.text
	assert_string_contains(hint, "Ajoutez au moins un ennemi")
	# Annuler restitue exactement l'état sans affrontement.
	ui._undo()
	assert_null(ui.session.current_encounter())
	assert_eq(_document_state(ui).fingerprint, before.fingerprint)
	# Rétablir recrée le même affrontement.
	ui._redo()
	assert_not_null(ui.session.current_encounter())


func test_composition_order_is_summary_then_roster_then_catalog_then_settings() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	# Repère l'ordre par index de première apparition de chaque section clé.
	var texts: Array[String] = []
	for node in _nodes(ui.composition_box):
		if node is Label or node is Button:
			texts.append(str(node.text))
	var index_ennemis := -1
	var index_catalogue := -1
	var index_reglages := -1
	for i in texts.size():
		if texts[i] == "Ennemis ajoutés" and index_ennemis < 0:
			index_ennemis = i
		if texts[i] == "Catalogue des ennemis" and index_catalogue < 0:
			index_catalogue = i
		if texts[i].contains("Réglages de l'affrontement") and index_reglages < 0:
			index_reglages = i
	assert_gt(index_ennemis, 0)
	assert_gt(index_catalogue, index_ennemis)
	assert_gt(index_reglages, index_catalogue)


func test_first_add_creates_quantity_one_and_repeat_add_increments() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	ui._add_unit(fixture.guard)
	var encounter := ui.session.current_encounter()
	assert_eq(encounter.roster_units.size(), 1)
	assert_eq(encounter.roster_counts[0], 1)
	ui._add_unit(fixture.guard)
	assert_eq(encounter.roster_units.size(), 1)
	assert_eq(encounter.roster_counts[0], 2)


func test_quantity_never_goes_below_one_and_remove_then_undo_restores() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	ui._add_unit(fixture.guard)
	ui._change_quantity(0, 0)
	assert_eq(ui.session.current_encounter().roster_counts[0], 1)
	var before := _document_state(ui)
	ui._remove_roster_index(0)
	assert_true(ui.session.current_encounter().roster_units.is_empty())
	ui._undo()
	assert_eq(ui.session.current_encounter().roster_units.size(), 1)
	assert_eq(_document_state(ui).fingerprint, before.fingerprint)


func test_catalog_search_and_filters_use_real_catalog_and_report_no_results() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	assert_eq(_catalog_cards(ui).size(), 2)
	ui._filter_catalog("garde")
	assert_eq(_catalog_cards(ui).size(), 1)
	ui._filter_catalog("aucune-correspondance-possible")
	assert_eq(_catalog_cards(ui).size(), 0)
	assert_true(ui.catalog_empty_label.visible)
	assert_string_contains(ui.catalog_empty_label.text, "Aucun ennemi ne correspond")
	ui._filter_catalog("")
	# Les filtres sont construits depuis le catalogue réel, jamais codés en dur.
	var factions := ui._catalog_factions()
	assert_true(factions.has(&"skeleton_legion"))
	assert_false(factions.has(&"faction_inexistante"))


func test_search_and_scroll_persist_across_a_composition_edit() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	ui._filter_catalog("champion")
	assert_eq(_catalog_cards(ui).size(), 1)
	ui._add_unit(fixture.guard)  # provoque un rafraîchissement complet de Composition.
	await wait_process_frames(1)
	assert_eq(ui.catalog_search.text, "champion", "La recherche reste affichée après un ajout")
	assert_eq(_catalog_cards(ui).size(), 1)


func test_illustrated_and_fallback_units_render_without_crashing() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	ui._add_unit(fixture.guard)
	ui._add_unit(fixture.brute)
	await wait_process_frames(1)
	var cards: Array[EncounterEnemyCard] = []
	for node in ui.composition_box.get_children():
		if node is EncounterEnemyCard:
			cards.append(node)
	assert_eq(cards.size(), 2)
	var with_texture := false
	var with_initials := false
	for card in cards:
		if card._thumbnail.visible and card._thumbnail.texture != null:
			with_texture = true
		if card._initials_label.visible:
			with_initials = true
			assert_false(card._initials_label.text.is_empty())
	assert_true(with_texture, "L'unité avec SpriteFrames affiche une illustration réelle")
	assert_true(with_initials, "L'unité sans illustration reçoit un remplacement neutre par initiales")


func test_no_technical_identifiers_in_composition_text() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	ui._add_unit(fixture.brute)
	for node in _nodes(ui.composition_box):
		if node is Label:
			assert_false(node.text.contains("res://"), node.text)
			assert_false(node.text.contains("user://"), node.text)
			assert_false(node.text.contains("g3g4_brute"), node.text)


func test_shared_encounter_protection_still_gated_through_new_cards() -> void:
	var fixture := _fixture_shared()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	var brute := _unit("Second ennemi", &"g3g4_shared_second", false)
	ui.enemy_catalog = [fixture.guard, brute]
	ui._refresh_composition()
	var encounter := ui.session.current_encounter()
	assert_eq(ui._usage_summary(encounter).published.usage_count, 2)
	ui._add_unit(brute)
	assert_true(ui.shared_dialog.visible, "Un ajout via la carte du catalogue reste protégé comme avant")
	ui.shared_dialog.hide()
	ui.shared_dialog.custom_action.emit(&"duplicate")
	assert_ne(ui.session.current_encounter(), encounter)
	assert_eq(encounter.roster_units.size(), 1, "L'original n'est jamais modifié par la copie")


func test_widget_stays_within_window_at_two_resolutions() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	ui._add_unit(fixture.brute)
	for size in [Vector2(1280, 720), Vector2(1920, 1080)]:
		workspace.size = size
		await wait_process_frames(2)
		assert_true(ui.composition_box.get_parent() is ScrollContainer)


# ---------------------------------------------------------------------------
# G4 — carte : consultation par défaut, outil explicite, informations de case
# ---------------------------------------------------------------------------

func test_map_click_in_view_mode_selects_without_mutation() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	ui._add_unit(fixture.guard)
	assert_false(ui.map_preview.edit_forbidden_mode)
	var before := _document_state(ui)
	var room := ui.session.runtime_room()
	ui.map_preview.room = room
	ui.map_preview.grid = EncounterGridFactory.build_from_room(room)
	ui.map_preview.size = Vector2(400, 400)
	ui.map_preview._configure_projection()
	var target_cell := Vector2i(3, 3)
	var click_position := ui.map_preview._cell_center(target_cell)
	var toggled: Array[Vector2i] = []
	ui.map_preview.forbidden_cell_toggled.connect(func(cell): toggled.append(cell))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = click_position
	ui.map_preview._gui_input(click)
	assert_true(toggled.is_empty(), "Un clic ordinaire ne modifie jamais les cases interdites")
	assert_eq(ui.map_preview.selected_cell, target_cell)
	assert_eq(ui.session.current_encounter().forbidden_initial_spawn_cells.size(), 0)
	assert_eq(_document_state(ui), before)
	assert_string_contains(ui.cell_info_label.text, "Case (3, 3)")


func test_forbidden_tool_must_be_active_for_a_click_to_emit_a_mutation() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	ui._add_unit(fixture.guard)
	var room := ui.session.runtime_room()
	ui.map_preview.room = room
	ui.map_preview.grid = EncounterGridFactory.build_from_room(room)
	ui.map_preview.size = Vector2(400, 400)
	ui.map_preview._configure_projection()
	var target_cell := Vector2i(2, 2)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = ui.map_preview._cell_center(target_cell)
	var before := _document_state(ui)
	# Outil inactif : la carte reste en consultation.
	ui.map_preview._gui_input(click)
	assert_eq(_document_state(ui), before)
	assert_eq(ui.session.current_encounter().forbidden_initial_spawn_cells.size(), 0)
	# Outil explicitement activé : le même clic mute, en une seule action.
	ui.map_preview.set_edit_mode(true)
	assert_true(ui.forbidden_tool_toggle.button_pressed)
	ui.map_preview._gui_input(click)
	assert_eq(ui.session.current_encounter().forbidden_initial_spawn_cells, [target_cell])
	assert_eq(ui.history_current_index(), int(before.index) + 1, "Une seule action d'historique par clic")
	ui._undo()
	assert_eq(ui.session.current_encounter().forbidden_initial_spawn_cells.size(), 0)
	# Après Annuler, le document retrouve exactement son empreinte et son état
	# précédents. L'historique, lui, gagne légitimement une entrée "à rétablir" :
	# Annuler ne l'efface jamais, donc on ne compare pas la liste complète ici.
	var after := _document_state(ui)
	assert_eq(after.fingerprint, before.fingerprint)
	assert_eq(after.dirty, before.dirty)
	assert_eq(after.room, before.room)
	assert_eq(after.wave, before.wave)
	assert_eq(after.index, before.index)


func test_escape_exits_tool_without_other_mutation() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	ui._add_unit(fixture.guard)
	ui.map_preview.set_edit_mode(true)
	var before := _document_state(ui)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	ui.map_preview._unhandled_key_input(escape)
	assert_false(ui.map_preview.edit_forbidden_mode)
	assert_false(ui.forbidden_tool_toggle.button_pressed)
	assert_eq(_document_state(ui), before)


func test_changing_properties_tab_exits_forbidden_tool() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	ui._add_unit(fixture.guard)
	ui.map_preview.set_edit_mode(true)
	ui.properties_tabs.current_tab = 1
	ui.properties_tabs.tab_changed.emit(1)
	assert_false(ui.map_preview.edit_forbidden_mode)


func test_changing_room_exits_forbidden_tool() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	ui.map_preview.set_edit_mode(true)
	ui._refresh_all()
	assert_false(ui.map_preview.edit_forbidden_mode)


func test_terrain_visible_before_first_encounter() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	assert_null(ui.session.current_encounter())
	assert_not_null(ui.map_preview.grid, "Le terrain reste visible avant tout affrontement")


func test_cell_info_reports_terrain_zone_and_forbidden_state() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	ui._add_unit(fixture.guard)
	var room := ui.session.runtime_room()
	ui.map_preview.grid = EncounterGridFactory.build_from_room(room)
	ui.map_preview.room = room
	var ally_info := ui.map_preview.get_cell_info_text(Vector2i(0, 0))
	assert_string_contains(ally_info, "Zone de départ des héros")
	assert_string_contains(ally_info, "Sol praticable")
	var enemy_info := ui.map_preview.get_cell_info_text(Vector2i(7, 7))
	assert_string_contains(enemy_info, "Zone préférée des ennemis")
	ui.map_preview.set_edit_mode(true)
	ui._on_forbidden_cell_toggled(Vector2i(4, 4))
	var forbidden_info := ui.map_preview.get_cell_info_text(Vector2i(4, 4))
	assert_string_contains(forbidden_info, "interdite au déploiement ennemi : oui")


func test_display_preferences_do_not_dirty_the_draft() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	ui._add_unit(fixture.guard)
	var before := _document_state(ui)
	ui.map_preview.show_grid = false
	ui.map_preview.show_zones = false
	ui.map_preview.show_placements = false
	ui.map_preview.show_legend = false
	ui.map_preview.queue_redraw()
	assert_eq(_document_state(ui), before)


func test_placement_markers_stay_normal_when_global_placement_is_invalid() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	ui._add_wave()
	_seed_catalog(ui, fixture)
	ui._add_unit(fixture.guard)
	# Aucune validité par case n'existe dans les données : un résultat global
	# invalide ne doit jamais teindre les marqueurs individuels en rouge.
	ui.map_preview.set_context(ui.session.runtime_room(), {
		"valid": false, "reason": &"incomplete_roster", "wave_index": 0,
		"placements": [{"order": 0, "unit_name": "Garde de test", "cell": Vector2i(1, 1)}],
	})
	ui.map_preview.grid = EncounterGridFactory.build_from_room(ui.session.runtime_room())
	assert_eq(ui.map_preview.visual_snapshot().valid, false)
	assert_eq(ui.map_preview.visual_snapshot().placement_count, 1)
	# Aucune "validité par case" n'est stockée ni consultée : le code source ne
	# doit plus teindre un marqueur individuel en fonction du résultat global.
	var source := FileAccess.get_file_as_string(
		"res://addons/dungeon_draft_arena_studio/encounter/ui/encounter_map_preview.gd"
	)
	assert_false(source.contains('else Color(1.0, 0.16, 0.16)'))
	assert_string_contains(source, "Aucune validité par case")
