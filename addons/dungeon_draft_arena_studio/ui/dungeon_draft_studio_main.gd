@tool
class_name DungeonDraftStudioMain
extends Control

var editor_interface = null
var editor_undo_redo = null
var tabs: TabContainer
var arena_studio: ArenaStudioMain
var encounter_studio: EncounterStudioMain
var undo_button: Button
var redo_button: Button
var history_button: MenuButton
var _pending_state := {}


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


func _build_shared_history_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 38
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 5)
	panel.add_child(bar)
	var label := Label.new()
	label.text = "DUNGEON DRAFT STUDIO 1.1"
	label.custom_minimum_size.x = 230
	label.add_theme_color_override("font_color", Color(0.48, 0.86, 1.0))
	label.add_theme_font_size_override("font_size", 16)
	bar.add_child(label)
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
	var hint := Label.new()
	hint.text = "Ctrl+Z • Ctrl+Shift+Z • Ctrl+Y"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", Color(0.62, 0.68, 0.76))
	bar.add_child(hint)
	return panel


func ensure_initial_content_loaded() -> void:
	if arena_studio != null:
		arena_studio.ensure_initial_arena_loaded()


func get_state_snapshot() -> Dictionary:
	return {
		"tab": tabs.current_tab if tabs != null else 0,
		"encounter": encounter_studio.get_state_snapshot() \
			if encounter_studio != null else {},
	}


func apply_state_snapshot(state: Dictionary) -> void:
	if not is_node_ready() or tabs == null or encounter_studio == null:
		_pending_state = state.duplicate(true)
		return
	tabs.current_tab = clampi(int(state.get("tab", 0)), 0, tabs.get_tab_count() - 1)
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
	popup.add_item(
		("● " if current_index == 0 else "  ") + "Ouverture du document", 0
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
	if not key.pressed or key.echo or not key.ctrl_pressed:
		return
	if _text_control_has_focus():
		return
	var provider = _active_history_provider()
	if provider == null:
		return
	if provider.has_method("cancel_active_gesture") \
			and provider.cancel_active_gesture():
		get_viewport().set_input_as_handled()
		return
	var handled := false
	if key.keycode == KEY_Z and key.shift_pressed:
		handled = provider.history_redo()
	elif key.keycode == KEY_Z:
		handled = provider.history_undo()
	elif key.keycode == KEY_Y:
		handled = provider.history_redo()
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
		redo_button.text = "Retablir"
