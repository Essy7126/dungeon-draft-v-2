# traits/trait_elan_on_turn_start.gd
# ============================================================
# FERVEUR AU DEBUT DU TOUR — reliques de tempo (Ferveur brute, Reflexe...).
#
# L'intention d'origine ("un peu plus de ressource en debut de tour") se
# traduit en JAUGE d'ecole : le porteur genere `amount` Ferveur au debut de
# son tour (ou une seule fois par combat si once_per_combat). Le nom de
# fichier est conserve (regle : ne jamais deplacer un .gd, les .tres le
# referencent par chemin).
# ============================================================

class_name TraitElanOnTurnStart
extends Trait

var amount: float = 5.0
var once_per_combat: bool = false
var _used: bool = false

func _trait_name() -> String:
	return "trait_elan_on_turn_start"

func configure(params: Dictionary) -> void:
	amount = params.get("amount", amount)
	once_per_combat = params.get("once_per_combat", once_per_combat)

func _activate() -> void:
	EventBus.turn_started.connect(_on_turn_started)

func _deactivate() -> void:
	if EventBus.turn_started.is_connected(_on_turn_started):
		EventBus.turn_started.disconnect(_on_turn_started)

func _on_turn_started(unit) -> void:
	if unit != owner or owner == null or amount <= 0.0:
		return
	if not owner.has_energy():
		return
	if once_per_combat and _used:
		return
	_used = true
	owner.generate_energy(amount, source_id)
