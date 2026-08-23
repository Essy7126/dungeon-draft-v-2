extends GutTest

const RUN_UI_SCENE := preload("res://ui/run/PersistentRunUI.tscn")

class FakeCombatContext:
	extends Node
	var active_unit = null
	var move_count := 0
	var attack_count := 0
	var spell_count := 0
	var end_turn_count := 0
	var selection_active := false
	var cancel_count := 0
	var external_locks: Dictionary = {}

	func get_active_unit():
		return active_unit

	func _on_move_pressed() -> void:
		move_count += 1

	func _on_attack_pressed() -> void:
		attack_count += 1

	func _on_spell_pressed(_spell) -> void:
		spell_count += 1

	func _on_end_turn_pressed() -> void:
		end_turn_count += 1

	func cancel_active_selection() -> bool:
		if not selection_active:
			return false
		selection_active = false
		cancel_count += 1
		return true

	func dismiss_top_combat_modal() -> bool:
		return false

	func set_external_interaction_lock(source: StringName, locked: bool) -> void:
		if locked:
			external_locks[source] = true
		else:
			external_locks.erase(source)

	func get_combat_presentation_snapshot() -> Dictionary:
		return {"phase_name": &"PLAYER_IDLE"}

func after_each() -> void:
	GameManager.cleanup_run_state()

func test_bind_is_idempotent_and_context_replacement_disconnects_old_room() -> void:
	var run_ui := RUN_UI_SCENE.instantiate() as PersistentRunUI
	var first := FakeCombatContext.new()
	var second := FakeCombatContext.new()
	add_child_autofree(run_ui)
	add_child_autofree(first)
	add_child_autofree(second)
	await get_tree().process_frame
	var hud = run_ui.bind_combat_context(first)
	run_ui.bind_combat_context(first)
	assert_same(hud.get_combat_context(), first)
	assert_true(hud.end_turn_pressed.is_connected(Callable(first, "_on_end_turn_pressed")))
	run_ui.bind_combat_context(second)
	assert_same(hud.get_combat_context(), second)
	assert_false(hud.end_turn_pressed.is_connected(Callable(first, "_on_end_turn_pressed")))
	assert_true(hud.end_turn_pressed.is_connected(Callable(second, "_on_end_turn_pressed")))

func test_unbind_clears_context_slots_and_combat_visibility() -> void:
	var run_ui := RUN_UI_SCENE.instantiate() as PersistentRunUI
	var context := FakeCombatContext.new()
	context.active_unit = Unit.from_data(load("res://data/units/alliés/elfe.tres") as UnitData)
	add_child_autofree(run_ui)
	add_child_autofree(context)
	await get_tree().process_frame
	var hud = run_ui.bind_combat_context(context)
	assert_eq(hud.get("_spell_buttons").size(), 4)
	run_ui.unbind_combat_context(context)
	assert_null(hud.get_combat_context())
	assert_true(hud.get("_spell_buttons").is_empty())
	assert_false(hud.visible)


func test_ui_cancel_cancels_targeting_before_opening_pause() -> void:
	var run := load("res://data/runs/first_run.tres") as RunData
	assert_true(GameManager._prepare_preconfigured_run(
		run,
		[
			"res://data/units/alliés/elfe.tres",
			"res://data/units/alliés/mage.tres",
			"res://data/units/alliés/Guerrier.tres",
		]
	))
	var run_ui := GameManager.get_persistent_run_ui()
	var context := FakeCombatContext.new()
	context.selection_active = true
	add_child_autofree(context)
	run_ui.bind_combat_context(context)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true

	run_ui._unhandled_input(cancel)
	assert_eq(context.cancel_count, 1)
	assert_false(context.selection_active)
	assert_false(run_ui.is_pause_menu_open())

	run_ui._unhandled_input(cancel)
	assert_true(run_ui.is_pause_menu_open())
	assert_true(context.external_locks.has(&"run_modal"))
	run_ui.close_pause_menu()
	assert_false(context.external_locks.has(&"run_modal"))
