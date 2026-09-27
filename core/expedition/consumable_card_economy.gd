extends RefCounted
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Cards := preload("res://core/expedition/consumable_cards_state.gd")


static func stage(encounter_index: int) -> int:
	return clampi((encounter_index - 1) / 3, 0, 3)


static func roll_family(rng: RandomNumberGenerator, rarity: String, class_id: String) -> String:
	var native: Array[String] = []
	var foreign: Array[String] = []
	for id in Catalog.pool("", rarity):
		if Catalog.card(id).affinity in ["shared", class_id]:
			native.append(id)
		else:
			foreign.append(id)
	var pool: Array[String] = native if rng.randf() < .7 else foreign
	if pool.is_empty():
		pool = foreign if native.is_empty() else native
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else ""


static func commit_loot(cards, encounter: Dictionary, eligible_uids: Array[String]) -> Dictionary:
	var key := str(encounter.index)
	if cards.loot_commitments.has(key):
		return cards.loot_commitments[key].duplicate(true)
	var result := { }
	var data := Catalog.data()
	var tier := stage(int(encounter.index))
	for uid in eligible_uids:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("cc2:loot:%d:%s:%s" % [cards.run_seed, key, uid])
		var drop := { "cards": [], "equipment": [], "relics": [], "bags": [] }
		if int(encounter.index) != 12:
			for channel in 7:
				if rng.randf() < float(data.rules.loot.rates[tier][channel]):
					drop.bags.append(channel)
					for _copy in int(data.rules.loot.sizes[channel]):
						drop.cards.append(
							roll_family(
								rng,
								str(data.rules.loot.tiers[channel]),
								cards.primary_class,
							)
						)
			if rng.randf() < float(data.rules.loot.gear[tier]):
				var items: Array = data.equipment.filter(
					func(item):
						return int(item.stage) <= tier + 1,
				)
				drop.equipment.append(items[rng.randi_range(0, items.size() - 1)].id)
			if rng.randf() < float(data.rules.loot.relic[tier]):
				drop.relics.append(data.relics[rng.randi_range(0, data.relics.size() - 1)].id)
		result[uid] = drop
	if encounter.get("relicGuaranteed", false) and not eligible_uids.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("cc2:relic:%d:%s" % [cards.run_seed, key])
		result[eligible_uids[0]].relics.append(
			data.relics[rng.randi_range(0, data.relics.size() - 1)].id
		)
	cards.loot_commitments[key] = result
	return result.duplicate(true)


static func collect_victory(cards, encounter: Dictionary, killed_uids: Array[String]) -> Dictionary:
	var receipt := "reward:" + str(encounter.index)
	if cards.receipts.has(receipt):
		return { "success": true, "replayed": true, "reward": cards.receipts[receipt].duplicate(
				true
			) }
	var key := str(encounter.index)
	if not cards.loot_commitments.has(key):
		return { "success": false, "reason": "loot_not_committed" }
	var seen := { }
	for uid in killed_uids:
		if seen.has(uid) or not cards.loot_commitments[key].has(uid):
			return { "success": false, "reason": "invalid_eligible_roster" }
		seen[uid] = true
	var reward := {
		"copies": [],
		"forfeited": [],
		"equipment": [],
		"relics": [],
		"gold": 0,
		"xp": 0,
		"previous_level": cards.level,
	}
	if int(encounter.index) != 12:
		for uid in killed_uids:
			var drop: Dictionary = cards.loot_commitments[key][uid]
			if drop.get("forfeited", false):
				reward.forfeited.append(uid)
				continue
			for family in drop.cards:
				reward.copies.append(cards.acquire(family, "loot", receipt + ":" + uid))
			for id in drop.equipment:
				reward.equipment.append(acquire_equipment(cards, id, receipt))
			for id in drop.relics:
				cards.owned_relics.append(id)
				reward.relics.append(id)
		reward.gold = 65 if encounter.kind == "elite" else 35
		reward.xp = int(Catalog.data().rules.xp[int(encounter.index) - 1])
		cards.gold += reward.gold
		cards.experience += reward.xp
		var thresholds: Array = Catalog.data().rules.xpThresholds
		for index in thresholds.size():
			if cards.experience >= int(thresholds[index]):
				cards.level = index + 1
	cards.last_drops.assign(reward.copies)
	cards.receipts[receipt] = reward.duplicate(true)
	return { "success": true, "replayed": false, "reward": reward }


static func acquire_equipment(cards, definition_id: String, receipt: String) -> String:
	cards.item_serial += 1
	var uid := "cc2_item_%08d" % cards.item_serial
	cards.equipment_copies.append({ "id": uid, "definition": definition_id, "receipt": receipt })
	return uid


