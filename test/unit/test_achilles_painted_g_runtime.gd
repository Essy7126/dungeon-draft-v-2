extends GutTest

const CLASSIC_SCENE := "res://characters/achilles/AchillesIsoUnitView.tscn"
const PAINTED_SCENE := "res://characters/achilles/AchillesPaintedGUnitView.tscn"
const PAINTED_PROFILE := "res://data/visuals/achilles/achilles_painted_g_sprite_profile.tres"
const PAINTED_FRAMES := "res://assets/characters/Achilles/sprites_painted_g/achilles_sprite_frames.tres"
const CANONICAL := preload("res://data/units/allies/achilles.tres")
const UNIT_VIEW := preload("res://battle/unit_view.gd")
const DIRECTIONS := {"N": Vector2i.UP, "E": Vector2i.RIGHT, "S": Vector2i.DOWN, "W": Vector2i.LEFT}
const STEMS := ["idle", "walk", "attack", "dash", "bow", "guard", "sweep", "volley", "hit", "death"]
const CASES := [
	{"spell": "peleid_strike", "stem": "attack", "profile": {}},
	{"spell": "peleid_strike", "stem": "sweep", "profile": {"target_shape": &"LINE", "maximum_targets": 2}},
	{"spell": "pelion_shot", "stem": "bow", "profile": {}},
	{"spell": "pelion_shot", "stem": "volley", "profile": {"target_shape": &"FAN", "maximum_targets": 3}},
	{"spell": "bronze_guard", "stem": "guard", "profile": {}},
]


func test_painted_scene_uses_shared_backend_with_complete_directional_kit() -> void:
	var view := await _create_view(PAINTED_SCENE)
	if view == null:
		return
	assert_eq(view.get_script().resource_path, "res://characters/achilles/achilles_iso_unit_view.gd")
	assert_eq(view.rendering_backend, "SPRITE_2D")
	assert_eq(view.sprite_profile.resource_path, PAINTED_PROFILE)
	assert_eq(view.sprite_profile.sprite_frames_path, PAINTED_FRAMES)
	assert_true(view.sprite_profile.expanded_kit_enabled)
	assert_eq(view.sprite_backend.get_script().resource_path, "res://characters/achilles/2d/achilles_sprite_2d_backend.gd")
	assert_true(view.sprite_backend.is_backend_active())
	assert_eq(view.find_children("*", "AnimatedSprite2D", true, false).size(), 1)
	assert_eq(view.find_children("*", "SubViewport", true, false).size(), 0)
	assert_eq(view.find_children("*", "Node3D", true, false).size(), 0)
	var frames := view.sprite_backend.animated_sprite.sprite_frames
	assert_eq(view.sprite_profile.validation_error(frames), &"")
	assert_eq(frames.get_animation_names().size(), 40, "Every canonical family has four directions")
	var canvas := view.sprite_profile.frame_canvas_size
	for stem: String in STEMS:
		var direction_textures: Dictionary = {}
		for direction: String in DIRECTIONS:
			var clip := StringName(stem + "_" + direction)
			assert_true(frames.has_animation(clip), str(clip))
			if not frames.has_animation(clip):
				continue
			assert_gt(frames.get_frame_count(clip), 0, str(clip))
			assert_eq(frames.get_animation_loop(clip), stem in ["idle", "walk"], str(clip))
			var first := frames.get_frame_texture(clip, 0)
			if first == null:
				fail_test("Missing first pose: " + str(clip))
				continue
			# Different directions need different source regions, even in a shared atlas.
			var identity := first.resource_path
			if first is AtlasTexture:
				identity = first.atlas.resource_path + ":" + str(first.region)
			direction_textures[identity] = true
			for index in frames.get_frame_count(clip):
				var texture := frames.get_frame_texture(clip, index)
				assert_not_null(texture, "%s frame %s" % [clip, index])
				if texture == null:
					continue
				assert_eq(texture.get_size(), Vector2(canvas), str(clip))
			assert_eq(first.get_size(), Vector2(canvas))
		assert_eq(direction_textures.size(), 4, "No missing orientation replaced by the same texture: " + stem)


