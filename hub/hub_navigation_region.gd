class_name HubNavigationRegion2D
extends NavigationRegion2D

## Autorite de navigation continue du StartHub. Les contours sont calibres
## manuellement sur l'illustration 2048 x 2048 et restent independants de la
## grille technique 20 x 20.

const INVALID_WORLD_POSITION := Vector2(INF, INF)

var navigable_floor := PackedVector2Array([
	Vector2(820.0, 740.0),
	Vector2(1220.0, 740.0),
	Vector2(1200.0, 900.0),
	Vector2(1190.0, 1020.0),
	Vector2(1260.0, 1095.0),
	Vector2(1450.0, 1110.0),
	Vector2(1650.0, 1095.0),
	Vector2(1830.0, 1080.0),
	Vector2(1975.0, 1390.0),
	Vector2(1810.0, 1600.0),
	Vector2(1690.0, 1700.0),
	Vector2(1630.0, 1670.0),
	Vector2(1528.0, 1660.0),
	Vector2(1448.0, 1700.0),
	Vector2(1400.0, 1790.0),
	Vector2(1325.0, 1860.0),
	Vector2(1375.0, 1920.0),
	Vector2(670.0, 1920.0),
	Vector2(720.0, 1860.0),
	Vector2(650.0, 1790.0),
	Vector2(600.0, 1700.0),
	Vector2(520.0, 1660.0),
	Vector2(420.0, 1670.0),
	Vector2(360.0, 1700.0),
	Vector2(220.0, 1600.0),
	Vector2(70.0, 1400.0),
	Vector2(210.0, 1110.0),
	Vector2(350.0, 1080.0),
	Vector2(440.0, 1100.0),
	Vector2(580.0, 1105.0),
	Vector2(710.0, 1095.0),
	Vector2(800.0, 1040.0),
	Vector2(830.0, 920.0),
])

var table_obstacle := PackedVector2Array([
	Vector2(300.0, 930.0),
	Vector2(325.0, 1010.0),
	Vector2(400.0, 1070.0),
	Vector2(520.0, 1100.0),
	Vector2(650.0, 1095.0),
	Vector2(755.0, 1060.0),
	Vector2(820.0, 1000.0),
	Vector2(820.0, 930.0),
	Vector2(760.0, 870.0),
	Vector2(650.0, 825.0),
	Vector2(480.0, 825.0),
	Vector2(360.0, 870.0),
])

var counter_obstacle := PackedVector2Array([
	Vector2(1220.0, 920.0),
	Vector2(1225.0, 1015.0),
	Vector2(1310.0, 1080.0),
	Vector2(1450.0, 1100.0),
	Vector2(1600.0, 1080.0),
	Vector2(1705.0, 1020.0),
	Vector2(1730.0, 925.0),
	Vector2(1660.0, 850.0),
	Vector2(1530.0, 810.0),
	Vector2(1370.0, 835.0),
	Vector2(1280.0, 865.0),
])

var archivist_obstacle := PackedVector2Array([
	Vector2(624.0, 1152.0),
	Vector2(629.0, 1163.0),
	Vector2(640.0, 1168.0),
	Vector2(651.0, 1163.0),
	Vector2(656.0, 1152.0),
	Vector2(651.0, 1141.0),
	Vector2(640.0, 1136.0),
	Vector2(629.0, 1141.0),
])

const DEBUG_FLOOR_COLOR := Color(0.08, 0.72, 1.0, 0.14)
const DEBUG_FLOOR_LINE := Color(0.22, 0.9, 1.0, 0.94)
const DEBUG_OBSTACLE_COLOR := Color(1.0, 0.24, 0.16, 0.2)
const DEBUG_OBSTACLE_LINE := Color(1.0, 0.42, 0.28, 0.96)
const DEBUG_PATH_COLOR := Color(1.0, 0.86, 0.2, 1.0)

@export var debug_visible := false
@export_range(0.5, 12.0, 0.5) var projection_epsilon := 5.0

var _reserved_positions: Dictionary = {}
var _debug_path := PackedVector2Array()
func _ready() -> void:
	if navigation_polygon == null or navigation_polygon.get_polygon_count() == 0:
		rebuild()


func rebuild() -> void:
	var polygon := NavigationPolygon.new()
	polygon.agent_radius = 4.0
	polygon.add_outline(_as_clockwise(navigable_floor))
	polygon.add_outline(_as_clockwise(archivist_obstacle))
	NavigationServer2D.bake_from_source_geometry_data(
		polygon, NavigationMeshSourceGeometryData2D.new()
	)
	navigation_polygon = polygon
	_force_navigation_sync()
	queue_redraw()


func get_outer_outline() -> PackedVector2Array:
	return navigable_floor.duplicate()


func get_obstacle_outlines() -> Array[PackedVector2Array]:
	return [
		table_obstacle.duplicate(),
		counter_obstacle.duplicate(),
		archivist_obstacle.duplicate(),
	]


