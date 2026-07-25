extends GutTest

const Factory = preload("res://test/support/factory.gd")
const GameManagerScript = preload("res://core/game_manager.gd")
const ProgressionScreenScript = preload("res://ui/progression/progression_choice_screen.gd")

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"
const MAGE_DISCIPLINE_PATH := "res://data/characters/elf/disciplines/mage.tres"
const INCANDESCENT_ID := &"elf_mage_incandescent_core"
const EMBERS_ID := &"elf_mage_persistent_embers"
const FIREBALL_ID := &"elf_fireball"

var manager


func before_each() -> void:
	manager = GameManagerScript.new()
	manager._ready()


func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager._exit_tree()
		manager._clear_heroes()
		manager.free()


func _make_run(room_count: int = 2, with_reward: bool = false) -> RunData:
	var run := RunData.new()
	for _index in range(room_count):
		run.rooms.append(RoomData.new())
	if with_reward:
		run.reward_pool.append(RewardData.new())
	return run


func _prepare_elf(room_count: int = 2) -> CharacterRunState:
	assert_true(manager._prepare_preconfigured_run(_make_run(room_count), [ELF_PATH]))
	return manager.get_character_state(&"elf")


func _elf_fireball() -> Spell:
	return (load(ELF_PATH) as UnitData).spells[2]


func _mage_data() -> DisciplineData:
	return load(MAGE_DISCIPLINE_PATH) as DisciplineData


func _make_progress() -> DisciplineProgressState:
	var progress := DisciplineProgressState.new()
	assert_true(progress.initialize(_mage_data()))
	return progress


func _make_fireball_field(hero: Unit, with_targets: bool = false):
	var battlefield := Factory.make_battlefield(9, 5)
	battlefield.grid.place_unit(hero, Vector2i(0, 2))
	if with_targets:
		battlefield.grid.place_unit(Unit.new("Centre", 1, 1000), Vector2i(3, 2))
		battlefield.grid.place_unit(Unit.new("Périphérie", 1, 1000), Vector2i(3, 3))
	return battlefield


func _raise_mage_to_rank_two(state: CharacterRunState) -> void:
	var result := state.add_discipline_xp(&"mage", 3)
	assert_eq(result["rank"], 2)
	assert_eq(result["pending_rank_choices"], [2])


func test_discipline_progress_starts_at_rank_one_without_xp_or_choices() -> void:
	var progress := _make_progress()
	assert_eq(progress.discipline_id, &"mage")
	assert_eq(progress.xp, 0)
	assert_eq(progress.rank, 1)
	assert_true(progress.get_selected_upgrade_ids().is_empty())
	assert_true(progress.get_pending_rank_choices().is_empty())


func test_discipline_progress_adds_xp_and_reaches_rank_two_at_three() -> void:
	var progress := _make_progress()
	progress.add_xp(2)
	assert_eq(progress.xp, 2)
	assert_eq(progress.rank, 1)
	progress.add_xp(1)
	assert_eq(progress.xp, 3)
	assert_eq(progress.rank, 2)
	assert_eq(progress.get_pending_rank_choices(), [2])


func test_rank_threshold_and_pending_choice_are_created_only_once() -> void:
	var progress := _make_progress()
	assert_eq(progress.add_xp(3), [2])
	assert_true(progress.add_xp(5).is_empty())
	assert_eq(progress.rank, 2)
	assert_eq(progress.get_pending_rank_choices(), [2])


func test_upgrade_selection_is_recorded_and_exclusive_for_the_rank() -> void:
	var progress := _make_progress()
	progress.add_xp(3)
	assert_not_null(progress.select_upgrade(INCANDESCENT_ID, 2))
	assert_eq(progress.get_selected_upgrade_ids(), [INCANDESCENT_ID])
	assert_true(progress.get_pending_rank_choices().is_empty())
	assert_null(progress.select_upgrade(EMBERS_ID, 2))
	assert_eq(progress.get_selected_upgrade_ids(), [INCANDESCENT_ID])


