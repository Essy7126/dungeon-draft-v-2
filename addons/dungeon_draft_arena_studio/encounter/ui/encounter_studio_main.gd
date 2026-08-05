@tool
class_name EncounterStudioMain
extends Control

signal open_arena_requested

const FORMATION_LABELS := {
	&"line": "Ligne",
	&"double_line": "Double ligne",
	&"left_flank": "Flanc gauche",
	&"right_flank": "Flanc droit",
	&"chief_forward": "Chefs en premiere ligne",
	&"centurion_rear": "Centurions a l'arriere",
	&"split": "Deux groupes",
}

var editor_interface = null
var editor_undo_redo = null
var session := EncounterEditSession.new()
var project_graph := {}
var enemy_catalog: Array[UnitData] = []
var preview_result := {}
var analysis_result := {}
var last_test_result := {}
var analysis_service := EncounterSeedAnalysisService.new()
var _fallback_undo_redo := UndoRedo.new()
var _last_history_object: Object = null
var _syncing := false
var _pending_shared_action: Callable

var title_label: Label
var status_label: Label
var run_tree: Tree
var timeline: HBoxContainer
var map_preview: EncounterMapPreview
var properties_tabs: TabContainer
var composition_box: VBoxContainer
var placement_box: VBoxContainer
var progression_text: RichTextLabel
var analysis_text: RichTextLabel
var analysis_progress: ProgressBar
var advanced_text: RichTextLabel
var validation_list: ItemList
var catalog_search: LineEdit
var catalog_list: ItemList
var seed_spin: SpinBox
var open_dialog: FileDialog
var save_dialog: ConfirmationDialog
var shared_dialog: ConfirmationDialog
var shared_duplicate_button: Button


func setup(host_editor_interface, undo_manager) -> void:
	editor_interface = host_editor_interface
	editor_undo_redo = undo_manager


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	_build_dialogs()
	analysis_service.progress_changed.connect(_on_analysis_progress)
	map_preview.forbidden_cell_toggled.connect(_on_forbidden_cell_toggled)
	if editor_interface != null:
		var filesystem = editor_interface.get_resource_filesystem()
		if filesystem != null and not filesystem.filesystem_changed.is_connected(
			_on_filesystem_changed
		):
			filesystem.filesystem_changed.connect(_on_filesystem_changed)
	call_deferred("_discover_default_run")


func _exit_tree() -> void:
	analysis_service.cancel()
	if editor_interface != null:
		var filesystem = editor_interface.get_resource_filesystem()
		if filesystem != null and filesystem.filesystem_changed.is_connected(
			_on_filesystem_changed
		):
			filesystem.filesystem_changed.disconnect(_on_filesystem_changed)


func _build_interface() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 5)
	add_child(root)
	root.add_child(_build_toolbar())

	var vertical := VSplitContainer.new()
	vertical.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vertical.split_offset = -155
	root.add_child(vertical)
	var horizontal := HSplitContainer.new()
	horizontal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal.split_offset = 230
	vertical.add_child(horizontal)
	horizontal.add_child(_build_run_panel())
	var center_right := HSplitContainer.new()
	center_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_right.split_offset = -390
	horizontal.add_child(center_right)
	center_right.add_child(_build_center_panel())
	center_right.add_child(_build_properties_panel())
	vertical.add_child(_build_validation_panel())

	status_label = Label.new()
	status_label.text = "Initialisation du Studio de rencontres..."
	status_label.custom_minimum_size.y = 25
	status_label.add_theme_color_override("font_color", Color(0.74, 0.84, 0.94))
	root.add_child(status_label)


func _build_toolbar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 50
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 5)
	panel.add_child(bar)
	title_label = Label.new()
	title_label.text = "STUDIO DE RENCONTRES"
	title_label.custom_minimum_size.x = 245
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.5, 0.88, 1.0))
	bar.add_child(title_label)
	_add_button(bar, "Ouvrir une run", _show_open_dialog, "folder")
	_add_button(bar, "Sauvegarder", _show_save_dialog, "save")
	_add_button(bar, "Annuler", _undo, "undo")
	_add_button(bar, "Retablir", _redo, "redo")
	_add_button(bar, "Valider", validate_session, "validate")
	_add_button(bar, "Generer un placement", generate_preview, "preview")
	_add_button(bar, "▶ Tester", test_current_encounter, "test")
	_add_button(bar, "Rapport", export_report, "report")
	return panel


func _build_run_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 220
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_section("RUN / SALLES"))
	run_tree = Tree.new()
	run_tree.hide_root = false
	run_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	run_tree.item_selected.connect(_on_tree_selected)
	box.add_child(run_tree)
	_add_button(box, "Convertir en vagues data-driven", _migrate_current_room)
	_add_button(box, "Restaurer la derniere recuperation", _restore_latest_recovery)
	return panel


func _build_center_panel() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview_toolbar := HBoxContainer.new()
	preview_toolbar.add_child(_section("PREVISUALISATION MAP"))
	var seed_label := Label.new()
	seed_label.text = "Seed de run"
	preview_toolbar.add_child(seed_label)
	seed_spin = SpinBox.new()
	seed_spin.min_value = -2_147_483_648
	seed_spin.max_value = 2_147_483_647
	seed_spin.allow_greater = true
	seed_spin.allow_lesser = true
	seed_spin.custom_minimum_size.x = 135
	seed_spin.value_changed.connect(func(_value):
		if not _syncing: generate_preview()
	)
	preview_toolbar.add_child(seed_spin)
	_add_button(preview_toolbar, "Ouvrir dans Arena Studio", func(): open_arena_requested.emit())
	box.add_child(preview_toolbar)
	map_preview = EncounterMapPreview.new()
	map_preview.custom_minimum_size = Vector2(430, 310)
	map_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(map_preview)
	box.add_child(_section("TIMELINE DES AFFRONTEMENTS"))
	var timeline_scroll := ScrollContainer.new()
	timeline_scroll.custom_minimum_size.y = 78
	timeline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	timeline_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	timeline = HBoxContainer.new()
	timeline.add_theme_constant_override("separation", 5)
	timeline_scroll.add_child(timeline)
	box.add_child(timeline_scroll)
	var actions := HBoxContainer.new()
	_add_button(actions, "+ Ajouter", _add_wave)
	_add_button(actions, "Dupliquer", _duplicate_wave)
	_add_button(actions, "Supprimer", _remove_wave)
	_add_button(actions, "←", func(): _move_wave(-1))
	_add_button(actions, "→", func(): _move_wave(1))
	_add_button(actions, "Dupliquer la rencontre", _duplicate_encounter_for_usage)
	box.add_child(actions)
	return box


