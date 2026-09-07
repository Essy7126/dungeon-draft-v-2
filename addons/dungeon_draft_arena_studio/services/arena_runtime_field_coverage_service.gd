@tool
class_name ArenaRuntimeFieldCoverageService
extends RefCounted

## Inventaire explicite des champs exposes par Arena Studio. Ce service ne
## deduit jamais qu'un champ est fonctionnel : chaque propriete stockee doit
## posseder une classification documentee.

enum Classification {
	RUNTIME_CONSUMED,
	EDITOR_ONLY,
	MANIFEST_ONLY,
	FUTURE_EXPLICIT,
	UNSUPPORTED,
	UNKNOWN,
}

const CLASSIFICATION_NAMES := [
	"RUNTIME_CONSUMED",
	"EDITOR_ONLY",
	"MANIFEST_ONLY",
	"FUTURE_EXPLICIT",
	"UNSUPPORTED",
	"UNKNOWN",
]

const GAMEPLAY_FIELDS := {
	"ArenaDefinition.cells": true,
	"ArenaDefinition.obstacles": true,
	"ArenaDefinition.spawns": true,
	"ArenaDefinition.objectives": true,
	"ArenaDefinition.vortex_pairs": true,
	"ArenaDefinition.vortex_networks": true,
	"ArenaDefinition.encounter_definition": true,
	"ArenaCellDefinition.defined": true,
	"ArenaCellDefinition.playable": true,
	"ArenaCellDefinition.border": true,
	"ArenaCellDefinition.cell_type": true,
	"ArenaCellDefinition.terrain_id": true,
	"ArenaObstacleDefinition.preset": true,
	"ArenaObstacleDefinition.blocks_movement": true,
	"ArenaObstacleDefinition.blocks_line_of_sight": true,
	"ArenaObstacleDefinition.blocks_projectiles": true,
	"ArenaObstacleDefinition.blocks_push": true,
	"ArenaSpawnDefinition.kind": true,
	"ArenaSpawnDefinition.unit_id": true,
	"ArenaSpawnDefinition.required": true,
	"ArenaSpawnDefinition.group_id": true,
	"ArenaObjectiveDefinition.objective_type": true,
	"ArenaObjectiveDefinition.required": true,
	"ArenaDecorationDefinition.gameplay_preset": true,
	"ArenaVortexPairDefinition.entry_cell": true,
	"ArenaVortexPairDefinition.exit_cell": true,
	"ArenaVortexPairDefinition.traversal_contract": true,
	"ArenaVortexPairDefinition.bidirectional": true,
	"ArenaVortexPairDefinition.runtime_enabled": true,
}

