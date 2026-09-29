extends RefCounted
## Rules adapter for the existing ExpeditionSession. No scene or run ownership.
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Cards := preload("res://core/expedition/consumable_cards_state.gd")
const Economy := preload("res://core/expedition/consumable_card_economy.gd")
const Turns := preload("res://core/expedition/consumable_card_turns.gd")
const Progression := preload("res://core/expedition/consumable_progression_v1.gd")


static func enabled(session) -> bool:
	return session != null and session.cards != null and session.cards.rules_revision == 4


static func configure_profile(profile: ChampionProgressionProfile) -> void:
	var rules: Dictionary = Catalog.data().rules
	profile.level_cap = 12
	profile.cumulative_xp_thresholds = PackedInt32Array(rules.xpThresholds)
	profile.base_hp_by_level = PackedInt32Array(rules.hp)
	profile.base_prowess_by_level = PackedInt32Array(rules.prowess)
	# Attribute allocation belongs to the saved cards profile; the shared
	# progression still owns XP, levels and encounter receipts.
	profile.attribute_point_levels = PackedInt32Array()
	profile.mastery_point_levels = PackedInt32Array()
	profile.wisdom_cap = 0
	profile.purchased_mastery_cap = 0
	for key in ["first_capstone_level", "second_capstone_level", "specialist_summit_level", "mythic_junction_level", "apotheosis_level"]:
		profile.set(key, 12)


static func prepare(session, selection: Dictionary, inventory: RunInventory) -> Dictionary:
	if not session.needs_preparation or not session.route.current_node_id.is_empty() or not Catalog.valid_departure(selection):
		return {"success": false, "message": "Préparez 15 copies normales, au plus 3 par famille."}
	session.build.class_mode = true
	session.cards.initialize_deck(selection)
	session.cards.run_seed = session.route.seed
	session.cards.bestiary_revision = 1 if session.route.get_catalog_revision() == 6 else 0
	session.card_inventory = inventory
	if inventory != null:
		for item in inventory.get_slots():
			if item != null: inventory.take_instance(item.instance_id)
	session.gold = session.cards.gold
	session.needs_preparation = false
	session.preparation_draft.clear()
	var difficulty := str(selection.get("difficulty_id", "normal"))
	if difficulty == "standard_v2": difficulty = "normal"
	session.route.initialize(session.route.seed, session.route.get_catalog_revision(), difficulty)
	rebuild(session)
	session.character.unit.current_hp = session.character.unit.max_hp.get_int()
	session.last_message = "Départ · 15 copies consommables · main de 5 · 40 oboles"
	session.journal.append(session.last_message)
	return {"success": true, "message": session.last_message}


static func rebuild(session, proportional := false, restoring := false, allow_migration := true) -> void:
	session.route.consumable_cards_enabled = true
	session.route.consumable_bestiary_revision = session.cards.bestiary_revision
	var hero: Unit = session.character.unit
	var maximum := hero.max_hp.get_int()
	var hp := hero.current_hp
	if allow_migration and not session.needs_preparation and session.cards.migrate_prototype():
		proportional = true
		session.journal.append("Prototype v1 · anciens attributs remboursés ; points élémentaires et aptitudes disponibles. PV conservés proportionnellement.")
	if not restoring and not session.equipment_health_basis.is_empty() and hp != equipment_hp(session, maximum):
		session.equipment_health_basis.clear()
	if proportional and session.equipment_health_basis.is_empty():
		session.equipment_health_basis = {"hp": hp, "maximum": maxi(1, maximum)}
	Turns.bind_hero(hero, session.cards)
	Turns.rebuild(hero, session.cards)
	if proportional:
		hero.current_hp = equipment_hp(session, hero.max_hp.get_int())
	elif not restoring and maximum != hero.max_hp.get_int():
		session.equipment_health_basis.clear()
	session.gold = session.cards.gold
	session.character.champion_progression.current_hp = hero.current_hp


static func equipment_hp(session, maximum: int) -> int:
	var basis: Dictionary = session.equipment_health_basis
	return clampi(int(floor(float(basis.hp) / float(basis.maximum) * maximum + .5)), 1, maximum)


static func encounter(session) -> Dictionary:
	var index := 1
	for id in session.route.completed_node_ids:
		for node in session.route.nodes:
			if str(node.id) == id and ExpeditionRouteCatalog.is_combat(str(node.kind)):
				index += 1
	var row: Dictionary = Catalog.data().route[clampi(index - 1, 0, 11)].duplicate(true)
	row.kind = session.route.get_current_node().get("kind", "normal")
	return row


