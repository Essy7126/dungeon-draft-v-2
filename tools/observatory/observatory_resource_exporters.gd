class_name ObservatoryResourceExporters
extends RefCounted

const AOE_NAMES := ["single", "cross", "square", "line"]
const DAMAGE_TYPE_NAMES := ["physical", "magical"]
const ELEMENT_NAMES := ["none", "fire", "ice", "lightning", "shadow", "holy", "earth"]
const DELAYED_NAMES := ["none", "strike_and_push", "summon"]
const ITEM_CATEGORY_NAMES := ["weapon", "armor", "accessory", "consumable", "scroll"]
const ITEM_SLOT_NAMES := ["weapon", "armor", "accessory"]
const ITEM_USE_NAMES := ["none", "heal_flat", "restore_ap_flat"]
const REWARD_TYPE_NAMES := ["team_heal_percent", "hero_max_hp", "next_combat_shield"]
const TARGET_POLICY_NAMES := ["team", "explicit_hero"]
const MODIFIER_PROPERTIES: Array[StringName] = [
	&"target_spell_id",
	&"damage_percent",
	&"damage_type_filter",
	&"require_elemental_damage",
	&"target_hp_at_or_below",
	&"range_bonus",
	&"push_bonus",
	&"healing_and_shield_percent",
	&"additional_push",
	&"additional_shield",
	&"damage_bonus",
	&"heal_bonus",
	&"minimum_range",
	&"status",
	&"status_duration",
	&"terrain_effect",
	&"movement_points",
	&"collision_damage",
]


static func export_character(character: UnitData) -> Dictionary:
	var spell_ids: Array[String] = []
	for spell in character.spells:
		if spell != null:
			spell_ids.append(str(spell.get_effective_spell_id()))
	var discipline_ids: Array[String] = []
	for discipline in character.disciplines:
		if discipline != null:
			discipline_ids.append(str(discipline.discipline_id))
	return {
		"id": str(character.get_effective_unit_id()),
		"name": character.unit_name,
		"description": character.description,
		"role": character.role,
		"presentation_summary": character.presentation_summary,
		"progression_summary": character.progression_summary,
		"presentation_badge": character.presentation_badge,
		"team": character.team,
		"max_hp": character.max_hp,
		"initiative": character.initiative,
		"max_ap": character.max_ap,
		"max_mp": character.max_mp,
		"attack_power": character.attack_power,
		"force": character.force,
		"armour": character.armure,
		"magic_resistance": character.resist_magique,
		"dodge": character.esquive,
		"resistances": ObservatorySerializer.sanitize(character.resistances),
		"critical_chance": character.crit_chance,
		"critical_multiplier": character.crit_multi,
		"basic_attack_enabled": character.basic_attack_enabled,
		"active_spell_slots": character.active_spell_slots,
		"spell_ids": spell_ids,
		"discipline_ids": discipline_ids,
		"visual_scene_path": ObservatorySerializer.resource_path(character.visual_scene),
		"preview_visual_scene_path": ObservatorySerializer.resource_path(
			character.preview_visual_scene
		),
		"source_path": ObservatorySerializer.resource_path(character),
	}


static func export_spell(spell: Spell, character_ids: Array[String]) -> Dictionary:
	var warnings: Array[String] = []
	var modifiers: Array[Dictionary] = []
	for modifier in spell.modifiers:
		if modifier != null:
			modifiers.append(ObservatorySerializer.explicit_resource(
				modifier,
				MODIFIER_PROPERTIES,
				warnings,
			))
	return {
		"id": str(spell.get_effective_spell_id()),
		"discipline_id": str(spell.discipline_id),
		"name": spell.spell_name,
		"description": spell.description,
		"referenced_by_character_ids": character_ids,
		"ap_cost": spell.ap_cost,
		"minimum_range": spell.minimum_range,
		"range": spell.spell_range,
		"needs_line_of_sight": spell.needs_line_of_sight,
		"cooldown_activations": spell.cooldown_activations,
		"initial_cooldown": spell.initial_cooldown,
		"max_uses_per_combat": spell.max_uses_per_combat,
		"once_per_activation": spell.once_per_activation,
		"can_target_enemy": spell.can_target_enemy,
		"can_target_ally": spell.can_target_ally,
		"can_target_free_cell": spell.can_target_free_cell,
		"can_target_self": spell.can_target_self,
		"aoe_shape": _enum_value(spell.aoe_shape, AOE_NAMES),
		"aoe_size": spell.aoe_size,
		"line_from_caster": spell.line_from_caster,
		"damage": spell.damage,
		"heal": spell.heal,
		"shield_grant": spell.shield_grant,
		"damage_type": _enum_value(spell.damage_type, DAMAGE_TYPE_NAMES),
		"element": _enum_value(spell.element, ELEMENT_NAMES),
		"critical_chance": spell.crit_chance,
		"terrain_effect": _resource_reference(spell.terrain_effect),
		"applied_status": _resource_reference(spell.applied_status),
		"push_distance": spell.push_distance,
		"pull_distance": spell.pull_distance,
		"collision_damage": spell.collision_damage,
		"cluster_bonus_damage": spell.cluster_bonus_damage,
		"ap_drain": spell.ap_drain,
		"teleport_behind_target": spell.teleport_behind_target,
		"delayed_resolution": _enum_value(spell.delayed_resolution, DELAYED_NAMES),
		"summon": _resource_reference(spell.summon_unit_data),
		"summon_type": str(spell.summon_type),
		"modifiers": modifiers,
		"serialization_warnings": warnings,
		"icon_path": ObservatorySerializer.resource_path(spell.icon),
		"vfx_scene_path": ObservatorySerializer.resource_path(spell.vfx_scene),
		"sound_path": ObservatorySerializer.resource_path(spell.sound_cast),
		"source_path": ObservatorySerializer.resource_path(spell),
	}


