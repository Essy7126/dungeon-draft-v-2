extends GutTest

const Audio := preload("res://hub/painted_halt/halt_audio.gd")


func _audio_tick() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame


func test_two_paused_visits_release_private_wavs_and_all_playbacks() -> void:
	var retiring: Array[WeakRef] = []
	for cycle in 2:
		var container := Node2D.new()
		add_child_autofree(container)
		var world := Node2D.new()
		container.add_child(world)
		var actor := Node2D.new()
		world.add_child(actor)
		var audio := Audio.new()
		# Match LivingHalt ownership: world first, controller next.
		container.add_child(audio)
		var definition := { "ambience": { "sources": [] } }
		for index in 4:
			definition.ambience.sources.append(
				{
					"id": "emitter_%d" % index,
					"kind": "water" if index < 2 else "fire",
					"point": [0.1 + index * 0.2, 0.3],
					"radius": 0.4,
					"gain_db": -17,
				}
			)
		audio.configure(world, actor, definition, Vector2(1600, 900))
		await _audio_tick()
		assert_eq(audio.sources.size(), 4)
		for source: AudioStreamPlayer2D in audio.sources:
			assert_true(source.playing)
			retiring.append(weakref(source.stream))
			if source.playing:
				retiring.append(weakref(source.get_stream_playback()))
		audio.advance(38.0, false, true)
		await _audio_tick()
		assert_true(audio.steps.playing)
		if audio.steps.playing:
			retiring.append(weakref(audio.steps.get_stream_playback()))
		audio.advance(0.0, true, false)
		await _audio_tick()
		for source: AudioStreamPlayer2D in audio.sources:
			assert_true(not source.playing or source.stream_paused)
		if cycle == 0:
			var players: Array = audio.sources.duplicate()
			players.append(audio.steps)
			audio.dispose()
			assert_true(audio.sources.is_empty())
			assert_null(audio.steps)
			for player: AudioStreamPlayer2D in players:
				assert_false(player.playing)
				assert_null(player.stream)
			# Closing twice must be harmless.
			audio.dispose()
		# Cycle 2 exercises automatic controller _exit_tree cleanup while paused.
		container.queue_free()
		for attempt in 30:
			await _audio_tick()
			if retiring.all(
				func(reference: WeakRef) -> bool:
					return reference.get_ref() == null,
			):
				break
		assert_true(
			retiring.all(
				func(reference: WeakRef) -> bool:
					return reference.get_ref() == null,
			),
			"Visit %d must release both private WAV resources and server playbacks." % cycle,
		)
