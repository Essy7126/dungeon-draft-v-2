class_name SurfaceConfig
extends Resource

## Configuration data-driven d'une surface temporaire. Aucun de ces champs ne
## remplace le CellType ou le cout de deplacement du GridData partage.

@export var surface: CellSurfaceState.DynamicSurface = CellSurfaceState.DynamicSurface.NONE
@export var display_name := "NONE"
@export var texture: Texture2D = null
@export_range(0, 20, 1) var duration_turns := 0
@export_range(0, 100, 1) var turn_start_damage := 0
@export var walkable := true
@export_range(1, 10, 1) var movement_cost := 1
@export var gameplay_flags: Dictionary = {}


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("display_name est requis.")
	if texture == null:
		errors.append("Une texture de surface est requise.")
	if not walkable:
		errors.append("Les surfaces dynamiques de ce prototype doivent rester praticables.")
	if movement_cost != 1:
		errors.append("Le cout de deplacement doit rester inchange (1).")
	return errors

