@tool
class_name ArenaRunAuthoringService
extends RefCounted

## Session transactionnelle pour la sequence RunData.rooms. Retirer une salle
## ne supprime jamais son fichier.

signal changed(report: Dictionary)

const RECOVERY_ROOT := "user://dungeon_draft_studio/arena_run_authoring/recovery"

var source_run: RunData = null
var working_run: RunData = null
var source_path := ""
var history: Array[Array] = []
var history_index := -1
var saved_fingerprint := ""
var reference_graph: StudioReferenceGraphService = null


func open(run_data: RunData, graph: StudioReferenceGraphService = null) -> bool:
	if run_data == null:
		return false
	source_run = run_data
	source_path = run_data.resource_path
	reference_graph = graph
	working_run = run_data.duplicate(false) as RunData
	working_run.set_path_cache("")
	working_run.rooms.assign(run_data.rooms)
	history = [_snapshot_rooms()]
	history_index = 0
	saved_fingerprint = fingerprint()
	changed.emit(state_report(&"OPEN"))
	return true


func insert_room(index: int, room: RoomData) -> Dictionary:
	if working_run == null or room == null:
		return _failure("Salle ou partie absente.")
	var target := clampi(index, 0, working_run.rooms.size())
	var rooms: Array[RoomData] = working_run.rooms.duplicate()
	rooms.insert(target, room)
	return _commit(&"INSERT", rooms, {"index": target, "room_path": room.resource_path})


func replace_room(index: int, room: RoomData) -> Dictionary:
	if not _valid_index(index) or room == null:
		return _failure("Remplacement hors limites ou salle absente.")
	var rooms: Array[RoomData] = working_run.rooms.duplicate()
	var previous := rooms[index]
	rooms[index] = room
	return _commit(&"REPLACE", rooms, {
		"index": index,
		"previous_path": previous.resource_path if previous != null else "",
		"room_path": room.resource_path,
	})


func update_room(index: int, room: RoomData) -> Dictionary:
	if not _valid_index(index) or room == null:
		return _failure("Mise à jour hors limites ou salle absente.")
	var current := working_run.rooms[index]
	if current == null or current.resource_path.is_empty() \
			or room.resource_path != current.resource_path:
		return _failure(
			"UPDATE conserve la référence canonique ; utilisez REPLACE pour changer de fichier."
		)
	return {
		"ok": true,
		"operation": &"UPDATE_IN_PLACE",
		"index": index,
		"room_path": current.resource_path,
		"sequence_changed": false,
		"requires_room_integration_service": true,
	}


func duplicate_room(index: int) -> Dictionary:
	if not _valid_index(index):
		return _failure("Duplication hors limites.")
	var source := working_run.rooms[index]
	if source == null:
		return _failure("La salle source est absente.")
	var copied: RoomData
	if source is ArenaDefinition:
		copied = ArenaDefinition.new()
		(copied as ArenaDefinition).restore_snapshot((source as ArenaDefinition).to_snapshot())
	else:
		copied = source.duplicate(true) as RoomData
	copied.set_path_cache("")
	var result := insert_room(index + 1, copied)
	result["operation"] = &"DUPLICATE"
	result["requires_destination_path"] = true
	return result


func move_room(from_index: int, to_index: int) -> Dictionary:
	if not _valid_index(from_index) or working_run.rooms.is_empty():
		return _failure("Déplacement hors limites.")
	var target := clampi(to_index, 0, working_run.rooms.size() - 1)
	var rooms: Array[RoomData] = working_run.rooms.duplicate()
	var room := rooms.pop_at(from_index) as RoomData
	rooms.insert(target, room)
	return _commit(&"MOVE", rooms, {"from": from_index, "to": target})


func remove_room(index: int) -> Dictionary:
	if not _valid_index(index):
		return _failure("Retrait hors limites.")
	var rooms: Array[RoomData] = working_run.rooms.duplicate()
	var removed := rooms.pop_at(index) as RoomData
	var result := _commit(&"REMOVE_REFERENCE", rooms, {
		"index": index,
		"removed_path": removed.resource_path if removed != null else "",
		"file_deleted": false,
	})
	result["removed_resource"] = removed
	return result


