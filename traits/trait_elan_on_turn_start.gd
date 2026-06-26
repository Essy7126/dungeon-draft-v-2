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
	if once_per_combat and _used:
		return
	_used = true
	owner.max_elan += amount
	owner.current_elan = minf(owner.current_elan + amount, owner.max_elan)
	EventBus.elan_changed.emit(owner, owner.current_elan, owner.max_elan)
	owner.elan_changed.emit(owner)