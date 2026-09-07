class_name PhilosopherMageIsoUnitView
extends Node2D

signal animation_finished(animation_name: StringName)
signal cast_release_reached
signal death_animation_finished

const DIRECTIONS := ["N", "E", "S", "W"]
const MOVEMENT_SETTLE_SECONDS := 0.06
const SPELL_STEMS := {
	&"philosopher_axiom": "attack", &"philosopher_refutation": "control",
	&"philosopher_mending": "heal", &"philosopher_aporia": "control",
	&"philosopher_aegis": "shield",
}

@export var sprite_profile: PhilosopherSpriteVisualProfile
@export var painted_visual_profile: UnitVisualProfile

## The only visible model. Frames never autoplay on a second engine clock.
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
var _action_duration := 0.0
var _pending_action_id: StringName = &""
var _release_emitted := false
var _generation := 0
var _reaction_pending := false
var _reaction_elapsed := 0.0
var _movement_active := false
var _movement_feedback_owned := false
var _movement_phase := 0.0
var _movement_stable_time := 0.0
var _last_parent_position := Vector2.ZERO
var _last_tick_usec := 0
var _last_error: StringName = &""


func _ready() -> void:
	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	animated_sprite.centered = false
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	animated_sprite.set_process(false)
	add_child(animated_sprite)
	configure_profile(sprite_profile)
	_record_parent_position()
	_reset_clock()
	if is_instance_valid(_unit) and not _unit.is_alive:
		play_death()


## Opt in to consistent painted-map proportions when the room has no override.
func get_painted_visual_profile() -> UnitVisualProfile:
	return painted_visual_profile


func configure_profile(profile: PhilosopherSpriteVisualProfile) -> bool:
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
	animated_sprite.scale = Vector2.ONE * profile.display_scale
	animated_sprite.position = Vector2.ZERO
	animated_sprite.rotation = 0.0
	animated_sprite.flip_h = false
	animated_sprite.flip_v = false
	_hold_idle_pose()
	_reset_clock()
	return true


func bind_unit(unit: Unit) -> void:
	_disconnect_unit()
	_dead = false
	cancel_pending_visual_actions()
	_unit = unit
	_death_finished = false
	_death_elapsed = 0.0
	modulate.a = 1.0
	visible = true
	if is_instance_valid(_unit):
		_unit.died.connect(_on_bound_unit_died)
		EventBus.hit_resolved.connect(_on_hit_resolved)
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


## Disable _process before deterministic sampling in tests and previews.
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
	if _reaction_pending:
		_reaction_elapsed += delta
		_sample_normalized("hit", _reaction_elapsed / sprite_profile.hit_duration_seconds)
		if _reaction_elapsed + 0.0000001 >= sprite_profile.hit_duration_seconds:
			_reaction_pending = false
			_apply_queued_facing()
			_hold_idle_pose()
		return
	_track_parent_movement(delta)


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
	if _action_pending or _reaction_pending:
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
	if not _can_act() or _reaction_pending or (_movement_active and _movement_feedback_owned):
		return false
	_movement_active = false
	_movement_stable_time = 0.0
	_record_parent_position()
	_hold_idle_pose()
	return true


func play_walk() -> bool:
	if not _can_act():
		return false
	_begin_walk(true)
	return true


func play_run() -> bool:
	return play_walk()


