class_name AchillesIsoUnitView
extends Node2D

signal animation_finished(animation_name: StringName)
signal cast_release_reached
signal death_animation_finished

const MOVEMENT_SETTLE_SECONDS := 0.06
const ACTION_TIMEOUT_SECONDS := 2.0
const ACTION_FALLBACK := &"ACTION_FALLBACK"
const REQUESTED_BACKEND := &"VIEWPORT_3D"
const MovementTiming = preload("res://characters/character_movement_timing.gd")
const DEFAULT_FALLBACK_BACKEND_SCENE := preload(
	"res://characters/achilles/3d/AchillesLegacy2DBackend.tscn"
)
const FALLBACK_BACKEND_SCRIPT := preload(
	"res://characters/achilles/3d/achilles_legacy_2d_backend.gd"
)

@export var visual_profile: AchillesVisualProfile

@onready var viewport_backend: AchillesViewport3DBackend = $Viewport3DBackend
var fallback_backend = null

var _active_backend: Node2D = null
var _unit: Unit = null
var _animation_set: CharacterAnimationSetData = null
var _facing := "SE"
var _action_pending := false
var _action_elapsed := 0.0
var _action_timeout_seconds := ACTION_TIMEOUT_SECONDS
var _pending_action_id: StringName = ACTION_FALLBACK
var _pending_action_clip: StringName = &""
var _release_emitted := false
var _closing := false
var _generation := 0
var _last_parent_position := Vector2.ZERO
var _movement_active := false
var _movement_action_id: StringName = &"walk"
var _movement_stable_time := 0.0
var _viewport_activation_deferred := false
var _queued_action_for_backend := false
var _death_tween: Tween = null
var _last_backend_error: Dictionary = {}
var _selected_profile: AchillesVisualProfile = null
var _runtime_diagnostics_enabled := false
var _runtime_room_id := ""
var _runtime_commit := ""


func _ready() -> void:
	_connect_backend_signals(viewport_backend)
	viewport_backend.backend_ready.connect(_on_viewport_backend_ready)
	viewport_backend.backend_failed.connect(_on_viewport_backend_failed)
	viewport_backend.set_backend_active(false)
	var parent_2d := get_parent() as Node2D
	if parent_2d != null:
		_last_parent_position = parent_2d.position
	call_deferred("_initialize_selected_backend")


func _process(delta: float) -> void:
	if _closing or _death_tween != null:
		return
	if _action_pending:
		_action_elapsed += maxf(delta, 0.0)
		if _action_elapsed >= _action_timeout_seconds:
			if _queued_action_for_backend:
				force_safe_fallback(&"SUBVIEWPORT_WARMUP_TIMEOUT")
			else:
				if is_instance_valid(_active_backend):
					_active_backend.cancel_action()
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
	_animation_set = (
		_unit.character_data.animation_set
		if _unit != null and _unit.character_data != null else null
	)
	if _unit != null and not _unit.died.is_connected(_on_bound_unit_died):
		_unit.died.connect(_on_bound_unit_died)
	if _unit != null and not EventBus.hit_resolved.is_connected(
			_on_hit_resolved
		):
		EventBus.hit_resolved.connect(_on_hit_resolved)
	if is_instance_valid(_active_backend) and not _action_pending:
		_play_active_idle()


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
	return _play_active_idle()


func play_basic_attack() -> bool:
	return _begin_action(&"cast")


func play_cast() -> bool:
	return _begin_action(&"cast")


func play_spell_action(spell: Spell = null) -> bool:
	var action_id := &"cast"
	if spell != null:
		var spell_action_id := CharacterAnimationSetData.cast_action_id_for_spell_id(
			spell.get_effective_spell_id()
		)
		if spell_action_id != &"":
			action_id = spell_action_id
	return _begin_action(action_id)


func play_hit() -> bool:
	if _closing or _action_pending or _movement_active \
			or _active_backend != viewport_backend:
		return false
	return bool(viewport_backend.play_hit(_facing, _clip_for_action(&"hit")))


