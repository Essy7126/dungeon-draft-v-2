class_name ExpeditionSession
extends RefCounted
## Destination rewards are transactions. Reopening a screen cannot reroll them.

var route := ExpeditionRouteState.new()
var challenges := preload("res://core/expedition/catabase_challenge_state.gd").new()
var build := ExpeditionBuildState.new()
var character: CharacterRunState
var gold: int = 0
var awarded_node_ids: Array[String] = []
var journal: Array[String] = []
var reward_spell_id: String = ""
var reward_item_id: String = ""
var last_message := "Achille entre dans Catabase avec ses quatre techniques habituelles."
var hub_used_ids: Dictionary = {}
var hub_stock_ids: Array[String] = []
var branch_receipts: Dictionary = {}
var needs_preparation := false
var advancement_step := ""
var advancement_from_level := 0
var cards: CatabaseCards = null
var card_inventory: RunInventory = null


func initialize(state: CharacterRunState, seed_value: int, selected_difficulty: String = "normal", catalog_revision: int = ExpeditionRouteCatalog.REVISION) -> void:
	character = state
	character.unit.set_meta("ct_session", weakref(self))
	route.initialize(seed_value, catalog_revision, selected_difficulty)
	character.unit.set_meta("ct_balance_revision", route.get_balance_revision())
	build.initialize(state)
	gold = 0
	advancement_step = ""
	advancement_from_level = 0
	hub_used_ids.clear()
	hub_stock_ids.clear()
	branch_receipts.clear()
	awarded_node_ids.clear()
	journal.clear()


func is_editable() -> bool:
	return not awarded_node_ids.is_empty() and route.phase in ["map", "reward"]


func prepare_start(raw_selection: Dictionary, inventory: RunInventory, item_catalog: ItemCatalog) -> Dictionary:
	var selection := raw_selection.duplicate(true)
	if cards != null and cards.rules_revision >= 2:
		selection["card_families"] = CatabaseCards.starter_families(selection)
	var selected_difficulty := str(selection.get("difficulty_id", route.difficulty_id))
	selection.erase("difficulty_id")
	if selected_difficulty not in ["normal", "easy"] or (route.get_balance_revision() == 0 and selected_difficulty != "normal"):
		return _failure("Ce mode de difficulté n'est pas disponible pour cette traversée.")
	if not needs_preparation or not route.current_node_id.is_empty() or not CatabasePreparationCatalog.valid(selection):
		return _failure("Cette préparation n'est pas disponible.")
	var ids: Array[String] = ["catabase_ct_" + String(selection.weapon), "catabase_ct_" + String(selection.armor), "ct_relic_" + String(selection.relic), "ct_supply_" + String(selection.supply)]
	if inventory == null or inventory.get_empty_slot_count() < 4: return _failure("Quatre places libres sont nécessaires pour préparer le départ.")
	for id in ids:
		if item_catalog.get_definition(StringName(id)) == null or not inventory.can_accept(StringName(id)): return _failure("Un objet de préparation est indisponible.")
	var service := EquipmentService.new()
	if not service.initialize(item_catalog): return _failure("Le catalogue d'équipement est invalide.")
	var before_inventory := inventory.to_snapshot()
	var before_equipment := character.equipment_loadout.to_snapshot()
	for index in ids.size():
		var added := inventory.try_add(StringName(ids[index]))
		var ok := bool(added.get("success", false))
		if ok and index < 2:
			ok = bool(service.equip(inventory, character, added.instance_ids[0], ItemDefinition.EquipmentSlot.WEAPON if index == 0 else ItemDefinition.EquipmentSlot.ARMOR).get("success", false))
		if not ok:
			inventory.restore_snapshot(before_inventory)
			character.equipment_loadout.restore_snapshot(before_equipment, item_catalog)
			service.rebuild_state(character)
			return _failure("La préparation a été annulée sans consommer d'objet.")
	if not build.configure_start(selection):
		inventory.restore_snapshot(before_inventory)
		character.equipment_loadout.restore_snapshot(before_equipment, item_catalog)
		service.rebuild_state(character)
		return _failure("Le choix de techniques n'est pas valide.")
	if route.get_balance_revision() >= 1:
		route.initialize(route.seed, route.get_catalog_revision(), selected_difficulty)
	gold = 60
	card_inventory = inventory
	if cards != null: cards.initialize_deck(selection)
	needs_preparation = false
	last_message = "Départ : %s · %s · 60 oboles" % [CatabasePreparationCatalog.WEAPONS[selection.weapon][0], CatabasePreparationCatalog.ARMORS[selection.armor][0]]
	journal.append(last_message)
	return {"success": true, "message": last_message}


