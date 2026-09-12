extends "res://tools/halt_workshop/verify_living_halt.gd"
## GPU observations at authored source pixels; no shader or calibration overrides.
const MANIFEST := "res://data/halts/stele_names_v1.json"
const TIMES := [0.0, 0.45, 0.90, 1.35, 1.80, 2.25, 2.70, 3.15]
const LANTERNS := [
	{ "id": "boat_lantern", "glass": [89, 614, 26, 32], "frame": [79, 581, 48, 79] },
	{ "id": "memorial_lantern", "glass": [1041, 351, 24, 30], "frame": [1034, 320, 42, 69] },
	{ "id": "shore_lantern", "glass": [1562, 543, 26, 32], "frame": [1553, 508, 48, 81] },
]
const FOLIAGE := [
	{ "id": "willow_left", "rect": [665, 60, 100, 110] },
	{ "id": "willow_middle", "rect": [862, 75, 100, 110] },
	{ "id": "willow_right", "rect": [1499, 100, 70, 116] },
	{ "id": "reeds_quay", "rect": [575, 395, 72, 98] },
	{ "id": "reeds_memorial", "rect": [784, 282, 80, 88] },
	{ "id": "reeds_foreground", "rect": [1536, 757, 84, 98] },
	{ "id": "reeds_pale_plume", "rect": [634, 377, 32, 46] },
]
const STABLE := [
	{ "id": "paving", "rect": [927, 504, 50, 24] },
	{ "id": "tree_trunk", "rect": [1379, 151, 46, 60] },
	{ "id": "boat_hull", "rect": [250, 692, 56, 14] },
	{ "id": "small_shore_slab", "rect": [1430, 753, 8, 8] },
	{ "id": "foreground_rock", "rect": [1446, 921, 8, 8] },
]
var sequences: Array[Dictionary] = []
var metrics: Array[Dictionary] = []
var controls: Array[Dictionary] = []
var _finishing_motion := false


func _run() -> void:
	output = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-root="):
			output = argument.trim_prefix("--output-root=").replace("\\", "/").trim_suffix("/")
	var artifacts := ProjectSettings \
			.globalize_path("res://artifacts/dev/") \
			.replace("\\", "/") \
			.to_lower()
	var userdata := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if (
		output.is_empty() or not output.to_lower().begins_with(artifacts)
		or not userdata.begins_with(output.to_lower() + "/userdata/")
	):
		push_error("Motion QA requires verify_motion.ps1 and isolated artifacts/userdata.")
		get_tree().quit(2)
		return
	_rendered = DisplayServer.get_name() != "headless"
	_check("rendered_gpu_backend", _rendered, DisplayServer.get_name())
	_check("no_active_user_run", not GameManager.run_active and GameManager.expedition == null)
	if not _rendered or GameManager.run_active or GameManager.expedition != null:
		await _finish_motion()
		return
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = size
		_resolution = "%dx%d" % [size.x, size.y]
		for frame in 3:
			await get_tree().process_frame
		_check("actual_viewport_size", get_viewport().get_visible_rect().size == Vector2(size))
		hall = SCENE.instantiate()
		hall.manifest_path = MANIFEST
		hall.preview_mode = true
		hall.audio_enabled = false
		add_child(hall)
		for attempt in 180:
			if hall.is_ready_for_play():
				break
			await get_tree().process_frame
		_check("real_halt_ready", hall.is_ready_for_play())
		if not hall.is_ready_for_play():
			await _dispose_halt()
			continue
		hall.set_process(false)
		hall.stop_movement()
		hall.set_chrome_visible(false)
		hall.player.hide()
		hall.landmarks_fx.hide()
		_source_evidence = {
			"manifest": MANIFEST,
			"manifest_sha256": FileAccess.get_sha256(MANIFEST),
			"source_sha256": FileAccess.get_sha256(str(hall.definition.source.image)),
			"build_sha256": FileAccess.get_sha256(
				str(hall.definition.build_dir).path_join("build.json")
			),
			"shader_sha256": FileAccess.get_sha256(
				"res://hub/painted_halt/living_materials.gdshader"
			),
		}
		var source_dimensions: Array = hall.definition.source.size
		_check(
			"authored_source_dimensions",
			source_dimensions.size() == 2 and float(source_dimensions[0]) == 1672.0
			and float(source_dimensions[1]) == 941.0,
			{ "observed": source_dimensions, "expected": [1672, 941] },
		)
		_check("three_authored_lanterns", hall.definition.torches.size() == 3)
		for torch: Dictionary in hall.definition.torches:
			_check("closed_lantern_" + str(torch.id), bool(torch.get("enclosed", false)))
		for layer in ["fire", "foliage"]:
			var full := await _sequence(layer, false)
			var reduced := await _sequence(layer, true)
			_compare_reduced(layer, full, reduced)
		await _control_modes()
		await _dispose_halt()
	await _finish_motion()