func is_world_position_navigable(world_position: Vector2) -> bool:
	var local_position := to_local(world_position)
	if not Geometry2D.is_point_in_polygon(local_position, navigable_floor):
		return false
	for obstacle in get_obstacle_outlines():
		if Geometry2D.is_point_in_polygon(local_position, obstacle):
			return false
	return true


func project_world_position(world_position: Vector2) -> Vector2:
	if is_world_position_navigable(world_position):
		return world_position
	var map_rid := get_navigation_map()
	_force_navigation_sync()
	if map_rid.is_valid():
		var projected := NavigationServer2D.map_get_closest_point(
			map_rid, world_position
		)
		if is_world_position_navigable(projected) \
			or _distance_to_boundaries(projected) <= projection_epsilon:
			return projected
	return to_global(_closest_boundary_point(to_local(world_position)))


func get_world_path(
		from_world: Vector2,
		to_world: Vector2
	) -> PackedVector2Array:
	var start := project_world_position(from_world)
	var destination := project_world_position(to_world)
	if not start.is_finite() or not destination.is_finite():
		return PackedVector2Array()
	var map_rid := get_navigation_map()
	if not map_rid.is_valid():
		return PackedVector2Array()
	_force_navigation_sync()
	var path := NavigationServer2D.map_get_path(
		map_rid,
		start,
		destination,
		true,
		navigation_layers
	)
	if path.is_empty():
		return path
	path[0] = start
	path[path.size() - 1] = destination
	return path


func get_path_length(path: PackedVector2Array) -> float:
	var result := 0.0
	for index in range(1, path.size()):
		result += path[index - 1].distance_to(path[index])
	return result


func reserve_world_position(world_position: Vector2, owner) -> bool:
	if owner == null or not is_world_position_navigable(world_position):
		return false
	for reserved_position in _reserved_positions:
		if (reserved_position as Vector2).is_equal_approx(world_position) \
			and _reserved_positions[reserved_position] != owner:
			return false
	_reserved_positions[world_position] = owner
	return true


func release_world_position(world_position: Vector2, owner = null) -> void:
	for reserved_position in _reserved_positions.keys():
		if not (reserved_position as Vector2).is_equal_approx(world_position):
			continue
		if owner == null or _reserved_positions[reserved_position] == owner:
			_reserved_positions.erase(reserved_position)
		return


func is_world_position_reserved(world_position: Vector2, requester = null) -> bool:
	for reserved_position in _reserved_positions:
		if (reserved_position as Vector2).is_equal_approx(world_position):
			return _reserved_positions[reserved_position] != requester
	return false


func set_debug_visible(enabled: bool) -> void:
	debug_visible = enabled
	queue_redraw()


func set_debug_path(path: PackedVector2Array) -> void:
	_debug_path = path.duplicate()
	queue_redraw()


func _draw() -> void:
	if not debug_visible:
		return
	_draw_closed_outline(navigable_floor, DEBUG_FLOOR_LINE, 4.0)
	for obstacle in get_obstacle_outlines():
		draw_colored_polygon(obstacle, DEBUG_OBSTACLE_COLOR)
		_draw_closed_outline(obstacle, DEBUG_OBSTACLE_LINE, 4.0)
	if _debug_path.size() >= 2:
		var local_path := PackedVector2Array()
		for world_point in _debug_path:
			local_path.append(to_local(world_point))
		draw_polyline(local_path, DEBUG_PATH_COLOR, 7.0, true)
		for point in local_path:
			draw_circle(point, 8.0, DEBUG_PATH_COLOR)


func _draw_closed_outline(
		outline: PackedVector2Array,
		color: Color,
		width: float
	) -> void:
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, color, width, true)


func _closest_boundary_point(local_position: Vector2) -> Vector2:
	var closest := INVALID_WORLD_POSITION
	var closest_distance := INF
	var outlines: Array[PackedVector2Array] = [navigable_floor]
	outlines.append_array(get_obstacle_outlines())
	for outline in outlines:
		for index in range(outline.size()):
			var point := Geometry2D.get_closest_point_to_segment(
				local_position,
				outline[index],
				outline[(index + 1) % outline.size()]
			)
			var distance := local_position.distance_squared_to(point)
			if distance < closest_distance:
				closest = point
				closest_distance = distance
	return closest


func _distance_to_boundaries(world_position: Vector2) -> float:
	var local_position := to_local(world_position)
	return local_position.distance_to(_closest_boundary_point(local_position))


func _force_navigation_sync() -> void:
	var map_rid := get_navigation_map()
	if map_rid.is_valid():
		NavigationServer2D.map_force_update(map_rid)


func _as_clockwise(source: PackedVector2Array) -> PackedVector2Array:
	var result := source.duplicate()
	if not Geometry2D.is_polygon_clockwise(result):
		result.reverse()
	return result
