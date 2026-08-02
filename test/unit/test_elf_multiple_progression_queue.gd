extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")
const ProgressionScreenScript = preload(
	"res://ui/progression/progression_choice_screen.gd"
)

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const DISCIPLINE_ORDER := [&"archer", &"assassin", &"mage", &"healer"]
const FIRST_CHOICE_IDS := [
	&"elf_archer_eagle_eye",
	&"elf_assassin_dans_le_dos",
	&"elf_mage_cur_incandescent",
	&"elf_healer_seve_abondante",
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


func _make_run(room_count: int = 2) -> RunData:
	var run := RunData.new()
	for _room_index in range(room_count):
		run.rooms.append(RoomData.new())
	return run


func _prepare_elf(room_count: int = 2) -> CharacterRunState:
	assert_true(manager._prepare_preconfigured_run(
		_make_run(room_count),
		[ELF_PATH],
	))
	return manager.get_character_state(&"elf")


func _raise_all_disciplines(state: CharacterRunState) -> void:
	for discipline_id in DISCIPLINE_ORDER:
		var result := state.add_discipline_xp(discipline_id, 3)
		assert_eq(result.get("rank", 0), 2, str(discipline_id))


func _open_screen():
	var screen = ProgressionScreenScript.new()
	screen.progression_controller = manager
	add_child_autofree(screen)
	return screen


func _make_second_elf_data() -> UnitData:
	var source := load(ELF_PATH) as UnitData
	var second := UnitData.new()
	second.unit_id = &"elf_two"
	second.unit_name = "Elfe deux"
	second.disciplines = source.disciplines.duplicate()
	second.spells = source.spells.duplicate()
	return second


func test_four_disciplines_pending_in_unit_data_order() -> void:
	var state := _prepare_elf()
	_raise_all_disciplines(state)
	var pending: Array = manager.get_pending_progression_choices()
	assert_eq(pending.size(), 4)
	assert_eq(
		pending.map(func(choice): return choice["discipline_id"]),
		DISCIPLINE_ORDER,
	)
	assert_eq(
		pending.map(func(choice): return choice["rank"]),
		[2, 2, 2, 2],
	)
	assert_true(pending.all(func(choice): return choice["choices"].size() == 2))


func test_pending_queue_uses_hero_order_before_discipline_order() -> void:
	assert_true(manager._prepare_preconfigured_run(
		_make_run(),
		[ELF_PATH, _make_second_elf_data()],
	))
	var first := manager.get_character_state(&"elf") as CharacterRunState
	var second := manager.get_character_state(&"elf_two") as CharacterRunState
	_raise_all_disciplines(first)
	_raise_all_disciplines(second)
	var pending: Array = manager.get_pending_progression_choices()
	assert_eq(pending.size(), 8)
	assert_eq(
		pending.slice(0, 4).map(func(choice): return choice["character_id"]),
		[&"elf", &"elf", &"elf", &"elf"],
	)
	assert_eq(
		pending.slice(0, 4).map(func(choice): return choice["discipline_id"]),
		DISCIPLINE_ORDER,
	)
	assert_eq(
		pending.slice(4, 8).map(func(choice): return choice["character_id"]),
		[&"elf_two", &"elf_two", &"elf_two", &"elf_two"],
	)
	assert_eq(
		pending.slice(4, 8).map(func(choice): return choice["discipline_id"]),
		DISCIPLINE_ORDER,
	)


func test_legacy_screen_api_resolves_queue_but_victory_never_opens_it() -> void:
	var state := _prepare_elf(2)
	_raise_all_disciplines(state)
	manager.current_room_index = 0
	var requested_scenes: Array = []
	manager.scene_change_requested.connect(
		func(path): requested_scenes.append(path)
	)
	var screen = _open_screen()
	assert_same(manager.get_active_progression_screen(), screen)
	assert_eq(screen.get_choice_card_count(), 2)

	for index in DISCIPLINE_ORDER.size():
		assert_eq(
			screen.get_current_choice().get("discipline_id"),
			DISCIPLINE_ORDER[index],
		)
		assert_eq(screen.get_selected_upgrade_id(), &"")
		assert_false(screen.is_confirmation_enabled())
		assert_true(screen.select_upgrade_card(FIRST_CHOICE_IDS[index]))
		assert_true(screen.confirm_selection())
		assert_false(screen.confirm_selection(), "une confirmation ne vaut qu'une fois")
		await get_tree().process_frame
		assert_eq(
			state.get_discipline_progress(
				DISCIPLINE_ORDER[index]
			).get_selected_upgrade_ids(),
			[FIRST_CHOICE_IDS[index]],
		)
		if index < DISCIPLINE_ORDER.size() - 1:
			assert_same(manager.get_active_progression_screen(), screen)
			assert_eq(screen.get_choice_card_count(), 2)
			assert_eq(
				screen.get_current_choice().get("discipline_id"),
				DISCIPLINE_ORDER[index + 1],
			)

	assert_true(screen.is_closed_for_progression())
	assert_false(manager.has_active_progression_screen())
	assert_true(manager.get_pending_progression_choices().is_empty())
	manager.on_battle_won()
	assert_eq(manager.current_room_index, 0)
	assert_eq(requested_scenes, [GameManagerScript.POST_COMBAT_SCREEN_PATH])
	var reward: Dictionary = manager.get_post_combat_reward_options()[0]
	assert_true(manager.confirm_post_combat_reward(
		reward["reward_id"], reward["target_character_id"]
	)["success"])
	assert_true(manager.complete_post_combat_transition(
		manager.get_current_combat_report().report_id
	))
	assert_eq(manager.current_room_index, 1)
	assert_eq(
		requested_scenes,
		[
			GameManagerScript.POST_COMBAT_SCREEN_PATH,
			GameManagerScript.ROOM_TRANSITION_SCREEN_PATH,
		],
	)


func test_queue_keeps_one_registered_screen_during_successive_replacements() -> void:
	var state := _prepare_elf()
	_raise_all_disciplines(state)
	var first = _open_screen()
	var second = _open_screen()
	assert_same(manager.get_active_progression_screen(), first)
	assert_true(second.is_closed_for_progression())
	assert_true(first.select_upgrade_card(FIRST_CHOICE_IDS[0]))
	assert_true(first.confirm_selection())
	await get_tree().process_frame
	assert_same(manager.get_active_progression_screen(), first)
	assert_eq(first.get_current_choice().get("discipline_id"), &"assassin")
	assert_eq(first.get_selected_upgrade_id(), &"")
	assert_eq(first.get_choice_card_count(), 2)


func test_new_run_discards_all_old_pending_choices() -> void:
	var old_state := _prepare_elf()
	_raise_all_disciplines(old_state)
	assert_eq(manager.get_pending_progression_choices().size(), 4)
	var fresh_state := _prepare_elf()
	assert_not_same(fresh_state, old_state)
	assert_true(manager.get_pending_progression_choices().is_empty())
	for discipline_id in DISCIPLINE_ORDER:
		var progress := fresh_state.get_discipline_progress(discipline_id)
		assert_eq(progress.xp, 0)
		assert_eq(progress.rank, 1)
		assert_true(progress.get_pending_rank_choices().is_empty())
		assert_true(progress.get_selected_upgrade_ids().is_empty())
