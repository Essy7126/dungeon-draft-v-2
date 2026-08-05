@tool
extends EditorPlugin

# Compatibilite : Arena Studio reste le module historique de ce plugin unique.

const TOOL_MENU_DETACH := "Dungeon Draft Studio : detacher / reintegrer"
const DETACH_SHORTCUT_SETTING := "dungeon_draft_studio/shortcuts/detach_workspace"

var _main_screen: EmbeddedStudioHost = null
var _workspace: StudioWorkspace = null
var _window_host: NativeStudioWindowHost = null
var _ui_state := {}


func _enter_tree() -> void:
	var editor_settings := get_editor_interface().get_editor_settings()
	if not editor_settings.has_setting(DETACH_SHORTCUT_SETTING):
		editor_settings.set_setting(DETACH_SHORTCUT_SETTING, "Ctrl+Shift+D")
		editor_settings.set_initial_value(
			DETACH_SHORTCUT_SETTING, "Ctrl+Shift+D", false
		)
	editor_settings.add_property_info({
		"name": DETACH_SHORTCUT_SETTING,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
		"hint_string": "Ctrl+Shift+D",
	})
	_ui_state = StudioUiStateService.load_state()
	_main_screen = EmbeddedStudioHost.new()
	_main_screen.name = "EmbeddedStudioHost"
	get_editor_interface().get_editor_main_screen().add_child(_main_screen)
	_workspace = StudioWorkspace.new()
	_workspace.name = "StudioWorkspace"
	_workspace.setup(get_editor_interface(), get_undo_redo())
	_workspace.set_detach_shortcut_string(str(
		editor_settings.get_setting(DETACH_SHORTCUT_SETTING)
	))
	_workspace.detach_requested.connect(_toggle_detached)
	_workspace.reintegrate_requested.connect(_reintegrate_workspace)
	_main_screen.reintegrate_requested.connect(_reintegrate_workspace)
	_main_screen.focus_window_requested.connect(_focus_window)
	_main_screen.attach_workspace(_workspace)
	_window_host = NativeStudioWindowHost.new()
	_window_host.name = "NativeStudioWindowHost"
	_window_host.reintegrate_requested.connect(_reintegrate_workspace)
	get_editor_interface().get_base_control().add_child(_window_host)
	add_tool_menu_item(TOOL_MENU_DETACH, _toggle_detached)
	_main_screen.hide()
	if bool(_ui_state.get("detached", false)):
		call_deferred("_detach_workspace")


func _exit_tree() -> void:
	_save_ui_state()
	if is_instance_valid(_workspace):
		_workspace.prepare_for_close()
	_reintegrate_workspace()
	remove_tool_menu_item(TOOL_MENU_DETACH)
	if is_instance_valid(_window_host):
		var parent := _window_host.get_parent()
		if parent != null:
			parent.remove_child(_window_host)
		_window_host.free()
	_window_host = null
	if is_instance_valid(_main_screen):
		var parent := _main_screen.get_parent()
		if parent != null:
			parent.remove_child(_main_screen)
		_main_screen.free()
	_main_screen = null
	_workspace = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_main_screen):
		if not visible and _workspace != null and _workspace.arena_studio != null:
			_workspace.arena_studio.cancel_active_gesture()
		_main_screen.visible = visible
		if visible and _workspace != null:
			_workspace.ensure_initial_content_loaded()


func _get_plugin_name() -> String:
	return "Dungeon Draft Studio"


func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_editor_theme().get_icon("TileMap", "EditorIcons")


func _get_state() -> Dictionary:
	return _workspace.get_state_snapshot() if is_instance_valid(_workspace) else {}


func _set_state(state: Dictionary) -> void:
	if is_instance_valid(_workspace):
		_workspace.apply_state_snapshot(state)


func _apply_changes() -> void:
	# Les ressources du Studio restent isolees jusqu'a la confirmation explicite
	# de sa boite de sauvegarde. Le cycle de l'editeur ne les ecrit jamais seul.
	pass


func _save_external_data() -> void:
	# Meme contrat que _apply_changes : aucune ecriture implicite.
	pass


func _toggle_detached() -> void:
	if _workspace == null:
		return
	if _workspace.get_parent() == _window_host:
		_reintegrate_workspace()
	else:
		_detach_workspace()


func _detach_workspace() -> void:
	if not is_instance_valid(_workspace) or not is_instance_valid(_window_host):
		return
	if _workspace.get_parent() == _window_host:
		_focus_window()
		return
	_workspace.cancel_active_gesture()
	_main_screen.show_detached_placeholder()
	_window_host.apply_window_state(_ui_state.get("window", {}))
	_window_host.attach_workspace(_workspace)
	_workspace.set_detached_state(true)
	_window_host.show()
	_window_host.grab_focus()
	_save_ui_state()


func _reintegrate_workspace() -> void:
	if not is_instance_valid(_workspace) or not is_instance_valid(_main_screen):
		return
	_workspace.cancel_active_gesture()
	if is_instance_valid(_window_host) and _workspace.get_parent() == _window_host:
		_ui_state["window"] = _window_host.capture_window_state()
		_window_host.detach_workspace()
		_window_host.hide()
	_main_screen.attach_workspace(_workspace)
	_workspace.set_detached_state(false)
	_save_ui_state()


func _focus_window() -> void:
	if is_instance_valid(_window_host) and _workspace != null \
			and _workspace.get_parent() == _window_host:
		_window_host.bring_to_front()


func _save_ui_state() -> void:
	if not is_instance_valid(_workspace):
		return
	_ui_state["detached"] = is_instance_valid(_window_host) \
		and _workspace.get_parent() == _window_host
	_ui_state["workspace"] = _workspace.get_state_snapshot()
	if is_instance_valid(_window_host) and bool(_ui_state["detached"]):
		_ui_state["window"] = _window_host.capture_window_state()
	StudioUiStateService.save_state(_ui_state)
