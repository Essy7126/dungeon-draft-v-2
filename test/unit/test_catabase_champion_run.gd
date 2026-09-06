extends GutTest

const MANAGER = preload("res://core/game_manager.gd")
const RUN: RunData = preload("res://data/runs/odyssey.tres")
var manager
var state: CharacterRunState


func before_each() -> void:
	manager = MANAGER.new()
	manager._ready()
	assert_true(manager._prepare_preconfigured_run(RUN, manager.resolve_run_hero_data(RUN).heroes))
	manager.current_room_index = 0
	state = manager.get_ordered_character_states()[0]


func after_each() -> void:
	manager.cleanup_run_state()
	manager._exit_tree()
	manager.free()


func test_current_catabase_keeps_five_actual_encounters_and_canonical_chassis() -> void:
	assert_eq(manager.rooms.size(), 5)
	assert_true(state.uses_champion_progression())
	assert_eq(state.unit.max_hp.get_int(), 110)
	assert_eq(state.unit.attack_power.get_int(), 18)
	assert_eq(state.unit.max_ap.get_int(), 6)
	assert_eq(state.unit.max_mp.get_int(), 3)
	assert_eq(state.unit.initiative.get_int(), 14)
	assert_eq(state.loadout.get_known_spells().size(), 4)
	assert_eq(manager.get_current_encounter_definition().resource_path, "res://data/encounters/catabase_frail_hellspawn_encounter.tres")
	var xp: Array[int] = []
	for room in manager.rooms:
		xp.append(room.get_encounter_for_wave(0).base_xp)
	assert_eq(xp, [100, 120, 140, 160, 180])
	assert_not_null(manager.get_item_catalog().get_definition(&"minor_healing_potion"))


func test_three_victories_advance_champion_to_four_once_without_spell_xp() -> void:
	for index in range(3):
		manager.current_room_index = index
		manager._room_outcome_resolved = false
		manager.begin_combat_report()
		manager.on_battle_won()
		var xp: int = state.champion_progression.current_xp
		manager.on_battle_won()
		assert_eq(state.champion_progression.current_xp, xp, "Repeated victory cannot grant XP twice")
	assert_eq(state.champion_progression.current_xp, 360)
	assert_eq(state.champion_progression.current_level, 4)
	assert_eq(state.champion_progression.unspent_attribute_points, 3)
	assert_eq(state.champion_progression.unspent_mastery_points, 3)
	assert_true(state.get_pending_progression_choices().is_empty())
	assert_eq(manager.get_champion_camp_snapshot().currency, 300)


func test_glory_is_accepted_before_combat_and_checked_against_real_item_use() -> void:
	assert_true(manager.set_current_glory_challenge_accepted(true))
	manager.begin_combat_report()
	assert_false(manager.set_current_glory_challenge_accepted(false))
	state.unit.current_hp = 70
	var potion: ItemInstance
	for item in manager.run_inventory.get_slots():
		if item != null and item.definition_id == &"minor_healing_potion":
			potion = item
	assert_not_null(potion)
	assert_true(manager.use_inventory_item(potion.instance_id, state.character_id).success)
	manager.on_battle_won()
	assert_eq(state.champion_progression.current_xp, 100)
	assert_false(manager.get_last_champion_progression_results().glory_succeeded)


func test_glory_success_and_wisdom_are_applied_only_to_the_next_encounter() -> void:
	assert_true(manager.set_current_glory_challenge_accepted(true))
	manager.begin_combat_report()
	manager.on_battle_won()
	assert_eq(state.champion_progression.current_xp, 130)
	assert_true(manager.spend_champion_attribute(state.character_id, &"wisdom"))
	assert_eq(state.champion_progression.current_xp, 130)
	manager.current_room_index = 1
	manager._room_outcome_resolved = false
	manager.begin_combat_report()
	assert_false(manager.spend_champion_attribute(state.character_id, &"vitality"))
	manager.on_battle_won()
	assert_eq(state.champion_progression.current_xp, 262)
	var result: Dictionary = manager.get_last_champion_progression_results().character_results[state.character_id]
	assert_eq(result.wisdom_bonus_xp, 12)
	assert_eq(result.gained_xp, 132)


func test_legacy_champion_save_is_explicitly_refused_without_mutation() -> void:
	var before: Dictionary = manager.get_inventory_equipment_snapshot()
	var legacy := before.duplicate(true)
	legacy.version = 3
	assert_false(manager.restore_inventory_equipment_snapshot(legacy))
	assert_eq(manager.last_restore_error, &"CHAMPION_LEGACY_SAVE_INCOMPATIBLE")
	assert_eq(manager.get_inventory_equipment_snapshot(), before)


func test_champion_snapshot_round_trip_preserves_build_equipment_and_generated_shop() -> void:
	manager.begin_combat_report()
	manager.on_battle_won()
	assert_true(manager.spend_champion_attribute(state.character_id, &"vitality"))
	var root_node: SkillTreeNodeData = state.get_mastery_nodes().filter(func(node: SkillTreeNodeData) -> bool: return node.node_type == SkillTreeNodeData.NodeType.ROOT)[0]
	assert_true(manager.purchase_champion_mastery(state.character_id, root_node.upgrade_id).purchased)
	var shop: Dictionary = manager.get_champion_camp_snapshot()
	var before: Dictionary = manager.get_inventory_equipment_snapshot()
	var json_round_trip: Dictionary = JSON.parse_string(JSON.stringify(before))
	state.unit.current_hp -= 10
	assert_true(manager.restore_inventory_equipment_snapshot(json_round_trip), str(manager.last_restore_error))
	assert_eq(JSON.parse_string(JSON.stringify(manager.get_inventory_equipment_snapshot())), json_round_trip)
	assert_eq(state.unit.current_hp, int(before.progression[str(state.character_id)].champion_progression.current_hp))
	assert_eq(manager.get_champion_camp_snapshot(), shop)
	assert_eq(state.unit.mastery_nodes.size(), 1)


