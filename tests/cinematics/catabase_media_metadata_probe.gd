extends SceneTree

const SEQUENCE_PATH := "res://cinematics/catabase/catabase_intro_v4.tres"


func _init() -> void:
	var sequence := load(SEQUENCE_PATH) as CinematicSequenceData
	if sequence == null:
		push_error("Catabase metadata : sequence introuvable.")
		quit(2)
		return
	var frames: Array[Dictionary] = []
	for frame in sequence.frames:
		frames.append({
			"path": frame.texture.resource_path,
			"width": frame.texture.get_width(),
			"height": frame.texture.get_height(),
		})
	print(JSON.stringify({
		"duration_seconds": sequence.duration_seconds,
		"music_duration_seconds": (
			sequence.music_stream.get_length()
			if sequence.music_stream != null else 0.0
		),
		"frames": frames,
	}))
	quit()

