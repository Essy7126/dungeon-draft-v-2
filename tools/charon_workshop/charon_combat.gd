extends RefCounted
## Local encounter controller. Shared engine owns cards, damage, status and movement.
signal changed
const Catalog = preload("res://core/expedition/class_card_catalog.gd")
const Cards = preload("res://core/expedition/class_cards.gd")
const PROFILE = preload("res://tools/charon_workshop/default_profile.tres")
const TERMINALS := [Vector2i(2, 3), Vector2i(6, 3)]
const SIGNATURES := {
	"assassin": "a_lure",
	"gardien": "g_hook",
	"arpenteur": "r_net",
	"thaumaturge": "t_charm",
}

var profile: Resource
var grid: GridData
var pathfinder: Pathfinder
var terrain: TerrainEffects
var caster: SpellCaster
var hero: Unit
var boss: Unit
var carriers: Array[Unit] = []
var session: ExpeditionSession
var arena: ArenaDefinition
var cards: CatabaseCards
var hook: Spell
var oar: Spell
var bolt: Spell
var round_number := 1
var enemy_activations := 0
var pending: Dictionary = { }
var coins: Dictionary = { }
var oboles := 0
var outcome := ""
var player_turn := true
var messages: Array[String] = []
var metrics := {
	"crossings": 0,
	"dodged": 0,
	"gates": 0,
	"rotations": 0,
	"friendly_hits": 0,
	"cards": 0,
}


func initialize(class_id := "gardien", run_seed := 42, tuning: Resource = null) -> void:
	profile = (tuning if tuning != null else PROFILE).duplicate()
	class_id = class_id if Catalog.CLASSES.has(class_id) else "gardien"
	arena = ArenaDefinition.new()
	arena.set_identity("Quais de Charon · prototype", "charon_workshop")
	arena.grid_size = Vector2i(9, 7)
	for y in 7:
		for x in 9:
			var water := x == 4 and y not in [1, 3, 5]
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)),
				&"hole" if water else &"neutral",
			)
	var runtime := ArenaRuntimeProjectionService.build(arena)
	grid = runtime.grid
	terrain = runtime.terrain_effects
	pathfinder = Pathfinder.new(grid)
	caster = SpellCaster.new(grid, pathfinder, terrain)
	hero = Unit.new(
		"Achille",
		0,
		profile.hero_hp,
		10,
		profile.hero_ap,
		profile.hero_mp,
		profile.prowess,
	)
	boss = Unit.new("Charon", 1, profile.boss_hp, 8, 4, 2, 0)
	grid.place_unit(hero, Vector2i(1, 3))
	grid.place_unit(boss, Vector2i(7, 3))
	for cell in [Vector2i(6, 1), Vector2i(6, 5)]:
		var carrier := Unit.new("Porteur", 1, profile.carrier_hp, 6, 2, 2, 0)
		carriers.append(carrier)
		grid.place_unit(carrier, cell)
		carrier.died.connect(_on_carrier_died)
	hook = _spell("charon_hook", "Crochet du passeur", 2, 2, 5, profile.hook_damage)
	hook.pull_distance = 2
	oar = _spell("charon_oar", "Coup de rame", 2, 1, 1, profile.oar_damage)
	oar.push_distance = 2
	bolt = _spell("charon_carrier", "Obole brûlante", 2, 1, 4, profile.carrier_damage)
	session = ExpeditionSession.new()
	session.character = CharacterRunState.new()
	var data := UnitData.new()
	data.unit_id = &"charon_workshop_hero"
	data.unit_name = "Achille"
	session.character.initialize(hero, data)
	session.route.seed = run_seed
	session.route.current_node_id = "charon_workshop"
	session.route.phase = "combat"
	cards = Cards.new()
	session.cards = cards
	cards.bind(session)
	cards.primary_class = class_id
	for key in cards.masteries:
		cards.masteries[key] = 2 if key == class_id else 0
	hero.set_meta("ct_session", weakref(session))
	var prefix: String = { "assassin": "a", "gardien": "g", "arpenteur": "r", "thaumaturge": "t" }[
		class_id
	]
	for family in [
		"s_%s_hit" % prefix,
		"s_%s_guard" % prefix,
		"s_%s_step" % prefix,
		"s_%s_push" % prefix,
		SIGNATURES[class_id],
	]:
		for _copy in 2:
			cards.active.append(cards.add_copy(family, true))
	grid.occupancy_changed.connect(_on_occupancy)
	hero.start_turn()
	cards.start_turn()
	log_message(
		"Tuez Charon. Les Porteurs laissent une obole à ramasser. Les bornes B exigent d'être dessus ou adjacent."
	)
	log_message(
		"Première traversée annoncée au prochain tour ennemi : vous aurez un tour complet pour réagir."
	)
	changed.emit()


