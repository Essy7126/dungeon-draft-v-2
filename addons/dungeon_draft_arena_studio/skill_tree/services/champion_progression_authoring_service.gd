@tool
class_name ChampionProgressionAuthoringService
extends RefCounted


## Projection pure partagée par Progression Studio et Spell Studio. Elle ne
## construit aucune Unit runtime et ne modifie jamais les Resources authored.
static func level_table(profile: ChampionProgressionProfile) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if profile == null:
		return rows
	for level in range(1, profile.level_cap + 1):
		rows.append({
			"level": level,
			"cumulative_xp": profile.xp_for_level(level),
			"xp_to_next": profile.xp_for_level(level + 1) - profile.xp_for_level(level) \
				if level < profile.level_cap else 0,
			"base_hp": profile.base_hp_for_level(level),
			"base_prowess": profile.base_prowess_for_level(level),
			"attribute_point_granted": profile.attribute_point_levels.has(level),
			"mastery_point_granted": profile.mastery_point_levels.has(level),
			"attribute_points": profile.attribute_points_through_level(level),
			"mastery_points": profile.mastery_points_through_level(level),
		})
	return rows


static func wisdom_glory_projection(
		profile: ChampionProgressionProfile,
		base_xp: int
	) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if profile == null:
		return rows
	for wisdom in range(profile.wisdom_cap + 1):
		rows.append({
			"wisdom": wisdom,
			"base_xp": maxi(0, base_xp),
			"without_glory": profile.encounter_xp(base_xp, wisdom, false, false),
			"glory_failed": profile.encounter_xp(base_xp, wisdom, true, false),
			"glory_succeeded": profile.encounter_xp(base_xp, wisdom, true, true),
		})
	return rows


static func spell_sheet(
		spell: Spell,
		profile: ChampionProgressionProfile,
		classification_catalog: CombatActionClassificationCatalogData,
		animation_set: CharacterAnimationSetData = null,
		levels: PackedInt32Array = PackedInt32Array([1, 5, 10, 14])
	) -> Dictionary:
	if spell == null:
		return {}
	var spell_id := spell.get_effective_spell_id()
	var values: Array[Dictionary] = []
	if profile != null:
		for level in levels:
			var safe_level := clampi(level, 1, profile.level_cap)
			var prowess := profile.base_prowess_for_level(safe_level)
			var hp := profile.base_hp_for_level(safe_level)
			values.append({
				"level": safe_level,
				"prowess": prowess,
				"max_hp": hp,
				"damage": SpellScalingResolver.resolve_from_values(
					spell.damage_scaling, prowess, hp, safe_level, spell.damage
				),
				"shield": SpellScalingResolver.resolve_from_values(
					spell.shield_scaling, prowess, hp, safe_level, spell.shield_grant
				),
			})
	var action_id := CharacterAnimationSetData.cast_action_id_for_spell_id(spell_id)
	return {
		"spell_id": spell_id,
		"display_name": spell.spell_name,
		"classification": _classification_id(classification_catalog, spell_id),
		"ap_cost": spell.ap_cost,
		"minimum_range": spell.minimum_range,
		"maximum_range": spell.spell_range,
		"needs_line_of_sight": spell.needs_line_of_sight,
		"targeting": {
			"enemy": spell.can_target_enemy,
			"ally": spell.can_target_ally,
			"free_cell": spell.can_target_free_cell,
			"self": spell.can_target_self,
		},
		"cooldown_activations": spell.cooldown_activations,
		"max_uses_per_combat": spell.max_uses_per_combat,
		"once_per_activation": spell.once_per_activation,
		"shield_duration_activations": spell.shield_duration_activations,
		"caster_movement": Spell.CasterMovement.keys()[spell.caster_movement],
		"movement_requires_clear_path": spell.movement_requires_clear_path,
		"cast_action_id": action_id,
		"animation_clip": animation_set.get_animation_name(action_id) \
			if animation_set != null else &"",
		"projections": values,
	}


static func spell_sheets(
		character_profile: CharacterProgressionProfile,
		animation_set: CharacterAnimationSetData = null
	) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if character_profile == null:
		return rows
	for spell in character_profile.spells:
		rows.append(spell_sheet(
			spell,
			character_profile.champion_progression_profile,
			character_profile.combat_action_classification_catalog,
			animation_set,
		))
	return rows


static func _classification_id(
		catalog: CombatActionClassificationCatalogData,
		spell_id: StringName
	) -> StringName:
	if catalog == null:
		return &""
	for entry in catalog.entries:
		if entry != null and entry.ability_id == spell_id:
			return entry.classification_id()
	return &""
