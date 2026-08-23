@tool
class_name SkillTreeReferenceIndex
extends RefCounted

var root: UnitData = null
var resources: Array[Resource] = []
var references: Array[Dictionary] = []
var resources_by_path := {}
var resources_by_key := {}
var ids := {
	"unit": {},
	"discipline": {},
	"node": {},
	"spell": {},
}
var orphan_records: Array[Dictionary] = []


static func project_id_exists(
		heroes: Array[Dictionary], kind: String, value: StringName,
		excluded_character_path := ""
	) -> bool:
	for hero_entry in heroes:
		if str(hero_entry.get("path", "")) == excluded_character_path:
			continue
		var units: Array[UnitData] = []
		var base := hero_entry.get(
			"unit_resource", hero_entry.get("resource")
		) as UnitData
		for authority_value in hero_entry.get("profile_authorities", []):
			var authority := authority_value as Dictionary
			var view := RunContentCatalogService.as_editable_unit_view(
				base,
				authority.get("progression_profile") as CharacterProgressionProfile
			)
			if view != null:
				units.append(view)
		if units.is_empty() and hero_entry.get("resource") is UnitData:
			units.append(hero_entry.get("resource") as UnitData)
		for unit in units:
			if SkillTreeReferenceIndex.new().build(unit).id_exists(kind, value):
				return true
	return false


func build(unit: UnitData, candidates: Array[Resource] = []) -> SkillTreeReferenceIndex:
	root = unit
	resources.clear()
	references.clear()
	resources_by_path.clear()
	orphan_records.clear()
	for table in ids.values():
		(table as Dictionary).clear()
	resources_by_key = SkillTreeCopyService.resources_by_key(unit)
	if unit == null:
		return self
	_register_resource(unit, "unit")
	_register_id("unit", unit.get_effective_unit_id(), unit)
	if unit.animation_set != null:
		_register_reference(unit, &"animation_set", unit.animation_set, "RESOURCE")
		_register_resource(unit.animation_set, "animations")
	for spell in unit.spells:
		if spell == null:
			continue
		_register_reference(unit, &"spells", spell, "RESOURCE")
		_register_resource(spell, "spell")
		_register_id("spell", spell.get_effective_spell_id(), spell)
		if spell.skill_tree != null:
			_register_reference(spell, &"skill_tree", spell.skill_tree, "RESOURCE")
		for modifier in spell.modifiers:
			if modifier == null:
				continue
			_register_reference(spell, &"modifiers", modifier, "RESOURCE")
			_register_modifier(modifier)
	for discipline in unit.disciplines:
		if discipline == null:
			continue
		_register_resource(discipline, "discipline")
		_register_id("discipline", discipline.discipline_id, discipline)
		for rank_data in discipline.ranks:
			if rank_data == null:
				continue
			_register_reference(discipline, &"ranks", rank_data, "RESOURCE")
			_register_resource(rank_data, "rank")
			for node in rank_data.choices:
				if node == null:
					continue
				_register_reference(rank_data, &"choices", node, "RESOURCE")
				_register_resource(node, "node")
				_register_id("node", node.upgrade_id, node)
				_register_id_reference(node, &"discipline_id", "discipline", node.discipline_id)
				_register_id_reference(node, &"target_spell_id", "spell", node.target_spell_id)
				if node is SkillTreeNodeData:
					for prerequisite_id in node.prerequisite_node_ids:
						_register_id_reference(
							node, &"prerequisite_node_ids", "node", prerequisite_id
						)
					for excluded_id in node.excluded_node_ids:
						_register_id_reference(
							node, &"excluded_node_ids", "node", excluded_id
						)
				for modifier in node.spell_modifiers:
					if modifier == null:
						continue
					_register_reference(node, &"spell_modifiers", modifier, "RESOURCE")
					_register_modifier(modifier)
	var reachable := {}
	for resource in resources:
		reachable[resource] = true
	for candidate in candidates:
		if candidate == null or reachable.has(candidate):
			continue
		orphan_records.append({
			"resource": candidate,
			"type": _resource_type_name(candidate),
			"path": candidate.resource_path,
			"last_owner": _last_owner_for(candidate),
			"reason": "La Resource n'est plus atteignable depuis le personnage.",
			"incoming_references": incoming_to_resource(candidate),
			"actions": ["ADOPT", "ARCHIVE", "DELETE"],
		})
	return self