func _spell(id: String, title: String, cost: int, minimum: int, maximum: int, damage: int) -> Spell:
	var spell := Spell.new()
	spell.spell_id = StringName(id)
	spell.spell_name = title
	spell.ap_cost = cost
	spell.minimum_range = minimum
	spell.spell_range = maximum
	spell.damage = damage
	spell.damage_type = Spell.DamageType.PHYSICAL
	spell.once_per_activation = true
	return spell


func log_message(message: String) -> void:
	messages.append(message)
	if messages.size() > 60:
		messages.pop_front()


func move_hero(cell: Vector2i) -> bool:
	if not _can_play():
		return false
	var path := pathfinder.find_path(hero.grid_pos, cell, hero)
	if path.size() < 2 or not hero.spend_mp(pathfinder.path_movement_cost(path, hero)):
		return false
	_move_path(hero, path)
	_finish_action()
	return true


func _move_path(actor: Unit, path: Array) -> void:
	terrain.begin_unit_resolution(actor, &"movement")
	for index in range(1, path.size()):
		if not grid.relocate_unit(actor, path[index]):
			break
		actor.record_runtime_movement(1)
		var entry := terrain.consume_last_entry_result(actor)
		if entry.get("end_movement", false) or not actor.is_alive:
			break
	terrain.end_unit_resolution(actor)


func play_card(id: String, cell: Vector2i) -> bool:
	if not _can_play() or id not in cards.hand:
		return false
	var spell: Spell = cards.spells_for(id)[0]
	if not caster.can_cast(hero, spell, cell):
		return false
	var result := caster.cast(hero, spell, cell)
	if result.get("failed", false):
		return false
	metrics.cards += 1
	log_message("%s · %d PA" % [spell.spell_name, spell.ap_cost])
	_finish_action()
	return true


func retain(id: String) -> void:
	if _can_play() and id in cards.hand:
		cards.retained = "" if cards.retained == id else id
		changed.emit()


func play_gesture(index: int, cell: Vector2i) -> bool:
	if not _can_play() or index < 0 or index >= cards.weapon_spells().size():
		return false
	var spell: Spell = cards.weapon_spells()[index]
	if not caster.can_cast(hero, spell, cell):
		return false
	var result := caster.cast(hero, spell, cell)
	if result.get("failed", false):
		return false
	log_message(spell.spell_name + " · geste hors deck")
	_finish_action()
	return true


func recompose(id: String) -> bool:
	if not _can_play() or not cards.recompose(id):
		return false
	log_message("Une carte recomposée pour 1 PA.")
	changed.emit()
	return true


func _can_play() -> bool:
	return player_turn and outcome.is_empty() and hero.is_alive


