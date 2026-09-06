class_name SpectreGreatswordIsoUnitView
extends Node2D

signal animation_finished(animation_name: StringName)
signal cast_release_reached
signal death_animation_finished

const MOVEMENT_SETTLE_SECONDS := 0.06
const DIRECTIONS := ["N", "E", "S", "W"]

@export var sprite_profile: SpectreSpriteVisualProfile
@export var painted_visual_profile: UnitVisualProfile

## Exposed for previews and validation; never plays itself on the engine clock.
var animated_sprite: AnimatedSprite2D
var rendering_backend := "SPRITE_2D"

var _frames: SpriteFrames
var _unit: Unit
var _facing := "S"
var _queued_facing := ""
var _stem := "idle"
var _configured := false
var _closing := false
var _dead := false
var _death_finished := false
var _death_elapsed := 0.0
var _death_base_alpha := 1.0
var _action_pending := false
var _action_elapsed := 0.0
var _pending_action_id: StringName = &""
var _release_emitted := false
var _generation := 0
var _movement_active := false
var _movement_feedback_owned := false
var _movement_elapsed := 0.0
var _movement_stable_time := 0.0
var _last_parent_position := Vector2.ZERO
var _last_tick_usec := 0
var _last_error: StringName = &""


func _ready() -> void:
	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	animated_sprite.centered = false
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Only the facade samples frames. This prevents a newly started clip from
	# consuming an engine delta that began before its actual start time.
	animated_sprite.set_process(false)
	add_child(animated_sprite)
	configure_profile(sprite_profile)
	_record_parent_position()
	_reset_clock()
	if is_instance_valid(_unit) and not _unit.is_alive:
		play_death()


func get_painted_visual_profile() -> UnitVisualProfile:
	return painted_visual_profile


func configure_profile(profile: SpectreSpriteVisualProfile) -> bool:
	if _closing or not is_instance_valid(animated_sprite):
		return false
	cancel_pending_visual_actions()
	sprite_profile = profile
	_frames = profile.frames if profile != null else null
	if profile != null and _frames == null and ResourceLoader.exists(profile.sprite_frames_path):
		_frames = load(profile.sprite_frames_path) as SpriteFrames
	_last_error = profile.validation_error(_frames) if profile != null else &"SPRITE_PROFILE_MISSING"
	_configured = _last_error == &""
	animated_sprite.visible = _configured
	if not _configured:
		return false
	animated_sprite.sprite_frames = _frames
	animated_sprite.offset = -profile.foot_anchor
	animated_sprite.scale = Vector2.ONE * profile.get_display_scale()
	animated_sprite.position = Vector2.ZERO
	animated_sprite.rotation = 0.0
	animated_sprite.flip_h = false
	animated_sprite.flip_v = false
	_hold_idle_pose()
	_reset_clock()
	return true


func bind_unit(unit: Unit) -> void:
	_disconnect_unit()
	cancel_pending_visual_actions()
	_unit = unit
	_dead = false
	_death_finished = false
	_death_elapsed = 0.0
	modulate.a = 1.0
	visible = true
	if is_instance_valid(_unit):
		_unit.died.connect(_on_bound_unit_died)
		set_facing(_unit.facing_dir)
		if not _unit.is_alive and is_node_ready():
			play_death()
	_record_parent_position()
	_reset_clock()