func test_spells_and_mastery_variants_release_once_with_classic_timing_in_every_direction() -> void:
	var classic := await _create_view(CLASSIC_SCENE)
	var painted := await _create_view(PAINTED_SCENE)
	if classic == null or painted == null:
		return
	var classic_counts := _counts(classic)
	var painted_counts := _counts(painted)
	for direction: String in DIRECTIONS:
		for entry: Dictionary in CASES:
			var spell := load("res://data/spells/achilles/%s.tres" % entry.spell) as Spell
			classic.set_facing(DIRECTIONS[direction])
			painted.set_facing(DIRECTIONS[direction])
			assert_true(classic.play_spell_action(spell, entry.profile))
			assert_true(painted.play_spell_action(spell, entry.profile))
			var expected := classic.sprite_backend.get_runtime_state()
			var actual := painted.sprite_backend.get_runtime_state()
			assert_eq(actual.animation, "%s_%s" % [entry.stem, direction])
			assert_eq(actual.action_id, expected.action_id)
			assert_eq(actual.presentation, expected.presentation, "Mastery geometry must use the shared resolver")
			assert_almost_eq(float(actual.release_seconds), float(expected.release_seconds), 0.000001)
			assert_almost_eq(float(actual.duration_seconds), float(expected.duration_seconds), 0.000001)
			assert_eq(actual.release_frame, expected.release_frame)
			var before: int = painted_counts.releases
			assert_false(painted.play_idle(), "Idle cannot interrupt the accepted spell")
			assert_false(painted.play_spell_action(spell), "A second spell cannot overlap")
			for view: AchillesIsoUnitView in [classic, painted]:
				view.sprite_backend.advance_simulation(float(actual.release_seconds) - 0.001)
			assert_eq(painted_counts.releases, before)
			assert_eq(classic_counts.releases, before)
			for view: AchillesIsoUnitView in [classic, painted]:
				view.sprite_backend.advance_simulation(0.001)
				assert_eq(view.sprite_backend.animated_sprite.frame, int(actual.release_frame))
			assert_eq(painted_counts.releases, before + 1)
			assert_eq(classic_counts.releases, before + 1)
			for view: AchillesIsoUnitView in [classic, painted]:
				view.sprite_backend.advance_simulation(float(actual.duration_seconds) - float(actual.release_seconds) + 0.001)
				view.sprite_backend.advance_simulation(1.0)
				assert_eq(view.sprite_backend.animated_sprite.animation, StringName("idle_" + direction))
				assert_false(view._action_pending)
			assert_eq(painted_counts.releases, before + 1)
			assert_eq(painted_counts.finishes, before + 1)
			assert_eq(classic_counts, painted_counts)


func test_directional_movement_is_distance_driven_and_keeps_the_ground_anchor() -> void:
	var view := await _create_view(PAINTED_SCENE)
	if view == null:
		return
	var sprite := view.sprite_backend.animated_sprite
	var parent := view.get_parent() as Node2D
	var original := parent.transform
	for direction: String in DIRECTIONS:
		view.begin_path_movement_feedback([Vector2i.ZERO, DIRECTIONS[direction], DIRECTIONS[direction] * 2])
		assert_eq(sprite.animation, StringName("walk_" + direction))
		var count := sprite.sprite_frames.get_frame_count(sprite.animation)
		assert_eq(count % 2, 0, "The two steps must have equal phase counts")
		var half := count / 2
		for step_index in 2:
			view.update_movement_stride(step_index, 1.0)
			assert_eq(sprite.frame, (step_index + 1) * half - 1)
			var held_frame := sprite.frame
			view.sprite_backend.advance_simulation(0.5)
			assert_eq(sprite.frame, held_frame, "Time cannot advance feet while the cell tween is stationary")
			assert_false(sprite.is_playing())
			assert_false(sprite.flip_h)
			assert_false(sprite.flip_v)
			assert_eq(parent.transform, original, "Only Battle may move the gameplay root")
			_assert_ground_anchor(view)
		view.cancel_movement_feedback()
		assert_eq(sprite.animation, StringName("idle_" + direction))
		assert_eq(sprite.frame, 0)
		view.update_movement_stride(0, 0.5)
		assert_eq(sprite.frame, 0, "A late stride callback cannot restart movement")
	var path: Array = []
	for index in 7:
		path.append(Vector2i(index, 0))
	view.begin_path_movement_feedback(path)
	assert_almost_eq(view.get_movement_segment_duration(path), 0.2, 0.000001)
	assert_almost_eq(sprite.speed_scale, 1.4, 0.000001)
	view.cancel_movement_feedback()
	assert_true(view.play_basic_attack(), "Running cannot leave the next attack locked")
	view.sprite_backend.advance_simulation(1.0)
	assert_false(view._action_pending)


