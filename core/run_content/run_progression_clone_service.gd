@tool
class_name RunProgressionCloneService
extends RefCounted

const SKIPPED_PROPERTIES: Array[StringName] = [
	&"script", &"resource_name", &"resource_path", &"resource_local_to_scene",
]


static func clone_from_unit(
		base_unit_data: UnitData,
		run_id: StringName,
		destination_path: String = ""
	) -> RunProgressionCloneResult:
	if base_unit_data == null:
		var invalid := RunProgressionCloneResult.new()
		invalid.errors.append("Le UnitData source est absent.")
		return invalid
	var source := CharacterProgressionProfile.new()
	source.character_id = base_unit_data.get_effective_unit_id()
	source.active_spell_slots = base_unit_data.active_spell_slots
	source.spells.assign(base_unit_data.spells)
	return clone_profile(source, run_id, destination_path)


static func clone_profile(
		source: CharacterProgressionProfile,
		run_id: StringName,
		destination_path: String = ""
	) -> RunProgressionCloneResult:
	var result := RunProgressionCloneResult.new()
	if source == null:
		result.errors.append("Le CharacterProgressionProfile source est absent.")
		return result
	result.errors.append_array(source.validation_errors())
	if not result.errors.is_empty():
		return result

	# Passe 1 : inventaire deterministe du graphe mutable.
	var inventoried := {}
	for spell in source.spells:
		_inventory_value(spell, inventoried, result.resources, result.allowed_shared_resources)

	# Passe 2 : creation des clones, sans raccorder leurs relations.
	for resource in result.resources:
		var clone := resource.duplicate(false) as Resource
		if clone == null:
			result.errors.append("Impossible de cloner %s." % _resource_label(resource))
			continue
		clone.set_path_cache("")
		result.source_to_clone[resource] = clone
		result.clone_to_source[clone] = resource
	if not result.errors.is_empty():
		return result

	# Passes 3 et 4 : remappage explicite de toutes les proprietes de stockage.
	for resource in result.resources:
		var clone := result.source_to_clone.get(resource) as Resource
		for property in _storage_properties(resource):
			var property_name := StringName(property.get("name", &""))
			clone.set(property_name, _remap_value(resource.get(property_name), result.source_to_clone))

	# Passe 5 : racines du document, sans dupliquer les donnees de base du heros.
	var profile := CharacterProgressionProfile.new()
	profile.character_id = source.character_id
	profile.active_spell_slots = source.active_spell_slots
	for spell in source.spells:
		profile.spells.append(result.source_to_clone.get(spell) as Spell)
	result.profile = profile
	result.errors.append_array(profile.validation_errors())
	result.manifest = _build_manifest(source, result, run_id, destination_path)
	return result


static func save_reload_and_compare(
		result: RunProgressionCloneResult,
		destination_path: String
	) -> Dictionary:
	var report := {
		"ok": false,
		"path": destination_path,
		"before_fingerprint": "",
		"after_fingerprint": "",
		"errors": PackedStringArray(),
		"reloaded": null,
	}
	if result == null or not result.is_valid():
		report.errors.append("Le resultat de clonage est invalide.")
		return report
	if destination_path.is_empty():
		report.errors.append("Le chemin de destination est absent.")
		return report
	var base_dir := destination_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(base_dir)):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
		if mkdir_error != OK:
			report.errors.append("Impossible de creer %s (erreur %d)." % [base_dir, mkdir_error])
			return report
	report.before_fingerprint = semantic_fingerprint(result.profile)
	var save_error := ResourceSaver.save(result.profile, destination_path)
	if save_error != OK:
		report.errors.append("Echec de sauvegarde %s (erreur %d)." % [destination_path, save_error])
		return report
	var reloaded := ResourceLoader.load(
		destination_path, "CharacterProgressionProfile", ResourceLoader.CACHE_MODE_REPLACE
	) as CharacterProgressionProfile
	if reloaded == null:
		report.errors.append("Le profil sauvegarde ne peut pas etre recharge.")
		return report
	report.reloaded = reloaded
	report.after_fingerprint = semantic_fingerprint(reloaded)
	report.ok = report.before_fingerprint == report.after_fingerprint
	if not report.ok:
		report.errors.append("Le fingerprint differe apres rechargement.")
	return report


static func semantic_fingerprint(resource: Resource) -> String:
	var visited := {}
	return JSON.stringify(_encode_semantic(resource, visited)).sha256_text()


static func progression_resources(profile: CharacterProgressionProfile) -> Array[Resource]:
	var resources: Array[Resource] = []
	if profile == null:
		return resources
	resources.append(profile)
	var inventoried := {profile: true}
	var allowed: Array[Resource] = []
	for spell in profile.spells:
		_inventory_value(spell, inventoried, resources, allowed)
	return resources


static func shared_assets(profile: CharacterProgressionProfile) -> Array[Resource]:
	var resources: Array[Resource] = []
	if profile == null:
		return resources
	var inventoried := {}
	var mutable: Array[Resource] = []
	for spell in profile.spells:
		_inventory_value(spell, inventoried, mutable, resources)
	return resources


static func is_shareable(resource: Resource) -> bool:
	return resource is UnitData \
		or resource is Texture2D \
		or resource is SpriteFrames \
		or resource is PackedScene \
		or resource is AudioStream \
		or resource is Font \
		or resource is Material \
		or resource is Mesh \
		or resource is Shader \
		or resource is Script


