extends RefCounted
## Encounter mechanics on the authored grid. Battle owns turns, commands and saves.
const Topology = preload("res://core/expedition/card_tactical_room_rules.gd")
const Effects = preload("res://core/expedition/consumable_card_effects.gd")
const Math = preload("res://core/expedition/consumable_card_math.gd")
const IDS := ["forge", "hourglass", "garden", "convoy", "reservoir"]
const TITLES := {
	"forge": "Presse",
	"hourglass": "Sablier",
	"garden": "Jardin",
	"convoy": "Convoi",
	"reservoir": "Réservoirs",
}
var grid: GridData
var terrain: TerrainEffects
var hero: Unit
var enemies: Array = []
var chief: Unit
var carriers: Array = []
var cards
var definition: Dictionary
var state: Dictionary = { }
var layout: Dictionary = { }
var room_id := ""


func configure(
	encounter: Dictionary,
	board: GridData,
	surfaces: TerrainEffects,
	player: Unit,
	actors: Array,
	deck,
) -> void:
	definition = encounter
	room_id = str(encounter.map) if str(encounter.map) in IDS else ""
	grid = board
	terrain = surfaces
	hero = player
	enemies = actors.duplicate()
	cards = deck
	if room_id.is_empty():
		return
	layout = make_layout(grid)
	var role: String = {
		"forge": "brute",
		"hourglass": "brute",
		"garden": "conducteur",
		"convoy": "collecteur",
		"reservoir": "fondeur",
	}[room_id]
	chief = enemies[0]
	for actor in enemies:
		if str(actor.tactical_role_id) == "catabase_evolution_" + role:
			chief = actor
			break
	if room_id == "convoy":
		for actor in enemies:
			if actor != chief and str(actor.tactical_role_id) == "catabase_evolution_porteur":
				carriers.append(actor)
		for actor in enemies:
			if carriers.size() >= 2:
				break
			if actor != chief and actor not in carriers:
				carriers.append(actor)
	var number: int = maxi(1, cards.round_index)
	state = {
		"version": 1,
		"id": room_id,
		"round": number,
		"rail": (number - 1) % layout.rails.size(),
		"used": false,
		"sealed": false,
		"delayed": false,
		"debt": false,
		"charges": [0, 0],
		"clock": [hero.grid_pos.x, hero.grid_pos.y],
		"chief": str(chief.unit_id),
		"carriers": carriers.map(
			func(u):
				return str(u.unit_id),
		),
		"deliveries": [],
	}


static func make_layout(board: GridData) -> Dictionary:
	# Keep the existing terrain. Controls use the largest connected floor component,
	# ignoring temporary occupancy, so reloading cannot move a lever or reservoir.
	var remaining := { }
	for y in board.rows:
		for x in board.cols:
			var cell := Vector2i(x, y)
			if board.is_terrain_interactable(cell):
				remaining[cell] = true
	var floor_cells: Array[Vector2i] = []
	while not remaining.is_empty():
		var component: Array[Vector2i] = [remaining.keys()[0]]
		remaining.erase(component[0])
		var cursor := 0
		while cursor < component.size():
			var origin: Vector2i = component[cursor]
			cursor += 1
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var cell: Vector2i = origin + direction
				if remaining.has(cell):
					remaining.erase(cell)
					component.append(cell)
		if component.size() > floor_cells.size():
			floor_cells = component
	if floor_cells.is_empty():
		return { }
	floor_cells.sort_custom(
		func(a, b):
			return a.x < b.x if a.y == b.y else a.y < b.y,
	)
	var low := floor_cells[0]
	var high := low
	var rows: Array[int] = []
	for cell in floor_cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
		if cell.y not in rows:
			rows.append(cell.y)
	var mid := Vector2i((low.x + high.x) / 2, (low.y + high.y) / 2)
	var points: Array[Vector2i] = []
	for target in [
		Vector2i(low.x + 1, mid.y),
		Vector2i(high.x, mid.y),
		Vector2i(mid.x, low.y),
		Vector2i(mid.x, high.y),
		Vector2i(high.x - 1, low.y + 1),
	]:
		var best := Vector2i(-1, -1)
		var distance := 100000
		for cell in floor_cells:
			if cell in points:
				continue
			var score: int = board.manhattan(cell, target)
			if score < distance:
				distance = score
				best = cell
		points.append(best)
	var rails: Array[int] = []
	for fraction in [.2, .5, .8]:
		var row: int = rows[roundi((rows.size() - 1) * fraction)]
		if row not in rails:
			rails.append(row)
	return {
		"lever": points[0],
		"reservoirs": [points[0], points[1]],
		"pedestals": [points[2], points[3]],
		"altar": points[4],
		"rails": rails,
	}


