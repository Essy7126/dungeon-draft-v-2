@tool
class_name ArenaSurfaceVisualDefinition
extends Resource

## Catalogue visuel des états de combat qui ne sont pas des sols persistants
## d'ArenaDefinition. La mécanique reste portée par TerrainEffectData et
## TerrainSurfaceRuntimeService.

enum Category {
	TEMPORARY_SURFACE,
	VISUAL_REACTION,
}

const CURRENT_SCHEMA_VERSION := 1

@export var schema_version := CURRENT_SCHEMA_VERSION
@export var stable_id: StringName = &"surface_visual"
@export var display_name := "Surface"
@export var texture: Texture2D = null
@export var category: Category = Category.TEMPORARY_SURFACE
@export var surface_id: StringName = &""
@export var reaction_id: StringName = &""
@export_range(0.0, 10.0, 0.05) var display_duration_seconds := 0.0
@export var runtime_supported := false
@export var editor_placeable := false
@export var production_placeable := false
@export_file("*.tres", "*.gd") var canonical_resource_path := ""


func category_name() -> StringName:
	return &"temporary_surface" if category == Category.TEMPORARY_SURFACE \
		else &"visual_reaction"