static func resource_type_name(resource: Resource) -> String:
	return _resource_type(resource) if resource != null else ""


static func _inventory_value(
		value: Variant,
		inventoried: Dictionary,
		mutable_resources: Array[Resource],
		allowed_resources: Array[Resource]
	) -> void:
	if value is Resource:
		var resource := value as Resource
		if is_shareable(resource):
			if not allowed_resources.has(resource):
				allowed_resources.append(resource)
			return
		if inventoried.has(resource):
			return
		inventoried[resource] = true
		mutable_resources.append(resource)
		for property in _storage_properties(resource):
			_inventory_value(
				resource.get(StringName(property.get("name", &""))),
				inventoried,
				mutable_resources,
				allowed_resources,
			)
		return
	if value is Array:
		for item in value:
			_inventory_value(item, inventoried, mutable_resources, allowed_resources)
	elif value is Dictionary:
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key in keys:
			_inventory_value(key, inventoried, mutable_resources, allowed_resources)
			_inventory_value(value[key], inventoried, mutable_resources, allowed_resources)


static func _remap_value(value: Variant, mapping: Dictionary) -> Variant:
	if value is Resource:
		return mapping.get(value, value)
	if value is Array:
		var array_copy: Array = (value as Array).duplicate()
		for index in range(array_copy.size()):
			array_copy[index] = _remap_value(array_copy[index], mapping)
		return array_copy
	if value is Dictionary:
		var dictionary_copy := {}
		for key in value:
			dictionary_copy[_remap_value(key, mapping)] = _remap_value(value[key], mapping)
		return dictionary_copy
	return value


static func _storage_properties(resource: Resource) -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	for property in resource.get_property_list():
		var property_name := StringName(property.get("name", &""))
		if property_name in SKIPPED_PROPERTIES:
			continue
		if int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE == 0:
			continue
		properties.append(property)
	properties.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return properties


static func _build_manifest(
		source: CharacterProgressionProfile,
		result: RunProgressionCloneResult,
		run_id: StringName,
		destination_path: String
	) -> Dictionary:
	var counts := {}
	var mapping_rows: Array[Dictionary] = []
	for index in range(result.resources.size()):
		var resource := result.resources[index]
		var type_name := _resource_type(resource)
		counts[type_name] = int(counts.get(type_name, 0)) + 1
		mapping_rows.append({
			"index": index,
			"type": type_name,
			"stable_id": _stable_id(resource),
			"source_path": resource.resource_path,
			"clone_owner": destination_path,
		})
	var allowed_rows: Array[Dictionary] = []
	for resource in result.allowed_shared_resources:
		allowed_rows.append({
			"type": _resource_type(resource),
			"path": resource.resource_path,
		})
	allowed_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("path", "")) < str(b.get("path", ""))
	)
	return {
		"schema_version": 1,
		"run_id": str(run_id),
		"character_id": str(source.character_id),
		"destination_path": destination_path,
		"resource_counts": counts,
		"mapping": mapping_rows,
		"allowed_shared_resources": allowed_rows,
		"forbidden_shared_resources": [],
		"source_fingerprint": semantic_fingerprint(source),
		"clone_fingerprint": semantic_fingerprint(result.profile),
		"verdict": "VALID" if result.errors.is_empty() else "INVALID",
	}


static func _encode_semantic(value: Variant, visited: Dictionary) -> Variant:
	if value is Resource:
		var resource := value as Resource
		if is_shareable(resource):
			return {"shared_type": _resource_type(resource), "path": resource.resource_path}
		var instance_id := resource.get_instance_id()
		if visited.has(instance_id):
			return {"reference": visited[instance_id]}
		var reference_index := visited.size()
		visited[instance_id] = reference_index
		var properties := {}
		for property in _storage_properties(resource):
			var property_name := StringName(property.get("name", &""))
			properties[str(property_name)] = _encode_semantic(resource.get(property_name), visited)
		return {
			"reference_index": reference_index,
			"type": _resource_type(resource),
			"properties": properties,
		}
	if value is Array:
		var encoded_array: Array = []
		for item in value:
			encoded_array.append(_encode_semantic(item, visited))
		return encoded_array
	if value is Dictionary:
		var encoded_dictionary := {}
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key in keys:
			encoded_dictionary[str(key)] = _encode_semantic(value[key], visited)
		return encoded_dictionary
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return str(value)
		_:
			return var_to_str(value)


static func _resource_type(resource: Resource) -> String:
	var script := resource.get_script() as Script
	if script != null and not script.get_global_name().is_empty():
		return script.get_global_name()
	return resource.get_class()


static func _stable_id(resource: Resource) -> String:
	if resource is Spell:
		return str((resource as Spell).get_effective_spell_id())
	if resource is DisciplineData:
		return str((resource as DisciplineData).discipline_id)
	if resource is DisciplineRankData:
		return str((resource as DisciplineRankData).rank)
	if resource is SkillUpgradeData:
		return str((resource as SkillUpgradeData).upgrade_id)
	if resource is StatusData:
		return str((resource as StatusData).get_effective_status_id())
	if resource is TerrainEffectData:
		return (resource as TerrainEffectData).effect_name
	if resource is SpellModifier:
		return (resource as SpellModifier).modifier_name
	return ""


static func _resource_label(resource: Resource) -> String:
	return "%s(%s)" % [_resource_type(resource), _stable_id(resource)]
