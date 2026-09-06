extends RefCounted

# Read actual floor rectangles back into their common authoring plane. All maps
# retain polygon support and shoreline clearance checks; reference probes are
# applied only when the map explicitly declares that local landmark.
const ValidationPaths := preload("res://tools/registered_terrain_validation/validation_paths.gd")
const AREA_TOLERANCE := 0.1
const PIXEL_TOLERANCE := 0.05
const RECT_CORNERS := [Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)]

static func run(battle: Node, arena: ArenaDefinition, view: Node2D, renderer: ArenaTerrainVisualRenderer) -> Dictionary:
	var errors: Array[String] = []
	var plan_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ValidationPaths.plan_path(arena, battle)))
	if not plan_value is Dictionary:
		return {"ok": false, "errors": ["terrain_plan_missing_or_invalid"]}
	var plan: Dictionary = plan_value
	var land := _polygon(plan.get("land_polygon", []))
	if land.size() < 3:
		return {"ok": false, "errors": ["terrain_land_polygon_invalid"]}
	var image := arena.painted_map_visual_data
	var screen_to_grid := view.get_global_transform_with_canvas().affine_inverse()
	var terrain := battle.get_node_or_null("GreekTerrainComposition")
	var land_node := terrain.get_node_or_null("Land") as Polygon2D if terrain != null else null
	if land_node == null or land_node.polygon.size() != land.size():
		return {"ok": false, "errors": ["actual_rendered_land_missing_or_changed"]}
	var rendered_land := PackedVector2Array()
	var land_vertex_error := 0.0
	for index in range(land_node.polygon.size()):
		var screen := land_node.get_global_transform_with_canvas() * (land_node.polygon[index] + land_node.offset)
		var native := (screen_to_grid * screen - image.image_offset) / image.image_scale
		rendered_land.append(native)
		land_vertex_error = maxf(land_vertex_error, native.distance_to(land[index]))
	if land_vertex_error > PIXEL_TOLERANCE:
		errors.append("rendered_land_transform_mismatch:%.3fpx" % land_vertex_error)
	land = rendered_land
	var allowed := _polygon(plan.get("allowed_floor_polygon", [])) if plan.has("allowed_floor_polygon") else land
	if allowed.size() < 3:
		return {"ok": false, "errors": ["terrain_allowed_floor_polygon_invalid"]}
	var rendered_shores: Array[PackedVector2Array] = []
	var shore_vertex_error := 0.0
	var shore_index := 0
	var declared_shores: Variant = plan.get("shorelines")
	if not declared_shores is Array:
		return {"ok": false, "errors": ["terrain_shorelines_must_be_explicit_array"]}
	for value: Dictionary in plan.get("shorelines", []):
		var source_points := _polygon(value.get("points", []))
		if source_points.size() < 2:
			errors.append("invalid_authoring_shoreline")
			continue
		if bool(value.get("closed", false)) and not source_points[0].is_equal_approx(source_points[source_points.size() - 1]):
			source_points.append(source_points[0])
		var line := terrain.get_node_or_null("Shore_%d" % shore_index) as Line2D
		shore_index += 1
		if line == null or line.points.size() != source_points.size():
			errors.append("actual_rendered_shore_missing_or_changed")
			continue
		var actual_points := PackedVector2Array()
		for index in range(line.points.size()):
			var screen := line.get_global_transform_with_canvas() * line.points[index]
			var native := (screen_to_grid * screen - image.image_offset) / image.image_scale
			actual_points.append(native)
			shore_vertex_error = maxf(shore_vertex_error, native.distance_to(source_points[index]))
		rendered_shores.append(actual_points)
	var actual_shore_nodes := 0
	for child: Node in terrain.get_children():
		if child is Line2D and str(child.name).begins_with("Shore_"):
			actual_shore_nodes += 1
	if actual_shore_nodes != declared_shores.size() or rendered_shores.size() != declared_shores.size():
		errors.append("rendered_shoreline_count_differs_from_declared_plan")
	if shore_vertex_error > PIXEL_TOLERANCE:
		errors.append("rendered_shore_transform_mismatch:%.3fpx" % shore_vertex_error)
	var sample_count := 0
	var unsupported_cells: Array = []
	var outside_allowed_cells: Array = []
	var exclusion_overlaps: Array = []
	var unsupported_area := 0.0
	var outside_allowed_area := 0.0
	var west_point := Vector2(INF, 0)
	var probe_value: Array = plan.get("western_margin_probe_native", [])
	var has_reference_probe: bool = plan.has("western_margin_probe_native")
	var west_rule_declared: bool = plan.has("minimum_west_land_margin_tiles")
	var reference_probe := Vector2(float(probe_value[0]), float(probe_value[1])) if probe_value.size() == 2 else Vector2(INF, 0)
	if has_reference_probe and (probe_value.size() != 2 or not reference_probe.is_finite()):
		errors.append("western_reference_probe_invalid")
	var probe_error := INF
	var shoreline_distance := INF
	var allowed_margin := INF
	var exclusions: Array = plan.get("excluded_floor_polygons", [])
	var allowed_boundary := allowed.duplicate()
	allowed_boundary.append(allowed[0])
	for definition in arena.cells:
		if definition == null or not definition.defined or definition.cell_type == GridData.CellType.HOLE:
			continue
		var root := renderer.node_for_cell(definition.coordinate)
		var sprite := root.get_node_or_null("Visual") as Sprite2D if root != null else null
		if sprite == null:
			errors.append("terrain_check_missing_floor_sprite:%s" % definition.coordinate)
			continue
		var polygon := PackedVector2Array()
		var rect := sprite.get_rect()
		for corner: Vector2 in RECT_CORNERS:
			var screen := sprite.get_global_transform_with_canvas() * (rect.position + rect.size * corner)
			var native := (screen_to_grid * screen - image.image_offset) / image.image_scale
			polygon.append(native)
			if is_finite(reference_probe.x):
				var distance := native.distance_to(reference_probe)
				if distance < probe_error:
					probe_error = distance
					west_point = native
			elif native.x < west_point.x:
				west_point = native
		var floor_area := _area(polygon)
		var missing := maxf(0.0, floor_area - _intersection_area(polygon, land))
		var outside_allowed := maxf(0.0, floor_area - _intersection_area(polygon, allowed))
		unsupported_area += missing
		outside_allowed_area += outside_allowed
		sample_count += 1
		if missing > AREA_TOLERANCE:
			unsupported_cells.append({"cell": [definition.coordinate.x, definition.coordinate.y], "area_native_px2": missing})
		if outside_allowed > AREA_TOLERANCE:
			outside_allowed_cells.append({"cell": [definition.coordinate.x, definition.coordinate.y], "area_native_px2": outside_allowed})
		allowed_margin = minf(allowed_margin, _polygon_polyline_distance(polygon, allowed_boundary))
		for exclusion_value: Variant in exclusions:
			var exclusion: Dictionary = exclusion_value if exclusion_value is Dictionary else {"polygon": exclusion_value}
			var excluded_polygon := _polygon(exclusion.get("polygon", exclusion.get("points", [])))
			if excluded_polygon.size() < 3:
				errors.append("invalid_authoring_exclusion")
				continue
			var overlap := _intersection_area(polygon, excluded_polygon)
			if overlap > AREA_TOLERANCE:
				exclusion_overlaps.append({"cell": [definition.coordinate.x, definition.coordinate.y], "zone": str(exclusion.get("id", "exclusion")), "area_native_px2": overlap})
		for points: PackedVector2Array in rendered_shores:
			shoreline_distance = minf(shoreline_distance, _polygon_polyline_distance(polygon, points))
	var west_distance := INF
	for points: PackedVector2Array in rendered_shores:
		for index in range(points.size() - 1):
			var nearest := Geometry2D.get_closest_point_to_segment(west_point, points[index], points[index + 1])
			west_distance = minf(west_distance, west_point.distance_to(nearest))
	var tile_width := absf(arena.axis_x.x) + absf(arena.axis_y.x)
	if not unsupported_cells.is_empty():
		errors.append("floor_outside_land:%d" % unsupported_cells.size())
	if not outside_allowed_cells.is_empty():
		errors.append("floor_outside_allowed_land:%d" % outside_allowed_cells.size())
	if not exclusion_overlaps.is_empty():
		errors.append("floor_overlaps_rock_footing:%d" % exclusion_overlaps.size())
	if has_reference_probe and probe_error > PIXEL_TOLERANCE:
		errors.append("western_reference_corner_missing:%.3fpx" % probe_error)
	var minimum_west_ratio := float(plan.get("minimum_west_land_margin_tiles", 0.0))
	var minimum_allowed_margin := float(plan.get("minimum_floor_margin_px", 0.0))
	var minimum_shore_margin := float(plan.get("minimum_floor_shore_clearance_native_px", 0.0))
	if not is_finite(minimum_west_ratio) or minimum_west_ratio < 0 or not is_finite(minimum_allowed_margin) or minimum_allowed_margin < 0 or not is_finite(minimum_shore_margin) or minimum_shore_margin < 0:
		errors.append("terrain_margin_requirement_invalid")
	if west_rule_declared and is_finite(west_distance) and west_distance + PIXEL_TOLERANCE < minimum_west_ratio * tile_width:
		errors.append("west_land_margin_too_narrow:%.3f_tiles" % (west_distance / tile_width))
	if allowed_margin + PIXEL_TOLERANCE < minimum_allowed_margin:
		errors.append("floor_allowed_land_margin_too_narrow:%.3fpx_expected_%.3fpx" % [allowed_margin, minimum_allowed_margin])
	if shoreline_distance + PIXEL_TOLERANCE < minimum_shore_margin:
		errors.append("floor_shoreline_margin_too_narrow:%.3fpx_expected_%.3fpx" % [shoreline_distance, minimum_shore_margin])
	if is_zero_approx(arena.axis_x.x) or is_zero_approx(arena.axis_y.x) or absf(absf(arena.axis_x.y / arena.axis_x.x) - 0.5) > 0.0001 or absf(absf(arena.axis_y.y / arena.axis_y.x) - 0.5) > 0.0001:
		errors.append("terrain_projection_not_2_to_1")
	var background := battle.get_node_or_null("PaintedBackground/BackgroundSprite") as CanvasItem
	if background != null and background.visible:
		errors.append("old_independent_background_still_visible")
	return {
		"ok": errors.is_empty(), "errors": errors,
		"authority": "Live stone Sprite2D rectangles transformed to the terrain plane; full polygon intersections with actual Land, authored allowed floor and exclusions; segment-to-segment distances to every live shoreline.",
		"native_canvas_size": plan.get("canvas_size", []),
		"rendered_land_vertex_error_native_px": land_vertex_error, "rendered_shore_vertex_error_native_px": shore_vertex_error, "floor_polygons_checked": sample_count,
		"unsupported_cells": unsupported_cells, "unsupported_area_native_px2": unsupported_area,
		"outside_allowed_cells": outside_allowed_cells, "outside_allowed_area_native_px2": outside_allowed_area,
		"rock_footing_overlaps": exclusion_overlaps,
		"shoreline_clearance_applicable": not rendered_shores.is_empty(),
		"declared_shoreline_count": declared_shores.size(), "rendered_shoreline_count": rendered_shores.size(),
		"minimum_shoreline_distance_native_px": shoreline_distance if is_finite(shoreline_distance) else null,
		"required_floor_shore_clearance_native_px": minimum_shore_margin,
		"minimum_allowed_land_margin_native_px": allowed_margin if is_finite(allowed_margin) else -1,
		"required_allowed_land_margin_native_px": minimum_allowed_margin,
		"west_reference_probe_declared": has_reference_probe, "west_margin_requirement_declared": west_rule_declared,
		"west_inlet_floor_point_native": [west_point.x, west_point.y],
		"west_land_margin_native_px": west_distance if is_finite(west_distance) else -1,
		"west_land_margin_tiles": west_distance / tile_width if is_finite(west_distance) and tile_width > 0 else -1,
		"minimum_west_land_margin_tiles": minimum_west_ratio, "west_probe_vertex_error_px": probe_error if is_finite(probe_error) else -1,
		"scope": "Every complete floor polygon remains on allowed land. Local landmark probes are map-specific; global floor support, actual shore measurements and the independent ground-band clearance oracle apply to every map."
	}