static func award(session, node: Dictionary) -> void:
	session.equipment_health_basis.clear()
	var cards = session.cards
	var hero: Unit = session.character.unit
	var previous_hp := hero.current_hp
	var previous_max := hero.max_hp.get_int()
	var gained_xp := 0
	var gained_gold := 0
	if ExpeditionRouteCatalog.is_combat(str(node.kind)):
		var definition := encounter(session)
		# Tests and imported boundary saves may enter without mounting Battle.
		if not cards.loot_commitments.has(str(definition.index)):
			Economy.commit_loot(cards, definition, ["encounter"] as Array[String])
		var roster: Array[String] = []
		roster.assign(cards.loot_commitments[str(definition.index)].keys())
		var result := Economy.collect_victory(cards, definition, roster)
		var reward: Dictionary = result.get("reward", {})
		gained_xp = int(reward.get("xp", 0))
		gained_gold = int(reward.get("gold", 0))
		var xp: Dictionary = session.character.award_encounter_xp(StringName("catabase:%d:%s" % [session.route.seed, node.id]), gained_xp, true)
		cards.battle_results[str(node.id)] = {
			"xp": gained_xp, "gold": gained_gold,
			"level_before": xp.get("level_before", cards.level), "level_after": cards.level,
			"xp_after": cards.experience, "turns": cards.round_index,
			"card_families": cards.last_drops.map(func(uid): return cards.copy_for(uid).family),
			"enemies": {"forfeited": reward.get("forfeited", []).duplicate()}, "reviewed": false,
		}
		cards.finish_combat()
		session.combat_checkpoint.clear()
		if int(xp.get("levels_gained", 0)) > 0 and int(node.depth) != 20:
			session.advancement_from_level = int(xp.level_before)
			session.advancement_step = "advancement"
	session.build.grant_depth_reward(int(node.depth))
	session.build.sync_level(session.character.champion_progression.current_level)
	session.awarded_node_ids.append(str(node.id))
	rebuild(session, false, false, false)
	# Champion progression also rebuilds its base stats. Apply the final maximum
	# increase once, including the card equipment, without a second level heal.
	hero.current_hp = mini(hero.max_hp.get_int(), previous_hp + maxi(0, hero.max_hp.get_int() - previous_max))
	session.character.champion_progression.current_hp = hero.current_hp
	# Finish the old encounter and its level heal before migrating its investment.
	if cards.prototype_revision == 0: rebuild(session)
	session.last_message = "%s franchi · +%d XP · +%d oboles · %d copies trouvées" % [node.title, gained_xp, gained_gold, cards.last_drops.size() if gained_xp > 0 else 0]
	session.journal.append(session.last_message)


static func can_edit_progression(session) -> bool:
	return enabled(session) and session.cards.prototype_revision == 1 and not session.cards.combat_started and session.route.phase in ["map", "reward"]


static func before_first_combat(session) -> bool:
	# Victory is awarded before the route marks the node completed on departure.
	if not session.cards.battle_results.is_empty(): return false
	for id in session.route.completed_node_ids:
		for node in session.route.nodes:
			if node.id == id and ExpeditionRouteCatalog.is_combat(str(node.kind)): return false
	return true


static func correction_available(session) -> bool:
	if not can_edit_progression(session): return false
	var node: Dictionary = session.route.get_current_node()
	return session.route.phase == "reward" and int(node.get("depth", 0)) in Progression.HALTS and str(node.get("id", "")) not in session.cards.correction_visits


static func full_reorientation_available(session) -> bool:
	if not can_edit_progression(session) or session.cards.full_reorientation_used or session.cards.level < 8: return false
	return session.route.phase == "reward" and int(session.route.get_current_node().get("depth", 0)) in Progression.FULL_RESET_DEPTHS


