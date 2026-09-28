extends CatabaseCards
## Only unspent UIDs are owned. Prepared is a selection, not a fourth combat pile.
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Profile := preload("res://core/expedition/consumable_cards_profile.gd")
var ruleset_id := Profile.ID
var primary_class := "assassin"
var specialization := ""
var level := 1
var experience := 0
var attributes := { "power": 0, "vitality": 0, "resolve": 0 }
var upgraded_ids: Array[String] = []
var consumed: Dictionary = { }
var retired: Dictionary = { }
var used_families: Array[String] = []
var trigger_counters: Dictionary = { }
var pending_choice: Dictionary = { }
var followed_families: Array[String] = []
var encounter_id := ""
var run_seed := 0
var bestiary_revision := 0 # Missing in pre-bestiary saves; never change their roster.
var round_index := 0
var hand_capacity := 5
var moved_cells := 0
var anchor_cell := Vector2i.ZERO
var anchor_available := false
var anchor_used := false
var absorbed_since_turn := 0
var absorbed_last_round := 0
var equipped: Dictionary = { }
var equipment_copies: Array[Dictionary] = []
var item_serial := 0
var loot_commitments: Dictionary = { }
var active_relics: Array[String] = []
var owned_relics: Array[String] = []
var pending_items: Array[String] = []
var battle_results: Dictionary = { }
var gold := 40
var action_options: Dictionary = { }
var surface_groups: Array[Dictionary] = []
var surface_serial := 0
var _spells: Dictionary = { }


func _init() -> void:
	# Deliberately not revision 3: legacy class/mastery adapters must not run.
	rules_revision = 4


func initialize_deck(selection: Dictionary) -> void:
	if not copies.is_empty() or serial > 0 or not Catalog.valid_departure(selection):
		return
	primary_class = selection.class_id
	for family in selection.card_families:
		active.append(acquire(str(family), "initial", "initial"))


func acquire(family: String, origin: String, receipt: String) -> String:
	if (
		Catalog.card(family).is_empty()
		or origin not in ["initial", "loot", "purchase", "trade"] or receipt.is_empty()
	):
		return ""
	serial += 1
	var uid := "cc2_copy_%08d" % serial
	copies.append(
		{
			"id": uid,
			"family": family,
			"origin": origin,
			"receipt": receipt,
			"bound": false,
			"favorite": false,
		}
	)
	return uid


func add_copy(family: String, _bound := false) -> String:
	return acquire(family, "loot", "external:%d" % (serial + 1))


func known_family(family: String) -> bool:
	return not Catalog.card(family).is_empty()


func valid_deck(ids: Array) -> bool:
	if ids.size() > 30:
		return false
	var seen := { }
	var counts := { }
	for uid in ids:
		if not uid is String or seen.has(uid):
			return false
		var copy := copy_for(uid)
		if copy.is_empty() or consumed.has(uid) or retired.has(uid):
			return false
		seen[uid] = true
		counts[copy.family] = int(counts.get(copy.family, 0)) + 1
		if counts[copy.family] > 3:
			return false
	return true


func move_card(uid: String, replace_id := "") -> bool:
	if combat_started or copy_for(uid).is_empty():
		return false
	var next := active.duplicate()
	if uid in next:
		next.erase(uid)
	else:
		if not replace_id.is_empty():
			if replace_id not in next:
				return false
			next.erase(replace_id)
		next.append(uid)
	if not valid_deck(next):
		return false
	active.assign(next)
	_repair_opening()
	changed.emit()
	return true


func _repair_opening() -> void:
	if (
		opening.size() != 1 or opening[0] not in active
		or rarity(str(copy_for(opening[0]).get("family", ""))) != 0
	):
		opening.clear()


func set_opening(uid: String, slot: int = 0) -> bool:
	if combat_started or slot != 0:
		return false
	if uid.is_empty():
		opening.clear()
	elif uid not in active or rarity(str(copy_for(uid).get("family", ""))) != 0:
		return false
	else:
		opening.assign([uid])
	changed.emit()
	return true


func prepare_entry() -> void:
	finish_combat()
	var session = owner()
	if session != null:
		run_seed = session.route.seed
		encounter_id = session.route.current_node_id


func begin_combat() -> void:
	if combat_started:
		return
	combat_started = true
	_rng.seed = hash("cc2:hand:%d:%s" % [run_seed, encounter_id])
	draw_pile.assign(active)
	hand.clear()
	discard.clear()
	exhausted.clear()
	retained = ""
	selected = ""
	round_index = 0
	absorbed_since_turn = 0
	absorbed_last_round = 0
	trigger_counters.clear()
	surface_groups.clear()
	surface_serial = 0
	_repair_opening()
	for uid in opening:
		draw_pile.erase(uid)
		hand.append(uid)
	_shuffle(draw_pile)


