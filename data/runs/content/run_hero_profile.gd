@tool
class_name RunHeroProfile
extends Resource

@export var character_id: StringName = &""
@export var base_unit_data: UnitData = null
@export var progression_profile: CharacterProgressionProfile = null


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if str(character_id).strip_edges().is_empty():
		errors.append("Le character_id du heros est absent.")
	if base_unit_data == null:
		errors.append("Le UnitData de base de %s est absent." % character_id)
	elif base_unit_data.get_effective_unit_id() != character_id:
		errors.append(
			"Le UnitData de base %s ne correspond pas au profil %s." % [
				base_unit_data.get_effective_unit_id(), character_id,
			]
		)
	if progression_profile == null:
		errors.append("La progression de %s est absente." % character_id)
	else:
		if progression_profile.character_id != character_id:
			errors.append(
				"La progression %s ne correspond pas au profil %s." % [
					progression_profile.character_id, character_id,
				]
			)
		errors.append_array(progression_profile.validation_errors())
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