func enter(node_id: String) -> bool:
	if needs_preparation or not advancement_step.is_empty(): return false
	if cards != null and not cards.valid_deck(cards.active): return false
	if not route.choose_node(node_id):
		return false
	character.begin_encounter()
	reward_spell_id = ""
	reward_item_id = ""
	hub_stock_ids.clear()
	build.is_editable = route.phase != "combat"
	if route.phase == "combat":
		build.begin_encounter("catabase:%d:%s" % [route.seed, node_id])
		if cards != null: cards.prepare_entry()
	else:
		if cards != null: cards.sale_undo.clear()
		award_destination()
		if cards != null: cards.shop()
	return true


func combat_won() -> bool:
	if not route.mark_combat_won():
		return false
	if challenges.enabled:
		challenges.finish_combat(6 if int(route.get_current_node().depth) >= 3 else 5)
	_clear_encounter_effects()
	build.is_editable = true
	award_destination()
	return true


func _clear_encounter_effects() -> void:
	var hero := character.unit
	for entry in hero.get_active_statuses():
		var status: StatusData = entry.get("data")
		if status != null:
			hero.remove_status(status.get_effective_status_id(), entry.get("source"), true)
	for name in ["max_hp", "max_ap", "max_mp", "initiative", "attack_power", "armure", "resist_magique", "esquive", "crit_chance", "crit_multi", "force"]:
		var stat := hero.get(name) as Stat
		stat.clear_temporary_modifiers()
	hero.clear_shield()
	hero.reset_combat_resources()
	hero.current_hp = mini(hero.current_hp, hero.max_hp.get_int())


func award_destination() -> void:
	var node := route.get_current_node()
	if route.phase != "reward" or str(node.id) in awarded_node_ids:
		return
	var depth := int(node.depth)
	var xp := ExpeditionRunFactory.xp_for(node)
	var result: Dictionary = {}
	var previous_level := character.champion_progression.current_level
	if xp > 0:
		result = character.award_encounter_xp(StringName("catabase:%d:%s" % [route.seed, node.id]), xp, true)
	if not build.starting_selection.is_empty() and character.champion_progression.current_level > previous_level and not (route.get_balance_revision() >= 1 and depth == 20):
		advancement_from_level = previous_level
		advancement_step = "level_up"
	build.grant_depth_reward(depth)
	build.sync_level(character.champion_progression.current_level)
	var gained_gold := 65 if str(node.kind) == "elite" else 35
	if str(node.kind) in ["normal", "elite", "boss"]:
		gold += gained_gold
	else:
		gained_gold = 0
	awarded_node_ids.append(str(node.id))
	if cards != null:
		cards.grant_loot(node)
		cards.sync_learned()
		if not advancement_step.is_empty(): cards.progression_offers()
	last_message = "%s franchi · +%d XP · +%d oboles" % [node.title, int(result.get("gained_xp", 0)), gained_gold]
	journal.append(last_message)
	if challenges.enabled and xp > 0 and (route.get_balance_revision() == 0 or not challenges.contract.is_empty()):
		journal.append(challenges.result_text)


