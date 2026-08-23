extends GutTest

const CATALOG_PATH := "res://data/items/catalogs/default_item_catalog.tres"
const SAVE_PATH := "user://gut_inventory_equipment_state.json"


func after_each() -> void:
	GameManager.cleanup_run_state()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _make_unit_data(character_id: StringName) -> UnitData:
	var data := UnitData.new()
	data.unit_id = character_id
	data.unit_name = str(character_id).capitalize()
	data.attack_power = 20
	data.max_hp = 100
	var rank_one := DisciplineRankData.new()
	rank_one.rank = 1
	rank_one.required_total_xp = 0
	var rank_two := DisciplineRankData.new()
	rank_two.rank = 2
	rank_two.required_total_xp = 5
	var tree := DisciplineData.new()
	tree.discipline_id = StringName("%s_tree" % character_id)
	tree.display_name = "%s progression" % data.unit_name
	tree.ranks = [rank_one, rank_two]
	var spell := Spell.new()
	spell.spell_id = StringName("%s_spell" % character_id)
	spell.spell_name = "%s spell" % data.unit_name
	spell.skill_tree = tree
	data.spells = [spell]
	return data


func _make_state(character_id: StringName) -> CharacterRunState:
	var data := _make_unit_data(character_id)
	var state := CharacterRunState.new()
	assert_true(state.initialize(Unit.from_data(data), data))
	return state


func _catalog() -> ItemCatalog:
	return load(CATALOG_PATH) as ItemCatalog


func _find_instance(
		inventory: RunInventory,
		definition_id: StringName
	) -> ItemInstance:
	for instance in inventory.get_slots():
		if instance != null and instance.definition_id == definition_id:
			return instance
	return null


func _prepare_global_run() -> void:
	var run := RunData.new()
	run.run_name = "Inventory Test Run"
	var heroes: Array[UnitData] = [
		_make_unit_data(&"elf"),
		_make_unit_data(&"mage"),
		_make_unit_data(&"warrior"),
	]
	assert_true(GameManager._prepare_preconfigured_run(run, heroes))


func test_catalog_contains_at_least_the_nineteen_stable_definitions() -> void:
	var catalog := _catalog()
	assert_not_null(catalog)
	var validation := catalog.validate_catalog()
	assert_true(validation.get("valid", false), str(validation.get("errors", [])))
	assert_gte(int(validation.get("definition_count", 0)), 19)
	for item_id in [
		&"warrior_training_sword",
		&"reinforced_vest",
		&"runic_charm",
		&"minor_healing_potion",
		&"minor_action_scroll",
	]:
		assert_not_null(catalog.get_definition(item_id), str(item_id))


func test_inventory_stacks_atomically_and_round_trips_snapshot() -> void:
	var inventory := RunInventory.new()
	assert_true(inventory.initialize(_catalog(), 2))
	var result := inventory.try_add(&"minor_healing_potion", 7)
	assert_true(result.get("success", false))
	assert_eq(inventory.get_empty_slot_count(), 0)
	assert_eq(inventory.get_slot(0).quantity, 5)
	assert_eq(inventory.get_slot(1).quantity, 2)
	var rejected := inventory.try_add(&"minor_healing_potion", 4)
	assert_false(rejected.get("success", true))
	assert_eq(inventory.get_slot(0).quantity, 5)
	assert_eq(inventory.get_slot(1).quantity, 2)
	var restored := RunInventory.new()
	assert_true(restored.initialize(_catalog(), 2))
	assert_true(restored.restore_snapshot(inventory.to_snapshot()))
	assert_eq(restored.get_slot(0).quantity, 5)
	assert_eq(restored.get_slot(1).quantity, 2)
	assert_ne(restored.get_slot(0), inventory.get_slot(0))


