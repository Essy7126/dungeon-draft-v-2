extends GutTest

const SCENE_PATH := "res://characters/paris/ParisIsoUnitView.tscn"
const UNIT_PATH := "res://data/units/enemies/catabase_shadow_paris.tres"
const DIRECTIONS := {"E": Vector2i.RIGHT, "N": Vector2i.UP, "S": Vector2i.DOWN, "W": Vector2i.LEFT}
const SPELLS := ["spectral_arrow", "fire_arrow", "ice_arrow", "vortex_arrow", "vortex_step",
	"infernal_whip", "infernal_sweep", "infernal_pull"]


func after_each() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


func test_two_authored_forms_and_reveal_have_complete_directional_clips() -> void:
	var fixture := _fixture()
	var view: ParisIsoUnitView = fixture.visual
	var profile := view.sprite_profile as ParisSpriteVisualProfile
	assert_true(view.get_visual_runtime_state().configured)
	assert_eq(profile.validation_error(view._spectral_frames), &"")
	assert_eq(profile.validation_error(view._infernal_frames), &"")
	assert_eq(profile.transformation_validation_error(view._transformation_frames), &"")
	assert_eq(view.find_children("*", "AnimatedSprite2D", true, false).size(), 1)
	assert_eq(view.find_children("*", "SubViewport", true, false).size(), 0)
	assert_eq(view.find_children("*", "Node3D", true, false).size(), 0)
	for bank: SpriteFrames in [view._spectral_frames, view._infernal_frames]:
		for direction: String in DIRECTIONS:
			for stem: String in ["idle", "walk", "attack", "cast", "hit", "death"]:
				var clip := StringName(stem + "_" + direction)
				assert_true(bank.has_animation(clip))
				assert_eq(bank.get_frame_texture(clip, 0).get_size(), Vector2(512, 384))
	assert_eq(profile.foot_anchor, Vector2(256, 320))
	assert_eq(view.animated_sprite.flip_h, view.get_visual_runtime_state().facing in ["S", "W"])
	assert_false(view.animated_sprite.flip_v)
	_assert_anchor(view)


func test_levitating_idle_has_no_clock_bob_or_root_drift() -> void:
	var view: ParisIsoUnitView = _fixture().visual
	var original := view.animated_sprite.transform
	for direction: String in DIRECTIONS:
		view.set_facing(DIRECTIONS[direction])
		for _sample in 20:
			view.advance_simulation(0.6)
			assert_true(view.play_idle())
			assert_eq(view.animated_sprite.frame, 0)
			assert_eq(view.animated_sprite.animation, StringName("idle_" + direction))
			assert_eq(view.animated_sprite.transform, original)
			assert_false(view.animated_sprite.is_playing())
			_assert_anchor(view)


func test_hover_and_infernal_walk_only_advance_with_real_movement_stride() -> void:
	var fixture := _fixture()
	var view: ParisIsoUnitView = fixture.visual
	for form: StringName in [&"spectral", &"infernal"]:
		if form == &"infernal":
			_transform(fixture)
		for direction: String in DIRECTIONS:
			view.begin_movement_feedback(Vector2i.ZERO, DIRECTIONS[direction])
			view.update_movement_stride(0, 0.9)
			var frame := view.animated_sprite.frame
			view.advance_simulation(2.0)
			assert_eq(view.animated_sprite.frame, frame)
			view.update_movement_stride(0, 1.0)
			frame = view.animated_sprite.frame
			view.update_movement_stride(1, 0)
			assert_eq(view.animated_sprite.frame, frame)
			view.synchronize_external_movement()
			view.advance_simulation(0.6)
			assert_eq(view.animated_sprite.animation, StringName("idle_" + direction))
			assert_false(view.get_visual_runtime_state().movement_active)
			_assert_anchor(view)


func test_eight_spell_animations_release_once_at_the_authored_marker_in_four_directions() -> void:
	var fixture := _fixture()
	var view: ParisIsoUnitView = fixture.visual
	var events := _events(view)
	for direction: String in DIRECTIONS:
		for stem: String in SPELLS:
			var spell := load("res://data/spells/enemies/paris/%s.tres" % stem) as Spell
			view.set_facing(DIRECTIONS[direction])
			var releases := int(events.releases)
			var finishes := int(events.actions)
			assert_true(view.play_spell_action(spell))
			var state := view.get_visual_runtime_state()
			var duration := float(state.duration_seconds)
			assert_eq(state.stem, view.get_spell_animation_stem(spell))
			assert_false(view.play_hit(), "A hit cannot replace a committed bow/whip pose")
			view.advance_simulation(duration * 0.5 - 0.001)
			assert_eq(events.releases, releases)
			view.advance_simulation(0.001)
			assert_eq(events.releases, releases + 1)
			view.advance_simulation(duration)
			assert_eq(events.actions, finishes + 1)
			assert_eq(events.releases, releases + 1)
			_assert_anchor(view)


