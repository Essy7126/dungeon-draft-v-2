extends GutTest

const Backend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const Catalog := preload("res://characters/achilles/2d/passe_rive_s19_catalog.gd")
const Effect := preload("res://vfx/class_cards/passe_rive_s19_effect.gd")
const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
const Cards := preload("res://core/expedition/class_card_catalog.gd")


func make_backend() -> Node2D:
	var backend := Backend.new()
	add_child_autofree(backend)
	assert_true(backend.configure(PROFILE))
	backend.set_backend_active(true)
	backend.set_cards_mode(true)
	backend.set_process(false)
	return backend


func test_release_pose_once_even_when_one_frame_crosses_the_whole_action() -> void:
	var backend := make_backend()
	var releases: Array = []
	var finishes: Array = []
	backend.action_release_reached.connect(func(): releases.append(backend.get_runtime_state()))
	backend.action_finished.connect(func(id): finishes.append(id))
	for id in Catalog.Data.CARDS:
		for direction in ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]:
			releases.clear()
			finishes.clear()
			var card: Dictionary = Catalog.Data.CARDS[id]
			assert_true(backend.play_action(&"cast", direction, {"spell_id": "class_" + id}))
			backend.advance_simulation(4.0)
			assert_eq(releases.size(), 1, id + " one release")
			assert_eq(finishes.size(), 1, id + " one recovery")
			assert_eq(releases[0].animation, card.clip)
			assert_eq(releases[0].frame, int(card.confirm_frame), id + " exact release drawing")
			assert_eq(releases[0].mirrored, direction in ["W", "NW", "SW"])
			assert_eq(backend.body.current_clip, "PR_IDLE")
			backend.advance_simulation(4.0)
			assert_eq(releases.size(), 1)


func test_cancellation_death_and_distance_driven_walk() -> void:
	var backend := make_backend()
	var releases: Array = []
	backend.action_release_reached.connect(func(): releases.append(true))
	backend.play_action(&"cast", "E", {"spell_id": "class_r_shot"})
	backend.advance_simulation(0.3)
	backend.cancel_action()
	backend.play_idle("E")
	backend.advance_simulation(2.0)
	assert_true(releases.is_empty(), "Interrupted anticipation cannot resolve a hit")
	assert_true(backend.play_move("W", true))
	backend.advance_ground_distance(22.0)
	assert_eq(backend.body.current_clip, "PR_WALK")
	var pose: int = backend.body.current_frame
	backend.advance_simulation(3.0)
	assert_eq(backend.body.current_frame, pose, "No sliding cycle while ground travel is stopped")
	backend.play_idle("E")
	backend.play_action(&"cast", "E", {"spell_id": "class_a_dagger"})
	backend.play_death("E")
	backend.advance_simulation(3.0)
	assert_true(releases.is_empty(), "Death cancels the release")
	assert_eq(backend.body.modulate.a, 0.0)


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


func test_target_effects_and_status_hold_have_distinct_lifetimes() -> void:
	var anchor := Node2D.new()
	add_child_autofree(anchor)
	anchor.position = Vector2(120, 80)
	var impact := Effect.new()
	add_child_autofree(impact)
	impact.configure({"s19_card": "t_mark"}, anchor.position, 128.0, anchor, false)
	impact.set_process(false)
	var hold := Effect.new()
	add_child_autofree(hold)
	hold.configure({"s19_card": "t_mark"}, anchor.position, 128.0, anchor, true)
	hold.set_process(false)
	anchor.position += Vector2(20, 10)
	impact.sample(0.2)
	hold.sample(12.0)
	assert_eq(impact.global_position, Vector2(120, 80), "Confirmed impact keeps its contact point")
	assert_eq(hold.global_position, anchor.position, "Status follows the actual target")
	assert_false(hold.closed, "No duration in seconds expires a gameplay status")
	hold.cancel()
	assert_true(hold.closed)
