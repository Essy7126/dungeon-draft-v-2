extends GutTest

const RUN_UI_SCENE := preload("res://ui/run/PersistentRunUI.tscn")

class FakeCombatContext:
	extends Node
	var active_unit = null
	var move_count := 0
	var attack_count := 0
	var spell_count := 0
	var end_turn_count := 0

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
