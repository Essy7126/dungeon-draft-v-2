extends Node

const NORMAL := preload("res://data/units/ennemie/skeleton_melee.tres")
const CENTURION := preload("res://data/units/ennemie/skeleton_snow_centurion.tres")


func _ready() -> void:
	var runs: Array = []
	for run_index in 5:
		runs.append(_simulate(run_index))
	print("SKELETON_SIMULATION_RESULT=" + JSON.stringify(runs))
	get_tree().quit()


func _hero(name: StringName) -> Unit:
	var hero := Unit.new(String(name), 0, 185, 10, 6, 4, 34)
	hero.unit_id = name
	hero.armure.base_value = 20
	hero.resist_magique.base_value = 15
	return hero


func _simulate(_seed_index: int) -> Dictionary:
	var grid := GridData.new(12, 8)
	var pathfinder := Pathfinder.new(grid)
	var terrain := TerrainEffects.new(grid)
	var caster := SpellCaster.new(grid, pathfinder, terrain)
	var enemy_ai := EnemyAI.new(grid, pathfinder, caster)
	var units: Array = []
	var first_activation_seen := {}
	var simulation_state := {"premature_hero_death": false}
	var death_connections: Array = []
	var summon_counts := {
		&"call_bones": 0,
		&"raise_chief": 0,
	}
	var on_summon_resolved := func(
			_caster: Unit,
			_summoned: Unit,
			_cell: Vector2i,
			source_ability_id: StringName
		) -> void:
		if summon_counts.has(source_ability_id):
			summon_counts[source_ability_id] = int(summon_counts[source_ability_id]) + 1
	EventBus.summon_resolved.connect(on_summon_resolved)

	var centurion := Unit.from_data(CENTURION)
	var normal_a := Unit.from_data(NORMAL)
	var normal_b := Unit.from_data(NORMAL)
	var hero_a := _hero(&"hero_a")
	var hero_b := _hero(&"hero_b")
	var hero_c := _hero(&"hero_c")
	var placements := {
		centurion: Vector2i(2, 3),
		normal_a: Vector2i(1, 1),
		normal_b: Vector2i(1, 6),
		hero_a: Vector2i(8, 3),
		hero_b: Vector2i(9, 1),
		hero_c: Vector2i(9, 6),
	}
	for unit_value in placements:
		var unit := unit_value as Unit
		grid.place_unit(unit, placements[unit_value])
		units.append(unit)
		var on_died := func(dead: Unit) -> void:
			if dead.team == 0 and not first_activation_seen.get(dead, false):
				simulation_state["premature_hero_death"] = true
			grid.remove_unit(dead)
		unit.died.connect(on_died)
		death_connections.append({"unit": unit, "callable": on_died})

	var rounds := 0
	var peak_enemies := grid.count_living_in_team(1)
	while rounds < 12 and _living_team(units, 0) > 0 and _living_team(units, 1) > 0:
		rounds += 1
		var round_order := units.filter(func(value): return (value as Unit).is_alive)
		round_order.sort_custom(func(a: Unit, b: Unit) -> bool:
			if a.get_initiative() != b.get_initiative():
				return a.get_initiative() > b.get_initiative()
			return a.get_runtime_stable_id() < b.get_runtime_stable_id()
		)
		for value in round_order:
			var unit := value as Unit
			if not unit.is_alive:
				continue
			for participant_value in units:
				var participant := participant_value as Unit
				participant.on_actor_activation_started(unit)
			unit.start_turn()
			first_activation_seen[unit] = true
			terrain.on_turn_start(unit)
			unit.process_statuses()
			if not unit.is_alive:
				continue
			var pending := caster.resolve_pending_activation(
				unit,
				units,
				null,
				func(summoned: Unit) -> void:
					_connect_grid_death_cleanup(summoned, grid, death_connections)
			)
			if not pending.consume_activation:
				if unit.team == 1:
					_execute_enemy_plan(unit, units, enemy_ai, caster, grid)
				else:
					_execute_hero_turn(unit, units, pathfinder, grid)
			unit.tick_statuses()
			peak_enemies = maxi(peak_enemies, grid.count_living_in_team(1))
			if _living_team(units, 0) == 0 or _living_team(units, 1) == 0:
				break
	var report := {
		"rounds": rounds,
		"heroes_alive": _living_team(units, 0),
		"enemies_alive": _living_team(units, 1),
		"peak_enemies": peak_enemies,
		"premature_hero_death": bool(simulation_state["premature_hero_death"]),
		"total_units": units.size(),
		"normal_summons_resolved": int(summon_counts[&"call_bones"]),
		"chiefs_resolved": int(summon_counts[&"raise_chief"]),
	}
	EventBus.summon_resolved.disconnect(on_summon_resolved)
	_release_grid_death_cleanup(death_connections, grid)
	return report


