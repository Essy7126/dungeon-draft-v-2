@tool
class_name ArenaTerrainDefinition
extends Resource

const CURRENT_SCHEMA_VERSION := 1

@export var schema_version := CURRENT_SCHEMA_VERSION
@export var stable_id: StringName = &"terrain"
@export var display_name := "Terrain"
@export var icon: Texture2D = null
@export var base_texture: Texture2D = null
@export var overlay_texture: Texture2D = null
@export var cell_type: int = GridData.CellType.NORMAL
@export var walkable := true
@export_range(1, 10, 1) var movement_cost := 1
@export var surface_configs: Array[SurfaceConfig] = []
@export var tags: Array[StringName] = []
@export var editor_color := Color.WHITE
@export var compatibilities: Dictionary = {}
@export var dynamic_catalog := true
@export var lab_surface := -1
@export var interaction_element: StringName = &"NONE"


func to_legacy_entry() -> Dictionary:
	var effects: Array[StringName] = []
	for config in surface_configs:
		if config != null and config.surface != CellSurfaceState.DynamicSurface.NONE:
			effects.append(StringName(config.display_name.to_lower()))
	return {
		"name": display_name,
		"cell_type": cell_type,
		"walkable": walkable,
		"movement_cost": movement_cost,
		"visual": base_texture.resource_path if base_texture != null else "",
		"overlay": overlay_texture.resource_path if overlay_texture != null else "",
		"effects": effects,
		"color": editor_color.to_html(false),
		"dynamic": dynamic_catalog,
		"schema_version": schema_version,
		"definition_path": resource_path,
	}
