extends Node

const OUTPUT_DIR := "res://artifacts/maps/unit_presence_audit"
const RUN_PATH := "res://data/runs/first_run.tres"
const ROOM_INDICES := [0, 4, 5]
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const MOVEMENT_CELLS := [
	Vector2i(3, 10),
	Vector2i(4, 10),
	Vector2i(5, 10),
	Vector2i(6, 10),
	Vector2i(7, 10),
]
const SPELL_CENTER := Vector2i(9, 3)
const CAPTURE_NAMES := [
	"final.png",
	"debug_grid.png",
	"unit_behind_occluder.png",
	"unit_side_of_occluder.png",
	"unit_in_front_of_occluder.png",
	"several_units_occlusion.png",
	"movement_overlay.png",
	"spell_overlay.png",
	"active_unit.png",
]

var _report := {
	"generated_at": "",
	"mode": "painted_unit_presence_final_v2",
	"force_regenerate": false,
	"maps": {},
}
var _opaque_bounds_cache := {}


func begin() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	call_deferred("_run")


func _run() -> void:
	_report.generated_at = Time.get_date_string_from_system()
	_report.force_regenerate = _force_regenerate()
	if not _report.force_regenerate:
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
	print(
		"UNIT_PRESENCE_FINAL_COMPLETE maps=%d force=%s" % [
			_report.maps.size(),
			str(_report.force_regenerate),
		]
	)
	get_tree().quit(0)


func _force_regenerate() -> bool:
	var arguments := OS.get_cmdline_user_args()
	return "--force" in arguments or "force_regenerate=true" in arguments


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
		_report.generated_at = Time.get_date_string_from_system()
		_report.force_regenerate = false


func _capture_room(room_index: int) -> void:
	GameManager.current_room_index = room_index
	seed(4200 + room_index)
	var room := GameManager.get_current_room()
	get_tree().change_scene_to_packed.call_deferred(room.battle_scene)
	await get_tree().scene_changed
	await _frames(5)
	var battle = get_tree().current_scene
	await _deploy_heroes(battle, room)
	await get_tree().create_timer(1.25).timeout
	_hide_turn_banner()
	var map_id := str(room.painted_map_visual_data.map_id)
	var room_dir := "%s/%s" % [OUTPUT_DIR, map_id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(room_dir))
	if "--cutouts-only" in OS.get_cmdline_user_args():
		_export_raw_unit_cutouts(battle)
		return
	var map_report := _base_map_report(battle, room, room_index)
	var previous_map = _report.maps.get(map_id, {})
	if previous_map is Dictionary and not _report.force_regenerate:
		map_report.resolutions = previous_map.get(
			"resolutions", {}
		).duplicate(true)
	var resolutions := RESOLUTIONS
	var requested_resolution := _requested_resolution()
	if requested_resolution != Vector2i.ZERO:
		resolutions = [requested_resolution]
	for resolution in resolutions:
		var label := _resolution_label(resolution)
		var resolution_dir := "%s/%s" % [room_dir, label]
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(resolution_dir)
		)
		map_report.resolutions[label] = await _capture_resolution_suite(
			battle,
			resolution,
			resolution_dir
		)
	_export_raw_unit_cutouts(battle)
	_report.maps[map_id] = map_report


func _deploy_heroes(battle, room) -> void:
	var deployed := 0
	for cell in room.hero_spawn_zone:
		if deployed >= GameManager.heroes.size():
			break
		if battle.grid.is_walkable(cell):
			battle._deployment.on_cell_clicked(cell)
			deployed += 1
			await get_tree().process_frame


func _hide_turn_banner() -> void:
	var banner := get_tree().root.find_child("TurnIntroBanner", true, false)
	if not is_instance_valid(banner):
		return
	if banner.has_method("hide_immediately"):
		banner.hide_immediately()
	banner.process_mode = Node.PROCESS_MODE_DISABLED
	banner.visible = false
	banner.modulate.a = 0.0


