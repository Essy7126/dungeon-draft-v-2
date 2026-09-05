@tool
class_name OdysseyItemAuthoringService
extends RefCounted

const CATALOG_PATH := ItemStudioCatalogService.ODYSSEY_CATALOG_PATH


static func catalog_sheet(catalog: ItemCatalog = null) -> Dictionary:
	var authority := catalog
	if authority == null:
		authority = ResourceLoader.load(
			CATALOG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
		) as ItemCatalog
	if authority == null:
		return {"valid": false, "error": "Catalogue Odyssey introuvable."}
	var definitions := authority.get_definitions()
	var equipment_count := definitions.filter(func(item: ItemDefinition):
		return item != null and item.is_equippable()
	).size()
	var relic_count := definitions.filter(func(item: ItemDefinition):
		return item != null and item.is_relic()
	).size()
	return {
		"catalog_path": CATALOG_PATH,
		"valid": authority.validate_catalog().get("valid", false),
		"total": definitions.size(),
		"equipment_count": equipment_count,
		"relic_count": relic_count,
		"items": definitions.map(item_sheet),
		"contract_ok": definitions.size() == 26 \
			and equipment_count == 16 and relic_count == 8 \
			and authority.get_definition(&"minor_healing_potion") != null \
			and authority.get_definition(&"minor_action_scroll") != null,
	}


static func item_sheet(definition: ItemDefinition) -> Dictionary:
	if definition == null:
		return {}
	var requirements := definition.runtime_requirements()
	var spell_modifiers: Array[Dictionary] = []
	for modifier in definition.spell_modifiers:
		if modifier is ItemSpellModifierData:
			var typed := modifier as ItemSpellModifierData
			requirements.append_array(typed.runtime_requirements())
			spell_modifiers.append({
				"target_spell_id": typed.target_spell_id,
				"damage_percent": typed.damage_percent,
				"range_bonus": typed.range_bonus,
				"minimum_range_override": typed.minimum_range_override,
				"push_bonus": typed.push_bonus,
				"healing_and_shield_percent": typed.healing_and_shield_percent,
				"runtime_requirements": typed.runtime_requirements(),
			})
	var reactives: Array[Dictionary] = []
	for effect in definition.reactive_effects:
		if effect != null:
			reactives.append({
				"trigger_id": effect.trigger_id,
				"target_id": effect.target_id,
				"result_id": effect.result_id,
				"frequency_id": effect.frequency_id,
				"reaction_group": effect.reaction_group,
				"stackable": effect.stackable,
				"priority": effect.priority,
			})
	return {
		"item_id": definition.item_id,
		"display_name": definition.display_name,
		"category": ItemDefinition.Category.keys()[definition.category],
		"slot": ItemDefinition.EquipmentSlot.keys()[definition.equipment_slot + 1] \
			if definition.equipment_slot >= ItemDefinition.EquipmentSlot.NONE else "NONE",
		"rarity": definition.rarity,
		"compatible_character_ids": definition.compatible_character_ids.duplicate(),
		"spell_modifiers": spell_modifiers,
		"reactive_effects": reactives,
		"runtime_requirements": _unique(requirements),
	}


static func level_projections(
		definition: ItemDefinition,
		unit_data: UnitData,
		profile: ChampionProgressionProfile,
		levels: PackedInt32Array = PackedInt32Array([1, 10, 14])
	) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if definition == null or unit_data == null or profile == null:
		return rows
	for level in levels:
		var safe_level := clampi(level, 1, profile.level_cap)
		var before := {
			"max_hp": float(profile.base_hp_for_level(safe_level)),
			"attack_power": float(profile.base_prowess_for_level(safe_level)),
			"max_ap": float(unit_data.max_ap),
			"max_mp": float(unit_data.max_mp),
			"initiative": float(unit_data.initiative),
		}
		var after := before.duplicate(true)
		for modifier in definition.stat_modifiers:
			if modifier == null or not after.has(modifier.stat_id):
				continue
			var current := float(after[modifier.stat_id])
			after[modifier.stat_id] = current + modifier.value \
				if modifier.modifier_type == ItemStatModifierData.ModifierType.FLAT \
				else current * (1.0 + modifier.value)
		rows.append({
			"level": safe_level,
			"before": before,
			"after": after,
			"signals": {
				"ap_delta": float(after.max_ap) - float(before.max_ap),
				"mp_delta": float(after.max_mp) - float(before.max_mp),
				"range_modifiers": definition.spell_modifiers.filter(
					func(value): return value is ItemSpellModifierData \
						and (value as ItemSpellModifierData).range_bonus != 0
				).size(),
			},
		})
	return rows


static func compare(first: ItemDefinition, second: ItemDefinition) -> Dictionary:
	return ItemComparisonService.new().compare(first, second)


static func _unique(values: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		if not result.has(value):
			result.append(value)
	return result
