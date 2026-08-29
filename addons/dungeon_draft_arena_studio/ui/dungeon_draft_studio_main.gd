@tool
class_name DungeonDraftStudioMain
extends Control

signal detach_requested
signal reintegrate_requested
signal skill_studio_requested

var editor_interface = null
var editor_undo_redo = null
var tabs: TabContainer
var arena_studio: ArenaStudioMain
var encounter_studio: EncounterStudioMain
var item_studio: ItemStudioMain
var vfx_composer: VFXComposer
var undo_button: Button
var redo_button: Button
var history_button: MenuButton
var home_button: Button
var document_label: Label
var document_state_label: Label
var save_button: Button
var validate_button: Button
var test_button: Button
## Action principale « Créer les combats de la salle » du parcours Terrain.
var create_encounters_button: Button
var produce_button: Button
var lab_transfer_button: Button
var lab_menu_button: MenuButton
var workspace_preset_option: OptionButton
var preview_view_option: OptionButton
var focus_map_button: Button
var detach_button: Button
var skill_studio_button: Button
var guided_toggle: CheckButton
var window_menu_button: MenuButton
var domain_buttons: Array[Button] = []
var detached := false
var _pending_state := {}
var studio_title_label: Label
var detach_shortcut_text := "Ctrl+Shift+D"
var project_context: StudioProjectContext = null
var reference_graph: StudioReferenceGraphService = null
var context_bar: StudioContextBar = null
## Les runners peuvent fournir eux-mêmes leur working copy sans déclencher
## l'import de production initial. Le comportement des hôtes reste vrai.
var arena_auto_load_enabled := true
var arena_production_planning_enabled := true


func setup(
		host_editor_interface,
		undo_manager,
		shared_context: StudioProjectContext = null,
		shared_reference_graph: StudioReferenceGraphService = null
	) -> void:
	editor_interface = host_editor_interface
	editor_undo_redo = undo_manager
	project_context = shared_context
	reference_graph = shared_reference_graph


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	context_bar = StudioContextBar.new()
	context_bar.setup(project_context, reference_graph)
	root.add_child(_build_domain_bar())
	root.add_child(_build_shared_history_bar())
	tabs = TabContainer.new()
	tabs.tabs_visible = false
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	arena_studio = ArenaStudioMain.new()
	arena_studio.name = "Arenes"
	arena_studio.auto_load_initial_arena = arena_auto_load_enabled
	arena_studio.production_planning_enabled = arena_production_planning_enabled
	arena_studio.setup(editor_interface, editor_undo_redo, project_context, reference_graph)
	arena_studio.domain_navigation_requested.connect(_on_domain_navigation_requested)
	tabs.add_child(arena_studio)
	# Le shell commun porte désormais les mêmes actions via leurs handlers
	# existants. La barre Terrain interne reste instanciée comme adaptateur
	# d'état, mais n'occupe plus une seconde ligne dans l'espace de travail.
	arena_studio.header_bar.hide()
	# Seul le libelle visible change : ArenaDefinition, ArenaStudioMain et les
	# contrats techniques conservent leurs noms internes.
	tabs.set_tab_title(tabs.get_tab_count() - 1, TerrainVocabulary.TAB_TITLE)
	tabs.set_tab_tooltip(tabs.get_tab_count() - 1, TerrainVocabulary.TAB_SUBTITLE)

	encounter_studio = EncounterStudioMain.new()
	encounter_studio.name = "Rencontres"
	encounter_studio.setup(editor_interface, editor_undo_redo, project_context, reference_graph)
	encounter_studio.open_arena_requested.connect(_open_arena_tab)
	encounter_studio.room_draft_opened.connect(_on_room_draft_opened)
	tabs.add_child(encounter_studio)
	tabs.set_tab_title(tabs.get_tab_count() - 1, "RENCONTRES")

	item_studio = ItemStudioMain.new()
	item_studio.name = "Objets"
	item_studio.setup(editor_interface, editor_undo_redo, project_context, reference_graph)
	tabs.add_child(item_studio)
	tabs.set_tab_title(tabs.get_tab_count() - 1, "OBJETS")
	tabs.tab_changed.connect(_on_tab_changed)
	arena_studio.history_state_changed.connect(_refresh_history_controls)
	encounter_studio.history_state_changed.connect(_refresh_history_controls)
	item_studio.history_state_changed.connect(_refresh_history_controls)

	vfx_composer = VFXComposer.new()
	vfx_composer.name = "VFX"
	tabs.add_child(vfx_composer)
	tabs.set_tab_title(tabs.get_tab_count() - 1, "EFFETS VISUELS")
	vfx_composer.history_state_changed.connect(_refresh_history_controls)

	if not _pending_state.is_empty():
		apply_state_snapshot(_pending_state)
		_pending_state.clear()
	_refresh_history_controls()
	_refresh_domain_buttons()
	_apply_theme_icons()
	resized.connect(_apply_toolbar_responsive)
	call_deferred("_apply_toolbar_responsive")
	call_deferred("_sync_shell_from_arena")