func _base_map_report(battle, room, room_index: int) -> Dictionary:
	var visual = room.painted_map_visual_data
	return {
		"room_index": room_index,
		"room_name": room.room_name,
		"origin": _vec2(visual.grid_origin),
		"axis_x": _vec2(visual.axis_x),
		"axis_y": _vec2(visual.axis_y),
		"calibration_rms_source_px": visual.calibration_rms(),
		"calibration_max_error_source_px": visual.calibration_max_error(),
		"camera_zoom": visual.camera_zoom,
		"camera_offset": _vec2(visual.camera_offset),
		"battle_unit_view_scale": battle.iso_unit_view_scale,
		"presentation_profile": str(battle.presentation_profile.profile_id),
		"camera_zoom_multiplier": (
			battle.presentation_profile.camera_zoom_multiplier
		),
		"camera_offset_adjustment": _vec2(
			battle.presentation_profile.camera_offset_adjustment
		),
		"global_unit_scale_multiplier": (
			battle.presentation_profile.global_unit_scale_multiplier
		),
		"unit_count": battle.units.size(),
		"resolutions": {},
	}


func _capture_resolution_suite(
		battle,
		resolution: Vector2i,
		resolution_dir: String
	) -> Dictionary:
	get_window().size = resolution
	battle.apply_presentation_variant(true, true, true)
	await _frames(6)
	battle.set_process(false)
	battle._update_painted_occlusion()
	var views := _audit_views(battle)
	var original_positions := {}
	for view in views:
		original_positions[view] = view.position
	var captures := {}
	await _capture_named(resolution_dir, "final.png", captures)
	await _capture_debug_grid(battle, resolution_dir, captures)
	var before_measured := await _capture_before_state(
		battle,
		resolution,
		resolution_dir,
		captures
	)
	var occlusion := await _capture_occlusion_states(
		battle,
		views,
		original_positions,
		resolution_dir,
		captures
	)
	await _capture_movement_overlay(battle, resolution_dir, captures)
	await _capture_spell_overlay(battle, resolution_dir, captures)
	await _capture_active_unit(views, resolution_dir, captures)
	if resolution == Vector2i(1920, 1080):
		await _capture_animation_states(views, resolution_dir, captures)
	_restore_positions(views, original_positions)
	battle._update_painted_occlusion()
	await _frames(2)
	var fps := await _sample_fps(24)
	var measured := _measure_scene(battle, resolution)
	measured.before_presentation = before_measured
	measured.fps = fps
	measured.test_unit_count = mini(4, views.size())
	measured.occlusion_results = occlusion
	measured.captures = captures
	battle.set_process(true)
	return measured


func _capture_debug_grid(battle, directory: String, captures: Dictionary) -> void:
	battle.grid_view.set_render_options(false, true, true, true)
	battle.grid_view.set_debug_layers(true, true, true, true, true)
	await _frames(2)
	await _capture_named(directory, "debug_grid.png", captures)
	battle.grid_view.set_render_options(false, false, false, false)
	battle.grid_view.set_debug_layers(false, false, false, false, false)
	await _frames(2)


func _capture_before_state(
		battle,
		resolution: Vector2i,
		directory: String,
		captures: Dictionary
	) -> Dictionary:
	battle.apply_presentation_variant(false, false, false)
	battle._update_painted_occlusion()
	await _frames(3)
	await _capture_named(directory, "before.png", captures)
	var measured := _measure_scene(battle, resolution)
	battle.apply_presentation_variant(true, true, true)
	battle._update_painted_occlusion()
	await _frames(3)
	return measured


