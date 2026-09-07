extends GutTest

const Factory := preload("res://test/support/factory.gd")
const FX := preload("res://vfx/paris/paris_spell_sprite_vfx.gd")
const PARIS_PATH := "res://data/units/enemies/catabase_shadow_paris.tres"

var _managers: Array[Node] = []


class GridView:
	extends Node2D

	func grid_to_local(cell: Vector2i) -> Vector2:
		return Vector2((cell.x - cell.y) * 64, (cell.x + cell.y) * 32)


class EffectManager:
	extends "res://core/vfx_manager.gd"


func after_each() -> void:
	for manager in _managers:
		if is_instance_valid(manager):
			manager.unregister_battle_view()
	_managers.clear()
	Engine.time_scale = 1


func test_all_authored_effects_have_four_distinct_sprite_frames() -> void:
	var frames := load("res://assets/vfx/paris/sprites_v1/effects.tres") as SpriteFrames
	assert_not_null(frames)
	if frames == null:
		return
	for animation: StringName in [&"arrow", &"frost", &"fire", &"vortex", &"impact", &"whip", &"hellfire", &"transform"]:
		assert_true(frames.has_animation(animation))
		assert_eq(frames.get_frame_count(animation), 4)
		for index in 4:
			assert_not_null(frames.get_frame_texture(animation, index))
			if index > 0:
				assert_ne(frames.get_frame_texture(animation, index), frames.get_frame_texture(animation, index - 1))


func test_four_arrow_flights_do_not_resolve_damage_until_actual_spell_impact() -> void:
	for name: String in ["spectral_arrow", "ice_arrow", "fire_arrow", "vortex_arrow"]:
		var fixture := _fixture()
		var spell := _spell(name)
		var paris: Unit = fixture.paris
		var hero: Unit = fixture.hero
		var original_cell := hero.grid_pos
		var original_hp := hero.current_hp
		var context: CastContext = fixture.field.caster.begin_cast(paris, spell, hero.grid_pos)
		assert_false(context.failed, name)
		var effect: Node = fixture.manager.play_spell_vfx(paris, spell, hero.grid_pos)
		assert_not_null(effect)
		if effect == null:
			continue
		assert_eq(fixture.manager.play_spell_vfx(paris, spell, hero.grid_pos), effect)
		effect.set_process(false)
		effect.advance_simulation(0.1)
		assert_eq(hero.current_hp, original_hp)
		assert_false(effect.get_debug_state().impact_reached)
		assert_eq(effect.get_debug_state().animation, FX.FLIGHT_ANIMATIONS[spell.spell_id])
		var expected_origin: Vector2 = fixture.paris_view.get_cast_effect_origin_global()
		assert_almost_eq(effect.get_debug_state().origin, expected_origin, Vector2(0.001, 0.001))
		var report: Dictionary = fixture.field.caster.resolve_cast(context)
		assert_false(report.get("failed", false))
		assert_lt(hero.current_hp, original_hp)
		assert_eq(effect.get_debug_state().phase, &"impact")
		assert_eq(effect.get_debug_state().targets, [fixture.manager._impact_cell_position(original_cell)])
		if name == "vortex_arrow":
			assert_ne(hero.grid_pos, original_cell, "The real pull must not drag the already resolved impact")
		if spell.applied_status != null:
			assert_true(hero.has_status(spell.applied_status.get_effective_status_id()))
		fixture.manager._on_spell_cast(paris, spell, report)
		assert_eq(_active(fixture.manager).size(), 1, "Repeated facts never duplicate impact")
		assert_true(fixture.manager._paris_router.flights.is_empty())
		fixture.manager.unregister_battle_view()


func test_empty_confirmation_failed_cast_and_stale_flight_have_no_fabricated_impact() -> void:
	var fixture := _fixture()
	var effect: Node = fixture.manager.play_spell_vfx(fixture.paris, _spell("spectral_arrow"), fixture.hero.grid_pos)
	fixture.manager._on_spell_cast(fixture.paris, _spell("spectral_arrow"), {"failed": true})
	assert_true(effect.get_debug_state().closed)
	assert_false(effect.get_debug_state().impact_reached)
	var stale := _effect(&"paris_ice_arrow")
	stale.start_flight(0.2)
	stale.set_process(false)
	stale.advance_simulation(1.3)
	assert_true(stale.get_debug_state().closed)
	stale.confirm_impact([Vector2(100, 20)])
	assert_false(stale.get_debug_state().impact_reached)
	var missed := _effect(&"paris_spectral_arrow")
	missed.start_flight(0.2)
	missed.confirm_impact([])
	assert_true(missed.get_debug_state().closed)
	assert_false(missed.get_debug_state().impact_reached)


