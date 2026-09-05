class_name AchillesSpellVisualResolver
extends RefCounted

## Read-only presentation: identities and resolved geometry stay gameplay-owned.
## A supplied profile can include temporary range/equipment effects. This class
## never evaluates reactive events, consumes a flag, or applies a mastery.
const STRIKE: StringName = &"achilles_peleid_strike"
const DASH: StringName = &"achilles_fulminant_dash"
const SHOT: StringName = &"achilles_pelion_shot"
const GUARD: StringName = &"achilles_bronze_guard"
const LEGACY_ALIASES := {
	&"achilles_spear_thrust": STRIKE,
	&"achilles_sweep": STRIKE,
	&"achilles_advance": DASH,
	&"achilles_guard": GUARD,
}


static func resolve(
		spell: Spell,
		unit: Unit = null,
		resolved_profile: Dictionary = {}
	) -> Dictionary:
	var spell_id: StringName = spell.get_effective_spell_id() if spell != null else &""
	var inherited_id: StringName = LEGACY_ALIASES.get(spell_id, spell_id)
	var nodes: Array[SkillTreeNodeData] = []
	if unit != null:
		nodes.assign(unit.mastery_nodes)
	var profile := MasteryStaticModifierResolver.resolve_spell_profile(spell, nodes)
	profile.merge(resolved_profile.duplicate(true), true)
	var selected_ids: Array[StringName] = []
	var doctrine_ids: Array[StringName] = []
	var intensity_tier := 0
	for node in nodes:
		if node == null:
			continue
		_append_name(selected_ids, node.upgrade_id)
		_append_name(doctrine_ids, node.doctrine_id)
		if node.node_type >= SkillTreeNodeData.NodeType.SPECIALIST_SUMMIT:
			intensity_tier = 2
		elif node.node_type == SkillTreeNodeData.NodeType.CAPSTONE:
			intensity_tier = maxi(intensity_tier, 1)
	var profile_sources := _names(profile.get("sources", []))
	var sources := selected_ids.duplicate()
	for source in profile_sources:
		_append_name(sources, source)
	selected_ids.sort()
	doctrine_ids.sort()
	profile_sources.sort()
	var result := {
		"spell_id": spell_id,
		"inherited_spell_id": inherited_id,
		"action_family": &"generic",
		"variant": &"base",
		"animation_stem": &"attack",
		"effect_variant": &"generic",
		"target_shape": StringName(profile.get("target_shape", &"SINGLE")),
		"movement": spell != null and spell.caster_movement != Spell.CasterMovement.NONE,
		"guard_active": _has_guard(unit),
		"minimum_range": int(profile.get("minimum_range", 0)),
		"maximum_range": int(profile.get("maximum_range", 0)),
		"maximum_targets": int(profile.get("maximum_targets", 1)),
		"piercing_enabled": bool(profile.get("piercing_enabled", false)),
		"selected_mastery_ids": selected_ids,
		"selected_doctrine_ids": doctrine_ids,
		"profile_source_ids": profile_sources,
		"palette_variant": &"base",
		"intensity_tier": intensity_tier,
	}
	match inherited_id:
		STRIKE:
			result.action_family = &"strike"
			result.effect_variant = &"strike"
			if result.target_shape == &"LINE" and result.maximum_targets > 1:
				result.variant = &"scourge"
				result.animation_stem = &"sweep"
				result.effect_variant = &"strike_line"
			elif spell_id == &"achilles_sweep":
				result.variant = &"sweep"
				result.animation_stem = &"sweep"
				result.effect_variant = &"strike_sweep"
			if doctrine_ids.has(&"achilles_wrath_of_peleus") or _has_source(sources, &"achilles_summit_wrath"):
				result.palette_variant = &"wrath"
		DASH:
			result.action_family = &"dash"
			result.animation_stem = &"dash"
			result.effect_variant = &"dash"
			# The retired advance used a movement modifier, not caster_movement.
			result.movement = true
			if result.guard_active and _has_source(sources, &"achilles_aeacus_mobile_bastion"):
				result.variant = &"bastion"
				result.effect_variant = &"dash_bastion"
				result.palette_variant = &"aeacus"
		SHOT:
			result.action_family = &"shot"
			result.animation_stem = &"bow"
			result.effect_variant = &"arrow"
			# Resolved shape wins over a lower-tier source that remains selected.
			if result.target_shape == &"FAN":
				result.variant = &"volley"
				result.animation_stem = &"volley"
				result.effect_variant = &"arrow_volley"
			elif result.target_shape == &"LINE" and result.piercing_enabled:
				if result.maximum_targets >= 3:
					result.variant = &"death_line"
					result.effect_variant = &"arrow_death_line"
				else:
					result.variant = &"piercing"
					result.effect_variant = &"arrow_piercing"
			if doctrine_ids.has(&"achilles_lesson_of_chiron") or _has_source(sources, &"achilles_summit_chiron"):
				result.palette_variant = &"chiron"
		GUARD:
			result.action_family = &"guard"
			result.animation_stem = &"guard"
			result.effect_variant = &"guard"
			if _has_source(sources, &"achilles_aeacus_myrmidon_rampart"):
				result.variant = &"rampart"
				result.effect_variant = &"guard_rampart"
			if doctrine_ids.has(&"achilles_aegis_of_aeacus") or _has_source(sources, &"achilles_summit_aeacus"):
				result.palette_variant = &"aeacus"
	return result


static func _has_guard(unit: Unit) -> bool:
	if unit == null:
		return false
	for shield in unit.get_shield_instances():
		if shield.value > 0 and shield.tags.has(&"guard"):
			return true
	return false


static func _has_source(sources: Array[StringName], node_id: StringName) -> bool:
	for source in sources:
		if source == node_id or str(source).begins_with(str(node_id) + "."):
			return true
	return false


static func _append_name(target: Array[StringName], value: StringName) -> void:
	if value != &"" and not target.has(value):
		target.append(value)


static func _names(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is Array or values is PackedStringArray:
		for value in values:
			_append_name(result, StringName(value))
	return result
