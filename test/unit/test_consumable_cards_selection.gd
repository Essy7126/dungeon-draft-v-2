extends GutTest
## Public preparation, real catalogs and the production departure consumer.
const SCREEN := preload("res://ui/selection/CharacterSelectionScreen.tscn")
const Catalog := preload("res://ui/selection/consumable_departure_catalog.gd")
var screen: CharacterSelectionScreen
var setup
var previous_variant := ""


class Manager:
	extends "res://tools/consumable_cards/integration_smoke.gd".Manager


class GuardScreen:
	extends CharacterSelectionScreen
	var launches := 0


	func _launch_adventure() -> void:
		launches += 1


func before_each() -> void:
	previous_variant = GameManager.selected_run_variant
	GameManager.selected_run_variant = "cards"
	screen = SCREEN.instantiate()
	add_child_autofree(screen)
	await wait_process_frames(3)
	setup = screen._cards_setup


func after_each() -> void:
	GameManager.selected_run_variant = previous_variant
	GameManager.cancel_expedition_replacement()
	await wait_process_frames(2)


func test_appearances_and_free_windows_keep_the_complete_preparation() -> void:
	for index in 3:
		assert_true(screen.select_character(index))
		assert_eq(setup.hero, index)
		assert_not_null(setup._hero_art.texture)
		assert_true(setup._portraits[index].button_pressed)
	assert_null(setup.find_child("SetupRotateRight", true, false))
	assert_null(setup.find_child("SetupStep_0", true, false))
	var before: Dictionary = setup.payload()
	for key in ["difficulty", "deck", "elements", "class"]:
		setup.open_window(key)
		await wait_process_frames(2)
		assert_eq(setup._modal, key)
		setup.open_window("deck" if key != "deck" else "class")
		assert_eq(setup._modal, key, "Only one preparation window")
		setup.close_window()
		await wait_process_frames(2)
		assert_true(setup._socles[key].has_focus())
		assert_eq(setup.payload(), before)


func test_deck_limits_common_cards_and_class_drafts() -> void:
	setup.open_window("deck")
	await wait_process_frames(2)
	_button("Starter_a01").pressed.emit()
	await wait_process_frames(2)
	assert_true(_button("ToggleStarter").disabled)
	_button("RemoveStarter").pressed.emit()
	await wait_process_frames(2)
	assert_true(screen.start_button.disabled)
	_button("Starter_n01").pressed.emit()
	await wait_process_frames(2)
	assert_eq(setup.find_child("StarterCategory", true, false).text, "Commune · toutes classes")
	_button("ToggleStarter").pressed.emit()
	await wait_process_frames(2)
	assert_eq(setup.selection.card_families.count("n01"), 1)
	assert_true(Catalog.valid_departure(setup.payload()))
	var draft: Dictionary = setup.payload()
	setup.close_window()
	setup.open_window("class")
	for id in ["gardien", "arpenteur", "thaumaturge", "assassin"]:
		_button("Choice_" + id).pressed.emit()
		await wait_process_frames(2)
		assert_eq(setup.selection.class_id, id)
		assert_true(Catalog.valid_departure(setup.payload()))
	assert_eq(setup.payload(), draft)
	setup.close_window()
	setup.open_window("deck")
	_button("Starter_a02").pressed.emit()
	await wait_process_frames(2)
	assert_eq(setup.selection.card_families.count("a02"), 3)
	assert_true(_button("ToggleStarter").disabled)
	_button("ToggleStarter").pressed.emit()
	assert_eq(setup.selection.card_families.size(), 15)
	assert_eq(setup.selection.card_families.count("a02"), 3)
	_button("Starter_a01").pressed.emit()
	await wait_process_frames(2)
	_button("RemoveStarter").pressed.emit()
	await wait_process_frames(2)
	_button("Starter_a02").pressed.emit()
	await wait_process_frames(2)
	assert_true(
		_button("ToggleStarter").disabled,
		"Three-copy cap also applies to incomplete decks",
	)
	_button("ToggleStarter").pressed.emit()
	assert_eq(setup.selection.card_families.size(), 14)
	assert_eq(setup.selection.card_families.count("a02"), 3)
	_button("Starter_a01").pressed.emit()
	await wait_process_frames(2)
	_button("ToggleStarter").pressed.emit()
	await wait_process_frames(2)
	assert_true(Catalog.valid_departure(setup.payload()))
	setup.selection.card_families[0] = "t01"
	assert_false(
		Catalog.valid_departure(setup.payload()),
		"Another class is forbidden at departure",
	)


