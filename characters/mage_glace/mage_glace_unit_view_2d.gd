class_name MageGlaceUnitView2D
extends Node2D

signal animation_started(animation_name: StringName)
signal animation_finished(animation_name: StringName)
signal cast_release_reached
signal hit_reaction_finished
signal death_animation_finished

const ACTION_IDLE := &"idle"
const ACTION_WALK := &"walk"
const ACTION_RUN := &"run"
const ACTION_CAST := &"cast"
const ACTION_HIT := &"hit"
const ACTION_DEATH := &"death"
const CAST_RELEASE_FRAME := 3
const GRID_FOOTPRINT := Vector2(64.0, 32.0)
const MOVE_SEGMENT_DURATION := 0.15

enum VisualPriority {
	IDLE,
	MOVEMENT,
	CAST,
	HIT,
	DEATH,
}

@export_range(0.25, 3.0, 0.01) var walk_animation_speed_multiplier := 1.0
@export_range(0.25, 3.0, 0.01) var run_animation_speed_multiplier := 1.0

@onready var shadow: Polygon2D = $Shadow
@onready var sprite_root: Node2D = $SpriteRoot
@onready var animated_sprite: AnimatedSprite2D = $SpriteRoot/AnimatedSprite2D
@onready var left_hand_effect_origin: Node2D = $LeftHandEffectOrigin
@onready var right_hand_effect_origin: Node2D = $RightHandEffectOrigin
@onready var default_cast_effect_origin: Node2D = $DefaultCastEffectOrigin

var _unit: Unit = null
var _current_action := ACTION_IDLE
var _priority := VisualPriority.IDLE
var _facing := Vector2i.RIGHT
var _death_locked := false
var _cast_release_emitted := false
var _hit_finished_emitted := false
var _death_finished_emitted := false
var _movement_active := false
var _movement_seen_motion := false
var _movement_stable_time := 0.0
var _last_parent_position := Vector2.ZERO
var _has_parent_sample := false
var _debug_run_for_next_movement := false
var _polish_tween: Tween = null


func _ready() -> void:
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_finished.connect(_on_sprite_animation_finished)
	set_process(true)
	reset_to_idle()


func _process(delta: float) -> void:
	_track_parent_movement(delta)


func _exit_tree() -> void:
	_cast_release_emitted = true
	set_process(false)
	_disconnect_bound_unit()
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
	_cancel_polish()


func bind_unit(unit: Unit) -> void:
	if _unit == unit:
		return
	_disconnect_bound_unit()
	_unit = unit
	if _unit == null:
		return
	_unit.moved.connect(_on_bound_unit_moved)
	_unit.died.connect(_on_bound_unit_died)
	if not EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.connect(_on_damage_dealt)


func _disconnect_bound_unit() -> void:
	if is_instance_valid(_unit):
		var moved_callable := Callable(self, "_on_bound_unit_moved")
		var died_callable := Callable(self, "_on_bound_unit_died")
		if _unit.moved.is_connected(moved_callable):
			_unit.moved.disconnect(moved_callable)
		if _unit.died.is_connected(died_callable):
			_unit.died.disconnect(died_callable)
	_unit = null


func play_idle() -> bool:
	if _death_locked or _priority > VisualPriority.IDLE:
		return false
	return _start_action(ACTION_IDLE, VisualPriority.IDLE)


func play_walk(speed_scale: float = 1.0) -> bool:
	if _death_locked or _priority > VisualPriority.MOVEMENT:
		return false
	return _start_action(
		ACTION_WALK,
		VisualPriority.MOVEMENT,
		maxf(speed_scale, 0.01) * walk_animation_speed_multiplier
	)


func play_run(speed_scale: float = 1.0) -> bool:
	if _death_locked or _priority > VisualPriority.MOVEMENT:
		return false
	return _start_action(
		ACTION_RUN,
		VisualPriority.MOVEMENT,
		maxf(speed_scale, 0.01) * run_animation_speed_multiplier
	)


func play_cast() -> bool:
	if _death_locked or _priority > VisualPriority.CAST:
		return false
	return _start_action(ACTION_CAST, VisualPriority.CAST)


func play_spell_action(_spell: Spell = null) -> bool:
	return play_cast()


func cancel_spell_action() -> void:
	if _current_action != ACTION_CAST or _death_locked:
		return
	_cast_release_emitted = true
	_priority = VisualPriority.IDLE
	_start_action(ACTION_IDLE, VisualPriority.IDLE, 1.0, true)