func power() -> float:
	return float(
		preload("res://core/expedition/consumable_card_catalog.gd")
		.data()
		.rules
		.prowess[int(definition.level) - 1]
	)


func active() -> bool:
	return (
		not room_id.is_empty() and hero.is_alive
		and enemies.any(
			func(u):
				return u.is_alive,
		)
		and (room_id != "convoy" or chief.is_alive)
	)


func current_target() -> Unit:
	# Garden and reservoirs follow the first living spawn, including after a kill.
	if room_id in ["garden", "reservoir"]:
		for enemy in enemies:
			if enemy.is_alive:
				return enemy
	return chief


func markers() -> Dictionary:
	if not active():
		return { }
	match room_id:
		"reservoir":
			return { layout.reservoirs[0]: "A", layout.reservoirs[1]: "B" }
		"convoy":
			return { layout.lever: "L", layout.altar: "O" }
		"garden":
			return { layout.lever: "L", layout.pedestals[0]: "S↑", layout.pedestals[1]: "S↓" }
	return { layout.lever: "L" }


func danger_cells() -> Array[Vector2i]:
	if not active():
		return []
	match room_id:
		"forge":
			return Topology.profile_danger_cells(
				"forge",
				grid,
				Vector2i.ZERO,
				layout.rails[int(state.rail)],
			)
		"garden":
			return Topology.profile_danger_cells(
				"garden",
				grid,
				current_target().grid_pos,
				[2, 3, 1][(int(state.round) - 1) % 3],
			)
		"hourglass":
			if state.delayed:
				return []
			return Topology.profile_danger_cells(
				"hourglass",
				grid,
				Vector2i(state.clock[0], state.clock[1]),
				2,
			)
	return []


func commands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match room_id:
		"forge":
			for index in layout.rails.size():
				result.append(
					{
						"id": "rail_%d" % index,
						"label": "Rail %d · 1 PA" % (int(layout.rails[index]) + 1),
						"cost": 1,
						"cell": layout.lever,
					}
				)
		"hourglass":
			result = [
				{ "id": "delay", "label": "Retarder · 1 PA", "cost": 1, "cell": layout.lever },
				{ "id": "center", "label": "Recentrer · 2 PA", "cost": 2, "cell": layout.lever },
			]
		"garden":
			result = [
				{
					"id": "pedestal_0",
					"label": "Socle haut · 1 PA",
					"cost": 1,
					"cell": layout.lever,
				},
				{ "id": "pedestal_1", "label": "Socle bas · 1 PA", "cost": 1, "cell": layout.lever },
			]
		"convoy":
			result = [
				{ "id": "seal", "label": "Sceller l'autel · 2 PA", "cost": 2, "cell": layout.lever }
			]
		"reservoir":
			result = [
				{
					"id": "discharge_0",
					"label": "Décharger A · 1 PA",
					"cost": 1,
					"cell": layout.reservoirs[0],
				},
				{
					"id": "discharge_1",
					"label": "Décharger B · 1 PA",
					"cost": 1,
					"cell": layout.reservoirs[1],
				},
			]
	return result


func failure(action: String) -> String:
	if not active():
		return "Mécanisme désactivé."
	if state.used:
		return "Une commande de salle par tour."
	var options := commands().filter(
		func(entry):
			return entry.id == action,
	)
	if options.is_empty():
		return "Commande inconnue."
	var entry: Dictionary = options[0]
	if grid.manhattan(hero.grid_pos, entry.cell) > 1:
		return "Rejoignez le mécanisme ou une case adjacente."
	if hero.current_ap < int(entry.cost):
		return "PA insuffisants."
	if action == "delay" and (state.delayed or state.debt):
		return "Cette croix a déjà été retardée."
	if action == "center" and not chief.is_alive:
		return "Chef vaincu."
	if action == "seal" and state.sealed:
		return "Autel déjà scellé."
	if action.begins_with("discharge_") and int(state.charges[int(action[-1])]) == 0:
		return "Réservoir vide : stockez des PA à proximité."
	if action.begins_with("pedestal_"):
		var destination: Vector2i = layout.pedestals[int(action[-1])]
		if (
			not grid.is_walkable(destination, current_target())
			or destination == current_target().grid_pos
		):
			return "Socle occupé."
	return ""


