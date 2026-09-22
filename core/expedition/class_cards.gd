extends CatabaseCards
const Catalog := preload("res://core/expedition/class_card_catalog.gd")
var ecosystem_revision := 2
var _last_discovery: Dictionary = {}
var card_rewards: Dictionary = {}
var primary_class := "assassin"
var specialization := ""
var masteries: Dictionary = { "assassin": 2, "gardien": 0, "arpenteur": 0, "thaumaturge": 0 }
var spent := 0
var upgraded_ids: Array[String] = []
var corrected := false
var loot_items: Dictionary = { }
var pending_items: Array[String] = []
var battle_results: Dictionary = { }
var _encounter_roster: Dictionary = { }
var _spell_cache: Dictionary = { }
var _gesture_cache: Array[Spell] = []


func _init() -> void:
	rules_revision = 3


func prepare_entry() -> void:
	_encounter_roster.clear()
	super()


func begin_combat() -> void:
	if not combat_started:
		var hero: Unit = owner().character.unit
		if hero.has_meta("ct_class_passive_turn"):
			hero.remove_meta("ct_class_passive_turn")
		_encounter_roster.clear()
		if hero.grid_context != null:
			for enemy: Unit in hero.grid_context.get_units():
				if enemy.team != hero.team:
					_encounter_roster[enemy.unit_name] = int(
						_encounter_roster.get(enemy.unit_name, 0)
					) + 1
	super()


func record_reward(node: Dictionary, xp: Dictionary, gold: int) -> void:
	if battle_results.has(str(node.id)):
		return
	battle_results[str(node.id)] = {
		"card_discovery": _last_discovery.duplicate(true),
		"xp": maxi(0, int(xp.get("gained_xp", 0))),
		"gold": gold,
		"level_before": int(
			xp.get("level_before", owner().character.champion_progression.current_level)
		),
		"level_after": owner().character.champion_progression.current_level,
		"xp_after": owner().character.champion_progression.current_xp,
		"card_families": last_drops.map(
			func(id):
				return str(copy_for(id).family),
		),
		"enemies": _encounter_roster.duplicate(),
		"turns": owner().character.unit.activation_index,
	}


func record_combat(report: CombatReport) -> void:
	var entry: Dictionary = battle_results.get(owner().route.current_node_id, { })
	if entry.is_empty() or report == null:
		return
	entry["duration_seconds"] = maxi(
		0,
		int((report.completed_at_msec - report.started_at_msec) / 1000),
	)
	var character := report.get_character_report(owner().character.character_id)
	if character != null:
		entry["damage_dealt"] = character.damage_dealt
		entry["damage_taken"] = character.damage_taken
		entry["shield"] = character.shield_applied
		entry["kills"] = character.kills


func initialize_deck(selection: Dictionary) -> void:
	if not copies.is_empty() or not Catalog.valid(selection):
		return
	if ecosystem_revision > 0:
		for family in selection.card_families:
			if Catalog.Ecology.tier(family) != 0:
				return
	primary_class = selection.class_id
	for key in masteries:
		masteries[key] = 2 if key == primary_class else 0
	for family in selection.card_families:
		for i in 2:
			active.append(add_copy(str(family), true))
	configure_profile()
	changed.emit()


func configure_profile() -> void:
	var profile = owner().character.champion_progression.profile.duplicate(true)
	profile.wisdom_cap = 0
	profile.wisdom_bonus_per_point = 0.
	profile.glory_success_multiplier = 1.
	owner().character.champion_progression.profile = profile


func points() -> int:
	return mini(6, int(owner().character.champion_progression.current_level / 2)) * 2 - spent


func mastery_cost(id: String) -> int:
	if not masteries.has(id):
		return -1
	var rank := int(masteries[id])
	if rank >= (4 if id == primary_class else 2):
		return -1
	return rank + 1 if id == primary_class else rank + 2


func train(id: String) -> bool:
	var cost := mastery_cost(id)
	if not owner().is_editable() or cost < 0 or points() < cost:
		return false
	masteries[id] += 1
	spent += cost
	changed.emit()
	return true


func specialize(id: String) -> bool:
	if (
		not owner().is_editable() or owner().character.champion_progression.current_level < 4
		or not specialization.is_empty()
	):
		return false
	if not Catalog.SPECS[primary_class].any(
		func(row):
			return row[0] == id,
	):
		return false
	specialization = id
	changed.emit()
	return true


