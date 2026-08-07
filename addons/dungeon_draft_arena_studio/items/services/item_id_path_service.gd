@tool
class_name ItemIdPathService
extends RefCounted

const ACCENT_REPLACEMENTS := {
	"à": "a", "â": "a", "ä": "a", "á": "a", "ã": "a",
	"ç": "c", "é": "e", "è": "e", "ê": "e", "ë": "e",
	"î": "i", "ï": "i", "í": "i", "ô": "o", "ö": "o", "ó": "o",
	"ù": "u", "û": "u", "ü": "u", "ú": "u", "ÿ": "y", "œ": "oe",
	"’": "_", "'": "_", "-": "_", " ": "_",
}


func suggest_item_id(display_name: String, catalog: ItemStudioCatalogService) -> StringName:
	var base := normalize_item_id(display_name)
	if base.is_empty():
		base = "nouvel_objet"
	var candidate := StringName(base)
	var suffix := 2
	while catalog != null and catalog.has_item_id(candidate):
		candidate = StringName("%s_%d" % [base, suffix])
		suffix += 1
	return candidate


func normalize_item_id(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	for source in ACCENT_REPLACEMENTS:
		normalized = normalized.replace(source, ACCENT_REPLACEMENTS[source])
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789_"
	var result := ""
	var previous_underscore := false
	for character in normalized:
		var safe := character if allowed.contains(character) else "_"
		if safe == "_":
			if previous_underscore:
				continue
			previous_underscore = true
		else:
			previous_underscore = false
		result += safe
	return result.trim_prefix("_").trim_suffix("_")


func draft_path(item_id: StringName) -> String:
	return ItemStudioCatalogService.DRAFT_DIRECTORY.path_join("%s.tres" % item_id)


func shared_path(item_id: StringName, catalog: ItemStudioCatalogService) -> String:
	var directories := catalog.auto_discovery_directories() if catalog != null else PackedStringArray()
	var directory := str(directories[0]) if not directories.is_empty() \
		else "res://data/items/definitions"
	return directory.path_join("%s.tres" % item_id)


func collision_report(
		item_id: StringName,
		resource_path: String,
		catalog: ItemStudioCatalogService,
		excluded_path := ""
	) -> Dictionary:
	var collisions: Array[String] = []
	if item_id == &"":
		collisions.append("L’identifiant est vide.")
	elif catalog != null and catalog.has_item_id(item_id, excluded_path):
		collisions.append("L’identifiant %s existe déjà." % item_id)
	if resource_path.is_empty():
		collisions.append("Le chemin est vide.")
	elif FileAccess.file_exists(resource_path) and resource_path != excluded_path:
		collisions.append("Le chemin %s existe déjà." % resource_path)
	return {"valid": collisions.is_empty(), "collisions": collisions}
