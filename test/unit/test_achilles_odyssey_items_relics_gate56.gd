extends GutTest

const Factory = preload("res://test/support/factory.gd")
const CATALOG_PATH := "res://data/items/catalogs/odyssey_item_catalog.tres"
const DEFAULT_CATALOG_PATH := "res://data/items/catalogs/default_item_catalog.tres"

const EQUIPMENT_IDS: Array[StringName] = [
	&"odyssey_xiphos_of_peleus", &"odyssey_line_breaker_kopis",
	&"odyssey_pelion_bow", &"odyssey_scyros_short_bow",
	&"odyssey_aeacus_shield_blade", &"odyssey_phthia_cuirass",
	&"odyssey_myrmidon_linothorax", &"odyssey_duelist_breastplate",
	&"odyssey_hunter_mantle", &"odyssey_wave_cuirass",
	&"odyssey_thetis_bracelet", &"odyssey_peleus_seal",
	&"odyssey_phthia_knot", &"odyssey_chiron_ferret",
	&"odyssey_patroclus_brooch", &"odyssey_myrmidon_crest",
]
const RELIC_IDS: Array[StringName] = [
	&"odyssey_patroclus_ashes", &"odyssey_hephaestus_nail",
	&"odyssey_centaur_step", &"odyssey_athena_mirror",
	&"odyssey_pelion_shard", &"odyssey_thetis_anchor",
	&"odyssey_thetis_heel", &"odyssey_fates_thread",
]

var _services: Array[RelicRuntimeService] = []


func after_each() -> void:
	for service in _services:
		service.dispose()
	_services.clear()


func test_catalog_is_explicit_exact_and_globally_excluded() -> void:
	var catalog := _catalog()
	assert_true(catalog.auto_discovery_directories.is_empty())
	assert_eq(catalog.definitions.size(), 26)
	assert_eq(catalog.get_definitions().size(), 26)
	assert_eq(catalog.get_definitions().filter(
		func(item: ItemDefinition): return item.is_equippable()
	).size(), 16)
	assert_eq(catalog.get_definitions().filter(
		func(item: ItemDefinition): return item.is_relic()
	).size(), 8)
	assert_eq(
		catalog.get_definitions().map(func(item: ItemDefinition): return item.item_id),
		EQUIPMENT_IDS + RELIC_IDS + [&"minor_healing_potion", &"minor_action_scroll"],
	)
	var default_catalog := load(DEFAULT_CATALOG_PATH) as ItemCatalog
	assert_true(default_catalog.excluded_discovery_directories.has(
		"res://data/items/definitions/odyssey"
	))
	assert_true(default_catalog.rebuild_index())
	for item_id in EQUIPMENT_IDS + RELIC_IDS:
		assert_null(default_catalog.get_definition(item_id), item_id)


