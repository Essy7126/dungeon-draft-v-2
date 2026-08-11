@tool
class_name ArenaSpatialInteractiveDefinition
extends Resource

## Définition de catalogue d'un interactif spatial. Elle décrit les capacités
## certifiées sans prétendre fournir une implémentation de déplacement.

const CURRENT_SCHEMA_VERSION := 1

@export var schema_version := CURRENT_SCHEMA_VERSION
@export var stable_id: StringName = &"spatial_interactive"
@export var display_name := "Interactif spatial"
@export var texture: Texture2D = null
@export var traversal_contract: StringName = &"enter_cell"
@export var runtime_supported := false
@export var pathfinding_certified := false
@export var ai_certified := false
@export var editor_placeable := true
@export var production_placeable := false


func is_production_certified() -> bool:
	return runtime_supported and pathfinding_certified and ai_certified \
		and production_placeable

