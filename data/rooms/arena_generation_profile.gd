@tool
class_name ArenaGenerationProfile
extends Resource

## Fiche de reglages de la generation procedurale d'une arene.
## Elle ne genere rien elle-meme : elle indique seulement au futur generateur
## combien d'obstacles placer et quelles limites respecter.

@export_group("Activation")
@export var enabled := true

@export_group("Obstacles")
@export_range(0, 100, 1) var minimum_obstacle_count := 4
@export_range(0, 100, 1) var maximum_obstacle_count := 7
@export_range(0, 20, 1) var spawn_safety_distance := 3
@export_range(1, 20, 1) var minimum_feature_distance := 1
@export_range(0.0, 1.0, 0.01) var maximum_blocked_cell_ratio := 0.20

@export_group("Poids des types")
@export_range(0, 100, 1) var wall_weight := 4
@export_range(0, 100, 1) var hole_weight := 2
@export_range(0, 100, 1) var lava_weight := 2
@export_range(0, 100, 1) var ice_weight := 2
@export_range(0, 100, 1) var shadow_weight := 1
@export_range(0, 100, 1) var rune_weight := 1

@export_group("Validation")
@export_range(1, 1000, 1) var maximum_generation_attempts := 30

@export_group("Test reproductible")
@export var use_test_seed := false
@export var test_seed: int = 0


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if minimum_obstacle_count > maximum_obstacle_count:
		errors.append(
			"Le nombre minimal d'obstacles ne peut pas depasser le maximum."
		)
	if total_type_weight() <= 0:
		errors.append("Au moins un poids de type doit etre superieur a zero.")
	return errors


func total_type_weight() -> int:
	return wall_weight + hole_weight + lava_weight + ice_weight \
		+ shadow_weight + rune_weight