func test_all_equipment_values_match_the_mandate() -> void:
	_assert_stat(&"odyssey_xiphos_of_peleus", &"attack_power", 0.15, 1)
	_assert_spell(&"odyssey_xiphos_of_peleus", &"achilles_peleid_strike", "damage_percent", 0.20)
	_assert_spell(&"odyssey_xiphos_of_peleus", &"achilles_bronze_guard", "healing_and_shield_percent", -0.15)
	_assert_stat(&"odyssey_line_breaker_kopis", &"attack_power", 0.10, 1)
	var kopis := _definition(&"odyssey_line_breaker_kopis").spell_modifiers[0] as ItemSpellModifierData
	assert_almost_eq(kopis.damage_percent, 0.20, 0.0001)
	assert_true(kopis.require_target_moved_or_collided)
	_assert_stat(&"odyssey_pelion_bow", &"attack_power", 0.12, 1)
	_assert_spell(&"odyssey_pelion_bow", &"achilles_pelion_shot", "range_bonus", 1)
	_assert_spell(&"odyssey_pelion_bow", &"achilles_pelion_shot", "minimum_range_override", 3)
	_assert_stat(&"odyssey_scyros_short_bow", &"attack_power", 0.10, 1)
	_assert_spell(&"odyssey_scyros_short_bow", &"achilles_pelion_shot", "damage_percent", 0.25)
	_assert_spell(&"odyssey_scyros_short_bow", &"achilles_pelion_shot", "target_distance_at_most", 4)
	_assert_spell(&"odyssey_scyros_short_bow", &"achilles_pelion_shot", "range_bonus", -1)
	_assert_stat(&"odyssey_aeacus_shield_blade", &"max_hp", 0.10, 1)
	_assert_stat(&"odyssey_aeacus_shield_blade", &"attack_power", 0.10, 1)
	_assert_spell(&"odyssey_aeacus_shield_blade", &"achilles_bronze_guard", "healing_and_shield_percent", 0.15)
	_assert_stat(&"odyssey_phthia_cuirass", &"max_hp", 0.20, 1)
	_assert_stat(&"odyssey_phthia_cuirass", &"armure", 30.0, 0)
	_assert_stat(&"odyssey_phthia_cuirass", &"attack_power", -0.10, 1)
	_assert_stat(&"odyssey_myrmidon_linothorax", &"max_hp", 0.10, 1)
	_assert_stat(&"odyssey_myrmidon_linothorax", &"armure", 20.0, 0)
	_assert_spell(&"odyssey_myrmidon_linothorax", &"achilles_fulminant_dash", "range_bonus", 1)
	_assert_spell(&"odyssey_myrmidon_linothorax", &"achilles_fulminant_dash", "minimum_prior_moved_cells", 2)
	_assert_stat(&"odyssey_duelist_breastplate", &"max_hp", 0.10, 1)
	_assert_stat(&"odyssey_duelist_breastplate", &"armure", 25.0, 0)
	_assert_spell(&"odyssey_duelist_breastplate", &"achilles_peleid_strike", "damage_percent", 0.20)
	assert_true((_spell(&"odyssey_duelist_breastplate", &"achilles_peleid_strike")).require_hp_lost_since_previous_activation)
	_assert_stat(&"odyssey_hunter_mantle", &"max_hp", 0.10, 1)
	_assert_stat(&"odyssey_hunter_mantle", &"attack_power", 0.10, 1)
	_assert_spell(&"odyssey_hunter_mantle", &"achilles_pelion_shot", "damage_percent", 0.15)
	_assert_spell(&"odyssey_hunter_mantle", &"achilles_pelion_shot", "minimum_mp_spent", 2)
	_assert_stat(&"odyssey_wave_cuirass", &"max_hp", 0.15, 1)
	assert_almost_eq(_definition(&"odyssey_wave_cuirass").guard_effectiveness_projectile, 1.25, 0.0001)
	assert_almost_eq(_definition(&"odyssey_wave_cuirass").guard_effectiveness_melee, 0.85, 0.0001)
	_assert_stat(&"odyssey_thetis_bracelet", &"max_hp", 0.20, 1)
	_assert_spell(&"odyssey_thetis_bracelet", &"achilles_bronze_guard", "healing_and_shield_percent", 0.20)
	_assert_stat(&"odyssey_peleus_seal", &"attack_power", 0.15, 1)
	_assert_spell(&"odyssey_peleus_seal", &"achilles_peleid_strike", "damage_percent", 0.15)
	_assert_spell(&"odyssey_peleus_seal", &"achilles_peleid_strike", "target_hp_at_or_above", 0.50)
	_assert_stat(&"odyssey_phthia_knot", &"max_hp", -0.10, 1)
	_assert_spell(&"odyssey_phthia_knot", &"achilles_fulminant_dash", "range_bonus", 1)
	_assert_stat(&"odyssey_chiron_ferret", &"attack_power", 0.12, 1)
	_assert_spell(&"odyssey_chiron_ferret", &"achilles_pelion_shot", "damage_percent", 0.20)
	_assert_spell(&"odyssey_chiron_ferret", &"achilles_pelion_shot", "target_distance_at_least", 6)
	_assert_stat(&"odyssey_patroclus_brooch", &"max_hp", 0.15, 1)
	_assert_stat(&"odyssey_patroclus_brooch", &"attack_power", 0.10, 1)
	_assert_spell(&"odyssey_patroclus_brooch", &"achilles_peleid_strike", "damage_percent", 0.15)
	assert_true((_spell(&"odyssey_patroclus_brooch", &"achilles_peleid_strike")).require_guard_destroyed)
	_assert_stat(&"odyssey_myrmidon_crest", &"max_hp", 0.10, 1)
	_assert_stat(&"odyssey_myrmidon_crest", &"attack_power", 0.12, 1)
	_assert_stat(&"odyssey_myrmidon_crest", &"initiative", 2.0, 0)