func start_turn() -> void:
	if _activation_open:
		return
	begin_combat()
	_activation_open = true
	round_index += 1
	used_families.clear()
	moved_cells = 0
	anchor_available = false
	anchor_used = false
	absorbed_last_round = absorbed_since_turn
	absorbed_since_turn = 0
	var session = owner()
	if session != null:
		anchor_cell = session.character.unit.grid_pos
	draw_cards(maxi(0, hand_capacity - hand.size()))
	changed.emit()


func draw_cards(count: int) -> int:
	var drawn := 0
	for _index in maxi(0, count):
		if hand.size() >= clampi(hand_capacity, 1, 7):
			break
		var uid := _draw()
		if uid.is_empty():
			break
		hand.append(uid)
		drawn += 1
	return drawn


func end_turn() -> void:
	if not _activation_open:
		return
	super.end_turn()
	anchor_available = false


func finish_combat() -> void:
	combat_started = false
	_activation_open = false
	hand.clear()
	draw_pile.clear()
	discard.clear()
	used_families.clear()
	pending_choice.clear()
	retained = ""
	selected = ""


func can_use_family(family: String) -> bool:
	return _activation_open and family not in used_families and pending_choice.is_empty()


func consume(spell: Spell) -> bool:
	var family := String(spell.spell_id).trim_prefix("cc2_")
	if not can_use_family(family):
		return false
	if is_weapon_spell(spell):
		used_families.append(family)
		return true
	var uid := card_for_spell(spell)
	if uid.is_empty():
		return false
	var copy := copy_for(uid).duplicate(true)
	consumed[uid] = { "family": family, "encounter": encounter_id, "round": round_index }
	hand.erase(uid)
	active.erase(uid)
	copies.erase(copy)
	if retained == uid:
		retained = ""
	selected = ""
	used_families.append(family)
	_repair_opening()
	changed.emit()
	return true


func retain_copy(uid: String) -> bool:
	if pending_choice.get("kind") != "retain" or (not uid.is_empty() and uid not in hand):
		return false
	retained = uid
	pending_choice.clear()
	changed.emit()
	return true


func recompose(_uid: String) -> bool:
	return false


func _prune_exhausted() -> void:
	pass


func sync_learned() -> void:
	pass


func shop() -> Array:
	# Purchases are handled by the session's existing halt services.
	return []


func progression_offers() -> Array[String]:
	return []


func grant_loot(_node: Dictionary) -> void:
	# The session commits per-enemy loot before combat and collects it once.
	pass


func attribute_points() -> int:
	return floori(float(level) / 2) - int(attributes.power) - int(attributes.vitality) - int(attributes.resolve)


func spend_attribute(id: String) -> bool:
	if combat_started or not attributes.has(id) or attribute_points() <= 0: return false
	attributes[id] += 1
	changed.emit()
	return true


func rarity(family: String) -> int:
	return Catalog.RARITIES.find(Catalog.card(family).get("rarity", ""))


func family_spell(family: String) -> Spell:
	var key := family + ("+" if family in upgraded_ids else "")
	if not _spells.has(key):
		_spells[key] = load("res://core/expedition/consumable_card_spells.gd").make_spell(
			family,
			family in upgraded_ids,
		)
	return _spells[key]


func weapon_spells() -> Array[Spell]:
	return [family_spell("fallback_strike"), family_spell("fallback_guard")]


func is_weapon_spell(spell: Spell) -> bool:
	return spell != null and spell.spell_id in [&"cc2_fallback_strike", &"cc2_fallback_guard"]


func known_forms(family: String) -> Array[Spell]:
	var spell := family_spell(family)
	return [] if spell == null else [spell]


func eligible_pool() -> Array[String]:
	return Catalog.pool()


func points() -> int:
	return (1 if level >= 4 else 0) + (1 if level >= 8 else 0) + (1 if level >= 12 else 0) - upgraded_ids.size()


func upgrade_copy(id: String) -> bool:
	var family := str(copy_for(id).get("family", id))
	if combat_started or points() <= 0 or family in upgraded_ids or Catalog.card(family).is_empty():
		return false
	upgraded_ids.append(family)
	changed.emit()
	return true


func specialize(id: String) -> bool:
	if (
		combat_started or level < 4 or not specialization.is_empty()
		or id not in Catalog.class_row(primary_class).get("specs", [])
	):
		return false
	specialization = id
	changed.emit()
	return true


func take_trigger(key: String, once_per_combat := false) -> bool:
	var token := -1 if once_per_combat else round_index
	if trigger_counters.get(key, -2) == token:
		return false
	trigger_counters[key] = token
	return true


