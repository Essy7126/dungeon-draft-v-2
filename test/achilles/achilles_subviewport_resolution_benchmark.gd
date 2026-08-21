extends Node

const BACKEND_SCENE: PackedScene = preload(
	"res://characters/achilles/3d/AchillesViewport3DBackend.tscn"
)
const BASE_PROFILE: AchillesVisualProfile = preload(
	"res://data/visuals/achilles/achilles_character_only_profile.tres"
)
const RESOLUTIONS: Array[int] = [256, 384, 512]
const ALPHA_THRESHOLD := 0.01
const READY_TIMEOUT_MSEC := 12000
const SETTLE_FRAMES := 8
const CLEANUP_SETTLE_SECONDS := 0.75
const CPU_SAMPLE_FRAMES := 120
const COLD_CPU_SAMPLE_FRAMES := 30
const CPU_MONITOR_WARMUP_SECONDS := 2.25
const REVIEW_ACTION := &"Anim_0_004"
const REVIEW_SAMPLE_SECONDS := 1.0

var _artifact_dir := ""
var _capture_dir := ""
var _failures: Array[String] = []
var _report := {
	"schema": "dd.achilles.subviewport-resolution-benchmark.v1",
	"status": "FAIL",
	"base_sha": "2d99ea4137ba1893e486b3ff1e39a73e66d0a469",
	"evidence_head": "2d99ea4137ba1893e486b3ff1e39a73e66d0a469",
	"final_head_pending": true,
	"scope": "ACHILLES_CHARACTER_ONLY_ROOM_II_GATE",
	"resolutions": RESOLUTIONS,
	"measurement_order": [
		"cold_start_reference_384",
		"cache_warm_256",
		"cache_warm_384",
		"cache_warm_512",
		"retention_probe_512_second_cycle",
	],
	"profile_path": (
		"res://data/visuals/achilles/achilles_character_only_profile.tres"
	),
	"backend_scene_path": (
		"res://characters/achilles/3d/AchillesViewport3DBackend.tscn"
	),
	"character_only": true,
	"weapon_runtime_integration": false,
	"fixed_review_pose": {
		"godot_action": String(REVIEW_ACTION),
		"sample_seconds": REVIEW_SAMPLE_SECONDS,
		"camera_profile_unchanged": true,
	},
	"cold_start_reference_384": {},
	"measurements": [],
	"limitations": {
		"gpu_frametime": {
			"status": "NOT_MEASURED",
			"reason": (
				"The OpenGL Compatibility renderer used for this pilot does not "
				+ "expose a validated RenderingDevice timestamp query in this "
				+ "runner; CPU or wall-clock values are not relabeled as GPU time."
			),
		},
		"room_change_stability": {
			"status": "PAUSED_OWNER_GATE_ROOM_II_ONLY",
			"reason": (
				"Rooms I and III are intentionally not opened before the owner "
				+ "selects or rejects the SubViewport presentation."
			),
		},
		"memory_attribution": (
			"Rendering and static-memory deltas are process-level observations, "
			+ "not exclusive allocations attributed by Godot to one SubViewport."
		),
		"cpu_frametime": (
			"Performance.TIME_PROCESS is sampled as the engine CPU-process "
			+ "monitor after a 2.25-second refresh interval; wall-frame intervals "
			+ "are reported separately and include "
			+ "presentation scheduling."
		),
	},
	"failures": _failures,
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_artifact_dir = _argument_value("--artifact-dir=")
	var evidence_head := _argument_value("--evidence-head=").to_lower()
	if evidence_head.length() == 40 and evidence_head.is_valid_hex_number(false):
		_report.evidence_head = evidence_head
		_report.final_head_pending = false
		_report["evidence_head_source"] = "EXPLICIT_POST_COMMIT_ARGUMENT"
	if _artifact_dir.is_empty() or not _artifact_dir.is_absolute_path():
		_fail("An absolute --artifact-dir is required.")
		_finish()
		return
	_capture_dir = _artifact_dir.path_join("captures")
	if DirAccess.make_dir_recursive_absolute(_capture_dir) != OK:
		_fail("Cannot create the benchmark capture directory.")
		_finish()
		return

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	_report["engine"] = {
		"version": Engine.get_version_info(),
		"display_server": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_device": RenderingServer.get_video_adapter_name(),
	}
	_report["baseline_before_cold_start"] = _memory_snapshot()

	var cold_record: Dictionary = await _measure_resolution(
		384, "cold_start_reference_384", COLD_CPU_SAMPLE_FRAMES, false
	)
	_report["cold_start_reference_384"] = cold_record
	await _settle(SETTLE_FRAMES)
	await RenderingServer.frame_post_draw
	_report["cache_warm_baseline"] = _memory_snapshot()

	for resolution in RESOLUTIONS:
		var record: Dictionary = await _measure_resolution(
			resolution,
			"cache_warm_%d" % resolution,
			CPU_SAMPLE_FRAMES,
			true
		)
		_report.measurements.append(record)
	_report["retention_probe_512_second_cycle"] = await _measure_resolution(
		512,
		"retention_probe_512_second_cycle",
		COLD_CPU_SAMPLE_FRAMES,
		false
	)

	_report["all_measurements_passed"] = _failures.is_empty() \
		and _report.measurements.size() == RESOLUTIONS.size()
	_finish()


func _measure_resolution(
		resolution: int,
		label: String,
		cpu_sample_frames: int,
		save_capture: bool
	) -> Dictionary:
	var before_memory := _memory_snapshot()
	var instantiate_started := Time.get_ticks_usec()
	var backend := BACKEND_SCENE.instantiate() as AchillesViewport3DBackend
	var instantiate_finished := Time.get_ticks_usec()
	if backend == null:
		_fail("%s: backend scene did not instantiate with the expected type." % label)
		return {"label": label, "resolution": resolution, "status": "FAIL"}

	backend.name = "BenchmarkBackend_%d" % resolution
	var add_child_started := Time.get_ticks_usec()
	add_child(backend)
	var add_child_finished := Time.get_ticks_usec()
	var profile := BASE_PROFILE.duplicate(true) as AchillesVisualProfile
	if profile == null:
		backend.queue_free()
		_fail("%s: character-only profile duplication failed." % label)
		return {"label": label, "resolution": resolution, "status": "FAIL"}
	profile.viewport_size = Vector2i(resolution, resolution)

	var configure_started := Time.get_ticks_usec()
	var configure_accepted: bool = backend.configure(profile)
	var configure_returned := Time.get_ticks_usec()
	var first_visible_usec := -1
	var first_visible_frame := -1
	var first_visible_bounds := Rect2i()
	var observed_frames := 0
	var ready_deadline := Time.get_ticks_msec() + READY_TIMEOUT_MSEC
	while Time.get_ticks_msec() < ready_deadline:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		observed_frames += 1
		var candidate_image := backend.character_viewport.get_texture().get_image()
		var candidate_bounds := _alpha_bounds(candidate_image, ALPHA_THRESHOLD)
		if first_visible_usec < 0 and candidate_bounds.has_area():
			first_visible_usec = Time.get_ticks_usec()
			first_visible_frame = observed_frames
			first_visible_bounds = candidate_bounds
		if first_visible_usec >= 0 and backend.is_ready_for_render():
			break

	var backend_ready_usec := Time.get_ticks_usec()
	var ready: bool = backend.is_ready_for_render()
	if not configure_accepted:
		_fail("%s: configure() rejected the canonical profile." % label)
	if not ready:
		_fail("%s: backend did not become ready before the timeout." % label)
	if first_visible_usec < 0:
		_fail("%s: no non-empty alpha frame was observed." % label)

	backend.set_backend_active(true)
	await _settle(SETTLE_FRAMES)
	var visual := backend.get_achilles_visual()
	var player: AnimationPlayer = (
		visual.get_animation_player() if visual != null else null
	)
	var fixed_pose_applied := false
	if player != null and player.has_animation(REVIEW_ACTION):
		player.play(REVIEW_ACTION)
		player.seek(REVIEW_SAMPLE_SECONDS, true)
		player.advance(0.0)
		player.speed_scale = 0.0
		fixed_pose_applied = true
	await _settle(SETTLE_FRAMES)
	await RenderingServer.frame_post_draw

	var viewport_image := backend.character_viewport.get_texture().get_image()
	var alpha_bounds := _alpha_bounds(viewport_image, ALPHA_THRESHOLD)
	var clipping := _clipping_record(viewport_image, alpha_bounds)
	var sharpness := _sharpness_record(viewport_image)
	var capture_record := {
		"status": "NOT_SAVED_COLD_REFERENCE",
		"path": "",
		"sha256": "",
		"size": [
			viewport_image.get_width() if viewport_image != null else 0,
			viewport_image.get_height() if viewport_image != null else 0,
		],
	}
	if save_capture:
		capture_record = _save_viewport_capture(viewport_image, resolution)

	var memory_active := _memory_snapshot()
	# Built-in Performance monitors can lag by up to one second. Waiting here
	# prevents setup and alpha-analysis work from being mislabeled as steady CPU
	# frametime.
	await get_tree().create_timer(CPU_MONITOR_WARMUP_SECONDS).timeout
	await RenderingServer.frame_post_draw
	var cpu_samples_msec: Array[float] = []
	var wall_samples_msec: Array[float] = []
	var previous_tick := Time.get_ticks_usec()
	for _sample_index in range(cpu_sample_frames):
		await get_tree().process_frame
		var current_tick := Time.get_ticks_usec()
		wall_samples_msec.append(float(current_tick - previous_tick) / 1000.0)
		previous_tick = current_tick
		cpu_samples_msec.append(
			float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		)
	var memory_after_samples := _memory_snapshot()

	var viewport_ref: WeakRef = weakref(backend.character_viewport)
	if player != null:
		player.speed_scale = 1.0
	backend.shutdown()
	backend.queue_free()
	backend = null
	profile = null
	await _settle(SETTLE_FRAMES)
	await RenderingServer.frame_post_draw
	var cleanup_released: bool = viewport_ref.get_ref() == null
	var memory_after_cleanup_immediate := _memory_snapshot()
	await get_tree().create_timer(CLEANUP_SETTLE_SECONDS).timeout
	await RenderingServer.frame_post_draw
	var memory_after_cleanup := _memory_snapshot()
	if not cleanup_released:
		_fail("%s: SubViewport weak reference remained live after cleanup." % label)
	if not fixed_pose_applied:
		_fail("%s: the fixed review pose could not be applied." % label)
	if bool(clipping.get("is_clipped", true)):
		_fail("%s: alpha bounds touch the SubViewport border." % label)

	return {
		"label": label,
		"resolution": resolution,
		"status": "PASS" if configure_accepted and ready \
			and first_visible_usec >= 0 and cleanup_released \
			and fixed_pose_applied and not bool(clipping.is_clipped) else "FAIL",
		"configure_accepted": configure_accepted,
		"fixed_pose_applied": fixed_pose_applied,
		"timing_usec": {
			"packed_scene_instantiate_call": (
				instantiate_finished - instantiate_started
			),
			"add_child_call": add_child_finished - add_child_started,
			"add_child_start_to_backend_ready": (
				backend_ready_usec - add_child_started
			),
			"configure_call": configure_returned - configure_started,
			"configure_start_to_backend_ready": (
				backend_ready_usec - configure_started
			),
			"configure_start_to_first_nonempty_alpha": (
				first_visible_usec - configure_started
				if first_visible_usec >= 0 else -1
			),
		},
		"first_nonempty_alpha_frame": {
			"observed": first_visible_usec >= 0,
			"process_frame_index": first_visible_frame,
			"alpha_threshold": ALPHA_THRESHOLD,
			"bounds": _rect_to_array(first_visible_bounds),
		},
		"memory": {
			"before": before_memory,
			"active_before_cpu_samples": memory_active,
			"active_after_cpu_samples": memory_after_samples,
			"after_cleanup_immediate": memory_after_cleanup_immediate,
			"after_cleanup": memory_after_cleanup,
			"active_delta_from_before": _memory_delta(
				before_memory, memory_active
			),
			"cleanup_delta_from_before": _memory_delta(
				before_memory, memory_after_cleanup
			),
		},
		"cpu_process_frametime_msec": _sample_summary(cpu_samples_msec),
		"cpu_monitor_warmup_seconds": CPU_MONITOR_WARMUP_SECONDS,
		"wall_frame_interval_msec": _sample_summary(wall_samples_msec),
		"gpu_frametime": _report.limitations.gpu_frametime,
		"sharpness": sharpness,
		"clipping": clipping,
		"capture": capture_record,
		"cleanup_released_subviewport": cleanup_released,
		"cleanup_settle_seconds": CLEANUP_SETTLE_SECONDS,
		"room_change_stability": _report.limitations.room_change_stability,
	}


func _memory_snapshot() -> Dictionary:
	return {
		"static_memory_bytes": int(
			Performance.get_monitor(Performance.MEMORY_STATIC)
		),
		"static_memory_peak_bytes": int(
			Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
		),
		"rendering_texture_mem_used_bytes": int(
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED
			)
		),
		"rendering_buffer_mem_used_bytes": int(
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_BUFFER_MEM_USED
			)
		),
		"rendering_video_mem_used_bytes": int(
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_VIDEO_MEM_USED
			)
		),
	}


