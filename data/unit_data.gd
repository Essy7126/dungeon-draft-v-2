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
# Force : colonne de Rage (placement). Scale distance de poussee, degats de
# collision/hasard et energie gagnee sur deplacement. 0 = pas d'ecole placement.
@export var force: float = 0.0

# ============================================================
# DÉFENSE (Couche 1)
# ============================================================

@export_group("Défense")
# Armure : mitigation des dégâts PHYSIQUES. Formule à rendement
# décroissant (armure/(armure+100)) : 100 → 50%, 200 → 66%. Jamais 100%.
@export var armure: float = 0.0
# Résistance magique : idem pour les dégâts MAGIQUES.
@export var resist_magique: float = 0.0
# Esquive : proba (0.0–1.0) d'annuler complètement un coup.
@export_range(0.0, 1.0) var esquive: float = 0.0
# Résistances élémentaires : dictionnaire { Spell.Element → pourcentage }.
# Ex : { 1: 0.5 } = -50% de dégâts de feu (FIRE=1 dans l'enum Spell.Element).
# Valeur négative = vulnérabilité. Ne remplis que les éléments utiles.
@export var resistances: Dictionary = {}

# ============================================================
# CRITIQUE (Couche 1)
# ============================================================

@export_group("Critique")
# Chance de critique de base de l'unité (0.0–1.0). S'ajoute au crit du sort.
@export_range(0.0, 1.0) var crit_chance: float = 0.0
# Multiplicateur de dégâts en cas de critique.
@export var crit_multi: float = 1.5

# ============================================================
# ÉNERGIE (économie d'action — remplace les PA)
# ============================================================

@export_group("Énergie")
# Le type d'énergie de cette unité (Rage, Foi, Ombre, Nature). Glisse ici un
# EnergyTypeData. Laisser VIDE = unité sans énergie (ennemi simple par ex.).
@export var energy_type: EnergyTypeData = null

@export_group("Traits")
@export var chassis_trait: TraitData = null
@export var starting_traits: Array[TraitData] = []

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
# Override IA avance, utilisable sur un boss OU un ennemi normal.
# Si rempli, il REMPLACE l'ai_behavior standard et peut contenir un etat interne.
@export var boss_behavior: BossBehavior = null
