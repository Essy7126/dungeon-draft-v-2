extends RefCounted

const DIRECTIONS := {"N": Vector2i.UP, "E": Vector2i.RIGHT, "S": Vector2i.DOWN, "W": Vector2i.LEFT}
const SCENARIOS := ["spectral", "ice", "fire", "vortex", "teleport", "approach", "transform", "defeat"]
const PARIS_PATH := "res://data/units/enemies/catabase_shadow_paris.tres"


static func configure(arena: ArenaDefinition, scenario: String, direction: String) -> Dictionary:
	var result := {"ok": false, "scenario": scenario, "direction": direction,
		"scope": "Memory-only initial spawns, facing and declared terrain fixture. The canonical enemy kit and AI are unchanged. Every subsequent HP, AP, MP, movement, transformation and spell comes from normal combat resolution."}
	if scenario not in SCENARIOS or not DIRECTIONS.has(direction):
		result.error = "unknown_scenario_or_direction"
		return result
	var grid := ArenaRuntimeBridge.build_grid_from_synced_resources(arena)
	var finder := Pathfinder.new(grid)
	var forward: Vector2i = DIRECTIONS[direction]
	var side := Vector2i(-forward.y, forward.x)
	var distance := 4
	if scenario in ["transform", "defeat", "teleport"]:
		distance = 2
	elif scenario == "approach":
		distance = 9
	elif scenario == "spectral":
		distance = 7
	var paris_cell := Vector2i(-1, -1)
	var best := INF
	for y in grid.rows:
		for x in grid.cols:
			var candidate := Vector2i(x, y)
			var legal := true
			for step in range(-1, distance + 2):
				for lateral in range(-1, 2):
					if lateral != 0 and step not in [0, 1, 2]:
						continue
					var cell := candidate + forward * step + side * lateral
					var authored := arena.get_cell_definition(cell)
					if not grid.is_walkable(cell) or grid.has_vortex(cell) or authored == null or authored.terrain_id != &"stone":
						legal = false
						break
			if not legal or not finder.has_line_of_sight(candidate, candidate + forward * distance):
				continue
			var score := (Vector2(candidate) + Vector2(forward) * distance * 0.5).distance_to(Vector2(grid.cols, grid.rows) * 0.5)
			if score < best:
				paris_cell = candidate
				best = score
	if paris_cell == Vector2i(-1, -1):
		result.error = "no_clear_lane_on_canonical_map"
		return result
	var source := load(PARIS_PATH) as UnitData
	if source == null:
		result.error = "canonical_paris_missing"
		return result
	var paris := source.duplicate(false) as UnitData
	paris.facing_dir = forward
	arena.encounter_definition = null
	arena.waves.clear()
	arena.enemies.assign([paris])
	arena.spawns.clear()
	var hero_cell := paris_cell + forward * distance
	_add_spawn(arena, &"paris_fixture_hero", ArenaSpawnDefinition.Kind.HERO_1, hero_cell)
	_add_spawn(arena, &"paris_fixture_enemy", ArenaSpawnDefinition.Kind.ENEMY, paris_cell)
	result.permanent_tiles = []
	if scenario == "vortex":
		var pull_destination := hero_cell - forward
		if not ArenaDynamicEditingService.paint_permanent_terrain(arena, pull_destination, &"lava"):
			result.error = "canonical_lava_fixture_failed"
			return result
		result.permanent_tiles.append({"cell": pull_destination, "terrain_id": "lava"})
		result.expected_pull_destination = pull_destination
	if not ArenaRuntimeBridge.sync_runtime_resources(arena):
		result.error = "fixture_projection_failed"
		return result
	result.paris_cell = paris_cell
	result.hero_cell = hero_cell
	result.direction_vector = forward
	result.canonical_enemy_data = PARIS_PATH
	result.modified_initial_fields = ["spawn_cells", "paris.facing_dir"]
	if scenario == "vortex":
		(result.modified_initial_fields as Array).append("declared_permanent_lava_tile")
	result.ok = true
	return result


static func _add_spawn(arena: ArenaDefinition, id: StringName, kind: int, cell: Vector2i) -> void:
	var spawn := ArenaSpawnDefinition.new()
	spawn.spawn_id = id
	spawn.kind = kind
	spawn.cell = cell
	arena.spawns.append(spawn)


static func prepare_progression(scenario: String) -> Dictionary:
	var state := GameManager.get_character_state(&"achilles") as CharacterRunState
	if state == null or not state.uses_champion_progression():
		return {"ok": false, "error": "canonical_champion_state_missing"}
	var level := 6 if scenario in ["transform", "defeat"] else 3
	var award := state.award_encounter_xp(StringName("paris_fixture_" + scenario), state.champion_progression.profile.xp_for_level(level), true)
	return {"ok": bool(award.get("granted", false)), "level": level, "xp_award": award,
		"scope": "Legal XP before combat, no mastery purchases or point allocation. Level 6 gives actual Shot 24 and Strike 26 to cross the strict threshold without a forced HP mutation. Level 3 survives the ordinary elemental volley. This validates a combat fixture, not a campaign playthrough."}
