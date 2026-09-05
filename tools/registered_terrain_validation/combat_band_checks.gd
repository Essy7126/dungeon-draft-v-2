extends RefCounted

const ValidationPaths := preload("res://tools/registered_terrain_validation/validation_paths.gd")

# Independent oracle: inspect live Polygon2D geometry, live floor sprites and
# GridData. Do not use the band's contour builder or geometry_report as proof.
const PIXEL_TOLERANCE := 0.05
const AREA_TOLERANCE := 0.25
const EXPECTED_WIDTH_GRID := 0.42
const WIDTH_TOLERANCE_GRID := 0.002
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const CORNERS := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
const SPRITE_CORNERS := [Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)]

static func run(battle: Node, arena: ArenaDefinition, renderer: ArenaTerrainVisualRenderer) -> Dictionary:
	var errors: Array[String] = []
	var terrain := battle.get_node_or_null("GreekTerrainComposition")
	if terrain == null:
		return {"ok": false, "errors": ["band_check_terrain_composition_missing"]}
	var raw_plan: Variant = terrain.get("plan")
	if not raw_plan is Dictionary:
		return {"ok": false, "errors": ["band_check_live_terrain_plan_missing"]}
	var style: Dictionary = raw_plan.get("combat_ground_band", {})
	if not bool(style.get("enabled", false)):
		return {"ok": true, "errors": [], "skipped": true, "reason": "combat_ground_band disabled in terrain plan"}
	var expected_width := float(style.get("width_cells", EXPECTED_WIDTH_GRID))
	var shore_clearance := float(style.get("minimum_shore_clearance_native_px", 20.0))
	if not is_finite(expected_width) or expected_width <= 0 or not is_finite(shore_clearance) or shore_clearance < 0:
		return {"ok": false, "errors": ["band_check_width_or_clearance_invalid"]}
	if not bool(battle.get("combat_band_active")):
		errors.append("band_check_enabled_plan_but_battle_inactive")
	var band := terrain.get_node_or_null("GroundBand") as Node2D if terrain != null else null
	var land := terrain.get_node_or_null("Land") as Polygon2D if terrain != null else null
	var platform := battle.get_node_or_null("GreekPlatformRisersAndPits") as Node2D
	var view := battle.get("grid_view") as Node2D
	var grid := battle.get("grid") as GridData
	if arena == null or renderer == null or band == null or land == null or platform == null or view == null or grid == null:
		return {"ok": false, "errors": ["band_check_required_runtime_node_missing"]}
	var image := arena.painted_map_visual_data
	if image == null or image.image_scale.x <= 0 or image.image_scale.y <= 0:
		return {"ok": false, "errors": ["band_check_native_image_transform_invalid"]}
	var manifest_path := ValidationPaths.manifest_path(arena, battle)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		return {"ok": false, "errors": ["band_check_canonical_manifest_missing"]}
	var manifest: Dictionary = parsed
	var canonical_floor := _cells(manifest.get("floor_cells", []))
	var floor := {}
	for definition in arena.cells:
		if definition != null and definition.defined and definition.cell_type != GridData.CellType.HOLE:
			if floor.has(definition.coordinate):
				errors.append("band_check_duplicate_runtime_floor:%s" % definition.coordinate)
			floor[definition.coordinate] = true
	if not _same_keys(floor, canonical_floor):
		errors.append("band_check_runtime_floor_differs_from_canonical_manifest")
	var pits := {}
	for group: Dictionary in manifest.get("pits", []):
		for cell: Vector2i in _cells(group.get("cells", [])):
			pits[cell] = true
	var core := floor.duplicate()
	for cell: Vector2i in pits:
		if floor.has(cell) or not grid.is_valid(cell) or grid.get_type(cell) != GridData.CellType.HOLE:
			errors.append("band_check_annotated_pit_became_floor:%s" % cell)
		core[cell] = true
	if core.is_empty() or pits.is_empty():
		errors.append("band_check_empty_combat_or_pit_domain")
	var void_count := 0
	var added_floor_or_input: Array = []
	if grid.cols != arena.grid_size.x or grid.rows != arena.grid_size.y:
		errors.append("band_check_runtime_grid_size_changed")
	for y in range(grid.rows):
		for x in range(grid.cols):
			var cell := Vector2i(x, y)
			if floor.has(cell):
				continue
			void_count += 1
			if grid.get_type(cell) != GridData.CellType.HOLE or grid.is_terrain_interactable(cell) or renderer.node_for_cell(cell) != null:
				added_floor_or_input.append([x, y])
	if not added_floor_or_input.is_empty():
		errors.append("band_check_void_gained_floor_or_input:%d" % added_floor_or_input.size())
	var screen_to_grid := view.get_global_transform_with_canvas().affine_inverse()
	var rendered_land := _rendered_polygon(land, screen_to_grid, image)
	var shores: Array[PackedVector2Array] = []
	for child: Node in terrain.get_children():
		if child is Line2D and str(child.name).begins_with("Shore_"):
			var line := child as Line2D
			var points := PackedVector2Array()
			for point: Vector2 in line.points:
				var screen := line.get_global_transform_with_canvas() * point
				points.append((screen_to_grid * screen - image.image_offset) / image.image_scale)
			if points.size() >= 2:
				shores.append(points)
	if shores.is_empty():
		errors.append("band_check_actual_shorelines_missing")
	var exclusions: Array[PackedVector2Array] = []
	for value: Variant in raw_plan.get("excluded_floor_polygons", []):
		var entry: Dictionary = value if value is Dictionary else {"polygon": value}
		var exclusion := _polygon(entry.get("polygon", entry.get("points", [])))
		if exclusion.size() >= 3:
			exclusions.append(exclusion)
	var surfaces: Array[Polygon2D] = []
	var forbidden_nodes: Array[String] = []
	_collect_surfaces(band, surfaces, forbidden_nodes)
	if not forbidden_nodes.is_empty():
		errors.append("band_check_non_decorative_descendants:%d" % forbidden_nodes.size())
	if surfaces.is_empty() or surfaces.size() > 512:
		return {"ok": false, "errors": ["band_check_surface_count_invalid"], "surface_count": surfaces.size(), "forbidden_nodes": forbidden_nodes}
	var polygons: Array[PackedVector2Array] = []
	var total_area := 0.0
	var outside_land := 0.0
	var rock_overlap := 0.0
	var native_error := 0.0
	var width_max := 0.0
	var minimum_shore_distance := INF
	var grid_affine := Transform2D(arena.axis_x, arena.axis_y, arena.grid_origin)
	var native_to_cell := grid_affine.affine_inverse()
	var min_band_z := 4096
	var max_band_z := -4096
	for surface: Polygon2D in surfaces:
		if not surface.is_visible_in_tree() or surface.invert_enabled or not surface.polygons.is_empty():
			errors.append("band_check_surface_render_contract:%s" % surface.name)
		var polygon := _rendered_polygon(surface, screen_to_grid, image)
		if polygon.size() < 3 or _area(polygon) <= 0.0001:
			errors.append("band_check_degenerate_surface:%s" % surface.name)
			continue
		polygons.append(polygon)
		minimum_shore_distance = minf(minimum_shore_distance, _polygon_shore_distance(polygon, shores))
		var area := _area(polygon)
		total_area += area
		var unsupported := maxf(0.0, area - _intersection_area(polygon, rendered_land))
		outside_land += unsupported
		if unsupported > AREA_TOLERANCE:
			errors.append("band_check_surface_outside_land:%s:%.3fpx2" % [surface.name, unsupported])
		for exclusion: PackedVector2Array in exclusions:
			var overlap := _intersection_area(polygon, exclusion)
			rock_overlap += overlap
			if overlap > AREA_TOLERANCE:
				errors.append("band_check_surface_over_rock:%s:%.3fpx2" % [surface.name, overlap])
		for index in range(polygon.size()):
			native_error = maxf(native_error, polygon[index].distance_to(surface.polygon[index]))
			width_max = maxf(width_max, _distance_to_core_grid(native_to_cell * polygon[index], core))
		min_band_z = mini(min_band_z, _effective_z(surface))
		max_band_z = maxi(max_band_z, _effective_z(surface))
	if native_error > PIXEL_TOLERANCE:
		errors.append("band_check_native_transform_mismatch:%.6fpx" % native_error)
	if width_max > expected_width + WIDTH_TOLERANCE_GRID:
		errors.append("band_check_exceeds_grid_offset:%.6f_cells" % width_max)
	if minimum_shore_distance + PIXEL_TOLERANCE < shore_clearance:
		errors.append("band_check_shore_clearance:%.6fpx_expected_%.3fpx" % [minimum_shore_distance, shore_clearance])
	if min_band_z <= _effective_z(land) or max_band_z >= _effective_z(platform) or not platform.is_visible_in_tree():
		errors.append("band_check_order_must_be_above_land_below_pits")
	var pair_overlap := 0.0
	var pair_count := 0
	for first in range(polygons.size()):
		for second in range(first + 1, polygons.size()):
			var overlap := _intersection_area(polygons[first], polygons[second])
			pair_overlap += overlap
			pair_count += 1
			if overlap > AREA_TOLERANCE:
				errors.append("band_check_double_draw_overlap:%d_%d:%.3fpx2" % [first, second, overlap])
	var core_covered_area := 0.0
	var core_missing_area := 0.0
	var core_missing_cells: Array = []
	var floor_count := 0
	var matching_floor_materials := 0
	var pit_count := 0
	for cell: Vector2i in core:
		var polygon := PackedVector2Array()
		if floor.has(cell):
			var root := renderer.node_for_cell(cell)
			var sprite := root.get_node_or_null("Visual") as Sprite2D if root != null else null
			if sprite == null:
				errors.append("band_check_missing_live_floor:%s" % cell)
				continue
			var material := sprite.material as ShaderMaterial
			if material == null or not bool(material.get_shader_parameter("combat_band_enabled")):
				errors.append("band_check_floor_material_band_disabled:%s" % cell)
			else:
				var width_value: Variant = material.get_shader_parameter("band_width_cells")
				if width_value == null or absf(float(width_value) - expected_width) > 0.000001:
					errors.append("band_check_floor_material_width_mismatch:%s" % cell)
				else:
					matching_floor_materials += 1
			var rect := sprite.get_rect()
			for corner: Vector2 in SPRITE_CORNERS:
				var screen := sprite.get_global_transform_with_canvas() * (rect.position + rect.size * corner)
				polygon.append((screen_to_grid * screen - image.image_offset) / image.image_scale)
			if max_band_z >= _effective_z(sprite) or not sprite.is_visible_in_tree():
				errors.append("band_check_core_not_below_live_floor:%s" % cell)
			floor_count += 1
		else:
			for corner: Vector2 in CORNERS:
				polygon.append(grid_affine * (Vector2(cell) + corner))
			pit_count += 1
		var covered := 0.0
		for surface: PackedVector2Array in polygons:
			covered += _intersection_area(polygon, surface)
		var missing := maxf(0.0, _area(polygon) - covered)
		core_covered_area += minf(_area(polygon), covered)
		core_missing_area += missing
		if missing > AREA_TOLERANCE:
			core_missing_cells.append({"cell": [cell.x, cell.y], "missing_native_px2": missing})
	if not core_missing_cells.is_empty():
		errors.append("band_check_uncovered_core:%d_cells" % core_missing_cells.size())
	var collar_probes := 0
	var clipped_probes := 0
	var missing_probes: Array = []
	for cell: Vector2i in core:
		for direction: Vector2i in DIRECTIONS:
			if core.has(cell + direction):
				continue
			var probe := grid_affine * (Vector2(cell) + Vector2(direction) * (0.5 + expected_width * 0.5))
			if not _point_on_land(probe, rendered_land, exclusions) or _point_shore_distance(probe, shores) < shore_clearance + PIXEL_TOLERANCE:
				clipped_probes += 1
				continue
			collar_probes += 1
			if not _point_in_union(probe, polygons):
				missing_probes.append([probe.x, probe.y])
	if not missing_probes.is_empty():
		errors.append("band_check_missing_external_collar:%d_probes" % missing_probes.size())
	var visible_area := maxf(0.0, total_area - core_covered_area)
	if visible_area <= AREA_TOLERANCE or collar_probes == 0:
		errors.append("band_check_no_exposed_external_ground")
	return {
		"ok": errors.is_empty(), "errors": errors,
		"authority": "Live Polygon2D canvas vertices against live Land; actual floor Sprite2D core; canonical VOID annotations and runtime GridData",
		"pixel_tolerance": PIXEL_TOLERANCE, "area_tolerance_native_px2": AREA_TOLERANCE,
		"expected_width_grid": expected_width, "width_tolerance_grid": WIDTH_TOLERANCE_GRID,
		"minimum_shore_clearance_native_px": shore_clearance,
		"measured_shore_clearance_native_px": minimum_shore_distance if is_finite(minimum_shore_distance) else -1,
		"rendered_shoreline_count": shores.size(), "floor_materials_with_matching_band_uniforms": matching_floor_materials,
		"surface_count": polygons.size(), "native_transform_max_error_px": native_error,
		"outside_land_native_px2": outside_land, "rock_overlap_native_px2": rock_overlap,
		"surface_pair_checks": pair_count, "surface_pair_overlap_native_px2": pair_overlap,
		"rendered_underlay_area_native_px2": total_area, "exposed_collar_area_native_px2": visible_area,
		"maximum_vertex_distance_from_core_grid_linf": width_max,
		"floor_core_polygons_checked": floor_count, "pit_core_polygons_checked": pit_count,
		"core_missing_native_px2": core_missing_area, "core_missing_cells": core_missing_cells,
		"external_collar_probes": collar_probes, "land_clipped_probes": clipped_probes, "missing_collar_probes_native": missing_probes,
		"forbidden_descendants": forbidden_nodes, "void_cells_still_without_floor_or_input": void_count - added_floor_or_input.size(),
		"new_floor_or_interactive_cells": added_floor_or_input,
		"effective_z": {"land": _effective_z(land), "band_min": min_band_z, "band_max": max_band_z, "pits": _effective_z(platform)},
		"scope": "Decorative geometry only; the expanded underlay is covered by real floor and pit rendering, and does not create playable cells. Shader alpha and perceived color require visual review."
	}