func test_equip_replace_and_unequip_apply_one_stat_modifier() -> void:
	var catalog := _catalog()
	var inventory := RunInventory.new()
	assert_true(inventory.initialize(catalog, 3))
	var first := inventory.try_add(&"warrior_training_sword", 1)
	var second := inventory.try_add(&"warrior_training_sword", 1)
	var first_id: StringName = first.get("instance_ids", [])[0]
	var second_id: StringName = second.get("instance_ids", [])[0]
	var state := _make_state(&"warrior")
	var service := EquipmentService.new()
	assert_true(service.initialize(catalog))
	assert_true(service.equip(
		inventory,
		state,
		first_id,
		ItemDefinition.EquipmentSlot.WEAPON,
	).get("success", false))
	assert_eq(state.unit.attack_power.get_int(), 23)
	assert_eq(state.unit.attack_power.get_modifiers().size(), 1)
	assert_true(service.equip(
		inventory,
		state,
		second_id,
		ItemDefinition.EquipmentSlot.WEAPON,
	).get("success", false))
	assert_eq(state.unit.attack_power.get_int(), 23)
	assert_eq(state.unit.attack_power.get_modifiers().size(), 1)
	assert_eq(state.equipment_loadout.get_item(
		ItemDefinition.EquipmentSlot.WEAPON
	).instance_id, second_id)
	assert_not_null(inventory.get_instance(first_id))
	assert_true(service.unequip(
		inventory,
		state,
		ItemDefinition.EquipmentSlot.WEAPON,
	).get("success", false))
	assert_eq(state.unit.attack_power.get_int(), 20)
	assert_true(state.unit.attack_power.get_modifiers().is_empty())


func test_unequip_is_rejected_atomically_when_inventory_is_full() -> void:
	var catalog := _catalog()
	var inventory := RunInventory.new()
	assert_true(inventory.initialize(catalog, 1))
	var sword := inventory.try_add(&"warrior_training_sword", 1)
	var sword_id: StringName = sword.get("instance_ids", [])[0]
	var state := _make_state(&"warrior")
	var service := EquipmentService.new()
	assert_true(service.initialize(catalog))
	assert_true(service.equip(
		inventory,
		state,
		sword_id,
		ItemDefinition.EquipmentSlot.WEAPON,
	).get("success", false))
	assert_true(inventory.try_add(&"minor_healing_potion", 1).get("success", false))
	var result := service.unequip(
		inventory,
		state,
		ItemDefinition.EquipmentSlot.WEAPON,
	)
	assert_false(result.get("success", true))
	assert_eq(result.get("error_code", ""), "INVENTORY_FULL")
	assert_eq(state.unit.attack_power.get_int(), 23)
	assert_eq(state.equipment_loadout.get_item(
		ItemDefinition.EquipmentSlot.WEAPON
	).instance_id, sword_id)


func test_potion_consumes_one_stack_and_heals_selected_hero() -> void:
	var catalog := _catalog()
	var inventory := RunInventory.new()
	assert_true(inventory.initialize(catalog, 2))
	var added := inventory.try_add(&"minor_healing_potion", 2)
	var potion_id: StringName = added.get("instance_ids", [])[0]
	var state := _make_state(&"elf")
	state.unit.current_hp = 50
	var service := ItemUseService.new()
	assert_true(service.initialize(catalog))
	var result := service.use_item(inventory, state, potion_id)
	assert_true(result.get("success", false))
	assert_eq(state.unit.current_hp, 75)
	assert_eq(inventory.get_instance(potion_id).quantity, 1)
	state.unit.current_hp = state.unit.max_hp.get_int()
	var rejected := service.use_item(inventory, state, potion_id)
	assert_false(rejected.get("success", true))
	assert_eq(inventory.get_instance(potion_id).quantity, 1)


func test_scroll_consumes_one_stack_and_restores_action_point() -> void:
	var catalog := _catalog()
	var inventory := RunInventory.new()
	assert_true(inventory.initialize(catalog, 2))
	var added := inventory.try_add(&"minor_action_scroll", 2)
	var scroll_id: StringName = added.get("instance_ids", [])[0]
	var state := _make_state(&"mage")
	state.unit.current_ap = state.unit.max_ap.get_int() - 2
	var service := ItemUseService.new()
	assert_true(service.initialize(catalog))
	var result := service.use_item(inventory, state, scroll_id)
	assert_true(result.get("success", false))
	assert_eq(result.get("details", {}).get("restored_ap", 0), 1)
	assert_eq(state.unit.current_ap, state.unit.max_ap.get_int() - 1)
	assert_eq(inventory.get_instance(scroll_id).quantity, 1)


