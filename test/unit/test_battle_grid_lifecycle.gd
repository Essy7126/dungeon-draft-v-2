extends GutTest


class EmptyBattle extends "res://battle/battle.gd":
	func _ready() -> void:
		pass


func _mount(unit: Unit) -> EmptyBattle:
	var battle := EmptyBattle.new()
	battle.grid = GridData.new(3, 3)
	battle.terrain_effects = TerrainEffects.new(battle.grid)
	battle.terrain_effects.capture_base_state()
	battle.units.append(unit)
	battle.grid.place_unit(unit, Vector2i(1, 1))
	add_child(battle)
	return battle


func _release_room() -> Dictionary:
	var enemy := Unit.new("Transient enemy", 1, 80, 10)
	var battle := _mount(enemy)
	var refs := {
		"unit": weakref(enemy),
		"grid": weakref(battle.grid),
		"terrain": weakref(battle.terrain_effects),
		"surface": weakref(battle.terrain_effects.runtime_service),
	}
	battle.free()
	return refs


func test_leaving_battle_releases_occupants_grid_and_terrain() -> void:
	var refs := _release_room()
	for key: String in refs:
		assert_null((refs[key] as WeakRef).get_ref(), key + " must leave with its scene")


func test_persistent_hero_keeps_state_without_retaining_old_grid() -> void:
	var hero := Unit.new("Persistent hero", 0, 100, 20)
	var battle := _mount(hero)
	var grid_ref: WeakRef = weakref(battle.grid)
	hero.current_hp = 73
	hero.current_ap = 2
	var previous_position := hero.grid_pos
	battle.free()
	assert_null(hero.grid_context)
	assert_null(grid_ref.get_ref())
	assert_eq(hero.current_hp, 73)
	assert_eq(hero.current_ap, 2)
	assert_eq(hero.grid_pos, previous_position)


func test_old_scene_does_not_detach_hero_from_next_battle() -> void:
	var hero := Unit.new("Transferred hero", 0, 100, 20)
	var battle := _mount(hero)
	var old_grid: WeakRef = weakref(battle.grid)
	var next_grid := GridData.new(4, 4)
	next_grid.place_unit(hero, Vector2i(2, 2))
	battle.free()
	assert_same(hero.grid_context, next_grid)
	assert_same(next_grid.get_unit(Vector2i(2, 2)), hero)
	assert_eq(hero.grid_pos, Vector2i(2, 2))
	assert_null(old_grid.get_ref())
	next_grid.remove_unit(hero)