func _capture_occlusion_states(
		battle,
		views: Array,
		original_positions: Dictionary,
		directory: String,
		captures: Dictionary
	) -> Dictionary:
	var visual = battle.painted_visual_data
	var rect: Rect2 = visual.foreground_full_hide_rect
	var positions := {
		"behind": rect.get_center(),
		"side_left": Vector2(rect.position.x - 28.0, rect.get_center().y),
		"side_right": Vector2(rect.end.x + 28.0, rect.get_center().y),
		"front": Vector2(rect.get_center().x, rect.end.y + 28.0),
	}
	var result := {
		"positions_image_px": {
			"behind": _vec2(positions.behind),
			"side_left": _vec2(positions.side_left),
			"side_right": _vec2(positions.side_right),
			"front": _vec2(positions.front),
		},
		"behind_hidden": false,
		"side_visible": false,
		"front_visible": false,
		"several_units_expected": [false, true, true, true],
		"several_units_actual": [],
		"occluder_count": _occluders(battle).size(),
		"y_sort_enabled": (
			battle.get_node("YSortedWorld") as Node2D
		).y_sort_enabled,
	}
	if views.is_empty():
		return result
	var subject: Node2D = views[0]
	subject.position = positions.behind
	_set_occluders_visible(battle, false)
	subject.visible = true
	await _frames(2)
	await _capture_named(directory, "occlusion_off.png", captures)
	_set_occluders_visible(battle, true)
	battle._update_painted_occlusion()
	result.behind_hidden = not subject.visible
	await _frames(2)
	await _capture_named(
		directory,
		"unit_behind_occluder.png",
		captures
	)
	subject.position = positions.side_left
	battle._update_painted_occlusion()
	result.side_visible = subject.visible
	await _frames(2)
	await _capture_named(
		directory,
		"unit_side_of_occluder.png",
		captures
	)
	subject.position = positions.front
	battle._update_painted_occlusion()
	result.front_visible = subject.visible
	await _frames(2)
	await _capture_named(
		directory,
		"unit_in_front_of_occluder.png",
		captures
	)
	var several_positions := [
		positions.behind,
		positions.side_left,
		positions.side_right,
		positions.front,
	]
	for index in mini(views.size(), several_positions.size()):
		views[index].position = several_positions[index]
	battle._update_painted_occlusion()
	for index in mini(views.size(), several_positions.size()):
		result.several_units_actual.append(views[index].visible)
	await _frames(2)
	await _capture_named(
		directory,
		"several_units_occlusion.png",
		captures
	)
	_restore_positions(views, original_positions)
	battle._update_painted_occlusion()
	return result


func _capture_movement_overlay(
		battle,
		directory: String,
		captures: Dictionary
	) -> void:
	battle.grid_view.clear_highlights()
	battle.grid_view.highlight(
		MOVEMENT_CELLS,
		Color(0.22, 0.9, 0.42, 0.58)
	)
	await _frames(2)
	await _capture_named(directory, "movement_overlay.png", captures)
	battle.grid_view.clear_highlights()


func _capture_spell_overlay(
		battle,
		directory: String,
		captures: Dictionary
	) -> void:
	var cells := []
	for y in range(battle.grid_rows):
		for x in range(battle.grid_cols):
			var cell := Vector2i(x, y)
			if battle.grid.is_terrain_interactable(cell) \
					and absi(cell.x - SPELL_CENTER.x) \
					+ absi(cell.y - SPELL_CENTER.y) <= 3:
				cells.append(cell)
	battle.grid_view.highlight(cells, Color(0.28, 0.5, 1.0, 0.56))
	await _frames(2)
	await _capture_named(directory, "spell_overlay.png", captures)
	battle.grid_view.clear_highlights()


func _capture_active_unit(
		views: Array,
		directory: String,
		captures: Dictionary
	) -> void:
	if views.is_empty():
		return
	views[0].set_active(true)
	await _frames(2)
	await _capture_named(directory, "active_unit.png", captures)
	views[0].set_active(false)


func _capture_animation_states(
		views: Array,
		directory: String,
		captures: Dictionary
	) -> void:
	if views.is_empty() or not views[0].has_optional_visual():
		return
	var visual = views[0].get_optional_visual()
	for state in [
		["play_walk", "walk_animation.png", 0.22],
		["play_cast", "cast_animation.png", 0.24],
		["play_hit", "hit_animation.png", 0.12],
	]:
		if not visual.has_method(state[0]):
			continue
		visual.call(state[0])
		await get_tree().create_timer(state[2]).timeout
		await _capture_named(directory, state[1], captures)
	if visual.has_method("play_idle"):
		visual.play_idle()
	await _frames(2)


