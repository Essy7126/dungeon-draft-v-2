@tool
class_name EnemyAIProfile
extends Resource

## Profil tactique data-driven. EnemyAI interprete une strategie generique ;
## les seuils, roles et preferences d'equilibrage restent dans les Resources.
enum Strategy {
	GENERIC_MELEE,
	GENERIC_RANGED,
	GENERIC_HEALER,
	FORMATION_MELEE,
	GUARDIAN_CHIEF,
	RANGED_COMMANDER,
	SUPPORT_MAGE,
}

@export var profile_id: StringName = &""
@export var strategy: Strategy = Strategy.GENERIC_MELEE

@export_group("Roles tactiques")
@export var marked_status_id: StringName = &"centurion_mark"
@export var normal_role_id: StringName = &"skeleton_normal"
@export var chief_role_id: StringName = &"skeleton_chief"
@export var commander_role_id: StringName = &"skeleton_centurion"

@export_group("Seuils")
@export_range(0.0, 1.0, 0.01) var sentence_hp_ratio_threshold: float = 0.60
@export var commander_emergency_hp: int = 75
@export var summon_when_normals_below: int = 2

@export_group("Placement")
@export var ideal_minimum_range: int = 4
@export var ideal_maximum_range: int = 6
@export var avoid_hero_adjacency: bool = true
@export var prefer_living_neighbors: bool = false
@export var protect_commander_paths: bool = false
@export var commander_distance_penalty_per_cell: int = 0
@export var commander_path_block_bonus: int = 0

@export_group("Soutien")
@export_range(0.0, 1.0, 0.01) var support_heal_threshold: float = 0.70
@export var support_protection_distance: int = 3
