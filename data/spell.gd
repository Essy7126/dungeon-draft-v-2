# data/spell.gd
class_name Spell
extends Resource

enum AoeShape { SINGLE, CROSS, SQUARE, LINE }
enum DamageType { PHYSICAL, MAGICAL }
enum Element { NONE, FIRE, ICE, LIGHTNING, SHADOW, HOLY }

@export var spell_name: String = "Sort sans nom"
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export_group("Presentation")
@export var vfx_scene: PackedScene = null
@export var sound_cast: AudioStream = null

@export_group("Cout et portee")
@export var ap_cost: int = 1
@export var energy_cost: float = 0.0 # Elan
@export var fervor_cost: float = 0.0
@export var energy_generated: float = 0.0
@export_group("Empreinte")
@export var imprint_fervor_cost: float = 0.0
@export var imprint_damage_bonus: int = 0
@export var imprint_heal_bonus: int = 0
@export var imprint_shield_bonus: int = 0
@export var imprint_status: StatusData = null
@export var imprint_terrain_effect: TerrainEffectData = null
@export var charge_verb: String = ""
@export var spell_range: int = 3
@export var needs_line_of_sight: bool = true

@export_group("Cibles autorisees")
@export var can_target_enemy: bool = true
@export var can_target_ally: bool = false
@export var can_target_free_cell: bool = false
@export var can_target_self: bool = false

@export_group("Zone d'effet")
@export var aoe_shape: AoeShape = AoeShape.SINGLE
@export var aoe_size: int = 1

@export_group("Effet de combat")
@export var damage: int = 0
@export var heal: int = 0
@export var damage_type: DamageType = DamageType.MAGICAL
@export var element: Element = Element.NONE
@export_range(0.0, 1.0) var crit_chance: float = 0.0
@export var crit_multiplier: float = 1.5

@export_group("Effet de terrain")
@export var terrain_effect: TerrainEffectData = null

@export_group("Statut applique")
@export var applied_status: StatusData = null

@export_group("Mecanique speciale")
@export var push_distance: int = 0
@export var push_all_adjacent: bool = false
@export var shield_grant: int = 0
@export var bonus_damage_if_marked: int = 0
@export var forces_taunt: bool = false
@export var taunt_duration: int = 1
@export var elan_drain: float = 0.0
@export var fervor_drain: float = 0.0
@export var teleport_behind_target: bool = false
@export var heal_bonus_effect_name: String = ""
@export var heal_bonus_multiplier: float = 1.0

func deals_damage() -> bool:
	return damage > 0

func is_healing() -> bool:
	return heal > 0

func is_generator() -> bool:
	return energy_cost <= 0.0 and fervor_cost <= 0.0

func is_consumer() -> bool:
	return energy_cost > 0.0 or fervor_cost > 0.0

func has_terrain_effect() -> bool:
	return terrain_effect != null

func is_self_only() -> bool:
	return can_target_self and not can_target_enemy \
		and not can_target_ally and not can_target_free_cell
func can_imprint() -> bool:
	return imprint_fervor_cost > 0.0
