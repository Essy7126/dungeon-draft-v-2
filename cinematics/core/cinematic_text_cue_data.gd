@tool
class_name CinematicTextCueData
extends Resource

@export var localization_key: StringName = &""
@export_multiline var fallback_text := ""
@export_range(0.0, 3600.0, 0.01) var start_time_seconds := 0.0
@export_range(0.0, 3600.0, 0.01) var end_time_seconds := 1.0
@export var style_id: StringName = &"narrative"
@export var normalized_position := Vector2(0.5, 0.82)
@export_range(0.0, 5.0, 0.01) var fade_in_seconds := 0.3
@export_range(0.0, 5.0, 0.01) var fade_out_seconds := 0.3
@export_range(-32, 32, 1) var layer := 0


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if localization_key == &"" and fallback_text.strip_edges().is_empty():
		errors.append("Une cue doit definir une cle de localisation ou un fallback.")
	if start_time_seconds < 0.0 or end_time_seconds <= start_time_seconds:
		errors.append("Les bornes temporelles de la cue sont invalides.")
	if style_id == &"":
		errors.append("Le style de la cue est absent.")
	if normalized_position.x < 0.0 or normalized_position.x > 1.0 \
			or normalized_position.y < 0.0 or normalized_position.y > 1.0:
		errors.append("La position normalisee de la cue doit rester dans l'ecran.")
	return errors