func upgrade_copy(id: String) -> bool:
	var card := copy_for(id)
	if not owner().is_editable() or card.is_empty() or card.get("upgraded", false) or points() < 2:
		return false
	var class_id: String = Catalog.row(card.family)[1]
	if int(masteries[class_id]) < 3:
		return false
	card.upgraded = true
	upgraded_ids.append(id)
	spent += 2
	changed.emit()
	return true


func permanent_offer(_offer: Dictionary) -> bool:
	return false


func upgrade_offers() -> Array[Dictionary]:
	return []


func progression_offers() -> Array[String]:
	return []


func _teach(_family: String) -> void:
	pass


func known_family(family: String) -> bool:
	return not Catalog.row(family).is_empty()


func eligible_pool() -> Array[String]:
	return Catalog.pool()


func known_forms(_family: String) -> Array[Spell]:
	return []


func choose_form(_family: String, _spell_id: String) -> bool:
	return false


func weapon_families() -> Array[String]:
	return []


func shop() -> Array:
	var node: Dictionary = owner().route.get_current_node()
	if (
		owner().route.phase != "reward"
		or not ExpeditionRouteCatalog.is_halt(str(node.get("kind", "")))
		or int(node.get("depth", 0)) == 19
	):
		return []
	var id := str(node.id)
	if not stocks.has(id):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("class_shop:%d:%s" % [owner().route.seed, id])
		var pool := Catalog.reward_pool("", int(node.depth)) if ecosystem_revision > 0 else Catalog.legacy_pool()
		var stock: Array = []
		for i in (6 if ecosystem_revision > 0 else 3):
			var index := rng.randi_range(0, pool.size() - 1)
			stock.append({ "family": pool[index], "sold": false })
			pool.remove_at(index)
		stocks[id] = stock
	return stocks[id]


func resolve_progression(action: String, _value := "", _replace_id := "") -> bool:
	if action != "skip" or not owner().is_editable() or owner().advancement_step != "advancement":
		return false
	if owner().character.champion_progression.current_level >= 4 and specialization.is_empty():
		return false
	owner().advancement_step = ""
	changed.emit()
	return true


func family_spell(family: String) -> Spell:
	var row := Catalog.row(family)
	if row.is_empty():
		return null
	var key := "family:%s:%d" % [family, int(masteries[row[1]])]
	if not _spell_cache.has(key):
		_spell_cache[key] = Catalog.make_spell(family, int(masteries[row[1]]))
	return _spell_cache[key]


func spells_for(id: String) -> Array[Spell]:
	var result: Array[Spell] = []
	var card := copy_for(id)
	if card.is_empty():
		return result
	var row := Catalog.row(card.family)
	if not row.is_empty():
		var key := "%s:%d:%s" % [id, int(masteries[row[1]]), str(card.get("upgraded", false))]
		if not _spell_cache.has(key):
			_spell_cache[key] = Catalog.make_spell(
				card.family,
				int(masteries[row[1]]),
				bool(card.get("upgraded", false)),
			)
		result.append(_spell_cache[key])
	return result


func title_for(id: String) -> String:
	var spells := spells_for(id)
	return spells[0].spell_name if not spells.is_empty() else "Carte inconnue"


func weapon_spells() -> Array[Spell]:
	if not _gesture_cache.is_empty():
		return _gesture_cache.duplicate()
	var strike := Catalog.make_spell("a_pierce", 0)
	strike.spell_id = &"class_basic_strike"
	strike.spell_name = "Frappe de secours"
	strike.damage_scaling = Catalog.scaling(.55)
	strike.description = "2 PA · 55 % de Prouesse · contact. Toujours disponible, hors deck."
	var guard := Catalog.make_spell("a_parry", 0)
	guard.spell_id = &"class_basic_guard"
	guard.spell_name = "Se protéger"
	guard.shield_scaling = Catalog.scaling(.2)
	guard.description = "1 PA · 20 % de Prouesse en garde jusqu'au prochain tour. Une fois par tour. Hors deck."
	_gesture_cache.assign([strike, guard])
	return _gesture_cache.duplicate()


func rarity(family: String) -> int:
	if ecosystem_revision > 0:
		return maxi(0, Catalog.Ecology.tier(family) - 1)
	return 0 if Catalog.row(family).is_empty() else (1 if Catalog.row(family)[3] >= 3 else 0)


