# traits/trait_second_nature.gd
# ============================================================
# SECONDE NATURE — plus de reserve, depart plus lent.
#
# Migration PA : l'ancien "+20 max Elan, -10 a l'ouverture" devient
# "+1 PA max permanent, -1 PA au premier tour du combat". Meme profil :
# le porteur agit plus par tour en regime de croisiere, mais demarre engourdi.
# ============================================================

class_name TraitSecondNature
extends Trait

var max_ap_bonus: float = 1.0
var opening_ap_penalty: int = 1

func _trait_name() -> String:
	return "trait_second_nature"

func configure(params: Dictionary) -> void:
	max_ap_bonus = params.get("max_ap_bonus", max_ap_bonus)
	opening_ap_penalty = int(params.get("opening_ap_penalty", opening_ap_penalty))

func _activate() -> void:
	if owner == null:
		return
	owner.max_ap.add_modifier(max_ap_bonus, Stat.ModType.FLAT, source_id, -1)
	# Le malus d'ouverture s'applique au prochain start_turn (= 1er tour).
	owner.next_turn_ap_modifier -= maxi(0, opening_ap_penalty)
	owner.stats_changed.emit(owner)

func _deactivate() -> void:
	# Les modifiers poses via source_id sont retires par _cleanup_modifiers.
	if owner != null:
		owner.stats_changed.emit(owner)
