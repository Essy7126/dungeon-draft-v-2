class_name SkeletonChiefVisual3D
extends CharacterVisual3D

const ANIM_IDLE: StringName = &"DD_SkeletonChief_Idle"
const ANIM_WALK: StringName = &"DD_SkeletonChief_Walk"
const ANIM_RUN: StringName = &"DD_SkeletonChief_Run"
const ANIM_ATTACK: StringName = &"DD_SkeletonChief_Attack"
const ANIM_HEAVY_ATTACK: StringName = &"DD_SkeletonChief_HeavyAttack"
const ANIM_HIT: StringName = &"DD_SkeletonChief_Hit"
const ANIM_DEATH: StringName = &"DD_SkeletonChief_Death"

const ATTACK_SPEED := 1.0
const HEAVY_ATTACK_SPEED := 1.7
const HIT_SPEED := 1.5
const DEATH_SPEED := 1.3
const ATTACK_IMPACT_NORMALIZED := 0.511111
const HEAVY_IMPACT_NORMALIZED := 0.666667

const IMPORTED_ANIMATIONS: Array[StringName] = [
	ANIM_IDLE,
	ANIM_WALK,
	ANIM_RUN,
	ANIM_ATTACK,
	ANIM_HEAVY_ATTACK,
	ANIM_HIT,
	ANIM_DEATH,
]


func _init() -> void:
	model_root_path = NodePath("ModelPivot/SkeletonChiefModel")
	animation_idle = ANIM_IDLE
	animation_walk = ANIM_WALK
	animation_run = ANIM_RUN
	animation_cast = ANIM_ATTACK
	animation_hit = ANIM_HIT
	animation_death = ANIM_DEATH
	left_mount_node_name = &"EffectOriginLeft"
	right_mount_node_name = &"EffectOriginRight"
	cast_release_time_seconds = -1.0
	cast_release_normalized_time = ATTACK_IMPACT_NORMALIZED


func play_basic_attack(_speed_scale: float = ATTACK_SPEED) -> bool:
	if is_death_locked():
		return false
	return play_animation_with_release(
		ANIM_ATTACK,
		ATTACK_IMPACT_NORMALIZED,
		-1.0,
		ATTACK_SPEED,
		0.10
	)


func play_spell_action(spell: Spell = null) -> bool:
	if is_death_locked() or not is_heavy_strike(spell):
		return false
	return play_animation_with_release(
		ANIM_HEAVY_ATTACK,
		HEAVY_IMPACT_NORMALIZED,
		-1.0,
		HEAVY_ATTACK_SPEED,
		0.10
	)


func play_hit(_speed_scale: float = HIT_SPEED) -> bool:
	return super.play_hit(HIT_SPEED)


func play_death(_speed_scale: float = DEATH_SPEED) -> bool:
	return super.play_death(DEATH_SPEED)


func is_cast_animation(animation_name: StringName) -> bool:
	return animation_name == ANIM_ATTACK or animation_name == ANIM_HEAVY_ATTACK \
		or super.is_cast_animation(animation_name)


func is_heavy_strike(spell: Spell) -> bool:
	return spell != null and spell.visual_action == Spell.VisualAction.HEAVY


func get_calibrated_duration(animation_name: StringName) -> float:
	var player := get_animation_player()
	if player == null or not player.has_animation(animation_name):
		return 0.0
	var speed := 1.0
	match animation_name:
		ANIM_ATTACK:
			speed = ATTACK_SPEED
		ANIM_HEAVY_ATTACK:
			speed = HEAVY_ATTACK_SPEED
		ANIM_HIT:
			speed = HIT_SPEED
		ANIM_DEATH:
			speed = DEATH_SPEED
	return player.get_animation(animation_name).length / speed


func _setup_profile_sockets() -> void:
	_create_hand_effect_origin(&"LeftHand", &"LeftHandEffectAttachment", &"EffectOriginLeft")
	_create_hand_effect_origin(&"RightHand", &"RightHandEffectAttachment", &"EffectOriginRight")


func _create_hand_effect_origin(
		bone_name: StringName,
		attachment_name: StringName,
		origin_name: StringName
	) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or skeleton.find_bone(str(bone_name)) < 0:
		push_warning("SkeletonChiefVisual3D: os %s absent, origine d'effet non creee." % bone_name)
		return
	if skeleton.find_child(str(attachment_name), false, false) != null:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = attachment_name
	attachment.bone_name = str(bone_name)
	skeleton.add_child(attachment)
	var origin := Node3D.new()
	origin.name = origin_name
	attachment.add_child(origin)