func valid_deck(ids: Array[String]) -> bool:
	if ids.size() != 10:
		return false
	var seen := { }
	var counts := { }
	for id in ids:
		var card := copy_for(id)
		if seen.has(id) or card.is_empty() or Catalog.row(card.family).is_empty():
			return false
		seen[id] = true
		counts[card.family] = int(counts.get(card.family, 0)) + 1
		if counts[card.family] > 2:
			return false
	return true


func grant_loot(node: Dictionary) -> void:
	if str(node.kind) not in ["normal", "elite", "boss"] or receipts.has(str(node.id)):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("class_loot:%d:%s" % [owner().route.seed, node.id])
	var depth := int(node.depth)
	last_drops.clear()
	for i in (0 if ecosystem_revision > 0 else (2 if node.kind == "elite" else 1)):
		var foreign := rng.randf() < (.15 if depth <= 3 else .35 if depth <= 12 else .45)
		var classes := Catalog.CLASSES.keys()
		classes.erase(primary_class)
		var chosen: String = classes[rng.randi_range(0, classes.size() - 1)] if foreign else primary_class
		var pool := Catalog.legacy_pool(chosen)
		last_drops.append(add_copy(pool[rng.randi_range(0, pool.size() - 1)]))
	if ecosystem_revision >= 2:
		var drop := preload("res://core/expedition/card_drop_catalog.gd").roll(owner().route.seed, node, primary_class, card_drought())
		_last_discovery = drop.factors
		for family in drop.families: last_drops.append(add_copy(family))
	receipts[str(node.id)] = last_drops.duplicate()
	if ecosystem_revision == 1 and depth < 20:
		var offers: Array[String] = []
		for i in 3:
			var pool := Catalog.reward_pool(primary_class if i < 2 else "", depth)
			if i == 0:
				var tier := 3 if depth >= 10 else 2 if depth >= 4 else 1
				pool = pool.filter(func(family): return Catalog.Ecology.tier(family) == tier)
			pool = pool.filter(func(family): return family not in offers)
			offers.append(pool[rng.randi_range(0, pool.size() - 1)])
		card_rewards[str(node.id)] = {"offers": offers, "resolved": false, "chosen": ""}
	var items: Array[String] = []
	var tier := mini(3, 1 + int(depth / 7))
	var slot := 0 if receipts.size() == 1 else rng.randi_range(0, 5)
	items.append("class_gear_%d_%d_%d" % [tier, slot, rng.randi_range(0, 3)])
	if node.kind == "elite":
		items.append("ct_relic_" + ["clou", "coupe", "obole"][rng.randi_range(0, 2)])
	if node.kind == "elite":
		items.append(
			preload("res://core/expedition/class_rune_catalog.gd").ROWS.keys()[
				rng.randi_range(0, 3)
			]
		)
	elif rng.randf() < .3:
		items.append("ct_supply_" + ["onguent", "souffle", "plaque", "sel"][rng.randi_range(0, 3)])
	loot_items[str(node.id)] = items.duplicate()
	pending_items.append_array(items)
	collect_pending()
	changed.emit()


func collect_pending() -> void:
	var inventory: RunInventory = owner().card_inventory
	if inventory == null:
		return
	for id in pending_items.duplicate():
		if inventory.try_add(StringName(id)).get("success", false):
			pending_items.erase(id)


func card_drought() -> int:
	var drought := 0
	# Route order is canonical, including receipts whose cards were later sold.
	var visited: Array = owner().route.completed_node_ids.duplicate()
	if owner().route.current_node_id not in visited: visited.append(owner().route.current_node_id)
	visited.reverse()
	for node_id in visited:
		if not receipts.has(node_id): continue
		if not receipts[node_id].is_empty(): break
		drought += 1
	return drought


func pending_card_reward() -> Dictionary:
	var reward: Dictionary = card_rewards.get(owner().route.current_node_id, {})
	return reward if not reward.get("resolved", true) else {}


## Empty family skips. Empty replacement keeps the new card in reserve.
func choose_card_reward(family: String, replace_id := "") -> bool:
	var reward := pending_card_reward()
	if not owner().is_editable() or owner().route.phase != "reward" or reward.is_empty():
		return false
	if family != "" and family not in reward.offers:
		return false
	if replace_id != "":
		if family == "" or replace_id not in active:
			return false
		var count := 0
		for id in active:
			if id != replace_id and copy_for(id).family == family: count += 1
		if count >= 2: return false
	if family != "":
		var id := add_copy(family)
		if replace_id != "": active[active.find(replace_id)] = id
		last_drops.assign([id])
		receipts[owner().route.current_node_id] = [id]
		var report: Dictionary = battle_results.get(owner().route.current_node_id, {})
		if not report.is_empty(): report.card_families = [family]
	reward.resolved = true
	reward.chosen = family
	changed.emit()
	return true


