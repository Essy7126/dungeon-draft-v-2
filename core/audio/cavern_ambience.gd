extends AudioStreamPlayer
## Scene-owned environmental layer; independent of Music and gameplay cues.
@export var gain_db := -6.0
@export var fade_seconds := 2.5
var _fade: Tween


func _ready() -> void:
	bus = &"Ambience"
	var source := load("res://assets/audio/catabase/ambience/suspended_cavern.ogg") as AudioStreamOggVorbis
	if source == null:
		return
	var loop := source.duplicate() as AudioStreamOggVorbis
	loop.loop = true
	stream = loop
	volume_db = -70.0
	var ambience_rng := RandomNumberGenerator.new()
	ambience_rng.randomize()
	play(ambience_rng.randf_range(0.0, loop.get_length() * 0.8))
	_fade = create_tween()
	_fade.tween_property(self, "volume_db", gain_db, fade_seconds)


func dispose() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	volume_db = -80.0
	stream_paused = false
	stop()
	stream = null


func _exit_tree() -> void:
	dispose()
