class_name MageVisual3D
extends CharacterVisual3D

const DEFAULT_ANIMATION_SET: CharacterAnimationSetData = preload(
	"res://data/characters/mage/animations.tres"
)
const ANIM_IDLE: StringName = &"DD_Mage_Idle"
const ANIM_WALK: StringName = &"DD_Mage_Walk"
const ANIM_RUN: StringName = &"DD_Mage_Run"
const ANIM_CAST: StringName = &"DD_Mage_Cast"
const ANIM_HIT: StringName = &"DD_Mage_Hit"
const ANIM_DEATH: StringName = &"DD_Mage_Death"
const CAST_RELEASE_TIME := 0.933333

const IMPORTED_ANIMATIONS: Array[StringName] = [
	ANIM_IDLE,
	ANIM_WALK,
	ANIM_RUN,
	ANIM_CAST,
	ANIM_HIT,
	ANIM_DEATH,
]


func _init() -> void:
	model_root_path = NodePath("ModelPivot/MageModel")
	default_animation_set = DEFAULT_ANIMATION_SET
	cast_release_time_seconds = CAST_RELEASE_TIME
	left_mount_node_name = &"CastSupportMount"
	right_mount_node_name = &"ProjectileMount"


func get_projectile_mount() -> Node3D:
	return get_right_weapon_mount()


func get_cast_support_mount() -> Node3D:
	return get_left_weapon_mount()


func _setup_profile_sockets() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_create_hand_mount(skeleton, "RightHand", "RightHandAttachment", "ProjectileMount", 0.085)
	_create_hand_mount(skeleton, "LeftHand", "LeftHandAttachment", "CastSupportMount", 0.075)


func _create_hand_mount(
		skeleton: Skeleton3D,
		bone_name: String,
		attachment_name: String,
		mount_name: String,
		height: float
	) -> void:
	if find_child(mount_name, true, false) != null or skeleton.find_bone(bone_name) < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = attachment_name
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	var mount := Node3D.new()
	mount.name = mount_name
	mount.position = Vector3(0.0, height, 0.0)
	attachment.add_child(mount)
