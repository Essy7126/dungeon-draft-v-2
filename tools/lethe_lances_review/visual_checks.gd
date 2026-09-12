extends RefCounted

const CONFIG := "res://assets/catabase/combat/lethe_lances_v1/visual_review.json"
const FRAMING := preload("res://tools/registered_terrain_validation/framing_proportion_checks.gd")
const REGION_NAMES := ["water", "torch", "lantern", "stable_ground"]


static func run(
	battle: Node,
	capture_path: String,
	config_path: String = CONFIG,
	region_names: Array = REGION_NAMES,
) -> Dictionary:
	if not FileAccess.file_exists(config_path):
		return { "ok": false, "errors": ["painted_visual_config_missing"], "config": config_path }
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not config is Dictionary or not config.get("regions", null) is Dictionary:
		return { "ok": false, "errors": ["painted_visual_config_invalid"], "config": config_path }
	var boat: Rect2 = _read_rect(config.get("boat_region", []))
	var regions := { }
	if boat.size.x <= 0.0 or boat.size.y <= 0.0:
		return { "ok": false, "errors": ["painted_boat_region_invalid"] }
	for name: String in region_names:
		var rect: Rect2 = _read_rect(config.regions.get(name, []))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return { "ok": false, "errors": ["painted_region_invalid:" + name] }
		regions[name] = rect
	var composition := battle.get_node_or_null("GreekTerrainComposition") as Node2D
	var controller_id: String = str(config.get("controller", "WorldDecor_lethe_lances_living"))
	var controller := composition.get_node_or_null(controller_id) if composition != null else null
	if controller == null or not controller.has_method("seek_for_review"):
		return { "ok": false, "errors": ["painted_effect_controller_missing"] }
	var original_time: Variant = controller.get("effect_time")
	if not original_time is float and not original_time is int:
		return { "ok": false, "errors": ["painted_effect_clock_missing"] }
	var hud: Array[Dictionary] = []
	for field: String in ["action_bar", "turn_order_timeline", "inspect_panel", "player_combat_log"]:
		var root := battle.get(field) as Node
		if is_instance_valid(root):
			FRAMING._collect_hud_masks(root, hud)
	var transform: Transform2D = composition.get_global_transform_with_canvas()
	var boat_report: Dictionary = _check_boat(
		boat,
		transform,
		battle.get_viewport().get_visible_rect(),
		hud,
	)
	var errors: Array[String] = []
	if not boat_report.ok:
		errors.append("painted_boat_clipped_or_under_hud")
	if hud.is_empty():
		errors.append("painted_live_hud_masks_missing")
	var prior_reduced := GameManager.is_reduced_motion_enabled()
	var prior_processing: bool = controller.is_processing()
	GameManager.set_reduced_motion_enabled(false)
	var first_time: float = float(controller.get("effect_time"))
	await battle.get_tree().create_timer(0.2).timeout
	var advances: bool = float(controller.get("effect_time")) > first_time
	GameManager.set_reduced_motion_enabled(true)
	var frozen: float = float(controller.get("effect_time"))
	await RenderingServer.frame_post_draw
	var frozen_first := battle.get_viewport().get_texture().get_image()
	await battle.get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var frozen_second := battle.get_viewport().get_texture().get_image()
	var freeze_ok := is_equal_approx(frozen, float(controller.get("effect_time")))
	controller.set_process(false)
	var frames: Array[Image] = []
	var captures: Array[String] = []
	for index in range(8):
		controller.call("seek_for_review", float(index) * 0.45)
		await RenderingServer.frame_post_draw
		var frame := battle.get_viewport().get_texture().get_image()
		var path := capture_path.get_basename() + "-motion-%02d.png" % index
		if frame.save_png(path) != OK:
			errors.append("painted_motion_capture_failed:%d" % index)
		frames.append(frame)
		captures.append(path)
	controller.call("seek_for_review", float(original_time))
	GameManager.set_reduced_motion_enabled(prior_reduced)
	controller.set_process(prior_processing)
	if not advances:
		errors.append("painted_effect_clock_did_not_advance")
	if not freeze_ok:
		errors.append("painted_reduced_motion_did_not_freeze")
	var metrics := { }
	var frozen_metrics := { }
	var frozen_pixels_ok := true
	var frozen_frames: Array[Image] = [frozen_first, frozen_second]
	for name: String in region_names:
		var metric: Dictionary = _measure_region(regions[name], transform, hud, frames)
		metric["ok"] = (
			metric.samples > 0
			and (metric.changed == 0 if name.begins_with("stable_") else metric.changed > 10)
		)
		metrics[name] = metric
		if not metric.ok:
			errors.append("painted_region_motion_invalid:" + name)
		var fixed: Dictionary = _measure_region(regions[name], transform, hud, frozen_frames)
		fixed["ok"] = fixed.samples > 0 and fixed.changed == 0
		frozen_metrics[name] = fixed
		frozen_pixels_ok = frozen_pixels_ok and bool(fixed.ok)
		if not fixed.ok:
			errors.append("painted_reduced_pixels_changed:" + name)
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"config": config_path,
		"config_sha256": FileAccess.get_sha256(config_path),
		"controller": controller_id,
		"boat": boat_report,
		"regions": metrics,
		"clock_advances": advances,
		"reduced_motion_freezes": freeze_ok,
		"reduced_motion_gpu_freezes": frozen_pixels_ok,
		"frozen_regions": frozen_metrics,
		"frames": frames.size(),
		"captures": captures,
		"scope": "Authored boat region projected after production interactions against the live viewport and HUD masks. This checks framing, not boat identity or scenery occlusion; inspect captures. Motion samples omit pixels outside the viewport or under HUD masks.",
	}


