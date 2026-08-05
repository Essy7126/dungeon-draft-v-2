@tool
class_name WallConfig
extends Resource

## Configuration reusable d'un mur temporaire. Aucune valeur de ce fichier
## n'est branchee sur l'equilibrage des salles de production.

@export var variant_id: StringName = &"base"
@export_range(1, 999, 1) var max_hp := 30
## -1 = infini, 0 = expire immediatement, valeur positive = tours restants.
@export_range(-1, 99, 1) var duration_turns := -1
@export var blocks_movement := true
@export var blocks_line_of_sight := true
@export var blocks_projectiles := true
@export_range(0, 99, 1) var damage_on_adjacent_turn := 0
@export var damage_element: StringName = &"NONE"
@export var vulnerable_to: Array[StringName] = []
@export var resistant_to: Array[StringName] = []
@export var destroyed_surface_result: StringName = &"BASE"
@export var texture: Texture2D = null
@export var spawn_vfx: PackedScene = null
@export var idle_vfx: PackedScene = null
@export var destroy_vfx: PackedScene = null


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if variant_id == &"":
		errors.append("variant_id est requis.")
	if max_hp <= 0:
		errors.append("max_hp doit etre strictement positif.")
	if duration_turns < -1:
		errors.append("duration_turns doit valoir -1 ou une valeur positive.")
	if texture == null:
		errors.append("texture est requise.")
	return errors
