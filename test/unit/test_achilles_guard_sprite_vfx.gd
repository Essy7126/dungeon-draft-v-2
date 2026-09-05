extends GutTest

const EFFECT := preload("res://battle/vfx/achilles_guard_sprite_vfx.tscn")
const GUARD := preload("res://data/spells/achilles/guard.tres")
const PROFILE := preload("res://vfx/profiles/achilles_guard_bronze_v1/guard_profile.tres")
const UNIT_VIEW := preload("res://battle/unit_view.tscn")
const ACHILLES := preload("res://data/units/allies/achilles.tres")


func test_canonical_guard_uses_four_real_transparent_sprite_phases() -> void:
	assert_eq(GUARD.vfx_scene, EFFECT)
	assert_eq(GUARD.ap_cost, 2)
	assert_eq(GUARD.shield_grant, 10)
	for phase: StringName in [&"activation", &"hold", &"hit", &"end"]:
		var sequence := PROFILE.get_sequence(phase)
		assert_not_null(sequence)
		if sequence == null:
			continue
		assert_eq(sequence.modules.size(), 1)
		var module := sequence.modules[0] as VFXFlipbookModuleData
		assert_not_null(module, "Every phase is an authored sprite flipbook")
		if module == null:
			continue
		var asset := module.asset
		assert_true(asset.validate_structure().is_empty())
		assert_false(asset.loop)
		assert_eq(asset.pivot_normalized, Vector2(0.5, 0.82))
		assert_eq(asset.alpha_mode, &"STRAIGHT")
		assert_eq(asset.blend_mode, &"MIX")
		assert_eq(asset.frame_count, {&"activation": 8, &"hold": 1, &"hit": 4, &"end": 4}[phase])
		var texture := asset.variants[0].texture_low
		assert_not_null(texture)
		if texture == null:
			continue
		var source := texture.get_image()
		assert_false(source.is_empty())
		var frame_size := Vector2i(source.get_width() / asset.columns, source.get_height() / asset.rows)
		assert_eq(frame_size.x, frame_size.y)
		for frame in range(asset.frame_count):
			var origin := Vector2i(frame % asset.columns, frame / asset.columns) * frame_size
			var drawing := source.get_region(Rect2i(origin, frame_size))
			assert_false(drawing.is_invisible(), "%s frame %d must contain art" % [phase, frame])
			assert_eq(drawing.get_pixel(0, 0).a, 0.0, "No opaque rectangular background")
			assert_eq(drawing.get_pixel(frame_size.x - 1, frame_size.y - 1).a, 0.0)


func test_activation_becomes_an_indefinitely_still_hold_without_changing_stats() -> void:
	var fixture := await _fixture()
	var effect := fixture.effect as VFXShieldSpriteEffect
	var unit := fixture.unit as Unit
	assert_eq(effect.get_phase_id(), &"activation")
	assert_eq(effect.get_bound_unit(), unit)
	_assert_sprite_only(effect)
	effect.advance_simulation(0.25)
	assert_gt(_sprite(effect).frame, 0)
	effect.advance_simulation(0.26)
	effect.set_process(false)
	assert_eq(effect.get_phase_id(), &"hold")
	var runtime := effect.get_runtime_instance()
	var fingerprint := runtime.geometry_fingerprint()
	var transform := _sprite(effect).transform
	for delta: float in [0.016, 1.0, 60.0]:
		effect.advance_simulation(delta)
		assert_eq(effect.get_phase_id(), &"hold")
		assert_eq(_sprite(effect).frame, 0)
		assert_eq(runtime.elapsed, 0.0)
		assert_eq(_sprite(effect).transform, transform)
		assert_eq(runtime.geometry_fingerprint(), fingerprint)
	assert_eq(unit.current_shield, 10)
	assert_eq(unit.current_hp, unit.max_hp.get_int())
	assert_eq(unit.current_ap, unit.max_ap.get_int())
	assert_eq(unit.current_mp, unit.max_mp.get_int())


