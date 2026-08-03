extends Node

const OUTPUT_DIR := "res://artifacts/maps/unit_presence_audit"
const RUN_PATH := "res://data/runs/first_run.tres"
const ROOM_INDICES := [0, 4, 5]
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var _report := {
	"generated_at": "2026-08-03",
	"mode": "painted_unit_presence_final",
	"maps": {},
}
var _opaque_bounds_cache := {}


func begin() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	call_deferred("_run")


func _run() -> void:
	_load_existing_report()
	var requested_resolution := _requested_resolution()
	if requested_resolution != Vector2i.ZERO:
		get_window().size = requested_resolution
		await _frames(3)
	var run := load(RUN_PATH) as RunData
	if run == null or not GameManager._prepare_preconfigured_run(
			run, GameManager.PRODUCTION_HERO_DATA_PATHS
		):
		push_error("UnitPresenceAudit: configuration de run indisponible.")
		get_tree().quit(2)
		return
	for room_index in _selected_room_indices():
		await _capture_room(room_index)
	_write_json("%s/final_metrics.json" % OUTPUT_DIR, _report)
	GameManager.cleanup_run_state()
	print("UNIT_PRESENCE_FINAL_COMPLETE maps=3 resolutions=3")
	get_tree().quit(0)


func _selected_room_indices() -> Array[int]:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--room-index="):
			return [int(argument.trim_prefix("--room-index="))]
	var indices: Array[int] = []
	for room_index in ROOM_INDICES:
		indices.append(room_index)
	return indices


func _requested_resolution() -> Vector2i:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--resolution="):
			continue
		match argument.trim_prefix("--resolution="):
			"720p":
				return Vector2i(1280, 720)
			"1080p":
				return Vector2i(1920, 1080)
			"1440p":
				return Vector2i(2560, 1440)
	return Vector2i.ZERO


func _load_existing_report() -> void:
	var path := "%s/final_metrics.json" % OUTPUT_DIR
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and parsed.get("mode", "") == _report.mode:
		_report = parsed


func _capture_room(room_index: int) -> void:
	GameManager.current_room_index = room_index
	seed(4200 + room_index)
	var room := GameManager.get_current_room()
	get_tree().change_scene_to_packed.call_deferred(room.battle_scene)
	await get_tree().scene_changed
	await _frames(5)
	var battle = get_tree().current_scene
	var deployed := 0
	for cell in room.hero_spawn_zone:
		if deployed >= GameManager.heroes.size():
			break
		if battle.grid.is_walkable(cell):
			battle._deployment.on_cell_clicked(cell)
			deployed += 1
			await get_tree().process_frame
	await get_tree().create_timer(1.25).timeout
	var banner := get_tree().root.find_child("TurnIntroBanner", true, false)
	if is_instance_valid(banner):
		if banner.has_method("hide_immediately"):
			banner.hide_immediately()
		banner.process_mode = Node.PROCESS_MODE_DISABLED
		banner.visible = false
		banner.modulate.a = 0.0
	var map_id := str(room.painted_map_visual_data.map_id)
	var room_dir := "%s/%s" % [OUTPUT_DIR, map_id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(room_dir))
	if "--cutouts-only" in OS.get_cmdline_user_args():
		_export_raw_unit_cutouts(battle)
		return
	var map_report := {
		"room_index": room_index,
		"room_name": room.room_name,
		"camera_zoom": room.painted_map_visual_data.camera_zoom,
		"camera_offset": _vec2(room.painted_map_visual_data.camera_offset),
		"battle_unit_view_scale": battle.iso_unit_view_scale,
		"presentation_profile": str(battle.presentation_profile.profile_id),
		"camera_zoom_multiplier": battle.presentation_profile.camera_zoom_multiplier,
		"camera_offset_adjustment": _vec2(
			battle.presentation_profile.camera_offset_adjustment
		),
		"global_unit_scale_multiplier": (
			battle.presentation_profile.global_unit_scale_multiplier
		),
		"unit_count": battle.units.size(),
		"resolutions": {},
	}
	var previous_map = _report.maps.get(map_id, {})
	if previous_map is Dictionary:
		map_report.resolutions = previous_map.get("resolutions", {}).duplicate(true)
	var requested_resolution := _requested_resolution()
	if requested_resolution != Vector2i.ZERO:
		await _capture_requested_resolution(
			battle, room_dir, map_report, requested_resolution
		)
		_report.maps[map_id] = map_report
		return
	get_window().size = Vector2i(1920, 1080)
	battle.apply_presentation_variant(false, false, false)
	await _frames(5)
	await _capture("%s/post_change_baseline_recheck.png" % room_dir)
	battle.apply_presentation_variant(true, false, false)
	await _frames(5)
	await _capture("%s/camera_only.png" % room_dir)
	battle.apply_presentation_variant(true, true, false)
	await _frames(5)
	await _capture("%s/camera_and_scale.png" % room_dir)
	battle.apply_presentation_variant(true, true, true)
	await _frames(5)
	await _capture("%s/final_readability.png" % room_dir)
	for resolution in RESOLUTIONS:
		get_window().size = resolution
		await _frames(5)
		var label := _resolution_label(resolution)
		map_report.resolutions[label] = _measure_scene(battle, resolution)
		var filename := "final.png" if resolution == Vector2i(1920, 1080) \
			else "final_%s.png" % label
		await _capture("%s/%s" % [room_dir, filename])
	get_window().size = Vector2i(1920, 1080)
	battle.apply_presentation_variant(true, true, true)
	await _frames(5)
	_export_raw_unit_cutouts(battle)
	await _capture("%s/front_center_back_units.png" % room_dir)
	await _capture_action_states(battle, room_dir)
	_report.maps[map_id] = map_report