static func _collect_surfaces(node: Node, surfaces: Array[Polygon2D], forbidden: Array[String]) -> void:
	for child: Node in node.get_children():
		if child is Polygon2D:
			surfaces.append(child as Polygon2D)
		else:
			# Contract intentionally admits only drawing polygons, not colliders,
			# Controls, navigation, terrain renderers or hidden gameplay children.
			forbidden.append(str(child.get_path()))
		if child.has_meta("arena_cell") or child.has_meta("grid_cell"):
			forbidden.append("cell_metadata:" + str(child.get_path()))
		_collect_surfaces(child, surfaces, forbidden)

static func _rendered_polygon(node: Polygon2D, screen_to_grid: Transform2D, image: PaintedMapVisualData) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in node.polygon:
		var screen := node.get_global_transform_with_canvas() * (point + node.offset)
		result.append((screen_to_grid * screen - image.image_offset) / image.image_scale)
	return result

static func _effective_z(node: CanvasItem) -> int:
	var total := node.z_index
	var current := node
	while current.z_as_relative:
		var parent := current.get_parent() as CanvasItem
		if parent == null:
			break
		total += parent.z_index
		current = parent
	return total

static func _cells(values: Array) -> Dictionary:
	var result := {}
	for value: Array in values:
		if value.size() == 2:
			result[Vector2i(int(value[0]), int(value[1]))] = true
	return result

