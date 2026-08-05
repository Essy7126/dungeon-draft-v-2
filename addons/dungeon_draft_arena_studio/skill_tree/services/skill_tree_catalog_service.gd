@tool
class_name SkillTreeCatalogService
extends RefCounted

const HERO_ROOT := "res://data/units/alliés"


static func discover_heroes() -> Array[Dictionary]:
	var heroes: Array[Dictionary] = []
	for path in _resource_files(HERO_ROOT):
		var resource := ResourceLoader.load(
			path, "", ResourceLoader.CACHE_MODE_REUSE
		) as UnitData
		if resource == null or resource.team != 0 or resource.disciplines.is_empty():
			continue
		heroes.append({
			"id": resource.get_effective_unit_id(),
			"name": resource.unit_name,
			"path": path,
			"resource": resource,
			"discipline_count": resource.disciplines.size(),
			"invalid": _hero_has_obvious_error(resource),
		})
	heroes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")).naturalnocasecmp_to(
			str(b.get("name", ""))
		) < 0
	)
	return heroes


static func disciplines_for(hero: UnitData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if hero == null:
		return result
	for discipline in hero.disciplines:
		if discipline == null:
			result.append({
				"id": &"",
				"name": "Discipline manquante",
				"resource": null,
				"invalid": true,
			})
			continue
		result.append({
			"id": discipline.discipline_id,
			"name": discipline.display_name,
			"path": discipline.resource_path,
			"resource": discipline,
			"spell": spell_for_discipline(hero, discipline.discipline_id),
			"invalid": not SkillTreeResolver.validate_discipline(discipline).is_empty(),
		})
	return result


static func spell_for_discipline(
		hero: UnitData,
		discipline_id: StringName
	) -> Spell:
	if hero == null or discipline_id == &"":
		return null
	for spell in hero.spells:
		if spell != null and spell.discipline_id == discipline_id:
			return spell
	return null


static func all_spells(hero: UnitData) -> Array[Spell]:
	var result: Array[Spell] = []
	if hero == null:
		return result
	for spell in hero.spells:
		if spell != null:
			result.append(spell)
	return result


static func _hero_has_obvious_error(hero: UnitData) -> bool:
	if hero.get_effective_unit_id() == &"unit_data:unassigned":
		return true
	var seen := {}
	for discipline in hero.disciplines:
		if discipline == null or discipline.discipline_id == &"" \
				or seen.has(discipline.discipline_id):
			return true
		seen[discipline.discipline_id] = true
	return false


static func _resource_files(root: String) -> PackedStringArray:
	var result := PackedStringArray()
	_append_resource_files(root, result)
	result.sort()
	return result


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
