class_name CharacterVisual3D
extends Node3D

signal animation_started(animation_name: StringName)
signal animation_finished(animation_name: StringName)
signal death_animation_finished
signal cast_release_reached
signal hit_reaction_finished

const ACTION_IDLE := &"idle"
const ACTION_WALK := &"walk"
const ACTION_RUN := &"run"
const ACTION_CAST := &"cast"
const ACTION_CAST_START := &"cast_start"
const ACTION_CAST_HOLD := &"cast_hold"
const ACTION_CAST_END := &"cast_end"
const ACTION_HIT := &"hit"
const ACTION_DEATH := &"death"

@export var model_root_path := NodePath("ModelPivot/CharacterModel")
@export var animation_idle: StringName = &""
@export var animation_walk: StringName = &""
@export var animation_run: StringName = &""
@export var animation_cast: StringName = &""
@export var animation_cast_start: StringName = &""
@export var animation_cast_hold: StringName = &""
@export var animation_cast_end: StringName = &""
@export var animation_hit: StringName = &""
@export var animation_death: StringName = &""
@export var cast_release_time_seconds := -1.0
@export_range(0.0, 1.0, 0.01) var cast_release_normalized_time := 0.32
@export var left_mount_node_name: StringName = &"WeaponMountLeft"
@export var right_mount_node_name: StringName = &"WeaponMountRight"

@export var show_socket_debug: bool = false:
	set(value):
		show_socket_debug = value
		_apply_socket_debug_visibility()

var _model_root: Node = null
var _animation_player: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _mesh_instance: MeshInstance3D = null
var _left_weapon_mount: Node3D = null
var _right_weapon_mount: Node3D = null
var _left_debug_marker: Node3D = null
var _right_debug_marker: Node3D = null
var _left_hand_item: Node3D = null
var _right_hand_item: Node3D = null
var _attachment_origins: Dictionary = {}
var _cast_release_emitted := true
var _release_animation_name: StringName = &""
var _release_time_seconds := -1.0
var _release_normalized_time := 0.0
var _death_locked := false


func _ready() -> void:
	_discover_nodes()
	_setup_profile_sockets()
	_discover_mounts()
	_connect_animation_player_signals()
	_apply_socket_debug_visibility()
	if _animation_player == null:
		push_warning("%s: AnimationPlayer introuvable dans le modele." % get_class())
		return
	play_idle()


func _process(_delta: float) -> void:
	if _animation_player == null or _cast_release_emitted or _death_locked:
		return
	if _release_animation_name == &"" \
			or not _animation_player.is_playing() \
			or get_current_animation() != _release_animation_name:
		return
	var animation := _animation_player.get_animation(_release_animation_name)
	if animation == null or animation.length <= 0.0:
		return
	var release_time := _release_time_seconds
	if release_time < 0.0:
		release_time = animation.length * clampf(_release_normalized_time, 0.0, 1.0)
	if _animation_player.current_animation_position + 0.000001 < release_time:
		return
	_cast_release_emitted = true
	cast_release_reached.emit()


func _exit_tree() -> void:
	_cast_release_emitted = true
	_release_animation_name = &""
	if _animation_player != null:
		var started := Callable(self, "_on_player_animation_started")
		var finished := Callable(self, "_on_player_animation_finished")
		if _animation_player.animation_started.is_connected(started):
			_animation_player.animation_started.disconnect(started)
		if _animation_player.animation_finished.is_connected(finished):
			_animation_player.animation_finished.disconnect(finished)


func play_idle(blend_time: float = 0.15) -> bool:
	if _death_locked:
		return false
	return play_animation(animation_idle, 1.0, blend_time)


func play_walk(speed_scale: float = 1.0, blend_time: float = 0.1) -> bool:
	if _death_locked:
		return false
	return play_animation(animation_walk, speed_scale, blend_time)


func play_run(speed_scale: float = 1.0, blend_time: float = 0.1) -> bool:
	if _death_locked:
		return false
	return play_animation(animation_run, speed_scale, blend_time)


func play_cast_full(speed_scale: float = 1.0) -> bool:
	if _death_locked:
		return false
	return play_animation_with_release(
		animation_cast,
		cast_release_normalized_time,
		cast_release_time_seconds,
		speed_scale,
		0.1
	)


func play_cast_start(speed_scale: float = 1.0) -> bool:
	if _death_locked or animation_cast_start == &"":
		return false
	return play_animation(animation_cast_start, speed_scale, 0.1)


func play_cast_hold(speed_scale: float = 1.0) -> bool:
	if _death_locked or animation_cast_hold == &"":
		return false
	return play_animation(animation_cast_hold, speed_scale, 0.1)


func play_cast_end(speed_scale: float = 1.0) -> bool:
	if _death_locked or animation_cast_end == &"":
		return false
	return play_animation(animation_cast_end, speed_scale, 0.1)