func _build_properties_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 355
	properties_tabs = TabContainer.new()
	panel.add_child(properties_tabs)
	composition_box = _scroll_page("Composition")
	placement_box = _scroll_page("Placement")
	progression_text = _rich_page("Progression")
	var analysis_page := VBoxContainer.new()
	analysis_page.name = "Analyse"
	var presets := HBoxContainer.new()
	_add_button(presets, "10 seeds", func(): analyze_seeds(10))
	_add_button(presets, "100 seeds", func(): analyze_seeds(100))
	_add_button(presets, "1 000 seeds", func(): analyze_seeds(1000))
	_add_button(presets, "Annuler", func(): analysis_service.cancel())
	analysis_page.add_child(presets)
	analysis_progress = ProgressBar.new()
	analysis_progress.max_value = 100
	analysis_page.add_child(analysis_progress)
	analysis_text = RichTextLabel.new()
	analysis_text.bbcode_enabled = true
	analysis_text.fit_content = false
	analysis_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	analysis_page.add_child(analysis_text)
	properties_tabs.add_child(analysis_page)
	advanced_text = _rich_page("Avance")
	return panel


func _build_validation_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 145
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_section("ERREURS / AVERTISSEMENTS / INFORMATIONS"))
	validation_list = ItemList.new()
	validation_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	validation_list.item_activated.connect(_on_validation_activated)
	box.add_child(validation_list)
	return panel


func _build_dialogs() -> void:
	open_dialog = FileDialog.new()
	open_dialog.title = "Ouvrir une RunData"
	open_dialog.access = FileDialog.ACCESS_RESOURCES
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.filters = PackedStringArray(["*.tres, *.res ; RunData"])
	open_dialog.current_dir = "res://data/runs"
	open_dialog.file_selected.connect(open_run)
	add_child(open_dialog)

	save_dialog = ConfirmationDialog.new()
	save_dialog.title = "Sauvegarde sure de la session"
	save_dialog.ok_button_text = "Sauvegarder les fichiers listes"
	save_dialog.confirmed.connect(_save_confirmed)
	add_child(save_dialog)

	shared_dialog = ConfirmationDialog.new()
	shared_dialog.title = "Rencontre partagee"
	shared_dialog.ok_button_text = "Modifier la rencontre partagee"
	shared_dialog.cancel_button_text = "Annuler"
	shared_duplicate_button = shared_dialog.add_button(
		"Dupliquer pour cet affrontement", true, "duplicate"
	)
	shared_dialog.confirmed.connect(_confirm_shared_edit)
	shared_dialog.custom_action.connect(_on_shared_custom_action)
	add_child(shared_dialog)


func _discover_default_run() -> void:
	enemy_catalog = StudioResourceCatalog.load_enemy_units()
	var paths := StudioResourceCatalog.find_run_paths()
	if paths.is_empty():
		_set_status("Aucune RunData detectee dans le projet.", true)
		return
	var selected := paths[0]
	for path in paths:
		if path.ends_with("/first_run.tres") or path.ends_with("/run_default.tres"):
			selected = path
			break
	open_run(selected)


func open_run(path: String) -> bool:
	var run := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as RunData
	if run == null or not session.open(run, path):
		_set_status("Le fichier selectionne n'est pas une RunData exploitable.", true)
		return false
	project_graph = EncounterReferenceGraphService.build_project_graph()
	_syncing = true
	seed_spin.value = run.default_seed
	_syncing = false
	_refresh_all()
	_set_status("Run ouverte en copie de travail : %s" % run.run_name)
	return true


func _refresh_all() -> void:
	if session.working_run == null:
		return
	_syncing = true
	_refresh_run_tree()
	_refresh_timeline()
	_refresh_composition()
	_refresh_placement()
	_refresh_progression()
	_refresh_advanced()
	_syncing = false
	generate_preview()
	validate_session()
	_refresh_title()


func _refresh_run_tree() -> void:
	run_tree.clear()
	var root := run_tree.create_item()
	root.set_text(0, "%s\n%d–%d min • plafond %d" % [
		session.working_run.run_name,
		session.working_run.target_duration_minutes,
		session.working_run.extended_duration_minutes,
		session.working_run.maximum_waves_per_room,
	])
	root.set_metadata(0, -1)
	for index in range(session.working_run.rooms.size()):
		var room := session.working_run.rooms[index]
		var item := run_tree.create_item(root)
		if room == null:
			item.set_text(0, "%d. Salle absente" % (index + 1))
		else:
			var map_type := "Map peinte" if room.painted_map_visual_data != null \
				else "Map scene"
			item.set_text(0, "%d. %s\n%s • %s • %d [%d–%d]" % [
				index + 1, room.room_name, map_type, session.room_mode_label(room),
				room.get_wave_count(), room.minimum_wave_count, room.maximum_wave_count,
			])
		item.set_metadata(0, index)
		if index == session.selected_room_index:
			item.select(0)
	root.set_collapsed(false)


