extends Node2D

const STYLE := preload("res://battle/painted/registered_terrain/terrain_style.gd")

# Cosmetic, filled underlay. The actual dalles and pit artwork cover its core.
# Offset happens in logical grid coordinates, then the same native projection
# as Land is applied. No grid, obstacle, unit or collider is changed here.
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const CORNERS_2 := [Vector2i(-1,-1), Vector2i(1,-1), Vector2i(1,1), Vector2i(-1,1)]
const MIN_AREA := 0.001
const CLIP_EPSILON := 0.00001
var outer_contour_grid := PackedVector2Array()
var outer_contours_grid: Array[PackedVector2Array] = []
var offset_contours_grid: Array[PackedVector2Array] = []
var _materials: Array[ShaderMaterial] = []
var _report: Dictionary = {}
var _errors: Array[String] = []
var _boundary_edge_count := 0

func configure(arena: ArenaDefinition, grid_view: Node2D, terrain_composition: Node2D, platform: Node2D) -> Dictionary:
	for child in get_children():
		child.free()
	outer_contour_grid.clear()
	outer_contours_grid.clear()
	offset_contours_grid.clear()
	_materials.clear()
	_errors.clear()
	_boundary_edge_count = 0
	z_as_relative = true
	z_index = 5
	transform = Transform2D.IDENTITY
	_report = {"ok": false, "enabled": true, "errors": [], "changes_tactical_cells": false, "changes_positions": false,
		"coordinate_space": "terrain native pixels; logical grid offset before projection", "local_z_index": 5,
		"filled_core_under_floor_and_pits": true, "polygon_role": "expanded_combat_underlay"}
	if arena == null or grid_view == null or terrain_composition == null or platform == null or get_parent() != terrain_composition:
		return _fail("combat_band_requires_arena_grid_platform_and_composition_parent")
	var plan_value: Variant = terrain_composition.get("plan")
	if not plan_value is Dictionary:
		return _fail("combat_band_missing_terrain_plan")
	var plan: Dictionary = plan_value
	var style_value: Variant = plan.get("combat_ground_band", {})
	if not style_value is Dictionary:
		return _fail("combat_band_style_invalid")
	var style: Dictionary = style_value
	if not bool(style.get("enabled", true)):
		_report.enabled = false
		return _finish()
	var width := float(style.get("width_cells", 0.42))
	var clearance := float(style.get("minimum_shore_clearance_native_px", 0.0))
	if not is_finite(width) or width <= 0.0 or not is_finite(clearance) or clearance < 0.0:
		return _fail("combat_band_width_or_clearance_invalid")
	_report.width_cells = width
	_report.minimum_shore_clearance_native_px = clearance
	var canonical_floor: Dictionary = {}
	for definition in arena.cells:
		if definition != null and definition.defined and definition.cell_type != GridData.CellType.HOLE:
			canonical_floor[definition.coordinate] = true
	var platform_floor: Variant = platform.get("floor_cells")
	var platform_pits: Variant = platform.get("pit_cells")
	if not platform_floor is Dictionary or not platform_pits is Dictionary:
		return _fail("combat_band_platform_topology_missing")
	if platform_floor.size() != canonical_floor.size():
		return _fail("combat_band_platform_floor_count_differs_from_arena")
	for cell: Vector2i in platform_floor:
		if not canonical_floor.has(cell):
			return _fail("combat_band_platform_floor_not_canonical:%s" % cell)
	var grid := grid_view.get("grid") as GridData
	if grid == null:
		return _fail("combat_band_runtime_grid_missing")
	var domain := canonical_floor.duplicate()
	for cell: Vector2i in platform_pits:
		if not arena.is_in_bounds(cell) or canonical_floor.has(cell) or grid.get_type(cell) != GridData.CellType.HOLE:
			return _fail("combat_band_pit_not_verified_void:%s" % cell)
		domain[cell] = true
	var annotation_errors: Variant = platform.get("pit_annotation_errors")
	if annotation_errors is Array and not annotation_errors.is_empty():
		return _fail("combat_band_platform_pit_annotations_invalid")
	_report.floor_cells = canonical_floor.size()
	_report.pit_cells = platform_pits.size()
	_report.domain_cells = domain.size()
	var loops := _trace_boundary(domain)
	if not _errors.is_empty():
		return _finish()
	var inner_loops := 0
	for loop: PackedVector2Array in loops:
		if _signed_area(loop) > 0.0:
			outer_contours_grid.append(_simplify(loop))
		else:
			inner_loops += 1
	_report.boundary_edge_count = _boundary_edge_count
	_report.contour_count = outer_contours_grid.size()
	_report.inner_contours = inner_loops
	# Known pits already belong to domain. Refuse a new unannotated inner void
	# instead of making it look like ground through a filled cosmetic core.
	if inner_loops != 0 or outer_contours_grid.size() != 1:
		return _fail("combat_band_requires_one_outer_contour_without_unannotated_holes")
	outer_contour_grid = outer_contours_grid[0]
	_report.simplified_contour_vertices = outer_contour_grid.size()
	_report.outer_contour_grid = _json_points(outer_contour_grid)
	if outer_contour_grid.size() > 128:
		return _fail("combat_band_contour_exceeds_shader_128_vertices")
	var expanded := Geometry2D.offset_polygon(outer_contour_grid, width, Geometry2D.JOIN_MITER)
	var expanded_parts: Array[PackedVector2Array] = []
	var expanded_area := 0.0
	for polygon: PackedVector2Array in expanded:
		if _signed_area(polygon) <= 0.0:
			return _fail("combat_band_offset_produced_inner_contour")
		var contour := _simplify(polygon)
		offset_contours_grid.append(contour)
		var native := _project(contour, arena)
		expanded_area += absf(_signed_area(native))
		expanded_parts.append_array(Geometry2D.decompose_polygon_in_convex(native))
	if expanded_parts.is_empty():
		return _fail("combat_band_offset_decomposition_empty")
	_report.offset_contour_count = offset_contours_grid.size()
	_report.offset_join = "MITER in logical grid space"
	_report.expanded_area_native_px2 = expanded_area
	var land := _points(plan.get("land_polygon", []))
	if land.size() < 3:
		return _fail("combat_band_land_polygon_invalid")
	var safe_land: Array[PackedVector2Array] = []
	if clearance > 0.0:
		safe_land = Geometry2D.offset_polygon(land, -clearance, Geometry2D.JOIN_MITER)
	else:
		safe_land.append(land)
	var safe_parts: Array[PackedVector2Array] = []
	for polygon: PackedVector2Array in safe_land:
		if _signed_area(polygon) > 0.0:
			safe_parts.append_array(Geometry2D.decompose_polygon_in_convex(polygon))
	if safe_parts.is_empty():
		return _fail("combat_band_land_clearance_removed_all_land")
	var clipped: Array[PackedVector2Array] = []
	for subject: PackedVector2Array in expanded_parts:
		for clip: PackedVector2Array in safe_parts:
			if not _bounds(subject).intersects(_bounds(clip)):
				continue
			var piece := _intersect_convex(subject, clip)
			if piece.size() >= 3 and absf(_signed_area(piece)) > MIN_AREA:
				clipped.append(piece)
	var supported_area := _total_area(clipped)
	_report.after_land_clearance_area_native_px2 = supported_area
	_report.clipped_by_land_and_clearance_native_px2 = maxf(0.0, expanded_area - supported_area)
	var exclusion_count := 0
	for value: Variant in plan.get("excluded_floor_polygons", []):
		var points: Array = value.get("polygon", value.get("points", [])) if value is Dictionary else value
		var exclusion := _points(points)
		if exclusion.size() < 3:
			return _fail("combat_band_exclusion_polygon_invalid")
		exclusion_count += 1
		for cut: PackedVector2Array in Geometry2D.decompose_polygon_in_convex(exclusion):
			var next: Array[PackedVector2Array] = []
			for subject: PackedVector2Array in clipped:
				if _bounds(subject).intersects(_bounds(cut)):
					next.append_array(_subtract_convex(subject, cut))
				else:
					next.append(subject)
			clipped = next
	var final_area := _total_area(clipped)
	_report.exclusion_polygons = exclusion_count
	_report.clipped_by_exclusions_native_px2 = maxf(0.0, supported_area - final_area)
	_report.rendered_area_native_px2 = final_area
	if clipped.is_empty():
		return _fail("combat_band_no_supported_surface")
	var material: ShaderMaterial = null
	var shader_path := str(style.get("shader_path", ""))
	if not shader_path.is_empty():
		var shader := load(shader_path) as Shader if ResourceLoader.exists(shader_path) else null
		if shader == null:
			return _fail("combat_band_shader_missing:%s" % shader_path)
		material = ShaderMaterial.new()
		material.shader = shader
		STYLE.apply_shader_parameters(material,style.get("shader_parameters",{}))
		_materials.append(material)
	var texture: Texture2D = null
	var texture_path := str(style.get("texture_path", ""))
	if not texture_path.is_empty():
		texture = load(texture_path) as Texture2D if ResourceLoader.exists(texture_path) else null
		if texture == null:
			return _fail("combat_band_texture_missing:%s" % texture_path)
	for index in range(clipped.size()):
		var surface := Polygon2D.new()
		surface.name = "BandSurface_%03d" % index
		surface.polygon = clipped[index]
		surface.uv = clipped[index]
		surface.texture = texture
		surface.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		surface.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		surface.color = Color.from_string(str(style.get("tint", "#ffffff")), Color.WHITE)
		surface.material = material
		surface.set_meta("ground_band_role", "expanded_combat_underlay")
		surface.set_meta("native_polygon", true)
		add_child(surface)
	_report.polygons_generated = clipped.size()
	_report.shader_path = shader_path
	_report.material_count = _materials.size()
	_report.local_transform = str(transform)
	return _finish()

