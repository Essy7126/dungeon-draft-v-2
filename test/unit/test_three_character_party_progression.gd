extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")

const GUARDIAN_PATH := "res://data/units/alliés/Gardien.tres"
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"
const SHARED_DISCIPLINE_ID := &"shared_discipline"
const SHARED_SPELL_ID := &"shared_spell"

var manager


func before_each() -> void:
	manager = GameManagerScript.new()
	manager._ready()


func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager.cleanup_run_state()
		manager._exit_tree()
		manager.free()


func _make_discipline() -> DisciplineData:
	var discipline := DisciplineData.new()
	discipline.discipline_id = SHARED_DISCIPLINE_ID
	discipline.display_name = "Discipline partagee"
	return discipline


func _make_spell() -> Spell:
	var spell := Spell.new()
	spell.spell_id = SHARED_SPELL_ID
	spell.spell_name = "Sort partage"
	spell.discipline_id = SHARED_DISCIPLINE_ID
	return spell


func _make_hero_data(character_id: StringName, display_name: String) -> UnitData:
	var data := UnitData.new()
	data.unit_id = character_id
	data.unit_name = display_name
	data.disciplines = [_make_discipline()]
	data.spells = [_make_spell()]
	return data


func _make_run() -> RunData:
	var run := RunData.new()
	run.rooms.append(RoomData.new())
	return run


func _prepare_synthetic_party() -> Array[CharacterRunState]:
	assert_true(manager._prepare_preconfigured_run(
		_make_run(),
		[
			_make_hero_data(&"hero_a", "Heros A"),
			_make_hero_data(&"hero_b", "Heros B"),
			_make_hero_data(&"hero_c", "Heros C"),
		],
	))
	return manager.get_ordered_character_states()


func _xp(state: CharacterRunState) -> int:
	return state.get_discipline_progress(SHARED_DISCIPLINE_ID).xp


func _emit_cast(state: CharacterRunState) -> void:
	EventBus.spell_cast.emit(state.unit, state.unit.spells[0], {})


func test_same_discipline_and_spell_ids_remain_independent_by_exact_caster() -> void:
	var states := _prepare_synthetic_party()
	assert_not_same(states[0].get_discipline_progress(SHARED_DISCIPLINE_ID), states[1].get_discipline_progress(SHARED_DISCIPLINE_ID))
	assert_not_same(states[0].unit.spells[0], states[1].unit.spells[0])
	assert_eq(
		states.map(func(state): return state.unit.spells[0].get_effective_spell_id()),
		[SHARED_SPELL_ID, SHARED_SPELL_ID, SHARED_SPELL_ID],
	)

	_emit_cast(states[0])
	assert_eq([_xp(states[0]), _xp(states[1]), _xp(states[2])], [1, 0, 0])
	_emit_cast(states[1])
	assert_eq([_xp(states[0]), _xp(states[1]), _xp(states[2])], [1, 1, 0])
	_emit_cast(states[2])
	assert_eq([_xp(states[0]), _xp(states[1]), _xp(states[2])], [1, 1, 1])


func test_three_casts_produce_three_results_bound_to_three_runtime_units() -> void:
	var states := _prepare_synthetic_party()
	var results: Array[Dictionary] = []
	manager.discipline_xp_gained.connect(
		func(_character_id, _discipline_id, _amount, snapshot):
			results.append(snapshot)
	)
	for state in states:
		_emit_cast(state)
	assert_eq(results.size(), 3)
	assert_eq(
		results.map(func(result): return result["character_id"]),
		[&"hero_a", &"hero_b", &"hero_c"],
	)
	for index in range(3):
		assert_same(results[index]["caster"], states[index].unit)
		assert_eq(results[index]["spell_id"], SHARED_SPELL_ID)
		assert_eq(results[index]["gained_xp"], 1)


func test_foreign_instance_with_same_ids_is_ignored() -> void:
	var states := _prepare_synthetic_party()
	var foreign_data := _make_hero_data(&"hero_a", "Clone etranger")
	var foreign_unit := Unit.from_data(foreign_data)
	assert_null(manager.get_character_state_for_unit(foreign_unit))
	EventBus.spell_cast.emit(foreign_unit, foreign_unit.spells[0], {})
	assert_eq([_xp(states[0]), _xp(states[1]), _xp(states[2])], [0, 0, 0])
	foreign_unit.clear_traits()


func test_removed_caster_cannot_credit_a_new_party() -> void:
	var old_states := _prepare_synthetic_party()
	var old_unit := old_states[0].unit
	_emit_cast(old_states[0])
	assert_eq(_xp(old_states[0]), 1)
	var fresh_states := _prepare_synthetic_party()
	EventBus.spell_cast.emit(old_unit, old_unit.spells[0], {})
	assert_eq(fresh_states.map(func(state): return _xp(state)), [0, 0, 0])
	_emit_cast(fresh_states[0])
	assert_eq(fresh_states.map(func(state): return _xp(state)), [1, 0, 0])


func test_guardian_stays_legacy_while_warrior_uses_its_real_progression() -> void:
	assert_true(manager._prepare_preconfigured_run(
		_make_run(),
		[GUARDIAN_PATH, WARRIOR_PATH],
	))
	var states: Array[CharacterRunState] = manager.get_ordered_character_states()
	assert_eq(states.size(), 2)
	assert_true(states[0].get_disciplines().is_empty())
	assert_eq(states[1].get_disciplines().size(), 3)
	EventBus.spell_cast.emit(states[0].unit, states[0].unit.spells[0], {})
	EventBus.spell_cast.emit(states[1].unit, states[1].unit.spells[0], {})
	assert_true(states[0].get_discipline_progressions().is_empty())
	assert_eq(states[1].get_discipline_progress(&"warrior_breaker").xp, 1)
	assert_eq(states[1].get_discipline_progress(&"warrior_executioner").xp, 0)
	assert_eq(states[1].get_discipline_progress(&"warrior_ravager").xp, 0)
