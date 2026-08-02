extends GutTest

const ELF_DATA_PATH := "res://data/units/alliés/elfe.tres"
const PRECISE_SHOT_PATH := "res://data/characters/elf/spells/precise_shot.tres"
const OTHER_SPELL_PATH := "res://data/characters/elf/spells/fireball.tres"
const ELF_ISO_SCENE := preload("res://characters/elf/ElfIsoUnitView.tscn")
const PROJECTILE_SCENE := preload(
	"res://asset/sorts/elfe_arc_magique/elf_magic_arrow_projectile.tscn"
)

var view: ElfIsoUnitView


func before_each() -> void:
	view = ELF_ISO_SCENE.instantiate() as ElfIsoUnitView
	add_child_autofree(view)
	await wait_process_frames(2)


func test_production_player_contains_exact_imported_bow_clip() -> void:
	var visual := view.get_elf_visual() as ElfVisual3D
	var player := visual.get_animation_player()
	assert_not_null(player)
	assert_true(player.has_animation(ElfVisual3D.ANIM_BOW_SHOT))
	var animation := player.get_animation(ElfVisual3D.ANIM_BOW_SHOT)
	assert_almost_eq(animation.length, 0.7, 0.0001)
	assert_eq(animation.get_track_count(), 25)
	for track_index in animation.get_track_count():
		assert_true(
			str(animation.track_get_path(track_index)).begins_with(
				"EXP_Elf_Rig/Skeleton3D:"
			)
		)


func test_precise_shot_selects_bow_once_and_other_spell_keeps_normal_cast() -> void:
	var precise := load(PRECISE_SHOT_PATH) as Spell
	var other := load(OTHER_SPELL_PATH) as Spell
	var visual := view.get_elf_visual() as ElfVisual3D
	assert_true(view.play_spell_action(precise))
	assert_eq(visual.get_current_animation(), ElfVisual3D.ANIM_BOW_SHOT)
	assert_true(view.has_active_magic_bow())
	var first_bow := view.get_active_magic_bow()
	assert_false(view.play_spell_action(precise))
	assert_same(view.get_active_magic_bow(), first_bow)
	view.cancel_spell_action()
	await wait_process_frames(1)
	assert_false(view.has_active_magic_bow())
	assert_true(view.play_spell_action(other))
	assert_eq(visual.get_current_animation(), ElfVisual3D.ANIM_CAST_FULL)
	assert_false(view.has_active_magic_bow())


func test_magic_bow_tracks_projected_hand_midpoint_with_offset() -> void:
	var precise := load(PRECISE_SHOT_PATH) as Spell
	view.magic_bow_position_offset = Vector2(7.0, -5.0)
	assert_true(view.play_spell_action(precise))
	view._process(0.0)
	var expected := (
		(view.get_left_hand_effect_origin() + view.get_right_hand_effect_origin()) * 0.5
		+ view.magic_bow_position_offset
	)
	assert_almost_eq(
		view.get_active_magic_bow().position.distance_to(expected),
		0.0,
		0.001
	)


func test_release_point_is_cast_origin_only_while_bow_is_active() -> void:
	var precise := load(PRECISE_SHOT_PATH) as Spell
	assert_true(view.play_spell_action(precise))
	view._process(0.0)
	var bow := view.get_active_magic_bow()
	var release_point := bow.get_node("BowSprite/ReleasePoint") as Node2D
	assert_almost_eq(
		view.get_default_cast_effect_origin().distance_to(
			view.to_local(release_point.global_position)
		),
		0.0,
		0.001
	)
	view.cancel_spell_action()
	await wait_process_frames(1)
	assert_almost_eq(
		view.get_default_cast_effect_origin().distance_to(
			view.get_right_hand_effect_origin()
		),
		0.0,
		0.001
	)


