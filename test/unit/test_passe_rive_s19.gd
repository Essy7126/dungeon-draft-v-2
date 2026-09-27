extends GutTest

const Backend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const Catalog := preload("res://characters/achilles/2d/passe_rive_s19_catalog.gd")
const Effect := preload("res://vfx/class_cards/passe_rive_s19_effect.gd")
const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
const Cards := preload("res://core/expedition/class_card_catalog.gd")
const Directions := preload("res://characters/achilles/2d/passe_rive_s20_directions.gd")
const Registration := preload("res://characters/achilles/2d/passe_rive_s22_registration.gd")
const CurrentCards := preload("res://core/expedition/consumable_card_catalog.gd")
const CurrentSpells := preload("res://core/expedition/consumable_card_spells.gd")
const Bindings := preload("res://characters/achilles/2d/passe_rive_card_bindings.gd")


func test_current_deck_has_explicit_assignments_and_never_uses_icon_ids_as_gestures() -> void:
	var ids: Array[String] = CurrentCards.pool()
	ids.append_array(["fallback_strike", "fallback_guard"])
	assert_eq(Bindings.CURRENT.size(), ids.size(), "48 cards plus two emergency actions")
	for id in ids:
		assert_true(Bindings.CURRENT.has(id), id + " must be reviewed when added to the deck")
		for upgraded in [false, true]:
			var spell := CurrentSpells.make_spell(id, upgraded)
			var binding := Bindings.resolve(str(spell.spell_id))
			assert_ne(binding.status, "unmapped", id)
			var row := CurrentSpells.definition(id, upgraded)
			if row.op in ["guard", "counter", "draw", "heal", "edict", "renew"]:
				assert_true(
					binding.reference in ["", "incantation", "guard"],
					"Support stays unarmed: " + id,
				)
			if row.op == "move":
				assert_eq(binding.reference, "dash")
			if row.op in ["blink", "swap"]:
				assert_eq(
					binding.reference,
					"blink",
					"Teleportation must not run through obstacles",
				)
	assert_eq(CurrentSpells.ICONS.n05, "a_dagger", "Historical icon is deliberately different")
	assert_eq(Bindings.resolve("cc2_n05").reference, "r_shot", "Trait court must draw the bow")
	assert_eq(Bindings.resolve("cc2_unknown").status, "unmapped")
	assert_true(Catalog.fallback("cc2_unknown").is_empty())


func test_current_shots_volleys_throwing_magic_and_kick_use_the_right_release_drawing() -> void:
	var expected := {
		"n05": "PR_SHOT",
		"r01": "PR_SHOT",
		"r02": "PR_SHOT",
		"r03": "PR_SHOT",
		"r07": "PR_SHOT",
		"r09": "PR_SHOT",
		"r04": "PR_VOLLEY",
		"r06": "PR_VOLLEY",
		"a07": "PR_DAGGER",
		"a08": "PR_DAGGER",
		"a03": "PR_BLADES",
		"a04": "PR_RIPOSTE",
		"t01": "PR_SEAL",
		"t06": Backend.IncantationBody.CLIP,
		"t02": "PR_EMBER",
		"t05": "PR_EMBER",
		"n04": Backend.KICK,
		"n02": Backend.GuardBody.CLIP,
		"g08": Backend.IncantationBody.CLIP,
		"n08": "idle_SE",
	}
	var backend := make_backend()
	var releases: Array[Dictionary] = []
	backend.action_release_reached.connect(
		func():
			releases.append(backend.get_runtime_state()),
	)
	for id in expected:
		for upgraded in [false, true]:
			releases.clear()
			var spell := CurrentSpells.make_spell(id, upgraded)
			assert_true(
				backend.play_action(
					"SE",
					StringName("cast:" + str(spell.spell_id)),
					{ "spell_id": spell.spell_id },
				)
			)
			backend.advance_simulation(3.0)
			assert_eq(releases.size(), 1, id + " exactly one effect release")
			assert_eq(releases[0].animation, expected[id], id + " actual release silhouette")
			assert_true(str(backend.get_runtime_state().animation).begins_with("idle_"))
			assert_true(
				backend.animated_sprite.visible
				and not backend.body.visible and not backend.kick.visible
			)
	backend.play_action("NW", &"cast:cc2_n04", { "spell_id": "cc2_n04" })
	assert_false(backend.kick.visible, "Kick still has only the reviewed SE artwork")
	backend.cancel_action()
	backend.play_action("SE", &"cast:cc2_n03", { "spell_id": "cc2_n03" })
	assert_eq(backend.get_runtime_state().animation, "dash_SE")
	backend.cancel_action()
	backend.play_action("SE", &"cast:cc2_r05", { "spell_id": "cc2_r05" })
	assert_eq(backend.get_runtime_state().animation, "idle_SE")