func use_command(action: String) -> bool:
	if not failure(action).is_empty():
		return false
	var entry: Dictionary = commands().filter(
		func(row):
			return row.id == action,
	)[0]
	if not hero.spend_ap(int(entry.cost)):
		return false
	state.used = true
	if action.begins_with("rail_"):
		state.rail = int(action[-1])
	elif action == "delay":
		state.delayed = true
	elif action == "center":
		state.clock = [chief.grid_pos.x, chief.grid_pos.y]
	elif action == "seal":
		state.sealed = true
	elif action.begins_with("pedestal_"):
		var target := current_target()
		var before := target.grid_pos
		grid.relocate_unit(target, layout.pedestals[int(action[-1])])
		EventBus.unit_pushed.emit(target, before, target.grid_pos, false)
	elif action.begins_with("discharge_"):
		var index := int(action[-1])
		var count: int = state.charges[index]
		state.charges[index] = 0
		Effects.hit(current_target(), hero, .5 * power() * count)
	return true


func end_hero() -> void:
	if not active() or room_id != "reservoir":
		return
	for index in 2:
		if grid.manhattan(hero.grid_pos, layout.reservoirs[index]) <= 1:
			var count: int = mini(hero.current_ap, 6 - int(state.charges[index]))
			if count > 0 and hero.spend_ap(count):
				state.charges[index] += count
			break


func begin_enemy(enemy: Unit) -> void:
	if not active() or room_id != "reservoir":
		return
	for index in 2:
		if (
			int(state.charges[index]) > 0
			and grid.manhattan(enemy.grid_pos, layout.reservoirs[index]) <= 1
		):
			state.charges[index] -= 1
			enemy.heal(Math.rounded(.3 * power()))


func is_courier(enemy: Unit) -> bool:
	return active() and room_id == "convoy" and not state.sealed and enemy in carriers


func deliver(enemy: Unit) -> bool:
	if not is_courier(enemy) or grid.manhattan(enemy.grid_pos, layout.altar) > 1:
		return false
	state.deliveries.append(str(enemy.unit_id))
	apply_delivery_bonus(true)
	# Content stays committed; its eligibility is forfeited before death/outcome.
	var key := str(definition.index)
	if cards.loot_commitments.has(key) and cards.loot_commitments[key].has(str(enemy.unit_id)):
		cards.loot_commitments[key][str(enemy.unit_id)]["forfeited"] = true
	enemy.set_meta("cc2_sacrificed", true)
	enemy.current_hp = 0
	enemy._die()
	return true


func apply_delivery_bonus(heal: bool) -> void:
	var bonus := Math.rounded(.8 * power())
	chief.max_hp.base_value += bonus
	chief.attack_power.base_value += Math.rounded(
		.02
		* float(
			preload("res://core/expedition/consumable_card_catalog.gd")
			.data()
			.rules
			.hp[int(definition.level) - 1]
		)
	)
	if heal:
		chief.current_hp += bonus
	chief.stats_changed.emit(chief)


func courier_path(enemy: Unit) -> Array:
	var pathfinder := Pathfinder.new(grid)
	var best: Array = []
	for direction in [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]:
		var cell: Vector2i = layout.altar + direction
		if not grid.is_walkable(cell, enemy):
			continue
		var path := pathfinder.find_path(enemy.grid_pos, cell, enemy)
		if path.size() > 1 and (best.is_empty() or path.size() < best.size()):
			best = path
	return best.slice(0, 2) if best.size() > 1 else []


func finish_round(number: int) -> void:
	if room_id.is_empty() or number <= int(state.round):
		return
	if active():
		var cells := danger_cells()
		if room_id == "hourglass" and state.delayed:
			state.delayed = false
			state.debt = true
		else:
			var coefficient := .7 * (1.5 if state.debt else 1.0) if room_id == "hourglass" else .6
			# Resolve the whole announced area even if the chief dies on its first cell.
			for unit in [hero] + enemies:
				if unit.is_alive and unit.grid_pos in cells:
					Effects.hit(
						unit,
						null,
						power() * (1.3 if room_id == "forge" and unit != hero else coefficient),
					)
			if room_id == "hourglass":
				state.clock = [hero.grid_pos.x, hero.grid_pos.y]
				state.debt = false
		if room_id == "forge":
			state.rail = (int(state.rail) + 1) % layout.rails.size()
	state.round = number
	state.used = false


