@tool
class_name ArenaGuidedPipelineDiagnosticsService
extends RefCounted

## Journal de progression du pipeline guide. Les evenements sont publies sur
## stdout, exposes par signaux et persistes en JSONL avant l'etape bloquante.
## Le service ne modifie jamais Git et ne nettoie aucun recovery.

signal step_started(event: Dictionary)
signal step_completed(event: Dictionary)
signal step_failed(event: Dictionary)

const DEFAULT_ROOT := "user://dungeon_draft_studio/room_integration/diagnostics"
const DEFAULT_STEP_TIMEOUTS_MS := {
	&"UI_GATE_PLAN": 30_000,
	&"PREVIEW_CAPTURE": 30_000,
	&"PLAN": 30_000,
	&"JOURNAL": 5_000,
	&"PRODUCTION": 120_000,
	&"ATTACHMENT": 30_000,
	&"ROLLBACK": 30_000,
	&"FINALIZE": 15_000,
}
const MAX_SCENE_TREE_NODES := 512
const MAX_ARTIFACT_ENTRIES := 512
const WATCHDOG_POLL_MS := 10
const MAX_HEARTBEAT_INTERVAL_MS := 5_000

var pipeline_id := ""
var diagnostic_directory := ""
var event_log_path := ""
var diagnostic_dump_path := ""
var events: Array[Dictionary] = []

var _clock_usec := Callable()
var _context := {}
var _step_timeouts_ms := DEFAULT_STEP_TIMEOUTS_MS.duplicate(true)
var _active_step := &""
var _active_started_usec := 0
var _active_timeout_ms := 0
var _active_context := {}
var _active_files: Array = []
var _active_fingerprints := {}
var _interrupt_requested := false
var _interrupt_reason := ""
var _last_event := {}
var _last_external_signal := {}
var _watchdog_thread: Thread = null
var _watchdog_mutex := Mutex.new()
var _watchdog_state := {
	"generation": 0,
	"stop_requested": true,
	"timed_out": false,
	"dump_path": "",
	"last_signal_received": {},
}
var _watchdog_dump_path := ""


func _init(options: Dictionary = {}) -> void:
	var supplied_clock: Variant = options.get("clock_usec")
	if supplied_clock is Callable and (supplied_clock as Callable).is_valid():
		_clock_usec = supplied_clock
	var supplied_timeouts: Variant = options.get("step_timeouts_ms")
	if supplied_timeouts is Dictionary:
		for step in supplied_timeouts:
			_step_timeouts_ms[StringName(str(step).to_upper())] = maxi(
				0, int(supplied_timeouts[step])
			)
	set_context(options.get("context", {}) as Dictionary)
	pipeline_id = str(options.get("pipeline_id", "")).strip_edges()
	if pipeline_id.is_empty():
		pipeline_id = "guided_%d_%d" % [
			int(Time.get_unix_time_from_system() * 1_000_000.0),
			Time.get_ticks_usec(),
		]
	pipeline_id = _safe_name(pipeline_id)
	if pipeline_id.is_empty():
		pipeline_id = "guided_%d" % Time.get_ticks_usec()
	var root := str(options.get("diagnostic_root", DEFAULT_ROOT)).trim_suffix("/")
	diagnostic_directory = root.path_join(pipeline_id)
	event_log_path = diagnostic_directory.path_join("events.jsonl")
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(diagnostic_directory)
	)
	var file := FileAccess.open(event_log_path, FileAccess.WRITE)
	if file != null:
		file.close()


func set_context(value: Dictionary) -> void:
	for key in value:
		_context[str(key)] = _json_safe(value[key])


func timeout_for(step: StringName) -> int:
	return int(_step_timeouts_ms.get(
		StringName(str(step).to_upper()), 30_000
	))


func update_step_evidence(
		context: Dictionary = {},
		files: Variant = null,
		fingerprints: Dictionary = {}
	) -> void:
	for key in context:
		_active_context[str(key)] = _json_safe(context[key])
	if files != null:
		for path in _string_array(files):
			if not _active_files.has(path):
				_active_files.append(path)
	for key in fingerprints:
		_active_fingerprints[str(key)] = _json_safe(fingerprints[key])


func begin_step(
		step: StringName,
		context: Dictionary = {},
		files: Variant = [],
		fingerprints: Dictionary = {},
		timeout_ms := -1
	) -> Dictionary:
	if _active_step != &"":
		end_step(
			_active_step, false, "step_superseded",
			{"superseded_by": str(step)}
		)
	_active_step = StringName(str(step).to_upper())
	_active_started_usec = _now_usec()
	_active_timeout_ms = timeout_for(_active_step) if timeout_ms < 0 else maxi(
		0, timeout_ms
	)
	_active_context = _merged_context(context)
	_active_files = _string_array(files)
	_active_fingerprints = _json_safe(fingerprints) as Dictionary
	var event := _base_event(&"step_started", _active_step, 0.0)
	event["timeout_ms"] = _active_timeout_ms
	var published := _publish(event)
	_start_watchdog()
	return published


