# data/status_data.gd
# ============================================================
# STATUS DATA — Définition d'un statut (Resource).
#
# Un fichier .tres éditable sans coder, comme les sorts/unités/terrain.
# Pour créer un statut : clic droit dans res://data/status/ →
# Nouvelle Resource → "StatusData" → remplis les champs.
#
# Couvre : poison, saignement (dégâts/tour), régénération (soin/tour),
# stun (saute le tour), slow (réduit les PM).
# ============================================================

class_name StatusData
extends Resource

# ============================================================
# IDENTITÉ
# ============================================================

@export var status_name: String = "Statut"
@export_multiline var description: String = ""

# Couleur d'indicateur (pour l'UI plus tard : petite icône/halo sur l'unité).
@export var color: Color = Color(0.6, 0.3, 0.8)

# ============================================================
# EFFETS PAR TOUR
# Appliqués au DÉBUT du tour de l'unité affectée.
# ============================================================

@export_group("Effets par tour")
# Dégâts infligés chaque tour (poison, saignement, brûlure).
@export var damage_per_turn: int = 0
# Soin reçu chaque tour (régénération).
@export var heal_per_turn: int = 0

# ============================================================
# EFFETS DE CONTRÔLE
# ============================================================

@export_group("Contrôle")
# L'unité saute entièrement son tour (stun).
@export var skips_turn: bool = false
# Réduction des points de mouvement ce tour (slow). 0 = aucune.
@export var mp_reduction: int = 0
# Réduction des points d'action ce tour. 0 = aucune.
@export var ap_reduction: int = 0

# ============================================================
# DURÉE
# ============================================================

@export_group("Durée")
# Nombre de tours pendant lesquels le statut reste actif.
@export var duration: int = 3
