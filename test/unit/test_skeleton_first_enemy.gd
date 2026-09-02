extends GutTest

const Factory = preload("res://test/support/factory.gd")
const SkeletonVisualScene := preload(
	"res://characters/enemies/skeleton/SkeletonVisual3D.tscn"
)
const SkeletonMeleeScene := preload(
	"res://characters/enemies/skeleton/SkeletonMeleeIsoUnitView.tscn"
)
const SkeletonRangedScene := preload(
	"res://characters/enemies/skeleton/SkeletonRangedIsoUnitView.tscn"
)
const ProjectileScene := preload(
	"res://battle/vfx/skeleton_ranged_projectile_vfx.tscn"
)
const ImportValidationScene := preload(
	"res://tests/characters/skeleton/SkeletonImportValidation.tscn"
)
const MovementTiming = preload("res://characters/character_movement_timing.gd")
const UnitViewScript = preload("res://battle/unit_view.gd")

const MELEE_PATH := "res://data/units/ennemie/skeleton_melee.tres"
const RANGED_PATH := "res://data/units/ennemie/skeleton_ranged.tres"
const ACTIVE_ROOMS := [
	"res://data/rooms/first_run_room_01.tres",
	"res://data/rooms/first_run_room_02.tres",
	"res://data/rooms/first_run_room_03.tres",
	"res://data/rooms/first_run_room_04_boss.tres",
]


class AttackVisualSpy extends Node2D:
	var spell_prepare_count := 0
	var attack_prepare_count := 0
	var attack_release_count := 0
	var recovery_count := 0
	var cancel_count := 0
	var action_pending := false
	var attack_release_hook := Callable()

	func prepare_spell_visual(_cell: Vector2i, _spell: Spell) -> bool:
		spell_prepare_count += 1
		action_pending = true
		await get_tree().process_frame
		return true

	func prepare_basic_attack_visual(_cell: Vector2i) -> bool:
		attack_prepare_count += 1
		action_pending = true
		await get_tree().process_frame
		if attack_release_hook.is_valid():
			attack_release_hook.call()
		attack_release_count += 1
		return true

	func has_optional_visual() -> bool:
		return true

	func wait_for_action_visual_finished(_timeout_msec: int = 8000) -> void:
		recovery_count += 1
		await get_tree().process_frame
		action_pending = false

	func cancel_pending_visual_actions() -> void:
		cancel_count += 1
		action_pending = false

	func is_action_visual_pending() -> bool:
		return action_pending


class EnemyRunnerBattleSpy extends Node:
	var spell_caster: SpellCaster
	var grid: GridData
	var grid_view := Node2D.new()
	var _unit_views := {}
	var _battle_over := false
	var _outcome_deferral_depth := 0
	var _action_sequence := 0

	func _init() -> void:
		add_child(grid_view)

	func _begin_outcome_deferral() -> void:
		_outcome_deferral_depth += 1

	func _finish_outcome_deferral() -> bool:
		_outcome_deferral_depth = maxi(0, _outcome_deferral_depth - 1)
		return false

	func _next_action_id(kind: StringName) -> StringName:
		_action_sequence += 1
		return StringName("%s_%d" % [kind, _action_sequence])

	func _animate_attack_to_impact(_unit: Unit, _target: Unit) -> void:
		await get_tree().process_frame

	func _animate_attack_recovery(_unit: Unit) -> void:
		await get_tree().process_frame


func test_single_visual_contains_the_seven_production_animations() -> void:
	var visual := SkeletonVisualScene.instantiate() as SkeletonVisual3D
	add_child_autofree(visual)
	await wait_process_frames(3)
	assert_true(visual is CharacterVisual3D)
	assert_not_null(visual.get_animation_player())
	assert_not_null(visual.get_skeleton())
	assert_eq(visual.get_skeleton().get_bone_count(), 24)
	for animation_name in SkeletonVisual3D.IMPORTED_ANIMATIONS:
		assert_true(
			visual.get_animation_player().has_animation(animation_name),
			str(animation_name)
		)
	assert_eq(SkeletonVisual3D.IMPORTED_ANIMATIONS.size(), 7)
	assert_eq(
		visual.get_animation_player().get_animation(SkeletonVisual3D.ANIM_IDLE).loop_mode,
		Animation.LOOP_LINEAR
	)
	assert_eq(
		visual.get_animation_player().get_animation(SkeletonVisual3D.ANIM_WALK).loop_mode,
		Animation.LOOP_LINEAR
	)
	assert_eq(
		visual.get_animation_player().get_animation(SkeletonVisual3D.ANIM_RUN).loop_mode,
		Animation.LOOP_LINEAR
	)
	assert_not_null(visual.get_mesh_instance())
	assert_not_null(visual.get_mesh_instance().skin)