func test_exact_twenty_percent_does_not_transform_but_next_real_hp_loss_does_once() -> void:
	var fixture := _fixture()
	var view: ParisIsoUnitView = fixture.visual
	var unit: Unit = fixture.unit
	var events := _events(view)
	unit.take_damage(96)
	assert_eq(unit.current_hp, 24)
	assert_false(view.is_transformation_pending())
	unit.take_damage(1)
	assert_eq(unit.current_hp, 23)
	assert_true(view.is_transformation_pending())
	assert_eq(view.animated_sprite.animation, &"transform_S")
	assert_false(view.play_idle())
	assert_false(view.play_cast())
	view.advance_simulation(0.899)
	assert_true(view.is_transformation_pending())
	view.advance_simulation(0.001)
	assert_false(view.is_transformation_pending())
	assert_eq(view.get_visual_runtime_state().combat_form, "infernal")
	assert_eq(view.animated_sprite.sprite_frames, view._infernal_frames)
	assert_eq(events.transformations, 1)
	assert_eq(events.releases, 0, "The automatic phase reveal is not a spell release")
	assert_eq(events.actions, 0)
	unit.combat_form_changed.emit(unit, &"spectral", &"infernal")
	view.advance_simulation(10)
	assert_eq(view.get_visual_runtime_state().transformation_count, 1)
	assert_eq(events.transformations, 1)
	_assert_anchor(view)


func test_phase_change_during_committed_action_finishes_it_then_reveals_new_form() -> void:
	var fixture := _fixture()
	var view: ParisIsoUnitView = fixture.visual
	var events := _events(view)
	assert_true(view.play_spell_action(load("res://data/spells/enemies/paris/spectral_arrow.tres") as Spell))
	view.advance_simulation(0.1)
	(fixture.unit as Unit).take_damage(97)
	assert_true(view.get_visual_runtime_state().action_pending)
	assert_eq(view.animated_sprite.animation, &"attack_S")
	view.advance_simulation(0.7)
	assert_eq(events.releases, 1)
	assert_eq(events.actions, 1)
	assert_eq(view.animated_sprite.animation, &"transform_S")
	view.advance_simulation(0.9)
	assert_eq(events.transformations, 1)
	assert_eq(events.releases, 1)
	assert_eq(view.animated_sprite.animation, &"idle_S")
	assert_eq(view.animated_sprite.sprite_frames, view._infernal_frames)


func test_facing_is_held_through_transformation_and_applied_to_the_new_form() -> void:
	var fixture := _fixture()
	var view: ParisIsoUnitView = fixture.visual
	view.set_facing(Vector2i.RIGHT)
	(fixture.unit as Unit).take_damage(97)
	view.set_facing(Vector2i.UP)
	view.advance_simulation(0.4)
	assert_eq(view.animated_sprite.animation, &"transform_E")
	view.advance_simulation(0.5)
	assert_eq(view.animated_sprite.animation, &"idle_N")
	_assert_anchor(view)


func test_cancelled_reveal_settles_authoritative_form_without_replaying() -> void:
	var fixture := _fixture()
	var view: ParisIsoUnitView = fixture.visual
	var events := _events(view)
	(fixture.unit as Unit).take_damage(97)
	view.advance_simulation(0.2)
	view.cancel_pending_visual_actions()
	assert_false(view.is_transformation_pending())
	assert_eq(view.get_visual_runtime_state().combat_form, "infernal")
	assert_eq(view.animated_sprite.sprite_frames, view._infernal_frames)
	view.advance_simulation(2)
	assert_eq(events.transformations, 1, "Cancellation releases waiting runners once")
	assert_eq(events.releases, 0)
	assert_true(view.play_cast())


