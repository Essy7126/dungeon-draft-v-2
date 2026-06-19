# data/spell.gd
# ============================================================
# SPELL — Définition d'un sort sous forme de Resource.
# Ciblage flexible : un sort peut accepter plusieurs types de cibles
# (ennemi, allié, case libre, soi) via des cases à cocher.
# ============================================================

class_name Spell
extends Resource

# ============================================================
# ÉNUMÉRATIONS
# ============================================================

enum AoeShape { SINGLE, CROSS, SQUARE, LINE }
enum DamageType { PHYSICAL, MAGICAL }
enum Element { NONE, FIRE, ICE, LIGHTNING, SHADOW, HOLY }
enum TerrainEffect { NONE, LAVA, ICE, SHADOW, RUNE }

# ============================================================
# IDENTITÉ
# ============================================================

@export var spell_name: String = "Sort sans nom"
@export_multiline var description: String = ""
@export var icon: Texture2D = null

# ============================================================
# COÛT ET CIBLAGE
# ============================================================

@export_group("Coût et portée")
@export var ap_cost: int = 2
@export var spell_range: int = 3
@export var needs_line_of_sight: bool = true

# Types de cibles autorisés (cochables, combinables).
@export_group("Cibles autorisées")
@export var can_target_enemy: bool = true       # une unité ennemie
@export var can_target_ally: bool = false       # une unité alliée
@export var can_target_free_cell: bool = false  # une case vide
@export var can_target_self: bool = false       # le lanceur lui-même

# ============================================================
# ZONE D'EFFET (AOE)
# ============================================================

@export_group("Zone d'effet")
@export var aoe_shape: AoeShape = AoeShape.SINGLE
@export var aoe_size: int = 1

# ============================================================
# EFFET DE COMBAT
# ============================================================

@export_group("Effet de combat")
@export var damage: int = 0
@export var heal: int = 0
@export var damage_type: DamageType = DamageType.MAGICAL
@export var element: Element = Element.NONE
@export_range(0.0, 1.0) var crit_chance: float = 0.0
@export var crit_multiplier: float = 1.5

# ============================================================
# EFFET DE TERRAIN
# ============================================================

@export_group("Effet de terrain")
@export var terrain_effect: TerrainEffect = TerrainEffect.NONE
@export var terrain_duration: int = 3

# ============================================================
# BUFF / DEBUFF
# ============================================================

@export_group("Buff / Debuff")
@export var applies_modifier: bool = false
@export var modifier_stat: String = ""
@export var modifier_value: float = 0.0
@export var modifier_is_percent: bool = false
@export var modifier_duration: int = 2

# ============================================================
# OUTILS DE LECTURE
# ============================================================

func deals_damage() -> bool:
	return damage > 0

func is_healing() -> bool:
	return heal > 0

func has_terrain_effect() -> bool:
	return terrain_effect != TerrainEffect.NONE

# Ce sort cible-t-il uniquement le lanceur (pas de sélection de case) ?
func is_self_only() -> bool:
	return can_target_self and not can_target_enemy \
		and not can_target_ally and not can_target_free_cell
