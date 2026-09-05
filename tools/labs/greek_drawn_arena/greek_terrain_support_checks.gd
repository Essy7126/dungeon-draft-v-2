extends RefCounted

# Read rendered floor rectangles back into the common authoring plane.
# This checks the map-to-terrain relationship, independently of grid picking.
const PLAN_PATH := "res://data/arenas/greek_drawn_courtyard_v1/terrain_plan.json"
const AREA_TOLERANCE := 0.1
const RECT_CORNERS := [Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)]

static func run(battle: Node, arena: ArenaDefinition, view: Node2D, renderer: ArenaTerrainVisualRenderer) -> Dictionary:
	var errors: Array[String] = []
	var plan_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLAN_PATH))
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
		var screen := land_node.get_global_transform_with_canvas() * land_node.polygon[index]
		var native := (screen_to_grid * screen - image.image_offset) / image.image_scale
		rendered_land.append(native)
		land_vertex_error = maxf(land_vertex_error, native.distance_to(land[index]))
	if land_vertex_error > 0.05:
		errors.append("rendered_land_transform_mismatch:%.3fpx" % land_vertex_error)
	land = rendered_land
	var rendered_shores: Array[PackedVector2Array] = []
	var shore_vertex_error := 0.0
	var shore_index := 0
	for value: Dictionary in plan.get("shorelines", []):
		var source_points := _polygon(value.get("points", []))
		if source_points.size() < 2:
			errors.append("invalid_authoring_shoreline")
			continue
		if bool(value.get("closed", false)):
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
	if rendered_shores.is_empty():
		errors.append("no_valid_rendered_shoreline")
	if shore_vertex_error > 0.05:
		errors.append("rendered_shore_transform_mismatch:%.3fpx" % shore_vertex_error)
	var sample_count := 0
	var unsupported_cells: Array = []
	var exclusion_overlaps: Array = []
	var unsupported_area := 0.0
	var west_point := Vector2(INF, 0)
	var probe_value: Array = plan.get("western_margin_probe_native", [])
	var reference_probe := Vector2(float(probe_value[0]), float(probe_value[1])) if probe_value.size() == 2 else Vector2(INF, 0)
	var probe_error := INF
	var shoreline_distance := INF
	var exclusions: Array = plan.get("excluded_floor_polygons", [])
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
		var supported_area := _intersection_area(polygon, land)
		var missing := maxf(0.0, floor_area - supported_area)
		unsupported_area += missing
		sample_count += 1
		if missing > AREA_TOLERANCE:
			unsupported_cells.append({"cell": [definition.coordinate.x, definition.coordinate.y], "area_native_px2": missing})
		for exclusion_value: Variant in exclusions:
			var exclusion: Dictionary = exclusion_value if exclusion_value is Dictionary else {"polygon": exclusion_value}
			var excluded_polygon := _polygon(exclusion.get("polygon", exclusion.get("points", [])))
			if excluded_polygon.size() < 3:
				continue
			var overlap := _intersection_area(polygon, excluded_polygon)
			if overlap > AREA_TOLERANCE:
				exclusion_overlaps.append({"cell": [definition.coordinate.x, definition.coordinate.y], "zone": str(exclusion.get("id", "exclusion")), "area_native_px2": overlap})
		for points: PackedVector2Array in rendered_shores:
			for point: Vector2 in polygon:
				for index in range(points.size() - 1):
					var nearest := Geometry2D.get_closest_point_to_segment(point, points[index], points[index + 1])
					shoreline_distance = minf(shoreline_distance, point.distance_to(nearest))
	var west_distance := INF
	for points: PackedVector2Array in rendered_shores:
		for index in range(points.size() - 1):
			var nearest := Geometry2D.get_closest_point_to_segment(west_point, points[index], points[index + 1])
			west_distance = minf(west_distance, west_point.distance_to(nearest))
	var tile_width := absf(arena.axis_x.x) + absf(arena.axis_y.x)
	if not unsupported_cells.is_empty():
		errors.append("floor_outside_land:%d" % unsupported_cells.size())
	if not exclusion_overlaps.is_empty():
		errors.append("floor_overlaps_rock_footing:%d" % exclusion_overlaps.size())
	if is_finite(reference_probe.x) and probe_error > 0.05:
		errors.append("western_reference_corner_missing:%.3fpx" % probe_error)
	var minimum_west_ratio := float(plan.get("minimum_west_land_margin_tiles", 0.6))
	if is_finite(west_distance) and west_distance < minimum_west_ratio * tile_width:
		errors.append("west_land_margin_too_narrow:%.3f_tiles" % (west_distance / tile_width))
	if absf(absf(arena.axis_x.y / arena.axis_x.x) - 0.5) > 0.0001 or absf(absf(arena.axis_y.y / arena.axis_y.x) - 0.5) > 0.0001:
		errors.append("terrain_projection_not_2_to_1")
	var background := battle.get_node_or_null("PaintedBackground/BackgroundSprite") as CanvasItem
	if background != null and background.visible:
		errors.append("old_independent_background_still_visible")
	return {
		"ok": errors.is_empty(), "errors": errors,
		"authority": "Live stone Sprite2D rectangles transformed into terrain_plan native coordinates; polygon intersection against authored land and rock footing",
		"native_canvas_size": plan.get("canvas_size", []),
		"rendered_land_vertex_error_native_px": land_vertex_error, "rendered_shore_vertex_error_native_px": shore_vertex_error, "floor_polygons_checked": sample_count, "unsupported_cells": unsupported_cells,
		"unsupported_area_native_px2": unsupported_area, "rock_footing_overlaps": exclusion_overlaps,
		"minimum_shoreline_distance_native_px": shoreline_distance if is_finite(shoreline_distance) else -1,
		"west_inlet_floor_point_native": [west_point.x, west_point.y],
		"west_land_margin_native_px": west_distance if is_finite(west_distance) else -1,
		"west_land_margin_tiles": west_distance / tile_width if is_finite(west_distance) else -1,
		"minimum_west_land_margin_tiles": minimum_west_ratio, "west_probe_vertex_error_px": probe_error if is_finite(probe_error) else -1,
		"scope": "Full floor polygon support, not only tile centers. Occluded reference contours are authored estimates, not extracted Dofus logical data."
	}

static func _polygon(values: Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for value: Variant in values:
		polygon.append(Vector2(float(value[0]), float(value[1])))
	return polygon

static func _area(polygon: PackedVector2Array) -> float:
	var result := 0.0
	for index in range(polygon.size()):
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		result += a.x * b.y - b.x * a.y
	return absf(result) * 0.5

static func _intersection_area(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var result := 0.0
	for intersection: PackedVector2Array in Geometry2D.intersect_polygons(a, b):
		result += _area(intersection)
	return result
