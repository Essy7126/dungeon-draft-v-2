class_name AchillesVisual2D
extends Node2D

signal action_started(animation_name: StringName)
signal action_finished(animation_name: StringName)

const SUPPORTED_DIRECTION := "SE"
const IDLE_ANIMATION := &"idle_SE"
const WALK_ANIMATION := &"walk_SE"
const ATTACK_ANIMATION := &"attack_SE"

@export_range(0.5, 2.0, 0.05) var visual_scale := 1.0:
	set(value):
		visual_scale = value
		_apply_visual_scale()

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var foot_anchor: Node2D = $FootAnchor
@onready var vfx_anchor: Node2D = $VFXAnchor

var _action_playing := false
var _warned_directions := {}


func _ready() -> void:
	_apply_visual_scale()
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	play_idle()


func play_idle(direction := SUPPORTED_DIRECTION) -> void:
	_action_playing = false
	animated_sprite.play(_animation_for(&"idle", direction))


func play_walk(direction := SUPPORTED_DIRECTION) -> void:
	if _action_playing:
		return
	animated_sprite.play(_animation_for(&"walk", direction))


func play_attack(direction := SUPPORTED_DIRECTION) -> void:
	if _action_playing:
		return
	_action_playing = true
	var animation_name := _animation_for(&"attack", direction)
	animated_sprite.play(animation_name)
	action_started.emit(animation_name)


func is_action_playing() -> bool:
	return _action_playing


func _animation_for(prefix: StringName, direction) -> StringName:
	var requested := String(direction).to_upper()
	if requested != SUPPORTED_DIRECTION and not _warned_directions.has(requested):
		_warned_directions[requested] = true
		push_warning(
			"AchillesVisual2D: direction '%s' unavailable in this POC; explicit fallback to SE."
			% requested
		)
	return StringName("%s_%s" % [prefix, SUPPORTED_DIRECTION])


func _on_animation_finished() -> void:
	if animated_sprite.animation != ATTACK_ANIMATION:
		return
	_action_playing = false
	animated_sprite.play(IDLE_ANIMATION)
	action_finished.emit(ATTACK_ANIMATION)


func _apply_visual_scale() -> void:
	if is_instance_valid(animated_sprite):
		animated_sprite.scale = Vector2.ONE * visual_scale
