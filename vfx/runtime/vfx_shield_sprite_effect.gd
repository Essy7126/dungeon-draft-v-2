class_name VFXShieldSpriteEffect
extends Node2D

## A status-bound presentation layer. Only observes Unit's resolved shield;
## it never grants points, changes damage, moves the actor, or changes its pose.
@export var profile: VFXProfile
@export var effect_id: StringName = &"shield_sprite"
@export_range(1.0, 512.0, 1.0) var canvas_display_size := 130.0
@export_range(0.0, 0.25, 0.01) var end_fade_seconds := 0.05

var _source_unit: Unit
var _source_view: Node2D
var _runtime: VFXRuntimeInstance
var _phase: StringName = &""
var _previous_shield := 0
var _last_tick_usec := 0
var _closing := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(false)


## Legacy scene placement is followed by bind_source_unit in VFXManager.
func initialiser(_origin: Vector2, target: Vector2) -> void:
	global_position = target


func bind_source_unit(source: Unit, source_view: Node2D) -> void:
	if not is_instance_valid(source) or not source.is_alive \
			or source.current_shield <= 0 or not is_instance_valid(source_view) \
			or not source_view.is_inside_tree() or profile == null:
		cancel()
		return
	_disconnect_source()
	_source_unit = source
	_source_view = source_view
	_previous_shield = source.current_shield
	# A refresh has one owner and one visual, including during the old fade.
	for child in source_view.get_children():
		if child != self and child is VFXShieldSpriteEffect \
				and child.effect_id == effect_id:
			child.cancel()
	if get_parent() != source_view:
		reparent(source_view, false)
	position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	if source_view.has_method("get_painted_visual_scale"):
		scale *= float(source_view.get_painted_visual_scale())
	_source_unit.shield_changed.connect(_on_shield_changed)
	_source_unit.died.connect(_on_source_died)
	_start_phase(&"activation")


func _process(_engine_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var own_delta := maxf(0.0, float(now - _last_tick_usec) / 1000000.0)
	_last_tick_usec = now
	advance_simulation(own_delta * Engine.time_scale)


## Manual stepping also supports deterministic previews and lifecycle checks.
func advance_simulation(delta: float) -> void:
	if _closing or not is_instance_valid(_runtime):
		return
	# A held shield is one still sprite, with no clock or frame oscillation.
	if _phase == &"hold":
		return
	if _phase == &"end" and end_fade_seconds > 0.0:
		var remaining := _runtime.sequence.duration() - (_runtime.elapsed + maxf(delta, 0.0))
		_runtime.modulate.a = clampf(remaining / end_fade_seconds, 0.0, 1.0)
	_runtime.advance_simulation(maxf(delta, 0.0))


func get_phase_id() -> StringName:
	return _phase


func get_runtime_instance() -> VFXRuntimeInstance:
	return _runtime if is_instance_valid(_runtime) else null


func get_bound_unit() -> Unit:
	return _source_unit


func cancel() -> void:
	if _closing:
		return
	_closing = true
	set_process(false)
	_disconnect_source()
	_clear_runtime()
	visible = false
	queue_free()


func _start_phase(phase_id: StringName) -> void:
	if _closing:
		return
	_clear_runtime()
	_phase = phase_id
	var context := VFXExecutionContext.create({
		"target_world": Vector2.ZERO,
		"origin_world": Vector2.ZERO,
		"cell_visual_size": Vector2.ONE * canvas_display_size,
		"quality_tier": 2,
		"seed": 0,
		"consumer_kind": &"status_bound_sprite",
		"target_layer": self,
	})
	var result := VFXProfileRunner.play(profile, context, phase_id, self, false)
	if not bool(result.get("ok", false)):
		push_warning("Shield sprite VFX skipped: %s" % result.get("errors", []))
		cancel()
		return
	_runtime = result.get("instance") as VFXRuntimeInstance
	_runtime.completed.connect(_on_phase_completed)
	# Display frame zero immediately; transitions never insert a blank frame.
	_runtime.advance_simulation(0.0)
	_last_tick_usec = Time.get_ticks_usec()
	set_process(phase_id != &"hold")


func _on_phase_completed(instance: VFXRuntimeInstance, _reason: StringName) -> void:
	if _closing or instance != _runtime:
		return
	if _phase == &"end":
		cancel()
	elif is_instance_valid(_source_unit) and _source_unit.is_alive \
			and _source_unit.current_shield > 0:
		_start_phase(&"hold")
	else:
		_start_phase(&"end")


func _on_shield_changed(changed_unit: Unit) -> void:
	if _closing or changed_unit != _source_unit:
		return
	var previous := _previous_shield
	_previous_shield = changed_unit.current_shield
	if not changed_unit.is_alive:
		cancel()
	elif changed_unit.current_shield <= 0:
		if _phase != &"end":
			_start_phase(&"end")
	elif _phase == &"end":
		# A recharge may arrive from another resolved source before dissolution
		# finishes. Preserve this owner instead of removing a live shield.
		_start_phase(&"activation")
	elif changed_unit.current_shield < previous:
		_start_phase(&"hit")


func _on_source_died(_unit: Unit) -> void:
	# The actor owns its death fade. A surviving aura would become a ghost.
	cancel()


func _clear_runtime() -> void:
	var previous := _runtime
	_runtime = null
	if not is_instance_valid(previous):
		return
	if previous.completed.is_connected(_on_phase_completed):
		previous.completed.disconnect(_on_phase_completed)
	previous.clear()
	previous.queue_free()


func _disconnect_source() -> void:
	if is_instance_valid(_source_unit):
		if _source_unit.shield_changed.is_connected(_on_shield_changed):
			_source_unit.shield_changed.disconnect(_on_shield_changed)
		if _source_unit.died.is_connected(_on_source_died):
			_source_unit.died.disconnect(_on_source_died)
	_source_unit = null
	_source_view = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_last_tick_usec = Time.get_ticks_usec()


func _exit_tree() -> void:
	# reparent(..., false) emits exit/enter notifications during initial binding.
	if not _closing and is_instance_valid(_source_view) \
			and get_parent() != _source_view:
		return
	_closing = true
	_disconnect_source()
	_clear_runtime()

