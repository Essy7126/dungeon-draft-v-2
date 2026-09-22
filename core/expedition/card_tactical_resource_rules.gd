extends "res://core/expedition/card_tactical_room_rules.gd"
## Local mechanics only: ordinary spells, damage, AP and enemy AI remain shared.
const RESERVOIRS := [Vector2i(4, 1), Vector2i(4, 5)]
var charges: Array[int] = [0, 0]
var mark := Vector2i.ZERO
var blast_damage := 32
var postponed := false
var skip_blast := false


func bind(
	id: String,
	board: GridData,
	surfaces: TerrainEffects,
	actors: Array,
	input_allowed: Callable,
) -> void:
	super(id, board, surfaces, actors, input_allowed)
	mark = hero.grid_pos


func board_markers() -> Dictionary:
	if room_id == "reservoir":
		return { RESERVOIRS[0]: "H", RESERVOIRS[1]: "B" }
	return { LEVER: "L", mark: "C" }


func _cross(origin: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if grid.is_terrain_interactable(origin):
		cells.append(origin)
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		for distance in range(1, 3):
			var cell: Vector2i = origin + direction * distance
			if grid.get_type(cell) == GridData.CellType.WALL:
				break
			if grid.is_terrain_interactable(cell):
				cells.append(cell)
	return cells


func danger_cells() -> Array:
	if not outcome.is_empty() or not boss.is_alive or room_id != "hourglass" or skip_blast:
		return []
	return _cross(mark)


func terminal_failure(action: String) -> String:
	if not _can_play() or not boss.is_alive:
		return "Commande indisponible hors de votre tour ou après la mort du chef."
	if action not in ["left", "right"]:
		return "Choisissez une des deux commandes."
	if mechanism_used:
		return "Une commande par tour."
	var target: Vector2i = LEVER
	var cost := 1
	if room_id == "reservoir":
		var index := 0 if action == "left" else 1
		target = RESERVOIRS[index]
		if charges[index] == 0:
			return "Réservoir vide : terminez un tour à proximité avec des PA restants."
	else:
		cost = 1 if action == "left" else 2
		if action == "left" and postponed:
			return "Cette croix a déjà été retardée."
	if grid.manhattan(hero.grid_pos, target) > 1:
		return "Rejoignez le mécanisme choisi ou une case adjacente."
	if hero.current_ap < cost:
		return "PA insuffisants."
	return ""


func preview_terminal(action: String) -> Array[Vector2i]:
	if not terminal_failure(action).is_empty():
		return []
	if room_id == "reservoir":
		return [boss.grid_pos]
	return _cross(mark if action == "left" else boss.grid_pos)


func use_terminal(action: String) -> bool:
	if not terminal_failure(action).is_empty():
		return false
	var cost := 2 if room_id == "hourglass" and action == "right" else 1
	if not hero.spend_ap(cost):
		return false
	mechanism_used = true
	if room_id == "reservoir":
		var index := 0 if action == "left" else 1
		var damage := charges[index] * 22
		charges[index] = 0
		boss.take_damage(damage, null, Spell.DamageType.PHYSICAL)
		environmental_hits += 1
		log_message("Décharge : %d dégâts au chef avant défense." % [damage])
	elif action == "left":
		postponed = true
		skip_blast = true
		blast_damage = 48
		log_message("Sursis : aucune explosion cette fin de tour ; 48 dégâts à la suivante.")
	else:
		mark = boss.grid_pos
		log_message("Croix verrouillée sur la position actuelle du chef.")
	changed.emit()
	return true


func finish_hero_turn() -> void:
	if not outcome.is_empty() or not hero.is_alive or not boss.is_alive:
		return
	if room_id == "reservoir":
		for index in 2:
			if grid.manhattan(hero.grid_pos, RESERVOIRS[index]) > 1:
				continue
			var stored := mini(hero.current_ap, 6 - charges[index])
			if stored > 0 and hero.spend_ap(stored):
				charges[index] += stored
				log_message("%d PA stockés. Réserve : %d/6." % [stored, charges[index]])
	elif skip_blast:
		skip_blast = false
	else:
		# Snapshot before damage: killing the chief must not truncate a simultaneous blast.
		for cell: Vector2i in danger_cells():
			var actor := grid.get_unit(cell) as Unit
			if actor != null and actor.is_alive:
				actor.take_damage(blast_damage, null, Spell.DamageType.PHYSICAL)
				if actor != hero:
					environmental_hits += 1
		mark = hero.grid_pos
		blast_damage = 32
		postponed = false
	mechanism_used = false
	changed.emit()


func begin_enemy_turn(actor: Unit) -> bool:
	if room_id != "reservoir" or not boss.is_alive or not actor.is_alive:
		return false
	for index in 2:
		if charges[index] > 0 and grid.manhattan(actor.grid_pos, RESERVOIRS[index]) <= 1:
			charges[index] -= 1
			actor.heal(12)
			log_message("%s vole une charge : jusqu'à 12 PV récupérés." % [actor.unit_name])
	changed.emit()
	return false


func intention_text() -> String:
	if not boss.is_alive:
		return "CHEF VAINCU · Mécanismes désactivés. Éliminez les ennemis restants."
	if room_id == "reservoir":
		return "H : %d/6 → %d dégâts\nB : %d/6 → %d dégâts\nFinir près de H/B stocke vos PA.\nDécharger : 1 PA à proximité.\nEnnemi adjacent : vole 1 charge et se soigne de 12 PV à son activation." % [
			charges[0],
			charges[0] * 22,
			charges[1],
			charges[1] * 22,
		]
	return "CROIX FIXE · %d dégâts à tous\n%s\nAprès explosion, la suivante se verrouille sur votre position finale.\nRetard : 1 PA, une fois par croix.\nRecentrage sur le chef : 2 PA." % [
		blast_damage,
		"Explosion au tour suivant : sursis actif." if skip_blast else "Explosion à cette fin de tour !",
	]
