class_name TraitEnergyOnGenerator
extends Trait

var amount: float = 6.0
var once_per_turn: bool = true
var _used_this_turn: bool = false

func _trait_name() -> String:
	return "trait_energy_on_generator"

func configure(params: Dictionary) -> void:
	amount = params.get("amount", amount)
	once_per_turn = params.get("once_per_turn", once_per_turn)

func _activate() -> void:
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.basic_attack_performed.connect(_on_basic_attack_performed)
	EventBus.turn_started.connect(_on_turn_started)

func _deactivate() -> void:
	if EventBus.spell_cast.is_connected(_on_spell_cast):
		EventBus.spell_cast.disconnect(_on_spell_cast)
	if EventBus.basic_attack_performed.is_connected(_on_basic_attack_performed):
		EventBus.basic_attack_performed.disconnect(_on_basic_attack_performed)
	if EventBus.turn_started.is_connected(_on_turn_started):
		EventBus.turn_started.disconnect(_on_turn_started)

func _on_turn_started(unit) -> void:
	if unit == owner:
		_used_this_turn = false

func _on_basic_attack_performed(attacker, _target) -> void:
	if attacker == owner:
		_generate("attaque de base")

func _on_spell_cast(caster, spell: Spell, _report: Dictionary) -> void:
	if caster != owner or spell == null or not spell.is_generator():
		return
	_generate(spell.spell_name)

func _generate(reason: String) -> void:
	if owner == null or not owner.is_alive or not owner.has_energy():
		return
	if once_per_turn and _used_this_turn:
		return
	owner.generate_energy(amount, source_id)
	_used_this_turn = true
	DebugLogger.debug(DebugLogger.LogCategory.STATS,
		"%s genere %.0f %s (%s)" % [owner.unit_name, amount, owner.energy_type.energy_name, reason])