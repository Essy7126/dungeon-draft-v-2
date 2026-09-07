class_name AchillesSprite2DBackend
extends Node2D

signal action_release_reached
signal action_finished(action_name: StringName)
signal death_pose_finished

const DASH_LANDING_SECONDS := 0.08

var animated_sprite: AnimatedSprite2D
var _profile: AchillesSpriteVisualProfile
var _frames: SpriteFrames
var _active := false
var _shutdown := false
var _dead := false
var _facing := "S"
var _stem := "idle"
var _action_pending := false
var _action_id: StringName = &""
var _action_generation := 0
var _release_emitted := false
var _timed_action := false
var _action_elapsed := 0.0
var _action_duration := 0.0
var _release_time := 0.0
var _release_frame := 3
var _legacy_action_loop := false
var _presentation: Dictionary = {}
var _dash_landing_pending := false
var _dash_landing_elapsed := 0.0
var _reaction_pending := false
var _reaction_elapsed := 0.0
var _death_pending := false
var _death_elapsed := 0.0
var _walk_elapsed := 0.0
var _last_tick_usec := 0
var _last_error: StringName = &""
var _distance_driven_move := false


func _ready() -> void:
	# Preserve the established contact shadow and a root fixed on the ground.
	var contact_shadow := Polygon2D.new()
	contact_shadow.name = "ContactShadow"
	contact_shadow.color = Color(0.025, 0.04, 0.035, 0.28)
	var shadow_points := PackedVector2Array()
	for index in 32:
		var angle := TAU * float(index) / 32.0
		shadow_points.append(Vector2(cos(angle) * 15.0, sin(angle) * 4.0 - 1.5))
	contact_shadow.polygon = shadow_points
	add_child(contact_shadow)
	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	animated_sprite.centered = false
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(animated_sprite)
	set_backend_active(false)
	_reset_clock()


func configure(profile: AchillesSpriteVisualProfile) -> bool:
	if _shutdown or profile == null or not is_instance_valid(animated_sprite):
		_last_error = &"SPRITE_PROFILE_INVALID"
		return false
	_profile = profile
	_frames = profile.frames
	if _frames == null and ResourceLoader.exists(profile.sprite_frames_path):
		_frames = load(profile.sprite_frames_path) as SpriteFrames
	_last_error = profile.validation_error(_frames)
	if _last_error != &"":
		return false
	animated_sprite.sprite_frames = _frames
	animated_sprite.scale = Vector2.ONE * profile.display_scale
	animated_sprite.offset = -profile.foot_anchor
	animated_sprite.position = Vector2.ZERO
	animated_sprite.rotation = 0.0
	animated_sprite.flip_h = false
	animated_sprite.flip_v = false
	return true


