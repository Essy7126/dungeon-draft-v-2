class_name AchillesSprite2DBackend
extends Node2D

signal action_release_reached
signal action_finished(action_name: StringName)

var animated_sprite: AnimatedSprite2D
var _profile: AchillesSpriteVisualProfile
var _frames: SpriteFrames
var _active := false
var _shutdown := false
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
var _reaction_tween: Tween
var _last_error: StringName = &""
var _starting_clip := false
var _distance_driven_move := false


func _ready() -> void:
	# Ground contact is independent of authored airborne/lunge poses.
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
	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	set_backend_active(false)


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
	animated_sprite.flip_h = false
	animated_sprite.flip_v = false
	return true


func _process(delta: float) -> void:
	if not _active or not _action_pending or not _timed_action:
		return
	var generation := _action_generation
	_action_elapsed += maxf(delta, 0.0)
	if _action_elapsed >= _release_time:
		_emit_release_once()
	if generation != _action_generation or not _action_pending:
		return
	if _action_elapsed >= _action_duration:
		_finish_action_once()


func set_backend_active(active: bool) -> void:
	if not active:
		cancel_action()
	_active = active and not _shutdown and _frames != null
	visible = _active
	process_mode = Node.PROCESS_MODE_INHERIT if _active else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(animated_sprite):
		if _active:
			play_idle(_facing)
		else:
			animated_sprite.stop()


func is_backend_active() -> bool:
	return _active and not _shutdown and visible and is_visible_in_tree()


func set_facing_label(direction: String) -> void:
	var next := direction.to_upper()
	if next not in ["N", "E", "S", "W"] or _action_pending:
		return
	if next == _facing:
		return
	_facing = next
	if _active:
		var prior_frame := animated_sprite.frame
		var prior_progress := animated_sprite.frame_progress
		_play_loop(_stem, animated_sprite.speed_scale)
		animated_sprite.set_frame_and_progress(
			mini(prior_frame, _frames.get_frame_count(animated_sprite.animation) - 1),
			prior_progress
		)


func play_idle(direction := "S") -> bool:
	if not _can_play_loop():
		return false
	set_facing_label(direction)
	return _play_loop("idle", 1.0)


func play_move(direction := "S", running := false) -> bool:
	if not _can_play_loop():
		return false
	set_facing_label(direction)
	var speed := 1.0
	if running:
		speed = _profile.walk_segment_duration_seconds / _profile.run_segment_duration_seconds
	return _play_loop("walk", speed)


func update_movement_stride(step_index: int, progress: float) -> void:
	if not _can_play_loop() or _stem != "walk":
		return
	# The same tween drives position and this half-cycle. A short path must
	# finish on an authored contact pose, never interrupt an airborne frame.
	_distance_driven_move = true
	animated_sprite.pause()
	var half_cycle := floori(float(_frames.get_frame_count(animated_sprite.animation)) * 0.5)
	var phase := float(posmod(step_index, 2) * half_cycle) \
		+ clampf(progress, 0.0, 0.99999) * float(half_cycle)
	animated_sprite.set_frame_and_progress(floori(phase), fposmod(phase, 1.0))

func play_action(direction := "S", action_id: StringName = &"cast") -> bool:
	if not _can_play_loop():
		return false
	set_facing_label(direction)
	_distance_driven_move = false
	_cancel_reaction()
	_action_generation += 1
	_action_pending = true
	_action_id = action_id
	_release_emitted = false
	_action_elapsed = 0.0
	_timed_action = action_id in [&"cast:achilles_guard", &"cast:achilles_advance"]
	if action_id == &"cast:achilles_guard":
		_action_duration = _profile.guard_duration_seconds
		_release_time = _profile.guard_release_seconds
		_stem = "idle"
		# Guard holds the planted pose; shield effects carry its feedback.
		# Translating the entire cutout would slide both feet off their anchor.
		_hold_idle_pose()
	elif action_id == &"cast:achilles_advance":
		_action_duration = _profile.advance_duration_seconds
		_release_time = _profile.advance_release_seconds
		_stem = "walk"
		_play_clip("walk", _profile.walk_segment_duration_seconds / _profile.run_segment_duration_seconds)
	else:
		# The first sprite set has a single authored estoc. Sweep intentionally
		# reuses it; its gameplay targeting and damage remain spell-owned.
		_stem = "attack"
		_play_clip("attack", 1.0)
		_on_frame_changed()
	return true


