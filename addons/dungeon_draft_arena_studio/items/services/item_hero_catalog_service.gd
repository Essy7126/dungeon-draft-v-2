@tool
class_name ItemHeroCatalogService
extends RefCounted

# Les deux orthographes existent dans le dépôt. Le catalogue parcourt les deux
# racines au lieu de maintenir une liste de personnages dans chaque écran.
const HERO_ROOTS: Array[String] = [
	"res://data/units/alliés",
	"res://data/units/allies",
]
const PLAYER_TEAM := 0

var _entries: Array[Dictionary] = []
var _warnings: Array[String] = []
var _built := false


func rebuild() -> Dictionary:
	_entries.clear()
	_warnings.clear()
	var paths := PackedStringArray()
	for root in HERO_ROOTS:
		_append_resource_files(root, paths)
	paths.sort()
	var seen_ids := {}
	for path in paths:
		if not _dependencies_available(path):
			_warnings.append("Héros ignoré, dépendance manquante : %s" % path)
			continue
		var hero := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as UnitData
		if hero == null or hero.team != PLAYER_TEAM:
			continue
		var hero_id := hero.get_effective_unit_id()
		if hero_id == &"unit_data:unassigned":
			_warnings.append("Héros ignoré, identifiant absent : %s" % path)
			continue
		if seen_ids.has(hero_id):
			_warnings.append(
				"Héros dupliqué ignoré : %s (%s et %s)" % [
					hero_id, seen_ids[hero_id], path,
				]
			)
			continue
		seen_ids[hero_id] = path
		var editorial_resource := hero
		var authorities := RunContentCatalogService.progression_authorities_for_unit(hero)
		if authorities.size() == 1:
			var progression := (authorities[0] as Dictionary).get(
				"progression_profile"
			) as CharacterProgressionProfile
			if progression != null:
				editorial_resource = RunContentCatalogService.as_editable_unit_view(
					hero, progression
				)
		_entries.append({
			"id": hero_id,
			"display_name": hero.unit_name if not hero.unit_name.strip_edges().is_empty() else str(hero_id),
			"path": path,
			"resource": editorial_resource,
			"unit_resource": hero,
			"progression_authority_count": authorities.size(),
		})
	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).naturalnocasecmp_to(
			str(b.get("display_name", ""))
		) < 0
	)
	_built = true
	return {
		"ok": not _entries.is_empty(),
		"heroes": entries(),
		"warnings": _warnings.duplicate(),
	}


func entries() -> Array[Dictionary]:
	_ensure_built()
	return _entries.duplicate(false)


func known_ids() -> Array[StringName]:
	_ensure_built()
	var result: Array[StringName] = []
	for entry in _entries:
		result.append(StringName(entry.get("id", &"")))
	return result


func entry_for_id(hero_id: StringName) -> Dictionary:
	_ensure_built()
	for entry in _entries:
		if StringName(entry.get("id", &"")) == hero_id:
			return entry.duplicate(false)
	return {}


func warnings() -> Array[String]:
	_ensure_built()
	return _warnings.duplicate()


func _ensure_built() -> void:
	if not _built:
		rebuild()


static func _dependencies_available(path: String) -> bool:
	for dependency in ResourceLoader.get_dependencies(path):
		var target := ""
		for part in str(dependency).split("::"):
			if part.begins_with("res://"):
				target = part
		if not target.is_empty() \
				and not ResourceLoader.exists(target) \
				and not FileAccess.file_exists(target):
			return false
	return true


static func _append_resource_files(path: String, result: PackedStringArray) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() in ["tres", "res"]:
			result.append(path.path_join(file_name))
	for directory_name in directory.get_directories():
		if directory_name.begins_with("."):
			continue
		_append_resource_files(path.path_join(directory_name), result)
