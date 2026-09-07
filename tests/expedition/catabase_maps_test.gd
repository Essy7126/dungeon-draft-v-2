extends Node
## Validate saved gameplay, authored geometry, runtime projection and render sets.

const CATALOG := preload("res://core/expedition/expedition_map_catalog.gd")
const BLUEPRINT_PATH := "res://data/rooms/catabase_expansion/blueprints.json"
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
var _checks := 0
var _errors: Array[String] = []
var _summaries: Array[Dictionary] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var maps := CATALOG.all_rooms()
	_check(maps.size() == 15, "15 map resources")
	_check(CATALOG.get_room(-1) == null and CATALOG.get_room(15) == null, "invalid index rejected")
	for index in 5:
		_check(maps[index] == load("res://data/rooms/odyssey/room_%02d.tres" % (index + 1)), "original %d exact resource" % index)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BLUEPRINT_PATH))
	var shapes := {}
	for index in range(5, 15):
		var arena := maps[index] as ArenaDefinition
		_check(arena != null, "map %d ArenaDefinition" % index)
		if arena == null: continue
		var spec: Dictionary = document.maps[index - 5]
		_validate_map(arena, spec, shapes)
	_check(shapes.size() == 10, "ten distinct authored playable shapes")
	var report := {"checks": _checks, "failures": _errors, "maps": _summaries}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/catabase_maps"))
	var file := FileAccess.open("res://artifacts/catabase_maps/topology_report.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t"))
	print("Catabase maps: %d checks, %d failures, %d new maps" % [_checks, _errors.size(), _summaries.size()])
	for failure in _errors: push_error(failure)
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_map(arena: ArenaDefinition, spec: Dictionary, shapes: Dictionary) -> void:
	var label := str(arena.arena_id)
	_check(arena.room_name == str(spec.title), label + " title")
	_check(arena.battle_scene != null and arena.battle_scene.resource_path == ArenaDefinition.REGISTERED_TERRAIN_BATTLE_SCENE, label + " production renderer")
	_check(arena.get_wave_count() == 1, label + " single encounter")
	_check(arena.encounter_definition.validation_errors().is_empty(), label + " encounter valid")
	_check(arena.grid_layout != null and arena.grid_layout.validation_errors().is_empty(), label + " persisted grid valid")
	_check(arena.painted_map_visual_data.validation_errors().is_empty(), label + " projection visual valid: " + str(arena.painted_map_visual_data.validation_errors()))
	var canonical := ArenaTopologySignatureService.build(arena)
	var grid := ArenaRuntimeBridge.build_grid(arena)
	var reachable := _reachable(grid, arena.hero_spawn_zone[0])
	var shape := str(canonical.hashes.playable_cells)
	_check(not shapes.has(shape), label + " distinct geometry")
	shapes[shape] = true
	_check(reachable.size() == canonical.playable_cells.size(), label + " all playable tiles connected")
	var expected_floor := {}
	var expected_blocks := {}
	var expected_hero := {}
	var expected_enemy := {}
	for y in spec.rows.size():
		for x in str(spec.rows[y]).length():
			var token := str(spec.rows[y]).substr(x, 1)
			var cell := Vector2i(x, y)
			if token != " ": expected_floor[cell] = true
			if token in ["#", "o"]: expected_blocks[cell] = true
			if token == "H": expected_hero[cell] = true
			if token == "E": expected_enemy[cell] = true
			_check(grid.is_walkable(cell) == (token != " " and token not in ["#", "o"]), label + " walkable %s" % cell)
			if token == " ": _check(grid.get_type(cell) == GridData.CellType.HOLE, label + " removed cell %s" % cell)
			if token == "L": _check(grid.get_type(cell) == GridData.CellType.LAVA, label + " real lava %s" % cell)
			if token == "I": _check(grid.get_type(cell) == GridData.CellType.ICE, label + " real ice %s" % cell)
			if token in ["#", "o"]:
				_check(grid.is_transparent(cell) == (token == "o"), label + " cover height %s" % cell)
	_check(_cell_set(arena.defined_cells()) == expected_floor, label + " source floor parity")
	_check(_cell_set(arena.hero_spawn_zone) == expected_hero, label + " source hero parity")
	_check(_cell_set(arena.enemy_spawn_zone) == expected_enemy, label + " source enemy parity")
	_check(arena.hero_spawn_zone.size() == 4, label + " four safe departure options")
	_check(arena.enemy_spawn_zone.size() >= arena.enemies.size(), label + " roster fits spawn zone")
	var min_distance := 10000
	for cell in arena.hero_spawn_zone + arena.enemy_spawn_zone:
		_check(grid.is_walkable(cell) and reachable.has(cell), label + " legal connected spawn %s" % cell)
		_check(grid.get_type(cell) == GridData.CellType.NORMAL, label + " spawn free of hazard")
	for hero in arena.hero_spawn_zone:
		for enemy in arena.enemy_spawn_zone:
			var distance := _distance(grid, hero, enemy)
			min_distance = mini(min_distance, distance)
			_check(distance >= 5, label + " initial spacing %s -> %s" % [hero, enemy])
	var planner := EncounterFormationPlanner.new(grid, Pathfinder.new(grid))
	for seed_value in range(24):
		var plan := planner.build_plan(arena.encounter_definition, arena.hero_spawn_zone, arena.enemy_spawn_zone, seed_value)
		_check(bool(plan.get("valid", false)), label + " valid formation seed %d" % seed_value)
		for placement: Dictionary in plan.get("placements", []):
			_check(expected_enemy.has(placement.cell), label + " formation uses authored enemy cells")
	var round_trip := ArenaDefinition.new()
	_check(round_trip.restore_snapshot(arena.to_snapshot()), label + " studio restore")
	_check(ArenaTopologySignatureService.build(round_trip).topology_hash == canonical.topology_hash, label + " studio topology parity")
	var reloaded := ResourceLoader.load(arena.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as ArenaDefinition
	_check(ArenaTopologySignatureService.build(reloaded).topology_hash == canonical.topology_hash, label + " disk topology parity")
	var projected := ArenaRuntimeBridge.build_runtime_projection(arena)
	_check(ArenaTopologySignatureService.build(projected).topology_hash == canonical.topology_hash, label + " runtime topology parity")
	var render := ArenaTerrainRenderPlanService.build(arena)
	var rendered_floor := {}
	for entry in render.render_entries: rendered_floor[entry.cell] = true
	_check(render.errors.is_empty(), label + " floor assets valid")
	_check(rendered_floor == expected_floor, label + " exact rendered floor set")
	for obstacle in arena.obstacles:
		_check(expected_blocks.has(obstacle.cell), label + " declared blocker exists")
		_check(arena.decorations.any(func(decor): return decor.cell == obstacle.cell and ResourceLoader.exists(decor.scene_path)), label + " blocker has production visual")
	_summaries.append({"id": label, "title": arena.room_name, "floor": expected_floor.size(), "walkable": reachable.size(), "blockers": expected_blocks.size(), "nearest_spawn_distance": min_distance, "enemies": arena.enemies.size(), "tactical_intent": spec.intent})


func _reachable(grid: GridData, start: Vector2i) -> Dictionary:
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for direction: Vector2i in DIRECTIONS:
			var neighbor := cell + direction
			if grid.is_walkable(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return visited


func _distance(grid: GridData, start: Vector2i, target: Vector2i) -> int:
	var costs := {start: 0}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		if cell == target: return costs[cell]
		for direction: Vector2i in DIRECTIONS:
			var neighbor := cell + direction
			if grid.is_walkable(neighbor) and not costs.has(neighbor):
				costs[neighbor] = int(costs[cell]) + 1
				queue.append(neighbor)
	return -1


func _cell_set(cells: Array[Vector2i]) -> Dictionary:
	var result := {}
	for cell in cells: result[cell] = true
	return result


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition: _errors.append(label)