const RULES := {
	"ArenaDefinition": {
		# RoomData herite : donnees effectivement transmises au runtime.
		"room_name": Classification.RUNTIME_CONSUMED,
		"background_image": Classification.RUNTIME_CONSUMED,
		"particles_scene": Classification.RUNTIME_CONSUMED,
		"battle_scene": Classification.RUNTIME_CONSUMED,
		"arena_generation_profile": Classification.RUNTIME_CONSUMED,
		"arena_visual_profile": Classification.RUNTIME_CONSUMED,
		"grid_layout": Classification.RUNTIME_CONSUMED,
		"painted_map_visual_data": Classification.RUNTIME_CONSUMED,
		"encounter_definition": Classification.RUNTIME_CONSUMED,
		"waves": Classification.RUNTIME_CONSUMED,
		"minimum_wave_count": Classification.RUNTIME_CONSUMED,
		"maximum_wave_count": Classification.RUNTIME_CONSUMED,
		"ultimate_reward_base_chance": Classification.RUNTIME_CONSUMED,
		"ultimate_reward_min_gain_per_wave": Classification.RUNTIME_CONSUMED,
		"ultimate_reward_max_gain_per_wave": Classification.RUNTIME_CONSUMED,
		"enemies": Classification.RUNTIME_CONSUMED,
		"hero_spawn_zone": Classification.RUNTIME_CONSUMED,
		"enemy_spawn_zone": Classification.RUNTIME_CONSUMED,
		# Source Arena Studio.
		"schema_version": Classification.MANIFEST_ONLY,
		"arena_id": Classification.RUNTIME_CONSUMED,
		"display_name": Classification.RUNTIME_CONSUMED,
		"visual_mode": Classification.RUNTIME_CONSUMED,
		"theme_id": Classification.RUNTIME_CONSUMED,
		"modular_visual_profile": Classification.RUNTIME_CONSUMED,
		"background_path": Classification.RUNTIME_CONSUMED,
		"source_image_size": Classification.RUNTIME_CONSUMED,
		"grid_size": Classification.RUNTIME_CONSUMED,
		"grid_origin": Classification.RUNTIME_CONSUMED,
		"axis_x": Classification.RUNTIME_CONSUMED,
		"axis_y": Classification.RUNTIME_CONSUMED,
		"image_offset": Classification.RUNTIME_CONSUMED,
		"image_scale": Classification.RUNTIME_CONSUMED,
		"foreground_path": Classification.RUNTIME_CONSUMED,
		"occlusion_mask_path": Classification.RUNTIME_CONSUMED,
		"foreground_offset": Classification.RUNTIME_CONSUMED,
		"foreground_scale": Classification.RUNTIME_CONSUMED,
		"foreground_occluder_polygon": Classification.RUNTIME_CONSUMED,
		"foreground_occluder_sort_y": Classification.RUNTIME_CONSUMED,
		"foreground_full_hide_rect": Classification.RUNTIME_CONSUMED,
		"camera_offset": Classification.RUNTIME_CONSUMED,
		"camera_zoom": Classification.RUNTIME_CONSUMED,
		"camp_orientation": Classification.EDITOR_ONLY,
		"border_thickness": Classification.EDITOR_ONLY,
		"cells": Classification.RUNTIME_CONSUMED,
		"obstacles": Classification.RUNTIME_CONSUMED,
		"spawns": Classification.RUNTIME_CONSUMED,
		"objectives": Classification.RUNTIME_CONSUMED,
		"decorations": Classification.RUNTIME_CONSUMED,
		"vortex_pairs": Classification.RUNTIME_CONSUMED,
		"vortex_networks": Classification.RUNTIME_CONSUMED,
		"calibration_cells": Classification.EDITOR_ONLY,
		"calibration_pixels": Classification.EDITOR_ONLY,
		"presentation_profile_path": Classification.RUNTIME_CONSUMED,
		"registered_terrain_plan_path": Classification.RUNTIME_CONSUMED,
		"source_room_path": Classification.MANIFEST_ONLY,
		"source_visual_path": Classification.MANIFEST_ONLY,
		"intentionally_isolated_cells": Classification.EDITOR_ONLY,
		"production_notes": Classification.EDITOR_ONLY,
	},
	"ArenaCellDefinition": {
		"coordinate": Classification.RUNTIME_CONSUMED,
		"defined": Classification.RUNTIME_CONSUMED,
		"playable": Classification.RUNTIME_CONSUMED,
		"border": Classification.RUNTIME_CONSUMED,
		"cell_type": Classification.RUNTIME_CONSUMED,
		"terrain_id": Classification.RUNTIME_CONSUMED,
		"production_note": Classification.EDITOR_ONLY,
	},
	"ArenaObstacleDefinition": {
		"obstacle_id": Classification.MANIFEST_ONLY,
		"cell": Classification.RUNTIME_CONSUMED,
		"wall_id": Classification.RUNTIME_CONSUMED,
		"wall_config": Classification.RUNTIME_CONSUMED,
		"visual_variant": Classification.FUTURE_EXPLICIT,
		"orientation": Classification.FUTURE_EXPLICIT,
		"preset": Classification.EDITOR_ONLY,
		"blocks_movement": Classification.RUNTIME_CONSUMED,
		"blocks_line_of_sight": Classification.RUNTIME_CONSUMED,
		"blocks_projectiles": Classification.FUTURE_EXPLICIT,
		"blocks_push": Classification.FUTURE_EXPLICIT,
	},
	"ArenaSpawnDefinition": {
		"spawn_id": Classification.MANIFEST_ONLY,
		"kind": Classification.RUNTIME_CONSUMED,
		"unit_id": Classification.FUTURE_EXPLICIT,
		"cell": Classification.RUNTIME_CONSUMED,
		"facing": Classification.FUTURE_EXPLICIT,
		"required": Classification.FUTURE_EXPLICIT,
		"group_id": Classification.FUTURE_EXPLICIT,
	},
	"ArenaObjectiveDefinition": {
		"objective_id": Classification.MANIFEST_ONLY,
		"cell": Classification.RUNTIME_CONSUMED,
		"objective_type": Classification.FUTURE_EXPLICIT,
		"required": Classification.FUTURE_EXPLICIT,
		"description": Classification.MANIFEST_ONLY,
	},
	"ArenaDecorationDefinition": {
		"decoration_id": Classification.MANIFEST_ONLY,
		"scene_path": Classification.RUNTIME_CONSUMED,
		"visual_variant": Classification.RUNTIME_CONSUMED,
		"cell": Classification.RUNTIME_CONSUMED,
		"local_offset": Classification.RUNTIME_CONSUMED,
		"rotation_degrees": Classification.RUNTIME_CONSUMED,
		"visual_scale": Classification.RUNTIME_CONSUMED,
		"layer": Classification.RUNTIME_CONSUMED,
		"y_sort": Classification.RUNTIME_CONSUMED,
		"gameplay_preset": Classification.FUTURE_EXPLICIT,
	},
	"ArenaVortexPairDefinition": {
		"schema_version": Classification.MANIFEST_ONLY,
		"pair_id": Classification.MANIFEST_ONLY,
		"entry_cell": Classification.RUNTIME_CONSUMED,
		"exit_cell": Classification.RUNTIME_CONSUMED,
		"traversal_contract": Classification.RUNTIME_CONSUMED,
		"bidirectional": Classification.RUNTIME_CONSUMED,
		"runtime_enabled": Classification.RUNTIME_CONSUMED,
	},
	"ArenaModularVisualProfile": {
		"theme_id": Classification.RUNTIME_CONSUMED,
		"terrain_ids": Classification.RUNTIME_CONSUMED,
		"wall_ids": Classification.RUNTIME_CONSUMED,
		"hybrid_floor_policy": Classification.RUNTIME_CONSUMED,
		"base_terrain_id": Classification.RUNTIME_CONSUMED,
		"tile_visual_profile": Classification.RUNTIME_CONSUMED,
		"background_texture": Classification.FUTURE_EXPLICIT,
		"foreground_texture": Classification.FUTURE_EXPLICIT,
		"environment_scene": Classification.FUTURE_EXPLICIT,
		"prop_scenes": Classification.FUTURE_EXPLICIT,
		"ambient_color": Classification.FUTURE_EXPLICIT,
		"ambient_energy": Classification.FUTURE_EXPLICIT,
		"camera_offset": Classification.RUNTIME_CONSUMED,
		"camera_zoom": Classification.RUNTIME_CONSUMED,
	},
}