func test_direct_resolution_has_impact_only_and_no_late_projectile() -> void:
	var fixture := _fixture()
	var report: Dictionary = fixture.field.caster.cast(fixture.paris, _spell("ice_arrow"), fixture.hero.grid_pos)
	assert_false(report.get("failed", false))
	assert_eq(_active(fixture.manager).size(), 1)
	assert_eq(_active(fixture.manager)[0].get_debug_state().phase, &"impact")
	assert_true(fixture.manager._paris_router.flights.is_empty())


func test_real_vortex_step_uses_actual_origin_and_arrival_and_next_arrow_origin() -> void:
	var fixture := _fixture()
	var paris: Unit = fixture.paris
	var from := paris.grid_pos
	var arrival := Vector2i(1, 4)
	fixture.field.terrain.place_effect(arrival, load("res://data/terrain/eau.tres") as TerrainEffectData)
	var report: Dictionary = fixture.field.caster.cast(paris, _spell("vortex_step"), arrival)
	assert_false(report.get("failed", false))
	assert_eq(paris.grid_pos, arrival)
	assert_true(paris.has_status(&"wet"))
	assert_eq(report.caster_movement_from, from)
	assert_eq(report.caster_movement_to, arrival)
	var effect: Node = _active(fixture.manager)[0]
	assert_eq(effect.get_debug_state().animation, &"vortex")
	assert_eq(effect.get_debug_state().targets,
		[fixture.manager._grid_cell_global(from), fixture.manager._grid_cell_global(arrival)])
	# The same projection used by Battle includes map elevation before the next cast.
	fixture.paris_view.position = fixture.view.grid_to_local(arrival) + Vector2(0, -32)
	fixture.paris_view.synchronize_external_movement()
	var body := fixture.paris_view.get_optional_visual() as ParisIsoUnitView
	body.advance_simulation(0.5)
	assert_eq(body.get_visual_runtime_state().stem, "idle")
	var next: Node = fixture.manager.play_spell_vfx(paris, _spell("spectral_arrow"), fixture.hero.grid_pos)
	assert_almost_eq(next.get_debug_state().origin,
		fixture.paris_view.get_cast_effect_origin_global(), Vector2(0.001, 0.001))
	assert_ne(next.get_debug_state().origin, fixture.manager._grid_cell_global(from))


func test_infernal_pull_follows_real_pre_pull_target_with_whip_between_both_points() -> void:
	var fixture := _fixture()
	var paris: Unit = fixture.paris
	paris.take_damage(97)
	var body := fixture.paris_view.get_optional_visual() as ParisIsoUnitView
	body.advance_simulation(0.9)
	var before: Vector2i = fixture.hero.grid_pos
	var report: Dictionary = fixture.field.caster.cast(paris, _spell("infernal_pull"), before)
	assert_false(report.get("failed", false))
	assert_ne(fixture.hero.grid_pos, before)
	var effect: Node = _active(fixture.manager)[0]
	assert_eq(effect.get_debug_state().animation, &"whip")
	assert_eq(effect.get_debug_state().targets, [fixture.manager._impact_cell_position(before)])
	var origin: Vector2 = fixture.paris_view.get_cast_effect_origin_global()
	var impact: Vector2 = fixture.manager._impact_cell_position(before)
	assert_almost_eq(effect._sprites[0].global_position, origin.lerp(impact, 0.5), Vector2(0.001, 0.001))
	assert_almost_eq(effect._sprites[0].global_rotation, (impact - origin).angle(), 0.001)


func test_sweep_shows_only_real_affected_targets_and_failed_teleport_is_silent() -> void:
	var fixture := _fixture()
	var paris: Unit = fixture.paris
	paris.take_damage(97)
	(fixture.paris_view.get_optional_visual() as ParisIsoUnitView).advance_simulation(0.9)
	var report: Dictionary = fixture.field.caster.cast(paris, _spell("infernal_sweep"), fixture.hero.grid_pos)
	assert_false(report.get("failed", false))
	assert_eq(_active(fixture.manager).size(), 1)
	assert_eq(_active(fixture.manager)[0].get_debug_state().animation, &"hellfire")
	fixture.manager._on_spell_cast(paris, _spell("vortex_step"), {"failed": true})
	assert_eq(_active(fixture.manager).size(), 1)


