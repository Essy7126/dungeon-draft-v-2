extends RefCounted


static func run(battle: Node, output: String) -> Dictionary:
	var composition := battle.get_node("GreekTerrainComposition") as Node2D
	var controller := composition.get_node("WorldDecor_lethe_living")
	var first_time: float = controller.effect_time
	await battle.get_tree().create_timer(0.2).timeout
	var advances: bool = controller.effect_time > first_time
	var prior := GameManager.is_reduced_motion_enabled()
	GameManager.set_reduced_motion_enabled(true)
	var frozen: float = controller.effect_time
	await battle.get_tree().create_timer(0.2).timeout
	var freeze_ok: bool = is_equal_approx(frozen, controller.effect_time)
	GameManager.set_reduced_motion_enabled(prior)
	controller.set_process(false)
	var frames: Array[Image] = []
	for index in 8:
		controller.seek_for_review(float(index) * 0.45)
		await RenderingServer.frame_post_draw
		var frame := battle.get_viewport().get_texture().get_image()
		frame.save_png(output.path_join("lethe-motion-%02d.png" % index))
		frames.append(frame)
	var regions := {
		"water": Rect2(1745, 300, 85, 90),
		"torch": Rect2(520, 99, 38, 60),
		"lantern": Rect2(122, 652, 34, 60),
		"stable_ground": Rect2(1000, 850, 28, 12),
	}
	var metrics := { }
	for name in regions:
		var rect: Rect2 = regions[name]
		var samples := 0
		var changed := 0
		for y in range(int(rect.position.y), int(rect.end.y), 2):
			for x in range(int(rect.position.x), int(rect.end.x), 2):
				var pixel := Vector2i(
					composition.get_global_transform_with_canvas() * Vector2(x, y)
				)
				if not Rect2i(Vector2i.ZERO, frames[0].get_size()).has_point(pixel):
					continue
				samples += 1
				var first := frames[0].get_pixelv(pixel)
				var maximum := 0.0
				for frame in frames:
					var next := frame.get_pixelv(pixel)
					maximum = maxf(
						maximum,
						maxf(
							absf(first.r - next.r),
							maxf(absf(first.g - next.g), absf(first.b - next.b)),
						),
					)
				if maximum > 1.0 / 255.0:
					changed += 1
		metrics[name] = { "samples": samples, "changed": changed }
	controller.set_process(true)
	var valid: bool = advances and freeze_ok
	for name in ["water", "torch", "lantern"]:
		valid = valid and metrics[name].changed > 10
	valid = valid and metrics.stable_ground.samples > 0 and metrics.stable_ground.changed == 0
	return {
		"ok": valid,
		"clock_advances": advances,
		"reduced_motion_freezes": freeze_ok,
		"regions": metrics,
		"frames": frames.size(),
	}