func test_equipment_forbids_permanent_economy_global_range_and_active_content() -> void:
	for item_id in EQUIPMENT_IDS:
		var definition := _definition(item_id)
		assert_true(definition.reactive_effects.is_empty(), item_id)
		assert_eq(definition.use_effect, ItemDefinition.UseEffect.NONE, item_id)
		for modifier in definition.stat_modifiers:
			assert_false(modifier.stat_id in [&"max_ap", &"max_mp", &"esquive"], item_id)
		for modifier_value in definition.spell_modifiers:
			var modifier := modifier_value as ItemSpellModifierData
			if modifier.range_bonus != 0 or modifier.minimum_range_override >= 0:
				assert_ne(modifier.target_spell_id, &"", item_id)


func test_knot_drawback_really_applies_through_equipment_runtime() -> void:
	var unit := Factory.make_unit("Achille")
	var definition := _definition(&"odyssey_phthia_knot")
	var instance := ItemInstance.new()
	assert_true(instance.initialize(definition.item_id, 1, &"knot_runtime"))
	assert_true(EquipmentStatService.new().apply_item(unit, instance, definition))
	assert_eq(unit.max_hp.get_int(), 90)
	assert_eq(unit.current_hp, 90)


func test_relics_are_registry_only_with_typed_valid_parameters() -> void:
	var registry := RelicEffectRegistry.new()
	for item_id in RELIC_IDS:
		var definition := _definition(item_id)
		assert_true(definition.is_relic(), item_id)
		assert_true(definition.compatible_character_ids.is_empty(), item_id)
		assert_true(definition.stat_modifiers.is_empty(), item_id)
		assert_true(definition.spell_modifiers.is_empty(), item_id)
		for effect in definition.reactive_effects:
			assert_true(registry.validate_effect(effect).is_empty(), "%s: %s" % [item_id, registry.validate_effect(effect)])
			for parameter in effect.parameters:
				assert_true(parameter.is_valid(), "%s/%s" % [item_id, parameter.parameter_id])
	var mirror := _definition(&"odyssey_athena_mirror").reactive_effects[0]
	assert_eq(mirror.reaction_group, &"projectile_counter")
	assert_false(mirror.stackable)
	var anchor := _definition(&"odyssey_thetis_anchor").reactive_effects[0]
	assert_eq(anchor.reaction_group, &"guard_dash_conversion")
	assert_false(anchor.stackable)


func test_reaction_policy_uses_priority_then_persistent_order_without_item_branching() -> void:
	var lower := ItemReactiveEffectData.new()
	lower.reaction_group = &"projectile_counter"
	lower.stackable = false
	lower.priority = 10
	var higher := ItemReactiveEffectData.new()
	higher.reaction_group = &"projectile_counter"
	higher.stackable = false
	higher.priority = 20
	var resolution := RelicEffectRegistry.new().resolve_reaction_candidates([
		{"effect": lower, "persistent_order": 0, "stable_id": &"first"},
		{"effect": higher, "persistent_order": 9, "stable_id": &"second"},
	])
	assert_eq((resolution.selected[0] as Dictionary).stable_id, &"second")
	assert_eq((resolution.suppressed[0] as Dictionary).stable_id, &"first")
	assert_eq((resolution.suppressed[0] as Dictionary).suppression_reason, &"reaction_group_conflict")


func test_priority_parameters_copy_fingerprint_and_studio_validation_round_trip() -> void:
	var source := _definition(&"odyssey_thetis_anchor")
	var copy := ItemDeepCopyService.new().duplicate_definition(source)
	assert_eq(copy.reactive_effects[0].priority, 100)
	assert_eq(copy.reactive_effects[0].reaction_group, &"guard_dash_conversion")
	assert_ne(copy.reactive_effects[0].parameters[0], source.reactive_effects[0].parameters[0])
	assert_eq(
		ItemFingerprintService.semantic_fingerprint(copy),
		ItemFingerprintService.semantic_fingerprint(source),
	)
	var report := ItemStudioValidationService.new().validate_interactive(source, null)
	assert_true(report.valid, str(report.messages))


