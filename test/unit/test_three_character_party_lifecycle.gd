extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const MAGE_PATH := "res://data/units/alliés/mage.tres"
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"
const INCANDESCENT_ID := &"elf_mage_cur_incandescent"
const PARTY_SOURCES := [ELF_PATH, MAGE_PATH, WARRIOR_PATH]

var manager


func before_each() -> void:
	manager = GameManagerScript.new()
	manager._ready()


func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager.cleanup_run_state()
		manager._exit_tree()
		manager.free()


func _make_run() -> RunData:
	var run := RunData.new()
	run.run_name = "Cycle equipe"
	run.rooms = [RoomData.new(), RoomData.new(), RoomData.new()]
	return run


func _prepare_party() -> Array[CharacterRunState]:
	assert_true(manager._prepare_preconfigured_run(_make_run(), PARTY_SOURCES))
	return manager.get_ordered_character_states()


func _prepare_solo() -> CharacterRunState:
	assert_true(manager._prepare_preconfigured_run(_make_run(), [ELF_PATH]))
	return manager.get_ordered_character_states()[0]


func _fireball() -> Spell:
	return (load(ELF_PATH) as UnitData).spells[2]


func _emit_fireball(unit: Unit) -> void:
	unit.activation_index += 1
	EventBus.spell_cast.emit(unit, _fireball(), {"effective_cast": true})


func _mage_xp(state: CharacterRunState) -> int:
	return state.get_discipline_progress(&"mage").xp


func _manager_callback_count() -> int:
	var wanted := Callable(manager, "_on_successful_spell_cast")
	return EventBus.spell_cast.get_connections().filter(
		func(connection): return connection.get("callable") == wanted
	).size()


func test_three_states_units_loadouts_xp_and_modifiers_persist_between_rooms() -> void:
	var states := _prepare_party()
	var units: Array[Unit] = manager.get_ordered_heroes()
	var loadouts := states.map(func(state): return state.loadout)
	var known_spells := states.map(func(state): return state.loadout.get_known_spells())
	units[0].current_hp = 73
	units[1].current_hp = 64
	units[2].current_hp = 55
	states[0].add_discipline_xp(&"mage", 5)
	assert_true(states[0].select_upgrade(&"mage", 2, INCANDESCENT_ID))
	assert_eq(units[0].get_progression_spell_modifiers().size(), 1)

	manager.current_room_index = 0
	manager._go_to_next_room()
	assert_eq(manager.current_room_index, 1)
	assert_eq(manager.get_ordered_character_states(), states)
	assert_eq(manager.get_ordered_heroes(), units)
	for index in range(3):
		assert_same(states[index].unit, units[index])
		assert_same(states[index].loadout, loadouts[index])
		assert_eq(states[index].loadout.get_known_spells(), known_spells[index])
	assert_eq(units.map(func(unit): return unit.current_hp), [73, 64, 55])
	assert_eq(_mage_xp(states[0]), 5)
	assert_eq(units[0].get_progression_spell_modifiers().size(), 1)
	assert_true(units[1].get_progression_spell_modifiers().is_empty())
	assert_true(units[2].get_progression_spell_modifiers().is_empty())


func test_three_to_solo_disposes_every_old_state_loadout_and_modifier() -> void:
	var old_states := _prepare_party()
	old_states[0].add_discipline_xp(&"mage", 5)
	assert_true(old_states[0].select_upgrade(&"mage", 2, INCANDESCENT_ID))
	var old_units: Array[Unit] = manager.get_ordered_heroes()
	var old_loadouts := old_states.map(func(state): return state.loadout)
	var callbacks: Array = old_states.map(
		func(state): return Callable(state, "sync_loadout_to_unit")
	)
	var solo := _prepare_solo()
	assert_eq(manager.character_states.keys(), [&"elf"])
	assert_eq(manager.heroes.size(), 1)
	assert_same(manager.heroes[0], solo.unit)
	for index in range(3):
		assert_null(old_states[index].unit)
		assert_null(old_states[index].loadout)
		assert_false(old_loadouts[index].changed.is_connected(callbacks[index]))
		assert_true(old_units[index].get_progression_spell_modifiers().is_empty())
	assert_eq(_mage_xp(solo), 0)
	assert_true(solo.unit.get_progression_spell_modifiers().is_empty())


func test_solo_to_three_rebuilds_the_full_order_without_old_keys() -> void:
	var old_solo := _prepare_solo()
	var old_unit := old_solo.unit
	old_solo.add_discipline_xp(&"mage", 5)
	assert_true(old_solo.select_upgrade(&"mage", 2, INCANDESCENT_ID))
	var states := _prepare_party()
	assert_eq(states.map(func(state): return state.unit.unit_name), ["Elfe", "Mage", "Guerrier"])
	assert_eq(manager.character_states.size(), 3)
	assert_not_same(states[0], old_solo)
	assert_null(old_solo.unit)
	assert_null(old_solo.loadout)
	assert_true(old_unit.get_progression_spell_modifiers().is_empty())
	assert_eq(_mage_xp(states[0]), 0)


func test_three_successive_party_runs_keep_one_callback_and_fresh_xp() -> void:
	for _run_index in range(3):
		var states := _prepare_party()
		manager._ready()
		_emit_fireball(states[0].unit)
		assert_eq(_mage_xp(states[0]), 1)
		assert_eq(_manager_callback_count(), 1)
		assert_eq(states[1].get_discipline_progressions().size(), 4)
		assert_true(states[1].get_discipline_progressions().values().all(
			func(progress): return progress.xp == 0
		))
		assert_eq(states[2].get_discipline_progressions().size(), 4)
		assert_true(states[2].get_discipline_progressions().values().all(
			func(progress): return progress.xp == 0
		))


func test_old_party_hero_is_ignored_after_replacement() -> void:
	var old_states := _prepare_party()
	var old_elf := old_states[0].unit
	_emit_fireball(old_elf)
	assert_eq(_mage_xp(old_states[0]), 1)
	var fresh_states := _prepare_party()
	_emit_fireball(old_elf)
	assert_eq(_mage_xp(fresh_states[0]), 0)
	_emit_fireball(fresh_states[0].unit)
	assert_eq(_mage_xp(fresh_states[0]), 1)


func test_cleanup_clears_all_party_state_pending_continuations_and_results() -> void:
	var states := _prepare_party()
	var units: Array[Unit] = manager.get_ordered_heroes()
	var loadouts := states.map(func(state): return state.loadout)
	var callbacks: Array = states.map(
		func(state): return Callable(state, "sync_loadout_to_unit")
	)
	states[0].add_discipline_xp(&"mage", 5)
	assert_true(states[0].select_upgrade(&"mage", 2, INCANDESCENT_ID))
	manager._awaiting_post_battle_progression = true
	manager._room_outcome_resolved = true
	manager._last_run_result = { "victory": true, "run_name": "ancien" }
	manager.cleanup_run_state()

	assert_true(manager.heroes.is_empty())
	assert_true(manager.character_states.is_empty())
	assert_true(manager.get_ordered_character_states().is_empty())
	assert_true(manager.get_pending_progression_choices().is_empty())
	assert_false(manager._awaiting_post_battle_progression)
	assert_false(manager._room_outcome_resolved)
	assert_false(manager.run_active)
	assert_eq(manager.current_room_index, -1)
	assert_true(manager._last_run_result.is_empty())
	for index in range(3):
		assert_null(states[index].unit)
		assert_null(states[index].loadout)
		assert_false(loadouts[index].changed.is_connected(callbacks[index]))
		assert_true(units[index].get_progression_spell_modifiers().is_empty())