func _process(_engine_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := maxf(0.0, float(now - _last_tick_usec) / 1000000.0) * Engine.time_scale
	_last_tick_usec = now
	advance_simulation(elapsed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_reset_clock()


## Disable _process before deterministic manual sampling in validation tools.
func advance_simulation(seconds: float) -> void:
	if not _active or _shutdown:
		return
	var delta := maxf(seconds, 0.0)
	if _death_pending:
		_death_elapsed += delta
		_sample_normalized("death", _death_elapsed / _profile.death_duration_seconds)
		if _death_elapsed + 0.0000001 >= _profile.death_duration_seconds:
			_death_pending = false
			death_pose_finished.emit()
		return
	if _dead:
		return
	if _action_pending:
		_advance_action(delta)
		return
	if _dash_landing_pending:
		_dash_landing_elapsed += delta
		if _dash_landing_elapsed + 0.0000001 >= DASH_LANDING_SECONDS:
			_cancel_dash_landing()
			_hold_idle_pose()
		return
	if _reaction_pending:
		_reaction_elapsed += delta
		_sample_normalized("hit", _reaction_elapsed / _profile.hit_duration_seconds)
		if _reaction_elapsed + 0.0000001 >= _profile.hit_duration_seconds:
			_reaction_pending = false
			_hold_idle_pose()
		return
	if _stem == "walk" and not _distance_driven_move:
		_walk_elapsed += delta * animated_sprite.speed_scale
		_sample_walk()


func set_backend_active(active: bool) -> void:
	if not active:
		cancel_action()
	_active = active and not _shutdown and _frames != null and _last_error == &""
	visible = _active
	process_mode = Node.PROCESS_MODE_INHERIT if _active else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(animated_sprite):
		if _active:
			play_idle(_facing)
		else:
			animated_sprite.pause()
	_reset_clock()


func is_backend_active() -> bool:
	return _active and not _shutdown and visible and is_visible_in_tree()


func set_facing_label(direction: String) -> void:
	var next := direction.to_upper()
	if next not in ["N", "E", "S", "W"] or _action_pending or _dead or _reaction_pending or _dash_landing_pending:
		return
	if next == _facing:
		return
	_facing = next
	if _active:
		if _stem == "walk":
			var previous_frame := animated_sprite.frame
			var previous_progress := animated_sprite.frame_progress
			_select_clip("walk")
			animated_sprite.set_frame_and_progress(previous_frame, previous_progress)
		else:
			_hold_idle_pose()


func play_idle(direction := "S") -> bool:
	if not _can_play_loop() or _reaction_pending or _dash_landing_pending:
		return false
	set_facing_label(direction)
	_hold_idle_pose()
	return true


func play_move(direction := "S", running := false) -> bool:
	if not _can_play_loop():
		return false
	_cancel_dash_landing()
	_cancel_reaction()
	set_facing_label(direction)
	var speed := _profile.walk_segment_duration_seconds / _profile.run_segment_duration_seconds if running else 1.0
	if _stem == "walk":
		animated_sprite.speed_scale = speed
		return true
	_stem = "walk"
	_distance_driven_move = false
	_walk_elapsed = 0.0
	animated_sprite.speed_scale = speed
	_select_clip("walk")
	_sample_walk()
	_reset_clock()
	return true


func update_movement_stride(step_index: int, progress: float) -> void:
	if not _can_play_loop() or _stem != "walk":
		return
	# Position and the authored half-cycle remain driven by the same cell tween.
	_distance_driven_move = true
	var half_cycle := floori(float(_frames.get_frame_count(animated_sprite.animation)) * 0.5)
	var phase := float(posmod(step_index, 2) * half_cycle) \
		+ clampf(progress, 0.0, 0.99999) * float(half_cycle)
	animated_sprite.pause()
	animated_sprite.set_frame_and_progress(floori(phase), fposmod(phase, 1.0))


func play_action(direction := "S", action_id: StringName = &"cast", presentation: Dictionary = {}) -> bool:
	if not _can_play_loop():
		return false
	_cancel_dash_landing()
	_cancel_reaction()
	set_facing_label(direction)
	var spec := _action_spec(action_id, presentation)
	_action_generation += 1
	_action_pending = true
	_action_id = action_id
	_presentation = presentation.duplicate(true)
	_release_emitted = false
	_action_elapsed = 0.0
	_distance_driven_move = false
	_timed_action = true
	_stem = String(spec.stem)
	_action_duration = float(spec.duration)
	_release_time = float(spec.release_seconds)
	_release_frame = int(spec.release_frame)
	_legacy_action_loop = bool(spec.legacy_loop)
	animated_sprite.speed_scale = float(spec.speed)
	_select_clip(_stem)
	_sample_action_at(0.0)
	_reset_clock()
	if _release_time <= 0.0:
		_emit_release_once()
	return true


func play_hit(direction := "S") -> bool:
	if not _can_play_loop() or _stem == "walk" or _reaction_pending:
		return false
	if not _has_clip("hit"):
		return true
	_cancel_dash_landing()
	set_facing_label(direction)
	_reaction_pending = true
	_reaction_elapsed = 0.0
	_stem = "hit"
	_select_clip("hit")
	_sample_normalized("hit", 0.0)
	_reset_clock()
	return true


## Arrival-only recovery: no action lock, release marker or finish signal.
## Idle cannot erase it, but a new intentional action can interrupt it.
func finish_dash_landing(direction := "S") -> bool:
	if not _can_play_loop() or not _has_clip("dash") or _dash_landing_pending:
		return false
	_cancel_reaction()
	set_facing_label(direction)
	_dash_landing_pending = true
	_dash_landing_elapsed = 0.0
	_stem = "dash"
	_select_clip("dash")
	animated_sprite.set_frame_and_progress(3, 0.0)
	_reset_clock()
	return true


func play_death(direction := "S") -> bool:
	if not _active or _shutdown or _dead or not _has_clip("death"):
		return false
	cancel_action()
	set_facing_label(direction)
	_dead = true
	_death_pending = true
	_death_elapsed = 0.0
	_stem = "death"
	_select_clip("death")
	_sample_normalized("death", 0.0)
	_reset_clock()
	return true


func cancel_action() -> void:
	_action_generation += 1
	_action_pending = false
	_action_id = &""
	_release_emitted = false
	_timed_action = false
	_action_elapsed = 0.0
	_distance_driven_move = false
	_legacy_action_loop = false
	_cancel_dash_landing()
	_cancel_reaction()
	if is_instance_valid(animated_sprite):
		animated_sprite.pause()
	_reset_clock()


func shutdown() -> void:
	cancel_action()
	_shutdown = true
	_death_pending = false
	_active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func get_last_error() -> StringName:
	return _last_error


func get_vfx_origin() -> Vector2:
	return _profile.cast_origins.get(_facing, Vector2(0.0, -48.0)) \
		if _profile != null else Vector2(0.0, -48.0)


func get_action_watchdog_seconds(action_id: StringName, presentation: Dictionary = {}) -> float:
	if _profile == null or _frames == null:
		return 2.0
	return float(_action_spec(action_id, presentation).duration) + 0.5


func get_runtime_state() -> Dictionary:
	return {
		"animation": String(animated_sprite.animation) if is_instance_valid(animated_sprite) else "",
		"frame": animated_sprite.frame if is_instance_valid(animated_sprite) else -1,
		"frame_progress": animated_sprite.frame_progress if is_instance_valid(animated_sprite) else 0.0,
		"facing": _facing, "stem": _stem, "action_pending": _action_pending,
		"action_id": String(_action_id), "action_elapsed": _action_elapsed,
		"duration_seconds": _action_duration, "release_seconds": _release_time,
		"release_frame": _release_frame, "release_emitted": _release_emitted,
		"presentation": _presentation.duplicate(true), "hit_pending": _reaction_pending,
		"landing_pending": _dash_landing_pending, "landing_elapsed": _dash_landing_elapsed,
		"landing_duration_seconds": DASH_LANDING_SECONDS,
		"dead": _dead, "death_pending": _death_pending, "death_elapsed": _death_elapsed,
		"distance_driven_move": _distance_driven_move, "manual_clock": true,
	}


func _can_play_loop() -> bool:
	return _active and not _shutdown and not _dead and not _action_pending and _frames != null


func _action_spec(action_id: StringName, presentation: Dictionary) -> Dictionary:
	var requested := String(presentation.get("animation_stem", ""))
	if requested == "":
		# Compatibility for callers that still supply only the retired action id.
		if action_id in [&"cast:achilles_guard", &"cast:achilles_bronze_guard"]:
			requested = "guard"
		elif action_id in [&"cast:achilles_advance", &"cast:achilles_fulminant_dash"]:
			requested = "dash"
		else:
			requested = "attack"
	var stem := requested
	if not _has_clip(stem):
		stem = "idle" if requested == "guard" else "walk" if requested == "dash" else "attack"
	var duration := 0.0
	var release_seconds := 0.0
	var release_frame := _profile.attack_release_frame
	var legacy_loop := false
	var speed := 1.0
	if requested == "guard":
		duration = _profile.guard_duration_seconds
		release_seconds = _profile.guard_release_seconds
		release_frame = 3 if stem == "guard" else 0
	elif requested == "dash":
		duration = _profile.advance_duration_seconds
		release_seconds = _profile.advance_release_seconds
		release_frame = 2 if stem == "dash" else 0
		legacy_loop = stem == "walk"
		if legacy_loop:
			speed = _profile.walk_segment_duration_seconds / _profile.run_segment_duration_seconds
	elif _profile.expanded_kit_enabled:
		if stem in ["bow", "volley"]:
			duration = _profile.shot_duration_seconds
			release_seconds = _profile.shot_release_seconds
			release_frame = 3
		elif stem == "sweep":
			duration = _profile.sweep_duration_seconds
			release_seconds = _profile.sweep_release_seconds
			release_frame = 3
		else:
			duration = _profile.attack_duration_seconds
			release_seconds = _profile.attack_release_seconds
	else:
		var clip := StringName(stem + "_" + _facing)
		var fps := _frames.get_animation_speed(clip)
		duration = _clip_weight(clip) / fps
		for index in release_frame:
			release_seconds += _frames.get_frame_duration(clip, index) / fps
	return {"stem": stem, "duration": duration, "release_seconds": release_seconds,
		"release_frame": release_frame, "legacy_loop": legacy_loop, "speed": speed}


func _advance_action(delta: float) -> void:
	var generation := _action_generation
	_action_elapsed += delta
	if not _release_emitted and _action_elapsed + 0.0000001 >= _release_time:
		# Even a busy frame publishes the exact release pose before gameplay
		# observers create the impact. A callback may cancel or kill the actor.
		_sample_action_at(_release_time)
		_emit_release_once()
	if generation != _action_generation or not _action_pending or _dead or _shutdown:
		return
	_sample_action_at(_action_elapsed)
	if _action_elapsed + 0.0000001 >= _action_duration:
		_finish_action_once()


func _sample_action_at(seconds: float) -> void:
	if _stem == "idle":
		animated_sprite.set_frame_and_progress(0, 0.0)
		return
	var clip := StringName(_stem + "_" + _facing)
	if _legacy_action_loop:
		var legacy_phase := fposmod(seconds * _frames.get_animation_speed(clip) * animated_sprite.speed_scale, _clip_weight(clip))
		_sample_weighted_clip(clip, legacy_phase)
		return
	if _stem == "dash":
		if seconds < _release_time:
			_sample_weighted_clip(clip, float(_release_frame) * seconds / maxf(_release_time, 0.000001))
		else:
			# Frame 2 is airborne charge; frame 3 has planted feet and is
			# reserved for Battle's actual arrival, never for translation.
			animated_sprite.set_frame_and_progress(_release_frame, 0.0)
		return
	var before_weight := 0.0
	for index in _release_frame:
		before_weight += _frames.get_frame_duration(clip, index)
	var total_weight := _clip_weight(clip)
	var phase := 0.0
	if seconds < _release_time:
		phase = before_weight * seconds / maxf(_release_time, 0.000001)
	else:
		phase = before_weight + (total_weight - before_weight) \
			* clampf((seconds - _release_time) / maxf(_action_duration - _release_time, 0.000001), 0.0, 1.0)
	_sample_weighted_clip(clip, phase)


func _sample_walk() -> void:
	var clip := StringName("walk_" + _facing)
	var phase := fposmod(_walk_elapsed * _frames.get_animation_speed(clip), _clip_weight(clip))
	_sample_weighted_clip(clip, phase)


func _sample_normalized(stem: String, progress: float) -> void:
	var clip := StringName(stem + "_" + _facing)
	_sample_weighted_clip(clip, clampf(progress, 0.0, 1.0) * _clip_weight(clip))


func _sample_weighted_clip(clip: StringName, phase: float) -> void:
	var count := _frames.get_frame_count(clip)
	var remaining := maxf(phase, 0.0)
	var selected := count - 1
	var progress := 1.0
	for index in count:
		var weight := _frames.get_frame_duration(clip, index)
		if remaining + 0.0000001 < weight:
			selected = index
			progress = clampf(remaining / weight, 0.0, 1.0)
			break
		remaining -= weight
	if animated_sprite.animation != clip:
		animated_sprite.animation = clip
	animated_sprite.pause()
	animated_sprite.set_frame_and_progress(selected, progress)


func _clip_weight(clip: StringName) -> float:
	var weight := 0.0
	for index in _frames.get_frame_count(clip):
		weight += _frames.get_frame_duration(clip, index)
	return weight


func _has_clip(stem: String) -> bool:
	return _frames != null and _frames.has_animation(StringName(stem + "_" + _facing))


func _select_clip(stem: String) -> void:
	animated_sprite.animation = StringName(stem + "_" + _facing)
	animated_sprite.pause()
	animated_sprite.set_frame_and_progress(0, 0.0)
	animated_sprite.flip_h = false
	animated_sprite.flip_v = false


func _emit_release_once() -> void:
	if not _action_pending or _release_emitted or _dead or _shutdown:
		return
	_release_emitted = true
	action_release_reached.emit()


func _finish_action_once() -> void:
	if not _action_pending:
		return
	var generation := _action_generation
	_emit_release_once()
	if generation != _action_generation or not _action_pending or _dead or _shutdown:
		return
	var completed := _action_id
	_action_pending = false
	_timed_action = false
	_action_id = &""
	_cancel_reaction()
	_hold_idle_pose()
	action_finished.emit(completed)


func _cancel_dash_landing() -> void:
	_dash_landing_pending = false
	_dash_landing_elapsed = 0.0


func _cancel_reaction() -> void:
	_reaction_pending = false
	_reaction_elapsed = 0.0


func _hold_idle_pose() -> void:
	_distance_driven_move = false
	_stem = "idle"
	var clip := StringName("idle_" + _facing)
	if animated_sprite.animation != clip:
		animated_sprite.animation = clip
	animated_sprite.pause()
	animated_sprite.set_frame_and_progress(0, 0.0)
	animated_sprite.flip_h = false
	animated_sprite.flip_v = false
	animated_sprite.speed_scale = 1.0


func _reset_clock() -> void:
	_last_tick_usec = Time.get_ticks_usec()


func _exit_tree() -> void:
	shutdown()
