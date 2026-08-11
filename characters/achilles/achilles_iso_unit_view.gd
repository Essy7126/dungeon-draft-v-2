class_name AchillesIsoUnitView
extends Node2D

signal animation_finished(animation_name: StringName)
signal cast_release_reached
signal death_animation_finished

const RELEASE_FRAME := 8
const MOVEMENT_SETTLE_SECONDS := 0.06

@onready var visual: AchillesVisual2D = $AchillesVisual2D
@onready var animated_sprite: AnimatedSprite2D = (
	$AchillesVisual2D/AnimatedSprite2D
)

var _unit: Unit = null
var _facing := "SE"
var _action_pending := false
var _release_emitted := false
var _closing := false
var _generation := 0
var _last_parent_position := Vector2.ZERO
var _movement_active := false
var _movement_stable_time := 0.0
var _death_tween: Tween = null


func _ready() -> void:
	visual.action_finished.connect(_on_visual_action_finished)
	animated_sprite.frame_changed.connect(_on_visual_frame_changed)
	var parent_2d := get_parent() as Node2D
	if parent_2d != null:
		_last_parent_position = parent_2d.position
	play_idle()


func _process(delta: float) -> void:
	if _closing or _action_pending or _death_tween != null:
		return
	var parent_2d := get_parent() as Node2D
	if parent_2d == null:
		return
	var moved := parent_2d.position.distance_squared_to(
		_last_parent_position
	) > 0.0001
	_last_parent_position = parent_2d.position
	if moved:
		_movement_stable_time = 0.0
		if not _movement_active:
			_movement_active = true
			visual.play_walk(_facing)
		return
	if not _movement_active:
		return
	_movement_stable_time += delta
	if _movement_stable_time >= MOVEMENT_SETTLE_SECONDS:
		_movement_active = false
		_movement_stable_time = 0.0
		visual.play_idle(_facing)


func _exit_tree() -> void:
	_closing = true
	cancel_pending_visual_actions()
	_disconnect_unit()


func bind_unit(unit: Unit) -> void:
	_disconnect_unit()
	_unit = unit
	if _unit != null and not _unit.died.is_connected(_on_bound_unit_died):
		_unit.died.connect(_on_bound_unit_died)


func set_facing(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	if abs(direction.x) >= abs(direction.y):
		_facing = "E" if direction.x > 0 else "W"
	else:
		_facing = "S" if direction.y > 0 else "N"
	if not _action_pending and not _movement_active:
		visual.play_idle(_facing)


func play_idle() -> bool:
	if _closing or _action_pending:
		return false
	visual.play_idle(_facing)
	return true


func play_basic_attack() -> bool:
	return _begin_attack_action()


func play_cast() -> bool:
	return _begin_attack_action()


func play_spell_action(_spell: Spell = null) -> bool:
	return _begin_attack_action()


func cancel_spell_action() -> void:
	cancel_pending_visual_actions()


func cancel_pending_visual_actions() -> void:
	_generation += 1
	_action_pending = false
	_release_emitted = false
	_movement_active = false
	_movement_stable_time = 0.0
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = null
	if is_instance_valid(visual) and not _closing:
		visual.play_idle(_facing)


func get_default_cast_effect_origin() -> Vector2:
	if is_instance_valid(visual.vfx_anchor):
		return visual.vfx_anchor.position
	return Vector2(0.0, -92.0)


func _begin_attack_action() -> bool:
	if _closing or _action_pending or not is_instance_valid(visual):
		return false
	_generation += 1
	_action_pending = true
	_release_emitted = false
	_movement_active = false
	visual.play_attack(_facing)
	return true


func _on_visual_frame_changed() -> void:
	if _closing or not _action_pending or _release_emitted:
		return
	if animated_sprite.animation == AchillesVisual2D.ATTACK_ANIMATION \
			and animated_sprite.frame >= RELEASE_FRAME:
		_release_emitted = true
		cast_release_reached.emit()


func _on_visual_action_finished(_animation_name: StringName) -> void:
	if _closing or not _action_pending:
		return
	_action_pending = false
	if not _release_emitted:
		_release_emitted = true
		cast_release_reached.emit()
	animation_finished.emit(&"attack_SE")


func _on_bound_unit_died(_dead_unit: Unit) -> void:
	if _closing or _death_tween != null:
		return
	_generation += 1
	_action_pending = false
	_release_emitted = false
	_movement_active = false
	var death_generation := _generation
	_death_tween = create_tween()
	_death_tween.tween_property(self, "modulate:a", 0.0, 0.28)
	_death_tween.finished.connect(func() -> void:
		_death_tween = null
		if not _closing and death_generation == _generation:
			death_animation_finished.emit()
	, CONNECT_ONE_SHOT)


func _disconnect_unit() -> void:
	if is_instance_valid(_unit) and _unit.died.is_connected(
			_on_bound_unit_died
		):
		_unit.died.disconnect(_on_bound_unit_died)
	_unit = null
