
# data/terrain_effect_data.gd
# ============================================================
# TERRAIN EFFECT DATA — Définition d'un effet de terrain (Resource).
# Peut infliger des dégâts ET/OU appliquer un statut (StatusData).
# ============================================================

class_name TerrainEffectData
extends Resource

enum Trigger {
	TURN_START,   # quand une unité COMMENCE son tour sur la case
	ON_ENTER,     # quand une unité ENTRE sur la case
	PASSIVE,      # effet permanent (bloque passage/vue)
}

@export var effect_name: String = "Effet"
@export_multiline var description: String = ""
@export var color: Color = Color(0.5, 0.5, 0.5)

@export_group("Déclenchement")
@export var trigger: Trigger = Trigger.TURN_START
@export var damage: int = 0
@export var damage_over_time: bool = false

# Statut appliqué à l'unité touchée (optionnel).
# Pointe vers une Resource StatusData (poison, stun, slow...).
@export_group("Statut infligé")
@export var applied_status: StatusData = null

@export_group("Propriétés de terrain")
@export var blocks_movement: bool = false
@export var blocks_vision: bool = false

@export_group("Durée")
@export var duration: int = 3
