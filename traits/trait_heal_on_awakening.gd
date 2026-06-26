class_name TraitHealOnAwakening
extends Trait

var heal_amount: int = 15

func _trait_name() -> String:
	return "trait_heal_on_awakening"

func configure(params: Dictionary) -> void:
	heal_amount = params.get("heal_amount", heal_amount)

func _activate() -> void:
	EventBus.awakening_activated.connect(_on_awakening_activated)

func _deactivate() -> void:
	if EventBus.awakening_activated.is_connected(_on_awakening_activated):
		EventBus.awakening_activated.disconnect(_on_awakening_activated)

func _on_awakening_activated(unit, _energy_id: String, _duration: int) -> void:
	if unit == owner and owner != null and heal_amount > 0:
		owner.heal(heal_amount)