func test_elements_and_difficulty_reach_the_real_threshold_without_reselection() -> void:
	setup.open_window("elements")
	await wait_process_frames(2)
	(setup.find_child("DepartureMastery_fire", true, false) as SpinBox).value = 3
	(setup.find_child("DepartureMastery_water", true, false) as SpinBox).value = 4
	assert_eq(setup.selection.masteries.fire, 3)
	assert_eq(setup.selection.masteries.water, 1, "Four points total")
	(setup.find_child("DepartureMastery_water", true, false) as SpinBox).value = 0
	setup.close_window()
	setup.open_window("difficulty")
	_button("Choice_easy").pressed.emit()
	await wait_process_frames(2)
	setup.close_window()
	var expected: Dictionary = setup.payload()
	var manager := Manager.new()
	manager.selected_run_variant = "cards"
	manager.expedition_save_path = "user://cards_selection_%d.json" % Time.get_ticks_usec()
	add_child(manager)
	assert_true(screen.prepare_adventure(manager))
	assert_eq(manager._cards_departure_selection, expected)
	assert_true(manager.continue_after_intro())
	assert_true(manager.finish_catabase_threshold().success)
	assert_eq(manager.expedition.cards.primary_class, expected.class_id)
	assert_eq(manager.expedition.cards.masteries, expected.masteries)
	assert_eq(manager.expedition.cards.active.size(), 15)
	assert_eq(manager.expedition.route.difficulty_id, "easy")
	assert_false(manager.expedition.needs_preparation)
	assert_eq(manager.expedition.cards.prototype_revision, 1)
	var families: Array = []
	for copy in manager.expedition.cards.active:
		families.append(manager.expedition.cards.copy_for(copy).family)
	assert_eq_deep(
		preload("res://ui/selection/departure_readability.gd").counts(families),
		preload("res://ui/selection/departure_readability.gd").counts(expected.card_families),
	)
	manager.cleanup_run_state()
	manager.queue_free()
	await wait_process_frames(2)


func test_escape_closes_help_before_window_and_restores_focus() -> void:
	setup.open_window("deck")
	await wait_process_frames(2)
	_button("DeckHelpToggle").pressed.emit()
	await wait_process_frames(2)
	var help := setup.find_child("DeckHelpDialog", true, false) as Control
	assert_true(help.visible)
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	get_viewport().push_input(escape)
	await wait_process_frames(2)
	assert_false(setup._show_deck_help)
	assert_eq(setup._modal, "deck")
	assert_true(_button("DeckHelpToggle").has_focus())
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	get_viewport().push_input(event)
	await wait_process_frames(2)
	assert_eq(setup._modal, "")
	assert_true(setup._socles.deck.has_focus())


func test_launch_guard_cancel_preserves_an_existing_cards_checkpoint() -> void:
	var old_path := GameManager.expedition_save_path
	var manager := Manager.new()
	manager.selected_run_variant = "cards"
	manager.expedition_save_path = "user://cards_selection_guard_%d.json" % Time.get_ticks_usec()
	add_child(manager)
	assert_true(manager.configure_next_run(screen.get_selected_entry().run, 0))
	assert_true(manager.configure_cards_departure(setup.payload()))
	assert_true(manager.continue_after_intro())
	assert_true(manager.finish_catabase_threshold().success)
	GameManager.expedition_save_path = manager.expedition_save_path
	var fingerprint := FileAccess.get_sha256(manager.expedition_save_path)
	var guarded := GuardScreen.new()
	add_child_autofree(guarded)
	await wait_process_frames(3)
	guarded.start_button.pressed.emit()
	await wait_process_frames(3)
	assert_true(guarded._is_replacement_open())
	assert_eq(guarded.launches, 0)
	guarded._replacement_dialog.get_cancel_button().pressed.emit()
	await wait_process_frames(2)
	assert_eq(guarded.launches, 0)
	assert_true(guarded.start_button.has_focus())
	assert_eq(FileAccess.get_sha256(manager.expedition_save_path), fingerprint)
	GameManager.expedition_save_path = old_path
	manager.cleanup_run_state()
	manager.queue_free()
	await wait_process_frames(2)


func _button(node_name: String) -> Button:
	return setup.find_child(node_name, true, false) as Button
