extends RefCounted


static func run(battle: Node, output: String) -> Dictionary:
	var atmosphere := battle.get_node("GreekTerrainComposition/WorldDecor_cavern_peripheral_mist")
	var initial: Dictionary = atmosphere.animation_report()
	await battle.get_tree().create_timer(0.25).timeout
	var advanced: Dictionary = atmosphere.animation_report()
	var prior := GameManager.is_reduced_motion_enabled()
	GameManager.set_reduced_motion_enabled(true)
	var frozen: float = atmosphere.effect_time
	await battle.get_tree().create_timer(0.25).timeout
	var freeze_ok: bool = is_equal_approx(frozen, atmosphere.effect_time)
	GameManager.set_reduced_motion_enabled(prior)
	atmosphere.set_process(false)
	var frames: Array[Image] = []
	for index in range(36):
		atmosphere.seek_for_review(float(index) / 3.0)
		await RenderingServer.frame_post_draw
		var shot := battle.get_viewport().get_texture().get_image()
		shot.save_png(output.path_join("motion_%03d.png" % index))
		frames.append(shot)
	var composition := atmosphere.get_parent() as Node2D
	var regions := {
		"water": Rect2(1490, 935, 140, 60),
		"mist": Rect2(1690, 520, 65, 110),
		"torch": Rect2(atmosphere.torch_base_a - Vector2(43, 70), Vector2(95, 115)),
		"floor": Rect2(920, 365, 25, 20),
	}
	var metrics := { }
	for name: String in regions:
		var rect: Rect2 = regions[name]
		var total := 0.0
		var count := 0
		var changed := 0
		for y in range(int(rect.position.y), int(rect.end.y), 3):
			for x in range(int(rect.position.x), int(rect.end.x), 3):
				var pixel: Vector2 = composition.get_global_transform_with_canvas() * Vector2(x, y)
				var at := Vector2i(pixel)
				if (
					at.x < 0 or at.y < 0 or at.x >= frames[0].get_width()
					or at.y >= frames[0].get_height()
				):
					continue
				var a := frames[0].get_pixelv(at)
				var b := frames[18].get_pixelv(at)
				var difference := (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
				total += difference
				count += 1
				if difference > 1.0 / 255.0:
					changed += 1
		metrics[name] = {
			"samples": count,
			"changed": changed,
			"mean_rgb_delta": total / maxi(1, count),
		}
	var moving: bool = advanced.clock > initial.clock
	var visible_motion: bool = (
		metrics.water.changed > 10 and metrics.mist.changed > 10 and metrics.torch.changed > 10
	)
	var floor_stable: bool = metrics.floor.changed == 0 and metrics.floor.samples > 0
	atmosphere.set_process(true)
	return {
		"ok": moving and freeze_ok and initial.materials == 4 and visible_motion and floor_stable,
		"clock_advances": moving,
		"reduced_motion_freezes": freeze_ok,
		"materials": initial.materials,
		"floor_stable": floor_stable,
		"visible_motion": visible_motion,
		"regions": metrics,
		"frames": frames.size(),
		"sample_times_seconds": [0, 6],
		"scope": "Real GPU images with explicit effect-clock sampling; live clock and reduced-motion freeze also checked. Not a framerate benchmark.",
	}
