extends GutTest

const SCREEN_SCENE := preload("res://ui/post_combat/PostCombatScreen.tscn")
const MAIN_RUN: RunData = preload("res://data/runs/first_run.tres")
const WAVE_RUN: RunData = preload("res://data/runs/fixed_trio_prototype_run.tres")


func before_each() -> void:
	GameManager.cleanup_run_state()
	await get_tree().process_frame


func after_each() -> void:
	GameManager.cleanup_run_state()
	await get_tree().process_frame


func test_main_post_combat_skips_room_decision_and_hides_wave_actions() -> void:
	_prepare_victory(MAIN_RUN)
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	_advance_once(screen)
	assert_eq(screen.get_phase_name(), &"COMBAT_STATS")
	assert_false(screen.get_node("%DecisionPanel").visible)
	assert_false(screen.get_node("%PushWaveButton").is_visible_in_tree())
	assert_false(await screen.choose_continue_room())


func test_main_post_combat_reaches_reward_flow() -> void:
	_prepare_victory(MAIN_RUN)
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	for _index in 12:
		if screen.get_phase_name() == &"REWARD_SELECTION":
			break
		screen.advance_or_skip()
	assert_eq(screen.get_phase_name(), &"REWARD_SELECTION")
	assert_eq(screen.get_reward_card_count(), 2)


func test_test_run_post_combat_exposes_wave_decision_when_available() -> void:
	_prepare_victory(WAVE_RUN)
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	_advance_once(screen)
	assert_eq(screen.get_phase_name(), &"ROOM_DECISION")
	assert_true(screen.get_node("%DecisionPanel").visible)
	assert_true(screen.get_node("%PushWaveButton").visible)
	assert_eq(
		GameManager.get_post_combat_decision_snapshot().room_flow_mode,
		&"WAVE_CHAIN",
	)


func test_public_phase_entry_cannot_force_wave_decision_for_main_run() -> void:
	_prepare_victory(MAIN_RUN)
	var screen := SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._enter_phase(PostCombatScreen.Phase.ROOM_DECISION)
	assert_eq(screen.get_phase_name(), &"COMBAT_STATS")
	assert_false(screen.get_node("%DecisionPanel").visible)


func _prepare_victory(run: RunData) -> void:
	assert_true(GameManager._prepare_preconfigured_run(
		run, GameManager.PRODUCTION_HERO_DATA_PATHS
	))
	_consume_known_warrior_uid_warning()
	GameManager.current_room_index = 0
	GameManager.begin_combat_report()
	GameManager._room_outcome_resolved = true
	GameManager._last_combat_report = GameManager._finalize_current_combat_report(true)
	GameManager._room_exit_selected = not run.uses_wave_chain()


func _consume_known_warrior_uid_warning() -> void:
	# Dette de ressource anterieure a RUN_FLOW_ISOLATION_V1, observee dans la baseline.
	for error in get_errors():
		if error.contains_text("uid://0flkpto1jkby"):
			error.handled = true


func _advance_once(screen: PostCombatScreen) -> void:
	screen.advance_or_skip()
	screen.advance_or_skip()