func crossing_cells(direction: Vector2i, origin: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for step in range(1, profile.crossing_length + 1):
		var cell := origin + direction * step
		if not grid.is_valid(cell) or not grid.is_terrain_interactable(cell):
			break
		cells.append(cell)
	return cells


func terminal_failure(action: String) -> String:
	if not _can_play():
		return "Le combat est terminé ou ce n'est pas votre tour."
	if action not in ["left", "right", "gate"]:
		return "Commande inconnue."
	if pending.is_empty():
		return "Aucune traversée en préparation."
	if boss.grid_pos != pending.origin:
		return "Charon a été déplacé : sa traversée sera annulée."
	if pending.modified:
		return "Cette traversée a déjà été modifiée."
	if not TERMINALS.any(
		func(cell):
			return grid.manhattan(hero.grid_pos, cell) <= 1,
	):
		return "Rejoignez une borne B ou une case adjacente."
	if oboles < 1:
		return "Ramassez une obole sur un Porteur vaincu."
	if hero.current_ap < 1:
		return "Il faut 1 PA."
	if action != "gate" and preview_terminal(action).is_empty():
		return "Ce trajet est bloqué."
	return ""


func preview_terminal(action: String) -> Array[Vector2i]:
	if pending.is_empty() or action == "gate":
		return []
	var direction: Vector2i = pending.direction
	direction = (
		Vector2i(direction.y, -direction.x)
		if action == "left"
		else Vector2i(-direction.y, direction.x)
	)
	return crossing_cells(direction, pending.origin)


func use_terminal(action: String) -> bool:
	if not terminal_failure(action).is_empty():
		return false
	var cells := preview_terminal(action)
	hero.current_ap -= 1
	oboles -= 1
	pending.modified = true
	if action == "gate":
		pending.gate = true
		metrics.gates += 1
		log_message(
			"Herse armée : prochaine traversée annulée, %d dégâts à Charon." % profile.gate_damage
		)
	else:
		pending.cells = cells
		pending.direction = cells[0] - Vector2i(pending.origin)
		metrics.rotations += 1
		log_message("Trajet tourné de 90° ; il reste fixé jusqu'à la résolution.")
	changed.emit()
	return true


func end_turn() -> void:
	if not _can_play():
		return
	player_turn = false
	cards.end_turn()
	EventBus.turn_ended.emit(hero, &"manual")
	enemy_activations += 1
	boss.start_turn()
	terrain.on_turn_start(boss)
	_check_outcome()
	if outcome.is_empty():
		if not pending.is_empty():
			_resolve_crossing()
		elif (enemy_activations - 1) % maxi(2, profile.crossing_period) == 0:
			_prepare_crossing()
		else:
			_normal_boss_turn()
	_check_outcome()
	for carrier in carriers:
		if not outcome.is_empty():
			break
		if not carrier.is_alive:
			continue
		carrier.start_turn()
		terrain.on_turn_start(carrier)
		if not carrier.is_alive:
			continue
		_approach(carrier, 4)
		if caster.can_cast(carrier, bolt, hero.grid_pos):
			caster.cast(carrier, bolt, hero.grid_pos)
			log_message(
				"Un Porteur lance Obole brûlante : %d dégâts avant défense."
				% profile.carrier_damage
			)
		_check_outcome()
	if outcome.is_empty():
		terrain.tick_all_effects()
		round_number += 1
		hero.start_turn()
		terrain.on_turn_start(hero)
		_check_outcome()
		if outcome.is_empty():
			cards.start_turn()
			player_turn = true
	changed.emit()


func _prepare_crossing() -> void:
	var delta := hero.grid_pos - boss.grid_pos
	var direction := (
		Vector2i(signi(delta.x), 0)
		if absi(delta.x) >= absi(delta.y)
		else Vector2i(0, signi(delta.y))
	)
	var cells := crossing_cells(direction, boss.grid_pos)
	if cells.is_empty():
		_normal_boss_turn()
		return
	pending = {
		"origin": boss.grid_pos,
		"direction": direction,
		"cells": cells,
		"modified": false,
		"gate": false,
	}
	boss.current_ap = 0
	boss.current_mp = 0
	log_message(
		"Charon prépare Traversée funèbre : %d dégâts sur le trajet au prochain tour ennemi, Porteurs compris."
		% profile.crossing_damage
	)


func _resolve_crossing() -> void:
	var order := pending.duplicate(true)
	pending.clear()
	boss.current_ap = 0
	boss.current_mp = 0
	if boss.grid_pos != order.origin:
		log_message("Charon a quitté son point de départ : traversée annulée, activation perdue.")
		return
	if order.gate:
		boss.take_damage(profile.gate_damage, hero, Spell.DamageType.PHYSICAL)
		log_message("La herse interrompt Charon : %d dégâts avant défense." % profile.gate_damage)
		return
	metrics.crossings += 1
	var hit_hero := false
	for cell: Vector2i in order.cells:
		var victim := grid.get_unit(cell) as Unit
		if victim != null and victim != boss:
			if victim == hero:
				hit_hero = true
			else:
				metrics.friendly_hits += 1
			victim.take_damage(profile.crossing_damage, boss, Spell.DamageType.PHYSICAL)
	if not hit_hero:
		metrics.dodged += 1
	# The spectral boat crosses occupants; land on its furthest free route cell.
	var reversed: Array = order.cells.duplicate()
	reversed.reverse()
	for cell: Vector2i in reversed:
		if grid.is_walkable(cell, boss):
			grid.relocate_unit(boss, cell)
			break
	log_message(
		"Traversée résolue : %s." % ("Achille touché" if hit_hero else "Achille hors du trajet")
	)


func _normal_boss_turn() -> void:
	_approach(boss, 1)
	if boss.grid_pos.x == hero.grid_pos.x or boss.grid_pos.y == hero.grid_pos.y:
		if caster.can_cast(boss, hook, hero.grid_pos):
			caster.cast(boss, hook, hero.grid_pos)
			log_message("Crochet : %d dégâts et attraction de 2 cases." % profile.hook_damage)
	if hero.is_alive and caster.can_cast(boss, oar, hero.grid_pos):
		caster.cast(boss, oar, hero.grid_pos)
		log_message("Coup de rame : %d dégâts et poussée de 2 cases." % profile.oar_damage)


func _approach(actor: Unit, desired_range: int) -> void:
	for _step in actor.current_mp:
		if grid.manhattan(actor.grid_pos, hero.grid_pos) <= desired_range:
			break
		var best: Array = []
		for offset in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var cell: Vector2i = hero.grid_pos + offset
			if not grid.is_walkable(cell, actor):
				continue
			var path := pathfinder.find_path(actor.grid_pos, cell, actor)
			if path.size() > 1 and (best.is_empty() or path.size() < best.size()):
				best = path
		if best.is_empty():
			break
		var hop: Array = [actor.grid_pos, best[1]]
		if not actor.spend_mp(pathfinder.path_movement_cost(hop, actor)):
			break
		_move_path(actor, hop)


func _on_carrier_died(actor: Unit) -> void:
	coins[actor.grid_pos] = int(coins.get(actor.grid_pos, 0)) + 1
	log_message("Un Porteur laisse une obole en %s." % str(actor.grid_pos))
	grid.remove_unit(actor)


func _on_occupancy(_reason: StringName, actor, _from: Vector2i, to: Vector2i) -> void:
	if actor == hero and hero.is_alive and coins.has(to):
		oboles += int(coins[to])
		coins.erase(to)
		log_message("Obole ramassée. Une borne permet de tourner le trajet ou d'armer la herse.")


func _finish_action() -> void:
	_check_outcome()
	changed.emit()


func _check_outcome() -> void:
	if not outcome.is_empty():
		return
	if not hero.is_alive:
		outcome = "Défaite"
	elif not boss.is_alive:
		outcome = "Victoire"
	if not outcome.is_empty():
		pending.clear()
		player_turn = false
		log_message(
			"%s · %d tours · %d cartes · %d traversées évitées · %d herses."
			% [outcome, round_number, metrics.cards, metrics.dodged, metrics.gates]
		)


func dispose() -> void:
	if cards != null and EventBus.turn_ended.is_connected(cards._on_turn_ended):
		EventBus.turn_ended.disconnect(cards._on_turn_ended)
	if grid != null and grid.occupancy_changed.is_connected(_on_occupancy):
		grid.occupancy_changed.disconnect(_on_occupancy)
	for carrier in carriers:
		if carrier.died.is_connected(_on_carrier_died):
			carrier.died.disconnect(_on_carrier_died)
		carrier.clear_combat_effect_history()
	if terrain != null:
		terrain.dispose()
	if grid != null:
		for actor: Unit in grid.get_units():
			actor.clear_combat_effect_history()
			grid.remove_unit(actor)
	if hero != null and hero.has_meta("ct_session"):
		hero.remove_meta("ct_session")
	if session != null and session.character != null:
		session.character.dispose()
	carriers.clear()
	session = null
	cards = null
