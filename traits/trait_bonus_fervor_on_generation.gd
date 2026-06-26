class_name TraitBonusFervorOnGeneration
extends Trait

var bonus: float = 3.0
var once_per_turn: bool = false
var _used_this_turn: bool = false
var _guard: bool = false

func _trait_name() -> String:
	return "trait_bonus_fervor_on_generation"

func configure(params: Dictionary) -> void:
	bonus = params.get("bonus", bonus)
	once_per_turn = params.get("once_per_turn", once_per_turn)

func _activate() -> void:
	EventBus.energy_generated.connect(_on_energy_generated)
	EventBus.turn_started.connect(_on_turn_started)

func _deactivate() -> void:
	if EventBus.energy_generated.is_connected(_on_energy_generated):
		EventBus.energy_generated.disconnect(_on_energy_generated)
	if EventBus.turn_started.is_connected(_on_turn_started):
		EventBus.turn_started.disconnect(_on_turn_started)

func _on_turn_started(unit) -> void:
	if unit == owner:
		_used_this_turn = false

func _on_energy_generated(unit, _energy_id: String, amount: float) -> void:
	if unit != owner or owner == null or amount <= 0.0 or bonus <= 0.0 or _guard:
		return
	if once_per_turn and _used_this_turn:
		return
	_used_this_turn = true
	_guard = true
	owner.generate_energy(bonus, source_id)
	_guard = false