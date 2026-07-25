class_name SpellLoadoutState
extends RefCounted

const DEFAULT_ACTIVE_SLOT_COUNT := 4

signal changed

var _slot_count: int = DEFAULT_ACTIVE_SLOT_COUNT
var _known_spells: Array[Spell] = []
var _known_by_id: Dictionary = {}
var _equipped_spell_ids: Array[StringName] = []


func initialize(starting_spells: Array, slot_count: int = DEFAULT_ACTIVE_SLOT_COUNT) -> void:
	_slot_count = maxi(0, slot_count)
	_known_spells.clear()
	_known_by_id.clear()
	_equipped_spell_ids.clear()
	for _slot_index in range(_slot_count):
		_equipped_spell_ids.append(&"")

	for candidate in starting_spells:
		if candidate is Spell:
			_learn_spell(candidate)

	for slot_index in range(mini(_slot_count, _known_spells.size())):
		_equipped_spell_ids[slot_index] = _known_spells[slot_index].get_effective_spell_id()
	changed.emit()


func learn_spell(spell: Spell) -> bool:
	if not _learn_spell(spell):
		return false
	changed.emit()
	return true


func _learn_spell(spell: Spell) -> bool:
	if spell == null:
		return false
	var effective_id := spell.get_effective_spell_id()
	if effective_id == &"" or _known_by_id.has(effective_id):
		return false
	_known_by_id[effective_id] = spell
	_known_spells.append(spell)
	return true


func knows_spell_id(spell_id: StringName) -> bool:
	return spell_id != &"" and _known_by_id.has(spell_id)


func equip_spell(spell_id: StringName, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _slot_count:
		return false
	if not knows_spell_id(spell_id):
		return false
	for index in range(_equipped_spell_ids.size()):
		if index != slot_index and _equipped_spell_ids[index] == spell_id:
			return false
	if _equipped_spell_ids[slot_index] == spell_id:
		return true
	_equipped_spell_ids[slot_index] = spell_id
	changed.emit()
	return true


func unequip_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_count:
		return
	if _equipped_spell_ids[slot_index] == &"":
		return
	_equipped_spell_ids[slot_index] = &""
	changed.emit()


func get_equipped_spells() -> Array[Spell]:
	var equipped: Array[Spell] = []
	for spell_id in _equipped_spell_ids:
		if spell_id != &"" and _known_by_id.has(spell_id):
			equipped.append(_known_by_id[spell_id])
	return equipped


func get_known_spells() -> Array[Spell]:
	return _known_spells.duplicate()


func get_active_slot_count() -> int:
	return _slot_count
