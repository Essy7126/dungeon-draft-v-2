extends RefCounted

const GEOMETRY := preload("res://tools/registered_terrain_validation/geometry_checks.gd")
const PIXEL_AREA_TOLERANCE := 0.5
const ALPHA_THRESHOLD_BYTE := 26
const RATIO_TOLERANCE := 0.002

# Snapshot oracle: actual floor vertices, current sprite-frame alpha and live HUD
# rectangles. No camera-fit helper or authored unit bounding box supplies proof.
static func run(battle: Node) -> Dictionary:
	await RenderingServer.frame_post_draw
	var errors: Array[String] = []
	var arena := battle.get("room_data") as ArenaDefinition
	var assembly: Dictionary = battle.get("arena_assembly")
	var renderer := assembly.get("renderer") as ArenaTerrainVisualRenderer
	var camera := battle.get("camera") as Camera2D
	if arena == null or renderer == null or camera == null:
		return {"ok": false, "errors": ["framing_live_dependencies_missing"]}
	var viewport: Rect2 = battle.get_viewport().get_visible_rect()
	var viewport_polygon: PackedVector2Array = _rect_polygon(viewport)
	var hud: Array[Dictionary] = []
	for field: String in ["action_bar", "turn_order_timeline", "inspect_panel", "player_combat_log"]:
		var root := battle.get(field) as Node
		if is_instance_valid(root):
			_collect_hud_masks(root, hud)
	if hud.is_empty():
		errors.append("framing_no_live_hud_masks")
	var floor_count := 0
	var floor_bounds := Rect2()
	var floor_clipped: Array = []
	var floor_hud: Array = []
	var tile_width_min := INF
	var tile_width_max := 0.0
	for definition in arena.cells:
		if definition == null or not definition.defined or definition.cell_type == GridData.CellType.HOLE:
			continue
		var tile := renderer.node_for_cell(definition.coordinate)
		var sprite := tile.get_node_or_null("Visual") as Sprite2D if tile != null else null
		if sprite == null:
			errors.append("framing_missing_floor_sprite:%s" % definition.coordinate)
			continue
		var polygon: PackedVector2Array = GEOMETRY.sprite_polygon(sprite)
		var rect: Rect2 = _bounds(polygon)
		floor_bounds = rect if floor_count == 0 else floor_bounds.merge(rect)
		floor_count += 1
		var width: float = polygon[1].distance_to(polygon[3])
		tile_width_min = minf(tile_width_min, width)
		tile_width_max = maxf(tile_width_max, width)
		var clipped: float = maxf(0.0, _area(polygon) - _intersection_area(polygon, viewport_polygon))
		if clipped > PIXEL_AREA_TOLERANCE:
			floor_clipped.append({"cell": [definition.coordinate.x, definition.coordinate.y], "area_px2": clipped})
		for mask: Dictionary in hud:
			var overlap: float = _intersection_area(polygon, _rect_polygon(mask["rect"]))
			if overlap > PIXEL_AREA_TOLERANCE:
				floor_hud.append({"cell": [definition.coordinate.x, definition.coordinate.y], "hud_path": mask["path"], "area_px2": overlap})
	if floor_count == 0 or not floor_clipped.is_empty() or not floor_hud.is_empty():
		errors.append("framing_floor_empty_clipped_or_under_hud")
	if absf(camera.zoom.x - camera.zoom.y) > 0.00001:
		errors.append("framing_camera_zoom_not_uniform")
	var unit_reports: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var views: Dictionary = battle.get("_unit_views")
	for unit: Unit in views:
		var view := views[unit] as Node2D
		if not is_instance_valid(view) or not view.is_visible_in_tree():
			errors.append("framing_unit_view_missing_or_hidden:%s" % unit.unit_id)
			continue
		var tile := renderer.node_for_cell(unit.grid_pos)
		var sprite := tile.get_node_or_null("Visual") as Sprite2D if tile != null else null
		if sprite == null:
			errors.append("framing_unit_floor_missing:%s" % unit.unit_id)
			continue
		var tile_polygon: PackedVector2Array = GEOMETRY.sprite_polygon(sprite)
		var tile_width: float = tile_polygon[1].distance_to(tile_polygon[3])
		var visual := view.call("get_optional_visual") as Node2D if view.has_method("get_optional_visual") else null
		if visual == null:
			visual = view
		var id: String = str(unit.unit_id)
		var occurrence: int = int(seen_ids.get(id, 0))
		seen_ids[id] = occurrence + 1
		var root_transform: Transform2D = view.get_global_transform_with_canvas()
		var visual_transform: Transform2D = visual.get_global_transform_with_canvas()
		var unit_report: Dictionary = {
			"key": "%s#%d" % [id, occurrence], "unit_id": id, "cell": [unit.grid_pos.x, unit.grid_pos.y],
			"foot_screen_px": _point(root_transform.origin), "tile_width_px": tile_width,
			"root_basis_x_per_tile": root_transform.x.length() / tile_width,
			"root_basis_y_per_tile": root_transform.y.length() / tile_width,
			"visual_basis_x_per_tile": visual_transform.x.length() / tile_width,
			"visual_basis_y_per_tile": visual_transform.y.length() / tile_width,
			"painted_visual_scale": float(view.call("get_painted_visual_scale")) if view.has_method("get_painted_visual_scale") else 1.0,
			"sprites": [], "opaque_pixels_tested": 0, "opaque_pixels_outside_viewport": 0, "opaque_pixels_under_hud_masks": 0,
		}
		if absf(visual_transform.x.length() - visual_transform.y.length()) > 0.00001:
			errors.append("framing_unit_visual_scale_not_uniform:" + id)
		var drawable: Array[Node2D] = []
		_collect_unit_sprites(visual, drawable)
		var body_bounds := Rect2()
		var body_count := 0
		for node: Node2D in drawable:
			var sample: Dictionary = _sample_sprite(node, viewport, hud)
			unit_report["sprites"].append(sample)
			if not bool(sample.get("ok", false)):
				errors.append("framing_unit_sprite_not_measurable:" + str(node.get_path()))
				continue
			unit_report["opaque_pixels_tested"] += int(sample["opaque_pixels_tested"])
			unit_report["opaque_pixels_outside_viewport"] += int(sample["opaque_pixels_outside_viewport"])
			unit_report["opaque_pixels_under_hud_masks"] += int(sample["opaque_pixels_under_hud_masks"])
			var rect: Rect2 = sample["bounds_rect"]
			body_bounds = rect if body_count == 0 else body_bounds.merge(rect)
			body_count += 1
			sample.erase("bounds_rect")
		if body_count == 0 or int(unit_report["opaque_pixels_tested"]) == 0:
			errors.append("framing_unit_has_no_measurable_body:" + id)
		if int(unit_report["opaque_pixels_outside_viewport"]) > 0 or int(unit_report["opaque_pixels_under_hud_masks"]) > 0:
			errors.append("framing_unit_body_clipped_or_under_hud:" + id)
		unit_report["opaque_bounds_screen_px"] = _rect(body_bounds)
		unit_report["opaque_height_per_tile_width_snapshot"] = body_bounds.size.y / tile_width
		unit_report["opaque_width_per_tile_width_snapshot"] = body_bounds.size.x / tile_width
		unit_reports.append(unit_report)
	var hud_records: Array[Dictionary] = []
	for mask: Dictionary in hud:
		hud_records.append({"path": mask["path"], "rect_px": _rect(mask["rect"])})
	var profile: BattlePresentationProfile = arena.painted_map_visual_data.presentation_profile
	return {
		"ok": errors.is_empty(), "errors": errors,
		"viewport_size": _point(viewport.size), "camera_zoom": _point(camera.zoom), "camera_position": _point(camera.position),
		"camera_canvas_transform": str(camera.get_viewport().get_canvas_transform()),
		"presentation_profile_path": profile.resource_path if profile != null else "",
		"room_global_unit_multiplier": profile.global_unit_scale_multiplier if profile != null else 1.0,
		"floor_polygons_checked": floor_count, "floor_bounds_screen_px": _rect(floor_bounds),
		"floor_viewport_occupancy_xy": _point(floor_bounds.size / viewport.size),
		"tile_width_min_px": tile_width_min, "tile_width_max_px": tile_width_max,
		"clipped_floor_cells": floor_clipped, "floor_hud_mask_overlaps": floor_hud, "hud_masks": hud_records,
		"units": unit_reports, "alpha_threshold_byte": ALPHA_THRESHOLD_BYTE,
		"scope": "Current live floor polygons and current visible sprite-frame alpha; current visible HUD plate/button/texture rectangles are conservative masks. Opaque silhouette sizes are animation snapshots, not anatomy measurements. Shader-created glow, future movement positions and scenery baked into Land require visual review.",
	}

