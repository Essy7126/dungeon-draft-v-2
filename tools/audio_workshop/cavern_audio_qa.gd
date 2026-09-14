extends Node
## Isolated WASAPI check of the production audio controllers, without run inventory.
var output := ""
var report := { "passed": true, "checks": [], "peaks": { } }


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://artifacts/") or ".." in output:
		get_tree().quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	add_child(world)
	var actor := Node2D.new()
	world.add_child(actor)
	var halt := preload("res://hub/painted_halt/halt_audio.gd").new()
	world.add_child(halt)
	halt.configure(world, actor, { "ambience": { "sources": [] } }, Vector2(1600, 900))
	halt.enable_cavern()
	await _measure(halt.cavern, "threshold_controller")
	halt.advance(0.0, false, false)
	_check(halt.cavern.stream_paused, "halt mute suspends cavern")
	halt.advance(0.0, false, true)
	_check(not halt.cavern.stream_paused, "halt unmute restores cavern")
	var retiring: WeakRef = weakref(halt.cavern)
	halt.dispose()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(retiring.get_ref() == null, "halt controller releases player")
	var combat := preload("res://battle/audio/catabase_battle_audio.gd").new()
	world.add_child(combat)
	await _measure(combat.cavern, "combat_controller")
	combat.dispose()
	_check(
		combat.cavern.stream == null and not combat.cavern.playing,
		"combat dispose silences cavern",
	)
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	get_tree().quit(0 if report.passed else 1)


func _measure(player: AudioStreamPlayer, label: String) -> void:
	await get_tree().create_timer(2.8).timeout
	_check(
		player.playing and player.bus == &"Ambience" and player.stream.loop,
		label + " production loop",
	)
	var bus_index := AudioServer.get_bus_index(&"Ambience")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(bus_index, capture)
	player.seek(player.stream.get_length() - 0.3)
	await get_tree().create_timer(1.0).timeout
	var peak := 0.0
	for frame: Vector2 in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	report.peaks[label] = peak
	_check(peak > 0.0001 and peak < 0.16, label + " real quiet signal")
	_check(player.get_playback_position() < 2.0, label + " loop wrap")
	AudioServer.remove_bus_effect(bus_index, AudioServer.get_bus_effect_count(bus_index) - 1)


func _check(ok: bool, label: String) -> void:
	report.checks.append({ "label": label, "passed": ok })
	report.passed = report.passed and ok
