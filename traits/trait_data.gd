# data/trait_data.gd
# ============================================================
# TRAIT DATA — La fiche d'un trait réglé, sous forme de Resource (.tres).
#
# Un TraitData NE contient PAS la logique du trait (le "fais CECI" reste dans
# le script .gd). Il contient :
#   1. QUEL trait instancier  → une référence directe au script .gd (option B).
#   2. AVEC QUELLES VALEURS    → un dictionnaire de paramètres réglables.
#   3. (confort) un display_name lisible, pour l'inspecteur et les logs.
#
# Ainsi, créer une variante d'un trait = créer un .tres et régler les valeurs,
# SANS toucher au code. Ex : "Vengeance +5" et "Vengeance +10" = deux .tres
# qui pointent vers le même script trait_vengeance.gd, avec un bonus différent.
#
# C'est aussi ce qui permettra à un futur EquipmentData de porter une liste de
# TraitData : tu construis une relique en glissant des traits dans l'inspecteur.
#
# ------------------------------------------------------------
# POUR CRÉER UN TRAIT RÉGLÉ :
#   Clic droit dans res://data/traits/ → Nouvelle Resource → "TraitData".
#   - trait_script : glisse le fichier .gd du trait (ex: trait_vengeance.gd).
#   - display_name : un nom lisible (ex: "Vengeance").
#   - params : remplis les valeurs réglables (ex: { "attack_bonus": 5.0 }).
# ------------------------------------------------------------

class_name TraitData
extends Resource

# Le script du trait à instancier. On glisse ici un fichier .gd qui hérite
# de Trait (ex: trait_vengeance.gd). Référence directe = aucune table à tenir.
@export var trait_script: Script = null

# Nom lisible (inspecteur, logs, futurs tooltips joueur). Purement cosmétique.
@export var display_name: String = "Trait"

# Description courte pour les choix de draft / recompense.
@export var description: String = ""

# Paramètres réglables passés au trait à sa création. Les clés correspondent
# aux variables que le trait sait lire (ex: { "attack_bonus": 5.0 }).
# Laisser vide = le trait utilise ses valeurs par défaut.
@export var params: Dictionary = {}