static func _same_keys(first: Dictionary, second: Dictionary) -> bool:
	if first.size() != second.size():
		return false
	for key: Variant in first:
		if not second.has(key):
			return false
	return true

static func _polygon(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value: Array in values:
		result.append(Vector2(float(value[0]), float(value[1])))
	return result

static func _area(polygon: PackedVector2Array) -> float:
	# Origin-relative shoelace avoids cancellation at large native coordinates.
	if polygon.size() < 3:
		return 0.0
	var area := 0.0
	var origin := polygon[0]
	for index in range(1, polygon.size() - 1):
		area += (polygon[index] - origin).cross(polygon[index + 1] - origin)
	return absf(area) * 0.5

static func _intersection_area(first: PackedVector2Array, second: PackedVector2Array) -> float:
	var result := 0.0
	for polygon: PackedVector2Array in Geometry2D.intersect_polygons(first, second):
		result += _area(polygon)
	return result

static func _distance_to_core_grid(point: Vector2, core: Dictionary) -> float:
	var result := INF
	for cell: Vector2i in core:
		var difference := (point - Vector2(cell)).abs() - Vector2(0.5, 0.5)
		result = minf(result, maxf(0.0, maxf(difference.x, difference.y)))
	return result

static func _point_in_union(point: Vector2, polygons: Array[PackedVector2Array]) -> bool:
	for polygon: PackedVector2Array in polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false

static func _point_on_land(point: Vector2, land: PackedVector2Array, exclusions: Array[PackedVector2Array]) -> bool:
	if not Geometry2D.is_point_in_polygon(point, land):
		return false
	return not _point_in_union(point, exclusions)

static func _point_shore_distance(point: Vector2, shores: Array[PackedVector2Array]) -> float:
	var result := INF
	for shore: PackedVector2Array in shores:
		for index in range(shore.size() - 1):
			result = minf(result, point.distance_to(Geometry2D.get_closest_point_to_segment(point, shore[index], shore[index + 1])))
	return result

static func _polygon_shore_distance(polygon: PackedVector2Array, shores: Array[PackedVector2Array]) -> float:
	var result := INF
	for shore: PackedVector2Array in shores:
		for index in range(shore.size() - 1):
			var a := shore[index]
			var b := shore[index + 1]
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
