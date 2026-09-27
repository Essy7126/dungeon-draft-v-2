extends RefCounted
## Detached combat state. The checkpoint owner publishes it only after persistence.
## Movement, aiming, spells, damage and surfaces use the project's common services.
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Effects := preload("res://core/expedition/consumable_card_effects.gd")
const Turns := preload("res://core/expedition/consumable_card_turns.gd")
const Terrain := preload("res://core/expedition/consumable_card_terrain.gd")
const Enemies := preload("res://core/expedition/consumable_enemy_rules.gd")
const Economy := preload("res://core/expedition/consumable_card_economy.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")
var cards
var encounter: Dictionary = {}
var grid: GridData
var pathfinder: Pathfinder
var terrain: TerrainEffects
var caster: SpellCaster
var hero: Unit
var enemies: Array[Unit] = []
var actor_index := 0
var phase := "hero"
var outcome := ""
var room: Dictionary = {}
var last_action: Dictionary = {}
static var last_restore_error := ""


func initialize(state, index: int, hp := -1) -> bool:
	if index < 1 or index > 12 or state == null or not state.valid_deck(state.active): return false
	cards = state
	encounter = Catalog.data().route[index - 1]
	_create_grid()
	hero = Unit.new("Achille", 0, 110, 10, 4, 3, 18)
	hero.unit_id = &"cc2_hero"
	Turns.bind_hero(hero, cards)
	Turns.rebuild(hero, cards)
	if hp >= 0: hero.current_hp = mini(hp, hero.max_hp.get_int())
	grid.place_unit(hero, Vector2i(3, 5))
	enemies = Enemies.build(encounter)
	var spawn := [Vector2i(3, 1), Vector2i(1, 1), Vector2i(5, 1), Vector2i(3, 2)]
	var roster: Array[String] = []
	for enemy_index in enemies.size():
		grid.place_unit(enemies[enemy_index], spawn[enemy_index])
		roster.append(str(enemies[enemy_index].unit_id))
	cards.encounter_id = "cc2_encounter_%02d" % index
	Economy.commit_loot(cards, encounter, roster)
	room = {"rail": 1, "radius": 2, "used": false, "sealed": false, "deliveries": 0, "charges": [0, 0], "clock": [3, 5], "delayed": false, "debt": false, "multiplier": 1.0}
	Turns.begin_hero(hero, cards, terrain)
	return true


func _create_grid() -> void:
	grid = preload("res://core/expedition/consumable_cards_content.gd").grid(str(encounter.map))
	pathfinder = Pathfinder.new(grid)
	terrain = TerrainEffects.new(grid)
	terrain.capture_base_state()
	caster = SpellCaster.new(grid, pathfinder, terrain)


func dispose() -> void:
	if terrain != null: terrain.dispose()
	if grid != null:
		for unit in grid.get_units().duplicate(): grid.remove_unit(unit)
	for unit in enemies:
		unit.grid_context = null
	if hero != null: hero.grid_context = null


func command(request: Dictionary) -> Dictionary:
	if not outcome.is_empty(): return _failure("combat_complete")
	if phase != "hero": return _failure("enemy_activation_pending")
	var kind := str(request.get("kind", ""))
	if not cards.pending_choice.is_empty():
		if kind == "retain" and cards.retain_copy(str(request.get("uid", ""))): return _success(kind)
		if kind == "relay":
			var uid := str(request.get("target", ""))
			var target := unit_for(uid)
			if not uid.is_empty() and target == null: return _failure("unknown_target")
			if Effects.relay(hero, cards, target): return _success(kind)
		return _failure("choice_pending")
	match kind:
		"card", "fallback":
			var spell: Spell
			if kind == "card":
				var uid := str(request.get("uid", ""))
				if uid not in cards.hand: return _failure("card_not_in_hand")
				spell = cards.family_spell(str(cards.copy_for(uid).family))
				cards.selected = uid
			else:
				var family := str(request.get("family", ""))
				if family not in ["fallback_strike", "fallback_guard"]: return _failure("unknown_fallback")
				spell = cards.family_spell(family)
			var cell_value: Variant = request.get("cell")
			if not _cell_array(cell_value): return _failure("target")
			var cell := Vector2i(cell_value[0], cell_value[1])
			cards.action_options = request.get("options", {}).duplicate(true)
			var failure := caster.get_cast_failure_reason(hero, spell, cell)
			if failure != &"":
				cards.action_options.clear()
				cards.selected = ""
				return _failure(str(failure))
			var report := caster.cast(hero, spell, cell)
			last_action = {"kind": kind, "spell": str(spell.spell_id), "cell": cell_value.duplicate(), "damage": int(report.get("hp_damage_total", 0)), "healing": int(report.get("healing_total", 0))}
			Enemies.update_boss_phase(enemies)
			_check_outcome()
			if hero.activation_consumed and outcome.is_empty(): _end_hero()
			return {"success": true, "action": last_action.duplicate(true), "outcome": outcome}
		"move":
			var cell_value: Variant = request.get("cell")
			if not _cell_array(cell_value): return _failure("target")
			var cell := Vector2i(cell_value[0], cell_value[1])
			var path := pathfinder.find_path(hero.grid_pos, cell, hero)
			if path.size() < 2 or path.size() - 1 > hero.current_mp: return _failure("movement")
			for step in path.slice(1):
				if not grid.relocate_unit(hero, step): return _failure("movement")
				hero.spend_mp(1)
				cards.moved_cells += 1
				if not hero.is_alive: break
			_check_outcome()
			return _success(kind)
		"anchor":
			if not Effects.return_to_anchor(hero, cards, grid): return _failure("anchor_unavailable")
			_check_outcome()
			return _success(kind)
		"room":
			return _room_command(request)
		"end_turn":
			_end_hero()
			return _success(kind)
	return _failure("unknown_command")


