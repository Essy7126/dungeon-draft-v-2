# data/spell.gd
# ============================================================
# SPELL — Définition d'un sort (Resource).
# ============================================================

class_name Spell
extends Resource

enum AoeShape { SINGLE, CROSS, SQUARE, LINE }
enum DamageType { PHYSICAL, MAGICAL }
enum Element { NONE, FIRE, ICE, LIGHTNING, SHADOW, HOLY }

@export var spell_name: String = "Sort sans nom"
@export_multiline var description: String = ""
@export var icon: Texture2D = null

@export_group("Coût et portée")
@export var ap_cost: int = 2
# Coût en ÉNERGIE (Rage, Foi...). L'énergie remplace les PA comme économie
# d'action. 0 = GÉNÉRATEUR (sort gratuit qui sert à lancer le moteur).
# > 0 = CONSOMMATEUR (sort puissant qui dépense l'énergie construite).
@export var energy_cost: float = 0.0
@export var spell_range: int = 3
@export var needs_line_of_sight: bool = true

@export_group("Cibles autorisées")
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
# Le sort peut poser un effet de terrain (Resource TerrainEffectData).
@export var terrain_effect: TerrainEffectData = null

# Dans spell.gd, remplace tout le groupe "Buff / Debuff" par ceci :

@export_group("Statut appliqué")
# Statut infligé aux unités touchées (poison, stun, slow...).
@export var applied_status: StatusData = null

func deals_damage() -> bool:
	return damage > 0

func is_healing() -> bool:
	return heal > 0

# Un GÉNÉRATEUR ne coûte pas d'énergie (il sert à lancer le moteur).
func is_generator() -> bool:
	return energy_cost <= 0.0

# Un CONSOMMATEUR dépense de l'énergie.
func is_consumer() -> bool:
	return energy_cost > 0.0

func has_terrain_effect() -> bool:
	return terrain_effect != null

func is_self_only() -> bool:
	return can_target_self and not can_target_enemy \
		and not can_target_ally and not can_target_free_cell
