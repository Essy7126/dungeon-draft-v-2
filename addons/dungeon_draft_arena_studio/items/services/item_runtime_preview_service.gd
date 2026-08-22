@tool
class_name ItemRuntimePreviewService
extends RefCounted


func preview_relic(definition: ItemDefinition) -> Dictionary:
	if definition == null or not definition.is_relic():
		return {"ok": false, "error": "La définition n’est pas une relique."}
	var canonical_fingerprint := ItemFingerprintService.semantic_fingerprint(definition)
	var isolated := ItemDeepCopyService.new().duplicate_definition(definition)
	var catalog := _catalog_with(isolated)
	var inventory := RunInventory.new()
	if catalog == null or not inventory.initialize(catalog, 4):
		return {"ok": false, "error": "Catalogue isolé invalide."}
	var added := inventory.try_add(isolated.item_id, 1)
	if not added.get("success", false):
		return {"ok": false, "error": "Relique temporaire impossible à acquérir."}
	var hero := Unit.new("Héros de test", 0, 100, 10, 6, 3, 20)
	hero.unit_id = &"relic_preview_hero"
	hero.grid_pos = Vector2i(1, 1)
	var enemy := Unit.new("Ennemi de test", 1, 100, 5, 6, 3, 10)
	enemy.unit_id = &"relic_preview_enemy"
	enemy.grid_pos = Vector2i(2, 1)
	var service := RelicRuntimeService.new()
	var evaluations: Array[Dictionary] = []
	service.effect_evaluated.connect(func(report: Dictionary): evaluations.append(report.duplicate(true)))
	if not service.initialize(inventory, catalog, [hero]):
		return {"ok": false, "error": "Service de reliques isolé invalide."}
	service.begin_combat([hero, enemy])
	var scenarios: Array[Dictionary] = [
		{"id": &"turn_start", "trigger": ItemReactiveEffectData.TRIGGER_TURN_START, "context": {"trigger_hero": hero, "active_unit": hero}},
		{"id": &"turn_end", "trigger": ItemReactiveEffectData.TRIGGER_TURN_END, "context": {"trigger_hero": hero, "active_unit": hero}},
		{"id": &"action_resolved", "trigger": ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, "context": {"trigger_hero": hero, "active_unit": hero, "action_id": &"preview_action"}},
		{"id": &"ap_after_action", "trigger": ItemReactiveEffectData.TRIGGER_AP_AFTER_ACTION, "context": {"trigger_hero": hero, "active_unit": hero, "action_id": &"preview_action", "ap_before": 6, "ap_after": 4}},
		{"id": &"move_prepared", "trigger": ItemReactiveEffectData.TRIGGER_VOLUNTARY_MOVE_PREPARED, "context": {"trigger_hero": hero, "active_unit": hero, "action_id": &"preview_move", "voluntary": true, "distance": 3, "interceptable": true}},
		{"id": &"move_resolved", "trigger": ItemReactiveEffectData.TRIGGER_VOLUNTARY_MOVE_RESOLVED, "context": {"trigger_hero": hero, "active_unit": hero, "action_id": &"preview_move", "voluntary": true, "distance": 3}},
		{"id": &"enemy_damage", "trigger": ItemReactiveEffectData.TRIGGER_HP_LOST, "context": {"trigger_hero": hero, "active_unit": hero, "damage_source": enemy, "enemy_source": true, "hp_loss": 20, "action_id": &"preview_hit"}},
		{"id": &"terrain_damage", "trigger": ItemReactiveEffectData.TRIGGER_HP_LOST, "context": {"trigger_hero": hero, "active_unit": hero, "damage_source": null, "enemy_source": false, "hp_loss": 10, "action_id": &"preview_terrain"}},
		{"id": &"hp_threshold", "trigger": ItemReactiveEffectData.TRIGGER_HP_THRESHOLD_CROSSED, "context": {"trigger_hero": hero, "active_unit": hero, "damage_source": enemy, "enemy_source": true, "hp_loss": 30, "hp_before_ratio": 0.7, "hp_after_ratio": 0.4}},
		{"id": &"unit_killed", "trigger": ItemReactiveEffectData.TRIGGER_UNIT_KILLED, "context": {"trigger_hero": hero, "active_unit": hero, "killer": hero, "killed_unit": enemy}},
		{"id": &"adjacent_enemy_turn_end", "trigger": ItemReactiveEffectData.TRIGGER_ADJACENT_ENEMY_TURN_END, "context": {"eligible_heroes": [hero], "active_unit": enemy}},
	]
	for scenario in scenarios:
		var context := (scenario.get("context", {}) as Dictionary).duplicate(false)
		context["scenario_id"] = scenario.get("id", &"")
		if scenario.get("id") in [&"enemy_damage", &"terrain_damage", &"hp_threshold"]:
			hero.current_hp = 40
		service.process_trigger(StringName(scenario.get("trigger", &"")), context)
	# Le déclenchement manuel n'est branché sur aucun événement : rejouer la
	# liste de scénarios ci-dessus ne le montrerait jamais. On l'exerce donc par
	# son vrai chemin d'appel, sinon l'aperçu annoncerait « rien ne se passe »
	# pour tout objet que le joueur active lui-même.
	var evaluations_before_manual := evaluations.size()
	for entry in service.manual_activation_entries():
		hero.current_hp = 40
		service.activate_relic_manually(hero, StringName(entry.get("instance_id", &"")))
	for index in range(evaluations_before_manual, evaluations.size()):
		evaluations[index]["scenario_id"] = ItemReactiveEffectData.TRIGGER_MANUAL_ACTIVATION
	var move_cost := service.modify_voluntary_transition_cost(hero, Vector2i(1, 1), Vector2i(2, 1), 2)
	service.end_combat()
	service.dispose()
	var frequency_resets := _preview_frequency_resets()
	return {
		"ok": true,
		"scenarios": evaluations,
		"movement_transition_before": 2,
		"movement_transition_after": move_cost,
		"frequency_resets": frequency_resets,
		"frequency_reset_confirmed": frequency_resets.values().all(func(value): return bool(value)),
		"canonical_unchanged": canonical_fingerprint == ItemFingerprintService.semantic_fingerprint(definition),
		"runtime_service": "RelicRuntimeService",
	}


