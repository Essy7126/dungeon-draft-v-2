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
var undo_button: Button
var redo_button: Button
var history_button: MenuButton
var document_label: Label
var save_button: Button
var validate_button: Button
var test_button: Button
var produce_button: Button
var lab_transfer_button: Button
var workspace_preset_option: OptionButton
var preview_view_option: OptionButton
var focus_map_button: Button
var detach_button: Button
var skill_studio_button: Button
var detached := false
var _pending_state := {}
var studio_title_label: Label
var detach_shortcut_text := "Ctrl+Shift+D"


func setup(host_editor_interface, undo_manager) -> void:
	editor_interface = host_editor_interface
	editor_undo_redo = undo_manager


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	root.add_child(_build_shared_history_bar())
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	arena_studio = ArenaStudioMain.new()
	arena_studio.name = "Arenes"
	arena_studio.setup(editor_interface, editor_undo_redo)
	tabs.add_child(arena_studio)
	tabs.set_tab_title(tabs.get_tab_count() - 1, "ARENES")

	encounter_studio = EncounterStudioMain.new()
	encounter_studio.name = "Rencontres"
	encounter_studio.setup(editor_interface, editor_undo_redo)
	encounter_studio.open_arena_requested.connect(_open_arena_tab)
	tabs.add_child(encounter_studio)
	tabs.set_tab_title(tabs.get_tab_count() - 1, "RENCONTRES")
	tabs.tab_changed.connect(_on_tab_changed)
	arena_studio.history_state_changed.connect(_refresh_history_controls)
	encounter_studio.history_state_changed.connect(_refresh_history_controls)

	if not _pending_state.is_empty():
		apply_state_snapshot(_pending_state)
		_pending_state.clear()
	_refresh_history_controls()
	_apply_theme_icons()
	resized.connect(_apply_toolbar_responsive)
	call_deferred("_apply_toolbar_responsive")


func _build_shared_history_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 38
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 5)
	panel.add_child(bar)
	studio_title_label = Label.new()
	studio_title_label.text = "DUNGEON DRAFT STUDIO 1.2.1"
	studio_title_label.custom_minimum_size.x = 224
	studio_title_label.add_theme_color_override("font_color", Color(0.48, 0.86, 1.0))
	studio_title_label.add_theme_font_size_override("font_size", 16)
	bar.add_child(studio_title_label)
	document_label = Label.new()
	document_label.text = "Aucune arene"
	document_label.custom_minimum_size.x = 135
	document_label.clip_text = true
	document_label.tooltip_text = "Document actif"
	bar.add_child(document_label)
	undo_button = Button.new()
	undo_button.text = "↶ Annuler"
	undo_button.pressed.connect(_undo_active)
	bar.add_child(undo_button)
	redo_button = Button.new()
	redo_button.text = "↷ Rétablir"
	redo_button.pressed.connect(_redo_active)
	bar.add_child(redo_button)
	history_button = MenuButton.new()
	history_button.text = "Historique ▾"
	history_button.get_popup().id_pressed.connect(_on_history_entry_pressed)
	history_button.get_popup().about_to_popup.connect(_rebuild_history_menu)
	bar.add_child(history_button)
	save_button = _global_button(bar, "Sauver", _global_save, "Sauvegarder le document actif")
	validate_button = _global_button(bar, "Valider", _global_validate, "Valider le document actif")
	test_button = _global_button(bar, "Tester", _global_test, "Tester la working copy")
	produce_button = _global_button(bar, "Produire", _global_produce, "Produire une salle prete pour la run")
	lab_transfer_button = _global_button(
		bar, "Lab", _global_lab_transfer,
		"Importer le dernier transfert Dynamic Arena Lab vérifié"
	)
	skill_studio_button = _global_button(
		bar, "Compétences", func(): skill_studio_requested.emit(),
		"Ouvrir le Studio autonome des personnages et compétences"
	)
	workspace_preset_option = OptionButton.new()
	workspace_preset_option.tooltip_text = "Disposition du workspace"
	for preset in ["Construction", "Calibration", "Gameplay", "Apercu final"]:
		workspace_preset_option.add_item(preset)
	workspace_preset_option.item_selected.connect(_on_workspace_preset_selected)
	bar.add_child(workspace_preset_option)
	preview_view_option = OptionButton.new()
	preview_view_option.tooltip_text = "Vue Logique / Art / Jeu"
	for preview_view in ["Logique", "Art", "Jeu"]:
		preview_view_option.add_item(preview_view)
	preview_view_option.item_selected.connect(_on_preview_view_selected)
	bar.add_child(preview_view_option)
	focus_map_button = _global_button(bar, "Focus", _toggle_focus_map, "Focus Map (Tab)")
	detach_button = _global_button(
		bar, "Detacher", func(): detach_requested.emit(),
		"Ouvrir dans une fenetre (Ctrl+Shift+D)"
	)
	return panel


func ensure_initial_content_loaded() -> void:
	if arena_studio != null:
		arena_studio.ensure_initial_arena_loaded()


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
	}