func cancel_spell_action() -> void:
	cancel_pending_visual_actions()


func cancel_pending_visual_actions() -> void:
	_generation += 1
	_action_pending = false
	_action_elapsed = 0.0
	_action_timeout_seconds = ACTION_TIMEOUT_SECONDS
	_pending_action_id = ACTION_FALLBACK
	_pending_action_clip = &""
	_release_emitted = false
	_queued_action_for_backend = false
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
		_play_active_idle()
	_activate_deferred_viewport_if_available()


func begin_movement_feedback(from_cell: Vector2i, to_cell: Vector2i) -> void:
	_begin_movement_feedback(from_cell, to_cell, &"walk")


func begin_path_movement_feedback(path: Array) -> void:
	if path.size() < 2 or not path[0] is Vector2i or not path[1] is Vector2i:
		return
	var step_count := maxi(1, path.size() - 1)
	var run_threshold := (
		_selected_profile.run_min_path_cells
		if _selected_profile != null
		else visual_profile.run_min_path_cells if visual_profile != null else 6
	)
	var action_id := &"run" if step_count >= run_threshold else &"walk"
	_begin_movement_feedback(path[0] as Vector2i, path[1] as Vector2i, action_id)


func get_movement_segment_duration(path: Array) -> float:
	var profile := _selected_profile \
		if _selected_profile != null else visual_profile
	if profile == null:
		return MovementTiming.MOVE_SEGMENT_DURATION
	var step_count := maxi(1, path.size() - 1)
	if step_count >= profile.run_min_path_cells:
		return profile.run_segment_duration_seconds
	return profile.walk_segment_duration_seconds


func _begin_movement_feedback(
		from_cell: Vector2i,
		to_cell: Vector2i,
		action_id: StringName
	) -> void:
	if _closing or _action_pending or from_cell == to_cell:
		return
	set_facing(to_cell - from_cell)
	_movement_active = true
	_movement_action_id = action_id if action_id in [&"walk", &"run"] else &"walk"
	_movement_stable_time = 0.0
	var parent_2d := get_parent() as Node2D
	if parent_2d != null:
		_last_parent_position = parent_2d.position
	if is_instance_valid(_active_backend):
		_play_active_movement()


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
	var fallback_was_active: bool = (
		is_instance_valid(fallback_backend)
		and _active_backend == fallback_backend
		and fallback_backend.is_backend_active()
	)
	var replay_action: bool = _action_pending and not fallback_was_active
	if is_instance_valid(viewport_backend):
		viewport_backend.cancel_action()
	if fallback_was_active:
		if reason != &"":
			_record_backend_error(reason)
		return
	if not _activate_safe_fallback():
		if reason != &"":
			_record_backend_error(reason)
		if replay_action:
			_queued_action_for_backend = false
			_complete_action_once(ACTION_FALLBACK)
		return
	if reason != &"":
		_record_backend_error(reason)
	if replay_action:
		_queued_action_for_backend = false
		_action_elapsed = 0.0
		if not fallback_backend.play_action(_facing):
			_complete_action_once(ACTION_FALLBACK)


func request_subviewport_backend(
		profile_override: AchillesVisualProfile = null
	) -> bool:
	var selected_profile := (
		profile_override if profile_override != null else visual_profile
	)
	if viewport_backend.is_shutdown():
		_selected_profile = selected_profile
		force_safe_fallback(&"SUBVIEWPORT_BACKEND_ALREADY_RELEASED")
		return false
	var configured_profile := viewport_backend.get_configured_profile()
	if configured_profile != null:
		if selected_profile != configured_profile:
			printerr(JSON.stringify({
				"event": "ACHILLES_VISUAL_BACKEND_REQUEST_REJECTED",
				"reason": "SUBVIEWPORT_PROFILE_SWITCH_UNSUPPORTED",
				"requested_backend": String(REQUESTED_BACKEND),
				"room_id": _runtime_room_id,
				"commit": _runtime_commit,
			}))
			return false
		_selected_profile = configured_profile
		if not viewport_backend.is_ready_for_render():
			return true
		if (_action_pending and not _queued_action_for_backend) \
				or (_movement_active and _active_backend == fallback_backend):
			_viewport_activation_deferred = true
		else:
			_activate_viewport_backend()
		return true
	_selected_profile = selected_profile
	if selected_profile == null or not selected_profile.is_character_only_valid():
		force_safe_fallback(&"INVALID_CHARACTER_ONLY_PROFILE")
		return false
	return viewport_backend.configure(selected_profile)


