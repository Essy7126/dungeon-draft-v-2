extends GutTest

const CANONICAL := preload("res://data/units/allies/achilles.tres")
const PROFILE_PATH := "res://data/visuals/achilles/achilles_kit_sprite_profile_v2.tres"
const DIRECTIONS := {"N": Vector2i.UP, "E": Vector2i.RIGHT, "S": Vector2i.DOWN, "W": Vector2i.LEFT}
const CASES := [
	{"spell": "peleid_strike", "stem": "attack", "profile": {}},
	{"spell": "peleid_strike", "stem": "sweep", "profile": {"target_shape": &"LINE", "maximum_targets": 2}},
	{"spell": "pelion_shot", "stem": "bow", "profile": {}},
	{"spell": "pelion_shot", "stem": "volley", "profile": {"target_shape": &"FAN", "maximum_targets": 3}},
	{"spell": "bronze_guard", "stem": "guard", "profile": {}},
]


func test_canonical_kit_has_authored_cardinal_clips_and_transparent_canvases() -> void:
	var view := await _create_view()
	var profile := view.sprite_profile
	assert_eq(profile.resource_path, PROFILE_PATH)
	assert_true(profile.expanded_kit_enabled)
	var frames := view.sprite_backend.animated_sprite.sprite_frames
	assert_eq(profile.validation_error(frames), &"")
	assert_eq(view.find_children("*", "AnimatedSprite2D", true, false).size(), 1)
	assert_eq(view.find_children("*", "Node3D", true, false).size(), 0)
	assert_eq(view.find_children("*", "SubViewport", true, false).size(), 0)
	var checked: Dictionary = {}
	for direction: String in DIRECTIONS:
		for stem: String in ["dash", "bow", "guard", "sweep", "volley", "hit", "death"]:
			var clip := StringName(stem + "_" + direction)
			var expected := 6 if stem in ["bow", "guard", "sweep", "volley"] else 4
			assert_eq(frames.get_frame_count(clip), expected, str(clip))
			var paths: Dictionary = {}
			for index in frames.get_frame_count(clip):
				var texture := frames.get_frame_texture(clip, index)
				assert_eq(texture.get_size(), Vector2(512, 384))
				paths[texture.resource_path] = true
				if checked.has(texture.resource_path):
					continue
				checked[texture.resource_path] = true
				var picture := texture.get_image()
				assert_not_null(picture)
				if picture == null:
					continue
				if picture.is_compressed():
					picture.decompress()
				assert_false(picture.get_used_rect().size == Vector2i.ZERO, "No empty pose: %s" % texture.resource_path)
				assert_eq(picture.get_pixel(0, 0).a, 0.0, "Transparent canvas corner")
				assert_eq(picture.get_pixel(511, 383).a, 0.0, "Transparent canvas corner")
			assert_gte(paths.size(), 3, "Authored useful poses; intentional repeated anticipation/recovery is allowed")


func test_all_families_release_once_at_the_marker_then_finish_in_correct_idle() -> void:
	var view := await _create_view()
	var backend := view.sprite_backend
	var sprite := backend.animated_sprite
	var counts := _counts(view)
	var parent := view.get_parent() as Node2D
	var initial_parent := parent.transform
	var initial_sprite := sprite.transform
	for direction: String in DIRECTIONS:
		for entry: Dictionary in CASES:
			view.set_facing(DIRECTIONS[direction])
			var spell := load("res://data/spells/achilles/%s.tres" % entry.spell) as Spell
			var before_releases: int = counts.releases
			var before_finishes: int = counts.finishes
			assert_true(view.play_spell_action(spell, entry.profile))
			assert_eq(sprite.animation, StringName("%s_%s" % [entry.stem, direction]))
			assert_false(view.play_idle(), "Idle cannot interrupt a committed action")
			assert_false(view.play_spell_action(spell), "No overlapping action")
			var state := backend.get_runtime_state()
			backend.advance_simulation(float(state.release_seconds) - 0.001)
			assert_eq(counts.releases, before_releases)
			backend.advance_simulation(0.001)
			assert_eq(counts.releases, before_releases + 1)
			assert_eq(sprite.frame, int(state.release_frame))
			assert_eq(counts.finishes, before_finishes)
			backend.advance_simulation(float(state.duration_seconds) - float(state.release_seconds) + 0.001)
			assert_eq(counts.finishes, before_finishes + 1)
			assert_eq(sprite.animation, StringName("idle_" + direction))
			backend.advance_simulation(1.5)
			assert_eq(counts.releases, before_releases + 1)
			assert_eq(counts.finishes, before_finishes + 1)
			assert_eq(sprite.frame, 0)
			assert_false(sprite.is_playing())
			assert_false(sprite.flip_h)
			assert_eq(parent.transform, initial_parent)
			assert_eq(sprite.transform, initial_sprite)
			assert_almost_eq(sprite.transform * (sprite.offset + view.sprite_profile.foot_anchor), Vector2.ZERO, Vector2(0.001, 0.001))