func _process(_engine_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := maxf(0.0, float(now - _last_tick_usec) / 1000000.0) * Engine.time_scale
	_last_tick_usec = now
	advance_simulation(elapsed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_reset_clock()


## Deterministic counterpart for validation. Disable _process while using it.
func advance_simulation(seconds: float) -> void:
	if _closing:
		return
	var delta := maxf(seconds, 0.0)
	if _dead:
		_advance_death(delta)
		return
	if not _configured:
		return
	if _action_pending:
		_advance_action(delta)
		return
	var inferred_start := _track_parent_movement(delta)
	if _movement_active and not inferred_start:
		_movement_elapsed += delta
		_sample_walk()


func set_facing(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	var label := ("E" if direction.x > 0 else "W") if absi(direction.x) >= absi(direction.y) \
		else ("S" if direction.y > 0 else "N")
	set_facing_label(label)


func set_facing_label(direction: String) -> void:
	var next := direction.to_upper()
	if _closing or _dead or next not in DIRECTIONS:
		return
	if _action_pending:
		_queued_facing = next
		return
	if next == _facing:
		return
	_facing = next
	if not _configured:
		return
	if _movement_active:
		_sample_walk()
	else:
		_hold_idle_pose()


func play_idle() -> bool:
	if not _can_act() or (_movement_active and _movement_feedback_owned):
		return false
	_movement_active = false
	_movement_stable_time = 0.0
	_record_parent_position()
	_hold_idle_pose()
	return true


func play_walk() -> bool:
	if not _can_act():
		return false
	_begin_glide(true)
	return true


func play_run() -> bool:
	return play_walk()


func begin_movement_feedback(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if not _can_act() or from_cell == to_cell:
		return
	set_facing(to_cell - from_cell)
	_begin_glide(true)


func begin_path_movement_feedback(path: Array) -> void:
	if path.size() < 2 or not path[0] is Vector2i or not path[1] is Vector2i:
		return
	begin_movement_feedback(path[0] as Vector2i, path[1] as Vector2i)


func get_movement_segment_duration(_path: Array) -> float:
	return sprite_profile.movement_segment_duration_seconds if sprite_profile != null else 0.28


func update_movement_stride(_step_index: int, _progress: float) -> void:
	# A levitating creature has no alternating foot contacts. Cell progress
	# must never reset or scrub the continuous authored cloth cycle.
	pass


func cancel_movement_feedback() -> void:
	synchronize_external_movement()


func end_movement_feedback() -> void:
	cancel_movement_feedback()


func synchronize_external_movement() -> void:
	_record_parent_position()
	_movement_active = false
	_movement_feedback_owned = false
	_movement_stable_time = 0.0
	if _can_act():
		_hold_idle_pose()


func play_basic_attack() -> bool:
	return _begin_action(&"attack")


func play_cast() -> bool:
	return _begin_action(&"cast")


func play_spell_action(spell: Spell = null) -> bool:
	var action_id := &"cast"
	if spell != null:
		action_id = StringName("cast:" + String(spell.get_effective_spell_id()))
	return _begin_action(action_id)


func play_hit() -> bool:
	# UnitView already supplies damage flash/text. Preserve the model and its
	# weapon grip instead of synthesizing an unauthored squash or cutout tilt.
	return _can_act() and not _movement_active


func cancel_spell_action() -> void:
	cancel_pending_visual_actions()


func cancel_pending_visual_actions() -> void:
	# UnitView cancels pending actions when death is signalled; that late
	# cancellation must not interrupt a fade already started by this visual.
	if _dead and not _closing:
		return
	_generation += 1
	_action_pending = false
	_action_elapsed = 0.0
	_pending_action_id = &""
	_release_emitted = false
	_movement_active = false
	_movement_feedback_owned = false
	_movement_elapsed = 0.0
	_movement_stable_time = 0.0
	_apply_queued_facing()
	_record_parent_position()
	if _configured and not _closing:
		_hold_idle_pose()
	_reset_clock()


func play_death() -> bool:
	if _closing or _dead:
		return false
	cancel_pending_visual_actions()
	_dead = true
	_death_finished = false
	_death_elapsed = 0.0
	_death_base_alpha = modulate.a
	_reset_clock()
	return true


func get_default_cast_effect_origin() -> Vector2:
	return sprite_profile.cast_origins.get(_facing, Vector2(0.0, -48.0)) \
		if sprite_profile != null else Vector2(0.0, -48.0)


func get_logical_foot_position() -> Vector2:
	return Vector2.ZERO


func get_portrait_texture(direction := "S") -> Texture2D:
	var label := direction.to_upper()
	if _frames == null or label not in DIRECTIONS:
		return null
	return _frames.get_frame_texture(StringName("idle_" + label), 0)


func get_active_backend_name() -> StringName:
	return &"Sprite2DBackend" if _configured else &"Unavailable"


func get_last_backend_error() -> Dictionary:
	return {} if _last_error == &"" else {"error_code": _last_error, "backend": "SPRITE_2D"}


func get_visual_runtime_state() -> Dictionary:
	return {
		"backend": "SPRITE_2D", "configured": _configured,
		"frames_path": sprite_profile.sprite_frames_path if sprite_profile != null else "",
		"animation": String(animated_sprite.animation) if is_instance_valid(animated_sprite) else "",
		"frame": animated_sprite.frame if is_instance_valid(animated_sprite) else -1,
		"frame_progress": animated_sprite.frame_progress if is_instance_valid(animated_sprite) else 0.0,
		"facing": _facing, "stem": _stem,
		"action_pending": _action_pending, "action_elapsed": _action_elapsed,
		"release_emitted": _release_emitted, "action_id": String(_pending_action_id),
		"movement_active": _movement_active, "movement_elapsed": _movement_elapsed,
		"movement_feedback_owned": _movement_feedback_owned,
		"dead": _dead, "death_finished": _death_finished, "death_elapsed": _death_elapsed,
		"ground_anchor": Vector2.ZERO,
		"authored_ground_anchor": sprite_profile.foot_anchor if sprite_profile != null else Vector2.ZERO,
		"sprite_offset": animated_sprite.offset if is_instance_valid(animated_sprite) else Vector2.ZERO,
		"sprite_scale": animated_sprite.scale if is_instance_valid(animated_sprite) else Vector2.ONE,
		"flip_h": animated_sprite.flip_h if is_instance_valid(animated_sprite) else false,
		"flip_v": animated_sprite.flip_v if is_instance_valid(animated_sprite) else false,
		"autoplay": animated_sprite.is_playing() if is_instance_valid(animated_sprite) else false,
		"error_code": String(_last_error),
	}


func _can_act() -> bool:
	return _configured and not _closing and not _dead and not _action_pending


func _begin_action(action_id: StringName) -> bool:
	if not _can_act():
		return false
	_generation += 1
	_action_pending = true
	_action_elapsed = 0.0
	_pending_action_id = action_id
	_release_emitted = false
	_movement_active = false
	_movement_feedback_owned = false
	_stem = "attack"
	_sample_action()
	_reset_clock()
	if sprite_profile.attack_release_frame == 0:
		_emit_release_once()
	return true


func _advance_action(delta: float) -> void:
	var generation := _generation
	_action_elapsed += delta
	_sample_action()
	var release_time := _get_attack_release_seconds()
	if _action_elapsed + 0.0000001 >= release_time:
		_emit_release_once()
	# A release observer may kill/cancel/free this visual immediately.
	if generation != _generation or not _action_pending or _dead or _closing:
		return
	if _action_elapsed + 0.0000001 >= sprite_profile.attack_duration_seconds:
		var completed := _pending_action_id
		_action_pending = false
		_pending_action_id = &""
		_apply_queued_facing()
		_record_parent_position()
		_hold_idle_pose()
		animation_finished.emit(completed)


func _emit_release_once() -> void:
	if _closing or _dead or not _action_pending or _release_emitted:
		return
	_release_emitted = true
	cast_release_reached.emit()


func _get_attack_release_seconds() -> float:
	var clip := StringName("attack_" + _facing)
	var preceding_weight := 0.0
	for index in sprite_profile.attack_release_frame:
		preceding_weight += _frames.get_frame_duration(clip, index)
	return sprite_profile.attack_duration_seconds * preceding_weight / _clip_weight(clip)


func _sample_action() -> void:
	var clip := StringName("attack_" + _facing)
	var normalized := clampf(_action_elapsed / sprite_profile.attack_duration_seconds, 0.0, 1.0)
	_sample_weighted_clip(clip, normalized * _clip_weight(clip))


func _begin_glide(owned: bool) -> void:
	if not _movement_active:
		_movement_elapsed = 0.0
		_reset_clock()
	_movement_active = true
	_movement_feedback_owned = owned
	_movement_stable_time = 0.0
	_stem = "walk"
	_record_parent_position()
	_sample_walk()


func _sample_walk() -> void:
	var clip := StringName("walk_" + _facing)
	var phase := fposmod(_movement_elapsed * _frames.get_animation_speed(clip), _clip_weight(clip))
	_sample_weighted_clip(clip, phase)


func _sample_weighted_clip(clip: StringName, phase: float) -> void:
	var frame_count := _frames.get_frame_count(clip)
	var remaining := phase
	var selected := frame_count - 1
	var progress := 1.0
	for index in frame_count:
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


func _hold_idle_pose() -> void:
	if not _configured or not is_instance_valid(animated_sprite):
		return
	_stem = "idle"
	var clip := StringName("idle_" + _facing)
	if animated_sprite.animation != clip:
		animated_sprite.animation = clip
	animated_sprite.pause()
	animated_sprite.set_frame_and_progress(0, 0.0)


func _track_parent_movement(delta: float) -> bool:
	var parent_2d := get_parent() as Node2D
	if parent_2d == null:
		return false
	var moved := parent_2d.position.distance_squared_to(_last_parent_position) > 0.0001
	_last_parent_position = parent_2d.position
	if moved:
		_movement_stable_time = 0.0
		if not _movement_active:
			_begin_glide(false)
			# As with explicit movement starts, frame zero must not inherit
			# the wall time that passed before the start was detected.
			return true
		return false
	if not _movement_active or _movement_feedback_owned:
		return false
	_movement_stable_time += delta
	if _movement_stable_time >= MOVEMENT_SETTLE_SECONDS:
		_movement_active = false
		_movement_stable_time = 0.0
		_hold_idle_pose()
	return false


func _advance_death(delta: float) -> void:
	if _death_finished:
		return
	_death_elapsed += delta
	var duration := sprite_profile.death_duration_seconds if sprite_profile != null else 0.32
	var progress := clampf(_death_elapsed / duration, 0.0, 1.0)
	modulate.a = _death_base_alpha * (1.0 - smoothstep(0.0, 1.0, progress))
	if progress >= 1.0:
		_death_finished = true
		visible = false
		death_animation_finished.emit()


func _on_bound_unit_died(_dead_unit: Unit) -> void:
	play_death()


func _apply_queued_facing() -> void:
	if _queued_facing != "":
		_facing = _queued_facing
		_queued_facing = ""


func _record_parent_position() -> void:
	var parent_2d := get_parent() as Node2D
	if parent_2d != null:
		_last_parent_position = parent_2d.position


func _reset_clock() -> void:
	_last_tick_usec = Time.get_ticks_usec()


func _disconnect_unit() -> void:
	if is_instance_valid(_unit) and _unit.died.is_connected(_on_bound_unit_died):
		_unit.died.disconnect(_on_bound_unit_died)
	_unit = null


func _exit_tree() -> void:
	_closing = true
	cancel_pending_visual_actions()
	_disconnect_unit()