func play_hit(speed_scale: float = 1.0) -> bool:
	if _death_locked:
		return false
	return play_animation(animation_hit, speed_scale, 0.08)


func play_death(speed_scale: float = 1.0) -> bool:
	if _death_locked:
		return false
	_death_locked = true
	_cast_release_emitted = true
	return play_animation(animation_death, speed_scale, 0.1)


func play_animation(
		animation_name: StringName,
		speed_scale: float = 1.0,
		blend_time: float = 0.1
	) -> bool:
	if _animation_player == null:
		push_warning("%s: impossible de lire %s, AnimationPlayer absent." % [get_class(), animation_name])
		return false
	if animation_name == &"" or not _animation_player.has_animation(animation_name):
		push_warning("%s: animation inconnue ignoree : %s" % [get_class(), animation_name])
		return false
	if not is_finite(speed_scale) or speed_scale <= 0.0:
		push_warning("%s: vitesse invalide pour %s : %s" % [get_class(), animation_name, speed_scale])
		return false
	_animation_player.speed_scale = 1.0
	_cast_release_emitted = true
	_release_animation_name = &""
	_release_time_seconds = -1.0
	_release_normalized_time = 0.0
	_animation_player.play(animation_name, maxf(blend_time, 0.0), speed_scale)
	return true


func play_animation_with_release(
		animation_name: StringName,
		release_normalized_time: float,
		release_time_seconds: float = -1.0,
		speed_scale: float = 1.0,
		blend_time: float = 0.1
	) -> bool:
	if _death_locked:
		return false
	if not play_animation(animation_name, speed_scale, blend_time):
		return false
	_release_animation_name = animation_name
	_release_time_seconds = release_time_seconds
	_release_normalized_time = clampf(release_normalized_time, 0.0, 1.0)
	_cast_release_emitted = false
	return true


func stop_animation() -> void:
	if _animation_player == null:
		return
	_animation_player.stop()
	_animation_player.speed_scale = 1.0
	_cast_release_emitted = true
	_release_animation_name = &""
	_release_time_seconds = -1.0
	_release_normalized_time = 0.0


func reset_to_idle() -> void:
	stop_animation()
	_death_locked = false
	play_idle(0.0)


func get_animation_player() -> AnimationPlayer:
	return _animation_player


func get_skeleton() -> Skeleton3D:
	return _skeleton


func get_mesh_instance() -> MeshInstance3D:
	return _mesh_instance


func get_left_weapon_mount() -> Node3D:
	return _left_weapon_mount


func get_right_weapon_mount() -> Node3D:
	return _right_weapon_mount


func get_default_cast_mount() -> Node3D:
	return _right_weapon_mount


func get_current_animation() -> StringName:
	if _animation_player == null:
		return &""
	return StringName(_animation_player.current_animation)


func is_animation_playing(animation_name: StringName = &"") -> bool:
	if _animation_player == null or not _animation_player.is_playing():
		return false
	return animation_name == &"" or get_current_animation() == animation_name


func is_cast_animation(animation_name: StringName) -> bool:
	return animation_name == animation_cast or (
		animation_cast_end != &"" and animation_name == animation_cast_end
	)


func is_death_locked() -> bool:
	return _death_locked


func get_animation_name_for_action(action: StringName) -> StringName:
	match action:
		ACTION_IDLE:
			return animation_idle
		ACTION_WALK:
			return animation_walk
		ACTION_RUN:
			return animation_run
		ACTION_CAST:
			return animation_cast
		ACTION_CAST_START:
			return animation_cast_start
		ACTION_CAST_HOLD:
			return animation_cast_hold
		ACTION_CAST_END:
			return animation_cast_end
		ACTION_HIT:
			return animation_hit
		ACTION_DEATH:
			return animation_death
	return &""


func get_animation_length_for_action(action: StringName) -> float:
	var animation_name := get_animation_name_for_action(action)
	if _animation_player == null or animation_name == &"" \
			or not _animation_player.has_animation(animation_name):
		return 0.0
	return _animation_player.get_animation(animation_name).length


func attach_to_left_hand(item: Node3D) -> void:
	_attach_item_to_mount(item, true)


func attach_to_right_hand(item: Node3D) -> void:
	_attach_item_to_mount(item, false)


func clear_left_hand() -> void:
	if not is_instance_valid(_left_hand_item):
		_left_hand_item = null
		return
	_detach_item_without_freeing(_left_hand_item)
	_left_hand_item = null


func clear_right_hand() -> void:
	if not is_instance_valid(_right_hand_item):
		_right_hand_item = null
		return
	_detach_item_without_freeing(_right_hand_item)
	_right_hand_item = null


func get_left_hand_item() -> Node3D:
	return _left_hand_item if is_instance_valid(_left_hand_item) else null


func get_right_hand_item() -> Node3D:
	return _right_hand_item if is_instance_valid(_right_hand_item) else null


func set_socket_debug_visible(visible: bool) -> void:
	show_socket_debug = visible


