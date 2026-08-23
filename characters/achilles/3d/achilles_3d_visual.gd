class_name Achilles3DVisual
extends Node3D

signal setup_completed
signal setup_failed(error_code: StringName)
signal action_started(action_name: StringName)
signal action_release_reached
signal action_finished(action_name: StringName)

const ACTION_FALLBACK := &"ACTION_FALLBACK"
const ROOT_MOTION_POLICY := &"ROOT_MOTION_UNCLASSIFIED"
const EXPECTED_BONE_COUNT := 52
const ACTION_TIMEOUT_MARGIN_SECONDS := 0.75
const FALLBACK_RELEASE_SECONDS := 0.18
const FALLBACK_FINISH_SECONDS := 0.45
const EXPECTED_ACTIONS: Array[StringName] = [
	&"Anim_0_001",
	&"Anim_0_003",
	&"Anim_0_004",
	&"Anim_0_005",
]

@onready var character_asset: Node3D = $CharacterAsset
@onready var foot_marker: Marker3D = $Markers/FootMarker
@onready var vfx_marker: Marker3D = $Markers/VFXMarker
@onready var facing_marker: Marker3D = $Markers/FacingMarker

var _profile: AchillesVisualProfile = null
var _model_root: Node3D = null
var _skeleton: Skeleton3D = null
var _animation_player: AnimationPlayer = null
var _mesh_instances: Array[MeshInstance3D] = []
var _model_local_transform := Transform3D.IDENTITY
var _hips_bone_index := -1
var _active_clip_hips_origin := Vector3.ZERO
var _active_clip: StringName = &""
var _active_semantic: StringName = &""
var _initialized := false
var _action_active := false
var _action_release_emitted := false
var _action_finished_emitted := false
var _action_elapsed := 0.0
var _action_release_seconds := FALLBACK_RELEASE_SECONDS
var _action_finish_seconds := FALLBACK_FINISH_SECONDS


func _ready() -> void:
	process_priority = 100


func _process(delta: float) -> void:
	_enforce_visual_origin()
	_neutralize_hips_xz()
	if not _action_active:
		return
	_action_elapsed += maxf(delta, 0.0)
	if not _action_release_emitted \
			and _action_elapsed >= _action_release_seconds:
		_action_release_emitted = true
		action_release_reached.emit()
	if _action_elapsed >= _action_finish_seconds:
		_finish_action_once()


func _exit_tree() -> void:
	cancel_action()
	_initialized = false


func initialize_from_profile(profile: AchillesVisualProfile) -> bool:
	if _initialized:
		return true
	_profile = profile
	if _profile == null or not _profile.is_character_only_valid():
		_fail_setup(&"INVALID_CHARACTER_ONLY_PROFILE")
		return false
	if not ResourceLoader.exists(_profile.character_asset_path, "PackedScene"):
		_fail_setup(&"CHARACTER_ASSET_MISSING")
		return false
	var resource := ResourceLoader.load(
		_profile.character_asset_path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REUSE
	)
	if not resource is PackedScene:
		_fail_setup(&"CHARACTER_ASSET_IMPORT_FAILED")
		return false
	var instance := (resource as PackedScene).instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.free()
		_fail_setup(&"CHARACTER_ASSET_ROOT_NOT_3D")
		return false
	_model_root = instance as Node3D
	_model_root.name = "CanonicalCharacterModel"
	character_asset.add_child(_model_root)
	character_asset.scale = Vector3.ONE * _profile.character_scale
	_model_local_transform = _model_root.transform
	if not _discover_and_validate_character():
		_cleanup_partial_model()
		return false
	_initialized = true
	_play_semantic_clip(&"IDLE")
	setup_completed.emit()
	return true


func play_idle(clip_override: StringName = &"") -> bool:
	if not _initialized:
		return false
	cancel_action()
	return _play_semantic_clip(&"IDLE", clip_override)


func play_move(clip_override: StringName = &"") -> bool:
	return play_walk(clip_override)


