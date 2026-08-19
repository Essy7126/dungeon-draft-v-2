@tool
class_name ArenaDirectTestService
extends RefCounted

const REQUEST_PATH := "user://arena_studio/test_request.json"
const WORK_ROOT := "user://dungeon_draft_studio/arena_studio/tests"
const LAST_RESULT_PATH := WORK_ROOT + "/last_result.json"
const CONTRACT_VERSION := 4
const QUICK_FIXTURE_HEROES := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]


static func prepare(
		arena: ArenaDefinition,
		active_run: RunData,
		configuration: StringName,
		options: Dictionary = {}
	) -> Dictionary:
	if arena == null:
		return {"ok": false, "error": "arena_missing"}
	_consume_previous_request()
	var generation_id := "%d_%d" % [
		int(Time.get_unix_time_from_system() * 1000000.0), Time.get_ticks_usec(),
	]
	var context_id := "%s_%s" % [arena.arena_id, generation_id]
	var context_root := WORK_ROOT.path_join(context_id)
	var context_absolute := ProjectSettings.globalize_path(context_root).simplify_path()
	var root_absolute := ProjectSettings.globalize_path(WORK_ROOT).simplify_path()
	if not context_absolute.begins_with(root_absolute + "/"):
		return {"ok": false, "error": "unsafe_context_path"}
	if DirAccess.make_dir_recursive_absolute(context_absolute) != OK:
		return {"ok": false, "error": "context_directory_failed"}

	var test_arena := ArenaDefinition.new()
	var working_topology := ArenaTopologySignatureService.build(arena)
	if not RoomDataSnapshotService.restore(
			test_arena, RoomDataSnapshotService.capture(arena)
		):
		return _failed(context_root, "working_copy_restore_failed")
	var restored_topology := ArenaTopologySignatureService.build(test_arena)
	if working_topology.topology_hash != restored_topology.topology_hash:
		return _failed(context_root, "snapshot_topology_mismatch", {
			"working_topology_hash": working_topology.topology_hash,
			"restored_topology_hash": restored_topology.topology_hash,
		})
	if not ArenaRuntimeBridge.sync_runtime_resources(test_arena):
		return _failed(context_root, "runtime_projection_sync_failed")
	var arena_path := context_root.path_join("arena.tres")
	if ResourceSaver.save(test_arena, arena_path) != OK:
		return _failed(context_root, "working_copy_save_failed")
	var temporary := ResourceLoader.load(
		arena_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	if temporary == null:
		return _failed(context_root, "temporary_copy_load_failed")

	var working_fingerprint := ArenaSnapshotService.arena_fingerprint(arena)
	var temporary_fingerprint := ArenaSnapshotService.arena_fingerprint(temporary)
	var runtime_state := ArenaRuntimeProjectionService.build(temporary)
	var temporary_topology := ArenaTopologySignatureService.build(temporary)
	var runtime_topology := ArenaTopologySignatureService.build(
		runtime_state.arena_projection if runtime_state != null else null
	)
	var runtime_fingerprint := (
		ArenaSnapshotService.arena_fingerprint(runtime_state.arena_projection)
		if runtime_state != null and runtime_state.arena_projection != null else ""
	)
	if working_fingerprint != temporary_fingerprint \
			or working_fingerprint != runtime_fingerprint \
			or working_topology.topology_hash != temporary_topology.topology_hash \
			or working_topology.topology_hash != runtime_topology.topology_hash:
		return _failed(context_root, "fingerprint_mismatch", {
			"working_fingerprint": working_fingerprint,
			"temporary_fingerprint": temporary_fingerprint,
			"runtime_fingerprint": runtime_fingerprint,
			"working_topology_hash": working_topology.topology_hash,
			"temporary_topology_hash": temporary_topology.topology_hash,
			"runtime_topology_hash": runtime_topology.topology_hash,
		})
	var render_plan := ArenaTerrainRenderPlanService.build(temporary)
	if not bool(render_plan.get("ok", false)):
		return _failed(context_root, "render_plan_invalid", {
			"errors": render_plan.get("errors", []),
		})
	var expected_battle_scene_path := (
		temporary.battle_scene.resource_path
		if temporary.battle_scene != null else ""
	)
	if expected_battle_scene_path.is_empty() \
			or not ResourceLoader.exists(expected_battle_scene_path):
		return _failed(context_root, "battle_scene_missing", {
			"battle_scene_path": expected_battle_scene_path,
		})
	var runtime_probe_key := probe_key(
		working_fingerprint,
		working_topology.topology_hash,
		expected_battle_scene_path,
		configuration
	)

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
		"context_id": context_id,
		"generation_id": generation_id,
		"transaction_id": generation_id,
		"cleanup_on_load": true,
		"probe_runtime": true,
		"probe_only": bool(options.get("probe_only", false)),
		"quit_after_probe": bool(options.get("quit_after_probe", false)),
		"result_path": LAST_RESULT_PATH,
		"working_fingerprint": working_fingerprint,
		"temporary_fingerprint": temporary_fingerprint,
		"runtime_fingerprint": runtime_fingerprint,
		"fingerprints_identical": true,
		"working_topology_hash": working_topology.topology_hash,
		"temporary_topology_hash": temporary_topology.topology_hash,
		"runtime_topology_hash": runtime_topology.topology_hash,
		"topology_hashes_identical": true,
		"visible_floor_hash": working_topology.visible_floor_hash,
		"expected_floor_hash": str(render_plan.expected_floor_hash),
		"expected_floor_cells": render_plan.expected_floor_cells.duplicate(),
		"removed_cells": working_topology.removed_cells.duplicate(),
		"expected_battle_scene_path": expected_battle_scene_path,
		"runtime_probe_key": runtime_probe_key,
		"camera_mode": "STUDIO_MATCH",
		"exact_run_content": exact_run_content,
		"fixture_fallback": not exact_run_content,
		"heroes": [] if exact_run_content else QUICK_FIXTURE_HEROES,
		"created_at": Time.get_datetime_string_from_system(true),
		"created_at_unix_usec": int(Time.get_unix_time_from_system() * 1000000.0),
	}
	if not _write_json(REQUEST_PATH, request):
		return _failed(context_root, "request_write_failed")
	if not _write_json(LAST_RESULT_PATH, {
		"ok": false,
		"probe_pending": true,
		"runtime_scene_inspected": false,
		"working_fingerprint": working_fingerprint,
		"working_topology_hash": working_topology.topology_hash,
		"expected_battle_scene_path": expected_battle_scene_path,
		"runtime_probe_key": runtime_probe_key,
		"generation_id": generation_id,
		"generated_at": request.created_at,
	}):
		return _failed(context_root, "pending_result_write_failed")
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
		"working_topology_hash": working_topology.topology_hash,
		"temporary_topology_hash": temporary_topology.topology_hash,
		"runtime_topology_hash": runtime_topology.topology_hash,
		"topology_hashes_identical": true,
		"visible_floor_hash": working_topology.visible_floor_hash,
		"expected_floor_hash": str(render_plan.expected_floor_hash),
		"expected_floor_cells": render_plan.expected_floor_cells.duplicate(),
		"removed_cells": working_topology.removed_cells.duplicate(),
		"expected_battle_scene_path": expected_battle_scene_path,
		"runtime_probe_key": runtime_probe_key,
		"generation_id": generation_id,
		"produced_bundle_loaded": false,
	}


