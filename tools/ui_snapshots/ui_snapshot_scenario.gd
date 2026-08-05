class_name UISnapshotScenario
extends RefCounted

var screen_id: StringName
var state_id: StringName
var scene_path: String
var fixture_id: StringName
var capture_driver: StringName
var production_status: StringName
var blocker: String
var notes: String


func _init(
		p_screen_id: StringName,
		p_state_id: StringName,
		p_scene_path: String,
		p_fixture_id: StringName,
		p_capture_driver: StringName,
		p_production_status: StringName = &"production",
		p_blocker := "",
		p_notes := ""
	) -> void:
	screen_id = p_screen_id
	state_id = p_state_id
	scene_path = p_scene_path
	fixture_id = p_fixture_id
	capture_driver = p_capture_driver
	production_status = p_production_status
	blocker = p_blocker
	notes = p_notes


func snapshot_id() -> String:
	return "%s__%s" % [screen_id, state_id]


func is_automated() -> bool:
	return blocker.is_empty() and capture_driver != &"documented"


func to_dictionary() -> Dictionary:
	return {
		"screen_id": String(screen_id),
		"state_id": String(state_id),
		"scene_path": scene_path,
		"fixture_id": String(fixture_id),
		"capture_driver": String(capture_driver),
		"production_status": String(production_status),
		"automated": is_automated(),
		"blocker": blocker,
		"notes": notes,
	}