func play_walk(clip_override: StringName = &"") -> bool:
	if not _initialized:
		return false
	cancel_action()
	var semantic := &"WALK" if _clip_for_semantic(&"WALK") != &"" else &"MOVE"
	return _play_semantic_clip(semantic, clip_override)


func play_run(clip_override: StringName = &"") -> bool:
	if not _initialized:
		return false
	cancel_action()
	var semantic := &"RUN" if _clip_for_semantic(&"RUN") != &"" else &"MOVE"
	return _play_semantic_clip(semantic, clip_override)


func play_action(
		action_id: StringName = ACTION_FALLBACK,
		clip_override: StringName = &""
	) -> bool:
	if not _initialized or _action_active:
		return false
	_action_active = true
	_action_release_emitted = false
	_action_finished_emitted = false
	_action_elapsed = 0.0
	_active_semantic = action_id if action_id != &"" else ACTION_FALLBACK
	var action_clip := _resolved_action_clip(clip_override)
	var animation: Animation = null
	if _animation_player != null and _animation_player.has_animation(action_clip):
		animation = _animation_player.get_animation(action_clip)
	if animation != null:
		var runtime := _profile.runtime_for_clip(action_clip)
		var speed_scale := float(runtime.get("speed_scale", 1.0))
		var effective_duration := animation.length / maxf(speed_scale, 0.05)
		_action_release_seconds = effective_duration * float(
			runtime.get("release_normalized", 0.5)
		)
		_action_finish_seconds = (
			effective_duration + ACTION_TIMEOUT_MARGIN_SECONDS
		)
		_play_clip(
			action_clip,
			_active_semantic,
			speed_scale,
			float(runtime.get("blend_time", 0.12)),
			true
		)
	else:
		_action_release_seconds = FALLBACK_RELEASE_SECONDS
		_action_finish_seconds = FALLBACK_FINISH_SECONDS
		_hold_stable_pose()
		_active_semantic = action_id if action_id != &"" else ACTION_FALLBACK
	action_started.emit(_active_semantic)
	return true


func play_hit(clip_override: StringName = &"") -> bool:
	if not _initialized or _action_active:
		return false
	var clip := clip_override
	if _animation_player == null or clip == &"" \
			or not _animation_player.has_animation(clip):
		clip = _clip_for_semantic(&"HIT")
	if clip == &"" or not _animation_player.has_animation(clip):
		return false
	var runtime := _profile.runtime_for_clip(clip)
	return _play_clip(
		clip,
		&"HIT",
		float(runtime.get("speed_scale", 1.0)),
		float(runtime.get("blend_time", 0.08)),
		true
	)


func get_action_watchdog_seconds(
		_clip_action_id: StringName = ACTION_FALLBACK,
		clip_override: StringName = &""
	) -> float:
	var action_clip := _resolved_action_clip(clip_override)
	if _animation_player == null or not _animation_player.has_animation(action_clip):
		return FALLBACK_FINISH_SECONDS + ACTION_TIMEOUT_MARGIN_SECONDS
	var animation := _animation_player.get_animation(action_clip)
	if animation == null:
		return FALLBACK_FINISH_SECONDS + ACTION_TIMEOUT_MARGIN_SECONDS
	var runtime := _profile.runtime_for_clip(action_clip)
	var speed_scale := float(runtime.get("speed_scale", 1.0))
	return animation.length / maxf(speed_scale, 0.05) \
		+ ACTION_TIMEOUT_MARGIN_SECONDS + 0.25


func cancel_action() -> void:
	var was_action_active := _action_active
	_action_active = false
	_action_release_emitted = false
	_action_finished_emitted = false
	_action_elapsed = 0.0
	if was_action_active and _initialized:
		_play_semantic_clip(&"IDLE")


func set_facing_label(direction: String) -> void:
	if _profile == null:
		return
	character_asset.rotation_degrees.y = _profile.yaw_for_direction(direction)


func get_skeleton() -> Skeleton3D:
	return _skeleton


func get_animation_player() -> AnimationPlayer:
	return _animation_player


func get_mesh_instances() -> Array[MeshInstance3D]:
	return _mesh_instances.duplicate()


