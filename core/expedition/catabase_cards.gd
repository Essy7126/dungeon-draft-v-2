class_name CatabaseCards
extends RefCounted
## Owned copies are persistent; hands are reconstructed from the combat boundary.
signal changed

const GESTURE := "weapon_gesture"
const MIN_DECK := 8
const HAND_SIZE := 4
const STARTERS := {
	"marteau": ["exp_crochet", "exp_feinte", "exp_heurt", "exp_posture", "exp_marche"],
	"xiphos": ["exp_ct_repercussion", "exp_souffle", "exp_heurt", "exp_posture", "exp_marche"],
	"disque": ["exp_feinte", "exp_marque", "exp_crochet", "exp_posture", "exp_marche"],
	"hampe": ["exp_crochet", "exp_ct_sceau", "exp_heurt", "exp_posture", "exp_marche"],
	"lame": ["exp_posture", "exp_marche", "exp_crochet", "exp_feinte", "exp_souffle"],
	"arc": ["exp_marque", "exp_feinte", "exp_heurt", "exp_posture", "exp_marche"],
}
var rules_revision := 2
var progression_drafts: Dictionary = {}
const NAMES := ["Usuelle", "Gravée", "Héroïque", "Mythique", "Légendaire"]
const BUY := [50, 75, 110, 160, 230]
const SELL := [8, 12, 20, 32, 50]
const PROVISIONS_GOLD := 20
const COLORS := [Color("c5c5b7"), Color("70b5a6"), Color("7ea7e1"), Color("c396df"), Color("e6ba62")]
const RARITIES := {
	"weapon_gesture": 0, "exp_crochet": 0, "exp_fauchage": 0, "exp_heurt": 0, "exp_rupture": 0,
	"exp_marque": 1, "exp_feinte": 1, "exp_posture": 1, "exp_givre": 1, "exp_ct_sceau": 1,
	"exp_entaille": 2, "exp_moisson": 2, "exp_contretemps": 2, "exp_souffle": 2, "exp_marche": 2,
	"exp_braise": 2, "exp_foudre": 2, "exp_serment_rempart": 3, "exp_serment_brasier": 3,
	"exp_ct_repercussion": 4, "achilles_peleid_strike": 0, "achilles_pelion_shot": 0,
	"achilles_bronze_guard": 0, "achilles_fulminant_dash": 1,
}
var copies: Array[Dictionary] = []
var active: Array[String] = []
var opening: Array[String] = []
var receipts: Dictionary = {}
var stocks: Dictionary = {}
var entry_pool: Array[String] = []
var last_drops: Array[String] = []
var sale_undo: Dictionary = {}
var learned_receipts: Array[String] = []
var serial := 0
var hand: Array[String] = []
var draw_pile: Array[String] = []
var discard: Array[String] = []
var exhausted: Array[String] = []
var retained := ""
var selected := ""
var combat_started := false
var recomposed := false
var _activation_open := false
var forms: Dictionary = {}
var preferred_forms: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _owner: WeakRef


func bind(session) -> void:
	_owner = weakref(session)
	if not EventBus.turn_ended.is_connected(_on_turn_ended):
		EventBus.turn_ended.connect(_on_turn_ended)


func _on_turn_ended(actor: Unit, _reason: StringName) -> void:
	var session = owner()
	if session != null and actor == session.character.unit:
		_activation_open = false


func owner():
	return _owner.get_ref() if _owner != null else null


static func for_actor(actor):
	if actor == null: return null
	var session = CatabaseCombatModifier.session_for(actor)
	return session.cards if session != null and session.cards != null else null


func initialize_deck(selection: Dictionary) -> void:
	if not copies.is_empty(): return
	for family in starter_families(selection):
		for index in 2: active.append(add_copy(str(family), true))
	changed.emit()


static func starter_families(selection: Dictionary) -> Array:
	var source: Variant = selection.get("card_families", STARTERS.get(selection.get("weapon", "marteau"), STARTERS.marteau))
	if not source is Array: return []
	var result: Array = source.duplicate()
	if not selection.has("card_families") and selection.get("relic") != "urne" and "exp_ct_repercussion" in result:
		result[result.find("exp_ct_repercussion")] = "exp_ct_sceau"
	return result