func play_hit() -> bool:
	if _death_locked or _priority > VisualPriority.HIT:
		return false
	return _start_action(ACTION_HIT, VisualPriority.HIT)


func play_death() -> bool:
	if _death_locked:
		return false
	_death_locked = true
	_movement_active = false
	return _start_action(ACTION_DEATH, VisualPriority.DEATH)


func stop_animation() -> void:
	animated_sprite.pause()


func reset_to_idle() -> void:
	if _death_locked:
		return
	_priority = VisualPriority.IDLE
	_start_action(ACTION_IDLE, VisualPriority.IDLE, 1.0, true)


func get_current_animation() -> StringName:
	return animated_sprite.animation


func is_animation_playing(animation_name: StringName = &"") -> bool:
	if not animated_sprite.is_playing():
		return false
	return animation_name == &"" or animated_sprite.animation == animation_name


func get_animation_name_for_action(action: StringName) -> StringName:
	return action if animated_sprite.sprite_frames.has_animation(action) else &""


func get_animation_length_for_action(action: StringName) -> float:
	var frames := animated_sprite.sprite_frames
	if not frames.has_animation(action):
		return 0.0
	var duration := 0.0
	for index in frames.get_frame_count(action):
		duration += frames.get_frame_duration(action, index)
	return duration / maxf(frames.get_animation_speed(action), 0.001)


func get_logical_foot_position() -> Vector2:
	return Vector2.ZERO


func get_left_hand_effect_origin() -> Vector2:
	return left_hand_effect_origin.position


func get_right_hand_effect_origin() -> Vector2:
	return right_hand_effect_origin.position


func get_default_cast_effect_origin() -> Vector2:
	return default_cast_effect_origin.position


func get_popup_anchor() -> Vector2:
	return Vector2(0.0, -80.0)


func get_facing_direction() -> Vector2i:
	return _facing


func get_sprite() -> AnimatedSprite2D:
	return animated_sprite


