extends SceneTree

const OUT := "res://artifacts/spine_trial/veilleur_walk_simple_v1/"
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
	var lab = load("res://tools/veilleur_walk/WalkSimpleReview.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab.set_process(false)
	check(DisplayServer.get_name() != "headless", "GPU render required")
	check(lab.actor.data.frame_count == 7, "Seven actual drawn poses")
	for d: String in ["E", "S", "N", "W"]:
		var frames: SpriteFrames = lab.actor.sprite.sprite_frames
		check(frames.get_frame_count("walk_" + d) == 7, "Imported poses: " + d)
		for i in range(7):
			lab.actor.sample(d, float(i) / 7.0 + 0.000001)
			check(lab.actor.sprite.frame == i, "Displayed pose %s/%d" % [d, i])
			var im: Image = frames.get_frame_texture("walk_" + d, i).get_image()
			check(
				im.get_pixel(0, 0).a == 0.0 and im.get_used_rect().size.y > 180,
				"Visible cutout: " + d,
			)
		lab.direction = d
		lab.phase = 2.0 / 7.0
		lab.route = [lab.cell + lab.STEPS[lab.DIRECTIONS.find(d)]]
		lab.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(
				ProjectSettings.globalize_path(OUT + "godot_" + d + ".png")
			) == OK, "Capture " + d)
	lab.route.clear()
	var initial: Vector2i = lab.cell
	for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var previous: Vector2i = lab.cell
		check(lab.request_path(previous + step), "Path exists")
		var before: Vector2 = lab.actor_position
		var p: float = lab.phase
		lab.advance(0.14)
		check(absf(fposmod(lab.phase - p, 1.0) - 0.2) < 0.001, "Clock follows short cycle")
		check(
			absf(before.distance_to(lab.actor_position) - lab.actor.cycle_distance(lab.direction) * 0.2) < 0.001,
			"Movement synchronized",
		)
		before = lab.actor_position
		lab.paused = true
		lab.advance(1.0)
		check(lab.actor_position == before, "Pause")
		lab.paused = false
		lab.advance(5.0)
		check(lab.cell == previous + step and lab.route.is_empty(), "Arrival")
		check(lab.actor.sprite.frame == 1, "Simple held rest pose")
	check(lab.cell == initial, "Four-angle route closes")
	check(not lab.request_path(Vector2i(-1, 0)), "Invalid cell blocked")
	# The existing 48-pose laboratory must still load its own resource.
	var old = load("res://tools/veilleur_walk/WalkIsoReview.tscn").instantiate()
	root.add_child(old)
	await process_frame
	old.set_process(false)
	old.actor.sample("E", 0.5)
	check(
		old.actor.sprite.frame == 24 and old.actor.data.frame_count == 48,
		"Legacy laboratory preserved",
	)
	old.queue_free()
	var report := {
		"passed": true,
		"checks": checks,
		"frames": 28,
		"directions": 4,
		"renderer": DisplayServer.get_name(),
		"artistic_approval": false,
	}
	var file := FileAccess.open(OUT + "godot_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SIMPLE_WALK_NATIVE " + JSON.stringify(report))
	lab.queue_free()
	await process_frame
	quit(0)