func end_step(
		step: StringName,
		success: bool,
		error := "",
		details: Dictionary = {},
		ignore_interruption := false
	) -> Dictionary:
	var normalized_step := StringName(str(step).to_upper())
	var started_usec := _active_started_usec \
		if _active_step == normalized_step else _now_usec()
	var timeout_ms := _active_timeout_ms \
		if _active_step == normalized_step else timeout_for(normalized_step)
	var watchdog := _stop_watchdog()
	var duration_usec := maxi(0, _now_usec() - started_usec)
	var duration_ms := float(duration_usec) / 1000.0
	var timed_out := bool(watchdog.get("timed_out", false)) \
		or timeout_ms > 0 and duration_usec >= timeout_ms * 1000
	var interrupted := _interrupt_requested and not ignore_interruption
	var event_name := &"step_completed" \
		if success and not timed_out and not interrupted else &"step_failed"
	var event := _base_event(event_name, normalized_step, duration_ms)
	event["timeout_ms"] = timeout_ms
	event["timed_out"] = timed_out
	event["interrupted"] = interrupted
	event["error"] = "step_timeout" if timed_out else (
		_interrupt_reason if interrupted else error
	)
	event["details"] = _json_safe(details)
	var last_event_before_failure := _last_event.duplicate(true)
	_publish(event)
	var dump := {}
	if timed_out or interrupted:
		dump = dump_diagnostic(str(event.error), {
			"step_event": event,
			"last_event_before_failure": last_event_before_failure,
			"watchdog_dump_path": watchdog.get("dump_path", ""),
		})
	_active_step = &""
	_active_started_usec = 0
	_active_timeout_ms = 0
	_active_context = {}
	_active_files = []
	_active_fingerprints = {}
	return {
		"ok": event_name == &"step_completed",
		"timed_out": timed_out,
		"interrupted": interrupted,
		"error": event.error,
		"event": event,
		"diagnostic": dump,
		"diagnostic_dump_path": diagnostic_dump_path,
		"watchdog_dump_path": _watchdog_dump_path,
	}


func request_interrupt(reason := "interruption_requested") -> Dictionary:
	_interrupt_requested = true
	_interrupt_reason = reason if not reason.is_empty() else "interruption_requested"
	return _publish({
		"event": "interruption_requested",
		"pipeline_id": pipeline_id,
		"step": str(_active_step),
		"duration_ms": _active_duration_ms(),
		"context": _json_safe(_active_context if not _active_context.is_empty() else _context),
		"files": _json_safe(_active_files),
		"fingerprints": _json_safe(_active_fingerprints),
		"reason": _interrupt_reason,
		"monotonic_usec": _now_usec(),
	})


func interruption_requested() -> bool:
	return _interrupt_requested


func interruption_reason() -> String:
	return _interrupt_reason


func record_signal(signal_name: StringName, context: Dictionary = {}) -> Dictionary:
	var event := {
		"event": "signal_received",
		"pipeline_id": pipeline_id,
		"step": str(_active_step),
		"signal": str(signal_name),
		"duration_ms": _active_duration_ms(),
		"context": _json_safe(_merged_context(context)),
		"files": _json_safe(_active_files),
		"fingerprints": _json_safe(_active_fingerprints),
		"monotonic_usec": _now_usec(),
	}
	_last_external_signal = event.duplicate(true)
	_watchdog_mutex.lock()
	_watchdog_state["last_signal_received"] = event.duplicate(true)
	_watchdog_mutex.unlock()
	return _publish(event)


func summary() -> Dictionary:
	return {
		"pipeline_id": pipeline_id,
		"diagnostic_directory": diagnostic_directory,
		"event_log_path": event_log_path,
		"diagnostic_dump_path": diagnostic_dump_path,
		"interruption_requested": _interrupt_requested,
		"interruption_reason": _interrupt_reason,
		"last_event": _last_event.duplicate(true),
		"watchdog_dump_path": _watchdog_dump_path,
		"last_signal_received": _last_external_signal.duplicate(true),
		"events": events.duplicate(true),
	}


