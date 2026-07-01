# data/room_data.gd
# ============================================================
# ROOM DATA — Définition d'une salle (Resource).
# Contient les ennemis de la salle et les zones de déploiement.
#
# Les positions ne sont PAS fixes : ce sont des POOLS de cases.
#   - hero_spawn_zone  : cases où le joueur pourra placer ses héros
#   - enemy_spawn_zone : cases où les ennemis apparaissent (aléatoire)
#
# Pour créer une salle : clic droit dans res://data/rooms/ →
# Nouvelle Resource → "RoomData" → remplis les listes.
# ============================================================

class_name RoomData
extends Resource

@export var room_name: String = "Salle"

@export var background_image: Texture2D

@export var particles_scene: PackedScene

@export var battle_scene: PackedScene
# Les ennemis présents dans cette salle.
@export var enemies: Array[UnitData] = []

# Cases autorisées pour le placement des héros (déploiement joueur).
@export var hero_spawn_zone: Array[Vector2i] = []

# Cases autorisées pour l'apparition des ennemis (placement aléatoire).
@export var enemy_spawn_zone: Array[Vector2i] = []

# ============================================================
# SALLE-SITUATION (optionnel) — menace qui s'aggrave + objectif != tuer tout.
# Si situation_totem est défini, battle instancie un SituationRoomController :
# le totem (immobile) spawn un renfort tous les N rounds, la lave s'étend d'1
# case/round (plafonnée), et détruire le totem = victoire. Laisser vide = salle
# classique.
# ============================================================
@export_group("Salle-situation")
@export var situation_totem: UnitData = null      # la source coupable (immobile, destructible)
@export var situation_spawn: UnitData = null      # le renfort spawné périodiquement
@export var situation_totem_cell: Vector2i = Vector2i(-1, -1)
@export var situation_spawn_period: int = 2       # 1 renfort tous les N rounds
@export var situation_lava_effect: TerrainEffectData = null
@export var situation_lava_origin: Vector2i = Vector2i(-1, -1)
@export var situation_lava_cap: int = 8           # nombre max de cases de lave (anti-invasion)
