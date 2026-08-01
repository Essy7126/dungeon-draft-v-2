extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")
const ActionBarScript = preload("res://ui/action_bar.gd")
const BattleScript = preload("res://battle/battle.gd")

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const GUARDIAN_PATH := "res://data/units/alliés/Gardien.tres"
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"

var manager
var bar


func before_each() -> void:
	manager = GameManagerScript.new()
	var run := RunData.new()
	run.rooms.append(RoomData.new())
	assert_true(manager._prepare_preconfigured_run(
		run,
		[ELF_PATH, GUARDIAN_PATH, WARRIOR_PATH],
	))
	bar = ActionBarScript.new()
	add_child_autofree(bar)


func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager.cleanup_run_state()
		manager.free()


func _show_unit(unit: Unit) -> void:
	bar.update_info(unit)
	bar.build_spell_buttons(unit)


func _spell_buttons() -> Array:
	return bar.get("_spell_buttons")


func _base_spell_buttons() -> Array:
	return _spell_buttons().filter(
		func(button): return not button.get_meta("imprinted", false)
	)


func _base_spell_ids() -> Array:
	return _base_spell_buttons().map(
		func(button): return button.get_meta("spell").get_effective_spell_id()
	)


func _equipped_spell_ids(unit: Unit) -> Array:
	return unit.spells.map(func(spell): return spell.get_effective_spell_id())


func _energy_controls_are_visible() -> bool:
	return [
		bar.get("_fervor_label"),
		bar.get("_fervor_bar"),
		bar.get("_awakening_btn"),
		bar.get("_reaction_btn"),
		bar.get("_energy_separator_before"),
		bar.get("_energy_separator_after"),
	].all(func(control): return control.visible)


func _assert_old_buttons_detached(buttons: Array) -> void:
	for button in buttons:
		assert_false(is_instance_valid(button))


func test_hud_switches_elf_guardian_warrior_and_back_without_residue() -> void:
	var heroes: Array[Unit] = manager.get_ordered_heroes()
	var elf: Unit = heroes[0]
	var guardian: Unit = heroes[1]
	var warrior: Unit = heroes[2]

	_show_unit(elf)
	assert_eq(_spell_buttons().size(), 4)
	assert_eq(_base_spell_ids(), _equipped_spell_ids(elf))
	assert_false(_energy_controls_are_visible())
	assert_true(_spell_buttons().all(
		func(button): return not button.get_meta("imprinted", false)
	))
	var elf_buttons := _spell_buttons().duplicate()

	_show_unit(guardian)
	_assert_old_buttons_detached(elf_buttons)
	assert_eq(_base_spell_buttons().size(), guardian.spells.size())
	assert_eq(_base_spell_ids(), _equipped_spell_ids(guardian))
	assert_true(_energy_controls_are_visible())
	var expected_guardian_variants := guardian.spells.filter(
		func(spell): return spell.can_imprint()
	).size()
	assert_eq(_spell_buttons().size(), guardian.spells.size() + expected_guardian_variants)
	var guardian_buttons := _spell_buttons().duplicate()

	_show_unit(warrior)
	_assert_old_buttons_detached(guardian_buttons)
	assert_eq(_base_spell_buttons().size(), warrior.spells.size())
	assert_eq(_base_spell_ids(), _equipped_spell_ids(warrior))
	assert_false(_energy_controls_are_visible())
	var expected_warrior_variants := warrior.spells.filter(
		func(spell): return spell.can_imprint()
	).size()
	assert_eq(expected_warrior_variants, 0)
	assert_eq(_spell_buttons().size(), warrior.spells.size() + expected_warrior_variants)
	var warrior_buttons := _spell_buttons().duplicate()

	_show_unit(elf)
	_assert_old_buttons_detached(warrior_buttons)
	assert_eq(_spell_buttons().size(), 4)
	assert_eq(_base_spell_ids(), _equipped_spell_ids(elf))
	assert_false(_energy_controls_are_visible())


func test_switch_disconnects_resource_signals_from_the_previous_unit() -> void:
	var heroes: Array[Unit] = manager.get_ordered_heroes()
	var elf: Unit = heroes[0]
	var guardian: Unit = heroes[1]
	var callback := Callable(bar, "_on_resource_changed")
	_show_unit(elf)
	assert_true(elf.energy_changed.is_connected(callback))
	assert_true(elf.stats_changed.is_connected(callback))
	_show_unit(guardian)
	assert_false(elf.energy_changed.is_connected(callback))
	assert_false(elf.stats_changed.is_connected(callback))
	assert_true(guardian.energy_changed.is_connected(callback))
	assert_true(guardian.stats_changed.is_connected(callback))


func test_battle_cancels_the_previous_spell_selection_before_hud_rebuild() -> void:
	var elf := manager.get_ordered_heroes()[0] as Unit
	var battle = BattleScript.new()
	battle.turn_state = TurnState.new()
	battle.action_bar = bar
	battle.turn_state.on_spell_selected(elf.spells[0])
	bar.set_active_mode("spell", elf.spells[0])
	assert_eq(battle.turn_state.current, TurnState.State.TARGET_SPELL)
	assert_same(battle.turn_state.selected_spell, elf.spells[0])
	battle._cancel_action_selection_for_active_unit()
	assert_eq(battle.turn_state.current, TurnState.State.IDLE)
	assert_null(battle.turn_state.selected_spell)
	assert_false(battle.turn_state.selected_spell_imprinted)
	battle.free()
