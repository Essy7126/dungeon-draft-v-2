@tool
class_name ArenaDirectTestConfiguration
extends RefCounted

const TREE_META := &"arena_studio_test_options"


static func resolve(configuration: StringName) -> Dictionary:
	var result := {
		"active": true,
		"configuration": str(configuration),
		"applied_mode": "visual_only",
		"allow_empty_heroes": true,
		"spawn_heroes": false,
		"spawn_enemies": false,
		"deployment_enabled": false,
		"combat_enabled": false,
		"hud_enabled": false,
		"camera_mode": "STUDIO_MATCH",
		"comparison_resolution": "RUNTIME_EXACT",
		"draw_base_cells": false,
		"draw_grid_lines": false,
		"draw_cell_centers": false,
		"draw_map_bounds": false,
		"draw_logic_types": false,
		"draw_void_cells": false,
		"draw_coordinates": false,
		"draw_spawns": false,
		"draw_calibration": false,
	}
	match configuration:
		&"hero_trio", &"occlusion":
			result.applied_mode = "hero_preview"
			result.allow_empty_heroes = false
			result.spawn_heroes = true
		&"spawns", &"y_sort":
			result.applied_mode = "character_preview"
			result.allow_empty_heroes = false
			result.spawn_heroes = true
			result.spawn_enemies = true
			result.draw_spawns = configuration == &"spawns"
		&"real_encounter", &"movement", &"full_run":
			result.applied_mode = "full_combat"
			result.allow_empty_heroes = false
			result.spawn_heroes = true
			result.spawn_enemies = true
			result.deployment_enabled = true
			result.combat_enabled = true
			result.hud_enabled = true
		&"clicks":
			result.applied_mode = "grid_interaction"
			result.draw_grid_lines = true
			result.draw_cell_centers = true
		&"line_of_sight", &"obstacles":
			result.applied_mode = "logic_overlay"
			result.draw_grid_lines = true
			result.draw_logic_types = true
		&"terrains":
			result.applied_mode = "terrain_overlay"
			result.draw_logic_types = true
			result.draw_void_cells = true
		&"view", &"no_characters", _:
			pass
	return result


static func from_tree(tree: SceneTree) -> Dictionary:
	if tree == null or not tree.has_meta(TREE_META):
		return {}
	var value = tree.get_meta(TREE_META)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