static func compare_cross_resolution(current: Dictionary, previous: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if current.get("viewport_size", []) == previous.get("viewport_size", []):
		errors.append("framing_comparison_requires_two_distinct_resolutions")
	var previous_units: Dictionary = {}
	for value: Dictionary in previous.get("units", []):
		previous_units[str(value.get("key", ""))] = value
	var comparisons: Array[Dictionary] = []
	for value: Dictionary in current.get("units", []):
		var key: String = str(value.get("key", ""))
		if not previous_units.has(key):
			errors.append("framing_cross_resolution_unit_missing:" + key)
			continue
		var prior: Dictionary = previous_units[key]
		var worst := 0.0
		for field: String in ["root_basis_x_per_tile", "root_basis_y_per_tile", "visual_basis_x_per_tile", "visual_basis_y_per_tile", "painted_visual_scale"]:
			var before: float = float(prior.get(field, 0.0))
			var after: float = float(value.get(field, -1.0))
			worst = maxf(worst, absf(after - before) / maxf(absf(before), 0.000001))
		comparisons.append({"unit": key, "maximum_relative_ratio_change": worst})
		if worst > RATIO_TOLERANCE:
			errors.append("framing_cross_resolution_proportion_changed:" + key)
	if comparisons.is_empty() or comparisons.size() != previous_units.size():
		errors.append("framing_cross_resolution_unit_set_incomplete")
	return {"ok": errors.is_empty(), "errors": errors, "previous_resolution": previous.get("viewport_size", []), "current_resolution": current.get("viewport_size", []), "relative_tolerance": RATIO_TOLERANCE, "units": comparisons, "scope": "Actual root and visual basis lengths divided by actual tile width; independent of camera zoom. Frame-alpha heights are reported separately because animation can change the silhouette between runs."}

static func _collect_hud_masks(node: Node, result: Array[Dictionary]) -> void:
	if node is CanvasLayer and not node.visible:
		return
	if node is CanvasItem and not node.is_visible_in_tree():
		return
	if node is Control and (node is Panel or node is PanelContainer or node is TextureRect or node is BaseButton):
		var control := node as Control
		if control.size.x > 0 and control.size.y > 0 and control.modulate.a * control.self_modulate.a > 0.05:
			var points: PackedVector2Array = _rect_polygon(Rect2(Vector2.ZERO, control.size))
			for index in range(points.size()):
				points[index] = control.get_global_transform_with_canvas() * points[index]
			result.append({"path": str(control.get_path()), "rect": _bounds(points)})
	for child: Node in node.get_children():
		_collect_hud_masks(child, result)

static func _collect_unit_sprites(node: Node, result: Array[Node2D]) -> void:
	if node is SubViewport or (node is CanvasItem and not node.is_visible_in_tree()):
		return
	if node is Sprite2D or node is AnimatedSprite2D:
		result.append(node as Node2D)
	for child: Node in node.get_children():
		_collect_unit_sprites(child, result)

static func _sample_sprite(node: Node2D, viewport: Rect2, hud: Array[Dictionary]) -> Dictionary:
	var texture: Texture2D = null
	var local_rect := Rect2()
	var image: Image = null
	var flip_h := false
	var flip_v := false
	if node is AnimatedSprite2D:
		var animated := node as AnimatedSprite2D
		if animated.sprite_frames != null and animated.sprite_frames.has_animation(animated.animation):
			texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
		if texture != null:
			local_rect = Rect2(animated.offset - (texture.get_size() * 0.5 if animated.centered else Vector2.ZERO), texture.get_size())
		flip_h = animated.flip_h
		flip_v = animated.flip_v
	elif node is Sprite2D:
		var sprite := node as Sprite2D
		texture = sprite.texture
		local_rect = sprite.get_rect()
		flip_h = sprite.flip_h
		flip_v = sprite.flip_v
	if texture == null:
		return {"ok": false, "path": str(node.get_path()), "reason": "visible_sprite_texture_missing"}
	image = texture.get_image()
	if image == null or image.is_empty():
		return {"ok": false, "path": str(node.get_path()), "reason": "sprite_image_unavailable"}
	if image.is_compressed():
		image.decompress()
	if node is Sprite2D:
		var sprite := node as Sprite2D
		var region: Rect2 = sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, texture.get_size())
		var frame_size: Vector2 = region.size / Vector2(sprite.hframes, sprite.vframes)
		image = image.get_region(Rect2i(Vector2i(region.position + Vector2(sprite.frame_coords) * frame_size), Vector2i(frame_size)))
	image.convert(Image.FORMAT_RGBA8)
	var used: Rect2i = image.get_used_rect()
	if used.get_area() > 4000000:
		return {"ok": false, "path": str(node.get_path()), "reason": "sprite_alpha_scan_exceeds_bounded_budget"}
	var bytes: PackedByteArray = image.get_data()
	var size := Vector2(image.get_size())
	var transform: Transform2D = node.get_global_transform_with_canvas()
	var tested := 0
	var clipped := 0
	var covered := 0
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if int(bytes[(y * image.get_width() + x) * 4 + 3]) < ALPHA_THRESHOLD_BYTE:
				continue
			var fraction := (Vector2(x, y) + Vector2(0.5, 0.5)) / size
			if flip_h:
				fraction.x = 1.0 - fraction.x
			if flip_v:
				fraction.y = 1.0 - fraction.y
			var point: Vector2 = transform * (local_rect.position + local_rect.size * fraction)
			tested += 1
			minimum = minimum.min(point)
			maximum = maximum.max(point)
			if not viewport.has_point(point):
				clipped += 1
			for mask: Dictionary in hud:
				var rect: Rect2 = mask["rect"]
				if rect.has_point(point):
					covered += 1
					break
	var bounds: Rect2 = Rect2(minimum, maximum - minimum) if tested > 0 else Rect2()
	return {"ok": tested > 0, "path": str(node.get_path()), "texture_path": texture.resource_path, "source_image_size": _point(size), "bounds_rect": bounds, "opaque_bounds_screen_px": _rect(bounds), "opaque_pixels_tested": tested, "opaque_pixels_outside_viewport": clipped, "opaque_pixels_under_hud_masks": covered}

static func _point(value: Vector2) -> Array:
	return [value.x, value.y]

static func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]

static func _rect_polygon(value: Rect2) -> PackedVector2Array:
	return PackedVector2Array([value.position, value.position + Vector2(value.size.x, 0), value.end, value.position + Vector2(0, value.size.y)])

static func _bounds(points: PackedVector2Array) -> Rect2:
	var minimum: Vector2 = points[0]
	var maximum: Vector2 = points[0]
	for point: Vector2 in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)

static func _area(points: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(1, points.size() - 1):
		area += (points[index] - points[0]).cross(points[index + 1] - points[0])
	return absf(area) * 0.5

static func _intersection_area(first: PackedVector2Array, second: PackedVector2Array) -> float:
	var result := 0.0
	for polygon: PackedVector2Array in Geometry2D.intersect_polygons(first, second):
		result += _area(polygon)
	return result
