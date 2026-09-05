@tool
class_name GloryAvailabilityRuleData
extends Resource

@export_range(1, 99, 1) var minimum_champion_level := 1
@export_range(1, 99, 1) var maximum_champion_level := 99
@export var required_encounter_tags: Array[StringName] = []
@export var excluded_encounter_tags: Array[StringName] = []


func is_available(champion_level: int, encounter_tags: Array[StringName]) -> bool:
	if champion_level < minimum_champion_level \
			or champion_level > maximum_champion_level:
		return false
	for required_tag in required_encounter_tags:
		if not encounter_tags.has(required_tag):
			return false
	for excluded_tag in excluded_encounter_tags:
		if encounter_tags.has(excluded_tag):
			return false
	return true


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if minimum_champion_level > maximum_champion_level:
		errors.append("Le niveau minimum de Gloire dépasse le niveau maximum.")
	for tag in required_encounter_tags:
		if tag == &"":
			errors.append("Un tag requis de Gloire est vide.")
		elif excluded_encounter_tags.has(tag):
			errors.append("Le tag %s est à la fois requis et exclu." % tag)
	for tag in excluded_encounter_tags:
		if tag == &"":
			errors.append("Un tag exclu de Gloire est vide.")
	return errors
