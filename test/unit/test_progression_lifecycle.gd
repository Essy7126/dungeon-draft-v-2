extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")
const ProgressionScreenScript = preload(
	"res://ui/progression/progression_choice_screen.gd"
)

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const INCANDESCENT_ID := &"elf_mage_incandescent_core"
const EMBERS_ID := &"elf_mage_persistent_embers"
const NEW_UPGRADES := [
	[&"archer", &"elf_archer_eagle_eye"],
	[&"archer", &"elf_archer_repel_arrow"],
	[&"assassin", &"elf_assassin_backstab"],
	[&"assassin", &"elf_assassin_venomous_blade"],
	[&"healer", &"elf_healer_abundant_sap"],
	[&"healer", &"elf_healer_protective_bark"],
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


func _make_run(room_count: int = 3) -> RunData:
	var run := RunData.new()
	run.run_name = "Lifecycle"
	for _room_index in range(room_count):
		run.rooms.append(RoomData.new())
	return run


func _prepare_elf(room_count: int = 3) -> CharacterRunState:
	manager.start_preconfigured_run(_make_run(room_count), [ELF_PATH])
	var state: CharacterRunState = manager.get_character_state(&"elf")
	assert_not_null(state)
	return state


func _make_second_elf_data() -> UnitData:
	var elf_data := load(ELF_PATH) as UnitData
	var second := UnitData.new()
	second.unit_id = &"elf_two"
	second.unit_name = "Elfe deux"
	second.disciplines = elf_data.disciplines.duplicate()
	second.spells = elf_data.spells.duplicate()
	return second


func _raise_mage_to_rank_two(state: CharacterRunState) -> void:
	var result := state.add_discipline_xp(&"mage", 3)
	assert_eq(result.get("rank", 0), 2)


func _fireball() -> Spell:
	return (load(ELF_PATH) as UnitData).spells[2]


func _emit_successful_cast(unit: Unit) -> void:
	EventBus.spell_cast.emit(unit, _fireball(), {})


func _progress_xp(state: CharacterRunState) -> int:
	return state.get_discipline_progress(&"mage").xp


func _manager_connection_count() -> int:
	var wanted := Callable(manager, "_on_successful_spell_cast")
	var count := 0
	for connection in EventBus.spell_cast.get_connections():
		if connection.get("callable") == wanted:
			count += 1
	return count


func _open_progression_screen():
	var screen = ProgressionScreenScript.new()
	screen.progression_controller = manager
	add_child_autofree(screen)
	return screen


func test_service_connection_is_idempotent_and_explicitly_disconnected() -> void:
	assert_true(manager.is_progression_service_connected())
	assert_eq(_manager_connection_count(), 1)
	manager._ready()
	manager._connect_progression_service()
	assert_eq(_manager_connection_count(), 1)
	manager._disconnect_progression_service()
	assert_false(manager.is_progression_service_connected())
	assert_eq(_manager_connection_count(), 0)
	manager._connect_progression_service()
	assert_eq(_manager_connection_count(), 1)


func test_three_successive_runs_each_gain_exactly_one_xp_per_cast() -> void:
	for _run_index in range(3):
		var state := _prepare_elf()
		manager._ready()
		_emit_successful_cast(state.unit)
		assert_eq(_progress_xp(state), 1)
		assert_eq(_manager_connection_count(), 1)


func test_room_change_and_combat_reset_do_not_multiply_cast_callbacks() -> void:
	var state := _prepare_elf()
	_emit_successful_cast(state.unit)
	state.unit.reset_combat_resources()
	manager.current_room_index = 0
	manager._go_to_next_room()
	_emit_successful_cast(state.unit)
	assert_eq(_progress_xp(state), 2)
	assert_eq(_manager_connection_count(), 1)


func test_removed_caster_cannot_change_the_current_run() -> void:
	var old_state := _prepare_elf()
	var old_unit := old_state.unit
	_emit_successful_cast(old_unit)
	assert_eq(_progress_xp(old_state), 1)
	var current_state := _prepare_elf()
	_emit_successful_cast(old_unit)
	assert_eq(_progress_xp(current_state), 0)
	_emit_successful_cast(current_state.unit)
	assert_eq(_progress_xp(current_state), 1)


func test_new_preconfigured_run_disposes_old_character_state() -> void:
	var old_state := _prepare_elf()
	_raise_mage_to_rank_two(old_state)
	assert_true(old_state.select_upgrade(&"mage", 2, INCANDESCENT_ID))
	var old_unit := old_state.unit
	assert_eq(old_unit.get_progression_spell_modifiers().size(), 1)
	var new_state := _prepare_elf()
	assert_not_same(new_state, old_state)
	assert_null(old_state.unit)
	assert_null(old_state.loadout)
	assert_eq(old_unit.get_progression_spell_modifiers().size(), 0)
	assert_eq(manager.character_states.size(), 1)


func test_old_unit_becomes_releasable_after_run_cleanup() -> void:
	var state := _prepare_elf()
	var old_unit: Unit = state.unit
	var old_unit_ref: WeakRef = weakref(old_unit)
	manager.cleanup_run_state()
	state = null
	old_unit = null
	assert_null(old_unit_ref.get_ref())


func test_return_to_title_clears_all_progression_transients() -> void:
	var state := _prepare_elf()
	_raise_mage_to_rank_two(state)
	manager._awaiting_post_battle_progression = true
	manager._record_run_result(true)
	var screen = _open_progression_screen()
	assert_true(manager.has_active_progression_screen())
	manager.return_to_title()
	assert_true(manager.character_states.is_empty())
	assert_true(manager.heroes.is_empty())
	assert_true(manager.get_pending_progression_choices().is_empty())
	assert_false(manager._awaiting_post_battle_progression)
	assert_true(manager.get_last_run_result().is_empty())
	assert_false(manager.has_active_progression_screen())
	assert_true(screen.is_closed_for_progression())


func test_return_to_title_clears_each_new_rank_two_modifier() -> void:
	for upgrade_entry in NEW_UPGRADES:
		var state := _prepare_elf()
		var discipline_id: StringName = upgrade_entry[0]
		var upgrade_id: StringName = upgrade_entry[1]
		state.add_discipline_xp(discipline_id, 3)
		assert_true(state.select_upgrade(discipline_id, 2, upgrade_id))
		var old_unit := state.unit
		assert_eq(old_unit.get_progression_spell_modifiers().size(), 1)
		manager.return_to_title()
		assert_true(manager.character_states.is_empty())
		assert_true(manager.heroes.is_empty())
		assert_eq(old_unit.get_progression_spell_modifiers().size(), 0)


func test_new_run_starts_at_zero_xp_rank_one_without_choice_or_result() -> void:
	var old_state := _prepare_elf()
	_raise_mage_to_rank_two(old_state)
	assert_true(old_state.select_upgrade(&"mage", 2, EMBERS_ID))
	manager._record_run_result(false)
	var state := _prepare_elf()
	var progress := state.get_discipline_progress(&"mage")
	assert_eq(progress.xp, 0)
	assert_eq(progress.rank, 1)
	assert_true(progress.get_pending_rank_choices().is_empty())
	assert_true(progress.get_selected_upgrade_ids().is_empty())
	assert_true(manager.get_pending_progression_choices().is_empty())
	assert_true(manager.get_last_run_result().is_empty())
	assert_true(state.unit.get_progression_spell_modifiers().is_empty())


func test_repeated_modifier_sync_and_room_change_keep_one_modifier() -> void:
	var state := _prepare_elf()
	_raise_mage_to_rank_two(state)
	assert_true(state.select_upgrade(&"mage", 2, INCANDESCENT_ID))
	state._sync_progression_modifiers_to_unit()
	state._sync_progression_modifiers_to_unit()
	state.unit.reset_combat_resources()
	manager.current_room_index = 0
	manager._go_to_next_room()
	assert_eq(state.unit.get_progression_spell_modifiers().size(), 1)


func test_unit_setter_deduplicates_the_same_progression_modifier() -> void:
	var state := _prepare_elf()
	_raise_mage_to_rank_two(state)
	assert_true(state.select_upgrade(&"mage", 2, INCANDESCENT_ID))
	var modifier: SpellModifier = state.unit.get_progression_spell_modifiers()[0]
	var duplicates: Array[SpellModifier] = [modifier, modifier]
	state.unit.set_progression_spell_modifiers(duplicates)
	assert_eq(state.unit.get_progression_spell_modifiers(), [modifier])


func test_two_characters_keep_independent_modifier_collections() -> void:
	assert_true(manager._prepare_preconfigured_run(
		_make_run(),
		[ELF_PATH, _make_second_elf_data()]
	))
	var first: CharacterRunState = manager.get_character_state(&"elf")
	var second: CharacterRunState = manager.get_character_state(&"elf_two")
	_raise_mage_to_rank_two(first)
	assert_true(first.select_upgrade(&"mage", 2, INCANDESCENT_ID))
	assert_eq(first.unit.get_progression_spell_modifiers().size(), 1)
	assert_true(second.unit.get_progression_spell_modifiers().is_empty())
	assert_eq(_progress_xp(second), 0)


func test_only_one_progression_screen_can_register() -> void:
	var state := _prepare_elf()
	_raise_mage_to_rank_two(state)
	var first = _open_progression_screen()
	var second = _open_progression_screen()
	assert_same(manager.get_active_progression_screen(), first)
	assert_false(first.is_closed_for_progression())
	assert_true(second.is_closed_for_progression())


func test_double_confirmation_applies_only_one_upgrade() -> void:
	var state := _prepare_elf()
	_raise_mage_to_rank_two(state)
	var screen = _open_progression_screen()
	assert_true(screen.select_upgrade_card(INCANDESCENT_ID))
	assert_true(screen.confirm_selection())
	assert_false(screen.confirm_selection())
	assert_eq(
		state.get_discipline_progress(&"mage").get_selected_upgrade_ids(),
		[INCANDESCENT_ID]
	)
	assert_eq(state.unit.get_progression_spell_modifiers().size(), 1)
	assert_false(manager.has_active_progression_screen())


func test_successive_screen_choices_use_distinct_character_data() -> void:
	assert_true(manager._prepare_preconfigured_run(
		_make_run(),
		[ELF_PATH, _make_second_elf_data()]
	))
	var first_state: CharacterRunState = manager.get_character_state(&"elf")
	var second_state: CharacterRunState = manager.get_character_state(&"elf_two")
	_raise_mage_to_rank_two(first_state)
	_raise_mage_to_rank_two(second_state)
	var screen = _open_progression_screen()
	var first_character_id: StringName = screen.get_current_choice()["character_id"]
	assert_true(screen.select_upgrade_card(INCANDESCENT_ID))
	assert_true(screen.confirm_selection())
	await get_tree().process_frame
	var second_character_id: StringName = screen.get_current_choice()["character_id"]
	assert_ne(second_character_id, first_character_id)
	assert_same(manager.get_active_progression_screen(), screen)
	assert_true(screen.select_upgrade_card(EMBERS_ID))
	assert_true(screen.confirm_selection())
	assert_true(screen.is_closed_for_progression())
	assert_false(manager.has_active_progression_screen())


func test_cleanup_during_choice_blocks_late_confirmation() -> void:
	var state := _prepare_elf()
	_raise_mage_to_rank_two(state)
	var progress := state.get_discipline_progress(&"mage")
	var screen = _open_progression_screen()
	assert_true(screen.select_upgrade_card(INCANDESCENT_ID))
	manager.cleanup_run_state()
	assert_true(screen.is_closed_for_progression())
	assert_false(manager.has_active_progression_screen())
	assert_false(screen.confirm_selection())
	assert_true(progress.get_selected_upgrade_ids().is_empty())


func test_duplicate_battle_win_signal_opens_progression_only_once() -> void:
	var state := _prepare_elf()
	_raise_mage_to_rank_two(state)
	manager.current_room_index = 0
	var requested_scenes: Array = []
	var cleared_rooms: Array = []
	manager.scene_change_requested.connect(
		func(path): requested_scenes.append(path)
	)
	manager.room_cleared.connect(
		func(index): cleared_rooms.append(index)
	)
	manager.on_battle_won()
	manager.on_battle_won()
	assert_eq(
		requested_scenes.count(GameManagerScript.PROGRESSION_CHOICE_SCREEN_PATH),
		1
	)
	assert_eq(cleared_rooms, [0])
	assert_true(manager._awaiting_post_battle_progression)


func test_repeated_run_stress_has_no_cumulative_xp_or_modifiers() -> void:
	for _cycle in range(5):
		var state := _prepare_elf()
		for _cast_index in range(3):
			_emit_successful_cast(state.unit)
		assert_eq(_progress_xp(state), 3)
		assert_true(state.select_upgrade(&"mage", 2, INCANDESCENT_ID))
		state.unit.reset_combat_resources()
		manager.current_room_index = 0
		manager._go_to_next_room()
		assert_eq(state.unit.get_progression_spell_modifiers().size(), 1)
		manager.cleanup_run_state()

		var fresh_state := _prepare_elf()
		_emit_successful_cast(fresh_state.unit)
		assert_eq(_progress_xp(fresh_state), 1)
		assert_eq(fresh_state.get_discipline_progress(&"mage").rank, 1)
		assert_true(fresh_state.unit.get_progression_spell_modifiers().is_empty())
		assert_eq(_manager_connection_count(), 1)
