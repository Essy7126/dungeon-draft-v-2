class_name TraitBloodthirst
extends Trait

var heal_ratio: float = 0.25
var fervor_gain: float = 4.0

func _trait_name() -> String:
	return "trait_bloodthirst"

func configure(params: Dictionary) -> void:
	heal_ratio = params.get("heal_ratio", heal_ratio)
	fervor_gain = params.get("fervor_gain", fervor_gain)

func _activate() -> void:
	EventBus.damage_dealt.connect(_on_damage_dealt)

func _deactivate() -> void:
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)

func _on_damage_dealt(_target, attacker, amount: int, _category, _element, _is_crit) -> void:
	if attacker != owner or owner == null or amount <= 0 or not owner.is_alive:
		return
	var heal_amount := maxi(1, int(round(float(amount) * heal_ratio)))
	owner.heal(heal_amount)
	if owner.has_energy() and fervor_gain > 0.0:
		owner.generate_fervor_from_verb(EnergyTypeData.VERB_HEAL, source_id)