func reward_options(item_catalog: ItemCatalog, inventory: RunInventory = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if route.phase != "reward":
		return result
	var node := route.get_current_node()
	if int(node.depth) == ExpeditionRouteCatalog.DEPTH_COUNT:
		return [{"id": "finish", "title": "Achever la Catabase", "description": "Votre chemin. Votre Achille."}]
	if bool(node.get("preparation_only", false)):
		return [{"id": "leave_hub", "title": "Affronter Pâris", "description": "Vérifiez vos techniques, votre équipement et vos fournitures. Aucun soin n'est offert ici."}]
	if ExpeditionRouteCatalog.is_halt(str(node.kind)):
		hub_services(item_catalog)
		return [{"id": "leave_hub", "title": "Reprendre le chemin", "description": "Terminer les interactions de cette halte et rejoindre la carte."}]
	var technique_window := bool(node.get("highlight_build_reward", false)) if route.get_balance_revision() >= 1 else (int(node.depth) in [3, 6, 10, 14, 18] or str(node.kind) == "elite")
	if technique_window:
		if str(node.reward) == "elemental" and not build.is_axis_discovered("elements"):
			result.append({"id": "discover:elements", "branch_id": "elements", "title": "Découvrir les braises du Styx", "description": "Ouvrir la branche élémentaire de l'arbre. Vos points de maîtrise permettent ensuite d'apprendre ses techniques."})
		elif cards == null:
			var card := _spell_card(str(node.reward))
			if not card.is_empty():
				result.append(card)
	var item := _equipment_offer(item_catalog)
	if not item.is_empty():
		result.append(item)
	if not build.starting_selection.is_empty():
		var relics := CatabasePreparationCatalog.relic_items()
		var offset := posmod(hash("%d:%s:relic" % [route.seed, node.id]), relics.size())
		for index in relics.size():
			var relic: ItemDefinition = relics[(offset + index) % relics.size()]
			if inventory != null and inventory.get_slots().any(func(instance): return instance != null and instance.definition_id == relic.item_id): continue
			result.append({"id": "relic:" + String(relic.item_id), "item_id": String(relic.item_id), "title": relic.display_name, "description": relic.description})
			break
	match str(node.kind):
		"hub":
			result.append({"id": "rest", "title": "Le feu des compagnons", "description": "Récupérer 30 % de vos PV maximum. Une seule faveur à ce refuge."})
		"event":
			result.append({"id": "wager", "title": "Le prix du sang", "description": "Sacrifier 15 % des PV maximum (non létal) pour 100 oboles. Un pari pour les prochains refuges."})
			result.append({"id": "scout", "title": "Suivre les cendres", "description": "Révéler un passage secret à venir et gagner 25 oboles."})
		_:
			var provisions_gold: int = CatabaseCards.PROVISIONS_GOLD if cards != null else 40
			result.append({"id": "supplies", "gold_amount": provisions_gold, "title": "Provisions du voyage" if cards != null else "Conserver le butin", "description": "Gagner %d oboles et récupérer 5 %% des PV maximum.%s" % [provisions_gold, " Les cartes obtenues restent à vous." if cards != null else ""]})
	return result


func claim(option_id: String, inventory: RunInventory, item_catalog: ItemCatalog) -> Dictionary:
	if not advancement_step.is_empty():
		return _failure("Terminez votre montée de niveau avant de choisir le butin.")
	if route.phase != "reward":
		return _failure("La récompense a déjà été choisie.")
	var selected: Dictionary = {}
	for option in reward_options(item_catalog, inventory):
		if option.id == option_id:
			selected = option
	if selected.is_empty():
		return _failure("Cette proposition n'est pas disponible.")
	if cards == null and int(route.get_current_node().depth) == ExpeditionBuildState.CAPACITY_DEPTH and build.to_snapshot().get("depth_eight_choice", "") == "":
		return _failure("Choisissez d'abord le sixième emplacement ou sa mutation exclusive.")
	if selected.has("branch_id"):
		var learned: Dictionary = build.unlock_branch(str(selected.branch_id))
		if not bool(learned.get("success", false)):
			return _failure(str(learned.get("reason", "Branche indisponible.")))
		branch_receipts[str(selected.branch_id)] = route.current_node_id
	elif selected.has("spell_id"):
		if character.loadout.knows_spell_id(StringName(selected.spell_id)):
			gold += 40
		elif not bool(build.learn_spell_card(StringName(selected.spell_id)).get("success", false)):
			return _failure("Cette technique ne peut pas être apprise.")
	elif selected.has("item_id"):
		var cost := int(selected.get("cost", 0))
		if gold < cost:
			return _failure("Il manque %d oboles." % (cost - gold))
		var granted := inventory.try_add(StringName(selected.item_id), 1)
		if not bool(granted.get("success", false)):
			return _failure("Libérez une place dans l'inventaire avant de prendre cet objet.")
		gold -= cost
	else:
		match option_id:
			"rest": _heal_fraction(refuge_heal_fraction())
			"supplies":
				gold += CatabaseCards.PROVISIONS_GOLD if cards != null else 40
				_heal_fraction(0.05)
			"scout":
				route.reveal_next_hidden_node()
				gold += 25
			"wager":
				var payment := ceili(float(character.unit.max_hp.get_int()) * 0.15)
				if character.unit.current_hp <= payment:
					return _failure("Vos PV sont trop bas pour payer ce tribut.")
				character.unit.current_hp -= payment
				character.unit.hp_changed.emit(character.unit)
				gold += 100
	last_message = str(selected.title)
	journal.append(last_message)
	route.complete_current_node()
	build.is_editable = route.phase == "map"
	return {"success": true, "message": last_message}


func advance_level_step() -> Dictionary:
	match advancement_step:
		"level_up":
			advancement_step = "progression"
			if route.get_balance_revision() >= 1 and character.champion_progression.unspent_attribute_points == 0:
				advancement_step = "advancement" if wants_build_review() else ""
		"progression":
			if character.champion_progression.unspent_attribute_points > 0:
				return _failure("Répartissez vos points de caractéristiques avant de continuer.")
			advancement_step = "advancement" if wants_build_review() else ""
		"advancement": advancement_step = ""
		_: return _failure("Aucune montée de niveau en attente.")
	return {"success": true, "message": "Progression enregistrée."}


func wants_build_review() -> bool:
	return cards != null or route.get_balance_revision() == 0 or bool(route.get_current_node().get("highlight_build_reward", false))


func refuge_heal_fraction() -> float:
	return 0.40 if route.get_balance_revision() >= 1 and route.difficulty_id == "easy" else 0.30


func _heal_fraction(fraction: float) -> void:
	character.unit.heal(roundi(float(character.unit.max_hp.get_int()) * fraction))


## A halt remains open for several transactions. Each service has one receipt.
func hub_services(item_catalog: ItemCatalog) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var node := route.get_current_node()
	if route.phase != "reward" or node.is_empty() or not ExpeditionRouteCatalog.is_halt(str(node.kind)):
		return result
	if bool(node.get("preparation_only", false)):
		return result
	if route.get_balance_revision() >= 1 and str(node.kind) == "lore" and not route.has_future_hidden_node():
		# A late memory cannot reveal a passage the player has already passed.
		# Trade its obsolete gold/reveal reward for one existing tactical supply.
		return _late_memory_services(item_catalog, node)
	var merchant := str(node.kind) == "merchant"
	if hub_stock_ids.is_empty():
		var ids := ExpeditionEquipmentCatalog.item_ids()
		ids.sort()
		var offset := posmod(hash("%d:%s:stock" % [route.seed, node.id]), ids.size())
		for index in 3:
			hub_stock_ids.append(str(ids[(offset + index * 3) % ids.size()]))
	var stock_count := 3 if merchant else 1
	for index in stock_count:
		var item: ItemDefinition = item_catalog.get_definition(StringName(hub_stock_ids[index]))
		if item != null:
			var price := 70 + int(node.depth) * 3 + index * 15
			result.append({"id": "buy:" + str(item.item_id), "kind": "merchant", "item_id": str(item.item_id),
				"title": item.display_name, "cost": price, "description": item.description})
	result.append({"id": "rest", "kind": "hub", "title": "Le feu des compagnons", "cost": 45,
		"description": "Retrouver %d %% des PV maximum. Une récupération par halte." % roundi(refuge_heal_fraction() * 100.0)})
	result.append({"id": "lore", "kind": "lore", "title": "Écouter les noms oubliés", "cost": 0,
		"description": _lore_text(int(node.depth)) + "\nDécouvrir un passage secret encore à venir et recevoir 20 oboles."})
	if not merchant:
		var branch := "elements" if not build.is_axis_discovered("elements") else "serment"
		if not build.is_axis_discovered(branch) and int(node.depth) >= (4 if branch == "elements" else 8):
			result.append({"id": "branch:" + branch, "kind": "sanctuary", "branch_id": branch,
				"title": "Lire les braises du Styx" if branch == "elements" else "Prêter le serment du revenant",
				"cost": 70 if branch == "elements" else 110,
				"description": "Découvrir une nouvelle branche de l'arbre. Les techniques s'achètent ensuite avec vos points de maîtrise."})
		else:
			result.append({"id": "wager", "kind": "sanctuary", "title": "Le tribut du sang", "cost": 0,
				"description": "Payer 15 % des PV maximum pour 80 oboles. Une fois par halte ; impossible si le prix vous tuerait."})
	# Older catalogues retain their original universal halt services.
	var profile := str(node.get("service_profile", ""))
	if not profile.is_empty():
		result = result.filter(func(service: Dictionary) -> bool: return str(service.kind) == profile)
		if profile == "hub":
			for service in result:
				service.cost = 0
				service.description = "Repos offert · retrouver %d %% des PV maximum, une fois." % roundi(refuge_heal_fraction() * 100.0)
	var used: Array = hub_used_ids.get(str(node.id), [])
	for service in result:
		service["used"] = str(service.id) in used
		service["available"] = not service.used and gold >= int(service.cost)
	return result


func use_hub_service(service_id: String, inventory: RunInventory, item_catalog: ItemCatalog) -> Dictionary:
	var selected: Dictionary = {}
	for service in hub_services(item_catalog):
		if str(service.id) == service_id:
			selected = service
	if selected.is_empty():
		return _failure("Ce service n'est pas disponible ici.")
	if bool(selected.used):
		return _failure("Ce service a déjà été utilisé dans cette halte.")
	if gold < int(selected.cost):
		return _failure("Il manque %d oboles." % (int(selected.cost) - gold))
	if selected.has("item_id"):
		var granted := inventory.try_add(StringName(selected.item_id), 1)
		if not bool(granted.get("success", false)):
			return _failure(str(granted.get("error", "Cet objet ne peut pas être ajouté à l'inventaire.")))
	elif selected.has("branch_id"):
		var unlocked: Dictionary = build.unlock_branch(str(selected.branch_id))
		if not bool(unlocked.get("success", false)):
			return _failure(str(unlocked.get("reason", "Branche indisponible.")))
		branch_receipts[str(selected.branch_id)] = route.current_node_id
	else:
		match service_id:
			"rest":
				if character.unit.current_hp >= character.unit.max_hp.get_int():
					return _failure("Vos PV sont déjà au maximum.")
				_heal_fraction(refuge_heal_fraction())
			"lore":
				var secret := route.reveal_next_hidden_node()
				gold += 20
				journal.append(_lore_text(int(route.get_current_node().depth)))
				if not secret.is_empty():
					journal.append("Un passage secret a été reporté sur le parchemin.")
			"wager":
				var payment := ceili(float(character.unit.max_hp.get_int()) * 0.15)
				if character.unit.current_hp <= payment:
					return _failure("Vos PV sont trop bas pour payer ce tribut.")
				character.unit.current_hp -= payment
				character.unit.hp_changed.emit(character.unit)
				gold += 80
	gold -= int(selected.cost)
	var node_id := str(route.current_node_id)
	if not hub_used_ids.has(node_id):
		hub_used_ids[node_id] = []
	hub_used_ids[node_id].append(service_id)
	if selected.has("choice_group"):
		hub_used_ids[node_id].append(str(selected.choice_group))
	last_message = str(selected.title)
	journal.append("%s · %d oboles" % [last_message, int(selected.cost)])
	return {"success": true, "message": last_message}


func _late_memory_services(item_catalog: ItemCatalog, node: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used: bool = "memory_supply" in hub_used_ids.get(str(node.id), [])
	for supply in ["plaque", "souffle"]:
		var item := item_catalog.get_definition(StringName("ct_supply_" + supply))
		if item == null: continue
		result.append({"id": "memory:" + supply, "choice_group": "memory_supply", "kind": "lore", "item_id": str(item.item_id), "cost": 0,
			"title": "Leçon de Chiron · " + item.display_name,
			"description": _lore_text(int(node.depth)) + "\nChoisissez un seul secours pour la suite, à la place des oboles et d'un secret dépassé. " + item.description,
			"used": used, "available": not used})
	return result


func _lore_text(depth: int) -> String:
	if depth <= 4:
		return "Le passeur ne demande pas qui vous étiez. Il demande quel nom vous êtes prêt à laisser sur la rive."
	if depth <= 8:
		return "Chiron enseignait le tir pour apprendre la patience. Ici, les ombres se souviennent surtout des flèches qui n'ont pas été tirées."
	if depth <= 12:
		return "Sous les cendres du Styx, un serment attend un corps vivant. La sixième mémoire n'est pas une arme : c'est le geste auquel vous refuserez de renoncer."
	if depth <= 16:
		return "Les cuirasses des morts sont intactes. Leurs propriétaires avaient appris à arrêter les coups, jamais à choisir leur dernier combat."
	return "Pâris connaît votre ancien talon. Devant sa porte, vous découvrez enfin si votre nouvelle force a créé une autre faiblesse."


func _spell_card(reward_axis: String) -> Dictionary:
	var axis := {"melee": "briseur", "vitality": "sang", "ranged": "chasseur", "mobility": "danseur", "armor": "airain", "healing": "endurance", "control": "briseur", "elemental": "elements"}.get(reward_axis, "") as String
	var candidates: Array[Spell] = []
	for spell_id in build.catalog.card_spell_ids():
		var spell: Spell = build.catalog.get_spell(spell_id)
		if build.is_axis_discovered(build.catalog.get_spell_axis(spell_id)) and not character.loadout.knows_spell_id(spell.get_effective_spell_id()):
			candidates.append(spell)
	if candidates.is_empty() and reward_spell_id.is_empty():
		return {}
	# Prefer an advertised family, then retain an honest discovery fallback.
	var matching: Array[Spell] = []
	for spell in candidates:
		if build.catalog.get_spell_axis(spell.get_effective_spell_id()) == axis:
			matching.append(spell)
	if not matching.is_empty():
		candidates = matching
	candidates.sort_custom(func(a: Spell, b: Spell): return str(a.get_effective_spell_id()) < str(b.get_effective_spell_id()))
	if reward_spell_id.is_empty():
		var index := posmod(hash("%d:%s:spell" % [route.seed, route.current_node_id]), candidates.size())
		reward_spell_id = str(candidates[index].get_effective_spell_id())
	var chosen: Spell = build.catalog.get_spell(reward_spell_id)
	var known := character.loadout.knows_spell_id(chosen.get_effective_spell_id())
	return {"id": "spell:" + reward_spell_id, "spell_id": reward_spell_id, "title": ("Technique connue : " if known else "Apprendre : ") + chosen.spell_name, "description": ("Déjà apprise depuis l'offre : recevez 40 oboles." if known else "Carte de technique · aucun emplacement supplémentaire.\n" + chosen.description)}


func _equipment_offer(item_catalog: ItemCatalog) -> Dictionary:
	var candidates: Array[ItemDefinition] = []
	var alternative_weapon := route.get_balance_revision() >= 1 and int(route.get_current_node().depth) == 2 and not build.starting_selection.is_empty()
	var excluded_weapon := "catabase_ct_" + str(build.starting_selection.get("weapon", ""))
	var equipped_weapon := character.equipment_loadout.get_item(ItemDefinition.EquipmentSlot.WEAPON)
	for item in item_catalog.get_definitions():
		if item.is_equippable() and item.is_compatible_with(&"achilles"):
			if alternative_weapon and (not str(item.item_id).trim_prefix("catabase_ct_") in CatabasePreparationCatalog.WEAPONS or str(item.item_id) == excluded_weapon):
				continue
			if alternative_weapon and equipped_weapon != null and item.item_id == equipped_weapon.definition_id:
				continue
			candidates.append(item)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: ItemDefinition, b: ItemDefinition): return str(a.item_id) < str(b.item_id))
	if reward_item_id.is_empty():
		reward_item_id = str(candidates[posmod(hash("%d:%s:gear" % [route.seed, route.current_node_id]), candidates.size())].item_id)
	var item: ItemDefinition = item_catalog.get_definition(StringName(reward_item_id))
	var cost := 50 if str(route.get_current_node().kind) == "hub" else 0
	return {"id": "item:" + str(item.item_id), "item_id": item.item_id, "cost": cost, "title": item.display_name + (" · 50 oboles" if cost > 0 else ""), "description": item.description}


