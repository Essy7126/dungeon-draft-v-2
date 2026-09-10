extends Node
## World-space emitters follow the player's listener, independent of zoom.
## Authored short loops are generated reproducibly by synthesize_ambience.py.
const WATER := preload("res://asset/audio/halts/water.wav")
const FIRE := preload("res://asset/audio/halts/fire.wav")
const STEP := preload("res://asset/audio/halts/stone_step.wav")
var sources: Array[AudioStreamPlayer2D] = []
var steps: AudioStreamPlayer2D
var _distance := 0.0
var enabled := true
var _listener: AudioListener2D


func configure(world: Node2D, actor: Node2D, definition: Dictionary, extent: Vector2) -> void:
	dispose()
	_listener = AudioListener2D.new()
	actor.add_child(_listener)
	_listener.make_current()
	for entry: Dictionary in definition.get("ambience", { }).get("sources", []):
		var source := AudioStreamPlayer2D.new()
		source.name = str(entry.get("id", "AmbientSource"))
		var loop: AudioStreamWAV = (WATER if str(entry.get("kind", "fire")) == "water" else FIRE).duplicate()
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
		source.stream = loop
		source.position = Vector2(entry.point[0], entry.point[1]) * extent
		source.max_distance = float(entry.get("radius", 0.3)) * extent.x
		source.volume_db = clampf(float(entry.get("gain_db", -17.0)), -40.0, -6.0)
		source.attenuation = 1.5
		world.add_child(source)
		source.play(float(sources.size()) * 0.37)
		sources.append(source)
	steps = AudioStreamPlayer2D.new()
	steps.name = "StoneFootsteps"
	steps.stream = STEP
	steps.volume_db = -13
	actor.add_child(steps)
	enabled = true


func advance(distance: float, halted: bool, audible: bool) -> void:
	enabled = audible
	for source in sources:
		source.stream_paused = halted or not audible
	if steps == null:
		return
	steps.stream_paused = halted or not audible
	if halted:
		return
	_distance += distance
	if _distance >= 38.0:
		_distance = fposmod(_distance, 38.0)
		if audible:
			steps.play()


func _exit_tree() -> void:
	# The controller exits before its sibling world; detach audio while the
	# player nodes still belong to the tree, including paused playback.
	dispose()


func dispose() -> void:
	for source in sources:
		_release_player(source)
	sources.clear()
	_release_player(steps)
	steps = null
	if is_instance_valid(_listener):
		if _listener.is_inside_tree():
			_listener.clear_current()
		_listener.queue_free()
	_listener = null
	_distance = 0.0
	enabled = false


func _release_player(player: AudioStreamPlayer2D) -> void:
	if not is_instance_valid(player):
		return
	# Handle suspended playback as well as active playback during teardown.
	# Silence, unpause, stop, then detach the private WAV resource.
	player.volume_db = -80.0
	player.stream_paused = false
	player.stop()
	player.stream = null
	player.queue_free()
