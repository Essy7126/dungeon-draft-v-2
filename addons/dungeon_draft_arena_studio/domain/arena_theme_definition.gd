@tool
class_name ArenaThemeDefinition
extends Resource

const CURRENT_SCHEMA_VERSION := 1

@export var schema_version := CURRENT_SCHEMA_VERSION
@export var stable_id: StringName = &"theme"
@export var display_name := "Theme"
@export var icon: Texture2D = null
@export var aliases: Array[StringName] = []
@export var terrain_ids: Array[StringName] = []
@export var wall_ids: Array[StringName] = []
@export var surface_configs: Array[SurfaceConfig] = []
@export var tags: Array[StringName] = []
@export var editor_color := Color.WHITE
@export var compatibilities: Dictionary = {}


func validates() -> PackedStringArray:
	var errors := PackedStringArray()
	if stable_id == &"":
		errors.append("stable_id_missing")
	for terrain_id in terrain_ids:
		if not ArenaCatalogService.has_terrain(terrain_id):
			errors.append("unknown_terrain:%s" % terrain_id)
	for wall_id in wall_ids:
		if not ArenaCatalogService.has_wall(wall_id):
			errors.append("unknown_wall:%s" % wall_id)
	for config in surface_configs:
		if config == null:
			errors.append("surface_config_missing")
	return errors