func _end_hero() -> void:
	if encounter.map == "reservoir":
		for index in 2:
			if grid.manhattan(hero.grid_pos, Vector2i(0 if index == 0 else 6, 3)) <= 1:
				var stored := mini(hero.current_ap, 6 - int(room.charges[index]))
				room.charges[index] += stored
				hero.spend_ap(stored)
				break
	Turns.end_hero(cards, grid)
	phase = "enemies"
	actor_index = 0


func next_actor() -> Dictionary:
	if not outcome.is_empty() or phase == "hero": return _failure("actor_not_pending")
	if phase == "enemies" and actor_index < enemies.size():
		var enemy := enemies[actor_index]
		actor_index += 1
		if enemy.is_alive:
			if not _convoy(enemy):
				var units: Array = [hero]
				units.append_array(enemies)
				last_action = Enemies.activate(enemy, hero, units, grid, terrain, caster, reference_power())
			if encounter.map == "reservoir" and enemy.is_alive:
				for index in 2:
					if int(room.charges[index]) > 0 and grid.manhattan(enemy.grid_pos, Vector2i(0 if index == 0 else 6, 3)) <= 1:
						room.charges[index] -= 1
						enemy.heal(Math.rounded(.3 * reference_power()))
		_check_outcome()
		if actor_index >= enemies.size() and outcome.is_empty(): phase = "environment"
		return _success("enemy_activation")
	if phase == "environment":
		_environment()
		_check_outcome()
		Turns.end_enemy_phase(cards, grid, terrain)
		if outcome.is_empty():
			var pressure := Math.pressure(hero.max_hp.get_int(), cards.round_index)
			hero.current_hp = maxi(0, hero.current_hp - pressure)
			if hero.current_hp == 0: hero._die()
			_check_outcome()
		if outcome.is_empty() and cards.round_index >= 24: outcome = "timeout"
		if outcome.is_empty():
			room.used = false
			phase = "hero"
			Turns.begin_hero(hero, cards, terrain)
			_check_outcome()
		return _success("enemy_phase_end")
	return _failure("actor_queue")


func _check_outcome() -> void:
	if not hero.is_alive or hero.current_hp <= 0: outcome = "defeat"
	elif not enemies.any(func(u): return u.is_alive): outcome = "victory"
	if not outcome.is_empty(): phase = "complete"
	if not outcome.is_empty():
		cards._activation_open = false
		cards.pending_choice.clear()


func unit_for(uid: String) -> Unit:
	if str(hero.unit_id) == uid: return hero
	for enemy in enemies:
		if str(enemy.unit_id) == uid: return enemy
	return null


func reference_power() -> float:
	return float(Catalog.data().rules.prowess[int(encounter.level) - 1])


