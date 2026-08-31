extends GutTest

const Factory = preload("res://test/support/factory.gd")
const COMBAT_TARGET_FEEDBACK = preload(
	"res://battle/combat_target_feedback.gd"
)


func test_presentation_snapshot_separates_targeting_resolution_and_locks() -> void:
	var state := CombatPresentationState.new()
	var snapshot := state.get_snapshot()
	assert_eq(snapshot["phase_name"], &"PLAYER_IDLE")
	assert_true(snapshot["controls_enabled"])

	state.begin_targeting(&"spell")
	snapshot = state.get_snapshot()
	assert_eq(snapshot["phase_name"], &"PLAYER_TARGETING")
	assert_eq(snapshot["selection_mode"], &"spell")
	assert_true(snapshot["focus_active"])

	state.set_lock(&"external:inventory", true)
	snapshot = state.get_snapshot()
	assert_true(snapshot["input_locked"])
	assert_false(snapshot["controls_enabled"])
	assert_has(snapshot["lock_reasons"], &"external:inventory")

	state.begin_resolution(&"spell")
	state.set_lock(&"external:inventory", false)
	snapshot = state.get_snapshot()
	assert_eq(snapshot["phase_name"], &"RESOLVING_ACTION")
	assert_true(snapshot["input_locked"], "La résolution reste verrouillée sans lock externe")

	state.begin_player_turn()
	assert_true(state.get_snapshot()["controls_enabled"])


func test_modal_coordinator_has_exactly_one_owner() -> void:
	var coordinator := CombatModalCoordinator.new()
	assert_true(coordinator.try_open(&"inventory"))
	assert_true(coordinator.is_active(&"inventory"))
	assert_false(coordinator.try_open(&"pause"))
	assert_false(coordinator.close(&"pause"))
	assert_true(coordinator.close(&"inventory"))
	assert_true(coordinator.try_open(&"pause"))
	coordinator.clear()
	assert_false(coordinator.has_active_modal())


func test_turn_state_emits_changes_and_cancel_returns_to_idle() -> void:
	var state := TurnState.new()
	var transitions: Array = []
	state.state_changed.connect(
		func(previous, current): transitions.append([previous, current])
	)
	state.on_move_button()
	state.on_cancel()
	assert_eq(transitions.size(), 2)
	assert_eq(transitions[0], [TurnState.State.IDLE, TurnState.State.MOVE])
	assert_eq(transitions[1], [TurnState.State.MOVE, TurnState.State.IDLE])


func test_cancelling_end_turn_modal_restores_player_presentation() -> void:
	var battle = load("res://battle/battle.gd").new()
	battle.turn_state = TurnState.new()
	battle.presentation_state = CombatPresentationState.new()
	battle.presentation_state.begin_modal()
	battle.presentation_state.set_lock(&"end_turn_confirmation", true)

	battle.call("_on_end_turn_confirmation_cancelled")
	var snapshot: Dictionary = battle.get_combat_presentation_snapshot()
	assert_eq(snapshot["phase_name"], &"PLAYER_IDLE")
	assert_true(snapshot["controls_enabled"])
	assert_does_not_have(snapshot["lock_reasons"], &"end_turn_confirmation")
	battle.free()


func test_tooltip_is_hidden_and_refuses_content_while_modal_is_active() -> void:
	var tooltip := KeywordTooltipLayer.new()
	add_child_autofree(tooltip)
	await get_tree().process_frame
	tooltip.show_text("Test", "Visible", Vector2(120.0, 120.0), true)
	await get_tree().process_frame
	assert_true((tooltip.get("_panel") as Control).visible)
	tooltip.set_modal_blocked(true)
	assert_true(tooltip.is_modal_blocked())
	assert_false((tooltip.get("_panel") as Control).visible)
	tooltip.show_text("Interdit", "Modal", Vector2(120.0, 120.0), true)
	await get_tree().process_frame
	assert_false((tooltip.get("_panel") as Control).visible)
	tooltip.set_modal_blocked(false)


func test_end_turn_confirmation_and_outcome_expose_testable_snapshots() -> void:
	var unit := Unit.from_data(
		load("res://data/units/alliés/elfe.tres") as UnitData
	)
	var confirmation := EndTurnConfirmation.new()
	add_child_autofree(confirmation)
	await get_tree().process_frame
	assert_false(confirmation.is_open())
	confirmation.present(unit)
	var confirmation_snapshot := confirmation.get_snapshot()
	assert_true(confirmation_snapshot["visible"])
	assert_true(str(confirmation_snapshot["message"]).contains("PA"))
	assert_true(confirmation.dismiss())
	assert_false(confirmation.is_open())

	var outcome := CombatOutcomeOverlay.new()
	add_child_autofree(outcome)
	await get_tree().process_frame
	outcome.present(true, true)
	var outcome_snapshot := outcome.get_snapshot()
	assert_true(outcome_snapshot["visible"])
	assert_true(outcome_snapshot["victory"])
	assert_eq(outcome_snapshot["title"], "VICTOIRE")
	outcome.hide_overlay()
	assert_false(outcome.get_snapshot()["visible"])


func test_player_log_compact_layout_stays_above_hud_at_720p() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child_autofree(viewport)
	var combat_log := CanvasLayer.new()
	combat_log.set_script(load("res://ui/player_combat_log.gd"))
	viewport.add_child(combat_log)
	await get_tree().process_frame
	var snapshot: Dictionary = combat_log.get_layout_snapshot()
	var panel := snapshot["panel"] as Rect2
	assert_false(snapshot["expanded"])
	assert_lte(panel.end.y, 596.0, str(snapshot))
	combat_log.set_tactical_focus(true)
	snapshot = combat_log.get_layout_snapshot()
	assert_true(snapshot["tactical_focus"])
	assert_false(snapshot["scroll_visible"])


func test_player_log_starts_collapsed_on_a_full_hd_battlefield() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	add_child_autofree(viewport)
	var combat_log := CanvasLayer.new()
	combat_log.set_script(load("res://ui/player_combat_log.gd"))
	viewport.add_child(combat_log)
	await get_tree().process_frame
	var snapshot: Dictionary = combat_log.get_layout_snapshot()
	assert_false(snapshot["expanded"])
	assert_false(snapshot["scroll_visible"])


func test_target_feedback_explains_invalid_move_spell_range_and_ap() -> void:
	var field = Factory.make_battlefield(5, 5)
	var unit := Factory.make_unit("Joueur", 0)
	assert_true(field.grid.place_unit(unit, Vector2i(1, 1)))
	var feedback = COMBAT_TARGET_FEEDBACK.new(
		field.grid,
		field.pathfinder,
		field.caster,
	)

	assert_eq(
		feedback.movement_rejection_reason(unit, Vector2i(-1, 0)),
		"Cette case n'est pas accessible.",
	)

	var ranged_spell := Factory.make_spell({
		"spell_range": 1,
		"can_target_free_cell": true,
	})
	assert_true(
		feedback.spell_rejection_reason(
			unit,
			ranged_spell,
			Vector2i(4, 4),
		).contains("hors de port"),
	)

	unit.current_ap = 0
	var expensive_spell := Factory.make_spell({"ap_cost": 2})
	assert_eq(
		feedback.spell_rejection_reason(
			unit,
			expensive_spell,
			Vector2i(1, 2),
		),
		"PA insuffisants (0 / 2).",
	)
