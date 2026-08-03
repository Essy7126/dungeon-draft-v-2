extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const MAGE_PATH := "res://data/units/alliés/mage.tres"
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"
const FIRST_RUN_PATH := "res://data/runs/first_run.tres"
const PARTY_SOURCES := [ELF_PATH, MAGE_PATH, WARRIOR_PATH]

var manager


func before_each() -> void:
	manager = GameManagerScript.new()


func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager.cleanup_run_state()
		manager.free()


func _first_run() -> RunData:
	return load(FIRST_RUN_PATH) as RunData


func _prepare_party() -> Array[CharacterRunState]:
	assert_true(manager._prepare_preconfigured_run(_first_run(), PARTY_SOURCES))
	return manager.get_ordered_character_states()


func test_first_run_has_six_rooms_and_a_skeleton_chief_finale() -> void:
	var run := _first_run()
	assert_not_null(run)
	assert_eq(run.run_name, "Première run")
	assert_eq(run.rooms.size(), 6)
	assert_eq(run.rooms[-1].resource_path, "res://data/rooms/room_06_space.tres")
	assert_true(run.rooms[-1].enemies.any(
		func(enemy): return enemy.unit_id == &"skeleton_chief"
	))


func test_production_party_has_stable_order_states_and_four_spell_loadouts() -> void:
	var states := _prepare_party()
	var heroes: Array[Unit] = manager.get_ordered_heroes()
	assert_eq(heroes.map(func(hero): return hero.unit_id), [&"elf", &"mage", &"warrior"])
	assert_eq(states.map(func(state): return state.character_id), [&"elf", &"mage", &"warrior"])
	for index in range(3):
		assert_same(states[index].unit, heroes[index])
		assert_same(manager.get_character_state_for_unit(heroes[index]), states[index])
		assert_eq(heroes[index].max_ap.get_int(), 6)
		assert_eq(heroes[index].max_mp.get_int(), 3)
		assert_eq(heroes[index].spells.size(), 4)


func test_duplicate_character_id_is_refused_without_replacing_current_run() -> void:
	var old_heroes := _prepare_party()
	assert_false(manager._prepare_preconfigured_run(
		_first_run(),
		[load(ELF_PATH) as UnitData, load(ELF_PATH) as UnitData],
	))
	assert_push_error("Identifiant de personnage duplique")
	assert_eq(manager.get_ordered_character_states(), old_heroes)
	assert_eq(manager.get_ordered_heroes().size(), 3)


func test_invalid_effective_id_is_refused_without_partial_construction() -> void:
	var invalid := UnitData.new()
	invalid.unit_name = "Source invalide"
	assert_false(manager._prepare_preconfigured_run(_first_run(), [invalid]))
	assert_push_error("Identifiant de personnage preconfigure invalide")
	assert_true(manager.heroes.is_empty())
	assert_true(manager.character_states.is_empty())
	assert_false(manager.run_active)


func test_turn_queue_receives_fixed_party_in_logical_order() -> void:
	_prepare_party()
	var heroes: Array = manager.get_living_heroes()
	var queue := TurnQueue.new()
	var turns: Array[String] = []
	queue.turn_started.connect(func(unit): turns.append(unit.unit_name))
	queue.setup(heroes)
	queue.start()
	queue.advance()
	queue.advance()
	assert_eq(turns, ["Elfe", "Mage", "Guerrier"])
	assert_same(queue.get_current_unit(), heroes[2])
