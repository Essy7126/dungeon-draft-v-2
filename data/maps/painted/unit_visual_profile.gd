class_name UnitVisualProfile
extends Resource

## Reglage visuel par famille. Il ne contient volontairement aucune donnee de
## gameplay : la racine UnitView et sa cellule logique ne sont jamais modifiees.

@export var family_id: StringName = &"unit"
@export var unit_ids: Array[StringName] = []
@export_range(1.0, 2.0, 0.01) var base_visual_scale := 1.0
@export_range(1.0, 2.0, 0.01) var minimum_visual_scale := 1.0
@export_range(1.0, 2.0, 0.01) var maximum_visual_scale := 1.5
@export_range(0.5, 1.5, 0.01) var contact_shadow_scale := 1.0
@export_range(0.0, 1.0, 0.01) var contact_shadow_opacity := 0.36


func matches(unit_id: StringName) -> bool:
	return unit_id in unit_ids


func final_visual_scale(room_global_multiplier: float) -> float:
	return clampf(
		base_visual_scale * room_global_multiplier,
		minimum_visual_scale,
		maximum_visual_scale
	)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if family_id == &"":
		errors.append("family_id est requis.")
	if unit_ids.is_empty():
		errors.append("unit_ids ne peut pas etre vide.")
	if minimum_visual_scale > maximum_visual_scale:
		errors.append("minimum_visual_scale depasse maximum_visual_scale.")
	if base_visual_scale < minimum_visual_scale \
			or base_visual_scale > maximum_visual_scale:
		errors.append("base_visual_scale doit rester dans les bornes de la famille.")
	return errors
