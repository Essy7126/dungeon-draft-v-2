extends GutTest

const MovementTiming = preload("res://characters/character_movement_timing.gd")
const UnitViewScript = preload("res://battle/unit_view.gd")
const MAGE_ISO_SCENE = preload("res://characters/mage/MageIsoUnitView.tscn")
const SKELETON_MELEE_DATA = preload("res://data/units/ennemie/skeleton_melee.tres")
const FOREST_PRESENTATION = preload(
	"res://data/maps/painted/room_01_forest_presentation.tres"
)


class MovementView:
	extends Node2D

	var begin_count := 0
	var end_count := 0
	var begin_position := Vector2.ZERO
	var faced_directions: Array[Vector2i] = []

	func begin_movement_feedback(_from_cell: Vector2i, _to_cell: Vector2i) -> void:
		begin_count += 1
		begin_position = position

	func end_movement_feedback() -> void:
		end_count += 1

	func face_grid_direction(direction: Vector2i) -> void:
		faced_directions.append(direction)


class MovementBattleFixture:
	extends "res://battle/battle.gd"

	func _ready() -> void:
		pass

	func grid_cell_to_parent_local(cell: Vector2i, _parent: Node2D) -> Vector2:
		return Vector2(cell.x * 64.0, cell.y * 32.0)

	func _create_unit_view(unit: Unit) -> void:
		var view := MovementView.new()
		add_child(view)
		_unit_views[unit] = view


class DeathVisualSpy:
	extends Node2D

	signal death_animation_finished

	var facing := Vector2i.ZERO
	var facing_when_death_started := Vector2i.ZERO

	func bind_unit(unit: Unit) -> void:
		unit.died.connect(_on_bound_unit_died)

	func set_facing(direction: Vector2i) -> void:
		facing = direction

	func _on_bound_unit_died(_unit: Unit) -> void:
		facing_when_death_started = facing
		death_animation_finished.emit.call_deferred()


class DeathUnitViewFixture:
	extends UnitViewScript

	var visual_spy: DeathVisualSpy = null

	func _instantiate_optional_visual() -> void:
		visual_spy = DeathVisualSpy.new()
		_optional_visual = visual_spy
		add_child(visual_spy)
		visual_spy.bind_unit(unit)


func test_painted_presentation_hides_character_outlines_by_default() -> void:
	var profile := BattlePresentationProfile.new()
	assert_false(profile.outlines_enabled)
	assert_false(FOREST_PRESENTATION.outlines_enabled)


func test_move_feedback_starts_before_motion_and_ends_on_arrival() -> void:
	var battle := MovementBattleFixture.new()
	add_child_autofree(battle)
	var grid := GridData.new(3, 1)
	var unit := Unit.new("Test")
	var view := MovementView.new()
	battle.add_child(view)
	battle.grid = grid
	battle.pathfinder = Pathfinder.new(grid)
	battle.terrain_effects = TerrainEffects.new(grid)
	battle._unit_views[unit] = view
	assert_true(grid.place_unit(unit, Vector2i.ZERO))

	battle._animate_move(unit, [Vector2i.ZERO, Vector2i.RIGHT])

	assert_eq(view.begin_count, 1)
	assert_eq(view.begin_position, Vector2.ZERO)
	assert_eq(view.position, Vector2.ZERO)
	assert_eq(view.end_count, 0)

	await wait_seconds(MovementTiming.MOVE_SEGMENT_DURATION + 0.1)

	assert_eq(unit.grid_pos, Vector2i.RIGHT)
	assert_eq(view.position, Vector2(64.0, 0.0))
	assert_eq(view.end_count, 1)


func test_hero_faces_nearest_enemy_as_soon_as_placed() -> void:
	var battle := MovementBattleFixture.new()
	add_child_autofree(battle)
	battle.grid = GridData.new(6, 6)
	var nearest_enemy := Unit.new("Ennemi proche")
	nearest_enemy.team = 1
	var farther_enemy := Unit.new("Ennemi lointain")
	farther_enemy.team = 1
	assert_true(battle.grid.place_unit(nearest_enemy, Vector2i(4, 1)))
	assert_true(battle.grid.place_unit(farther_enemy, Vector2i(1, 5)))
	battle.units = [nearest_enemy, farther_enemy]
	var hero := Unit.new("Heros")

	battle._place(hero, Vector2i(1, 1))

	var view := battle._unit_views[hero] as MovementView
	assert_eq(view.faced_directions, [Vector2i(3, 0)])
	assert_eq(hero.facing_dir, Vector2i.RIGHT)


func test_enemy_faces_nearest_hero_after_movement_feedback_ends() -> void:
	var battle := MovementBattleFixture.new()
	add_child_autofree(battle)
	var grid := GridData.new(6, 3)
	var enemy := Unit.new("Ennemi")
	enemy.team = 1
	var hero := Unit.new("Heros")
	var view := MovementView.new()
	battle.add_child(view)
	battle.grid = grid
	battle.pathfinder = Pathfinder.new(grid)
	battle.terrain_effects = TerrainEffects.new(grid)
	battle._unit_views[enemy] = view
	battle.units = [enemy, hero]
	assert_true(grid.place_unit(enemy, Vector2i(2, 1)))
	assert_true(grid.place_unit(hero, Vector2i(0, 1)))

	battle._animate_move(enemy, [Vector2i(2, 1), Vector2i(3, 1)])
	await wait_seconds(MovementTiming.MOVE_SEGMENT_DURATION + 0.1)

	assert_eq(view.end_count, 1)
	assert_eq(view.faced_directions, [Vector2i.RIGHT, Vector2i(-3, 0)])
	assert_eq(enemy.facing_dir, Vector2i.LEFT)


