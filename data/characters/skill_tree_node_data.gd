class_name SkillTreeNodeData
extends SkillUpgradeData

enum NodeType {
	LEGACY,
	ROOT,
	MASTERY,
	CAPSTONE,
	SPECIALIST_SUMMIT,
	MYTHIC_JUNCTION,
	APOTHEOSIS,
}

@export var prerequisite_node_ids: Array[StringName] = []
## En mode maitrise, au moins un de ces prerequis suffit. Le tableau historique
## prerequisite_node_ids conserve sa semantique ET.
@export var requires_any_node_ids: Array[StringName] = []
@export var excluded_node_ids: Array[StringName] = []
@export_range(0, 99, 1) var mastery_cost: int = 0
@export_range(1, 99, 1) var required_champion_level: int = 1
@export_range(0, 99, 1) var tier: int = 0
@export var node_type: NodeType = NodeType.LEGACY
@export var exclusive_group: StringName = &""
@export var doctrine_id: StringName = &""
@export var targeted_spell_modifiers: Array[TargetedSpellModifierData] = []
@export var reactive_effects: Array[MasteryReactiveEffectData] = []
@export var requires_completed_tree_ids: Array[StringName] = []
@export var doctrine_point_requirements: Array[DoctrinePointRequirementData] = []
@export var effect_axis: StringName = &""
@export var reaction_group: StringName = &""
@export var stackable: bool = true
@export_range(-1000, 1000, 1) var priority: int = 0
## Autorite explicite pour les outils, l'analyse et les tests. Les cibles des
## wrappers typés ci-dessus restent la source runtime.
@export var affected_spell_ids: Array[StringName] = []


func get_node_id() -> StringName:
	return upgrade_id


func is_champion_mastery() -> bool:
	return mastery_cost > 0 and doctrine_id != &"" \
		and node_type != NodeType.LEGACY


func get_spell_modifiers() -> Array[SpellModifier]:
	var result := super.get_spell_modifiers()
	for targeted in targeted_spell_modifiers:
		if targeted == null:
			continue
		for modifier in targeted.get_modifiers_for_spell():
			if modifier != null and not result.has(modifier):
				result.append(modifier)
	return result


func get_targeted_spell_modifier_map() -> Dictionary:
	var result := {}
	for targeted in targeted_spell_modifiers:
		if targeted == null or targeted.spell_id == &"":
			continue
		var bucket: Array[SpellModifier] = []
		bucket.assign(result.get(targeted.spell_id, []))
		for modifier in targeted.get_modifiers_for_spell():
			if modifier != null and not bucket.has(modifier):
				bucket.append(modifier)
		result[targeted.spell_id] = bucket
	return result


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_champion_mastery():
		return errors
	if mastery_cost <= 0:
		errors.append("MASTERY_COST_INVALID: %s" % upgrade_id)
	if tier <= 0:
		errors.append("MASTERY_TIER_INVALID: %s" % upgrade_id)
	if effect_axis == &"":
		errors.append("MASTERY_EFFECT_AXIS_EMPTY: %s" % upgrade_id)
	for targeted in targeted_spell_modifiers:
		if targeted == null:
			errors.append("MASTERY_TARGETED_MODIFIER_NULL: %s" % upgrade_id)
		else:
			for message in targeted.validation_errors():
				errors.append("%s: %s" % [upgrade_id, message])
	for effect in reactive_effects:
		if effect == null:
			errors.append("MASTERY_REACTIVE_EFFECT_NULL: %s" % upgrade_id)
		else:
			for message in effect.structural_errors():
				errors.append("%s: %s" % [upgrade_id, message])
	for requirement in doctrine_point_requirements:
		if requirement == null or not requirement.is_valid():
			errors.append("MASTERY_DOCTRINE_REQUIREMENT_INVALID: %s" % upgrade_id)
	return errors