func _failure(reason: String) -> Dictionary:
	return {"success": false, "message": reason}


func to_snapshot() -> Dictionary:
	var result := {"version": 2, "route": route.to_snapshot(), "build": build.to_snapshot(), "gold": gold, "awarded_node_ids": awarded_node_ids.duplicate(), "journal": journal.duplicate(), "last_message": last_message, "reward_spell_id": reward_spell_id, "reward_item_id": reward_item_id, "hub_used_ids": hub_used_ids.duplicate(true), "hub_stock_ids": hub_stock_ids.duplicate(), "branch_receipts": branch_receipts.duplicate()}
	if challenges.enabled: result["challenges"] = challenges.snapshot()
	result["needs_preparation"] = needs_preparation
	result["advancement_step"] = advancement_step
	result["advancement_from_level"] = advancement_from_level
	if cards != null: result["cards_run"] = cards.snapshot()
	return result


func restore_snapshot(snapshot: Dictionary) -> bool:
	var pending_step: Variant = snapshot.get("advancement_step", "")
	if not pending_step is String or pending_step not in ["", "level_up", "progression", "advancement"]: return false
	var from_level := int(snapshot.get("advancement_from_level", 0))
	# Existing first-six saves may already be waiting on the level's attributes.
	if not snapshot.has("advancement_step") and snapshot.get("build") is Dictionary and snapshot.get("route") is Dictionary:
		if not snapshot.build.get("starting_selection", {}).is_empty() and snapshot.route.get("phase", "") == "reward" and character.champion_progression.unspent_attribute_points > 0 and character.champion_progression.current_level > 1:
			pending_step = "level_up"
			from_level = character.champion_progression.current_level - 1
	if not pending_step.is_empty():
		if not snapshot.get("route") is Dictionary: return false
		if from_level < 1 or from_level >= character.champion_progression.current_level or snapshot.route.get("phase", "") != "reward": return false
	if not snapshot.get("needs_preparation", false) is bool: return false
	var pending_start: bool = snapshot.get("needs_preparation", false)
	var candidate_challenges := preload("res://core/expedition/catabase_challenge_state.gd").new()
	if snapshot.has("challenges"):
		if not snapshot.challenges is Dictionary or not candidate_challenges.restore(snapshot.challenges):
			return false
	elif snapshot.has("deck"):
		# Retired prototype saves resume with the normal loadout; only consequences survive.
		if not snapshot.deck is Dictionary or not candidate_challenges.restore_retired_deck(snapshot.deck):
			return false
	if int(snapshot.get("version", 0)) != 2 or not snapshot.get("route") is Dictionary or not snapshot.get("build") is Dictionary:
		return false
	var candidate_route := ExpeditionRouteState.new()
	if not candidate_route.restore_snapshot(snapshot.route):
		return false
	if pending_start and (not candidate_route.current_node_id.is_empty() or not candidate_route.completed_node_ids.is_empty() or not snapshot.build.get("starting_selection", {}).is_empty()): return false
	var expected: Array[String] = candidate_route.completed_node_ids.duplicate()
	if candidate_route.phase == "reward":
		expected.append(candidate_route.current_node_id)
	if not snapshot.get("awarded_node_ids") is Array or snapshot.awarded_node_ids != expected:
		return false
	if int(snapshot.build.get("completed_depth", -1)) != expected.size() \
			or int(snapshot.build.get("current_level", -1)) != character.champion_progression.current_level:
		return false
	var expected_xp_ids: Array[String] = []
	for id in expected:
		for node in candidate_route.nodes:
			if str(node.id) == id and ExpeditionRouteCatalog.is_combat(str(node.kind)):
				expected_xp_ids.append("catabase:%d:%s" % [candidate_route.seed, id])
	var actual_xp_ids := character.champion_progression.awarded_encounter_ids
	if actual_xp_ids.size() != expected_xp_ids.size():
		return false
	for id in actual_xp_ids:
		if str(id) not in expected_xp_ids:
			return false
	if not snapshot.get("journal") is Array or int(snapshot.get("gold", -1)) < 0 or int(snapshot.get("gold", 0)) > 10000:
		return false
	if not snapshot.get("hub_used_ids") is Dictionary or not snapshot.get("hub_stock_ids") is Array:
		return false
	for id in snapshot.hub_used_ids:
		if id not in expected or not snapshot.hub_used_ids[id] is Array:
			return false
		var seen := {}
		for service in snapshot.hub_used_ids[id]:
			if not service is String or seen.has(service):
				return false
			seen[service] = true
	if snapshot.hub_stock_ids.size() not in [0, 3]:
		return false
	var seen_stock := {}
	for id in snapshot.hub_stock_ids:
		if not id is String or id not in ExpeditionEquipmentCatalog.item_ids() or seen_stock.has(id):
			return false
		seen_stock[id] = true
	if not snapshot.get("branch_receipts") is Dictionary:
		return false
	var discoveries: Array = snapshot.build.get("discovered_branches", [])
	if snapshot.branch_receipts.size() != discoveries.size():
		return false
	for branch in discoveries:
		var receipt: String = str(snapshot.branch_receipts.get(str(branch), ""))
		if receipt not in expected:
			return false
		var receipt_node: Dictionary = {}
		for node in candidate_route.nodes:
			if str(node.id) == receipt:
				receipt_node = node
		if receipt_node.is_empty() or int(receipt_node.depth) < (4 if str(branch) == "elements" else 8):
			return false
		if ExpeditionRouteCatalog.is_halt(str(receipt_node.kind)):
			if "branch:" + str(branch) not in snapshot.hub_used_ids.get(receipt, []):
				return false
		elif str(branch) != "elements" or str(receipt_node.reward) != "elemental":
			return false
	var saved_spell := str(snapshot.get("reward_spell_id", ""))
	if not saved_spell.is_empty() and saved_spell not in build.catalog.card_spell_ids():
		return false
	var saved_axis := build.catalog.get_spell_axis(saved_spell)
	if build.catalog.DISCOVERY_DEPTHS.has(saved_axis) and saved_axis not in discoveries and not build._starting_axis_available(saved_axis, snapshot.build.get("starting_selection", {})):
		return false
	var previous_balance := int(character.unit.get_meta("ct_balance_revision", 0))
	character.unit.set_meta("ct_balance_revision", candidate_route.get_balance_revision())
	if not build.restore_snapshot(snapshot.build):
		character.unit.set_meta("ct_balance_revision", previous_balance)
		return false
	route = candidate_route
	gold = int(snapshot.gold)
	awarded_node_ids.assign(snapshot.awarded_node_ids)
	journal.clear()
	for entry in snapshot.journal:
		journal.append(str(entry).left(500))
	last_message = str(snapshot.get("last_message", "Traversée reprise."))
	reward_spell_id = saved_spell
	reward_item_id = str(snapshot.get("reward_item_id", ""))
	hub_used_ids = snapshot.hub_used_ids.duplicate(true)
	hub_stock_ids.assign(snapshot.hub_stock_ids)
	branch_receipts = snapshot.branch_receipts.duplicate()
	challenges = candidate_challenges
	needs_preparation = pending_start
	advancement_step = pending_step
	advancement_from_level = from_level
	build.is_editable = needs_preparation or is_editable()
	if snapshot.has("cards_run"):
		if not snapshot.cards_run is Dictionary: return false
		cards = CatabaseCards.new()
		cards.bind(self)
		if not cards.restore(snapshot.cards_run, needs_preparation): return false
		cards.migrate_legacy(needs_preparation)
	return true
