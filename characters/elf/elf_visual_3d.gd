class_name ElfVisual3D
extends Node3D

signal animation_started(animation_name: StringName)
signal animation_finished(animation_name: StringName)
signal death_animation_finished
signal cast_release_reached
signal hit_reaction_finished

const ANIM_IDLE: StringName = &"Elf_Idle"
const ANIM_WALK: StringName = &"Elf_Walk"
const ANIM_RUN: StringName = &"Elf_Run"
const ANIM_CAST_FULL: StringName = &"Elf_Cast_Full"
const ANIM_CAST_START: StringName = &"Elf_Cast_Start"
const ANIM_CAST_HOLD: StringName = &"Elf_Cast_Hold"
const ANIM_CAST_END: StringName = &"Elf_Cast_End"
const ANIM_HIT: StringName = &"Elf_Hit"
const ANIM_DEATH: StringName = &"Elf_Death"

const IMPORTED_ANIMATIONS: Array[StringName] = [
	ANIM_IDLE,
	ANIM_WALK,
	ANIM_RUN,
	ANIM_CAST_FULL,
	ANIM_CAST_START,
	ANIM_CAST_HOLD,
	ANIM_CAST_END,
	ANIM_HIT,
	ANIM_DEATH,
]

@export var show_socket_debug: bool = false:
	set(value):
		show_socket_debug = value
		_apply_socket_debug_visibility()

@export_range(0.0, 1.0, 0.01) var cast_release_normalized_time := 0.32

var _model_root: Node
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _mesh_instance: MeshInstance3D
var _left_weapon_mount: Node3D
var _right_weapon_mount: Node3D
var _left_socket: BoneAttachment3D
var _right_socket: BoneAttachment3D
var _left_debug_marker: Node3D
var _right_debug_marker: Node3D
var _left_hand_item: Node3D
var _right_hand_item: Node3D
var _attachment_origins: Dictionary = {}
var _cast_release_emitted := false


func _ready() -> void:
	_discover_nodes()
	_connect_animation_player_signals()
	_apply_socket_debug_visibility()
	if _animation_player == null:
		push_warning("ElfVisual3D: AnimationPlayer introuvable dans l’instance GLB.")
		return
	play_idle()


func _process(_delta: float) -> void:
	if _animation_player == null or _cast_release_emitted:
		return
	if not _animation_player.is_playing() or get_current_animation() != ANIM_CAST_FULL:
		return
	var animation := _animation_player.get_animation(ANIM_CAST_FULL)
	if animation == null or animation.length <= 0.0:
		return
	var release_time := animation.length * clampf(cast_release_normalized_time, 0.0, 1.0)
	if _animation_player.current_animation_position >= release_time:
		_cast_release_emitted = true
		cast_release_reached.emit()


func play_idle(blend_time: float = 0.15) -> void:
	play_animation(ANIM_IDLE, 1.0, blend_time)


func play_walk(speed_scale: float = 1.0, blend_time: float = 0.1) -> void:
	play_animation(ANIM_WALK, speed_scale, blend_time)


func play_run(speed_scale: float = 1.0, blend_time: float = 0.1) -> void:
	play_animation(ANIM_RUN, speed_scale, blend_time)


func play_cast_full(speed_scale: float = 1.0) -> void:
	play_animation(ANIM_CAST_FULL, speed_scale, 0.1)


func play_cast_start(speed_scale: float = 1.0) -> void:
	play_animation(ANIM_CAST_START, speed_scale, 0.1)


func play_cast_hold(speed_scale: float = 1.0) -> void:
	play_animation(ANIM_CAST_HOLD, speed_scale, 0.1)


func play_cast_end(speed_scale: float = 1.0) -> void:
	play_animation(ANIM_CAST_END, speed_scale, 0.1)


func play_hit(speed_scale: float = 1.0) -> void:
	play_animation(ANIM_HIT, speed_scale, 0.08)


func play_death(speed_scale: float = 1.0) -> void:
	play_animation(ANIM_DEATH, speed_scale, 0.1)


func play_animation(
	animation_name: StringName,
	speed_scale: float = 1.0,
	blend_time: float = 0.1
) -> void:
	if _animation_player == null:
		push_warning("ElfVisual3D: impossible de lire %s, AnimationPlayer absent." % animation_name)
		return
	if not _animation_player.has_animation(animation_name):
		push_warning("ElfVisual3D: animation inconnue ignorée : %s" % animation_name)
		return
	if not is_finite(speed_scale) or speed_scale <= 0.0:
		push_warning("ElfVisual3D: vitesse invalide pour %s : %s" % [animation_name, speed_scale])
		return
	_animation_player.speed_scale = 1.0
	_cast_release_emitted = animation_name != ANIM_CAST_FULL
	_animation_player.play(animation_name, maxf(blend_time, 0.0), speed_scale)


func stop_animation() -> void:
	if _animation_player == null:
		return
	_animation_player.stop()
	_animation_player.speed_scale = 1.0
	_cast_release_emitted = true


func reset_to_idle() -> void:
	stop_animation()
	play_idle(0.0)


func get_animation_player() -> AnimationPlayer:
	return _animation_player


func get_skeleton() -> Skeleton3D:
	return _skeleton


func get_left_weapon_mount() -> Node3D:
	return _left_weapon_mount


func get_right_weapon_mount() -> Node3D:
	return _right_weapon_mount


func get_current_animation() -> StringName:
	if _animation_player == null:
		return &""
	return StringName(_animation_player.current_animation)


func is_animation_playing(animation_name: StringName = &"") -> bool:
	if _animation_player == null or not _animation_player.is_playing():
		return false
	return animation_name == &"" or get_current_animation() == animation_name


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
	_model_root = get_node_or_null("ModelPivot/ElfModel")
	if _model_root != null:
		var players: Array[Node] = _model_root.find_children("*", "AnimationPlayer", true, false)
		var skeletons: Array[Node] = _model_root.find_children("*", "Skeleton3D", true, false)
		var meshes: Array[Node] = _model_root.find_children("*", "MeshInstance3D", true, false)
		_animation_player = players[0] as AnimationPlayer if not players.is_empty() else null
		_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
		_mesh_instance = meshes[0] as MeshInstance3D if not meshes.is_empty() else null
	_left_socket = find_child("WeaponSocketLeft", true, false) as BoneAttachment3D
	_right_socket = find_child("WeaponSocketRight", true, false) as BoneAttachment3D
	_left_weapon_mount = find_child("WeaponMountLeft", true, false) as Node3D
	_right_weapon_mount = find_child("WeaponMountRight", true, false) as Node3D
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
	animation_finished.emit(animation_name)
	match animation_name:
		ANIM_DEATH:
			death_animation_finished.emit()
		ANIM_HIT:
			hit_reaction_finished.emit()
			play_idle()
		ANIM_CAST_FULL, ANIM_CAST_END:
			play_idle()


func _apply_socket_debug_visibility() -> void:
	if is_instance_valid(_left_debug_marker):
		_left_debug_marker.visible = show_socket_debug
	if is_instance_valid(_right_debug_marker):
		_right_debug_marker.visible = show_socket_debug


func _attach_item_to_mount(item: Node3D, attach_left: bool) -> void:
	if item == null:
		push_warning("ElfVisual3D: tentative d’attachement d’un objet null ignorée.")
		return
	var mount := _left_weapon_mount if attach_left else _right_weapon_mount
	if mount == null:
		push_warning("ElfVisual3D: WeaponMount introuvable, objet non attaché.")
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
