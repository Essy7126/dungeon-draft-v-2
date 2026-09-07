extends Node
## Explicit authoring tool; runtime consumes the saved ArenaDefinition resources.
## No seed, noise, source-room duplication or gameplay mutation during loading.

const BLUEPRINT_PATH := "res://data/rooms/catabase_expansion/blueprints.json"
const ROOT := "res://data/rooms/catabase_expansion/"
const PROP_ROOT := "res://battle/painted/registered_terrain/props/"
const ENEMIES := {
	"guard": "res://data/units/enemies/odyssey_guard.tres",
	"archer": "res://data/units/enemies/catabase_shadow_paris.tres",
	"skirmisher": "res://data/units/enemies/odyssey_skirmisher.tres",
	"spectre": "res://data/units/enemies/spectre_greatsword.tres",
	"champion": "res://data/units/enemies/odyssey_champion.tres",
}
const PALETTES := {
	"limestone": ["#252f2e", "#5c6559", "#aca67c", "#d8c9a1"],
	"lethe": ["#122c35", "#345459", "#6d9891", "#b0c3b1"],
	"ember": ["#2f2222", "#594039", "#95745b", "#c8a47a"],
	"judgment": ["#252737", "#484f66", "#8793a2", "#c4c1b5"],
	"oath": ["#1b1f2a", "#363e50", "#697386", "#a6adc0"],
}
var _errors: Array[String] = []


func _ready() -> void:
	_build.call_deferred()


func _build() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BLUEPRINT_PATH))
	for index in document.maps.size():
		_build_map(document.maps[index], index + 6)
	print("Catabase map authoring: %d maps, errors=%s" % [document.maps.size(), _errors])
	get_tree().quit(0 if _errors.is_empty() else 1)


func _build_map(spec: Dictionary, number: int) -> void:
	var arena := ArenaDefinition.new()
	arena.set_identity(str(spec.title), "catabase_%s_v1" % spec.id)
	arena.visual_mode = ArenaDefinition.VisualMode.HYBRID
	arena.theme_id = &"forest"
	arena.source_image_size = Vector2i(1920, 1200)
	arena.grid_size = Vector2i(str(spec.rows[0]).length(), spec.rows.size())
	arena.grid_origin = Vector2(960, 220)
	arena.axis_x = Vector2(51.6, 25.8)
	arena.axis_y = Vector2(-51.6, 25.8)
	arena.presentation_profile_path = ROOT + "presentation.tres"
	arena.source_room_path = ROOT + "room_%02d_%s.tres" % [number, spec.id]
	arena.background_path = ROOT + "%s/grid_reference.png" % spec.id
	arena.registered_terrain_plan_path = ROOT + "%s/terrain_plan.json" % spec.id
	arena.battle_scene = load(ArenaDefinition.REGISTERED_TERRAIN_BATTLE_SCENE)
	arena.production_notes = str(spec.intent) + " | Authored blueprint: " + BLUEPRINT_PATH
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = &"forest"
	arena.modular_visual_profile.hybrid_floor_policy = ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	arena.ultimate_reward_base_chance = 0
	arena.ultimate_reward_min_gain_per_wave = 0
	arena.ultimate_reward_max_gain_per_wave = 0
	var pits: Array = []
	for y in arena.grid_size.y:
		var row := str(spec.rows[y])
		if row.length() != arena.grid_size.x:
			_errors.append("%s: unequal row width" % spec.id)
		for x in row.length():
			var token := row.substr(x, 1)
			var cell := Vector2i(x, y)
			if token == " ":
				pits.append([x, y])
				continue
			var definition := arena.ensure_cell(cell)
			ArenaTerrainRegistry.configure_cell(definition, &"lava" if token == "L" else (&"ice" if token == "I" else &"stone"))
			if token in ["H", "E"]:
				var spawn := ArenaSpawnDefinition.new()
				spawn.spawn_id = StringName("%s_%d_%d" % [token, x, y])
				spawn.cell = cell
				spawn.kind = ArenaSpawnDefinition.Kind.HERO_1 if token == "H" else ArenaSpawnDefinition.Kind.ENEMY
				arena.spawns.append(spawn)
			elif token in ["o", "#"]:
				var obstacle := ArenaObstacleDefinition.new()
				obstacle.obstacle_id = StringName("pillar_%d_%d" % [x, y])
				obstacle.cell = cell
				obstacle.apply_preset(ArenaObstacleDefinition.Preset.LOW_OBSTACLE if token == "o" else ArenaObstacleDefinition.Preset.FULL_WALL)
				arena.obstacles.append(obstacle)
				var decoration := ArenaDecorationDefinition.new()
				decoration.decoration_id = obstacle.obstacle_id
				decoration.cell = cell
				decoration.scene_path = PROP_ROOT + ("StonePlinth.tscn" if token == "o" else "BrokenColumn.tscn")
				decoration.gameplay_preset = &"low_obstacle" if token == "o" else &"full_wall"
				arena.decorations.append(decoration)
	arena.encounter_definition = _encounter(spec, number)
	for index in [0, arena.cells.size() / 2, arena.cells.size() - 1]:
		var cell: Vector2i = arena.cells[index].coordinate
		arena.calibration_cells.append(cell)
		arena.calibration_pixels.append(arena.grid_origin + arena.axis_x * cell.x + arena.axis_y * cell.y)
	if not ArenaRuntimeBridge.sync_runtime_resources(arena):
		_errors.append("%s: projection failed" % spec.id)
		return
	# The shared formation planner treats enemy_spawn_zone only as a score bonus.
	# Lock initial deployments to the authored safe cells; combat movement stays free.
	for cell in arena.cells:
		if not arena.enemy_spawn_zone.has(cell.coordinate):
			arena.encounter_definition.forbidden_initial_spawn_cells.append(cell.coordinate)
	var folder := ProjectSettings.globalize_path(ROOT + str(spec.id))
	DirAccess.make_dir_recursive_absolute(folder)
	_save_reference(arena, spec)
	_save_json(ROOT + "%s/terrain_plan.json" % spec.id, _terrain_plan(spec))
	_save_json(ROOT + "%s/geometry_manifest.json" % spec.id, _manifest(arena, pits))
	var result := ResourceSaver.save(arena, arena.source_room_path)
	if result != OK:
		_errors.append("%s: save error %d" % [spec.id, result])


