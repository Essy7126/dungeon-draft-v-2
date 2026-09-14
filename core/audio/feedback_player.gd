extends Node
## Bounded, local variation counters never consume the gameplay random generator.
signal played(cue: StringName)
const Catalog := preload("res://core/audio/feedback_cues.gd")
var voices: Array[AudioStreamPlayer] = []
var _last: Dictionary = { }
var _variants: Dictionary = { }
var _streams: Dictionary = { }


func _ready() -> void:
	for index in 4:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		voices.append(voice)


func play(cue: StringName, gain_db: float = 0.0) -> bool:
	if not can_process() or not Catalog.CUES.has(cue):
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last.get(cue, -10000)) < 140:
		return false
	for voice in voices:
		if voice.playing:
			continue
		var choices: Array = Catalog.CUES[cue]
		var variant := int(_variants.get(cue, 0)) % choices.size()
		var path: String = choices[variant]
		if not _streams.has(path):
			_streams[path] = load(path) as AudioStream
		if _streams[path] == null:
			return false
		voice.stream = _streams[path]
		voice.volume_db = clampf(gain_db, -60.0, 0.0)
		voice.play()
		_last[cue] = now
		_variants[cue] = variant + 1
		played.emit(cue)
		return true
	return false


func stop() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null


func _exit_tree() -> void:
	stop()
