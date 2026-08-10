@tool
class_name ArenaWallDefinition
extends Resource

const CURRENT_SCHEMA_VERSION := 1

@export var schema_version := CURRENT_SCHEMA_VERSION
@export var stable_id: StringName = &"wall"
@export var display_name := "Mur"
@export var icon: Texture2D = null
@export var base_texture: Texture2D = null
@export var overlay_texture: Texture2D = null
@export var wall_config: WallConfig = null
@export var variant := DynamicWall.WallVariant.BASE
@export var tags: Array[StringName] = []
@export var editor_color := Color.WHITE
@export var compatibilities: Dictionary = {}


func to_legacy_entry() -> Dictionary:
	return {
		"name": display_name,
		"config": wall_config,
		"variant": variant,
		"visual": base_texture.resource_path if base_texture != null else "",
		"color": editor_color.to_html(false),
		"schema_version": schema_version,
		"definition_path": resource_path,
	}
