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
var topology_generation := 0
var topology_hash := ""
var history := StudioHistoryController.new()
## Correspondance source ↔ copie des Resources de gameplay du brouillon. Elle
## permet à Rencontres de distinguer une rencontre déjà canonique d'une
## rencontre créée dans le brouillon, sans jamais partager l'instance source.
var gameplay_source_to_work := {}
var gameplay_work_to_source := {}
var _runtime_projection: ArenaDefinition = null
var _runtime_projection_fingerprint := ""
var editor_state := {
	"pivot_mode": "center",
	"custom_pivot": [0.0, 0.0],
	"snap_enabled": true,
	"fine_factor": 0.1,
	"layers": {},
	"accepted_design_warnings": [],
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
	# to_snapshot() ne transporte que le chemin de la rencontre : la moitié
	# Rencontres du brouillon est reprise séparément, en copie profonde, pour que
	# la working copy porte la salle complète sans toucher aux Resources sources.
	var isolation := RoomDraftAuthority.isolate_gameplay_into(working_arena, source)
	gameplay_source_to_work = isolation.get("source_to_work", {}) as Dictionary
	gameplay_work_to_source = isolation.get("work_to_source", {}) as Dictionary
	working_arena.authoring_document = true
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)
	_invalidate_runtime_projection()
	topology_generation = 0
	topology_hash = str(
		ArenaTopologySignatureService.build(working_arena).topology_hash
	)
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
	var before_hash := topology_hash
	if working_arena == null:
		working_arena = ArenaDefinition.new()
	# L'historique de Terrain ne possède que les champs de terrain. La moitié
	# Rencontres du brouillon est conservée telle quelle : Annuler/Rétablir dans
	# un domaine ne doit jamais modifier l'autre.
	var gameplay := RoomDraftAuthority.gameplay_state(working_arena)
	working_arena.authoring_document = false
	working_arena.restore_snapshot(snapshot)
	RoomDraftAuthority.restore_gameplay_state(working_arena, gameplay)
	working_arena.authoring_document = true
	ArenaRuntimeBridge.sync_runtime_resources(working_arena)
	_invalidate_runtime_projection()
	_update_topology_generation(before_hash)


## Projection runtime de la working copy. Elle est reconstruite uniquement
## quand l'empreinte du document change ; la working copy metier n'est jamais
## mutee par cette lecture.
func runtime_projection() -> ArenaDefinition:
	if working_arena == null:
		return null
	var current := current_fingerprint()
	if _runtime_projection != null and _runtime_projection_fingerprint == current:
		return _runtime_projection
	var projection := ArenaRuntimeBridge.build_runtime_projection(working_arena)
	if projection == null:
		return null
	_runtime_projection = projection
	_runtime_projection_fingerprint = current
	return projection


func runtime_state() -> ArenaRuntimeState:
	return ArenaRuntimeProjectionService.build(working_arena)


func _invalidate_runtime_projection() -> void:
	_runtime_projection = null
	_runtime_projection_fingerprint = ""


func commit(
		action_name: String,
		before: Dictionary,
		after: Dictionary,
		topology_unchanged := false
	) -> bool:
	var recorded := history.record(action_name, before, after, true)
	if recorded:
		_invalidate_runtime_projection()
		if not topology_unchanged:
			var before_topology := ArenaTopologySignatureService.from_snapshot(before)
			var after_topology := ArenaTopologySignatureService.from_snapshot(after)
			if before_topology.topology_hash != after_topology.topology_hash:
				topology_generation += 1
				topology_hash = str(after_topology.topology_hash)
		_invalidate_warning_acceptances(fingerprint(after))
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
	var saved_source := ArenaDefinition.new()
	if saved_source.restore_snapshot(saved_snapshot):
		source_arena = saved_source
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


func topology_invalidation_report() -> Dictionary:
	return {
		"topology_generation": topology_generation,
		"topology_hash": topology_hash,
		"document_dirty": is_dirty(),
		"validation_obsolete": is_dirty(),
		"preview_art_obsolete": is_dirty(),
		"preview_game_obsolete": is_dirty(),
		"runtime_test_obsolete": is_dirty(),
		"integration_certificate_obsolete": is_dirty(),
		"production_plan_obsolete": is_dirty(),
	}


func accept_design_warning(
		issue: Dictionary,
		justification: String
	) -> Dictionary:
	var reason := justification.strip_edges()
	if working_arena == null or reason.is_empty():
		return {}
	var record := {
		"warning_key": ArenaIntegrationGatePolicy.warning_key(issue),
		"code": str(issue.get("code", "warning")),
		"cell": issue.get("cell", null),
		"subject_id": str(issue.get("subject_id", "")),
		"arena_fingerprint": str(issue.get(
			"arena_fingerprint", current_fingerprint()
		)),
		"justification": reason,
		"accepted_at": Time.get_datetime_string_from_system(true),
	}
	var records: Array = editor_state.get("accepted_design_warnings", [])
	records = records.filter(func(value):
		return str((value as Dictionary).get("warning_key", "")) \
			!= str(record.warning_key) \
			or str((value as Dictionary).get("arena_fingerprint", "")) \
			!= str(record.arena_fingerprint)
	)
	records.append(record)
	editor_state["accepted_design_warnings"] = records
	return record


func accepted_design_warnings(for_fingerprint := "") -> Array[Dictionary]:
	var current := for_fingerprint if not for_fingerprint.is_empty() \
		else current_fingerprint()
	var result: Array[Dictionary] = []
	for value in editor_state.get("accepted_design_warnings", []):
		var record := value as Dictionary
		if str(record.get("arena_fingerprint", "")) == current:
			result.append(record.duplicate(true))
	return result


func _update_topology_generation(before_hash: String) -> void:
	var current := ArenaTopologySignatureService.build(working_arena)
	topology_hash = str(current.topology_hash)
	if not before_hash.is_empty() and before_hash != topology_hash:
		topology_generation += 1
	_invalidate_warning_acceptances(current_fingerprint())


func _invalidate_warning_acceptances(current: String) -> void:
	var records: Array = editor_state.get("accepted_design_warnings", [])
	editor_state["accepted_design_warnings"] = records.filter(func(value):
		return str((value as Dictionary).get("arena_fingerprint", "")) == current
	)
