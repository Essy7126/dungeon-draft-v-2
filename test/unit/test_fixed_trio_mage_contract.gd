extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")
const ActionBarScript = preload("res://ui/action_bar.gd")
const BattleScript = preload("res://battle/battle.gd")

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const MAGE_PATH := "res://data/units/alliés/mage.tres"
const GUARDIAN_PATH := "res://data/units/alliés/Gardien.tres"
const RUN_PATH := "res://data/runs/fixed_trio_prototype_run.tres"
const PARTY := [ELF_PATH, MAGE_PATH, GUARDIAN_PATH]
const EXPECTED_ROOMS := [
	"res://data/rooms/bible/le_gue.tres",
	"res://data/rooms/bible/la_forge.tres",
	"res://data/rooms/bible/elite_brute.tres",
]

var manager


func before_each() -> void:
	manager = GameManagerScript.new()
	manager._ready()


func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager.cleanup_run_state()
		manager._exit_tree()
		manager.free()


func _prepare() -> Array[CharacterRunState]:
	assert_true(manager._prepare_preconfigured_run(load(RUN_PATH) as RunData, PARTY))
	return manager.get_ordered_character_states()


func test_run_has_exact_rooms_and_no_progression_or_reward_pool() -> void:
	var run := load(RUN_PATH) as RunData
	assert_eq(run.run_name, "Trio fixe — prototype")
	assert_eq(run.rooms.map(func(room): return room.resource_path), EXPECTED_ROOMS)
	assert_true(run.reward_pool.is_empty())
	assert_true(run.relic_pool.is_empty())
	assert_true(run.equipment_pool.is_empty())
	assert_true(run.event_pool.is_empty())
	assert_true(run.boss_malus_pool.is_empty())
	assert_true(run.run_nodes.is_empty())


func test_fixed_composition_order_ids_states_and_loadouts_are_exact() -> void:
	var states := _prepare()
	var heroes: Array[Unit] = manager.get_ordered_heroes()
	assert_eq(heroes.map(func(hero): return hero.unit_name), ["Elfe", "Mage", "Gardien"])
	assert_eq(states.map(func(state): return state.character_id), [
		&"elf",
		&"mage",
		StringName(GUARDIAN_PATH),
	])
	for index in range(3):
		assert_same(states[index].unit, heroes[index])
		assert_same(manager.get_character_state_for_unit(heroes[index]), states[index])
		assert_eq(states[index].loadout.get_equipped_spells(), heroes[index].spells)
	assert_eq(states[0].loadout.get_equipped_spells().size(), 4)
	assert_eq(states[1].loadout.get_equipped_spells().size(), 4)
	assert_eq(states[2].loadout.get_equipped_spells().size(), 4)
	assert_eq(states[0].get_disciplines().size(), 4)
	assert_eq(
		states[1].get_disciplines().map(func(item): return item.discipline_id),
		[&"mage_fire", &"mage_ice", &"mage_lightning", &"mage_earth"],
	)
	assert_eq(states[1].get_discipline_progressions().size(), 4)


func test_mage_spell_cast_grants_only_its_own_discipline_xp() -> void:
	var states := _prepare()
	var elf := states[0]
	var mage := states[1]
	elf.add_discipline_xp(&"mage", 3)
	assert_true(elf.select_upgrade(&"mage", 2, &"elf_mage_incandescent_core"))
	assert_eq(elf.unit.get_progression_spell_modifiers().size(), 1)
	assert_true(mage.unit.get_progression_spell_modifiers().is_empty())
	EventBus.spell_cast.emit(mage.unit, mage.unit.spells[0], {})
	assert_eq(mage.get_discipline_progress(&"mage_fire").xp, 1)
	assert_eq(mage.get_discipline_progress(&"mage_ice").xp, 0)
	assert_eq(mage.get_discipline_progress(&"mage_lightning").xp, 0)
	assert_eq(mage.get_discipline_progress(&"mage_earth").xp, 0)
	assert_true(mage.unit.get_progression_spell_modifiers().is_empty())
	assert_eq(elf.get_discipline_progress(&"mage").xp, 3)


func test_same_mage_state_unit_hp_loadout_and_visual_persist_between_rooms() -> void:
	var states := _prepare()
	var mage_state := states[1]
	var mage := mage_state.unit
	var loadout := mage_state.loadout
	var known := loadout.get_known_spells()
	var equipped := loadout.get_equipped_spells()
	var combat_visual := mage.visual_scene
	var preview_visual := mage.preview_visual_scene
	mage.current_hp = 61
	manager.current_room_index = 0
	manager._go_to_next_room()
	assert_eq(manager.current_room_index, 1)
	assert_same(manager.get_ordered_character_states()[1], mage_state)
	assert_same(manager.get_ordered_heroes()[1], mage)
	assert_same(mage_state.loadout, loadout)
	assert_eq(loadout.get_known_spells(), known)
	assert_eq(loadout.get_equipped_spells(), equipped)
	assert_eq(mage.current_hp, 61)
	assert_same(mage.visual_scene, combat_visual)
	assert_same(mage.preview_visual_scene, preview_visual)


func test_hud_cycles_elf_mage_guardian_elf_without_buttons_or_state_residue() -> void:
	_prepare()
	var heroes: Array[Unit] = manager.get_ordered_heroes()
	var bar = ActionBarScript.new()
	add_child_autofree(bar)

	bar.update_info(heroes[0])
	bar.build_spell_buttons(heroes[0])
	assert_true(bar.get("_attack_btn").visible)
	assert_eq(bar.get("_spell_buttons").size(), 4)
	var elf_buttons: Array = bar.get("_spell_buttons").duplicate()

	bar.update_info(heroes[1])
	bar.build_spell_buttons(heroes[1])
	assert_true(elf_buttons.all(func(button): return not is_instance_valid(button)))
	assert_false(bar.get("_attack_btn").visible)
	assert_eq(bar.get("_spell_buttons").size(), 4)
	assert_false(bar.get("_fervor_bar").visible)
	var mage_buttons: Array = bar.get("_spell_buttons").duplicate()

	bar.update_info(heroes[2])
	bar.build_spell_buttons(heroes[2])
	assert_true(mage_buttons.all(func(button): return not is_instance_valid(button)))
	assert_true(bar.get("_attack_btn").visible)
	assert_true(bar.get("_fervor_bar").visible)
	var guardian_buttons: Array = bar.get("_spell_buttons").duplicate()

	bar.update_info(heroes[0])
	bar.build_spell_buttons(heroes[0])
	assert_true(guardian_buttons.all(func(button): return not is_instance_valid(button)))
	assert_true(bar.get("_attack_btn").visible)
	assert_false(bar.get("_fervor_bar").visible)
	assert_eq(bar.get("_spell_buttons").size(), 4)


func test_battle_rejects_hidden_basic_attack_without_mage_special_case() -> void:
	_prepare()
	var mage := manager.get_ordered_heroes()[1] as Unit
	var battle = BattleScript.new()
	battle.turn_queue = TurnQueue.new()
	battle.turn_queue.setup([mage])
	battle.turn_queue.start()
	battle.turn_state = TurnState.new()
	battle._on_attack_pressed()
	assert_eq(battle.turn_state.current, TurnState.State.IDLE)
	assert_false(mage.can_use_basic_attack())
	assert_false(
		FileAccess.get_file_as_string("res://battle/battle.gd").to_lower().contains("\"mage\"")
	)
	assert_false(
		FileAccess.get_file_as_string("res://ui/action_bar.gd").to_lower().contains("\"mage\"")
	)
	battle.free()
