class_name WarriorVisual3D
extends CharacterVisual3D

const DEFAULT_ANIMATION_SET: CharacterAnimationSetData = preload(
	"res://data/characters/warrior/animations.tres"
)
const ANIM_IDLE: StringName = &"DD_Warrior_Idle"
const ANIM_WALK: StringName = &"DD_Warrior_Walk"
const ANIM_RUN: StringName = &"DD_Warrior_Run"
const ANIM_ATTACK: StringName = &"DD_Warrior_Attack"
const ANIM_SPIN_ATTACK: StringName = &"DD_Warrior_SpinAttack"
const ANIM_HEAVY_ATTACK: StringName = &"DD_Warrior_HeavyAttack"
const ANIM_PARRY: StringName = &"DD_Warrior_Parry"
const ANIM_HIT: StringName = &"DD_Warrior_Hit"
const ANIM_DEATH: StringName = &"DD_Warrior_Death"

# Cadence de presentation visee (les Actions importees restent intactes) :
# Attack 1.20 s, Spin 1.45 s, Heavy 1.65 s, Parry 0.80 s,
# Hit 0.65 s et Death 2.00 s.
const ATTACK_SPEED := 4.944444
const SPIN_SPEED := 3.908046
const HEAVY_SPEED := 2.646465
const PARRY_SPEED := 0.708333
const HIT_SPEED := 1.897436
const DEATH_SPEED := 1.483333

# The imported artistic impact frames are retained as normalized positions.
# Playback speed changes only the presentation duration, never gameplay damage.
const IMPACT_BY_ANIMATION := {
	ANIM_ATTACK: 0.7191,
	ANIM_SPIN_ATTACK: 0.2294,
	ANIM_HEAVY_ATTACK: 0.3511,
	ANIM_PARRY: 0.5879,
}

const SPEED_BY_ANIMATION := {
	ANIM_ATTACK: ATTACK_SPEED,
	ANIM_SPIN_ATTACK: SPIN_SPEED,
	ANIM_HEAVY_ATTACK: HEAVY_SPEED,
	ANIM_PARRY: PARRY_SPEED,
	ANIM_HIT: HIT_SPEED,
	ANIM_DEATH: DEATH_SPEED,
}

const IMPORTED_ANIMATIONS: Array[StringName] = [
	ANIM_IDLE,
	ANIM_WALK,
	ANIM_RUN,
	ANIM_ATTACK,
	ANIM_SPIN_ATTACK,
	ANIM_HEAVY_ATTACK,
	ANIM_PARRY,
	ANIM_HIT,
	ANIM_DEATH,
]

# Stable spell IDs are the production API. Resource paths are a compatibility
# fallback for historical spell resources that predate Spell.spell_id.
const ANIMATION_BY_SPELL_ID := {
	&"warrior_heavy_strike": ANIM_HEAVY_ATTACK,
	&"warrior_charge": ANIM_RUN,
	&"warrior_whirlwind": ANIM_SPIN_ATTACK,
	&"warrior_guard": ANIM_PARRY,
}

const SPELL_ID_BY_RESOURCE_PATH := {
	"res://data/spells/Guerrier/frappe_lourde.tres": &"warrior_heavy_strike",
	"res://data/spells/Guerrier/charge.tres": &"warrior_charge",
	"res://data/spells/Guerrier/tourbillon.tres": &"warrior_whirlwind",
	"res://data/spells/Guerrier/garde.tres": &"warrior_guard",
}


func _init() -> void:
	model_root_path = NodePath("ModelPivot/WarriorModel")
	default_animation_set = DEFAULT_ANIMATION_SET
	cast_release_time_seconds = -1.0
	cast_release_normalized_time = IMPACT_BY_ANIMATION[ANIM_ATTACK]
	left_mount_node_name = &"WeaponMountLeft"
	right_mount_node_name = &"WeaponMountRight"


