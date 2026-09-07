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


## Changes capacity without forgetting learned spells or compacting empty slots.
## A shrink that would discard an equipped spell must be made explicit first.
func resize_slots(slot_count: int) -> bool:
	if slot_count < 0 or slot_count > 6:
		return false
	if slot_count < _slot_count:
		for index in range(slot_count, _slot_count):
			if _equipped_spell_ids[index] != &"":
				return false
	if slot_count == _slot_count:
		return true
	while _equipped_spell_ids.size() < slot_count:
		_equipped_spell_ids.append(&"")
	_equipped_spell_ids.resize(slot_count)
	_slot_count = slot_count
	changed.emit()
	return true


func get_spell_slot_ids() -> Array[StringName]:
	return _equipped_spell_ids.duplicate()


func to_snapshot() -> Dictionary:
	var known: Array[String] = []
	var equipped: Array[String] = []
	for spell in _known_spells:
		known.append(String(spell.get_effective_spell_id()))
	for spell_id in _equipped_spell_ids:
		equipped.append(String(spell_id))
	return {"version": 1, "slot_count": _slot_count,
		"known_spell_ids": known, "equipped_spell_ids": equipped}


## The caller supplies the allowed resources; snapshots never load arbitrary paths.
## All validation precedes the first mutation, including duplicate/unknown IDs.
func restore_snapshot(snapshot: Dictionary, available_spells: Array) -> bool:
	if snapshot.get("version", 0) != 1:
		return false
	var count_value: Variant = snapshot.get("slot_count", -1)
	if not (count_value is int or count_value is float) \
			or float(count_value) != floor(float(count_value)):
		return false
	var count := int(count_value)
	var known_value: Variant = snapshot.get("known_spell_ids")
	var slots_value: Variant = snapshot.get("equipped_spell_ids")
	if count < 0 or count > 6 or not known_value is Array \
			or not slots_value is Array or slots_value.size() != count:
		return false
	var available := {}
	for candidate in available_spells:
		if candidate is Spell:
			available[String(candidate.get_effective_spell_id())] = candidate
	var known: Array[Spell] = []
	var known_by_id := {}
	for id_value in known_value:
		if not (id_value is String or id_value is StringName):
			return false
		var id := StringName(id_value)
		if id == &"" or known_by_id.has(id) or not available.has(String(id)):
			return false
		known.append(available[String(id)])
		known_by_id[id] = available[String(id)]
	var slots: Array[StringName] = []
	for id_value in slots_value:
		if not (id_value is String or id_value is StringName):
			return false
		var id := StringName(id_value)
		if id != &"" and (not known_by_id.has(id) or slots.has(id)):
			return false
		slots.append(id)
	_slot_count = count
	_known_spells = known
	_known_by_id = known_by_id
	_equipped_spell_ids = slots
	changed.emit()
	return true