func materials() -> Array[ShaderMaterial]:
	return _materials.duplicate()

func geometry_report() -> Dictionary:
	return _report.duplicate(true)

func _fail(message: String) -> Dictionary:
	_errors.append(message)
	return _finish()

func _finish() -> Dictionary:
	_report.ok = _errors.is_empty()
	_report.errors = _errors.duplicate()
	set_meta("greek_combat_ground_band_report", _report.duplicate(true))
	return geometry_report()

func _trace_boundary(domain: Dictionary) -> Array[PackedVector2Array]:
	var edges: Array[Dictionary] = []
	var outgoing: Dictionary = {}
	for cell: Vector2i in domain:
		for side in range(4):
			if domain.has(cell + DIRECTIONS[side]):
				continue
			var a: Vector2i = cell * 2 + CORNERS_2[side]
			var b: Vector2i = cell * 2 + CORNERS_2[(side+1)%4]
			var index := edges.size()
			edges.append({"a": a, "b": b})
			if not outgoing.has(a):
				outgoing[a] = []
			outgoing[a].append(index)
	_boundary_edge_count = edges.size()
	var unused: Dictionary = {}
	for index in range(edges.size()):
		unused[index] = true
	var loops: Array[PackedVector2Array] = []
	while not unused.is_empty():
		var current: int = unused.keys()[0]
		var start: Vector2i = edges[current].a
		var points := PackedVector2Array()
		var closed := false
		for _step in range(edges.size()+1):
			if not unused.has(current):
				break
			unused.erase(current)
			var a: Vector2i = edges[current].a
			var b: Vector2i = edges[current].b
			points.append(Vector2(a) * 0.5)
			if b == start:
				closed = true
				break
			var incoming := Vector2(b-a)
			var next := -1
			var best_rank := -1
			for candidate: int in outgoing.get(b, []):
				if not unused.has(candidate):
					continue
				var direction := Vector2(Vector2i(edges[candidate].b)-b)
				var turn := incoming.cross(direction)
				var rank := 3 if turn > 0.0 else (2 if incoming.dot(direction) > 0.0 else (1 if turn < 0.0 else 0))
				if rank > best_rank:
					best_rank = rank
					next = candidate
			if next < 0:
				break
			current = next
		if not closed or points.size() < 4:
			_errors.append("combat_band_boundary_not_closed")
			return []
		loops.append(points)
	return loops