func _room_command(request: Dictionary) -> Dictionary:
	if room.used or hero.current_ap < 1: return _failure("mechanism_unavailable")
	var mode := str(request.get("mode", ""))
	var cell := Vector2i(0, 3)
	var cost := 1
	var value := int(request.get("value", 0))
	match str(encounter.map):
		"forge":
			if mode != "forge" or value not in [1, 3, 5]: return _failure("choose_rail")
		"hourglass":
			if mode != "delay" or room.delayed or room.debt: return _failure("already_delayed")
		"convoy":
			if mode != "seal" or room.sealed: return _failure("already_sealed")
			cost = 2
		"reservoir":
			if mode != "discharge" or value not in [0, 1] or int(room.charges[value]) <= 0: return _failure("empty_reservoir")
			cell = Vector2i(0 if value == 0 else 6, 3)
		_: return _failure("no_mechanism")
	if hero.current_ap < cost or grid.manhattan(hero.grid_pos, cell) > 1: return _failure("mechanism_out_of_reach")
	hero.spend_ap(cost)
	room.used = true
	match str(encounter.map):
		"forge": room.rail = value
		"hourglass":
			room.delayed = true
			room.multiplier = 1.5
		"convoy": room.sealed = true
		"reservoir":
			for enemy in enemies:
				if enemy.is_alive:
					Effects.hit(enemy, hero, .5 * reference_power() * int(room.charges[value]))
					break
			room.charges[value] = 0
	Enemies.update_boss_phase(enemies)
	_check_outcome()
	return _success("room")


func _convoy(enemy: Unit) -> bool:
	if encounter.map != "convoy" or room.sealed or int(enemy.get_meta("cc2_spawn", -1)) not in [1, 2]: return false
	enemy.start_turn()
	if Turns.apply_activation_statuses(enemy, grid, Terrain.begin_activation(terrain, enemy)): return true
	if grid.manhattan(enemy.grid_pos, Vector2i(3, 0)) <= 1:
		for leader in enemies:
			if leader.is_alive and int(leader.get_meta("cc2_spawn")) not in [1, 2]:
				var bonus := Math.rounded(.8 * reference_power())
				leader.max_hp.base_value += bonus
				leader.current_hp += bonus
				leader.attack_power.base_value += Math.rounded(.02 * float(Catalog.data().rules.hp[int(encounter.level) - 1]))
				break
		enemy.set_meta("cc2_sacrificed", true)
		enemy.current_hp = 0
		enemy._die()
		room.deliveries += 1
	else:
		var path := pathfinder.find_path(enemy.grid_pos, Vector2i(3, 0), enemy)
		if path.size() > 1 and enemy.current_mp > 0: grid.relocate_unit(enemy, path[1])
	return true


func _environment() -> void:
	var units: Array = [hero]
	units.append_array(enemies)
	var hit_cells := danger_cells()
	var coefficient := .6
	match str(encounter.map):
		"forge":
			room.rail = {1: 3, 3: 5, 5: 1}[int(room.rail)]
		"hourglass":
			if room.delayed:
				room.delayed = false
				room.debt = true
				return
			coefficient = .7 * float(room.multiplier)
			room.clock = [hero.grid_pos.x, hero.grid_pos.y]
			room.multiplier = 1.0
			room.debt = false
	for unit in units:
		if unit.is_alive and unit.grid_pos in hit_cells:
			Effects.hit(unit, null, reference_power() * (1.3 if encounter.map == "forge" and unit != hero else coefficient))


func danger_cells() -> Array[Vector2i]:
	var center := Vector2i(room.clock[0], room.clock[1])
	var band := 2
	match str(encounter.map):
		"forge": band = int(room.rail)
		"garden":
			band = int([2, 3, 1][(cards.round_index - 1) % 3])
			for enemy in enemies:
				if enemy.is_alive:
					center = enemy.grid_pos
					break
		"hourglass":
			if room.delayed: return []
	return preload("res://core/expedition/card_tactical_room_rules.gd").profile_danger_cells(str(encounter.map), grid, center, band)


func snapshot() -> Dictionary:
	var units: Array[Dictionary] = []
	for unit in [hero] + enemies:
		var stats := {}
		for key in ["max_hp", "attack_power", "max_ap", "max_mp", "armure", "resist_magique"]: stats[key] = unit.get(key).base_value
		var metadata := {}
		for key in unit.get_meta_list():
			if str(key).begins_with("cc2_") and key != &"cc2_cards": metadata[str(key)] = unit.get_meta(key)
		units.append({"id": str(unit.unit_id), "cell": [unit.grid_pos.x, unit.grid_pos.y], "hp": unit.current_hp, "ap": unit.current_ap, "mp": unit.current_mp, "alive": unit.is_alive, "activation": unit.activation_index, "activation_consumed": unit.activation_consumed, "shields": unit.get_shield_instances_snapshot(), "stats": stats, "metadata": metadata})
	# Canonical JSON-compatible scalar types and detached nested metadata.
	return JSON.parse_string(JSON.stringify({"encounter": int(encounter.index), "phase": phase, "outcome": outcome, "actor_index": actor_index, "units": units, "surfaces": Terrain.snapshot(terrain), "room": room.duplicate(true), "cast_sequence": caster._cast_sequence, "last_action": last_action.duplicate(true)}))