static func allocate_progression(session, masteries: Dictionary, aptitudes: Dictionary) -> bool:
	if not can_edit_progression(session): return false
	var cards = session.cards
	if not Progression.valid_allocation(masteries, Progression.ELEMENTS, Progression.element_budget(cards.level), 26) or not Progression.valid_allocation(aptitudes, Progression.APTITUDES, Progression.aptitude_budget(cards.level), 3): return false
	var refund := Progression.refunded(cards.masteries, masteries)
	var initial := before_first_combat(session)
	if not initial and Progression.refunded(cards.aptitudes, aptitudes) > 0: return false
	if not initial and refund > 0 and (refund > 2 or not correction_available(session)): return false
	if masteries == cards.masteries and aptitudes == cards.aptitudes: return false
	if not initial and refund > 0: cards.correction_visits.append(str(session.route.current_node_id))
	cards.masteries = masteries.duplicate(true)
	cards.aptitudes = aptitudes.duplicate(true)
	rebuild(session, true)
	cards.changed.emit()
	return true


static func full_reorientation(session) -> bool:
	if not full_reorientation_available(session): return false
	var cards = session.cards
	cards.full_reorientation_used = true
	cards.masteries = Progression.empty_elements()
	cards.aptitudes = Progression.empty_aptitudes()
	cards.specialization = ""
	rebuild(session, true)
	cards.changed.emit()
	return true


static func is_market(session) -> bool:
	var node: Dictionary = session.route.get_current_node()
	return session.route.phase == "reward" and not node.get("preparation_only", false) and str(node.get("service_profile", node.get("kind", ""))) == "merchant"


static func services(session) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var node: Dictionary = session.route.get_current_node()
	if session.route.phase != "reward" or not ExpeditionRouteCatalog.is_halt(str(node.get("kind", ""))) or node.get("preparation_only", false): return result
	var used: Array = session.hub_used_ids.get(str(node.id), [])
	var profile := str(node.get("service_profile", node.kind))
	if profile == "hub":
		result.append({"id": "rest", "kind": "hub", "title": "Le feu des compagnons", "cost": 0, "description": "Récupérer %d %% des PV maximum, une fois dans ce refuge." % roundi(session.refuge_heal_fraction() * 100)})
	elif profile == "merchant":
		var stock := Economy.market(session.cards, str(node.id), int(encounter(session).index))
		for family in stock.singles:
			if int(stock.singles[family]) > 0:
				result.append({"id": "cc2:single:" + str(family), "kind": "merchant", "title": Catalog.card(family).name, "cost": 8, "description": "Une copie normale rejoint votre réserve."})
		if not stock.bags.is_empty(): result.append({"id": "cc2:bag", "kind": "merchant", "title": "Sac de six copies normales", "cost": 36, "description": "Six copies, contenu fixé pour cette visite."})
		if int(stock.heal) > 0: result.append({"id": "cc2:heal", "kind": "merchant", "title": "Soin", "cost": 25, "description": "Récupérer 30 % des PV maximum."})
		for key in ["equipment", "relics"]:
			for id in stock[key]:
				for item in Catalog.data()[key]:
					if item.id == id:
						var definition := preload("res://core/expedition/consumable_cards_content.gd").items().get_definition(StringName("cc2_" + str(id)))
						result.append({"id": "cc2:%s:%s" % ["equipment" if key == "equipment" else "relic", id], "kind": "merchant", "title": item.name, "cost": int(item.price), "description": definition.description})
	else:
		result.append({"id": "lore", "kind": "lore", "title": "Écouter les noms oubliés", "cost": 0, "description": "Révéler un passage à venir et recevoir 20 oboles."})
	for entry in result:
		entry.used = entry.id in used
		entry.available = not entry.used and session.gold >= int(entry.cost)
	return result


static func service(session, id: String) -> Dictionary:
	for entry in services(session):
		if entry.id != id or not entry.available: continue
		var node_id: String = session.route.current_node_id
		if id.begins_with("cc2:"):
			var parts := id.split(":")
			var request := {"id": "%s:%d" % [id, session.cards.receipts.size()], "kind": parts[1]}
			if parts.size() > 2: request["family" if parts[1] == "single" else "item"] = parts[2]
			var result := Economy.transact(session.cards, node_id, request)
			if not result.get("success", false): return result
			if parts[1] == "heal": session._heal_fraction(float(result.receipt.heal_fraction))
		else:
			if id == "rest": session._heal_fraction(session.refuge_heal_fraction())
			if id == "lore":
				session.route.reveal_next_hidden_node()
				session.cards.gold += 20
			if not session.hub_used_ids.has(node_id): session.hub_used_ids[node_id] = []
			session.hub_used_ids[node_id].append(id)
		session.gold = session.cards.gold
		return {"success": true, "message": entry.title}
	return {"success": false, "message": "Ce service n'est pas disponible."}
