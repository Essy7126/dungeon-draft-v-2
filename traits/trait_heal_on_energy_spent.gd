class_name TraitHealOnEnergySpent
extends Trait

var heal_flat: float = 3.0
var heal_ratio: float = 0.20
var minimum_heal: int = 1

func _trait_name() -> String:
	return "trait_heal_on_energy_spent"

func configure(params: Dictionary) -> void:
	heal_flat = params.get("heal_flat", heal_flat)
	heal_ratio = params.get("heal_ratio", heal_ratio)
	minimum_heal = params.get("minimum_heal", minimum_heal)

func _activate() -> void:
	EventBus.energy_spent.connect(_on_energy_spent)

func _deactivate() -> void:
	if EventBus.energy_spent.is_connected(_on_energy_spent):
		EventBus.energy_spent.disconnect(_on_energy_spent)

func _on_energy_spent(unit, _energy_id: String, amount: float) -> void:
	if unit != owner or owner == null or not owner.is_alive:
		return
	var value := maxi(minimum_heal, int(round(heal_flat + amount * heal_ratio)))
	owner.heal(value)
	DebugLogger.debug(DebugLogger.LogCategory.STATS,
		"%s recupere %d PV via %s" % [owner.unit_name, value, display_name])