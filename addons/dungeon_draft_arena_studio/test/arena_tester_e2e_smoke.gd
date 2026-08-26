extends Node

## End-to-end smoke for the real Arena Studio "Tester" path.
##
## This runner deliberately starts from the canonical authoring resource and
## never imports, loads, saves, or cleans the frozen produced bundle.

const SOURCE_PATH := "res://data/arenas/room_01_forest.tres"
const EXPECTED_BATTLE_SCENE_PATH := "res://data/rooms/maps/painted_battle.tscn"
const PRODUCED_PREFIX := "res://data/arenas/produced/"
const RESULT_PATH := (
	"user://dungeon_draft_studio/arena_studio/tests/"
	+ "arena_tester_e2e_smoke_result.json"
)
const TEST_RUNNER: PackedScene = preload(
	"res://addons/dungeon_draft_arena_studio/test/arena_studio_test_runner.tscn"
)
const CONFIGURATION := &"spawns"
const MAX_FRAMES := 720

var _prepared: Dictionary = {}
var _runner: Node = null
var _source_sha256 := ""
var _working_fingerprint := ""
var _working_topology_hash := ""
var _started_usec := 0


func _ready() -> void:
	# The observer must survive GameManager changing the current scene.
	get_tree().current_scene = null
	call_deferred("_run")