static func load_last_result() -> Dictionary:
	if not FileAccess.file_exists(LAST_RESULT_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAST_RESULT_PATH))
	return parsed if parsed is Dictionary else {}


static func matching_runtime_result(
		arena: ArenaDefinition,
		configuration: StringName = &""
	) -> Dictionary:
	if arena == null:
		return {}
	var result := load_last_result()
	if not bool(result.get("ok", false)) \
			or not bool(result.get("runtime_scene_inspected", false)) \
			or bool(result.get("probe_pending", false)) \
			or bool(result.get("produced_bundle_loaded", true)):
		return {}
	var battle_scene_path := (
		arena.battle_scene.resource_path if arena.battle_scene != null else ""
	)
	var fingerprint := ArenaSnapshotService.arena_fingerprint(arena)
	var topology: Dictionary = ArenaTopologySignatureService.build(arena)
	var topology_hash: String = str(topology.get("topology_hash", ""))
	var result_configuration := StringName(result.get("configuration", &""))
	var expected_key := probe_key(
		fingerprint,
		topology_hash,
		battle_scene_path,
		result_configuration if configuration == &"" else configuration
	)
	if str(result.get("working_fingerprint", "")) != fingerprint \
			or str(result.get("runtime_fingerprint", "")) != fingerprint \
			or str(result.get("runtime_topology_hash", "")) != topology_hash \
			or str(result.get("battle_scene_path", result.get("scene_path", ""))) \
				!= battle_scene_path \
			or str(result.get("runtime_probe_key", "")) != expected_key:
		return {}
	if configuration != &"" and result_configuration != configuration:
		return {}
	return result


static func probe_key(
		arena_fingerprint: String,
		topology_hash: String,
		battle_scene_path: String,
		configuration: StringName
	) -> String:
	return JSON.stringify({
		"contract_version": CONTRACT_VERSION,
		"engine": Engine.get_version_info().get("hash", ""),
		"studio_product_version": StudioVersion.PRODUCT_VERSION,
		"arena_fingerprint": arena_fingerprint,
		"topology_hash": topology_hash,
		"battle_scene_path": battle_scene_path,
		"configuration": str(configuration),
	}, "", true).sha256_text()


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


static func _consume_previous_request() -> void:
	if not FileAccess.file_exists(REQUEST_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REQUEST_PATH))
	if parsed is Dictionary:
		var context_root := str((parsed as Dictionary).get("context_root", ""))
		if context_root.begins_with(WORK_ROOT + "/"):
			cleanup_context(parsed)
	var request_absolute := ProjectSettings.globalize_path(REQUEST_PATH)
	if FileAccess.file_exists(request_absolute):
		DirAccess.remove_absolute(request_absolute)


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