func snapshot() -> Dictionary:
	var data := super()
	data.ecosystem_revision = ecosystem_revision
	data.card_rewards = card_rewards.duplicate(true)
	data.primary_class = primary_class
	data.specialization = specialization
	data.masteries = masteries.duplicate()
	data.spent = spent
	data.loot_items = loot_items.duplicate(true)
	data.pending_items = pending_items.duplicate()
	data.battle_results = battle_results.duplicate(true)
	data.upgraded_ids = upgraded_ids.duplicate()
	data.corrected = corrected
	return data


func restore(data: Dictionary, pending_start: bool) -> bool:
	var revision: Variant = data.get("ecosystem_revision", 0)
	if not (revision is int or revision is float) or not is_finite(float(revision)) or float(revision) != int(revision) or int(revision) not in [0, 1, 2]:
		return false
	var rewards: Variant = data.get("card_rewards", {})
	if not rewards is Dictionary or (revision == 0 and not rewards.is_empty()):
		return false
	for node_id in rewards:
		var reward: Variant = rewards[node_id]
		if node_id not in owner().awarded_node_ids or not reward is Dictionary:
			return false
		if not reward.get("offers") is Array or reward.offers.size() != 3 or not reward.get("resolved") is bool:
			return false
		var seen := {}
		for family in reward.offers:
			if not family is String or Catalog.row(family).is_empty() or Catalog.Ecology.tier(family) == 0 or seen.has(family):
				return false
			seen[family] = true
		if not reward.get("chosen") is String or (reward.chosen != "" and reward.chosen not in reward.offers):
			return false
		if not reward.resolved and (reward.chosen != "" or node_id != owner().route.current_node_id or owner().route.phase != "reward"):
			return false
	var summaries: Variant = data.get("battle_results", { })
	if not summaries is Dictionary:
		return false
	for node_id in summaries:
		if node_id not in owner().awarded_node_ids or not summaries[node_id] is Dictionary:
			return false
		var entry: Dictionary = summaries[node_id]
		var discovery: Variant = entry.get("card_discovery", {})
		if not discovery is Dictionary: return false
		if not discovery.is_empty():
			for key in ["resonance", "exploration", "danger", "memory", "drought"]:
				var value: Variant = discovery.get(key)
				if not (value is int or value is float) or not is_finite(float(value)) or float(value) != int(value) or value < 0 or value > 100: return false
			if not discovery.get("chances") is Array or discovery.chances.size() < 2 or discovery.chances.size() > 4: return false
			for chance in discovery.chances:
				if not (chance is int or chance is float) or not is_finite(float(chance)) or float(chance) != int(chance) or chance < 0 or chance > 100: return false
		if entry.has("reviewed") and not entry.reviewed is bool:
			return false
		for key in ["xp", "gold", "level_before", "level_after", "xp_after", "turns"]:
			if (
				not (entry.get(key) is int or entry.get(key) is float)
				or not is_finite(float(entry[key]))
				or float(entry[key]) != int(entry[key]) or int(entry[key]) < 0
			):
				return false
		for key in ["duration_seconds", "damage_dealt", "damage_taken", "shield", "kills"]:
			if entry.has(key):
				if not (entry[key] is int or entry[key] is float):
					return false
				if (
					not is_finite(float(entry[key]))
					or float(entry[key]) != int(entry[key]) or int(entry[key]) < 0
				):
					return false
		if not entry.get("enemies") is Dictionary or not entry.get("card_families") is Array:
			return false
		for family in entry.card_families:
			if not family is String or Catalog.row(family).is_empty():
				return false
		for enemy in entry.enemies:
			if (
				not enemy is String
				or not (entry.enemies[enemy] is int or entry.enemies[enemy] is float)
				or not is_finite(float(entry.enemies[enemy]))
				or float(entry.enemies[enemy]) != int(entry.enemies[enemy])
				or int(entry.enemies[enemy]) <= 0
			):
				return false
	for field in ["version", "rules_revision", "spent", "serial"]:
		var value: Variant = data.get(field)
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
		if float(value) != int(value) or int(value) < 0:
			return false
	if int(data.get("version", 0)) != 1 or int(data.get("rules_revision", 0)) != 3:
		return false
	if owner().character.champion_progression.wisdom_points != 0:
		return false
	var primary: String = str(data.get("primary_class", ""))
	var ranks: Variant = data.get("masteries")
	if not Catalog.CLASSES.has(primary) or not ranks is Dictionary or ranks.size() != 4:
		return false
	var cost := 0
	for id in Catalog.CLASSES:
		var rank: Variant = ranks.get(id)
		if not (rank is int or rank is float) or float(rank) != int(rank):
			return false
		if int(rank) < (2 if id == primary else 0) or int(rank) > (4 if id == primary else 2):
			return false
		cost += ([0, 0, 0, 3, 7][int(rank)] if id == primary else [0, 2, 5][int(rank)])
	var spec := str(data.get("specialization", ""))
	if (
		not spec.is_empty()
		and (
			owner().character.champion_progression.current_level < 4
			or not Catalog.SPECS[primary].any(
				func(row):
					return row[0] == spec,
			)
		)
	):
		return false
	var upgrades: Variant = data.get("upgraded_ids", [])
	if not upgrades is Array or not data.get("corrected", false) is bool:
		return false
	var seen_upgrades := { }
	for id in upgrades:
		if (
			not id is String or not id.begins_with("card_")
			or not id.trim_prefix("card_").is_valid_int()
			or int(id.trim_prefix("card_")) > int(data.get("serial", -1)) or seen_upgrades.has(id)
		):
			return false
		seen_upgrades[id] = true
	cost += upgrades.size() * 2
	var saved: Variant = data.get("copies")
	if not saved is Array or saved.size() > 200:
		return false
	var ids := { }
	var max_serial := 0
	for card in saved:
		if (
			not card is Dictionary or not card.get("id") is String
			or not card.get("family") is String
		):
			return false
		var id: String = card.id
		if (
			not id.begins_with("card_") or not id.trim_prefix("card_").is_valid_int()
			or ids.has(id) or Catalog.row(card.family).is_empty()
		):
			return false
		if (
			not card.get("bound") is bool or not card.get("favorite") is bool
			or not card.get("upgraded", false) is bool
		):
			return false
		if card.get("upgraded", false):
			if int(ranks[Catalog.row(card.family)[1]]) < 3:
				return false
			if not seen_upgrades.has(id):
				return false
		elif seen_upgrades.has(id):
			return false
		ids[id] = true
		max_serial = maxi(max_serial, int(id.trim_prefix("card_")))
	# Sold upgraded copies do not refund investment. A ledger preserves their cost.
	if (
		int(data.get("spent", -1)) != cost
		or int(data.spent)
		> mini(6, int(owner().character.champion_progression.current_level / 2)) * 2
	):
		return false
	if not data.get("active") is Array or int(data.get("serial", -1)) < max_serial:
		return false
	if (
		not data.get("receipts") is Dictionary or not data.get("loot_items", { }) is Dictionary
		or not data.get("pending_items", []) is Array
	):
		return false
	for node_id in data.receipts:
		if node_id not in owner().awarded_node_ids or not data.receipts[node_id] is Array:
			return false
	var saved_stocks: Variant = data.get("stocks", { })
	if not saved_stocks is Dictionary:
		return false
	for node_id in saved_stocks:
		if (
			node_id not in owner().awarded_node_ids
			or not saved_stocks[node_id] is Array or saved_stocks[node_id].size() != (6 if revision > 0 else 3)
		):
			return false
		for offer in saved_stocks[node_id]:
			if (
				not offer is Dictionary or Catalog.row(str(offer.get("family", ""))).is_empty()
				or not offer.get("sold") is bool
			):
				return false
	for id in data.get("pending_items", []):
		if not id is String or not _valid_item(id):
			return false
	for node_id in data.get("loot_items", { }):
		if node_id not in data.receipts or not data.loot_items[node_id] is Array:
			return false
		for id in data.loot_items[node_id]:
			if not id is String or not _valid_item(id):
				return false
	var old := copies.duplicate(true)
	copies.assign(saved)
	var chosen: Array[String] = []
	for id in data.active:
		if not id is String:
			copies = old
			return false
		chosen.append(id)
	if (
		(pending_start and (not copies.is_empty() or not chosen.is_empty()))
		or (not pending_start and not valid_deck(chosen))
	):
		copies = old
		return false
	primary_class = primary
	# Revision 1 runs adopt actual drops, including an unresolved reward boundary.
	ecosystem_revision = 2 if int(revision) > 0 else 0
	card_rewards = rewards.duplicate(true)
	masteries = ranks.duplicate()
	specialization = spec
	spent = int(data.spent)
	upgraded_ids.assign(upgrades)
	corrected = data.get("corrected", false)
	stocks = saved_stocks.duplicate(true)
	active = chosen
	serial = int(data.serial)
	receipts = data.receipts.duplicate(true)
	loot_items = data.get("loot_items", { }).duplicate(true)
	pending_items.assign(data.get("pending_items", []))
	battle_results = summaries.duplicate(true)
	for entry: Dictionary in battle_results.values():
		var discovery: Dictionary = entry.get("card_discovery", {})
		if not discovery.is_empty():
			for key in ["resonance", "exploration", "danger", "memory", "drought"]:
				discovery[key] = int(discovery[key])
			var chances: Array[int] = []
			for chance in discovery.chances: chances.append(int(chance))
			discovery.chances = chances
		for key in [
			"xp",
			"gold",
			"level_before",
			"level_after",
			"xp_after",
			"turns",
			"duration_seconds",
			"damage_dealt",
			"damage_taken",
			"shield",
			"kills",
		]:
			if entry.has(key):
				entry[key] = int(entry[key])
		for enemy in entry.enemies:
			entry.enemies[enemy] = int(entry.enemies[enemy])
	last_drops.clear()
	for id in data.get("last_drops", []):
		if id is String and ids.has(id):
			last_drops.append(id)
	if int(revision) == 1 and not pending_card_reward().is_empty():
		var node: Dictionary = owner().route.get_current_node()
		receipts.erase(str(node.id))
		var drop := preload("res://core/expedition/card_drop_catalog.gd").roll(owner().route.seed, node, primary_class, card_drought())
		last_drops.clear()
		for family in drop.families: last_drops.append(add_copy(family))
		receipts[str(node.id)] = last_drops.duplicate()
		card_rewards[str(node.id)].resolved = true
		card_rewards[str(node.id)].chosen = ""
		if battle_results.has(str(node.id)):
			battle_results[str(node.id)].card_families = drop.families.duplicate()
			battle_results[str(node.id)].card_discovery = drop.factors.duplicate(true)
			battle_results[str(node.id)].reviewed = false
	configure_profile()
	return true


