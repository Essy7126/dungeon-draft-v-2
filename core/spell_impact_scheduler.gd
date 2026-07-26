class_name SpellImpactScheduler
extends Node

signal impact_due(context: CastContext)

var _pending_by_timer: Dictionary = {}


func schedule(context: CastContext, delay_seconds: float) -> bool:
	if context == null or context.failed or context.resolved or not is_inside_tree():
		return false
	if delay_seconds <= 0.0:
		impact_due.emit(context)
		return true

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = delay_seconds
	add_child(timer)
	_pending_by_timer[timer] = context
	timer.timeout.connect(_on_timer_timeout.bind(timer), CONNECT_ONE_SHOT)
	timer.start()
	return true


func cancel_all() -> void:
	for timer_value in _pending_by_timer.keys():
		var timer := timer_value as Timer
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
	_pending_by_timer.clear()


func get_pending_count() -> int:
	return _pending_by_timer.size()


func _exit_tree() -> void:
	cancel_all()


func _on_timer_timeout(timer: Timer) -> void:
	var context := _pending_by_timer.get(timer) as CastContext
	_pending_by_timer.erase(timer)
	if is_instance_valid(timer):
		timer.queue_free()
	if context != null and not context.resolved:
		impact_due.emit(context)
