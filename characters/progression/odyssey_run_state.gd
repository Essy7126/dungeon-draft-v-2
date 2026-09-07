class_name OdysseyRunState
extends RefCounted

const CURRENT_SCHEMA_VERSION := 2

var schema_version := CURRENT_SCHEMA_VERSION
var currency := 0
var purchase_counts: Dictionary = {}
var merchant_mastery_purchases := 0
var reroll_counts: Dictionary = {}
var sequence_index := 0
var completed_sequence_entry_ids: Array[StringName] = []
var generated_reward_snapshots: Dictionary = {}
var selected_reward_ids: Array[StringName] = []
var distributed_reward_ids: Array[StringName] = []
var forge_levels: Dictionary = {}
var reaction_priority_overrides: Dictionary = {}
var transaction_results: Dictionary = {}


func initialize(starting_currency: int) -> void:
	currency = maxi(0, starting_currency)
	purchase_counts.clear()
	merchant_mastery_purchases = 0
	reroll_counts.clear()
	sequence_index = 0
	completed_sequence_entry_ids.clear()
	generated_reward_snapshots.clear()
	selected_reward_ids.clear()
	distributed_reward_ids.clear()
	forge_levels.clear()
	reaction_priority_overrides.clear()
	transaction_results.clear()


func can_purchase(profile: MerchantProfile, offer: MerchantOfferData) -> bool:
	if profile == null or offer == null or not offer.is_valid() \
			or currency < offer.currency_cost:
		return false
	if int(purchase_counts.get(offer.offer_id, 0)) >= offer.per_run_limit:
		return false
	if offer.offer_type == MerchantOfferData.OfferType.CHIRON_LESSON \
			and merchant_mastery_purchases + offer.mastery_amount \
			> profile.maximum_mastery_purchases_per_run:
		return false
	return true


func commit_purchase(profile: MerchantProfile, offer: MerchantOfferData) -> bool:
	if not can_purchase(profile, offer):
		return false
	currency -= offer.currency_cost
	purchase_counts[offer.offer_id] = int(purchase_counts.get(offer.offer_id, 0)) + 1
	if offer.offer_type == MerchantOfferData.OfferType.CHIRON_LESSON:
		merchant_mastery_purchases += offer.mastery_amount
	if offer.offer_type == MerchantOfferData.OfferType.REROLL:
		reroll_counts[profile.merchant_id] = int(reroll_counts.get(profile.merchant_id, 0)) + 1
	return true


func remember_generated_reward(reward_id: StringName, snapshot: Dictionary) -> bool:
	if reward_id == &"" or generated_reward_snapshots.has(reward_id):
		return false
	generated_reward_snapshots[reward_id] = snapshot.duplicate(true)
	return true


func generated_reward(reward_id: StringName) -> Dictionary:
	return (generated_reward_snapshots.get(reward_id, {}) as Dictionary).duplicate(true)


func select_reward(reward_id: StringName, selected_id: StringName) -> bool:
	if reward_id == &"" or selected_id == &"" \
			or not generated_reward_snapshots.has(reward_id) \
			or distributed_reward_ids.has(reward_id):
		return false
	selected_reward_ids.append(selected_id)
	distributed_reward_ids.append(reward_id)
	return true


func commit_direct_reward(reward_id: StringName, outcome_id: StringName) -> bool:
	if reward_id == &"" or outcome_id == &"" \
			or distributed_reward_ids.has(reward_id) \
			or selected_reward_ids.has(outcome_id):
		return false
	selected_reward_ids.append(outcome_id)
	distributed_reward_ids.append(reward_id)
	return true


func has_distributed_reward(reward_id: StringName) -> bool:
	return distributed_reward_ids.has(reward_id)


func advance_sequence(
		expected_index: int,
		completed_entry_id: StringName = &""
	) -> bool:
	if expected_index != sequence_index:
		return false
	var stable_entry_id := completed_entry_id
	if stable_entry_id == &"":
		stable_entry_id = StringName("sequence_index_%d" % expected_index)
	if completed_sequence_entry_ids.has(stable_entry_id):
		return false
	completed_sequence_entry_ids.append(stable_entry_id)
	sequence_index += 1
	return true


