@tool
class_name ItemDeepCopyService
extends RefCounted


func duplicate_definition(source: ItemDefinition) -> ItemDefinition:
	if source == null:
		return null
	var copy := ItemDefinition.new()
	copy.item_id = source.item_id
	copy.display_name = source.display_name
	copy.description = source.description
	copy.icon = source.icon
	copy.inventory_icon = source.inventory_icon
	copy.card_texture = source.card_texture
	copy.rarity = source.rarity
	copy.tags = source.tags.duplicate()
	copy.reward_fx_profile = source.reward_fx_profile
	copy.reward_audio_profile = source.reward_audio_profile
	copy.category = source.category
	copy.stack_limit = source.stack_limit
	copy.equipment_slot = source.equipment_slot
	copy.compatible_character_ids = source.compatible_character_ids.duplicate()
	var stat_copies: Array[ItemStatModifierData] = []
	for modifier in source.stat_modifiers:
		stat_copies.append(_duplicate_resource(modifier) as ItemStatModifierData)
	copy.stat_modifiers = stat_copies
	var spell_copies: Array[SpellModifier] = []
	for modifier in source.spell_modifiers:
		spell_copies.append(_duplicate_resource(modifier) as SpellModifier)
	copy.spell_modifiers = spell_copies
	var reactive_copies: Array[ItemReactiveEffectData] = []
	for effect in source.reactive_effects:
		reactive_copies.append(_duplicate_resource(effect) as ItemReactiveEffectData)
	copy.reactive_effects = reactive_copies
	copy.use_effect = source.use_effect
	copy.use_value = source.use_value
	return copy


func duplicate_effect(source: Resource) -> Resource:
	return _duplicate_resource(source)


func mutable_sharing_audit(
		first: ItemDefinition,
		second: ItemDefinition
	) -> Dictionary:
	var first_resources := {}
	var second_resources := {}
	_collect_mutable_resources(first, "definition", first_resources, {})
	_collect_mutable_resources(second, "definition", second_resources, {})
	var shared: Array[Dictionary] = []
	for instance_id in first_resources:
		if second_resources.has(instance_id):
			shared.append({
				"instance_id": instance_id,
				"first_path": first_resources[instance_id],
				"second_path": second_resources[instance_id],
			})
	return {"valid": shared.is_empty(), "shared_mutable": shared}


func audit_catalog(definitions: Array[ItemDefinition]) -> Dictionary:
	var owners := {}
	var shared: Array[Dictionary] = []
	for definition in definitions:
		if definition == null:
			continue
		var resources := {}
		_collect_mutable_resources(definition, definition.resource_path, resources, {})
		for instance_id in resources:
			if owners.has(instance_id):
				shared.append({
					"instance_id": instance_id,
					"first": owners[instance_id],
					"second": resources[instance_id],
				})
			else:
				owners[instance_id] = resources[instance_id]
	return {"valid": shared.is_empty(), "shared_mutable": shared}


func _duplicate_resource(source: Resource, memo := {}) -> Resource:
	if source == null or _is_immutable_asset(source):
		return source
	var source_id := source.get_instance_id()
	if memo.has(source_id):
		return memo[source_id] as Resource
	var script := source.get_script() as Script
	var copy: Resource = script.new() as Resource if script != null else source.duplicate(false)
	if copy == null:
		return null
	memo[source_id] = copy
	for property_value in source.get_property_list():
		var property := property_value as Dictionary
		var property_name := str(property.get("name", ""))
		var usage := int(property.get("usage", 0))
		if property_name in ["resource_local_to_scene", "resource_name", "script"] \
				or not (usage & PROPERTY_USAGE_STORAGE):
			continue
		copy.set(property_name, _duplicate_variant(source.get(property_name), memo))
	return copy


func _duplicate_variant(value: Variant, memo: Dictionary) -> Variant:
	if value is Resource:
		return _duplicate_resource(value as Resource, memo)
	if value is Array:
		var source_array := value as Array
		var result := source_array.duplicate(false)
		for index in range(result.size()):
			result[index] = _duplicate_variant(source_array[index], memo)
		return result
	if value is Dictionary:
		var result := {}
		for key in (value as Dictionary).keys():
			result[_duplicate_variant(key, memo)] = _duplicate_variant(
				(value as Dictionary)[key], memo
			)
		return result
	return value


func _collect_mutable_resources(
		value: Variant,
		path: String,
		result: Dictionary,
		visited: Dictionary
	) -> void:
	if value is Resource:
		var resource := value as Resource
		if _is_immutable_asset(resource):
			return
		var instance_id := resource.get_instance_id()
		if visited.has(instance_id):
			return
		visited[instance_id] = true
		if not resource is ItemDefinition:
			result[instance_id] = path
		for property_value in resource.get_property_list():
			var property := property_value as Dictionary
			var property_name := str(property.get("name", ""))
			if property_name in ["resource_local_to_scene", "resource_name", "script"] \
					or not (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE):
				continue
			_collect_mutable_resources(
				resource.get(property_name), "%s.%s" % [path, property_name],
				result, visited
			)
	elif value is Array:
		var array := value as Array
		for index in range(array.size()):
			_collect_mutable_resources(array[index], "%s[%d]" % [path, index], result, visited)
	elif value is Dictionary:
		for key in (value as Dictionary).keys():
			_collect_mutable_resources((value as Dictionary)[key], "%s.%s" % [path, key], result, visited)


func _is_immutable_asset(resource: Resource) -> bool:
	return resource is Texture2D or resource is Script or resource is PackedScene \
		or resource is AudioStream or resource is Font or resource is Material \
		or resource is Mesh or resource is Shader
