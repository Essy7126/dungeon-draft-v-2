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

const ArenaGenerationProfileScript = preload(
	"res://data/rooms/arena_generation_profile.gd"
)
const ArenaVisualProfileScript = preload(
	"res://data/rooms/arena_visual_profile.gd"
)

@export var room_name: String = "Salle"

@export var background_image: Texture2D

@export var particles_scene: PackedScene

@export var battle_scene: PackedScene

## Regles optionnelles de placement procedural propres a cette salle.
## Si ce champ reste vide, la salle conserve son comportement actuel.
@export var arena_generation_profile: ArenaGenerationProfileScript
@export var arena_visual_profile: ArenaVisualProfileScript

# Configuration optionnelle des salles peintes. Les salles historiques gardent
# ces champs a null et continuent d'utiliser leurs scenes/TileMap existantes.
@export var grid_layout: RoomGridLayout
@export var painted_map_visual_data: PaintedMapVisualData
@export var encounter_definition: EncounterDefinition

## Vagues ordonnees jouees dans cette meme arene. Une liste vide conserve le
## contrat historique : encounter_definition represente alors l'unique vague.
@export var waves: Array[RoomWaveData] = []
# Les ennemis présents dans cette salle.
@export var enemies: Array[UnitData] = []

# Cases autorisées pour le placement des héros (déploiement joueur).
@export var hero_spawn_zone: Array[Vector2i] = []

# Cases autorisées pour l'apparition des ennemis (placement aléatoire).
@export var enemy_spawn_zone: Array[Vector2i] = []


func get_wave_count() -> int:
	if not waves.is_empty():
		return waves.size()
	return 1 if encounter_definition != null or not enemies.is_empty() else 0


func get_wave(wave_index: int) -> RoomWaveData:
	if wave_index < 0 or wave_index >= waves.size():
		return null
	return waves[wave_index]


func get_encounter_for_wave(wave_index: int) -> EncounterDefinition:
	var wave := get_wave(wave_index)
	if wave != null:
		return wave.encounter_definition
	return encounter_definition if wave_index == 0 else null


func get_reward_multiplier_for_wave(wave_index: int) -> float:
	var wave := get_wave(wave_index)
	return wave.reward_multiplier if wave != null else 1.0