static func export_discipline(
		discipline: DisciplineData,
		character_id: String
	) -> Dictionary:
	var ranks: Array[Dictionary] = []
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		var choices: Array[Dictionary] = []
		for choice in rank_data.choices:
			if choice == null:
				continue
			var modifiers: Array[Dictionary] = []
			for modifier in choice.spell_modifiers:
				if modifier != null:
					modifiers.append(ObservatorySerializer.explicit_resource(
						modifier,
						MODIFIER_PROPERTIES,
					))
			var prerequisites: Array[String] = []
			var exclusions: Array[String] = []
			if choice is SkillTreeNodeData:
				for value in (choice as SkillTreeNodeData).prerequisite_node_ids:
					prerequisites.append(str(value))
				for value in (choice as SkillTreeNodeData).excluded_node_ids:
					exclusions.append(str(value))
			choices.append({
				"upgrade_id": str(choice.upgrade_id),
				"name": choice.display_name,
				"description": choice.description,
				"discipline_id": str(choice.discipline_id),
				"rank": choice.rank,
				"target_spell_id": str(choice.target_spell_id),
				"prerequisite_ids": prerequisites,
				"excluded_ids": exclusions,
				"modifiers": modifiers,
				"source_path": ObservatorySerializer.resource_path(choice),
			})
		ranks.append({
			"rank": rank_data.rank,
			"required_total_xp": rank_data.required_total_xp,
			"choices": choices,
			"source_path": ObservatorySerializer.resource_path(rank_data),
		})
	var total_choice_count := 0
	for rank in ranks:
		total_choice_count += (rank.get("choices", []) as Array).size()
	return {
		"id": str(discipline.discipline_id),
		"character_id": character_id,
		"name": discipline.display_name,
		"description": discipline.description,
		"presentation_color": ObservatorySerializer.sanitize(
			discipline.presentation_color
		),
		"rank_count": ranks.size(),
		"total_choice_count": total_choice_count,
		"ranks": ranks,
		"icon_path": ObservatorySerializer.resource_path(discipline.icon),
		"source_path": ObservatorySerializer.resource_path(discipline),
	}


static func export_item(item: ItemDefinition, pool_ids: Array[String]) -> Dictionary:
	var stat_modifiers: Array[Dictionary] = []
	for modifier in item.stat_modifiers:
		if modifier != null:
			stat_modifiers.append({
				"stat_id": str(modifier.stat_id),
				"value": modifier.value,
				"modifier_type": _enum_value(
					modifier.modifier_type,
					["flat", "percent"],
				),
				"source_path": ObservatorySerializer.resource_path(modifier),
			})
	var spell_modifiers: Array[Dictionary] = []
	for modifier in item.spell_modifiers:
		if modifier != null:
			spell_modifiers.append(ObservatorySerializer.explicit_resource(
				modifier,
				MODIFIER_PROPERTIES,
			))
	var compatible_ids: Array[String] = []
	for character_id in item.compatible_character_ids:
		compatible_ids.append(str(character_id))
	var tags: Array[String] = []
	for tag in item.tags:
		tags.append(str(tag))
	return {
		"id": str(item.item_id),
		"name": item.display_name,
		"description": item.description,
		"rarity": str(item.rarity),
		"tags": tags,
		"category": _enum_value(item.category, ITEM_CATEGORY_NAMES),
		"equipment_slot": _enum_value(item.equipment_slot, ITEM_SLOT_NAMES, -1, "none"),
		"stack_limit": item.stack_limit,
		"compatible_character_ids": compatible_ids,
		"stat_modifiers": stat_modifiers,
		"spell_modifiers": spell_modifiers,
		"use_effect": _enum_value(item.use_effect, ITEM_USE_NAMES),
		"use_value": item.use_value,
		"equippable": item.is_equippable(),
		"consumable": item.is_consumable(),
		"valid": item.is_valid(),
		"pool_ids": pool_ids,
		"reward_fx_profile": str(item.reward_fx_profile),
		"reward_audio_profile": str(item.reward_audio_profile),
		"icon_path": ObservatorySerializer.resource_path(item.icon),
		"inventory_icon_path": ObservatorySerializer.resource_path(item.inventory_icon),
		"card_texture_path": ObservatorySerializer.resource_path(item.card_texture),
		"source_path": ObservatorySerializer.resource_path(item),
	}


static func export_reward(reward: PostCombatRewardData) -> Dictionary:
	return {
		"id": str(reward.reward_id),
		"name": reward.display_name,
		"description": reward.description,
		"reward_type": _enum_value(reward.reward_type, REWARD_TYPE_NAMES),
		"target_policy": _enum_value(reward.target_policy, TARGET_POLICY_NAMES),
		"value": reward.value,
		"valid": reward.is_valid(),
		"usage_status": "declared_and_referenced_by_service",
		"icon_path": ObservatorySerializer.resource_path(reward.icon),
		"source_path": ObservatorySerializer.resource_path(reward),
	}


static func _resource_reference(resource: Resource) -> Variant:
	if resource == null:
		return null
	return {
		"resource_type": ObservatorySerializer.resource_type_name(resource),
		"resource_path": ObservatorySerializer.resource_path(resource),
	}


static func _enum_value(
		value: int,
		names: Array,
		offset: int = 0,
		fallback: String = "unknown"
	) -> Dictionary:
	var index := value - offset
	return {
		"value": value,
		"name": str(names[index]) if index >= 0 and index < names.size() else fallback,
	}