func test_progress_state_returns_defensive_collection_copies() -> void:
	var progress := _make_progress()
	progress.add_xp(3)
	var pending_copy := progress.get_pending_rank_choices()
	pending_copy.clear()
	assert_eq(progress.get_pending_rank_choices(), [2])
	progress.select_upgrade(INCANDESCENT_ID, 2)
	var selected_copy := progress.get_selected_upgrade_ids()
	selected_copy.append(EMBERS_ID)
	assert_eq(progress.get_selected_upgrade_ids(), [INCANDESCENT_ID])
	var snapshot := progress.get_snapshot()
	snapshot["selected_upgrade_ids"].clear()
	assert_eq(progress.get_selected_upgrade_ids(), [INCANDESCENT_ID])


func test_two_discipline_states_are_independent() -> void:
	var first := _make_progress()
	var second := _make_progress()
	first.add_xp(3)
	first.select_upgrade(INCANDESCENT_ID, 2)
	assert_eq(first.rank, 2)
	assert_eq(second.rank, 1)
	assert_eq(second.xp, 0)
	assert_true(second.get_selected_upgrade_ids().is_empty())


func test_mage_rank_two_data_has_exactly_two_expected_choices() -> void:
	var mage := _mage_data()
	assert_eq(mage.ranks.size(), 2)
	assert_eq([mage.ranks[0].rank, mage.ranks[0].required_total_xp], [1, 0])
	assert_eq([mage.ranks[1].rank, mage.ranks[1].required_total_xp], [2, 3])
	assert_eq(
		mage.ranks[1].choices.map(func(upgrade): return upgrade.upgrade_id),
		[INCANDESCENT_ID, EMBERS_ID]
	)
	assert_eq(
		mage.ranks[1].choices.map(func(upgrade): return upgrade.target_spell_id),
		[FIREBALL_ID, FIREBALL_ID]
	)


func test_successful_fireball_cast_grants_exactly_one_mage_xp() -> void:
	var state := _prepare_elf()
	var hero := state.unit
	var battlefield = _make_fireball_field(hero)
	var report: Dictionary = battlefield.caster.cast(hero, _elf_fireball(), Vector2i(3, 2))
	assert_false(report.get("failed", false))
	assert_eq(state.get_discipline_progress(&"mage").xp, 1)


func test_three_successful_fireballs_reach_mage_rank_two() -> void:
	var state := _prepare_elf()
	var hero := state.unit
	var battlefield = _make_fireball_field(hero)
	for _cast_index in range(3):
		battlefield.caster.cast(hero, _elf_fireball(), Vector2i(3, 2))
	var progress := state.get_discipline_progress(&"mage")
	assert_eq(progress.xp, 3)
	assert_eq(progress.rank, 2)
	assert_eq(progress.get_pending_rank_choices(), [2])


func test_failed_or_invalid_cast_grants_no_xp_and_spends_no_invalid_target_ap() -> void:
	var state := _prepare_elf()
	var hero := state.unit
	var battlefield = _make_fireball_field(hero)
	var ap_before := hero.current_ap
	var invalid_report: Dictionary = battlefield.caster.cast(
		hero,
		_elf_fireball(),
		Vector2i(99, 99)
	)
	assert_true(invalid_report.get("failed", false))
	assert_eq(invalid_report.get("reason"), "target")
	assert_eq(hero.current_ap, ap_before)
	hero.current_ap = 0
	var cost_report: Dictionary = battlefield.caster.cast(
		hero,
		_elf_fireball(),
		Vector2i(3, 2)
	)
	assert_true(cost_report.get("failed", false))
	assert_eq(state.get_discipline_progress(&"mage").xp, 0)


func test_aoe_cast_touching_multiple_units_still_grants_one_xp() -> void:
	var state := _prepare_elf()
	var battlefield = _make_fireball_field(state.unit, true)
	var report: Dictionary = battlefield.caster.cast(
		state.unit,
		_elf_fireball(),
		Vector2i(3, 2)
	)
	assert_eq(report["affected_units"].size(), 2)
	assert_eq(state.get_discipline_progress(&"mage").xp, 1)


