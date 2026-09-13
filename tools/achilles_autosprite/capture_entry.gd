extends SceneTree

const OUTPUT := "res://artifacts/dev/achilles_autosprite/entry/"
var checks: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var selection = load("res://ui/selection/CharacterSelectionScreen.tscn").instantiate()
	root.add_child(selection)
	current_scene = selection
	await create_timer(0.8).timeout
	var entry: Dictionary = selection.get_selected_entry()
	checks.append({ "check": "classic_selected", "ok": str(entry.id) == "achilles" })
	checks.append(
		{
			"check": "new_preview",
			"ok": entry.unit.preview_sprite_frames.resource_path
			== "res://assets/characters/Achilles/autosprite_v1/sprite_frames.tres",
		}
	)
	await _capture("selection")
	current_scene = null
	selection.queue_free()
	await process_frame
	var threshold = load("res://hub/catabase_threshold/CatabaseThreshold.tscn").instantiate()
	threshold.audio_enabled = false
	root.add_child(threshold)
	current_scene = threshold
	var deadline := Time.get_ticks_msec() + 15000
	while not threshold.is_ready_for_play() and Time.get_ticks_msec() < deadline:
		await process_frame
	checks.append({ "check": "real_threshold_ready", "ok": threshold.is_ready_for_play() })
	if threshold.is_ready_for_play():
		checks.append(
			{ "check": "new_actor", "ok": threshold.player._backend is AchillesAutoSpriteBackend }
		)
		threshold._welcome.dismiss()
		await create_timer(0.4).timeout
		await _capture("threshold_idle")
		var start: Vector2 = threshold.player.position
		var accepted := false
		for offset: Vector2 in [Vector2(-180, -65), Vector2(140, -60), Vector2(100, 40)]:
			if threshold.request_move(start + offset):
				accepted = true
				break
		checks.append({ "check": "real_navigation_accepted", "ok": accepted })
		if accepted:
			await create_timer(0.3).timeout
			checks.append(
				{
					"check": "native_walk",
					"ok": str(threshold.player.get_visual_state().animation).begins_with("walk_"),
				}
			)
			await _capture("threshold_walk")
			deadline = Time.get_ticks_msec() + 10000
			while threshold.is_player_moving() and Time.get_ticks_msec() < deadline:
				await process_frame
			checks.append(
				{
					"check": "navigation_arrived",
					"ok": not threshold.is_player_moving()
					and threshold.player.position.distance_to(start) > 10,
				}
			)
			await _capture("threshold_arrival")
	var ok := checks.all(
		func(check: Dictionary) -> bool:
			return bool(check.ok),
	)
	var report := FileAccess.open(OUTPUT + "report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({ "ok": ok, "checks": checks }, "\t"))
	report.close()
	current_scene = null
	threshold.queue_free()
	await process_frame
	await process_frame
	print("AUTOSPRITE_ENTRY: ", ok)
	quit(0 if ok else 1)


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var error := screenshot.save_png(ProjectSettings.globalize_path(OUTPUT + label + ".png"))
	checks.append({ "check": "capture_" + label, "ok": error == OK })
