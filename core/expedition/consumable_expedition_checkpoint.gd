extends RefCounted
## Validate a combat continuation before replacing the live session.
const NativeStatuses := preload("res://core/expedition/consumable_native_status_checkpoint.gd")
static func valid(session: ExpeditionSession, value: Dictionary) -> bool:
	if value.is_empty(): return not session.cards.combat_started
	if session.route.phase != "combat" or not session.cards.combat_started or not session.cards._activation_open: return false
	if not whole(value.get("version"), 1, 2) or value.get("node") != session.route.current_node_id: return false
	if not whole(value.get("round"), 1, 24) or not whole(value.get("cast_sequence"), 0, 100000): return false
	if int(value.round) != session.cards.round_index or not value.get("units") is Array or not value.get("surfaces") is Array: return false
	var room := ExpeditionRunFactory.make_room(session.route.get_current_node(), session.route.seed)
	if room == null: return false
	var grid := EncounterGridFactory.build_from_room(room)
	if grid == null or value.units.size() != room.enemies.size() + 1: return false
	var occupied := {}
	var identities := {}
	for index in value.units.size():
		var entry: Variant = value.units[index]
		var expected := str(session.character.unit.unit_id) if index == 0 else "cc2_enemy_%02d" % (index - 1)
		if not entry is Dictionary or entry.get("id") != expected: return false
		identities[expected] = true
		if not entry.get("alive") is bool or not entry.get("consumed") is bool or not entry.get("abilities") is Dictionary or not entry.get("metadata") is Dictionary or not entry.get("shields") is Array: return false
		for key in ["hp", "ap", "mp", "activation"]:
			if not whole(entry.get(key), 0, {"hp": 100000, "ap": 10, "mp": 20, "activation": 24}[key]): return false
		if entry.alive != (entry.hp > 0): return false
		if not cell(entry.get("cell"), grid, not entry.alive): return false
		if entry.alive:
			var pos := Vector2i(entry.cell[0], entry.cell[1])
			if occupied.has(pos) or not grid.is_walkable(pos): return false
			occupied[pos] = true
		if entry.metadata.get("cc2_ruleset") != "catabase_cards_consumable_v2": return false
		if not json_safe(entry.metadata) or not json_safe(entry.abilities): return false
		for key in entry.abilities:
			var ability: Variant = entry.abilities[key]
			if not ability is Dictionary: return false
			for count in ["ready_activation", "uses_this_combat", "used_activation"]:
				if not whole(ability.get(count), -1, 100000): return false
		var probe := Unit.new()
		if not probe.restore_shield_instances_snapshot(entry.shields): return false
		probe.clear_shield()
	for entry in value.units:
		if not json_safe(entry.get("statuses")) or not NativeStatuses.valid(entry.get("statuses"), identities): return false
		if not valid_metadata(entry.metadata, grid, identities): return false
		if not entry.get("queued") is Dictionary: return false
		var queued_keys := ["next_turn_ap_modifier", "next_turn_mp_bonus", "next_turn_mp_penalty", "_moved_cells_this_activation", "_mp_spent_this_activation"]
		if entry.queued.size() != queued_keys.size(): return false
		for key in queued_keys:
			if not whole(entry.queued.get(key), -10 if key == "next_turn_ap_modifier" else 0, 100): return false
	if not value.units[0].alive or int(value.units[0].activation) != session.cards.round_index: return false
	var native: Variant = value.get("native_terrain")
	if not native is Dictionary or not whole(native.get("serial"), 0, 100000) or not native.get("void") is Dictionary or not native.get("electric") is Dictionary: return false
	for id in native.void:
		if not identities.has(id) or not whole(native.void[id], 0, 24): return false
	for id in native.electric:
		var entry: Variant = native.electric[id]
		if not identities.has(id) or not entry is Dictionary or not whole(entry.get("round"), 0, 24) or not entry.get("regions") is Dictionary: return false
		for region in entry.regions:
			if not region is String or entry.regions[region] != true: return false
	var surfaces := {}
	for entry in value.surfaces:
		if not entry is Dictionary or not cell(entry.get("cell"), grid) or not entry.get("flags") is Dictionary or not json_safe(entry.flags): return false
		if entry.get("surface") not in ["fire", "ice", "water", "steam"] or not whole(entry.get("duration"), 1, 3): return false
		if entry.get("source") not in identities: return false
		var pos := Vector2i(entry.cell[0], entry.cell[1])
		if surfaces.has(pos) or not grid.is_terrain_interactable(pos): return false
		surfaces[pos] = true
	if int(value.version) >= 2:
		var definition := preload("res://core/expedition/consumable_cards_integration.gd").encounter(session)
		if not preload("res://core/expedition/consumable_room_rules.gd").valid(value.get("room"), str(definition.map), grid, value.units, int(value.round)): return false
		for id in value.room.get("deliveries", []):
			if not session.cards.loot_commitments.get(str(definition.index), {}).get(id, {}).get("forfeited", false): return false
	return true


static func valid_metadata(data: Dictionary, grid: GridData, identities: Dictionary) -> bool:
	if data.has("cc2_phase") and not whole(data.cc2_phase, 1, 2): return false
	for key in ["cc2_sacrificed", "cc2_boss"]:
		if data.has(key) and not data[key] is bool: return false
	if data.has("cc2_kind") and data.cc2_kind not in preload("res://core/expedition/consumable_card_catalog.gd").data().enemyTypes: return false
	var intent: Variant = data.get("cc2_intent", {})
	if not intent is Dictionary: return false
	if not intent.is_empty():
		if not intent.get("cells") is Array or intent.cells.is_empty() or intent.cells.size() > 3: return false
		for position in intent.cells:
			if not cell(position, grid): return false
		if intent.get("multiplier") not in [1.4, 1.5]: return false
	var effects: Variant = data.get("cc2_effects", {})
	if not effects is Dictionary: return false
	for key in effects:
		if key not in ["mark", "slow", "burn", "bleed", "weak", "stasis", "stasis_ward", "parry", "counter", "edict"]: return false
		var effect: Variant = effects[key]
		if not effect is Dictionary or not whole(effect.get("duration"), 1, 3): return false
		if effect.get("source") != "" and not identities.has(effect.get("source")): return false
		if not NativeStatuses.number(effect.get("amount")) or effect.amount < 0 or effect.amount > 10000: return false
		if effect.has("expires_hero_end") and not whole(effect.expires_hero_end, 1, 25): return false
		if effect.has("origin") and effect.origin not in ["relay", "direct"]: return false
	return true


static func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floorf(value) and value >= low and value <= high


static func cell(value: Variant, grid: GridData, dead := false) -> bool:
	if not value is Array or value.size() != 2: return false
	# JSON numbers are floats; Array equality would reject [-1.0, -1.0].
	if dead and whole(value[0], -1, -1) and whole(value[1], -1, -1): return true
	return whole(value[0], 0, grid.cols - 1) and whole(value[1], 0, grid.rows - 1)


static func json_safe(value: Variant, depth := 0) -> bool:
	if depth > 10: return false
	if value is float: return is_finite(value)
	if value is Dictionary:
		for key in value:
			if not key is String or not json_safe(value[key], depth + 1): return false
	elif value is Array:
		for entry in value:
			if not json_safe(entry, depth + 1): return false
	return value == null or value is String or value is bool or value is int or value is float or value is Dictionary or value is Array
