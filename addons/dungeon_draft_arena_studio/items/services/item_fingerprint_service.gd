@tool
class_name ItemFingerprintService
extends RefCounted

const TRANSIENT_RESOURCE_PROPERTIES := {
	"resource_local_to_scene": true,
	"resource_name": true,
	"resource_path": true,
	"script": true,
}


static func semantic_snapshot(definition: ItemDefinition) -> Dictionary:
	if definition == null:
		return {}
	var stat_snapshots: Array[Dictionary] = []
	for modifier in definition.stat_modifiers:
		stat_snapshots.append(_resource_snapshot(modifier))
	var spell_snapshots: Array[Dictionary] = []
	for modifier in definition.spell_modifiers:
		spell_snapshots.append(_resource_snapshot(modifier))
	var reactive_snapshots: Array[Dictionary] = []
	for effect in definition.reactive_effects:
		reactive_snapshots.append(_resource_snapshot(effect))
	return {
		"item_id": str(definition.item_id),
		"display_name": definition.display_name,
		"description": definition.description,
		"icon": _asset_path(definition.icon),
		"inventory_icon": _asset_path(definition.inventory_icon),
		"card_texture": _asset_path(definition.card_texture),
		"rarity": str(definition.rarity),
		"tags": _string_array(definition.tags),
		"reward_fx_profile": str(definition.reward_fx_profile),
		"reward_audio_profile": str(definition.reward_audio_profile),
		"category": int(definition.category),
		"stack_limit": definition.stack_limit,
		"equipment_slot": int(definition.equipment_slot),
		"compatible_character_ids": _string_array(
			definition.compatible_character_ids
		),
		"guard_effectiveness_melee": definition.guard_effectiveness_melee,
		"guard_effectiveness_projectile": definition.guard_effectiveness_projectile,
		"stat_modifiers": stat_snapshots,
		"spell_modifiers": spell_snapshots,
		"reactive_effects": reactive_snapshots,
		"use_effect": int(definition.use_effect),
		"use_value": definition.use_value,
	}


static func semantic_fingerprint(definition: ItemDefinition) -> String:
	return JSON.stringify(semantic_snapshot(definition)).sha256_text()


static func catalog_fingerprint(definitions: Array[ItemDefinition]) -> String:
	var entries: Array[Dictionary] = []
	for definition in definitions:
		entries.append({
			"path": definition.resource_path if definition != null else "",
			"snapshot": semantic_snapshot(definition),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("path", "")) < str(b.get("path", ""))
	)
	return JSON.stringify(entries).sha256_text()


static func _resource_snapshot(resource: Resource) -> Dictionary:
	if resource == null:
		return {"null": true}
	var script := resource.get_script() as Script
	var values := {}
	for property_value in resource.get_property_list():
		var property := property_value as Dictionary
		var property_name := str(property.get("name", ""))
		var usage := int(property.get("usage", 0))
		if property_name.is_empty() \
				or TRANSIENT_RESOURCE_PROPERTIES.has(property_name) \
				or not (usage & PROPERTY_USAGE_STORAGE):
			continue
		values[property_name] = _variant_snapshot(resource.get(property_name))
	return {
		"class": resource.get_class(),
		"script_path": script.resource_path if script != null else "",
		"properties": _sorted_dictionary(values),
	}


static func _variant_snapshot(value: Variant) -> Variant:
	if value is StringName:
		return str(value)
	if value is Resource:
		var resource := value as Resource
		if resource is Texture2D or resource is Script or resource is PackedScene \
				or resource is AudioStream or resource is Material \
				or resource is Mesh or resource is Font:
			return {"asset": _asset_path(resource), "class": resource.get_class()}
		return _resource_snapshot(resource)
	if value is Array:
		var result: Array = []
		for entry in value as Array:
			result.append(_variant_snapshot(entry))
		return result
	if value is Dictionary:
		var result := {}
		for key in (value as Dictionary).keys():
			result[str(key)] = _variant_snapshot((value as Dictionary)[key])
		return _sorted_dictionary(result)
	if value is Vector2 or value is Vector2i or value is Vector3 \
			or value is Vector3i or value is Color or value is Rect2 \
			or value is Transform2D or value is Transform3D:
		return var_to_str(value)
	return value


static func _sorted_dictionary(source: Dictionary) -> Dictionary:
	var keys: Array = source.keys()
	keys.sort_custom(func(a, b): return str(a) < str(b))
	var result := {}
	for key in keys:
		result[key] = source[key]
	return result


static func _asset_path(resource: Resource) -> String:
	return resource.resource_path if resource != null else ""


static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