func _run() -> void:
	_started_usec = Time.get_ticks_usec()
	var errors: Array[String] = []
	var evidence: Dictionary = {
		"source_path": SOURCE_PATH,
		"expected_battle_scene_path": EXPECTED_BATTLE_SCENE_PATH,
		"configuration": str(CONFIGURATION),
		"produced_prefix": PRODUCED_PREFIX,
	}
	_check(
		errors,
		not SOURCE_PATH.begins_with(PRODUCED_PREFIX),
		"SOURCE_PATH_IS_PRODUCED"
	)
	_check(
		errors,
		ResourceLoader.exists(SOURCE_PATH),
		"CANONICAL_SOURCE_MISSING"
	)
	_check(
		errors,
		not _dependency_closure_contains_produced(SOURCE_PATH),
		"CANONICAL_SOURCE_DEPENDS_ON_PRODUCED"
	)
	_source_sha256 = FileAccess.get_sha256(SOURCE_PATH)
	evidence["source_sha256_before"] = _source_sha256
	_check(errors, not _source_sha256.is_empty(), "SOURCE_SHA256_UNAVAILABLE")

	var source := ResourceLoader.load(
		SOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	_check(errors, source != null, "CANONICAL_SOURCE_LOAD_FAILED")
	if source == null or not errors.is_empty():
		await _finish(errors, evidence, {})
		return

	var session := ArenaEditSession.new()
	var session_opened := session.open(
		source, SOURCE_PATH, false, "arena_tester_e2e_smoke"
	)
	_check(errors, session_opened, "EDIT_SESSION_OPEN_FAILED")
	var working_arena: ArenaDefinition = session.working_arena
	_check(errors, working_arena != null, "WORKING_ARENA_MISSING")
	if working_arena == null or not errors.is_empty():
		await _finish(errors, evidence, {})
		return

	# The historical canonical source predates three editor-only validation
	# annotations. Complete them on the transient working copy only: no cell,
	# obstacle, spawn coordinate, encounter, or canonical file is changed.
	var compatibility_actions := _annotate_legacy_working_copy(working_arena)
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)
	var working_validation := ArenaValidator.validate(working_arena, false)
	var blocking_codes := _blocking_validation_codes(working_validation)
	evidence["working_copy_compatibility_actions"] = compatibility_actions
	evidence["working_copy_blocking_validation_codes"] = blocking_codes
	_check(
		errors,
		working_validation.is_valid(),
		"WORKING_COPY_REMAINS_INVALID:%s" % ",".join(blocking_codes)
	)
	if not errors.is_empty():
		await _finish(errors, evidence, {})
		return

	_working_fingerprint = ArenaSnapshotService.arena_fingerprint(working_arena)
	var working_topology: Dictionary = ArenaTopologySignatureService.build(
		working_arena
	)
	_working_topology_hash = str(working_topology.get("topology_hash", ""))
	var working_battle_scene_path := (
		working_arena.battle_scene.resource_path
		if working_arena.battle_scene != null else ""
	)
	evidence.merge({
		"session_source_path": session.source_path,
		"working_resource_path": working_arena.resource_path,
		"working_fingerprint": _working_fingerprint,
		"working_topology_hash": _working_topology_hash,
		"working_battle_scene_path": working_battle_scene_path,
	}, true)
	_check(
		errors,
		session.source_path == SOURCE_PATH,
		"EDIT_SESSION_SOURCE_PATH_MISMATCH"
	)
	_check(
		errors,
		working_arena != source,
		"EDIT_SESSION_DID_NOT_CREATE_WORKING_COPY"
	)
	_check(
		errors,
		not _working_fingerprint.is_empty(),
		"WORKING_FINGERPRINT_EMPTY"
	)
	_check(
		errors,
		not _working_topology_hash.is_empty(),
		"WORKING_TOPOLOGY_HASH_EMPTY"
	)
	_check(
		errors,
		working_battle_scene_path == EXPECTED_BATTLE_SCENE_PATH,
		"WORKING_BATTLE_SCENE_PATH_MISMATCH"
	)
	if not errors.is_empty():
		await _finish(errors, evidence, {})
		return

	_prepared = ArenaDirectTestService.prepare(
		working_arena,
		null,
		CONFIGURATION,
		{"probe_only": true, "quit_after_probe": false}
	)
	evidence["prepare_ok"] = bool(_prepared.get("ok", false))
	if not bool(_prepared.get("ok", false)):
		errors.append("DIRECT_TEST_PREPARE_FAILED:%s" % str(
			_prepared.get("error", "unknown")
		))
		evidence["prepare_result"] = _prepared.duplicate(true)
		await _finish(errors, evidence, {})
		return

	var request_value: Variant = _prepared.get("request", {})
	var request: Dictionary = (
		(request_value as Dictionary).duplicate(true)
		if request_value is Dictionary else {}
	)
	var preparation_errors := _preparation_errors(request)
	errors.append_array(preparation_errors)
	evidence.merge(_preparation_evidence(request), true)
	if not errors.is_empty():
		await _finish(errors, evidence, {})
		return

	_runner = TEST_RUNNER.instantiate()
	add_child(_runner)
	var runtime_result: Dictionary = {}
	var elapsed_frames := 0
	for frame_index in range(MAX_FRAMES):
		await get_tree().process_frame
		elapsed_frames = frame_index + 1
		runtime_result = ArenaDirectTestService.load_last_result()
		if bool(runtime_result.get("runtime_scene_inspected", false)) \
				and not bool(runtime_result.get("probe_pending", true)):
			break
	evidence["probe_wait_frames"] = elapsed_frames
	if not bool(runtime_result.get("runtime_scene_inspected", false)) \
			or bool(runtime_result.get("probe_pending", true)):
		errors.append("RUNTIME_PROBE_TIMEOUT")
	else:
		errors.append_array(_runtime_result_errors(runtime_result, request))
	await _finish(errors, evidence, runtime_result)


