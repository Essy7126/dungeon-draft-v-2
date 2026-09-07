@tool
class_name SkillTreeMasteryAuthoringService
extends RefCounted


const CANONICAL_ALLOCATIONS := {
	&"opening_specialist": [9, 0, 0],
	&"opening_hybrid": [6, 3, 0],
	&"balanced_hybrid": [5, 4, 0],
	&"double_capstone": [6, 6, 0],
	&"specialist_13": [13, 0, 0],
	&"hybrid_14": [8, 6, 0],
	&"specialist_14": [14, 0, 0],
}


static func catalog_sheet(catalog: MasteryCatalogData) -> Dictionary:
	if catalog == null:
		return {"valid": false, "errors": PackedStringArray(["Catalogue absent."])}
	var doctrines: Array[Dictionary] = []
	for doctrine in catalog.doctrines:
		doctrines.append(_doctrine_sheet(doctrine))
	return {
		"catalog_id": catalog.catalog_id,
		"valid": catalog.validation_errors().is_empty(),
		"errors": catalog.validation_errors(),
		"doctrine_count": catalog.doctrines.size(),
		"doctrines": doctrines,
		"advanced_nodes": catalog.get_advanced_nodes().map(_node_sheet),
		"canonical_allocations": CANONICAL_ALLOCATIONS.duplicate(true),
	}


static func capstone_paths(
		doctrine: DisciplineData,
		champion_level: int
	) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for path_value in SkillTreeResolver.champion_capstone_paths(doctrine, champion_level):
		var ids: Array[StringName] = []
		ids.assign(path_value)
		rows.append({
			"node_ids": ids,
			"cost": _selected_cost(doctrine, ids),
			"exact": true,
		})
	return rows


static func allocation_scenario(
		catalog: MasteryCatalogData,
		allocation: PackedInt32Array
	) -> Dictionary:
	if catalog == null or allocation.size() != catalog.doctrines.size():
		return {"supported": false, "reason": "Allocation et doctrines non parallèles."}
	var per_doctrine: Array[Dictionary] = []
	for index in range(allocation.size()):
		var doctrine := catalog.doctrines[index]
		var points := allocation[index]
		var minimum := SkillTreeResolver.minimal_champion_capstone_cost(doctrine)
		per_doctrine.append({
			"doctrine_id": doctrine.discipline_id if doctrine != null else &"",
			"points": points,
			"reaches_capstone_budget": minimum >= 0 and points >= minimum,
			"minimum_capstone_cost": minimum,
			"full_tree_cost": SkillTreeResolver.full_champion_doctrine_cost(doctrine),
		})
	return {
		"supported": _allocation_is_non_negative(allocation),
		"total_points": Array(allocation).reduce(func(total, value): return total + value, 0),
		"per_doctrine": per_doctrine,
		"exact_purchase_set": false,
		"note": "Une allocation de points décrit un budget, pas un chemin unique.",
	}


## Analyse volontairement conservatrice : deux nœuds conditionnels, réactifs
## ou portant des axes différents ne sont jamais déclarés dominants.
static func compare_siblings(
		first: SkillTreeNodeData,
		second: SkillTreeNodeData
	) -> Dictionary:
	if first == null or second == null:
		return {"status": &"INCOMPARABLE", "reason": "Sélection incomplète."}
	if first.doctrine_id != second.doctrine_id or first.tier != second.tier:
		return {"status": &"INCOMPARABLE", "reason": "Doctrine ou palier différent."}
	var conditional := not first.reactive_effects.is_empty() \
		or not second.reactive_effects.is_empty() \
		or not first.prerequisite_node_ids.is_empty() \
		or not second.prerequisite_node_ids.is_empty() \
		or not first.requires_any_node_ids.is_empty() \
		or not second.requires_any_node_ids.is_empty()
	return {
		"status": &"PARTIAL",
		"dominant_node_id": &"",
		"conditional": conditional,
		"first_axis": first.effect_axis,
		"second_axis": second.effect_axis,
		"reason": "Effets typés et contextuels : aucune dominance stricte n’est affirmée.",
	}


static func _doctrine_sheet(doctrine: DisciplineData) -> Dictionary:
	if doctrine == null:
		return {}
	var nodes := SkillTreeResolver.champion_doctrine_nodes(doctrine)
	return {
		"doctrine_id": doctrine.discipline_id,
		"display_name": doctrine.display_name,
		"progression_mode": DisciplineData.ProgressionMode.keys()[doctrine.progression_mode],
		"nodes": nodes.map(_node_sheet),
		"minimum_capstone_cost": SkillTreeResolver.minimal_champion_capstone_cost(doctrine),
		"full_tree_cost": SkillTreeResolver.full_champion_doctrine_cost(doctrine),
		"capstone_paths_level_10": capstone_paths(doctrine, 10),
		"capstone_paths_level_14": capstone_paths(doctrine, 14),
	}


static func _node_sheet(node: SkillTreeNodeData) -> Dictionary:
	if node == null:
		return {}
	var targets: Array[Dictionary] = []
	for targeted in node.targeted_spell_modifiers:
		if targeted != null:
			targets.append({
				"spell_id": targeted.spell_id,
				"modifier_count": targeted.modifiers.size(),
			})
	var reactives: Array[Dictionary] = []
	for effect in node.reactive_effects:
		if effect != null:
			reactives.append({
				"effect_id": effect.effect_id,
				"event_id": effect.event_id,
				"scope": MasteryReactiveEffectData.Scope.keys()[effect.scope],
				"frequency": MasteryReactiveEffectData.Frequency.keys()[effect.frequency],
				"reaction_group": effect.reaction_group,
				"stackable": effect.stackable,
				"priority": effect.priority,
				"valid_spell_ids": effect.valid_spell_ids.duplicate(),
			})
	return {
		"node_id": node.upgrade_id,
		"doctrine_id": node.doctrine_id,
		"tier": node.tier,
		"node_type": SkillTreeNodeData.NodeType.keys()[node.node_type],
		"mastery_cost": node.mastery_cost,
		"required_champion_level": node.required_champion_level,
		"prerequisite_node_ids": node.prerequisite_node_ids.duplicate(),
		"requires_any_node_ids": node.requires_any_node_ids.duplicate(),
		"excluded_node_ids": node.excluded_node_ids.duplicate(),
		"requires_completed_tree_ids": node.requires_completed_tree_ids.duplicate(),
		"effect_axis": node.effect_axis,
		"affected_spell_ids": node.affected_spell_ids.duplicate(),
		"targeted_spell_modifiers": targets,
		"reactive_effects": reactives,
	}


static func _selected_cost(
		doctrine: DisciplineData,
		selected_ids: Array[StringName]
	) -> int:
	return SkillTreeResolver.champion_doctrine_selected_cost(doctrine, selected_ids)


static func _allocation_is_non_negative(allocation: PackedInt32Array) -> bool:
	for value in allocation:
		if value < 0:
			return false
	return true
