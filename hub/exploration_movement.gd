class_name ExplorationMovement
extends Node

signal movement_started(destination: Vector2)
signal waypoint_reached(world_position: Vector2)
signal movement_completed(destination: Vector2)
signal movement_cancelled(previous_destination: Vector2)
signal movement_failed(destination: Vector2)
signal movement_direction_changed(world_direction: Vector2)
signal path_changed(path: PackedVector2Array)

const INVALID_WORLD_POSITION := Vector2(INF, INF)

@export_range(40.0, 1200.0, 1.0) var movement_speed := 260.0
@export_range(0.25, 8.0, 0.25) var arrival_tolerance := 2.0

var actor: Node2D = null
var navigation_region: HubNavigationRegion2D = null

var _path := PackedVector2Array()
var _next_waypoint_index := 0
var _requested_destination := INVALID_WORLD_POSITION
var _requester = null
var _moving := false
var _last_direction := Vector2.ZERO


func setup(
		p_actor: Node2D,
		p_navigation_region: HubNavigationRegion2D,
		start_world_position: Vector2
	) -> void:
	actor = p_actor
	navigation_region = p_navigation_region
	var projected_start := navigation_region.project_world_position(
		start_world_position
	)
	actor.global_position = projected_start
	actor.set_meta(&"hub_current_world_position", projected_start)
	_clear_path()
	if actor.is_node_ready():
		_set_actor_idle()
	else:
		call_deferred("_set_actor_idle")
	set_process(true)


func request_move(destination: Vector2, requester = null) -> bool:
	if actor == null or navigation_region == null:
		_set_actor_idle()
		movement_failed.emit(destination)
		return false
	var projected_destination := navigation_region.project_world_position(
		destination
	)
	if not projected_destination.is_finite() \
		or navigation_region.is_world_position_reserved(
			projected_destination, requester
		):
		_set_actor_idle()
		movement_failed.emit(destination)
		return false

	if is_moving():
		var previous := _requested_destination
		_clear_path()
		movement_cancelled.emit(previous)
	return _begin_path(projected_destination, requester)


func cancel() -> void:
	if not is_moving():
		_set_actor_idle()
		return
	var previous := _requested_destination
	_clear_path()
	movement_cancelled.emit(previous)
	_set_actor_idle()


func is_moving() -> bool:
	return _moving


func ensure_idle() -> void:
	if is_moving():
		cancel()
	else:
		_set_actor_idle()


func get_current_world_position() -> Vector2:
	return actor.global_position if is_instance_valid(actor) else INVALID_WORLD_POSITION


func get_requested_destination() -> Vector2:
	return _requested_destination


func get_remaining_path() -> PackedVector2Array:
	var result := PackedVector2Array()
	if not is_instance_valid(actor):
		return result
	result.append(actor.global_position)
	for index in range(_next_waypoint_index, _path.size()):
		result.append(_path[index])
	return result


func _process(delta: float) -> void:
	if not _moving or not is_instance_valid(actor):
		return
	var remaining_distance := movement_speed * maxf(delta, 0.0)
	while _moving and remaining_distance > 0.0:
		if _next_waypoint_index >= _path.size():
			_complete_movement()
			return
		var waypoint := _path[_next_waypoint_index]
		var offset := waypoint - actor.global_position
		var distance := offset.length()
		if distance <= arrival_tolerance:
			actor.global_position = waypoint
			_update_actor_world_position_meta()
			waypoint_reached.emit(waypoint)
			_next_waypoint_index += 1
			continue
		var direction := offset / distance
		_update_actor_facing(direction)
		var travelled := minf(distance, remaining_distance)
		actor.global_position += direction * travelled
		_update_actor_world_position_meta()
		remaining_distance -= travelled
		if travelled + arrival_tolerance >= distance:
			actor.global_position = waypoint
			_update_actor_world_position_meta()
			waypoint_reached.emit(waypoint)
			_next_waypoint_index += 1
		else:
			break
	if _moving and _next_waypoint_index >= _path.size():
		_complete_movement()


func _begin_path(destination: Vector2, requester) -> bool:
	var new_path := navigation_region.get_world_path(
		actor.global_position, destination
	)
	if new_path.is_empty():
		_clear_path()
		_set_actor_idle()
		movement_failed.emit(destination)
		return false
	_requested_destination = destination
	_requester = requester
	_path = new_path
	_next_waypoint_index = 0
	while _next_waypoint_index < _path.size() \
		and actor.global_position.distance_to(
			_path[_next_waypoint_index]
		) <= arrival_tolerance:
		_next_waypoint_index += 1
	path_changed.emit(_path.duplicate())
	if _next_waypoint_index >= _path.size():
		actor.global_position = destination
		_update_actor_world_position_meta()
		_set_actor_idle()
		movement_started.emit(destination)
		movement_completed.emit(destination)
		return true
	_moving = true
	_set_actor_walking()
	movement_started.emit(destination)
	return true


func _complete_movement() -> void:
	var completed_destination := _requested_destination
	actor.global_position = completed_destination
	_update_actor_world_position_meta()
	_clear_path()
	_set_actor_idle()
	movement_completed.emit(completed_destination)


func _clear_path() -> void:
	_path = PackedVector2Array()
	_next_waypoint_index = 0
	_requester = null
	_moving = false
	_last_direction = Vector2.ZERO
	path_changed.emit(PackedVector2Array())


func _update_actor_facing(world_direction: Vector2) -> void:
	if world_direction.is_zero_approx():
		return
	if not world_direction.is_equal_approx(_last_direction):
		_last_direction = world_direction
		movement_direction_changed.emit(world_direction)


func _update_actor_world_position_meta() -> void:
	actor.set_meta(&"hub_current_world_position", actor.global_position)


func _set_actor_walking() -> void:
	if is_instance_valid(actor) and actor.has_method("play_walk"):
		actor.play_walk()


func _set_actor_idle() -> void:
	if not is_instance_valid(actor):
		return
	if actor.has_method("cancel_movement_feedback"):
		actor.cancel_movement_feedback()
	if actor.has_method("play_idle"):
		actor.play_idle()
