@tool
class_name ArenaEditSession
extends RefCounted

var session_key := ""
var source_arena: ArenaDefinition = null
var working_arena: ArenaDefinition = null
var source_path := ""
var saved_snapshot := {}
var source_fingerprint := ""
var source_is_visual := false
var is_new_document := false
var history := StudioHistoryController.new()
var editor_state := {
	"pivot_mode": "center",
	"custom_pivot": [0.0, 0.0],
	"snap_enabled": true,
	"fine_factor": 0.1,
	"layers": {},
}


func open(
		source: ArenaDefinition,
		path := "",
		mark_new := false,
		key := ""
	) -> bool:
	if source == null:
		return false
	source_arena = source
	source_path = path if not path.is_empty() else (
		source.source_visual_path if not source.source_visual_path.is_empty() \
		else source.resource_path
	)
	source_is_visual = not source.source_visual_path.is_empty() \
		and source_path == source.source_visual_path
	session_key = key if not key.is_empty() else (
		source_path if not source_path.is_empty() else str(source.arena_id)
	)
	working_arena = ArenaDefinition.new()
	if not working_arena.restore_snapshot(source.to_snapshot()):
		working_arena = null
		return false
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)
	saved_snapshot = working_arena.to_snapshot().duplicate(true)
	source_fingerprint = ArenaSerializer.visual_calibration_fingerprint(source_path) \
		if source_is_visual else fingerprint(source.to_snapshot())
	is_new_document = mark_new
	history = StudioHistoryController.new()
	history.configure(
		Callable(self, "apply_snapshot"),
		Callable(self, "current_fingerprint"),
	)
	history.set_saved_fingerprint("__UNSAVED__" if mark_new else current_fingerprint())
	return true


func apply_snapshot(snapshot: Dictionary) -> void:
	if working_arena == null:
		working_arena = ArenaDefinition.new()
	working_arena.restore_snapshot(snapshot)
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)


func commit(action_name: String, before: Dictionary, after: Dictionary) -> bool:
	var recorded := history.record(action_name, before, after, true)
	if recorded:
		is_new_document = is_new_document and source_path.is_empty()
	return recorded


func is_dirty() -> bool:
	return is_new_document or not history.is_at_saved_state()


func current_fingerprint() -> String:
	return fingerprint(working_arena.to_snapshot()) if working_arena != null else ""


func mark_saved(path: String) -> void:
	source_path = path
	source_is_visual = working_arena != null \
		and not working_arena.source_visual_path.is_empty() \
		and path == working_arena.source_visual_path
	is_new_document = false
	saved_snapshot = working_arena.to_snapshot().duplicate(true)
	source_fingerprint = ArenaSerializer.visual_calibration_fingerprint(path) \
		if source_is_visual else fingerprint(saved_snapshot)
	history.set_saved_fingerprint(current_fingerprint())


func saved_transform() -> GridTransformSnapshot:
	return GridTransformSnapshot.from_dictionary({
		"origin": saved_snapshot.get("grid_origin", [0.0, 0.0]),
		"axis_x": saved_snapshot.get("axis_x", [48.0, 24.0]),
		"axis_y": saved_snapshot.get("axis_y", [-48.0, 24.0]),
	})


func has_external_conflict() -> bool:
	if source_path.is_empty() or not ResourceLoader.exists(source_path):
		return false
	if source_is_visual:
		return ArenaSerializer.visual_calibration_fingerprint(source_path) \
			!= source_fingerprint
	var disk := ResourceLoader.load(
		source_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ArenaDefinition
	return disk != null and fingerprint(disk.to_snapshot()) != source_fingerprint


static func fingerprint(snapshot: Dictionary) -> String:
	return JSON.stringify(snapshot).sha256_text()
