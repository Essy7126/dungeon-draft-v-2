extends GutTest

const HUD_SCENE := preload(
	"res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn"
)
const RUN_UI_SCENE := preload("res://ui/run/PersistentRunUI.tscn")
const RUN_DATA := preload("res://data/runs/fixed_trio_prototype_run.tres")


class FakeCombatContext:
	extends Node

	var active_unit = null
	var move_count := 0
	var attack_count := 0
	var spell_count := 0
	var awakening_count := 0
	var reaction_count := 0
	var end_turn_count := 0

	func get_active_unit():
		return active_unit

	func _on_move_pressed() -> void:
		move_count += 1

	func _on_attack_pressed() -> void:
		attack_count += 1

	func _on_spell_pressed(_spell, _imprinted: bool = false) -> void:
		spell_count += 1

	func _on_awakening_pressed() -> void:
		awakening_count += 1

	func _on_reaction_pressed() -> void:
		reaction_count += 1

	func _on_end_turn_pressed() -> void:
		end_turn_count += 1


func after_each() -> void:
	GameManager.cleanup_run_state()


func test_bind_is_idempotent_and_context_replacement_disconnects_the_old_room() -> void:
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
	assert_true(hud.end_turn_pressed.is_connected(
		Callable(first, "_on_end_turn_pressed")
	))
	assert_eq(_connection_count(
		hud.end_turn_pressed,
		Callable(first, "_on_end_turn_pressed")
	), 1)

	hud.end_turn_pressed.emit()
	assert_eq(first.end_turn_count, 1)
	run_ui.bind_combat_context(second)
	assert_false(hud.end_turn_pressed.is_connected(
		Callable(first, "_on_end_turn_pressed")
	))
	assert_true(hud.end_turn_pressed.is_connected(
		Callable(second, "_on_end_turn_pressed")
	))
	hud.end_turn_pressed.emit()
	assert_eq(first.end_turn_count, 1)
	assert_eq(second.end_turn_count, 1)

	run_ui.unbind_combat_context(second)
	run_ui.unbind_combat_context(second)
	hud.end_turn_pressed.emit()
	assert_eq(second.end_turn_count, 1)
	assert_null(hud.get_combat_context())
	assert_eq(run_ui.get_ui_mode(), PersistentRunUI.RunUIMode.TRANSITION)


func test_modes_hide_and_disable_combat_without_removing_future_layers() -> void:
	var run_ui := RUN_UI_SCENE.instantiate() as PersistentRunUI
	var context := FakeCombatContext.new()
	add_child_autofree(run_ui)
	add_child_autofree(context)
	await get_tree().process_frame
	var hud = run_ui.bind_combat_context(context)

	assert_eq(run_ui.get_ui_mode(), PersistentRunUI.RunUIMode.COMBAT)
	assert_true(hud.visible)
	run_ui.set_ui_mode(PersistentRunUI.RunUIMode.NON_COMBAT)
	assert_false(hud.visible)
	assert_true(run_ui.contextual_ui_layer.visible)
	assert_true(hud.get_node("%EndTurnButton").disabled)
	run_ui.set_ui_mode(PersistentRunUI.RunUIMode.TRANSITION)
	assert_false(hud.visible)
	assert_false(run_ui.contextual_ui_layer.visible)
	assert_false(run_ui.overlay_layer.visible)


func test_active_character_refreshes_name_and_shared_draft_portrait() -> void:
	var run_ui := RUN_UI_SCENE.instantiate() as PersistentRunUI
	var context := FakeCombatContext.new()
	var elf_data := load("res://data/units/alliés/elfe.tres") as UnitData
	var mage_data := load("res://data/units/alliés/mage.tres") as UnitData
	var elf := Unit.from_data(elf_data)
	var mage := Unit.from_data(mage_data)
	context.active_unit = elf
	add_child_autofree(run_ui)
	add_child_autofree(context)
	await get_tree().process_frame
	var hud = run_ui.bind_combat_context(context)

	assert_eq(hud.get_node("%CharacterName").text, "Elfe")
	assert_same(hud.get_node("%PortraitView").character_data, elf_data)
	context.active_unit = mage
	run_ui.refresh_from_context()
	assert_eq(hud.get_node("%CharacterName").text, "Mage")
	assert_same(hud.get_node("%PortraitView").character_data, mage_data)
	assert_same(
		hud.get_node("%PortraitView").character_data.preview_visual_scene,
		mage_data.preview_visual_scene
	)
	elf.clear_traits()
	mage.clear_traits()


