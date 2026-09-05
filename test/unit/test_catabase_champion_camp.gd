extends GutTest

const Factory = preload("res://test/support/factory.gd")
const Camp = preload("res://core/run_content/champion_camp_service.gd")
const ECONOMY_PATH := "res://data/runs/economy/odyssey_economy_profile.tres"
const PROFILE_PATH := "res://data/runs/progression/odyssey/achilles_progression_profile.tres"
const SEED := 8127
var profile: RunEconomyProfile
var merchant: MerchantProfile
var economy: OdysseyRunState
var inventory: RunInventory
var character: CharacterRunState
var equipment: EquipmentService
var camp

func before_each() -> void:
	profile = load(ECONOMY_PATH) as RunEconomyProfile
	merchant = profile.merchant_profile
	economy = OdysseyRunState.new()
	economy.initialize(profile.starting_currency)
	inventory = RunInventory.new()
	assert_true(inventory.initialize(profile.item_catalog))
	for item in profile.starting_items:
		assert_true(inventory.try_add(item.item_id, item.quantity).success)
	character = _character()
	equipment = EquipmentService.new()
	assert_true(equipment.initialize(profile.item_catalog))
	camp = Camp.new()

func after_each() -> void:
	equipment.clear_state_stats(character)
	character.dispose()

func test_current_economy_keeps_consumables_and_funds_equipment_relic_and_forge() -> void:
	assert_eq(economy.currency, 120)
	assert_eq(_quantity(&"minor_healing_potion"), 2)
	assert_eq(_quantity(&"minor_action_scroll"), 1)
	var before := character.unit.attack_power.get_int()
	var equipment_row := _row(&"odyssey_equipment_offer")
	assert_false(equipment_row.targets.is_empty())
	var selected := StringName(equipment_row.targets[0].id)
	var purchase := _buy(&"odyssey_equipment_offer", selected)
	assert_true(purchase.success)
	assert_eq(economy.currency, 60)
	var instance := inventory.get_instance(purchase.instance_ids[0])
	var definition := profile.item_catalog.get_definition(selected)
	assert_true(equipment.equip(inventory, character, instance.instance_id, definition.equipment_slot).success)
	assert_not_null(character.equipment_loadout.get_item(definition.equipment_slot))
	# The three existing victories are the only income used in this direct flow.
	for encounter_path in ["res://data/encounters/catabase_frail_hellspawn_encounter.tres",
		"res://data/encounters/odyssey_room_02_encounter.tres", "res://data/encounters/odyssey_room_03_encounter.tres"]:
		var encounter := load(encounter_path) as EncounterDefinition
		var encounter_id := encounter.encounter_id
		character.champion_progression.begin_encounter()
		var xp := character.champion_progression.award_encounter_xp(encounter_id, encounter.base_xp, true)
		assert_true(xp.granted)
		assert_true(economy.add_currency(profile.victory_currency_reward))
		assert_false(character.champion_progression.award_encounter_xp(encounter_id, encounter.base_xp, true).granted)
	assert_eq(economy.currency, 240)
	var relic_id := StringName(_row(&"odyssey_relic_offer").targets[0].id)
	assert_true(_buy(&"odyssey_relic_offer", relic_id).success)
	assert_eq(economy.currency, 150)
	assert_true(inventory.contains_definition(relic_id))
	assert_true(_buy(&"odyssey_forge_offer", instance.instance_id).success)
	assert_eq(economy.currency, 80)
	assert_true(_buy(&"odyssey_reroll_offer").success)
	assert_eq(economy.currency, 55)
	assert_gt(character.unit.attack_power.get_int(), before)
	assert_eq(_quantity(&"minor_healing_potion"), 2, "Camp transactions do not consume combat potions")

func test_insufficient_funds_full_inventory_and_stale_target_preserve_inventory_and_money() -> void:
	var row := _row(&"odyssey_relic_offer")
	var target := StringName(row.targets[0].id)
	economy.currency = 20
	var inventory_before := inventory.to_snapshot()
	var economy_before := economy.get_snapshot()
	assert_false(_buy(&"odyssey_relic_offer", target).success)
	assert_eq(inventory.to_snapshot(), inventory_before)
	assert_eq(economy.get_snapshot(), economy_before)
	economy.currency = 500
	var full := RunInventory.new()
	assert_true(full.initialize(profile.item_catalog, 1))
	assert_true(full.try_add(&"minor_action_scroll").success)
	var money := economy.currency
	var full_before := full.to_snapshot()
	assert_false(camp.purchase(merchant, economy, character, full, SEED, &"odyssey_relic_offer", target).success)
	assert_eq(full.to_snapshot(), full_before)
	assert_eq(economy.currency, money)
	assert_false(_buy(&"odyssey_relic_offer", &"unknown_item").success)
	assert_eq(economy.currency, money)