static func _read_rect(value: Variant) -> Rect2:
	if not value is Array or value.size() != 4:
		return Rect2()
	for number: Variant in value:
		if (not number is float and not number is int) or not is_finite(float(number)):
			return Rect2()
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))


static func _check_boat(
	boat: Rect2,
	transform: Transform2D,
	viewport: Rect2,
	hud: Array[Dictionary],
) -> Dictionary:
	var polygon: PackedVector2Array = FRAMING._rect_polygon(boat)
	for index in range(polygon.size()):
		polygon[index] = transform * polygon[index]
	var clipped: float = maxf(
		0.0,
		FRAMING._area(polygon)
		- FRAMING._intersection_area(polygon, FRAMING._rect_polygon(viewport)),
	)
	var overlaps: Array[Dictionary] = []
	for mask: Dictionary in hud:
		var overlap: float = FRAMING._intersection_area(polygon, FRAMING._rect_polygon(mask.rect))
		if overlap > FRAMING.PIXEL_AREA_TOLERANCE:
			overlaps.append({ "hud_path": mask.path, "area_px2": overlap })
	var points: Array = []
	for point: Vector2 in polygon:
		points.append([point.x, point.y])
	return {
		"ok": clipped <= FRAMING.PIXEL_AREA_TOLERANCE and overlaps.is_empty(),
		"native_region_xywh": [boat.position.x, boat.position.y, boat.size.x, boat.size.y],
		"screen_polygon": points,
		"clipped_area_px2": clipped,
		"hud_overlaps": overlaps,
	}


static func _measure_region(
	rect: Rect2,
	transform: Transform2D,
	hud: Array[Dictionary],
	frames: Array[Image],
) -> Dictionary:
	var samples := 0
	var changed := 0
	var excluded := 0
	var viewport := Rect2i(Vector2i.ZERO, frames[0].get_size())
	for y in range(int(rect.position.y), int(rect.end.y), 2):
		for x in range(int(rect.position.x), int(rect.end.x), 2):
			var pixel := Vector2i(transform * Vector2(x + 0.5, y + 0.5))
			var masked := false
			for mask: Dictionary in hud:
				var hud_rect: Rect2 = mask.rect
				if hud_rect.has_point(Vector2(pixel)):
					masked = true
					break
			if not viewport.has_point(pixel) or masked:
				excluded += 1
				continue
			samples += 1
			var first := frames[0].get_pixelv(pixel)
			var maximum := 0.0
			for frame: Image in frames:
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
	return { "samples": samples, "changed": changed, "excluded": excluded }
