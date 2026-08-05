@tool
extends EditorPlugin

# Compatibilite : Arena Studio reste le module historique de ce plugin unique.

var _main_screen: DungeonDraftStudioMain = null


func _enter_tree() -> void:
	_main_screen = DungeonDraftStudioMain.new()
	_main_screen.name = "DungeonDraftStudioMain"
	_main_screen.setup(get_editor_interface(), get_undo_redo())
	get_editor_interface().get_editor_main_screen().add_child(_main_screen)
	_main_screen.hide()


func _exit_tree() -> void:
	if is_instance_valid(_main_screen):
		_main_screen.prepare_for_close()
		var parent := _main_screen.get_parent()
		if parent != null:
			parent.remove_child(_main_screen)
		_main_screen.free()
	_main_screen = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_main_screen):
		_main_screen.visible = visible
		if visible:
			_main_screen.ensure_initial_content_loaded()


func _get_plugin_name() -> String:
	return "Dungeon Draft Studio"


func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_editor_theme().get_icon("TileMap", "EditorIcons")


func _get_state() -> Dictionary:
	return _main_screen.get_state_snapshot() if is_instance_valid(_main_screen) else {}


func _set_state(state: Dictionary) -> void:
	if is_instance_valid(_main_screen):
		_main_screen.apply_state_snapshot(state)


func _apply_changes() -> void:
	# Les ressources du Studio restent isolees jusqu'a la confirmation explicite
	# de sa boite de sauvegarde. Le cycle de l'editeur ne les ecrit jamais seul.
	pass


func _save_external_data() -> void:
	# Meme contrat que _apply_changes : aucune ecriture implicite.
	pass
