@tool
class_name CharacterProgressionProfile
extends Resource

@export var character_id: StringName = &""
@export_range(1, 12, 1) var active_spell_slots: int = 4
@export var spells: Array[Spell] = []
@export var disciplines: Array[DisciplineData] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if str(character_id).strip_edges().is_empty():
		errors.append("Le character_id de progression est absent.")
	if active_spell_slots < 1 or active_spell_slots > 12:
		errors.append("Le nombre de slots actifs doit etre compris entre 1 et 12.")
	if spells.is_empty():
		errors.append("La progression %s ne contient aucun sort." % character_id)
	for index in range(spells.size()):
		if spells[index] == null:
			errors.append("Le sort %d de %s est absent." % [index, character_id])
	if disciplines.is_empty():
		errors.append("La progression %s ne contient aucune discipline." % character_id)
	for index in range(disciplines.size()):
		if disciplines[index] == null:
			errors.append("La discipline %d de %s est absente." % [index, character_id])
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