func test_busy_frame_publishes_release_pose_before_reentrant_cancellation() -> void:
	var view := await _create_view()
	var backend := view.sprite_backend
	var counts := _counts(view)
	var observed := {"frame": -1, "clip": ""}
	view.cast_release_reached.connect(func() -> void:
		observed.frame = backend.animated_sprite.frame
		observed.clip = str(backend.animated_sprite.animation)
		view.cancel_pending_visual_actions()
	, CONNECT_ONE_SHOT)
	var spell := load("res://data/spells/achilles/pelion_shot.tres") as Spell
	view.set_facing(Vector2i.RIGHT)
	assert_true(view.play_spell_action(spell))
	backend.advance_simulation(2.0)
	assert_eq(observed.frame, 3)
	assert_eq(observed.clip, "bow_E")
	assert_eq(counts.releases, 1)
	assert_eq(counts.finishes, 0)
	assert_eq(backend.animated_sprite.animation, &"idle_E")
	assert_true(view.play_spell_action(spell))
	backend.advance_simulation(2.0)
	assert_eq(counts.releases, 2)
	assert_eq(counts.finishes, 1)


func test_dash_holds_charge_through_maximum_real_travel_and_arrival_cancels_budget() -> void:
	var view := await _create_view()
	var backend := view.sprite_backend
	var counts := _counts(view)
	var spell := load("res://data/spells/achilles/fulminant_dash.tres") as Spell
	for direction: String in DIRECTIONS:
		var before: int = counts.releases
		view.set_facing(DIRECTIONS[direction])
		assert_true(view.play_spell_action(spell))
		backend.advance_simulation(0.099)
		assert_eq(counts.releases, before)
		backend.advance_simulation(0.001)
		assert_eq(counts.releases, before + 1)
		assert_eq(backend.animated_sprite.frame, 2)
		backend.advance_simulation(0.48)
		assert_true(bool(backend.get_runtime_state().action_pending))
		assert_eq(backend.animated_sprite.animation, StringName("dash_" + direction))
		assert_eq(backend.animated_sprite.frame, 2, "Keep the airborne pose throughout translation")
		assert_eq(counts.finishes, 0)
		view.finish_external_spell_movement()
		assert_false(bool(backend.get_runtime_state().action_pending), "Arrival releases the cast budget immediately")
		assert_true(bool(backend.get_runtime_state().landing_pending))
		assert_eq(backend.animated_sprite.frame, 3, "Planted reception begins only after arrival")
		assert_false(view.play_idle(), "Routine idle cannot erase the short landing")
		backend.advance_simulation(0.04)
		view.finish_external_spell_movement()
		backend.advance_simulation(0.039)
		assert_eq(backend.animated_sprite.frame, 3, "Repeated arrival cannot restart or cancel reception")
		backend.advance_simulation(0.001)
		assert_false(bool(backend.get_runtime_state().landing_pending))
		assert_eq(backend.animated_sprite.animation, StringName("idle_" + direction))
		backend.advance_simulation(3.0)
		assert_eq(counts.releases, before + 1)
		assert_eq(counts.finishes, 0, "Landing never publishes an attack completion or another marker")
		assert_eq(backend.animated_sprite.frame, 0)
	# Reception is cosmetic: intentional play interrupts it without any late
	# timer putting the actor back in idle over that newer action.
	for interruption: String in ["action", "walk", "hit", "cancel"]:
		assert_true(view.play_spell_action(spell))
		backend.advance_simulation(0.1)
		view.finish_external_spell_movement()
		var released: int = counts.releases
		var expected := "idle"
		match interruption:
			"action":
				assert_true(view.play_spell_action(load("res://data/spells/achilles/bronze_guard.tres") as Spell))
				expected = "guard"
			"walk":
				view.begin_movement_feedback(Vector2i.ZERO, Vector2i.LEFT)
				expected = "walk"
			"hit":
				assert_true(view.play_hit())
				expected = "hit"
			"cancel":
				view.cancel_pending_visual_actions()
		backend.advance_simulation(0.09)
		assert_false(bool(backend.get_runtime_state().landing_pending))
		assert_eq(String(backend.get_runtime_state().stem), expected)
		assert_eq(counts.releases, released)
		assert_eq(counts.finishes, 0)
		view.cancel_pending_visual_actions()
	assert_true(view.play_spell_action(spell))
	backend.advance_simulation(0.1)
	view.finish_external_spell_movement()
	assert_true(backend.play_death("S"))
	backend.advance_simulation(0.09)
	assert_false(bool(backend.get_runtime_state().landing_pending))
	assert_eq(backend.animated_sprite.animation, &"death_S")