func apply_state_snapshot(state: Dictionary) -> void:
	if not is_node_ready() or tabs == null or encounter_studio == null:
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
	_refresh_history_controls()


func _open_arena_tab() -> void:
	if tabs != null:
		tabs.current_tab = 0


func prepare_for_close() -> void:
	if arena_studio != null and arena_studio.has_method("cancel_active_gesture"):
		arena_studio.cancel_active_gesture()
	if arena_studio != null and arena_studio.has_method("_flush_recovery"):
		arena_studio._flush_recovery()


func cancel_active_gesture() -> bool:
	return arena_studio != null and arena_studio.cancel_active_gesture()


func _active_history_provider():
	if tabs == null:
		return null
	return arena_studio if tabs.current_tab == 0 else encounter_studio


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
	var undo_name := provider.history_undo_name() if provider != null else ""
	var redo_name := provider.history_redo_name() if provider != null else ""
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
	if produce_button != null:
		produce_button.disabled = not arena_active
	if workspace_preset_option != null:
		workspace_preset_option.disabled = not arena_active
	if preview_view_option != null:
		preview_view_option.disabled = not arena_active
	if focus_map_button != null:
		focus_map_button.disabled = not arena_active


func _rebuild_history_menu() -> void:
	var popup := history_button.get_popup()
	popup.clear()
	var provider = _active_history_provider()
	if provider == null:
		popup.add_item("Aucun document", -1)
		popup.set_item_disabled(0, true)
		return
	popup.add_item(provider.history_document_name(), -1)
	popup.set_item_disabled(0, true)
	popup.add_separator()
	var current_index: int = provider.history_current_index()
	popup.add_item("● Position actuelle — etape %d" % current_index, -2)
	popup.set_item_disabled(popup.item_count - 1, true)
	popup.add_separator()
	var opening_saved := provider.has_method("history_opening_is_saved") \
		and provider.history_opening_is_saved()
	if not opening_saved:
		opening_saved = current_index == 0 \
			and provider.has_method("history_is_at_saved_state") \
			and provider.history_is_at_saved_state()
	popup.add_item(
		("● " if current_index == 0 else "  ") + "Ouverture du document" \
		+ ("  ✓ sauvegardee" if opening_saved else ""), 0
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


func _on_history_entry_pressed(index: int) -> void:
	if index < 0:
		return
	var provider = _active_history_provider()
	if provider != null:
		provider.history_jump_to(index)
	_refresh_history_controls()


func _on_tab_changed(_index: int) -> void:
	if arena_studio != null and arena_studio.has_method("cancel_active_gesture"):
		arena_studio.cancel_active_gesture()
	_refresh_history_controls()


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
		detach_button.text = "Reintegrer" if detached else "Detacher"
		detach_button.tooltip_text = (
			"Reintegrer dans Godot (Ctrl+Shift+D)" if detached
			else "Ouvrir dans une fenetre (Ctrl+Shift+D)"
		)
	_apply_toolbar_responsive()


func set_detach_shortcut_string(value: String) -> void:
	detach_shortcut_text = value.strip_edges() if not value.strip_edges().is_empty() \
		else "Ctrl+Shift+D"
	if detach_button != null:
		detach_button.tooltip_text = "%s (%s)" % [
			"Réintégrer dans Godot" if detached else "Ouvrir dans une fenêtre",
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
	studio_title_label.text = "DD STUDIO 1.2.1" if compact else "DUNGEON DRAFT STUDIO 1.2.1"
	studio_title_label.custom_minimum_size.x = 104 if compact else 224
	document_label.visible = not compact
	undo_button.text = "↶" if compact else "Annuler"
	redo_button.text = "↷" if compact else "Rétablir"
	undo_button.custom_minimum_size.x = 34 if compact else 0
	redo_button.custom_minimum_size.x = 34 if compact else 0
	history_button.text = "Hist. ▾" if compact else "Historique ▾"
	skill_studio_button.text = "Comp." if compact else "Compétences"
	workspace_preset_option.custom_minimum_size.x = 104 if compact else 0
	preview_view_option.custom_minimum_size.x = 72 if compact else 0
	detach_button.text = (
		("Réint." if compact else "Réintégrer") if detached \
		else ("Dét." if compact else "Détacher")
	)


func _global_save() -> void:
	if tabs.current_tab == 0:
		arena_studio.save_arena()
	elif encounter_studio.has_method("_show_save_dialog"):
		encounter_studio._show_save_dialog()


func _global_validate() -> void:
	if tabs.current_tab == 0:
		arena_studio.validate_arena()
	else:
		encounter_studio.validate_session()


func _global_test() -> void:
	if tabs.current_tab == 0:
		arena_studio.test_arena()
	else:
		encounter_studio.test_current_encounter()


func _global_produce() -> void:
	if tabs.current_tab == 0 and arena_studio.has_method("show_production_wizard"):
		arena_studio.show_production_wizard()


func _global_lab_transfer() -> void:
	if arena_studio == null:
		return
	arena_studio.import_latest_lab_transfer()
	arena_studio.show_dynamic_construction()


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
		focus_map_button.text = "Restaurer" if focused else "Focus"


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
