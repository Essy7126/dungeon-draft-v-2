class_name TerrainEffectData
extends Resource

enum Trigger {
	TURN_START,
	ON_ENTER,
	PASSIVE,
}

enum SameSurfacePolicy {
	IGNORE,
	REFRESH_DURATION,
	REPLACE,
}

@export var effect_name: String = "Effet"
@export_multiline var description: String = ""
@export var color: Color = Color(0.5, 0.5, 0.5)

@export_group("Identifiants runtime stables")
@export var surface_id: StringName = &""
@export var visual_terrain_id: StringName = &""
@export var same_surface_policy: SameSurfacePolicy = SameSurfacePolicy.IGNORE

@export_group("Declenchement")
@export var trigger: Trigger = Trigger.TURN_START
@export var damage: int = 0
@export var damage_over_time: bool = false
@export var damage_type: Spell.DamageType = Spell.DamageType.MAGICAL
@export var element: Spell.Element = Spell.Element.NONE
@export var ignores_defense := false
@export var can_be_dodged := true

@export_group("Statut inflige")
@export var applied_status: StatusData = null

@export_group("Proprietes de terrain")
@export var blocks_movement: bool = false
@export var blocks_vision: bool = false
@export var cell_type: int = -1
@export var dangerous_for_ai: bool = false
@export var ai_danger_weight: float = 0.0

@export_group("Duree")
@export var duration: int = 3
