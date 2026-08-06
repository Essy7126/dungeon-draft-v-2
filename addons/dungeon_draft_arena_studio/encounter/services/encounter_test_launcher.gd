@tool
class_name EncounterTestLauncher
extends RefCounted

const ROOT := "user://dungeon_draft_studio/encounter_studio/tests"
const REQUEST_PATH := ROOT + "/active_request.json"
const LAST_RESULT_PATH := ROOT + "/last_result.json"
const BOOTSTRAP_SCENE := "res://addons/dungeon_draft_arena_studio/encounter/runtime/EncounterStudioTestBootstrap.tscn"
const DEFAULT_HEROES := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]


static func prepare_and_launch(
		session: EncounterEditSession,
		editor_interface,
		run_seed: int,
		automatic_deployment := false,
		debug_overlays := true
	) -> Dictionary:
	if session == null or session.current_room() == null \
			or session.current_encounter() == null:
		return {"ok": false, "error": "selection_missing"}
	var validation := EncounterValidationService.validate_session(session, run_seed)
	if EncounterValidationService.has_errors(validation):
		return {"ok": false, "error": "validation_failed"}
	# Aucun tirage global : un test Studio ne doit jamais avancer le RNG du jeu.
	var context_id := "%d_%d" % [
		Time.get_unix_time_from_system(), Time.get_ticks_usec()
	]
	var context_dir := ROOT.path_join(context_id)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(context_dir)) != OK:
		return {"ok": false, "error": "context_directory_failed"}
	var encounter := EncounterCopyService.copy_encounter(session.current_encounter())
	var encounter_path := context_dir.path_join("encounter.tres")
	if ResourceSaver.save(encounter, encounter_path) != OK:
		return {"ok": false, "error": "encounter_save_failed"}
	var source_wave := session.current_wave()
	var wave := EncounterCopyService.copy_wave(source_wave) if source_wave != null \
		else RoomWaveData.new()
	wave.wave_name = source_wave.wave_name if source_wave != null else "Test direct"
	wave.encounter_definition = ResourceLoader.load(
		encounter_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as EncounterDefinition
	var room := EncounterCopyService.copy_room(session.current_room())
	room.encounter_definition = wave.encounter_definition
	room.waves = [wave]
	room.minimum_wave_count = 1
	room.maximum_wave_count = 1
	var room_path := context_dir.path_join("room.tres")
	if ResourceSaver.save(room, room_path) != OK:
		return {"ok": false, "error": "room_save_failed"}
	var run := RunData.new()
	run.run_name = "Test Encounter Studio — %s" % room.room_name
	run.default_seed = run_seed
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 1
	run.rooms = [ResourceLoader.load(
		room_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as RoomData]
	var run_path := context_dir.path_join("run.tres")
	if ResourceSaver.save(run, run_path) != OK:
		return {"ok": false, "error": "run_save_failed"}
	var result_path := context_dir.path_join("result.json")
	var request := {
		"context_id": context_id,
		"run_path": run_path,
		"result_path": result_path,
		"heroes": DEFAULT_HEROES,
		"run_seed": run_seed,
		"automatic_deployment": automatic_deployment,
		"debug_overlays": debug_overlays,
		"created_at": Time.get_datetime_string_from_system(),
	}
	if not _write_json(REQUEST_PATH, request):
		return {"ok": false, "error": "request_write_failed"}
	if editor_interface == null or not editor_interface.has_method("play_custom_scene"):
		return {"ok": false, "error": "editor_play_api_missing", "request": request}
	editor_interface.play_custom_scene(BOOTSTRAP_SCENE)
	return {"ok": true, "request": request, "context_directory": context_dir}


static func load_last_result() -> Dictionary:
	if FileAccess.file_exists(LAST_RESULT_PATH):
		var stable_result = JSON.parse_string(
			FileAccess.get_file_as_string(LAST_RESULT_PATH)
		)
		if stable_result is Dictionary:
			return stable_result
	if not FileAccess.file_exists(REQUEST_PATH):
		return {}
	var request = JSON.parse_string(FileAccess.get_file_as_string(REQUEST_PATH))
	if not request is Dictionary:
		return {}
	var result_path := str(request.get("result_path", ""))
	if result_path.is_empty() or not FileAccess.file_exists(result_path):
		return {}
	var result = JSON.parse_string(FileAccess.get_file_as_string(result_path))
	return result if result is Dictionary else {}


static func finalize_context(request: Dictionary, payload: Dictionary) -> bool:
	var stored := _write_json(LAST_RESULT_PATH, payload)
	cleanup_context(request)
	return stored


static func cleanup_context(request: Dictionary) -> bool:
	var run_path := str(request.get("run_path", ""))
	var context_dir := run_path.get_base_dir()
	if context_dir.is_empty() or context_dir == ROOT \
			or not context_dir.begins_with(ROOT + "/"):
		return false
	var absolute_root := ProjectSettings.globalize_path(ROOT).simplify_path()
	var absolute_context := ProjectSettings.globalize_path(context_dir).simplify_path()
	if not absolute_context.begins_with(absolute_root + "/"):
		return false
	_remove_owned_tree(context_dir, absolute_root)
	return not DirAccess.dir_exists_absolute(absolute_context)


static func _remove_owned_tree(path: String, absolute_root: String) -> void:
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	if absolute == absolute_root or not absolute.begins_with(absolute_root + "/"):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child_directory in directory.get_directories():
		_remove_owned_tree(path.path_join(child_directory), absolute_root)
	for file_name in directory.get_files():
		var file_absolute := ProjectSettings.globalize_path(
			path.path_join(file_name)
		).simplify_path()
		if file_absolute.begins_with(absolute_root + "/"):
			DirAccess.remove_absolute(file_absolute)
	DirAccess.remove_absolute(absolute)


static func _write_json(path: String, value: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	) != OK:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  "))
	return true
