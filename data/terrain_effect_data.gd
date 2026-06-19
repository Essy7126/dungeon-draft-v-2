# data/terrain_effect_data.gd
# ============================================================
# TERRAIN EFFECT DATA — Définition d'un effet de terrain (Resource).
#
# Comme les sorts et les unités : un fichier .tres éditable sans coder.
# Pour créer un effet : clic droit dans res://data/terrain/ →
# Nouvelle Resource → "TerrainEffectData" → remplis les champs.
#
# Le moteur terrain_effects.gd lit ces données et applique le comportement.
# Ajouter un nouvel effet = créer un fichier, AUCUN code.
# ============================================================

class_name TerrainEffectData
extends Resource

# ============================================================
# DÉCLENCHEUR — quand l'effet agit
# ============================================================

enum Trigger {
	TURN_START,   # quand une unité COMMENCE son tour sur la case
	ON_ENTER,     # quand une unité ENTRE sur la case (déplacement)
	PASSIVE,      # effet permanent (bloque passage/vue, pas d'action ponctuelle)
}

# ============================================================
# STATUT appliqué à l'unité touchée (optionnel)
# ============================================================

enum StatusEffect {
	NONE,
	STUN,    # l'unité saute son prochain tour
	SLOW,    # l'unité a moins de PM (à implémenter)
}

# ============================================================
# IDENTITÉ
# ============================================================

@export var effect_name: String = "Effet"
@export_multiline var description: String = ""

# Couleur de rendu de la case (en attendant les vrais tiles).
@export var color: Color = Color(0.5, 0.5, 0.5)

# ============================================================
# DÉCLENCHEMENT ET DÉGÂTS
# ============================================================

@export_group("Déclenchement")
@export var trigger: Trigger = Trigger.TURN_START

# Dégâts infligés à chaque déclenchement.
@export var damage: int = 0

# Si vrai : dégâts sur la durée (feu). Si faux : dégâts directs (lave).
# (le feu inflige damage chaque tour pendant sa durée ; la lave fait mal immédiatement)
@export var damage_over_time: bool = false

# ============================================================
# STATUT INFLIGÉ
# ============================================================

@export_group("Statut infligé")
@export var status: StatusEffect = StatusEffect.NONE
@export var status_duration: int = 1   # en tours (glace = stun 1 tour)

# ============================================================
# PROPRIÉTÉS PASSIVES (terrain qui bloque)
# ============================================================

@export_group("Propriétés de terrain")
@export var blocks_movement: bool = false   # infranchissable (mur de glace)
@export var blocks_vision: bool = false     # bloque la ligne de vue (fumée)

# ============================================================
# DURÉE DE VIE DE L'EFFET SUR LA CASE
# ============================================================

@export_group("Durée")
@export var duration: int = 3   # combien de tours l'effet reste sur la case (-1 = permanent)
