@tool
class_name SkillTreeCatalogService
extends RefCounted

# Les personnages jouables ne sont plus une liste écrite en dur : tout UnitData
# d'équipe Joueur trouvé sous l'un de ces dossiers apparaît dans le Studio.
# Déposer un .tres suffit donc à ajouter un personnage, sans toucher au code.
# Les deux orthographes du dossier existent réellement dans le dépôt.
const HERO_ROOTS: Array[String] = [
	"res://data/units/alliés",
	"res://data/units/allies",
]
const ENEMY_ROOTS: Array[String] = [
	"res://data/units/ennemie",
	"res://data/units/enemies",
]
const HERO_ROOT := "res://data/units/alliés"
const TEAM_PLAYER := 0
const TEAM_ENEMY := 1


## `root` limite la recherche à un seul dossier, `playable_ids` à une liste
## d'identifiants. Les deux sont vides par défaut : tout est découvert.
static func discover_heroes(
		root := "",
		playable_ids: Array = []
	) -> Array[Dictionary]:
	return _discover(HERO_ROOTS, TEAM_PLAYER, root, playable_ids)


static func discover_enemies(
		root := "",
		playable_ids: Array = []
	) -> Array[Dictionary]:
	return _discover(ENEMY_ROOTS, TEAM_ENEMY, root, playable_ids)


## Personnages jouables ET ennemis, dans un seul catalogue trié : les héros
## d'abord, puis les ennemis, chacun par ordre alphabétique.
static func discover_units() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append_array(discover_heroes())
	result.append_array(discover_enemies())
	return result


static func _discover(
		default_roots: Array[String],
		team: int,
		root: String,
		playable_ids: Array
	) -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	var roots: Array[String] = []
	if root.is_empty():
		roots.assign(default_roots)
	else:
		roots.append(root)
	var seen_ids := {}
	for unit_root in roots:
		for path in _resource_files(unit_root):
			# Un fichier dont une dépendance a disparu se chargerait en
			# renvoyant null, mais en inondant la console d'erreurs moteur.
			# On le repère avant, sans le charger.
			if not _dependencies_available(path):
				continue
			var resource := ResourceLoader.load(
				path, "", ResourceLoader.CACHE_MODE_REUSE
			) as UnitData
			if resource == null or resource.team != team:
				continue
			var unit_id := resource.get_effective_unit_id()
			if not playable_ids.is_empty() and not playable_ids.has(unit_id):
				continue
			if seen_ids.has(unit_id):
				continue
			seen_ids[unit_id] = true
			units.append({
				"id": unit_id,
				"name": resource.unit_name,
				"path": path,
				"resource": resource,
				"team": resource.team,
				"is_enemy": resource.team == TEAM_ENEMY,
				"spell_count": resource.spells.size(),
				"discipline_count": resource.disciplines.size(),
				"invalid": _hero_has_obvious_error(resource),
			})
	units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")).naturalnocasecmp_to(
			str(b.get("name", ""))
		) < 0
	)
	return units


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


## Vrai si toutes les ressources référencées par ce fichier existent encore.
## Plusieurs fichiers d'ennemis du dépôt pointent des assets supprimés : ils
## sont inexploitables et doivent être écartés du catalogue en silence.
static func _dependencies_available(path: String) -> bool:
	for dependency in ResourceLoader.get_dependencies(path):
		var target := ""
		for part in str(dependency).split("::"):
			if part.begins_with("res://"):
				target = part
		if target.is_empty():
			continue
		if not ResourceLoader.exists(target) and not FileAccess.file_exists(target):
			return false
	return true


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
