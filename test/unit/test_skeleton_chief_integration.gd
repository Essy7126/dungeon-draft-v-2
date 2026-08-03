extends GutTest

const Factory = preload("res://test/support/factory.gd")
const UnitViewScript = preload("res://battle/unit_view.gd")
const ChiefVisualScene := preload(
	"res://characters/enemies/skeleton_chief/SkeletonChiefVisual3D.tscn"
)
const ChiefIsoScene := preload(
	"res://characters/enemies/skeleton_chief/SkeletonChiefIsoUnitView.tscn"
)
const ImportValidationScene := preload(
	"res://tests/characters/skeleton_chief/SkeletonChiefImportValidation.tscn"
)
const CHIEF_PATH := "res://data/units/ennemie/skeleton_chief.tres"
const MELEE_PATH := "res://data/units/ennemie/skeleton_melee.tres"
const STRIKE_PATH := "res://data/spells/enemies/skeleton_chief_strike.tres"
const SENTENCE_PATH := "res://data/spells/enemies/scarlet_sentence.tres"
const ACTIVE_ROOMS := [
	"res://data/rooms/first_run_room_01.tres",
	"res://data/rooms/first_run_room_02.tres",
	"res://data/rooms/first_run_room_03.tres",
	"res://data/rooms/first_run_room_04_boss.tres",
]


func test_import_has_valid_skin_geometry_and_all_nonempty_animations() -> void:
	var validation = ImportValidationScene.instantiate()
	add_child_autofree(validation)
	await wait_process_frames(3)
	var report: Dictionary = validation.run_validation()
	assert_true(report.passed, str(report.errors))
	assert_eq(report.bone_count, 24)
	assert_eq(report.root_bones, [&"Hips"])
	assert_eq(report.mesh_triangles, 3354)
	assert_true(report.has_skin)
	assert_eq(report.material_count, 1)
	assert_gte(report.maximum_influences, 5)
	assert_eq(report.animations.size(), 7)
	assert_true(report.empty_animations.is_empty())


func test_visual_maps_seven_actions_and_respects_heavy_pacing() -> void:
	var visual := ChiefVisualScene.instantiate() as SkeletonChiefVisual3D
	add_child_autofree(visual)
	await wait_process_frames(3)
	assert_true(visual is CharacterVisual3D)
	assert_not_null(visual.get_skeleton())
	assert_eq(visual.get_skeleton().get_bone_count(), 24)
	assert_not_null(visual.get_mesh_instance())
	assert_not_null(visual.get_mesh_instance().skin)
	for animation_name in SkeletonChiefVisual3D.IMPORTED_ANIMATIONS:
		assert_true(visual.get_animation_player().has_animation(animation_name), str(animation_name))
	for loop_name in [
		SkeletonChiefVisual3D.ANIM_IDLE,
		SkeletonChiefVisual3D.ANIM_WALK,
		SkeletonChiefVisual3D.ANIM_RUN,
	]:
		assert_eq(visual.get_animation_player().get_animation(loop_name).loop_mode, Animation.LOOP_LINEAR)
	assert_between(visual.get_calibrated_duration(SkeletonChiefVisual3D.ANIM_ATTACK), 1.30, 1.65)
	assert_between(visual.get_calibrated_duration(SkeletonChiefVisual3D.ANIM_HEAVY_ATTACK), 1.55, 1.95)
	assert_between(visual.get_calibrated_duration(SkeletonChiefVisual3D.ANIM_HIT), 0.65, 0.90)
	assert_between(visual.get_calibrated_duration(SkeletonChiefVisual3D.ANIM_DEATH), 1.90, 2.50)
	assert_between(SkeletonChiefVisual3D.ATTACK_IMPACT_NORMALIZED, 0.0, 1.0)
	assert_between(SkeletonChiefVisual3D.HEAVY_IMPACT_NORMALIZED, 0.0, 1.0)
	assert_not_null(visual.get_left_weapon_mount())
	assert_not_null(visual.get_right_weapon_mount())
	assert_null(visual.get_left_hand_item())
	assert_null(visual.get_right_hand_item())