func test_isolated_import_validation_reports_expected_geometry() -> void:
	var validation: Node = ImportValidationScene.instantiate()
	add_child_autofree(validation)
	await wait_process_frames(3)
	var report: Dictionary = validation.run_validation()
	assert_true(report.passed, str(report.errors))
	assert_eq(report.bone_count, 24)
	assert_eq(report.mesh_triangles, 4054)
	assert_true(report.has_skin)
	assert_eq(report.animations.size(), 7)


func test_profiles_share_model_and_select_distinct_combat_actions() -> void:
	var melee := SkeletonMeleeScene.instantiate() as SkeletonIsoUnitView
	var ranged := SkeletonRangedScene.instantiate() as SkeletonIsoUnitView
	add_child_autofree(melee)
	add_child_autofree(ranged)
	await wait_process_frames(3)
	assert_eq(melee.combat_style, SkeletonVisual3D.CombatStyle.MELEE)
	assert_eq(ranged.combat_style, SkeletonVisual3D.CombatStyle.RANGED)
	assert_eq(melee.get_skeleton_visual().get_attack_animation(), SkeletonVisual3D.ANIM_MELEE)
	assert_eq(ranged.get_skeleton_visual().get_attack_animation(), SkeletonVisual3D.ANIM_RANGED)
	assert_not_null(melee.get_skeleton_visual().get_left_weapon_mount())
	assert_not_null(melee.get_skeleton_visual().get_right_weapon_mount())
	assert_null(melee.get_skeleton_visual().get_left_hand_item())
	assert_null(melee.get_skeleton_visual().get_right_hand_item())


func test_attack_durations_and_release_markers_match_pacing_contract() -> void:
	var visual := SkeletonVisualScene.instantiate() as SkeletonVisual3D
	add_child_autofree(visual)
	await wait_process_frames(3)
	var player := visual.get_animation_player()
	var melee_duration := (
		player.get_animation(SkeletonVisual3D.ANIM_MELEE).length
		/ SkeletonVisual3D.MELEE_SPEED
	)
	var ranged_duration := (
		player.get_animation(SkeletonVisual3D.ANIM_RANGED).length
		/ SkeletonVisual3D.RANGED_SPEED
	)
	assert_between(melee_duration, 1.10, 1.40)
	assert_between(ranged_duration, 1.25, 1.60)
	assert_between(SkeletonVisual3D.MELEE_IMPACT_NORMALIZED, 0.0, 1.0)
	assert_between(SkeletonVisual3D.RANGED_RELEASE_NORMALIZED, 0.0, 1.0)


func test_enemy_resources_are_generic_and_keep_expected_ranges() -> void:
	var melee := load(MELEE_PATH) as UnitData
	var ranged := load(RANGED_PATH) as UnitData
	assert_eq(melee.unit_id, &"skeleton_melee")
	assert_eq(ranged.unit_id, &"skeleton_ranged")
	assert_eq([melee.minimum_range, melee.maximum_range], [1, 1])
	assert_false(melee.keep_distance)
	assert_false(melee.basic_attack_enabled)
	assert_eq(melee.max_hp, 72)
	assert_eq([melee.max_ap, melee.max_mp, melee.initiative], [4, 5, 12])
	assert_eq([melee.armure, melee.resist_magique], [0.0, 0.0])
	assert_eq(melee.spells.size(), 1)
	assert_eq(melee.spells[0].spell_id, &"skeleton_bone_blade")
	assert_eq(melee.spells[0].damage, 18)
	assert_eq([ranged.minimum_range, ranged.preferred_range, ranged.maximum_range], [3, 6, 6])
	assert_true(ranged.keep_distance)
	assert_false(ranged.basic_attack_enabled)
	assert_eq(ranged.spells.size(), 1)
	assert_eq(ranged.spells[0].spell_range, 6)
	assert_true(ranged.spells[0].needs_line_of_sight)
	assert_eq(ranged.spells[0].damage_type, Spell.DamageType.PHYSICAL)
	assert_not_null(ranged.spells[0].vfx_scene)


