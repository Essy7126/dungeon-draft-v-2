# core/enemy_ai.gd
# ============================================================
# ENEMY AI — Décide les actions d'un ennemi à son tour.
# Logique pure : ne bouge rien, ne touche pas au visuel.
# Renvoie un PLAN que Battle exécutera et animera.
#
# Comportement : agressif simple.
#   1. cible le héros le plus proche
#   2. s'approche jusqu'à être adjacent (selon ses PM)
#   3. attaque s'il est à portée de mêlée
# ============================================================

class_name EnemyAI
extends RefCounted

var _grid: GridData
var _pathfinder: Pathfinder

func _init(grid: GridData, pathfinder: Pathfinder) -> void:
	_grid = grid
	_pathfinder = pathfinder

# ============================================================
# DÉCISION
# Retourne un plan d'actions sous forme de liste ordonnée.
# Chaque action est un dictionnaire :
#   { "type": "move",   "path": [...] }       déplacement le long d'un chemin
#   { "type": "attack", "target": Unit }       attaque d'une cible
# Battle lit ce plan et l'exécute/anime dans l'ordre.
# ============================================================

func decide(enemy: Unit, all_units: Array) -> Array:
	var plan: Array = []

	# 1. Trouver la cible : le héros vivant le plus proche.
	var target = _find_nearest_enemy(enemy, all_units)
	if target == null:
		return plan   # aucun héros : rien à faire

	# 2. Est-on déjà adjacent ? Si oui, on attaque direct.
	if _grid.are_adjacent(enemy.grid_pos, target.grid_pos):
		if enemy.current_ap >= 1:
			plan.append({ "type": "attack", "target": target })
		return plan

	# 3. Sinon, on s'approche. On cherche la case adjacente à la cible
	#    la plus proche de nous, accessible avec nos PM.
	var approach_cell = _find_approach_cell(enemy, target)
	if approach_cell != Vector2i(-1, -1):
		var path = _pathfinder.find_path(enemy.grid_pos, approach_cell, enemy)
		# On tronque le chemin selon les PM disponibles.
		var max_steps = enemy.current_mp
		if path.size() > 1:
			var reachable_path = path.slice(0, min(path.size(), max_steps + 1))
			if reachable_path.size() >= 2:
				plan.append({ "type": "move", "path": reachable_path })
				# Après déplacement, sera-t-on adjacent ? Si oui, on attaque.
				var final_pos = reachable_path[reachable_path.size() - 1]
				if _grid.are_adjacent(final_pos, target.grid_pos) and enemy.current_ap >= 1:
					plan.append({ "type": "attack", "target": target })

	return plan

# ============================================================
# OUTILS DE DÉCISION
# ============================================================

# Trouve l'unité ennemie (équipe différente) vivante la plus proche.
func _find_nearest_enemy(enemy: Unit, all_units: Array) -> Unit:
	var nearest: Unit = null
	var best_dist = 999999

	for u in all_units:
		if not u.is_alive:
			continue
		if u.team == enemy.team:
			continue
		var dist = _grid.manhattan(enemy.grid_pos, u.grid_pos)
		if dist < best_dist:
			best_dist = dist
			nearest = u

	return nearest

# Trouve la meilleure case adjacente à la cible pour l'attaquer.
# On veut une case libre, accessible, et la plus proche de l'ennemi.
func _find_approach_cell(enemy: Unit, target: Unit) -> Vector2i:
	var best_cell = Vector2i(-1, -1)
	var best_dist = 999999

	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell = target.grid_pos + dir
		if not _grid.is_valid(cell):
			continue
		# La case doit être marchable (libre + bon type).
		if not _grid.is_walkable(cell):
			continue
		# On vérifie qu'un chemin existe vers cette case.
		var path = _pathfinder.find_path(enemy.grid_pos, cell, enemy)
		if path.size() < 2:
			continue
		# On garde la case adjacente la plus proche (chemin le plus court).
		var dist = path.size()
		if dist < best_dist:
			best_dist = dist
			best_cell = cell

	return best_cell
