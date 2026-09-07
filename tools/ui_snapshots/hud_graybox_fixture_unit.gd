class_name HudGrayboxFixtureUnit
extends Unit

## Keep the production Unit type contract without starting a run or a battle.
## Unit is RefCounted: this fixture must not be added to the scene tree.

var availability_by_spell: Dictionary = {}
var cooldown_by_spell: Dictionary = {}


func _init() -> void:
	super("Achille", 0, 110.0, 10.0, 6.0, 4.0, 20.0)
	unit_id = &"achilles"
	current_hp = 86


func configure_for_state(state_id: StringName, source_spells: Array[Spell]) -> void:
	spells = source_spells.duplicate()
	availability_by_spell.clear()
	cooldown_by_spell.clear()
	current_ap = 6
	match state_id:
		&"unavailable":
			current_ap = 1
			_set_availability(1, &"pa")
		&"cooldown":
			_set_availability(2, &"cooldown")
			_set_cooldown(2, 2)
		&"locked":
			_set_availability(3, &"once_per_activation")


func get_spell_ap_cost(spell: Spell) -> int:
	return spell.ap_cost if spell != null else 0


func get_spell_availability_reason(spell: Spell) -> StringName:
	if spell == null:
		return &"spell"
	return StringName(availability_by_spell.get(spell.spell_id, &""))


func get_spell_cooldown_remaining(spell: Spell) -> int:
	if spell == null:
		return 0
	return int(cooldown_by_spell.get(spell.spell_id, 0))


func can_use_spell(spell: Spell) -> bool:
	return spell != null and get_spell_availability_reason(spell) == &""


func can_use_basic_attack() -> bool:
	return basic_attack_enabled and current_ap >= get_basic_attack_ap_cost()


func get_basic_attack_ap_cost() -> int:
	return 2


func _set_availability(index: int, reason: StringName) -> void:
	if index >= 0 and index < spells.size() and spells[index] != null:
		availability_by_spell[spells[index].spell_id] = reason


func _set_cooldown(index: int, turns: int) -> void:
	if index >= 0 and index < spells.size() and spells[index] != null:
		cooldown_by_spell[spells[index].spell_id] = turns
