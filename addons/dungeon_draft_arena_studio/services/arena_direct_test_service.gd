@tool
class_name ArenaDirectTestService
extends RefCounted

const REQUEST_PATH := "user://arena_studio/test_request.json"
const WORK_ROOT := "user://dungeon_draft_studio/arena_studio/tests"
const LAST_RESULT_PATH := WORK_ROOT + "/last_result.json"
const CONTRACT_VERSION := 2
const QUICK_FIXTURE_HEROES := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]


static func prepare(
		arena: ArenaDefinition,
		active_run: RunData,
		configuration: StringName
	) -> Dictionary:
	if arena == null:
		return {"ok": false, "error": "arena_missing"}
	var context_id := "%s_%d" % [arena.arena_id, Time.get_ticks_usec()]
	var context_root := WORK_ROOT.path_join(context_id)
	var context_absolute := ProjectSettings.globalize_path(context_root).simplify_path()
	var root_absolute := ProjectSettings.globalize_path(WORK_ROOT).simplify_path()
	if not context_absolute.begins_with(root_absolute + "/"):
		return {"ok": false, "error": "unsafe_context_path"}
	if DirAccess.make_dir_recursive_absolute(context_absolute) != OK:
		return {"ok": false, "error": "context_directory_failed"}

	var test_arena := ArenaDefinition.new()
	if not RoomDataSnapshotService.restore(
			test_arena, RoomDataSnapshotService.capture(arena)
		):
		return _failed(context_root, "working_copy_restore_failed")
	if not ArenaRuntimeBridge.sync_runtime_resources(test_arena):
		return _failed(context_root, "runtime_projection_sync_failed")
	var arena_path := context_root.path_join("arena.tres")
	if ResourceSaver.save(test_arena, arena_path) != OK:
		return _failed(context_root, "working_copy_save_failed")
	var temporary := ResourceLoader.load(
		arena_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ArenaDefinition
	if temporary == null:
		return _failed(context_root, "temporary_copy_load_failed")

	var working_fingerprint := ArenaSnapshotService.arena_fingerprint(arena)
	var temporary_fingerprint := ArenaSnapshotService.arena_fingerprint(temporary)
	var runtime_state := ArenaRuntimeProjectionService.build(temporary)
	var runtime_fingerprint := (
		ArenaSnapshotService.arena_fingerprint(runtime_state.arena_projection)
		if runtime_state != null and runtime_state.arena_projection != null else ""
	)
	if working_fingerprint != temporary_fingerprint \
			or working_fingerprint != runtime_fingerprint:
		return _failed(context_root, "fingerprint_mismatch", {
			"working_fingerprint": working_fingerprint,
			"temporary_fingerprint": temporary_fingerprint,
			"runtime_fingerprint": runtime_fingerprint,
		})

	var run_path := ""
	var exact_run_content := false
	if active_run != null:
		var transient_run := _transient_run(active_run, temporary)
		run_path = context_root.path_join("run.tres")
		if ResourceSaver.save(transient_run, run_path) != OK:
			return _failed(context_root, "run_context_save_failed")
		var resolution := RunHeroResolver.resolve_runtime_hero_data(
			transient_run, false
		)
		exact_run_content = resolution.is_valid()

	var request := {
		"contract_version": CONTRACT_VERSION,
		"studio_product_version": StudioVersion.PRODUCT_VERSION,
		"generated_by": StudioVersion.GENERATED_BY,
		"arena_path": arena_path,
		"run_path": run_path,
		"configuration": str(configuration),
		"context_root": context_root,
		"cleanup_on_load": true,
		"probe_runtime": true,
		"result_path": LAST_RESULT_PATH,
		"working_fingerprint": working_fingerprint,
		"temporary_fingerprint": temporary_fingerprint,
		"runtime_fingerprint": runtime_fingerprint,
		"fingerprints_identical": true,
		"camera_mode": "STUDIO_MATCH",
		"exact_run_content": exact_run_content,
		"fixture_fallback": not exact_run_content,
		"heroes": [] if exact_run_content else QUICK_FIXTURE_HEROES,
		"created_at": Time.get_datetime_string_from_system(true),
	}
	if not _write_json(REQUEST_PATH, request):
		return _failed(context_root, "request_write_failed")
	return {
		"ok": true,
		"request": request,
		"context_root": context_root,
		"arena_path": arena_path,
		"run_path": run_path,
		"working_fingerprint": working_fingerprint,
		"temporary_fingerprint": temporary_fingerprint,
		"runtime_fingerprint": runtime_fingerprint,
		"fingerprints_identical": true,
		"produced_bundle_loaded": false,
	}


static func load_last_result() -> Dictionary:
	if not FileAccess.file_exists(LAST_RESULT_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAST_RESULT_PATH))
	return parsed if parsed is Dictionary else {}


static func cleanup_context(request: Dictionary) -> bool:
	var context_root := str(request.get("context_root", ""))
	if context_root.is_empty() or context_root == WORK_ROOT \
			or not context_root.begins_with(WORK_ROOT + "/"):
		return false
	var absolute_root := ProjectSettings.globalize_path(WORK_ROOT).simplify_path()
	var absolute_context := ProjectSettings.globalize_path(context_root).simplify_path()
	if not absolute_context.begins_with(absolute_root + "/"):
		return false
	_remove_owned_tree(context_root, absolute_root)
	var request_absolute := ProjectSettings.globalize_path(REQUEST_PATH)
	if FileAccess.file_exists(request_absolute):
		DirAccess.remove_absolute(request_absolute)
	return not DirAccess.dir_exists_absolute(absolute_context)


static func _transient_run(source: RunData, room: ArenaDefinition) -> RunData:
	var run := RunData.new()
	run.run_name = "Test Arena Studio — %s" % source.run_name
	run.default_seed = source.default_seed
	run.target_duration_minutes = source.target_duration_minutes
	run.extended_duration_minutes = source.extended_duration_minutes
	run.room_flow_mode = source.room_flow_mode
	run.maximum_waves_per_room = source.maximum_waves_per_room
	run.content_profile = source.content_profile
	run.rooms = [room]
	return run


static func _failed(
		context_root: String,
		error: String,
		details: Dictionary = {}
	) -> Dictionary:
	cleanup_context({"context_root": context_root})
	var result := {"ok": false, "error": error}
	result.merge(details, true)
	return result


static func _write_json(path: String, value: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  "))
	file.close()
	return true


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