func test_effect_follows_real_unit_view_without_modifying_the_character_or_feet() -> void:
	var fixture := await _fixture()
	var effect := fixture.effect as VFXShieldSpriteEffect
	var view := fixture.view as Node2D
	var visual: Node2D = view.get_optional_visual()
	var hero_sprite := visual.find_children("*", "AnimatedSprite2D", true, false)[0] as AnimatedSprite2D
	var original_pose := hero_sprite.transform
	var original_visual := visual.transform
	assert_eq(effect.get_parent(), view)
	assert_eq(effect.position, Vector2.ZERO)
	assert_eq(effect.scale, Vector2.ONE * view.get_painted_visual_scale())
	view.position += Vector2(63.0, 31.5)
	await wait_process_frames(2)
	assert_eq(effect.global_position, view.global_position)
	assert_eq(hero_sprite.transform, original_pose)
	assert_eq(visual.transform, original_visual)


func test_partial_absorption_plays_hit_then_preserves_the_remaining_shield() -> void:
	var fixture := await _fixture()
	var effect := fixture.effect as VFXShieldSpriteEffect
	var unit := fixture.unit as Unit
	_settle(effect)
	unit.take_damage(3, null, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"ignore_defense": true, "cannot_be_dodged": true})
	assert_eq(unit.current_shield, 7)
	assert_eq(unit.current_hp, unit.max_hp.get_int())
	assert_eq(effect.get_phase_id(), &"hit")
	effect.advance_simulation(0.12)
	assert_gt(_sprite(effect).frame, 0)
	effect.advance_simulation(0.14)
	effect.set_process(false)
	assert_eq(effect.get_phase_id(), &"hold")
	assert_eq(_sprite(effect).frame, 0)
	assert_eq(unit.current_shield, 7)


func test_exhaustion_and_explicit_clear_end_once_and_free_the_effect() -> void:
	for clear_explicitly: bool in [false, true]:
		var fixture := await _fixture()
		var effect := fixture.effect as VFXShieldSpriteEffect
		var unit := fixture.unit as Unit
		_settle(effect)
		if clear_explicitly:
			unit.clear_shield()
		else:
			unit.take_damage(10, null, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
				{"ignore_defense": true, "cannot_be_dodged": true})
		assert_eq(unit.current_shield, 0)
		assert_eq(effect.get_phase_id(), &"end")
		var runtime := effect.get_runtime_instance()
		unit.shield_changed.emit(unit)
		assert_eq(effect.get_runtime_instance(), runtime, "Repeated zero may not restart dissolution")
		effect.advance_simulation(0.31)
		await wait_process_frames(2)
		assert_false(is_instance_valid(effect))
		assert_eq(_effect_count(fixture.view), 0)


func test_refresh_deduplicates_and_death_cannot_leave_a_ghost_aura() -> void:
	var fixture := await _fixture()
	var previous := fixture.effect as VFXShieldSpriteEffect
	var replacement := EFFECT.instantiate() as VFXShieldSpriteEffect
	add_child(replacement)
	replacement.bind_source_unit(fixture.unit, fixture.view)
	replacement.set_process(false)
	assert_false(previous.visible)
	await wait_process_frames(2)
	assert_false(is_instance_valid(previous))
	assert_eq(_effect_count(fixture.view), 1)
	var unit := fixture.unit as Unit
	unit.take_damage(10000, null, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"ignore_defense": true, "cannot_be_dodged": true})
	await wait_process_frames(2)
	assert_false(unit.is_alive)
	assert_false(is_instance_valid(replacement))
	assert_eq(_effect_count(fixture.view), 0)


