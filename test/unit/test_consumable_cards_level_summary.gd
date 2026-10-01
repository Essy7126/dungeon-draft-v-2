extends GutTest
const LevelSummary := preload("res://ui/expedition/consumable_level_summary.gd")
const Progression := preload("res://core/expedition/consumable_progression_v1.gd")
var manager


class Manager:
	extends "res://core/game_manager.gd"

	func _request_scene_change(
		_path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		pass


	func start_next_battle() -> void:
		pass


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func before_each() -> void:
	manager = Manager.new()
	add_child(manager)
	manager.select_run_variant("cards")
	manager.expedition_save_path = "user://level_summary_%d.json" % Time.get_ticks_usec()
	assert_true(manager.start_expedition(33, { }, false, true, "normal", true))


func after_each() -> void:
	ExpeditionSaveService.remove_snapshot(manager.expedition_save_path)
	manager.cleanup_run_state()
	manager.free()


func test_grouped_level_summary_uses_profile_without_mutation() -> void:
	var cards = manager.expedition.cards
	cards.level = 8
	var snapshot: Dictionary = manager.get_expedition_snapshot()
	var gains := LevelSummary.read(cards, 1)
	assert_eq(gains.gained, 7)
	assert_eq(gains.elements_gained, Progression.element_budget(8) - Progression.element_budget(1))
	assert_eq(gains.training_gained, Progression.training_slots(8) - Progression.training_slots(1))
	assert_eq(manager.get_expedition_snapshot(), snapshot, "Reading gains never grants them again")


func test_available_points_are_distinct_from_new_gains() -> void:
	var cards = manager.expedition.cards
	cards.level = 3
	var before := LevelSummary.read(cards, 2)
	cards.masteries.earth += 1
	var after := LevelSummary.read(cards, 2)
	assert_eq(after.elements_gained, before.elements_gained)
	assert_eq(after.elements_left, before.elements_left - 1)


func test_early_level_can_be_acknowledged_without_spending_points() -> void:
	var session = manager.expedition
	session.cards.level = 2
	session.advancement_from_level = 1
	session.advancement_step = "advancement"
	var before := LevelSummary.read(session.cards, 1)
	assert_true(session.advance_level_step().success)
	assert_eq(session.advancement_step, "")
	assert_eq(LevelSummary.read(session.cards, 1), before)


func test_specialization_remains_required() -> void:
	var session = manager.expedition
	session.cards.level = Progression.specialization_level()
	session.cards.specialization = ""
	session.advancement_step = "advancement"
	assert_true(LevelSummary.read(session.cards, 1).specialization_required)
	assert_false(session.advance_level_step().success)
	assert_eq(session.advancement_step, "advancement")


func test_acknowledgement_preserves_points_after_saved_reload() -> void:
	assert_true(manager.expedition.combat_won())
	assert_true(manager.acknowledge_expedition_combat_receipt().success)
	var previous: int = manager.expedition.advancement_from_level
	var before := LevelSummary.read(manager.expedition.cards, previous)
	var result: Dictionary = manager.advance_expedition_level_step()
	assert_true(result.success)
	assert_true(result.saved)
	var saved := ExpeditionSaveService.read_snapshot(manager.expedition_save_path)
	assert_false(saved.is_empty())
	assert_true(manager.restore_expedition_snapshot(saved))
	assert_eq(manager.expedition.advancement_step, "")
	assert_eq(LevelSummary.read(manager.expedition.cards, previous), before)
