@tool
class_name EncounterStudioMain
extends Control

signal open_arena_requested
signal history_state_changed
signal room_draft_opened

const FORMATION_LABELS := EncounterPresentation.FORMATION_LABELS

var editor_interface = null
var editor_undo_redo = null
var session := EncounterEditSession.new()
var enemy_catalog: Array[UnitData] = []
var preview_result := {}
var analysis_result := {}
var last_test_result := {}
var analysis_service := EncounterSeedAnalysisService.new()
var _fallback_undo_redo := UndoRedo.new()
var _last_history_object: Object = null
var _syncing := false
var _pending_shared_action: Callable
var project_context: StudioProjectContext = null
var shared_reference_graph: StudioReferenceGraphService = null
var _reference_refresh_queued := false
var _reference_scan_queued := false
var _reference_scan_state := "Analyse des usages en cours"
var _pending_navigation := Callable()
var _navigation_token := ""
var _syncing_context := false

var title_label: Label
var encounter_toolbar: Control
var draft_banner: Label
var status_label: Label
var run_tree: Tree
var timeline: HBoxContainer
var timeline_panel: Control
var map_preview: EncounterMapPreview
var properties_tabs: TabContainer
var composition_box: VBoxContainer
var _usage_label: Label
var placement_box: VBoxContainer
var progression_text: RichTextLabel
var analysis_text: RichTextLabel
var analysis_progress: ProgressBar
var technical_text: RichTextLabel
var _progression_details := {}
var _operation_details := {}
var validation_details_dialog: AcceptDialog
var validation_details_text: RichTextLabel
## G5 — cartes de diagnostic compréhensibles ; « Voir » et « Corriger » sont
## des actions distinctes, jamais déclenchées par une simple sélection.
var validation_summary_label: Label
var validation_cards_box: VBoxContainer
var validation_empty_label: Label
var validation_filter_buttons := {}
var _validation_severity_filters := {
	StudioValidationMessage.Severity.ERROR: true,
	StudioValidationMessage.Severity.WARNING: true,
	StudioValidationMessage.Severity.INFO: true,
}
var analysis_presets: Control
var catalog_search: LineEdit
var catalog_cards_box: VBoxContainer
var catalog_empty_label: Label
var catalog_faction_filter_button: OptionButton
var catalog_role_filter_button: OptionButton
var _catalog_search_text := ""
var _catalog_faction_filter: StringName = &""
var _catalog_role_filter: StringName = &""
var _wave_settings_open := false
var _summon_settings_open := false
var _focus_catalog_search_next_refresh := false
var seed_spin: SpinBox
var generate_placement_button: Button
var add_wave_button: Button
var duplicate_wave_button: Button
var edit_terrain_button: Button
var forbidden_tool_toggle: Button
var display_menu_button: MenuButton
var cell_info_label: Label
var open_dialog: FileDialog
var save_dialog: ConfirmationDialog
var shared_dialog: ConfirmationDialog
var shared_duplicate_button: Button
var workspace_split: VSplitContainer
var navigation_split: HSplitContainer
var properties_split: HSplitContainer
var navigation_panel: Control
var properties_panel: Control
var validation_panel: Control
var timeline_scroll: ScrollContainer
var navigation_toggle: Button
var validation_toggle: Button
var properties_navigation: HFlowContainer
# Préférences de disposition uniquement, sérialisées par le workspace existant.
var _navigation_width := 220.0
var _properties_width := 360.0
var _validation_height := 250.0
var _layout_queued := false
var _layout_dragging := false


func setup(
		host_editor_interface,
		undo_manager,
		shared_context: StudioProjectContext = null,
		reference_graph: StudioReferenceGraphService = null
	) -> void:
	editor_interface = host_editor_interface
	editor_undo_redo = undo_manager
	project_context = shared_context
	_disconnect_reference_graph()
	shared_reference_graph = reference_graph
	if shared_reference_graph != null:
		shared_reference_graph.scan_started.connect(_on_reference_scan_started)
		shared_reference_graph.scan_progress.connect(_on_reference_scan_progress)
		shared_reference_graph.scan_completed.connect(_on_reference_scan_completed)
		shared_reference_graph.scan_cancelled.connect(_on_reference_scan_cancelled)
		shared_reference_graph.invalidated.connect(_on_reference_invalidated)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	_build_dialogs()
	analysis_service.progress_changed.connect(_on_analysis_progress)
	map_preview.forbidden_cell_toggled.connect(_on_forbidden_cell_toggled)
	map_preview.cell_selected.connect(_on_cell_selected)
	map_preview.edit_mode_changed.connect(func(active):
		if forbidden_tool_toggle != null:
			forbidden_tool_toggle.set_pressed_no_signal(active)
	)
	if editor_interface != null:
		var filesystem = editor_interface.get_resource_filesystem()
		if filesystem != null and not filesystem.filesystem_changed.is_connected(
			_on_filesystem_changed
		):
			filesystem.filesystem_changed.connect(_on_filesystem_changed)
	call_deferred("_discover_default_run")
	if project_context != null:
		project_context.run_changed.connect(_on_shared_run_changed)
		project_context.room_changed.connect(_on_shared_room_changed)
		project_context.transition_resolved.connect(_on_transition_resolved)
		project_context.register_transition_handler(
			&"encounter", Callable(self, "_context_save"),
			Callable(self, "_context_draft"), Callable(self, "_context_discard"),
			Callable(), Callable(), Callable(self, "_context_rollback"), Callable(session, "is_dirty"),
			Callable(self, "_context_snapshot"), Callable(self, "_context_restore")
		)


func _notification(what: int) -> void:
	# Le workspace quitte brièvement l'arbre lors d'un détachement de fenêtre.
	# Ce n'est pas une fermeture : la session et son contrat doivent rester
	# actifs. Le nettoyage permanent appartient uniquement à PREDELETE.
	if what != NOTIFICATION_PREDELETE:
		return
	analysis_service.cancel()
	_disconnect_reference_graph()
	if project_context != null:
		project_context.unregister_transition_handler(&"encounter")
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
	encounter_toolbar = _build_toolbar()
	root.add_child(encounter_toolbar)

	draft_banner = Label.new()
	draft_banner.name = "EncounterRoomDraftBanner"
	draft_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	draft_banner.add_theme_font_size_override("font_size", 14)
	draft_banner.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	draft_banner.visible = false
	root.add_child(draft_banner)

	timeline_panel = _build_timeline_panel()
	root.add_child(timeline_panel)
	workspace_split = VSplitContainer.new()
	workspace_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(workspace_split)
	navigation_split = HSplitContainer.new()
	navigation_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_split.add_child(navigation_split)
	navigation_panel = _build_run_panel()
	navigation_split.add_child(navigation_panel)
	properties_split = HSplitContainer.new()
	properties_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_split.add_child(properties_split)
	properties_split.add_child(_build_center_panel())
	properties_panel = _build_properties_panel()
	properties_split.add_child(properties_panel)
	validation_panel = _build_validation_panel()
	workspace_split.add_child(validation_panel)
	validation_panel.hide()
	var footer := HBoxContainer.new()
	validation_toggle = _add_button(footer, "Validation", _apply_validation_panel_visibility)
	validation_toggle.toggle_mode = true
	validation_toggle.tooltip_text = "Ouvrir ou replier les erreurs, avertissements et informations"
	# G5 — ce résumé reste visible même quand le panneau est replié : le
	# bouton seul ne doit jamais être la seule façon de savoir s'il reste des
	# problèmes bloquants.
	validation_summary_label = Label.new()
	validation_summary_label.text = "Aucun problème bloquant"
	footer.add_child(validation_summary_label)

	status_label = Label.new()
	status_label.text = "Initialisation du Studio de rencontres..."
	status_label.custom_minimum_size.y = 25
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_color_override("font_color", Color(0.74, 0.84, 0.94))
	footer.add_child(status_label)
	root.add_child(footer)
	navigation_toggle.set_pressed_no_signal(true)
	for split in [workspace_split, navigation_split, properties_split]:
		split.resized.connect(_queue_layout)
		split.drag_started.connect(func(): _layout_dragging = true)
		split.drag_ended.connect(func():
			_layout_dragging = false
			_queue_layout()
		)
	navigation_split.dragged.connect(func(offset):
		_navigation_width = offset
	)
	properties_split.dragged.connect(func(offset):
		_properties_width = -offset
	)
	workspace_split.dragged.connect(func(offset):
		_validation_height = -offset
	)
	_queue_layout()


func _build_toolbar() -> Control:
	var panel := PanelContainer.new()
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 5)
	panel.add_child(bar)
	title_label = Label.new()
	title_label.text = "STUDIO DE RENCONTRES"
	title_label.custom_minimum_size.x = 245
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.5, 0.88, 1.0))
	bar.add_child(title_label)
	navigation_toggle = _add_button(bar, "Partie et salles", func():
		navigation_panel.visible = navigation_toggle.button_pressed
		_queue_layout()
	)
	navigation_toggle.toggle_mode = true
	navigation_toggle.tooltip_text = "Ouvrir ou replier la navigation pour agrandir le terrain"
	_add_button(bar, "Ouvrir une partie", _show_open_dialog, "Folder")
	generate_placement_button = _add_button(
		bar, "Générer un placement", generate_preview, "preview"
	)
	_add_button(bar, "Rapport", export_report, "report")
	return panel


func _build_run_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 180
	panel.size_flags_horizontal = Control.SIZE_FILL
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_section("PARTIE / SALLES"))
	run_tree = Tree.new()
	run_tree.hide_root = false
	run_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	run_tree.item_selected.connect(_on_tree_selected)
	box.add_child(run_tree)
	var convert := _add_button(box, "Convertir en vagues configurables", _migrate_current_room)
	convert.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var restore := _add_button(box, "Restaurer la dernière récupération", _restore_latest_recovery)
	restore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return panel


func _build_center_panel() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview_toolbar := HFlowContainer.new()
	var preview_heading := _section("TERRAIN ET PLACEMENT")
	preview_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	preview_toolbar.add_child(preview_heading)
	var seed_label := Label.new()
	seed_label.text = "Variante de placement"
	seed_label.tooltip_text = (
		"Change la disposition proposée des ennemis sans modifier le terrain."
	)
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
	edit_terrain_button = _add_button(
		preview_toolbar, "Modifier le terrain", func(): open_arena_requested.emit()
	)
	edit_terrain_button.tooltip_text = (
		"Revenir au Studio Terrain. Le terrain reste en lecture seule dans Rencontres."
	)
	forbidden_tool_toggle = _add_button(preview_toolbar, "Modifier les cases interdites", func():
		map_preview.set_edit_mode(forbidden_tool_toggle.button_pressed)
	)
	forbidden_tool_toggle.toggle_mode = true
	forbidden_tool_toggle.tooltip_text = (
		"Par défaut, la carte est en consultation : cliquer une case ne change rien. "
		+ "Activez cet outil pour ajouter ou retirer des cases interdites au "
		+ "déploiement ennemi. Échap l'arrête sans autre changement."
	)
	display_menu_button = MenuButton.new()
	display_menu_button.text = "Affichage"
	display_menu_button.tooltip_text = "Choisir ce que la carte montre, sans modifier la rencontre."
	var display_popup := display_menu_button.get_popup()
	display_popup.hide_on_checkable_item_selection = false
	display_popup.add_check_item("Grille", 0)
	display_popup.set_item_checked(0, true)
	display_popup.add_check_item("Zones", 1)
	display_popup.set_item_checked(1, true)
	display_popup.add_check_item("Placements", 2)
	display_popup.set_item_checked(2, true)
	display_popup.add_check_item("Distances", 3)
	display_popup.set_item_checked(3, true)
	display_popup.add_check_item("Légende", 4)
	display_popup.set_item_checked(4, true)
	display_popup.id_pressed.connect(_on_display_option_pressed)
	preview_toolbar.add_child(display_menu_button)
	box.add_child(preview_toolbar)
	map_preview = EncounterMapPreview.new()
	map_preview.custom_minimum_size = Vector2(320, 100)
	map_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(map_preview)
	cell_info_label = Label.new()
	cell_info_label.text = "Aucune case sélectionnée."
	cell_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cell_info_label.custom_minimum_size.y = 24
	cell_info_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.94))
	box.add_child(cell_info_label)
	return box