func test_talon_executes_exact_emergency_guard_once_per_combat() -> void:
	var setup := _runtime_with_relic(&"odyssey_thetis_heel")
	var hero := setup.hero as Unit
	hero.current_hp = 20
	var reports := (setup.service as RelicRuntimeService).process_trigger(
		ItemReactiveEffectData.TRIGGER_HP_THRESHOLD_CROSSED,
		{"trigger_hero": hero, "hp_before_ratio": 0.30, "hp_after_ratio": 0.20},
	)
	assert_true(reports[0].triggered, str(reports[0]))
	assert_eq(hero.current_shield, 18)
	var second := (setup.service as RelicRuntimeService).process_trigger(
		ItemReactiveEffectData.TRIGGER_HP_THRESHOLD_CROSSED,
		{"trigger_hero": hero, "hp_before_ratio": 0.30, "hp_after_ratio": 0.20},
	)
	assert_false(second[0].triggered)


func test_mirror_uses_only_the_injected_explicit_projectile_classification() -> void:
	var inventory := RunInventory.new()
	assert_true(inventory.initialize(_catalog()))
	assert_true(inventory.try_add(&"odyssey_athena_mirror").get("success", false))
	var hero := Factory.make_unit("Achille")
	var enemy := Factory.make_unit("Archer", 1)
	var service := RelicRuntimeService.new()
	_services.append(service)
	assert_true(service.initialize(
		inventory,
		_catalog(),
		[hero],
		load("res://data/characters/achilles/attack_classifications.tres") \
			as CombatActionClassificationCatalogData,
	))
	service.begin_combat([hero, enemy])
	var intents: Array[Dictionary] = []
	service.tactical_intent_emitted.connect(
		func(intent: Dictionary): intents.append(intent)
	)
	EventBus.hit_resolved.emit(CombatEventFact.create(
		&"hit_resolved", hero, enemy, {
			"ability_id": &"ability_without_classification",
			"amount_resolved": 10, "amount_absorbed": 10, "guard_absorbed": true,
			"source_absorption": [{"source_id": &"guard", "tags": [&"guard"], "amount_absorbed": 10}],
		}
	))
	assert_true(intents.is_empty())
	EventBus.hit_resolved.emit(CombatEventFact.create(
		&"hit_resolved", hero, enemy, {
			"ability_id": &"achilles_peleid_strike",
			"amount_resolved": 10, "amount_absorbed": 10, "guard_absorbed": true,
			"source_absorption": [{"source_id": &"guard", "tags": [&"guard"], "amount_absorbed": 10}],
		}
	))
	assert_true(intents.is_empty(), "Une classification MELEE ne déclenche pas Miroir.")
	EventBus.hit_resolved.emit(CombatEventFact.create(
		&"hit_resolved", hero, enemy, {
			"ability_id": &"achilles_pelion_shot",
			"amount_resolved": 10, "amount_absorbed": 10, "guard_absorbed": true,
			"source_absorption": [{"source_id": &"guard", "tags": [&"guard"], "amount_absorbed": 10}],
		}
	))
	assert_eq(intents.size(), 1)
	assert_eq(intents[0].intent_id, &"projectile_counter")
	assert_almost_eq(float((intents[0].parameters as Dictionary).reflect_ratio), 0.50, 0.0001)


func test_fates_thread_executes_one_hp_twenty_percent_guard_and_consumption() -> void:
	var setup := _runtime_with_relic(&"odyssey_fates_thread")
	var hero := setup.hero as Unit
	hero.current_hp = 0
	var reports := (setup.service as RelicRuntimeService).process_trigger(
		ItemReactiveEffectData.TRIGGER_LETHAL_HIT,
		{"trigger_hero": hero, "damage_source": Factory.make_unit("Ennemi", 1)},
	)
	assert_true(reports[0].triggered, str(reports[0]))
	assert_eq(hero.current_hp, 1)
	assert_eq(hero.current_shield, 20)
	assert_false((setup.inventory as RunInventory).contains_definition(&"odyssey_fates_thread"))


