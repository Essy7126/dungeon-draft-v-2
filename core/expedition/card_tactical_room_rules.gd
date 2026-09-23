extends RefCounted
signal changed
const ALTAR := Vector2i(7, 3)
const LEVER := Vector2i(2, 3)
var room_id := "forge"
var rail := 3
var radius := 2
var mechanism_used := false
var altar_sealed := false
var deliveries := 0
var environmental_hits := 0
var grid: GridData
var pathfinder: Pathfinder
var terrain: TerrainEffects
var hero: Unit
var boss: Unit
var carriers: Array[Unit] = []
var enemies: Array[Unit] = []
var coins := { }
var messages: Array[String] = []
var outcome := ""
var can_play: Callable


func bind(
	id: String,
	board: GridData,
	surfaces: TerrainEffects,
	actors: Array,
	input_allowed: Callable,
) -> void:
	room_id = id
	grid = board
	terrain = surfaces
	pathfinder = Pathfinder.new(grid)
	can_play = input_allowed
	for actor: Unit in actors:
		if actor.team == 0:
			hero = actor
		else:
			enemies.append(actor)
	var role: String = preload("res://core/expedition/card_tactical_room_catalog.gd").CHIEF_ROLES[
		id
	]
	for actor in enemies:
		if str(actor.tactical_role_id) == "catabase_evolution_" + role:
			boss = actor
			break
	# Isolated fixtures may have no authored roles. Production encounters must contain the chief.
	if boss == null:
		assert(
			enemies.all(
				func(actor):
					return str(actor.tactical_role_id).is_empty(),
			),
			"Missing room chief: " + role,
		)
		boss = enemies[0] if not enemies.is_empty() else null
	for actor: Unit in actors:
		if (
			actor.team != 0 and actor != boss
			and (id != "convoy" or str(actor.tactical_role_id) in ["", "catabase_evolution_porteur"])
		):
			carriers.append(actor)
			actor.died.connect(_on_carrier_died)
	grid.occupancy_changed.connect(_on_occupancy)


func _can_play() -> bool:
	return hero != null and hero.is_alive and outcome.is_empty() and can_play.call()


func is_mechanism_active() -> bool:
	if not outcome.is_empty() or hero == null or not hero.is_alive:
		return false
	if room_id in ["forge", "hourglass"]:
		return grid.get_units().any(
			func(actor):
				return actor.is_alive and actor.team != hero.team,
		)
	return boss != null and boss.is_alive


func log_message(message: String) -> void:
	messages.append(message)
	if messages.size() > 5:
		messages.pop_front()


func finish_hero_turn() -> void:
	if not outcome.is_empty():
		return
	_resolve_environment()
	rail = 3 if rail == 1 else (5 if rail == 3 else 1)
	radius = 3 if radius == 2 else (1 if radius == 3 else 2)
	mechanism_used = false
	changed.emit()


func begin_enemy_turn(actor: Unit) -> bool:
	if room_id != "convoy" or boss == null or not boss.is_alive:
		return false
	if actor == boss:
		for carrier in carriers:
			if carrier.is_alive and grid.manhattan(carrier.grid_pos, boss.grid_pos) <= 2:
				boss.add_shield(12)
	elif actor in carriers and not altar_sealed:
		_advance_convoy(actor)
		changed.emit()
		return true
	return false


func _move_path(actor: Unit, path: Array) -> void:
	terrain.begin_unit_resolution(actor, &"movement")
	if grid.relocate_unit(actor, path[1]):
		actor.record_runtime_movement(1)
	terrain.end_unit_resolution(actor)


func dispose() -> void:
	if grid != null and grid.occupancy_changed.is_connected(_on_occupancy):
		grid.occupancy_changed.disconnect(_on_occupancy)
	for actor in carriers:
		if actor.died.is_connected(_on_carrier_died):
			actor.died.disconnect(_on_carrier_died)
	can_play = Callable()


func board_markers() -> Dictionary:
	if room_id == "convoy":
		return { LEVER: "L", ALTAR: "O" }
	if room_id == "garden":
		return { LEVER: "L", Vector2i(5, 1): "S", Vector2i(5, 5): "S" }
	return { LEVER: "L" }


func actor_initial(actor: Unit) -> String:
	return "A" if actor == hero else ("M" if actor == boss else "P")


func danger_cells() -> Array:
	var result: Array[Vector2i] = []
	if room_id == "convoy" or not is_mechanism_active():
		return result
	for y in 7:
		for x in 9:
			var cell := Vector2i(x, y)
			if not grid.is_terrain_interactable(cell):
				continue
			if (
				(room_id == "forge" and y == rail)
				or (room_id == "garden" and grid.manhattan(cell, boss.grid_pos) == radius)
			):
				result.append(cell)
	return result