func _memory_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var result := {}
	for key in before:
		result[key] = int(after.get(key, 0)) - int(before.get(key, 0))
	return result


func _alpha_bounds(image: Image, threshold: float) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= threshold:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _clipping_record(image: Image, bounds: Rect2i) -> Dictionary:
	if image == null or image.is_empty() or not bounds.has_area():
		return {
			"is_clipped": true,
			"reason": "EMPTY_ALPHA_BOUNDS",
			"alpha_bounds": _rect_to_array(bounds),
		}
	var right_margin := image.get_width() - (bounds.position.x + bounds.size.x)
	var bottom_margin := image.get_height() - (bounds.position.y + bounds.size.y)
	var margins := {
		"left": bounds.position.x,
		"top": bounds.position.y,
		"right": right_margin,
		"bottom": bottom_margin,
	}
	var touches_border := bounds.position.x <= 0 or bounds.position.y <= 0 \
		or right_margin <= 0 or bottom_margin <= 0
	return {
		"is_clipped": touches_border,
		"method": (
			"alpha > %.3f bounding rectangle compared with all four image borders"
			% ALPHA_THRESHOLD
		),
		"alpha_bounds": _rect_to_array(bounds),
		"margins_pixels": margins,
		"minimum_margin_pixels": mini(
			mini(int(margins.left), int(margins.top)),
			mini(int(margins.right), int(margins.bottom))
		),
	}


