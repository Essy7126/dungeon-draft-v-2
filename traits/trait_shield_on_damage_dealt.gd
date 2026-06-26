class_name TraitShieldOnDamageDealt
extends Trait

var shield_ratio: float = 0.35
var minimum_shield: int = 1
var generate_protect: bool = true

func _trait_name() -> String:
	return "trait_shield_on_damage_dealt"

func configure(params: Dictionary) -> void:
	shield_ratio = params.get("shield_ratio", shield_ratio)
	minimum_shield = params.get("minimum_shield", minimum_shield)
	generate_protect = params.get("generate_protect", generate_protect)

func _activate() -> void:
	EventBus.damage_dealt.connect(_on_damage_dealt)

func _deactivate() -> void:
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)

func _on_damage_dealt(_target, attacker, amount: int, _category, _element, _is_crit) -> void:
	if attacker != owner or owner == null or amount <= 0 or not owner.is_alive:
		return
	var shield_amount := maxi(minimum_shield, int(round(float(amount) * shield_ratio)))
	owner.add_shield(shield_amount)
	if generate_protect and owner.has_energy():
		owner.generate_fervor_from_verb(EnergyTypeData.VERB_PROTECT, source_id)