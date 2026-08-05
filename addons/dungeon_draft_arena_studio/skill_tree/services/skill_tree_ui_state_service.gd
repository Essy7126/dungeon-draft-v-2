@tool
class_name SkillTreeUiStateService
extends RefCounted

const STATE_PATH := "user://dungeon_draft_studio/skill_tree/workspace.cfg"


static func load_state() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(STATE_PATH) != OK:
		return default_state()
	return {
		"guided": bool(config.get_value("workspace", "guided", true)),
		"production_profile": bool(config.get_value("workspace", "production_profile", false)),
		"character_path": str(config.get_value("workspace", "character_path", "")),
		"discipline_id": str(config.get_value("workspace", "discipline_id", "")),
		"window_screen": int(config.get_value("window", "screen", 0)),
		"window_position": config.get_value("window", "position", Vector2i(80, 80)),
		"window_size": config.get_value("window", "size", Vector2i(1660, 940)),
		"window_maximized": bool(config.get_value("window", "maximized", false)),
	}


static func save_state(state: Dictionary) -> bool:
	var config := ConfigFile.new()
	config.load(STATE_PATH)
	config.set_value("workspace", "guided", bool(state.get("guided", true)))
	config.set_value(
		"workspace", "production_profile",
		bool(state.get("production_profile", false))
	)
	config.set_value("workspace", "character_path", str(state.get("character_path", "")))
	config.set_value("workspace", "discipline_id", str(state.get("discipline_id", "")))
	config.set_value("window", "screen", int(state.get("window_screen", 0)))
	config.set_value(
		"window", "position", state.get("window_position", Vector2i(80, 80))
	)
	config.set_value(
		"window", "size", state.get("window_size", Vector2i(1660, 940))
	)
	config.set_value(
		"window", "maximized", bool(state.get("window_maximized", false))
	)
	var absolute := ProjectSettings.globalize_path(STATE_PATH)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	return config.save(STATE_PATH) == OK


static func load_graph_state(discipline_id: StringName) -> Dictionary:
	if discipline_id == &"":
		return {}
	var config := ConfigFile.new()
	if config.load(STATE_PATH) != OK:
		return {}
	var section := "graph_%s" % discipline_id
	return {
		"scroll_offset": config.get_value(section, "scroll_offset", Vector2.ZERO),
		"zoom": float(config.get_value(section, "zoom", 1.0)),
		"positions": config.get_value(section, "positions", {}),
	}


static func save_graph_state(
		discipline_id: StringName,
		graph_state: Dictionary
	) -> bool:
	if discipline_id == &"":
		return false
	var config := ConfigFile.new()
	config.load(STATE_PATH)
	var section := "graph_%s" % discipline_id
	config.set_value(section, "scroll_offset", graph_state.get("scroll_offset", Vector2.ZERO))
	config.set_value(section, "zoom", float(graph_state.get("zoom", 1.0)))
	config.set_value(section, "positions", graph_state.get("positions", {}))
	var absolute := ProjectSettings.globalize_path(STATE_PATH)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	return config.save(STATE_PATH) == OK


static func default_state() -> Dictionary:
	return {
		"guided": true,
		"production_profile": false,
		"character_path": "",
		"discipline_id": "",
		"window_screen": 0,
		"window_position": Vector2i(80, 80),
		"window_size": Vector2i(1660, 940),
		"window_maximized": false,
	}
