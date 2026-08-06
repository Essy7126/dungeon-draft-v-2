@tool
class_name SkillTreePropertyRegistry
extends RefCounted

enum Classification {
	EDITABLE,
	READ_ONLY_JUSTIFIED,
	HIDDEN_JUSTIFIED,
	UNSUPPORTED_ERROR,
}

const HIDDEN_PROPERTIES := {
	&"script": "Le script définit le type de Resource et ne constitue pas une donnée de design.",
	&"resource_path": "Le chemin est géré par le plan de sauvegarde.",
	&"resource_name": "Le nom interne Godot n'est pas utilisé par le gameplay.",
	&"resource_local_to_scene": "Cette option moteur est conservée par le format de Resource.",
}

const LABELS_FR := {
	&"unit_id": "Identifiant du personnage",
	&"discipline_id": "Identifiant de discipline",
	&"upgrade_id": "Identifiant de l'amélioration",
	&"spell_id": "Identifiant du sort",
	&"target_spell_id": "Sort ciblé",
	&"spell_modifiers": "Effets de progression",
	&"modifiers": "Modificateurs permanents",
	&"summon_initial_cooldowns": "Recharges initiales de l'invocation",
	&"resistances": "Résistances élémentaires",
	&"prerequisite_node_ids": "Prérequis",
	&"excluded_node_ids": "Exclusions",
}


static func contract_for(
		resource: Resource,
		property_name: StringName
	) -> Dictionary:
	if resource == null or property_name == &"":
		return _unsupported(property_name, "Resource ou propriété absente.")
	if HIDDEN_PROPERTIES.has(property_name):
		return _contract(
			property_name,
			Classification.HIDDEN_JUSTIFIED,
			"hidden",
			str(HIDDEN_PROPERTIES[property_name]),
			null,
			{}
		)
	var info := _property_info(resource, property_name)
	if info.is_empty():
		return _unsupported(property_name, "La propriété n'existe pas sur cette Resource.")
	var usage := int(info.get("usage", 0))
	if usage & PROPERTY_USAGE_STORAGE == 0:
		return _contract(
			property_name,
			Classification.READ_ONLY_JUSTIFIED,
			"readonly",
			"Propriété calculée ou d'éditeur, non sérialisée dans la Resource.",
			resource.get(property_name),
			info
		)
	var editor := _editor_type(info, resource.get(property_name))
	if editor == "unsupported":
		return _unsupported(
			property_name,
			"Type Variant %d sans éditeur déclaré." % int(info.get("type", TYPE_NIL)),
			info
		)
	return _contract(
		property_name,
		Classification.EDITABLE,
		editor,
		"Valeur sérialisée utilisée par le document ou le runtime.",
		resource.get(property_name),
		info
	)


static func contracts_for(resource: Resource) -> Dictionary:
	var result := {}
	if resource == null:
		return result
	for info_value in resource.get_property_list():
		var info := info_value as Dictionary
		var property_name := StringName(info.get("name", &""))
		if property_name == &"":
			continue
		result[property_name] = contract_for(resource, property_name)
	return result


static func audit(root: UnitData) -> Dictionary:
	var unsupported: Array[Dictionary] = []
	var hidden: Array[Dictionary] = []
	var readonly: Array[Dictionary] = []
	var editable: Array[Dictionary] = []
	var resources := SkillTreeReferenceIndex.new().build(root).resources
	for resource in resources:
		for property_name_value in contracts_for(resource):
			var property_name := StringName(property_name_value)
			var contract := contract_for(resource, property_name)
			var record := {
				"resource": resource,
				"resource_type": resource.get_class(),
				"resource_path": resource.resource_path,
				"property": property_name,
				"contract": contract,
			}
			match int(contract.get("classification", Classification.UNSUPPORTED_ERROR)):
				Classification.EDITABLE:
					editable.append(record)
				Classification.READ_ONLY_JUSTIFIED:
					readonly.append(record)
				Classification.HIDDEN_JUSTIFIED:
					hidden.append(record)
				_:
					unsupported.append(record)
	return {
		"ok": unsupported.is_empty(),
		"editable": editable,
		"readonly": readonly,
		"hidden": hidden,
		"unsupported": unsupported,
		"resource_count": resources.size(),
		"property_count": editable.size() + readonly.size() + hidden.size() + unsupported.size(),
	}