func _save_reference(arena: ArenaDefinition, spec: Dictionary) -> void:
	# Technical artwork reference for Studio. Runtime RegisteredTerrainBattle
	# draws the real floor/props and hides this guide after initialization.
	var palette: Array = PALETTES[spec.palette]
	var reference := Image.create(1920, 1200, false, Image.FORMAT_RGB8)
	reference.fill(Color(palette[0]))
	for cell in arena.cells:
		var center := arena.grid_origin + arena.axis_x * cell.coordinate.x + arena.axis_y * cell.coordinate.y
		var color := Color(palette[2])
		if cell.terrain_id == &"lava": color = Color("b95831")
		elif cell.terrain_id == &"ice": color = Color("82c3d5")
		for dy in range(-24, 25):
			var half_width := roundi(49.0 * (1.0 - absf(float(dy)) / 25.0))
			reference.fill_rect(Rect2i(roundi(center.x) - half_width, roundi(center.y) + dy, half_width * 2 + 1, 1), color)
		if arena.obstacle_at(cell.coordinate) != null:
			reference.fill_rect(Rect2i(Vector2i(center) - Vector2i(7, 7), Vector2i(14, 14)), Color(palette[1]))
	var status := reference.save_png(ProjectSettings.globalize_path(arena.background_path))
	if status != OK: _errors.append("%s: reference save %d" % [spec.id, status])


func _encounter(spec: Dictionary, number: int) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.encounter_id = StringName("catabase_%s" % spec.id)
	encounter.room_index = number
	encounter.base_xp = 160
	encounter.living_enemy_cap = spec.enemies.size()
	encounter.formation_profiles = [&"split", &"line"]
	encounter.minimum_path_distance_by_role = {}
	encounter.maximum_path_distance_by_role = {}
	var counts := {}
	for key in spec.enemies:
		counts[key] = int(counts.get(key, 0)) + 1
	for key in counts:
		var data := load(ENEMIES[key]) as UnitData
		encounter.roster_units.append(data)
		encounter.roster_counts.append(counts[key])
		encounter.minimum_path_distance_by_role[data.tactical_role_id] = 5
		encounter.maximum_path_distance_by_role[data.tactical_role_id] = 22
	return encounter


func _terrain_plan(spec: Dictionary) -> Dictionary:
	var palette: Array = PALETTES[spec.palette]
	return {
		"version": 1, "canvas_size": [1920, 1200],
		"geometry_manifest_path": "geometry_manifest.json",
		"water": {"color": palette[0]},
		"land": {"color": palette[0]},
		"land_polygon": [[0, 0], [1920, 0], [1920, 1200], [0, 1200]],
		"allowed_floor_polygon": [[0, 0], [1920, 0], [1920, 1200], [0, 1200]],
		"minimum_floor_margin_px": 30.0,
		"floor_palette": {"shade": palette[1], "body": palette[2], "light": palette[3], "painted_steps": 0.25, "bevel_flatten_strength": 0.82},
		"props_palette": {"ink": palette[0], "top": palette[3], "left": palette[2], "right": palette[1], "highlight": palette[3]},
		"pit_palette": {"floor": palette[0], "back_wall": palette[1], "left_wall": palette[1], "depth_native_px": 13},
		"ground_details": {"enabled": false},
		"combat_ground_band": {"enabled": false},
		"world_decor": [], "soil_patches": [], "shorelines": [],
		"metadata": {"biome": spec.palette, "art_method": "Existing Catabase terrain renderer, original authored topology and palette; dedicated environmental paintings remain future art work.", "tactical_intent": spec.intent},
	}


func _manifest(arena: ArenaDefinition, pits: Array) -> Dictionary:
	var floor: Array = []
	var obstacles: Array = []
	for cell in arena.cells:
		floor.append([cell.coordinate.x, cell.coordinate.y])
	for obstacle in arena.obstacles:
		obstacles.append({"id": str(obstacle.obstacle_id), "cells": [[obstacle.cell.x, obstacle.cell.y]], "blocks_line_of_sight": obstacle.blocks_line_of_sight})
	return {
		"arena_id": str(arena.arena_id), "title": arena.display_name,
		"geometry_version": 1, "image_size": [1920, 1200],
		"grid_size": [arena.grid_size.x, arena.grid_size.y],
		"grid_origin": [arena.grid_origin.x, arena.grid_origin.y],
		"axis_x": [arena.axis_x.x, arena.axis_x.y], "axis_y": [arena.axis_y.x, arena.axis_y.y],
		"floor_cells": floor, "obstacles": obstacles,
		"hero_spawns": arena.hero_spawn_zone.map(func(cell): return [cell.x, cell.y]),
		"enemy_spawns": arena.enemy_spawn_zone.map(func(cell): return [cell.x, cell.y]),
		"pits": [{"id": "open_recesses", "cells": pits}],
		"authoring_source": BLUEPRINT_PATH,
	}


func _save_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_errors.append("cannot write " + path)
		return
	file.store_string(JSON.stringify(data, "\t") + "\n")