func play_hit(_direction := "S") -> bool:
	# Damage text, impact effects and sound carry this first sprite set's hit
	# feedback. Keep the authored pose and feet intact; no synthetic squash
	# or whole-body translation substitutes for an un-authored recoil clip.
	return _can_play_loop()


func cancel_action() -> void:
	_action_generation += 1
	_action_pending = false
	_action_id = &""
	_release_emitted = false
	_timed_action = false
	_action_elapsed = 0.0
	_distance_driven_move = false
	_cancel_reaction()
	if is_instance_valid(animated_sprite):
		animated_sprite.stop()


func shutdown() -> void:
	cancel_action()
	_shutdown = true
	_active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func get_last_error() -> StringName:
	return _last_error


func get_vfx_origin() -> Vector2:
	return _profile.cast_origins.get(_facing, Vector2(0.0, -48.0)) \
		if _profile != null else Vector2(0.0, -48.0)


func get_action_watchdog_seconds(action_id: StringName) -> float:
	if action_id == &"cast:achilles_guard":
		return _profile.guard_duration_seconds + 0.5
	if action_id == &"cast:achilles_advance":
		return _profile.advance_duration_seconds + 0.5
	var clip := StringName("attack_" + _facing)
	var duration := 0.0
	for frame_index in _frames.get_frame_count(clip):
		duration += _frames.get_frame_duration(clip, frame_index) / _frames.get_animation_speed(clip)
	return duration + 0.5


func _can_play_loop() -> bool:
	return _active and not _shutdown and not _action_pending and _frames != null


func _play_loop(stem: String, speed: float) -> bool:
	_stem = stem
	if stem == "idle":
		_hold_idle_pose()
		return true
	var clip := StringName(stem + "_" + _facing)
	if animated_sprite.animation == clip and (animated_sprite.is_playing() or _distance_driven_move):
		animated_sprite.speed_scale = speed
		return true
	_play_clip(stem, speed)
	return true


func _play_clip(stem: String, speed: float) -> void:
	# stop()/play() can emit frame_changed synchronously. Publish frame zero
	# only once the new clip is fully selected, including a marker at frame 0.
	_starting_clip = true
	animated_sprite.stop()
	animated_sprite.flip_h = false
	animated_sprite.flip_v = false
	animated_sprite.speed_scale = speed
	animated_sprite.play(StringName(stem + "_" + _facing))
	if stem == "walk" and _distance_driven_move:
		animated_sprite.pause()
	_starting_clip = false


func _on_frame_changed() -> void:
	if _starting_clip:
		return
	if _action_pending and not _timed_action and _stem == "attack" \
			and animated_sprite.animation == StringName("attack_" + _facing) \
			and animated_sprite.frame >= _profile.attack_release_frame:
		_emit_release_once()


func _on_animation_finished() -> void:
	if _action_pending and not _timed_action and _stem == "attack":
		_finish_action_once()


func _emit_release_once() -> void:
	if not _action_pending or _release_emitted:
		return
	_release_emitted = true
	action_release_reached.emit()


func _finish_action_once() -> void:
	if not _action_pending:
		return
	var generation := _action_generation
	_emit_release_once()
	# A release observer can cancel, kill, or remove the character immediately.
	if generation != _action_generation or not _action_pending or _shutdown:
		return
	var completed := _action_id
	_action_pending = false
	_timed_action = false
	_action_id = &""
	_cancel_reaction()
	action_finished.emit(completed)


func _cancel_reaction() -> void:
	if _reaction_tween != null and _reaction_tween.is_valid():
		_reaction_tween.kill()
	_reaction_tween = null
	if is_instance_valid(animated_sprite):
		animated_sprite.position = Vector2.ZERO
		if _profile != null:
			animated_sprite.scale = Vector2.ONE * _profile.display_scale


func _exit_tree() -> void:
	shutdown()


func _hold_idle_pose() -> void:
	_distance_driven_move = false
	# The idle art is a stable model pose, not a sequence of independently
	# redrawn hands/feet. Repeated idle polling must never restart a cycle.
	var clip := StringName("idle_" + _facing)
	_starting_clip = true
	if animated_sprite.animation != clip:
		animated_sprite.animation = clip
	animated_sprite.pause()
	if animated_sprite.frame != 0 or animated_sprite.frame_progress != 0.0:
		animated_sprite.set_frame_and_progress(0, 0.0)
	animated_sprite.flip_h = false
	animated_sprite.flip_v = false
	animated_sprite.speed_scale = 1.0
	_starting_clip = false