func begin_movement_feedback(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if not _can_act() or from_cell == to_cell:
		return
	_reaction_pending = false
	_apply_queued_facing()
	set_facing(to_cell - from_cell)
	_begin_walk(true)


func begin_path_movement_feedback(path: Array) -> void:
	if path.size() < 2 or not path[0] is Vector2i or not path[1] is Vector2i:
		return
	begin_movement_feedback(path[0] as Vector2i, path[1] as Vector2i)


func get_movement_segment_duration(_path: Array) -> float:
	return sprite_profile.movement_segment_duration_seconds if sprite_profile != null else 0.30


func update_movement_stride(step_index: int, progress: float) -> void:
	if not _can_act() or not _movement_active:
		return
	# One half stride per grid segment. Sampling a normalized cycle keeps odd
	# authored frame counts continuous at cell boundaries and direction changes.
	_movement_phase = fposmod((float(step_index) + clampf(progress, 0.0, 1.0)) * 0.5, 1.0)
	_sample_walk()


func cancel_movement_feedback() -> void:
	synchronize_external_movement()


func end_movement_feedback() -> void:
	cancel_movement_feedback()


func synchronize_external_movement() -> void:
	_record_parent_position()
	_movement_active = false
	_movement_feedback_owned = false
	_movement_stable_time = 0.0
	if _can_act() and not _reaction_pending:
		_hold_idle_pose()


func play_basic_attack() -> bool:
	return _begin_action(&"attack", "attack")


func play_cast() -> bool:
	return _begin_action(&"cast", "attack")


func play_spell_action(spell: Spell = null) -> bool:
	var action_id := &"cast"
	if spell != null:
		action_id = StringName("cast:" + String(spell.get_effective_spell_id()))
	return _begin_action(action_id, get_spell_animation_stem(spell))


func get_spell_animation_stem(spell: Spell) -> String:
	if spell == null:
		return "attack"
	var id := spell.get_effective_spell_id()
	if SPELL_STEMS.has(id):
		return String(SPELL_STEMS[id])
	if spell.heal > 0:
		return "heal"
	if spell.shield_grant > 0 or spell.shield_scaling != null:
		return "shield"
	if spell.applied_status != null or spell.push_distance > 0 or spell.pull_distance > 0 or spell.ap_drain > 0:
		return "control"
	return "attack"


func play_hit() -> bool:
	if not _can_act() or _movement_active or _reaction_pending:
		return false
	_reaction_pending = true
	_reaction_elapsed = 0.0
	_stem = "hit"
	_sample_normalized("hit", 0.0)
	_reset_clock()
	return true


func cancel_spell_action() -> void:
	cancel_pending_visual_actions()


func cancel_pending_visual_actions() -> void:
	# UnitView cancels a committed action after the death signal. Preserve the
	# already running death clip so its one completion can remove the unit view.
	if _dead and not _closing:
		return
	_generation += 1
	_action_pending = false
	_action_elapsed = 0.0
	_pending_action_id = &""
	_release_emitted = false
	_reaction_pending = false
	_reaction_elapsed = 0.0
	_movement_active = false
	_movement_feedback_owned = false
	_movement_phase = 0.0
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
	_stem = "death"
	if _configured:
		_sample_normalized("death", 0.0)
	_reset_clock()
	return true


func get_default_cast_effect_origin() -> Vector2:
	return sprite_profile.cast_origins.get(_facing, Vector2(0.0, -50.0)) \
		if sprite_profile != null else Vector2(0.0, -50.0)


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
		"action_duration": _action_duration, "duration_seconds": _action_duration,
		"release_seconds": _release_seconds(), "release_emitted": _release_emitted,
		"action_id": String(_pending_action_id),
		"reaction_pending": _reaction_pending, "reaction_elapsed": _reaction_elapsed,
		"movement_active": _movement_active, "movement_phase": _movement_phase,
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


func _begin_action(action_id: StringName, stem: String) -> bool:
	if not _can_act():
		return false
	_reaction_pending = false
	_apply_queued_facing()
	_generation += 1
	_action_pending = true
	_action_elapsed = 0.0
	_action_duration = sprite_profile.duration_for(stem)
	_pending_action_id = action_id
	_release_emitted = false
	_movement_active = false
	_movement_feedback_owned = false
	_stem = stem
	_sample_normalized(_stem, 0.0)
	_reset_clock()
	return true


func _advance_action(delta: float) -> void:
	var generation := _generation
	var target_elapsed := _action_elapsed + delta
	var release_time := _release_seconds()
	if not _release_emitted and target_elapsed + 0.0000001 >= release_time:
		# Always display the release pose when notifying gameplay, even if a
		# slow frame crosses anticipation, impact and recovery at once.
		_action_elapsed = release_time
		_sample_normalized(_stem, _action_elapsed / _action_duration)
		_release_emitted = true
		cast_release_reached.emit()
	if generation != _generation or not _action_pending or _dead or _closing:
		return
	_action_elapsed = target_elapsed
	_sample_normalized(_stem, _action_elapsed / _action_duration)
	if _action_elapsed + 0.0000001 >= _action_duration:
		var completed := _pending_action_id
		_action_pending = false
		_pending_action_id = &""
		_apply_queued_facing()
		_record_parent_position()
		_hold_idle_pose()
		animation_finished.emit(completed)


func _release_seconds() -> float:
	return _action_duration * sprite_profile.release_ratio if sprite_profile != null else 0.0


func _begin_walk(owned: bool) -> void:
	_reaction_pending = false
	if not _movement_active:
		_movement_phase = 0.0
		_reset_clock()
	_movement_active = true
	_movement_feedback_owned = owned
	_movement_stable_time = 0.0
	_stem = "walk"
	_record_parent_position()
	_sample_walk()


func _sample_walk() -> void:
	_sample_normalized("walk", _movement_phase)


func _sample_normalized(stem: String, normalized: float) -> void:
	var clip := StringName(stem + "_" + _facing)
	_sample_weighted_clip(clip, clampf(normalized, 0.0, 1.0) * _clip_weight(clip))


func _sample_weighted_clip(clip: StringName, phase: float) -> void:
	var count := _frames.get_frame_count(clip)
	var remaining := phase
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


func _hold_idle_pose() -> void:
	if not _configured or not is_instance_valid(animated_sprite):
		return
	_stem = "idle"
	var clip := StringName("idle_" + _facing)
	if animated_sprite.animation != clip:
		animated_sprite.animation = clip
	animated_sprite.pause()
	animated_sprite.set_frame_and_progress(0, 0.0)


func _track_parent_movement(delta: float) -> void:
	var parent_2d := get_parent() as Node2D
	if parent_2d == null:
		return
	var distance := parent_2d.position.distance_to(_last_parent_position)
	_last_parent_position = parent_2d.position
	if distance > 0.01:
		_movement_stable_time = 0.0
		if not _movement_active:
			_begin_walk(false)
		if not _movement_feedback_owned:
			# Preview/external movement fallback uses distance, never elapsed time.
			_movement_phase = fposmod(_movement_phase + distance / 128.0, 1.0)
			_sample_walk()
		return
	if not _movement_active or _movement_feedback_owned:
		return
	_movement_stable_time += delta
	if _movement_stable_time >= MOVEMENT_SETTLE_SECONDS:
		_movement_active = false
		_movement_stable_time = 0.0
		_hold_idle_pose()


func _advance_death(delta: float) -> void:
	if _death_finished:
		return
	_death_elapsed += delta
	var duration := sprite_profile.death_duration_seconds if sprite_profile != null else 0.52
	var fade := sprite_profile.death_fade_seconds if sprite_profile != null else 0.12
	if _configured:
		_sample_normalized("death", _death_elapsed / duration)
	var progress := clampf((_death_elapsed - duration) / fade, 0.0, 1.0)
	modulate.a = _death_base_alpha * (1.0 - smoothstep(0.0, 1.0, progress))
	if progress >= 1.0:
		_death_finished = true
		visible = false
		death_animation_finished.emit()


func _on_bound_unit_died(_dead_unit: Unit) -> void:
	play_death()


func _on_hit_resolved(fact: CombatEventFact) -> void:
	if fact == null or fact.target != _unit or fact.amount_resolved <= 0 \
			or not is_instance_valid(_unit) or not _unit.is_alive:
		return
	play_hit()


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
	if EventBus.hit_resolved.is_connected(_on_hit_resolved):
		EventBus.hit_resolved.disconnect(_on_hit_resolved)
	_unit = null


func _exit_tree() -> void:
	_closing = true
	cancel_pending_visual_actions()
	_disconnect_unit()
