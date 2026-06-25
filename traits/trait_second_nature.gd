class_name TraitSecondNature
extends Trait

var max_elan_bonus: float = 20.0
var opening_penalty: float = 10.0

func _trait_name() -> String:
	return "trait_second_nature"

func configure(params: Dictionary) -> void:
	max_elan_bonus = params.get("max_elan_bonus", max_elan_bonus)
	opening_penalty = params.get("opening_penalty", opening_penalty)

func _activate() -> void:
	if owner == null:
		return
	owner.max_elan += max_elan_bonus
	owner.current_elan = maxf(0.0, owner.current_elan - opening_penalty)
	owner.elan_changed.emit(owner)

func _deactivate() -> void:
	if owner == null:
		return
	owner.max_elan = maxf(Unit.ELAN_MAX, owner.max_elan - max_elan_bonus)
	owner.current_elan = minf(owner.current_elan, owner.max_elan)
	owner.elan_changed.emit(owner)