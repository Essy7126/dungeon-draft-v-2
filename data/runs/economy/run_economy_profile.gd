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
@export var item_catalog: ItemCatalog = null
@export var isolated_catalog_required := false
@export_range(0, 99999, 1) var starting_currency := 0
@export_range(0, 99999, 1) var victory_currency_reward := 0
@export var merchant_profile: MerchantProfile = null


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
	if isolated_catalog_required and item_catalog == null:
		errors.append(
			"Une économie isolée avec récompenses doit référencer son catalogue."
		)
	if item_catalog != null:
		var catalog_report := item_catalog.validate_catalog()
		if not bool(catalog_report.get("valid", false)):
			errors.append("Le catalogue de l'économie est invalide.")
	if merchant_profile != null:
		errors.append_array(merchant_profile.validation_errors())
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
