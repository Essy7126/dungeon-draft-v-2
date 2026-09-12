extends SceneTree

const OUT := "res://artifacts/spine_trial/veilleur_walk_iso_v1/"
var checks := 0
var captures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		push_error(description)
		quit(1)
		assert(false, description)


func run() -> void:
	var lab = load("res://tools/veilleur_walk/WalkIsoReview.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab.set_process(false)
	check(DisplayServer.get_name() != "headless", "Real GPU framebuffer required")
	var initial: Vector2 = lab.actor_position
	for d: String in ["E", "S", "N", "W"]:
		check(lab.actor.FRAMES.get_frame_count("walk_" + d) == 48, "48 imported atlas regions: " + d)
		lab.direction = d
		for i in range(48):
			lab.phase = float(i) / 48.0 + 0.000001
			lab.refresh()
			check(
				lab.actor.sprite.frame == i and not lab.actor.sprite.flip_h,
				"Correct frame, no mirror: %s/%d" % [d, i],
			)
		lab.phase = 0.25
		lab.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var filename := "godot_" + d + ".png"
		check(image.save_png(ProjectSettings.globalize_path(OUT + filename)) == OK, "Capture " + d)
		captures.append(filename)
		# Four native moving samples make phase/translation inspectable together.
		var strip := Image.create(180 * 8, 230, false, Image.FORMAT_RGBA8)
		for j in range(8):
			var t := float(j) / 8.0
			var stride: Array = lab.actor.data.views[d].stride
			lab.phase = t
			lab.actor_position = initial + Vector2(stride[0], stride[1]) * 0.3 * t
			lab.refresh()
			await process_frame
			await RenderingServer.frame_post_draw
			image = root.get_texture().get_image()
			var crop := image.get_region(
				Rect2i(Vector2i(initial) - Vector2i(70, 135), Vector2i(180, 230))
			)
			strip.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(j * 180, 0))
		check(
			strip.save_png(ProjectSettings.globalize_path(OUT + "godot_" + d + "_steps.png")) == OK,
			"Native moving strip " + d,
		)
		lab.actor_position = initial
	# Actual pathfinding and phase are exercised independently from the renderer.
	lab.phase = 0.0
	var start: Vector2i = lab.cell
	for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var previous: Vector2i = lab.cell
		check(lab.request_path(previous + step), "Walk to adjacent real cell")
		var p0: float = lab.phase
		lab.advance(0.1)
		check(
			absf(fposmod(lab.phase - p0, 1.0) - 0.125) < 0.0001,
			"Direction change preserves gait clock",
		)
		var distance: float = lab.actor_position.distance_to(lab.visual.cell_to_display(previous))
		check(
			absf(distance - lab.actor.cycle_distance(lab.direction) * 0.125) < 0.001,
			"Movement and foot cycle follow same distance",
		)
		var frozen: Vector2 = lab.actor_position
		var frozen_phase: float = lab.phase
		lab.paused = true
		lab.advance(1.0)
		check(
			lab.phase == frozen_phase and lab.actor_position == frozen,
			"Pause freezes motion and animation",
		)
		lab.paused = false
		lab.advance(5.0)
		check(lab.route.is_empty() and lab.cell == previous + step, "Exact destination reached")
		frozen_phase = lab.phase
		lab.advance(1.0)
		check(lab.phase == frozen_phase, "Stopped actor holds its last pose")
	check(lab.cell == start, "Four-view path returns to start")
	check(not lab.request_path(Vector2i(-1, 0)), "Out of bounds rejected")
	check(not lab.request_path(Vector2i(0, 0)), "Blocked terrain rejected")
	check(lab.world.y_sort_enabled, "Foreground uses world depth sorting")
	lab.actor.sample("E", 1.0)
	check(lab.actor.sprite.frame == 0, "Wrap returns to first frame")
	var report := {
		"passed": true,
		"checks": checks,
		"frames": 192,
		"directions": 4,
		"captures": captures,
		"renderer": DisplayServer.get_name(),
		"artistic_approval": false,
		"limitations": [
			"Walk-only laboratory; no idle or combat",
			"Instant turns",
			"Art review required",
		],
	}
	var file := FileAccess.open(OUT + "godot_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VEILLEUR_ISO_NATIVE " + JSON.stringify(report))
	lab.queue_free()
	await process_frame
	quit(0)
