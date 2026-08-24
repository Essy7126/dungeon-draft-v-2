@tool
class_name ArenaDraftSaveService
extends RefCounted

## Brouillon local d'un terrain. Un brouillon est une copie personnelle : il
## vit sous user://, hors de res://data/arenas/produced que la production
## decouvre automatiquement, et il ne modifie donc jamais une partie ni une
## Resource canonique.

const DRAFT_ROOT := "user://dungeon_draft_studio/arena_studio/drafts"
const SCHEMA_VERSION := 1


static func draft_path(arena_id: StringName) -> String:
	return DRAFT_ROOT.path_join("%s.json" % ArenaDefinition.sanitize_id(str(arena_id)))


## Plan lisible avant ecriture : l'utilisateur voit toujours ce qui va etre
## ecrit et ce qui ne le sera pas.
static func plan(arena: ArenaDefinition) -> Dictionary:
	if arena == null:
		return {"ok": false, "error": "no_arena"}
	var path := draft_path(arena.arena_id)
	return {
		"ok": true,
		"path": path,
		"replaces_existing": FileAccess.file_exists(path),
		"summary": "Enregistrer le brouillon de « %s » dans votre dossier personnel." \
			% arena.display_name,
		"guarantees": PackedStringArray([
			"Aucune partie n'est modifiée.",
			"Aucun fichier de production n'est créé.",
			"Vous pourrez reprendre ce brouillon plus tard.",
		]),
	}


static func save(arena: ArenaDefinition, context := {}) -> Dictionary:
	if arena == null:
		return {"ok": false, "error": "no_arena"}
	var path := draft_path(arena.arena_id)
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return {"ok": false, "error": "directory_failed", "path": path}
	var payload := arena.to_snapshot()
	payload["_schema_version"] = SCHEMA_VERSION
	payload["_studio_product_version"] = StudioVersion.PRODUCT_VERSION
	payload["_saved_at"] = Time.get_datetime_string_from_system(true)
	payload["_draft_context"] = (context as Dictionary).duplicate(true)
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "open_failed", "path": path}
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		DirAccess.remove_absolute(temporary)
		return {"ok": false, "error": "commit_failed", "path": path}
	var verified = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not verified is Dictionary:
		return {"ok": false, "error": "verification_failed", "path": path}
	return {
		"ok": true,
		"path": path,
		"summary": "Brouillon enregistré : %s" % path,
	}


static func load_draft(arena_id: StringName) -> ArenaDefinition:
	var path := draft_path(arena_id)
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return null
	var arena := ArenaDefinition.new()
	return arena if arena.restore_snapshot(parsed) else null


static func has_draft(arena_id: StringName) -> bool:
	return FileAccess.file_exists(draft_path(arena_id))


static func drafts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(DRAFT_ROOT)
	if directory == null:
		return result
	for file_name in directory.get_files():
		if not file_name.ends_with(".json"):
			continue
		var path := DRAFT_ROOT.path_join(file_name)
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			continue
		result.append({
			"path": path,
			"arena_id": str((parsed as Dictionary).get("arena_id", file_name.get_basename())),
			"display_name": str((parsed as Dictionary).get("display_name", "")),
			"saved_at": str((parsed as Dictionary).get("_saved_at", "")),
		})
	result.sort_custom(func(left, right):
		return str(left.get("saved_at", "")) > str(right.get("saved_at", ""))
	)
	return result


static func remove(arena_id: StringName) -> bool:
	var absolute := ProjectSettings.globalize_path(draft_path(arena_id))
	if not FileAccess.file_exists(absolute):
		return true
	return DirAccess.remove_absolute(absolute) == OK
