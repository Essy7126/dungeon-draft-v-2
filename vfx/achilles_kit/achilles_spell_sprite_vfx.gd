class_name AchillesSpellSpriteVFX
extends Node2D

## Presentation only. Flight waits for the real resolution acknowledgement;
## reaching the end of its clock never applies damage or creates an impact.
var _frames: SpriteFrames
var _presentation: Dictionary = {}
var _sprites: Array[Sprite2D] = []
var _origin := Vector2.ZERO
var _targets: Array[Vector2] = []
var _elapsed := 0.0
var _phase_elapsed := 0.0
var _duration := 0.2
var _width := 64.0
var _animation: StringName = &"impact"
var _phase: StringName = &""
var _impact_reached := false
var _closed := false
var _last_tick_usec := 0


func _ready() -> void:
	add_to_group("achilles_spell_sprite_vfx")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(false)


func configure(frames: SpriteFrames, presentation: Dictionary, origin: Vector2,
		targets: Array[Vector2], display_width: float) -> void:
	_frames = frames
	_presentation = presentation.duplicate(true)
	_origin = origin
	_targets.assign(targets)
	_width = maxf(1.0, display_width)


func start_flight(duration: float) -> void:
	_impact_reached = false
	_start(&"flight", &"arrow", maxf(0.001, duration))


func start_burst(animation: StringName, duration: float = 0.24) -> void:
	_impact_reached = animation not in [&"dust"]
	_start(&"impact", animation, maxf(0.001, duration))


func start_hold(animation: StringName = &"barrier") -> void:
	_impact_reached = true
	_start(&"hold", animation, 1.0)
	set_process(false)


func confirm_impact(resolved_targets: Array[Vector2]) -> void:
	if _closed or _phase not in [&"flight", &"awaiting_impact"]:
		return
	_targets.assign(resolved_targets)
	if _targets.is_empty():
		cancel()
		return
	_impact_reached = true
	_start(&"impact", &"impact", 0.22)


func _start(phase: StringName, animation: StringName, duration: float) -> void:
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
	set_process(phase != &"hold")


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var delta := maxf(0.0, float(now - _last_tick_usec) / 1000000.0)
	_last_tick_usec = now
	advance_simulation(delta * Engine.time_scale)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_last_tick_usec = Time.get_ticks_usec()


func advance_simulation(delta: float) -> void:
	if _closed or _phase == &"hold":
		return
	var step := maxf(0.0, delta)
	_elapsed += step
	_phase_elapsed += step
	if _phase == &"flight" and _phase_elapsed >= _duration:
		_phase = &"awaiting_impact"
	elif _phase == &"impact" and _phase_elapsed >= _duration:
		cancel()
		return
	# A cancelled/stale cast must not leave a projectile hanging forever.
	if _phase == &"awaiting_impact" and _phase_elapsed > _duration + 1.0:
		cancel()
		return
	_render()


func _render() -> void:
	var progress := clampf(_phase_elapsed / _duration, 0.0, 1.0)
	var count := _frames.get_frame_count(_animation)
	var frame := mini(count - 1, int(progress * count))
	if _phase == &"hold":
		frame = mini(1, count - 1)
	var texture := _frames.get_frame_texture(_animation, frame)
	if texture == null:
		return
	for index in _sprites.size():
		var sprite := _sprites[index]
		var target := _targets[index]
		sprite.texture = texture
		sprite.global_position = _origin.lerp(target, progress) \
			if _phase in [&"flight", &"awaiting_impact"] else target
		sprite.global_rotation = (target - _origin).angle() \
			if _animation in [&"arrow", &"sweep"] else 0.0
		sprite.global_scale = Vector2.ONE * _width / maxf(1.0, texture.get_width())
		var tint := Color.WHITE
		match StringName(_presentation.get("palette_variant", &"base")):
			&"wrath": tint = Color(1.0, 0.88, 0.77)
			&"chiron": tint = Color(0.84, 0.94, 1.0)
			&"aeacus": tint = Color(0.9, 0.96, 1.0)
		if _phase == &"impact":
			tint.a *= clampf((1.0 - progress) / 0.25, 0.0, 1.0)
		sprite.modulate = tint


func get_visual_runtime_state() -> Dictionary:
	return {
		"spell_id": _presentation.get("spell_id", &""),
		"family": _presentation.get("action_family", &"generic"),
		"variant": _presentation.get("variant", &"base"),
		"effect_variant": _presentation.get("effect_variant", &""),
		"phase": _phase, "origin": _origin,
		"target": _targets[0] if not _targets.is_empty() else _origin,
		"targets": _targets.duplicate(), "elapsed": _elapsed,
		"impact_reached": _impact_reached,
		"automatic": bool(_presentation.get("automatic", false)),
		"source_chain": _presentation.get("source_chain", []).duplicate(),
		"cell": _presentation.get("cell", Vector2i(-1, -1)),
		"animation": _animation, "closed": _closed,
	}


func cancel() -> void:
	if _closed:
		return
	_closed = true
	_phase = &"cancelled"
	visible = false
	set_process(false)
	queue_free()