func _refresh_timeline() -> void:
	_clear_children(timeline)
	var room := session.current_room()
	if room == null:
		return
	var count := maxi(1, room.get_wave_count())
	for index in count:
		var wave := room.get_wave(index)
		var encounter := room.get_encounter_for_wave(index)
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = index == session.selected_wave_index
		button.custom_minimum_size = Vector2(150, 64)
		var name := wave.wave_name if wave != null else "Rencontre historique"
		button.text = "%d — %s\n%d ennemi(s)%s" % [
			index + 1,
			name,
			encounter.get_initial_enemy_count() if encounter != null else room.enemies.size(),
			" • PARTAGEE" if _usage_count(encounter) > 1 else "",
		]
		button.tooltip_text = _wave_tooltip(wave, encounter)
		button.pressed.connect(func():
			if _syncing:
				return
			session.select(session.selected_room_index, index)
			_refresh_all()
		)
		timeline.add_child(button)


func _refresh_composition() -> void:
	_clear_children(composition_box)
	var room := session.current_room()
	var wave := session.current_wave()
	var encounter := session.current_encounter()
	if room == null:
		return
	composition_box.add_child(_section(session.room_mode_label()))
	if wave != null:
		_add_line_edit(composition_box, "Nom de l'affrontement", wave.wave_name, func(value):
			_set_property(wave, &"wave_name", value, "Renommer l'affrontement")
		)
		_add_float_spin(composition_box, "PV ennemis ×", wave.enemy_health_multiplier, 0.1, 5.0, func(value):
			_set_property(wave, &"enemy_health_multiplier", value, "Modifier le multiplicateur de PV")
		)
		_add_float_spin(composition_box, "Attaque ennemie ×", wave.enemy_attack_multiplier, 0.1, 5.0, func(value):
			_set_property(wave, &"enemy_attack_multiplier", value, "Modifier le multiplicateur d'attaque")
		)
		_add_float_spin(composition_box, "Recompense ×", wave.reward_multiplier, 0.0, 10.0, func(value):
			_set_property(wave, &"reward_multiplier", value, "Modifier le multiplicateur de recompense")
		)
	if encounter == null:
		composition_box.add_child(_wrapped_label("Aucune EncounterDefinition pour cet affrontement."))
		return
	var usage := _usage_summary(encounter)
	var shared := _wrapped_label(
		"Ressource %s • %d affrontement(s), %d salle(s)" % [
			"externe" if usage.external else "integree",
			usage.usage_count, usage.room_count,
		]
	)
	shared.add_theme_color_override(
		"font_color", Color(1.0, 0.72, 0.3) if usage.usage_count > 1 else Color(0.7, 0.9, 0.75)
	)
	composition_box.add_child(shared)
	composition_box.add_child(_section("Composition ennemie"))
	for index in range(encounter.roster_units.size()):
		_add_roster_row(encounter, index)
	composition_box.add_child(_section("Catalogue des UnitData ennemies"))
	catalog_search = LineEdit.new()
	catalog_search.placeholder_text = "Rechercher par nom, faction ou role"
	catalog_search.text_changed.connect(_filter_catalog)
	composition_box.add_child(catalog_search)
	catalog_list = ItemList.new()
	catalog_list.custom_minimum_size.y = 145
	catalog_list.item_activated.connect(_on_catalog_activated)
	composition_box.add_child(catalog_list)
	_filter_catalog("")
	composition_box.add_child(_section("Presence et invocations"))
	_add_int_spin(composition_box, "Plafond vivant simultane", encounter.living_enemy_cap, 0, 99, func(value):
		_edit_encounter_property(&"living_enemy_cap", value, "Modifier le plafond vivant")
	)
	_add_int_spin(composition_box, "Budget total — invocations normales", encounter.shared_normal_summon_budget, 0, 99, func(value):
		_edit_encounter_property(&"shared_normal_summon_budget", value, "Modifier le budget normal")
	)
	_add_int_spin(composition_box, "Budget total — invocations de chef", encounter.shared_chief_summon_budget, 0, 99, func(value):
		_edit_encounter_property(&"shared_chief_summon_budget", value, "Modifier le budget de chef")
	)
	composition_box.add_child(_wrapped_label(
		"Ennemis initiaux : %d • Total theorique apparu : %d" % [
			encounter.get_initial_enemy_count(),
			encounter.get_initial_enemy_count() + encounter.shared_normal_summon_budget \
				+ encounter.shared_chief_summon_budget,
		]
	))
	_refresh_disabled_abilities(encounter)


func _refresh_placement() -> void:
	_clear_children(placement_box)
	var encounter := session.current_encounter()
	if encounter == null:
		return
	placement_box.add_child(_section("Formations autorisees"))
	for formation_id in EncounterDefinition.FORMATION_IDS:
		var checkbox := CheckBox.new()
		checkbox.text = FORMATION_LABELS.get(formation_id, str(formation_id))
		checkbox.tooltip_text = "Identifiant runtime : %s" % formation_id
		checkbox.button_pressed = encounter.formation_profiles.has(formation_id)
		checkbox.toggled.connect(func(enabled): _toggle_formation(formation_id, enabled))
		placement_box.add_child(checkbox)
	_add_int_spin(placement_box, "Tentatives maximales", encounter.maximum_formation_attempts, 1, 99, func(value):
		_edit_encounter_property(&"maximum_formation_attempts", value, "Modifier les tentatives de formation")
	)
	_add_int_spin(placement_box, "Voisins libres requis autour des invocateurs", encounter.summon_free_neighbor_requirement, 0, 8, func(value):
		_edit_encounter_property(&"summon_free_neighbor_requirement", value, "Modifier les voisins libres requis")
	)
	placement_box.add_child(_section("Distances a la zone de deploiement alliee"))
	var roles := {}
	for role in encounter.minimum_path_distance_by_role:
		roles[role] = true
	for role in encounter.maximum_path_distance_by_role:
		roles[role] = true
	for unit in encounter.roster_units:
		if unit != null and unit.tactical_role_id != &"":
			roles[unit.tactical_role_id] = true
	for role_value in roles:
		var role := StringName(role_value)
		placement_box.add_child(_section(str(role)))
		_add_int_spin(placement_box, "Distance minimale obligatoire", int(encounter.minimum_path_distance_by_role.get(role, 0)), 0, 99, func(value):
			_set_role_distance(true, role, value)
		)
		_add_int_spin(placement_box, "Distance maximale souhaitee", int(encounter.maximum_path_distance_by_role.get(role, 0)), 0, 99, func(value):
			_set_role_distance(false, role, value)
		)
	placement_box.add_child(_wrapped_label(
		"ZONE ENNEMIE PREFEREE : le planificateur privilegie ces cellules, mais peut utiliser d'autres cases praticables lorsque les contraintes de formation l'exigent."
	))
	placement_box.add_child(_wrapped_label(
		"CASES INTERDITES AU DEPLOIEMENT ENNEMI : exclusions strictes. Cliquez directement sur la map pour les modifier."
	))