func test_already_distributed_reward_cannot_grant_another_item_or_charge_currency() -> void:
	var row := _row(&"odyssey_relic_offer")
	var target := StringName(row.targets[0].id)
	var rewards := OdysseyRewardService.new()
	assert_true(rewards.select_merchant_option(merchant, merchant.get_offer(row.id), target, profile.item_catalog, economy))
	var before := inventory.to_snapshot()
	var money := economy.currency
	assert_false(_buy(row.id, target).success)
	assert_eq(inventory.to_snapshot(), before)
	assert_eq(economy.currency, money)

func test_purchase_signal_cannot_reenter_and_grant_unpaid_second_item() -> void:
	economy.currency = 500
	var row := _row(&"odyssey_equipment_offer")
	var target := StringName(row.targets[0].id)
	var reentrant: Array[Dictionary] = []
	var callback := func() -> void:
		reentrant.append(_buy(&"odyssey_equipment_offer", target))
	inventory.changed.connect(callback)
	assert_true(_buy(&"odyssey_equipment_offer", target).success)
	inventory.changed.disconnect(callback)
	assert_eq(reentrant.size(), 1)
	assert_false(reentrant[0].success)
	assert_eq(economy.currency, 440)
	assert_eq(economy.purchase_counts.get(&"odyssey_equipment_offer"), 1)

func test_reroll_and_generated_options_survive_economy_snapshot() -> void:
	var first: Array = _row(&"odyssey_equipment_offer").targets
	assert_eq(_row(&"odyssey_equipment_offer").targets, first)
	assert_true(_buy(&"odyssey_reroll_offer").success)
	assert_eq(economy.currency, 95)
	assert_eq(economy.reroll_counts.get(merchant.merchant_id), 1)
	var rerolled: Array = _row(&"odyssey_equipment_offer").targets
	var restored := OdysseyRunState.new()
	assert_true(restored.restore_snapshot(economy.get_snapshot()))
	var presentation: Dictionary = camp.presentation(merchant, restored, character, inventory, SEED)
	assert_eq(_find_row(presentation, &"odyssey_equipment_offer").targets, rerolled)
	assert_eq(restored.get_snapshot(), economy.get_snapshot())

func test_forge_improves_positive_bonuses_only_without_heal_and_roundtrips() -> void:
	economy.currency = 500
	var added := inventory.try_add(&"odyssey_phthia_cuirass")
	var instance := inventory.get_instance(added.instance_ids[0])
	assert_true(equipment.equip(inventory, character, instance.instance_id, ItemDefinition.EquipmentSlot.ARMOR).success)
	character.unit.current_hp = 50
	var max_before := character.unit.max_hp.get_int()
	var prowess_before := character.unit.attack_power.get_int()
	assert_eq(character.unit.armure.get_int(), 30)
	assert_true(_buy(&"odyssey_forge_offer", instance.instance_id).success)
	assert_eq(instance.forge_level, 1)
	assert_eq(economy.get_forge_level(instance.instance_id), 1)
	assert_gt(character.unit.max_hp.get_int(), max_before)
	assert_eq(character.unit.armure.get_int(), 36)
	assert_eq(character.unit.attack_power.get_int(), prowess_before, "Negative modifier is not amplified")
	assert_eq(character.unit.current_hp, 50)
	assert_true(equipment.rebuild_state(character))
	assert_eq(character.unit.armure.get_int(), 36, "Rebuild does not duplicate forge modifiers")
	var copied := instance.duplicate_instance()
	assert_eq(copied.forge_level, 1)
	assert_eq(copied.instance_id, instance.instance_id)
	var restored := ItemInstance.from_snapshot(instance.to_snapshot(), profile.item_catalog)
	assert_not_null(restored)
	assert_eq(restored.forge_level, 1)
	assert_true(equipment.unequip(inventory, character, ItemDefinition.EquipmentSlot.ARMOR).success)
	var inventory_copy := RunInventory.new()
	assert_true(inventory_copy.initialize(profile.item_catalog))
	assert_true(inventory_copy.restore_snapshot(inventory.to_snapshot()))
	assert_eq(inventory_copy.get_instance(instance.instance_id).forge_level, 1)
	assert_true(equipment.equip(inventory, character, instance.instance_id, ItemDefinition.EquipmentSlot.ARMOR).success)
	assert_eq(character.unit.current_hp, 50)
	assert_true(_buy(&"odyssey_forge_offer", instance.instance_id).success)
	assert_eq(instance.forge_level, 2)
	assert_eq(character.unit.armure.get_int(), 42)
	var money := economy.currency
	assert_false(_buy(&"odyssey_forge_offer", instance.instance_id).success)
	assert_eq(economy.currency, money)