func test_game_manager_owns_starting_inventory_and_restores_equipment_snapshot() -> void:
	_prepare_global_run()
	var inventory := GameManager.get_run_inventory()
	assert_not_null(inventory)
	assert_eq(inventory.capacity, 24)
	assert_eq(inventory.get_empty_slot_count(), 19)
	var sword := _find_instance(inventory, &"warrior_training_sword")
	assert_not_null(sword)
	assert_true(GameManager.equip_inventory_item(
		sword.instance_id,
		&"warrior",
		ItemDefinition.EquipmentSlot.WEAPON,
	).get("success", false))
	assert_eq(GameManager.get_character_state(&"warrior").unit.attack_power.get_int(), 23)
	var snapshot := GameManager.get_inventory_equipment_snapshot()
	assert_true(GameManager.unequip_inventory_item(
		&"warrior",
		ItemDefinition.EquipmentSlot.WEAPON,
	).get("success", false))
	assert_eq(GameManager.get_character_state(&"warrior").unit.attack_power.get_int(), 20)
	assert_true(GameManager.restore_inventory_equipment_snapshot(snapshot))
	var restored_state := GameManager.get_character_state(&"warrior")
	assert_eq(restored_state.unit.attack_power.get_int(), 23)
	assert_not_null(restored_state.equipment_loadout.get_item(
		ItemDefinition.EquipmentSlot.WEAPON
	))


func test_inventory_and_equipment_save_file_round_trip() -> void:
	_prepare_global_run()
	var warrior_state := GameManager.get_character_state(&"warrior")
	assert_eq(warrior_state.add_spell_xp(&"warrior_spell", 4).get("xp", -1), 4)
	var sword := _find_instance(
		GameManager.get_run_inventory(),
		&"warrior_training_sword",
	)
	assert_not_null(sword)
	assert_true(GameManager.equip_inventory_item(
		sword.instance_id,
		&"warrior",
		ItemDefinition.EquipmentSlot.WEAPON,
	).get("success", false))
	assert_true(GameManager.save_inventory_equipment_state(SAVE_PATH))
	assert_eq(warrior_state.add_spell_xp(&"warrior_spell", 1).get("rank", -1), 2)
	assert_true(GameManager.unequip_inventory_item(
		&"warrior",
		ItemDefinition.EquipmentSlot.WEAPON,
	).get("success", false))
	assert_true(GameManager.load_inventory_equipment_state(SAVE_PATH))
	var restored_state := GameManager.get_character_state(&"warrior")
	assert_eq(restored_state.unit.attack_power.get_int(), 23)
	assert_eq(restored_state.get_spell_progress(&"warrior_spell").xp, 4)
	assert_eq(restored_state.get_spell_progress(&"warrior_spell").rank, 1)
	assert_not_null(restored_state.equipment_loadout.get_item(
		ItemDefinition.EquipmentSlot.WEAPON
	))


func test_persistent_ui_opens_inventory_for_requested_character() -> void:
	_prepare_global_run()
	var run_ui := GameManager.get_persistent_run_ui()
	assert_not_null(run_ui)
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.NON_COMBAT)
	assert_true(run_ui.open_inventory_screen(&"mage"))
	assert_true(run_ui.is_inventory_open())
	assert_eq(run_ui.get_inventory_screen().get_selected_character_id(), &"mage")
	assert_true(run_ui.close_inventory_screen())
	assert_false(run_ui.is_inventory_open())


func test_hud_and_pause_menu_open_the_same_inventory_screen() -> void:
	_prepare_global_run()
	var run_ui := GameManager.get_persistent_run_ui()
	var hud = run_ui.get_combat_hud()
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.COMBAT)
	hud.update_info(GameManager.get_character_state(&"warrior").unit)
	hud.set_player_controls_enabled(true)
	hud.get_node("%InventoryButton").pressed.emit()
	assert_true(run_ui.is_inventory_open())
	assert_eq(run_ui.get_inventory_screen().get_selected_character_id(), &"warrior")
	run_ui.close_inventory_screen()
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.NON_COMBAT)
	assert_true(run_ui.open_pause_menu())
	run_ui.get_pause_menu().get_action_button(&"equipment").pressed.emit()
	assert_false(run_ui.is_pause_menu_open())
	assert_true(run_ui.is_inventory_open())
	assert_eq(run_ui.get_inventory_screen().get_selected_character_id(), &"elf")
	run_ui.close_inventory_screen()