func test_transform_effect_follows_the_actual_model_then_dies_with_it() -> void:
	var fixture := _fixture()
	var paris: Unit = fixture.paris
	var body := fixture.paris_view.get_optional_visual() as ParisIsoUnitView
	paris.take_damage(97)
	var effect: Node = body.get("_transformation_fx")
	assert_not_null(effect)
	if effect == null:
		return
	assert_eq(effect.get_debug_state().animation, &"transform")
	effect.set_process(false)
	var before: Vector2 = effect.get_debug_state().targets[0]
	var model_before := body.global_position
	var model_offset := before - model_before
	assert_lt(model_offset.y, 0.0, "The transformation is centered above the model anchor")
	fixture.paris_view.position += Vector2(80, -16)
	# The fixture parent is scaled to 0.85: a local move is not a global move.
	var global_displacement := body.global_position - model_before
	assert_almost_eq(global_displacement, Vector2(68, -13.6), Vector2(0.001, 0.001))
	effect.advance_simulation(0.1)
	assert_almost_eq(effect.get_debug_state().targets[0], before + global_displacement, Vector2(0.001, 0.001))
	assert_almost_eq(effect._sprites[0].global_position, body.global_position + model_offset, Vector2(0.001, 0.001))
	# A model-only offset must also be followed, independently of the grid view.
	body.position += Vector2(12, -6)
	effect.advance_simulation(0.1)
	assert_almost_eq(effect.get_debug_state().targets[0], body.global_position + model_offset, Vector2(0.001, 0.001))
	assert_almost_eq(effect._sprites[0].global_position, body.global_position + model_offset, Vector2(0.001, 0.001))
	paris.take_damage(999)
	assert_true(effect.get_debug_state().closed)
	assert_false(effect.visible)
	assert_false(body.is_transformation_pending())


func test_unregister_cancels_all_Paris_effects_without_touching_confirmed_combat() -> void:
	var fixture := _fixture()
	var effect: Node = fixture.manager.play_spell_vfx(fixture.paris, _spell("spectral_arrow"), fixture.hero.grid_pos)
	var hp := int(fixture.hero.current_hp)
	fixture.manager.unregister_battle_view()
	assert_true(effect.get_debug_state().closed)
	assert_eq(fixture.hero.current_hp, hp)
	assert_true(fixture.manager._paris_router.flights.is_empty())
	assert_eq(_active(fixture.manager).size(), 0)


func _spell(stem: String) -> Spell:
	return load("res://data/spells/enemies/paris/%s.tres" % stem) as Spell


func _fixture() -> Dictionary:
	var field := Factory.make_battlefield(10, 7)
	var paris := Unit.from_data(load(PARIS_PATH) as UnitData)
	var hero := Factory.make_unit("Cible", 0)
	field.grid.place_unit(paris, Vector2i(1, 2))
	field.grid.place_unit(hero, Vector2i(4, 2))
	var view := GridView.new()
	view.position = Vector2(210, 170)
	view.scale = Vector2.ONE * 0.85
	add_child_autofree(view)
	var paris_view := (load("res://battle/unit_view.gd") as Script).new() as Node2D
	view.add_child(paris_view)
	paris_view.setup(paris, false)
	paris_view.position = view.grid_to_local(paris.grid_pos)
	paris_view.apply_painted_presentation(BattlePresentationProfile.new())
	(paris_view.get_optional_visual() as ParisIsoUnitView).set_process(false)
	var manager := EffectManager.new()
	manager._get_paris_router().frames = _frames()
	add_child_autofree(manager)
	manager.register_battle_view(view)
	_managers.append(manager)
	return {"field": field, "paris": paris, "hero": hero, "view": view,
		"paris_view": paris_view, "manager": manager}


func _active(manager: EffectManager) -> Array[Node]:
	var result: Array[Node] = []
	for effect in manager._paris_router.effects:
		if is_instance_valid(effect) and not effect.get_debug_state().closed:
			result.append(effect)
	return result


func _effect(spell_id: StringName) -> ParisSpellSpriteVFX:
	var effect := FX.new()
	add_child_autofree(effect)
	effect.configure(_frames(), spell_id, Vector2(0, 20), [Vector2(100, 20)], 32)
	return effect


func _frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	for animation: StringName in [&"arrow", &"frost", &"fire", &"vortex", &"impact", &"whip", &"hellfire", &"transform"]:
		frames.add_animation(animation)
		for _index in 4:
			# Timing-only fixture. No generated test texture is used in the game.
			var texture := GradientTexture2D.new()
			texture.width = 16
			texture.height = 16
			frames.add_frame(animation, texture)
	return frames