func _discover_nodes() -> void:
	_model_root = get_node_or_null(model_root_path)
	if _model_root == null:
		return
	var players: Array[Node] = _model_root.find_children("*", "AnimationPlayer", true, false)
	var skeletons: Array[Node] = _model_root.find_children("*", "Skeleton3D", true, false)
	var meshes: Array[Node] = _model_root.find_children("*", "MeshInstance3D", true, false)
	_animation_player = players[0] as AnimationPlayer if not players.is_empty() else null
	_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	for mesh_node in meshes:
		var candidate := mesh_node as MeshInstance3D
		if candidate.mesh != null and candidate.skin != null:
			_mesh_instance = candidate
			break
	if _mesh_instance == null and not meshes.is_empty():
		_mesh_instance = meshes[0] as MeshInstance3D


func _setup_profile_sockets() -> void:
	pass


func _discover_mounts() -> void:
	_left_weapon_mount = find_child(str(left_mount_node_name), true, false) as Node3D
	_right_weapon_mount = find_child(str(right_mount_node_name), true, false) as Node3D
	_left_debug_marker = find_child("DebugLeftHandMarker", true, false) as Node3D
	_right_debug_marker = find_child("DebugRightHandMarker", true, false) as Node3D


func _connect_animation_player_signals() -> void:
	if _animation_player == null:
		return
	if not _animation_player.animation_started.is_connected(_on_player_animation_started):
		_animation_player.animation_started.connect(_on_player_animation_started)
	if not _animation_player.animation_finished.is_connected(_on_player_animation_finished):
		_animation_player.animation_finished.connect(_on_player_animation_finished)


func _on_player_animation_started(animation_name: StringName) -> void:
	animation_started.emit(animation_name)


func _on_player_animation_finished(animation_name: StringName) -> void:
	_animation_player.speed_scale = 1.0
	if animation_name == _release_animation_name and not _cast_release_emitted and not _death_locked:
		_cast_release_emitted = true
		cast_release_reached.emit()
	animation_finished.emit(animation_name)
	if animation_name == animation_death:
		death_animation_finished.emit()
	elif animation_name == animation_hit:
		hit_reaction_finished.emit()
		if not _death_locked:
			play_idle()
	elif is_cast_animation(animation_name):
		if not _death_locked:
			play_idle()


func _apply_socket_debug_visibility() -> void:
	if is_instance_valid(_left_debug_marker):
		_left_debug_marker.visible = show_socket_debug
	if is_instance_valid(_right_debug_marker):
		_right_debug_marker.visible = show_socket_debug


func _attach_item_to_mount(item: Node3D, attach_left: bool) -> void:
	if item == null:
		push_warning("%s: tentative d'attachement d'un objet null ignoree." % get_class())
		return
	var mount := _left_weapon_mount if attach_left else _right_weapon_mount
	if mount == null:
		push_warning("%s: mount introuvable, objet non attache." % get_class())
		return
	if attach_left and item == _left_hand_item:
		item.transform = Transform3D.IDENTITY
		return
	if not attach_left and item == _right_hand_item:
		item.transform = Transform3D.IDENTITY
		return
	if item == _left_hand_item:
		clear_left_hand()
	if item == _right_hand_item:
		clear_right_hand()
	if attach_left and is_instance_valid(_left_hand_item):
		clear_left_hand()
	if not attach_left and is_instance_valid(_right_hand_item):
		clear_right_hand()
	_remember_attachment_origin(item)
	_reparent_item(item, mount, false)
	item.transform = Transform3D.IDENTITY
	if attach_left:
		_left_hand_item = item
	else:
		_right_hand_item = item


func _remember_attachment_origin(item: Node3D) -> void:
	var item_id := item.get_instance_id()
	if _attachment_origins.has(item_id):
		return
	_attachment_origins[item_id] = {
		"parent": item.get_parent(),
		"transform": item.transform,
	}


func _detach_item_without_freeing(item: Node3D) -> void:
	var item_id := item.get_instance_id()
	var origin: Dictionary = _attachment_origins.get(item_id, {})
	var original_parent := origin.get("parent") as Node
	var target_parent: Node = original_parent if is_instance_valid(original_parent) else get_parent()
	if target_parent == null:
		target_parent = get_tree().current_scene
	if target_parent != null and target_parent != item.get_parent():
		_reparent_item(item, target_parent, true)
	elif target_parent == null and item.get_parent() != null:
		item.get_parent().remove_child(item)
	if origin.has("transform") and target_parent == original_parent:
		item.transform = origin["transform"] as Transform3D
	_attachment_origins.erase(item_id)


func _reparent_item(item: Node3D, new_parent: Node, keep_global_transform: bool) -> void:
	if item.get_parent() == new_parent:
		return
	if item.get_parent() != null and item.is_inside_tree() and new_parent.is_inside_tree():
		item.reparent(new_parent, keep_global_transform)
		return
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	new_parent.add_child(item)
