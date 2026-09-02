extends GutTest

const UNIT_VIEW_SCRIPT := preload("res://battle/unit_view.gd")
const Factory := preload("res://test/support/factory.gd")


class ActionVisualStub extends Node2D:
	signal cast_release_reached
	signal animation_finished(animation_name: StringName)

	var release_synchronously := true
	var finish_synchronously := true
	var active := false
	var cancel_count := 0
	var start_count := 0

	func play_spell_action(_spell: Spell = null) -> bool:
		return _play(&"spell")

	func play_basic_attack() -> bool:
		return _play(&"attack")

	func cancel_pending_visual_actions() -> void:
		cancel_count += 1
		active = false

	func _play(action_name: StringName) -> bool:
		if active:
			return false
		active = true
		start_count += 1
		if release_synchronously:
			cast_release_reached.emit()
		if finish_synchronously:
			active = false
			animation_finished.emit(action_name)
		return true


func test_distinct_once_per_activation_spells_chain_with_independent_state() -> void:
	var field := Factory.make_battlefield(5, 1)
	var caster := Unit.new("Lanceur", 0, 30, 10, 6, 3, 10)
	var target := Unit.new("Cible", 1, 30)
	field.grid.place_unit(caster, Vector2i.ZERO)
	field.grid.place_unit(target, Vector2i(2, 0))
	var first := _combat_spell(&"chain_first")
	var second := _combat_spell(&"chain_second")
	caster.add_spell(first)
	caster.add_spell(second)
	caster.start_turn()

	var first_report := field.caster.cast(caster, first, target.grid_pos)
	var second_report := field.caster.cast(caster, second, target.grid_pos)
	var repeated_report := field.caster.cast(caster, first, target.grid_pos)

	assert_false(first_report.get("failed", false), str(first_report))
	assert_false(second_report.get("failed", false), str(second_report))
	assert_true(repeated_report.get("failed", false))
	assert_eq(repeated_report.get("reason"), "once_per_activation")
	assert_eq(caster.current_ap, 2)
	assert_eq(target.current_hp, 28)


func test_spell_caster_exposes_caster_movement_semantics_from_modifier() -> void:
	var field := Factory.make_battlefield(3, 1)
	var caster := Unit.new("Lanceur", 0)
	var rush := _combat_spell(&"rush")
	var movement := SpellModSkillTreeEffect.new()
	movement.effect_type = SpellModSkillTreeEffect.EffectType.MOVE_CASTER_TO_TARGET
	rush.modifiers.append(movement)
	assert_true(field.caster.spell_moves_caster(caster, rush))
	assert_false(field.caster.spell_moves_caster(caster, _combat_spell(&"static")))


func test_synchronous_release_is_observed_and_two_actions_can_chain() -> void:
	var visual := ActionVisualStub.new()
	var view: Variant = _view_with_visual(visual)
	var spell := Spell.new()
	spell.spell_id = &"sync_release"

	assert_true(await view.prepare_spell_visual(Vector2i.RIGHT, spell, 10))
	await view.wait_for_action_visual_finished(10)
	assert_false(view.is_action_visual_pending())
	assert_true(await view.prepare_basic_attack_visual(Vector2i.RIGHT, 10))
	await view.wait_for_action_visual_finished(10)
	assert_eq(visual.start_count, 2)
	assert_eq(visual.cancel_count, 0)


func test_missing_spell_release_cancels_backend_before_next_action() -> void:
	var visual := ActionVisualStub.new()
	visual.release_synchronously = false
	visual.finish_synchronously = false
	var view: Variant = _view_with_visual(visual)
	var spell := Spell.new()
	spell.spell_id = &"missing_release"

	assert_false(await view.prepare_spell_visual(Vector2i.RIGHT, spell, 1))
	assert_eq(visual.cancel_count, 1)
	assert_false(visual.active)
	assert_false(view.is_action_visual_pending())

	visual.release_synchronously = true
	visual.finish_synchronously = true
	assert_true(await view.prepare_spell_visual(Vector2i.RIGHT, spell, 10))
	await view.wait_for_action_visual_finished(10)
	assert_eq(visual.start_count, 2)


func test_missing_attack_release_and_recovery_timeout_both_cancel_backend() -> void:
	var missing_release := ActionVisualStub.new()
	missing_release.release_synchronously = false
	missing_release.finish_synchronously = false
	var attack_view: Variant = _view_with_visual(missing_release)
	assert_false(await attack_view.prepare_basic_attack_visual(Vector2i.RIGHT, 1))
	assert_eq(missing_release.cancel_count, 1)
	assert_false(missing_release.active)

	var missing_finish := ActionVisualStub.new()
	missing_finish.finish_synchronously = false
	var spell_view: Variant = _view_with_visual(missing_finish)
	var spell := Spell.new()
	spell.spell_id = &"missing_finish"
	assert_true(await spell_view.prepare_spell_visual(Vector2i.RIGHT, spell, 10))
	await spell_view.wait_for_action_visual_finished(1)
	assert_eq(missing_finish.cancel_count, 1)
	assert_false(missing_finish.active)
	assert_false(spell_view.is_action_visual_pending())


func test_looping_charge_finishes_one_cycle_and_returns_warrior_to_idle() -> void:
	var visual := WarriorVisual3D.new()
	var pivot := Node3D.new()
	pivot.name = "ModelPivot"
	var model := Node3D.new()
	model.name = "WarriorModel"
	var player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = 0.5
	idle.loop_mode = Animation.LOOP_LINEAR
	var run := Animation.new()
	run.length = 0.5
	run.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(WarriorVisual3D.ANIM_IDLE, idle)
	library.add_animation(WarriorVisual3D.ANIM_RUN, run)
	player.add_animation_library(&"", library)
	model.add_child(player)
	pivot.add_child(model)
	visual.add_child(pivot)
	add_child_autofree(visual)
	await get_tree().process_frame

	var events := {"release": 0, "finished": []}
	visual.cast_release_reached.connect(func() -> void:
		events["release"] = int(events["release"]) + 1
	)
	visual.animation_finished.connect(func(animation_name: StringName) -> void:
		(events["finished"] as Array).append(animation_name)
	)
	var charge := Spell.new()
	charge.spell_id = &"warrior_charge"
	assert_true(visual.play_spell_action(charge))
	var action_duration := float(visual.get("_release_action_finish_seconds"))
	assert_gt(action_duration, 0.0)

	visual._process(action_duration + 0.01)

	assert_eq(events["release"], 1)
	assert_eq(events["finished"], [WarriorVisual3D.ANIM_RUN])
	assert_eq(visual.get_current_animation(), WarriorVisual3D.ANIM_IDLE)
	assert_true(player.is_playing())


func _view_with_visual(visual: ActionVisualStub) -> Variant:
	var view: Variant = UNIT_VIEW_SCRIPT.new()
	add_child_autofree(view)
	view.setup(Unit.new("Test", 0), false)
	view.add_child(visual)
	view.set("_optional_visual", visual)
	visual.animation_finished.connect(
		Callable(view, "_on_optional_visual_action_finished")
	)
	return view


func _combat_spell(id: StringName) -> Spell:
	var spell := Spell.new()
	spell.spell_id = id
	spell.spell_name = String(id)
	spell.ap_cost = 2
	spell.damage = 1
	spell.once_per_activation = true
	return spell
