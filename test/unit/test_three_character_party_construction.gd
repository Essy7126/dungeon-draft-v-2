extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const GUARDIAN_PATH := "res://data/units/alliés/Gardien.tres"
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"
const VALIDATION_RUN_PATH := "res://data/runs/three_character_validation_run.tres"
const ELF_RUN_PATH := "res://data/runs/elf_prototype_run.tres"
const PARTY_SOURCES := [ELF_PATH, GUARDIAN_PATH, WARRIOR_PATH]

var manager


func before_each() -> void:
	manager = GameManagerScript.new()


func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager.cleanup_run_state()
		manager.free()


func _validation_run() -> RunData:
	return load(VALIDATION_RUN_PATH) as RunData


func _prepare_party() -> Array[CharacterRunState]:
	assert_true(manager._prepare_preconfigured_run(_validation_run(), PARTY_SOURCES))
	return manager.get_ordered_character_states()


func test_validation_run_reuses_elf_rooms_and_keeps_every_pool_empty() -> void:
	var validation := _validation_run()
	var elf_run := load(ELF_RUN_PATH) as RunData
	assert_not_null(validation)
	assert_eq(validation.run_name, "Validation technique — équipe de 3")
	assert_eq(
		validation.rooms.map(func(room): return room.resource_path),
		elf_run.rooms.map(func(room): return room.resource_path),
	)
	assert_eq(validation.rooms.size(), 3)
	assert_true(validation.reward_pool.is_empty())
	assert_true(validation.relic_pool.is_empty())
	assert_true(validation.equipment_pool.is_empty())
	assert_true(validation.event_pool.is_empty())
	assert_true(validation.boss_malus_pool.is_empty())
	assert_true(validation.run_nodes.is_empty())


func test_three_valid_sources_keep_composition_and_state_order() -> void:
	var states := _prepare_party()
	var heroes: Array[Unit] = manager.get_ordered_heroes()
	assert_eq(heroes.size(), 3)
	assert_eq(states.size(), 3)
	assert_eq(heroes.map(func(hero): return hero.unit_name), ["Elfe", "Gardien", "Guerrier"])
	assert_eq(
		states.map(func(state): return state.character_id),
		[
			&"elf",
			StringName(GUARDIAN_PATH),
			StringName(WARRIOR_PATH),
		],
	)
	for index in range(3):
		assert_same(states[index].unit, heroes[index])
		assert_same(manager.get_character_state_for_unit(heroes[index]), states[index])
		assert_same(manager.get_character_state(states[index].character_id), states[index])

	var hero_copy: Array[Unit] = manager.get_ordered_heroes()
	var state_copy: Array[CharacterRunState] = manager.get_ordered_character_states()
	hero_copy.clear()
	state_copy.clear()
	assert_eq(manager.heroes.size(), 3)
	assert_eq(manager.character_states.size(), 3)


func test_duplicate_id_is_refused_before_previous_run_is_cleaned() -> void:
	var old_states := _prepare_party()
	var old_heroes: Array[Unit] = manager.get_ordered_heroes()
	var old_name: String = manager._active_run_name
	assert_false(manager._prepare_preconfigured_run(
		_validation_run(),
		[load(ELF_PATH) as UnitData, load(ELF_PATH) as UnitData],
	))
	assert_push_error("Identifiant de personnage duplique")
	assert_eq(manager.get_ordered_heroes(), old_heroes)
	assert_eq(manager.get_ordered_character_states(), old_states)
	assert_eq(manager._active_run_name, old_name)
	assert_eq(manager.character_states.size(), 3)


func test_invalid_effective_id_is_refused_without_partial_construction() -> void:
	var invalid := UnitData.new()
	invalid.unit_name = "Source invalide"
	assert_false(manager._prepare_preconfigured_run(_validation_run(), [invalid]))
	assert_push_error("Identifiant de personnage preconfigure invalide")
	assert_true(manager.heroes.is_empty())
	assert_true(manager.character_states.is_empty())
	assert_false(manager.run_active)


func test_invalid_source_preserves_the_existing_party() -> void:
	var old_states := _prepare_party()
	var old_heroes: Array[Unit] = manager.get_ordered_heroes()
	var invalid := UnitData.new()
	assert_false(manager._prepare_preconfigured_run(_validation_run(), [invalid]))
	assert_push_error("Identifiant de personnage preconfigure invalide")
	assert_eq(manager.get_ordered_heroes(), old_heroes)
	assert_eq(manager.get_ordered_character_states(), old_states)
	for index in range(3):
		assert_same(old_states[index].unit, old_heroes[index])


func test_production_loadouts_are_independent_known_and_capped_at_four() -> void:
	var states := _prepare_party()
	var expected_known := [4, 5, 8]
	var expected_equipped := [4, 4, 4]
	for index in range(3):
		var state: CharacterRunState = states[index]
		assert_eq(state.loadout.get_known_spells().size(), expected_known[index])
		assert_eq(state.loadout.get_equipped_spells().size(), expected_equipped[index])
		assert_eq(state.unit.spells, state.loadout.get_equipped_spells())
	assert_not_same(states[0].loadout, states[1].loadout)
	assert_not_same(states[1].loadout, states[2].loadout)

	var guardian_before := states[1].loadout.get_equipped_spells()
	var warrior_before := states[2].loadout.get_equipped_spells()
	states[0].loadout.unequip_slot(0)
	assert_eq(states[0].unit.spells.size(), 3)
	assert_eq(states[1].loadout.get_equipped_spells(), guardian_before)
	assert_eq(states[2].loadout.get_equipped_spells(), warrior_before)


func test_warrior_historical_draft_still_exposes_all_eight_spells() -> void:
	assert_true(manager._build_heroes_from_draft([WARRIOR_PATH], [], []))
	assert_eq(manager.heroes.size(), 1)
	assert_eq(manager.heroes[0].spells.size(), 8)
	assert_true(manager.character_states.is_empty())


func test_turn_queue_receives_three_allies_in_stable_logical_order() -> void:
	_prepare_party()
	var heroes: Array = manager.get_living_heroes()
	var queue := TurnQueue.new()
	var turns: Array[String] = []
	queue.turn_started.connect(func(unit): turns.append(unit.unit_name))
	queue.setup(heroes)
	assert_eq(queue.get_full_order(), heroes)
	assert_eq(queue.count_living_in_team(0), 3)
	queue.start()
	queue.advance()
	queue.advance()
	assert_eq(turns, ["Elfe", "Gardien", "Guerrier"])
	assert_same(queue.get_current_unit(), heroes[2])


func test_three_units_keep_combat_state_and_collections_independent() -> void:
	var states := _prepare_party()
	var elf := states[0].unit
	var guardian := states[1].unit
	var warrior := states[2].unit
	elf.current_hp -= 7
	elf.current_ap -= 1
	elf.current_mp -= 1
	elf.add_shield(9)
	var status := StatusData.new()
	status.status_name = "Statut propre a l Elfe"
	status.duration = 2
	elf.apply_status(status)
	assert_ne(elf.current_hp, guardian.current_hp)
	assert_ne(elf.current_ap, guardian.current_ap)
	assert_ne(elf.current_mp, guardian.current_mp)
	assert_eq(guardian.current_shield, 0)
	assert_eq(warrior.current_shield, 0)
	assert_true(guardian.active_statuses.is_empty())
	assert_true(warrior.active_statuses.is_empty())
	assert_not_same(elf.spells, guardian.spells)
	assert_not_same(guardian.spells, warrior.spells)
	assert_true(guardian.get_progression_spell_modifiers().is_empty())
	assert_true(warrior.get_progression_spell_modifiers().is_empty())
