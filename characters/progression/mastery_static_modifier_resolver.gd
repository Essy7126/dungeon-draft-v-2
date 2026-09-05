class_name MasteryStaticModifierResolver
extends RefCounted

## Autorite commune aux aperçus et a l'integration runtime. Le resolver ne
## connait ni personnage ni node : il ne lit que des transformations typées.
static func resolve_spell_profile(
		spell: Spell,
		nodes: Array[SkillTreeNodeData]
	) -> Dictionary:
	if spell == null:
		return {}
	var profile := {
		"spell_id": spell.get_effective_spell_id(),
		"minimum_range": spell.minimum_range,
		"maximum_range": spell.spell_range,
		"damage_multiplier": 1.0,
		"shield_multiplier": 1.0,
		"push_distance": spell.push_distance,
		"ignore_armor_flat": 0,
		"maximum_targets": 1,
		"target_shape": &"SINGLE",
		"target_multipliers": PackedFloat32Array([1.0]),
		"piercing_enabled": false,
		"ignore_engagement_points": 0,
		"guard_armor": 0,
		"push_immunity": false,
		"pull_immunity": false,
		"conditional_bonus_scale": 1.0,
		"movement_threshold_delta": 0,
		"movement_threshold_minimum": 0,
		"sources": [],
	}
	for node in nodes:
		if node == null:
			continue
		for targeted in node.targeted_spell_modifiers:
			if targeted == null or targeted.spell_id != spell.get_effective_spell_id():
				continue
			for modifier in targeted.modifiers:
				if modifier != null:
					_apply_modifier(profile, modifier, node.upgrade_id)
	return profile


## Static damage for one ordered target, before situational effects and defenses.
## Shares the same single rounding step between combat and factual previews.
static func resolve_target_damage(
		base_damage: int,
		profile: Dictionary,
		target_index: int = 0
	) -> int:
	var coefficients: PackedFloat32Array = profile.get("target_multipliers", PackedFloat32Array([1.0]))
	var coefficient := float(coefficients[mini(target_index, coefficients.size() - 1)]) if not coefficients.is_empty() else 1.0
	return int(round(base_damage * float(profile.get("damage_multiplier", 1.0)) * coefficient))


## Guard creation rounds the mastery-adjusted amount before creation bonuses.
## Combat uses the default multiplier here; Unit applies creation bonuses later.
static func resolve_shield_amount(
		base_shield: int,
		profile: Dictionary,
		creation_multiplier: float = 1.0
	) -> int:
	var adjusted := int(round(base_shield * float(profile.get("shield_multiplier", 1.0))))
	return int(round(adjusted * creation_multiplier))


static func modifiers_by_spell(
		nodes: Array[SkillTreeNodeData]
	) -> Dictionary:
	var result := {}
	for node in nodes:
		if node == null:
			continue
		for spell_id_value in node.get_targeted_spell_modifier_map():
			var spell_id := StringName(spell_id_value)
			var bucket: Array[SpellModifier] = []
			bucket.assign(result.get(spell_id, []))
			for modifier in node.get_targeted_spell_modifier_map()[spell_id_value]:
				if modifier != null and not bucket.has(modifier):
					bucket.append(modifier)
			result[spell_id] = bucket
	return result


static func _apply_modifier(
		profile: Dictionary,
		modifier: MasterySpellModifierData,
		source_id: StringName
	) -> void:
	match modifier.effect_type:
		MasterySpellModifierData.EffectType.DAMAGE_MULTIPLIER:
			profile.damage_multiplier *= modifier.multiplier
		MasterySpellModifierData.EffectType.SHIELD_MULTIPLIER:
			profile.shield_multiplier *= modifier.multiplier
		MasterySpellModifierData.EffectType.RANGE_DELTA:
			profile.maximum_range = int(profile.maximum_range) + modifier.flat_value
		MasterySpellModifierData.EffectType.RANGE_BOUNDS:
			profile.minimum_range = modifier.minimum_range
			profile.maximum_range = modifier.maximum_range
		MasterySpellModifierData.EffectType.PUSH_DISTANCE:
			profile.push_distance = modifier.flat_value
		MasterySpellModifierData.EffectType.IGNORE_ARMOR_FLAT:
			profile.ignore_armor_flat = int(profile.ignore_armor_flat) + modifier.flat_value
		MasterySpellModifierData.EffectType.LINE_TARGETS:
			profile.target_shape = &"LINE"
			profile.maximum_targets = modifier.maximum_targets
			profile.target_multipliers = modifier.target_multipliers.duplicate()
		MasterySpellModifierData.EffectType.FAN_TARGETS:
			profile.target_shape = &"FAN"
			profile.maximum_targets = modifier.maximum_targets
			profile.target_multipliers = modifier.target_multipliers.duplicate()
		MasterySpellModifierData.EffectType.PIERCING_ENABLED:
			profile.piercing_enabled = modifier.enabled_value
		MasterySpellModifierData.EffectType.ENGAGEMENT_PENALTY_IGNORE:
			profile.ignore_engagement_points = int(profile.ignore_engagement_points) \
				+ modifier.flat_value
		MasterySpellModifierData.EffectType.GUARD_ARMOR:
			profile.guard_armor = int(profile.guard_armor) + modifier.flat_value
		MasterySpellModifierData.EffectType.PUSH_IMMUNITY:
			profile.push_immunity = modifier.enabled_value
		MasterySpellModifierData.EffectType.PULL_IMMUNITY:
			profile.pull_immunity = modifier.enabled_value
		MasterySpellModifierData.EffectType.CONDITIONAL_BONUS_SCALE:
			profile.conditional_bonus_scale *= modifier.multiplier
		MasterySpellModifierData.EffectType.MOVEMENT_THRESHOLD_DELTA:
			profile.movement_threshold_delta = int(profile.movement_threshold_delta) \
				+ modifier.flat_value
			profile.movement_threshold_minimum = maxi(
				int(profile.movement_threshold_minimum), modifier.minimum_value
			)
	if not (profile.sources as Array).has(source_id):
		(profile.sources as Array).append(source_id)