func _build_domain_bar() -> Control:
	var panel := PanelContainer.new()
	panel.name = "StudioDomainBar"
	panel.custom_minimum_size.y = 38
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	panel.add_child(bar)
	studio_title_label = Label.new()
	studio_title_label.text = StudioVersion.display_name()
	studio_title_label.custom_minimum_size.x = 224
	studio_title_label.add_theme_color_override("font_color", Color(0.48, 0.86, 1.0))
	studio_title_label.add_theme_font_size_override("font_size", 16)
	bar.add_child(studio_title_label)
	for index in range(4):
		var button := Button.new()
		button.flat = true
		button.toggle_mode = true
		button.text = [TerrainVocabulary.TAB_TITLE, "Rencontres", "Objets", "Effets visuels"][index]
		button.pressed.connect(_select_domain.bind(index))
		bar.add_child(button)
		domain_buttons.append(button)
	skill_studio_button = Button.new()
	skill_studio_button.flat = true
	skill_studio_button.text = "Compétences"
	skill_studio_button.tooltip_text = "Ouvrir le Studio des personnages et compétences"
	skill_studio_button.pressed.connect(func(): skill_studio_requested.emit())
	bar.add_child(skill_studio_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	context_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	bar.add_child(context_bar)
	window_menu_button = MenuButton.new()
	window_menu_button.text = "Fenêtre ▾"
	window_menu_button.tooltip_text = "Options de fenêtre et outils secondaires"
	window_menu_button.get_popup().id_pressed.connect(_on_window_menu_pressed)
	window_menu_button.get_popup().about_to_popup.connect(_rebuild_window_menu)
	bar.add_child(window_menu_button)
	return panel


func _build_shared_history_bar() -> Control:
	var panel := PanelContainer.new()
	panel.name = "StudioDocumentBar"
	panel.custom_minimum_size.y = 46
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("separation", 5)
	panel.add_child(bar)
	home_button = _global_button(
		bar, "Accueil", _open_terrain_home,
		"Quitter le terrain courant pour en ouvrir ou en créer un autre"
	)
	var document_box := VBoxContainer.new()
	document_box.custom_minimum_size.x = 168
	document_box.add_theme_constant_override("separation", 0)
	bar.add_child(document_box)
	document_label = Label.new()
	document_label.text = "Aucune arène"
	document_label.clip_text = true
	document_label.tooltip_text = "Document actif"
	document_box.add_child(document_label)
	document_state_label = Label.new()
	document_state_label.text = "Enregistré"
	document_state_label.add_theme_font_size_override("font_size", 12)
	document_box.add_child(document_state_label)
	undo_button = Button.new()
	undo_button.text = "Annuler"
	undo_button.pressed.connect(_undo_active)
	bar.add_child(undo_button)
	redo_button = Button.new()
	redo_button.text = "Rétablir"
	redo_button.pressed.connect(_redo_active)
	bar.add_child(redo_button)
	history_button = MenuButton.new()
	history_button.text = "Historique ▾"
	history_button.tooltip_text = "Parcourir l'historique du document"
	history_button.get_popup().id_pressed.connect(_on_file_entry_pressed)
	history_button.get_popup().about_to_popup.connect(_rebuild_file_menu)
	bar.add_child(history_button)
	guided_toggle = CheckButton.new()
	guided_toggle.text = "Mode guidé"
	guided_toggle.button_pressed = true
	guided_toggle.tooltip_text = "Masquer les réglages techniques et afficher les consignes"
	guided_toggle.toggled.connect(_on_guided_toggled)
	bar.add_child(guided_toggle)
	# Le libellé est ensuite ajusté à l'autorité réellement ouverte.
	save_button = _global_button(
		bar, "Enregistrer le brouillon", _global_save,
		"Garder le travail en cours dans votre dossier personnel. Aucune partie n'est modifiée."
	)
	validate_button = _global_button(
		bar, "Validation…", _global_validate,
		"Ouvrir les erreurs et avertissements du document actif"
	)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	bar.move_child(spacer, validate_button.get_index())
	test_button = _global_button(
		bar, "Tester", _global_test,
		"Lancer un vrai combat sur la version en cours, sans rien publier"
	)
	# Étape intermédiaire du parcours : elle ne publie rien et n'ouvre pas
	# l'assistant d'intégration. Elle ouvre le brouillon de salle courant dans
	# Rencontres. Voir RoomDraftAuthority.
	create_encounters_button = _global_button(
		bar, RoomDraftAuthority.ENCOUNTERS_ACTION_LABEL, _global_create_encounters,
		RoomDraftAuthority.ENCOUNTERS_ACTION_HELP
	)
	create_encounters_button.name = "StudioCreateRoomEncountersButton"
	produce_button = _global_button(
		bar, "Intégrer à la partie", _global_produce,
		"Dernière étape : publier le terrain et ses affrontements dans une salle"
	)
	workspace_preset_option = OptionButton.new()
	workspace_preset_option.tooltip_text = "Disposition de l'espace de travail"
	for preset in ["Construction", "Calibration", "Gameplay", "Aperçu final"]:
		workspace_preset_option.add_item(preset)
	workspace_preset_option.item_selected.connect(_on_workspace_preset_selected)
	workspace_preset_option.visible = false
	# Modèle d'état interne du menu Fenêtre. Il ne doit jamais être enfant d'un
	# Container : un rafraîchissement de visibilité ne peut ainsi plus lui faire
	# réserver toute une ligne dans la barre du Studio.
	add_child(workspace_preset_option)
	preview_view_option = OptionButton.new()
	preview_view_option.tooltip_text = "Vue Structure / Décor / Résultat en jeu"
	for preview_view in ["Structure", "Décor", "Résultat en jeu"]:
		preview_view_option.add_item(preview_view)
	preview_view_option.item_selected.connect(_on_preview_view_selected)
	bar.add_child(preview_view_option)
	focus_map_button = _global_button(
		panel, "Agrandir", _toggle_focus_map,
		"Agrandir la carte en plein panneau (Tab)"
	)
	focus_map_button.visible = false
	detach_button = _global_button(
		panel, "Détacher la fenêtre", func(): detach_requested.emit(),
		"Détacher la fenêtre du Studio (Ctrl+Shift+D)"
	)
	detach_button.visible = false
	bar.move_child(preview_view_option, guided_toggle.get_index() + 1)
	bar.move_child(spacer, preview_view_option.get_index() + 1)
	bar.move_child(validate_button, spacer.get_index() + 1)
	bar.move_child(save_button, validate_button.get_index() + 1)
	bar.move_child(test_button, save_button.get_index() + 1)
	bar.move_child(create_encounters_button, test_button.get_index() + 1)
	bar.move_child(produce_button, create_encounters_button.get_index() + 1)
	return panel


func ensure_initial_content_loaded() -> void:
	if arena_studio != null:
		arena_studio.ensure_initial_arena_loaded()
	if item_studio != null:
		item_studio.ensure_initial_content_loaded()
	if vfx_composer != null:
		vfx_composer.ensure_initial_content_loaded()


func get_state_snapshot() -> Dictionary:
	return {
		"tab": tabs.current_tab if tabs != null else 0,
		"detached": detached,
		"workspace_preset": workspace_preset_option.selected \
			if workspace_preset_option != null else 0,
		"preview_view": preview_view_option.selected \
			if preview_view_option != null else 0,
		"arena_workspace": arena_studio.get_workspace_state() \
			if arena_studio != null and arena_studio.has_method("get_workspace_state") else {},
		"encounter": encounter_studio.get_state_snapshot() \
			if encounter_studio != null else {},
		"items": item_studio.get_state_snapshot() \
			if item_studio != null else {},
		"vfx": vfx_composer.get_state_snapshot() \
			if vfx_composer != null else {},
		"project_context": project_context.snapshot() if project_context != null else {},
	}


func apply_state_snapshot(state: Dictionary) -> void:
	if not is_node_ready() or tabs == null or encounter_studio == null or item_studio == null:
		_pending_state = state.duplicate(true)
		return
	tabs.current_tab = clampi(int(state.get("tab", 0)), 0, tabs.get_tab_count() - 1)
	if workspace_preset_option != null:
		workspace_preset_option.select(clampi(
			int(state.get("workspace_preset", 0)), 0,
			workspace_preset_option.item_count - 1
		))
		_on_workspace_preset_selected(workspace_preset_option.selected)
	if preview_view_option != null:
		preview_view_option.select(clampi(
			int(state.get("preview_view", 0)), 0,
			preview_view_option.item_count - 1
		))
		_on_preview_view_selected(preview_view_option.selected)
	var arena_workspace = state.get("arena_workspace", {})
	if arena_workspace is Dictionary and arena_studio.has_method("apply_workspace_state"):
		arena_studio.apply_workspace_state(arena_workspace)
	var encounter_state = state.get("encounter", {})
	if encounter_state is Dictionary:
		encounter_studio.apply_state_snapshot(encounter_state)
	var item_state = state.get("items", {})
	if item_state is Dictionary:
		item_studio.apply_state_snapshot(item_state)
	var vfx_state = state.get("vfx", {})
	if vfx_state is Dictionary and vfx_composer != null:
		vfx_composer.apply_state_snapshot(vfx_state)
	_refresh_history_controls()


func _open_arena_tab() -> void:
	if tabs != null:
		tabs.current_tab = 0


func prepare_for_close() -> void:
	if arena_studio != null and arena_studio.has_method("cancel_active_gesture"):
		arena_studio.cancel_active_gesture()
	if arena_studio != null and arena_studio.has_method("_flush_recovery"):
		arena_studio._flush_recovery()
	if item_studio != null:
		item_studio.prepare_for_close()
	if vfx_composer != null:
		vfx_composer.prepare_for_close()


func cancel_active_gesture() -> bool:
	return arena_studio != null and arena_studio.cancel_active_gesture()


func _active_history_provider():
	if tabs == null:
		return null
	match tabs.current_tab:
		0:
			return arena_studio
		1:
			return encounter_studio
		2:
			return item_studio
		3:
			return vfx_composer
	return null


func _undo_active() -> void:
	var provider = _active_history_provider()
	if provider != null and provider.history_can_undo():
		provider.history_undo()
	_refresh_history_controls()


func _redo_active() -> void:
	var provider = _active_history_provider()
	if provider != null and provider.history_can_redo():
		provider.history_redo()
	_refresh_history_controls()


func _refresh_history_controls() -> void:
	if undo_button == null or redo_button == null or history_button == null:
		return
	var provider = _active_history_provider()
	var undo_name: String = provider.history_undo_name() if provider != null else ""
	var redo_name: String = provider.history_redo_name() if provider != null else ""
	undo_button.disabled = provider == null or not provider.history_can_undo()
	redo_button.disabled = provider == null or not provider.history_can_redo()
	undo_button.tooltip_text = "Annuler : %s" % undo_name \
		if not undo_name.is_empty() else "Rien à annuler"
	redo_button.tooltip_text = "Rétablir : %s" % redo_name \
		if not redo_name.is_empty() else "Rien à rétablir"
	history_button.disabled = provider == null
	if document_label != null:
		document_label.text = provider.history_document_name() if provider != null else "Aucun document"
		document_label.tooltip_text = document_label.text
	var arena_active := tabs != null and tabs.current_tab == 0
	if home_button != null:
		home_button.visible = arena_active
	if produce_button != null:
		produce_button.visible = arena_active or _active_room_draft()
		produce_button.disabled = not (arena_active or _active_room_draft())
	if create_encounters_button != null:
		create_encounters_button.visible = arena_active
	# Dispositions, laboratoire et transferts sont des preferences avancees :
	# ils disparaissent du parcours guide au lieu de concurrencer le rail des
	# etapes du domaine Terrain.
	var terrain_guided := arena_active and arena_studio != null \
		and arena_studio.has_method("is_guided") and arena_studio.is_guided()
	if workspace_preset_option != null:
		workspace_preset_option.disabled = not arena_active
		workspace_preset_option.visible = false
	if lab_menu_button != null:
		lab_menu_button.visible = not terrain_guided
	if lab_transfer_button != null:
		lab_transfer_button.visible = not terrain_guided
	if preview_view_option != null:
		preview_view_option.disabled = not arena_active
		# Le sélecteur partagé remplace désormais celui de l'en-tête Terrain
		# replié : une seule commande reste visible dans le shell.
		preview_view_option.visible = arena_active
	if focus_map_button != null:
		focus_map_button.disabled = not arena_active
	if lab_transfer_button != null and arena_studio != null:
		var transfer_count := arena_studio.pending_lab_transfer_count()
		lab_transfer_button.text = "Importer depuis le laboratoire (%d)" % transfer_count \
			if transfer_count > 0 else "Importer depuis le laboratoire"
	if guided_toggle != null:
		guided_toggle.disabled = false
		guided_toggle.visible = tabs == null or tabs.current_tab != 1
	_sync_shell_from_arena()
	_refresh_action_labels()


func _rebuild_file_menu() -> void:
	var popup := history_button.get_popup()
	popup.clear()
	var provider = _active_history_provider()
	if provider == null:
		popup.add_item("Aucun document", -1)
		popup.set_item_disabled(popup.item_count - 1, true)
		return
	popup.add_item(provider.history_document_name(), -1)
	popup.set_item_disabled(popup.item_count - 1, true)
	popup.add_separator()
	var current_index: int = provider.history_current_index()
	popup.add_item("● Position actuelle — étape %d" % current_index, -2)
	popup.set_item_disabled(popup.item_count - 1, true)
	popup.add_separator()
	var opening_saved: bool = provider.has_method("history_opening_is_saved") \
		and provider.history_opening_is_saved()
	if not opening_saved:
		opening_saved = current_index == 0 \
			and provider.has_method("history_is_at_saved_state") \
			and provider.history_is_at_saved_state()
	popup.add_item(
		("● " if current_index == 0 else "  ") + "Ouverture du document" \
		+ ("  ✓ sauvegardée" if opening_saved else ""), 0
	)
	for entry_value in provider.history_entries():
		var entry := entry_value as Dictionary
		var marker := "● " if int(entry.get("index", -1)) == current_index else "  "
		var saved := "  ✓ sauvegardée" if bool(entry.get("saved", false)) else ""
		var undone := "  (rétablissable)" if not bool(entry.get("applied", false)) else ""
		popup.add_item(
			"%s%s%s%s" % [marker, entry.get("name", "Action"), saved, undone],
			int(entry.get("index", 0)),
		)


## Adaptateur de compatibilité : le menu Fichier contient désormais
## l'historique, mais l'ancien contrat de reconstruction reste callable.
func _rebuild_history_menu() -> void:
	_rebuild_file_menu()


func _on_file_entry_pressed(index: int) -> void:
	if index < 0:
		return
	var provider = _active_history_provider()
	if provider != null:
		provider.history_jump_to(index)
	_refresh_history_controls()


func _on_tab_changed(_index: int) -> void:
	if arena_studio != null and arena_studio.has_method("cancel_active_gesture"):
		arena_studio.cancel_active_gesture()
	# Terrain et Rencontres partagent le même brouillon de salle. Revenir dans
	# Rencontres reconstruit seulement sa projection visuelle en lecture seule ;
	# les affrontements et leurs historiques restent sur l'autorité partagée.
	if tabs != null and tabs.current_tab == 1 and encounter_studio != null \
			and encounter_studio.is_room_draft_mode() and arena_studio != null \
			and encounter_studio.session.draft_room == arena_studio.room_draft():
		encounter_studio.refresh_draft_context(
			project_context.active_run if project_context != null else null
		)
	_report_obsolete_room_draft()
	_refresh_history_controls()
	_refresh_domain_buttons()


## Un changement d'onglet ne synchronise jamais les domaines : il se contente de
## signaler qu'un brouillon ouvert dans Rencontres ne correspond plus au terrain
## courant. Rouvrir passe par « Créer les combats de la salle ».
func _report_obsolete_room_draft() -> void:
	if encounter_studio == null or arena_studio == null \
			or not encounter_studio.is_room_draft_mode():
		return
	if encounter_studio.session.draft_room == arena_studio.room_draft():
		return
	encounter_studio._set_status(
		"Ce brouillon ne correspond plus au terrain ouvert. Revenez dans Terrain "
		+ "et cliquez sur « %s »." % RoomDraftAuthority.ENCOUNTERS_ACTION_LABEL,
		true
	)


func _select_domain(index: int) -> void:
	if tabs != null and index >= 0 and index < tabs.get_tab_count():
		tabs.current_tab = index


func _refresh_domain_buttons() -> void:
	if tabs == null:
		return
	for index in range(domain_buttons.size()):
		domain_buttons[index].set_pressed_no_signal(index == tabs.current_tab)


func _on_guided_toggled(value: bool) -> void:
	if arena_studio != null:
		arena_studio.set_guided(value)
	if item_studio != null and item_studio.has_method("set_guided"):
		item_studio.set_guided(value)
	_refresh_history_controls()


func _on_domain_navigation_requested(domain: StringName) -> void:
	if tabs == null:
		return
	match domain:
		&"encounters":
			# Le brouillon de salle de Terrain est l'autorité ouverte ici : rien
			# n'est publié, la partie active ne sert que de contexte de lecture.
			var draft := arena_studio.room_draft()
			if draft == null:
				arena_studio._set_status(
					"Ouvrez ou créez un terrain avant de créer ses combats.", true
				)
				return
			if not encounter_studio.open_room_draft(
					draft,
					project_context.active_run if project_context != null else null,
					project_context.active_run.resource_path \
						if project_context != null and project_context.active_run != null else "",
					arena_studio.room_draft_gameplay_mapping()
				):
				if project_context != null and project_context.has_pending_transition():
					return
				arena_studio._set_status(
					"Rencontres n'a pas pu ouvrir ce brouillon de salle.", true
				)
				return
			if arena_studio.production_dialog != null:
				arena_studio.production_dialog.hide()
			tabs.current_tab = 1
		&"items":
			tabs.current_tab = 2
	_refresh_domain_buttons()
	_refresh_history_controls()


func _on_room_draft_opened() -> void:
	if arena_studio.production_dialog != null:
		arena_studio.production_dialog.hide()
	tabs.current_tab = 1
	_refresh_domain_buttons()
	_refresh_history_controls()


func _rebuild_window_menu() -> void:
	var popup := window_menu_button.get_popup()
	popup.clear()
	popup.add_item("Restaurer l'affichage" if focus_map_button != null \
		and focus_map_button.button_pressed else "Agrandir le terrain", 0)
	popup.add_item("Réintégrer la fenêtre" if detached else "Détacher la fenêtre", 1)
	popup.add_separator("Disposition")
	for index in range(4):
		popup.add_radio_check_item(["Construction", "Calibration", "Gameplay", "Aperçu final"][index], 10 + index)
		popup.set_item_checked(popup.item_count - 1, workspace_preset_option != null \
			and workspace_preset_option.selected == index)
	popup.add_separator("Laboratoire")
	popup.add_item("Importer depuis le laboratoire", 20)
	popup.add_item("Ouvrir le laboratoire autonome", 21)


func _on_window_menu_pressed(id: int) -> void:
	match id:
		0:
			_toggle_focus_map()
		1:
			detach_requested.emit()
		20:
			_global_lab_transfer()
		21:
			if arena_studio != null:
				arena_studio.open_standalone_lab()
		_:
			if id >= 10 and id < 14 and workspace_preset_option != null:
				workspace_preset_option.select(id - 10)
				_on_workspace_preset_selected(id - 10)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if _text_control_has_focus():
		return
	if _matches_detach_shortcut(key):
		detach_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if not key.ctrl_pressed and not key.alt_pressed and key.keycode == KEY_TAB:
		_toggle_focus_map()
		get_viewport().set_input_as_handled()
		return
	if not key.ctrl_pressed:
		return
	var requests_undo := key.keycode == KEY_Z and not key.shift_pressed
	var requests_redo := (key.keycode == KEY_Z and key.shift_pressed) \
		or key.keycode == KEY_Y
	if not requests_undo and not requests_redo:
		return
	var provider = _active_history_provider()
	if provider == null:
		return
	if provider.has_method("cancel_active_gesture") \
			and provider.cancel_active_gesture():
		get_viewport().set_input_as_handled()
		return
	var handled := false
	if requests_redo:
		handled = provider.history_redo()
	elif requests_undo:
		handled = provider.history_undo()
	if handled:
		get_viewport().set_input_as_handled()
		_refresh_history_controls()


func _text_control_has_focus() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return true
	var parent := focused.get_parent() if focused != null else null
	return parent is SpinBox


func _apply_theme_icons() -> void:
	if undo_button != null and has_theme_icon("Undo", "EditorIcons"):
		undo_button.icon = get_theme_icon("Undo", "EditorIcons")
		undo_button.text = "Annuler"
	if redo_button != null and has_theme_icon("Redo", "EditorIcons"):
		redo_button.icon = get_theme_icon("Redo", "EditorIcons")
		redo_button.text = "Rétablir"
	if save_button != null and has_theme_icon("Save", "EditorIcons"):
		save_button.icon = get_theme_icon("Save", "EditorIcons")
	if detach_button != null and has_theme_icon("MakeFloatingOn", "EditorIcons"):
		detach_button.icon = get_theme_icon("MakeFloatingOn", "EditorIcons")
	if skill_studio_button != null and has_theme_icon("ScriptCreate", "EditorIcons"):
		skill_studio_button.icon = get_theme_icon("ScriptCreate", "EditorIcons")


func set_detached_state(value: bool) -> void:
	detached = value
	if detach_button != null:
		detach_button.text = "Réintégrer la fenêtre" if detached else "Détacher la fenêtre"
		detach_button.tooltip_text = (
			"Réintégrer la fenêtre dans Godot (Ctrl+Shift+D)" if detached
			else "Détacher la fenêtre du Studio (Ctrl+Shift+D)"
		)
	_apply_toolbar_responsive()


func set_detach_shortcut_string(value: String) -> void:
	detach_shortcut_text = value.strip_edges() if not value.strip_edges().is_empty() \
		else "Ctrl+Shift+D"
	if detach_button != null:
		detach_button.tooltip_text = "%s (%s)" % [
			"Réintégrer la fenêtre dans Godot" if detached \
			else "Détacher la fenêtre du Studio",
			detach_shortcut_text,
		]


func _matches_detach_shortcut(event: InputEventKey) -> bool:
	var parts := detach_shortcut_text.to_upper().replace(" ", "").split("+")
	var requested_key := parts[-1] if not parts.is_empty() else "D"
	var keycode := OS.find_keycode_from_string(requested_key)
	if keycode == KEY_NONE:
		keycode = KEY_D
	return event.pressed and not event.echo and event.keycode == keycode \
		and event.ctrl_pressed == parts.has("CTRL") \
		and event.shift_pressed == parts.has("SHIFT") \
		and event.alt_pressed == parts.has("ALT") \
		and event.meta_pressed == parts.has("META")


func _apply_toolbar_responsive() -> void:
	if studio_title_label == null or detach_button == null:
		return
	var compact := size.x < 1500.0
	# Le shell dispose encore de la place nécessaire à 1280 px : le titre
	# abrégé n'est réservé qu'aux largeurs logiques réellement insuffisantes
	# (notamment lorsqu'une échelle de contenu réduit l'espace disponible).
	var compact_title := uses_compact_title(size.x)
	studio_title_label.text = StudioVersion.display_name(compact_title)
	studio_title_label.tooltip_text = StudioVersion.display_name(false)
	studio_title_label.custom_minimum_size.x = 82 if compact_title else 224
	if document_label != null and document_label.get_parent() != null:
		document_label.get_parent().custom_minimum_size.x = 132 if compact else 168
	undo_button.text = "↶" if compact else "Annuler"
	redo_button.text = "↷" if compact else "Rétablir"
	undo_button.custom_minimum_size.x = 34 if compact else 0
	redo_button.custom_minimum_size.x = 34 if compact else 0
	history_button.text = "Hist." if compact else "Historique ▾"
	home_button.text = "Accueil"
	_refresh_action_labels()
	if guided_toggle != null:
		# En 1280 de large, l'étape « Créer les combats » a besoin de sa place :
		# l'interrupteur garde son sens avec un libellé plus court et son
		# infobulle complète.
		guided_toggle.text = "Guidé" if compact else "Mode guidé"
	if create_encounters_button != null:
		# En 1280 de large la barre est déjà dense : le libellé raccourci garde
		# le même sens et l'aide complète reste dans l'infobulle.
		create_encounters_button.text = (
			RoomDraftAuthority.ENCOUNTERS_ACTION_LABEL_COMPACT if compact
			else RoomDraftAuthority.ENCOUNTERS_ACTION_LABEL
		)
	produce_button.text = "Intégrer à la partie"
	if domain_buttons.size() >= 4:
		domain_buttons[3].text = "VFX" if compact else "Effets visuels"
	workspace_preset_option.custom_minimum_size.x = 104 if compact else 0
	preview_view_option.custom_minimum_size.x = 94 if compact else 138
	if window_menu_button != null:
		window_menu_button.text = "⋮" if compact else "Fenêtre ▾"
		window_menu_button.custom_minimum_size.x = 34 if compact else 0
	if context_bar != null:
		context_bar.set_compact(compact)
	detach_button.text = (
		("Réint. fenêtre" if compact else "Réintégrer la fenêtre") if detached \
		else ("Dét. fenêtre" if compact else "Détacher la fenêtre")
	)


static func uses_compact_title(logical_width: float) -> bool:
	return logical_width < 1120.0


func _global_save() -> void:
	if tabs.current_tab == 0:
		arena_studio.save_draft()
	elif tabs.current_tab == 1 and encounter_studio.has_method("_show_save_dialog"):
		encounter_studio._show_save_dialog()
	elif tabs.current_tab == 2:
		item_studio.save_as_draft()
	elif tabs.current_tab == 3:
		vfx_composer.save_as_draft()


func _active_room_draft() -> bool:
	return tabs != null and tabs.current_tab == 1 and encounter_studio != null \
		and encounter_studio.is_room_draft_mode() and arena_studio != null \
		and encounter_studio.session.draft_room == arena_studio.room_draft()


func _refresh_action_labels() -> void:
	if save_button == null or tabs == null:
		return
	var canonical_encounter := tabs.current_tab == 1 and encounter_studio != null \
		and not encounter_studio.is_room_draft_mode()
	save_button.text = "Publier les rencontres" if canonical_encounter else "Enregistrer le brouillon"
	save_button.tooltip_text = (
		"Publier les changements dans les fichiers de la partie, après confirmation du plan."
		if canonical_encounter else
		"Garder le travail en cours dans votre dossier personnel. Aucune partie n'est modifiée."
	)
	if test_button != null:
		test_button.text = "Tester"
	if tabs.current_tab == 1 and encounter_studio != null:
		validate_button.text = "Valider"
		validate_button.remove_theme_color_override("font_color")
		document_state_label.text = "Modifié" if encounter_studio.session.is_dirty() else "Enregistré"


func _open_terrain_home() -> void:
	if arena_studio != null:
		arena_studio.request_home()


func _global_validate() -> void:
	if tabs.current_tab == 0:
		arena_studio._open_validation_drawer()
	elif tabs.current_tab == 1:
		encounter_studio.validate_session()
	elif tabs.current_tab == 2:
		item_studio.validate_document()
	elif tabs.current_tab == 3:
		vfx_composer.validate_document()
	_sync_shell_from_arena()


func _sync_shell_from_arena() -> void:
	if arena_studio == null:
		return
	if guided_toggle != null:
		guided_toggle.set_pressed_no_signal(arena_studio.is_guided())
	if preview_view_option != null and arena_studio.preview_option != null:
		preview_view_option.select(arena_studio.preview_option.selected)
	if tabs == null or tabs.current_tab != 0:
		return
	if document_state_label != null:
		document_state_label.text = "Brouillon modifié" if arena_studio.dirty else "Enregistré"
		document_state_label.add_theme_color_override(
			"font_color", Color(1.0, 0.66, 0.25) if arena_studio.dirty \
			else Color(0.48, 0.9, 0.62)
		)
	if validate_button != null and arena_studio.header_bar != null:
		var terrain_validation_button := arena_studio.header_bar.get("validation_button") as Button
		if terrain_validation_button != null:
			validate_button.text = terrain_validation_button.text
			validate_button.remove_theme_color_override("font_color")
			if terrain_validation_button.has_theme_color_override("font_color"):
				validate_button.add_theme_color_override(
					"font_color",
					terrain_validation_button.get_theme_color("font_color")
				)


func _global_test() -> void:
	if tabs.current_tab == 0:
		arena_studio.test_arena()
	elif tabs.current_tab == 1:
		encounter_studio.test_current_encounter()
	elif tabs.current_tab == 2:
		item_studio.test_document()
	elif tabs.current_tab == 3:
		vfx_composer.test_document()


func _global_create_encounters() -> void:
	if tabs.current_tab == 0:
		arena_studio.open_room_encounters()


func _global_produce() -> void:
	if (tabs.current_tab == 0 or _active_room_draft()) \
			and arena_studio.has_method("show_production_wizard"):
		tabs.current_tab = 0
		arena_studio.show_production_wizard()


func _global_lab_transfer() -> void:
	if arena_studio == null:
		return
	arena_studio.show_lab_import_dialog()


func _on_workspace_preset_selected(index: int) -> void:
	if arena_studio != null and arena_studio.has_method("apply_workspace_preset"):
		arena_studio.apply_workspace_preset(index)


func _on_preview_view_selected(index: int) -> void:
	if arena_studio != null and arena_studio.has_method("set_preview_view"):
		arena_studio.set_preview_view(index)


func _toggle_focus_map() -> void:
	if arena_studio == null or not arena_studio.has_method("toggle_focus_map"):
		return
	var focused: bool = arena_studio.toggle_focus_map()
	if focus_map_button != null:
		focus_map_button.button_pressed = focused
		focus_map_button.text = "Restaurer" if focused else "Agrandir"


func _global_button(
		parent: Node,
		label: String,
		callback: Callable,
		tooltip: String
	) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