func _sequence(layer: String, reduced: bool) -> Dictionary:
	hall.set_original(false)
	hall.set_paused(false)
	hall.reduced = reduced
	for name: String in hall.layers:
		hall.set_layer(name, name == layer)
	var mode := "reduced" if reduced else "normal"
	var sequence := {
		"resolution": _resolution,
		"layer": layer,
		"mode": mode,
		"frames": [],
		"regions": [],
		"metrics": { },
	}
	var frames: Array[Image] = []
	for index in TIMES.size():
		var rendered := await _image_at(float(TIMES[index]))
		frames.append(rendered)
		var path := output.path_join("%s_%s_%s_t%02d.png" % [_resolution, layer, mode, index])
		_check("save_" + path.get_file(), rendered.save_png(path) == OK)
		captures.append(path)
		sequence.frames.append({ "time": TIMES[index], "path": path })
	if layer == "fire":
		for sample: Dictionary in LANTERNS:
			var rect := _screen_rect(sample.glass)
			var values := _temporal_range(frames, rect)
			sequence.metrics[sample.id] = values
			_record_metric(layer, mode, str(sample.id), values)
			sequence.regions.append(
				{
					"id": str(sample.id),
					"rect": _rect_array(_screen_rect(sample.frame)),
					"kind": "lantern",
				}
			)
			if not reduced:
				_check(
					"lantern_visible_luminance_" + str(sample.id),
					float(values.mean_luma_span) >= 1.0 / 255.0
					and float(values.mean_pixel_luma_span) >= 1.0 / 255.0,
					values,
				)
			var edges := _frame_stability(frames, _screen_rect(sample.frame))
			_record_metric(layer, mode, str(sample.id) + "_frame_edges", edges)
			_check(
				mode + "_lantern_frame_not_translated_" + str(sample.id),
				bool(edges.stable),
				edges,
			)
	else:
		for sample: Dictionary in FOLIAGE:
			var rect := _screen_rect(sample.rect)
			var values := _temporal_range(frames, rect)
			sequence.metrics[sample.id] = values
			_record_metric(layer, mode, str(sample.id), values)
			sequence.regions.append(
				{ "id": str(sample.id), "rect": _rect_array(rect), "kind": "foliage" }
			)
			if not reduced:
				_check(
					"foliage_visible_motion_" + str(sample.id),
					float(values.mean_rgb_span) >= 0.003 and float(values.changed_fraction) >= 0.08,
					values,
				)
		for sample: Dictionary in STABLE:
			var rect := _screen_rect(sample.rect)
			var values := _temporal_range(frames, rect)
			_record_metric(layer, mode, str(sample.id), values)
			sequence.regions.append(
				{ "id": str(sample.id), "rect": _rect_array(rect), "kind": "stable" }
			)
			_check(
				mode + "_vegetation_keeps_" + str(sample.id) + "_fixed",
				float(values.max_channel_span) < 0.5 / 255.0,
				values,
			)
	sequences.append(sequence)
	return sequence.metrics


func _compare_reduced(layer: String, full: Dictionary, reduced: Dictionary) -> void:
	for id: String in full:
		var full_span := float(full[id].mean_rgb_span)
		var reduced_span := float(reduced[id].mean_rgb_span)
		_check(
			"reduced_" + layer + "_quieter_" + id,
			reduced_span < full_span * 0.8 + 0.5 / 255.0,
			{
				"normal_span": full_span,
				"reduced_span": reduced_span,
				"ratio": reduced_span / maxf(full_span, 0.000001),
			},
		)