func make_backend() -> Node2D:
	var backend := Backend.new()
	add_child_autofree(backend)
	assert_true(backend.configure(PROFILE))
	backend.set_backend_active(true)
	backend.set_cards_mode(true)
	backend.set_process(false)
	return backend


func test_cards_reuse_exact_exploration_frames_contacts_and_stride() -> void:
	var backend := make_backend()
	var exploration := PasseRiveAutoSpriteBackend.new()
	add_child_autofree(exploration)
	assert_true(exploration.configure(PROFILE))
	exploration.set_backend_active(true)
	exploration.set_process(false)
	for direction in Directions.CANONICAL:
		for running in [false, true]:
			backend.play_idle(direction)
			exploration.play_idle(direction)
			backend.advance_simulation(.45)
			exploration.advance_simulation(.45)
			assert_eq(backend.animated_sprite.frame, exploration.animated_sprite.frame)
			assert_true(backend.animated_sprite.visible and not backend.body.visible)
			backend.play_move(direction, running)
			exploration.play_move(direction, running)
			for distance in [0.0, 12.0, 35.0, 44.0, 10.0]:
				backend.advance_ground_distance(distance)
				exploration.advance_ground_distance(distance)
				var actual: AnimatedSprite2D = backend.animated_sprite
				var expected: AnimatedSprite2D = exploration.animated_sprite
				assert_eq(actual.animation, expected.animation)
				assert_eq(actual.frame, expected.frame)
				assert_eq(actual.offset, expected.offset)
				assert_eq(actual.scale, expected.scale)
				assert_eq(
					actual.sprite_frames.get_frame_texture(actual.animation, actual.frame),
					expected.sprite_frames.get_frame_texture(expected.animation, expected.frame),
				)
			var pose: int = backend.animated_sprite.frame
			backend.set_facing_label("NE")
			assert_eq(backend.animated_sprite.frame, pose, "Turning preserves phase")
			backend.advance_simulation(2.0)
			assert_eq(backend.animated_sprite.frame, pose, "No translation means no steps")


func test_appearance_is_shared_but_clip_and_environment_state_are_isolated() -> void:
	var appearance = preload("res://characters/achilles/2d/passe_rive_appearance.gd")
	var a := make_backend()
	var b := make_backend()
	a.play_idle("SE")
	b.play_idle("SE")
	var material_a: ShaderMaterial = a.animated_sprite.material
	var material_b: ShaderMaterial = b.animated_sprite.material
	assert_eq(material_a.shader, appearance.PALETTE_SHADER)
	assert_eq(material_a.shader, b.body.material.shader)
	assert_ne(material_a, material_b, "A room cannot tint another actor's material")
	material_a.set_shader_parameter("warm_light", 1.0)
	assert_eq(material_b.get_shader_parameter("warm_light"), 0.0)
	var original_gain: Vector3 = material_a.get_shader_parameter("cape_gain")
	for card in Catalog.Data.CARDS:
		a.play_action("SE", &"cast", { "spell_id": "class_" + card })
		a._sample_action_at(Catalog.card(card).confirm_ms / 1000.0)
		assert_false(a.animated_sprite.visible, "Never stack two character silhouettes")
		assert_eq(a.body.modulate.a, 1.0, "No translucent ghost during the action")
		assert_eq(material_a.get_shader_parameter("cape_gain"), original_gain)
		a.cancel_action()
		a.play_idle("SE")
		assert_true(a.animated_sprite.visible and not a.body.visible)
		assert_eq(a.animated_sprite.self_modulate, Color.WHITE)
		assert_eq(material_a.get_shader_parameter("cape_gain"), original_gain)