func get_source_action_names() -> Array[StringName]:
	var result: Array[StringName] = []
	if _animation_player == null:
		return result
	for animation_name in _animation_player.get_animation_list():
		var normalized := StringName(animation_name)
		if normalized in EXPECTED_ACTIONS:
			result.append(normalized)
	return result


func get_all_source_action_names() -> Array[StringName]:
	var result: Array[StringName] = []
	if _animation_player == null:
		return result
	for animation_name in _animation_player.get_animation_list():
		var normalized := StringName(animation_name)
		if normalized != &"RESET":
			result.append(normalized)
	return result


func get_runtime_skeleton_signature() -> String:
	if _skeleton == null:
		return ""
	var bone_names: Array[String] = []
	for bone_index in range(_skeleton.get_bone_count()):
		var bone_name := String(_skeleton.get_bone_name(bone_index))
		if bone_name.begins_with("mixamorig_"):
			bone_name = "mixamorig:" + bone_name.trim_prefix("mixamorig_")
		bone_names.append(bone_name)
	return JSON.stringify(bone_names).sha256_text().to_upper()


func get_root_motion_policy() -> StringName:
	return ROOT_MOTION_POLICY


func get_active_semantic() -> StringName:
	return _active_semantic


func is_initialized() -> bool:
	return _initialized


func has_visible_character_materials() -> bool:
	for mesh_instance in _mesh_instances:
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			if mesh_instance.get_active_material(surface_index) != null:
				return true
	return false


func _discover_and_validate_character() -> bool:
	var skeleton_nodes := _model_root.find_children(
		"*", "Skeleton3D", true, false
	)
	if skeleton_nodes.size() != 1:
		_fail_setup(&"SKELETON_COUNT_MISMATCH")
		return false
	_skeleton = skeleton_nodes[0] as Skeleton3D
	if _skeleton == null or _skeleton.get_bone_count() != EXPECTED_BONE_COUNT:
		_fail_setup(&"SKELETON_BONE_COUNT_MISMATCH")
		return false
	var players := _model_root.find_children(
		"*", "AnimationPlayer", true, false
	)
	_animation_player = (
		players[0] as AnimationPlayer if not players.is_empty() else null
	)
	if _animation_player == null:
		_fail_setup(&"ANIMATION_PLAYER_MISSING")
		return false
	_animation_player.animation_finished.connect(_on_animation_player_finished)
	_mesh_instances.clear()
	for node in _model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			_mesh_instances.append(mesh_instance)
	if _mesh_instances.is_empty():
		_fail_setup(&"CHARACTER_MESH_MISSING")
		return false
	if not has_visible_character_materials():
		_fail_setup(&"CHARACTER_MATERIAL_MISSING")
		return false
	if get_runtime_skeleton_signature() != _profile.skeleton_signature.to_upper():
		_fail_setup(&"SKELETON_SIGNATURE_MISMATCH")
		return false
	_hips_bone_index = _skeleton.find_bone("mixamorig_Hips")
	if _hips_bone_index < 0:
		_hips_bone_index = _skeleton.find_bone("mixamorig:Hips")
	if _hips_bone_index < 0:
		_fail_setup(&"HIPS_BONE_MISSING")
		return false
	var available_actions := get_all_source_action_names()
	for expected_action in EXPECTED_ACTIONS:
		if expected_action not in available_actions:
			_fail_setup(&"SOURCE_ACTION_SET_MISMATCH")
			return false
	if _contains_equipment_named_node():
		_fail_setup(&"EMBEDDED_EQUIPMENT_NODE_DETECTED")
		return false
	return true


func _contains_equipment_named_node() -> bool:
	const EQUIPMENT_TOKENS: Array[String] = [
		"weapon", "sword", "blade", "shield", "bow", "quiver",
	]
	var nodes: Array[Node] = [_model_root]
	nodes.append_array(_model_root.find_children("*", "Node", true, false))
	for node in nodes:
		var lowered := String(node.name).to_lower()
		for token in EQUIPMENT_TOKENS:
			if token in lowered:
				return true
	return false


func _hold_stable_pose() -> void:
	if _animation_player != null:
		_animation_player.stop(false)
	_active_clip = &""
	_active_semantic = &""