func _sharpness_record(image: Image) -> Dictionary:
	if image == null or image.is_empty():
		return {
			"status": "NOT_MEASURED",
			"reason": "EMPTY_IMAGE",
		}
	var common := image.duplicate()
	common.resize(96, 96, Image.INTERPOLATE_LANCZOS)
	var gradients: Array[float] = []
	var laplacians: Array[float] = []
	for y in range(1, common.get_height() - 1):
		for x in range(1, common.get_width() - 1):
			var center: Color = common.get_pixel(x, y)
			var left: Color = common.get_pixel(x - 1, y)
			var right: Color = common.get_pixel(x + 1, y)
			var up: Color = common.get_pixel(x, y - 1)
			var down: Color = common.get_pixel(x, y + 1)
			if minf(center.a, minf(left.a, minf(right.a, minf(up.a, down.a)))) \
					<= ALPHA_THRESHOLD:
				continue
			var center_luma := _luminance(center)
			var left_luma := _luminance(left)
			var right_luma := _luminance(right)
			var up_luma := _luminance(up)
			var down_luma := _luminance(down)
			gradients.append(
				(absf(right_luma - left_luma) + absf(down_luma - up_luma))
				* 0.5
			)
			laplacians.append(
				left_luma + right_luma + up_luma + down_luma
				- 4.0 * center_luma
			)
	var gradient_summary := _sample_summary(gradients)
	var laplacian_variance := 0.0
	if not laplacians.is_empty():
		var mean := 0.0
		for value in laplacians:
			mean += value
		mean /= float(laplacians.size())
		for value in laplacians:
			laplacian_variance += (value - mean) * (value - mean)
		laplacian_variance /= float(laplacians.size())
	return {
		"status": "MEASURED",
		"method": (
			"Each source is Lanczos-resampled to the common 96x96 gameplay "
			+ "display footprint; gradients and Laplacian variance exclude "
			+ "transparent-edge pixels. Values are comparative, not a perceptual "
			+ "quality score."
		),
		"common_display_size": [96, 96],
		"interior_sample_count": gradients.size(),
		"interior_luminance_gradient": gradient_summary,
		"interior_laplacian_variance": laplacian_variance,
	}