func _control_modes() -> void:
	hall.reduced = false
	for name: String in hall.layers:
		hall.set_layer(name, true)
	hall.set_original(false)
	hall.set_paused(true)
	var first := await _image_at(4.0)
	var clock_before: float = hall.clock
	hall.advance_world(2.0)
	var second := await _render_frame()
	_check("pause_clock_frozen", hall.clock == clock_before)
	_check("pause_gpu_frame_identical", first.get_data() == second.get_data())
	await _save_control("pause_before", first)
	await _save_control("pause_after", second)
	hall.set_paused(false)
	hall.set_original(true)
	first = await _image_at(1.0)
	second = await _image_at(3.15)
	_check("original_gpu_frame_identical", first.get_data() == second.get_data())
	await _save_control("original_before", first)
	await _save_control("original_after", second)
	hall.set_original(false)
	hall.player.show()
	hall.landmarks_fx.show()
	hall.set_chrome_visible(true)
	await _image_at(1.8)
	await _capture("all_layers_context")


func _save_control(label: String, frame: Image) -> void:
	var path := output.path_join(_resolution + "_" + label + ".png")
	_check("save_control_" + label, frame.save_png(path) == OK)
	captures.append(path)
	controls.append({ "resolution": _resolution, "id": label, "path": path })


func _render_frame() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _screen_rect(source_pixels: Array) -> Rect2i:
	var source_size := Vector2(hall.definition.source.size[0], hall.definition.source.size[1])
	var a := Vector2(float(source_pixels[0]), float(source_pixels[1])) / source_size
	var b := Vector2(
		float(source_pixels[0]) + float(source_pixels[2]),
		float(source_pixels[1]) + float(source_pixels[3]),
	) / source_size
	var screen_a: Vector2 = hall.world.to_global(a * hall.world_size)
	var screen_b: Vector2 = hall.world.to_global(b * hall.world_size)
	var rect := Rect2i(Vector2i(screen_a.floor()), Vector2i(screen_b.ceil() - screen_a.floor()))
	var bounds := Rect2i(Vector2i.ZERO, Vector2i(get_viewport().get_visible_rect().size))
	_check(
		"sample_in_view",
		bounds.encloses(rect) and rect.size.x > 3 and rect.size.y > 3,
		_rect_array(rect),
	)
	return rect.intersection(bounds)


func _rect_array(rect: Rect2i) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _luma(pixel: Color) -> float:
	return pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722


func _temporal_range(frames: Array[Image], rect: Rect2i) -> Dictionary:
	var count := rect.size.x * rect.size.y
	var changed := 0
	var rgb_total := 0.0
	var luma_total := 0.0
	var largest := 0.0
	var means: Array[float] = []
	means.resize(frames.size())
	means.fill(0.0)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var minimum := Vector3.ONE
			var maximum := Vector3.ZERO
			var minimum_luma := 1.0
			var maximum_luma := 0.0
			for index in frames.size():
				var pixel := frames[index].get_pixel(x, y)
				var rgb := Vector3(pixel.r, pixel.g, pixel.b)
				minimum = minimum.min(rgb)
				maximum = maximum.max(rgb)
				var light := _luma(pixel)
				minimum_luma = minf(minimum_luma, light)
				maximum_luma = maxf(maximum_luma, light)
				means[index] += light / maxf(count, 1)
			var span := maximum - minimum
			var pixel_max := maxf(span.x, maxf(span.y, span.z))
			largest = maxf(largest, pixel_max)
			rgb_total += (span.x + span.y + span.z) / 3.0
			luma_total += maximum_luma - minimum_luma
			if pixel_max > 2.0 / 255.0:
				changed += 1
	return {
		"rect": _rect_array(rect),
		"samples": count,
		"mean_luma": means,
		"mean_luma_span": float(means.max()) - float(means.min()),
		"mean_pixel_luma_span": luma_total / maxf(count, 1),
		"mean_rgb_span": rgb_total / maxf(count, 1),
		"max_channel_span": largest,
		"changed_fraction": changed / maxf(count, 1),
	}