func test_defeat_does_not_grant_champion_xp_or_currency() -> void:
	manager.begin_combat_report()
	manager.on_battle_lost()
	assert_eq(state.champion_progression.current_xp, 0)
	assert_true(state.champion_progression.awarded_encounter_ids.is_empty())
	assert_eq(manager._odyssey_run_state.currency, 120)


func test_snapshot_preserves_equipped_forge_and_rejected_restore_leaves_live_state_untouched() -> void:
	manager.begin_combat_report()
	manager.on_battle_won()
	assert_true(manager.spend_champion_attribute(state.character_id, &"vitality"))
	var added: Dictionary = manager.run_inventory.try_add(&"odyssey_phthia_cuirass")
	assert_true(added.success)
	var instance_id := StringName(added.instance_ids[0])
	assert_true(manager.equip_inventory_item(instance_id, state.character_id, ItemDefinition.EquipmentSlot.ARMOR).success)
	assert_true(manager.purchase_champion_camp_offer(&"odyssey_forge_offer", instance_id).success)
	state.unit.current_hp = state.unit.max_hp.get_int() - 7
	var before: Dictionary = manager.get_inventory_equipment_snapshot()
	var max_hp := state.unit.max_hp.get_int()
	var armor := state.unit.armure.get_int()
	var hp_events: Array[bool] = []
	var on_hp_changed := func(_unit: Unit) -> void: hp_events.append(true)
	state.unit.hp_changed.connect(on_hp_changed)
	var invalid := before.duplicate(true)
	invalid.progression[str(state.character_id)].champion_progression.current_hp = max_hp + 1
	assert_false(manager.restore_inventory_equipment_snapshot(invalid))
	assert_eq(manager.last_restore_error, &"INVALID_CHAMPION_PROGRESSION")
	assert_eq(manager.get_inventory_equipment_snapshot(), before)
	assert_true(hp_events.is_empty(), "Rejected save cannot emit live HP events")
	assert_eq(state.unit.max_hp.get_int(), max_hp)
	assert_eq(state.unit.armure.get_int(), armor)
	state.unit.hp_changed.disconnect(on_hp_changed)
	assert_true(manager.unequip_inventory_item(state.character_id, ItemDefinition.EquipmentSlot.ARMOR).success)
	assert_true(manager.restore_inventory_equipment_snapshot(JSON.parse_string(JSON.stringify(before))), str(manager.last_restore_error))
	var restored := state.equipment_loadout.get_item(ItemDefinition.EquipmentSlot.ARMOR)
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.instance_id, instance_id)
		assert_eq(restored.forge_level, 1)
	assert_eq(state.unit.max_hp.get_int(), max_hp)
	assert_eq(state.unit.armure.get_int(), armor)
	assert_eq(state.unit.current_hp, max_hp - 7)
	assert_eq(JSON.parse_string(JSON.stringify(manager.get_inventory_equipment_snapshot())), JSON.parse_string(JSON.stringify(before)))


func test_four_equipment_rewards_reach_black_temple_and_only_fifth_victory_ends_run() -> void:
	assert_eq(manager.rooms.size(), 5)
	var selected_ids: Array[StringName] = []
	for index in range(manager.rooms.size()):
		assert_eq(manager.current_room_index, index)
		assert_eq(manager.is_final_room(), index == 4)
		manager._room_outcome_resolved = false
		manager.begin_combat_report()
		manager.on_battle_won()
		var report: CombatReport = manager.get_current_combat_report()
		assert_not_null(report)
		if report == null:
			return
		assert_true(report.finalized and report.victory)
		if index < 4:
			assert_false(manager.complete_post_combat_transition(report.report_id), "Each non-final room requires its equipment choice")
			assert_true(manager.can_claim_post_combat_equipment(report.report_id))
			var options: Array[Dictionary] = manager.get_post_combat_reward_options()
			assert_eq(options.size(), 2, "Every non-final room must still offer two valid choices")
			if options.size() != 2:
				return
			var item_id := StringName(options[0].get("item_id", &""))
			assert_false(selected_ids.has(item_id))
			var result: Dictionary = manager.confirm_post_combat_equipment(item_id)
			assert_true(result.get("success", false), str(result))
			selected_ids.append(item_id)
		else:
			assert_false(manager.can_claim_post_combat_equipment(report.report_id))
			assert_true(manager.get_post_combat_reward_options().is_empty())
			assert_eq(manager.confirm_post_combat_equipment(&"unused").get("error_code"), "FINAL_ROOM_HAS_NO_REWARD")
		assert_true(manager.complete_post_combat_transition(report.report_id))
		assert_eq(manager.current_room_index, index + 1)
		assert_eq(manager.run_active, index < 4)
		if index == 2:
			assert_eq(manager.get_current_room().room_name, "Catabase IV — Le Gué du Léthé")
			assert_eq(manager.get_current_encounter_definition().resource_path, "res://data/encounters/catabase_room_04_encounter.tres")
		elif index == 3:
			assert_eq(manager.get_current_room().room_name, "Catabase V — Le Temple du Serment Noir")
			assert_eq(manager.get_current_encounter_definition().resource_path, "res://data/encounters/catabase_room_05_encounter.tres")
	assert_eq(selected_ids.size(), 4)
	assert_eq(state.champion_progression.current_xp, 700)