func migrate_legacy(pending_start: bool) -> void:
	if rules_revision >= 2: return
	rules_revision = 2
	opening.clear()
	entry_pool.erase(GESTURE)
	for node_id in stocks:
		for offer in stocks[node_id]:
			if offer.family == GESTURE and not offer.sold: offer.family = "exp_heurt"
	# Keep purchased and bound copies, including old Gestures, as an archive.
	# Only the playable deck changes. No reroll, sale, gold or reward receipt.
	if pending_start: return
	var session = owner()
	var families := starter_families(session.build.starting_selection)
	session.build.starting_selection["card_families"] = families
	for family in families:
		session.character.loadout.learn_spell(session.build.catalog.get_spell(str(family)))
	var kept: Array[String] = []
	var counts := {}
	for id in active:
		var family := str(copy_for(id).family)
		if family == GESTURE or int(counts.get(family, 0)) >= 2: continue
		kept.append(id)
		counts[family] = int(counts.get(family, 0)) + 1
	for family in families:
		while kept.size() < 10 and int(counts.get(family, 0)) < 2:
			var reserves := copies.filter(func(card): return card.family == family and card.id not in kept)
			kept.append(str(reserves[0].id) if not reserves.is_empty() else add_copy(str(family), true))
			counts[family] = int(counts.get(family, 0)) + 1
	active.assign(kept)
	changed.emit()


func permanent_offer(offer: Dictionary) -> bool:
	var id := str(offer.get("spell_id", ""))
	return id.is_empty() or owner().build.catalog.get_spell_family(id) in weapon_families()


func upgrade_offers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for offer in owner().build.get_offers():
		if not offer.available or offer.owned or str(offer.kind) == "apprentissage": continue
		var family: String = owner().build.catalog.get_spell_family(str(offer.spell_id))
		if copies.any(func(card): return card.family == family): result.append(offer)
	return result


