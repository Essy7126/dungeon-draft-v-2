class_name ArenaMapSerializer
extends RefCounted

const MAP_ROOT := "user://arena_map_editor/maps"
const EXPORT_ROOT := "user://arena_map_editor/exports"


static func save_json(document: ArenaMapDocument, path: String) -> Error:
	if document == null or not document.validation_errors().is_empty():
		return ERR_INVALID_DATA
	var absolute := ProjectSettings.globalize_path(path)
	var directory := absolute.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK:
		return directory_error
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(document.to_dict(), "  "))
	return OK


static func load_json(path: String) -> ArenaMapDocument:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return null
	var document := ArenaMapDocument.new(Vector2i.ONE)
	return document if document.load_from_dict(parsed) else null


static func suggested_map_path(document: ArenaMapDocument) -> String:
	return MAP_ROOT.path_join(document.map_id + ".json")


static func suggested_export_dir(document: ArenaMapDocument) -> String:
	return EXPORT_ROOT.path_join(document.map_id)


static func build_nano_banana_brief(document: ArenaMapDocument) -> String:
	var counts := document.counts()
	return "\n".join([
		"NANO BANANA — ARENA DECOR BRIEF",
		"Map: %s (%s)" % [document.display_name, document.map_id],
		"Type: %s | Theme: %s" % [document.map_kind, document.theme_id],
		"Grid: %d x %d | Projection isometrique 64 x 32, diamond-down" % [
			document.grid_size.x, document.grid_size.y,
		],
		"Cellules actives: %d | VOID: %d | Murs: %d | Speciales: %d" % [
			counts.active, counts.void, counts.walls, counts.specials,
		],
		"",
		"INTENTION ARTISTIQUE",
		document.decor_prompt,
		"",
		"CONTRAINTES IMPERATIVES",
		"- Ne pas modifier la silhouette, la projection, le nombre ni la position des dalles.",
		"- Ne pas peindre de surface praticable sur les cellules VOID.",
		"- Conserver exactement les murs, spawns, objectifs et ancres decoratives.",
		"- Construire le decor autour et sous les limites de l'arene.",
		"- Ne pas masquer les centres de cellules ni inventer de raccourci praticable.",
		"- Utiliser map_logic.png et map_debug.png comme autorites geometriques.",
		"- Utiliser map_reference.png comme guide de volume et de couleurs.",
	])


static func save_export_metadata(document: ArenaMapDocument, export_dir: String) -> Error:
	var absolute := ProjectSettings.globalize_path(export_dir)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute)
	if directory_error != OK:
		return directory_error
	var manifest := FileAccess.open(absolute.path_join("map_definition.json"), FileAccess.WRITE)
	if manifest == null:
		return FileAccess.get_open_error()
	manifest.store_string(JSON.stringify(document.to_dict(), "  "))
	var brief := FileAccess.open(absolute.path_join("nano_banana_brief.txt"), FileAccess.WRITE)
	if brief == null:
		return FileAccess.get_open_error()
	brief.store_string(build_nano_banana_brief(document))
	return OK
