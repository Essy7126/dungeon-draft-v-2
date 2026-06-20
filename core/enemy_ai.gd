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
var _spell_caster: SpellCaster

func _init(grid: GridData, pathfinder: Pathfinder, spell_caster: SpellCaster) -> void:
	_grid = grid
	_pathfinder = pathfinder
	_spell_caster = spell_caster

# ============================================================
# DÉCISION
# Retourne un plan d'actions sous forme de liste ordonnée.
# Chaque action est un dictionnaire :
#   { "type": "move",   "path": [...] }       déplacement le long d'un chemin
#   { "type": "attack", "target": Unit }       attaque d'une cible
# Battle lit ce plan et l'exécute/anime dans l'ordre.
# ============================================================
# Constantes de comportement (doivent correspondre à l'enum de UnitData).
const BEHAVIOR_MELEE  := 0
const BEHAVIOR_RANGED := 1
const BEHAVIOR_HEALER := 2

# ============================================================
# DÉCISION — Aiguille vers le bon comportement selon ai_behavior.
# ============================================================

func decide(enemy: Unit, all_units: Array) -> Array:
	match enemy.ai_behavior:
		BEHAVIOR_MELEE:
			return _decide_melee(enemy, all_units)
		BEHAVIOR_RANGED:
			return _decide_ranged(enemy, all_units)
		BEHAVIOR_HEALER:
			return _decide_healer(enemy, all_units)
		_:
			return _decide_melee(enemy, all_units)

# --- Comportements à venir (Couches 3 et 4). Pour l'instant : mêlée. ---

func _decide_ranged(enemy: Unit, all_units: Array) -> Array:
	return _decide_melee(enemy, all_units)

# ============================================================
# COMPORTEMENT HEALER
# Priorité : soigner l'allié le plus blessé (sous le seuil) à portée.
# Sinon : se rapprocher d'un allié blessé pour le soigner au tour suivant.
# Sinon : se tenir à distance des héros (repli).
# ============================================================

# En dessous de ce ratio de PV, un allié est jugé "à soigner".
const HEAL_THRESHOLD := 0.70

func _decide_healer(enemy: Unit, all_units: Array) -> Array:
	var plan: Array = []

	# Cherche le sort de soin de l'unité (le premier trouvé).
	var heal_spell = _find_heal_spell(enemy)

	# Pas de sort de soin OU pas assez de PA : le healer se replie.
	if heal_spell == null or enemy.current_ap < heal_spell.ap_cost:
		return _decide_flee(enemy, all_units)

	# 1. Y a-t-il un allié blessé à portée du soin ? Si oui, on soigne.
	var heal_target = _find_heal_target_in_range(enemy, heal_spell, all_units)
	if heal_target != Vector2i(-1, -1):
		plan.append({
			"type": "cast",
			"spell": heal_spell,
			"cell": heal_target,
		})
		return plan

	# 2. Un allié blessé existe mais hors de portée : on s'en rapproche.
	var wounded = _find_most_wounded_ally(enemy, all_units)
	if wounded != null:
		var approach = _find_approach_cell(enemy, wounded)
		if approach != Vector2i(-1, -1):
			var path = _pathfinder.find_path(enemy.grid_pos, approach, enemy)
			var max_steps = enemy.current_mp
			if path.size() > 1:
				var reachable = path.slice(0, min(path.size(), max_steps + 1))
				if reachable.size() >= 2:
					plan.append({ "type": "move", "path": reachable })
		return plan

	# 3. Personne à soigner : on se tient à l'écart des héros.
	return _decide_flee(enemy, all_units)


# --- Trouve le sort de soin de l'unité (premier qui soigne un allié). ---
func _find_heal_spell(enemy: Unit) -> Spell:
	for spell in enemy.spells:
		if spell == null:
			continue
		if spell.is_healing() and (spell.can_target_ally or spell.can_target_self):
			return spell
	return null


# --- L'allié le plus blessé sous le seuil (ou null). Inclut le healer. ---
func _find_most_wounded_ally(enemy: Unit, all_units: Array) -> Unit:
	var worst: Unit = null
	var worst_ratio := HEAL_THRESHOLD

	for u in all_units:
		if not u.is_alive:
			continue
		if u.team != enemy.team:   # même équipe = allié
			continue
		var ratio = u.get_hp_ratio()
		if ratio < worst_ratio:
			worst_ratio = ratio
			worst = u

	return worst