static func _cell_array(value: Variant) -> bool:
	return value is Array and value.size() == 2 and value.all(func(n): return _integer(n, 0, 6))


static func restore(state, value: Dictionary):
	last_restore_error = "header"
	var index := int(value.get("encounter", 0))
	if index < 1 or index > 12 or value.get("phase") not in ["hero", "enemies", "environment", "complete"] or value.get("outcome") not in ["", "victory", "defeat", "timeout"]:
		return null
	if not value.get("units") is Array or not value.get("room") is Dictionary or not value.get("surfaces") is Array or not value.get("last_action") is Dictionary:
		return null
	var candidate = load("res://core/expedition/consumable_cards_battle.gd").new()
	candidate.cards = state
	candidate.encounter = Catalog.data().route[index - 1]
	candidate._create_grid()
	candidate.hero = Unit.new("Achille", 0, 110, 10, 4, 3, 18)
	candidate.hero.unit_id = &"cc2_hero"
	Turns.bind_hero(candidate.hero, state)
	candidate.enemies = Enemies.build(candidate.encounter)
	var all_units: Array = [candidate.hero]
	all_units.append_array(candidate.enemies)
	if value.units.size() != all_units.size():
		last_restore_error = "roster_size"
		candidate.dispose()
		return null
	var valid := true
	for unit_index in all_units.size():
		var entry: Variant = value.units[unit_index]
		var unit: Unit = all_units[unit_index]
		if not _valid_unit_snapshot(entry, str(unit.unit_id)):
			last_restore_error = "unit:" + str(unit.unit_id)
			valid = false
			break
		if unit != candidate.hero:
			for key in ["cc2_kind", "cc2_spawn", "cc2_boss", "cc2_variant"]:
				if entry.metadata.get(key) != unit.get_meta(key): valid = false
			if not valid:
				last_restore_error = "enemy_identity"
				break
		for key in entry.stats: unit.get(key).base_value = float(entry.stats[key])
		unit.current_hp = int(entry.hp)
		unit.current_ap = int(entry.ap)
		unit.current_mp = int(entry.mp)
		unit.activation_index = int(entry.activation)
		unit.activation_consumed = entry.activation_consumed
		unit.is_alive = entry.alive
		for key in entry.metadata: unit.set_meta(key, entry.metadata[key].duplicate(true) if entry.metadata[key] is Dictionary else entry.metadata[key])
		if not unit.restore_shield_instances_snapshot(entry.shields):
			last_restore_error = "shields:" + str(unit.unit_id)
			valid = false
			break
		var cell := Vector2i(entry.cell[0], entry.cell[1])
		if unit.is_alive:
			if not candidate.grid.is_walkable(cell) or not candidate.grid.place_unit(unit, cell):
				last_restore_error = "occupancy:" + str(unit.unit_id)
				valid = false
				break
		else: unit.grid_pos = cell
	var actor: Variant = value.get("actor_index")
	var sequence: Variant = value.get("cast_sequence")
	if not _integer(actor, 0, candidate.enemies.size()) or not _integer(sequence, 0, 10000): valid = false
	for key in ["rail", "radius", "used", "sealed", "deliveries", "charges", "clock", "delayed", "debt", "multiplier"]:
		if not value.room.has(key): valid = false
	if valid:
		if int(value.room.rail) not in [1, 3, 5] or int(value.room.radius) not in [1, 2, 3] or not value.room.charges is Array or value.room.charges.size() != 2 or not value.room.charges.all(func(n): return _integer(n, 0, 6)) or not _cell_array(value.room.clock):
			last_restore_error = "room_fields"
			valid = false
		for key in ["used", "sealed", "delayed", "debt"]:
			if not value.room[key] is bool: valid = false
		if not _integer(value.room.deliveries, 0, 2) or float(value.room.multiplier) not in [1.0, 1.5]:
			last_restore_error = "room_multiplier"
			valid = false
	var cells := {}
	if valid:
		for entry in value.surfaces:
			if not entry is Dictionary or not _cell_array(entry.get("cell")) or entry.get("surface") not in ["fire", "water", "ice", "steam"] or not _integer(entry.get("duration"), 1, 3) or not entry.get("flags") is Dictionary or not entry.get("source") is String:
				valid = false
				break
			var payload: Variant = entry.flags.get("cc2_payload")
			if not entry.flags.get("cc2_group") is String or not (payload is int or payload is float) or not is_finite(float(payload)) or payload < 0 or payload > 10000:
				valid = false
				break
			var cell := Vector2i(entry.cell[0], entry.cell[1])
			var source: Unit = candidate.unit_for(entry.source)
			if source == null or cells.has(cell) or not candidate.grid.is_terrain_interactable(cell):
				valid = false
				break
			cells[cell] = true
			candidate.terrain.place_effect(cell, Terrain.effect(entry.surface, int(entry.duration)), source)
			candidate.terrain.runtime_service.get_state(cell).gameplay_flags = entry.flags.duplicate(true)
	if not valid:
		candidate.dispose()
		return null
	candidate.actor_index = int(actor)
	candidate.phase = value.phase
	candidate.outcome = value.outcome
	candidate.caster._cast_sequence = int(sequence)
	candidate.room = value.room.duplicate(true)
	candidate.last_action = value.last_action.duplicate(true)
	if (candidate.phase == "hero") != bool(state._activation_open) or (candidate.phase == "complete") != (not candidate.outcome.is_empty()):
		last_restore_error = "phase_activation"
		candidate.dispose()
		return null
	last_restore_error = ""
	return candidate


