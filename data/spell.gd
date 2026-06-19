# data/spell.gd
# ============================================================
# SPELL — Définition d'un sort sous forme de Resource.
#
# Une Resource = un fichier de données éditable dans Godot SANS coder.
# Chaque @export devient un champ dans le formulaire de l'éditeur.
#
# Pour créer un sort : clic droit dans res://data/spells/ →
# Nouvelle Resource → cherche "Spell" → remplis les champs → sauvegarde .tres
#
# Tous les champs sont présents dès maintenant. L'implémentation de
# leur effet en combat se fait progressivement (voir spell_caster.gd).
# ============================================================

class_name Spell
extends Resource

# ============================================================
# ÉNUMÉRATIONS (les choix possibles)
# ============================================================

# Qui/quoi le sort peut cibler.
enum TargetType {
	ENEMY,       # une unité ennemie
	ALLY,        # une unité alliée
	FREE_CELL,   # une case libre (pose de terrain, invocation...)
	SELF,        # l'unité qui lance
}

# Forme de la zone d'effet.
enum AoeShape {
	SINGLE,   # une seule case
	CROSS,    # une croix (+ ) de rayon aoe_size
	SQUARE,   # un carré de rayon aoe_size
	LINE,     # une ligne (à implémenter plus tard)
}

# Type de dégâts (pour les résistances futures).
enum DamageType {
	PHYSICAL,
	MAGICAL,
}

# Élément (thématique mythologie).
enum Element {
	NONE,
	FIRE,
	ICE,
	LIGHTNING,
	SHADOW,
	HOLY,
}

# Effet de terrain posé par le sort (correspond aux types de GridData).
enum TerrainEffect {
	NONE,
	LAVA,
	ICE,
	SHADOW,
	RUNE,
}

# ============================================================
# IDENTITÉ
# ============================================================

@export var spell_name: String = "Sort sans nom"
@export_multiline var description: String = ""
@export var icon: Texture2D = null

# ============================================================
# COÛTS ET CIBLAGE
# ============================================================

@export_group("Coût et ciblage")
@export var ap_cost: int = 2
@export var spell_range: int = 3          # portée de ciblage (en cases)
@export var target_type: TargetType = TargetType.ENEMY
@export var needs_line_of_sight: bool = true

# ============================================================
# ZONE D'EFFET (AOE)
# ============================================================

@export_group("Zone d'effet")
@export var aoe_shape: AoeShape = AoeShape.SINGLE
@export var aoe_size: int = 1             # rayon de la zone (1 = la case seule)

# ============================================================
# EFFET DE COMBAT
# ============================================================

@export_group("Effet de combat")
@export var damage: int = 0               # dégâts de base (0 = pas de dégâts)
@export var heal: int = 0                 # soin (0 = pas de soin)
@export var damage_type: DamageType = DamageType.MAGICAL
@export var element: Element = Element.NONE
@export_range(0.0, 1.0) var crit_chance: float = 0.0      # 0.0 à 1.0 (0% à 100%)
@export var crit_multiplier: float = 1.5

# ============================================================
# EFFET DE TERRAIN
# ============================================================

@export_group("Effet de terrain")
@export var terrain_effect: TerrainEffect = TerrainEffect.NONE
@export var terrain_duration: int = 3     # durée en tours (si applicable)

# ============================================================
# BUFF / DEBUFF APPLIQUÉ (lien avec le système de stats)
# Pour l'instant ce sont des champs simples ; on enrichira en Resource
# dédiée quand on implémentera les buffs de sorts.
# ============================================================

@export_group("Buff / Debuff")
@export var applies_modifier: bool = false
@export var modifier_stat: String = ""    # "initiative", "max_mp", etc.
@export var modifier_value: float = 0.0
@export var modifier_is_percent: bool = false
@export var modifier_duration: int = 2

# ============================================================
# OUTILS DE LECTURE
# ============================================================

# Le sort inflige-t-il des dégâts ?
func deals_damage() -> bool:
	return damage > 0

# Le sort soigne-t-il ?
func is_healing() -> bool:
	return heal > 0

# Le sort pose-t-il un effet de terrain ?
func has_terrain_effect() -> bool:
	return terrain_effect != TerrainEffect.NONE
