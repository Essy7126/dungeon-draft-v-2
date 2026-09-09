class_name AchillesSpellVisualResolver
extends RefCounted

## Read-only presentation: identities and resolved geometry stay gameplay-owned.
## A supplied profile can include temporary range/equipment effects. This class
## never evaluates reactive events, consumes a flag, or applies a mastery.
const ExpeditionPresentation = preload("res://data/visuals/achilles/achilles_expedition_spell_presentation.gd")
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
	var inherited_id: StringName = LEGACY_ALIASES.get(spell_id, ExpeditionPresentation.inherited_id(spell_id))
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
		"presentation_version": 3,
		"gesture_variant": &"base",
		"projectile_variant": &"none",
		"projectile_animation": &"arrow",
		"impact_animation": &"impact",
		"projectile_scale": Vector2.ONE,
		"projectile_trail_count": 0,
		"projectile_trail_spacing": 0.06,
		"projectile_trail_alpha": 0.18,
		"push_distance": int(profile.get("push_distance", 0)),
		"stopping_arrow_selected": _has_source(sources, &"achilles_chiron_stopping_arrow"),
		"effects_source": &"achilles",
		"heal_animation": &"",
		"heal_effects_source": &"philosopher",
		"aux_burst_animation": &"",
		"expedition_spell": false,
		"target_geometry_source": &"mastery_profile",
		"target_count_policy": &"profile",
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
					result.animation_stem = &"bow_death"
					result.effect_variant = &"arrow_death_line"
				else:
					result.variant = &"piercing"
					result.animation_stem = &"bow_piercing"
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
	ExpeditionPresentation.apply_geometry(result, spell)
	_resolve_projectile(result, profile_sources if result.expedition_spell else sources)
	ExpeditionPresentation.apply_effects(result, spell)
	return result


## Art selection is independent of damage, quotas and conditional triggers.
## Geometry comes from the resolved gameplay profile. A numeric bonus alone
## never invents a different attack or an elemental damage type.
static func _resolve_projectile(result: Dictionary, sources: Array[StringName]) -> void:
	if result.action_family != &"shot":
		return
	var variant: StringName = &"bronze"
	if result.variant in [&"piercing", &"death_line", &"volley"]:
		variant = result.variant
	elif result.push_distance > 0:
		variant = &"heavy"
	elif _has_source(sources, &"achilles_chiron_pelion_reach"):
		variant = &"reach"
	result.projectile_variant = variant
	result.gesture_variant = &"bow_release"
	match variant:
		&"reach":
			result.gesture_variant = &"bow_aimed"
			result.projectile_animation = &"arrow_reach"
			result.impact_animation = &"impact_reach"
			result.projectile_scale = Vector2(1.14, 0.8)
			result.projectile_trail_count = 1
		&"heavy":
			result.gesture_variant = &"bow_heavy"
			result.projectile_animation = &"arrow_heavy"
			result.impact_animation = &"impact_heavy"
			result.projectile_scale = Vector2(0.95, 1.28)
		&"piercing":
			result.gesture_variant = &"bow_power"
			result.projectile_animation = &"arrow_piercing"
			result.impact_animation = &"impact_piercing"
			result.projectile_scale = Vector2(1.18, 0.84)
			result.projectile_trail_count = 2
		&"death_line":
			result.gesture_variant = &"bow_power"
			result.projectile_animation = &"arrow_death_line"
			result.impact_animation = &"impact_death_line"
			result.projectile_scale = Vector2(1.36, 0.95)
			result.projectile_trail_count = 3
			result.projectile_trail_alpha = 0.24
		&"volley":
			result.gesture_variant = &"bow_volley"
			result.projectile_animation = &"arrow_volley"
			result.impact_animation = &"impact_volley"
			result.projectile_scale = Vector2(0.82, 0.88)
			result.projectile_trail_count = 1
	if variant != &"bronze":
		result.effect_variant = StringName("arrow_" + String(variant))


## Freeze the origin chosen by combat without querying or consuming its
## reactive state. Selected control capability is not a confirmed control hit.
static func with_cast_context(presentation: Dictionary, origin_cell: Vector2i,
		target_cell: Vector2i, caster_cell: Vector2i) -> Dictionary:
	var result := presentation.duplicate(true)
	result["origin_cell"] = origin_cell
	result["cell"] = target_cell
	result["caster_cell"] = caster_cell
	result["cast_distance"] = absi(target_cell.x - origin_cell.x) + absi(target_cell.y - origin_cell.y)
	result["alternate_origin"] = origin_cell != caster_cell
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