func test_dash_holds_release_until_real_arrival_then_allows_the_next_spell() -> void:
	var view := await _create_view(PAINTED_SCENE)
	if view == null:
		return
	var counts := _counts(view)
	var backend := view.sprite_backend
	var dash := load("res://data/spells/achilles/fulminant_dash.tres") as Spell
	var guard := load("res://data/spells/achilles/bronze_guard.tres") as Spell
	for direction: String in DIRECTIONS:
		view.set_facing(DIRECTIONS[direction])
		var released: int = counts.releases
		var finished: int = counts.finishes
		assert_true(view.play_spell_action(dash))
		backend.advance_simulation(view.sprite_profile.advance_release_seconds - 0.001)
		assert_eq(counts.releases, released)
		backend.advance_simulation(0.001)
		assert_eq(counts.releases, released + 1)
		assert_eq(backend.animated_sprite.frame, 2)
		backend.advance_simulation(0.48)
		assert_true(bool(backend.get_runtime_state().action_pending))
		assert_eq(backend.animated_sprite.animation, StringName("dash_" + direction))
		assert_eq(backend.animated_sprite.frame, 2)
		_assert_ground_anchor(view)
		view.finish_external_spell_movement()
		assert_false(view._action_pending)
		assert_true(bool(backend.get_runtime_state().landing_pending))
		assert_eq(backend.animated_sprite.frame, 3)
		assert_eq(counts.finishes, finished, "Arrival is not a second attack impact")
		assert_true(view.play_spell_action(guard), "An intentional action may interrupt cosmetic reception")
		assert_false(bool(backend.get_runtime_state().landing_pending))
		backend.advance_simulation(2.0)
		assert_eq(counts.releases, released + 2)
		assert_eq(counts.finishes, finished + 1)
		assert_eq(backend.animated_sprite.animation, StringName("idle_" + direction))


func test_cancelled_and_reentrant_actions_cannot_publish_stale_markers() -> void:
	var view := await _create_view(PAINTED_SCENE)
	if view == null:
		return
	var counts := _counts(view)
	var backend := view.sprite_backend
	var spell := load("res://data/spells/achilles/pelion_shot.tres") as Spell
	view.set_facing(Vector2i.RIGHT)
	assert_true(view.play_spell_action(spell))
	backend.advance_simulation(0.01)
	view.cancel_pending_visual_actions()
	backend.advance_simulation(3.0)
	assert_eq(counts.releases, 0)
	assert_eq(counts.finishes, 0)
	var observed := {"clip": "", "frame": -1}
	view.cast_release_reached.connect(func() -> void:
		observed.clip = str(backend.animated_sprite.animation)
		observed.frame = backend.animated_sprite.frame
		view.cancel_pending_visual_actions()
	, CONNECT_ONE_SHOT)
	assert_true(view.play_spell_action(spell))
	backend.advance_simulation(3.0)
	assert_eq(observed.clip, "bow_E")
	assert_eq(observed.frame, 3, "A busy frame must publish the release drawing before callbacks")
	assert_eq(counts.releases, 1)
	assert_eq(counts.finishes, 0)
	assert_true(view.play_spell_action(spell))
	backend.advance_simulation(3.0)
	assert_eq(counts.releases, 2)
	assert_eq(counts.finishes, 1)


func test_hit_and_death_use_each_orientation_without_attack_events() -> void:
	for direction: String in DIRECTIONS:
		var view := await _create_view(PAINTED_SCENE)
		if view == null:
			return
		var backend := view.sprite_backend
		var counts := _counts(view)
		var actor := Unit.from_data(CANONICAL)
		actor.grid_pos = Vector2i.ZERO
		view.bind_unit(actor)
		view.set_facing(DIRECTIONS[direction])
		assert_true(view.play_hit())
		backend.advance_simulation(view.sprite_profile.hit_duration_seconds * 0.5)
		assert_eq(backend.animated_sprite.animation, StringName("hit_" + direction))
		backend.advance_simulation(view.sprite_profile.hit_duration_seconds)
		assert_eq(backend.animated_sprite.animation, StringName("idle_" + direction))
		assert_true(view.play_basic_attack())
		var deaths := {"count": 0}
		backend.death_pose_finished.connect(func() -> void: deaths.count += 1)
		actor.take_damage(10000, null, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
			{"ignore_defense": true, "cannot_be_dodged": true})
		assert_false(actor.is_alive)
		assert_false(view._action_pending, "The bound unit death cancels a pending cast")
		backend.advance_simulation(3.0)
		assert_eq(backend.animated_sprite.animation, StringName("death_" + direction))
		assert_eq(backend.animated_sprite.frame, 3)
		assert_eq(deaths.count, 1)
		assert_eq(counts.releases, 0)
		assert_eq(counts.finishes, 0)
		assert_false(backend.play_action(direction))
		backend.advance_simulation(3.0)
		assert_eq(deaths.count, 1)
		_assert_ground_anchor(view)


