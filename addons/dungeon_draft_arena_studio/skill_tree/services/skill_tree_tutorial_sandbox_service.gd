@tool
class_name SkillTreeTutorialSandboxService
extends RefCounted

## Possède les fixtures du tutoriel et borne toutes leurs écritures à user://.

const ROOT := "user://dungeon_draft_studio/tests/skill_tree_tutorial/"
const INITIAL_FILE := "initial_character.tres"
const WORKING_FILE := "tutorial_character.tres"

var session_directory := ""
var source_path := ""
var initial_path := ""


func start(session: SkillTreeEditSession) -> Dictionary:
	if session == null:
		return _failure("La session d’édition est indisponible.")
	session_directory = ROOT.path_join(_new_session_id()) + "/"
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(session_directory)
	)
	if directory_error != OK:
		return _failure("Impossible de créer le dossier possédé par l’exercice.")
	initial_path = session_directory.path_join(INITIAL_FILE)
	source_path = session_directory.path_join(WORKING_FILE)
	var initial_error := ResourceSaver.save(_build_fixture(), initial_path)
	var source_error := ResourceSaver.save(_build_fixture(), source_path)
	if initial_error != OK or source_error != OK:
		return _failure("Impossible d’enregistrer les fixtures de l’exercice.")
	var source := ResourceLoader.load(
		source_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData
	if source == null or not session.open(source):
		return _failure("La fixture créée ne peut pas être ouverte dans le Studio.")
	configure_session(session)
	session.last_operation_report = {
		"operation": "OPEN_TUTORIAL_SANDBOX",
		"source_path": source_path,
		"allowed_root": session_directory,
	}
	return {
		"ok": true,
		"message": (
			"Exercice sécurisé chargé. Créez une discipline et son sort, puis "
			+ "suivez le chapitre 10. Toutes les écritures restent sous user://."
		),
		"source_path": source_path,
		"initial_path": initial_path,
		"allowed_root": session_directory,
		"catalog_entry": catalog_entry(session),
	}


func restore_initial(session: SkillTreeEditSession) -> Dictionary:
	if not is_active(session) or not FileAccess.file_exists(initial_path):
		return _failure("Aucun exercice actif ne peut être réinitialisé.")
	var initial := ResourceLoader.load(
		initial_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData
	if initial == null:
		return _failure("La copie initiale de l’exercice est illisible.")
	var copied := initial.duplicate(true) as UnitData
	copied.set_path_cache("")
	var error := ResourceSaver.save(copied, source_path)
	if error != OK:
		return _failure("L’état initial n’a pas pu être restauré.")
	var restored := ResourceLoader.load(
		source_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData
	if restored == null or not session.open(restored):
		return _failure("La fixture restaurée ne peut pas être rouverte.")
	configure_session(session)
	session.last_operation_report = {
		"operation": "RESTORE_TUTORIAL_SANDBOX",
		"source_path": source_path,
	}
	return {
		"ok": true,
		"message": "L’exercice a retrouvé son personnage vide initial.",
		"catalog_entry": catalog_entry(session),
	}


func prepare_for_save(session: SkillTreeEditSession) -> Dictionary:
	if not is_active(session):
		return _failure("La session courante n’appartient pas à cet exercice.")
	configure_session(session)
	var resources: Array[Resource] = []
	for resource_value in session.new_resource_paths:
		var resource := resource_value as Resource
		if resource != null:
			resources.append(resource)
	var remapped := PackedStringArray()
	for resource in resources:
		var former_path := str(session.new_resource_paths.get(resource, ""))
		var candidate := session_directory.path_join(
			_folder_for(resource)
		).path_join(_file_stem_for(resource, former_path) + ".tres")
		var path := session.path_reservations.generate_unique_path(
			candidate, _resource_type_name(resource)
		)
		if path.is_empty() or not _is_owned_path(path):
			return _failure("Un chemin sûr n’a pas pu être réservé pour l’exercice.")
		session.path_reservations.reserve(path, resource, _resource_type_name(resource))
		session.new_resource_paths[resource] = path
		resource.set_path_cache(path)
		remapped.append(path)
	return {
		"ok": true,
		"remapped_paths": remapped,
		"allowed_root": session_directory,
	}


func configure_session(session: SkillTreeEditSession) -> void:
	if session == null or session_directory.is_empty():
		return
	session.path_reservations = SkillTreePathReservationService.new(
		PackedStringArray([session_directory])
	)


func save_options() -> Dictionary:
	return {
		"allowed_roots": PackedStringArray([session_directory]),
	}


func validation_roots() -> PackedStringArray:
	return PackedStringArray([session_directory])


func is_active(session: SkillTreeEditSession) -> bool:
	return session != null and not session_directory.is_empty() \
		and session.canonical_source_path() == source_path \
		and _is_owned_path(source_path)


func catalog_entry(session: SkillTreeEditSession) -> Dictionary:
	var unit := session.working_unit if session != null else null
	return {
		"id": unit.get_effective_unit_id() if unit != null else &"tutorial_hero",
		"name": unit.unit_name if unit != null else "Héros d’exercice",
		"path": source_path,
		"resource": unit,
		"discipline_count": unit.disciplines.size() if unit != null else 0,
		"invalid": false,
		"tutorial_sandbox": true,
	}


func cleanup_owned_fixture(session: SkillTreeEditSession) -> Dictionary:
	if session != null and is_active(session):
		return _failure("Fermez l’exercice avant de supprimer sa fixture.")
	if session_directory.is_empty() or not session_directory.begins_with(ROOT) \
			or session_directory == ROOT or session_directory.contains(".."):
		return _failure("Le dossier demandé n’appartient pas à une session tutorielle.")
	var absolute := ProjectSettings.globalize_path(session_directory.trim_suffix("/"))
	var error := _remove_directory_tree(absolute)
	return {"ok": error == OK, "error": "" if error == OK \
		else "La fixture tutorielle n’a pas pu être supprimée.", "code": error}


func _build_fixture() -> UnitData:
	var unit := UnitData.new()
	unit.unit_id = &"tutorial_hero"
	unit.unit_name = "Héros d’exercice"
	unit.description = (
		"Fixture isolée du tutoriel. Créez sa première discipline sans risque."
	)
	unit.max_hp = 100
	unit.max_ap = 6
	unit.max_mp = 3
	unit.initiative = 10
	unit.attack_power = 20
	unit.active_spell_slots = 4
	unit.disciplines = []
	unit.spells = []
	return unit


func _is_owned_path(path: String) -> bool:
	return not session_directory.is_empty() \
		and session_directory.begins_with(ROOT) \
		and path.begins_with(session_directory) \
		and not path.contains("..") \
		and path.get_extension().to_lower() in ["tres", "res"]


func _folder_for(resource: Resource) -> String:
	if resource is DisciplineData:
		return "disciplines"
	if resource is Spell:
		return "spells"
	if resource is DisciplineRankData:
		return "ranks"
	if resource is SkillUpgradeData:
		return "upgrades"
	if resource is SpellModifier:
		return "modifiers"
	return "resources"


func _file_stem_for(resource: Resource, former_path: String) -> String:
	if resource is DisciplineData:
		return _slug(str((resource as DisciplineData).discipline_id))
	if resource is Spell:
		return _slug(str((resource as Spell).get_effective_spell_id()))
	if resource is DisciplineRankData:
		return "rank_%d" % (resource as DisciplineRankData).rank
	if resource is SkillUpgradeData:
		return _slug(str((resource as SkillUpgradeData).upgrade_id))
	if not former_path.is_empty():
		return _slug(former_path.get_file().get_basename())
	return "resource_%d" % resource.get_instance_id()


func _resource_type_name(resource: Resource) -> String:
	var script := resource.get_script() as Script
	var global_name := script.get_global_name() if script != null else ""
	return global_name if not global_name.is_empty() else resource.get_class()


func _new_session_id() -> String:
	return "session_%d_%d" % [
		int(Time.get_unix_time_from_system() * 1000000.0),
		Time.get_ticks_usec(),
	]


func _slug(value: String) -> String:
	var normalized := value.to_lower().strip_edges()
	var result := ""
	for character in normalized:
		if character >= "a" and character <= "z" \
				or character >= "0" and character <= "9":
			result += character
		elif not result.ends_with("_"):
			result += "_"
	return result.trim_prefix("_").trim_suffix("_") \
		if not result.is_empty() else "resource"


func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}


func _remove_directory_tree(absolute_directory: String) -> Error:
	var directory := DirAccess.open(absolute_directory)
	if directory == null:
		return OK if not DirAccess.dir_exists_absolute(absolute_directory) \
			else DirAccess.get_open_error()
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var child := absolute_directory.path_join(name)
			var error := _remove_directory_tree(child) if directory.current_is_dir() \
				else DirAccess.remove_absolute(child)
			if error != OK:
				directory.list_dir_end()
				return error
		name = directory.get_next()
	directory.list_dir_end()
	return DirAccess.remove_absolute(absolute_directory)