func test_registration_and_vfx_origin_follow_one_constant_calibration_per_clip() -> void:
	var registration = preload("res://characters/achilles/2d/passe_rive_registration.gd")
	var backend := make_backend()
	for direction in Directions.CANONICAL:
		for id in Catalog.Data.CARDS:
			var card: Dictionary = Catalog.card(id)
			backend.play_action(direction, &"cast", { "spell_id": "class_" + id })
			var factor: float = registration.factor(card.clip, direction)
			assert_between(factor, .90, 1.0, "Coverage cannot arbitrarily shrink the head")
			var contact: Vector2 = backend.get_vfx_origin()
			for t in [.08, card.confirm_ms / 1000.0, card.body_duration_ms / 1000.0 - .01]:
				backend._sample_action_at(t)
				assert_eq(
					backend.get_vfx_origin(),
					contact,
					"Stable launch point within the gesture",
				)
			backend.cancel_action()
			backend.play_idle(direction)


func test_movement_cards_have_native_travel_and_arrival_without_second_release() -> void:
	var backend := make_backend()
	watch_signals(backend)
	for id in [
		"g_charge",
		"a_step",
		"a_escape",
		"g_step",
		"r_step",
		"r_escape",
		"t_step",
		"t_escape",
		"i_a_step",
	]:
		var definition := Cards.row(id)
		if definition.is_empty():
			continue
		assert_true(backend.play_action("SE", &"cast", { "spell_id": "class_" + id }))
		backend.advance_simulation(.25)
		assert_eq(backend.get_runtime_state().animation, "dash_SE", id)
		assert_between(backend.animated_sprite.frame, 2, 13)
		assert_true(backend.animated_sprite.visible and not backend.body.visible)
		backend.cancel_action()
		assert_true(backend.finish_dash_landing("SE"))
		assert_eq(backend.animated_sprite.frame, 14)
		backend.advance_simulation(.15)
		assert_between(backend.animated_sprite.frame, 18, 20)
		assert_false(backend.play_idle("SE"))
		backend.advance_simulation(.16)
		assert_eq(backend.get_runtime_state().animation, "idle_SE")
	assert_signal_emit_count(backend, "action_release_reached", 9)
	assert_signal_emit_count(backend, "action_finished", 0)


func test_dash_art_exists_in_all_eight_facings() -> void:
	var backend := make_backend()
	for direction in Directions.CANONICAL:
		assert_true(backend.play_action(direction, &"cast", { "spell_id": "class_g_charge" }))
		backend.advance_simulation(.2)
		assert_eq(backend.get_runtime_state().animation, "dash_" + direction)
		assert_true(backend.animated_sprite.visible and not backend.body.visible)
		backend.cancel_action()
		assert_true(backend.finish_dash_landing(direction))
		backend.advance_simulation(.31)
		assert_eq(backend.get_runtime_state().animation, "idle_" + direction)


func test_attack_scale_is_constant_through_action_and_tracks_reference_profile() -> void:
	var backend := make_backend()
	for id in Catalog.Data.CARDS:
		for direction in Directions.CANONICAL:
			backend.play_action(direction, &"cast", { "spell_id": "class_" + id })
			var expected: Vector2 = backend.body.transform.y
			for time in [0.0, .2, .45, .7, .9]:
				backend._sample_action_at(time)
				assert_eq(backend.body.transform.y, expected, "Pose never rescales drawing")
			assert_almost_eq(absf(expected.y) * 330.0, 214.0 * PROFILE.display_scale, .0001)
			backend.cancel_action()
			backend.play_idle(direction)
			assert_false(backend.body.visible)


