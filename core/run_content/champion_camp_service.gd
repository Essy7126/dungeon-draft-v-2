class_name ChampionCampService
extends RefCounted

var _rewards := OdysseyRewardService.new()
var _purchasing := false


func presentation(profile: MerchantProfile, economy: OdysseyRunState,
		character: CharacterRunState, inventory: RunInventory, seed_value: int) -> Dictionary:
	if not _valid_context(profile, economy, character, inventory):
		return {}
	var rows: Array[Dictionary] = []
	for offer in profile.offers:
		var targets := _targets(profile, offer, economy, character, inventory, seed_value)
		var needs_target := offer.offer_type in [MerchantOfferData.OfferType.EQUIPMENT,
			MerchantOfferData.OfferType.RELIC, MerchantOfferData.OfferType.FORGE,
			MerchantOfferData.OfferType.REORIENTATION]
		rows.append({"id": offer.offer_id, "name": offer.display_name,
			"description": offer.description, "cost": offer.currency_cost,
			"remaining": maxi(0, offer.per_run_limit - int(economy.purchase_counts.get(offer.offer_id, 0))),
			"available": economy.can_purchase(profile, offer) and (not needs_target or not targets.is_empty())
				and (offer.offer_type != MerchantOfferData.OfferType.HEAL or character.unit.is_alive and character.unit.current_hp < character.unit.max_hp.get_int()),
			"targets": targets})
	return {"name": profile.display_name, "currency": economy.currency,
		"mastery_lessons": economy.merchant_mastery_purchases, "offers": rows}


func purchase(profile: MerchantProfile, economy: OdysseyRunState,
		character: CharacterRunState, inventory: RunInventory, seed_value: int,
		offer_id: StringName, target_id: StringName = &"") -> Dictionary:
	if _purchasing:
		return _failure("Une transaction est déjà en cours.")
	_purchasing = true
	var result := _purchase(profile, economy, character, inventory, seed_value, offer_id, target_id)
	_purchasing = false
	return result


func _purchase(profile: MerchantProfile, economy: OdysseyRunState,
		character: CharacterRunState, inventory: RunInventory, seed_value: int,
		offer_id: StringName, target_id: StringName) -> Dictionary:
	if not _valid_context(profile, economy, character, inventory):
		return _failure("La préparation est indisponible.")
	var offer := profile.get_offer(offer_id)
	if offer == null or not economy.can_purchase(profile, offer):
		return _failure("Drachmes insuffisantes ou limite d’achat atteinte.")
	var targets := _targets(profile, offer, economy, character, inventory, seed_value)
	var target_valid := false
	for target in targets:
		if StringName(target.id) == target_id:
			target_valid = true
	if offer.offer_type in [MerchantOfferData.OfferType.EQUIPMENT, MerchantOfferData.OfferType.RELIC,
		MerchantOfferData.OfferType.FORGE, MerchantOfferData.OfferType.REORIENTATION] and not target_valid:
		return _failure("Sélectionnez une proposition encore disponible.")
	# Validate the economy transition before changing the live inventory or build.
	# Inventory/stat signals can refresh the UI while an effect is being applied.
	var staged := OdysseyRunState.new()
	if not staged.restore_snapshot(economy.get_snapshot()):
		return _failure("L’état du marchand est invalide.")
	if offer.offer_type in [MerchantOfferData.OfferType.EQUIPMENT, MerchantOfferData.OfferType.RELIC]:
		if not _rewards.select_merchant_option(profile, offer, target_id, inventory.get_catalog(), staged):
			return _failure("Cette proposition a déjà été distribuée.")
	if not staged.commit_purchase(profile, offer):
		return _failure("La transaction n’a pas pu être validée.")
	if not OdysseyRunState.new().restore_snapshot(staged.get_snapshot()):
		return _failure("L’état résultant du marchand est invalide.")
	var result := {"success": true, "offer_id": offer_id, "target_id": target_id}
	match offer.offer_type:
		MerchantOfferData.OfferType.EQUIPMENT, MerchantOfferData.OfferType.RELIC:
			if not inventory.can_accept(target_id):
				return _failure("Libérez une place dans l’inventaire.")
			var granted := inventory.try_add(target_id)
			if not bool(granted.get("success", false)):
				return granted
			result["instance_ids"] = granted.get("instance_ids", [])
		MerchantOfferData.OfferType.HEAL:
			if not character.unit.is_alive or character.unit.current_hp >= character.unit.max_hp.get_int():
				return _failure("Les PV sont déjà au maximum.")
			var heal := int(round(character.unit.max_hp.get_int() * offer.heal_max_hp_ratio))
			var before := character.unit.current_hp
			character.unit.heal(heal)
			result["healed"] = character.unit.current_hp - before
		MerchantOfferData.OfferType.CHIRON_LESSON:
			if not character.champion_progression.grant_purchased_mastery(offer.mastery_amount):
				return _failure("Trois leçons de Chiron au maximum par run.")
		MerchantOfferData.OfferType.FORGE:
			var instance := _find_item(character, inventory, target_id)
			if instance == null:
				return _failure("L’équipement sélectionné n’est plus disponible.")
			var previous_level := instance.forge_level
			instance.forge_level += offer.forge_tier_delta
			if not EquipmentStatService.new().rebuild_loadout(character, inventory.get_catalog()):
				instance.forge_level = previous_level
				EquipmentStatService.new().rebuild_loadout(character, inventory.get_catalog())
				return _failure("L’amélioration n’a pas pu être appliquée.")
			staged.forge_levels[instance.instance_id] = instance.forge_level
			inventory.notify_changed()
		MerchantOfferData.OfferType.REORIENTATION:
			var snapshot := _refund_snapshot(character, target_id, offer.reorientation_refund_limit)
			if snapshot.is_empty() or not character.champion_progression.restore_snapshot(snapshot):
				return _failure("Ce retrait invaliderait un prérequis de votre doctrine.")
			character.refresh_mastery_effects()
		MerchantOfferData.OfferType.REROLL:
			pass # commit_purchase advances the deterministic offer generation.
	if not economy.restore_snapshot(staged.get_snapshot()):
		return _failure("La transaction n’a pas pu être validée.")
	character.champion_changed.emit()
	result["currency"] = economy.currency
	return result


