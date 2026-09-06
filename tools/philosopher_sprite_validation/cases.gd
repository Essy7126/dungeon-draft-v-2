extends RefCounted

const DIRECTIONS := {"N": Vector2i.UP, "E": Vector2i.RIGHT, "S": Vector2i.DOWN, "W": Vector2i.LEFT}
const SCENARIOS := ["attack", "control", "shield", "heal_self", "heal_ally", "approach", "repel", "defeat"]
const MAGE_PATH := "res://data/units/enemies/philosopher_mage.tres"


static func configure(arena: ArenaDefinition, scenario: String, direction: String) -> Dictionary:
	var result := {"ok": false, "scenario": scenario, "direction": direction,
		"scope": "Memory-only initial spawns and facing on the production terrain. All HP changes, casts and movements thereafter use normal combat resolution."}
	if scenario not in SCENARIOS or not DIRECTIONS.has(direction):
		result.error = "unknown_scenario_or_direction"
		return result
	var grid := ArenaRuntimeBridge.build_grid_from_synced_resources(arena)
	var pathfinder := Pathfinder.new(grid)
	var forward: Vector2i = DIRECTIONS[direction]
	var side := Vector2i(-forward.y, forward.x)
	var distance := 5 if scenario == "attack" else 4
	if scenario in ["heal_self", "defeat"]:
		distance = 2
	elif scenario == "approach":
		distance = 7
	elif scenario == "repel":
		distance = 1
	var mage_cell := Vector2i(-1, -1)
	var best := INF
	for y in grid.rows:
		for x in grid.cols:
			var candidate := Vector2i(x, y)
			var legal := true
			for step in range(-1, distance + 2):
				var cell := candidate + forward * step
				legal = legal and grid.is_walkable(cell) and grid.get_type(cell) == GridData.CellType.NORMAL
			for cell in [candidate + side, candidate - side, candidate + forward + side]:
				legal = legal and grid.is_walkable(cell)
			if not legal or not pathfinder.has_line_of_sight(candidate, candidate + forward * distance):
				continue
			var score := (Vector2(candidate) + Vector2(forward) * distance * 0.5).distance_to(Vector2(grid.cols, grid.rows) * 0.5)
			if score < best:
				mage_cell = candidate
				best = score
	if mage_cell == Vector2i(-1, -1):
		result.error = "no_clear_fixture_lane_on_real_terrain"
		return result
	var source := load(MAGE_PATH) as UnitData
	if source == null:
		result.error = "canonical_mage_missing"
		return result
	var mage := source.duplicate(false) as UnitData
	mage.facing_dir = forward
	arena.encounter_definition = null
	arena.waves.clear()
	arena.enemies.assign([mage])
	arena.spawns.clear()
	var hero_cell := mage_cell + forward * distance
	_add_spawn(arena, &"philosopher_fixture_hero", ArenaSpawnDefinition.Kind.HERO_1, hero_cell)
	_add_spawn(arena, &"philosopher_fixture_mage", ArenaSpawnDefinition.Kind.ENEMY, mage_cell)
	if scenario in ["shield", "heal_ally"]:
		var ally := load("res://data/units/enemies/spectre_greatsword.tres") as UnitData
		arena.enemies.append(ally)
		var ally_cell := mage_cell + forward * 2
		_add_spawn(arena, &"philosopher_fixture_ally", ArenaSpawnDefinition.Kind.ENEMY, ally_cell)
		result.ally_cell = ally_cell
		# The legacy room roster shuffles all enemy spawn cells, so a support
		# mage and its patient can be interchanged. Use the real formation
		# planner with explicit initial role distances instead of teleporting
		# either actor after spawn. These restrictions concern initial enemy
		# placement only; the terrain remains fully traversable in combat.
		var encounter := EncounterDefinition.new()
		encounter.encounter_id = StringName("philosopher_fixture_" + scenario)
		encounter.roster_units.assign([mage, ally])
		encounter.roster_counts = PackedInt32Array([1, 1])
		encounter.living_enemy_cap = 2
		encounter.formation_profiles.assign([&"line"])
		encounter.minimum_path_distance_by_role = {&"philosopher_mage": 4, &"spectre_greatsword": 2}
		encounter.maximum_path_distance_by_role = {&"philosopher_mage": 4, &"spectre_greatsword": 2}
		for y in grid.rows:
			for x in grid.cols:
				var cell := Vector2i(x, y)
				if grid.is_walkable(cell) and cell not in [mage_cell, ally_cell]:
					encounter.forbidden_initial_spawn_cells.append(cell)
		arena.encounter_definition = encounter
		result.initial_formation = {"method": "Canonical EncounterFormationPlanner", "mage_distance": 4,
			"ally_distance": 2, "only_initial_enemy_cells": [mage_cell, ally_cell]}
	if not ArenaRuntimeBridge.sync_runtime_resources(arena):
		result.error = "fixture_projection_failed"
		return result
	result.mage_cell = mage_cell
	result.hero_cell = hero_cell
	result.direction_vector = forward
	result.canonical_mage_data = MAGE_PATH
	result.modified_initial_fields = ["spawn_cells", "mage.facing_dir"]
	if result.has("initial_formation"):
		(result.modified_initial_fields as Array).append("initial_enemy_formation_constraints")
	result.ok = true
	return result


static func _add_spawn(arena: ArenaDefinition, id: StringName, kind: int, cell: Vector2i) -> void:
	var spawn := ArenaSpawnDefinition.new()
	spawn.spawn_id = id
	spawn.kind = kind
	spawn.cell = cell
	arena.spawns.append(spawn)


static func prepare_progression(scenario: String) -> Dictionary:
	if scenario not in ["defeat", "heal_self", "heal_ally"]:
		return {"ok": true, "level": 1, "scope": "Unmodified starting Achilles"}
	var state := GameManager.get_character_state(&"achilles") as CharacterRunState
	if state == null or not state.uses_champion_progression():
		return {"ok": false, "error": "canonical_champion_state_missing"}
	var level := 10 if scenario == "defeat" else 2
	var award := state.award_encounter_xp(StringName("philosopher_fixture_" + scenario), state.champion_progression.profile.xp_for_level(level), true)
	return {"ok": bool(award.get("granted", false)), "level": level, "xp_award": award,
		"scope": "Legal XP awarded before combat, no mastery purchases. Healing uses level 2 so real Shot and Strike exceed the AI healing threshold; defeat uses level 10 to show a real hit and lethal spell. This is a combat fixture, not a claimed campaign playthrough."}