static func scan() -> Dictionary:
	var entries: Array[Dictionary] = []
	_scan_resource("ArenaDefinition", ArenaDefinition.new(), entries)
	_scan_resource("ArenaCellDefinition", ArenaCellDefinition.new(), entries)
	_scan_resource("ArenaObstacleDefinition", ArenaObstacleDefinition.new(), entries)
	_scan_resource("ArenaSpawnDefinition", ArenaSpawnDefinition.new(), entries)
	_scan_resource("ArenaObjectiveDefinition", ArenaObjectiveDefinition.new(), entries)
	_scan_resource("ArenaDecorationDefinition", ArenaDecorationDefinition.new(), entries)
	_scan_resource("ArenaVortexPairDefinition", ArenaVortexPairDefinition.new(), entries)
	_scan_resource("ArenaModularVisualProfile", ArenaModularVisualProfile.new(), entries)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.key) < str(b.key)
	)
	var counts := {}
	for name in CLASSIFICATION_NAMES:
		counts[name] = 0
	var unknown: Array[Dictionary] = []
	var unsupported_gameplay: Array[Dictionary] = []
	for entry in entries:
		var name := str(entry.classification)
		counts[name] = int(counts.get(name, 0)) + 1
		if name == "UNKNOWN":
			unknown.append(entry)
		if name == "UNSUPPORTED" and bool(entry.gameplay):
			unsupported_gameplay.append(entry)
	return {
		"entries": entries,
		"counts": counts,
		"unknown": unknown,
		"unsupported_gameplay": unsupported_gameplay,
		"production_gate_valid": unknown.is_empty() and unsupported_gameplay.is_empty(),
	}


static func classification_for(type_name: String, property_name: StringName) -> int:
	# Metadonnees natives de Resource, stockees par Godot mais sans semantique
	# arena. Elles restent visibles dans le rapport au lieu d'etre filtrees.
	if property_name in [&"resource_name", &"resource_local_to_scene"]:
		return Classification.EDITOR_ONLY
	var rules := RULES.get(type_name, {}) as Dictionary
	return int(rules.get(str(property_name), Classification.UNKNOWN))


static func _scan_resource(
		type_name: String,
		resource: Resource,
		entries: Array[Dictionary]
	) -> void:
	for property in resource.get_property_list():
		var usage := int(property.get("usage", 0))
		var property_name := StringName(property.get("name", ""))
		if property_name == &"script" or not (usage & PROPERTY_USAGE_STORAGE):
			continue
		var classification := classification_for(type_name, property_name)
		var key := "%s.%s" % [type_name, property_name]
		entries.append({
			"key": key,
			"type": type_name,
			"property": str(property_name),
			"classification": CLASSIFICATION_NAMES[classification],
			"gameplay": GAMEPLAY_FIELDS.has(key),
		})