func test_enemy_cast_never_grants_character_progression() -> void:
	var state := _prepare_elf()
	var battlefield := Factory.make_battlefield(9, 5)
	var enemy := Unit.new("Ennemi", 1)
	battlefield.grid.place_unit(enemy, Vector2i(0, 2))
	battlefield.caster.cast(enemy, _elf_fireball(), Vector2i(3, 2))
	assert_eq(state.get_discipline_progress(&"mage").xp, 0)


func test_spell_without_discipline_grants_no_xp() -> void:
	var state := _prepare_elf()
	var battlefield = _make_fireball_field(state.unit)
	var legacy_spell := Factory.make_spell({
		"spell_id": &"legacy_no_discipline",
		"spell_range": 5,
		"can_target_free_cell": true,
	})
	battlefield.caster.cast(state.unit, legacy_spell, Vector2i(3, 2))
	assert_eq(state.get_discipline_progress(&"mage").xp, 0)


func test_cast_xp_is_assigned_to_the_exact_character_instance() -> void:
	var elf_data := load(ELF_PATH) as UnitData
	var other_data := UnitData.new()
	other_data.unit_id = &"other_hero"
	other_data.unit_name = "Autre héros"
	other_data.disciplines = elf_data.disciplines
	other_data.spells = [_elf_fireball()]
	assert_true(manager._prepare_preconfigured_run(
		_make_run(),
		[elf_data, other_data]
	))
	var elf_state: CharacterRunState = manager.get_character_state(&"elf")
	var other_state: CharacterRunState = manager.get_character_state(&"other_hero")
	var battlefield = _make_fireball_field(other_state.unit)
	battlefield.caster.cast(other_state.unit, _elf_fireball(), Vector2i(3, 2))
	assert_eq(other_state.get_discipline_progress(&"mage").xp, 1)
	assert_eq(elf_state.get_discipline_progress(&"mage").xp, 0)


func test_xp_rank_and_selection_persist_between_rooms_and_resource_resets() -> void:
	var state := _prepare_elf(3)
	_raise_mage_to_rank_two(state)
	assert_true(state.select_upgrade(&"mage", 2, INCANDESCENT_ID))
	var unit := state.unit
	unit.reset_combat_resources()
	manager.current_room_index = 0
	manager._go_to_next_room()
	assert_same(manager.get_character_state(&"elf"), state)
	assert_eq(state.get_discipline_progress(&"mage").xp, 3)
	assert_eq(state.get_discipline_progress(&"mage").rank, 2)
	assert_eq(
		state.get_discipline_progress(&"mage").get_selected_upgrade_ids(),
		[INCANDESCENT_ID]
	)
	assert_eq(unit.get_progression_spell_modifiers().size(), 1)


func test_starting_a_new_run_resets_xp_rank_and_choices() -> void:
	var old_state := _prepare_elf()
	_raise_mage_to_rank_two(old_state)
	assert_true(old_state.select_upgrade(&"mage", 2, INCANDESCENT_ID))
	assert_true(manager._prepare_preconfigured_run(_make_run(), [ELF_PATH]))
	var new_state: CharacterRunState = manager.get_character_state(&"elf")
	assert_not_same(new_state, old_state)
	assert_eq(new_state.get_discipline_progress(&"mage").xp, 0)
	assert_eq(new_state.get_discipline_progress(&"mage").rank, 1)
	assert_true(new_state.get_discipline_progress(&"mage").get_selected_upgrade_ids().is_empty())


