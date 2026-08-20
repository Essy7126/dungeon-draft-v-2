class_name AchillesNoVisualFallbackBackend
extends Node2D

signal action_started(action_name: StringName)
signal action_release_reached
signal action_finished(action_name: StringName)

const ACTION_FALLBACK := &"ACTION_FALLBACK"
const RELEASE_SECONDS := 0.18
const FINISH_SECONDS := 0.45
const DEFAULT_VFX_ORIGIN := Vector2(0.0, -92.0)

var _active := false
var _shutdown := false
var _action_pending := false
var _release_emitted := false
var _action_elapsed := 0.0


func _ready() -> void:
	# This backend is a gameplay-safety contract, never a presentation layer.
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not _active or not _action_pending or _shutdown:
		return
	_action_elapsed += maxf(delta, 0.0)
	if not _release_emitted and _action_elapsed >= RELEASE_SECONDS:
		_release_emitted = true
		action_release_reached.emit()
	if _action_pending and _action_elapsed >= FINISH_SECONDS:
		_finish_action_once()


func _exit_tree() -> void:
	shutdown()


func set_backend_active(active: bool) -> void:
	if _shutdown:
		return
	if not active:
		cancel_action()
	_active = active
	# Never expose pixels, even while this logical backend is active.
	visible = false


func is_backend_active() -> bool:
	return _active and not _shutdown


func set_facing_label(_direction: String) -> void:
	pass


func play_idle(_direction := "S") -> bool:
	return _active and not _shutdown and not _action_pending


func play_move(_direction := "S") -> bool:
	return _active and not _shutdown and not _action_pending


func play_action(_direction := "S") -> bool:
	if not _active or _shutdown or _action_pending:
		return false
	_action_pending = true
	_release_emitted = false
	_action_elapsed = 0.0
	set_process(true)
	action_started.emit(ACTION_FALLBACK)
	return true


func cancel_action() -> void:
	_action_pending = false
	_release_emitted = false
	_action_elapsed = 0.0
	set_process(false)


func get_vfx_origin() -> Vector2:
	return DEFAULT_VFX_ORIGIN


func shutdown() -> void:
	if _shutdown:
		return
	cancel_action()
	_active = false
	_shutdown = true
	visible = false


func is_shutdown() -> bool:
	return _shutdown


func _finish_action_once() -> void:
	if not _action_pending:
		return
	var needs_release := not _release_emitted
	_release_emitted = true
	_action_pending = false
	_action_elapsed = 0.0
	set_process(false)
	if needs_release:
		action_release_reached.emit()
	action_finished.emit(ACTION_FALLBACK)
