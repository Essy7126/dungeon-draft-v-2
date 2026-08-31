@tool
class_name CinematicFrameData
extends Resource

enum TransitionMode {
	CUT = 0,
	CROSSFADE = 1,
}

@export var texture: Texture2D = null
@export_range(0.0, 3600.0, 0.01) var start_time_seconds := 0.0
@export_range(0.0, 3600.0, 0.01) var end_time_seconds := 1.0
@export_enum("Cut", "Crossfade") var transition_mode: int = TransitionMode.CROSSFADE
@export_range(0.0, 5.0, 0.01) var transition_duration_seconds := 0.8
@export var ken_burns_enabled := true
@export var ken_burns_direction := Vector2.ZERO
@export_range(1.0, 1.04, 0.001) var start_zoom := 1.0
@export_range(1.0, 1.04, 0.001) var end_zoom := 1.04


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if texture == null:
		errors.append("La texture de la frame est absente.")
	if start_time_seconds < 0.0 or end_time_seconds <= start_time_seconds:
		errors.append("Les bornes temporelles de la frame sont invalides.")
	if transition_mode == TransitionMode.CROSSFADE \
			and transition_duration_seconds <= 0.0:
		errors.append("Une transition CROSSFADE doit avoir une duree positive.")
	if start_zoom < 1.0 or start_zoom > 1.04 \
			or end_zoom < 1.0 or end_zoom > 1.04:
		errors.append("Le zoom Ken Burns doit rester compris entre 1.0 et 1.04.")
	return errors

