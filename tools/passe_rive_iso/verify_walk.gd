extends SceneTree

var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		push_error(description)
		quit(1)
		assert(false, description)


func run() -> void:
	var scene: PackedScene = load("res://tools/passe_rive_iso/WalkReview.tscn")
	var lab = scene.instantiate()
	root.add_child(lab)
	await process_frame
	lab.set_process(false)
	for d: String in ["E", "S", "N", "W"]:
		check(lab.textures[d].size() == 12, "Twelve loaded frames: " + d)
		lab.direction = d
		for i in range(12):
			lab.phase = float(i) / 12.0 + 0.000001
			lab.refresh()
			check(lab.sprite.texture != null, "Visible texture: %s %d" % [d, i])
		lab.phase = 0.25
		lab.refresh()
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var error := root.get_texture().get_image().save_png(
				ProjectSettings.globalize_path(lab.ROOT + "godot_walk_" + d + ".png")
			)
			check(error == OK, "Save native capture: " + d)
	var start: Vector2i = lab.cell
	for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT]:
		var previous: Vector2i = lab.cell
		check(lab.request_path(previous + step), "Start valid walk")
		lab.advance(0.1)
		var before: Vector2 = lab.actor_position
		var before_phase: float = lab.phase
		lab.paused = true
		lab.advance(2.0)
		check(
			lab.actor_position == before and lab.phase == before_phase,
			"Pause freezes feet and path together",
		)
		lab.paused = false
		lab.advance(3.0)
		check(
			lab.route.is_empty() and lab.cell == previous + step,
			"Arrive exactly on the requested cell",
		)
		var arrival_phase: float = lab.phase
		lab.advance(1.0)
		check(lab.phase == arrival_phase, "Stopped movement does not keep walking")
	check(lab.cell == start, "Four directions return to the start")
	check(not lab.request_path(Vector2i(0, 0)), "Blocked terrain rejected")
	check(not lab.request_path(Vector2i(-1, 0)), "Outside map rejected")
	var report := {
		"checks": checks,
		"success": true,
		"directions": 4,
		"frames": 48,
		"pathfinding": "real GridData and Pathfinder",
		"artistic_approval": false,
		"calibration": "provisional",
	}
	var file := FileAccess.open(lab.ROOT + "godot_walk_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("WALK_NATIVE_CHECKS " + JSON.stringify(report))
	lab.queue_free()
	await process_frame
	quit(0)
