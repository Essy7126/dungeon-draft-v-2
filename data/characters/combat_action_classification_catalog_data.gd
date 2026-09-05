@tool
class_name CombatActionClassificationCatalogData
extends Resource

@export var catalog_id: StringName = &""
@export var entries: Array[CombatActionClassificationData] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if catalog_id == &"":
		errors.append("ATTACK_CLASSIFICATION_CATALOG_ID_EMPTY")
	var ability_ids := {}
	for entry in entries:
		if entry == null or not entry.is_valid():
			errors.append("ATTACK_CLASSIFICATION_ENTRY_INVALID")
			continue
		if ability_ids.has(entry.ability_id):
			errors.append("ATTACK_CLASSIFICATION_DUPLICATE: %s" % entry.ability_id)
		ability_ids[entry.ability_id] = true
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