func snapshot() -> Dictionary:
	var result := {
		"schema_version": 1,
		"ruleset_id": ruleset_id,
		"content_version": Profile.CONTENT_VERSION,
	}
	for key in _persistent_keys():
		var value: Variant = get(key)
		result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	result["rng_seed"] = str(_rng.seed)
	result["rng_state"] = str(_rng.state)
	result["anchor_cell"] = [anchor_cell.x, anchor_cell.y]
	return result


func restore(data: Dictionary, _pending_start := false) -> bool:
	if (
		data.get("ruleset_id") != Profile.ID
		or data.get("content_version") != Profile.CONTENT_VERSION or data.get("schema_version") != 1
	):
		return false
	# Validate a detached candidate. A rejected restore never mutates this object.
	var candidate = get_script().new()
	for key in _persistent_keys():
		if key == "bestiary_revision" and not data.has(key):
			continue
		if not data.has(key):
			return false
		var current: Variant = candidate.get(key)
		var incoming: Variant = data[key]
		if current is int and (incoming is int or incoming is float):
			if not is_finite(float(incoming)) or float(incoming) != floorf(float(incoming)):
				return false
			candidate.set(key, int(incoming))
		elif current is Array and incoming is Array:
			if not incoming.all(
				func(v):
					return (
						v is Dictionary
						if key in ["copies", "equipment_copies", "surface_groups"]
						else v is String
					),
			):
				return false
			current.assign(incoming.duplicate(true))
		elif typeof(current) == typeof(incoming):
			candidate.set(key, incoming.duplicate(true) if incoming is Dictionary else incoming)
		else:
			return false
	for key in ["rng_seed", "rng_state"]:
		if not data.get(key) is String or not str(data[key]).is_valid_int():
			return false
	var anchor: Variant = data.get("anchor_cell")
	if (
		not anchor is Array or anchor.size() != 2
		or not anchor.all(
			func(n):
				return (
					(n is int or n is float) and is_finite(float(n))
					and float(n) == floorf(float(n))
				),
		)
	):
		return false
	candidate.anchor_cell = Vector2i(int(anchor[0]), int(anchor[1]))
	if not candidate.invariant_errors().is_empty():
		return false
	for key in _persistent_keys():
		var value: Variant = candidate.get(key)
		if value is Array:
			get(key).assign(value)
		else:
			set(key, value)
	anchor_cell = candidate.anchor_cell
	_rng.seed = int(data.rng_seed)
	_rng.state = int(data.rng_state)
	_spells.clear()
	return true


static func _persistent_keys() -> Array[String]:
	return [
		"bestiary_revision",
		"primary_class",
		"specialization",
		"level",
		"experience",
		"attributes",
		"upgraded_ids",
		"copies",
		"active",
		"opening",
		"serial",
		"consumed",
		"retired",
		"used_families",
		"trigger_counters",
		"pending_choice",
		"followed_families",
		"encounter_id",
		"run_seed",
		"round_index",
		"hand_capacity",
		"moved_cells",
		"anchor_available",
		"anchor_used",
		"absorbed_since_turn",
		"absorbed_last_round",
		"equipped",
		"equipment_copies",
		"active_relics",
		"owned_relics",
		"gold",
		"hand",
		"draw_pile",
		"discard",
		"retained",
		"selected",
		"combat_started",
		"_activation_open",
		"receipts",
		"stocks",
		"last_drops",
		"pending_items",
		"battle_results",
		"surface_groups",
		"surface_serial",
		"item_serial",
		"loot_commitments",
	]


