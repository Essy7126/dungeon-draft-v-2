@tool
class_name RunRewardEventData
extends Resource

enum RewardType {
	EQUIPMENT_CACHE,
	RELIC_CHOICE,
	CURRENCY,
	HEAL,
	FORGE,
	AUTHORED_CHOICE,
}

@export var reward_id: StringName = &""
@export var display_name := "Récompense"
@export_multiline var description := ""
@export var reward_type: RewardType = RewardType.EQUIPMENT_CACHE
@export var catalog_tags: Array[StringName] = []
@export_range(1, 12, 1) var offered_choice_count := 1
@export_range(0, 9999, 1) var currency_amount := 0
@export_range(0.0, 1.0, 0.01) var heal_max_hp_ratio := 0.0
@export var authored_reward_id: StringName = &""
@export var one_shot := true


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if reward_id == &"":
		errors.append("Le reward_id est absent.")
	if display_name.strip_edges().is_empty():
		errors.append("Le nom de la récompense est absent.")
	match reward_type:
		RewardType.EQUIPMENT_CACHE, RewardType.RELIC_CHOICE:
			if catalog_tags.is_empty():
				errors.append("La récompense %s doit filtrer un catalogue." % reward_id)
		RewardType.CURRENCY:
			if currency_amount <= 0:
				errors.append("La récompense monétaire doit être positive.")
		RewardType.HEAL:
			if heal_max_hp_ratio <= 0.0:
				errors.append("La récompense de soin doit être positive.")
		RewardType.AUTHORED_CHOICE:
			if authored_reward_id == &"":
				errors.append("La récompense authored doit posséder un identifiant.")
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
