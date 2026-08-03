class_name ItemCatalog
extends Resource

@export var definitions: Array[ItemDefinition] = []

var _definitions_by_id: Dictionary = {}


func rebuild_index() -> bool:
	_definitions_by_id.clear()
	for definition in definitions:
		if definition == null or not definition.is_valid():
			return false
		if _definitions_by_id.has(definition.item_id):
			return false
		_definitions_by_id[definition.item_id] = definition
	return true


func get_definition(item_id: StringName) -> ItemDefinition:
	if _definitions_by_id.size() != definitions.size():
		if not rebuild_index():
			return null
	return _definitions_by_id.get(item_id) as ItemDefinition


func has_definition(item_id: StringName) -> bool:
	return get_definition(item_id) != null


func get_definitions() -> Array[ItemDefinition]:
	return definitions.duplicate()


func validate_catalog() -> Dictionary:
	var seen := {}
	var errors: Array[String] = []
	for index in range(definitions.size()):
		var definition := definitions[index]
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
		"definition_count": definitions.size(),
	}
