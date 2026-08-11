class_name RunEconomyProfile
extends Resource

const DEFAULT_EQUIPMENT_REWARD_POOL_TAG: StringName = (
	&"first_run_equipment_reward"
)

@export var starting_items: Array[RunStartingItemData] = []
@export var equipment_rewards_enabled := true
@export var equipment_reward_pool_tag: StringName = (
	DEFAULT_EQUIPMENT_REWARD_POOL_TAG
)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	for index in range(starting_items.size()):
		var entry := starting_items[index]
		if entry == null:
			errors.append("L'objet initial %d est absent." % index)
			continue
		errors.append_array(entry.validation_errors())
		if seen.has(entry.item_id):
			errors.append("L'objet initial %s est duplique." % entry.item_id)
		seen[entry.item_id] = true
	if equipment_rewards_enabled and equipment_reward_pool_tag == &"":
		errors.append(
			"Une economie avec recompenses doit declarer un pool tag."
		)
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