func add_currency(amount: int) -> bool:
	if amount <= 0:
		return false
	currency += amount
	return true


func apply_forge(instance_id: StringName, tier_delta: int) -> bool:
	if instance_id == &"" or tier_delta <= 0:
		return false
	forge_levels[instance_id] = int(forge_levels.get(instance_id, 0)) + tier_delta
	return true


func get_forge_level(instance_id: StringName) -> int:
	return int(forge_levels.get(instance_id, 0))


func set_reaction_priority_override(
		reaction_group: StringName,
		ordered_effect_ids: Array[StringName]
	) -> bool:
	if reaction_group == &"" or ordered_effect_ids.is_empty():
		return false
	var seen := {}
	for effect_id in ordered_effect_ids:
		if effect_id == &"" or seen.has(effect_id):
			return false
		seen[effect_id] = true
	reaction_priority_overrides[reaction_group] = ordered_effect_ids.duplicate()
	return true


func get_reaction_priority_override(
		reaction_group: StringName
	) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(reaction_priority_overrides.get(reaction_group, []))
	return result


func remember_transaction(
		transaction_id: StringName,
		result: Dictionary
	) -> bool:
	if transaction_id == &"" or result.is_empty() \
			or transaction_results.has(transaction_id):
		return false
	transaction_results[transaction_id] = result.duplicate(true)
	return true


func get_transaction_result(transaction_id: StringName) -> Dictionary:
	return (
		transaction_results.get(transaction_id, {}) as Dictionary
	).duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": schema_version,
		"currency": currency,
		"purchase_counts": _stringify_dictionary_keys(purchase_counts),
		"merchant_mastery_purchases": merchant_mastery_purchases,
		"reroll_counts": _stringify_dictionary_keys(reroll_counts),
		"sequence_index": sequence_index,
		"completed_sequence_entry_ids": _string_names_to_strings(
			completed_sequence_entry_ids
		),
		"generated_reward_snapshots": _stringify_dictionary_keys(generated_reward_snapshots),
		"selected_reward_ids": _string_names_to_strings(selected_reward_ids),
		"distributed_reward_ids": _string_names_to_strings(distributed_reward_ids),
		"forge_levels": _stringify_dictionary_keys(forge_levels),
		"reaction_priority_overrides": _serialize_priority_overrides(),
		"transaction_results": _stringify_dictionary_keys(transaction_results),
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	if int(snapshot.get("schema_version", 0)) != CURRENT_SCHEMA_VERSION:
		return false
	var restored_currency := int(snapshot.get("currency", -1))
	var restored_sequence_index := int(snapshot.get("sequence_index", -1))
	var restored_mastery_purchases := int(snapshot.get("merchant_mastery_purchases", -1))
	if restored_currency < 0 or restored_sequence_index < 0 \
			or restored_mastery_purchases < 0 or restored_mastery_purchases > 3:
		return false
	var purchases_result := _parse_string_name_dictionary(
		snapshot.get("purchase_counts", {})
	)
	var rerolls_result := _parse_string_name_dictionary(snapshot.get("reroll_counts", {}))
	if not bool(purchases_result.get("ok", false)) \
			or not bool(rerolls_result.get("ok", false)):
		return false
	var candidate_purchases := purchases_result.get("values", {}) as Dictionary
	var candidate_rerolls := rerolls_result.get("values", {}) as Dictionary
	for value in candidate_purchases.values():
		if int(value) < 0:
			return false
	for value in candidate_rerolls.values():
		if int(value) < 0:
			return false
	var completed_result := _parse_unique_string_names(
		snapshot.get("completed_sequence_entry_ids", [])
	)
	if not bool(completed_result.get("ok", false)):
		return false
	var candidate_completed: Array[StringName] = completed_result.get("values", [])
	if candidate_completed.size() != restored_sequence_index:
		return false
	var generated_result := _parse_string_name_dictionary(
		snapshot.get("generated_reward_snapshots", {})
	)
	if not bool(generated_result.get("ok", false)):
		return false
	var candidate_generated := generated_result.get("values", {}) as Dictionary
	for value in candidate_generated.values():
		if not value is Dictionary:
			return false
	var selected_result := _parse_unique_string_names(
		snapshot.get("selected_reward_ids", [])
	)
	var distributed_result := _parse_unique_string_names(
		snapshot.get("distributed_reward_ids", [])
	)
	if not bool(selected_result.get("ok", false)) \
			or not bool(distributed_result.get("ok", false)):
		return false
	var candidate_selected: Array[StringName] = selected_result.get("values", [])
	var candidate_distributed: Array[StringName] = distributed_result.get("values", [])
	if candidate_selected.size() != candidate_distributed.size():
		return false
	for reward_id in candidate_distributed:
		if not candidate_generated.has(reward_id):
			# Direct currency/heal/authored rewards do not need an option deck.
			var selected_index := candidate_distributed.find(reward_id)
			if selected_index < 0 or selected_index >= candidate_selected.size():
				return false
	var forge_result := _parse_string_name_dictionary(
		snapshot.get("forge_levels", {})
	)
	var transaction_result := _parse_string_name_dictionary(
		snapshot.get("transaction_results", {})
	)
	var priorities_result := _parse_priority_overrides(
		snapshot.get("reaction_priority_overrides", {})
	)
	if not bool(forge_result.get("ok", false)) \
			or not bool(transaction_result.get("ok", false)) \
			or not bool(priorities_result.get("ok", false)):
		return false
	var candidate_forge := forge_result.get("values", {}) as Dictionary
	for value in candidate_forge.values():
		if int(value) <= 0:
			return false
	var candidate_transactions := transaction_result.get("values", {}) as Dictionary
	for value in candidate_transactions.values():
		if not value is Dictionary or (value as Dictionary).is_empty():
			return false
	currency = restored_currency
	sequence_index = restored_sequence_index
	completed_sequence_entry_ids = candidate_completed
	merchant_mastery_purchases = restored_mastery_purchases
	purchase_counts = candidate_purchases
	reroll_counts = candidate_rerolls
	generated_reward_snapshots = candidate_generated
	selected_reward_ids = candidate_selected
	distributed_reward_ids = candidate_distributed
	forge_levels = candidate_forge
	reaction_priority_overrides = priorities_result.get("values", {}) as Dictionary
	transaction_results = candidate_transactions
	return true