# --- Cherche une case ciblable contenant un allié blessé. ---
func _find_heal_target_in_range(enemy: Unit, spell: Spell, all_units: Array) -> Vector2i:
	var wounded = _find_most_wounded_ally(enemy, all_units)
	if wounded == null:
		return Vector2i(-1, -1)

	var targetable = _spell_caster.get_targetable_cells(enemy, spell)
	if targetable.has(wounded.grid_pos):
		return wounded.grid_pos

	return Vector2i(-1, -1)


# --- Repli : s'éloigner du héros le plus proche. ---
func _decide_flee(enemy: Unit, all_units: Array) -> Array:
	var plan: Array = []
	var threat = _find_nearest_enemy(enemy, all_units)
	if threat == null:
		return plan   # aucun héros : on ne bouge pas

	# On cherche, parmi les cases atteignables, celle la plus loin du héros.
	var reachable = _pathfinder.get_reachable(enemy.grid_pos, enemy.current_mp, enemy)
	var best_cell = enemy.grid_pos
	var best_dist = _grid.manhattan(enemy.grid_pos, threat.grid_pos)

	for cell in reachable:
		var dist = _grid.manhattan(cell, threat.grid_pos)
		if dist > best_dist:
			best_dist = dist
			best_cell = cell

	# Si une meilleure case existe, on s'y déplace.
	if best_cell != enemy.grid_pos:
		var path = _pathfinder.find_path(enemy.grid_pos, best_cell, enemy)
		if path.size() >= 2:
			plan.append({ "type": "move", "path": path })

	return plan

func _decide_melee(enemy: Unit, all_units: Array) -> Array:
	var plan: Array = []

	# 1. Trouver la cible : le héros vivant le plus proche.
	var target = _find_nearest_enemy(enemy, all_units)
	if target == null:
		return plan   # aucun héros : rien à faire

	# 2. A-t-on un sort offensif utilisable sur une cible à portée ?
	#    Si oui, on le lance en priorité (avant la mêlée).
	var spell_action = _try_offensive_spell(enemy, all_units)
	if not spell_action.is_empty():
		plan.append(spell_action)
		# Si après le sort il reste des PA et qu'on est adjacent, on tape aussi.
		if _grid.are_adjacent(enemy.grid_pos, target.grid_pos) and enemy.current_ap >= 1:
			plan.append({ "type": "attack", "target": target })
		return plan

	# 3. Est-on déjà adjacent ? Si oui, on attaque direct.
	if _grid.are_adjacent(enemy.grid_pos, target.grid_pos):
		if enemy.current_ap >= 1:
			plan.append({ "type": "attack", "target": target })
		return plan

	# 4. Sinon, on s'approche.
	var approach_cell = _find_approach_cell(enemy, target)
	if approach_cell != Vector2i(-1, -1):
		var path = _pathfinder.find_path(enemy.grid_pos, approach_cell, enemy)
		var max_steps = enemy.current_mp
		if path.size() > 1:
			var reachable_path = path.slice(0, min(path.size(), max_steps + 1))
			if reachable_path.size() >= 2:
				plan.append({ "type": "move", "path": reachable_path })
				var final_pos = reachable_path[reachable_path.size() - 1]
				if _grid.are_adjacent(final_pos, target.grid_pos) and enemy.current_ap >= 1:
					plan.append({ "type": "attack", "target": target })

	return plan

# ============================================================
# CHOIX D'UN SORT OFFENSIF
# Parcourt les sorts de l'unité, garde le premier sort qui :
#   - fait des dégâts
#   - est abordable (assez de PA)
#   - a une cible ennemie valide à portée
# Retourne une action { "type": "cast", ... } ou un dict vide.
# ============================================================

func _try_offensive_spell(enemy: Unit, all_units: Array) -> Dictionary:
	for spell in enemy.spells:
		if spell == null:
			continue
		# On ne garde que les sorts qui blessent un ennemi.
		if not spell.deals_damage():
			continue
		if not spell.can_target_enemy:
			continue
		if enemy.current_ap < spell.ap_cost:
			continue

		# Cherche une case ciblable contenant un héros.
		var targetable = _spell_caster.get_targetable_cells(enemy, spell)
		for cell in targetable:
			var occupant = _grid.get_unit(cell)
			if occupant != null and occupant.is_alive and occupant.team != enemy.team:
				return {
					"type": "cast",
					"spell": spell,
					"cell": cell,
				}

	return {}
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
