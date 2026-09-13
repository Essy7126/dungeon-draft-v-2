extends SceneTree

const OUTPUT := "res://artifacts/dev/passe_rive_autosprite/entry/"
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
	await create_timer(0.5).timeout
	for i in selection.get_entries().size():
		if selection.get_entries()[i].id == &"achilles_passe_rive":
			selection.select_character(i)
	var entry: Dictionary = selection.get_selected_entry()
	_check("public_selection", str(entry.id) == "achilles_passe_rive")
	_check("prepare_selected_adventure", selection.prepare_adventure(root.get_node("GameManager")))
	await create_timer(0.3).timeout
	await _capture("selection")
	current_scene = null
	selection.queue_free()
	await process_frame
	root.get_node("GameManager").continue_after_intro()
	var threshold: Node
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if (
			current_scene != null and current_scene.has_method("get_entry_state")
			and current_scene.is_ready_for_play()
		):
			threshold = current_scene
			break
	_check("real_threshold_ready", threshold != null)
	if threshold != null:
		_check(
			"selected_actor_carried_to_threshold",
			threshold.player._backend is PasseRiveAutoSpriteBackend,
		)
		threshold.audio_enabled = false
		threshold._welcome.dismiss()
		await _capture("threshold_idle")
		for gait: String in ["walk", "run"]:
			var start: Vector2 = threshold.player.position
			var offsets := (
				[Vector2(-55, -15), Vector2(55, -15), Vector2(0, 35)]
				if gait == "walk"
				else [
					Vector2(-240, -60),
					Vector2(250, -80),
					Vector2(240, 50),
					Vector2(400, 0),
					Vector2(500, -150),
					Vector2(650, -150),
					Vector2(50, -180),
				]
			)
			var accepted := false
			for offset: Vector2 in offsets:
				if (
					threshold.request_move(start + offset)
					and threshold.player.locomotion_running == (gait == "run")
				):
					accepted = true
					break
			_check(gait + "_navigation", accepted)
			if accepted:
				await create_timer(0.18).timeout
				_check(
					gait + "_native_sheet",
					str(threshold.player.get_visual_state().animation).begins_with(gait + "_"),
				)
				await _capture("threshold_" + gait)
				deadline = Time.get_ticks_msec() + 10000
				while threshold.is_player_moving() and Time.get_ticks_msec() < deadline:
					await process_frame
				_check(
					gait + "_arrived",
					not threshold.is_player_moving() and threshold.player.position.distance_to(
						start
					) > 10,
				)
				await _capture(gait + "_arrival")
	var ok := checks.all(
		func(c: Dictionary) -> bool:
			return c.ok,
	)
	var report := FileAccess.open(OUTPUT + "report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({ "ok": ok, "checks": checks }, "\t"))
	report.close()
	current_scene = null
	if threshold != null:
		threshold.queue_free()
	await process_frame
	await process_frame
	print("PASSE_RIVE_ENTRY: ", ok)
	quit(0 if ok else 1)


func _check(label: String, ok: bool) -> void:
	checks.append({ "check": label, "ok": ok })


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check("capture_" + label, root.get_texture().get_image().save_png(
			ProjectSettings.globalize_path(OUTPUT + label + ".png")
		) == OK)
