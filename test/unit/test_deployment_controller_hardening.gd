extends GutTest


class DeploymentBattleSpy:
	extends Node

	const SPELL_COLOR := Color(0.25, 0.65, 1.0, 0.35)

	var grid: GridData
	var room_data := RoomData.new()
	var units: Array = []
	var _unit_views := {}


	func _init(cols: int, rows: int) -> void:
		grid = GridData.new(cols, rows)


	func _resolve_spawn_cell(pool: Array, _who: String) -> Vector2i:
		while not pool.is_empty():
			var candidate: Vector2i = pool.pop_front()
			if grid.is_valid(candidate) \
					and grid.is_walkable(candidate) \
					and not grid.has_unit(candidate):
				return candidate
		return Vector2i(-1, -1)


	func _place(unit: Unit, cell: Vector2i) -> bool:
		return grid.place_unit(unit, cell)


func after_each() -> void:
	GameManager.heroes.clear()


func test_duplicate_and_occupied_zone_cells_use_distinct_free_fallbacks() -> void:
	var battle := _battle(4, 1)
	var enemy := Unit.new("Occupant", 1, 10)
	assert_true(battle.grid.place_unit(enemy, Vector2i.ZERO))
	battle.units.append(enemy)
	battle.room_data.hero_spawn_zone = [
		Vector2i.ZERO,
		Vector2i(1, 0),
		Vector2i(1, 0),
	]
	var heroes := _heroes(2)
	var controller := _controller(battle)
	var completed := [0]
	controller.deployment_completed.connect(func(): completed[0] += 1)

	controller.start()

	assert_eq(controller._deploy_zone, [Vector2i(1, 0)])
	assert_eq(completed[0], 1)
	assert_eq(controller._heroes_to_place.size(), 0)
	assert_eq(battle.units.size(), 3)
	assert_eq(battle.grid.find_unit(heroes[0]), Vector2i(1, 0))
	assert_eq(battle.grid.find_unit(heroes[1]), Vector2i(2, 0))
	assert_same(battle.grid.get_unit(Vector2i.ZERO), enemy)


func test_small_nominal_zone_expands_to_free_grid_cells() -> void:
	var battle := _battle(4, 1)
	battle.room_data.hero_spawn_zone = [Vector2i.ZERO]
	var heroes := _heroes(2)
	var controller := _controller(battle)
	var completed := [0]
	controller.deployment_completed.connect(func(): completed[0] += 1)

	controller.start()

	assert_eq(completed[0], 1)
	assert_eq(battle.grid.find_unit(heroes[0]), Vector2i.ZERO)
	assert_eq(battle.grid.find_unit(heroes[1]), Vector2i(1, 0))
	assert_eq(battle.units, heroes)


func test_impossible_fallback_returns_control_for_the_terminal_outcome() -> void:
	var battle := _battle(2, 1)
	var enemy := Unit.new("Occupant", 1, 10)
	assert_true(battle.grid.place_unit(enemy, Vector2i.ZERO))
	battle.units.append(enemy)
	battle.room_data.hero_spawn_zone = [Vector2i(1, 0)]
	var heroes := _heroes(2)
	var controller := _controller(battle)
	var completed := [0]
	controller.deployment_completed.connect(func(): completed[0] += 1)

	controller.start()

	assert_push_error("capacité totale insuffisante")
	assert_eq(
		completed[0],
		1,
		"Battle doit pouvoir constater zéro héros et terminer en défaite.",
	)
	assert_eq(controller._heroes_to_place, heroes)
	assert_eq(battle.units, [enemy])
	assert_eq(battle.grid.find_unit(heroes[0]), Vector2i(-1, -1))
	assert_eq(battle.grid.find_unit(heroes[1]), Vector2i(-1, -1))


func _battle(cols: int, rows: int) -> DeploymentBattleSpy:
	var battle := DeploymentBattleSpy.new(cols, rows)
	add_child_autofree(battle)
	return battle


func _controller(battle: DeploymentBattleSpy) -> DeploymentController:
	var controller := DeploymentController.new()
	battle.add_child(controller)
	controller.setup(battle)
	return controller


func _heroes(count: int) -> Array:
	var result: Array = []
	for index in count:
		result.append(Unit.new("Héros %d" % (index + 1), 0, 20))
	GameManager.heroes = result.duplicate()
	return result
