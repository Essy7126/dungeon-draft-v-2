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