func _capture_requested_resolution(
		battle,
		room_dir: String,
		map_report: Dictionary,
		resolution: Vector2i
	) -> void:
	if resolution == Vector2i(1920, 1080):
		battle.apply_presentation_variant(false, false, false)
		await _frames(5)
		await _capture("%s/post_change_baseline_recheck.png" % room_dir)
		battle.apply_presentation_variant(true, false, false)
		await _frames(5)
		await _capture("%s/camera_only.png" % room_dir)
		battle.apply_presentation_variant(true, true, false)
		await _frames(5)
		await _capture("%s/camera_and_scale.png" % room_dir)
	battle.apply_presentation_variant(true, true, true)
	await _frames(5)
	var label := _resolution_label(resolution)
	map_report.resolutions[label] = _measure_scene(battle, resolution)
	var filename := "final.png" if resolution == Vector2i(1920, 1080) \
		else "final_%s.png" % label
	await _capture("%s/%s" % [room_dir, filename])
	if resolution == Vector2i(1920, 1080):
		await _capture("%s/final_readability.png" % room_dir)
		_export_raw_unit_cutouts(battle)
		await _capture("%s/front_center_back_units.png" % room_dir)
		await _capture_action_states(battle, room_dir)


func _export_raw_unit_cutouts(battle) -> void:
	var output := "%s/raw_models" % OUTPUT_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for unit in battle.units:
		var view = battle._unit_views.get(unit)
		if not is_instance_valid(view) or not view.has_optional_visual():
			continue
		var visual = view.get_optional_visual()
		if not visual is CharacterIsoUnitView:
			continue
		var image := (visual as CharacterIsoUnitView).character_viewport.get_texture().get_image()
		if image != null and not image.is_empty():
			image.save_png(ProjectSettings.globalize_path(
				"%s/%s.png" % [output, str(unit.unit_id)]
			))


func _capture_action_states(battle, room_dir: String) -> void:
	var subject_view: Node2D = null
	for unit in battle.units:
		if unit.team == 0:
			subject_view = battle._unit_views.get(unit)
			break
	if not is_instance_valid(subject_view):
		return
	subject_view.set_active(true)
	await _frames(3)
	await _capture("%s/active_unit.png" % room_dir)
	var visual = subject_view.get_optional_visual()
	if visual == null:
		return
	if visual.has_method("play_walk"):
		visual.play_walk()
		await get_tree().create_timer(0.22).timeout
		await _capture("%s/movement.png" % room_dir)
	if visual.has_method("play_cast"):
		visual.play_cast()
		await get_tree().create_timer(0.24).timeout
		await _capture("%s/cast.png" % room_dir)
	if visual.has_method("play_hit"):
		visual.play_hit()
		await get_tree().create_timer(0.12).timeout
		await _capture("%s/hit.png" % room_dir)
	if visual.has_method("play_death"):
		visual.play_death()
		await get_tree().create_timer(0.28).timeout
		await _capture("%s/death.png" % room_dir)