func _audit_views(battle) -> Array:
	var views := []
	for team in [0, 1]:
		for unit in battle.units:
			if unit.team != team:
				continue
			var view = battle._unit_views.get(unit)
			if is_instance_valid(view):
				views.append(view)
	return views


func _restore_positions(views: Array, positions: Dictionary) -> void:
	for view in views:
		if is_instance_valid(view) and positions.has(view):
			view.position = positions[view]


func _occluders(battle) -> Array:
	var result := []
	var world := battle.get_node("YSortedWorld") as Node2D
	for child in world.get_children():
		if child.is_in_group("painted_foreground_occluders"):
			result.append(child)
	return result


func _set_occluders_visible(battle, visible: bool) -> void:
	for occluder in _occluders(battle):
		occluder.visible = visible


func _capture_named(
		directory: String,
		filename: String,
		captures: Dictionary
	) -> void:
	var path := "%s/%s" % [directory, filename]
	await _capture(path)
	captures[filename.trim_suffix(".png")] = path


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
		var image := (
			visual as CharacterIsoUnitView
		).character_viewport.get_texture().get_image()
		if image != null and not image.is_empty():
			image.save_png(ProjectSettings.globalize_path(
				"%s/%s.png" % [output, str(unit.unit_id)]
			))


func _sample_fps(frame_count: int) -> Dictionary:
	await _frames(12)
	var samples: Array[float] = []
	var previous_tick := Time.get_ticks_usec()
	for _index in frame_count:
		await get_tree().process_frame
		var current_tick := Time.get_ticks_usec()
		var elapsed_usec := current_tick - previous_tick
		previous_tick = current_tick
		if elapsed_usec > 0:
			samples.append(1000000.0 / float(elapsed_usec))
	if samples.is_empty():
		return {"average": 0.0, "minimum": 0.0, "samples": 0}
	var total := 0.0
	var minimum := samples[0]
	for sample in samples:
		total += sample
		minimum = minf(minimum, sample)
	return {
		"average": total / float(samples.size()),
		"minimum": minimum,
		"samples": samples.size(),
		"method": "frame_interval_after_12_frame_warmup",
	}


