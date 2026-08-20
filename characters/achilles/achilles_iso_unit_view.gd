class_name AchillesIsoUnitView
extends Node2D

signal animation_finished(animation_name: StringName)
signal cast_release_reached
signal death_animation_finished

const MOVEMENT_SETTLE_SECONDS := 0.06
const ACTION_TIMEOUT_SECONDS := 2.0
const ACTION_FALLBACK := &"ACTION_FALLBACK"
const DEFAULT_FALLBACK_BACKEND_SCENE := preload(
	"res://characters/achilles/3d/AchillesNoVisualFallbackBackend.tscn"
)
const FALLBACK_BACKEND_SCRIPT := preload(
	"res://characters/achilles/3d/achilles_no_visual_fallback_backend.gd"
)

@export var visual_profile: AchillesVisualProfile

@onready var viewport_backend: AchillesViewport3DBackend = $Viewport3DBackend
var fallback_backend = null

var _active_backend: Node2D = null
var _unit: Unit = null
var _facing := "SE"
var _action_pending := false
var _action_elapsed := 0.0
var _release_emitted := false
var _closing := false
var _generation := 0
var _last_parent_position := Vector2.ZERO
var _movement_active := false
var _movement_stable_time := 0.0
var _viewport_activation_deferred := false
var _death_tween: Tween = null
var _last_backend_error: Dictionary = {}


func _ready() -> void:
	fallback_backend = _create_fallback_backend()
	_connect_backend_signals(fallback_backend)
	_connect_backend_signals(viewport_backend)
	viewport_backend.backend_ready.connect(_on_viewport_backend_ready)
	viewport_backend.backend_failed.connect(_on_viewport_backend_failed)
	_activate_safe_fallback()
	var parent_2d := get_parent() as Node2D
	if parent_2d != null:
		_last_parent_position = parent_2d.position
	call_deferred("_initialize_selected_backend")


func _process(delta: float) -> void:
	if _closing or _death_tween != null:
		return
	if _action_pending:
		_action_elapsed += maxf(delta, 0.0)
		if _action_elapsed >= ACTION_TIMEOUT_SECONDS:
			_complete_action_once(ACTION_FALLBACK)
		return
	_track_parent_movement(delta)


func _exit_tree() -> void:
	_closing = true
	cancel_pending_visual_actions()
	_disconnect_unit()
	if is_instance_valid(viewport_backend):
		viewport_backend.shutdown()
	if is_instance_valid(fallback_backend):
		fallback_backend.shutdown()


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
	if is_instance_valid(_active_backend) \
			and _active_backend.has_method("set_facing_label"):
		_active_backend.set_facing_label(_facing)


func play_idle() -> bool:
	if _closing or _action_pending or not is_instance_valid(_active_backend):
		return false
	return bool(_active_backend.play_idle(_facing))


func play_basic_attack() -> bool:
	return _begin_action()


func play_cast() -> bool:
	return _begin_action()


func play_spell_action(_spell: Spell = null) -> bool:
	return _begin_action()


func cancel_spell_action() -> void:
	cancel_pending_visual_actions()


func cancel_pending_visual_actions() -> void:
	_generation += 1
	_action_pending = false
	_action_elapsed = 0.0
	_release_emitted = false
	_movement_active = false
	_movement_stable_time = 0.0
	if is_instance_valid(viewport_backend):
		viewport_backend.cancel_action()
	if is_instance_valid(fallback_backend):
		fallback_backend.cancel_action()
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = null
	if is_instance_valid(_active_backend) and not _closing:
		_active_backend.play_idle(_facing)
	_activate_deferred_viewport_if_available()


