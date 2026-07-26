extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")
const MAGE_GLACE_SCENE := preload(
	"res://characters/mage_glace/MageGlaceUnitView2D.tscn"
)
const MAGE_GLACE_DATA_PATH := "res://characters/mage_glace/mage_glace.tres"
const PARTY_SCREEN_SCENE := preload("res://ui/party/PartyPresentationScreen.tscn")
const RUN_PATH := "res://data/runs/fixed_trio_prototype_run.tres"
const FIRST_ROOM_PATH := "res://data/rooms/bible/le_gue.tres"
const PARTY := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	MAGE_GLACE_DATA_PATH,
]
const REQUIRED_ANIMATIONS := [&"idle", &"walk", &"run", &"cast", &"hit", &"death"]

var view: MageGlaceUnitView2D


func before_each() -> void:
	view = MAGE_GLACE_SCENE.instantiate() as MageGlaceUnitView2D
	add_child_autofree(view)
	await wait_process_frames(2)


func test_scene_instantiates_with_required_animation_contract() -> void:
	assert_not_null(view)
	assert_true(view is Node2D)
	var frames := view.animated_sprite.sprite_frames
	for animation_name in REQUIRED_ANIMATIONS:
		assert_true(frames.has_animation(animation_name))
	for looped in [&"idle", &"walk", &"run"]:
		assert_true(frames.get_animation_loop(looped))
	for one_shot in [&"cast", &"hit", &"death"]:
		assert_false(frames.get_animation_loop(one_shot))
	assert_eq(frames.get_animation_speed(&"idle"), 6.0)
	assert_eq(frames.get_animation_speed(&"walk"), 10.0)
	assert_eq(frames.get_animation_speed(&"run"), 13.0)
	assert_eq(frames.get_animation_speed(&"cast"), 10.0)
	assert_eq(frames.get_animation_speed(&"hit"), 12.0)
	assert_eq(frames.get_animation_speed(&"death"), 8.0)


func test_cast_release_and_completion_are_each_emitted_once() -> void:
	var releases := {"count": 0}
	var completions := {"count": 0}
	view.cast_release_reached.connect(func(): releases["count"] += 1)
	view.animation_finished.connect(
		func(action): completions["count"] += 1 if action == &"cast" else 0
	)
	assert_true(view.play_cast())
	view.animated_sprite.frame = MageGlaceUnitView2D.CAST_RELEASE_FRAME
	view._on_frame_changed()
	view._on_frame_changed()
	assert_eq(releases["count"], 1)
	view._on_sprite_animation_finished()
	assert_eq(releases["count"], 1)
	assert_eq(completions["count"], 1)
	assert_eq(view.get_current_animation(), &"idle")


func test_hit_and_death_completion_signals_are_guarded_and_terminal() -> void:
	var hit_finishes := {"count": 0}
	var death_finishes := {"count": 0}
	view.hit_reaction_finished.connect(func(): hit_finishes["count"] += 1)
	view.death_animation_finished.connect(func(): death_finishes["count"] += 1)
	assert_true(view.play_hit())
	view._on_sprite_animation_finished()
	view._on_sprite_animation_finished()
	assert_eq(hit_finishes["count"], 1)
	assert_eq(view.get_current_animation(), &"idle")
	assert_true(view.play_death())
	view._on_sprite_animation_finished()
	view._on_sprite_animation_finished()
	assert_eq(death_finishes["count"], 1)
	assert_eq(view.get_current_animation(), &"death")
	assert_eq(
		view.animated_sprite.frame,
		view.animated_sprite.sprite_frames.get_frame_count(&"death") - 1,
	)
	assert_false(view.play_idle())


func test_logical_pivot_origins_facing_and_popup_anchor_are_valid() -> void:
	assert_eq(view.get_logical_foot_position(), Vector2.ZERO)
	assert_gt(view.get_left_hand_effect_origin().distance_to(Vector2.ZERO), 1.0)
	assert_gt(view.get_right_hand_effect_origin().distance_to(Vector2.ZERO), 1.0)
	assert_gt(view.get_default_cast_effect_origin().distance_to(Vector2.ZERO), 1.0)
	assert_lt(view.get_popup_anchor().y, -52.0)
	view.set_facing(Vector2i.LEFT)
	assert_true(view.animated_sprite.flip_h)
	view.set_facing(Vector2i.UP)
	assert_true(view.animated_sprite.flip_h)
	view.set_facing(Vector2i.RIGHT)
	assert_false(view.animated_sprite.flip_h)
	view.set_facing(Vector2i.DOWN)
	assert_false(view.animated_sprite.flip_h)


func test_unit_data_uses_distinct_identity_visual_portrait_and_stable_mage_kit() -> void:
	var data := load(MAGE_GLACE_DATA_PATH) as UnitData
	assert_not_null(data)
	assert_eq(data.unit_id, &"mage_glace_test")
	assert_eq(data.unit_name, "Mage de glace")
	assert_eq(data.team, 0)
	assert_eq(data.visual_scene.resource_path, MAGE_GLACE_SCENE.resource_path)
	assert_not_null(data.portrait)
	assert_eq(
		data.sprite_frames.resource_path,
		"res://characters/mage_glace/mage_glace_sprite_frames.tres",
	)
	assert_false(data.basic_attack_enabled)
	assert_eq(data.spells.size(), 4)
	assert_true(data.spells.any(
		func(spell): return spell.get_effective_spell_id() == &"mage_ice_wall"
	))
	assert_eq(
		data.disciplines.map(func(discipline): return discipline.discipline_id),
		[&"mage_fire", &"mage_ice", &"mage_lightning", &"mage_earth"],
	)


func test_fixed_run_screen_contains_ice_mage_in_third_position() -> void:
	var screen := PARTY_SCREEN_SCENE.instantiate() as PartyPresentationScreen
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_eq(screen.run_data.resource_path, RUN_PATH)
	assert_eq(
		screen.party_members.map(func(member): return member.unit_id),
		[&"elf", &"mage", &"mage_glace_test"],
	)


func test_first_room_can_instantiate_three_unique_heroes_without_collision() -> void:
	var manager = GameManagerScript.new()
	assert_true(manager._prepare_preconfigured_run(
		load(RUN_PATH) as RunData,
		PARTY,
	))
	var heroes: Array[Unit] = manager.get_ordered_heroes()
	var room := load(FIRST_ROOM_PATH) as RoomData
	assert_eq(heroes.size(), 3)
	assert_gte(room.hero_spawn_zone.size(), heroes.size())
	var grid := GridData.new(10, 8)
	var views: Array[Node] = []
	for index in heroes.size():
		var cell: Vector2i = room.hero_spawn_zone[index]
		assert_true(grid.is_valid(cell))
		assert_true(grid.is_walkable(cell))
		assert_false(grid.has_unit(cell))
		grid.set_unit(cell, heroes[index])
		heroes[index].grid_pos = cell
		var unit_view = load("res://battle/unit_view.tscn").instantiate()
		add_child_autofree(unit_view)
		unit_view.setup(heroes[index])
		views.append(unit_view)
	await wait_process_frames(2)
	assert_eq(views.size(), 3)
	assert_true(views[2].get_optional_visual() is MageGlaceUnitView2D)
	assert_eq(
		heroes.map(func(hero): return hero.grid_pos),
		[Vector2i(9, 7), Vector2i(8, 7), Vector2i(9, 6)],
	)
	manager.cleanup_run_state()
	manager.free()