# Partition convex subjects by each exclusion half-plane. Unlike drawing the
# hole loops returned by clip_polygons, these pieces never refill exclusions.
static func _subtract_convex(subject: PackedVector2Array, cut: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var remaining := subject
	var orientation := 1.0 if _signed_area(cut) >= 0.0 else -1.0
	for index in range(cut.size()):
		var a := cut[index]
		var b := cut[(index+1)%cut.size()]
		var outside := _clip_half_plane(remaining, a, b, orientation, false)
		if outside.size() >= 3 and absf(_signed_area(outside)) > MIN_AREA:
			result.append(outside)
		remaining = _clip_half_plane(remaining, a, b, orientation, true)
		if remaining.size() < 3:
			break
	return result

static func _intersect_convex(subject: PackedVector2Array, cut: PackedVector2Array) -> PackedVector2Array:
	var result := subject
	var orientation := 1.0 if _signed_area(cut) >= 0.0 else -1.0
	for index in range(cut.size()):
		result = _clip_half_plane(result, cut[index], cut[(index+1)%cut.size()], orientation, true)
		if result.size() < 3:
			return PackedVector2Array()
	return result

static func _clip_half_plane(polygon: PackedVector2Array, a: Vector2, b: Vector2, orientation: float, keep_inside: bool) -> PackedVector2Array:
	var result := PackedVector2Array()
	if polygon.is_empty():
		return result
	var previous := polygon[polygon.size()-1]
	var previous_distance := (b-a).cross(previous-a) * orientation
	var previous_kept := previous_distance >= -CLIP_EPSILON if keep_inside else previous_distance <= CLIP_EPSILON
	for current: Vector2 in polygon:
		var distance := (b-a).cross(current-a) * orientation
		var kept := distance >= -CLIP_EPSILON if keep_inside else distance <= CLIP_EPSILON
		if kept != previous_kept:
			var denominator := previous_distance-distance
			if absf(denominator) > 0.00000001:
				result.append(previous.lerp(current, clampf(previous_distance/denominator, 0.0, 1.0)))
		if kept:
			result.append(current)
		previous = current
		previous_distance = distance
		previous_kept = kept
	return _simplify(result)

static func _simplify(polygon: PackedVector2Array) -> PackedVector2Array:
	var unique := PackedVector2Array()
	for point: Vector2 in polygon:
		if unique.is_empty() or point.distance_squared_to(unique[unique.size()-1]) > 0.00000001:
			unique.append(point)
	if unique.size() > 1 and unique[0].distance_squared_to(unique[unique.size()-1]) <= 0.00000001:
		unique.remove_at(unique.size()-1)
	var result := PackedVector2Array()
	for index in range(unique.size()):
		var previous := unique[(index+unique.size()-1)%unique.size()]
		var point := unique[index]
		var next := unique[(index+1)%unique.size()]
		if absf((point-previous).cross(next-point)) <= 0.000001 and (point-previous).dot(next-point) >= 0.0:
			continue
		result.append(point)
	return result

static func _project(polygon: PackedVector2Array, arena: ArenaDefinition) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in polygon:
		result.append(arena.grid_origin + point.x * arena.axis_x + point.y * arena.axis_y)
	return result

static func _points(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value: Array in values:
		if value.size() >= 2:
			result.append(Vector2(float(value[0]),float(value[1])))
	return result

static func _bounds(polygon: PackedVector2Array) -> Rect2:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		bounds = bounds.expand(point)
	return bounds

static func _signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(polygon.size()):
		area += polygon[index].cross(polygon[(index+1)%polygon.size()])
	return area * 0.5

static func _total_area(polygons: Array[PackedVector2Array]) -> float:
	var area := 0.0
	for polygon: PackedVector2Array in polygons:
		area += absf(_signed_area(polygon))
	return area

static func _json_points(polygon: PackedVector2Array) -> Array:
	var result: Array = []
	for point: Vector2 in polygon:
		result.append([point.x, point.y])
	return result