func begin_movement_feedback(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if _closing or _action_pending or from_cell == to_cell:
		return
	set_facing(to_cell - from_cell)
	_movement_active = true
	_movement_stable_time = 0.0
	var parent_2d := get_parent() as Node2D
	if parent_2d != null:
		_last_parent_position = parent_2d.position
	if is_instance_valid(_active_backend):
		_active_backend.play_move(_facing)


func cancel_movement_feedback() -> void:
	_movement_active = false
	_movement_stable_time = 0.0
	if not _closing and not _action_pending:
		play_idle()
	_activate_deferred_viewport_if_available()


func get_default_cast_effect_origin() -> Vector2:
	# Preserve the established gameplay/VFX contract without loading the
	# retired 2D scene. The 3D marker remains presentation-only metadata.
	return Vector2(0.0, -92.0)


func force_safe_fallback(reason: StringName = &"MANUAL_FALLBACK") -> void:
	var replay_action := _action_pending and _active_backend == viewport_backend
	if reason != &"":
		_record_backend_error(reason)
	if replay_action and is_instance_valid(viewport_backend):
		viewport_backend.cancel_action()
	_activate_safe_fallback()
	if replay_action and not fallback_backend.play_action(_facing):
		_complete_action_once(ACTION_FALLBACK)


func request_subviewport_backend(
		profile_override: AchillesVisualProfile = null
	) -> bool:
	var selected_profile := (
		profile_override if profile_override != null else visual_profile
	)
	if selected_profile == null or not selected_profile.is_character_only_valid():
		force_safe_fallback(&"INVALID_CHARACTER_ONLY_PROFILE")
		return false
	if viewport_backend.is_shutdown():
		force_safe_fallback(&"SUBVIEWPORT_BACKEND_ALREADY_RELEASED")
		return false
	if viewport_backend.is_ready_for_render():
		if _action_pending or _movement_active:
			_viewport_activation_deferred = true
		else:
			_activate_viewport_backend()
		return true
	return viewport_backend.configure(selected_profile)


func get_active_backend_name() -> StringName:
	if _active_backend == viewport_backend:
		return &"Viewport3DBackend"
	return &"NoVisualFallbackBackend"


func get_last_backend_error() -> Dictionary:
	return _last_backend_error.duplicate(true)


func _initialize_selected_backend() -> void:
	if _closing or visual_profile == null:
		return
	request_subviewport_backend()


func _begin_action() -> bool:
	if _closing or _action_pending or not is_instance_valid(_active_backend):
		return false
	_generation += 1
	_action_pending = true
	_action_elapsed = 0.0
	_release_emitted = false
	_movement_active = false
	var started := bool(_active_backend.play_action(_facing))
	if started:
		return true
	_action_pending = false
	if _active_backend != fallback_backend:
		force_safe_fallback(&"SUBVIEWPORT_ACTION_START_FAILED")
		_action_pending = true
		started = bool(fallback_backend.play_action(_facing))
	if not started:
		_action_pending = false
	return started


func _connect_backend_signals(backend: Node) -> void:
	backend.action_release_reached.connect(_on_backend_action_release)
	backend.action_finished.connect(_on_backend_action_finished)


func _on_backend_action_release() -> void:
	if _closing or not _action_pending or _release_emitted:
		return
	_release_emitted = true
	cast_release_reached.emit()


func _on_backend_action_finished(action_name: StringName) -> void:
	_complete_action_once(action_name)


func _complete_action_once(action_name: StringName) -> void:
	if _closing or not _action_pending:
		return
	if not _release_emitted:
		_release_emitted = true
		cast_release_reached.emit()
	_action_pending = false
	_action_elapsed = 0.0
	if is_instance_valid(_active_backend):
		_active_backend.play_idle(_facing)
	_activate_deferred_viewport_if_available()
	animation_finished.emit(action_name)


func _on_viewport_backend_ready() -> void:
	if _closing:
		return
	if _action_pending or _movement_active:
		_viewport_activation_deferred = true
		return
	_activate_viewport_backend()


func _on_viewport_backend_failed(error_code: StringName) -> void:
	if _closing:
		return
	force_safe_fallback(error_code)


func _activate_safe_fallback() -> void:
	_viewport_activation_deferred = false
	if is_instance_valid(viewport_backend):
		viewport_backend.set_backend_active(false)
	if is_instance_valid(fallback_backend):
		if _active_backend != fallback_backend:
			fallback_backend.set_backend_active(false)
		fallback_backend.set_backend_active(true)
	_active_backend = fallback_backend
	if is_instance_valid(fallback_backend):
		fallback_backend.set_facing_label(_facing)


func _activate_viewport_backend() -> void:
	if not is_instance_valid(viewport_backend) \
			or not viewport_backend.is_ready_for_render():
		return
	fallback_backend.set_backend_active(false)
	viewport_backend.set_backend_active(false)
	viewport_backend.set_backend_active(true)
	_active_backend = viewport_backend
	viewport_backend.set_facing_label(_facing)
	_viewport_activation_deferred = false


func _activate_deferred_viewport_if_available() -> void:
	if not _viewport_activation_deferred or _closing \
			or _action_pending or _movement_active:
		return
	if not is_instance_valid(viewport_backend) \
			or not viewport_backend.is_ready_for_render():
		_viewport_activation_deferred = false
		return
	_activate_viewport_backend()


func _record_backend_error(error_code: StringName) -> void:
	_last_backend_error = {
		"event": "ACHILLES_VISUAL_BACKEND_FALLBACK",
		"error_code": String(error_code),
		"fallback": "NO_VISUAL_ACTION_CONTRACT",
		"legacy_2d_loaded": false,
		"equipment_enabled": false,
	}
	printerr(JSON.stringify(_last_backend_error))


func _track_parent_movement(delta: float) -> void:
	var parent_2d := get_parent() as Node2D
	if parent_2d == null or not is_instance_valid(_active_backend):
		return
	var moved := parent_2d.position.distance_squared_to(
		_last_parent_position
	) > 0.0001
	_last_parent_position = parent_2d.position
	if moved:
		_movement_stable_time = 0.0
		if not _movement_active:
			_movement_active = true
			_active_backend.play_move(_facing)
		return
	if not _movement_active:
		return
	_movement_stable_time += delta
	if _movement_stable_time >= MOVEMENT_SETTLE_SECONDS:
		_movement_active = false
		_movement_stable_time = 0.0
		_active_backend.play_idle(_facing)
		_activate_deferred_viewport_if_available()


func _on_bound_unit_died(_dead_unit: Unit) -> void:
	if _closing or _death_tween != null:
		return
	_generation += 1
	_action_pending = false
	_release_emitted = false
	_movement_active = false
	viewport_backend.cancel_action()
	fallback_backend.cancel_action()
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


func _create_fallback_backend():
	var scene := DEFAULT_FALLBACK_BACKEND_SCENE
	if visual_profile != null and visual_profile.fallback_backend_scene != null:
		scene = visual_profile.fallback_backend_scene
	var candidate := scene.instantiate()
	if candidate == null or candidate.get_script() != FALLBACK_BACKEND_SCRIPT:
		if candidate != null:
			candidate.free()
		candidate = DEFAULT_FALLBACK_BACKEND_SCENE.instantiate()
	var backend := candidate as Node2D
	backend.name = "NoVisualFallbackBackend"
	add_child(backend)
	move_child(backend, 0)
	return backend
