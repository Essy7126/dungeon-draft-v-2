# data/rewards/reward_data.gd
# ============================================================
# REWARD DATA — Définition d'une récompense (Resource).
# Un .tres éditable sans coder, comme les sorts/unités/terrain.
#
# Une récompense est une COMBINAISON d'effets. On ne remplit que les
# champs utiles ; les autres restent neutres. Une bénédiction simple
# n'a qu'un effet. Une malédiction combine un bonus ET un malus (et/ou
# un statut permanent type saignement).
#
# Pour créer une récompense : clic droit dans res://data/rewards/ →
# Nouvelle Resource → "RewardData" → remplis les champs.
# ============================================================

class_name RewardData
extends Resource

# Quelle(s) unité(s) la récompense affecte.
enum Target {
	CHOICE,      # le joueur choisit le héros sur l'écran de récompense
	ALL,         # toute l'équipe
	LOWEST_HP,   # le héros le plus blessé (automatique)
	HIGHEST_HP,  # le héros le plus en forme (automatique)
}

# Quelle stat un effet modifie. NONE = pas d'effet de stat.
enum StatKind { NONE, MAX_HP, ATTACK, MAX_MP, MAX_AP, INITIATIVE }

# ============================================================
# IDENTITÉ
# ============================================================

@export var reward_name: String = "Récompense"
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var target: Target = Target.CHOICE
@export_enum("Commune:0", "Rare:1", "Épique:2") var rarity: int = 0

# ============================================================
# EFFETS (on remplit seulement ce qui sert)
# ============================================================

@export_group("Soin immédiat")
# Soigne la/les cible(s) de ce montant, tout de suite.
@export var heal_amount: int = 0

@export_group("Bonus de stat (effet principal)")
@export var stat: StatKind = StatKind.NONE
@export var stat_amount: float = 0.0
# false = valeur plate (+5) ; true = pourcentage (+0.30 = +30%).
@export var stat_is_percent: bool = false

@export_group("Malus de stat (pour les malédictions)")
# Mets une valeur NÉGATIVE ici (ex: -20 PV max, ou -0.15 = -15%).
@export var malus_stat: StatKind = StatKind.NONE
@export var malus_amount: float = 0.0
@export var malus_is_percent: bool = false

@export_group("Nouveau sort")
@export var spell: Spell = null

@export_group("Statut permanent (ex: saignement de malédiction)")
# Pointe vers un StatusData (ex: saignement -2 PV/tour, durée très longue).
@export var status: StatusData = null

# La récompense demande-t-elle au joueur de choisir un héros ?
func needs_hero_choice() -> bool:
	return target == Target.CHOICE