func _gradient(frame: Image, point: Vector2i) -> Vector2:
	return Vector2(
		_luma(frame.get_pixelv(point + Vector2i.RIGHT))
		- _luma(frame.get_pixelv(point + Vector2i.LEFT)),
		_luma(frame.get_pixelv(point + Vector2i.DOWN))
		- _luma(frame.get_pixelv(point + Vector2i.UP)),
	)


func _edge_similarity(first: Image, next: Image, rect: Rect2i, offset: Vector2i) -> float:
	var dot := 0.0
	var first_energy := 0.0
	var next_energy := 0.0
	for y in range(rect.position.y + 3, rect.end.y - 3):
		for x in range(rect.position.x + 3, rect.end.x - 3):
			var point := Vector2i(x, y)
			var a := _gradient(first, point)
			var b := _gradient(next, point + offset)
			dot += a.dot(b)
			first_energy += a.length_squared()
			next_energy += b.length_squared()
	return dot / sqrt(maxf(first_energy * next_energy, 0.00000001))


func _frame_stability(frames: Array[Image], rect: Rect2i) -> Dictionary:
	var comparisons: Array[Dictionary] = []
	var stable := true
	for index in range(1, frames.size()):
		var zero_score := _edge_similarity(frames[0], frames[index], rect, Vector2i.ZERO)
		var best_score := zero_score
		var best_shift := Vector2i.ZERO
		for y in range(-2, 3):
			for x in range(-2, 3):
				var shift := Vector2i(x, y)
				if shift == Vector2i.ZERO:
					continue
				var score := _edge_similarity(frames[0], frames[index], rect, shift)
				if score > best_score + 0.002:
					best_score = score
					best_shift = shift
		var fixed := best_shift == Vector2i.ZERO and zero_score >= 0.94
		stable = stable and fixed
		comparisons.append(
			{
				"time": TIMES[index],
				"zero_shift_similarity": zero_score,
				"best_similarity": best_score,
				"best_shift_px": [best_shift.x, best_shift.y],
				"fixed": fixed,
			}
		)
	return { "stable": stable, "rect": _rect_array(rect), "comparisons": comparisons }


func _record_metric(layer: String, mode: String, id: String, value: Dictionary) -> void:
	metrics.append(
		{ "resolution": _resolution, "layer": layer, "mode": mode, "id": id, "values": value }
	)


func _finish_motion() -> void:
	if _finishing_motion:
		return
	_finishing_motion = true
	if is_instance_valid(hall):
		await _dispose_halt()
	var failures: Array[Dictionary] = []
	for check: Dictionary in checks:
		if not bool(check.passed):
			failures.append(check)
	var report := {
		"passed": not checks.is_empty() and failures.is_empty(),
		"rendered": _rendered,
		"checks": checks,
		"check_count": checks.size(),
		"failures": failures,
		"captures": captures,
		"sequences": sequences,
		"metrics": metrics,
		"controls": controls,
		"source_evidence": _source_evidence,
		"times": TIMES,
		"user_data": OS.get_user_data_dir(),
		"manual_visual_review_required": true,
		"criteria": {
			"lantern_mean_luma_span_min": 1.0 / 255.0,
			"foliage_mean_rgb_span_min": 0.003,
			"foliage_changed_fraction_min": 0.08,
			"fixed_witness_max_channel_span": 0.5 / 255.0,
			"lantern_frame_min_gradient_similarity": 0.94,
			"lantern_frame_translation_px": 0,
			"reduced_max_fraction": 0.8,
			"reduced_quantization_tolerance": 0.5 / 255.0,
		},
		"limits": [
			"Lantern geometry uses gradient registration to separate motion from brightness changes.",
			"Pixel registration does not replace visual inspection of subpixel shape distortion.",
			"Measurements isolate shader layers; context captures include the assembled scene.",
		],
	}
	var file := FileAccess.open(output.path_join("motion_verification.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write motion verification report")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(
		"STELE_MOTION_VERIFY: %s; %d checks; %d captures"
		% [report.passed, checks.size(), captures.size()]
	)
	await get_tree().create_timer(0.20, true, false, true).timeout
	get_tree().quit(0 if report.passed else 1)
