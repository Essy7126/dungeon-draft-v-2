extends GutTest

const Factory = preload("res://test/support/factory.gd")
const UnitViewScript = preload("res://battle/unit_view.gd")
const SnowVisualScene := preload(
	"res://characters/enemies/skeleton_snow_centurion/SnowCenturionVisual3D.tscn"
)
const SnowIsoScene := preload(
	"res://characters/enemies/skeleton_snow_centurion/SnowCenturionIsoUnitView.tscn"
)
const ImportValidationScene := preload(
	"res://tests/characters/skeleton_snow_centurion/SnowCenturionImportValidation.tscn"
)
const SNOW_PATH := "res://data/units/ennemie/skeleton_snow_centurion.tres"
const CHIEF_PATH := "res://data/units/ennemie/skeleton_chief.tres"
const RANGED_PATH := "res://data/units/ennemie/skeleton_ranged.tres"
const FROST_LANCE_PATH := "res://data/spells/enemies/frost_lance.tres"
const ROOM_FOUR_PATH := "res://data/rooms/first_run_room_04_boss.tres"


func test_import_has_audited_skin_geometry_and_seven_animations() -> void:
	var validation := ImportValidationScene.instantiate()
	add_child_autofree(validation)
	await wait_process_frames(3)
	var report: Dictionary = validation.run_validation()
	assert_true(report.passed, str(report.errors))
	assert_eq(report.bone_count, 24)
	assert_eq(report.root_bones, [&"Hips"])
	assert_eq(report.mesh_triangles, 3513)
	assert_true(report.has_skin)
	assert_eq(report.material_count, 1)
	assert_gte(report.maximum_influences, 5)
	assert_lte(report.maximum_influences, 8)
	assert_eq(report.animations.size(), 7)
	assert_true(report.empty_animations.is_empty())


func test_visual_maps_native_actions_and_respects_pacing_contract() -> void:
	var visual := SnowVisualScene.instantiate() as SnowCenturionVisual3D
	add_child_autofree(visual)
	await wait_process_frames(3)
	assert_true(visual is CharacterVisual3D)
	assert_not_null(visual.get_skeleton())
	assert_eq(visual.get_skeleton().get_bone_count(), 24)
	assert_not_null(visual.get_mesh_instance())
	assert_not_null(visual.get_mesh_instance().skin)
	for animation_name in SnowCenturionVisual3D.IMPORTED_ANIMATIONS:
		assert_true(visual.get_animation_player().has_animation(animation_name), str(animation_name))
	for loop_name in [
		SnowCenturionVisual3D.ANIM_IDLE,
		SnowCenturionVisual3D.ANIM_WALK,
		SnowCenturionVisual3D.ANIM_RUN,
	]:
		assert_eq(visual.get_animation_player().get_animation(loop_name).loop_mode, Animation.LOOP_LINEAR)
	assert_between(visual.get_calibrated_duration(SnowCenturionVisual3D.ANIM_ATTACK), 1.40, 1.60)
	assert_between(visual.get_calibrated_duration(SnowCenturionVisual3D.ANIM_HEAVY_ATTACK), 1.65, 1.90)
	assert_between(visual.get_calibrated_duration(SnowCenturionVisual3D.ANIM_HIT), 0.65, 0.75)
	assert_between(visual.get_calibrated_duration(SnowCenturionVisual3D.ANIM_DEATH), 2.15, 2.40)
	assert_almost_eq(SnowCenturionVisual3D.ATTACK_IMPACT_NORMALIZED, 0.244444, 0.000001)
	assert_almost_eq(SnowCenturionVisual3D.HEAVY_IMPACT_NORMALIZED, 0.666667, 0.000001)
	assert_not_null(visual.get_left_weapon_mount())
	assert_not_null(visual.get_right_weapon_mount())
	assert_null(visual.get_left_hand_item())
	assert_null(visual.get_right_hand_item())


func test_iso_uses_one_high_quality_viewport_four_facings_and_foot_pivot() -> void:
	var iso := SnowIsoScene.instantiate() as SnowCenturionIsoUnitView
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


func test_native_hit_is_used_and_death_overrides_combat_actions() -> void:
	var iso := SnowIsoScene.instantiate() as SnowCenturionIsoUnitView
	add_child_autofree(iso)
	await wait_process_frames(4)
	assert_true(iso.play_hit())
	assert_eq(
		iso.get_snow_centurion_visual().get_current_animation(),
		SnowCenturionVisual3D.ANIM_HIT
	)
	assert_true(iso.play_death())
	assert_eq(
		iso.get_snow_centurion_visual().get_current_animation(),
		SnowCenturionVisual3D.ANIM_DEATH
	)
	assert_false(iso.play_hit())
	assert_false(iso.play_basic_attack())


func test_native_hit_finishes_and_returns_to_idle() -> void:
	var iso := SnowIsoScene.instantiate() as SnowCenturionIsoUnitView
	add_child_autofree(iso)
	await wait_process_frames(4)
	var finished_count := [0]
	iso.hit_reaction_finished.connect(func(): finished_count[0] += 1)
	assert_true(iso.play_hit())
	await get_tree().create_timer(0.80).timeout
	assert_eq(finished_count[0], 1)
	assert_eq(
		iso.get_snow_centurion_visual().get_current_animation(),
		SnowCenturionVisual3D.ANIM_IDLE
	)


func test_attack_release_marker_emits_once_at_source_impact() -> void:
	var iso := SnowIsoScene.instantiate() as SnowCenturionIsoUnitView
	add_child_autofree(iso)
	await wait_process_frames(4)
	var release_count := [0]
	iso.cast_release_reached.connect(func(): release_count[0] += 1)
	assert_true(iso.play_basic_attack())
	var visual := iso.get_snow_centurion_visual()
	var player := visual.get_animation_player()
	var animation := player.get_animation(SnowCenturionVisual3D.ANIM_ATTACK)
	player.seek(animation.length * SnowCenturionVisual3D.ATTACK_IMPACT_NORMALIZED + 0.001, true)
	visual._process(0.0)
	visual._process(0.0)
	assert_eq(release_count[0], 1)