func incoming_to_resource(target: Resource) -> Array[Dictionary]:
	return references.filter(func(reference: Dictionary) -> bool:
		return reference.get("target") == target
	)


func incoming_to_id(kind: String, value: StringName) -> Array[Dictionary]:
	return references.filter(func(reference: Dictionary) -> bool:
		return str(reference.get("kind", "")) == "ID" \
			and str(reference.get("id_kind", "")) == kind \
			and StringName(reference.get("value", &"")) == value
	)


func id_exists(kind: String, value: StringName) -> bool:
	return (ids.get(kind, {}) as Dictionary).has(value)


func can_delete(target: Resource) -> Dictionary:
	var incoming := incoming_to_resource(target)
	return {
		"allowed": incoming.is_empty(),
		"incoming_references": incoming,
		"count": incoming.size(),
	}


func impact_report(kind: String, value: StringName) -> Dictionary:
	var incoming := incoming_to_id(kind, value)
	var by_property := {}
	for reference in incoming:
		var property_name := str(reference.get("property", ""))
		by_property[property_name] = int(by_property.get(property_name, 0)) + 1
	return {
		"kind": kind,
		"id": value,
		"reference_count": incoming.size(),
		"by_property": by_property,
		"references": incoming,
	}


func orphaned_resources() -> Array[Dictionary]:
	return orphan_records.duplicate(true)


func shared_resources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for resource in resources:
		var incoming := incoming_to_resource(resource)
		if incoming.size() > 1:
			result.append({
				"resource": resource,
				"path": resource.resource_path,
				"owner_count": incoming.size(),
				"incoming_references": incoming,
			})
	return result


func _register_modifier(modifier: SpellModifier) -> void:
	_register_resource(modifier, "modifier")
	_register_id_reference(
		modifier, &"target_spell_id", "spell", modifier.target_spell_id
	)


func _register_resource(resource: Resource, logical_type: String) -> void:
	if resource == null:
		return
	if not resources.has(resource):
		resources.append(resource)
	if not resource.resource_path.is_empty():
		resources_by_path[resource.resource_path] = resource
	if not resources_by_key.values().has(resource):
		resources_by_key["%s:%d" % [logical_type, resource.get_instance_id()]] = resource


func _register_id(kind: String, value: StringName, resource: Resource) -> void:
	if value == &"":
		return
	var table := ids.get(kind, {}) as Dictionary
	var owners: Array = table.get(value, [])
	owners.append(resource)
	table[value] = owners


func _register_reference(
		owner: Resource,
		property_name: StringName,
		target: Resource,
		kind: String
	) -> void:
	references.append({
		"owner": owner,
		"property": property_name,
		"target": target,
		"kind": kind,
	})


func _register_id_reference(
		owner: Resource,
		property_name: StringName,
		id_kind: String,
		value: StringName
	) -> void:
	if value == &"":
		return
	references.append({
		"owner": owner,
		"property": property_name,
		"target": null,
		"kind": "ID",
		"id_kind": id_kind,
		"value": value,
	})


func _last_owner_for(target: Resource) -> String:
	for reference in references:
		if reference.get("target") == target:
			var owner := reference.get("owner") as Resource
			return owner.resource_path if owner != null else ""
	return ""


static func _resource_type_name(resource: Resource) -> String:
	var script := resource.get_script() as Script if resource != null else null
	if script != null and not script.get_global_name().is_empty():
		return script.get_global_name()
	return resource.get_class() if resource != null else "Resource"