func test_battle_unit_view_waits_for_painted_release_and_clears_pending_action() -> void:
	var scene := load(PAINTED_SCENE) as PackedScene
	assert_not_null(scene)
	if scene == null:
		return
	var data := CANONICAL.duplicate(true) as UnitData
	data.visual_scene = scene
	var actor := Unit.from_data(data)
	actor.grid_pos = Vector2i.ZERO
	var owner := UNIT_VIEW.new()
	add_child_autofree(owner)
	owner.setup(actor, false)
	await wait_process_frames(3)
	var visual := owner.get_optional_visual() as AchillesIsoUnitView
	assert_not_null(visual)
	if visual == null or visual.sprite_backend == null:
		return
	visual.set_process(false)
	visual.sprite_backend.set_process(false)
	var counts := _counts(visual)
	var observed := {"returned": false, "ok": false}
	var complete_preparation := func() -> void:
		observed.ok = await owner.prepare_spell_visual(Vector2i.RIGHT, load("res://data/spells/achilles/peleid_strike.tres") as Spell)
		observed.returned = true
	complete_preparation.call()
	assert_true(owner.is_action_visual_pending())
	assert_false(observed.returned, "Gameplay preparation must wait for the actual visual marker")
	assert_eq(visual.sprite_backend.animated_sprite.animation, &"attack_E")
	visual.sprite_backend.advance_simulation(visual.sprite_profile.attack_release_seconds - 0.001)
	await wait_process_frames(1)
	assert_false(observed.returned)
	assert_eq(counts.releases, 0)
	visual.sprite_backend.advance_simulation(0.001)
	await wait_process_frames(2)
	assert_true(observed.returned)
	assert_true(observed.ok)
	assert_eq(counts.releases, 1)
	assert_true(owner.is_action_visual_pending(), "Recovery remains locked after the release")
	visual.sprite_backend.advance_simulation(1.0)
	assert_eq(counts.finishes, 1)
	await owner.wait_for_action_visual_finished()
	assert_false(owner.is_action_visual_pending())
	assert_eq(actor.grid_pos, Vector2i.ZERO, "Presentation must never relocate the gameplay unit")


func _create_view(scene_path: String) -> AchillesIsoUnitView:
	var scene := load(scene_path) as PackedScene
	assert_not_null(scene, scene_path)
	if scene == null:
		return null
	var parent := Node2D.new()
	parent.position = Vector2(137, 211)
	parent.scale = Vector2(1.2, 0.9)
	add_child_autofree(parent)
	var view := scene.instantiate() as AchillesIsoUnitView
	assert_not_null(view)
	if view == null:
		return null
	parent.add_child(view)
	await wait_process_frames(3)
	view.set_process(false)
	assert_not_null(view.sprite_backend)
	if view.sprite_backend == null:
		return null
	view.sprite_backend.set_process(false)
	return view


func _counts(view: AchillesIsoUnitView) -> Dictionary:
	var counts := {"releases": 0, "finishes": 0}
	view.cast_release_reached.connect(func() -> void: counts.releases += 1)
	view.animation_finished.connect(func(_clip: StringName) -> void: counts.finishes += 1)
	return counts


func _assert_ground_anchor(view: AchillesIsoUnitView) -> void:
	var sprite := view.sprite_backend.animated_sprite
	assert_almost_eq(sprite.transform * (sprite.offset + view.sprite_profile.foot_anchor), Vector2.ZERO, Vector2(0.001, 0.001))
	assert_eq(sprite.position, Vector2.ZERO)
	assert_false(sprite.flip_h)
	assert_false(sprite.flip_v)