func _on_display_option_pressed(id: int) -> void:
	var popup := display_menu_button.get_popup()
	var index := popup.get_item_index(id)
	var value := not popup.is_item_checked(index)
	popup.set_item_checked(index, value)
	match id:
		0: map_preview.show_grid = value
		1: map_preview.show_zones = value
		2: map_preview.show_placements = value
		3: map_preview.show_distances = value
		4: map_preview.show_legend = value
	map_preview.queue_redraw()


func _on_cell_selected(cell: Vector2i) -> void:
	if cell_info_label != null:
		cell_info_label.text = map_preview.get_cell_info_text(cell)


func _build_timeline_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_child(_section("CHRONOLOGIE DES AFFRONTEMENTS"))
	timeline_scroll = ScrollContainer.new()
	timeline_scroll.custom_minimum_size.y = 56
	timeline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	timeline_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	timeline_scroll.follow_focus = true
	timeline = HBoxContainer.new()
	timeline.add_theme_constant_override("separation", 5)
	timeline_scroll.add_child(timeline)
	box.add_child(timeline_scroll)
	var actions := HFlowContainer.new()
	add_wave_button = _add_button(actions, "Ajouter un affrontement", _add_wave)
	duplicate_wave_button = _add_button(actions, "Dupliquer", _duplicate_wave)
	# G6 — action destructrice : identifiable par sa couleur de texte, sans
	# dominer l'écran (pas de fond plein, pas de taille agrandie).
	_add_button(actions, "Supprimer", _remove_wave, "", true)
	var move_left := _add_button(actions, "←", func(): _move_wave(-1))
	move_left.tooltip_text = "Déplacer cet affrontement plus tôt dans la chronologie"
	var move_right := _add_button(actions, "→", func(): _move_wave(1))
	move_right.tooltip_text = "Déplacer cet affrontement plus tard dans la chronologie"
	_add_button(actions, "Dupliquer la rencontre", _duplicate_encounter_for_usage)
	box.add_child(actions)
	return box


func _build_properties_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 320
	panel.size_flags_horizontal = Control.SIZE_FILL
	var column := VBoxContainer.new()
	panel.add_child(column)
	properties_navigation = HFlowContainer.new()
	column.add_child(properties_navigation)
	properties_tabs = TabContainer.new()
	properties_tabs.tabs_visible = false
	properties_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(properties_tabs)
	composition_box = _scroll_page("Composition")
	placement_box = _scroll_page("Placement")
	progression_text = _rich_page("Progression")
	var analysis_page := VBoxContainer.new()
	analysis_page.name = "Analyse"
	var presets := HFlowContainer.new()
	analysis_presets = presets
	var presets_label := Label.new()
	presets_label.text = "Analyser sur"
	presets_label.tooltip_text = "Nombre de valeurs de départ testées"
	presets.add_child(presets_label)
	var preset_10 := _add_button(presets, "10", func(): analyze_seeds(10))
	preset_10.tooltip_text = "Analyser 10 valeurs de départ"
	var preset_100 := _add_button(presets, "100", func(): analyze_seeds(100))
	preset_100.tooltip_text = "Analyser 100 valeurs de départ"
	var preset_1000 := _add_button(presets, "1 000", func(): analyze_seeds(1000))
	preset_1000.tooltip_text = "Analyser 1 000 valeurs de départ"
	_add_button(presets, "Annuler", func(): analysis_service.cancel())
	analysis_page.add_child(presets)
	analysis_progress = ProgressBar.new()
	analysis_progress.max_value = 100
	analysis_page.add_child(analysis_progress)
	analysis_text = RichTextLabel.new()
	analysis_text.bbcode_enabled = false
	analysis_text.text = EncounterPresentation.analysis({})
	analysis_text.fit_content = false
	analysis_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	analysis_page.add_child(analysis_text)
	properties_tabs.add_child(analysis_page)
	technical_text = _rich_page("Détails techniques")
	properties_tabs.current_tab = 0
	var group := ButtonGroup.new()
	for index in properties_tabs.get_tab_count():
		var tab_button := _add_button(properties_navigation, properties_tabs.get_tab_title(index), func():
			properties_tabs.current_tab = index
		)
		tab_button.toggle_mode = true
		tab_button.button_group = group
		tab_button.set_pressed_no_signal(index == 0)
	properties_tabs.tab_changed.connect(func(index):
		(properties_navigation.get_child(index) as Button).set_pressed_no_signal(true)
		if map_preview != null:
			map_preview.set_edit_mode(false)
	)
	return panel


func _build_validation_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 220
	panel.size_flags_vertical = Control.SIZE_FILL
	var box := VBoxContainer.new()
	panel.add_child(box)
	var heading := HFlowContainer.new()
	var label := _section("ERREURS / AVERTISSEMENTS / INFORMATIONS")
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.add_child(label)
	box.add_child(heading)
	# G5 — les filtres sont une préférence d'affichage : ils ne salissent
	# jamais le brouillon et survivent à un rafraîchissement de validation.
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 10)
	box.add_child(filters)
	for entry in [
		[StudioValidationMessage.Severity.ERROR, "Erreurs"],
		[StudioValidationMessage.Severity.WARNING, "Avertissements"],
		[StudioValidationMessage.Severity.INFO, "Informations"],
	]:
		var severity: int = entry[0]
		var check := CheckBox.new()
		check.text = entry[1]
		check.button_pressed = bool(_validation_severity_filters.get(severity, true))
		check.toggled.connect(func(pressed):
			_validation_severity_filters[severity] = pressed
			_rebuild_validation_cards()
		)
		filters.add_child(check)
		validation_filter_buttons[severity] = check
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	validation_cards_box = VBoxContainer.new()
	validation_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	validation_cards_box.add_theme_constant_override("separation", 6)
	scroll.add_child(validation_cards_box)
	validation_empty_label = _wrapped_label(
		"Aucun problème bloquant détecté. Vous pouvez tester l'affrontement."
	)
	validation_empty_label.hide()
	box.add_child(validation_empty_label)
	return panel


## Applique la visibilité du panneau de diagnostic à partir de l'état du bouton.
## Extrait du bouton lui-même pour qu'une action bloquée puisse ouvrir le
## panneau sans simuler un clic.
func _apply_validation_panel_visibility() -> void:
	validation_panel.visible = validation_toggle.button_pressed
	# Les détails textuels de la case sont secondaires pendant la lecture
	# des diagnostics ; la carte et sa légende restent visibles.
	cell_info_label.visible = not validation_panel.visible
	if timeline_panel != null:
		timeline_panel.visible = not (validation_panel.visible and size.y < 650.0)
	if encounter_toolbar != null:
		encounter_toolbar.visible = not (validation_panel.visible and size.y < 650.0)
	if draft_banner != null and size.y < 650.0:
		draft_banner.visible = not validation_panel.visible and session.room_draft_mode
	if validation_panel.visible:
		# Le titre, les filtres et la première carte actionnable doivent être
		# visibles dès l'ouverture à 1280 x 720.
		_validation_height = maxf(_validation_height, 250.0)
	_queue_layout()


func _open_validation_panel() -> void:
	if validation_toggle == null or validation_panel == null:
		return
	validation_toggle.set_pressed_no_signal(true)
	_apply_validation_panel_visibility()


func _queue_layout() -> void:
	if _layout_queued or not is_inside_tree():
		return
	_layout_queued = true
	_apply_layout.call_deferred()


func _apply_layout() -> void:
	_layout_queued = false
	if not is_inside_tree() or _layout_dragging:
		return
	# Les côtés gardent leur largeur préférée ; le terrain reçoit le surplus.
	# Borner l'affichage ne remplace jamais la préférence d'une grande fenêtre.
	var left_min := navigation_panel.get_combined_minimum_size().x
	var right_min := properties_panel.get_combined_minimum_size().x
	var left_width := clampf(_navigation_width, left_min, maxf(left_min, size.x * 0.24))
	var right_width := clampf(_properties_width, right_min, maxf(right_min, size.x * 0.34))
	navigation_split.split_offsets = PackedInt32Array([roundi(left_width)])
	properties_split.split_offsets = PackedInt32Array([-roundi(right_width)])
	var bottom_min := validation_panel.get_combined_minimum_size().y
	var bottom_height := clampf(_validation_height, bottom_min,
		maxf(bottom_min, workspace_split.size.y * 0.58))
	workspace_split.split_offsets = PackedInt32Array([-roundi(bottom_height)])


func get_layout_snapshot() -> Dictionary:
	return {
		"navigation_open": navigation_panel.visible,
		"validation_open": validation_panel.visible,
		"navigation_width": _navigation_width,
		"properties_width": _properties_width,
		"validation_height": _validation_height,
	}


func apply_layout_snapshot(layout: Dictionary) -> void:
	_navigation_width = clampf(float(layout.get("navigation_width", 220.0)), 180.0, 700.0)
	_properties_width = clampf(float(layout.get("properties_width", 360.0)), 320.0, 900.0)
	_validation_height = clampf(float(layout.get("validation_height", 250.0)), 220.0, 600.0)
	navigation_panel.visible = bool(layout.get("navigation_open", true))
	validation_panel.visible = bool(layout.get("validation_open", false))
	if cell_info_label != null:
		cell_info_label.visible = not validation_panel.visible
	if timeline_panel != null:
		timeline_panel.visible = not (validation_panel.visible and size.y < 650.0)
	if encounter_toolbar != null:
		encounter_toolbar.visible = not (validation_panel.visible and size.y < 650.0)
	if draft_banner != null and size.y < 650.0:
		draft_banner.visible = not validation_panel.visible and session.room_draft_mode
	navigation_toggle.set_pressed_no_signal(navigation_panel.visible)
	validation_toggle.set_pressed_no_signal(validation_panel.visible)
	_queue_layout()


func _build_dialogs() -> void:
	validation_details_dialog = AcceptDialog.new()
	validation_details_dialog.title = "Détails techniques"
	validation_details_dialog.ok_button_text = "Fermer"
	validation_details_dialog.min_size = Vector2i(320, 200)
	validation_details_text = RichTextLabel.new()
	validation_details_text.bbcode_enabled = false
	validation_details_text.selection_enabled = true
	validation_details_dialog.add_child(validation_details_text)
	add_child(validation_details_dialog)

	open_dialog = FileDialog.new()
	open_dialog.title = "Ouvrir une configuration de partie"
	open_dialog.access = FileDialog.ACCESS_RESOURCES
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.filters = PackedStringArray(["*.tres, *.res ; Configuration de partie"])
	open_dialog.current_dir = "res://data/runs"
	open_dialog.file_selected.connect(open_run)
	add_child(open_dialog)

	save_dialog = ConfirmationDialog.new()
	save_dialog.title = "Sauvegarde sûre de la session"
	save_dialog.ok_button_text = "Sauvegarder les fichiers listés"
	save_dialog.confirmed.connect(_save_confirmed)
	add_child(save_dialog)

	shared_dialog = ConfirmationDialog.new()
	shared_dialog.title = "Rencontre partagée"
	shared_dialog.ok_button_text = "Modifier la rencontre partagée"
	shared_dialog.cancel_button_text = "Annuler"
	shared_duplicate_button = shared_dialog.add_button(
		"Dupliquer pour cet affrontement", true, "duplicate"
	)
	shared_dialog.confirmed.connect(_confirm_shared_edit)
	shared_dialog.custom_action.connect(_on_shared_custom_action)
	add_child(shared_dialog)


