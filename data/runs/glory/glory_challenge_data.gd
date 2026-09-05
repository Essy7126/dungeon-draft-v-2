@tool
class_name GloryChallengeData
extends Resource

enum EncounterModifier {
	EXTRA_ELITE,
	AUTHORED_REINFORCEMENT,
	REDUCED_AVAILABLE_HEALING,
	ADVERSE_INITIAL_TERRAIN,
	OPTIONAL_ENEMY,
	CONSUMABLE_RESTRICTION,
	SECONDARY_OBJECTIVE,
}

enum SuccessCondition {
	DEFEAT_EXTRA_ELITE,
	DEFEAT_AUTHORED_REINFORCEMENT,
	WIN_WITH_HEALING_LIMIT,
	WIN_FROM_ADVERSE_TERRAIN,
	DEFEAT_OPTIONAL_ENEMY,
	WIN_WITHOUT_CONSUMABLE,
	COMPLETE_SECONDARY_OBJECTIVE,
}

enum FailurePolicy {
	KEEP_BASE_XP_ON_VICTORY,
}

@export var challenge_id: StringName = &""
@export var display_name := "Défi de Gloire"
@export_multiline var description := ""
@export var encounter_modifier: EncounterModifier = EncounterModifier.EXTRA_ELITE
@export_range(1.0, 3.0, 0.01) var xp_multiplier := 1.30
@export var success_condition: SuccessCondition = SuccessCondition.DEFEAT_EXTRA_ELITE
@export var failure_policy: FailurePolicy = FailurePolicy.KEEP_BASE_XP_ON_VICTORY
@export var availability_rules: Array[GloryAvailabilityRuleData] = []
@export var authored_encounter_variant_id: StringName = &""


func is_available(champion_level: int, encounter_tags: Array[StringName]) -> bool:
	for rule in availability_rules:
		if rule == null or not rule.is_available(champion_level, encounter_tags):
			return false
	return true


func final_multiplier(accepted: bool, victory: bool, succeeded: bool) -> float:
	return xp_multiplier if accepted and victory and succeeded else 1.0


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if challenge_id == &"":
		errors.append("Le challenge_id de Gloire est absent.")
	if display_name.strip_edges().is_empty() or description.strip_edges().is_empty():
		errors.append("Le défi de Gloire doit avoir un nom et une règle lisible.")
	if xp_multiplier <= 1.0:
		errors.append("Le multiplicateur de Gloire doit être strictement supérieur à 1.")
	if encounter_modifier in [
		EncounterModifier.EXTRA_ELITE,
		EncounterModifier.AUTHORED_REINFORCEMENT,
		EncounterModifier.OPTIONAL_ENEMY,
		EncounterModifier.SECONDARY_OBJECTIVE,
	] and authored_encounter_variant_id == &"":
		errors.append("Le défi %s exige une variante authored stable." % challenge_id)
	for rule in availability_rules:
		if rule == null:
			errors.append("Une règle de disponibilité de Gloire est absente.")
		else:
			errors.append_array(rule.validation_errors())
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