func set_facing(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	var cardinal := (
		Vector2i(signi(direction.x), 0)
		if absi(direction.x) >= absi(direction.y)
		else Vector2i(0, signi(direction.y))
	)
	if cardinal.x != 0:
		_facing = cardinal
		animated_sprite.flip_h = cardinal == Vector2i.LEFT
	elif _facing.x == 0:
		# Les planches animees ne possedent pas de dos. Une direction verticale
		# au spawn conserve donc naturellement la vue trois-quarts vers la droite.
		_facing = Vector2i.RIGHT


func set_debug_run_for_next_movement(enabled: bool) -> void:
	_debug_run_for_next_movement = enabled


func cancel_movement_feedback() -> void:
	_movement_active = false
	_movement_seen_motion = false
	_movement_stable_time = 0.0
	_has_parent_sample = false
	if not _death_locked and _priority == VisualPriority.MOVEMENT:
		_priority = VisualPriority.IDLE
		_start_action(ACTION_IDLE, VisualPriority.IDLE, 1.0, true)


func _start_action(
	action: StringName,
	priority: VisualPriority,
	speed_scale: float = 1.0,
	force_restart: bool = false
	) -> bool:
	if not animated_sprite.sprite_frames.has_animation(action):
		return false
	if not force_restart and animated_sprite.animation == action \
			and animated_sprite.is_playing():
		return false
	if action != ACTION_CAST:
		_cast_release_emitted = true
	else:
		_cast_release_emitted = false
	_hit_finished_emitted = false if action == ACTION_HIT else _hit_finished_emitted
	_death_finished_emitted = false if action == ACTION_DEATH else _death_finished_emitted
	_cancel_polish()
	sprite_root.position = Vector2.ZERO
	sprite_root.scale = Vector2.ONE
	animated_sprite.modulate = Color.WHITE
	_current_action = action
	_priority = priority
	animated_sprite.speed_scale = maxf(speed_scale, 0.01)
	animated_sprite.play(action)
	animation_started.emit(action)
	if action == ACTION_HIT:
		_play_hit_polish()
	return true


func _on_frame_changed() -> void:
	if _current_action != ACTION_CAST \
			or animated_sprite.frame != CAST_RELEASE_FRAME \
			or _cast_release_emitted:
		return
	_cast_release_emitted = true
	cast_release_reached.emit()
	_play_cast_release_polish()


func _on_sprite_animation_finished() -> void:
	var completed := _current_action
	animation_finished.emit(completed)
	match completed:
		ACTION_CAST:
			if not _cast_release_emitted:
				_cast_release_emitted = true
				cast_release_reached.emit()
			_priority = VisualPriority.IDLE
			_start_action(ACTION_IDLE, VisualPriority.IDLE, 1.0, true)
		ACTION_HIT:
			if not _hit_finished_emitted:
				_hit_finished_emitted = true
				hit_reaction_finished.emit()
			if not _death_locked and (_unit == null or _unit.is_alive):
				_priority = VisualPriority.IDLE
				_start_action(ACTION_IDLE, VisualPriority.IDLE, 1.0, true)
		ACTION_DEATH:
			animated_sprite.pause()
			animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count(
				ACTION_DEATH
			) - 1
			if not _death_finished_emitted:
				_death_finished_emitted = true
				death_animation_finished.emit()


func _play_hit_polish() -> void:
	var recoil := 4.0 if animated_sprite.flip_h else -4.0
	animated_sprite.modulate = Color(1.0, 0.58, 0.62, 1.0)
	_polish_tween = create_tween()
	_polish_tween.tween_property(sprite_root, "position:x", recoil, 0.055)
	_polish_tween.parallel().tween_property(
		animated_sprite, "modulate", Color.WHITE, 0.14
	)
	_polish_tween.tween_property(sprite_root, "position:x", 0.0, 0.08)


func _play_cast_release_polish() -> void:
	_cancel_polish()
	_polish_tween = create_tween()
	_polish_tween.tween_property(
		sprite_root, "scale", Vector2(1.035, 1.035), 0.045
	)
	_polish_tween.tween_property(sprite_root, "scale", Vector2.ONE, 0.09)


func _cancel_polish() -> void:
	if _polish_tween != null and _polish_tween.is_valid():
		_polish_tween.kill()
	_polish_tween = null


func _on_bound_unit_moved(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if _death_locked:
		return
	set_facing(to_cell - from_cell)
	_movement_active = true
	_movement_seen_motion = false
	_movement_stable_time = 0.0
	_has_parent_sample = false
	var distance_cells := (
		absi(to_cell.x - from_cell.x) + absi(to_cell.y - from_cell.y)
	)
	var action := ACTION_RUN if _debug_run_for_next_movement else ACTION_WALK
	var playback_speed := _movement_playback_speed(
		get_animation_length_for_action(action),
		distance_cells
	)
	if _debug_run_for_next_movement:
		play_run(playback_speed)
	else:
		play_walk(playback_speed)


func _movement_playback_speed(loop_duration: float, distance_cells: int) -> float:
	if loop_duration <= 0.0:
		return 1.0
	var travelled_distance := (
		maxf(float(distance_cells), 1.0) * GRID_FOOTPRINT.length() * 0.5
	)
	var one_cell_distance := GRID_FOOTPRINT.length() * 0.5
	var visual_cycles := travelled_distance / one_cell_distance
	var gameplay_duration := maxf(float(distance_cells), 1.0) * MOVE_SEGMENT_DURATION
	return loop_duration * visual_cycles / gameplay_duration


func _track_parent_movement(delta: float) -> void:
	var parent_2d := get_parent() as Node2D
	if parent_2d == null:
		return
	var current := parent_2d.position
	if not _has_parent_sample:
		_last_parent_position = current
		_has_parent_sample = true
		return
	var screen_delta := current - _last_parent_position
	_last_parent_position = current
	if not _movement_active:
		return
	if screen_delta.length_squared() > 0.0001:
		_movement_seen_motion = true
		_movement_stable_time = 0.0
		return
	if not _movement_seen_motion:
		return
	_movement_stable_time += delta
	if _movement_stable_time >= 0.06:
		_movement_active = false
		_movement_seen_motion = false
		if _priority == VisualPriority.MOVEMENT:
			_priority = VisualPriority.IDLE
			_start_action(ACTION_IDLE, VisualPriority.IDLE, 1.0, true)


func _on_bound_unit_died(unit: Unit) -> void:
	if unit == _unit:
		play_death()


func _on_damage_dealt(
	target,
	_attacker,
	amount: int,
	_category: int,
	_element: int,
	_is_crit: bool
	) -> void:
	if target == _unit and amount > 0 and _unit != null and _unit.is_alive:
		play_hit()