func test_bow_release_is_driven_by_player_position_and_emitted_once() -> void:
	var visual := view.get_elf_visual() as ElfVisual3D
	var player := visual.get_animation_player()
	var release := {"count": 0}
	visual.cast_release_reached.connect(func() -> void: release["count"] += 1)
	assert_true(visual.play_bow_shot())
	var animation := player.get_animation(ElfVisual3D.ANIM_BOW_SHOT)
	player.advance(0.0)
	player.seek(animation.length * 0.59, true)
	visual._process(0.0)
	assert_eq(release["count"], 0)
	player.seek(animation.length * 0.60, true)
	visual._process(0.0)
	assert_eq(release["count"], 1)
	player.seek(animation.length * 0.95, true)
	visual._process(0.0)
	assert_eq(release["count"], 1)


func test_death_and_cancel_remove_the_magic_bow() -> void:
	var precise := load(PRECISE_SHOT_PATH) as Spell
	assert_true(view.play_spell_action(precise))
	assert_true(view.has_active_magic_bow())
	assert_true(view.play_death())
	assert_false(view.has_active_magic_bow())
	await wait_process_frames(1)
	assert_eq(
		view.find_children("ElfMagicBowCharge", "Node2D", true, false).size(),
		0
	)


func test_bow_shot_finishes_back_in_idle_without_orphan() -> void:
	var precise := load(PRECISE_SHOT_PATH) as Spell
	var visual := view.get_elf_visual() as ElfVisual3D
	assert_true(view.play_spell_action(precise))
	await wait_seconds(0.80)
	assert_eq(visual.get_current_animation(), ElfVisual3D.ANIM_IDLE)
	assert_false(view.has_active_magic_bow())


func test_unit_view_forwards_spell_and_waits_for_bow_release() -> void:
	var unit := Unit.from_data(load(ELF_DATA_PATH) as UnitData)
	var unit_view = load("res://battle/unit_view.tscn").instantiate()
	add_child_autofree(unit_view)
	unit_view.setup(unit)
	await wait_process_frames(2)
	var iso := unit_view.get_optional_visual() as ElfIsoUnitView
	var visual := iso.get_elf_visual() as ElfVisual3D
	visual.bow_shot_release_normalized_time = 0.20
	var ready: bool = await unit_view.prepare_spell_visual(
		unit.grid_pos + Vector2i.RIGHT,
		load(PRECISE_SHOT_PATH) as Spell
	)
	assert_true(ready)
	assert_eq(visual.get_current_animation(), ElfVisual3D.ANIM_BOW_SHOT)
	assert_true(iso.has_active_magic_bow())


func test_precise_shot_vfx_timing_matches_projectile_scene() -> void:
	var precise := load(PRECISE_SHOT_PATH) as Spell
	var projectile = PROJECTILE_SCENE.instantiate()
	assert_eq(precise.vfx_scene.resource_path, PROJECTILE_SCENE.resource_path)
	assert_eq(precise.vfx_placement, Spell.VfxPlacement.FROM_CASTER_TO_TARGET)
	assert_almost_eq(
		precise.impact_delay_seconds,
		float(projectile.get("travel_duration")),
		0.0001
	)
	projectile.free()


func test_projectile_initialiser_travels_impacts_and_leaves_no_orphan() -> void:
	var container := Node2D.new()
	add_child_autofree(container)
	var projectile := PROJECTILE_SCENE.instantiate() as Node2D
	container.add_child(projectile)
	projectile.set("travel_duration", 0.01)
	var start := Vector2(10.0, 20.0)
	var target := Vector2(50.0, 60.0)
	projectile.initialiser(start, target)
	assert_eq(projectile.global_position, start)
	await wait_seconds(0.05)
	assert_false(is_instance_valid(projectile))
	assert_eq(container.get_child_count(), 1)
	assert_eq(container.get_child(0).name, &"ElfMagicArrowImpact")
	await wait_seconds(0.80)
	assert_eq(container.get_child_count(), 0)
