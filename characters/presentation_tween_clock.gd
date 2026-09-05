extends Node

## Movement started late in a busy frame must not inherit that frame's
## already elapsed/smoothed delta. Keep Tween interpolation and completion,
## but advance it from its own start time. This changes presentation only.
var _tween: Tween
var _last_tick_usec := 0


static func drive(owner_node: Node, tween: Tween) -> void:
	var clock = load("res://characters/presentation_tween_clock.gd").new()
	clock.name = "PresentationTweenClock"
	clock._tween = tween
	tween.pause()
	clock._last_tick_usec = Time.get_ticks_usec()
	owner_node.add_child(clock)


func _process(_engine_delta: float) -> void:
	if _tween == null or not _tween.is_valid():
		queue_free()
		return
	var now := Time.get_ticks_usec()
	var elapsed := maxf(0.0, float(now - _last_tick_usec) / 1000000.0)
	_last_tick_usec = now
	if not _tween.custom_step(elapsed * Engine.time_scale):
		_tween.kill()
		queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		# Paused wall time is never charged when the tree resumes.
		_last_tick_usec = Time.get_ticks_usec()


func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