func get_active_backend_name() -> StringName:
	if _active_backend == viewport_backend:
		return &"Viewport3DBackend"
	if is_instance_valid(fallback_backend) and _active_backend == fallback_backend:
		return &"Legacy2DFallbackBackend"
	return &"Initializing"


func get_last_backend_error() -> Dictionary:
	return _last_backend_error.duplicate(true)


func configure_runtime_diagnostics(
		enabled: bool,
		room_id: String = "",
		commit: String = ""
	) -> void:
	_runtime_diagnostics_enabled = enabled
	_runtime_room_id = room_id
	_runtime_commit = commit
	if not _last_backend_error.is_empty():
		_last_backend_error["room_id"] = _runtime_room_id
		_last_backend_error["commit"] = _runtime_commit
		printerr(JSON.stringify(_last_backend_error))
	_emit_runtime_state(&"ACHILLES_VISUAL_RUNTIME_DIAGNOSTICS_CONFIGURED")


func get_visual_runtime_state() -> Dictionary:
	var character_scene_path := ""
	var evidence_profile := _selected_profile \
		if _selected_profile != null else visual_profile
	if evidence_profile != null and evidence_profile.character_scene != null:
		character_scene_path = evidence_profile.character_scene.resource_path
	var skeleton_path := ""
	var skeletons := viewport_backend.find_children(
		"*", "Skeleton3D", true, false
	)
	if not skeletons.is_empty():
		skeleton_path = String(skeletons[0].get_path())
	var viewport_texture_valid := false
	if is_instance_valid(viewport_backend):
		viewport_texture_valid = viewport_backend.has_valid_render_output()
	var legacy_visible := false
	var legacy_processing := false
	if is_instance_valid(fallback_backend):
		legacy_visible = fallback_backend.visible \
			and fallback_backend.is_visible_in_tree()
		legacy_processing = fallback_backend.can_process()
	return {
		"event": "ACHILLES_VISUAL_RUNTIME_STATE",
		"ACHILLES_VISUAL_BACKEND_REQUESTED": String(REQUESTED_BACKEND),
		"ACHILLES_VISUAL_BACKEND_ACTIVE": _normalized_active_backend(),
		"ACHILLES_VISUAL_FALLBACK_ACTIVE": (
			is_instance_valid(fallback_backend)
			and _active_backend == fallback_backend
			and fallback_backend.is_backend_active()
		),
		"ACHILLES_CHARACTER_SCENE_PATH": character_scene_path,
		"ACHILLES_SKELETON_PATH": skeleton_path,
		"ACHILLES_SUBVIEWPORT_PATH": String(
			viewport_backend.character_viewport.get_path()
			if is_instance_valid(viewport_backend.character_viewport) else ""
		),
		"ACHILLES_VIEWPORT_TEXTURE_VALID": viewport_texture_valid,
		"ACHILLES_LEGACY_BODY_VISIBLE": legacy_visible,
		"ACHILLES_LEGACY_BODY_PROCESSING": legacy_processing,
		"ACHILLES_ROOM_ID": _runtime_room_id,
		"commit": _runtime_commit,
	}


func _initialize_selected_backend() -> void:
	if _closing:
		return
	if visual_profile == null:
		_selected_profile = null
		force_safe_fallback(&"INVALID_CHARACTER_ONLY_PROFILE")
		return
	request_subviewport_backend()


