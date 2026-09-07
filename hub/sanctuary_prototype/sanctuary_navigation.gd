class_name SanctuaryNavigation
extends RefCounted

## Preparatory navigation service, not a playable scene. Owns a dedicated map.
## Coordinates use one stable local floor space chosen by the caller. Convert
## global mouse/actor positions through that floor Node2D's to_local() method.
## RefCounted deliberately avoids Node.get_path(), which has another signature.
signal configuration_finished(success: bool)

const SURFACE_TOLERANCE := 0.25

var foot_radius := 8.0
var debug_enabled := false:
	set(value):
		debug_enabled = value
		_refresh_debug_overlay()

var _navigation_map := RID()
var _navigation_region := RID()
var _polygon: NavigationPolygon
var _outer := PackedVector2Array()
var _obstacles: Array[PackedVector2Array] = []
var _last_path := PackedVector2Array()
var _navigation_ready := false
var _configuration_token := 0
var _debug_overlay_ref: WeakRef


class SanctuaryNavOverlay extends Node2D:
	var surface: NavigationPolygon
	var outer := PackedVector2Array()
	var obstacles: Array[PackedVector2Array] = []
	var path := PackedVector2Array()

	func _draw() -> void:
		if surface != null:
			var vertices := surface.get_vertices()
			for index in surface.get_polygon_count():
				var face := PackedVector2Array()
				for vertex_index in surface.get_polygon(index):
					face.append(vertices[vertex_index])
				draw_colored_polygon(face, Color(0.15, 0.75, 0.70, 0.14))
		_draw_outline(outer, Color(0.3, 0.9, 0.85, 0.85))
		for obstacle: PackedVector2Array in obstacles:
			_draw_outline(obstacle, Color(1.0, 0.35, 0.22, 0.9))
		if path.size() >= 2:
			draw_polyline(path, Color(1.0, 0.82, 0.2), 2.0, true)

	func _draw_outline(outline: PackedVector2Array, color: Color) -> void:
		if outline.size() < 2:
			return
		var closed := outline.duplicate()
		closed.append(outline[0])
		draw_polyline(closed, color, 1.5, true)


## Await while the SceneTree is running. Invalid geometry or close() during
## configuration returns false and leaves movement disabled.
func configure(outer: PackedVector2Array, obstacles: Array[PackedVector2Array]) -> bool:
	_configuration_token += 1
	var token := _configuration_token
	_navigation_ready = false
	_release_navigation()
	_outer = outer.duplicate()
	_obstacles.clear()
	_last_path.clear()
	for obstacle: PackedVector2Array in obstacles:
		_obstacles.append(obstacle.duplicate())
	_refresh_debug_overlay()
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null or not _valid_outline(_outer):
		configuration_finished.emit(false)
		return false
	for obstacle: PackedVector2Array in _obstacles:
		if not _valid_outline(obstacle):
			configuration_finished.emit(false)
			return false

	_polygon = NavigationPolygon.new()
	_polygon.cell_size = 1.0
	_polygon.agent_radius = maxf(foot_radius, 0.0)
	var geometry := NavigationMeshSourceGeometryData2D.new()
	geometry.add_traversable_outline(_outer)
	for obstacle: PackedVector2Array in _obstacles:
		geometry.add_obstruction_outline(obstacle)
	NavigationServer2D.bake_from_source_geometry_data(_polygon, geometry)
	if _polygon.get_polygon_count() == 0:
		configuration_finished.emit(false)
		return false

	_navigation_map = NavigationServer2D.map_create()
	NavigationServer2D.map_set_cell_size(_navigation_map, 1.0)
	NavigationServer2D.map_set_active(_navigation_map, true)
	_navigation_region = NavigationServer2D.region_create()
	NavigationServer2D.region_set_navigation_layers(_navigation_region, 1)
	NavigationServer2D.region_set_transform(_navigation_region, Transform2D.IDENTITY)
	NavigationServer2D.region_set_navigation_polygon(_navigation_region, _polygon)
	NavigationServer2D.region_set_map(_navigation_region, _navigation_map)
	# Godot synchronizes regions/maps asynchronously. A nonzero map iteration
	# alone may describe an empty map; wait until this baked region owns a known
	# interior point. Never rely on the deprecated map_force_update().
	var vertices := _polygon.get_vertices()
	var seed := Vector2.ZERO
	var first_face := _polygon.get_polygon(0)
	for vertex_index in first_face:
		seed += vertices[vertex_index]
	seed /= float(first_face.size())
	for _attempt in range(60):
		await scene_tree.physics_frame
		if token != _configuration_token:
			return false
		if NavigationServer2D.map_get_iteration_id(_navigation_map) > 0 \
				and NavigationServer2D.map_get_closest_point_owner(_navigation_map, seed) == _navigation_region \
				and NavigationServer2D.map_get_closest_point(_navigation_map, seed).distance_to(seed) <= SURFACE_TOLERANCE:
			_navigation_ready = true
			break
	_refresh_debug_overlay()
	configuration_finished.emit(_navigation_ready)
	return _navigation_ready


