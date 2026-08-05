@tool
class_name RoomWaveData
extends Resource

## Donnees immuables d'une vague jouee dans une salle.
## La composition et la difficulte restent portees par EncounterDefinition.

@export var wave_name: String = "Vague"
@export var encounter_definition: EncounterDefinition
@export_range(0.1, 5.0, 0.05) var enemy_health_multiplier: float = 1.0
@export_range(0.1, 5.0, 0.05) var enemy_attack_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.05) var reward_multiplier: float = 1.0


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if wave_name.strip_edges().is_empty():
		errors.append("Le nom de la vague ne peut pas etre vide.")
	if encounter_definition == null:
		errors.append("La vague doit referencer une EncounterDefinition.")
	elif not encounter_definition.is_valid():
		errors.append("La rencontre referencee par la vague est invalide.")
	if enemy_health_multiplier <= 0.0:
		errors.append("Le multiplicateur de PV ennemis doit etre positif.")
	if enemy_attack_multiplier <= 0.0:
		errors.append("Le multiplicateur d'attaque ennemie doit etre positif.")
	if reward_multiplier < 0.0:
		errors.append("Le multiplicateur de recompense ne peut pas etre negatif.")
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