func test_direction_change_during_guard_preserves_pose_then_uses_new_idle() -> void:
	var view := await _create_view()
	var backend := view.sprite_backend
	var counts := _counts(view)
	view.set_facing(Vector2i.RIGHT)
	assert_true(view.play_spell_action(load("res://data/spells/achilles/bronze_guard.tres") as Spell))
	backend.advance_simulation(0.1)
	view.set_facing(Vector2i.UP)
	assert_eq(backend.animated_sprite.animation, &"guard_E")
	backend.advance_simulation(0.6)
	assert_eq(counts.releases, 1)
	assert_eq(counts.finishes, 1)
	assert_eq(backend.animated_sprite.animation, &"idle_N")


func test_hit_and_death_clips_do_not_publish_attack_markers_or_move_ground_anchor() -> void:
	var view := await _create_view()
	var backend := view.sprite_backend
	var counts := _counts(view)
	var parent := view.get_parent() as Node2D
	var original := parent.transform
	assert_true(backend.play_hit("W"))
	backend.advance_simulation(0.12)
	assert_eq(backend.animated_sprite.animation, &"hit_W")
	backend.advance_simulation(0.2)
	assert_eq(backend.animated_sprite.animation, &"idle_W")
	assert_eq(counts.releases, 0)
	assert_eq(counts.finishes, 0)
	assert_true(view.play_spell_action(load("res://data/spells/achilles/pelion_shot.tres") as Spell))
	var deaths := {"count": 0}
	backend.death_pose_finished.connect(func() -> void: deaths.count += 1)
	assert_true(backend.play_death("S"))
	backend.advance_simulation(1.0)
	assert_eq(backend.animated_sprite.animation, &"death_S")
	assert_eq(deaths.count, 1)
	assert_eq(counts.releases, 0)
	assert_eq(counts.finishes, 0)
	assert_false(backend.play_action("S"))
	backend.advance_simulation(2.0)
	assert_eq(deaths.count, 1)
	assert_eq(parent.transform, original)
	assert_eq(backend.animated_sprite.position, Vector2.ZERO)


func _create_view() -> AchillesIsoUnitView:
	var parent := Node2D.new()
	parent.position = Vector2(137, 211)
	add_child_autofree(parent)
	var view := CANONICAL.visual_scene.instantiate() as AchillesIsoUnitView
	parent.add_child(view)
	await wait_process_frames(2)
	view.set_process(false)
	view.sprite_backend.set_process(false)
	return view


func _counts(view: AchillesIsoUnitView) -> Dictionary:
	var counts := {"releases": 0, "finishes": 0}
	view.cast_release_reached.connect(func() -> void: counts.releases += 1)
	view.animation_finished.connect(func(_clip: StringName) -> void: counts.finishes += 1)
	return counts
