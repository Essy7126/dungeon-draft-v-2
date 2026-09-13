extends GutTest
const Cavern := preload("res://core/audio/cavern_ambience.gd")
const HaltAudio := preload("res://hub/painted_halt/halt_audio.gd")


func test_loop_routes_separately_and_releases_when_paused() -> void:
	var audio := Cavern.new()
	audio.fade_seconds = 0.05
	add_child_autofree(audio)
	await get_tree().create_timer(0.1).timeout
	assert_true(audio.playing)
	assert_eq(audio.bus, &"Ambience")
	assert_gte(AudioServer.get_bus_index(audio.bus), 0)
	assert_true(audio.stream.loop)
	assert_gt(audio.stream.get_length(), 30.0)
	assert_almost_eq(audio.volume_db, -6.0, 0.1)
	audio.stream_paused = true
	audio.dispose()
	audio.dispose()
	assert_false(audio.playing)
	assert_null(audio.stream)


func test_threshold_ambience_respects_mute_pause_and_reconfiguration() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var actor := Node2D.new()
	world.add_child(actor)
	var audio := HaltAudio.new()
	world.add_child(audio)
	var definition: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/halts/underworld_threshold_v1.json")
	)
	audio.configure(world, actor, definition, Vector2(1600, 900))
	audio.enable_cavern()
	audio.enable_cavern()
	assert_not_null(audio.cavern)
	assert_true(audio.cavern.playing)
	var retired: WeakRef = weakref(audio.cavern)
	audio.advance(0.0, false, false)
	assert_true(audio.cavern.stream_paused)
	audio.advance(0.0, true, true)
	assert_true(audio.cavern.stream_paused)
	audio.advance(0.0, false, true)
	assert_false(audio.cavern.stream_paused)
	audio.configure(world, actor, { "ambience": { "sources": [] } }, Vector2(1600, 900))
	assert_null(audio.cavern)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(retired.get_ref())