func test_incandescent_core_adds_three_damage_only_to_the_center_cell() -> void:
	var state := _prepare_elf()
	_raise_mage_to_rank_two(state)
	assert_true(state.select_upgrade(&"mage", 2, INCANDESCENT_ID))
	var fireball := _elf_fireball()
	var original_damage := fireball.damage
	var battlefield = _make_fireball_field(state.unit, true)
	var center: Unit = battlefield.grid.get_unit(Vector2i(3, 2))
	var peripheral: Unit = battlefield.grid.get_unit(Vector2i(3, 3))
	battlefield.caster.cast(state.unit, fireball, Vector2i(3, 2))
	assert_eq(center.current_hp, 1000 - original_damage - 3)
	assert_eq(peripheral.current_hp, 1000 - original_damage)
	assert_eq(fireball.damage, original_damage, "la Resource Spell partagée reste immuable")


func test_incandescent_core_does_not_affect_another_spell() -> void:
	var state := _prepare_elf()
	_raise_mage_to_rank_two(state)
	state.select_upgrade(&"mage", 2, INCANDESCENT_ID)
	var battlefield := Factory.make_battlefield(5, 1)
	battlefield.grid.place_unit(state.unit, Vector2i(0, 0))
	var enemy := Unit.new("Cible", 1, 100)
	battlefield.grid.place_unit(enemy, Vector2i(1, 0))
	var other_spell := Factory.make_spell({
		"spell_id": &"another_spell",
		"damage": 10,
		"spell_range": 3,
	})
	battlefield.caster.cast(state.unit, other_spell, Vector2i(1, 0))
	assert_eq(enemy.current_hp, 90)


func test_incandescent_core_does_not_leak_to_another_caster_using_same_spell() -> void:
	var state := _prepare_elf()
	_raise_mage_to_rank_two(state)
	state.select_upgrade(&"mage", 2, INCANDESCENT_ID)
	var other := Unit.new("Autre lanceur", 0)
	var battlefield := Factory.make_battlefield(7, 3)
	battlefield.grid.place_unit(other, Vector2i(0, 1))
	var enemy := Unit.new("Cible", 1, 1000)
	battlefield.grid.place_unit(enemy, Vector2i(3, 1))
	battlefield.caster.cast(other, _elf_fireball(), Vector2i(3, 1))
	assert_eq(enemy.current_hp, 600)


func test_persistent_embers_places_existing_fire_for_exactly_one_turn() -> void:
	var state := _prepare_elf()
	_raise_mage_to_rank_two(state)
	assert_true(state.select_upgrade(&"mage", 2, EMBERS_ID))
	var battlefield = _make_fireball_field(state.unit)
	var fireball := _elf_fireball()
	var center := Vector2i(3, 2)
	var affected_cells: Array = battlefield.caster.get_aoe_cells(fireball, center)
	battlefield.caster.cast(state.unit, fireball, center)
	for cell in affected_cells:
		var effect: TerrainEffectData = battlefield.terrain.get_effect_data(cell)
		assert_not_null(effect)
		if effect != null:
			assert_eq(effect.effect_name, "feu")
		var stored: Dictionary = battlefield.grid.get_effect(cell)
		assert_eq(stored["data"]["duration"], 1)
	battlefield.terrain.tick_all_effects()
	for cell in affected_cells:
		assert_null(battlefield.terrain.get_effect_data(cell))


func test_persistent_embers_does_not_affect_another_spell() -> void:
	var state := _prepare_elf()
	_raise_mage_to_rank_two(state)
	state.select_upgrade(&"mage", 2, EMBERS_ID)
	var battlefield := Factory.make_battlefield(5, 1)
	battlefield.grid.place_unit(state.unit, Vector2i(0, 0))
	var other_spell := Factory.make_spell({
		"spell_id": &"another_free_spell",
		"spell_range": 3,
		"can_target_free_cell": true,
	})
	battlefield.caster.cast(state.unit, other_spell, Vector2i(2, 0))
	assert_null(battlefield.terrain.get_effect_data(Vector2i(2, 0)))