static func market(cards, visit: String, encounter_index: int) -> Dictionary:
	if cards.stocks.has(visit):
		return cards.stocks[visit].duplicate(true)
	var tier := stage(encounter_index) + 1
	var singles := { }
	for family in Catalog.pool(cards.primary_class, "normal", true):
		singles[family] = 1
	var bags: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cc2:market:%d:%s" % [cards.run_seed, visit])
	for _bag in 2:
		var contents: Array[String] = []
		for _copy in 6:
			contents.append(roll_family(rng, "normal", cards.primary_class))
		bags.append(contents)
	var result := {
		"visit": visit,
		"stage": tier,
		"bags": bags,
		"singles": singles,
		"trades": 2,
		"heal": 1,
		"respec": 1,
		"equipment": [],
		"relics": [],
	}
	for item in Catalog.data().equipment:
		if int(item.stage) <= tier:
			result.equipment.append(item.id)
	if tier >= 3:
		for relic in Catalog.data().relics:
			result.relics.append(relic.id)
	cards.stocks[visit] = result
	return result.duplicate(true)


static func transact(cards, visit: String, request: Dictionary) -> Dictionary:
	if (
		cards.combat_started or not cards.stocks.has(visit)
		or not request.get("id") is String or str(request.id).is_empty()
	):
		return { "success": false, "reason": "merchant_unavailable" }
	var receipt := "market:%s:%s" % [visit, request.id]
	if cards.receipts.has(receipt):
		return { "success": true, "replayed": true, "receipt": cards.receipts[receipt].duplicate(
				true
			) }
	var candidate := Cards.new()
	if not candidate.restore(cards.snapshot()):
		return { "success": false, "reason": "invalid_state" }
	var result := _apply(candidate, visit, request, receipt)
	if not result.get("success", false):
		return result
	candidate.receipts[receipt] = result.duplicate(true)
	if not cards.restore(candidate.snapshot()):
		return { "success": false, "reason": "invalid_result" }
	cards.changed.emit()
	return { "success": true, "replayed": false, "receipt": result }


static func _apply(cards, visit: String, request: Dictionary, receipt: String) -> Dictionary:
	var stock: Dictionary = cards.stocks[visit]
	var price := 0
	var acquired: Array[String] = []
	var removed: Array[String] = []
	var heal := 0.0
	var kind := str(request.get("kind", ""))
	var family := str(request.get("family", ""))
	match kind:
		"single":
			if int(stock.singles.get(family, 0)) < 1:
				return _failure("sold_out")
			price = 8
			stock.singles[family] -= 1
			acquired.append(cards.acquire(family, "purchase", receipt))
		"bag":
			if stock.bags.is_empty():
				return _failure("sold_out")
			price = 36
			for id in stock.bags.pop_front():
				acquired.append(cards.acquire(id, "purchase", receipt))
		"sell", "trade":
			var uids: Variant = request.get("copies")
			if not uids is Array or uids.is_empty() or (kind == "trade" and uids.size() != 3):
				return _failure("copy_selection")
			var seen := { }
			for uid in uids:
				if not uid is String or seen.has(uid) or cards.copy_for(uid).is_empty():
					return _failure("copy_selection")
				seen[uid] = true
				var copy: Dictionary = cards.copy_for(uid)
				if kind == "trade" and Catalog.card(copy.family).rarity != "normal":
					return _failure("normal_copies_required")
			if kind == "trade":
				if (
					int(stock.trades) < 1
					or family not in Catalog.pool(cards.primary_class, "normal", true)
				):
					return _failure("trade_unavailable")
				stock.trades -= 1
				acquired.append(cards.acquire(family, "trade", receipt))
			for uid in uids:
				var copy: Dictionary = cards.copy_for(uid)
				if kind == "sell":
					price -= int(
						Catalog.data().rules.economy.sell[Catalog.card(copy.family).rarity]
					)
				cards.retired[uid] = { "family": copy.family, "reason": kind, "receipt": receipt }
				cards.copies.erase(copy)
				cards.active.erase(uid)
				removed.append(uid)
			cards._repair_opening()
		"equipment", "relic":
			var id := str(request.get("item", ""))
			var key := "equipment" if kind == "equipment" else "relics"
			if id not in stock[key]:
				return _failure("sold_out")
			for item in Catalog.data()[key]:
				if item.id == id:
					price = int(item.price)
			if price <= 0:
				return _failure("unknown_item")
			stock[key].erase(id)
			if kind == "equipment":
				acquire_equipment(cards, id, receipt)
			else:
				cards.owned_relics.append(id)
		"heal":
			if int(stock.heal) < 1:
				return _failure("sold_out")
			price = 25
			stock.heal -= 1
			heal = .3
		"respec":
			var from := str(request.get("from", ""))
			if (
				int(stock.respec) < 1 or from not in cards.upgraded_ids
				or family in cards.upgraded_ids or Catalog.card(family).is_empty()
			):
				return _failure("respec_unavailable")
			price = 35
			stock.respec -= 1
			cards.upgraded_ids.erase(from)
			cards.upgraded_ids.append(family)
		_:
			return _failure("unknown_transaction")
	if cards.gold < price:
		return _failure("insufficient_gold")
	cards.gold -= price
	return {
		"success": true,
		"kind": kind,
		"paid": price,
		"acquired": acquired,
		"removed": removed,
		"heal_fraction": heal,
	}


static func _failure(reason: String) -> Dictionary:
	return { "success": false, "reason": reason }