static func _polygon(values: Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for value: Variant in values:
		polygon.append(Vector2(float(value[0]), float(value[1])))
	return polygon

static func _area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var result := 0.0
	var origin := polygon[0]
	for index in range(1, polygon.size() - 1):
		result += (polygon[index] - origin).cross(polygon[index + 1] - origin)
	return absf(result) * 0.5

static func _intersection_area(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var result := 0.0
	for intersection: PackedVector2Array in Geometry2D.intersect_polygons(a, b):
		result += _area(intersection)
	return result

static func _polygon_polyline_distance(polygon: PackedVector2Array, line: PackedVector2Array) -> float:
	var result := INF
	for index in range(line.size() - 1):
		var a := line[index]
		var b := line[index + 1]
		if Geometry2D.is_point_in_polygon(a, polygon) or Geometry2D.is_point_in_polygon(b, polygon):
			return 0.0
		for edge in range(polygon.size()):
			var c := polygon[edge]
			var d := polygon[(edge + 1) % polygon.size()]
			if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
				return 0.0
			result = minf(result, a.distance_to(Geometry2D.get_closest_point_to_segment(a, c, d)))
			result = minf(result, b.distance_to(Geometry2D.get_closest_point_to_segment(b, c, d)))
			result = minf(result, c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)))
			result = minf(result, d.distance_to(Geometry2D.get_closest_point_to_segment(d, a, b)))
	return result