func _begin_action(action_id: StringName = ACTION_FALLBACK) -> bool:
	if _closing or _action_pending:
		return false
	_generation += 1
	_action_pending = true
	_action_elapsed = 0.0
	_action_timeout_seconds = ACTION_TIMEOUT_SECONDS
	_pending_action_id = action_id if action_id != &"" else ACTION_FALLBACK
	_pending_action_clip = _clip_for_action(_pending_action_id)
	_release_emitted = false
	_movement_active = false
	if not is_instance_valid(_active_backend):
		_queued_action_for_backend = true
		return true
	var started := _play_active_action()
	if started:
		return true
	if _active_backend != fallback_backend:
		force_safe_fallback(&"SUBVIEWPORT_ACTION_START_FAILED")
		return _action_pending
	_action_pending = false
	_action_elapsed = 0.0
	_pending_action_id = ACTION_FALLBACK
	_pending_action_clip = &""
	return false


func _connect_backend_signals(backend: Node) -> void:
	if not is_instance_valid(backend):
		return
	backend.action_release_reached.connect(
		_on_backend_action_release.bind(backend)
	)
	backend.action_finished.connect(
		_on_backend_action_finished.bind(backend)
	)


func _on_backend_action_release(source_backend: Node) -> void:
	if _closing or source_backend != _active_backend \
			or not _action_pending or _release_emitted:
		return
	_release_emitted = true
	cast_release_reached.emit()


func _on_backend_action_finished(
		action_name: StringName,
		source_backend: Node
	) -> void:
	if source_backend != _active_backend:
		return
	_complete_action_once(action_name)


func _complete_action_once(action_name: StringName) -> void:
	if _closing or not _action_pending:
		return
	if not _release_emitted:
		_release_emitted = true
		cast_release_reached.emit()
	var completed_action := (
		_pending_action_id if _pending_action_id != &"" else action_name
	)
	_action_pending = false
	_action_elapsed = 0.0
	_action_timeout_seconds = ACTION_TIMEOUT_SECONDS
	_pending_action_id = ACTION_FALLBACK
	_pending_action_clip = &""
	_queued_action_for_backend = false
	if is_instance_valid(_active_backend):
		_play_active_idle()
	_activate_deferred_viewport_if_available()
	animation_finished.emit(completed_action)


func _on_viewport_backend_ready() -> void:
	if _closing:
		return
	if _action_pending and not _queued_action_for_backend:
		_viewport_activation_deferred = true
		return
	_activate_viewport_backend()
	if _queued_action_for_backend:
		_queued_action_for_backend = false
		_action_elapsed = 0.0
		if not _play_active_action():
			force_safe_fallback(&"SUBVIEWPORT_ACTION_START_FAILED")
	elif _movement_active:
		_play_active_movement()
	else:
		_play_active_idle()
	_emit_runtime_state(&"ACHILLES_VISUAL_BACKEND_READY")


func _on_viewport_backend_failed(error_code: StringName) -> void:
	if _closing:
		return
	force_safe_fallback(error_code)


func _activate_safe_fallback() -> bool:
	_viewport_activation_deferred = false
	if is_instance_valid(viewport_backend):
		viewport_backend.set_backend_active(false)
	if not _ensure_fallback_backend():
		_active_backend = null
		return false
	if _active_backend != fallback_backend:
		fallback_backend.set_backend_active(false)
	fallback_backend.set_backend_active(true)
	_active_backend = fallback_backend
	fallback_backend.set_facing_label(_facing)
	_emit_runtime_state(&"ACHILLES_VISUAL_FALLBACK_ACTIVE")
	return true