func test_refined_utility_dock_disables_missing_screens_and_reuses_skill_tree() -> void:
	assert_true(GameManager._prepare_preconfigured_run(RUN_DATA, [
		"res://data/units/alliés/elfe.tres",
		"res://data/units/alliés/mage.tres",
		"res://data/units/alliés/Gardien.tres",
	]))
	var run_ui := GameManager.get_persistent_run_ui()
	var context := FakeCombatContext.new()
	context.active_unit = GameManager.get_character_state(&"elf").unit
	add_child_autofree(context)
	var hud = run_ui.bind_combat_context(context)
	hud.set_player_controls_enabled(true)

	assert_true(hud.get_node("%UtilityDock").visible)
	assert_true(hud.get_node("%InventoryButton").disabled)
	assert_true(hud.get_node("%MapButton").disabled)
	assert_false(hud.get_node("%SkillsButton").disabled)
	assert_true(hud.utility_skill_tree_requested.is_connected(
		Callable(run_ui, "_on_skill_tree_requested")
	))
	assert_not_null(hud.get_node("%InventoryButton").icon)
	assert_not_null(hud.get_node("%MapButton").icon)
	assert_not_null(hud.get_node("%SkillsButton").icon)
	assert_not_null(hud.get_node("%MoveButton/ActionIcon").texture)
	hud.get_node("%SkillsButton").pressed.emit()
	assert_true(run_ui.get_skill_tree_screen().visible)
	assert_false(bool(hud.get("_player_controls_enabled")))
	assert_eq(run_ui.find_children("SkillTreeScreen", "SkillTreeScreen").size(), 1)
	run_ui.get_skill_tree_screen().close_screen()
	assert_false(run_ui.get_skill_tree_screen().visible)
	assert_true(bool(hud.get("_player_controls_enabled")))


func test_game_manager_keeps_one_hud_instance_across_contexts() -> void:
	assert_true(GameManager._prepare_preconfigured_run(RUN_DATA, [
		"res://data/units/alliés/elfe.tres",
		"res://data/units/alliés/mage.tres",
		"res://data/units/alliés/Gardien.tres",
	]))
	var persistent_ui := GameManager.get_persistent_run_ui()
	var hud := persistent_ui.get_combat_hud()
	var first := FakeCombatContext.new()
	var second := FakeCombatContext.new()
	add_child_autofree(first)
	add_child_autofree(second)

	assert_same(GameManager.bind_combat_context(first), hud)
	GameManager.unbind_combat_context(first)
	assert_same(GameManager.bind_combat_context(second), hud)
	assert_same(GameManager.get_persistent_run_ui(), persistent_ui)
	assert_same(persistent_ui.get_combat_hud(), hud)
	hud.end_turn_pressed.emit()
	assert_eq(first.end_turn_count, 0)
	assert_eq(second.end_turn_count, 1)


func test_runtime_layout_never_rewrites_the_three_editor_anchors() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	add_child_autofree(viewport)
	var hud = HUD_SCENE.instantiate()
	viewport.add_child(hud)
	await get_tree().process_frame
	var before := _anchor_snapshot(hud)

	hud._apply_layout_metrics()
	viewport.size = Vector2i(1366, 768)
	hud._apply_layout_metrics()
	viewport.size = Vector2i(1920, 1080)
	hud._apply_layout_metrics()
	assert_eq(_anchor_snapshot(hud), before)

	var source := FileAccess.get_file_as_string(
		"res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.gd"
	)
	for forbidden in [
		"_character_anchor.position =",
		"_character_anchor.size =",
		"_character_anchor.offset_",
		"_spell_anchor.position =",
		"_spell_anchor.size =",
		"_spell_anchor.offset_",
		"_turn_anchor.position =",
		"_turn_anchor.size =",
		"_turn_anchor.offset_",
	]:
		assert_false(forbidden in source, forbidden)


func test_debug_overlay_targets_all_seven_layout_nodes_and_ignores_mouse() -> void:
	var hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	await get_tree().process_frame
	var overlay: Control = hud.get_node("%LayoutDebugOverlay")
	assert_eq(overlay.target_paths.size(), 7)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for node_name in [
		"HudBand",
		"CharacterAnchor",
		"SpellAnchor",
		"TurnAnchor",
		"CharacterSection",
		"SpellSection",
		"TurnSection",
	]:
		assert_true(overlay.target_paths.any(
			func(path): return str(path).ends_with(node_name)
		), node_name)


func _connection_count(source_signal: Signal, callback: Callable) -> int:
	return source_signal.get_connections().filter(
		func(connection): return connection["callable"] == callback
	).size()


func _anchor_snapshot(hud: CanvasLayer) -> Dictionary:
	var snapshot := {}
	for node_name in ["CharacterAnchor", "SpellAnchor", "TurnAnchor"]:
		var control := hud.get_node("%" + node_name) as Control
		snapshot[node_name] = {
			"anchors": Vector4(
				control.anchor_left,
				control.anchor_top,
				control.anchor_right,
				control.anchor_bottom
			),
			"offsets": Vector4(
				control.offset_left,
				control.offset_top,
				control.offset_right,
				control.offset_bottom
			),
			"minimum": control.custom_minimum_size,
		}
	return snapshot
