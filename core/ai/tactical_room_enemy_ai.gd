extends EnemyAI
## Opt-in for the five room scenes and their headless harness. Ordinary battles are unchanged.
var room_rules


func decide(enemy: Unit, all_units: Array) -> Array:
	var normal := super(enemy, all_units)
	if (
		room_rules == null or not enemy.is_alive or enemy.activation_consumed
		or not enemy.pending_ability.is_empty()
	):
		return normal
	var origin := enemy.grid_pos
	var current := _room_value(enemy, origin)
	var best := current
	var chosen: Array = []
	if enemy.current_mp > 0:
		for y in _grid.rows:
			for x in _grid.cols:
				var cell := Vector2i(x, y)
				if cell == origin or not _grid.is_walkable(cell, enemy):
					continue
				var path := _pathfinder.find_path(origin, cell, enemy)
				if path.size() < 2:
					continue
				var cost := _pathfinder.path_movement_cost(path, enemy)
				if cost > enemy.current_mp:
					continue
				var score := _room_value(enemy, cell) - cost * 2.0 - _path_danger_score(path) * 10.0
				if score > best + 1.0:
					best = score
					chosen = path
	if not chosen.is_empty():
		return [{ "type": "move", "path": chosen }]
	# Do not immediately undo a safe position or abandon a charged objective to chase.
	if not normal.is_empty() and str(normal[0].type) == "move":
		var path: Array = normal[0].path
		if not path.is_empty() and _room_value(enemy, path.back()) < current - 1.0:
			return []
	return normal


func _room_value(enemy: Unit, cell: Vector2i) -> float:
	if not room_rules.is_mechanism_active():
		return 0.0
	var value := 0.0
	value -= preload("res://core/ai/support_mage_terrain.gd").cell_risk(self, cell) * 10.0
	var role := str(enemy.tactical_role_id).trim_prefix("catabase_evolution_")
	var reckless := role in ["brute", "molosse", "alpha"]
	if cell in room_rules.danger_cells():
		var damage: int = (
			60
			if room_rules.room_id == "forge"
			else (room_rules.blast_damage if room_rules.room_id == "hourglass" else 28)
		)
		if not reckless or enemy.current_hp + enemy.current_shield <= damage:
			value -= 100.0
	if room_rules.room_id == "reservoir":
		for index in 2:
			if room_rules.charges[index] > 0:
				var distance := _grid.manhattan(cell, room_rules.RESERVOIRS[index])
				value += maxf(0.0, 40.0 - max(0, distance - 1) * 10.0)
	return value
