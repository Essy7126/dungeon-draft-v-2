extends "res://hub/painted_halt/halt_interactions.gd"
## Painted plaques and the gate route to authored safe approaches before opening.


func configure(owner_hall, _preview: bool) -> void:
	hall = owner_hall


func blocked() -> bool:
	return active or hall.entry_input_blocked()


func hit_test(at: Vector2) -> int:
	for index: int in hall.definition.landmarks.size():
		var landmark: Dictionary = hall.definition.landmarks[index]
		var hit: Array = landmark.get("hit_polygon", [])
		if hit.size() >= 3:
			if Geometry2D.is_point_in_polygon(at, hall.polygon(hit)):
				return index
		else:
			var focus: Vector2 = hall.point(landmark.get("focus", landmark.point))
			var delta := Vector2(at.x - focus.x, (at.y - focus.y) * 1.4)
			if delta.length() <= float(landmark.get("radius", 0.045)) * hall.world_size.x:
				return index
	return -1


func request(index: int) -> bool:
	if not super.request(index):
		return false
	hall.announce_approach(index)
	return true


func after_movement() -> void:
	if pending < 0 or hall.is_player_moving() or hall.paused:
		return
	var index := pending
	pending = -1
	# request_move may make a small, safe correction to the authored approach.
	var destination: Vector2 = hall.get_movement_state().destination
	if hall.player.position.distance_to(destination) < 2.0:
		open(index)


func open(index: int) -> void:
	if index < 0 or index >= hall.definition.landmarks.size():
		return
	selected = index
	active = true
	hall.stop_movement()
	hall.show_landmark(index)


func close() -> void:
	active = false
	hall.close_dialogue()


func refresh() -> void:
	if active:
		hall.show_landmark(selected)
