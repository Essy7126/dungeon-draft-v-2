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