func _activate_viewport_backend() -> void:
	if not is_instance_valid(viewport_backend) \
			or not viewport_backend.is_ready_for_render():
		return
	if is_instance_valid(fallback_backend):
		fallback_backend.set_backend_active(false)
		fallback_backend.shutdown()
		fallback_backend.queue_free()
		fallback_backend = null
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
		"event": "ACHILLES_VISUAL_FALLBACK_ACTIVATED",
		"reason": String(error_code),
		"error_code": String(error_code),
		"requested_backend": String(REQUESTED_BACKEND),
		"failed_resource": _failed_resource_for(error_code),
		"room_id": _runtime_room_id,
		"commit": _runtime_commit,
		"fallback": "LEGACY_2D_ON_VERIFIED_ERROR",
		"legacy_2d_loaded": is_instance_valid(fallback_backend),
		"fallback_active": (
			is_instance_valid(fallback_backend)
			and _active_backend == fallback_backend
			and fallback_backend.is_backend_active()
		),
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
			_movement_action_id = &"walk"
			_play_active_movement()
		return
	if not _movement_active:
		return
	_movement_stable_time += delta
	if _movement_stable_time >= MOVEMENT_SETTLE_SECONDS:
		_movement_active = false
		_movement_stable_time = 0.0
		_play_active_idle()
		_activate_deferred_viewport_if_available()


func _on_bound_unit_died(_dead_unit: Unit) -> void:
	if _closing or _death_tween != null:
		return
	_generation += 1
	_action_pending = false
	_action_elapsed = 0.0
	_action_timeout_seconds = ACTION_TIMEOUT_SECONDS
	_pending_action_id = ACTION_FALLBACK
	_pending_action_clip = &""
	_release_emitted = false
	_queued_action_for_backend = false
	_movement_active = false
	viewport_backend.cancel_action()
	if is_instance_valid(fallback_backend):
		fallback_backend.cancel_action()
	var death_generation := _generation
	_death_tween = create_tween()
	_death_tween.tween_property(self, "modulate:a", 0.0, 0.28)
	_death_tween.finished.connect(func() -> void:
		_death_tween = null
		if not _closing and death_generation == _generation:
			death_animation_finished.emit()
	, CONNECT_ONE_SHOT)


func _on_hit_resolved(fact: CombatEventFact) -> void:
	if fact == null or fact.target != _unit or fact.amount_resolved <= 0 \
			or _unit == null or not _unit.is_alive:
		return
	play_hit()


func _disconnect_unit() -> void:
	if is_instance_valid(_unit) and _unit.died.is_connected(
			_on_bound_unit_died
		):
		_unit.died.disconnect(_on_bound_unit_died)
	if EventBus.hit_resolved.is_connected(_on_hit_resolved):
		EventBus.hit_resolved.disconnect(_on_hit_resolved)
	_unit = null
	_animation_set = null


func _clip_for_action(action_id: StringName) -> StringName:
	if _animation_set == null:
		return &""
	var exact := _animation_set.get_animation_name(action_id)
	if exact != &"":
		return exact
	if String(action_id).begins_with("cast:"):
		return _animation_set.get_animation_name(&"cast")
	return &""


func _play_active_idle() -> bool:
	if not is_instance_valid(_active_backend):
		return false
	if _active_backend == viewport_backend:
		return bool(viewport_backend.play_idle(
			_facing, _clip_for_action(&"idle")
		))
	return bool(_active_backend.play_idle(_facing))


func _play_active_movement() -> bool:
	if not is_instance_valid(_active_backend):
		return false
	if _active_backend == viewport_backend:
		var clip := _clip_for_action(_movement_action_id)
		if _movement_action_id == &"run":
			return bool(viewport_backend.play_run(_facing, clip))
		return bool(viewport_backend.play_walk(_facing, clip))
	return bool(_active_backend.play_move(_facing))


func _play_active_action() -> bool:
	if not is_instance_valid(_active_backend):
		return false
	if _active_backend == viewport_backend:
		_action_timeout_seconds = viewport_backend.get_action_watchdog_seconds(
			_pending_action_id, _pending_action_clip
		)
		return bool(viewport_backend.play_action(
			_facing, _pending_action_id, _pending_action_clip
		))
	_action_timeout_seconds = ACTION_TIMEOUT_SECONDS
	return bool(_active_backend.play_action(_facing))