func dump_diagnostic(reason: String, extra: Dictionary = {}) -> Dictionary:
	var active_duration := _active_duration_ms()
	var artifacts := _capture_runtime_artifacts()
	var dump := {
		"pipeline_id": pipeline_id,
		"reason": reason,
		"step": str(_active_step),
		"duration_ms": active_duration,
		"timeout_ms": _active_timeout_ms,
		"context": _json_safe(
			_active_context if not _active_context.is_empty() else _context
		),
		"files": _json_safe(_active_files),
		"fingerprints": _json_safe(_active_fingerprints),
		"last_signal_received": _last_external_signal.duplicate(true) \
			if not _last_external_signal.is_empty() else _last_event.duplicate(true),
		"last_event": _last_event.duplicate(true),
		"git_status": _capture_git_status(),
		"scene_tree": _capture_scene_tree(),
		"locks": artifacts.locks,
		"transactions": artifacts.transactions,
		"staging": artifacts.staging,
		"recovery": artifacts.recovery,
		"events": events.duplicate(true),
		"extra": _json_safe(extra),
		"watchdog_dump_path": _watchdog_dump_path,
		"captured_unix_time": Time.get_unix_time_from_system(),
	}
	var step_name := _safe_name(str(_active_step).to_lower())
	if step_name.is_empty():
		step_name = "pipeline"
	diagnostic_dump_path = diagnostic_directory.path_join(
		"diagnostic_%s_%d.json" % [step_name, Time.get_ticks_usec()]
	)
	_write_json(diagnostic_dump_path, dump)
	return dump


func _base_event(
		event_name: StringName,
		step: StringName,
		duration_ms: float
	) -> Dictionary:
	return {
		"event": str(event_name),
		"pipeline_id": pipeline_id,
		"step": str(step),
		"duration_ms": duration_ms,
		"context": _json_safe(_active_context),
		"files": _json_safe(_active_files),
		"fingerprints": _json_safe(_active_fingerprints),
		"monotonic_usec": _now_usec(),
	}


func _publish(event: Dictionary) -> Dictionary:
	var safe_event := _json_safe(event) as Dictionary
	events.append(safe_event.duplicate(true))
	_last_event = safe_event.duplicate(true)
	_append_event_log(safe_event)
	print("ARENA_GUIDED_PIPELINE_EVENT %s" % JSON.stringify(safe_event))
	match str(safe_event.get("event", "")):
		"step_started":
			step_started.emit(safe_event.duplicate(true))
		"step_completed":
			step_completed.emit(safe_event.duplicate(true))
		"step_failed":
			step_failed.emit(safe_event.duplicate(true))
	return safe_event


func _append_event_log(event: Dictionary) -> bool:
	_watchdog_mutex.lock()
	var written := _append_json_line(event_log_path, event)
	_watchdog_mutex.unlock()
	return written


func _merged_context(value: Dictionary) -> Dictionary:
	var merged := _context.duplicate(true)
	for key in value:
		merged[str(key)] = _json_safe(value[key])
	return merged


func _active_duration_ms() -> float:
	if _active_step == &"" or _active_started_usec <= 0:
		return 0.0
	return float(maxi(0, _now_usec() - _active_started_usec)) / 1000.0


func _now_usec() -> int:
	if _clock_usec.is_valid():
		return int(_clock_usec.call())
	return Time.get_ticks_usec()


func _start_watchdog() -> void:
	_stop_watchdog()
	if _active_step == &"" or _active_timeout_ms <= 0:
		return
	_watchdog_mutex.lock()
	_watchdog_state["generation"] = int(_watchdog_state.generation) + 1
	var generation := int(_watchdog_state.generation)
	_watchdog_state["stop_requested"] = false
	_watchdog_state["timed_out"] = false
	_watchdog_state["dump_path"] = ""
	_watchdog_state["last_signal_received"] = _last_external_signal.duplicate(true)
	_watchdog_thread = Thread.new()
	var timeout_dump_path := diagnostic_directory.path_join(
		"watchdog_%s_%d.json" % [
			_safe_name(str(_active_step).to_lower()), Time.get_ticks_usec(),
		]
	)
	var payload := {
		"pipeline_id": pipeline_id,
		"step": str(_active_step),
		"timeout_ms": _active_timeout_ms,
		"context": _active_context.duplicate(true),
		"files": _active_files.duplicate(true),
		"fingerprints": _active_fingerprints.duplicate(true),
		"last_signal_received": _last_external_signal.duplicate(true),
		"event_log_path": event_log_path,
	}
	var thread := _watchdog_thread
	_watchdog_mutex.unlock()
	if thread == null:
		return
	var error := thread.start(ArenaGuidedPipelineDiagnosticsService._watchdog_loop.bind(
		_watchdog_mutex, _watchdog_state, generation, _active_timeout_ms,
		payload, timeout_dump_path, event_log_path
	))
	if error != OK:
		_watchdog_mutex.lock()
		_watchdog_state["stop_requested"] = true
		_watchdog_thread = null
		_watchdog_mutex.unlock()