func progression_offers() -> Array[String]:
	var node_id: String = owner().route.current_node_id
	if progression_drafts.has(node_id):
		var saved: Array[String] = []
		saved.assign(progression_drafts[node_id])
		return saved
	var pool := eligible_pool()
	pool = pool.filter(func(family): return active.filter(func(id): return copy_for(id).family == family).size() < 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cards:progression:%d:%s" % [owner().route.seed, owner().route.current_node_id])
	var result: Array[String] = []
	while result.size() < 3 and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		result.append(pool[index])
		pool.remove_at(index)
	if node_id in owner().awarded_node_ids:
		progression_drafts[node_id] = result.duplicate()
	return result


func resolve_progression(action: String, value := "", replace_id := "") -> bool:
	var session = owner()
	if not session.is_editable() or session.advancement_step != "advancement": return false
	if action == "upgrade":
		if not upgrade_offers().any(func(offer): return offer.id == value): return false
		if not session.build.purchase(value).success: return false
	elif action == "add":
		if value not in progression_offers(): return false
		if not replace_id.is_empty() and replace_id not in active: return false
		var candidate := active.duplicate()
		candidate.erase(replace_id)
		var count := 0
		for id in candidate:
			if copy_for(id).family == value: count += 1
		if count >= 2: return false
		_teach(value)
		candidate.append(add_copy(value, true))
		active.assign(candidate)
	elif action != "skip": return false
	session.advancement_step = ""
	session.journal.append("Deck : " + action + (" · " + value if not value.is_empty() else ""))
	changed.emit()
	return true


func weapon_spells() -> Array[Spell]:
	var result: Array[Spell] = []
	for family in weapon_families():
		var spell := family_spell(family)
		if spell != null: result.append(spell)
	return result


func is_weapon_spell(spell: Spell) -> bool:
	if rules_revision < 2: return false
	return weapon_spells().any(func(available): return available.get_effective_spell_id() == spell.get_effective_spell_id())


func add_copy(family: String, bound := false) -> String:
	if family not in learned_receipts: learned_receipts.append(family)
	serial += 1
	var id := "card_%06d" % serial
	copies.append({"id": id, "family": family, "bound": bound, "favorite": false})
	return id


func copy_for(id: String) -> Dictionary:
	for card in copies:
		if card.id == id: return card
	return {}


func rarity(family: String) -> int:
	return int(RARITIES.get(family, 3))


func family_spell(family: String) -> Spell:
	var session = owner()
	if session == null: return null
	if forms.has(family) and session.route.phase == "combat":
		return session.build.catalog.get_spell(str(forms[family]))
	if preferred_forms.has(family):
		return session.build.catalog.get_spell(str(preferred_forms[family]))
	for equipped in session.character.loadout.get_equipped_spells():
		if session.build.catalog.get_spell_family(str(equipped.spell_id)) == family: return equipped
	var result: Spell = session.build.catalog.get_spell(family)
	for spell in session.character.loadout.get_known_spells():
		if session.build.catalog.get_spell_family(str(spell.spell_id)) == family:
			result = spell
	return result


func known_forms(family: String) -> Array[Spell]:
	var result: Array[Spell] = []
	for spell in owner().character.loadout.get_known_spells():
		if owner().build.catalog.get_spell_family(str(spell.spell_id)) == family: result.append(spell)
	return result


func choose_form(family: String, spell_id: String) -> bool:
	if owner().route.phase == "combat": return false
	for spell in known_forms(family):
		if str(spell.spell_id) == spell_id:
			preferred_forms[family] = spell_id
			changed.emit()
			return true
	return false


func weapon_families() -> Array[String]:
	var session = owner()
	var result: Array[String] = []
	if session == null: return result
	for item in session.character.equipment_loadout.get_equipped_items():
		var weapon := CatabasePreparationCatalog.weapon_for_item(str(item.definition_id))
		if not weapon.is_empty():
			result.assign([CatabasePreparationCatalog.WEAPONS[weapon][2], CatabasePreparationCatalog.WEAPONS[weapon][3]])
			return result
	return result


func spells_for(id: String) -> Array[Spell]:
	var card := copy_for(id)
	var result: Array[Spell] = []
	if card.is_empty(): return result
	var families: Array[String] = []
	if card.family == GESTURE: families = weapon_families()
	else: families.append(str(card.family))
	for family in families:
		var spell := family_spell(family)
		if spell != null: result.append(spell)
	return result


func title_for(id: String) -> String:
	var card := copy_for(id)
	if card.is_empty(): return "Carte vendue"
	if card.family == GESTURE: return "Geste d’arme"
	var spell := family_spell(str(card.family))
	return spell.spell_name if spell != null else str(card.family)


func valid_deck(ids: Array) -> bool:
	if ids.size() < (MIN_DECK if rules_revision >= 2 else 12) or (rules_revision < 2 and ids.size() > 18): return false
	var seen := {}
	var counts := {}
	for id in ids:
		var card := copy_for(str(id))
		if card.is_empty() or seen.has(id): return false
		if rules_revision >= 2 and card.family == GESTURE: return false
		seen[id] = true
		counts[card.family] = int(counts.get(card.family, 0)) + 1
		if counts[card.family] > (2 if rules_revision >= 2 else (6 if card.family == GESTURE else 3)): return false
	return rules_revision >= 2 or (int(counts.get(GESTURE, 0)) >= 2 and ids.size() - int(counts.get(GESTURE, 0)) >= 2)


func move_card(id: String, replace_id := "") -> bool:
	if owner().route.phase == "combat" or copy_for(id).is_empty(): return false
	var candidate := active.duplicate()
	if id in candidate: candidate.erase(id)
	else:
		if not replace_id.is_empty():
			if replace_id not in candidate: return false
			candidate.erase(replace_id)
		candidate.append(id)
	if not valid_deck(candidate): return false
	active.assign(candidate)
	_repair_opening()
	changed.emit()
	return true


func _repair_opening() -> void:
	if rules_revision >= 2:
		opening.clear()
		return
	var weapons: Array[String] = []
	var techniques: Array[String] = []
	for id in opening + active:
		if id not in active: continue
		var bucket: Array[String] = weapons if copy_for(id).family == GESTURE else techniques
		if id not in bucket and bucket.size() < 2: bucket.append(id)
	opening.assign(weapons + techniques)


func set_opening(id: String, slot: int) -> bool:
	if rules_revision >= 2: return false
	if owner().route.phase == "combat" or id not in active or slot < 0 or slot > 3: return false
	if (copy_for(id).family == GESTURE) != (slot < 2): return false
	var other := opening.find(id)
	if other >= 0: opening[other] = opening[slot]
	opening[slot] = id
	return true


func sync_learned() -> void:
	if rules_revision >= 2: return
	if copies.is_empty(): return
	var session = owner()
	var known := {}
	for card in copies: known[card.family] = true
	var weapon_roots := []
	for row in CatabasePreparationCatalog.WEAPONS.values(): weapon_roots.append_array([row[2], row[3]])
	for spell in session.character.loadout.get_known_spells():
		var family: String = session.build.catalog.get_spell_family(str(spell.spell_id))
		if family in weapon_roots or known.has(family) or family in learned_receipts: continue
		add_copy(family, true)
		known[family] = true


func eligible_pool() -> Array[String]:
	var result: Array[String] = []
	if rules_revision < 2: result.append(GESTURE)
	var session = owner()
	var has_urn: bool = false
	if session.card_inventory != null:
		has_urn = session.card_inventory.get_slots().any(func(item): return item != null and str(item.definition_id) == "ct_relic_urne")
	for family in session.build.catalog.card_spell_ids():
		if not RARITIES.has(family) or family == "exp_ct_repercussion" and not has_urn: continue
		var axis: String = session.build.catalog.get_spell_axis(family)
		if not session.build.is_axis_discovered(axis): continue
		if axis == "serment" and not session.character.loadout.knows_spell_id(StringName(family)): continue
		result.append(family)
	for family in ["exp_serment_rempart", "exp_serment_brasier"]:
		if session.character.loadout.knows_spell_id(StringName(family)): result.append(family)
	return result


func known_family(family: String) -> bool:
	if family == GESTURE: return true
	for spell in owner().character.loadout.get_known_spells():
		if owner().build.catalog.get_spell_family(str(spell.spell_id)) == family: return true
	return false


## A refunded mastery cannot leave a playable or sellable ghost card.
## Validate first so the caller can roll the mastery back without changing copies.
func reconcile_learned() -> bool:
	var forgotten: Array[String] = []
	for card in copies:
		if known_family(str(card.family)): continue
		if str(card.id) in active or not card.bound: return false
		if str(card.family) not in forgotten: forgotten.append(str(card.family))
	for family in forgotten:
		copies = copies.filter(func(card): return card.family != family)
		learned_receipts.erase(family)
	for family in preferred_forms.keys():
		if not owner().character.loadout.knows_spell_id(StringName(preferred_forms[family])):
			preferred_forms.erase(family)
	forms.clear()
	changed.emit()
	return true


static func weights(depth: int) -> Array:
	return [64.0, 27.0, 8.0, 0.9, 0.1] if depth <= 5 else [49.0, 32.0, 16.0, 2.5, 0.5] if depth <= 12 else [38.0, 34.0, 22.0, 5.0, 1.0]


func _roll(pool: Array[String], distribution: Array, rng: RandomNumberGenerator, axis := "", excluded: Array[String] = []) -> String:
	var groups := [[], [], [], [], []]
	for family in pool: groups[rarity(family)].append(family)
	var total := 0.0
	for index in 5:
		if not groups[index].is_empty(): total += float(distribution[index])
	if total <= 0.0: return ""
	var value := rng.randf() * total
	var chosen := 0
	for index in 5:
		if groups[index].is_empty() or float(distribution[index]) <= 0.0: continue
		value -= float(distribution[index])
		chosen = index
		if value <= 0.0: break
	var candidates: Array = groups[chosen]
	var unique: Array = candidates.filter(func(family): return family not in excluded)
	if not unique.is_empty(): candidates = unique
	if not axis.is_empty() and rng.randf() < 0.6:
		var themed: Array = candidates.filter(func(family): return owner().build.catalog.get_spell_axis(family) == axis)
		if not themed.is_empty(): candidates = themed
	return str(candidates[rng.randi_range(0, candidates.size() - 1)])


func prepare_entry() -> void:
	_activation_open = false
	sale_undo.clear()
	last_drops.clear()
	sync_learned()
	entry_pool = eligible_pool()
	combat_started = false
	forms.clear()


func grant_loot(node: Dictionary) -> void:
	var id := str(node.id)
	if receipts.has(id) or int(node.depth) == 20 or str(node.kind) not in ["normal", "elite"]: return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cards:loot:%d:%s" % [owner().route.seed, id])
	var pool := entry_pool if not entry_pool.is_empty() else eligible_pool()
	var axis := str({"armor": "airain", "mobility": "danseur", "control": "briseur", "elemental": "elements"}.get(str(node.reward), ""))
	var families: Array[String] = []
	families.append(_roll(pool, weights(int(node.depth)), rng, axis))
	if str(node.kind) == "elite":
		var elite := [0, 0, 95, 4.5, 0.5] if int(node.depth) == 6 else [0, 0, 90, 9, 1] if int(node.depth) == 10 else [0, 0, 85, 12, 3]
		families.append(_roll(pool, elite, rng, axis, families))
	if rng.randf() < 0.25: families.append(_roll(pool, weights(int(node.depth)), rng, axis, families))
	last_drops.clear()
	for family in families:
		if family.is_empty(): push_error("Card loot has no eligible family"); continue
		last_drops.append(add_copy(family))
		_teach(family)
	receipts[id] = last_drops.duplicate()
	changed.emit()


func _teach(family: String) -> void:
	if family == GESTURE: return
	var session = owner()
	if not session.character.loadout.knows_spell_id(StringName(family)):
		session.build.learn_spell_card(family)


func shop() -> Array:
	var session = owner()
	var node: Dictionary = session.route.get_current_node()
	if session.route.phase != "reward" or int(node.get("depth", 0)) == 19: return []
	if str(node.get("kind", "")) != "merchant" and int(node.get("depth", 0)) not in [7, 11, 16]: return []
	var id := str(node.id)
	if not stocks.has(id):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("cards:shop:%d:%s" % [session.route.seed, id])
		var stock: Array = []
		var families: Array[String] = []
		for distribution in [[100, 0, 0, 0, 0], [0, 100, 0, 0, 0], [0, 0, 90, 9, 1]]:
			var family := _roll(eligible_pool(), distribution, rng, "", families)
			if family.is_empty(): continue
			families.append(family)
			stock.append({"family": family, "sold": false})
		stocks[id] = stock
	return stocks[id]


func buy(index: int) -> bool:
	var offers := shop()
	if index < 0 or index >= offers.size() or offers[index].sold: return false
	var family := str(offers[index].family)
	var price: int = BUY[rarity(family)]
	if owner().gold < price: return false
	owner().gold -= price
	offers[index].sold = true
	add_copy(family)
	_teach(family)
	changed.emit()
	return true


func sell(id: String) -> bool:
	var card := copy_for(id)
	if owner().route.phase == "combat" or card.is_empty() or id in active or card.bound or card.favorite: return false
	sale_undo[id] = card.duplicate(true)
	owner().gold += int(SELL[rarity(str(card.family))])
	copies.erase(card)
	changed.emit()
	return true


func undo_sale(id: String) -> bool:
	if owner().route.phase == "combat" or not sale_undo.has(id): return false
	var card: Dictionary = sale_undo[id]
	var price: int = SELL[rarity(str(card.family))]
	if owner().gold < price: return false
	owner().gold -= price
	copies.append(card)
	sale_undo.erase(id)
	changed.emit()
	return true


func begin_combat() -> void:
	if combat_started: return
	combat_started = true
	forms.clear()
	for spell in owner().character.loadout.get_known_spells():
		var family: String = owner().build.catalog.get_spell_family(str(spell.spell_id))
		var resolved := family_spell(family)
		if resolved != null and not forms.has(family): forms[family] = str(resolved.spell_id)
	_rng.seed = hash("cards:hand:%d:%s" % [owner().route.seed, owner().route.current_node_id])
	draw_pile.assign(active)
	discard.clear()
	exhausted.clear()
	hand.clear()
	retained = ""
	selected = ""
	_repair_opening()
	for id in opening:
		draw_pile.erase(id)
		hand.append(id)
	_shuffle(draw_pile)


func _shuffle(values: Array[String]) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var value := values[index]
		values[index] = values[other]
		values[other] = value


func _draw() -> String:
	if draw_pile.is_empty():
		draw_pile.assign(discard)
		discard.clear()
		_shuffle(draw_pile)
	return "" if draw_pile.is_empty() else draw_pile.pop_back()


func start_turn() -> void:
	begin_combat()
	_activation_open = true
	recomposed = false
	_prune_exhausted()
	var capacity: int = HAND_SIZE if rules_revision >= 2 else owner().character.loadout.get_active_slot_count()
	while hand.size() < capacity:
		var id := _draw()
		if id.is_empty(): break
		hand.append(id)
	changed.emit()


func end_turn() -> void:
	_activation_open = false
	for id in hand:
		if id != retained: discard.append(id)
	hand.assign([retained] if retained in hand else [])
	retained = ""
	selected = ""
	changed.emit()


func _prune_exhausted() -> void:
	var actor: Unit = owner().character.unit
	for pile in [hand, draw_pile, discard]:
		for id in pile.duplicate():
			var spells := spells_for(str(id))
			if spells.is_empty(): continue
			var spent := true
			for spell in spells:
				if spell.max_uses_per_combat <= 0 or actor.get_spell_uses(spell) < spell.max_uses_per_combat: spent = false
			if spent:
				pile.erase(id)
				exhausted.append(id)


func card_for_spell(spell: Spell) -> String:
	var candidates := hand.duplicate()
	if selected in candidates:
		candidates.erase(selected)
		candidates.push_front(selected)
	for id in candidates:
		for available in spells_for(id):
			if available.get_effective_spell_id() == spell.get_effective_spell_id(): return id
	return ""


func consume(spell: Spell) -> bool:
	if is_weapon_spell(spell): return true
	var id := card_for_spell(spell)
	if id.is_empty(): return false
	hand.erase(id)
	discard.append(id)
	if retained == id: retained = ""
	selected = ""
	_prune_exhausted()
	changed.emit()
	return true


func recompose(id: String) -> bool:
	var actor: Unit = owner().character.unit
	if not _activation_open or actor.activation_consumed or owner().route.phase != "combat" or id not in hand or recomposed or actor.current_ap < 1 or not actor.is_alive: return false
	_prune_exhausted()
	if id not in hand: return false
	if draw_pile.is_empty() and discard.is_empty(): return false
	var replacement := _draw()
	if replacement.is_empty(): return false
	hand.erase(id)
	discard.append(id)
	hand.append(replacement)
	if retained == id: retained = ""
	actor.current_ap -= 1
	actor.stats_changed.emit(actor)
	recomposed = true
	changed.emit()
	return true


func snapshot() -> Dictionary:
	return {"version": 1, "rules_revision": rules_revision, "progression_drafts": progression_drafts.duplicate(true), "copies": copies.duplicate(true), "active": active.duplicate(), "opening": opening.duplicate(), "serial": serial, "preferred_forms": preferred_forms.duplicate(),
		"receipts": receipts.duplicate(true), "stocks": stocks.duplicate(true), "entry_pool": entry_pool.duplicate(), "last_drops": last_drops.duplicate(), "sale_undo": {}, "learned_receipts": learned_receipts.duplicate()}


func restore(data: Dictionary, pending_start: bool) -> bool:
	if int(data.get("version", 0)) != 1: return false
	rules_revision = int(data.get("rules_revision", 1))
	if rules_revision not in [1, 2]: return false
	var drafts: Variant = data.get("progression_drafts", {})
	if not drafts is Dictionary: return false
	for node_id in drafts:
		if node_id not in owner().awarded_node_ids or not drafts[node_id] is Array or drafts[node_id].size() > 3: return false
		var unique := {}
		for family in drafts[node_id]:
			if not family is String or family == GESTURE or not RARITIES.has(family) or unique.has(family): return false
			unique[family] = true
	progression_drafts = drafts.duplicate(true)
	for key in ["copies", "active", "opening", "entry_pool", "last_drops", "learned_receipts"]:
		if not data.get(key) is Array: return false
	for key in ["receipts", "stocks", "sale_undo"]:
		if not data.get(key) is Dictionary: return false
	var preferences: Variant = data.get("preferred_forms", {})
	if not preferences is Dictionary: return false
	for family in preferences:
		if not family is String or not preferences[family] is String: return false
		var id: String = preferences[family]
		if not owner().character.loadout.knows_spell_id(StringName(id)) or owner().build.catalog.get_spell_family(id) != family: return false
	preferred_forms = preferences.duplicate()
	if data.copies.size() > 200 or int(data.get("serial", -1)) < data.copies.size(): return false
	var seen := {}
	for card in data.copies:
		if not card is Dictionary or not card.get("id") is String or not card.get("family") is String or not card.get("bound") is bool or not card.get("favorite") is bool: return false
		if seen.has(card.id) or not str(card.id).begins_with("card_") or not str(card.id).trim_prefix("card_").is_valid_int() or int(str(card.id).trim_prefix("card_")) > int(data.serial): return false
		if card.family != GESTURE and owner().build.catalog.get_spell(card.family) == null: return false
		if not known_family(str(card.family)): return false
		seen[card.id] = true
		copies.append(card.duplicate(true))
	for id in data.active:
		if not id is String: return false
	active.assign(data.active)
	if not pending_start and not valid_deck(active): return false
	if pending_start and (not copies.is_empty() or not active.is_empty()): return false
	for id in data.opening:
		if not id is String or id not in active or id in opening: return false
		opening.append(id)
	if rules_revision >= 2 and not opening.is_empty(): return false
	if rules_revision == 1 and not pending_start and (opening.size() != 4 or copy_for(opening[0]).family != GESTURE or copy_for(opening[1]).family != GESTURE or copy_for(opening[2]).family == GESTURE or copy_for(opening[3]).family == GESTURE): return false
	for family in data.entry_pool:
		if not family is String or not RARITIES.has(family): return false
	entry_pool.assign(data.entry_pool)
	for id in data.last_drops:
		if not id is String: return false
	last_drops.assign(data.last_drops)
	serial = int(data.serial)
	for family in data.learned_receipts:
		if not family is String or family in learned_receipts or (family != GESTURE and owner().build.catalog.get_spell(family) == null): return false
		learned_receipts.append(family)
	for card in copies:
		if card.family not in learned_receipts: return false
	for node_id in data.receipts:
		if node_id not in owner().awarded_node_ids or not data.receipts[node_id] is Array: return false
		for id in data.receipts[node_id]:
			if not id is String or not id.begins_with("card_"): return false
	for node_id in data.stocks:
		if node_id not in owner().awarded_node_ids or not data.stocks[node_id] is Array or data.stocks[node_id].size() > 3: return false
		for offer in data.stocks[node_id]:
			if not offer is Dictionary or not offer.get("family") is String or not RARITIES.has(offer.family) or not offer.get("sold") is bool: return false
	for id in data.sale_undo:
		var card: Variant = data.sale_undo[id]
		if seen.has(id) or not card is Dictionary or card.get("id") != id or card.get("bound", true) != false or not card.get("favorite") is bool or not card.get("family") is String or not RARITIES.has(card.family): return false
	receipts = data.receipts.duplicate(true)
	stocks = data.stocks.duplicate(true)
	sale_undo = data.sale_undo.duplicate(true)
	return true