func _refresh_progression() -> void:
	if progression_text == null or session.current_room() == null:
		return
	var room := session.current_room()
	var grid := EncounterGridFactory.build_from_room(room)
	var walkable := 0
	if grid != null:
		for y in grid.rows:
			for x in grid.cols:
				walkable += 1 if grid.is_walkable(Vector2i(x, y)) else 0
	var current := EncounterWaveComparisonService.metrics(
		room, session.selected_wave_index, walkable
	)
	var previous := EncounterWaveComparisonService.metrics(
		room, session.selected_wave_index - 1, walkable
	) if session.selected_wave_index > 0 else {}
	var comparison := EncounterWaveComparisonService.compare(previous, current)
	var projection := EncounterRunProjectionService.project(
		session.working_run, int(seed_spin.value), 100
	)
	progression_text.text = "[b]METRIQUES STRUCTURELLES — pas de score de difficulte[/b]\n\n%s\n\n[b]Evolution[/b]\n%s\n\n[b]Projection de run (100 seeds)[/b]\n%s" % [
		JSON.stringify(current, "  "),
		JSON.stringify(comparison, "  "),
		JSON.stringify(projection, "  "),
	]


func _refresh_advanced() -> void:
	if advanced_text == null:
		return
	var encounter := session.current_encounter()
	var source := session.source_encounter()
	advanced_text.text = "[b]Informations techniques[/b]\n\nRun : %s\nSalle : %s\nRencontre : %s\nroom_index : %s\nallowed_spawn_groups : %s\n\n[b]Usages[/b]\n%s\n\n[i]allowed_spawn_groups n'est pas consomme par le runtime actuel.[/i]" % [
		session.source_run_path,
		(session.source_for(session.current_room()) as Resource).resource_path \
			if session.source_for(session.current_room()) != null else "copie de travail",
		source.resource_path if source != null else str(session.new_resource_paths.get(encounter, "copie de travail")),
		encounter.room_index if encounter != null else "—",
		str(encounter.allowed_spawn_groups) if encounter != null else "—",
		JSON.stringify(_usage_summary(encounter), "  ") if encounter != null else "—",
	]


func generate_preview() -> Dictionary:
	var room := session.current_room()
	var encounter := session.current_encounter()
	if room == null or encounter == null:
		preview_result = {}
		map_preview.set_context(room, preview_result)
		return preview_result
	preview_result = EncounterPreviewService.generate(
		room, encounter, int(seed_spin.value),
		session.selected_room_index, session.selected_wave_index
	)
	map_preview.set_context(room, preview_result)
	_set_status(
		"Placement %s • seed effective %d • formation %s" % [
			"valide" if preview_result.get("valid", false) else "impossible",
			int(preview_result.get("effective_seed", 0)),
			str(preview_result.get("formation_id", preview_result.get("reason", &""))),
		],
		not preview_result.get("valid", false),
	)
	return preview_result


func validate_session() -> Array[StudioValidationMessage]:
	var messages := EncounterValidationService.validate_session(
		session, int(seed_spin.value)
	)
	validation_list.clear()
	for index in range(messages.size()):
		var message := messages[index]
		validation_list.add_item(message.display_text())
		validation_list.set_item_tooltip(index, "%s\nCode : %s\n%s" % [
			message.explanation, message.code, message.resource_path,
		])
		validation_list.set_item_metadata(index, index)
		match message.severity:
			StudioValidationMessage.Severity.ERROR:
				validation_list.set_item_custom_fg_color(index, Color(1.0, 0.36, 0.32))
			StudioValidationMessage.Severity.WARNING:
				validation_list.set_item_custom_fg_color(index, Color(1.0, 0.76, 0.3))
			_:
				validation_list.set_item_custom_fg_color(index, Color(0.58, 0.82, 1.0))
	var summary := EncounterValidationService.summary(messages)
	_set_status("Validation : %d erreur(s), %d avertissement(s)." % [
		summary.errors, summary.warnings,
	], summary.errors > 0)
	return messages


func analyze_seeds(count: int) -> void:
	var room := session.current_room()
	var encounter := session.current_encounter()
	if room == null or encounter == null:
		return
	analysis_progress.max_value = count
	analysis_progress.value = 0
	analysis_text.text = "Analyse du vrai planificateur en cours..."
	analysis_result = await analysis_service.analyze(
		room, encounter, int(seed_spin.value), count,
		session.selected_room_index, session.selected_wave_index
	)
	analysis_text.text = _format_analysis(analysis_result)
	validate_session()


func test_current_encounter() -> Dictionary:
	var result := EncounterTestLauncher.prepare_and_launch(
		session, editor_interface, int(seed_spin.value)
	)
	_set_status(
		"Test direct lance dans le vrai runtime." if result.get("ok", false) \
		else "Test direct impossible : %s" % result.get("error", "inconnu"),
		not result.get("ok", false),
	)
	return result


