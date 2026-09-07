@tool
class_name ItemCatalog
extends Resource

@export var definitions: Array[ItemDefinition] = []
@export var auto_discovery_directories: PackedStringArray = PackedStringArray()
@export var excluded_discovery_directories: PackedStringArray = PackedStringArray()

var _definitions_by_id: Dictionary = {}
var _resolved_definitions: Array[ItemDefinition] = []
var _index_built := false


func rebuild_index() -> bool:
	_definitions_by_id.clear()
	_resolved_definitions = _collect_definitions()
	_index_built = false
	for definition in _resolved_definitions:
		if definition == null or not definition.is_valid():
			return false
		if _definitions_by_id.has(definition.item_id):
			return false
		_definitions_by_id[definition.item_id] = definition
	_index_built = true
	return true


func get_definition(item_id: StringName) -> ItemDefinition:
	if not _index_built:
		if not rebuild_index():
			return null
	return _definitions_by_id.get(item_id) as ItemDefinition


func has_definition(item_id: StringName) -> bool:
	return get_definition(item_id) != null


func get_definitions() -> Array[ItemDefinition]:
	if not _index_built and not rebuild_index():
		return []
	return _resolved_definitions.duplicate()


func validate_catalog() -> Dictionary:
	var resolved := _collect_definitions()
	var seen := {}
	var errors: Array[String] = []
	for index in range(resolved.size()):
		var definition := resolved[index]
		if definition == null:
			errors.append("Définition nulle à l’index %d." % index)
			continue
		if not definition.is_valid():
			errors.append("Définition invalide : %s." % definition.item_id)
		if seen.has(definition.item_id):
			errors.append("Identifiant dupliqué : %s." % definition.item_id)
		seen[definition.item_id] = true
	return {
		"valid": errors.is_empty() and rebuild_index(),
		"errors": errors,
		"definition_count": resolved.size(),
	}


func _collect_definitions() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	var explicit_paths := {}
	for definition in definitions:
		if definition != null and not definition.resource_path.is_empty():
			explicit_paths[definition.resource_path] = true
		result.append(definition)
	var discovered_paths: Array[String] = []
	for directory in auto_discovery_directories:
		_collect_resource_paths(str(directory), discovered_paths)
	discovered_paths.sort()
	for resource_path in discovered_paths:
		if explicit_paths.has(resource_path):
			continue
		var resource := load(resource_path)
		if resource is ItemDefinition:
			result.append(resource as ItemDefinition)
	return result


func _collect_resource_paths(
		directory_path: String,
		result: Array[String]
	) -> void:
	for excluded_directory in excluded_discovery_directories:
		var excluded := str(excluded_directory).trim_suffix("/")
		if directory_path == excluded or directory_path.begins_with(excluded + "/"):
			return
	var directory := DirAccess.open(directory_path)
	if directory == null:
		push_warning("Dossier d’objets introuvable : %s" % directory_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_resource_paths(path, result)
		elif entry.get_extension().to_lower() in ["tres", "res"]:
			result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