func _preview_frequency_resets() -> Dictionary:
	var result := {}
	for frequency in [
		ItemReactiveEffectData.FREQUENCY_ACTION,
		ItemReactiveEffectData.FREQUENCY_TURN,
		ItemReactiveEffectData.FREQUENCY_ROUND,
		ItemReactiveEffectData.FREQUENCY_COMBAT,
	]:
		result[frequency] = _preview_one_frequency_reset(frequency)
	return result


func _preview_one_frequency_reset(frequency: StringName) -> bool:
	var definition := ItemDefinition.new()
	definition.item_id = StringName("preview_frequency_%s" % frequency)
	definition.display_name = "Sonde de fréquence"
	definition.category = ItemDefinition.Category.RELIC
	definition.stack_limit = 1
	var effect := ItemReactiveEffectData.new()
	effect.trigger_id = ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED
	effect.target_id = ItemReactiveEffectData.TARGET_TRIGGER_HERO
	effect.result_id = ItemReactiveEffectData.RESULT_CURRENT_AP
	effect.value = 1.0
	effect.frequency_id = frequency
	definition.reactive_effects = [effect]
	var catalog := _catalog_with(definition)
	var inventory := RunInventory.new()
	if catalog == null or not inventory.initialize(catalog, 1) \
			or not inventory.try_add(definition.item_id).get("success", false):
		return false
	var hero := Unit.new("Sonde", 0, 100, 10, 6, 3, 20)
	hero.unit_id = StringName("preview_frequency_hero_%s" % frequency)
	var service := RelicRuntimeService.new()
	if not service.initialize(inventory, catalog, [hero]):
		return false
	service.begin_combat([hero])
	if frequency == ItemReactiveEffectData.FREQUENCY_TURN:
		EventBus.turn_started.emit(hero)
	elif frequency == ItemReactiveEffectData.FREQUENCY_ROUND:
		EventBus.round_started.emit(1)
	var first_context := {"trigger_hero": hero, "active_unit": hero, "action_id": &"frequency_action_a"}
	service.process_trigger(ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, first_context)
	service.process_trigger(ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, first_context)
	var after_block := hero.current_ap
	if frequency == ItemReactiveEffectData.FREQUENCY_ACTION:
		first_context["action_id"] = &"frequency_action_b"
	elif frequency == ItemReactiveEffectData.FREQUENCY_TURN:
		EventBus.turn_started.emit(hero)
	elif frequency == ItemReactiveEffectData.FREQUENCY_ROUND:
		EventBus.round_started.emit(2)
	else:
		service.end_combat()
		service.begin_combat([hero])
	service.process_trigger(ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, first_context)
	var reset_applied := hero.current_ap == after_block + 1
	service.dispose()
	return reset_applied


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
