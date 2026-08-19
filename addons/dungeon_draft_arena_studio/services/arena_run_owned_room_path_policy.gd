@tool
class_name ArenaRunOwnedRoomPathPolicy
extends RefCounted

## Autorite unique des chemins de RoomData possedes par une RunData.
## Les fixtures restent sous leur racine artifacts ; les runs canoniques
## utilisent le namespace run_specific deja etabli par Arena Studio.

const CANONICAL_ROOT := "res://data/arenas/run_specific"
const CANONICAL_PRODUCED_ROOT := "res://data/arenas/produced/"
const MANIFEST_FILE := "production_manifest.json"


static func path_for(
		run_data: RunData,
		room_index: int,
		room: RoomData = null,
		source_arena_path := ""
	) -> String:
	if run_data == null or run_data.resource_path.is_empty() or room_index < 0:
		return ""
	var run_id := ArenaDefinition.sanitize_id(run_data.run_name)
	if run_id.is_empty():
		run_id = ArenaDefinition.sanitize_id(
			run_data.resource_path.get_file().get_basename()
		)
	var room_label := room.room_name if room != null else ""
	if room_label.is_empty() and not source_arena_path.is_empty():
		room_label = source_arena_path.get_base_dir().get_file()
	if room_label.is_empty():
		room_label = "salle"
	var room_id := ArenaDefinition.sanitize_id(room_label)
	if run_id.is_empty() or room_id.is_empty():
		return ""
	return run_owned_root_for(run_data).path_join(run_id).path_join(
		"%02d_%s.tres" % [room_index + 1, room_id]
	)


static func run_owned_root_for(run_data: RunData) -> String:
	if run_data == null:
		return ""
	var run_path := run_data.resource_path.simplify_path()
	if run_path.begins_with("res://artifacts/"):
		return run_path.get_base_dir().path_join("run_specific")
	return CANONICAL_ROOT


static func is_run_owned_path(path: String, run_data: RunData = null) -> bool:
	var normalized := path.simplify_path()
	if normalized.is_empty() or normalized.contains("..") \
			or normalized.get_extension().to_lower() not in ["tres", "res"]:
		return false
	var root := run_owned_root_for(run_data) if run_data != null else CANONICAL_ROOT
	if not root.is_empty() and normalized.begins_with(root.trim_suffix("/") + "/"):
		return true
	# Les tests transactionnels ont leur namespace run_specific isole sous
	# res://artifacts et ne doivent jamais ecrire dans les donnees officielles.
	return normalized.begins_with("res://artifacts/") \
		and "/run_specific/" in normalized


static func is_produced_bundle_resource(path: String) -> bool:
	var normalized := path.simplify_path()
	if normalized.is_empty() or normalized.contains(".."):
		return false
	if normalized.begins_with(CANONICAL_PRODUCED_ROOT) \
			or "/produced/" in normalized:
		return true
	var directory := normalized.get_base_dir()
	if FileAccess.file_exists(directory.path_join(MANIFEST_FILE)):
		return true
	# Les plans d'integration sont construits avant l'ecriture du manifeste.
	# Ces deux noms couvrent les destinations de production des fixtures.
	return normalized.get_file() == "arena.tres" \
		and directory.get_file() in ["produced", "production"]


static func destination_report(
		run_data: RunData,
		room_index: int,
		room: RoomData,
		source_arena_path: String
	) -> Dictionary:
	var path := path_for(run_data, room_index, room, source_arena_path)
	return {
		"ok": not path.is_empty() and is_run_owned_path(path, run_data) \
			and not is_produced_bundle_resource(path),
		"path": path,
		"root": run_owned_root_for(run_data),
		"source_from_produced_bundle": is_produced_bundle_resource(
			source_arena_path
		),
		"outside_produced_bundle": not is_produced_bundle_resource(path),
	}
