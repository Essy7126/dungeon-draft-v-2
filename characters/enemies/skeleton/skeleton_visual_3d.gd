class_name SkeletonVisual3D
extends CharacterVisual3D

enum CombatStyle {
	MELEE,
	RANGED,
}

# Godot retire volontairement le suffixe d'import glTF "-loop" tout en
# conservant le bouclage des Actions Blender correspondantes.
const ANIM_IDLE: StringName = &"DD_Skeleton_Idle"
const ANIM_WALK: StringName = &"DD_Skeleton_Walk"
const ANIM_RUN: StringName = &"DD_Skeleton_Run"
const ANIM_MELEE: StringName = &"DD_Skeleton_MeleeAttack"
const ANIM_RANGED: StringName = &"DD_Skeleton_RangedAttack"
const ANIM_HIT: StringName = &"DD_Skeleton_Hit"
const ANIM_DEATH: StringName = &"DD_Skeleton_Death"

const MELEE_SPEED := 3.0
const RANGED_SPEED := 5.0
const HIT_SPEED := 8.974359
const DEATH_SPEED := 1.395833
const MELEE_IMPACT_NORMALIZED := 0.244444
const RANGED_RELEASE_NORMALIZED := 0.850575

const IMPORTED_ANIMATIONS: Array[StringName] = [
	ANIM_IDLE,
	ANIM_WALK,
	ANIM_RUN,
	ANIM_MELEE,
	ANIM_RANGED,
	ANIM_HIT,
	ANIM_DEATH,
]

@export var combat_style: CombatStyle = CombatStyle.MELEE


func _init() -> void:
	model_root_path = NodePath("ModelPivot/SkeletonModel")
	animation_idle = ANIM_IDLE
	animation_walk = ANIM_WALK
	animation_run = ANIM_RUN
	animation_hit = ANIM_HIT
	animation_death = ANIM_DEATH
	left_mount_node_name = &"WeaponMountLeft"
	right_mount_node_name = &"WeaponMountRight"
	_apply_combat_style()


func _ready() -> void:
	_apply_combat_style()
	super._ready()


func set_combat_style(value: int) -> void:
	combat_style = value as CombatStyle
	_apply_combat_style()


func play_basic_attack(_speed_scale: float = MELEE_SPEED) -> bool:
	if combat_style != CombatStyle.MELEE or is_death_locked():
		return false
	return play_animation_with_release(
		ANIM_MELEE,
		MELEE_IMPACT_NORMALIZED,
		-1.0,
		MELEE_SPEED,
		0.08
	)


func play_spell_action(_spell: Spell = null) -> bool:
	if combat_style != CombatStyle.RANGED or is_death_locked():
		return false
	return play_animation_with_release(
		ANIM_RANGED,
		RANGED_RELEASE_NORMALIZED,
		-1.0,
		RANGED_SPEED,
		0.08
	)


func play_hit(_speed_scale: float = HIT_SPEED) -> bool:
	return super.play_hit(HIT_SPEED)


func play_death(_speed_scale: float = DEATH_SPEED) -> bool:
	return super.play_death(DEATH_SPEED)


func is_cast_animation(animation_name: StringName) -> bool:
	return animation_name == ANIM_MELEE or animation_name == ANIM_RANGED \
		or super.is_cast_animation(animation_name)


func get_attack_animation() -> StringName:
	return ANIM_RANGED if combat_style == CombatStyle.RANGED else ANIM_MELEE


func get_attack_speed() -> float:
	return RANGED_SPEED if combat_style == CombatStyle.RANGED else MELEE_SPEED


func get_release_normalized_time() -> float:
	return (
		RANGED_RELEASE_NORMALIZED
		if combat_style == CombatStyle.RANGED
		else MELEE_IMPACT_NORMALIZED
	)


func _apply_combat_style() -> void:
	animation_cast = get_attack_animation()
	cast_release_time_seconds = -1.0
	cast_release_normalized_time = get_release_normalized_time()


func _setup_profile_sockets() -> void:
	# Ces BoneAttachment3D ne portent aucun equipement. Ils fournissent seulement
	# des origines d'effet reproductibles sur les os de mains audites dans le GLB.
	_create_hand_origin(&"LeftHand", &"LeftHandEffectAttachment", &"WeaponMountLeft")
	_create_hand_origin(&"RightHand", &"RightHandEffectAttachment", &"WeaponMountRight")


func _create_hand_origin(
		bone_name: StringName,
		attachment_name: StringName,
		mount_name: StringName
	) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or skeleton.find_bone(str(bone_name)) < 0:
		push_warning("SkeletonVisual3D: os %s absent, origine d'effet non creee." % bone_name)
		return
	if skeleton.find_child(str(attachment_name), false, false) != null:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = attachment_name
	attachment.bone_name = str(bone_name)
	skeleton.add_child(attachment)
	var mount := Node3D.new()
	mount.name = mount_name
	attachment.add_child(mount)
