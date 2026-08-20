class_name AchillesLegacy2DBackend
extends Node2D

signal action_started(action_name: StringName)
signal action_release_reached
signal action_finished(action_name: StringName)

const RELEASE_FRAME := 8
const ACTION_FALLBACK := &"ACTION_FALLBACK"

@onready var visual: AchillesVisual2D = $AchillesVisual2D
@onready var animated_sprite: AnimatedSprite2D = (
	$AchillesVisual2D/AnimatedSprite2D
)

var _active := false
var _action_pending := false
var _release_emitted := false


func _ready() -> void:
	visual.action_finished.connect(_on_visual_action_finished)
	animated_sprite.frame_changed.connect(_on_visual_frame_changed)
	_apply_active_state()


func _exit_tree() -> void:
	cancel_action()


func set_backend_active(active: bool) -> void:
	if not active and _action_pending:
		cancel_action()
	_active = active
	visible = active
	process_mode = (
		Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	)
	_apply_active_state()


func is_backend_active() -> bool:
	return _active and visible and is_visible_in_tree() and can_process()


func set_facing_label(direction: String) -> void:
	if _active and not _action_pending:
		visual.play_idle(direction)


func play_idle(direction := "SE") -> bool:
	if not _active or _action_pending:
		return false
	visual.play_idle(direction)
	return true


func play_move(direction := "SE") -> bool:
	if not _active or _action_pending:
		return false
	visual.play_walk(direction)
	return true


func play_action(direction := "SE") -> bool:
	if not _active or _action_pending:
		return false
	_action_pending = true
	_release_emitted = false
	visual.play_attack(direction)
	action_started.emit(ACTION_FALLBACK)
	return true


func cancel_action() -> void:
	_action_pending = false
	_release_emitted = false
	if is_instance_valid(visual) and _active:
		visual.play_idle()


func get_vfx_origin() -> Vector2:
	if is_instance_valid(visual) and is_instance_valid(visual.vfx_anchor):
		return visual.vfx_anchor.position
	return Vector2(0.0, -92.0)


func shutdown() -> void:
	cancel_action()
	_active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(animated_sprite):
		animated_sprite.stop()


func _on_visual_frame_changed() -> void:
	if not _action_pending or _release_emitted:
		return
	if animated_sprite.animation == AchillesVisual2D.ATTACK_ANIMATION \
			and animated_sprite.frame >= RELEASE_FRAME:
		_release_emitted = true
		action_release_reached.emit()


func _on_visual_action_finished(_animation_name: StringName) -> void:
	if not _action_pending:
		return
	_action_pending = false
	if not _release_emitted:
		_release_emitted = true
		action_release_reached.emit()
	action_finished.emit(ACTION_FALLBACK)


func _apply_active_state() -> void:
	if not is_instance_valid(animated_sprite):
		return
	if _active:
		visual.play_idle()
	else:
		animated_sprite.stop()