func test_generic_ai_uses_adjacency_for_melee_and_range_six_for_ranged() -> void:
	var melee_field := Factory.make_battlefield(8, 3)
	var melee := Unit.from_data(load(MELEE_PATH) as UnitData)
	var melee_target := Unit.new("Cible melee", 0, 100)
	melee_field.grid.place_unit(melee, Vector2i(0, 1))
	melee_field.grid.place_unit(melee_target, Vector2i(3, 1))
	var melee_ai := EnemyAI.new(
		melee_field.grid,
		melee_field.pathfinder,
		melee_field.caster
	)
	var melee_plan := melee_ai.decide(melee, [melee, melee_target])
	assert_false(melee_plan.is_empty())
	assert_eq(melee_plan[0].type, "move")

	var ranged_field := Factory.make_battlefield(8, 3)
	var ranged := Unit.from_data(load(RANGED_PATH) as UnitData)
	var ranged_target := Unit.new("Cible distance", 0, 100)
	ranged_field.grid.place_unit(ranged, Vector2i(0, 1))
	ranged_field.grid.place_unit(ranged_target, Vector2i(6, 1))
	var ranged_ai := EnemyAI.new(
		ranged_field.grid,
		ranged_field.pathfinder,
		ranged_field.caster
	)
	var ranged_plan := ranged_ai.decide(ranged, [ranged, ranged_target])
	assert_false(ranged_plan.is_empty())
	assert_eq(ranged_plan[0].type, "cast")
	assert_eq(ranged_plan[0].cell, ranged_target.grid_pos)


func test_ranged_ai_respects_blocked_line_of_sight_without_name_branching() -> void:
	var field := Factory.make_battlefield(8, 3)
	var ranged := Unit.from_data(load(RANGED_PATH) as UnitData)
	var target := Unit.new("Cible masquee", 0, 100)
	field.grid.place_unit(ranged, Vector2i(0, 1))
	field.grid.place_unit(target, Vector2i(6, 1))
	field.grid.set_type(Vector2i(3, 1), GridData.CellType.WALL)
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	var plan := ai.decide(ranged, [ranged, target])
	assert_true(plan.is_empty() or plan[0].type != "cast")
	var ai_source := FileAccess.get_file_as_string("res://core/enemy_ai.gd").to_lower()
	assert_false("squelette" in ai_source)
	assert_false("skeleton" in ai_source)


func test_active_run_rooms_keep_their_expected_enemy_rosters() -> void:
	var expected := [
		{&"skeleton_melee": 4},
		{&"skeleton_melee": 3, &"skeleton_chief": 1},
		{&"skeleton_melee": 4, &"skeleton_chief": 2},
		{&"skeleton_chief": 3, &"skeleton_snow_centurion": 1},
	]
	for room_index in ACTIVE_ROOMS.size():
		var room_path: String = ACTIVE_ROOMS[room_index]
		var room = load(room_path)
		assert_not_null(room, room_path)
		var ids: Array = room.enemies.map(func(data): return data.unit_id)
		assert_eq(ids.size(), [4, 4, 6, 4][room_index], room_path)
		for unit_id in [&"skeleton_melee", &"skeleton_chief", &"skeleton_snow_centurion", &"skeleton_ranged"]:
			assert_eq(
				ids.count(unit_id),
				int((expected[room_index] as Dictionary).get(unit_id, 0)),
				room_path,
			)


func test_projectile_is_visual_only_and_cleans_itself() -> void:
	var projectile := ProjectileScene.instantiate() as SkeletonRangedProjectileVFX
	add_child(projectile)
	projectile.initialiser(Vector2.ZERO, Vector2(64.0, 0.0))
	await get_tree().create_timer(0.35).timeout
	assert_false(is_instance_valid(projectile))


