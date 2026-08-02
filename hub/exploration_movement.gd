class_name ExplorationMovement
extends Node

signal movement_started(destination: Vector2i)
signal cell_entered(cell: Vector2i)
signal movement_completed(destination: Vector2i)
signal movement_cancelled(previous_destination: Vector2i)
signal movement_failed(destination: Vector2i)

const INVALID_CELL := Vector2i(-1, -1)

@export_range(40.0, 1200.0, 1.0) var movement_speed := 260.0

var current_cell := INVALID_CELL
var actor: Node2D = null
var navigation_grid: HubNavigationGrid = null

var _path: Array[Vector2i] = []
var _segment_target := INVALID_CELL
var _requested_destination := INVALID_CELL
var _requester = null
var _pending_destination := INVALID_CELL
var _pending_requester = null
var _cancel_at_next_center := false


func setup(p_actor: Node2D, grid: HubNavigationGrid, start_cell: Vector2i) -> void:
	actor = p_actor
	navigation_grid = grid
	current_cell = start_cell
	actor.position = navigation_grid.cell_to_world(current_cell)
	actor.set_meta(&"hub_current_cell", current_cell)
	if actor.is_node_ready():
		_set_actor_idle()
	else:
		call_deferred("_set_actor_idle")
	set_process(true)


func request_move(destination: Vector2i, requester = null) -> bool:
	if actor == null or navigation_grid == null \
		or not navigation_grid.is_walkable(destination, requester):
		_set_actor_idle()
		movement_failed.emit(destination)
		return false

	if is_moving():
		var previous := _requested_destination
		_path.clear()
		_pending_destination = destination
		_pending_requester = requester
		_requested_destination = destination
		_requester = requester
		_cancel_at_next_center = false
		movement_cancelled.emit(previous)
		_set_actor_walking()
		movement_started.emit(destination)
		return true

	return _begin_path(destination, requester, true)


func cancel() -> void:
	if not is_moving():
		_set_actor_idle()
		return
	var previous := _requested_destination
	_path.clear()
	_pending_destination = INVALID_CELL
	_pending_requester = null
	_cancel_at_next_center = true
	movement_cancelled.emit(previous)


func is_moving() -> bool:
	return _segment_target != INVALID_CELL or not _path.is_empty() \
		or _pending_destination != INVALID_CELL


func ensure_idle() -> void:
	_set_actor_idle()


func _process(delta: float) -> void:
	if actor == null or _segment_target == INVALID_CELL:
		return
	var target_world := navigation_grid.cell_to_world(_segment_target)
	actor.position = actor.position.move_toward(target_world, movement_speed * delta)
	if not actor.position.is_equal_approx(target_world):
		return

	actor.position = target_world
	current_cell = _segment_target
	actor.set_meta(&"hub_current_cell", current_cell)
	_segment_target = INVALID_CELL
	cell_entered.emit(current_cell)

	if _cancel_at_next_center:
		_cancel_at_next_center = false
		_finish_visual_motion()
		return
	if _pending_destination != INVALID_CELL:
		var destination := _pending_destination
		var pending_requester = _pending_requester
		_pending_destination = INVALID_CELL
		_pending_requester = null
		_begin_path(destination, pending_requester, false)
		return
	if not _path.is_empty():
		_start_next_segment()
		return

	_finish_visual_motion()
	movement_completed.emit(_requested_destination)


func _begin_path(destination: Vector2i, requester, emit_started: bool) -> bool:
	var new_path := navigation_grid.get_path(current_cell, destination, requester)
	if new_path.is_empty():
		_set_actor_idle()
		movement_failed.emit(destination)
		return false
	_requested_destination = destination
	_requester = requester
	_path = new_path
	if _path[0] == current_cell:
		_path.pop_front()
	if emit_started:
		_set_actor_walking()
		movement_started.emit(destination)
	if _path.is_empty():
		actor.position = navigation_grid.cell_to_world(current_cell)
		_finish_visual_motion()
		movement_completed.emit(destination)
		return true
	_start_next_segment()
	return true


func _start_next_segment() -> void:
	_segment_target = _path.pop_front()
	var direction := _segment_target - current_cell
	if actor.has_method("set_facing"):
		actor.set_facing(direction)


func _finish_visual_motion() -> void:
	_segment_target = INVALID_CELL
	_path.clear()
	_requester = null
	_set_actor_idle()


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
