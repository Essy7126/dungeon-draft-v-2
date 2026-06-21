# data/unit_data.gd
# ============================================================
# UNIT DATA — Définition d'un type d'unité sous forme de Resource.
#
# Comme pour les sorts : un fichier .tres éditable dans Godot, sans coder.
# Pour créer une unité : clic droit dans res://data/units/ →
# Nouvelle Resource → "UnitData" → remplis les champs + glisse un sprite.
#
# Chaque unité du jeu (héros, monstre, boss) sera un de ces fichiers.
# ============================================================

class_name UnitData
extends Resource

# ============================================================
# IDENTITÉ
# ============================================================

@export var unit_name: String = "Unité"
@export_multiline var description: String = ""

# Équipe : 0 = joueur (héros), 1 = ennemis.
@export_enum("Joueur:0", "Ennemi:1") var team: int = 0

# ============================================================
# STATS DE BASE
# ============================================================

@export_group("Stats")
@export var max_hp: int = 100
@export var initiative: int = 10
@export var max_ap: int = 6
@export var max_mp: int = 3
@export var attack_power: int = 20

# ============================================================
# APPARENCE
# ============================================================

@export_group("Apparence")
# Le sprite animé propre à cette unité.
@export var sprite_frames: SpriteFrames = null
# Échelle du sprite (pour ajuster la taille du pixel art).
@export var sprite_scale: float = 3.0
# Nom de l'animation à jouer par défaut (idle).
@export var idle_animation: String = "default"

# ============================================================
# SORTS
# ============================================================

@export_group("Sorts")
# Liste des sorts (Resources Spell) que cette unité connaît.
@export var spells: Array[Spell] = []
# ============================================================
# COMPORTEMENT D'IA
# ============================================================

@export_group("Comportement IA")
# Détermine comment l'unité décide ses actions à son tour.
# MELEE  : fonce et frappe au corps-à-corps (comportement par défaut).
# RANGED : garde ses distances, attaque de loin (kiting).
# HEALER : soigne l'allié le plus blessé, évite le combat.
@export_enum("Mêlée:0", "Distance:1", "Soigneur:2") var ai_behavior: int = 0
@export_group("Boss")
# Comportement spécial. Laisse VIDE pour un ennemi normal.
# Si rempli, il REMPLACE l'ai_behavior standard.
@export var boss_behavior: BossBehavior = null
