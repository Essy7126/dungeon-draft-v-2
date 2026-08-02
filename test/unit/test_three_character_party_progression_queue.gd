extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")
const ProgressionScreenScript = preload(
	"res://ui/progression/progression_choice_screen.gd"
)

const DISCIPLINE_ONE := &"discipline_one"
const DISCIPLINE_TWO := &"discipline_two"

var manager


func before_each() -> void:
	manager = GameManagerScript.new()


func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager.cleanup_run_state()
		manager.free()


func _make_upgrade(
		discipline_id: StringName,
		upgrade_id: StringName
	) -> SkillUpgradeData:
	var upgrade := SkillUpgradeData.new()
	upgrade.upgrade_id = upgrade_id
	upgrade.display_name = "Evolution %s" % upgrade_id
	upgrade.description = "Choix synthetique"
	upgrade.discipline_id = discipline_id
	upgrade.rank = 2
	return upgrade


func _make_discipline(
		discipline_id: StringName,
		display_name: String,
		upgrade_id: StringName
	) -> DisciplineData:
	var rank_two := DisciplineRankData.new()
	rank_two.rank = 2
	rank_two.required_total_xp = 1
	rank_two.choices = [_make_upgrade(discipline_id, upgrade_id)]
	var discipline := DisciplineData.new()
	discipline.discipline_id = discipline_id
	discipline.display_name = display_name
	discipline.ranks = [rank_two]
	return discipline


func _make_hero(
		character_id: StringName,
		display_name: String,
		disciplines: Array[DisciplineData]
	) -> UnitData:
	var data := UnitData.new()
	data.unit_id = character_id
	data.unit_name = display_name
	data.disciplines = disciplines
	return data


func _prepare_pending_party() -> Array[CharacterRunState]:
	var run := RunData.new()
	run.run_name = "File synthetique"
	run.rooms = [RoomData.new(), RoomData.new()]
	var hero_a := _make_hero(
		&"hero_a",
		"Heros A",
		[
			_make_discipline(DISCIPLINE_ONE, "Discipline 1", &"a_d1"),
			_make_discipline(DISCIPLINE_TWO, "Discipline 2", &"a_d2"),
		],
	)
	var hero_b := _make_hero(
		&"hero_b",
		"Heros B",
		[_make_discipline(DISCIPLINE_ONE, "Discipline 1", &"b_d1")],
	)
	var hero_c := _make_hero(
		&"hero_c",
		"Heros C",
		[_make_discipline(DISCIPLINE_ONE, "Discipline 1", &"c_d1")],
	)
	assert_true(manager._prepare_preconfigured_run(run, [hero_a, hero_b, hero_c]))
	var states: Array[CharacterRunState] = manager.get_ordered_character_states()
	for state in states:
		for discipline in state.get_disciplines():
			state.add_discipline_xp(discipline.discipline_id, 1)
	return states


func _open_screen():
	var screen = ProgressionScreenScript.new()
	screen.progression_controller = manager
	add_child_autofree(screen)
	return screen


func test_pending_choices_follow_hero_then_discipline_then_rank_order() -> void:
	_prepare_pending_party()
	var pending: Array[Dictionary] = manager.get_pending_progression_choices()
	assert_eq(pending.size(), 4)
	assert_eq(
		pending.map(func(choice): return choice["character_id"]),
		[&"hero_a", &"hero_a", &"hero_b", &"hero_c"],
	)
	assert_eq(
		pending.map(func(choice): return choice["character_name"]),
		["Heros A", "Heros A", "Heros B", "Heros C"],
	)
	assert_eq(
		pending.map(func(choice): return choice["discipline_id"]),
		[DISCIPLINE_ONE, DISCIPLINE_TWO, DISCIPLINE_ONE, DISCIPLINE_ONE],
	)
	assert_eq(pending.map(func(choice): return choice["rank"]), [2, 2, 2, 2])


func test_legacy_screen_api_keeps_owner_order_without_post_combat_routing() -> void:
	var states := _prepare_pending_party()
	manager.current_room_index = 0
	var requested_scenes: Array[String] = []
	manager.scene_change_requested.connect(func(path): requested_scenes.append(path))
	var screen = _open_screen()
	assert_same(manager.get_active_progression_screen(), screen)
	var duplicate = _open_screen()
	assert_true(duplicate.is_closed_for_progression())
	assert_same(manager.get_active_progression_screen(), screen)

	var expected := [
		{ "state": states[0], "name": "Heros A", "discipline": DISCIPLINE_ONE, "upgrade": &"a_d1" },
		{ "state": states[0], "name": "Heros A", "discipline": DISCIPLINE_TWO, "upgrade": &"a_d2" },
		{ "state": states[1], "name": "Heros B", "discipline": DISCIPLINE_ONE, "upgrade": &"b_d1" },
		{ "state": states[2], "name": "Heros C", "discipline": DISCIPLINE_ONE, "upgrade": &"c_d1" },
	]
	for index in range(expected.size()):
		var entry: Dictionary = expected[index]
		var choice := screen.get_current_choice()
		assert_eq(choice["character_name"], entry["name"])
		assert_eq(choice["character_id"], entry["state"].character_id)
		assert_eq(choice["discipline_id"], entry["discipline"])
		assert_eq(choice["choices"][0].upgrade_id, entry["upgrade"])
		assert_true(screen.select_upgrade_card(entry["upgrade"]))
		assert_true(screen.confirm_selection())
		var progress: DisciplineProgressState = entry["state"].get_discipline_progress(
			entry["discipline"]
		)
		assert_eq(progress.get_selected_upgrade_ids(), [entry["upgrade"]])
		for later_index in range(index + 1, expected.size()):
			var later: Dictionary = expected[later_index]
			var later_progress: DisciplineProgressState = later["state"].get_discipline_progress(
				later["discipline"]
			)
			assert_true(later_progress.get_selected_upgrade_ids().is_empty())
		if index < expected.size() - 1:
			assert_same(manager.get_active_progression_screen(), screen)
			assert_eq(requested_scenes.size(), 0)

	assert_true(screen.is_closed_for_progression())
	assert_false(manager.has_active_progression_screen())
	assert_false(manager._awaiting_post_battle_progression)
	manager.on_battle_won()
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