func invariant_errors() -> Array[String]:
	var errors: Array[String] = []
	if (
		bestiary_revision not in [0, 1] or primary_class not in Catalog.CLASSES or level < 1 or level > 12 or gold < 0
		or experience < 0 or round_index < 0 or serial < 0 or hand_capacity < 1 or hand_capacity > 7
	):
		errors.append("Profil ou ressources invalides.")
	if (
		not specialization.is_empty()
		and (level < 4 or specialization not in Catalog.class_row(primary_class).get("specs", []))
	):
		errors.append("Spécialisation invalide.")
	var seen := { }
	for copy in copies:
		if (
			not copy.get("id") is String or not copy.get("family") is String
			or Catalog.card(copy.family).is_empty()
			or copy.get("origin") not in ["initial", "loot", "purchase", "trade"]
			or not copy.get("receipt") is String or str(copy.receipt).is_empty()
		):
			errors.append("Copie invalide.")
			continue
		var uid: String = copy.id
		if not _valid_uid(uid) or seen.has(uid) or consumed.has(uid) or retired.has(uid):
			errors.append("UID dupliqué ou rejouable : " + uid)
		seen[uid] = true
	for tombstones in [consumed, retired]:
		for uid in tombstones:
			if (
				not uid is String or not _valid_uid(uid) or seen.has(uid)
				or not tombstones[uid] is Dictionary or Catalog.card(str(
					tombstones[uid].get("family", "")
				)).is_empty()
			):
				errors.append("UID retiré invalide.")
			seen[uid] = true
	if not valid_deck(active):
		errors.append("Préparation invalide.")
	if (
		opening.size() > 1
		or (
			opening.size() == 1
			and (
				opening[0] not in active or rarity(str(copy_for(opening[0]).get("family", ""))) != 0
			)
		)
	):
		errors.append("Ouverture invalide.")
	var zones := { }
	for pile in [hand, draw_pile, discard]:
		for uid in pile:
			if uid not in active or zones.has(uid):
				errors.append("Zones non disjointes ou réserve accessible.")
			zones[uid] = true
	if combat_started and zones.size() != active.size():
		errors.append("Copie préparée absente des zones.")
	if not combat_started and (not zones.is_empty() or _activation_open):
		errors.append("Zones actives hors combat.")
	if (
		hand.size() > hand_capacity or (not retained.is_empty() and retained not in hand)
		or (not selected.is_empty() and selected not in hand)
	):
		errors.append("Main invalide.")
	var upgraded := { }
	for family in upgraded_ids:
		if Catalog.card(family).is_empty() or upgraded.has(family):
			errors.append("Amélioration invalide.")
		upgraded[family] = true
	if points() < 0:
		errors.append("Points d'amélioration dépassés.")
	var spent := 0
	for key in ["power", "vitality", "resolve"]:
		if not _whole(attributes.get(key), 0, 6):
			errors.append("Attribut invalide.")
		else:
			spent += int(attributes[key])
	if attributes.size() != 3 or spent > floori(float(level) / 2):
		errors.append("Points d'attribut dépassés.")
	var equipment_ids := { }
	for row in Catalog.data().equipment:
		equipment_ids[row.id] = row.slot
	var item_uids := { }
	for item in equipment_copies:
		var uid := str(item.get("id", ""))
		if (
			uid.is_empty() or item_uids.has(uid) or not equipment_ids.has(item.get("definition"))
			or not item.get("receipt") is String
		):
			errors.append("Objet invalide.")
		item_uids[uid] = true
	for slot in equipped:
		if (
			equipment_ids.get(equipped[slot]) != slot
			or not equipment_copies.any(
				func(item):
					return item.get("definition") == equipped[slot],
			)
		):
			errors.append("Équipement absent ou incompatible.")
	var relic_ids: Array = Catalog.data().relics.map(
		func(row):
			return row.id,
	)
	for id in owned_relics:
		if id not in relic_ids:
			errors.append("Relique inconnue.")
	var seen_relics := { }
	for id in active_relics:
		if id not in owned_relics or seen_relics.has(id):
			errors.append("Relique active invalide.")
		seen_relics[id] = true
	if active_relics.size() > 2 or followed_families.size() > 2:
		errors.append("Limite de suivi ou reliques dépassée.")
	var followed := { }
	for id in followed_families:
		if Catalog.card(id).is_empty() or followed.has(id):
			errors.append("Famille suivie invalide.")
		followed[id] = true
	for key in trigger_counters:
		if (
			not key is String
			or not _whole(trigger_counters[key], -1, 10000 if key == "lifesteal_healed" else 24)
		):
			errors.append("Compteur de déclenchement invalide.")
	if not pending_choice.is_empty():
		if not _activation_open or pending_choice.get("kind") not in ["relay", "retain"]:
			errors.append("Choix différé invalide.")
		elif pending_choice.kind == "relay":
			var cell: Variant = pending_choice.get("cell")
			var amount: Variant = pending_choice.get("amount")
			if (
				not cell is Array or cell.size() != 2
				or not cell.all(
					func(n):
						return _whole(n, 0, 255),
				)
				or not (amount is int or amount is float)
				or not is_finite(float(amount)) or amount < 0 or amount > 10000
			):
				errors.append("Relais invalide.")
	if surface_groups.size() > 2:
		errors.append("Trop de groupes de terrain.")
	for group in surface_groups:
		if not group.get("id") is String or not _whole(group.get("serial"), 1, surface_serial):
			errors.append("Groupe de terrain invalide.")
	return errors


static func _whole(value: Variant, low: int, high: int) -> bool:
	return (
		(value is int or value is float) and is_finite(float(value))
		and value == floorf(float(value)) and value >= low and value <= high
	)


func _valid_uid(uid: String) -> bool:
	var number := uid.trim_prefix("cc2_copy_")
	return (
		uid.begins_with("cc2_copy_") and number.is_valid_int() and int(number) > 0
		and int(number) <= serial and uid == "cc2_copy_%08d" % int(number)
	)
