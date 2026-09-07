class_name PhilosopherSpellSpriteVFX
extends Node2D

## Presentation of confirmed combat facts only. No damage or status is applied
## here; an unacknowledged projectile never invents its own impact.
var _frames: SpriteFrames
var _spell_id: StringName = &""
var _sprites: Array[Sprite2D] = []
var _origin := Vector2.ZERO
var _targets: Array[Vector2] = []
var _width := 64.0
var _phase: StringName = &""
var _animation: StringName = &"impact"
var _duration := 0.2
var _elapsed := 0.0
var _phase_elapsed := 0.0
var _impact_reached := false
var _closed := false
var _last_tick_usec := 0
var _bound_unit: WeakRef
var _bound_view: WeakRef
var _binding_kind: StringName = &""
var _binding_id: StringName = &""
var _binding_offset := Vector2.ZERO


func _ready() -> void:
	add_to_group("philosopher_spell_sprite_vfx")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(false)


func configure(frames: SpriteFrames, spell_id: StringName, origin: Vector2,
		targets: Array[Vector2], width: float) -> void:
	_frames = frames
	_spell_id = spell_id
	_origin = origin
	_targets.assign(targets)
	_width = maxf(1.0, width)


func start_flight(duration: float) -> void:
	_impact_reached = false
	_start(&"flight", &"bolt", maxf(0.001, duration))


func confirm_impact(targets: Array[Vector2]) -> void:
	if _closed or _phase not in [&"flight", &"awaiting_impact"]:
		return
	_targets.assign(targets)
	if _targets.is_empty():
		cancel()
		return
	start_burst(&"impact", 0.24)


func start_burst(animation: StringName, duration := 0.32) -> void:
	_impact_reached = true
	_start(&"impact", animation, maxf(0.001, duration))


func start_bound(animation: StringName, unit: Unit, unit_view: Node2D,
		kind: StringName, source_id: StringName, offset: Vector2) -> void:
	if not is_instance_valid(unit) or not is_instance_valid(unit_view):
		cancel()
		return
	_bound_unit = weakref(unit)
	_bound_view = weakref(unit_view)
	_binding_kind = kind
	_binding_id = source_id
	_binding_offset = offset
	if not _update_binding():
		return
	start_burst(animation, 0.30)


func _start(phase: StringName, animation: StringName, duration: float) -> void:
	if _closed:
		return
	_phase = phase
	_animation = animation
	_duration = duration
	_phase_elapsed = 0.0
	if _frames == null or not _frames.has_animation(animation) \
			or _frames.get_frame_count(animation) == 0 or _targets.is_empty():
		cancel()
		return
	for sprite in _sprites:
		sprite.free()
	_sprites.clear()
	for _target in _targets:
		var sprite := Sprite2D.new()
		add_child(sprite)
		_sprites.append(sprite)
	_last_tick_usec = Time.get_ticks_usec()
	_render()
	set_process(true)


func _process(_engine_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var delta := maxf(0.0, float(now - _last_tick_usec) / 1000000.0) * Engine.time_scale
	_last_tick_usec = now
	advance_simulation(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_last_tick_usec = Time.get_ticks_usec()


func advance_simulation(seconds: float) -> void:
	if _closed:
		return
	if _binding_kind != &"" and not _update_binding():
		return
	if _phase == &"hold":
		_render()
		return
	var delta := maxf(0.0, seconds)
	_elapsed += delta
	_phase_elapsed += delta
	if _phase == &"flight" and _phase_elapsed >= _duration:
		_phase = &"awaiting_impact"
	elif _phase == &"impact" and _phase_elapsed >= _duration:
		if _binding_kind != &"":
			_phase = &"hold"
		else:
			cancel()
			return
	if _phase == &"awaiting_impact" and _phase_elapsed > _duration + 1.0:
		cancel()
		return
	_render()


func _update_binding() -> bool:
	var unit := _bound_unit.get_ref() as Unit if _bound_unit != null else null
	var view := _bound_view.get_ref() as Node2D if _bound_view != null else null
	if not is_instance_valid(unit) or not unit.is_alive or not is_instance_valid(view) \
			or not view.is_inside_tree() or view.is_queued_for_deletion():
		cancel()
		return false
	var active := unit.get_shield_value(_binding_id) > 0 if _binding_kind == &"shield" \
		else unit.has_status(_binding_id) if _binding_kind == &"status" else false
	if not active:
		cancel()
		return false
	_targets.assign([view.global_position + _binding_offset])
	return true


func _render() -> void:
	var progress := clampf(_phase_elapsed / _duration, 0.0, 1.0)
	var count := _frames.get_frame_count(_animation)
	var frame := mini(count - 1, int(progress * float(count)))
	# The shield/control peak stays stable while the real source remains.
	# The final dissolving drawing is reserved for finite bursts.
	if _binding_kind != &"":
		frame = mini(frame, maxi(0, count - 2))
	var texture := _frames.get_frame_texture(_animation, frame)
	if texture == null:
		return
	for index in _sprites.size():
		var sprite := _sprites[index]
		var target := _targets[index]
		sprite.texture = texture
		sprite.global_position = _origin.lerp(target, progress) \
			if _phase in [&"flight", &"awaiting_impact"] else target
		sprite.global_rotation = (target - _origin).angle() if _animation == &"bolt" else 0.0
		sprite.global_scale = Vector2.ONE * _width / maxf(1.0, texture.get_width())
		sprite.modulate = Color.WHITE
		if _phase == &"impact" and _binding_kind == &"":
			sprite.modulate.a = clampf((1.0 - progress) / 0.25, 0.0, 1.0)


func get_debug_state() -> Dictionary:
	return {
		"spell_id": _spell_id, "phase": _phase, "animation": _animation,
		"sprite_count": _sprites.size(), "origin": _origin,
		"targets": _targets.duplicate(), "elapsed": _elapsed,
		"impact_reached": _impact_reached, "closed": _closed,
		"binding_kind": _binding_kind, "binding_id": _binding_id,
	}


func get_visual_runtime_state() -> Dictionary:
	return get_debug_state()


func cancel() -> void:
	if _closed:
		return
	_closed = true
	_phase = &"cancelled"
	visible = false
	set_process(false)
	_bound_unit = null
	_bound_view = null
	queue_free()
