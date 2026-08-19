@tool
class_name ArenaRecoveryContextSelectionService
extends RefCounted

const DOMAIN := &"arena"


static func scan(
	context: Dictionary,
	roots: PackedStringArray = PackedStringArray([
		ArenaSerializer.RECOVERY_ROOT,
		ArenaSerializer.LEGACY_RECOVERY_ROOT,
	])
	) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for root in roots:
		var directory := DirAccess.open(root)
		if directory == null:
			continue
		for file_name in directory.get_files():
			if not file_name.ends_with(".json"):
				continue
			var record := inspect(root.path_join(file_name))
			if not record.is_empty():
				candidates.append(record)
	return select_best(candidates, context).merged({
		"candidates": candidates,
		"roots": roots,
	}, false)


static func inspect(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {
			"path": path,
			"source": path,
			"domain": DOMAIN,
			"compatible": false,
			"compatibility": &"INVALID_JSON",
		}
	var snapshot := parsed as Dictionary
	var metadata := snapshot.get("_recovery_context", {}) as Dictionary
	var schema_version := int(snapshot.get("schema_version", 0))
	var compatibility := _compatibility(schema_version)
	var modified := int(FileAccess.get_modified_time(path))
	var timestamp := int(snapshot.get("_recovery_saved_at_unix", modified))
	var now := int(Time.get_unix_time_from_system())
	return {
		"path": path,
		"source": str(metadata.get("source", path)),
		"domain": StringName(metadata.get("domain", DOMAIN)),
		"arena_id": str(metadata.get("arena_id", snapshot.get("arena_id", ""))),
		"run_path": str(metadata.get("run_path", "")),
		"run_id": str(metadata.get("run_id", metadata.get("run_name", ""))),
		"room_path": str(metadata.get("room_path", "")),
		"room_id": str(metadata.get("room_id", metadata.get("room_name", ""))),
		"room_index": int(metadata.get("room_index", -1)),
		"timestamp_unix": timestamp,
		"date": Time.get_datetime_string_from_unix_time(timestamp, true),
		"age_seconds": maxi(0, now - timestamp),
		"files": PackedStringArray([path]),
		"transaction": str(metadata.get("transaction", "autosave")),
		"status": str(metadata.get("status", "RECOVERABLE")),
		"schema_version": schema_version,
		"compatibility": compatibility,
		"compatible": compatibility in [&"CURRENT", &"LEGACY"],
		"legacy_root": path.begins_with(ArenaSerializer.LEGACY_RECOVERY_ROOT + "/"),
	}


static func select_best(
	candidates: Array[Dictionary],
	context: Dictionary
	) -> Dictionary:
	var compatible: Array[Dictionary] = []
	var foreign: Array[Dictionary] = []
	var expected_domain := StringName(context.get("domain", DOMAIN))
	var expected_arena := str(context.get("arena_id", ""))
	for candidate in candidates:
		if not bool(candidate.get("compatible", false)):
			continue
		if StringName(candidate.get("domain", &"")) != expected_domain:
			foreign.append(candidate)
			continue
		if not expected_arena.is_empty() \
				and str(candidate.get("arena_id", "")) != expected_arena:
			foreign.append(candidate)
			continue
		compatible.append(candidate)
	compatible.sort_custom(func(a: Dictionary, b: Dictionary):
		return _higher_priority(a, b, context)
	)
	if compatible.is_empty():
		return {
			"ok": false,
			"error": "contextual_recovery_missing",
			"selected": {},
			"foreign_candidates": foreign,
		}
	return {
		"ok": true,
		"error": "",
		"selected": compatible[0],
		"matching_candidates": compatible,
		"foreign_candidates": foreign,
		"requires_confirmation": true,
	}


static func describe(candidate: Dictionary) -> String:
	if candidate.is_empty():
		return "Aucune récupération contextuelle."
	return (
		"Source : %s\nArène : %s\nRun : %s\nSalle : %s (index %d)\n"
		+ "Date : %s — âge : %s\nFichiers : %s\nTransaction : %s\n"
		+ "Statut : %s\nCompatibilité de schéma : %s"
	) % [
		candidate.get("source", ""),
		candidate.get("arena_id", ""),
		candidate.get("run_path", candidate.get("run_id", "non renseignée")),
		candidate.get("room_path", candidate.get("room_id", "non renseignée")),
		int(candidate.get("room_index", -1)),
		candidate.get("date", ""),
		_human_age(int(candidate.get("age_seconds", 0))),
		", ".join(candidate.get("files", PackedStringArray())),
		candidate.get("transaction", ""),
		candidate.get("status", ""),
		candidate.get("compatibility", &""),
	]


static func _priority(candidate: Dictionary, context: Dictionary) -> Array:
	var run_path := str(context.get("run_path", ""))
	var room_path := str(context.get("room_path", ""))
	var room_index := int(context.get("room_index", -1))
	var same_run := run_path.is_empty() \
		or str(candidate.get("run_path", "")) == run_path
	var same_room := (room_path.is_empty() \
		or str(candidate.get("room_path", "")) == room_path) \
		and (room_index < 0 or int(candidate.get("room_index", -1)) == room_index)
	return [
		1 if same_run else 0,
		1 if same_room else 0,
		int(candidate.get("timestamp_unix", 0)),
	]


static func _higher_priority(
	a: Dictionary,
	b: Dictionary,
	context: Dictionary
	) -> bool:
	var a_priority := _priority(a, context)
	var b_priority := _priority(b, context)
	for index in range(a_priority.size()):
		var a_value := int(a_priority[index])
		var b_value := int(b_priority[index])
		if a_value != b_value:
			return a_value > b_value
	return str(a.get("path", "")) < str(b.get("path", ""))


static func _compatibility(schema_version: int) -> StringName:
	if schema_version <= 0:
		return &"INVALID_SCHEMA"
	if schema_version > ArenaDefinition.CURRENT_SCHEMA_VERSION:
		return &"INCOMPATIBLE_FUTURE"
	if schema_version < ArenaDefinition.CURRENT_SCHEMA_VERSION:
		return &"LEGACY"
	return &"CURRENT"


static func _human_age(seconds: int) -> String:
	if seconds < 60:
		return "%d s" % seconds
	if seconds < 3600:
		return "%d min" % (seconds / 60)
	if seconds < 86400:
		return "%d h" % (seconds / 3600)
	return "%d j" % (seconds / 86400)