func test_intent_is_stable_and_synchronous_recursion_is_blocked() -> void:
	var setup := _runtime_with_relic(&"odyssey_patroclus_ashes")
	var hero := setup.hero as Unit
	var enemy := Factory.make_unit("Ennemi", 1)
	var nested_results: Array = []
	(setup.service as RelicRuntimeService).tactical_intent_emitted.connect(
		func(_intent: Dictionary): nested_results.append(
			(setup.service as RelicRuntimeService).process_trigger(
				ItemReactiveEffectData.TRIGGER_HP_LOST,
				{"trigger_hero": hero, "damage_source": enemy, "enemy_source": true, "hp_loss": 15},
			)
		)
	)
	var reports := (setup.service as RelicRuntimeService).process_trigger(
		ItemReactiveEffectData.TRIGGER_HP_LOST,
		{"trigger_hero": hero, "damage_source": enemy, "enemy_source": true, "hp_loss": 15},
	)
	assert_true(reports[0].triggered, str(reports[0]))
	assert_eq((reports[0].tactical_intent as Dictionary).intent_id, &"vengeance_mark")
	assert_eq((reports[0].tactical_intent as Dictionary).damage_source_id, enemy.get_runtime_stable_id())
	assert_eq(nested_results.size(), 1)
	assert_true((nested_results[0] as Array).is_empty())


func test_required_shared_hooks_are_explicitly_described() -> void:
	assert_has(
		_definition(&"odyssey_wave_cuirass").runtime_requirements(),
		&"guard_attack_classification_hook",
	)
	assert_has(
		_spell(&"odyssey_pelion_bow", &"achilles_pelion_shot").runtime_requirements(),
		&"minimum_range_override_hook",
	)
	assert_has(
		_spell(&"odyssey_myrmidon_linothorax", &"achilles_fulminant_dash").runtime_requirements(),
		&"prior_moved_cells_fact",
	)
	assert_has(
		_spell(&"odyssey_hunter_mantle", &"achilles_pelion_shot").runtime_requirements(),
		&"mp_spent_fact",
	)
	assert_has(
		_spell(&"odyssey_patroclus_brooch", &"achilles_peleid_strike").runtime_requirements(),
		&"guard_destroyed_fact",
	)


func _runtime_with_relic(item_id: StringName) -> Dictionary:
	var inventory := RunInventory.new()
	assert_true(inventory.initialize(_catalog()))
	assert_true(inventory.try_add(item_id).get("success", false))
	var hero := Factory.make_unit("Achille")
	var service := RelicRuntimeService.new()
	_services.append(service)
	assert_true(service.initialize(inventory, _catalog(), [hero]))
	service.begin_combat([hero])
	return {"inventory": inventory, "hero": hero, "service": service}


func _catalog() -> ItemCatalog:
	var catalog := load(CATALOG_PATH) as ItemCatalog
	assert_not_null(catalog)
	assert_true(catalog.rebuild_index(), str(catalog.validate_catalog()))
	return catalog


func _definition(item_id: StringName) -> ItemDefinition:
	var definition := _catalog().get_definition(item_id)
	assert_not_null(definition, item_id)
	return definition


func _spell(item_id: StringName, spell_id: StringName) -> ItemSpellModifierData:
	for value in _definition(item_id).spell_modifiers:
		var modifier := value as ItemSpellModifierData
		if modifier != null and modifier.target_spell_id == spell_id:
			return modifier
	assert_true(false, "Modifier %s/%s absent" % [item_id, spell_id])
	return null


func _assert_spell(
		item_id: StringName,
		spell_id: StringName,
		property_name: String,
		expected
	) -> void:
	var modifier := _spell(item_id, spell_id)
	var actual = modifier.get(property_name)
	if expected is float:
		assert_almost_eq(float(actual), float(expected), 0.0001, "%s/%s" % [item_id, property_name])
	else:
		assert_eq(actual, expected, "%s/%s" % [item_id, property_name])


func _assert_stat(
		item_id: StringName,
		stat_id: StringName,
		expected: float,
		expected_type: int
	) -> void:
	for modifier in _definition(item_id).stat_modifiers:
		if modifier.stat_id == stat_id:
			assert_almost_eq(modifier.value, expected, 0.0001, "%s/%s" % [item_id, stat_id])
			assert_eq(modifier.modifier_type, expected_type, "%s/%s type" % [item_id, stat_id])
			return
	assert_true(false, "Stat %s/%s absente" % [item_id, stat_id])