func _discover_default_run() -> void:
	enemy_catalog = StudioResourceCatalog.load_enemy_units()
	if project_context != null and project_context.active_run != null:
		sync_project_selection()
		return
	var paths := StudioResourceCatalog.find_run_paths()
	if paths.is_empty():
		_set_status("Aucune configuration de partie trouvée dans le projet.", true)
		return
	var selected := paths[0]
	for path in paths:
		if path.ends_with("/first_run.tres") or path.ends_with("/run_default.tres"):
			selected = path
			break
	open_run(selected)


func open_run(path: String) -> bool:
	var run := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as RunData
	return _open_run_resource(run, path)


func _open_run_resource(run: RunData, path: String) -> bool:
	return _request_document(run, path, 0)


func _open_approved_run(run: RunData, path: String) -> bool:
	if run == null or not session.open(run, path):
		_set_status("Le fichier sélectionné n'est pas une configuration de partie valide.", true)
		return false
	_fallback_undo_redo.clear_history()
	_last_history_object = null
	_syncing = true
	seed_spin.value = run.default_seed
	_syncing = false
	if project_context != null and run == project_context.active_run:
		session.select(project_context.active_room_index, 0)
	_refresh_all()
	history_state_changed.emit()
	_set_status("Partie ouverte en version en cours : %s" % run.run_name)
	return true


## Ouvre le brouillon de salle courant de Terrain. `draft_room` est l'instance
## même éditée par Terrain : les deux domaines partagent une seule autorité.
## `context_run` est la partie active, utilisée en lecture seule.
func open_room_draft(
		draft_room: RoomData,
		context_run: RunData,
		context_run_path := "",
		gameplay_mapping := {}
	) -> bool:
	if session.room_draft_mode and session.draft_room == draft_room:
		return refresh_draft_context(context_run)
	if project_context != null and project_context.has_pending_transition():
		# Une décision SAVE/DRAFT/DISCARD/CANCEL est déjà ouverte ailleurs
		# (par exemple un changement de salle en attente). Changer l'autorité
		# du document de Rencontres maintenant la résoudrait implicitement ou
		# laisserait la session dans un état partiellement modifié. On refuse
		# temporairement, sans rien perdre : l'utilisateur doit d'abord
		# répondre à la décision en cours.
		_set_status(
			"Une décision est déjà en attente ailleurs dans le Studio. "
			+ "Résolvez-la avant de créer les combats de cette salle.", true
		)
		return false
	if not session.is_dirty():
		# Rien n'est perdu côté Rencontres : ouvrir le brouillon de Terrain ne
		# discute jamais SON PROPRE document, quel que soit l'état d'un autre
		# domaine (Terrain peut être modifié — c'est justement le cas normal
		# en créant les combats d'un terrain tout juste créé). Bloquer ce geste
		# derrière la décision globale à quatre choix laisserait Rencontres
		# silencieusement lié aux Resources canoniques au lieu du brouillon
		# isolé — un risque réel d'écriture sur des données de production à
		# la prochaine sauvegarde. Si Rencontres a lui-même des changements non
		# enregistrés, la décision explicite reste demandée ci-dessous.
		return _open_approved_draft(draft_room, context_run, context_run_path, gameplay_mapping)
	return _request_navigation(
		Callable(self, "_open_approved_draft").bind(
			draft_room, context_run, context_run_path, gameplay_mapping
		), &"encounter_open_draft"
	)


func _open_approved_draft(
		draft_room: RoomData, context_run: RunData,
		context_run_path: String, gameplay_mapping: Dictionary
	) -> bool:
	if draft_room == null:
		_set_status("Aucun brouillon de salle à ouvrir.", true)
		return false
	if enemy_catalog.is_empty():
		enemy_catalog = StudioResourceCatalog.load_enemy_units()
	if not session.open_room_draft(
			draft_room, context_run, context_run_path, gameplay_mapping
		):
		_set_status("Le brouillon de salle n'a pas pu être ouvert.", true)
		return false
	_fallback_undo_redo.clear_history()
	_last_history_object = null
	_syncing = true
	seed_spin.value = session.working_run.default_seed
	_syncing = false
	_refresh_all()
	history_state_changed.emit()
	_set_status("%s %s" % [
		RoomDraftAuthority.DRAFT_BANNER,
		RoomDraftAuthority.context_summary(context_run),
	])
	room_draft_opened.emit()
	return true


func is_room_draft_mode() -> bool:
	return session.room_draft_mode


func _refresh_draft_banner() -> void:
	if draft_banner == null:
		return
	draft_banner.visible = session.room_draft_mode
	if not session.room_draft_mode:
		return
	draft_banner.text = "%s\n%s" % [
		RoomDraftAuthority.DRAFT_BANNER,
		RoomDraftAuthority.context_summary(session.context_run),
	]