func test_single_target_death_faces_the_attacker_before_animation_starts() -> void:
	var grid := GridData.new(6, 3)
	var attacker := Unit.new("Lanceur", 0)
	var victim := Unit.new("Victime", 1)
	assert_true(grid.place_unit(attacker, Vector2i(0, 1)))
	assert_true(grid.place_unit(victim, Vector2i(3, 1)))
	var view := DeathUnitViewFixture.new()
	add_child_autofree(view)
	view.setup(victim)

	victim.take_damage(999, attacker)

	assert_eq(view.visual_spy.facing_when_death_started, Vector2i(-3, 0))
	assert_eq(victim.facing_dir, Vector2i.LEFT)


func test_area_death_faces_the_spell_epicenter_before_animation_starts() -> void:
	var grid := GridData.new(7, 5)
	var attacker := Unit.new("Lanceur", 0)
	var victim := Unit.new("Victime peripherique", 1)
	assert_true(grid.place_unit(attacker, Vector2i(0, 2)))
	assert_true(grid.place_unit(victim, Vector2i(4, 2)))
	var view := DeathUnitViewFixture.new()
	add_child_autofree(view)
	view.setup(victim)
	var spell := Spell.new()
	spell.spell_id = &"test_area_death_facing"
	spell.spell_name = "Zone test"
	spell.ap_cost = 0
	spell.spell_range = 6
	spell.needs_line_of_sight = false
	spell.can_target_free_cell = true
	spell.aoe_shape = Spell.AoeShape.CROSS
	spell.aoe_size = 1
	spell.damage = 999
	var caster := SpellCaster.new(
		grid,
		Pathfinder.new(grid),
		TerrainEffects.new(grid),
	)

	caster.cast(attacker, spell, Vector2i(4, 1))

	assert_eq(view.visual_spy.facing_when_death_started, Vector2i.UP)
	assert_eq(victim.facing_dir, Vector2i.UP)


func test_real_skeleton_targeted_death_keeps_facing_the_attacker_after_grid_cleanup() -> void:
	var grid := GridData.new(7, 5)
	var attacker := Unit.new("Lanceur", 0)
	var victim := Unit.from_data(SKELETON_MELEE_DATA)
	assert_true(grid.place_unit(attacker, Vector2i(4, 0)))
	assert_true(grid.place_unit(victim, Vector2i(4, 2)))
	# Battle connecte son nettoyage avant de creer la vue : ce test reproduit
	# cet ordre pour couvrir l'animation reelle, pas seulement une doublure.
	victim.died.connect(func(dead_unit: Unit): grid.clear_unit(dead_unit.grid_pos))
	var view := UnitViewScript.new()
	add_child_autofree(view)
	view.setup(victim)
	var skeleton_view := view.get_optional_visual() as CharacterIsoUnitView
	assert_not_null(skeleton_view)
	await wait_process_frames(2)

	victim.take_damage(999, attacker)

	assert_eq(
		skeleton_view.get_character_visual().get_current_animation(),
		SkeletonVisual3D.ANIM_DEATH,
	)
	assert_eq(skeleton_view.get_facing_direction(), Vector2i.UP)
	assert_eq(victim.facing_dir, Vector2i.UP)


func test_real_skeleton_area_death_keeps_facing_the_epicenter_after_grid_cleanup() -> void:
	var grid := GridData.new(7, 5)
	var attacker := Unit.new("Lanceur", 0)
	var victim := Unit.from_data(SKELETON_MELEE_DATA)
	assert_true(grid.place_unit(attacker, Vector2i(0, 2)))
	assert_true(grid.place_unit(victim, Vector2i(4, 2)))
	victim.died.connect(func(dead_unit: Unit): grid.clear_unit(dead_unit.grid_pos))
	var view := UnitViewScript.new()
	add_child_autofree(view)
	view.setup(victim)
	var skeleton_view := view.get_optional_visual() as CharacterIsoUnitView
	assert_not_null(skeleton_view)
	await wait_process_frames(2)
	var spell := Spell.new()
	spell.spell_id = &"test_real_area_death_facing"
	spell.spell_name = "Zone test reelle"
	spell.ap_cost = 0
	spell.spell_range = 6
	spell.needs_line_of_sight = false
	spell.can_target_free_cell = true
	spell.aoe_shape = Spell.AoeShape.CROSS
	spell.aoe_size = 1
	spell.damage = 999
	var caster := SpellCaster.new(
		grid,
		Pathfinder.new(grid),
		TerrainEffects.new(grid),
	)

	caster.cast(attacker, spell, Vector2i(4, 1))

	assert_eq(
		skeleton_view.get_character_visual().get_current_animation(),
		SkeletonVisual3D.ANIM_DEATH,
	)
	assert_eq(skeleton_view.get_facing_direction(), Vector2i.UP)
	assert_eq(victim.facing_dir, Vector2i.UP)


func test_iso_run_starts_immediately_ignores_cell_signal_and_returns_to_idle() -> void:
	var iso := MAGE_ISO_SCENE.instantiate() as CharacterIsoUnitView
	add_child_autofree(iso)
	await wait_process_frames(2)
	var unit := Unit.new("Mage test")
	iso.bind_unit(unit)
	iso.set_debug_run_for_next_movement(true)
	var visual := iso.get_character_visual()

	iso.begin_movement_feedback(Vector2i.ZERO, Vector2i.RIGHT)

	assert_true(iso._movement_active)
	assert_eq(visual.get_current_animation(), visual.animation_run)
	iso._on_bound_unit_moved(Vector2i.ZERO, Vector2i.RIGHT)
	assert_true(iso._movement_active)
	assert_eq(visual.get_current_animation(), visual.animation_run)

	iso.cancel_movement_feedback()

	assert_false(iso._movement_active)
	assert_eq(visual.get_current_animation(), visual.animation_idle)