func test_release_pose_once_even_when_one_frame_crosses_the_whole_action() -> void:
	var backend := make_backend()
	var releases: Array = []
	var finishes: Array = []
	backend.action_release_reached.connect(
		func():
			releases.append(backend.get_runtime_state()),
	)
	backend.action_finished.connect(
		func(id):
			finishes.append(id),
	)
	for id in Catalog.Data.CARDS:
		for direction in ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]:
			releases.clear()
			finishes.clear()
			var card: Dictionary = Catalog.Data.CARDS[id]
			assert_true(backend.play_action(direction, &"cast", { "spell_id": "class_" + id }))
			backend.advance_simulation(4.0)
			assert_eq(releases.size(), 1, id + " one release")
			assert_eq(finishes.size(), 1, id + " one recovery")
			assert_eq(releases[0].animation, card.clip)
			assert_eq(releases[0].frame, int(card.confirm_frame), id + " exact release drawing")
			assert_eq(releases[0].mirrored, direction in ["W", "NW", "SW"])
			var expected_source: String = (
				""
				if direction in ["E", "W"]
				else card.clip + "_" + Directions.CANONICAL[direction]
			)
			assert_eq(
				releases[0].directional_source,
				expected_source,
				"Actual drawing follows projected facing",
			)
			assert_gt(backend.body.transform.y.y, 0.0, "Facing changes keep the character upright")
			assert_true(str(backend.get_runtime_state().animation).begins_with("idle_"))
			assert_false(backend.body.visible)
			backend.advance_simulation(4.0)
			assert_eq(releases.size(), 1)


func test_cancellation_death_and_distance_driven_walk() -> void:
	var backend := make_backend()
	var releases: Array = []
	backend.action_release_reached.connect(
		func():
			releases.append(true),
	)
	backend.play_action("E", &"cast", { "spell_id": "class_r_shot" })
	backend.advance_simulation(0.3)
	backend.cancel_action()
	backend.play_idle("E")
	backend.advance_simulation(2.0)
	assert_true(releases.is_empty(), "Interrupted anticipation cannot resolve a hit")
	assert_true(backend.play_move("W", true))
	backend.advance_ground_distance(22.0)
	assert_eq(backend.get_runtime_state().animation, "run_W")
	var pose: int = backend.animated_sprite.frame
	backend.advance_simulation(3.0)
	assert_eq(
		backend.animated_sprite.frame,
		pose,
		"No sliding cycle while ground travel is stopped",
	)
	backend.play_idle("E")
	backend.play_action("E", &"cast", { "spell_id": "class_a_dagger" })
	backend.play_death("E")
	backend.advance_simulation(3.0)
	assert_true(releases.is_empty(), "Death cancels the release")
	assert_eq(backend.get_runtime_state().animation, "death_E")
	assert_true(backend.animated_sprite.visible and not backend.body.visible)


func test_original_timing_regions_aliases_and_card_rules_match() -> void:
	for id in Catalog.Data.CARDS:
		var card: Dictionary = Catalog.Data.CARDS[id]
		assert_eq(Cards.row(id), card.source_row)
		assert_almost_eq(Catalog.duration(card.clip), card.body_duration_ms / 1000.0, 0.00001)
		assert_eq(Catalog.frame_at(card.clip, card.confirm_ms / 1000.0), int(card.confirm_frame))
	for alias in Catalog.ALIASES:
		assert_eq(Catalog.card("class_" + alias).id, Catalog.ALIASES[alias])
	assert_true(Catalog.card("class_g_guard").is_empty())
	var dagger: Dictionary = Catalog.Data.REGIONS.PR_DAGGER
	assert_true(dagger.frames[6].has("effects"), "Cross-cell projectile drawing is retained")
	assert_true(dagger.frames[7].has("exclude"), "Projectile is not drawn twice")
	assert_true(Catalog.Data.REGIONS.PR_SHOT.frames[7].has("exclude"), "Wrong-way painted arrow is excluded")
	assert_true(
		Directions.Art.REGIONS.PR_SEAL_SE.frames[0].has("exclude"),
		"No cross-row seal under neutral feet",
	)
	assert_true(
		Directions.Art.REGIONS.PR_SEAL_SE.frames[4].has("effects"),
		"Whole seal stays with the raised hand",
	)
	for facing in ["SE", "SW"]:
		assert_eq(Directions.pose_index("PR_VOLLEY", facing, 6), 5, "Hold until actual release")
		assert_eq(
			Directions.pose_index("PR_VOLLEY", facing, 7),
			7,
			"Release drawing stays synchronized",
		)