func _connect_grid_death_cleanup(unit: Unit, grid: GridData, connections: Array) -> void:
	var on_died := func(dead: Unit) -> void: grid.remove_unit(dead)
	unit.died.connect(on_died)
	connections.append({"unit": unit, "callable": on_died})


func _release_grid_death_cleanup(connections: Array, grid: GridData) -> void:
	for entry_value in connections:
		var entry := entry_value as Dictionary
		var unit := entry.get("unit") as Unit
		var callback: Callable = entry.get("callable", Callable())
		if unit != null and callback.is_valid() and unit.died.is_connected(callback):
			unit.died.disconnect(callback)
	for unit_value in grid.get_units():
		grid.remove_unit(unit_value)
	connections.clear()


func _living_team(units: Array, team: int) -> int:
	return units.filter(func(value):
		var unit := value as Unit
		return unit.is_alive and unit.team == team
	).size()


func _execute_enemy_plan(
		enemy: Unit,
		units: Array,
		enemy_ai: EnemyAI,
		caster: SpellCaster,
		grid: GridData
	) -> void:
	var plan := enemy_ai.decide(enemy, units)
	for action in plan:
		match action.type:
			"move":
				var path: Array = action.path
				if path.size() >= 2:
					var destination: Vector2i = path[-1]
					enemy.spend_mp(path.size() - 1)
					grid.relocate_unit(enemy, destination)
			"cast":
				caster.cast(enemy, action.spell as Spell, action.cell)
			"attack":
				var target := action.target as Unit
				if target != null and target.is_alive and enemy.spend_ap(enemy.get_basic_attack_ap_cost()):
					target.take_damage(enemy.get_attack(), enemy)


func _execute_hero_turn(hero: Unit, units: Array, pathfinder: Pathfinder, grid: GridData) -> void:
	var enemies := units.filter(func(value):
		var unit := value as Unit
		return unit.is_alive and unit.team == 1
	)
	if enemies.is_empty():
		return
	enemies.sort_custom(func(a: Unit, b: Unit) -> bool:
		var distance_a := grid.manhattan(hero.grid_pos, a.grid_pos)
		var distance_b := grid.manhattan(hero.grid_pos, b.grid_pos)
		if distance_a != distance_b:
			return distance_a < distance_b
		# Les heros reconnaissent tactiquement le commandant comme cible prioritaire.
		if (a.tactical_role_id == &"skeleton_centurion") != (b.tactical_role_id == &"skeleton_centurion"):
			return a.tactical_role_id == &"skeleton_centurion"
		return a.get_runtime_stable_id() < b.get_runtime_stable_id()
	)
	var target := enemies[0] as Unit
	if not grid.are_adjacent(hero.grid_pos, target.grid_pos):
		var best_path: Array = []
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var edge: Vector2i = target.grid_pos + direction
			if not grid.is_walkable(edge):
				continue
			var path := pathfinder.find_path(hero.grid_pos, edge, hero)
			if path.size() >= 2 and (best_path.is_empty() or path.size() < best_path.size()):
				best_path = path
		if not best_path.is_empty():
			var step_count := mini(hero.current_mp, best_path.size() - 1)
			hero.spend_mp(step_count)
			grid.relocate_unit(hero, best_path[step_count])
	if target.is_alive and grid.are_adjacent(hero.grid_pos, target.grid_pos):
		target.take_damage(hero.get_attack(), hero, Spell.DamageType.PHYSICAL)
