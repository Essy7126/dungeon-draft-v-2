class_name ElfVisual3D
extends CharacterVisual3D

const ANIM_IDLE: StringName = &"Elf_Idle"
const ANIM_WALK: StringName = &"Elf_Walk"
const ANIM_RUN: StringName = &"Elf_Run"
const ANIM_CAST_FULL: StringName = &"Elf_Cast_Full"
const ANIM_CAST_START: StringName = &"Elf_Cast_Start"
const ANIM_CAST_HOLD: StringName = &"Elf_Cast_Hold"
const ANIM_CAST_END: StringName = &"Elf_Cast_End"
const ANIM_HIT: StringName = &"Elf_Hit"
const ANIM_DEATH: StringName = &"Elf_Death"
# Extrait du FBX provisoire Icebound Ranger. Les 24 noms d'os correspondent
# au rig de production ; seul le préfixe de piste a été remappé.
const ANIM_BOW_SHOT: StringName = &"Armature|Armature|Archery_Shot_3|baselayer"
const BOW_SHOT_ANIMATION: Animation = preload(
	"res://assets/characters/elf/animations/elf_bow_shot_animation.tres"
)

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

@export_range(0.0, 1.0, 0.01)
var bow_shot_release_normalized_time := 0.60


func _init() -> void:
	model_root_path = NodePath("ModelPivot/ElfModel")
	animation_idle = ANIM_IDLE
	animation_walk = ANIM_WALK
	animation_run = ANIM_RUN
	animation_cast = ANIM_CAST_FULL
	animation_cast_start = ANIM_CAST_START
	animation_cast_hold = ANIM_CAST_HOLD
	animation_cast_end = ANIM_CAST_END
	animation_hit = ANIM_HIT
	animation_death = ANIM_DEATH
	cast_release_time_seconds = -1.0
	cast_release_normalized_time = 0.32
	left_mount_node_name = &"WeaponMountLeft"
	right_mount_node_name = &"WeaponMountRight"


func _setup_profile_sockets() -> void:
	var player := get_animation_player()
	if player == null or player.has_animation(ANIM_BOW_SHOT):
		return
	var library := player.get_animation_library(&"")
	if library == null:
		library = AnimationLibrary.new()
		player.add_animation_library(&"", library)
	library.add_animation(ANIM_BOW_SHOT, BOW_SHOT_ANIMATION.duplicate(true))


func play_bow_shot(speed_scale: float = 1.0) -> bool:
	return play_animation_with_release(
		ANIM_BOW_SHOT,
		bow_shot_release_normalized_time,
		-1.0,
		speed_scale,
		0.1
	)


func is_cast_animation(animation_name: StringName) -> bool:
	return animation_name == ANIM_BOW_SHOT or super.is_cast_animation(animation_name)
