class_name OdysseyRewardService
extends RefCounted

const SNAPSHOT_VERSION := 1


func build_merchant_options(
		profile: MerchantProfile,
		offer: MerchantOfferData,
		catalog: ItemCatalog,
		state: OdysseyRunState,
		run_seed: int
	) -> Array[StringName]:
	if profile == null or offer == null or catalog == null or state == null \
			or not profile.is_valid() or not offer.is_valid() \
			or offer.offer_type not in [
				MerchantOfferData.OfferType.EQUIPMENT,
				MerchantOfferData.OfferType.RELIC,
			]:
		return []
	var reward := _merchant_reward(profile, offer, state)
	if reward == null:
		return []
	if offer.item_id != &"":
		var remembered := state.generated_reward(reward.reward_id)
		if not remembered.is_empty():
			return _validated_remembered_options(remembered, reward, catalog)
		var definition := catalog.get_definition(offer.item_id)
		if not _matches_reward(definition, reward):
			return []
		var snapshot := {
			"version": SNAPSHOT_VERSION,
			"reward_id": str(reward.reward_id),
			"seed": _stable_seed(run_seed, reward.reward_id),
			"option_ids": [str(offer.item_id)],
		}
		if not state.remember_generated_reward(reward.reward_id, snapshot):
			return []
		return [offer.item_id]
	return build_options(reward, catalog, state, run_seed)


func select_merchant_option(
		profile: MerchantProfile,
		offer: MerchantOfferData,
		item_id: StringName,
		catalog: ItemCatalog,
		state: OdysseyRunState
	) -> bool:
	var reward := _merchant_reward(profile, offer, state)
	return reward != null and select_option(reward, item_id, catalog, state)


func merchant_reward_id(
		profile: MerchantProfile,
		offer: MerchantOfferData,
		state: OdysseyRunState
	) -> StringName:
	if profile == null or offer == null or state == null:
		return &""
	return StringName("merchant:%s:%s:purchase_%d:reroll_%d" % [
		str(profile.merchant_id),
		str(offer.offer_id),
		int(state.purchase_counts.get(offer.offer_id, 0)),
		int(state.reroll_counts.get(profile.merchant_id, 0)),
	])


func build_options(
		reward: RunRewardEventData,
		catalog: ItemCatalog,
		state: OdysseyRunState,
		run_seed: int
	) -> Array[StringName]:
	if reward == null or catalog == null or state == null or not reward.is_valid():
		return []
	var remembered := state.generated_reward(reward.reward_id)
	if not remembered.is_empty():
		return _validated_remembered_options(remembered, reward, catalog)
	if reward.reward_type not in [
		RunRewardEventData.RewardType.EQUIPMENT_CACHE,
		RunRewardEventData.RewardType.RELIC_CHOICE,
	]:
		return []
	if not catalog.rebuild_index():
		return []
	var candidates: Array[StringName] = []
	for definition in catalog.get_definitions():
		if not _matches_reward(definition, reward):
			continue
		if state.selected_reward_ids.has(definition.item_id):
			continue
		candidates.append(definition.item_id)
	candidates.sort_custom(func(a: StringName, b: StringName) -> bool:
		return str(a) < str(b)
	)
	_shuffle(candidates, _stable_seed(run_seed, reward.reward_id))
	var count := mini(reward.offered_choice_count, candidates.size())
	var options: Array[StringName] = []
	for index in range(count):
		options.append(candidates[index])
	if options.is_empty():
		return []
	var snapshot := {
		"version": SNAPSHOT_VERSION,
		"reward_id": str(reward.reward_id),
		"seed": _stable_seed(run_seed, reward.reward_id),
		"option_ids": _to_strings(options),
	}
	if not state.remember_generated_reward(reward.reward_id, snapshot):
		return []
	return options


func select_option(
		reward: RunRewardEventData,
		item_id: StringName,
		catalog: ItemCatalog,
		state: OdysseyRunState
	) -> bool:
	if reward == null or catalog == null or state == null:
		return false
	var options := _validated_remembered_options(
		state.generated_reward(reward.reward_id),
		reward,
		catalog,
	)
	return options.has(item_id) and state.select_reward(reward.reward_id, item_id)


func _validated_remembered_options(
		snapshot: Dictionary,
		reward: RunRewardEventData,
		catalog: ItemCatalog
	) -> Array[StringName]:
	var result: Array[StringName] = []
	if int(snapshot.get("version", -1)) != SNAPSHOT_VERSION \
			or StringName(snapshot.get("reward_id", "")) != reward.reward_id \
			or not catalog.rebuild_index():
		return result
	var raw_options: Variant = snapshot.get("option_ids", [])
	if not raw_options is Array:
		return result
	for raw_id in (raw_options as Array):
		var item_id := StringName(str(raw_id))
		var definition := catalog.get_definition(item_id)
		if item_id == &"" or result.has(item_id) \
				or not _matches_reward(definition, reward):
			return []
		result.append(item_id)
	return result


func _matches_reward(
		definition: ItemDefinition,
		reward: RunRewardEventData
	) -> bool:
	if definition == null:
		return false
	if reward.reward_type == RunRewardEventData.RewardType.RELIC_CHOICE:
		if not definition.is_relic():
			return false
	elif not definition.is_equippable() or definition.is_relic():
		return false
	for tag in reward.catalog_tags:
		if not definition.tags.has(tag):
			return false
	return true


func _merchant_reward(
		profile: MerchantProfile,
		offer: MerchantOfferData,
		state: OdysseyRunState
	) -> RunRewardEventData:
	if profile == null or offer == null or state == null:
		return null
	var reward := RunRewardEventData.new()
	reward.reward_id = merchant_reward_id(profile, offer, state)
	reward.display_name = offer.display_name
	reward.description = offer.description
	reward.reward_type = (
		RunRewardEventData.RewardType.RELIC_CHOICE
		if offer.offer_type == MerchantOfferData.OfferType.RELIC
		else RunRewardEventData.RewardType.EQUIPMENT_CACHE
	)
	reward.catalog_tags = offer.catalog_tags.duplicate()
	reward.offered_choice_count = _merchant_offer_count(profile)
	return reward


func _merchant_offer_count(profile: MerchantProfile) -> int:
	for candidate in profile.offers:
		if candidate != null \
				and candidate.offer_type == MerchantOfferData.OfferType.REROLL:
			return maxi(1, candidate.reroll_offer_count)
	return 3


func _stable_seed(run_seed: int, stable_id: StringName) -> int:
	var value := int(run_seed) & 0x7fffffff
	for byte in str(stable_id).to_utf8_buffer():
		value = int((value * 16777619) ^ byte) & 0x7fffffff
	return value


func _shuffle(values: Array[StringName], seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary


func _to_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