func test_target_effects_and_status_hold_have_distinct_lifetimes() -> void:
	var world := Node2D.new()
	world.y_sort_enabled = true
	add_child_autofree(world)
	var anchor := Node2D.new()
	world.add_child(anchor)
	anchor.position = Vector2(120, 80)
	var impact := Effect.new()
	add_child_autofree(impact)
	impact.configure({ "s19_card": "t_mark" }, anchor.position, 128.0, anchor, false)
	assert_eq(impact.get_parent(), world, "Rear target contact stays behind foreground actors")
	assert_eq(impact.z_index, anchor.z_index, "Ground-depth sorting is not overridden")
	impact.set_process(false)
	var hold := Effect.new()
	add_child_autofree(hold)
	hold.configure({ "s19_card": "t_mark" }, anchor.position, 128.0, anchor, true)
	hold.set_process(false)
	anchor.position += Vector2(20, 10)
	impact.sample(0.2)
	hold.sample(12.0)
	assert_eq(impact.global_position, Vector2(120, 80), "Confirmed impact keeps its contact point")
	assert_eq(hold.global_position, anchor.position, "Status follows the actual target")
	assert_false(hold.closed, "No duration in seconds expires a gameplay status")
	hold.cancel()
	assert_true(hold.closed)


func test_directional_coverage_projection_and_idle_turn_without_advancing_time() -> void:
	assert_eq(Directions.Art.REGIONS.size(), 36, "Four new authored angles for nine clips")
	var projection := IsoProjection.new()
	var directions := {
		"E": Vector2i(1, -1),
		"SE": Vector2i(1, 0),
		"S": Vector2i(1, 1),
		"SW": Vector2i(0, 1),
		"W": Vector2i(-1, 1),
		"NW": Vector2i(-1, 0),
		"N": Vector2i(-1, -1),
		"NE": Vector2i(0, -1),
	}
	var backend := make_backend()
	for direction in directions:
		var projected := projection.grid_to_world(directions[direction])
		assert_eq(AchillesAutoSpriteProfile.screen_facing(projected), direction)
		assert_almost_eq(Directions.axis(direction).dot(projected.normalized()), 1.0, 0.0001)
		backend.play_idle(direction)
		assert_eq(
			backend.get_runtime_state().animation,
			"idle_" + direction,
			"Native rest follows facing immediately",
		)
		var origin: Vector2 = backend.get_vfx_origin()
		assert_almost_eq(
			(origin - Vector2(0, -65) * (PROFILE.display_scale * 214.0 / 108.0)).normalized().dot(
				projected.normalized()
			),
			1.0,
			0.0001,
		)
	for id in Directions.Art.REGIONS:
		var atlas: Dictionary = Directions.Art.REGIONS[id]
		assert_eq(atlas.frames.size(), 12, id)
		assert_almost_eq(
			float(atlas.body_height) * float(atlas.scale),
			330.0,
			.01,
			"Historical crop registration (not the runtime anatomical scale)",
		)
		var texture: Texture2D = Directions.Art.TEXTURES[id]
		for pose in atlas.frames:
			var rect := Rect2(pose.rect[0], pose.rect[1], pose.rect[2], pose.rect[3])
			assert_true(
				Rect2(Vector2.ZERO, texture.get_size()).encloses(rect),
				id + " stays in source texture",
			)
