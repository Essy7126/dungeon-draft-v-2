@tool
class_name ItemRuntimePreviewService
extends RefCounted


func preview_equipment(unit_data: UnitData, definition: ItemDefinition) -> Dictionary:
	if unit_data == null or definition == null or not definition.is_equippable():
		return {"ok": false, "error": "Équipement ou héros incompatible avec la prévisualisation."}
	var canonical_fingerprint := ItemFingerprintService.semantic_fingerprint(definition)
	var isolated_definition := ItemDeepCopyService.new().duplicate_definition(definition)
	var catalog := _catalog_with(isolated_definition)
	if catalog == null:
		return {"ok": false, "error": "Catalogue isolé invalide."}
	var unit := Unit.from_data(unit_data)
	var state := CharacterRunState.new()
	if unit == null or not state.initialize(unit, unit_data):
		return {"ok": false, "error": "Héros isolé impossible à construire."}
	var inventory := RunInventory.new()
	var equipment_service := EquipmentService.new()
	if not inventory.initialize(catalog, 4) or not equipment_service.initialize(catalog):
		state.dispose()
		return {"ok": false, "error": "Services runtime isolés invalides."}
	var added := inventory.try_add(isolated_definition.item_id, 1)
	var ids := added.get("instance_ids", []) as Array
	if not added.get("success", false) or ids.size() != 1:
		state.dispose()
		return {"ok": false, "error": "Instance de test impossible à créer."}
	var before := unit_snapshot(unit)
	var equipped := equipment_service.equip(
		inventory, state, StringName(ids[0]), isolated_definition.equipment_slot
	)
	if not equipped.get("success", false):
		state.dispose()
		return {"ok": false, "error": equipped.get("error", "Équipement impossible.")}
	var after := unit_snapshot(unit)
	var removed := equipment_service.unequip(inventory, state, isolated_definition.equipment_slot)
	var restored := unit_snapshot(unit)
	var result := {
		"ok": removed.get("success", false) and before == restored,
		"before": before,
		"after": after,
		"restored": restored,
		"delta": _numeric_delta(before, after),
		"restoration_exact": before == restored,
		"canonical_unchanged": canonical_fingerprint == ItemFingerprintService.semantic_fingerprint(definition),
		"runtime_service": "EquipmentService + EquipmentStatService",
	}
	state.dispose()
	return result


func preview_consumable(unit_data: UnitData, definition: ItemDefinition) -> Dictionary:
	if unit_data == null or definition == null or not definition.is_consumable():
		return {"ok": false, "error": "Consommable ou héros incompatible."}
	var canonical_fingerprint := ItemFingerprintService.semantic_fingerprint(definition)
	var isolated_definition := ItemDeepCopyService.new().duplicate_definition(definition)
	var catalog := _catalog_with(isolated_definition)
	var unit := Unit.from_data(unit_data)
	var state := CharacterRunState.new()
	var inventory := RunInventory.new()
	var use_service := ItemUseService.new()
	if catalog == null or unit == null or not state.initialize(unit, unit_data) \
			or not inventory.initialize(catalog, 4) or not use_service.initialize(catalog):
		return {"ok": false, "error": "État isolé du consommable invalide."}
	unit.current_hp = maxi(1, unit.max_hp.get_int() - 50)
	unit.current_ap = maxi(0, unit.max_ap.get_int() - 2)
	var added := inventory.try_add(isolated_definition.item_id, 2)
	var ids := added.get("instance_ids", []) as Array
	if not added.get("success", false) or ids.is_empty():
		state.dispose()
		return {"ok": false, "error": "Pile de test impossible à créer."}
	var instance_id := StringName(ids[0])
	var quantity_before := inventory.get_instance(instance_id).quantity
	var before := unit_snapshot(unit)
	var used := use_service.use_item(inventory, state, instance_id)
	var after := unit_snapshot(unit)
	var remaining := inventory.get_instance(instance_id)
	var result := {
		"ok": used.get("success", false),
		"before": before,
		"after": after,
		"details": used.get("details", {}),
		"quantity_before": quantity_before,
		"quantity_after": remaining.quantity if remaining != null else 0,
		"canonical_unchanged": canonical_fingerprint == ItemFingerprintService.semantic_fingerprint(definition),
		"runtime_service": "ItemUseService",
	}
	state.dispose()
	return result


func project_spell(unit_data: UnitData, spell: Spell, definition: ItemDefinition) -> Dictionary:
	if unit_data == null or spell == null or definition == null:
		return {"ok": false, "error": "Projection de sort incomplète."}
	var unit := Unit.from_data(unit_data)
	var range_before := spell.spell_range
	var range_after := range_before
	var applicable: Array[Dictionary] = []
	for modifier in definition.spell_modifiers:
		if modifier == null:
			continue
		var applies := modifier.applies_to(spell)
		if applies:
			range_after += modifier.get_range_bonus(unit, spell)
		applicable.append({
			"class": modifier.get_script().resource_path.get_file().get_basename(),
			"applies": applies,
			"summary": ItemEffectRegistry.new().summarize(modifier),
		})
	return {
		"ok": true,
		"spell_id": str(spell.get_effective_spell_id()),
		"range_before": range_before,
		"range_after": range_after,
		"base_damage": spell.damage,
		"heal": spell.heal,
		"shield": spell.shield_grant,
		"push": spell.push_distance,
		"damage_type": int(spell.damage_type),
		"element": int(spell.element),
		"modifiers": applicable,
		"battle_context_required": _requires_battle_context(definition),
	}


func _requires_battle_context(definition: ItemDefinition) -> bool:
	for modifier in definition.spell_modifiers:
		if modifier is ItemSpellModifierData:
			var item_modifier := modifier as ItemSpellModifierData
			if item_modifier.damage_percent > 0.0 \
					or item_modifier.healing_and_shield_percent > 0.0 \
					or item_modifier.push_bonus > 0:
				return true
	return false


func unit_snapshot(unit: Unit) -> Dictionary:
	return {
		"max_hp": unit.max_hp.get_value(), "current_hp": unit.current_hp,
		"armure": unit.armure.get_value(), "resist_magique": unit.resist_magique.get_value(),
		"initiative": unit.initiative.get_value(), "max_ap": unit.max_ap.get_value(),
		"current_ap": unit.current_ap, "max_mp": unit.max_mp.get_value(),
		"current_mp": unit.current_mp, "attack_power": unit.attack_power.get_value(),
		"crit_chance": unit.crit_chance.get_value(), "esquive": unit.esquive.get_value(),
		"force": unit.force.get_value(), "resistance_ice": unit.get_resistance_value(Spell.Element.ICE),
	}


func _catalog_with(definition: ItemDefinition) -> ItemCatalog:
	var catalog := ItemCatalog.new()
	var definitions: Array[ItemDefinition] = []
	definitions.append(definition)
	catalog.definitions = definitions
	return catalog if catalog.rebuild_index() else null


func _numeric_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var result := {}
	for key in before:
		if before[key] is int or before[key] is float:
			result[key] = float(after.get(key, 0.0)) - float(before[key])
	return result