func _targets(profile: MerchantProfile, offer: MerchantOfferData, economy: OdysseyRunState,
		character: CharacterRunState, inventory: RunInventory, seed_value: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var catalog := inventory.get_catalog()
	match offer.offer_type:
		MerchantOfferData.OfferType.EQUIPMENT, MerchantOfferData.OfferType.RELIC:
			for item_id in _rewards.build_merchant_options(profile, offer, catalog, economy, seed_value):
				var definition := catalog.get_definition(item_id)
				if definition != null and not (definition.is_relic() and inventory.contains_definition(item_id)):
					result.append({"id": item_id, "name": definition.display_name, "description": definition.description})
		MerchantOfferData.OfferType.FORGE:
			var instances := inventory.get_slots()
			instances.append_array(character.equipment_loadout.get_equipped_items())
			for instance in instances:
				if instance == null:
					continue
				var definition := catalog.get_definition(instance.definition_id)
				if definition != null and definition.is_equippable() and definition.stat_modifiers.any(func(modifier: ItemStatModifierData) -> bool: return modifier != null and modifier.value > 0.0) and instance.forge_level >= 0 and instance.forge_level + offer.forge_tier_delta <= 2:
					result.append({"id": instance.instance_id,
						"name": "%s · forge %d → %d" % [definition.display_name, instance.forge_level, instance.forge_level + offer.forge_tier_delta],
						"description": "+20 % de la valeur de base des bonus de caractéristiques positifs. Les PV actuels ne remontent pas."})
		MerchantOfferData.OfferType.REORIENTATION:
			for node in character.get_selected_mastery_nodes():
				if not _refund_snapshot(character, node.upgrade_id, offer.reorientation_refund_limit).is_empty():
					result.append({"id": node.upgrade_id, "name": node.display_name, "description": "Rembourse %d maîtrise." % node.mastery_cost})
	return result


func _refund_snapshot(character: CharacterRunState, node_id: StringName, limit: int) -> Dictionary:
	var champion := character.champion_progression
	if champion == null or not champion.selected_node_ids.has(node_id):
		return {}
	var node: SkillTreeNodeData = character.progression_profile.mastery_catalog.node_catalog().get(node_id)
	if node == null or node.mastery_cost > limit or node.node_type not in [SkillTreeNodeData.NodeType.ROOT, SkillTreeNodeData.NodeType.MASTERY]:
		return {}
	var candidate := champion.to_snapshot()
	(candidate.selected_node_ids as Array).erase(str(node_id))
	candidate.unspent_mastery_points = int(candidate.unspent_mastery_points) + node.mastery_cost
	# The same pure snapshot validator checks the remaining branch, including
	# every capstone, exclusion and advanced prerequisite before spending money.
	return candidate if bool(champion._parse_snapshot(candidate).get("ok", false)) else {}


func _find_item(character: CharacterRunState, inventory: RunInventory, instance_id: StringName) -> ItemInstance:
	var instance := inventory.get_instance(instance_id)
	if instance != null:
		return instance
	for equipped in character.equipment_loadout.get_equipped_items():
		if equipped.instance_id == instance_id:
			return equipped
	return null


func _valid_context(profile: MerchantProfile, economy: OdysseyRunState,
		character: CharacterRunState, inventory: RunInventory) -> bool:
	return profile != null and profile.is_valid() and economy != null and character != null \
		and character.unit != null and character.champion_progression != null \
		and character.equipment_loadout != null and inventory != null and inventory.get_catalog() != null


func _failure(message: String) -> Dictionary:
	return {"success": false, "error": message}
