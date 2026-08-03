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

@export var unit_id: StringName = &""
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
# Force reste une statistique de placement : elle module les poussees,
# attractions et collisions. Elle n'est rattachee a aucune ressource speciale.
@export var force: float = 0.0
# Direction logique initiale (facing) au spawn. Sert aux mecaniques directionnelles
# (ex: boss qui durcit de face). Ecrasee des le premier deplacement reel de l'unite.
@export var facing_dir: Vector2i = Vector2i(0, 1)

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
# APPARENCE
# ============================================================

@export_group("Apparence")
# Le sprite animé propre à cette unité.
@export var sprite_frames: SpriteFrames = null
# Échelle du sprite (pour ajuster la taille du pixel art).
@export var sprite_scale: float = 3.0
# Nom de l'animation à jouer par défaut (idle).
@export var idle_animation: String = "default"
# Scene visuelle optionnelle instanciee par UnitView. Si elle est vide, le
# rendu historique de l'unite reste le fallback.
@export var visual_scene: PackedScene = null
@export var preview_visual_scene: PackedScene = null

@export_group("Presentation")
@export var role: String = ""
@export_multiline var presentation_summary: String = ""
@export var progression_summary: String = ""
@export var presentation_badge: String = ""

# ============================================================
# SORTS
# ============================================================

@export_group("Progression")
@export var disciplines: Array[DisciplineData] = []

@export_group("Sorts")
@export var basic_attack_enabled: bool = true
@export_range(1, 12, 1) var active_spell_slots: int = 4
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
@export_enum("Melee:0", "Ranged:1") var combat_style: int = 0
@export_range(1, 20, 1) var preferred_range: int = 1
@export_range(1, 20, 1) var minimum_range: int = 1
@export_range(1, 20, 1) var maximum_range: int = 1
@export var keep_distance: bool = false
@export var ai_profile: EnemyAIProfile = null

@export_group("Faction tactique")
@export var faction_id: StringName = &""
@export var tactical_role_id: StringName = &""
@export var linked_commander_role_id: StringName = &""

@export_group("Passifs de proximite")
@export var proximity_armor_source: StringName = &""
@export var proximity_armor_per_living_neighbor: int = 0
@export var proximity_armor_max_neighbors: int = 0

@export_group("Resistance au deplacement force")
@export var first_forced_movement_reduction_per_activation: int = 0


func get_effective_unit_id() -> StringName:
	if unit_id != &"":
		return unit_id
	if resource_path != "":
		return StringName(resource_path)
	return &"unit_data:unassigned"