func _serialize_priority_overrides() -> Dictionary:
	var result := {}
	var keys := reaction_priority_overrides.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for key in keys:
		var values: Array[StringName] = []
		values.assign(reaction_priority_overrides[key])
		result[str(key)] = _string_names_to_strings(values)
	return result


func _parse_priority_overrides(source: Variant) -> Dictionary:
	var result := {}
	if not source is Dictionary:
		return {"ok": false, "values": result}
	for key in (source as Dictionary).keys():
		var group_id := StringName(str(key))
		var parsed := _parse_unique_string_names((source as Dictionary)[key])
		var values: Array[StringName] = parsed.get("values", [])
		if group_id == &"" or not bool(parsed.get("ok", false)) \
				or values.is_empty():
			return {"ok": false, "values": {}}
		result[group_id] = values
	return {"ok": true, "values": result}


func _stringify_dictionary_keys(source: Dictionary) -> Dictionary:
	var result := {}
	var keys := source.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for key in keys:
		var value: Variant = source[key]
		result[str(key)] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result


func _parse_string_name_dictionary(source: Variant) -> Dictionary:
	var result := {}
	if not source is Dictionary:
		return {"ok": false, "values": result}
	for key in (source as Dictionary).keys():
		var normalized_key := StringName(str(key))
		if normalized_key == &"" or result.has(normalized_key):
			return {"ok": false, "values": {}}
		var value: Variant = (source as Dictionary)[key]
		result[normalized_key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return {"ok": true, "values": result}


func _string_names_to_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func _parse_unique_string_names(values: Variant) -> Dictionary:
	var result: Array[StringName] = []
	if not values is Array:
		return {"ok": false, "values": result}
	for raw_value in values:
		if not raw_value is String and not raw_value is StringName:
			return {"ok": false, "values": []}
		var value := StringName(str(raw_value))
		if value == &"" or result.has(value):
			return {"ok": false, "values": []}
		result.append(value)
	return {"ok": true, "values": result}
