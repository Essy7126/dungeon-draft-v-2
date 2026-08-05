@tool
class_name StudioUiStateService
extends RefCounted

const STATE_PATH := "user://dungeon_draft_studio/ui_state/workspace.json"
const SCHEMA_VERSION := 1


static func load_state() -> Dictionary:
	if not FileAccess.file_exists(STATE_PATH):
		return default_state()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		return default_state()
	return parsed


static func save_state(state: Dictionary) -> bool:
	var payload := state.duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION
	var absolute := ProjectSettings.globalize_path(STATE_PATH)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	return DirAccess.rename_absolute(temporary, absolute) == OK


static func default_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"detached": false,
		"window": {
			"screen": 0,
			"position": [80, 80],
			"size": [1600, 950],
			"maximized": false,
		},
		"workspace": {},
	}