static func _editor_type(info: Dictionary, value: Variant) -> String:
	var type := int(info.get("type", typeof(value)))
	var hint := int(info.get("hint", PROPERTY_HINT_NONE))
	var hint_string := str(info.get("hint_string", ""))
	if hint == PROPERTY_HINT_ENUM:
		return "enum"
	if hint == PROPERTY_HINT_FLAGS:
		return "flags"
	match type:
		TYPE_BOOL:
			return "boolean"
		TYPE_INT:
			return "integer"
		TYPE_FLOAT:
			if hint == PROPERTY_HINT_RANGE and _range_is_percentage(hint_string):
				return "percentage"
			return "float"
		TYPE_STRING:
			return "multiline_text" if hint == PROPERTY_HINT_MULTILINE_TEXT else "string"
		TYPE_STRING_NAME:
			return "string_name"
		TYPE_COLOR:
			return "color"
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I:
			return "vector"
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			return "ordered_resource_list" if _array_contains_resource(value) \
				or _array_hint_contains_resource(hint_string) else "typed_array"
		TYPE_DICTIONARY:
			return "structured_dictionary"
		TYPE_OBJECT:
			return "resource"
		TYPE_NIL:
			return "resource" if hint == PROPERTY_HINT_RESOURCE_TYPE else "unsupported"
		_:
			return "unsupported"


static func _array_contains_resource(value: Variant) -> bool:
	if not value is Array:
		return false
	for item in value:
		if item is Resource:
			return true
	return false


static func _array_hint_contains_resource(hint_string: String) -> bool:
	# Godot encode les tableaux typés de Resource sous la forme
	# "24/17:ClassName" (TYPE_OBJECT / PROPERTY_HINT_RESOURCE_TYPE).
	return hint_string.begins_with(str(TYPE_OBJECT) + "/") \
		or hint_string.contains(":Resource") \
		or hint_string.contains(":SpellModifier") \
		or hint_string.contains(":Spell") \
		or hint_string.contains(":Discipline") \
		or hint_string.contains(":Skill")


static func _range_is_percentage(hint_string: String) -> bool:
	var parts := hint_string.split(",")
	return parts.size() >= 2 and is_equal_approx(float(parts[0]), 0.0) \
		and is_equal_approx(float(parts[1]), 1.0)


static func _property_info(resource: Resource, property_name: StringName) -> Dictionary:
	for info_value in resource.get_property_list():
		var info := info_value as Dictionary
		if StringName(info.get("name", &"")) == property_name:
			return info
	return {}


static func _contract(
		property_name: StringName,
		classification: Classification,
		editor: String,
		reason: String,
		default_value: Variant,
		info: Dictionary
	) -> Dictionary:
	return {
		"property": property_name,
		"classification": classification,
		"classification_name": Classification.keys()[classification],
		"category": _category(property_name),
		"label_fr": str(LABELS_FR.get(property_name, str(property_name).replace("_", " ").capitalize())),
		"description": reason,
		"editor": editor,
		"constraints": {
			"hint": int(info.get("hint", PROPERTY_HINT_NONE)),
			"hint_string": str(info.get("hint_string", "")),
		},
		"unit": "%" if editor == "percentage" else "",
		"guided": property_name not in [&"script", &"resource_local_to_scene"],
		"advanced": true,
		"validator": "storage_contract",
		"default_value": default_value,
		"reason": reason,
	}


static func _unsupported(
		property_name: StringName,
		reason: String,
		info: Dictionary = {}
	) -> Dictionary:
	return _contract(
		property_name,
		Classification.UNSUPPORTED_ERROR,
		"unsupported",
		reason,
		null,
		info
	)


static func _category(property_name: StringName) -> String:
	var name := str(property_name)
	if "spell" in name or "modifier" in name:
		return "Sorts et effets"
	if "icon" in name or "visual" in name or "color" in name:
		return "Présentation"
	if "rank" in name or "xp" in name or "discipline" in name:
		return "Progression"
	return "Général"