func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _sample_summary(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {"count": 0, "mean": 0.0, "median": 0.0, "p95": 0.0, "max": 0.0}
	var ordered := samples.duplicate()
	ordered.sort()
	var total := 0.0
	for sample in ordered:
		total += sample
	var p95_index := mini(
		ordered.size() - 1,
		int(ceil(float(ordered.size()) * 0.95)) - 1
	)
	var median: float = ordered[ordered.size() / 2]
	if ordered.size() % 2 == 0:
		median = (
			ordered[ordered.size() / 2 - 1] + ordered[ordered.size() / 2]
		) * 0.5
	return {
		"count": ordered.size(),
		"mean": total / float(ordered.size()),
		"median": median,
		"p95": ordered[p95_index],
		"max": ordered[ordered.size() - 1],
	}


func _save_viewport_capture(image: Image, resolution: int) -> Dictionary:
	var file_name := "benchmark_viewport_%d.png" % resolution
	var path := _capture_dir.path_join(file_name)
	var save_error := image.save_png(path) if image != null else ERR_INVALID_DATA
	if save_error != OK:
		_fail("Viewport benchmark capture failed for %d." % resolution)
	return {
		"file": file_name,
		"path": path,
		"save_error": save_error,
		"sha256": (
			FileAccess.get_sha256(path).to_upper() if save_error == OK else ""
		),
		"size": [
			image.get_width() if image != null else 0,
			image.get_height() if image != null else 0,
		],
	}


func _rect_to_array(rect: Rect2i) -> Array[int]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("ACHILLES SUBVIEWPORT BENCHMARK: %s" % message)


func _finish() -> void:
	_report.status = "PASS" if _failures.is_empty() else "FAIL"
	if not _artifact_dir.is_empty() and _artifact_dir.is_absolute_path():
		var report_path := _artifact_dir.path_join("resolution_benchmark.json")
		var output := FileAccess.open(report_path, FileAccess.WRITE)
		if output != null:
			output.store_string(JSON.stringify(_report, "  ", false) + "\n")
			output.close()
	print("ACHILLES_SUBVIEWPORT_BENCHMARK=" + JSON.stringify(_report))
	get_tree().quit(0 if _failures.is_empty() else 1)
