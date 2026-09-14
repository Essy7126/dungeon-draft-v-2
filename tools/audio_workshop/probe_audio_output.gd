extends SceneTree
## Decode and mix through the real audio driver; never changes OS audio settings.
var player: AudioStreamPlayer
var capture: AudioEffectCapture
var output := "res://artifacts/audio/output_probe.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	player = AudioStreamPlayer.new()
	root.add_child(player)
	player.bus = &"Master"
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0, capture)
	var results: Array = []
	for cue in ["strike", "guard", "shot", "dash"]:
		player.stream = AudioStreamWAV.load_from_file(
			ProjectSettings.globalize_path("res://artifacts/audio/soft_v4/%s.wav" % cue)
		)
		player.volume_db = linear_to_db(0.65)
		capture.clear_buffer()
		player.play()
		await create_timer(1.1).timeout
		var frames := capture.get_buffer(capture.get_frames_available())
		var peak := 0.0
		var energy := 0.0
		for frame: Vector2 in frames:
			peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
			energy += frame.length_squared() * 0.5
		results.append(
			{
				"cue": cue,
				"frames": frames.size(),
				"peak": peak,
				"rms": sqrt(energy / maxi(1, frames.size())),
				"stream_length": player.stream.get_length(),
				"mix_audible": peak > 0.001,
			}
		)
	var report := {
		"driver": AudioServer.get_driver_name(),
		"device": AudioServer.output_device,
		"devices": AudioServer.get_output_device_list(),
		"master_mute": AudioServer.is_bus_mute(0),
		"master_volume_db": AudioServer.get_bus_volume_db(0),
		"results": results,
	}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	player.stop()
	player.stream = null
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	capture = null
	player.queue_free()
	await process_frame
	quit()
