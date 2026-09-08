class_name AchillesSpellSpriteVFX
extends Node2D

## Presentation only. Flight waits for the real resolution acknowledgement;
## reaching the end of its clock never applies damage or creates an impact.
var _frames: SpriteFrames
var _primary_frames: SpriteFrames
var _fallback_frames: SpriteFrames
var _used_source_fallback := false
var _presentation: Dictionary = {}
var _sprites: Array[Sprite2D] = []
var _trails: Array[Sprite2D] = []
var _origin := Vector2.ZERO
var _targets: Array[Vector2] = []
var _elapsed := 0.0
var _phase_elapsed := 0.0
var _duration := 0.2
var _width := 64.0
var _animation: StringName = &"impact"
var _requested_animation: StringName = &"impact"
var _used_animation_fallback := false
var _phase: StringName = &""
var _impact_reached := false
var _closed := false
var _last_tick_usec := 0


func _ready() -> void:
	add_to_group("achilles_spell_sprite_vfx")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(false)


func configure(frames: SpriteFrames, presentation: Dictionary, origin: Vector2,
		targets: Array[Vector2], display_width: float, fallback_frames: SpriteFrames = null) -> void:
	_frames = frames
	_primary_frames = frames
	_fallback_frames = fallback_frames
	_presentation = presentation.duplicate(true)
	_origin = origin
	_targets.assign(targets)
	_width = maxf(1.0, display_width)


func start_flight(duration: float) -> void:
	_impact_reached = false
	var animation := StringName(_presentation.get("projectile_animation", &"arrow"))
	_start(&"flight", animation, maxf(0.001, duration), &"arrow")


func start_burst(animation: StringName, duration: float = 0.24) -> void:
	_impact_reached = animation not in [&"dust"]
	var requested := animation
	if animation == &"impact":
		requested = StringName(_presentation.get("impact_animation", animation))
	elif animation == &"sweep" and _presentation.get("aux_burst_animation", &"") != &"":
		requested = StringName(_presentation.aux_burst_animation)
	_start(&"impact", requested, maxf(0.001, duration), animation)


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
	var animation := StringName(_presentation.get("impact_animation", &"impact"))
	_start(&"impact", animation, 0.22, &"impact")


func _start(phase: StringName, requested: StringName, duration: float,
		fallback: StringName = &"") -> void:
	_phase = phase
	_requested_animation = requested
	_animation = requested
	_used_animation_fallback = false
	_used_source_fallback = false
	_frames = _primary_frames
	# A source may lack utility clips such as guard/dust. Reuse the canonical
	# authored clip while retaining the selected source for its next phase.
	if not _has_animation(requested) and not _has_animation(fallback) and _fallback_frames != null:
		_frames = _fallback_frames
		_used_source_fallback = _frames != _primary_frames
	if not _has_animation(_animation) and fallback != &"" and _has_animation(fallback):
		_animation = fallback
		_used_animation_fallback = true
	_duration = duration
	_phase_elapsed = 0.0
	if not _has_animation(_animation) or _targets.is_empty():
		cancel()
		return
	_clear_sprites()
	for _target in _targets:
		var sprite := Sprite2D.new()
		add_child(sprite)
		_sprites.append(sprite)
	# These are fading samples of the SAME projectile, never extra arrows or
	# target cells. A volley still owns one real head per legal fan cell.
	if phase == &"flight":
		for _index in _targets.size() * _trail_count():
			var trail := Sprite2D.new()
			trail.z_index = -1
			add_child(trail)
			_trails.append(trail)
	_last_tick_usec = Time.get_ticks_usec()
	_render()
	set_process(phase != &"hold")


func _has_animation(animation: StringName) -> bool:
	return _frames != null and _frames.has_animation(animation) \
		and _frames.get_frame_count(animation) > 0


func _clear_sprites() -> void:
	for sprite in _sprites:
		sprite.free()
	_sprites.clear()
	for trail in _trails:
		trail.free()
	_trails.clear()