func _measure_scene(battle, resolution: Vector2i) -> Dictionary:
	var grid_bounds := _logical_platform_screen_bounds(battle)
	var reference_cell := Vector2i(6, 6)
	var cell_bounds := _screen_bounds_for_polygon(
		battle.grid_view,
		battle.grid_view.get_cell_polygon(reference_cell)
	)
	var units := []
	for unit in battle.units:
		var view = battle._unit_views.get(unit)
		if not is_instance_valid(view):
			continue
		var visual_bounds := _unit_visual_screen_bounds(view, str(unit.unit_id))
		var foot: Vector2 = view.get_global_transform_with_canvas() * Vector2.ZERO
		units.append({
			"unit_id": str(unit.unit_id),
			"team": unit.team,
			"grid_cell": _vec2i(unit.grid_pos),
			"visible_width_px": visual_bounds.size.x,
			"visible_height_px": visual_bounds.size.y,
			"width_per_cell_width": _safe_ratio(visual_bounds.size.x, cell_bounds.size.x),
			"height_per_projected_cell_height": _safe_ratio(visual_bounds.size.y, cell_bounds.size.y),
			"foot_screen": _vec2(foot),
			"unit_view_position": _vec2(view.position),
			"unit_view_scale": _vec2(view.scale),
			"painted_visual_scale": view.get_painted_visual_scale(),
			"logical_foot_local": _vec2(view.get_logical_foot_position()),
		})
	return {
		"viewport": _vec2i(resolution),
		"logical_platform_bounds": _rect(grid_bounds),
		"platform_width_percent": 100.0 * grid_bounds.size.x / float(resolution.x),
		"platform_height_percent": 100.0 * grid_bounds.size.y / float(resolution.y),
		"cell_width_px": cell_bounds.size.x,
		"cell_height_px": cell_bounds.size.y,
		"peripheral_decor_percent": 100.0 * (1.0 - (
			grid_bounds.size.x * grid_bounds.size.y
			/ float(resolution.x * resolution.y)
		)),
		"distance_platform_to_viewport_bottom_px": float(resolution.y) - grid_bounds.end.y,
		"units": units,
	}


func _logical_platform_screen_bounds(battle) -> Rect2:
	var points := PackedVector2Array()
	for y in range(battle.grid_rows):
		for x in range(battle.grid_cols):
			var cell := Vector2i(x, y)
			if battle.grid.get_type(cell) == GridData.CellType.HOLE:
				continue
			for point in battle.grid_view.get_cell_polygon(cell):
				points.append(battle.grid_view.get_global_transform_with_canvas() * point)
	return _bounds(points)


func _screen_bounds_for_polygon(node: Node2D, polygon: PackedVector2Array) -> Rect2:
	var points := PackedVector2Array()
	for point in polygon:
		points.append(node.get_global_transform_with_canvas() * point)
	return _bounds(points)


func _unit_visual_screen_bounds(view: Node2D, visual_key: String) -> Rect2:
	var visual = view.get_optional_visual() if view.has_method("get_optional_visual") else null
	if not visual is CharacterIsoUnitView:
		return Rect2(view.get_global_transform_with_canvas() * Vector2(-15, -58), Vector2(30, 58))
	var character := visual as CharacterIsoUnitView
	if not _opaque_bounds_cache.has(visual_key):
		var rendered := character.character_viewport.get_texture().get_image()
		if rendered == null or rendered.is_empty():
			return _fallback_visual_screen_bounds(view)
		_opaque_bounds_cache[visual_key] = _opaque_bounds(rendered)
	var opaque: Rect2i = _opaque_bounds_cache[visual_key]
	var points := PackedVector2Array()
	for point in [
		Vector2(opaque.position),
		Vector2(opaque.end.x, opaque.position.y),
		Vector2(opaque.end),
		Vector2(opaque.position.x, opaque.end.y),
	]:
		points.append(character.render_sprite.get_global_transform_with_canvas() * point)
	return _bounds(points)


func _fallback_visual_screen_bounds(view: Node2D) -> Rect2:
	var transform := view.get_global_transform_with_canvas()
	return _bounds(PackedVector2Array([
		transform * Vector2(-15.0, -58.0),
		transform * Vector2(15.0, -58.0),
		transform * Vector2(15.0, 0.0),
		transform * Vector2(-15.0, 0.0),
	]))


func _opaque_bounds(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.02:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var minimum := points[0]
	var maximum := points[0]
	for point in points.slice(1):
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _capture(resource_path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("UnitPresenceAudit: rendu indisponible pour %s" % resource_path)
		return
	var error := image.save_png(ProjectSettings.globalize_path(resource_path))
	if error != OK:
		push_error("UnitPresenceAudit: capture impossible %s" % resource_path)


func _write_json(resource_path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(resource_path, FileAccess.WRITE)
	if file == null:
		push_error("UnitPresenceAudit: JSON impossible %s" % resource_path)
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()


func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame


func _resolution_label(size: Vector2i) -> String:
	return "%dp" % size.y


func _safe_ratio(numerator: float, denominator: float) -> float:
	return numerator / denominator if not is_zero_approx(denominator) else 0.0


func _vec2(value: Vector2) -> Array:
	return [value.x, value.y]


func _vec2i(value: Vector2i) -> Array:
	return [value.x, value.y]


func _rect(value: Rect2) -> Dictionary:
	return {"x": value.position.x, "y": value.position.y, "width": value.size.x, "height": value.size.y}