func test_invalid_bind_and_view_destruction_do_not_leak_signal_connections() -> void:
	var unit := Unit.new("Without shield")
	var view := Node2D.new()
	add_child_autofree(view)
	var invalid := EFFECT.instantiate() as VFXShieldSpriteEffect
	add_child(invalid)
	invalid.bind_source_unit(unit, view)
	await wait_process_frames(2)
	assert_false(is_instance_valid(invalid))
	unit.add_shield(10)
	var valid := EFFECT.instantiate() as VFXShieldSpriteEffect
	add_child(valid)
	valid.bind_source_unit(unit, view)
	view.queue_free()
	await wait_process_frames(2)
	assert_false(is_instance_valid(valid))
	assert_eq(unit.shield_changed.get_connections().size(), 0)
	assert_eq(unit.died.get_connections().size(), 0)
	unit.clear_shield()
	assert_eq(unit.current_shield, 0)


func test_pause_does_not_charge_the_wall_clock_into_the_next_frame() -> void:
	var fixture := await _fixture()
	var effect := fixture.effect as VFXShieldSpriteEffect
	effect.set_process(true)
	await wait_process_frames(1)
	var before := effect.get_runtime_instance().elapsed
	get_tree().paused = true
	await get_tree().create_timer(0.15, true).timeout
	assert_almost_eq(effect.get_runtime_instance().elapsed, before, 0.0001)
	get_tree().paused = false
	await wait_process_frames(1)
	assert_lt(effect.get_runtime_instance().elapsed - before, 0.1,
		"Paused wall time must not skip activation frames after resume")


func test_new_shield_during_dissolution_reactivates_same_single_instance() -> void:
	var fixture := await _fixture()
	var effect := fixture.effect as VFXShieldSpriteEffect
	var unit := fixture.unit as Unit
	_settle(effect)
	unit.clear_shield()
	assert_eq(effect.get_phase_id(), &"end")
	effect.advance_simulation(0.1)
	assert_eq(effect.get_phase_id(), &"end")
	unit.add_shield(10)
	effect.set_process(false)
	assert_eq(effect.get_phase_id(), &"activation")
	assert_eq(effect.get_bound_unit(), unit)
	assert_eq(_effect_count(fixture.view), 1)
	assert_true(effect.visible)
	assert_eq(effect.get_runtime_instance().modulate.a, 1.0,
		"Refreshing during dissolution must reset the previous fade")
	effect.advance_simulation(0.51)
	effect.set_process(false)
	assert_eq(effect.get_phase_id(), &"hold")
	assert_eq(unit.current_shield, 10)
	assert_eq(_effect_count(fixture.view), 1)
	assert_eq(_sprite(effect).frame, 0)

func _fixture() -> Dictionary:
	var unit := Unit.from_data(ACHILLES)
	var view := UNIT_VIEW.instantiate() as Node2D
	add_child_autofree(view)
	view.setup(unit)
	await wait_process_frames(3)
	unit.add_shield(10)
	var effect := EFFECT.instantiate() as VFXShieldSpriteEffect
	add_child(effect)
	effect.bind_source_unit(unit, view)
	effect.set_process(false)
	return {"unit": unit, "view": view, "effect": effect}


func _settle(effect: VFXShieldSpriteEffect) -> void:
	effect.advance_simulation(0.51)
	effect.set_process(false)


func _sprite(effect: VFXShieldSpriteEffect) -> Sprite2D:
	var sprites := effect.get_runtime_instance().find_children("*", "Sprite2D", true, false)
	return sprites[0] as Sprite2D if not sprites.is_empty() else null


func _effect_count(view: Node) -> int:
	var result := 0
	for child in view.get_children():
		if child is VFXShieldSpriteEffect and not child.is_queued_for_deletion():
			result += 1
	return result


func _assert_sprite_only(effect: VFXShieldSpriteEffect) -> void:
	assert_eq(effect.get_runtime_instance().active_visual_count(), 1)
	assert_eq(effect.find_children("*", "Sprite2D", true, false).size(), 1)
	for unwanted: String in ["Node3D", "SubViewport", "GPUParticles2D", "CPUParticles2D"]:
		assert_eq(effect.find_children("*", unwanted, true, false).size(), 0)
