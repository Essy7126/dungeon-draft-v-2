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

# Configuration optionnelle des salles peintes. Les salles historiques gardent
# ces champs a null et continuent d'utiliser leurs scenes/TileMap existantes.
@export var grid_layout: RoomGridLayout
@export var painted_map_visual_data: PaintedMapVisualData
@export var encounter_definition: EncounterDefinition
# Les ennemis présents dans cette salle.
@export var enemies: Array[UnitData] = []

# Cases autorisées pour le placement des héros (déploiement joueur).
@export var hero_spawn_zone: Array[Vector2i] = []

# Cases autorisées pour l'apparition des ennemis (placement aléatoire).
@export var enemy_spawn_zone: Array[Vector2i] = []