func make_room_run_specific(index: int, destination_path: String) -> Dictionary:
	if not _valid_index(index):
		return _failure("Copie spécifique hors limites.")
	if not _safe_resource_path(destination_path) or ResourceLoader.exists(destination_path):
		return _failure("Le chemin de copie est invalide ou déjà utilise.")
	var source := working_run.rooms[index]
	if source == null:
		return _failure("La salle source est absente.")
	var copied := source.duplicate(true) as RoomData
	copied.set_path_cache("")
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(destination_path.get_base_dir())
	)
	if directory_error != OK:
		return _failure("Le dossier cible ne peut pas être créé.")
	var save_error := ResourceSaver.save(copied, destination_path)
	if save_error != OK:
		return _failure("La copie spécifique ne peut pas être enregistree.")
	var reloaded := ResourceLoader.load(
		destination_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RoomData
	if reloaded == null:
		return _failure("La copie spécifique ne peut pas être relue.")
	var result := replace_room(index, reloaded)
	result["operation"] = &"COPY_ON_WRITE"
	result["created_path"] = destination_path
	return result


func undo() -> bool:
	if history_index <= 0:
		return false
	history_index -= 1
	_restore_rooms(history[history_index])
	changed.emit(state_report(&"UNDO"))
	return true


func redo() -> bool:
	if history_index + 1 >= history.size():
		return false
	history_index += 1
	_restore_rooms(history[history_index])
	changed.emit(state_report(&"REDO"))
	return true


func reload() -> bool:
	if source_path.is_empty() or not ResourceLoader.exists(source_path):
		return false
	var disk := ResourceLoader.load(
		source_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	return open(disk, reference_graph)


func build_save_plan() -> Dictionary:
	var before := _room_paths(source_run.rooms if source_run != null else [])
	var after := _room_paths(working_run.rooms if working_run != null else [])
	return {
		"ok": working_run != null and not source_path.is_empty(),
		"run_path": source_path,
		"before": before,
		"after": after,
		"changed_indices": _changed_indices(before, after),
		"removed_files": [],
		"fingerprint": fingerprint(),
	}


func save() -> Dictionary:
	var plan := build_save_plan()
	if not plan.get("ok", false):
		return _failure("La partie ne possède pas de chemin canonique.")
	if not is_dirty():
		return {"ok": true, "saved_paths": [], "plan": plan}
	for room in working_run.rooms:
		if room == null:
			return _failure("La séquence contient une salle absente.")
		if room.resource_path.is_empty():
			return _failure(
				"Une salle sans chemin externe doit recevoir une copie spécifique avant sauvegarde."
			)
	var recovery := RECOVERY_ROOT.path_join(
		"save_%d_%d" % [int(Time.get_unix_time_from_system() * 1000000.0), Time.get_ticks_usec()]
	)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(recovery)) != OK:
		return _failure("Le point de récupération ne peut pas être créé.")
	var backup := recovery.path_join(source_path.get_file() + ".bak")
	if DirAccess.copy_absolute(
			ProjectSettings.globalize_path(source_path), ProjectSettings.globalize_path(backup)
		) != OK:
		return _failure("La partie canonique ne peut pas être sauvegardée avant écriture.")
	var staging := recovery.path_join("staged_run.tres")
	var staged_run := ResourceLoader.load(
		staging, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData if ResourceSaver.save(working_run, staging) == OK else null
	if staged_run == null:
		return _failure("La préparation de la partie a échoué.")
	var error := ResourceSaver.save(working_run, source_path)
	if error != OK:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(source_path))
		return _failure("L'écriture de la partie a échoué.")
	var reloaded := ResourceLoader.load(
		source_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	if reloaded == null or _room_paths(reloaded.rooms) != plan.get("after", []):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(source_path))
		return _failure("La vérification de la séquence sauvegardée a échoué.")
	open(reloaded, reference_graph)
	if reference_graph != null:
		reference_graph.invalidate(source_path)
	return {
		"ok": true,
		"saved_paths": PackedStringArray([source_path]),
		"recovery_path": recovery,
		"backup_path": backup,
		"plan": plan,
	}


func write_draft() -> Dictionary:
	if working_run == null or not is_dirty():
		return _failure("Aucune séquence de partie modifiée à conserver.")
	var directory := "user://dungeon_draft_studio/arena_run_authoring/drafts"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		return _failure("Le dossier de brouillon ne peut pas être créé.")
	var identity := source_path.sha256_text().left(20)
	var path := directory.path_join("%s.tres" % identity)
	var error := ResourceSaver.save(working_run, path)
	return {
		"ok": error == OK,
		"path": path,
		"source_path": source_path,
		"error": error_string(error) if error != OK else "",
	}


func is_dirty() -> bool:
	return working_run != null and fingerprint() != saved_fingerprint


func snapshot() -> Array:
	return _snapshot_rooms()


func restore_snapshot(snapshot_value: Array) -> Dictionary:
	_restore_rooms(snapshot_value)
	return {"ok": working_run != null}


func fingerprint() -> String:
	return JSON.stringify(_room_paths(working_run.rooms if working_run != null else [])).sha256_text()


func room_usages(index: int) -> Array[Dictionary]:
	if not _valid_index(index) or reference_graph == null:
		return []
	return reference_graph.usages(working_run.rooms[index])


func state_report(operation: StringName) -> Dictionary:
	return {
		"ok": working_run != null,
		"operation": operation,
		"room_count": working_run.rooms.size() if working_run != null else 0,
		"dirty": is_dirty(),
		"can_undo": history_index > 0,
		"can_redo": history_index + 1 < history.size(),
	}


func _commit(operation: StringName, rooms: Array[RoomData], metadata: Dictionary) -> Dictionary:
	working_run.rooms.assign(rooms)
	if history_index + 1 < history.size():
		history.resize(history_index + 1)
	history.append(_snapshot_rooms())
	history_index = history.size() - 1
	var result := state_report(operation)
	result.merge(metadata, true)
	changed.emit(result)
	return result


func _snapshot_rooms() -> Array:
	return working_run.rooms.duplicate() if working_run != null else []


func _restore_rooms(snapshot: Array) -> void:
	var rooms: Array[RoomData] = []
	rooms.assign(snapshot)
	working_run.rooms = rooms


func _valid_index(index: int) -> bool:
	return working_run != null and index >= 0 and index < working_run.rooms.size()


func _room_paths(rooms: Array) -> Array[String]:
	var result: Array[String] = []
	for room_value in rooms:
		var room := room_value as RoomData
		result.append(room.resource_path if room != null else "")
	return result


func _changed_indices(before: Array, after: Array) -> Array[int]:
	var result: Array[int] = []
	for index in range(maxi(before.size(), after.size())):
		if index >= before.size() or index >= after.size() or before[index] != after[index]:
			result.append(index)
	return result


func _safe_resource_path(path: String) -> bool:
	return path.begins_with("res://data/") and not path.contains("..") \
		and path.get_extension().to_lower() in ["tres", "res"]


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
