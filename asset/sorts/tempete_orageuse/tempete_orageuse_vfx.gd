class_name TempeteOrageuseVFX
extends Node2D

signal impact_reached

const CAST_ANIMATION: StringName = &"cast"
const IMPACT_TIME := 0.31
const WATCHDOG_SECONDS := 1.8

@onready var _animation_player: AnimationPlayer = $AnimationPlayer

var _watchdog_elapsed := 0.0
var _impact_emitted := false
var _cancelled := false
var _finished := false


func _ready() -> void:
	_animation_player.animation_finished.connect(_on_animation_finished)
	_animation_player.play(CAST_ANIMATION)


func _process(delta: float) -> void:
	if _finished:
		return

	_watchdog_elapsed += delta
	if (
		not _cancelled
		and not _impact_emitted
		and _animation_player.current_animation == CAST_ANIMATION
		and _animation_player.current_animation_position >= IMPACT_TIME
	):
		_impact_emitted = true
		impact_reached.emit()

	if _watchdog_elapsed >= WATCHDOG_SECONDS:
		_finish()


func cancel() -> void:
	if _finished:
		return

	_cancelled = true
	if is_instance_valid(_animation_player):
		_animation_player.stop()
	_finish()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == CAST_ANIMATION:
		_finish()


func _finish() -> void:
	if _finished:
		return

	_finished = true
	set_process(false)
	if is_inside_tree():
		queue_free()
	else:
		free()
