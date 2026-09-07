class_name CombatActionClassificationRegistry
extends RefCounted

var _classification_by_ability_id: Dictionary = {}


func initialize(catalog: CombatActionClassificationCatalogData) -> bool:
	_classification_by_ability_id.clear()
	if catalog == null or not catalog.is_valid():
		return false
	for entry in catalog.entries:
		_classification_by_ability_id[entry.ability_id] = entry.classification_id()
	return true


func classification_for_ability(ability_id: StringName) -> StringName:
	return StringName(_classification_by_ability_id.get(ability_id, &""))


func classification_for_spell(spell: Spell) -> StringName:
	if spell == null:
		return &""
	return classification_for_ability(spell.get_effective_spell_id())


func is_projectile_ability(ability_id: StringName) -> bool:
	return classification_for_ability(ability_id) == &"PROJECTILE"


func has_explicit_classification(ability_id: StringName) -> bool:
	return _classification_by_ability_id.has(ability_id)
