# data/energy_type_data.gd
# ============================================================
# ENERGY TYPE DATA — Définit un TYPE d'énergie (Rage, Foi, Ombre, Nature).
# Resource (.tres) éditable dans l'inspecteur.
#
# L'énergie de Dungeon Draft n'est PAS une mana ni une jauge d'ultime : c'est
# une ressource de FLUX, produite par l'intention tactique, dépensée en continu.
# Ce fichier décrit le "réservoir" : son nom, ses bornes, son point de départ.
# La PRODUCTION (générateurs) et la DÉPENSE (consommateurs) sont ailleurs :
#   - générer/convertir = des Traits qui écoutent le bus
#   - dépenser = des sorts avec un coût en énergie
#
# Pour l'instant : une seule énergie par unité (la Rage pour valider le noyau).
# ------------------------------------------------------------
# POUR CRÉER UN TYPE D'ÉNERGIE :
#   Clic droit dans res://data/energy/ → Nouvelle Resource → "EnergyTypeData".
#   - energy_name   : "Rage"
#   - max_energy    : 100
#   - start_energy  : 50   (on démarre tiède, pas de tour 1 mort)
#   - color         : pour l'UI (jauge rouge pour la Rage...)
# ------------------------------------------------------------

class_name EnergyTypeData
extends Resource

# Nom lisible de l'énergie (UI, logs).
@export var energy_name: String = "Énergie"

# Identifiant interne stable (pour retrouver l'énergie par code/clé).
# Ex: "rage", "foi", "ombre", "nature". Minuscule, sans espace.
@export var energy_id: String = "rage"

# Capacité maximale. Le surplus généré au-delà est PERDU (garde-fou design :
# on ne thésaurise pas à l'infini, le flux a un plafond).
@export var max_energy: float = 100.0

# Énergie au DÉBUT de chaque combat. > 0 = la machine démarre tiède, ce qui
# évite le "tour 1 mort" où l'unité ne peut rien faire faute d'énergie.
@export var start_energy: float = 50.0

# Couleur de la jauge dans l'UI (Rage = rouge, Foi = doré...).
@export var color: Color = Color(0.8, 0.2, 0.2)
