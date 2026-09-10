extends "res://hub/sanctuary_prototype/sanctuary_navigation.gd"
## Entrance-only click assistance. Authored obstacles and foot clearance remain authoritative.


func resolve_destination(from: Vector2, requested: Vector2, snap_distance: float) -> Dictionary:
	if not is_navigation_ready() or not requested.is_finite() or not is_walkable(from):
		return { "ok": false }
	var destination := requested
	if not is_walkable(destination):
		destination = NavigationServer2D.map_get_closest_point(_navigation_map, requested)
		if destination.distance_to(requested) > maxf(0.0, snap_distance):
			return { "ok": false }
	var route := get_path(from, destination)
	if route.is_empty():
		return { "ok": false }
	return {
		"ok": true,
		"destination": destination,
		"adjusted": destination.distance_to(requested) > SURFACE_TOLERANCE,
		"path": route,
	}


func segment_is_walkable(from: Vector2, to: Vector2) -> bool:
	if not is_walkable(from) or not is_walkable(to):
		return false
	# Test the whole displacement, including large QA/time steps; endpoints alone
	# would accept crossing a thin obstruction and landing on its other side.
	for shape: PackedVector2Array in _obstacles:
		for index in shape.size():
			if Geometry2D.segment_intersects_segment(
				from,
				to,
				shape[index],
				shape[(index + 1) % shape.size()],
			) != null:
				return false
	for index in _outer.size():
		if Geometry2D.segment_intersects_segment(
			from,
			to,
			_outer[index],
			_outer[(index + 1) % _outer.size()],
		) != null:
			return false
	var steps := maxi(1, ceili(from.distance_to(to) / maxf(1.0, foot_radius * 0.5)))
	for index in range(1, steps):
		if not is_walkable(from.lerp(to, float(index) / steps)):
			return false
	return true
