class_name EnergyTypeData
extends Resource

const VERB_HIT := "HIT"
const VERB_PROTECT := "PROTECT"
const VERB_HEAL := "HEAL"
const VERB_EXPLOIT := "EXPLOIT"
const VERB_TAKE_DAMAGE := "TAKE_DAMAGE"

@export_group("Identite")
@export var energy_name: String = "Ferveur"
@export_multiline var description: String = ""
@export var energy_id: String = "rage"
@export var color: Color = Color(0.8, 0.2, 0.2)
# Couleur d'ECOLE : la couleur officielle de lisibilite (barres, textes
# flottants, fiches). Alpha 0 = non renseignee -> repli sur `color` (legacy).
@export var school_color: Color = Color(0, 0, 0, 0)
# La signature en une phrase : COMMENT cette ecole gagne sa jauge. Doit decrire
# exactement les verbes les plus payants de la gain_table (ne jamais mentir).
@export_multiline var signature_text: String = ""

@export_group("Ferveur")
@export var max_energy: float = 100.0
@export var start_energy: float = 0.0
@export var passive_income_per_tier: float = 0.0
@export var basic_attack_cost: float = 10.0

@export_group("Generation par verbe")
@export var gain_table: Dictionary = {
	VERB_HIT: 0.0,
	VERB_PROTECT: 0.0,
	VERB_HEAL: 0.0,
	VERB_EXPLOIT: 0.0,
	VERB_TAKE_DAMAGE: 0.0,
}
@export var threshold_gain_multipliers: Dictionary = {}

@export_group("Seuil de Ferveur")
@export var threshold: float = 50.0
@export var threshold_exit: float = 30.0
@export var threshold_name: String = "Charge"
@export var threshold_trait: TraitData = null
@export var threshold_damage_reduction_pct: float = 0.0
@export var threshold_shield_multiplier: float = 1.0
@export var threshold_heal_multiplier: float = 1.0
@export var threshold_overheal_to_shield: bool = false
@export var threshold_overheal_shield_multiplier: float = 0.0
@export var threshold_take_damage_gain: float = 0.0
@export var threshold_attack_bonus_pct: float = 0.0
@export var threshold_armure_bonus: float = 0.0
@export var threshold_resist_bonus: float = 0.0
@export var threshold_esquive_bonus: float = 0.0

@export_group("Eveil v2")
@export var awakening_cost: float = 50.0
@export var awakening_duration_turns: int = 2
@export var awakening_damage_multiplier: float = 1.0
@export var awakening_incoming_damage_multiplier: float = 1.0
@export var awakening_shield_multiplier: float = 1.0
@export var awakening_heal_multiplier: float = 1.0
@export var awakening_imprint_discount: float = 0.0
@export var awakening_blocks_healing: bool = false
@export var awakening_blocks_direct_damage: bool = false
@export var awakening_blocks_shield: bool = false
# PA en moins pendant l'Eveil (le prix a payer pour l'etat surpuissant).
@export var awakening_ap_penalty: int = 0
@export var awakening_terrain_duration_multiplier: float = 1.0

@export_group("Reaction v2")
@export var reaction_cost: float = 25.0
@export var reaction_damage_multiplier: float = 0.5
# PA bonus au prochain tour quand la reaction se declenche.
@export var reaction_next_turn_ap_bonus: int = 1

# Couleur d'ecole effective : school_color si renseignee, sinon l'ancienne
# `color` — une seule source de verite pour toute l'UI.
func get_school_color() -> Color:
	return school_color if school_color.a > 0.0 else color

func get_signature_text() -> String:
	return signature_text.strip_edges()

func gain_for(verb: String) -> float:
	var key := verb.strip_edges().to_upper()
	return float(gain_table.get(key, 0.0))

func gain_multiplier_for(verb: String, threshold_active: bool) -> float:
	if not threshold_active:
		return 1.0
	var key := verb.strip_edges().to_upper()
	return float(threshold_gain_multipliers.get(key, 1.0))

func passive_income_for_tier(tier: int) -> float:
	return float(maxi(1, tier)) * passive_income_per_tier