func _stop_watchdog() -> Dictionary:
	_watchdog_mutex.lock()
	_watchdog_state["stop_requested"] = true
	var thread: Thread = _watchdog_thread
	_watchdog_mutex.unlock()
	if thread != null and thread.is_started():
		thread.wait_to_finish()
	_watchdog_mutex.lock()
	var timed_out := bool(_watchdog_state.timed_out)
	var dump_path := str(_watchdog_state.dump_path) if timed_out else ""
	if timed_out:
		_watchdog_dump_path = dump_path
	_watchdog_thread = null
	_watchdog_mutex.unlock()
	return {"timed_out": timed_out, "dump_path": dump_path}


static func _watchdog_loop(
		shared_mutex: Mutex,
		shared_state: Dictionary,
		generation: int,
		timeout_ms: int,
		payload: Dictionary,
		timeout_dump_path: String,
		log_path: String
	) -> void:
	var started_msec := Time.get_ticks_msec()
	var poll_interval_ms := mini(
		WATCHDOG_POLL_MS, maxi(1, int(timeout_ms / 4.0))
	)
	var heartbeat_interval_ms := mini(
		MAX_HEARTBEAT_INTERVAL_MS,
		maxi(poll_interval_ms, int(timeout_ms / 4.0))
	)
	var next_heartbeat_msec := started_msec + heartbeat_interval_ms
	while true:
		OS.delay_msec(poll_interval_ms)
		shared_mutex.lock()
		var stopped := bool(shared_state.stop_requested) \
			or generation != int(shared_state.generation)
		var last_signal: Dictionary = (
			shared_state.get("last_signal_received", {}) as Dictionary
		).duplicate(true)
		shared_mutex.unlock()
		if stopped:
			return
		var now_msec := Time.get_ticks_msec()
		var elapsed_ms := now_msec - started_msec
		if now_msec >= next_heartbeat_msec:
			var heartbeat := payload.duplicate(true)
			heartbeat["last_signal_received"] = last_signal
			heartbeat.merge({
				"event": "pipeline_heartbeat",
				"duration_ms": elapsed_ms,
				"monotonic_msec": now_msec,
			}, true)
			shared_mutex.lock()
			_append_json_line(log_path, heartbeat)
			shared_mutex.unlock()
			print("ARENA_GUIDED_PIPELINE_EVENT %s" % JSON.stringify(heartbeat))
			next_heartbeat_msec = now_msec + heartbeat_interval_ms
		if elapsed_ms < timeout_ms:
			continue
		var timeout_dump := payload.duplicate(true)
		timeout_dump["last_signal_received"] = last_signal
		timeout_dump.merge({
			"event": "step_failed",
			"kind": "step_timeout_watchdog",
			"duration_ms": elapsed_ms,
			"timed_out": true,
			"interrupted": false,
			"error": "step_timeout",
			"reason": "main_thread_did_not_return_before_deadline",
			"capture_deferred_to_main_thread": [
				"git_status", "scene_tree", "locks", "transactions",
				"staging", "recovery",
			],
		}, true)
		_write_json(timeout_dump_path, timeout_dump)
		shared_mutex.lock()
		_append_json_line(log_path, timeout_dump)
		shared_mutex.unlock()
		printerr(
			"ARENA_GUIDED_PIPELINE_TIMEOUT %s" % JSON.stringify(timeout_dump)
		)
		shared_mutex.lock()
		if generation == int(shared_state.generation):
			shared_state["timed_out"] = true
			shared_state["dump_path"] = timeout_dump_path
		shared_mutex.unlock()
		return


func _capture_git_status() -> Dictionary:
	var repository := ProjectSettings.globalize_path("res://")
	var output: Array[String] = []
	var exit_code := OS.execute(
		"git",
		PackedStringArray([
			"--no-optional-locks", "-C", repository, "status", "--short",
			"--untracked-files=all",
		]),
		output,
		true,
		false,
	)
	return {
		"attempted": true,
		"read_only": true,
		"optional_locks_disabled": true,
		"command": "git --no-optional-locks status --short --untracked-files=all",
		"exit_code": exit_code,
		"output": output,
	}


func _capture_scene_tree() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return {"available": false, "nodes": []}
	var nodes: Array[Dictionary] = []
	_append_scene_node(tree.root, nodes, 0)
	return {
		"available": true,
		"node_count": nodes.size(),
		"truncated": nodes.size() >= MAX_SCENE_TREE_NODES,
		"nodes": nodes,
	}


