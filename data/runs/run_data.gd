# data/run_data.gd
# ============================================================
# RUN DATA — Définition d'un run complet.
# Contient la liste ordonnée des salles à traverser, et le pool
# de récompenses dans lequel on pioche après chaque salle gagnée.
# Configurable entièrement dans l'inspecteur sans toucher au code.
# ============================================================

class_name RunData
extends Resource

@export var run_name: String = "Run"
@export var rooms: Array[RoomData] = []

# Pool de récompenses : on en tire 3 au hasard après chaque salle gagnée.
# Mélange bénédictions et malédictions pour créer de vrais choix.
@export var reward_pool: Array[RewardData] = []
@export_group("Pools etendus - Bible")
@export var relic_pool: Array[Resource] = []
@export var equipment_pool: Array[Resource] = []
@export var event_pool: Array[Resource] = []
@export var boss_malus_pool: Array[Resource] = []
@export var run_nodes: Array[Resource] = []