func test_unit_data_matches_the_tactical_commander_specification() -> void:
	var snow := load(SNOW_PATH) as UnitData
	assert_eq(snow.unit_id, &"skeleton_snow_centurion")
	assert_eq(snow.unit_name, "Centurion squelette de glace")
	assert_eq(snow.team, 1)
	assert_eq(snow.max_hp, 150)
	assert_eq([snow.max_ap, snow.max_mp, snow.initiative], [6, 3, 16])
	assert_eq([snow.armure, snow.resist_magique], [15.0, 80.0])
	assert_eq([snow.esquive, snow.crit_chance], [0.0, 0.0])
	assert_eq(snow.resistances[Spell.Element.ICE], 0.5)
	assert_eq(snow.resistances[Spell.Element.FIRE], -0.25)
	assert_false(snow.basic_attack_enabled)
	assert_true(snow.keep_distance)
	assert_eq([snow.minimum_range, snow.preferred_range, snow.maximum_range], [2, 5, 6])
	assert_eq(snow.spells.size(), 5)
	assert_eq(snow.spells.map(func(spell): return spell.spell_id), [
		&"centurion_mark",
		&"frost_lance",
		&"frost_aegis",
		&"call_bones",
		&"raise_chief",
	])


func test_tactical_ai_prioritizes_missing_normal_reinforcements_without_id_branch() -> void:
	var field := Factory.make_battlefield(8, 2)
	var snow := Unit.from_data(load(SNOW_PATH) as UnitData)
	var target := Unit.new("Cible du Centurion", 0, 100)
	field.grid.place_unit(snow, Vector2i(0, 0))
	field.grid.place_unit(target, Vector2i(3, 0))
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	var plan := ai.decide(snow, [snow, target])
	assert_false(plan.is_empty())
	assert_eq(plan[0].type, "cast")
	assert_eq(plan[0].spell.spell_id, &"call_bones")
	var ai_source := FileAccess.get_file_as_string("res://core/enemy_ai.gd").to_lower()
	assert_false("skeleton_snow_centurion" in ai_source)


func test_room_four_has_exact_requested_roster_and_distinct_valid_spawns() -> void:
	var room = load(ROOM_FOUR_PATH)
	assert_not_null(room)
	var ids: Array = room.enemies.map(func(data): return data.unit_id)
	assert_eq(ids.size(), 6)
	assert_eq(ids.count(&"skeleton_chief"), 3)
	assert_eq(ids.count(&"skeleton_snow_centurion"), 2)
	assert_eq(ids.count(&"skeleton_ranged"), 1)
	assert_eq(room.enemy_spawn_zone.size(), 6)
	var unique_cells := {}
	var grid := GridData.new(20, 14)
	for cell in room.enemy_spawn_zone:
		assert_true(grid.is_valid(cell), "%s must be inside the room grid" % cell)
		assert_false(unique_cells.has(cell), "%s must be unique" % cell)
		unique_cells[cell] = true


func test_grid_clear_keeps_snow_visual_roots_stable_until_scene_cleanup() -> void:
	var unit := Unit.from_data(load(SNOW_PATH) as UnitData)
	var grid := GridData.new(8, 8)
	grid.place_unit(unit, Vector2i(4, 4))
	var view := UnitViewScript.new()
	add_child(view)
	view.position = Vector2(420, 360)
	view.setup(unit)
	await wait_process_frames(4)
	var optional := view.get_optional_visual() as SnowCenturionIsoUnitView
	var root_before: Vector2 = view.global_position
	var visual_before: Vector2 = optional.global_position
	grid.clear_unit(Vector2i(4, 4))
	assert_null(grid.get_unit(Vector2i(4, 4)))
	assert_eq(unit.grid_pos, Vector2i(-1, -1))
	assert_eq(view.global_position, root_before)
	assert_eq(optional.global_position, visual_before)
	var viewport_ref: WeakRef = weakref(optional.character_viewport)
	view.queue_free()
	await wait_process_frames(3)
	assert_null(viewport_ref.get_ref())


func test_scene_removal_cleans_viewport_during_hit_heavy_and_death() -> void:
	var heavy_spell := load(FROST_LANCE_PATH) as Spell
	for mode in [&"hit", &"heavy", &"death"]:
		var owner := Node2D.new()
		add_child(owner)
		var iso := SnowIsoScene.instantiate() as SnowCenturionIsoUnitView
		owner.add_child(iso)
		await wait_process_frames(4)
		match mode:
			&"hit":
				assert_true(iso.play_hit())
			&"heavy":
				assert_true(iso.play_spell_action(heavy_spell))
			&"death":
				assert_true(iso.play_death())
		var iso_ref: WeakRef = weakref(iso)
		var viewport_ref: WeakRef = weakref(iso.character_viewport)
		owner.queue_free()
		await wait_process_frames(3)
		assert_null(iso_ref.get_ref(), str(mode))
		assert_null(viewport_ref.get_ref(), str(mode))


func test_snow_sources_do_not_add_unsafe_scene_tree_awaits() -> void:
	for path in [
		"res://characters/enemies/skeleton_snow_centurion/snow_centurion_visual_3d.gd",
		"res://characters/enemies/skeleton_snow_centurion/snow_centurion_iso_unit_view.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		assert_false("await get_tree().process_frame" in source, path)
		assert_false("await get_tree().create_timer" in source, path)