func _valid_item(id: String) -> bool:
	return (
		preload("res://core/expedition/class_equipment_catalog.gd").has_id(id)
		or preload("res://core/expedition/class_rune_catalog.gd").ROWS.has(id)
		or id
		in [
			"ct_relic_clou",
			"ct_relic_coupe",
			"ct_relic_obole",
			"ct_supply_onguent",
			"ct_supply_souffle",
			"ct_supply_plaque",
			"ct_supply_sel",
		]
	)


func socket_rune(rune_instance: StringName, equipment_instance: StringName) -> bool:
	if not owner().is_editable():
		return false
	var inventory: RunInventory = owner().card_inventory
	var rune := inventory.get_instance(rune_instance)
	var item := inventory.get_instance(equipment_instance)
	if item == null:
		for equipped in owner().character.equipment_loadout.get_equipped_items():
			if equipped.instance_id == equipment_instance:
				item = equipped
				break
	if (
		rune == null or item == null or item.rune_id != &""
		or not preload("res://core/expedition/class_rune_catalog.gd").ROWS.has(
			str(rune.definition_id)
		)
	):
		return false
	var definition := inventory.get_catalog().get_definition(item.definition_id)
	if definition == null or not definition.is_equippable():
		return false
	var taken := inventory.take_instance(rune_instance)
	if not taken.get("success", false):
		return false
	item.rune_id = rune.definition_id
	var service := EquipmentService.new()
	service.initialize(inventory.get_catalog())
	if not service.rebuild_state(owner().character):
		item.rune_id = &""
		inventory.try_insert_instance(rune, int(taken.slot_index))
		return false
	changed.emit()
	return true


func can_correct() -> bool:
	return (
		not corrected and owner().is_editable() and int(owner().route.get_current_node().depth) <= 7
		and ExpeditionRouteCatalog.is_halt(str(owner().route.get_current_node().kind))
	)


func correct_build() -> bool:
	if not can_correct():
		return false
	for id in masteries:
		masteries[id] = 2 if id == primary_class else 0
	for card in copies:
		card.upgraded = false
	spent = 0
	upgraded_ids.clear()
	specialization = ""
	corrected = true
	sale_undo.clear()
	changed.emit()
	return true