func test_ranged_spell_deals_damage_exactly_once_through_spell_caster() -> void:
	var battlefield := Factory.make_battlefield(8, 1)
	var attacker := Unit.from_data(load(RANGED_PATH) as UnitData)
	var target := Unit.new("Cible", 0, 100)
	battlefield.grid.place_unit(attacker, Vector2i(0, 0))
	battlefield.grid.place_unit(target, Vector2i(6, 0))
	var before := target.current_hp
	var report := battlefield.caster.cast(attacker, attacker.spells[0], target.grid_pos)
	assert_false(report.get("failed", false))
	assert_eq(before - target.current_hp, 8)


func test_enemy_runner_resolves_each_skeleton_impact_once_and_waits_recovery() -> void:
	var ranged_field := Factory.make_battlefield(8, 1)
	var ranged := Unit.from_data(load(RANGED_PATH) as UnitData)
	var ranged_target := Unit.new("Cible distance runner", 0, 100)
	ranged_field.grid.place_unit(ranged, Vector2i(0, 0))
	ranged_field.grid.place_unit(ranged_target, Vector2i(6, 0))
	var ranged_view := AttackVisualSpy.new()
	add_child_autofree(ranged_view)
	var ranged_battle := EnemyRunnerBattleSpy.new()
	add_child_autofree(ranged_battle)
	ranged_battle.grid = ranged_field.grid
	ranged_battle.spell_caster = ranged_field.caster
	ranged_battle._unit_views[ranged] = ranged_view
	var ranged_runner := EnemyTurnRunner.new()
	add_child_autofree(ranged_runner)
	ranged_runner.setup(ranged_battle)
	var ranged_hp_before := ranged_target.current_hp
	await ranged_runner._execute_cast(ranged, ranged.spells[0], ranged_target.grid_pos)
	assert_eq(ranged_hp_before - ranged_target.current_hp, 8)
	assert_eq(ranged_view.spell_prepare_count, 1)
	assert_eq(ranged_view.recovery_count, 1)

	var melee_field := Factory.make_battlefield(2, 1)
	var melee := Unit.from_data(load(MELEE_PATH) as UnitData)
	var melee_target := Unit.new("Cible melee runner", 0, 100)
	melee_field.grid.place_unit(melee, Vector2i(0, 0))
	melee_field.grid.place_unit(melee_target, Vector2i(1, 0))
	var melee_view := AttackVisualSpy.new()
	add_child_autofree(melee_view)
	var melee_battle := EnemyRunnerBattleSpy.new()
	add_child_autofree(melee_battle)
	melee_battle.grid = melee_field.grid
	melee_battle.spell_caster = melee_field.caster
	melee_battle._unit_views[melee] = melee_view
	var melee_runner := EnemyTurnRunner.new()
	add_child_autofree(melee_runner)
	melee_runner.setup(melee_battle)
	var melee_hp_before := melee_target.current_hp
	await melee_runner._execute_cast(melee, melee.spells[0], melee_target.grid_pos)
	assert_eq(melee_hp_before - melee_target.current_hp, 18)
	assert_eq(melee_view.spell_prepare_count, 1)
	assert_eq(melee_view.recovery_count, 1)


func test_enemy_runner_revalidates_stale_attack_after_spell_spends_last_ap() -> void:
	var field := Factory.make_battlefield(2, 1)
	var enemy := Unit.new("Ennemi combo", 1, 100, 10, 6, 3, 20)
	var target := Unit.new("Cible combo", 0, 100)
	assert_true(field.grid.place_unit(enemy, Vector2i.ZERO))
	assert_true(field.grid.place_unit(target, Vector2i.RIGHT))
	enemy.current_ap = 2
	var spell := Factory.make_spell({
		"spell_id": &"enemy_combo_spell",
		"spell_name": "Sort de combo",
		"ap_cost": 2,
		"spell_range": 1,
		"damage": 3,
	})
	enemy.add_spell(spell)

	var view := AttackVisualSpy.new()
	add_child_autofree(view)
	var battle := EnemyRunnerBattleSpy.new()
	add_child_autofree(battle)
	battle.grid = field.grid
	battle.spell_caster = field.caster
	battle._unit_views[enemy] = view
	var runner := EnemyTurnRunner.new()
	add_child_autofree(runner)
	runner.setup(battle)
	var basic_attack_count := 0
	var basic_action_count := 0
	var on_basic := func(source, _target) -> void:
		if source == enemy:
			basic_attack_count += 1
	var on_action := func(source, _action_id, kind, _report) -> void:
		if source == enemy and kind == &"basic_attack":
			basic_action_count += 1
	EventBus.basic_attack_performed.connect(on_basic)
	EventBus.action_resolved.connect(on_action)

	# Simule l'exécution d'un plan construit avec les ressources d'avant-sort.
	await runner._execute_cast(enemy, spell, target.grid_pos)
	await runner._execute_attack(enemy, target)

	EventBus.basic_attack_performed.disconnect(on_basic)
	EventBus.action_resolved.disconnect(on_action)
	assert_eq(enemy.current_ap, 0)
	assert_eq(target.current_hp, 97)
	assert_eq(view.spell_prepare_count, 1)
	assert_eq(view.recovery_count, 1)
	assert_eq(view.attack_prepare_count, 0)
	assert_eq(view.attack_release_count, 0)
	assert_eq(basic_attack_count, 0)
	assert_eq(basic_action_count, 0)
	assert_false(view.is_action_visual_pending())
	assert_eq(battle._outcome_deferral_depth, 0)