func _enforce_visual_origin() -> void:
	if is_instance_valid(_model_root):
		_model_root.transform = _model_local_transform
	character_asset.position = Vector3.ZERO


func _neutralize_hips_xz() -> void:
	if _skeleton == null or _hips_bone_index < 0 or _active_clip == &"":
		return
	var pose_position := _skeleton.get_bone_pose_position(_hips_bone_index)
	pose_position.x = _active_clip_hips_origin.x
	pose_position.z = _active_clip_hips_origin.z
	var runtime := _profile.runtime_for_clip(_active_clip)
	if String(runtime.get("root_motion_policy", "")) \
			== "LOCAL_XYZ_NEUTRALIZED":
		pose_position.y = _active_clip_hips_origin.y
	_skeleton.set_bone_pose_position(_hips_bone_index, pose_position)


func _clip_for_semantic(semantic: StringName) -> StringName:
	if _profile == null:
		return &""
	var entry := _profile.animation_profile.get(String(semantic), {}) as Dictionary
	return StringName(entry.get("godot_name", ""))


func _resolved_action_clip(clip_override: StringName) -> StringName:
	if _animation_player != null and clip_override != &"" \
			and _animation_player.has_animation(clip_override):
		return clip_override
	return _clip_for_semantic(ACTION_FALLBACK)


func _play_semantic_clip(
		semantic: StringName,
		clip_override: StringName = &""
	) -> bool:
	var clip := clip_override
	if _animation_player == null or clip == &"" \
			or not _animation_player.has_animation(clip):
		clip = _clip_for_semantic(semantic)
	if clip == &"":
		_hold_stable_pose()
		return true
	var runtime := _profile.runtime_for_clip(clip)
	return _play_clip(
		clip,
		semantic,
		float(runtime.get("speed_scale", 1.0)),
		float(runtime.get("blend_time", 0.12))
	)


func _play_clip(
		clip: StringName,
		semantic: StringName,
		speed_scale := 1.0,
		blend_time := 0.12,
		restart := false
	) -> bool:
	if _animation_player == null or not _animation_player.has_animation(clip):
		return false
	if not restart and _active_clip == clip \
			and _animation_player.is_playing():
		_active_semantic = semantic
		return true
	_animation_player.play(
		clip,
		maxf(blend_time, 0.0),
		maxf(speed_scale, 0.05)
	)
	_animation_player.seek(0.0, true)
	_active_clip = clip
	_active_semantic = semantic
	if _hips_bone_index >= 0:
		_active_clip_hips_origin = _skeleton.get_bone_pose_position(
			_hips_bone_index
		)
	_neutralize_hips_xz()
	return true


func _on_animation_player_finished(animation_name: StringName) -> void:
	if _action_active and animation_name == _active_clip:
		_finish_action_once()
		return
	if not _action_active and animation_name == _active_clip \
			and _active_semantic == &"HIT":
		_play_semantic_clip(&"IDLE")
		return
	if not _action_active and animation_name == _active_clip \
			and _active_semantic in [&"IDLE", &"MOVE", &"WALK", &"RUN"]:
		var runtime := _profile.runtime_for_clip(animation_name)
		_play_clip(
			animation_name,
			_active_semantic,
			float(runtime.get("speed_scale", 1.0)),
			0.0
		)


func _finish_action_once() -> void:
	if not _action_active or _action_finished_emitted:
		return
	if not _action_release_emitted:
		_action_release_emitted = true
		action_release_reached.emit()
	_action_finished_emitted = true
	_action_active = false
	var completed_action := _active_semantic
	_play_semantic_clip(&"IDLE")
	action_finished.emit(completed_action)


func _cleanup_partial_model() -> void:
	if is_instance_valid(_model_root):
		character_asset.remove_child(_model_root)
		_model_root.free()
	_model_root = null
	_skeleton = null
	_animation_player = null
	_hips_bone_index = -1
	_active_clip = &""
	_active_semantic = &""
	_mesh_instances.clear()


func _fail_setup(error_code: StringName) -> void:
	_initialized = false
	setup_failed.emit(error_code)