func terminal_failure(action: String) -> String:
	if not _can_play():
		return "Ce n'est pas votre tour ou le combat est terminé."
	if action not in ["left", "right", "gate"]:
		return "Commande inconnue."
	if room_id == "convoy" and action != "gate":
		return "Seul le sceau est utilisable dans cette salle."
	if room_id == "garden" and action == "gate":
		return "Choisissez le socle haut ou bas."
	if not is_mechanism_active():
		return "Mécanisme désactivé."
	if mechanism_used or (room_id == "convoy" and altar_sealed):
		return "Mécanisme déjà actionné."
	if grid.manhattan(hero.grid_pos, LEVER) > 1:
		return "Rejoignez le levier L ou une case adjacente."
	if hero.current_ap < (2 if room_id == "convoy" else 1):
		return "PA insuffisants."
	if room_id == "garden":
		var target := Vector2i(5, 1 if action == "left" else 5)
		if not grid.is_walkable(target, boss) or target == boss.grid_pos:
			return "Le socle est occupé."
	return ""


func preview_terminal(action: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not terminal_failure(action).is_empty():
		return result
	if room_id == "forge":
		var row := 1 if action == "left" else (5 if action == "right" else 3)
		for x in 9:
			result.append(Vector2i(x, row))
	elif room_id == "garden":
		var origin := Vector2i(5, 1 if action == "left" else 5)
		for y in 7:
			for x in 9:
				var cell := Vector2i(x, y)
				if grid.is_terrain_interactable(cell) and grid.manhattan(cell, origin) == radius:
					result.append(cell)
	else:
		result.append(ALTAR)
	return result


func use_terminal(action: String) -> bool:
	if not terminal_failure(action).is_empty():
		return false
	if not hero.spend_ap(2 if room_id == "convoy" else 1):
		return false
	mechanism_used = true
	if room_id == "forge":
		rail = 1 if action == "left" else (5 if action == "right" else 3)
		log_message("La presse frappera le rail %d." % [rail])
	elif room_id == "garden":
		grid.relocate_unit(boss, Vector2i(5, 1 if action == "left" else 5))
		log_message("L'anneau suit immédiatement le nouveau socle.")
	else:
		altar_sealed = true
		log_message("Autel scellé : les porteurs ne peuvent plus alimenter %s." % [boss.unit_name])
	changed.emit()
	return true


func _resolve_environment() -> void:
	for cell: Vector2i in danger_cells():
		var actor := grid.get_unit(cell) as Unit
		if actor == null:
			continue
		var damage := (32 if actor == hero else 60) if room_id == "forge" else 28
		actor.take_damage(damage, null, Spell.DamageType.PHYSICAL)
		if actor != hero:
			environmental_hits += 1
		log_message("%s subit %d dégâts de salle avant défense." % [actor.unit_name, damage])


func _advance_convoy(carrier: Unit) -> void:
	if grid.manhattan(carrier.grid_pos, ALTAR) <= 1:
		deliveries += 1
		boss.heal(35)
		boss.attack_power.add_modifier(8, Stat.ModType.FLAT, "soul_delivery_%d" % [deliveries])
		carrier.died.disconnect(_on_carrier_died)
		carrier.clear_shield()
		carrier.take_damage(99999, null, Spell.DamageType.PHYSICAL)
		grid.remove_unit(carrier)
		log_message("Âme livrée : +35 PV au chef, +8 attaque permanente. Aucune âme à ramasser.")
		return
	var best: Array = []
	for offset in [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]:
		var goal: Vector2i = ALTAR + offset
		if not grid.is_walkable(goal, carrier):
			continue
		var path := pathfinder.find_path(carrier.grid_pos, goal, carrier)
		if path.size() > 1 and (best.is_empty() or path.size() < best.size()):
			best = path
	if best.size() > 1:
		var hop: Array = [carrier.grid_pos, best[1]]
		if carrier.spend_mp(pathfinder.path_movement_cost(hop, carrier)):
			_move_path(carrier, hop)


func _on_carrier_died(actor: Unit) -> void:
	if room_id == "convoy":
		coins[actor.grid_pos] = 1
		log_message("Une âme libérée attend sur la case du porteur : +12 garde au ramassage.")
	grid.remove_unit(actor)


func _on_occupancy(_reason: StringName, actor, _from: Vector2i, to: Vector2i) -> void:
	if actor == hero and hero.is_alive and coins.has(to):
		coins.erase(to)
		hero.add_shield(12)
		log_message("Âme recueillie : +12 garde.")


func intention_text() -> String:
	var title := "%s · %d/%d PV · %d garde\n" % [
		boss.unit_name,
		boss.current_hp,
		boss.max_hp.get_int(),
		boss.current_shield,
	]
	if not is_mechanism_active():
		return title + "CHEF VAINCU\nMécanisme désactivé. Éliminez les ennemis restants."
	if room_id == "forge":
		return title + "PRESSE À LA FIN DU TOUR\nRail %d · 32 dégâts héros / 60 ennemis.\nProchain rail : %d." % [
			rail,
			3 if rail == 1 else (5 if rail == 3 else 1),
		]
	if room_id == "garden":
		return title + "ANNEAU À LA FIN DU TOUR\nDistance exacte %d du boss · 28 dégâts, alliés compris.\nProchaine distance : %d." % [
			radius,
			3 if radius == 2 else (1 if radius == 3 else 2),
		]
	return title + "AUTEL %s · %d LIVRAISONS\nLes porteurs à 2 cases du chef lui donnent 12 garde chacun. Livraison en début d'activation adjacente à O : +35 PV et +8 attaque." % [
		"SCELLÉ" if altar_sealed else "ACTIF",
		deliveries,
	]