func description() -> String:
	if room_id.is_empty():
		return ""
	if not active():
		return TITLES[room_id] + " · mécanisme désactivé"
	match room_id:
		"forge":
			return "Presse · rail %d après les ennemis · %d dégâts héros / %d ennemis avant défense" % [
				int(layout.rails[int(state.rail)]) + 1,
				Math.rounded(.6 * power()),
				Math.rounded(1.3 * power()),
			]
		"hourglass":
			return "Sablier · %s · %d dégâts avant défense" % [
				"sursis : pas d'explosion cette ronde" if state.delayed else "croix fixe après les ennemis",
				Math.rounded(.7 * power() * (1.5 if state.delayed or state.debt else 1.0)),
			]
		"garden":
			return "Jardin · anneau à %d cases de %s après les ennemis · %d dégâts avant défense" % [
				[2, 3, 1][(int(state.round) - 1) % 3],
				current_target().unit_name,
				Math.rounded(.6 * power()),
			]
		"convoy":
			return "Convoi · autel %s · %d sacrifice(s), leur butin est perdu" % [
				"scellé" if state.sealed else "actif",
				state.deliveries.size(),
			]
		"reservoir":
			return "Réservoirs · A %d/6 · B %d/6 · finissez près d'un réservoir pour stocker vos PA" % [
				state.charges[0],
				state.charges[1],
			]
	return ""


func help_text() -> String:
	return str(
		{
			"forge": "Une commande par tour au levier L ou à une case. La presse frappe après les ennemis, puis change de rail. Les zones rouges indiquent son prochain impact.",
			"hourglass": "Au levier L : retarder coûte 1 PA, une seule fois par croix, et multiplie le prochain impact par 1,5. Recentrer coûte 2 PA. Après explosion, la croix suit votre dernière position.",
			"garden": "L'anneau suit le premier ennemi vivant par ordre d'apparition : déplacez-le avec vos cartes, ou utilisez L pour le téléporter sur un socle libre (1 PA). Il traverse les obstacles.",
			"convoy": "Les deux porteurs avancent vers O au lieu d'attaquer. Une livraison donne +0,8 P PV maximum et actuels et +2 % des PV de référence en attaque au chef. Le porteur disparaît sans butin. Entrave et Stase s'appliquent avant sa marche. Sceller coûte 2 PA au levier L ; les porteurs reprennent leurs attaques.",
			"reservoir": "À distance 0 ou 1 de A/B, vos PA de fin de tour deviennent des charges, maximum 6. Décharge : 1 PA, toutes les charges, 0,5 P par charge au premier ennemi vivant. Un ennemi adjacent vole une charge et se soigne de 0,3 P au début de son activation.",
		}.get(room_id, "")
	)


func restore(saved: Dictionary) -> void:
	state = saved.duplicate(true)
	for _id in state.deliveries:
		apply_delivery_bonus(false)


static func valid(
	saved: Variant,
	id: String,
	board: GridData,
	records: Array,
	round_number: int,
) -> bool:
	if not saved is Dictionary:
		return false
	if id not in IDS:
		return saved.is_empty()
	if saved.get("version") != 1 or saved.get("id") != id or saved.get("round") != round_number:
		return false
	if saved.size() != 13:
		return false
	for key in ["used", "sealed", "delayed", "debt"]:
		if not saved.get(key) is bool:
			return false
	var geometry := make_layout(board)
	if geometry.is_empty() or not whole(saved.get("rail"), 0, geometry.rails.size() - 1):
		return false
	if not saved.get("charges") is Array or saved.charges.size() != 2:
		return false
	for count in saved.charges:
		if not whole(count, 0, 6):
			return false
	if not saved.get("clock") is Array or saved.clock.size() != 2:
		return false
	if not whole(saved.clock[0], 0, board.cols - 1) or not whole(saved.clock[1], 0, board.rows - 1):
		return false
	if not board.is_terrain_interactable(Vector2i(saved.clock[0], saved.clock[1])):
		return false
	var ids: Array = records.slice(1).map(
		func(entry):
			return entry.id,
	)
	if (
		saved.get("chief") not in ids or not saved.get("carriers") is Array
		or not saved.get("deliveries") is Array
	):
		return false
	if saved.carriers.size() != (mini(2, ids.size() - 1) if id == "convoy" else 0):
		return false
	var seen := { }
	for uid in saved.carriers:
		if uid not in ids or uid == saved.chief or seen.has(uid):
			return false
		seen[uid] = true
	seen.clear()
	for uid in saved.deliveries:
		if uid not in saved.carriers or seen.has(uid):
			return false
		seen[uid] = true
		for entry in records:
			if entry.id == uid and (entry.alive or not entry.metadata.get("cc2_sacrificed", false)):
				return false
	if id != "reservoir" and (saved.charges[0] != 0 or saved.charges[1] != 0):
		return false
	if id != "convoy" and (saved.sealed or not saved.deliveries.is_empty()):
		return false
	if id != "hourglass" and (saved.delayed or saved.debt):
		return false
	if saved.delayed and saved.debt:
		return false
	return true


static func whole(value: Variant, low: int, high: int) -> bool:
	return (
		(value is int or value is float) and is_finite(float(value))
		and value == floorf(value) and value >= low and value <= high
	)
