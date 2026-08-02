extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")
const ActionBarScript = preload("res://ui/action_bar.gd")

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const MAGE_PATH := "res://data/units/alliés/mage.tres"
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"
const RUN_PATH := "res://data/runs/first_run.tres"
const PARTY := [ELF_PATH, MAGE_PATH, WARRIOR_PATH]
const EXPECTED_ROOMS := [
	"res://data/rooms/first_run_room_01.tres",
	"res://data/rooms/first_run_room_02.tres",
	"res://data/rooms/first_run_room_03.tres",
	"res://data/rooms/first_run_room_04_boss.tres",
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

func test_first_run_contains_the_four_migrated_rooms_in_order() -> void:
	var run := load(RUN_PATH) as RunData
	assert_not_null(run)
	assert_eq(run.run_name, "Première run")
	assert_eq(run.rooms.map(func(room): return room.resource_path), EXPECTED_ROOMS)
	assert_true(run.rooms.all(func(room): return room != null and room.battle_scene != null))

func test_fixed_party_has_exact_ids_resources_and_four_spells_each() -> void:
	var states := _prepare()
	var heroes: Array[Unit] = manager.get_ordered_heroes()
	assert_eq(states.map(func(state): return state.character_id), [&"elf", &"mage", &"warrior"])
	assert_eq(heroes.map(func(hero): return hero.unit_name), ["Elfe", "Mage", "Guerrier"])
	for index in range(3):
		assert_same(states[index].unit, heroes[index])
		assert_same(manager.get_character_state_for_unit(heroes[index]), states[index])
		assert_eq(heroes[index].max_ap.get_int(), 6)
		assert_eq(heroes[index].max_mp.get_int(), 3)
		assert_eq(heroes[index].spells.size(), 4)
		assert_eq(states[index].loadout.get_equipped_spells(), heroes[index].spells)
	assert_eq(states[0].get_disciplines().size(), 4)
	assert_eq(states[1].get_disciplines().size(), 4)
	assert_eq(states[2].get_disciplines().size(), 4)

func test_mage_cast_grants_only_matching_discipline_xp() -> void:
	var mage_state := _prepare()[1]
	EventBus.spell_cast.emit(mage_state.unit, mage_state.unit.spells[0], {})
	assert_eq(mage_state.get_discipline_progress(&"mage_pyromancy").xp, 1)
	assert_eq(mage_state.get_discipline_progress(&"mage_cryomancy").xp, 0)
	assert_eq(mage_state.get_discipline_progress(&"mage_fulguromancy").xp, 0)
	assert_eq(mage_state.get_discipline_progress(&"mage_geomancy").xp, 0)

func test_state_hp_and_loadout_persist_between_rooms() -> void:
	var states := _prepare()
	var mage_state := states[1]
	var mage := mage_state.unit
	var loadout := mage_state.loadout
	mage.current_hp = 61
	manager.current_room_index = 0
	manager._go_to_next_room()
	assert_eq(manager.current_room_index, 1)
	assert_same(manager.get_ordered_character_states()[1], mage_state)
	assert_same(manager.get_ordered_heroes()[1], mage)
	assert_same(mage_state.loadout, loadout)
	assert_eq(mage.current_hp, 61)

func test_action_bar_cycles_four_spells_without_legacy_resource_controls() -> void:
	var heroes: Array = _prepare().map(func(state): return state.unit)
	var bar = ActionBarScript.new()
	add_child_autofree(bar)
	for hero in heroes:
		bar.update_info(hero)
		bar.build_spell_buttons(hero)
		assert_eq(bar.get("_spell_buttons").size(), 4)
		assert_true(bar.get("_ap_label").text.begins_with("PA"))

func test_basic_attack_policy_is_explicit_for_the_fixed_party() -> void:
	var heroes: Array = _prepare().map(func(state): return state.unit)
	assert_true(heroes[0].basic_attack_enabled)
	assert_false(heroes[1].basic_attack_enabled)
	assert_true(heroes[2].basic_attack_enabled)
	assert_false(FileAccess.file_exists("res://data/units/alliés/Gardien.tres"))
	assert_false(FileAccess.file_exists("res://data/energy/energy_type.gd"))