func _preparation_errors(request: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var arena_path := str(_prepared.get("arena_path", ""))
	var context_root := str(_prepared.get("context_root", ""))
	var disk_request := _load_json(ArenaDirectTestService.REQUEST_PATH)
	var temporary := ResourceLoader.load(
		arena_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition if ResourceLoader.exists(arena_path) else null
	var temporary_fingerprint := (
		ArenaSnapshotService.arena_fingerprint(temporary)
		if temporary != null else ""
	)
	var temporary_topology: Dictionary = (
		ArenaTopologySignatureService.build(temporary)
		if temporary != null else {}
	)
	var temporary_topology_hash := str(temporary_topology.get(
		"topology_hash", ""
	))

	_check(errors, not request.is_empty(), "REQUEST_PAYLOAD_MISSING")
	_check(
		errors,
		int(request.get("contract_version", 0)) \
			== ArenaDirectTestService.CONTRACT_VERSION,
		"REQUEST_CONTRACT_IS_NOT_CURRENT"
	)
	_check(
		errors,
		int(request.get("contract_version", 0)) == 5,
		"REQUEST_CONTRACT_IS_NOT_V5"
	)
	_check(errors, bool(request.get("probe_runtime", false)), "PROBE_NOT_REQUESTED")
	_check(errors, bool(request.get("probe_only", false)), "PROBE_ONLY_NOT_REQUESTED")
	_check(errors, bool(request.get("cleanup_on_load", false)), "CLEANUP_NOT_REQUESTED")
	_check(
		errors,
		not bool(request.get("quit_after_probe", true)),
		"PROBE_MUST_NOT_PREEMPT_OBSERVER_EXIT"
	)
	_check(
		errors,
		arena_path.begins_with(ArenaDirectTestService.WORK_ROOT + "/"),
		"TEMPORARY_ARENA_OUTSIDE_OWNED_USER_CONTEXT"
	)
	_check(
		errors,
		context_root.begins_with(ArenaDirectTestService.WORK_ROOT + "/"),
		"TEMPORARY_CONTEXT_OUTSIDE_OWNED_USER_ROOT"
	)
	_check(errors, not arena_path.begins_with(PRODUCED_PREFIX), "TEMPORARY_ARENA_IS_PRODUCED")
	_check(errors, ResourceLoader.exists(arena_path), "TEMPORARY_ARENA_MISSING")
	_check(errors, temporary != null, "TEMPORARY_ARENA_LOAD_FAILED")
	_check(
		errors,
		temporary != null and temporary.resource_path == arena_path,
		"TEMPORARY_ARENA_EXACT_PATH_MISMATCH"
	)
	_check(
		errors,
		FileAccess.file_exists(ArenaDirectTestService.REQUEST_PATH),
		"REQUEST_FILE_MISSING"
	)
	_check(errors, not disk_request.is_empty(), "REQUEST_FILE_INVALID_JSON")
	_check(
		errors,
		str(disk_request.get("arena_path", "")) == arena_path,
		"DISK_REQUEST_ARENA_PATH_MISMATCH"
	)
	_check(
		errors,
		int(disk_request.get("contract_version", 0)) == 5,
		"DISK_REQUEST_CONTRACT_IS_NOT_V5"
	)
	_check(
		errors,
		str(request.get("expected_battle_scene_path", "")) \
			== EXPECTED_BATTLE_SCENE_PATH,
		"REQUEST_BATTLE_SCENE_PATH_MISMATCH"
	)
	_check(
		errors,
		str(request.get("configuration", "")) == str(CONFIGURATION),
		"REQUEST_CONFIGURATION_MISMATCH"
	)
	_check(
		errors,
		not str(request.get("runtime_probe_key", "")).is_empty(),
		"REQUEST_PROBE_KEY_EMPTY"
	)
	_check(
		errors,
		str(request.get("runtime_probe_key", "")) \
			== str(disk_request.get("runtime_probe_key", "")),
		"DISK_REQUEST_PROBE_KEY_MISMATCH"
	)
	_check(
		errors,
		_working_fingerprint == str(_prepared.get("working_fingerprint", "")) \
			and _working_fingerprint \
				== str(_prepared.get("temporary_fingerprint", "")) \
			and _working_fingerprint \
				== str(_prepared.get("runtime_fingerprint", "")) \
			and _working_fingerprint == temporary_fingerprint,
		"PREPARED_FINGERPRINTS_DIVERGE"
	)
	_check(
		errors,
		bool(_prepared.get("fingerprints_identical", false)),
		"PREPARED_FINGERPRINT_FLAG_FALSE"
	)
	_check(
		errors,
		_working_topology_hash \
			== str(_prepared.get("working_topology_hash", "")) \
			and _working_topology_hash \
				== str(_prepared.get("temporary_topology_hash", "")) \
			and _working_topology_hash \
				== str(_prepared.get("runtime_topology_hash", "")) \
			and _working_topology_hash == temporary_topology_hash,
		"PREPARED_TOPOLOGY_HASHES_DIVERGE"
	)
	_check(
		errors,
		bool(_prepared.get("topology_hashes_identical", false)),
		"PREPARED_TOPOLOGY_FLAG_FALSE"
	)
	_check(
		errors,
		not bool(_prepared.get("produced_bundle_loaded", true)),
		"PREPARE_REPORTED_PRODUCED_BUNDLE"
	)
	_check(
		errors,
		not _dependency_closure_contains_produced(arena_path),
		"TEMPORARY_ARENA_DEPENDS_ON_PRODUCED"
	)
	return errors


func _preparation_evidence(request: Dictionary) -> Dictionary:
	var arena_path := str(_prepared.get("arena_path", ""))
	var temporary := ResourceLoader.load(
		arena_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition if ResourceLoader.exists(arena_path) else null
	var temporary_topology: Dictionary = (
		ArenaTopologySignatureService.build(temporary)
		if temporary != null else {}
	)
	return {
		"contract_version": int(request.get("contract_version", 0)),
		"request_path": ArenaDirectTestService.REQUEST_PATH,
		"request_file_written": FileAccess.file_exists(
			ArenaDirectTestService.REQUEST_PATH
		),
		"temporary_context_root": str(_prepared.get("context_root", "")),
		"temporary_arena_path": arena_path,
		"temporary_resource_path": (
			temporary.resource_path if temporary != null else ""
		),
		"temporary_fingerprint": (
			ArenaSnapshotService.arena_fingerprint(temporary)
			if temporary != null else ""
		),
		"runtime_fingerprint_prepared": str(_prepared.get(
			"runtime_fingerprint", ""
		)),
		"fingerprints_identical_prepared": bool(_prepared.get(
			"fingerprints_identical", false
		)),
		"temporary_topology_hash": str(temporary_topology.get(
			"topology_hash", ""
		)),
		"runtime_topology_hash_prepared": str(_prepared.get(
			"runtime_topology_hash", ""
		)),
		"topology_hashes_identical_prepared": bool(_prepared.get(
			"topology_hashes_identical", false
		)),
		"runtime_probe_key": str(request.get("runtime_probe_key", "")),
		"produced_bundle_loaded_prepared": bool(_prepared.get(
			"produced_bundle_loaded", true
		)),
	}


func _runtime_result_errors(
		runtime_result: Dictionary,
		request: Dictionary
	) -> Array[String]:
	var errors: Array[String] = []
	var arena_path := str(_prepared.get("arena_path", ""))
	_check(errors, bool(runtime_result.get("ok", false)), "RUNTIME_RESULT_NOT_OK")
	_check(
		errors,
		bool(runtime_result.get("request_consumed_once", false)),
		"REQUEST_NOT_CONSUMED_ONCE"
	)
	_check(
		errors,
		str(runtime_result.get("arena_path_loaded", "")) == arena_path,
		"RUNNER_LOADED_WRONG_ARENA_PATH"
	)
	_check(
		errors,
		str(runtime_result.get("battle_scene_path", "")) \
			== EXPECTED_BATTLE_SCENE_PATH,
		"RUNTIME_BATTLE_SCENE_PATH_MISMATCH"
	)
	_check(
		errors,
		str(runtime_result.get("expected_battle_scene_path", "")) \
			== EXPECTED_BATTLE_SCENE_PATH,
		"RUNTIME_EXPECTED_SCENE_PATH_MISMATCH"
	)
	_check(
		errors,
		bool(runtime_result.get("scene_exact", false)),
		"RUNTIME_SCENE_NOT_EXACT"
	)
	_check(
		errors,
		bool(runtime_result.get("script_parse_ok", false)),
		"RUNTIME_SCRIPT_PARSE_FAILED"
	)
	_check(
		errors,
		bool(runtime_result.get("scene_instantiated", false)),
		"RUNTIME_SCENE_NOT_INSTANTIATED"
	)
	_check(
		errors,
		bool(runtime_result.get("runtime_ready", false)),
		"RUNTIME_READY_FALSE"
	)
	_check(errors, bool(runtime_result.get("grid_ready", false)), "GRID_DATA_MISSING")
	_check(
		errors,
		bool(runtime_result.get("pathfinder_ready", false)),
		"PATHFINDER_MISSING"
	)
	_check(errors, bool(runtime_result.get("render_ready", false)), "RENDER_NOT_READY")
	_check(errors, bool(runtime_result.get("spawn_ready", false)), "SPAWNS_NOT_READY")
	_check(
		errors,
		str(runtime_result.get("configuration", "")) == str(CONFIGURATION),
		"RUNTIME_CONFIGURATION_MISMATCH"
	)
	_check(
		errors,
		bool(runtime_result.get("configuration_consumed", false)),
		"RUNTIME_CONFIGURATION_NOT_CONSUMED"
	)
	_check(
		errors,
		str(runtime_result.get("camera_mode", "")) == "STUDIO_MATCH",
		"RUNTIME_CAMERA_MODE_MISMATCH"
	)
	_check(
		errors,
		_working_fingerprint \
			== str(runtime_result.get("working_fingerprint", "")) \
			and _working_fingerprint \
				== str(runtime_result.get("temporary_fingerprint", "")) \
			and _working_fingerprint \
				== str(runtime_result.get("runtime_fingerprint", "")),
		"RUNTIME_FINGERPRINTS_DIVERGE"
	)
	_check(
		errors,
		bool(runtime_result.get("fingerprints_identical", false)),
		"RUNTIME_FINGERPRINT_FLAG_FALSE"
	)
	_check(
		errors,
		_working_topology_hash \
			== str(runtime_result.get("working_topology_hash", "")) \
			and _working_topology_hash \
				== str(runtime_result.get("temporary_topology_hash", "")) \
			and _working_topology_hash \
				== str(runtime_result.get("runtime_topology_hash", "")),
		"RUNTIME_TOPOLOGY_HASHES_DIVERGE"
	)
	_check(
		errors,
		bool(runtime_result.get("topology_hashes_identical", false)),
		"RUNTIME_TOPOLOGY_FLAG_FALSE"
	)
	_check(
		errors,
		str(runtime_result.get("runtime_probe_key", "")) \
			== str(request.get("runtime_probe_key", "")),
		"RUNTIME_PROBE_KEY_MISMATCH"
	)
	_check(
		errors,
		not bool(runtime_result.get("produced_bundle_loaded", true)),
		"RUNNER_LOADED_PRODUCED_BUNDLE"
	)
	_check(
		errors,
		bool(runtime_result.get("cleanup_required", false)),
		"RUNTIME_CLEANUP_NOT_REQUIRED"
	)
	_check(
		errors,
		bool(runtime_result.get("cleanup_ok", false)),
		"RUNTIME_CONTEXT_CLEANUP_FAILED"
	)
	return errors


func _finish(
		errors: Array[String],
		evidence: Dictionary,
		runtime_result: Dictionary
	) -> void:
	var request_value: Variant = _prepared.get("request", {})
	var request: Dictionary = (
		(request_value as Dictionary).duplicate(true)
		if request_value is Dictionary else {}
	)
	var context_root := str(_prepared.get("context_root", ""))
	var cleanup_ok := true
	if not context_root.is_empty() and _context_exists(context_root):
		cleanup_ok = ArenaDirectTestService.cleanup_context(request)
	if _runner != null and is_instance_valid(_runner):
		_runner.queue_free()
		_runner = null

	var runtime_scene := get_tree().current_scene
	var manager := get_tree().root.get_node_or_null("GameManager")
	if manager != null and manager.has_method("cleanup_run_state"):
		manager.call("cleanup_run_state")
	else:
		cleanup_ok = false
		if not errors.has("GAME_MANAGER_CLEANUP_UNAVAILABLE"):
			errors.append("GAME_MANAGER_CLEANUP_UNAVAILABLE")
	get_tree().current_scene = null
	if runtime_scene != null and is_instance_valid(runtime_scene):
		runtime_scene.queue_free()
	for metadata_key in [
		&"arena_studio_test_configuration",
		&"arena_studio_test_options",
	]:
		if get_tree().has_meta(metadata_key):
			get_tree().remove_meta(metadata_key)
	for _frame in range(4):
		await get_tree().process_frame

	var context_removed := context_root.is_empty() or not _context_exists(context_root)
	var request_removed := not FileAccess.file_exists(
		ArenaDirectTestService.REQUEST_PATH
	)
	var scene_freed := runtime_scene == null or not is_instance_valid(runtime_scene)
	var game_manager_clean := _game_manager_is_clean(manager)
	var tree_metadata_clean := not get_tree().has_meta(
		&"arena_studio_test_configuration"
	) and not get_tree().has_meta(&"arena_studio_test_options")
	var source_sha256_after := FileAccess.get_sha256(SOURCE_PATH)
	_check(errors, cleanup_ok, "BEST_EFFORT_CONTEXT_CLEANUP_FAILED")
	_check(errors, context_removed, "TEMPORARY_CONTEXT_STILL_EXISTS")
	_check(errors, request_removed, "REQUEST_FILE_STILL_EXISTS")
	_check(errors, scene_freed, "RUNTIME_SCENE_STILL_ALIVE")
	_check(errors, game_manager_clean, "GAME_MANAGER_STATE_NOT_CLEAN")
	_check(errors, tree_metadata_clean, "DIRECT_TEST_TREE_METADATA_NOT_CLEAN")
	_check(
		errors,
		not _source_sha256.is_empty() and source_sha256_after == _source_sha256,
		"CANONICAL_SOURCE_CHANGED"
	)

	var ok := errors.is_empty()
	var exit_code := 0 if ok else 1
	evidence.merge({
		"ok": ok,
		"exit_code": exit_code,
		"errors": errors.duplicate(),
		"runtime_result": runtime_result.duplicate(true),
		"source_sha256_after": source_sha256_after,
		"canonical_source_unchanged": (
			not _source_sha256.is_empty() and source_sha256_after == _source_sha256
		),
		"temporary_context_removed": context_removed,
		"request_file_removed": request_removed,
		"runtime_scene_freed": scene_freed,
		"game_manager_clean": game_manager_clean,
		"direct_test_tree_metadata_clean": tree_metadata_clean,
		"produced_bundle_loaded": bool(runtime_result.get(
			"produced_bundle_loaded", false
		)) if not runtime_result.is_empty() else false,
		"duration_ms": float(Time.get_ticks_usec() - _started_usec) / 1000.0,
	}, true)
	_write_json(RESULT_PATH, evidence)
	var console_evidence := evidence.duplicate(true)
	if console_evidence.has("runtime_result"):
		var compact_runtime := runtime_result.duplicate(true)
		compact_runtime.erase("visual_report")
		compact_runtime.erase("scene_tree_representations")
		console_evidence["runtime_result"] = compact_runtime
	print("ARENA_TESTER_E2E_SMOKE ", JSON.stringify(console_evidence))
	# Let both coroutine stacks unwind, release their ArenaDefinition graphs,
	# and free this observer before asking SceneTree to exit. This keeps shutdown
	# diagnostics meaningful instead of reporting locals that are still live.
	var tree := get_tree()
	var quit_timer := tree.create_timer(0.1)
	quit_timer.timeout.connect(tree.quit.bind(exit_code))
	_prepared.clear()
	queue_free()


func _game_manager_is_clean(manager: Node) -> bool:
	if manager == null:
		return false
	var rooms_value: Variant = manager.get("rooms")
	var rooms_empty := rooms_value is Array and (rooms_value as Array).is_empty()
	return not bool(manager.get("run_active")) \
		and int(manager.get("current_room_index")) == -1 \
		and rooms_empty \
		and manager.call("get_current_room") == null


func _annotate_legacy_working_copy(arena: ArenaDefinition) -> Dictionary:
	var terrain_override_notes := 0
	for definition_value in arena.cells:
		var definition := definition_value as ArenaCellDefinition
		if definition == null or not ArenaTerrainRegistry.has(definition.terrain_id):
			continue
		var terrain_entry := ArenaTerrainRegistry.get_entry(definition.terrain_id)
		var expected_defined := definition.terrain_id != &"void"
		var expected_playable := bool(terrain_entry.get("walkable", false)) \
			and not definition.border
		var expected_type := int(terrain_entry.get(
			"cell_type", GridData.CellType.HOLE
		))
		var is_override := definition.defined != expected_defined \
			or definition.playable != expected_playable \
			or definition.cell_type != expected_type
		if is_override and definition.production_note.strip_edges().is_empty():
			definition.production_note = (
				"Smoke E2E: override historique canonique conserve sans mutation runtime."
			)
			terrain_override_notes += 1

	var required_hero_seen := {
		ArenaSpawnDefinition.Kind.HERO_1: false,
		ArenaSpawnDefinition.Kind.HERO_2: false,
		ArenaSpawnDefinition.Kind.HERO_3: false,
	}
	var required_flags_adjusted := 0
	var enemy_group_ids_added := 0
	for spawn_value in arena.spawns:
		var spawn := spawn_value as ArenaSpawnDefinition
		if spawn == null:
			continue
		if spawn.kind == ArenaSpawnDefinition.Kind.ENEMY_GROUP \
				and spawn.group_id == &"":
			spawn.group_id = &"e2e_canonical_enemy_pool"
			enemy_group_ids_added += 1
		if not spawn.is_hero() or not required_hero_seen.has(spawn.kind):
			continue
		var must_be_required := not bool(required_hero_seen[spawn.kind])
		if spawn.required != must_be_required:
			spawn.required = must_be_required
			required_flags_adjusted += 1
		required_hero_seen[spawn.kind] = true
	return {
		"scope": "transient_working_copy_only",
		"terrain_override_notes_added": terrain_override_notes,
		"enemy_group_ids_added": enemy_group_ids_added,
		"required_hero_flags_adjusted": required_flags_adjusted,
		"coordinates_changed": false,
		"runtime_consumed_fields_changed": false,
		"canonical_saved": false,
	}


func _blocking_validation_codes(report: ArenaValidationReport) -> Array[String]:
	var result: Array[String] = []
	if report == null:
		result.append("validation_report_missing")
		return result
	for message_value in report.messages:
		var message := message_value as ArenaValidationMessage
		if message == null \
				or message.severity != ArenaValidationMessage.Severity.ERROR:
			continue
		var code := str(message.code)
		if not result.has(code):
			result.append(code)
	result.sort()
	return result


func _dependency_closure_contains_produced(root_path: String) -> bool:
	var pending: Array[String] = [root_path]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var current := pending.pop_back()
		if current.begins_with(PRODUCED_PREFIX):
			return true
		if visited.has(current):
			continue
		visited[current] = true
		if not ResourceLoader.exists(current):
			continue
		for raw_dependency in ResourceLoader.get_dependencies(current):
			var dependency_text := str(raw_dependency)
			if dependency_text.contains(PRODUCED_PREFIX):
				return true
			var dependency_path := _resource_path_from_dependency(dependency_text)
			if not dependency_path.is_empty() and not visited.has(dependency_path):
				pending.append(dependency_path)
	return false


func _resource_path_from_dependency(dependency: String) -> String:
	var resource_index := dependency.find("res://")
	return dependency.substr(resource_index) if resource_index >= 0 else ""


func _context_exists(context_root: String) -> bool:
	if context_root.is_empty():
		return false
	return DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(context_root).simplify_path()
	)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _write_json(path: String, value: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  "))
	file.close()
	return true


func _check(
		errors: Array[String],
		condition: bool,
		code: String
	) -> void:
	if not condition and not errors.has(code):
		errors.append(code)