func test_persistent_embers_remains_active_on_a_new_battlefield() -> void:
	var state := _prepare_elf()
	_raise_mage_to_rank_two(state)
	state.select_upgrade(&"mage", 2, EMBERS_ID)
	var first_battlefield = _make_fireball_field(state.unit)
	first_battlefield.caster.cast(state.unit, _elf_fireball(), Vector2i(3, 2))
	state.unit.reset_combat_resources()
	var next_battlefield = _make_fireball_field(state.unit)
	next_battlefield.caster.cast(state.unit, _elf_fireball(), Vector2i(3, 2))
	assert_eq(
		next_battlefield.terrain.get_effect_data(Vector2i(3, 2)).effect_name,
		"feu"
	)


func test_progression_screen_requires_selection_then_confirms_one_choice() -> void:
	var state := _prepare_elf()
	_raise_mage_to_rank_two(state)
	var screen = ProgressionScreenScript.new()
	screen.progression_controller = manager
	add_child_autofree(screen)
	assert_eq(screen.get_choice_card_count(), 2)
	assert_false(screen.is_confirmation_enabled())
	assert_false(screen.confirm_selection())
	assert_true(screen.select_upgrade_card(INCANDESCENT_ID))
	assert_true(screen.is_confirmation_enabled())
	assert_eq(screen.get_selected_upgrade_id(), INCANDESCENT_ID)
	assert_true(screen.confirm_selection())
	assert_eq(
		state.get_discipline_progress(&"mage").get_selected_upgrade_ids(),
		[INCANDESCENT_ID]
	)
	assert_true(state.get_discipline_progress(&"mage").get_pending_rank_choices().is_empty())


func test_victory_with_pending_choice_opens_progression_then_next_room() -> void:
	var state := _prepare_elf(2)
	_raise_mage_to_rank_two(state)
	manager.current_room_index = 0
	var requested_scenes: Array = []
	manager.scene_change_requested.connect(func(path): requested_scenes.append(path))
	manager.on_battle_won()
	assert_eq(requested_scenes[-1], GameManagerScript.PROGRESSION_CHOICE_SCREEN_PATH)
	assert_eq(manager.current_room_index, 0)
	assert_true(manager.choose_progression_upgrade(&"elf", &"mage", 2, EMBERS_ID))
	assert_eq(manager.current_room_index, 1)
	assert_eq(requested_scenes[-1], GameManagerScript.ROOM_TRANSITION_SCREEN_PATH)


func test_victory_without_pending_choice_skips_progression_screen() -> void:
	_prepare_elf(2)
	manager.current_room_index = 0
	var requested_scenes: Array = []
	manager.scene_change_requested.connect(func(path): requested_scenes.append(path))
	manager.on_battle_won()
	assert_false(requested_scenes.has(GameManagerScript.PROGRESSION_CHOICE_SCREEN_PATH))
	assert_eq(requested_scenes[-1], GameManagerScript.ROOM_TRANSITION_SCREEN_PATH)


func test_last_room_resolves_progression_before_run_result() -> void:
	var state := _prepare_elf(1)
	_raise_mage_to_rank_two(state)
	manager.current_room_index = 0
	var requested_scenes: Array = []
	manager.scene_change_requested.connect(func(path): requested_scenes.append(path))
	manager.on_battle_won()
	assert_eq(requested_scenes[-1], GameManagerScript.PROGRESSION_CHOICE_SCREEN_PATH)
	manager.choose_progression_upgrade(&"elf", &"mage", 2, INCANDESCENT_ID)
	assert_eq(requested_scenes[-1], GameManagerScript.RUN_RESULT_SCREEN_PATH)


func test_historical_victory_still_routes_to_reward_screen() -> void:
	manager._build_heroes_from_draft([WARRIOR_PATH], [], [])
	manager._initialize_run_state(_make_run(2, true))
	manager.current_room_index = 0
	var requested_scenes: Array = []
	manager.scene_change_requested.connect(func(path): requested_scenes.append(path))
	manager.on_battle_won()
	assert_true(manager.character_states.is_empty())
	assert_eq(requested_scenes[-1], GameManagerScript.REWARD_SCREEN_PATH)
	assert_eq(manager.heroes[0].spells.size(), 8)