func _refresh_all() -> void:
	if session.working_run == null:
		return
	# Changer de salle, d'affrontement ou de partie doit sortir proprement de
	# l'outil d'édition des cases interdites : ce n'est qu'un état d'interface.
	if map_preview != null:
		map_preview.set_edit_mode(false)
	_refresh_draft_banner()
	if project_context != null:
		project_context.set_dirty(&"encounter", session.is_dirty(), {
			"document": RoomDraftAuthority.DRAFT_BANNER if session.room_draft_mode \
				else session.source_run_path,
			"room_draft": session.room_draft_mode,
		})
	_syncing = true
	_refresh_run_tree()
	_refresh_timeline()
	_refresh_composition()
	_refresh_placement()
	_refresh_progression()
	_refresh_technical_details()
	_refresh_document_actions()
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
			var map_type := "Carte peinte" if room.painted_map_visual_data != null \
				else "Carte de scène"
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
		if wave == null and encounter == null and room.enemies.is_empty():
			button.text = "Aucun affrontement créé\nCommencez dans le panneau Composition"
		else:
			var name := wave.wave_name if wave != null else "Affrontement existant"
			button.text = "%d — %s\n%d ennemi(s)%s" % [
				index + 1,
				name,
				encounter.get_initial_enemy_count() if encounter != null else room.enemies.size(),
			_usage_badge(encounter),
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
	_usage_label = null
	var previous_search := _catalog_search_text
	var scroll := composition_box.get_parent() as ScrollContainer
	var previous_scroll := scroll.scroll_vertical if scroll != null else 0
	_clear_children(composition_box)
	var room := session.current_room()
	var encounter := session.current_encounter()
	if room == null:
		return
	if encounter == null:
		_build_empty_encounter_block()
		return
	_build_composition_summary(encounter)
	composition_box.add_child(_section("Ennemis ajoutés"))
	if encounter.roster_units.is_empty():
		composition_box.add_child(_wrapped_label(
			"Ajoutez au moins un ennemi depuis le catalogue ci-dessous."
		))
	for index in range(encounter.roster_units.size()):
		composition_box.add_child(_build_roster_card(encounter, index))
	composition_box.add_child(_section("Catalogue des ennemis"))
	_build_catalog_section(composition_box)
	var settings_content := _fold_section(
		composition_box, "Réglages de l'affrontement", _wave_settings_open,
		func(open): _wave_settings_open = open
	)
	_build_wave_settings(settings_content)
	var summon_content := _fold_section(
		composition_box, "Invocations et capacités", _summon_settings_open,
		func(open): _summon_settings_open = open
	)
	_build_summon_settings(summon_content, encounter)
	if not encounter.roster_units.is_empty():
		var next_button := _add_button(composition_box, "Voir le placement", func():
			properties_tabs.current_tab = 1
		)
		next_button.tooltip_text = (
			"La composition contient au moins un ennemi : passez au réglage du placement."
		)
	_filter_catalog(previous_search)
	if scroll != null:
		scroll.scroll_vertical = previous_scroll
	if _focus_catalog_search_next_refresh and catalog_search != null:
		_focus_catalog_search_next_refresh = false
		catalog_search.grab_focus.call_deferred()


## Résumé toujours visible : nom, effectif total, nombre de types distincts et
## avertissements reposant uniquement sur une règle métier réelle (jamais une
## alerte inventée pour l'occasion).
func _build_composition_summary(encounter: EncounterDefinition) -> void:
	var wave := session.current_wave()
	composition_box.add_child(_section(session.room_mode_label()))
	if wave != null:
		_add_line_edit(composition_box, "Nom de l'affrontement", wave.wave_name, func(value):
			_set_property(wave, &"wave_name", value, "Renommer l'affrontement")
		)
	var distinct_types := {}
	for unit in encounter.roster_units:
		if unit != null:
			distinct_types[unit] = true
	composition_box.add_child(_wrapped_label(
		"%d ennemi(s) au total • %d type(s) d'ennemi" % [
			encounter.get_initial_enemy_count(), distinct_types.size(),
		]
	))
	var usage := _usage_summary(encounter)
	var shared := _wrapped_label(_usage_text(usage))
	_usage_label = shared
	shared.name = "EncounterUsageSummary"
	shared.add_theme_color_override(
		"font_color", Color(1.0, 0.72, 0.3) if not usage.published.ready \
			or _usage_count(encounter) > 1 else Color(0.7, 0.9, 0.75)
	)
	composition_box.add_child(shared)
	if encounter.living_enemy_cap > 0 \
			and encounter.living_enemy_cap < encounter.get_initial_enemy_count():
		var warning := _wrapped_label(
			"Le plafond simultané (%d) est inférieur au nombre d'ennemis au début (%d)." % [
				encounter.living_enemy_cap, encounter.get_initial_enemy_count(),
			]
		)
		warning.add_theme_color_override("font_color", Color(1.0, 0.76, 0.3))
		composition_box.add_child(warning)


func _build_empty_encounter_block() -> void:
	composition_box.add_child(_section("Aucun affrontement dans cette salle"))
	composition_box.add_child(_wrapped_label(
		"Cette salle n'a pas encore d'affrontement. Créez-en un pour choisir "
		+ "ses ennemis. Ce travail reste un brouillon tant qu'il n'est pas "
		+ "intégré à la partie."
	))
	var create_button := _add_button(
		composition_box, "Créer le premier affrontement", func():
			_focus_catalog_search_next_refresh = true
			_add_wave()
	)
	create_button.custom_minimum_size.y = 46
	create_button.tooltip_text = (
		"Ajoute un premier affrontement vide à ce brouillon de salle."
	)


func _build_roster_card(encounter: EncounterDefinition, index: int) -> Control:
	var card := EncounterEnemyCard.new()
	var unit := encounter.roster_units[index]
	var quantity := int(encounter.roster_counts[index]) if index < encounter.roster_counts.size() else 1
	card.configure_roster(unit, enemy_catalog, quantity)
	card.quantity_changed.connect(func(value): _change_quantity(index, value))
	card.removed.connect(func(): _remove_roster_index(index))
	return card


func _build_wave_settings(parent: Control) -> void:
	var wave := session.current_wave()
	if wave == null:
		return
	_add_float_spin(parent, "PV ennemis ×", wave.enemy_health_multiplier, 0.1, 5.0, func(value):
		_set_property(wave, &"enemy_health_multiplier", value, "Modifier le multiplicateur de PV")
	)
	_add_float_spin(parent, "Attaque ennemie ×", wave.enemy_attack_multiplier, 0.1, 5.0, func(value):
		_set_property(wave, &"enemy_attack_multiplier", value, "Modifier le multiplicateur d'attaque")
	)
	_add_float_spin(parent, "Récompense ×", wave.reward_multiplier, 0.0, 10.0, func(value):
		_set_property(wave, &"reward_multiplier", value, "Modifier le multiplicateur de récompense")
	)


func _build_summon_settings(parent: Control, encounter: EncounterDefinition) -> void:
	_add_int_spin(parent, "Plafond vivant simultané", encounter.living_enemy_cap, 0, 99, func(value):
		_edit_encounter_property(&"living_enemy_cap", value, "Modifier le plafond vivant")
	)
	_add_int_spin(parent, "Budget total — invocations normales", encounter.shared_normal_summon_budget, 0, 99, func(value):
		_edit_encounter_property(&"shared_normal_summon_budget", value, "Modifier le budget normal")
	)
	_add_int_spin(parent, "Budget total — invocations de chef", encounter.shared_chief_summon_budget, 0, 99, func(value):
		_edit_encounter_property(&"shared_chief_summon_budget", value, "Modifier le budget de chef")
	)
	parent.add_child(_wrapped_label(
		"Ennemis initiaux : %d • Total théorique apparu : %d" % [
			encounter.get_initial_enemy_count(),
			encounter.get_initial_enemy_count() + encounter.shared_normal_summon_budget \
				+ encounter.shared_chief_summon_budget,
		]
	))
	_refresh_disabled_abilities(parent, encounter)


## Section locale repliable : purement une préférence d'interface, jamais une
## action d'historique ni une salissure du brouillon.
func _fold_section(parent: Control, title: String, initially_open: bool, on_toggled: Callable) -> VBoxContainer:
	var container := VBoxContainer.new()
	parent.add_child(container)
	var header := Button.new()
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.toggle_mode = true
	header.button_pressed = initially_open
	header.text = ("▾ " if initially_open else "▸ ") + title
	container.add_child(header)
	var content := VBoxContainer.new()
	content.visible = initially_open
	container.add_child(content)
	header.toggled.connect(func(pressed):
		content.visible = pressed
		header.text = ("▾ " if pressed else "▸ ") + title
		on_toggled.call(pressed)
	)
	return content


func _refresh_placement() -> void:
	_clear_children(placement_box)
	var encounter := session.current_encounter()
	if encounter == null:
		return
	placement_box.add_child(_section("Formations autorisées"))
	for formation_id in EncounterDefinition.FORMATION_IDS:
		var checkbox := CheckBox.new()
		checkbox.text = EncounterPresentation.formation_name(formation_id)
		checkbox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		checkbox.tooltip_text = EncounterPresentation.FORMATION_DESCRIPTIONS[formation_id]
		checkbox.button_pressed = encounter.formation_profiles.has(formation_id)
		checkbox.toggled.connect(func(enabled): _toggle_formation(formation_id, enabled))
		placement_box.add_child(checkbox)
	_add_int_spin(placement_box, "Tentatives maximales", encounter.maximum_formation_attempts, 1, 99, func(value):
		_edit_encounter_property(&"maximum_formation_attempts", value, "Modifier les tentatives de formation")
	)
	_add_int_spin(placement_box, "Voisins libres requis autour des invocateurs", encounter.summon_free_neighbor_requirement, 0, 8, func(value):
		_edit_encounter_property(&"summon_free_neighbor_requirement", value, "Modifier les voisins libres requis")
	)
	placement_box.add_child(_section("Distances à la zone de déploiement alliée"))
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
		placement_box.add_child(_section(EncounterPresentation.role_name(role, enemy_catalog)))
		_add_int_spin(placement_box, "Distance minimale obligatoire", int(encounter.minimum_path_distance_by_role.get(role, 0)), 0, 99, func(value):
			_set_role_distance(true, role, value)
		)
		_add_int_spin(placement_box, "Distance maximale souhaitée", int(encounter.maximum_path_distance_by_role.get(role, 0)), 0, 99, func(value):
			_set_role_distance(false, role, value)
		)
	placement_box.add_child(_wrapped_label(
		"ZONE ENNEMIE PRÉFÉRÉE : le planificateur privilégie ces cellules, mais peut utiliser d'autres cases praticables lorsque les contraintes de formation l'exigent."
	))
	placement_box.add_child(_wrapped_label(
		"CASES INTERDITES AU DÉPLOIEMENT ENNEMI : exclusions strictes. Cliquez directement sur la carte pour les modifier."
	))


## Plafond d'affrontements de la salle. Aucune constante locale : la partie —
## ou la partie de contexte en brouillon de salle, recopiée par
## RoomDraftAuthority.build_context_run — porte la règle dans
## `maximum_waves_per_room`. Monter ce plafond doit donc rouvrir le bouton
## sans qu'aucune ligne d'interface ne change.
func _wave_cap() -> int:
	if session.working_run == null:
		return 1
	return maxi(1, session.working_run.maximum_waves_per_room)


func _refresh_document_actions() -> void:
	var has_encounter := session.current_encounter() != null
	if generate_placement_button != null:
		generate_placement_button.disabled = not has_encounter
		generate_placement_button.tooltip_text = (
			"Proposer une disposition des ennemis sur le terrain."
			if has_encounter else
			"Créez d'abord le premier affrontement."
		)
	# Le plafond d'affrontements par salle est une règle de partie : un bouton
	# grisé sans explication laisserait croire à une panne. Le survol dit donc
	# toujours pourquoi l'action est fermée, et avec quelle limite.
	var room := session.current_room()
	var cap := _wave_cap()
	var cap_reached := room != null and room.waves.size() >= cap
	var cap_reason := "Limite de %d affrontement(s) atteinte pour cette salle." % cap
	if add_wave_button != null:
		add_wave_button.disabled = room == null or cap_reached
		add_wave_button.tooltip_text = (
			"Ouvrez une salle avant d'ajouter un affrontement." if room == null
			else cap_reason if cap_reached
			else "Ajouter un affrontement à la fin de la chronologie de cette salle."
		)
	# Dupliquer ajoute lui aussi un affrontement : le laisser actif contournerait
	# la même limite.
	if duplicate_wave_button != null:
		var has_wave := session.current_wave() != null
		duplicate_wave_button.disabled = not has_wave or cap_reached
		duplicate_wave_button.tooltip_text = (
			cap_reason if cap_reached
			else "Sélectionnez d'abord un affrontement à copier." if not has_wave
			else "Copier l'affrontement sélectionné, sa rencontre comprise."
		)
	if edit_terrain_button != null:
		edit_terrain_button.visible = session.room_draft_mode


func _refresh_progression() -> void:
	if progression_text == null or session.current_room() == null:
		return
	var room := session.runtime_room()
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
	_progression_details = {"metrics": current, "comparison": comparison, "projection": projection}
	progression_text.text = EncounterPresentation.progression(current, comparison, projection, walkable, enemy_catalog)


func _refresh_technical_details() -> void:
	if technical_text == null:
		return
	var encounter := session.current_encounter()
	var source := session.source_encounter()
	technical_text.text = "DÉTAILS TECHNIQUES — facultatifs, destinés au diagnostic\n\nPartie : %s\nSalle : %s\nRencontre : %s\nNuméro de salle visé : %s\nGroupes d'apparition autorisés : %s\n\nUSAGES PUBLIÉS ET LOCAUX (périmètres séparés)\n%s\n\nCe réglage de groupes est conservé dans le fichier, mais il n'est pas encore utilisé pendant les combats." % [
		session.source_run_path,
		(session.source_for(session.current_room()) as Resource).resource_path \
			if session.source_for(session.current_room()) != null else "version en cours",
		source.resource_path if source != null else str(session.new_resource_paths.get(encounter, "version en cours")),
		encounter.room_index if encounter != null else "—",
		str(encounter.allowed_spawn_groups) if encounter != null else "—",
		JSON.stringify(_usage_summary(encounter), "  ") if encounter != null else "—",
	]
	technical_text.text += "\n\nGénération du graphe partagé : %s" % (str(shared_reference_graph.generation) if shared_reference_graph != null else "indisponible")
	if encounter != null:
		technical_text.text += "\n\nFormations : %s\nCapacités désactivées : %s" % [encounter.formation_profiles, encounter.disabled_ability_ids]
		for unit in encounter.roster_units:
			if unit != null:
				technical_text.text += "\n%s : %s\nIdentifiant : %s • Faction : %s • Rôle : %s" % [unit.unit_name, unit.resource_path, unit.get_effective_unit_id(), unit.faction_id, unit.tactical_role_id]
	technical_text.text += "\n\nPROGRESSION\n%s\n\nANALYSE\n%s" % [JSON.stringify(_progression_details, "  "), JSON.stringify(analysis_result, "  ")]
	technical_text.text += "\n\nPLACEMENT\n%s" % JSON.stringify(EncounterPreviewService.serializable(preview_result), "  ")
	var messages: Array = []
	for message in session.validation_messages:
		messages.append(message.to_dictionary())
	technical_text.text += "\n\nVALIDATION\n%s" % JSON.stringify(messages, "  ")
	technical_text.text += "\n\nDERNIÈRE OPÉRATION SIGNALÉE\n%s" % JSON.stringify(_operation_details, "  ")


func generate_preview() -> Dictionary:
	var room := session.runtime_room()
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
	if map_preview.selected_cell != Vector2i(-1, -1):
		_on_cell_selected(map_preview.selected_cell)
	_set_status(
		"Placement %s • valeur de départ effective %d • formation %s" % [
			"valide" if preview_result.get("valid", false) else "impossible",
			int(preview_result.get("effective_seed", 0)),
			EncounterPresentation.formation_name(StringName(preview_result.get("formation_id", &""))) if preview_result.get("valid", false) else EncounterPresentation.failure_text(str(preview_result.get("reason", ""))),
		],
		not preview_result.get("valid", false),
	)
	_refresh_technical_details()
	return preview_result


func validate_session() -> Array[StudioValidationMessage]:
	var messages := EncounterValidationService.validate_session(
		session, int(seed_spin.value)
	)
	_rebuild_validation_cards()
	var summary := EncounterValidationService.summary(messages)
	_refresh_validation_summary(summary)
	_set_status("Validation : %d erreur(s), %d avertissement(s)." % [
		summary.errors, summary.warnings,
	], summary.errors > 0)
	_refresh_technical_details()
	return messages


## Barrière commune aux actions qui publient ou lancent le vrai jeu.
##
## Une ERREUR est bloquante : elle ferme l'action. Un AVERTISSEMENT ne ferme
## jamais rien, il est seulement rappelé dans le message pour que la distinction
## reste lisible. La barrière revalide au lieu de relire le dernier compte
## affiché : une action ne doit jamais s'appuyer sur un diagnostic périmé.
func blocking_validation_report() -> Dictionary:
	var messages := validate_session()
	var summary := EncounterValidationService.summary(messages)
	var titles := PackedStringArray()
	for message in messages:
		if message.severity == StudioValidationMessage.Severity.ERROR \
				and titles.size() < 3:
			titles.append(message.title)
	return {
		"blocked": int(summary.errors) > 0,
		"errors": int(summary.errors),
		"warnings": int(summary.warnings),
		"titles": titles,
	}


## Signale une action fermée par la validation : message explicite en statut et
## panneau de diagnostic ouvert sur les cartes concernées. Jamais un simple
## bouton inerte.
func report_blocked_action(action: String, report: Dictionary) -> void:
	_open_validation_panel()
	_set_status(_blocking_message(action, report), true)


func _blocking_message(action: String, report: Dictionary) -> String:
	var errors := int(report.get("errors", 0))
	var warnings := int(report.get("warnings", 0))
	var text := "%s : %d erreur(s) bloquante(s)" % [action, errors]
	var titles: PackedStringArray = report.get("titles", PackedStringArray())
	if not titles.is_empty():
		text += " — %s" % ", ".join(titles)
		if errors > titles.size():
			text += "…"
	if warnings > 0:
		text += " • %d avertissement(s), qui ne bloquent pas" % warnings
	return text + ". Corrigez-les dans le panneau de diagnostic."


## G5 — résumé permanent, visible même panneau replié : icône + libellé +
## couleur, jamais la couleur seule. Ordre de priorité erreurs > avertissements
## > informations.
func _refresh_validation_summary(summary: Dictionary) -> void:
	if validation_summary_label == null:
		return
	var errors := int(summary.get("errors", 0))
	var warnings := int(summary.get("warnings", 0))
	if errors > 0:
		validation_summary_label.text = "✖ %d erreur(s)%s" % [
			errors, " • %d avertissement(s)" % warnings if warnings > 0 else "",
		]
		validation_summary_label.add_theme_color_override(
			"font_color", EncounterVisualConstants.severity_color(StudioValidationMessage.Severity.ERROR)
		)
	elif warnings > 0:
		# Un avertissement n'empêche jamais de tester : le message reste
		# rassurant en tête, le compte reste visible et honnête.
		validation_summary_label.text = "Aucun problème bloquant (%d avertissement(s))" % warnings
		validation_summary_label.add_theme_color_override(
			"font_color", EncounterVisualConstants.severity_color(StudioValidationMessage.Severity.WARNING)
		)
	else:
		validation_summary_label.text = "Aucun problème bloquant"
		validation_summary_label.add_theme_color_override("font_color", EncounterVisualConstants.COLOR_SUCCESS)


## G5 — reconstruit les cartes à partir des messages actuels et des filtres
## de gravité en vigueur (préférence d'affichage, jamais de mutation).
func _rebuild_validation_cards() -> void:
	if validation_cards_box == null:
		return
	# G6 — Corriger relance la validation, qui reconstruit les cartes : sans
	# ce garde, le focus clavier posé sur le bouton qu'on vient d'activer
	# serait perdu (le contrôle est libéré). On le reporte sur un point
	# d'ancrage stable et déjà compris de l'utilisateur : le bouton qui
	# ouvre/replie le panneau lui-même.
	var focus_owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_was_in_panel := focus_owner != null and validation_cards_box.is_ancestor_of(focus_owner)
	_clear_children(validation_cards_box)
	if focus_was_in_panel and validation_toggle != null:
		validation_toggle.grab_focus.call_deferred()
	var messages := session.validation_messages
	var shown := 0
	for message in messages:
		if not bool(_validation_severity_filters.get(message.severity, true)):
			continue
		shown += 1
		var card := EncounterDiagnosticCard.new()
		validation_cards_box.add_child(card)
		var can_view := message.room_index >= 0 or message.cell != Vector2i(-1, -1)
		var can_fix := message.fix_id != &""
		card.setup(message, can_view, can_fix)
		card.view_requested.connect(_view_diagnostic.bind(message))
		card.fix_requested.connect(_apply_diagnostic_fix.bind(message))
		card.details_requested.connect(_show_validation_details_for.bind(message))
	# « Aucun problème bloquant » ne dépend que des erreurs : un avertissement
	# n'empêche jamais de tester (EncounterPresentation.validation_consequence).
	# Les avertissements et informations restent consultables séparément,
	# affichés sous le message positif plutôt qu'à sa place.
	var has_blocking := messages.any(func(m: StudioValidationMessage) -> bool:
		return m.severity == StudioValidationMessage.Severity.ERROR
	)
	validation_empty_label.visible = not has_blocking
	validation_cards_box.visible = shown > 0


## G5 — « Voir » ouvre le bon endroit sans jamais rien modifier.
func _view_diagnostic(message: StudioValidationMessage) -> void:
	if message.room_index >= 0:
		if not _request_room(message.room_index, maxi(0, message.wave_index)):
			return
	if message.cell != Vector2i(-1, -1) and map_preview != null:
		map_preview.selected_cell = message.cell
		map_preview.queue_redraw()
		_on_cell_selected(message.cell)


## G5 — « Corriger » est le seul chemin qui applique une correction. Elle
## passe par la protection des rencontres partagées (_ensure_editable) et par
## l'historique (une action Annuler/Rétablir), puis relance la validation.
func _apply_diagnostic_fix(message: StudioValidationMessage) -> void:
	if message.room_index >= 0:
		if not _request_room(message.room_index, maxi(0, message.wave_index)):
			return
	match message.fix_id:
		&"fit_living_cap":
			_edit_encounter_property(&"living_enemy_cap", session.current_encounter().get_initial_enemy_count(), "Ajuster le plafond vivant")
		&"use_actual_room_index":
			_edit_encounter_property(&"room_index", session.selected_room_index + 1, "Utiliser le numéro réel de la salle")
		&"deduplicate_forbidden":
			var encounter := session.current_encounter()
			var unique: Array[Vector2i] = []
			for cell in encounter.forbidden_initial_spawn_cells:
				if not unique.has(cell): unique.append(cell)
			_edit_encounter_property(&"forbidden_initial_spawn_cells", unique, "Retirer les doublons de cases interdites")
	_refresh_all()


func _show_validation_details_for(message: StudioValidationMessage) -> void:
	var path := message.resource_path
	# Les copies en mémoire n'ont pas toujours de chemin ; retrouver la source
	# sans changer de salle, de vague, de sélection métier ou d'historique.
	if path.is_empty() and message.room_index >= 0 and message.room_index < session.working_run.rooms.size():
		var room := session.working_run.rooms[message.room_index]
		var concerned: Resource = room
		if room != null and message.wave_index >= 0:
			concerned = room.get_encounter_for_wave(message.wave_index)
		var source := session.source_for(concerned)
		if source != null:
			path = source.resource_path
		if path.is_empty():
			path = str(session.new_resource_paths.get(concerned, ""))
	if path.is_empty() and message.room_index < 0:
		path = session.source_run_path
	validation_details_text.text = "Diagnostic facultatif — consultation seule\n\n%s\n\nCode stable : %s\nChemin concerné : %s\nSalle (index) : %s\nAffrontement (index) : %s\nCellule : %s\n\nMétadonnées\n%s" % [
		EncounterPresentation.validation_explanation(message), message.code,
		path if not path.is_empty() else "Copie en mémoire — aucun fichier associé",
		message.room_index, message.wave_index, message.cell,
		JSON.stringify(message.to_dictionary(), "  "),
	]
	validation_details_dialog.popup_centered(Vector2i(700, 430).min(Vector2i(get_viewport_rect().size) - Vector2i(40, 40)))


func analyze_seeds(count: int) -> void:
	var room := session.runtime_room()
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
	# Le lanceur refuse déjà une session en erreur, mais son code de retour seul
	# ne dit pas à l'auteur ce qui bloque : la barrière parle avant lui.
	var gate := blocking_validation_report()
	if bool(gate.blocked):
		last_test_result = {"ok": false, "error": "validation_failed", "gate": gate}
		report_blocked_action("Test impossible", gate)
		return last_test_result
	last_test_result = EncounterTestLauncher.prepare_and_launch(
		session, editor_interface, int(seed_spin.value)
	)
	if last_test_result.get("ok", false):
		_set_status("Test direct lancé dans le vrai jeu.")
	else:
		_show_operation_failure("Le test n'a pas pu être lancé", last_test_result)
	return last_test_result


func export_report() -> Dictionary:
	last_test_result = EncounterTestLauncher.load_last_result()
	var result := EncounterReportExporter.export_report(
		session, preview_result, analysis_result, last_test_result
	)
	if result.get("ok", false):
		DisplayServer.clipboard_set(str(result.get("markdown", "")))
		_set_status("Rapport Markdown et JSON exporté ; le Markdown est copié dans le presse-papiers.")
	else:
		_show_operation_failure("Le rapport n'a pas pu être exporté", result)
	return result


func get_state_snapshot() -> Dictionary:
	return {
		"room_draft": session.room_draft_mode,
		"context_run_path": session.context_run_path,
		"run_path": session.source_run_path,
		"room_index": session.selected_room_index,
		"wave_index": session.selected_wave_index,
		"seed": int(seed_spin.value) if seed_spin != null else 1337,
		"properties_tab": properties_tabs.current_tab if properties_tabs != null else 0,
		"layout": get_layout_snapshot() if navigation_panel != null else {},
	}


func apply_state_snapshot(state: Dictionary) -> void:
	var layout = state.get("layout", {})
	if layout is Dictionary and navigation_panel != null:
		apply_layout_snapshot(layout)
	if bool(state.get("room_draft", false)):
		# Un brouillon de salle appartient à la session Terrain : il se rouvre
		# par « Créer les combats de la salle », jamais par un chemin de partie.
		_set_status(
			"Ce brouillon de salle se rouvre depuis Terrain, avec « %s »."
			% RoomDraftAuthority.ENCOUNTERS_ACTION_LABEL
		)
		return
	var path := str(state.get("run_path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var run := ResourceLoader.load(path) as RunData
		_request_document(run, path, int(state.get("room_index", 0)), state)


func _show_open_dialog() -> void:
	open_dialog.popup_centered_ratio(0.72)


func _show_save_dialog() -> void:
	if session.room_draft_mode:
		# La sauvegarde canonique n'est pas atteignable en brouillon de salle :
		# le bouton enregistre le brouillon dans le dossier personnel.
		save_room_draft()
		return
	# Une erreur bloquante ferme la publication ; un avertissement ne l'a jamais
	# fermée et n'a donc pas à changer de comportement ici.
	var gate := blocking_validation_report()
	if bool(gate.blocked):
		report_blocked_action("Publication impossible", gate)
		return
	var plan := EncounterSaveService.build_plan(session)
	if not plan.get("ok", false):
		_show_operation_failure("La publication est bloquée ; vérifiez la validation", plan)
		return
	if plan.entries.is_empty():
		_set_status("Aucun changement à publier.")
		return
	var paths: Array = plan.paths
	save_dialog.title = "Publier les rencontres"
	save_dialog.ok_button_text = "Publier les rencontres"
	save_dialog.dialog_text = "FICHIERS MODIFIÉS / CRÉÉS\n\n%s\n\nUne sauvegarde de récupération sera créée en local avant toute écriture." % "\n".join(paths)
	save_dialog.popup_centered(Vector2i(720, 430))


func _save_confirmed() -> void:
	var result := EncounterSaveService.save(session)
	if result.get("ok", false):
		_invalidate_published_paths(result)
		_fallback_undo_redo.clear_history()
		_last_history_object = null
		if editor_interface != null:
			editor_interface.get_resource_filesystem().scan()
		_set_status("Sauvegarde vérifiée : %d fichier(s)." % (result.get("saved_paths", []) as Array).size())
		_refresh_title()
		history_state_changed.emit()
	else:
		_show_operation_failure("La sauvegarde a été arrêtée", result)
	if project_context != null:
		project_context.set_dirty(&"encounter", session.is_dirty())


func _on_shared_run_changed(run_data: RunData) -> void:
	if run_data != null:
		sync_project_selection()


## La Resource rechargée du contexte prime sur le cache et sur son seul chemin.
func sync_project_selection() -> bool:
	if _syncing_context or project_context == null or project_context.active_run == null:
		return false
	if session.room_draft_mode:
		# Le brouillon n'appartient à aucune partie : la run active n'est qu'un
		# contexte en lecture seule. Elle est rafraîchie sans jamais remplacer
		# l'autorité du brouillon ni sa sélection.
		return refresh_draft_context(project_context.active_run)
	var run := project_context.active_run
	var index := project_context.active_room_index
	if session.is_dirty() and (session.source_run != run \
			or session.selected_room_index != index):
		_set_status("Rencontres contient des changements non enregistrés. Résolvez-les avant de changer de salle.", true)
		return false
	_syncing_context = true
	if session.source_run != run and (session.source_run_path.is_empty() \
			or session.source_run_path != run.resource_path):
		if not _open_approved_run(run, run.resource_path):
			_syncing_context = false
			return false
	if index >= 0 and not session.select(index, 0):
		_syncing_context = false
		return false
	_refresh_all()
	_syncing_context = false
	return true


## Remplace les règles de partie portées par le porteur, sans toucher au
## brouillon. La partie de contexte reste strictement en lecture seule.
func refresh_draft_context(context_run: RunData) -> bool:
	if not session.room_draft_mode or session.draft_room == null:
		return false
	var carrier := RoomDraftAuthority.build_context_run(session.draft_room, context_run)
	if carrier == null:
		return false
	session.working_run = carrier
	session.context_run = context_run
	session.context_run_path = context_run.resource_path if context_run != null else ""
	session.select(0, session.selected_wave_index)
	_refresh_all()
	return true


func _on_shared_room_changed(room_index: int, _room: RoomData) -> void:
	if session.room_draft_mode:
		# Le brouillon n'est pas une salle de la partie : changer de salle dans
		# le contexte ne doit ni le remplacer ni déplacer sa sélection.
		return
	if room_index >= 0:
		sync_project_selection()


## Enregistre le brouillon de salle complet — terrain et affrontements — dans le
## dossier personnel. Aucune Resource canonique n'est touchée.
func save_room_draft() -> Dictionary:
	if not session.room_draft_mode:
		return {"ok": false, "error": "not_room_draft"}
	var result := RoomDraftSaveService.save(
		session.draft_room, _room_draft_session_key(), get_state_snapshot()
	)
	if bool(result.get("ok", false)):
		var loaded := RoomDraftSaveService.load_draft(_room_draft_session_key())
		var verified := EncounterEditSession.new()
		if not bool(loaded.get("ok", false)) or not verified.open_room_draft(
				loaded.get("room") as RoomData, session.context_run):
			return {"ok": false, "error": "draft_reload_failed", "details": loaded}
		# ArenaDefinition.authoring_document est un marqueur d'édition non
		# sérialisé (RoomIntegrationFieldPolicy en dépend pour classer
		# enemies/background_image/arena_visual_profile/battle_scene comme
		# GAMEPLAY_OWNED ou DERIVED_RUNTIME). RoomDraftSaveService.load_draft()
		# le reconstruit toujours à sa valeur par défaut : sans réalignement,
		# la comparaison d'empreinte ci-dessous compare deux classifications de
		# champs différentes, pas deux contenus différents. On aligne la copie
		# rechargée sur le brouillon vivant avant de comparer.
		if verified.draft_room is ArenaDefinition and session.draft_room is ArenaDefinition:
			(verified.draft_room as ArenaDefinition).authoring_document = \
				(session.draft_room as ArenaDefinition).authoring_document
		# Les destinations canoniques restent en mémoire : le fichier de salle
		# publie ses rencontres comme sous-ressources lors de l'intégration.
		var expected := EncounterEditSession.new()
		expected.room_draft_mode = true
		expected.draft_room = session.draft_room
		if verified.document_fingerprint() != expected.document_fingerprint() \
				or (session.draft_room is ArenaDefinition and ArenaEditSession.fingerprint(
					(session.draft_room as ArenaDefinition).to_snapshot()) != ArenaEditSession.fingerprint(
					(verified.draft_room as ArenaDefinition).to_snapshot())):
			return {"ok": false, "error": "draft_content_mismatch"}
		session.confirm_draft_saved()
		_refresh_all()
		history_state_changed.emit()
	if bool(result.get("ok", false)):
		_set_status(
			"Brouillon de salle enregistré dans votre dossier personnel. "
			+ "Aucune partie ni rencontre n'a été publiée."
		)
	else:
		_show_operation_failure("Le brouillon n'a pas pu être enregistré", result)
	return result


func restore_room_draft() -> Dictionary:
	var ok := _request_navigation(Callable(self, "_restore_approved_room_draft"), &"encounter_restore_draft")
	return {"ok": ok, "pending": project_context != null and project_context.has_pending_transition()}


func _restore_approved_room_draft() -> bool:
	if not session.room_draft_mode:
		return false
	var loaded := RoomDraftSaveService.load_draft(_room_draft_session_key())
	if not bool(loaded.get("ok", false)):
		_show_operation_failure("Aucun brouillon de salle n'a pu être chargé", loaded)
		return false
	var stored := loaded.get("room") as RoomData
	RoomDraftAuthority.isolate_gameplay_into(session.draft_room, stored)
	var state := loaded.get("state", {}) as Dictionary
	session.select(0, int(state.get("wave_index", 0)))
	for wave in session.draft_room.waves:
		session.mark_dirty(wave)
	session.mark_dirty(session.draft_room)
	_refresh_all()
	history_state_changed.emit()
	_set_status("Brouillon de salle restauré. Vérifiez avant d'intégrer.")
	return true


func _room_draft_session_key() -> String:
	if session.draft_room is ArenaDefinition:
		return str((session.draft_room as ArenaDefinition).arena_id)
	return session.draft_room.room_name if session.draft_room != null else ""


func _context_save() -> Dictionary:
	if session.room_draft_mode:
		# En brouillon de salle, SAVE ne peut pas signifier « publier ». La
		# décision reste explicite et locale : le brouillon part sous user://.
		return save_room_draft()
	var result := EncounterSaveService.save(session)
	if result.get("ok", false):
		_invalidate_published_paths(result)
		_refresh_all()
	return result


func _context_draft() -> Dictionary:
	if session.room_draft_mode:
		return save_room_draft()
	var result := EncounterSaveService.save_draft(session)
	if result.get("ok", false):
		_refresh_all()
		history_state_changed.emit()
	return result


func _context_discard() -> Dictionary:
	var ok := session.discard()
	if ok:
		_refresh_all()
	return {"ok": ok, "error": "La session de rencontre n'a pas pu être rechargée." if not ok else ""}


func _context_snapshot() -> Dictionary:
	var state := {}
	# Les Resources sont gardées par référence pour que l'historique continue
	# de viser les mêmes objets après l'échec d'un autre domaine.
	for property in session.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = session.get(property.name)
			state[property.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return {"session": state, "gameplay": RoomDraftAuthority.gameplay_state(session.draft_room)}


func _context_restore(snapshot: Dictionary) -> Dictionary:
	for property in snapshot.session:
		session.set(property, snapshot.session[property])
	if session.room_draft_mode:
		RoomDraftAuthority.restore_gameplay_state(session.draft_room, snapshot.gameplay)
	_refresh_all()
	return {"ok": true}


func _context_rollback(_action: StringName, _metadata: Dictionary, plan: Dictionary) -> Dictionary:
	var committed := plan.get("committed", {}) as Dictionary
	if committed.has("journal"):
		return EncounterSaveService._restore_backups(committed.journal)
	return {"ok": true}


func _restore_latest_recovery() -> void:
	_request_navigation(Callable(self, "_restore_approved_recovery"), &"encounter_recovery")


func _restore_approved_recovery() -> bool:
	var candidate := EncounterEditSession.new()
	var loaded := EncounterSaveService.restore_latest(candidate)
	if not loaded.get("ok", false):
		return false
	var selection := project_context.request_selection({
		"run": candidate.source_run, "room_index": candidate.selected_room_index,
	}, &"encounter")
	if not selection.get("ok", false):
		return false
	var result := EncounterSaveService.restore_latest(session)
	if result.get("ok", false):
		_refresh_all()
		_operation_details = result.duplicate(true)
		_refresh_technical_details()
		_set_status("Session restaurée depuis la récupération locale. Vérifiez puis sauvegardez pour confirmer.")
	else:
		_show_operation_failure("La session n'a pas pu être restaurée", result)
	return bool(result.get("ok", false))


func _on_tree_selected() -> void:
	if _syncing:
		return
	var item := run_tree.get_selected()
	if item == null:
		return
	var room_index := int(item.get_metadata(0))
	if room_index >= 0:
		# Restaurer immédiatement la sélection visible, puis demander au contexte
		# hors du signal Tree (qui interdit clear/create_item).
		_syncing = true
		var current := run_tree.get_root().get_first_child()
		while current != null:
			if int(current.get_metadata(0)) == session.selected_room_index:
				current.select(0)
			current = current.get_next()
		_syncing = false
		call_deferred("_request_room", room_index)


func _request_room(index: int, wave := 0) -> bool:
	if session.room_draft_mode:
		return session.select(0, wave)
	return _request_document(session.source_run, session.source_run_path, index, {"wave_index": wave})


func _request_document(run: RunData, path: String, index: int, state := {}) -> bool:
	if run == null or project_context == null or project_context.has_pending_transition():
		return false
	project_context.set_dirty(&"encounter", session.is_dirty())
	var action := Callable(self, "_finish_document_selection").bind(run, path, index, state)
	# Changer d'autorité (brouillon -> canonique) peut garder la même sélection
	# projet : cela reste une transition documentaire explicite.
	if session.room_draft_mode and project_context.active_run == run \
			and project_context.active_room_index == index:
		return _request_navigation(action, &"encounter_open_run")
	var result := project_context.request_selection({"run": run, "room_index": index}, &"encounter")
	return _complete_or_queue_navigation(result, action)


func _finish_document_selection(run: RunData, path: String, index: int, state: Dictionary) -> bool:
	if session.room_draft_mode or session.working_run == null \
			or (session.source_run != run and (path.is_empty() or session.source_run_path != path)):
		if not _open_approved_run(run, path):
			return false
	if index >= 0 and not session.select(index, int(state.get("wave_index", 0))):
		return false
	if state.has("seed"):
		seed_spin.value = int(state.seed)
	if state.has("properties_tab"):
		var tab := int(state.properties_tab)
		# Une ancienne préférence Avancé ne doit pas ouvrir les diagnostics.
		properties_tabs.current_tab = tab if tab >= 0 and tab < properties_tabs.get_tab_count() - 1 else 0
	_refresh_all()
	return true


func _request_navigation(action: Callable, intent: StringName) -> bool:
	if project_context == null or project_context.has_pending_transition():
		return false
	project_context.set_dirty(&"encounter", session.is_dirty())
	return _complete_or_queue_navigation(
		project_context.request_dirty_transition(intent, &"encounter"), action
	)


func _complete_or_queue_navigation(result: Dictionary, action: Callable) -> bool:
	if result.get("ok", false):
		return bool(action.call())
	if result.get("status") == &"REQUIRES_DECISION":
		_pending_navigation = action
		_navigation_token = str((result.transition as Dictionary).get("token", ""))
	return false


func _on_transition_resolved(result: Dictionary) -> void:
	var transition := result.get("transition", {}) as Dictionary
	if result.get("status") == &"APPLIED_AFTER_DECISION" \
			and result.get("action") in [&"SAVE", &"DISCARD"] \
			and (transition.get("dirty_domains", {}) as Dictionary).has(&"encounter"):
		_fallback_undo_redo.clear_history()
		_last_history_object = null
		history_state_changed.emit()
	if str(transition.get("token", "")) != _navigation_token:
		return
	var action := _pending_navigation
	_pending_navigation = Callable()
	_navigation_token = ""
	if result.get("status") != &"CANCELLED" and result.get("ok", false) and action.is_valid():
		action.call()


func _on_forbidden_cell_toggled(cell: Vector2i) -> void:
	if session.current_encounter() == null:
		return
	# La rencontre courante n'est résolue que DANS la fermeture, jamais avant :
	# si l'utilisateur choisit « Dupliquer », l'action doit s'appliquer à la
	# copie fraîchement créée, pas à l'ancienne rencontre capturée avant le
	# dialogue.
	_ensure_editable(func():
		var encounter := session.current_encounter()
		var cells: Array[Vector2i] = encounter.forbidden_initial_spawn_cells.duplicate()
		if cells.has(cell):
			cells.erase(cell)
		else:
			cells.append(cell)
		_set_property(encounter, &"forbidden_initial_spawn_cells", cells, "Modifier les cases interdites")
	)


func _build_catalog_section(parent: Control) -> void:
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	parent.add_child(filters)
	catalog_search = LineEdit.new()
	catalog_search.placeholder_text = "Rechercher par nom, faction ou rôle"
	catalog_search.text = _catalog_search_text
	catalog_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_search.text_changed.connect(_filter_catalog)
	filters.add_child(catalog_search)
	catalog_faction_filter_button = OptionButton.new()
	_populate_filter_button(
		catalog_faction_filter_button, _catalog_factions(), _catalog_faction_filter,
		"Toutes les factions", Callable(EncounterPresentation, "faction_name")
	)
	catalog_faction_filter_button.item_selected.connect(func(index):
		_catalog_faction_filter = catalog_faction_filter_button.get_item_metadata(index)
		_filter_catalog(_catalog_search_text)
	)
	filters.add_child(catalog_faction_filter_button)
	catalog_role_filter_button = OptionButton.new()
	_populate_filter_button(
		catalog_role_filter_button, _catalog_roles(), _catalog_role_filter,
		"Tous les rôles", func(role): return EncounterPresentation.role_name(role, enemy_catalog)
	)
	catalog_role_filter_button.item_selected.connect(func(index):
		_catalog_role_filter = catalog_role_filter_button.get_item_metadata(index)
		_filter_catalog(_catalog_search_text)
	)
	filters.add_child(catalog_role_filter_button)
	catalog_cards_box = VBoxContainer.new()
	catalog_cards_box.add_theme_constant_override("separation", 4)
	parent.add_child(catalog_cards_box)
	catalog_empty_label = _wrapped_label(
		"Aucun ennemi ne correspond à cette recherche. Effacez la recherche ou changez les filtres."
	)
	catalog_empty_label.hide()
	parent.add_child(catalog_empty_label)


func _catalog_factions() -> Array[StringName]:
	var seen := {}
	var result: Array[StringName] = []
	for unit in enemy_catalog:
		if unit != null and not seen.has(unit.faction_id):
			seen[unit.faction_id] = true
			result.append(unit.faction_id)
	return result


func _catalog_roles() -> Array[StringName]:
	var seen := {}
	var result: Array[StringName] = []
	for unit in enemy_catalog:
		if unit != null and not seen.has(unit.tactical_role_id):
			seen[unit.tactical_role_id] = true
			result.append(unit.tactical_role_id)
	return result


func _populate_filter_button(
		button: OptionButton, values: Array, current: StringName,
		none_label: String, label_fn: Callable
	) -> void:
	button.clear()
	button.add_item(none_label)
	button.set_item_metadata(0, &"")
	var select_index := 0
	for index in values.size():
		var value: StringName = values[index]
		button.add_item(str(label_fn.call(value)))
		button.set_item_metadata(index + 1, value)
		if value == current:
			select_index = index + 1
	button.selected = select_index


func _filter_catalog(query: String) -> void:
	_catalog_search_text = query
	if catalog_cards_box == null:
		return
	var normalized := query.to_lower().strip_edges()
	var filtered: Array[UnitData] = []
	for unit in enemy_catalog:
		if unit == null:
			continue
		if _catalog_faction_filter != &"" and unit.faction_id != _catalog_faction_filter:
			continue
		if _catalog_role_filter != &"" and unit.tactical_role_id != _catalog_role_filter:
			continue
		var haystack := "%s %s %s %s %s" % [unit.unit_name, unit.faction_id, unit.tactical_role_id, EncounterPresentation.faction_name(unit.faction_id), EncounterPresentation.role_name(unit.tactical_role_id, enemy_catalog)]
		if not normalized.is_empty() and normalized not in haystack.to_lower():
			continue
		filtered.append(unit)
	_rebuild_catalog_cards(filtered)


func _rebuild_catalog_cards(units: Array[UnitData]) -> void:
	_clear_children(catalog_cards_box)
	catalog_empty_label.visible = units.is_empty()
	var encounter := session.current_encounter()
	for unit in units:
		var card := EncounterEnemyCard.new()
		catalog_cards_box.add_child(card)
		var current_quantity := 0
		if encounter != null:
			var roster_index := encounter.roster_units.find(unit)
			if roster_index >= 0 and roster_index < encounter.roster_counts.size():
				current_quantity = int(encounter.roster_counts[roster_index])
		card.configure_catalog(unit, enemy_catalog, current_quantity)
		card.add_pressed.connect(func(): _add_unit(unit))
		card.activated.connect(func(): _add_unit(unit))


func _add_unit(unit: UnitData) -> void:
	if session.current_encounter() == null:
		return
	_ensure_editable(func():
		var encounter := session.current_encounter()
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
		var current := session.current_encounter()
		var counts := current.roster_counts.duplicate()
		counts[index] = maxi(1, value)
		_set_property(current, &"roster_counts", counts, "Modifier une quantité")
	)


func _remove_roster_index(index: int) -> void:
	var encounter := session.current_encounter()
	if encounter == null or index < 0 or index >= encounter.roster_units.size():
		return
	_ensure_editable(func():
		var current := session.current_encounter()
		var units: Array[UnitData] = current.roster_units.duplicate()
		var counts := current.roster_counts.duplicate()
		units.remove_at(index)
		if index < counts.size(): counts.remove_at(index)
		_set_properties(current, {&"roster_units": units, &"roster_counts": counts}, "Retirer une unité")
	)


func _refresh_disabled_abilities(parent: Control, encounter: EncounterDefinition) -> void:
	parent.add_child(_section("Capacités désactivées"))
	var abilities := {}
	for unit in encounter.roster_units:
		if unit == null: continue
		for spell in unit.spells:
			if spell != null:
				abilities[spell.get_effective_spell_id()] = spell.spell_name
	for ability_id in abilities:
		var checkbox := CheckBox.new()
		checkbox.text = str(abilities[ability_id]) if not str(abilities[ability_id]).is_empty() else "Capacité sans nom"
		checkbox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		checkbox.button_pressed = encounter.disabled_ability_ids.has(ability_id)
		checkbox.toggled.connect(func(disabled): _toggle_disabled_ability(ability_id, disabled))
		parent.add_child(checkbox)


func _toggle_disabled_ability(ability_id: StringName, disabled: bool) -> void:
	if _syncing: return
	if session.current_encounter() == null: return
	_ensure_editable(func():
		var encounter := session.current_encounter()
		var values: Array[StringName] = encounter.disabled_ability_ids.duplicate()
		if disabled and not values.has(ability_id): values.append(ability_id)
		elif not disabled: values.erase(ability_id)
		_set_property(encounter, &"disabled_ability_ids", values, "Modifier les capacités désactivées")
	)


func _toggle_formation(formation_id: StringName, enabled: bool) -> void:
	if _syncing: return
	if session.current_encounter() == null: return
	_ensure_editable(func():
		var encounter := session.current_encounter()
		var values: Array[StringName] = encounter.formation_profiles.duplicate()
		if enabled and not values.has(formation_id): values.append(formation_id)
		elif not enabled: values.erase(formation_id)
		_set_property(encounter, &"formation_profiles", values, "Modifier les formations")
	)


func _set_role_distance(minimum: bool, role: StringName, value: int) -> void:
	if _syncing: return
	if session.current_encounter() == null: return
	_ensure_editable(func():
		var encounter := session.current_encounter()
		var property := &"minimum_path_distance_by_role" if minimum \
			else &"maximum_path_distance_by_role"
		var values: Dictionary = encounter.get(property).duplicate(true)
		values[role] = value
		_set_property(encounter, property, values, "Modifier une distance par rôle")
	)


func _edit_encounter_property(property: StringName, value, action_name: String) -> void:
	if _syncing: return
	if session.current_encounter() == null:
		return
	_ensure_editable(func():
		_set_property(session.current_encounter(), property, value, action_name)
	)


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
	if project_context != null:
		project_context.set_dirty(&"encounter", session.is_dirty())
	call_deferred("_refresh_after_edit")
	history_state_changed.emit()


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
	# Conserver les destinations pour Rétablir. Empreinte et plan d'écriture
	# ne parcourent que les ressources encore atteignables depuis le document.


func _refresh_after_edit() -> void:
	# Une modification doit rendre le domaine explicitement « modifié » dans le
	# contexte partagé : sans cela, une transition sale ne proposerait jamais ses
	# quatre décisions après une édition.
	if project_context != null:
		project_context.set_dirty(&"encounter", session.is_dirty(), {
			"document": RoomDraftAuthority.DRAFT_BANNER if session.room_draft_mode \
				else session.source_run_path,
			"room_draft": session.room_draft_mode,
		})
	_refresh_draft_banner()
	_refresh_composition()
	_refresh_placement()
	_refresh_timeline()
	_refresh_document_actions()
	_refresh_progression()
	_refresh_technical_details()
	generate_preview()
	validate_session()
	_refresh_title()


## En brouillon de salle, la rencontre éditée est déjà une copie isolée
## (RoomDraftAuthority.isolate_gameplay_into) : elle n'est jamais littéralement
## la Resource canonique partagée par d'autres salles du projet. « Modifier »
## n'affecte donc jamais ces autres salles, quel que soit le choix — seul un
## partage *à l'intérieur de ce brouillon* (plusieurs affrontements de la même
## salle pointant vers la même copie) reste réellement concerné. Prévenir d'un
## effet sur « toutes les salles du projet » serait donc faux dans ce mode.
func _draft_local_usage_count(encounter: EncounterDefinition) -> int:
	if not session.room_draft_mode or session.draft_room == null or encounter == null:
		return 0
	var count := 0
	var room := session.draft_room
	if room.encounter_definition == encounter:
		count += 1
	for wave in room.waves:
		if wave != null and wave.encounter_definition == encounter:
			count += 1
	return count


func _shared_acknowledgement_key(encounter: EncounterDefinition) -> String:
	if session.room_draft_mode:
		return "draft:%d" % encounter.get_instance_id()
	return str(_usage_summary(encounter).published.key)


func _ensure_editable(action: Callable) -> void:
	var encounter := session.current_encounter()
	if encounter == null:
		action.call()
		return
	if session.room_draft_mode:
		var local_usage := _draft_local_usage_count(encounter)
		var key := _shared_acknowledgement_key(encounter)
		if local_usage <= 1 or session.shared_edit_acknowledged.has(key) \
				or session.new_resource_paths.has(encounter):
			action.call()
			return
		_pending_shared_action = action
		shared_dialog.dialog_text = (
			"%d affrontements de cette salle partagent encore cette rencontre dans "
			+ "votre brouillon.\n\nModifier la rencontre partagée affectera ces %d "
			+ "affrontements-là. Les autres salles du projet ne sont jamais "
			+ "concernées : votre brouillon ne modifie que sa propre copie.\n\n"
			+ "Action recommandée : DUPLIQUER POUR CET AFFRONTEMENT."
		) % [local_usage, local_usage]
		shared_dialog.popup_centered(Vector2i(650, 360))
		shared_duplicate_button.grab_focus.call_deferred()
		return
	var usage: Dictionary = _usage_summary(encounter).published
	if not usage.ready and session.source_for(encounter) != null:
		_set_status(_reference_scan_state + " — réessayez avant de modifier la rencontre.", true)
		return
	var key := str(usage.key)
	if usage.usage_count <= 1 \
			or session.shared_edit_acknowledged.has(key) \
			or session.new_resource_paths.has(encounter):
		action.call()
		return
	_pending_shared_action = action
	shared_dialog.dialog_text = "Dans le projet publié, cette rencontre est utilisée par %d affrontements dans %d salles.\n\nModifier la rencontre partagée affectera tous ses usages après publication.\n\nAction recommandée : DUPLIQUER POUR CET AFFRONTEMENT." % [usage.usage_count, usage.room_count]
	shared_dialog.popup_centered(Vector2i(650, 360))
	shared_duplicate_button.grab_focus.call_deferred()


func _confirm_shared_edit() -> void:
	var encounter := session.current_encounter()
	session.shared_edit_acknowledged[_shared_acknowledgement_key(encounter)] = true
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
	_set_status("Copie indépendante créée en session ; l'original reste intact.")


func _add_wave() -> void:
	var room := session.current_room()
	if room == null: return
	# Le plafond de la partie reste vrai même si le bouton est contourné
	# (raccourci, script de test, action rejouée par l'historique).
	if room.waves.size() >= _wave_cap():
		_set_status("Limite de %d affrontement(s) atteinte pour cette salle." % _wave_cap(), true)
		return
	var waves: Array[RoomWaveData] = room.waves.duplicate()
	var wave := RoomWaveData.new()
	wave.wave_name = "Affrontement %d" % (waves.size() + 1)
	if not waves.is_empty():
		var previous: RoomWaveData = waves.back() as RoomWaveData
		wave = EncounterCopyService.copy_wave(previous)
		wave.wave_name = "Affrontement %d — copie indépendante" % (waves.size() + 1)
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
	if room.waves.size() >= _wave_cap():
		_set_status("Limite de %d affrontement(s) atteinte pour cette salle." % _wave_cap(), true)
		return
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
	_set_property(room, &"waves", waves, "Réordonner les affrontements")
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
		_set_status("Migration appliquée uniquement à la version en cours. Sauvegardez pour confirmer.")


func _undo() -> void:
	var history := _active_undo_redo()
	if history != null and history.has_undo():
		history.undo()
		history_state_changed.emit()


func _redo() -> void:
	var history := _active_undo_redo()
	if history != null and history.has_redo():
		history.redo()
		history_state_changed.emit()


func history_can_undo() -> bool:
	var value := _active_undo_redo()
	return value != null and value.has_undo()


func history_can_redo() -> bool:
	var value := _active_undo_redo()
	return value != null and value.has_redo()


func history_undo() -> bool:
	if not history_can_undo():
		return false
	_undo()
	return true


func history_redo() -> bool:
	if not history_can_redo():
		return false
	_redo()
	return true


func history_undo_name() -> String:
	var value := _active_undo_redo()
	return value.get_current_action_name() \
		if value != null and value.has_undo() else ""


func history_redo_name() -> String:
	var value := _active_undo_redo()
	if value == null or not value.has_redo():
		return ""
	var index := value.get_current_action() + 1
	return value.get_action_name(index) \
		if index >= 0 and index < value.get_history_count() else "Action"


func history_entries() -> Array[Dictionary]:
	var value := _active_undo_redo()
	var result: Array[Dictionary] = []
	if value == null:
		return result
	var current := value.get_current_action()
	for index in range(value.get_history_count()):
		result.append({
			"index": index + 1,
			"name": value.get_action_name(index),
			"applied": index <= current,
			"current": index == current,
			"saved": false,
		})
	return result


func history_current_index() -> int:
	var value := _active_undo_redo()
	return value.get_current_action() + 1 if value != null else 0


func history_jump_to(index: int) -> bool:
	var value := _active_undo_redo()
	if value == null or index < 0 or index > value.get_history_count():
		return false
	while value.get_current_action() + 1 > index:
		if not value.undo():
			return false
	while value.get_current_action() + 1 < index:
		if not value.redo():
			return false
	history_state_changed.emit()
	return true


func history_document_name() -> String:
	return session.working_run.run_name \
		if session.working_run != null else "Aucune partie"


func history_is_at_saved_state() -> bool:
	return session.working_run != null and not session.is_dirty()


func history_opening_is_saved() -> bool:
	return session.working_run != null and session.opening_fingerprint == session.saved_fingerprint


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
	if catalog_cards_box != null:
		_filter_catalog(_catalog_search_text)


func _usage_summary(encounter: EncounterDefinition) -> Dictionary:
	var source := session.source_for(encounter) as EncounterDefinition
	var published := EncounterReferenceGraphService.published_summary(source, shared_reference_graph)
	var local := EncounterReferenceGraphService.summary_for(encounter,
		EncounterReferenceGraphService.build_for_run(session.working_run))
	local["scope"] = "room_draft" if session.room_draft_mode else "working_copy"
	if session.room_draft_mode:
		local.usage_count = _draft_local_usage_count(encounter)
		local.room_count = 1 if local.usage_count > 0 else 0
	return {"published": published, "local": local}


func _usage_count(encounter: EncounterDefinition) -> int:
	var summary := _usage_summary(encounter)
	return int(summary.local.usage_count) if session.room_draft_mode \
		else int(summary.published.usage_count)


func _usage_badge(encounter: EncounterDefinition) -> String:
	if encounter == null:
		return ""
	if session.room_draft_mode:
		return " • PARTAGÉE DANS LE BROUILLON" if _draft_local_usage_count(encounter) > 1 else ""
	var published: Dictionary = _usage_summary(encounter).published
	if not published.ready:
		return " • ANALYSE EN COURS"
	return " • PARTAGÉE (PROJET PUBLIÉ)" if published.usage_count > 1 else ""


func _usage_text(summary: Dictionary) -> String:
	var published: Dictionary = summary.published
	var local: Dictionary = summary.local
	var text := "Usages de cette rencontre"
	if published.ready:
		text += "\nProjet publié : %d affrontement(s), %d salle(s)." % [published.usage_count, published.room_count]
	else:
		text += "\nProjet publié : " + _reference_scan_state + "."
	text += "\n%s : %d référence(s)." % ["Brouillon courant" if session.room_draft_mode else "Copie de travail", local.usage_count]
	return text


func _disconnect_reference_graph() -> void:
	if shared_reference_graph == null:
		return
	for connection in [
		[shared_reference_graph.scan_started, _on_reference_scan_started],
		[shared_reference_graph.scan_progress, _on_reference_scan_progress],
		[shared_reference_graph.scan_completed, _on_reference_scan_completed],
		[shared_reference_graph.scan_cancelled, _on_reference_scan_cancelled],
		[shared_reference_graph.invalidated, _on_reference_invalidated],
	]:
		if connection[0].is_connected(connection[1]):
			connection[0].disconnect(connection[1])


func _on_reference_scan_started() -> void:
	_reference_scan_state = "Analyse des usages en cours"
	_queue_reference_refresh()


func _on_reference_scan_progress(completed: int, total: int, _label: String) -> void:
	_reference_scan_state = "Analyse des usages en cours (%d/%d)" % [completed, total]
	_queue_reference_refresh()


func _on_reference_scan_completed(_report: Dictionary) -> void:
	_queue_reference_refresh()


func _on_reference_scan_cancelled(_report: Dictionary) -> void:
	_reference_scan_state = "Analyse des usages annulée — résultats indisponibles"
	_queue_reference_refresh()


func _on_reference_invalidated(_keys: PackedStringArray) -> void:
	_reference_scan_state = "Analyse des usages en cours"
	_queue_reference_refresh()
	# Un lot de publications peut invalider plusieurs fichiers. Un seul scan
	# différé du service partagé suffit ; scan(false) conserve son cache.
	if not _reference_scan_queued:
		_reference_scan_queued = true
		call_deferred("_scan_invalidated_references")


func _scan_invalidated_references() -> void:
	_reference_scan_queued = false
	if shared_reference_graph != null:
		shared_reference_graph.scan()


func _queue_reference_refresh() -> void:
	if not _reference_refresh_queued:
		_reference_refresh_queued = true
		call_deferred("_refresh_reference_summary")


func _refresh_reference_summary() -> void:
	_reference_refresh_queued = false
	if not is_inside_tree() or session.working_run == null or composition_box == null:
		return
	# Ne pas relancer la preview ni détruire un champ en cours de saisie.
	if is_instance_valid(_usage_label):
		_usage_label.text = _usage_text(_usage_summary(session.current_encounter()))
	_refresh_timeline()
	_refresh_technical_details()


func _invalidate_published_paths(result: Dictionary) -> void:
	if shared_reference_graph == null:
		return
	for path in result.get("saved_paths", []):
		shared_reference_graph.invalidate(str(path))


func _wave_tooltip(wave: RoomWaveData, encounter: EncounterDefinition) -> String:
	return "%s\nPV ×%.2f • Attaque ×%.2f • Récompense ×%.2f\n%s" % [
		"%d ennemi(s)" % encounter.get_initial_enemy_count() if encounter != null else "Rencontre absente",
		wave.enemy_health_multiplier if wave != null else 1.0,
		wave.enemy_attack_multiplier if wave != null else 1.0,
		wave.reward_multiplier if wave != null else 1.0,
		_usage_text(_usage_summary(encounter)) if encounter != null else "Aucune rencontre",
	]


func _format_analysis(report: Dictionary) -> String:
	return EncounterPresentation.analysis(report)


func _refresh_title() -> void:
	if title_label == null: return
	title_label.text = "STUDIO DE RENCONTRES%s" % (" • MODIFIÉ" if session.is_dirty() else "")


func _set_status(message: String, error := false) -> void:
	if status_label == null: return
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if error else Color(0.74, 0.84, 0.94))


func _show_operation_failure(explanation: String, result: Dictionary) -> void:
	_operation_details = result.duplicate(true)
	_refresh_technical_details()
	_set_status(explanation + ". Consultez Détails techniques.", true)


func _add_button(
		parent: Control, text: String, callback: Callable,
		icon_name := "", destructive := false
	) -> Button:
	var button := Button.new()
	button.text = text
	# G6 — une hauteur commune évite les boutons de hauteurs incohérentes sur
	# une même barre ; la largeur reste libre pour garder chaque libellé lisible.
	button.custom_minimum_size.y = EncounterVisualConstants.BUTTON_MIN_HEIGHT
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	focus_style.border_color = Color(1.0, 0.82, 0.2, 1.0)
	focus_style.set_border_width_all(2)
	focus_style.corner_radius_top_left = 3
	focus_style.corner_radius_top_right = 3
	focus_style.corner_radius_bottom_left = 3
	focus_style.corner_radius_bottom_right = 3
	button.add_theme_stylebox_override("focus", focus_style)
	if destructive:
		EncounterVisualConstants.apply_destructive_style(button)
	if not icon_name.is_empty() and has_theme_icon(icon_name, "EditorIcons"):
		button.icon = get_theme_icon(icon_name, "EditorIcons")
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	scroll.follow_focus = true
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	properties_tabs.add_child(scroll)
	return box


func _rich_page(name: String) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.name = name
	text.bbcode_enabled = false
	text.fit_content = false
	properties_tabs.add_child(text)
	return text


func _add_line_edit(parent: Control, label_text: String, value: String, callback: Callable) -> void:
	var label := _wrapped_label(label_text); parent.add_child(label)
	var edit := LineEdit.new(); edit.text = value; edit.text_submitted.connect(callback); edit.focus_exited.connect(func(): callback.call(edit.text)); parent.add_child(edit)


func _add_int_spin(parent: Control, label_text: String, value: int, minimum: int, maximum: int, callback: Callable) -> void:
	var row := HBoxContainer.new(); var label := _wrapped_label(label_text); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
	var spin := SpinBox.new(); spin.min_value = minimum; spin.max_value = maximum; spin.step = 1; spin.value = value; spin.value_changed.connect(func(new_value): callback.call(int(new_value))); row.add_child(spin); parent.add_child(row)


func _add_float_spin(parent: Control, label_text: String, value: float, minimum: float, maximum: float, callback: Callable) -> void:
	var row := HBoxContainer.new(); var label := _wrapped_label(label_text); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
	var spin := SpinBox.new(); spin.min_value = minimum; spin.max_value = maximum; spin.step = 0.05; spin.value = value; spin.value_changed.connect(callback); row.add_child(spin); parent.add_child(row)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