func test_death_during_reveal_plays_once_and_cannot_be_resurrected_by_late_signals() -> void:
	var fixture := _fixture()
	var view: ParisIsoUnitView = fixture.visual
	var events := _events(view)
	var unit: Unit = fixture.unit
	unit.take_damage(97)
	view.advance_simulation(0.2)
	unit.take_damage(999)
	assert_true(view.get_visual_runtime_state().dead)
	assert_false(view.is_transformation_pending())
	assert_eq(view.animated_sprite.animation, &"death_S")
	view.advance_simulation(0.81)
	assert_eq(events.deaths, 1)
	assert_false(view.visible)
	unit.combat_form_changed.emit(unit, &"spectral", &"infernal")
	view.advance_simulation(5)
	assert_eq(events.deaths, 1)
	assert_false(view.visible)
	assert_eq(events.releases, 0)


func test_binding_already_transformed_unit_uses_infernal_bank_without_replay() -> void:
	var unit := Unit.from_data(load(UNIT_PATH) as UnitData)
	unit.take_damage(97)
	var fixture := _fixture(unit)
	var view: ParisIsoUnitView = fixture.visual
	assert_eq(view.get_visual_runtime_state().combat_form, "infernal")
	assert_eq(view.get_visual_runtime_state().transformation_count, 0)
	assert_false(view.is_transformation_pending())
	assert_eq(view.animated_sprite.sprite_frames, view._infernal_frames)


func test_zero_time_scale_and_pause_clock_reset_do_not_advance_the_reveal() -> void:
	var fixture := _fixture()
	var view: ParisIsoUnitView = fixture.visual
	(fixture.unit as Unit).take_damage(97)
	view.advance_simulation(0.2)
	var elapsed := float(view.get_visual_runtime_state().transformation_elapsed)
	Engine.time_scale = 0
	view._process(3)
	assert_almost_eq(float(view.get_visual_runtime_state().transformation_elapsed), elapsed, 0.0001)
	view._notification(Node.NOTIFICATION_PAUSED)
	view._notification(Node.NOTIFICATION_UNPAUSED)
	assert_almost_eq(float(view.get_visual_runtime_state().transformation_elapsed), elapsed, 0.0001)
	Engine.time_scale = 1
	view.advance_simulation(0.7)
	assert_false(view.is_transformation_pending())


func test_registered_map_profiles_do_not_classify_paris_as_a_skeleton() -> void:
	var fixture := _fixture()
	var wrapper: Node2D = fixture.wrapper
	for id: String in ["greek_drawn_courtyard_v1", "ashen_hell_courtyard_v1", "silent_judgment_courtyard_v1",
			"lethe_crossing_v1", "black_oath_temple_v1"]:
		var path := "res://data/arenas/%s/presentation.tres" % id
		var presentation := load(path) as BattlePresentationProfile
		assert_not_null(presentation, path)
		if presentation == null:
			continue
		wrapper.apply_painted_presentation(presentation)
		var family := wrapper.get("_painted_family_profile") as UnitVisualProfile
		assert_eq(family.family_id, &"paris")
		assert_gte(float(wrapper.get_painted_visual_scale()), 1.5)
		_assert_anchor(fixture.visual)


func _fixture(existing: Unit = null) -> Dictionary:
	var unit := existing if existing != null else Unit.from_data(load(UNIT_PATH) as UnitData)
	var wrapper := (load("res://battle/unit_view.gd") as Script).new() as Node2D
	add_child_autofree(wrapper)
	wrapper.position = Vector2(187, 243)
	wrapper.setup(unit, false)
	var visual := wrapper.get_optional_visual() as ParisIsoUnitView
	assert_not_null(visual)
	visual.set_process(false)
	return {"unit": unit, "wrapper": wrapper, "visual": visual}


func _transform(fixture: Dictionary) -> void:
	(fixture.unit as Unit).take_damage(97)
	(fixture.visual as ParisIsoUnitView).advance_simulation(0.90)
	assert_eq((fixture.visual as ParisIsoUnitView).get_visual_runtime_state().combat_form, "infernal")


func _assert_anchor(view: ParisIsoUnitView) -> void:
	var sprite := view.animated_sprite
	assert_almost_eq(sprite.to_global(sprite.offset + view.sprite_profile.foot_anchor),
		(view.get_parent() as Node2D).global_position, Vector2(0.001, 0.001))


func _events(view: ParisIsoUnitView) -> Dictionary:
	var events := {"releases": 0, "actions": 0, "transformations": 0, "deaths": 0}
	view.cast_release_reached.connect(func() -> void: events.releases += 1)
	view.animation_finished.connect(func(_id: StringName) -> void: events.actions += 1)
	view.transformation_finished.connect(func() -> void: events.transformations += 1)
	view.death_animation_finished.connect(func() -> void: events.deaths += 1)
	return events