func _measure_scene(battle, resolution: Vector2i) -> Dictionary:
	var grid_bounds := _logical_platform_screen_bounds(battle)
	var reference_cell := Vector2i(6, 6)
	var cell_bounds := _screen_bounds_for_polygon(
		battle.grid_view,
		battle.grid_view.get_cell_polygon(reference_cell)
	)
	var units := []
	var ally_scales: Array[float] = []
	var enemy_scales: Array[float] = []
	var hero_widths: Array[float] = []
	var hero_heights: Array[float] = []
	var width_ratios: Array[float] = []
	var height_ratios: Array[float] = []
	var foot_errors: Array[float] = []
	for unit in battle.units:
		var view = battle._unit_views.get(unit)
		if not is_instance_valid(view):
			continue
		var visual_bounds := _unit_visual_screen_bounds(view, str(unit.unit_id))
		var foot: Vector2 = view.get_global_transform_with_canvas() * Vector2.ZERO
		var width_ratio := _safe_ratio(
			visual_bounds.size.x,
			cell_bounds.size.x
		)
		var height_ratio := _safe_ratio(
			visual_bounds.size.y,
			cell_bounds.size.y
		)
		var visual_scale: float = view.get_painted_visual_scale()
		var foot_error: float = view.get_logical_foot_position().length()
		width_ratios.append(width_ratio)
		height_ratios.append(height_ratio)
		foot_errors.append(foot_error)
		if unit.team == 0:
			ally_scales.append(visual_scale)
			hero_widths.append(visual_bounds.size.x)
			hero_heights.append(visual_bounds.size.y)
		else:
			enemy_scales.append(visual_scale)
		units.append({
			"unit_id": str(unit.unit_id),
			"team": unit.team,
			"grid_cell": _vec2i(unit.grid_pos),
			"visible_width_px": visual_bounds.size.x,
			"visible_height_px": visual_bounds.size.y,
			"width_per_cell_width": width_ratio,
			"height_per_projected_cell_height": height_ratio,
			"foot_screen": _vec2(foot),
			"unit_view_position": _vec2(view.position),
			"unit_view_scale": _vec2(view.scale),
			"painted_visual_scale": visual_scale,
			"logical_foot_local": _vec2(view.get_logical_foot_position()),
			"foot_anchor_error_px": foot_error,
		})
	var viewport_area := float(resolution.x * resolution.y)
	var tactical_area := grid_bounds.size.x * grid_bounds.size.y
	return {
		"viewport": _vec2i(resolution),
		"origin": _vec2(battle.painted_visual_data.grid_origin),
		"axis_x": _vec2(battle.painted_visual_data.axis_x),
		"axis_y": _vec2(battle.painted_visual_data.axis_y),
		"logical_platform_bounds": _rect(grid_bounds),
		"platform_width_percent": (
			100.0 * grid_bounds.size.x / float(resolution.x)
		),
		"platform_height_percent": (
			100.0 * grid_bounds.size.y / float(resolution.y)
		),
		"tactical_viewport_percent": 100.0 * tactical_area / viewport_area,
		"apparent_cell_size_px": {
			"width": cell_bounds.size.x,
			"height": cell_bounds.size.y,
		},
		"camera_zoom": {
			"resource": battle.painted_visual_data.camera_zoom,
			"presentation_multiplier": (
				battle.presentation_profile.camera_zoom_multiplier
			),
			"effective_canvas_zoom": battle.camera.zoom.x,
		},
		"visual_scales": {
			"allies": _summary(ally_scales),
			"enemies": _summary(enemy_scales),
		},
		"hero_visible_size_px": {
			"width": _summary(hero_widths),
			"height": _summary(hero_heights),
		},
		"unit_cell_ratios": {
			"width": _summary(width_ratios),
			"height": _summary(height_ratios),
		},
		"foot_anchor_error_px": _summary(foot_errors),
		"peripheral_decor_percent": (
			100.0 * (1.0 - tactical_area / viewport_area)
		),
		"distance_platform_to_viewport_bottom_px": (
			float(resolution.y) - grid_bounds.end.y
		),
		"units": units,
	}


func _summary(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"minimum": 0.0, "maximum": 0.0, "average": 0.0}
	var minimum := values[0]
	var maximum := values[0]
	var total := 0.0
	for value in values:
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
		total += value
	return {
		"minimum": minimum,
		"maximum": maximum,
		"average": total / float(values.size()),
	}


func _logical_platform_screen_bounds(battle) -> Rect2:
	var points := PackedVector2Array()
	for y in range(battle.grid_rows):
		for x in range(battle.grid_cols):
			var cell := Vector2i(x, y)
			if battle.grid.get_type(cell) == GridData.CellType.HOLE:
				continue
			for point in battle.grid_view.get_cell_polygon(cell):
				points.append(
					battle.grid_view.get_global_transform_with_canvas() * point
				)
	return _bounds(points)


func _screen_bounds_for_polygon(
		node: Node2D,
		polygon: PackedVector2Array
	) -> Rect2:
	var points := PackedVector2Array()
	for point in polygon:
		points.append(node.get_global_transform_with_canvas() * point)
	return _bounds(points)


func _unit_visual_screen_bounds(view: Node2D, visual_key: String) -> Rect2:
	var visual = (
		view.get_optional_visual()
		if view.has_method("get_optional_visual")
		else null
	)
	if not visual is CharacterIsoUnitView:
		return _fallback_visual_screen_bounds(view)
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
		points.append(
			character.render_sprite.get_global_transform_with_canvas() * point
		)
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
	return {
		"x": value.position.x,
		"y": value.position.y,
		"width": value.size.x,
		"height": value.size.y,
	}