func _append_scene_node(
		node: Node,
		result: Array[Dictionary],
		depth: int
	) -> void:
	if node == null or result.size() >= MAX_SCENE_TREE_NODES:
		return
	result.append({
		"path": str(node.get_path()),
		"class": node.get_class(),
		"depth": depth,
		"inside_tree": node.is_inside_tree(),
		"process_mode": int(node.process_mode),
	})
	for child in node.get_children():
		if child is Node:
			_append_scene_node(child, result, depth + 1)
		if result.size() >= MAX_SCENE_TREE_NODES:
			return


func _capture_runtime_artifacts() -> Dictionary:
	var result := {
		"locks": [],
		"transactions": [],
		"staging": [],
		"recovery": [],
	}
	var roots := PackedStringArray([
		"user://dungeon_draft_studio/production_transactions",
		"user://dungeon_draft_studio/room_integration/recovery",
	])
	var destination := str(_context.get("destination", ""))
	if not destination.is_empty():
		roots.append(destination.get_base_dir())
	for root in roots:
		var seen := {}
		_collect_artifacts(root, root, result, seen, 0)
	return result


func _collect_artifacts(
		root: String,
		current: String,
		result: Dictionary,
		seen: Dictionary,
		depth: int
	) -> void:
	if depth > 8 or seen.size() >= MAX_ARTIFACT_ENTRIES:
		return
	var absolute := ProjectSettings.globalize_path(current)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	for file_name in directory.get_files():
		if seen.size() >= MAX_ARTIFACT_ENTRIES:
			return
		var path := current.path_join(file_name)
		if seen.has(path):
			continue
		seen[path] = true
		var entry := _file_entry(path)
		var lower := file_name.to_lower()
		if "lock" in lower or lower.ends_with(".marker"):
			(result.locks as Array).append(entry)
		if ".staging" in path.to_lower():
			(result.staging as Array).append(entry)
		if "/recovery" in path.to_lower() or "/backup" in path.to_lower():
			(result.recovery as Array).append(entry)
		if lower == "transaction_report.json":
			var transaction := _read_json(path)
			transaction["report_path"] = path
			(result.transactions as Array).append(_json_safe(transaction))
	for child in directory.get_directories():
		if seen.size() >= MAX_ARTIFACT_ENTRIES:
			return
		var child_path := current.path_join(child)
		var entry := {
			"path": child_path,
			"kind": "directory",
			"root": root,
		}
		var lower_path := child_path.to_lower()
		if ".staging" in lower_path:
			(result.staging as Array).append(entry)
		if "/recovery" in lower_path or "/backup" in lower_path:
			(result.recovery as Array).append(entry)
		_collect_artifacts(root, child_path, result, seen, depth + 1)


func _file_entry(path: String) -> Dictionary:
	var size := 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		size = file.get_length()
		file.close()
	return {
		"path": path,
		"kind": "file",
		"size": size,
		"modified_unix_time": FileAccess.get_modified_time(path),
		"sha256": FileAccess.get_sha256(path),
	}


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_json_safe(value), "  "))
	file.close()
	return true


static func _append_json_line(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.seek_end()
	file.store_line(JSON.stringify(_json_safe(value)))
	file.close()
	return true


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is PackedStringArray or value is Array:
		for item in value:
			var path := str(item)
			if not path.is_empty() and not result.has(path):
				result.append(path)
	return result


static func _json_safe(value: Variant, depth := 0) -> Variant:
	if depth > 12:
		return "<max_depth>"
	if value == null or value is bool or value is int or value is float \
			or value is String:
		return value
	if value is StringName or value is NodePath:
		return str(value)
	if value is Dictionary:
		var dictionary := {}
		for key in value:
			dictionary[str(key)] = _json_safe(value[key], depth + 1)
		return dictionary
	if value is Array or value is PackedStringArray or value is PackedInt32Array \
			or value is PackedFloat32Array or value is PackedByteArray \
			or value is PackedVector2Array:
		var array: Array = []
		for item in value:
			array.append(_json_safe(item, depth + 1))
		return array
	if value is Resource:
		return {
			"class": (value as Resource).get_class(),
			"resource_path": (value as Resource).resource_path,
		}
	if value is Object:
		return {
			"class": (value as Object).get_class(),
			"instance_id": (value as Object).get_instance_id(),
		}
	return str(value)


static func _safe_name(value: String) -> String:
	var result := ""
	for character in value.to_lower():
		if character in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			result += character
		else:
			result += "_"
	return result.strip_edges().trim_prefix("_").trim_suffix("_")
