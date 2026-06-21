# data/run_data.gd
# ============================================================
# RUN DATA — Définition d'un run complet.
# Contient la liste ordonnée des salles à traverser.
# Configurable entièrement dans l'inspecteur sans toucher au code.
# ============================================================

class_name RunData
extends Resource

@export var run_name: String = "Run"
@export var rooms: Array[RoomData] = []