static func _integer(n: Variant, low: int, high: int) -> bool:
	return (n is int or n is float) and is_finite(float(n)) and float(n) == floorf(float(n)) and n >= low and n <= high


static func _valid_unit_snapshot(entry: Variant, expected_id: String) -> bool:
	if not entry is Dictionary or entry.get("id") != expected_id or not _cell_array(entry.get("cell")) or not entry.get("stats") is Dictionary or not entry.get("metadata") is Dictionary or not entry.get("shields") is Array:
		return false
	for key in ["max_hp", "attack_power", "max_ap", "max_mp", "armure", "resist_magique"]:
		var n: Variant = entry.stats.get(key)
		if not (n is int or n is float) or not is_finite(float(n)) or n < 0 or n > 10000: return false
	if entry.stats.size() != 6 or float(entry.stats.max_hp) <= 0: return false
	if not _integer(entry.get("hp"), 0, int(entry.stats.max_hp)) or not _integer(entry.get("ap"), 0, 4) or not _integer(entry.get("mp"), 0, 7) or not _integer(entry.get("activation"), 0, 25): return false
	if not entry.get("alive") is bool or not entry.get("activation_consumed") is bool or entry.alive != (entry.hp > 0): return false
	if entry.metadata.get("cc2_ruleset") != Effects.ID: return false
	if entry.metadata.has("cc2_phase") and not _integer(entry.metadata.cc2_phase, 1, 2): return false
	if entry.metadata.has("cc2_sacrificed") and not entry.metadata.cc2_sacrificed is bool: return false
	var intent: Variant = entry.metadata.get("cc2_intent", {})
	if not intent is Dictionary: return false
	if not intent.is_empty():
		if not intent.get("cells") is Array or intent.cells.is_empty() or intent.cells.size() > 3 or not intent.cells.all(_cell_array): return false
		if not (intent.get("multiplier") is int or intent.get("multiplier") is float) or float(intent.multiplier) not in [1.4, 1.5]: return false
	for key in entry.metadata:
		if key not in ["cc2_ruleset", "cc2_kind", "cc2_spawn", "cc2_boss", "cc2_phase", "cc2_sacrificed", "cc2_intent", "cc2_variant", "cc2_effects"]: return false
	var statuses: Variant = entry.metadata.get("cc2_effects", {})
	if not statuses is Dictionary: return false
	for key in statuses:
		if key not in ["mark", "slow", "burn", "bleed", "weak", "stasis", "stasis_ward", "parry", "counter", "edict"]: return false
		var status: Variant = statuses[key]
		if not status is Dictionary or not _integer(status.get("duration"), 1, 3) or not status.get("source") is String: return false
		if not (status.get("amount") is float or status.get("amount") is int) or not is_finite(float(status.amount)) or status.amount < 0 or status.amount > 10000: return false
		if status.has("expires_hero_end") and not _integer(status.expires_hero_end, 1, 25): return false
		if status.has("origin") and status.origin not in ["relay", "direct"]: return false
	return true


func _success(kind: String) -> Dictionary:
	return {"success": true, "kind": kind, "outcome": outcome}


func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}