func test_iso_has_required_viewport_four_facings_and_foot_pivot() -> void:
	var iso := ChiefIsoScene.instantiate() as SkeletonChiefIsoUnitView
	add_child_autofree(iso)
	await wait_process_frames(4)
	assert_true(iso is CharacterIsoUnitView)
	assert_eq(iso.viewport_size, Vector2i(768, 512))
	assert_eq(iso.character_viewport.msaa_3d, Viewport.MSAA_4X)
	assert_false(iso.character_viewport.use_taa)
	assert_eq(iso.character_viewport.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_true(iso.character_viewport.transparent_bg)
	assert_true(iso.character_viewport.own_world_3d)
	assert_eq(iso.get_logical_foot_position(), Vector2.ZERO)
	var expected_yaws := [90.0, -90.0, 0.0, 180.0]
	var directions := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	for index in directions.size():
		iso.set_facing(directions[index])
		assert_almost_eq(iso.character_pivot.rotation_degrees.y, expected_yaws[index], 0.001)


func test_primary_attack_releases_exactly_once_and_death_overrides_attack() -> void:
	var iso := ChiefIsoScene.instantiate() as SkeletonChiefIsoUnitView
	add_child_autofree(iso)
	await wait_process_frames(4)
	var release_count := [0]
	iso.cast_release_reached.connect(func(): release_count[0] += 1)
	assert_true(iso.play_basic_attack())
	await get_tree().create_timer(0.90).timeout
	assert_eq(release_count[0], 1)
	await get_tree().create_timer(0.75).timeout
	assert_eq(release_count[0], 1)
	assert_true(iso.play_basic_attack())
	await wait_process_frames(2)
	assert_true(iso.play_death())
	assert_eq(iso.get_skeleton_chief_visual().get_current_animation(), SkeletonChiefVisual3D.ANIM_DEATH)
	assert_false(iso.play_basic_attack())


func test_chief_resource_is_elite_melee_without_hero_economy() -> void:
	var chief := load(CHIEF_PATH) as UnitData
	assert_eq(chief.unit_id, &"skeleton_chief")
	assert_eq(chief.unit_name, "Chef squelette rouge")
	assert_eq(chief.team, 1)
	assert_eq(chief.max_hp, 220)
	assert_eq([chief.max_ap, chief.max_mp, chief.initiative], [6, 2, 6])
	assert_eq([chief.armure, chief.resist_magique], [90.0, 70.0])
	assert_eq([chief.esquive, chief.crit_chance], [0.0, 0.0])
	assert_eq([chief.minimum_range, chief.preferred_range, chief.maximum_range], [1, 1, 1])
	assert_false(chief.keep_distance)
	assert_eq(chief.ai_behavior, 0)
	assert_false(chief.basic_attack_enabled)
	assert_eq(chief.spells.size(), 2)
	assert_eq(chief.spells[0].resource_path, STRIKE_PATH)
	assert_eq(chief.spells[1].resource_path, SENTENCE_PATH)


func test_chief_strike_is_single_data_driven_physical_melee_spell() -> void:
	var spell := load(STRIKE_PATH) as Spell
	assert_eq(spell.spell_id, &"skeleton_chief_strike")
	assert_eq(spell.ap_cost, 4)
	assert_eq(spell.spell_range, 1)
	assert_eq(spell.damage, 32)
	assert_eq(spell.damage_type, Spell.DamageType.PHYSICAL)
	assert_eq(spell.element, Spell.Element.NONE)
	assert_true(spell.can_target_enemy)
	assert_false(spell.can_target_ally)
	assert_false(spell.can_target_free_cell)
	assert_false(spell.can_target_self)
	assert_null(spell.vfx_scene)


func test_tactical_melee_ai_moves_then_uses_chief_strike_without_id_branch() -> void:
	var chief_data := load(CHIEF_PATH) as UnitData
	var field := Factory.make_battlefield(8, 2)
	var chief := Unit.from_data(chief_data)
	var target := Unit.new("Cible du Chef", 0, 100)
	field.grid.place_unit(chief, Vector2i(0, 0))
	field.grid.place_unit(target, Vector2i(3, 0))
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	var approach_plan := ai.decide(chief, [chief, target])
	assert_false(approach_plan.is_empty())
	assert_eq(approach_plan[0].type, "move")
	field.grid.move_unit(Vector2i(0, 0), Vector2i(2, 0))
	var adjacent_plan := ai.decide(chief, [chief, target])
	assert_false(adjacent_plan.is_empty())
	assert_eq(adjacent_plan[0].type, "cast")
	assert_eq(adjacent_plan[0].spell.resource_path, STRIKE_PATH)
	var ai_source := FileAccess.get_file_as_string("res://core/enemy_ai.gd").to_lower()
	assert_false("skeleton_chief" in ai_source)
	assert_false("chef squelette" in ai_source)


func test_chief_strike_applies_damage_exactly_once_through_spell_caster() -> void:
	var field := Factory.make_battlefield(2, 1)
	var chief := Unit.from_data(load(CHIEF_PATH) as UnitData)
	var target := Unit.new("Cible", 0, 100)
	field.grid.place_unit(chief, Vector2i(0, 0))
	field.grid.place_unit(target, Vector2i(1, 0))
	var before := target.current_hp
	var report := field.caster.cast(chief, chief.spells[0], target.grid_pos)
	assert_false(report.get("failed", false))
	assert_eq(before - target.current_hp, 32)


func test_chief_rosters_keep_rooms_one_to_three_and_expand_room_four() -> void:
	for room_index in ACTIVE_ROOMS.size():
		var room = load(ACTIVE_ROOMS[room_index])
		var ids: Array = room.enemies.map(func(data): return data.unit_id)
		if room_index == 1:
			assert_eq(room.enemies.size(), 3, ACTIVE_ROOMS[room_index])
			assert_eq(ids, [&"skeleton_chief", &"skeleton_melee", &"skeleton_ranged"])
		elif room_index == 3:
			assert_eq(room.enemies.size(), 6, ACTIVE_ROOMS[room_index])
			assert_eq(ids.count(&"skeleton_chief"), 3, ACTIVE_ROOMS[room_index])
			assert_eq(ids.count(&"skeleton_snow_centurion"), 2, ACTIVE_ROOMS[room_index])
			assert_eq(ids.count(&"skeleton_ranged"), 1, ACTIVE_ROOMS[room_index])
		else:
			assert_eq(room.enemies.size(), 3, ACTIVE_ROOMS[room_index])
			assert_eq(ids.count(&"skeleton_chief"), 0, ACTIVE_ROOMS[room_index])
			assert_eq(ids.count(&"skeleton_melee"), 2, ACTIVE_ROOMS[room_index])
			assert_eq(ids.count(&"skeleton_ranged"), 1, ACTIVE_ROOMS[room_index])


func test_grid_clear_and_free_keep_visual_root_stable_and_release_viewport() -> void:
	var unit := Unit.from_data(load(CHIEF_PATH) as UnitData)
	var grid := GridData.new(8, 8)
	grid.place_unit(unit, Vector2i(4, 4))
	var view := UnitViewScript.new()
	add_child(view)
	view.position = Vector2(420, 360)
	view.setup(unit)
	await wait_process_frames(4)
	var optional := view.get_optional_visual() as SkeletonChiefIsoUnitView
	var root_before: Vector2 = view.global_position
	var visual_before: Vector2 = optional.global_position
	grid.clear_unit(Vector2i(4, 4))
	assert_null(grid.get_unit(Vector2i(4, 4)))
	assert_eq(unit.grid_pos, Vector2i(-1, -1))
	assert_eq(view.global_position, root_before)
	assert_eq(optional.global_position, visual_before)
	assert_true(optional.play_basic_attack())
	var viewport_ref: WeakRef = weakref(optional.character_viewport)
	var visual_ref: WeakRef = weakref(optional)
	view.queue_free()
	await wait_process_frames(3)
	assert_null(visual_ref.get_ref())
	assert_null(viewport_ref.get_ref())


func test_hit_then_death_and_scene_removal_cancel_the_chief_visual_cleanly() -> void:
	var old_scene := Node2D.new()
	add_child(old_scene)
	var iso := ChiefIsoScene.instantiate() as SkeletonChiefIsoUnitView
	old_scene.add_child(iso)
	await wait_process_frames(4)
	assert_true(iso.play_hit())
	await wait_process_frames(2)
	assert_true(iso.play_death())
	assert_eq(iso.get_skeleton_chief_visual().get_current_animation(), SkeletonChiefVisual3D.ANIM_DEATH)
	var iso_ref: WeakRef = weakref(iso)
	var viewport_ref: WeakRef = weakref(iso.character_viewport)
	old_scene.queue_free()
	await wait_process_frames(3)
	assert_null(iso_ref.get_ref())
	assert_null(viewport_ref.get_ref())


func test_chief_removed_during_attack_leaves_no_visual_or_subviewport() -> void:
	var old_scene := Node2D.new()
	add_child(old_scene)
	var iso := ChiefIsoScene.instantiate() as SkeletonChiefIsoUnitView
	old_scene.add_child(iso)
	await wait_process_frames(4)
	assert_true(iso.play_basic_attack())
	var iso_ref: WeakRef = weakref(iso)
	var viewport_ref: WeakRef = weakref(iso.character_viewport)
	old_scene.queue_free()
	await wait_process_frames(3)
	assert_null(iso_ref.get_ref())
	assert_null(viewport_ref.get_ref())


func test_chief_sources_do_not_add_unsafe_scene_tree_awaits() -> void:
	for path in [
		"res://characters/enemies/skeleton_chief/skeleton_chief_visual_3d.gd",
		"res://characters/enemies/skeleton_chief/skeleton_chief_iso_unit_view.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		assert_false("await get_tree().process_frame" in source, path)
		assert_false("await get_tree().create_timer" in source, path)