func export_report() -> Dictionary:
	last_test_result = EncounterTestLauncher.load_last_result()
	var result := EncounterReportExporter.export_report(
		session, preview_result, analysis_result, last_test_result
	)
	if result.get("ok", false):
		DisplayServer.clipboard_set(str(result.get("markdown", "")))
		_set_status("Rapport Markdown et JSON exporte ; Markdown copie dans le presse-papiers.")
	else:
		_set_status("Export impossible : %s" % result.get("error", "inconnu"), true)
	return result


func get_state_snapshot() -> Dictionary:
	return {
		"run_path": session.source_run_path,
		"room_index": session.selected_room_index,
		"wave_index": session.selected_wave_index,
		"seed": int(seed_spin.value) if seed_spin != null else 1337,
		"properties_tab": properties_tabs.current_tab if properties_tabs != null else 0,
	}


func apply_state_snapshot(state: Dictionary) -> void:
	var path := str(state.get("run_path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		open_run(path)
		session.select(
			int(state.get("room_index", 0)), int(state.get("wave_index", 0))
		)
		seed_spin.value = int(state.get("seed", session.working_run.default_seed))
		properties_tabs.current_tab = int(state.get("properties_tab", 0))
		_refresh_all()


func _show_open_dialog() -> void:
	open_dialog.popup_centered_ratio(0.72)


func _show_save_dialog() -> void:
	if not session.is_dirty():
		_set_status("Aucun changement a sauvegarder.")
		return
	var paths := session.affected_paths()
	save_dialog.dialog_text = "FICHIERS MODIFIES / CREES\n\n%s\n\nUne recuperation sera creee sous user:// avant toute ecriture." % "\n".join(paths)
	save_dialog.popup_centered(Vector2i(720, 430))


func _save_confirmed() -> void:
	var result := EncounterSaveService.save(session)
	if result.get("ok", false):
		if editor_interface != null:
			editor_interface.get_resource_filesystem().scan()
		_set_status("Sauvegarde verifiee : %d fichier(s)." % (result.get("saved_paths", []) as Array).size())
		_refresh_title()
	else:
		_set_status("Sauvegarde arretee : %s" % result.get("error", "inconnu"), true)


func _restore_latest_recovery() -> void:
	var result := EncounterSaveService.restore_latest(session)
	if result.get("ok", false):
		_refresh_all()
		_set_status(
			"Session restauree depuis %s. Verifiez puis sauvegardez pour confirmer." \
			% result.get("recovery_path", "")
		)
	else:
		_set_status(
			"Restauration impossible : %s" % result.get("error", "inconnu"), true
		)


func _on_tree_selected() -> void:
	if _syncing:
		return
	var item := run_tree.get_selected()
	if item == null:
		return
	var room_index := int(item.get_metadata(0))
	if room_index >= 0 and session.select(room_index, 0):
		# Tree interdit clear/create_item pendant son signal de selection.
		call_deferred("_refresh_all")


func _on_forbidden_cell_toggled(cell: Vector2i) -> void:
	var encounter := session.current_encounter()
	if encounter == null:
		return
	_ensure_editable(func():
		var cells: Array[Vector2i] = encounter.forbidden_initial_spawn_cells.duplicate()
		if cells.has(cell):
			cells.erase(cell)
		else:
			cells.append(cell)
		_set_property(encounter, &"forbidden_initial_spawn_cells", cells, "Modifier les cases interdites")
	)


func _add_roster_row(encounter: EncounterDefinition, index: int) -> void:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	var unit := encounter.roster_units[index]
	var label := Label.new()
	label.text = unit.unit_name if unit != null else "UnitData absente"
	label.tooltip_text = "%s • %s • %s" % [
		unit.resource_path if unit != null else "",
		unit.faction_id if unit != null else &"",
		unit.tactical_role_id if unit != null else &"",
	]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(label)
	var row := HBoxContainer.new()
	var quantity := SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 99
	quantity.value = encounter.roster_counts[index] if index < encounter.roster_counts.size() else 1
	quantity.custom_minimum_size.x = 72
	quantity.value_changed.connect(func(value): _change_quantity(index, int(value)))
	row.add_child(quantity)
	_add_button(row, "−", func(): _change_quantity(index, maxi(1, int(quantity.value) - 1)))
	_add_button(row, "+", func(): _change_quantity(index, int(quantity.value) + 1))
	_add_button(row, "Retirer", func(): _remove_roster_index(index))
	card.add_child(row)
	composition_box.add_child(card)


func _filter_catalog(query: String) -> void:
	if catalog_list == null:
		return
	catalog_list.clear()
	var normalized := query.to_lower().strip_edges()
	for unit in enemy_catalog:
		var haystack := "%s %s %s" % [unit.unit_name, unit.faction_id, unit.tactical_role_id]
		if not normalized.is_empty() and normalized not in haystack.to_lower():
			continue
		var index := catalog_list.add_item("%s — %s • %s • PV %d • PA %d • PM %d • %d sort(s)%s" % [
			unit.unit_name,
			str(unit.faction_id) if unit.faction_id != &"" else "Faction non renseignee",
			str(unit.tactical_role_id) if unit.tactical_role_id != &"" else "Role generique",
			unit.max_hp, unit.max_ap, unit.max_mp, unit.spells.size(),
			" • INVOCATION" if unit.spells.any(func(spell): return spell != null and spell.is_summon()) else "",
		])
		catalog_list.set_item_metadata(index, unit.resource_path)
		catalog_list.set_item_tooltip(index, "Double-cliquez pour ajouter a la composition.")


func _on_catalog_activated(index: int) -> void:
	var path := str(catalog_list.get_item_metadata(index))
	var unit := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as UnitData
	if unit != null:
		_add_unit(unit)


func _add_unit(unit: UnitData) -> void:
	var encounter := session.current_encounter()
	if encounter == null:
		return
	_ensure_editable(func():
		var units: Array[UnitData] = encounter.roster_units.duplicate()
		var counts := encounter.roster_counts.duplicate()
		var index := units.find(unit)
		if index >= 0:
			counts[index] += 1
		else:
			units.append(unit)
			counts.append(1)
		_set_properties(encounter, {
			&"roster_units": units,
			&"roster_counts": counts,
		}, "Ajouter %s" % unit.unit_name)
	)


func _change_quantity(index: int, value: int) -> void:
	if _syncing:
		return
	var encounter := session.current_encounter()
	if encounter == null or index < 0 or index >= encounter.roster_counts.size():
		return
	_ensure_editable(func():
		var counts := encounter.roster_counts.duplicate()
		counts[index] = maxi(1, value)
		_set_property(encounter, &"roster_counts", counts, "Modifier une quantite")
	)


func _remove_roster_index(index: int) -> void:
	var encounter := session.current_encounter()
	if encounter == null or index < 0 or index >= encounter.roster_units.size():
		return
	_ensure_editable(func():
		var units: Array[UnitData] = encounter.roster_units.duplicate()
		var counts := encounter.roster_counts.duplicate()
		units.remove_at(index)
		if index < counts.size(): counts.remove_at(index)
		_set_properties(encounter, {&"roster_units": units, &"roster_counts": counts}, "Retirer une unite")
	)


func _refresh_disabled_abilities(encounter: EncounterDefinition) -> void:
	composition_box.add_child(_section("Capacites desactivees"))
	var abilities := {}
	for unit in encounter.roster_units:
		if unit == null: continue
		for spell in unit.spells:
			if spell != null:
				abilities[spell.get_effective_spell_id()] = spell.spell_name
	for ability_id in abilities:
		var checkbox := CheckBox.new()
		checkbox.text = "%s (%s)" % [abilities[ability_id], ability_id]
		checkbox.button_pressed = encounter.disabled_ability_ids.has(ability_id)
		checkbox.toggled.connect(func(disabled): _toggle_disabled_ability(ability_id, disabled))
		composition_box.add_child(checkbox)


func _toggle_disabled_ability(ability_id: StringName, disabled: bool) -> void:
	if _syncing: return
	var encounter := session.current_encounter()
	_ensure_editable(func():
		var values: Array[StringName] = encounter.disabled_ability_ids.duplicate()
		if disabled and not values.has(ability_id): values.append(ability_id)
		elif not disabled: values.erase(ability_id)
		_set_property(encounter, &"disabled_ability_ids", values, "Modifier les capacites desactivees")
	)


func _toggle_formation(formation_id: StringName, enabled: bool) -> void:
	if _syncing: return
	var encounter := session.current_encounter()
	_ensure_editable(func():
		var values: Array[StringName] = encounter.formation_profiles.duplicate()
		if enabled and not values.has(formation_id): values.append(formation_id)
		elif not enabled: values.erase(formation_id)
		_set_property(encounter, &"formation_profiles", values, "Modifier les formations")
	)


func _set_role_distance(minimum: bool, role: StringName, value: int) -> void:
	if _syncing: return
	var encounter := session.current_encounter()
	_ensure_editable(func():
		var property := &"minimum_path_distance_by_role" if minimum \
			else &"maximum_path_distance_by_role"
		var values: Dictionary = encounter.get(property).duplicate(true)
		values[role] = value
		_set_property(encounter, property, values, "Modifier une distance par role")
	)


func _edit_encounter_property(property: StringName, value, action_name: String) -> void:
	if _syncing: return
	var encounter := session.current_encounter()
	if encounter != null:
		_ensure_editable(func(): _set_property(encounter, property, value, action_name))


func _set_property(target: Object, property: StringName, value, action_name: String) -> void:
	_set_properties(target, {property: value}, action_name)


func _set_properties(target: Object, values: Dictionary, action_name: String) -> void:
	if target == null:
		return
	if editor_undo_redo != null:
		_last_history_object = target
		editor_undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, target)
		for property in values:
			editor_undo_redo.add_do_property(target, property, values[property])
			editor_undo_redo.add_undo_property(target, property, target.get(property))
		editor_undo_redo.add_do_method(self, "_after_change", target)
		editor_undo_redo.add_undo_method(self, "_after_change", target)
		editor_undo_redo.commit_action()
	else:
		_last_history_object = target
		_fallback_undo_redo.create_action(action_name)
		for property in values:
			_fallback_undo_redo.add_do_property(target, property, values[property])
			_fallback_undo_redo.add_undo_property(target, property, target.get(property))
		_fallback_undo_redo.add_do_method(
			Callable(self, "_after_change").bind(target)
		)
		_fallback_undo_redo.add_undo_method(
			Callable(self, "_after_change").bind(target)
		)
		_fallback_undo_redo.commit_action()


func _after_change(target: Object) -> void:
	if target is Resource:
		session.mark_dirty(target)
	if target is RoomWaveData:
		session.mark_dirty(session.current_room())
	_prune_unreferenced_new_encounters()
	call_deferred("_refresh_after_edit")


func _prune_unreferenced_new_encounters() -> void:
	if session.working_run == null:
		return
	var referenced := {}
	for room_value in session.working_run.rooms:
		var room := room_value as RoomData
		if room == null:
			continue
		if room.encounter_definition != null:
			referenced[room.encounter_definition] = true
		for wave in room.waves:
			if wave != null and wave.encounter_definition != null:
				referenced[wave.encounter_definition] = true
	for resource_value in session.new_resource_paths.keys():
		if resource_value is EncounterDefinition and not referenced.has(resource_value):
			session.new_resource_paths.erase(resource_value)


func _refresh_after_edit() -> void:
	_refresh_composition()
	_refresh_placement()
	_refresh_timeline()
	_refresh_progression()
	_refresh_advanced()
	generate_preview()
	validate_session()
	_refresh_title()


func _ensure_editable(action: Callable) -> void:
	var encounter := session.current_encounter()
	var usage := _usage_summary(encounter)
	var key := str(usage.key)
	if encounter == null or usage.usage_count <= 1 \
			or session.shared_edit_acknowledged.has(key) \
			or session.new_resource_paths.has(encounter):
		action.call()
		return
	_pending_shared_action = action
	shared_dialog.dialog_text = "Cette EncounterDefinition est utilisee par %d affrontements dans %d salles.\n\nModifier la rencontre partagee affectera tous ses usages.\n\nAction recommandee : DUPLIQUER POUR CET AFFRONTEMENT." % [usage.usage_count, usage.room_count]
	shared_dialog.popup_centered(Vector2i(650, 360))
	shared_duplicate_button.grab_focus.call_deferred()


func _confirm_shared_edit() -> void:
	var encounter := session.current_encounter()
	session.shared_edit_acknowledged[str(_usage_summary(encounter).key)] = true
	if _pending_shared_action.is_valid():
		_pending_shared_action.call()
	_pending_shared_action = Callable()


func _on_shared_custom_action(action: StringName) -> void:
	if action != &"duplicate":
		return
	shared_dialog.hide()
	_duplicate_encounter_for_usage()
	if _pending_shared_action.is_valid():
		_pending_shared_action.call()
	_pending_shared_action = Callable()


func _duplicate_encounter_for_usage() -> void:
	var old := session.current_encounter()
	var room := session.current_room()
	if old == null or room == null:
		return
	var copy := EncounterCopyService.copy_encounter(old)
	session.new_resource_paths[copy] = EncounterCopyService.suggested_path(
		room, session.selected_wave_index
	)
	var wave := session.current_wave()
	if wave != null:
		_set_property(wave, &"encounter_definition", copy, "Dupliquer la rencontre pour cet affrontement")
		session.mark_dirty(room)
	else:
		_set_property(room, &"encounter_definition", copy, "Dupliquer la rencontre pour cette salle")
	_set_status("Copie independante creee en session ; l'original reste intact.")


func _add_wave() -> void:
	var room := session.current_room()
	if room == null: return
	var waves: Array[RoomWaveData] = room.waves.duplicate()
	var wave := RoomWaveData.new()
	wave.wave_name = "Affrontement %d" % (waves.size() + 1)
	if not waves.is_empty():
		var previous := waves.back()
		wave = EncounterCopyService.copy_wave(previous)
		wave.wave_name = "Affrontement %d — copie independante" % (waves.size() + 1)
		wave.encounter_definition = EncounterCopyService.copy_encounter(previous.encounter_definition)
	else:
		wave.encounter_definition = EncounterCopyService.copy_encounter(room.encounter_definition) \
			if room.encounter_definition != null else EncounterDefinition.new()
	wave.encounter_definition.room_index = session.selected_room_index + 1
	session.new_resource_paths[wave.encounter_definition] = EncounterCopyService.suggested_path(room, waves.size())
	waves.append(wave)
	_set_property(room, &"waves", waves, "Ajouter un affrontement")
	session.selected_wave_index = waves.size() - 1


func _duplicate_wave() -> void:
	var room := session.current_room()
	var current := session.current_wave()
	if room == null or current == null: return
	var waves: Array[RoomWaveData] = room.waves.duplicate()
	var copy := EncounterCopyService.copy_wave(current)
	copy.wave_name += " — copie"
	copy.encounter_definition = EncounterCopyService.copy_encounter(current.encounter_definition)
	session.new_resource_paths[copy.encounter_definition] = EncounterCopyService.suggested_path(room, session.selected_wave_index + 1)
	waves.insert(session.selected_wave_index + 1, copy)
	_set_property(room, &"waves", waves, "Dupliquer un affrontement")
	session.selected_wave_index += 1


func _remove_wave() -> void:
	var room := session.current_room()
	if room == null or room.waves.is_empty(): return
	var waves: Array[RoomWaveData] = room.waves.duplicate()
	waves.remove_at(session.selected_wave_index)
	_set_property(room, &"waves", waves, "Supprimer un affrontement sans supprimer sa rencontre")
	session.selected_wave_index = clampi(session.selected_wave_index, 0, maxi(0, waves.size() - 1))


func _move_wave(offset: int) -> void:
	var room := session.current_room()
	if room == null: return
	var target := session.selected_wave_index + offset
	if target < 0 or target >= room.waves.size(): return
	var waves: Array[RoomWaveData] = room.waves.duplicate()
	var wave := waves[session.selected_wave_index]
	waves.remove_at(session.selected_wave_index)
	waves.insert(target, wave)
	_set_property(room, &"waves", waves, "Reordonner les affrontements")
	session.selected_wave_index = target


func _migrate_current_room() -> void:
	var room := session.current_room()
	var preview := EncounterMigrationService.preview(room, session.selected_room_index)
	if not preview.get("available", false):
		_set_status("Migration indisponible : %s" % preview.get("reason", ""), true)
		return
	var report := EncounterMigrationService.migrate_working_room(room, session.selected_room_index)
	if report.get("success", false):
		var encounter := report.get("encounter") as EncounterDefinition
		if encounter.resource_path.is_empty():
			session.new_resource_paths[encounter] = EncounterCopyService.suggested_path(room, 0)
		session.mark_dirty(room)
		_refresh_all()
		_set_status("Migration appliquee uniquement a la copie de travail. Sauvegardez pour confirmer.")


func _on_validation_activated(index: int) -> void:
	if index < 0 or index >= session.validation_messages.size(): return
	var message := session.validation_messages[index]
	if message.room_index >= 0:
		session.select(message.room_index, maxi(0, message.wave_index))
	match message.fix_id:
		&"fit_living_cap":
			_edit_encounter_property(&"living_enemy_cap", session.current_encounter().get_initial_enemy_count(), "Ajuster le plafond vivant")
		&"use_actual_room_index":
			_edit_encounter_property(&"room_index", session.selected_room_index + 1, "Utiliser l'index reel de la salle")
		&"deduplicate_forbidden":
			var encounter := session.current_encounter()
			var unique: Array[Vector2i] = []
			for cell in encounter.forbidden_initial_spawn_cells:
				if not unique.has(cell): unique.append(cell)
			_edit_encounter_property(&"forbidden_initial_spawn_cells", unique, "Retirer les doublons de cases interdites")
	_refresh_all()


func _undo() -> void:
	var history := _active_undo_redo()
	if history != null and history.has_undo():
		history.undo()


func _redo() -> void:
	var history := _active_undo_redo()
	if history != null and history.has_redo():
		history.redo()


func _active_undo_redo() -> UndoRedo:
	if editor_undo_redo == null or _last_history_object == null:
		return _fallback_undo_redo
	var history_id: int = editor_undo_redo.get_object_history_id(
		_last_history_object
	)
	return editor_undo_redo.get_history_undo_redo(history_id)


func _on_analysis_progress(completed: int, total: int, _generation: int) -> void:
	analysis_progress.max_value = maxi(1, total)
	analysis_progress.value = completed


func _on_filesystem_changed() -> void:
	enemy_catalog = StudioResourceCatalog.load_enemy_units()
	project_graph = EncounterReferenceGraphService.build_project_graph()
	if catalog_list != null:
		_filter_catalog(catalog_search.text if catalog_search != null else "")


func _usage_summary(encounter: EncounterDefinition) -> Dictionary:
	if encounter == null:
		return {"key": "missing", "usage_count": 0, "room_count": 0, "external": false, "usages": []}
	var source := session.source_for(encounter) as EncounterDefinition
	if source != null:
		return EncounterReferenceGraphService.summary_for(source, project_graph)
	var working_graph := EncounterReferenceGraphService.build_for_run(
		session.working_run, session.source_run_path
	)
	return EncounterReferenceGraphService.summary_for(encounter, working_graph)


func _usage_count(encounter: EncounterDefinition) -> int:
	return int(_usage_summary(encounter).usage_count) if encounter != null else 0


func _wave_tooltip(wave: RoomWaveData, encounter: EncounterDefinition) -> String:
	return "%s\nPV ×%.2f • Attaque ×%.2f • Recompense ×%.2f\n%s" % [
		"%d ennemi(s)" % encounter.get_initial_enemy_count() if encounter != null else "Rencontre absente",
		wave.enemy_health_multiplier if wave != null else 1.0,
		wave.enemy_attack_multiplier if wave != null else 1.0,
		wave.reward_multiplier if wave != null else 1.0,
		"Rencontre partagee" if _usage_count(encounter) > 1 else "Rencontre unique",
	]


func _format_analysis(report: Dictionary) -> String:
	if report.is_empty(): return "Aucune analyse."
	return "[b]%d seeds analysees[/b] • succes %.1f %% • %d echec(s)%s\n\nFormations : %s\nFormations jamais retenues : %s\nTentatives moyennes : %.2f\nDistances min / moy / max : %s / %s / %s\nDans la zone preferee : %.1f %%\n\nRaisons d'echec : %s\nSeeds problematiques : %s" % [
		report.completed, report.success_rate_percent, report.failures,
		" • ANNULEE" if report.cancelled else "",
		JSON.stringify(report.formations), JSON.stringify(report.formations_never_selected),
		report.average_attempts, str(report.distance_minimum), str(report.distance_average), str(report.distance_maximum),
		report.preferred_percent, JSON.stringify(report.failure_reasons), JSON.stringify(report.problem_seeds),
	]


func _refresh_title() -> void:
	if title_label == null: return
	title_label.text = "STUDIO DE RENCONTRES%s" % (" • MODIFIE" if session.is_dirty() else "")


func _set_status(message: String, error := false) -> void:
	if status_label == null: return
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if error else Color(0.74, 0.84, 0.94))