func play_basic_attack(speed_scale: float = ATTACK_SPEED) -> bool:
	if is_death_locked():
		return false
	return play_animation_with_release(
		ANIM_ATTACK,
		IMPACT_BY_ANIMATION[ANIM_ATTACK],
		-1.0,
		speed_scale,
		0.08
	)


func play_spell_action(spell: Spell = null) -> bool:
	if is_death_locked():
		return false
	var animation_name := get_animation_for_spell(spell)
	var speed_scale: float = SPEED_BY_ANIMATION.get(animation_name, ATTACK_SPEED)
	var impact_normalized: float = IMPACT_BY_ANIMATION.get(animation_name, 0.5)
	return play_animation_with_release(
		animation_name,
		impact_normalized,
		-1.0,
		speed_scale,
		0.08
	)


func cancel_spell_action() -> void:
	if not is_death_locked():
		reset_to_idle()


func get_animation_for_spell(spell: Spell = null) -> StringName:
	if spell == null:
		return ANIM_ATTACK
	var spell_id := spell.get_effective_spell_id()
	if ANIMATION_BY_SPELL_ID.has(spell_id):
		return ANIMATION_BY_SPELL_ID[spell_id]
	if not spell.resource_path.is_empty():
		var fallback_id: StringName = SPELL_ID_BY_RESOURCE_PATH.get(
			spell.resource_path,
			&""
		)
		if ANIMATION_BY_SPELL_ID.has(fallback_id):
			return ANIMATION_BY_SPELL_ID[fallback_id]
	return ANIM_ATTACK


func get_playback_speed_for_spell(spell: Spell = null) -> float:
	return SPEED_BY_ANIMATION.get(get_animation_for_spell(spell), ATTACK_SPEED)


func get_impact_normalized_for_spell(spell: Spell = null) -> float:
	return IMPACT_BY_ANIMATION.get(get_animation_for_spell(spell), 0.5)


func get_calibrated_duration(animation_name: StringName) -> float:
	var player := get_animation_player()
	if player == null or not player.has_animation(animation_name):
		return 0.0
	return player.get_animation(animation_name).length / float(
		SPEED_BY_ANIMATION.get(animation_name, 1.0)
	)


func play_hit(speed_scale: float = HIT_SPEED) -> bool:
	return super.play_hit(speed_scale)


func play_death(speed_scale: float = DEATH_SPEED) -> bool:
	return super.play_death(speed_scale)


func get_default_effect_mount() -> Node3D:
	var impact_mount := find_child("ImpactMount", true, false) as Node3D
	return impact_mount if impact_mount != null else get_right_weapon_mount()


func get_default_cast_mount() -> Node3D:
	return get_default_effect_mount()


func is_cast_animation(animation_name: StringName) -> bool:
	return animation_name in [
		ANIM_ATTACK,
		# La course est une locomotion en temps normal, mais elle constitue une
		# action one-shot lorsqu'elle presente le sort Charge.
		ANIM_RUN,
		ANIM_SPIN_ATTACK,
		ANIM_HEAVY_ATTACK,
		ANIM_PARRY,
	]


func _setup_profile_sockets() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_create_hand_mount(
		skeleton,
		"RightHand",
		"RightHandAttachment",
		"WeaponMountRight",
		true
	)
	_create_hand_mount(
		skeleton,
		"LeftHand",
		"LeftHandAttachment",
		"WeaponMountLeft",
		false
	)


func _create_hand_mount(
		skeleton: Skeleton3D,
		bone_name: String,
		attachment_name: String,
		mount_name: String,
		add_impact_mount: bool
	) -> void:
	if find_child(mount_name, true, false) != null:
		return
	if skeleton.find_bone(bone_name) < 0:
		push_warning("WarriorVisual3D: os requis absent : %s" % bone_name)
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = attachment_name
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	var mount := Node3D.new()
	mount.name = mount_name
	attachment.add_child(mount)
	if add_impact_mount:
		var impact_mount := Node3D.new()
		impact_mount.name = "ImpactMount"
		impact_mount.position = Vector3(0.0, 0.08, 0.0)
		mount.add_child(impact_mount)
