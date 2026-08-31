@tool
class_name CinematicSequenceData
extends Resource

enum Continuation {
	START_CONFIGURED_RUN = 0,
	RETURN_TO_CALLER = 1,
}

@export var sequence_id: StringName = &""
@export_range(0.01, 3600.0, 0.01) var duration_seconds := 1.0
@export var frames: Array[CinematicFrameData] = []
@export var text_cues: Array[CinematicTextCueData] = []
@export var music_stream: AudioStream = null
@export_range(-40.0, 0.0, 0.5) var music_volume_db := -12.0
@export_range(0.0, 10.0, 0.05) var music_fade_in_seconds := 0.8
@export_range(0.0, 3600.0, 0.05) var music_fade_out_start_seconds := 0.0
@export_range(0.0, 10.0, 0.05) var music_fade_out_seconds := 0.8
@export var narration_stream: AudioStream = null
@export_range(-40.0, 0.0, 0.5) var narration_volume_db := 0.0
@export var allow_skip := true
@export_range(0.0, 5.0, 0.05) var opening_fade_seconds := 0.8
@export_range(0.0, 5.0, 0.05) var exit_fade_seconds := 0.8
@export_enum("Start configured run", "Return to caller") var continuation: int = (
	Continuation.START_CONFIGURED_RUN
)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if sequence_id == &"":
		errors.append("sequence_id ne peut pas etre vide.")
	if duration_seconds <= 0.0:
		errors.append("La duree de la sequence doit etre positive.")
	if frames.is_empty():
		errors.append("La sequence doit contenir au moins une frame.")
	var previous_end := 0.0
	for index in range(frames.size()):
		var frame := frames[index]
		if frame == null:
			errors.append("La frame %d est absente." % index)
			continue
		for error in frame.validation_errors():
			errors.append("Frame %d : %s" % [index, error])
		if not is_equal_approx(frame.start_time_seconds, previous_end):
			errors.append("La frame %d ne suit pas la borne precedente." % index)
		previous_end = frame.end_time_seconds
	if not frames.is_empty() and not is_equal_approx(previous_end, duration_seconds):
		errors.append("La derniere frame doit finir a la duree de la sequence.")
	for index in range(text_cues.size()):
		var cue := text_cues[index]
		if cue == null:
			errors.append("La cue %d est absente." % index)
			continue
		for error in cue.validation_errors():
			errors.append("Cue %d : %s" % [index, error])
		if cue.end_time_seconds > duration_seconds + 0.001:
			errors.append("La cue %d depasse la duree de la sequence." % index)
	if music_fade_out_start_seconds > duration_seconds:
		errors.append("Le fondu musical de sortie commence apres la sequence.")
	if music_fade_out_start_seconds + music_fade_out_seconds \
			> duration_seconds + 0.001:
		errors.append("Le fondu musical de sortie depasse la sequence.")
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()