func _add_button(parent: Control, text: String, callback: Callable, _icon_name := "") -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.58, 0.86, 1.0))
	return label


func _wrapped_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _scroll_page(name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	properties_tabs.add_child(scroll)
	return box


func _rich_page(name: String) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.name = name
	text.bbcode_enabled = true
	text.fit_content = false
	properties_tabs.add_child(text)
	return text


func _add_line_edit(parent: Control, label_text: String, value: String, callback: Callable) -> void:
	var label := Label.new(); label.text = label_text; parent.add_child(label)
	var edit := LineEdit.new(); edit.text = value; edit.text_submitted.connect(callback); edit.focus_exited.connect(func(): callback.call(edit.text)); parent.add_child(edit)


func _add_int_spin(parent: Control, label_text: String, value: int, minimum: int, maximum: int, callback: Callable) -> void:
	var row := HBoxContainer.new(); var label := Label.new(); label.text = label_text; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
	var spin := SpinBox.new(); spin.min_value = minimum; spin.max_value = maximum; spin.step = 1; spin.value = value; spin.value_changed.connect(func(new_value): callback.call(int(new_value))); row.add_child(spin); parent.add_child(row)


func _add_float_spin(parent: Control, label_text: String, value: float, minimum: float, maximum: float, callback: Callable) -> void:
	var row := HBoxContainer.new(); var label := Label.new(); label.text = label_text; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
	var spin := SpinBox.new(); spin.min_value = minimum; spin.max_value = maximum; spin.step = 0.05; spin.value = value; spin.value_changed.connect(callback); row.add_child(spin); parent.add_child(row)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.hide()
		child.queue_free()