func test_forge_rejects_overflow_tier_and_invalid_snapshot() -> void:
	economy.currency = 500
	var added := inventory.try_add(&"odyssey_phthia_cuirass")
	var instance := inventory.get_instance(added.instance_ids[0])
	instance.forge_level = 1
	var altered := merchant.duplicate(true) as MerchantProfile
	altered.get_offer(&"odyssey_forge_offer").forge_tier_delta = 2
	assert_false(camp.purchase(altered, economy, character, inventory, SEED, &"odyssey_forge_offer", instance.instance_id).success)
	assert_eq(instance.forge_level, 1)
	assert_eq(economy.currency, 500)
	var snapshot := instance.to_snapshot()
	snapshot.forge_level = 3
	assert_null(ItemInstance.from_snapshot(snapshot, profile.item_catalog))
	snapshot.definition_id = "minor_healing_potion"
	snapshot.forge_level = 1
	assert_null(ItemInstance.from_snapshot(snapshot, profile.item_catalog))

func test_three_lessons_add_points_without_bypassing_level_gates() -> void:
	economy.currency = 1000
	for index in range(3):
		assert_true(_buy(&"odyssey_chiron_lesson").success)
	assert_eq(economy.currency, 700)
	assert_eq(character.champion_progression.purchased_mastery_points, 3)
	assert_eq(character.champion_progression.unspent_mastery_points, 3)
	assert_eq(character.champion_progression.current_level, 1)
	assert_false(_buy(&"odyssey_chiron_lesson").success)
	assert_eq(economy.currency, 700)
	for node in character.get_mastery_nodes():
		if node.node_type in [SkillTreeNodeData.NodeType.CAPSTONE, SkillTreeNodeData.NodeType.SPECIALIST_SUMMIT,
			SkillTreeNodeData.NodeType.MYTHIC_JUNCTION, SkillTreeNodeData.NodeType.APOTHEOSIS]:
			var decision := character.evaluate_mastery_node(node.upgrade_id)
			assert_false(decision.allowed, node.display_name)
			assert_eq(decision.reason_id, "LEVEL_GATE", node.display_name)

func test_reorientation_refunds_leaf_but_never_a_required_root() -> void:
	economy.currency = 1000
	assert_true(_buy(&"odyssey_chiron_lesson").success)
	assert_true(_buy(&"odyssey_chiron_lesson").success)
	assert_true(character.purchase_mastery_node(&"achilles_wrath_focused_fury").purchased)
	assert_true(character.purchase_mastery_node(&"achilles_wrath_opening_slash").purchased)
	var before := character.champion_progression.to_snapshot()
	var money := economy.currency
	assert_false(_buy(&"odyssey_reorientation_offer", &"achilles_wrath_focused_fury").success)
	assert_eq(character.champion_progression.to_snapshot(), before)
	assert_eq(economy.currency, money)
	assert_true(_buy(&"odyssey_reorientation_offer", &"achilles_wrath_opening_slash").success)
	assert_eq(economy.currency, money - 55)
	assert_true(character.champion_progression.selected_node_ids.has(&"achilles_wrath_focused_fury"))
	assert_false(character.champion_progression.selected_node_ids.has(&"achilles_wrath_opening_slash"))
	assert_eq(character.champion_progression.unspent_mastery_points, 1)
	assert_eq(character.champion_progression.purchased_mastery_points, 2)
	assert_true(character.champion_progression.restore_snapshot(character.champion_progression.to_snapshot()))

func test_heal_cost_and_dead_or_full_hp_refusal() -> void:
	economy.currency = 300
	character.unit.current_hp = character.unit.max_hp.get_int()
	assert_false(_buy(&"odyssey_heal_offer").success)
	assert_eq(economy.currency, 300)
	character.unit.current_hp = 20
	assert_true(_buy(&"odyssey_heal_offer").success)
	assert_eq(character.unit.current_hp, 48)
	assert_eq(economy.currency, 270)
	character.unit.is_alive = false
	character.unit.current_hp = 0
	assert_false(_row(&"odyssey_heal_offer").available)
	assert_false(_buy(&"odyssey_heal_offer").success)
	assert_eq(economy.currency, 270)

func _character() -> CharacterRunState:
	var progression := load(PROFILE_PATH) as CharacterProgressionProfile
	var data := UnitData.new()
	data.unit_id = &"achilles"
	data.unit_name = "Achille"
	data.spells.assign(progression.spells)
	data.progression_profile = progression
	var unit := Factory.make_unit("Achille")
	unit.unit_id = &"achilles"
	unit.character_data = data
	var result := CharacterRunState.new()
	assert_true(result.initialize(unit, data, 4, progression))
	return result

func _row(id: StringName) -> Dictionary:
	return _find_row(camp.presentation(merchant, economy, character, inventory, SEED), id)

func _find_row(presentation: Dictionary, id: StringName) -> Dictionary:
	for row in presentation.get("offers", []):
		if StringName(row.id) == id:
			return row
	return {}

func _buy(id: StringName, target: StringName = &"") -> Dictionary:
	return camp.purchase(merchant, economy, character, inventory, SEED, id, target)

func _quantity(id: StringName) -> int:
	var result := 0
	for instance in inventory.get_slots():
		if instance != null and instance.definition_id == id:
			result += instance.quantity
	return result