func is_navigation_ready() -> bool:
	return _navigation_ready


func is_walkable(point: Vector2) -> bool:
	if not _navigation_ready or not point.is_finite():
		return false
	if not Geometry2D.is_point_in_polygon(point, _outer):
		return false
	for obstacle: PackedVector2Array in _obstacles:
		if Geometry2D.is_point_in_polygon(point, obstacle):
			return false
	# The baked surface includes the foot clearance around walls and holes.
	var closest := NavigationServer2D.map_get_closest_point(_navigation_map, point)
	return closest.distance_to(point) <= SURFACE_TOLERANCE


## Refuses invalid endpoints instead of silently crossing a collision boundary.
## The returned path uses local coordinates and is empty until configure finishes.
func get_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	_last_path.clear()
	if not is_walkable(from) or not is_walkable(to):
		_refresh_debug_overlay()
		return PackedVector2Array()
	_last_path = NavigationServer2D.map_get_path(_navigation_map, from, to, true, 1)
	# The server may return a partial path on disconnected islands. Never treat
	# that partial journey as successful arrival at the requested destination.
	if not _last_path.is_empty() and _last_path[-1].distance_to(to) > SURFACE_TOLERANCE:
		_last_path.clear()
	_refresh_debug_overlay()
	return _last_path.duplicate()


## Call when leaving the prototype; destruction also releases all server RIDs.
func close() -> void:
	_configuration_token += 1
	_navigation_ready = false
	_release_navigation()
	_last_path.clear()
	_refresh_debug_overlay()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Inline cleanup: script method dispatch is unavailable during predelete.
		if _navigation_region.is_valid():
			NavigationServer2D.free_rid(_navigation_region)
		if _navigation_map.is_valid():
			NavigationServer2D.free_rid(_navigation_map)


## Optional debug drawing. Add under the same floor Node2D used for coordinates.
## The overlay owns no navigation state and may be freed by its scene normally.
func create_debug_overlay(parent: Node2D) -> Node2D:
	if parent == null:
		return null
	var previous := _debug_overlay_ref.get_ref() as Node2D if _debug_overlay_ref != null else null
	if is_instance_valid(previous):
		previous.queue_free()
	var overlay := SanctuaryNavOverlay.new()
	overlay.name = "SanctuaryNavigationDebug"
	parent.add_child(overlay)
	_debug_overlay_ref = weakref(overlay)
	_refresh_debug_overlay()
	return overlay


func _release_navigation() -> void:
	if _navigation_region.is_valid():
		NavigationServer2D.free_rid(_navigation_region)
		_navigation_region = RID()
	if _navigation_map.is_valid():
		NavigationServer2D.free_rid(_navigation_map)
		_navigation_map = RID()
	_polygon = null


func _valid_outline(outline: PackedVector2Array) -> bool:
	if outline.size() < 3:
		return false
	for point: Vector2 in outline:
		if not point.is_finite():
			return false
	return not Geometry2D.triangulate_polygon(outline).is_empty()


func _refresh_debug_overlay() -> void:
	var overlay := _debug_overlay_ref.get_ref() as SanctuaryNavOverlay if _debug_overlay_ref != null else null
	if not is_instance_valid(overlay):
		return
	overlay.surface = _polygon
	overlay.outer = _outer.duplicate()
	overlay.obstacles.clear()
	for obstacle: PackedVector2Array in _obstacles:
		overlay.obstacles.append(obstacle.duplicate())
	overlay.path = _last_path.duplicate()
	overlay.visible = debug_enabled
	overlay.queue_redraw()