func _trail_count() -> int:
	return clampi(int(_presentation.get("projectile_trail_count", 0)), 0, 3)


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
	var in_flight := _phase in [&"flight", &"awaiting_impact"]
	var scale_ratio := Vector2.ONE
	# Dedicated art carries its authored silhouette without stretching. The
	# older six-clip atlas remains readable through a bounded shape fallback.
	if in_flight and _used_animation_fallback:
		scale_ratio = _presentation.get("projectile_scale", Vector2.ONE)
	var tint := _palette_tint()
	if _phase == &"impact":
		tint.a *= clampf((1.0 - progress) / 0.25, 0.0, 1.0)
	for index in _sprites.size():
		var sprite := _sprites[index]
		var target := _targets[index]
		var angle := (target - _origin).angle() if in_flight or _animation == &"sweep" else 0.0
		_render_sprite(sprite, texture,
			_origin.lerp(target, progress) if in_flight else target,
			angle, scale_ratio, tint)
		if in_flight:
			_render_trail(index, texture, progress, angle, scale_ratio, tint)


func _render_sprite(sprite: Sprite2D, texture: Texture2D, point: Vector2,
		angle: float, scale_ratio: Vector2, tint: Color) -> void:
	sprite.texture = texture
	sprite.global_position = point
	sprite.global_rotation = angle
	sprite.global_scale = scale_ratio * _width / maxf(1.0, texture.get_width())
	sprite.modulate = tint


func _render_trail(target_index: int, texture: Texture2D, progress: float,
		angle: float, scale_ratio: Vector2, tint: Color) -> void:
	var count := _trail_count()
	var spacing := clampf(float(_presentation.get("projectile_trail_spacing", 0.06)), 0.02, 0.12)
	var alpha := clampf(float(_presentation.get("projectile_trail_alpha", 0.18)), 0.0, 0.3)
	var waiting_fade := clampf(1.0 - maxf(0.0, _phase_elapsed - _duration) / 0.08, 0.0, 1.0)
	for index in count:
		var trail := _trails[target_index * count + index]
		var delay := spacing * float(index + 1)
		var trail_progress := maxf(0.0, progress - delay)
		var trail_tint := tint
		trail_tint.a *= alpha * (1.0 - float(index) / float(count)) * waiting_fade \
			* clampf(progress / delay, 0.0, 1.0)
		_render_sprite(trail, texture, _origin.lerp(_targets[target_index], trail_progress),
			angle, scale_ratio * (1.0 - 0.06 * float(index + 1)), trail_tint)


func _palette_tint() -> Color:
	# Elemental and healing art already carries its own authored palette.
	if _presentation.get("effects_source", &"achilles") != &"achilles" and not _used_source_fallback:
		return Color.WHITE
	match StringName(_presentation.get("palette_variant", &"base")):
		&"wrath": return Color(1.0, 0.88, 0.77)
		&"chiron": return Color(0.84, 0.94, 1.0)
		&"aeacus": return Color(0.9, 0.96, 1.0)
	return Color.WHITE


func get_visual_runtime_state() -> Dictionary:
	return {
		"spell_id": _presentation.get("spell_id", &""),
		"family": _presentation.get("action_family", &"generic"),
		"variant": _presentation.get("variant", &"base"),
		"effect_variant": _presentation.get("effect_variant", &""),
		"projectile_variant": _presentation.get("projectile_variant", &"none"),
		"projectile_animation": _presentation.get("projectile_animation", &"arrow"),
		"impact_animation": _presentation.get("impact_animation", &"impact"),
		"effects_source": _presentation.get("effects_source", &"achilles"),
		"used_source_fallback": _used_source_fallback,
		"phase": _phase, "origin": _origin,
		"target": _targets[0] if not _targets.is_empty() else _origin,
		"targets": _targets.duplicate(), "elapsed": _elapsed,
		"impact_reached": _impact_reached,
		"automatic": bool(_presentation.get("automatic", false)),
		"source_chain": _presentation.get("source_chain", []).duplicate(),
		"cell": _presentation.get("cell", Vector2i(-1, -1)),
		"cast_distance": int(_presentation.get("cast_distance", -1)),
		"alternate_origin": bool(_presentation.get("alternate_origin", false)),
		"animation": _animation, "requested_animation": _requested_animation,
		"used_animation_fallback": _used_animation_fallback,
		"head_count": _sprites.size(), "trail_count": _trails.size(),
		"closed": _closed,
	}


func cancel() -> void:
	if _closed:
		return
	_closed = true
	_phase = &"cancelled"
	visible = false
	set_process(false)
	queue_free()