func test_enemy_runner_cancels_released_attack_if_ap_changes_during_visual() -> void:
	var field := Factory.make_battlefield(2, 1)
	var enemy := Unit.new("Ennemi visuel", 1, 100, 10, 1, 3, 20)
	var target := Unit.new("Cible visuelle", 0, 100)
	assert_true(field.grid.place_unit(enemy, Vector2i.ZERO))
	assert_true(field.grid.place_unit(target, Vector2i.RIGHT))
	var view := AttackVisualSpy.new()
	view.attack_release_hook = func() -> void:
		enemy.current_ap = 0
	add_child_autofree(view)
	var battle := EnemyRunnerBattleSpy.new()
	add_child_autofree(battle)
	battle.grid = field.grid
	battle.spell_caster = field.caster
	battle._unit_views[enemy] = view
	var runner := EnemyTurnRunner.new()
	add_child_autofree(runner)
	runner.setup(battle)
	var events := {"basic": 0, "action": 0}
	var on_basic := func(source, _target) -> void:
		if source == enemy:
			events["basic"] = int(events["basic"]) + 1
	var on_action := func(source, _action_id, kind, _report) -> void:
		if source == enemy and kind == &"basic_attack":
			events["action"] = int(events["action"]) + 1
	EventBus.basic_attack_performed.connect(on_basic)
	EventBus.action_resolved.connect(on_action)

	await runner._execute_attack(enemy, target)

	EventBus.basic_attack_performed.disconnect(on_basic)
	EventBus.action_resolved.disconnect(on_action)
	assert_eq(target.current_hp, 100)
	assert_eq(view.attack_prepare_count, 1)
	assert_eq(view.attack_release_count, 1)
	assert_eq(view.cancel_count, 1)
	assert_eq(events, {"basic": 0, "action": 0})
	assert_false(view.is_action_visual_pending())
	assert_eq(battle._outcome_deferral_depth, 0)


func test_grid_cleanup_keeps_skeleton_visual_root_stable() -> void:
	var data := load(MELEE_PATH) as UnitData
	var unit := Unit.from_data(data)
	var grid := GridData.new(8, 8)
	grid.place_unit(unit, Vector2i(4, 4))
	var view := UnitViewScript.new()
	add_child_autofree(view)
	view.position = Vector2(420, 360)
	view.setup(unit)
	await wait_process_frames(4)
	var optional_visual := view.get_optional_visual()
	var root_before: Vector2 = view.global_position
	var visual_before: Vector2 = optional_visual.global_position
	grid.clear_unit(Vector2i(4, 4))
	assert_null(grid.get_unit(Vector2i(4, 4)))
	assert_eq(unit.grid_pos, Vector2i(-1, -1))
	assert_eq(view.global_position, root_before)
	assert_eq(optional_visual.global_position, visual_before)
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		optional_visual.set_facing(direction)
		assert_eq(view.global_position, root_before)


func test_shared_movement_pacing_is_within_contract() -> void:
	assert_between(MovementTiming.MOVE_SEGMENT_DURATION, 0.22, 0.28)
	assert_eq(MovementTiming.duration_for_segments(4), 0.96)
	assert_gt(MovementTiming.playback_speed_for_loop(1.0, false), 0.0)
	assert_gt(MovementTiming.playback_speed_for_loop(1.0, true), 0.0)