func _ensure_fallback_backend() -> bool:
	if is_instance_valid(fallback_backend):
		return true
	var scene := DEFAULT_FALLBACK_BACKEND_SCENE
	var fallback_profile := _selected_profile \
		if _selected_profile != null else visual_profile
	if fallback_profile != null \
			and fallback_profile.fallback_backend_scene != null:
		scene = fallback_profile.fallback_backend_scene
	var candidate := scene.instantiate()
	if candidate == null or candidate.get_script() != FALLBACK_BACKEND_SCRIPT:
		if candidate != null:
			candidate.free()
		printerr(JSON.stringify({
			"event": "ACHILLES_VISUAL_FALLBACK_ACTIVATION_FAILED",
			"reason": "LEGACY_FALLBACK_SCENE_INVALID",
			"requested_backend": String(REQUESTED_BACKEND),
			"room_id": _runtime_room_id,
			"commit": _runtime_commit,
		}))
		return false
	var backend := candidate as Node2D
	backend.name = "Legacy2DFallbackBackend"
	backend.visible = false
	backend.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(backend)
	move_child(backend, 0)
	fallback_backend = backend
	_connect_backend_signals(fallback_backend)
	fallback_backend.set_backend_active(false)
	return true


func _normalized_active_backend() -> String:
	if _active_backend == viewport_backend and viewport_backend.is_backend_active():
		return "VIEWPORT_3D"
	if is_instance_valid(fallback_backend) \
			and _active_backend == fallback_backend \
			and fallback_backend.is_backend_active():
		return "LEGACY_2D"
	return "INITIALIZING"


func _failed_resource_for(error_code: StringName) -> String:
	var evidence_profile := _selected_profile \
		if _selected_profile != null else visual_profile
	if error_code in [
		&"CHARACTER_VISUAL_SCENE_MISSING",
		&"CHARACTER_VISUAL_SCENE_INVALID",
	]:
		if evidence_profile != null \
				and evidence_profile.character_scene != null:
			return evidence_profile.character_scene.resource_path
		return "res://characters/achilles/3d/Achilles3DVisual.tscn"
	if error_code in [
		&"CHARACTER_ASSET_MISSING",
		&"CHARACTER_ASSET_IMPORT_FAILED",
		&"CHARACTER_ASSET_ROOT_NOT_3D",
		&"SKELETON_COUNT_MISMATCH",
		&"SKELETON_BONE_COUNT_MISMATCH",
		&"ANIMATION_PLAYER_MISSING",
		&"CHARACTER_MESH_MISSING",
		&"CHARACTER_MATERIAL_MISSING",
		&"SKELETON_SIGNATURE_MISMATCH",
		&"HIPS_BONE_MISSING",
		&"SOURCE_ACTION_SET_MISMATCH",
		&"EMBEDDED_EQUIPMENT_NODE_DETECTED",
	]:
		if evidence_profile != null:
			return evidence_profile.character_asset_path
	if error_code in [
		&"SUBVIEWPORT_MISSING",
		&"SUBVIEWPORT_CAMERA_MISSING",
		&"SUBVIEWPORT_RENDER_WORLD_MISSING",
		&"RENDERED_SPRITE_MISSING",
		&"SUBVIEWPORT_TEXTURE_MISSING",
		&"SUBVIEWPORT_TEXTURE_INVALID",
		&"SUBVIEWPORT_RENDER_EMPTY",
		&"SUBVIEWPORT_WARMUP_UNAVAILABLE",
		&"SUBVIEWPORT_WARMUP_TIMEOUT",
		&"SUBVIEWPORT_BACKEND_ALREADY_RELEASED",
		&"SUBVIEWPORT_ACTION_START_FAILED",
	]:
		return "res://characters/achilles/3d/AchillesViewport3DBackend.tscn"
	return evidence_profile.resource_path if evidence_profile != null else ""


func _emit_runtime_state(event_name: StringName) -> void:
	if not _runtime_diagnostics_enabled:
		return
	var state := get_visual_runtime_state()
	state.event = String(event_name)
	print(JSON.stringify(state))
