# core/enemy_ai.gd
# ============================================================
# ENEMY AI — Décide les actions d'un ennemi à son tour.
# Logique pure : ne bouge rien, ne touche pas au visuel.
# Renvoie un PLAN que Battle exécutera et animera.
#
# Aiguillage : si l'unité a un boss_behavior, on lui délègue. Sinon,
# on applique le comportement standard selon ai_behavior (mêlée /
# distance / soigneur).
#
# Logs en catégorie AI (dev) : on suit le raisonnement des ennemis.
# ============================================================

class_name EnemyAI
extends RefCounted

var _grid: GridData
var _pathfinder: Pathfinder
var _spell_caster: SpellCaster

const CAT := DebugLogger.LogCategory.AI

func _init(grid: GridData, pathfinder: Pathfinder, spell_caster: SpellCaster) -> void:
	_grid = grid
	_pathfinder = pathfinder
	_spell_caster = spell_caster

# Constantes de comportement (doivent correspondre à l'enum de UnitData).
const BEHAVIOR_MELEE  := 0
const BEHAVIOR_RANGED := 1
const BEHAVIOR_HEALER := 2

# ============================================================
# DÉCISION — Aiguille vers le bon comportement.
# Priorité au boss_behavior s'il existe, sinon comportement standard.
# Chaque action du plan est un dictionnaire :
#   { "type": "move",   "path": [...] }
#   { "type": "attack", "target": Unit }
#   { "type": "cast",   "spell": Spell, "cell": Vector2i }
# ============================================================

func decide(enemy: Unit, all_units: Array) -> Array:
	# Un boss a son propre comportement, branché sans toucher ce fichier.
	if enemy.boss_behavior != null:
		return enemy.boss_behavior.decide(enemy, all_units, self)

	match enemy.ai_behavior:
		BEHAVIOR_MELEE:
			return _decide_melee(enemy, all_units)
		BEHAVIOR_RANGED:
			return _decide_ranged(enemy, all_units)
		BEHAVIOR_HEALER:
			return _decide_healer(enemy, all_units)
		_:
			return _decide_melee(enemy, all_units)

# ============================================================
# API PUBLIQUE POUR LES COMPORTEMENTS DE BOSS
# Les BossBehavior reçoivent l'EnemyAI et composent avec ces outils,
# pour réutiliser la logique existante au lieu de la dupliquer.
# ============================================================

# Le plan d'attaque standard (mêlée agressive). Un boss peut s'en servir
# comme comportement "par défaut" entre ses coups spéciaux.
func default_attack_plan(enemy: Unit, all_units: Array) -> Array:
	return _decide_melee(enemy, all_units)

# Première case ciblable d'un sort qui contient un héros (ou (-1,-1)).
func find_target_cell_for_spell(enemy: Unit, spell: Spell) -> Vector2i:
	var targetable = _spell_caster.get_targetable_cells(enemy, spell)
	for cell in targetable:
		var occ = _grid.get_unit(cell)
		if occ != null and occ.is_alive and occ.team != enemy.team:
			return cell
	return Vector2i(-1, -1)

# Le héros vivant le plus proche du boss (ou null).
func find_nearest_hero(enemy: Unit, all_units: Array) -> Unit:
	return _find_nearest_enemy(enemy, all_units)

# Accès aux briques logiques, pour les comportements avancés.
func get_grid() -> GridData:
	return _grid

func get_pathfinder() -> Pathfinder:
	return _pathfinder

func get_spell_caster() -> SpellCaster:
	return _spell_caster

# ============================================================
# COMPORTEMENT DISTANCE (stub : retombe sur la mêlée pour l'instant)
# ============================================================

func _decide_ranged(enemy: Unit, all_units: Array) -> Array:
	DebugLogger.trace(CAT, "%s : comportement distance (stub → mêlée)" % enemy.unit_name)
	return _decide_melee(enemy, all_units)

# ============================================================
# COMPORTEMENT HEALER
# Priorité : soigner l'allié le plus blessé (sous le seuil) à portée.
# Sinon : se rapprocher d'un allié blessé. Sinon : se replier.
# ============================================================

const HEAL_THRESHOLD := 0.70

func _decide_healer(enemy: Unit, all_units: Array) -> Array:
	var plan: Array = []
	var heal_spell = _find_heal_spell(enemy)

	if heal_spell == null or enemy.current_ap < heal_spell.ap_cost:
		DebugLogger.debug(CAT, "%s (soigneur) : pas de soin dispo -> attaque faible" % enemy.unit_name)
		return _decide_melee(enemy, all_units)

	var heal_target = _find_heal_target_in_range(enemy, heal_spell, all_units)
	if heal_target != Vector2i(-1, -1):
		DebugLogger.info(CAT, "%s (soigneur) → soigne en %s" % [enemy.unit_name, str(heal_target)])
		plan.append({ "type": "cast", "spell": heal_spell, "cell": heal_target })
		return plan

	var wounded = _find_most_wounded_ally(enemy, all_units)
	if wounded != null:
		DebugLogger.debug(CAT, "%s (soigneur) → se rapproche de %s (blessé)" % [
			enemy.unit_name, wounded.unit_name])
		var approach = _find_approach_cell(enemy, wounded)
		if approach != Vector2i(-1, -1):
			var path = _pathfinder.find_path(enemy.grid_pos, approach, enemy)
			var max_steps = enemy.current_mp
			if path.size() > 1:
				var reachable = path.slice(0, min(path.size(), max_steps + 1))
				if reachable.size() >= 2:
					plan.append({ "type": "move", "path": reachable })
		return plan

	DebugLogger.debug(CAT, "%s (soigneur) : personne a soigner -> attaque faible" % enemy.unit_name)
	return _decide_melee(enemy, all_units)

func _find_heal_spell(enemy: Unit) -> Spell:
	for spell in enemy.spells:
		if spell == null:
			continue
		if spell.is_healing() and (spell.can_target_ally or spell.can_target_self):
			return spell
	return null

func _find_most_wounded_ally(enemy: Unit, all_units: Array) -> Unit:
	var worst: Unit = null
	var worst_ratio := HEAL_THRESHOLD
	for u in all_units:
		if not u.is_alive:
			continue
		if u.team != enemy.team:
			continue
		var ratio = u.get_hp_ratio()
		if ratio < worst_ratio:
			worst_ratio = ratio
			worst = u
	return worst

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
		return plan
	var reachable = _pathfinder.get_reachable(enemy.grid_pos, enemy.current_mp, enemy)
	var best_cell = enemy.grid_pos
	var best_dist = _grid.manhattan(enemy.grid_pos, threat.grid_pos)
	for cell in reachable:
		var dist = _grid.manhattan(cell, threat.grid_pos)
		if dist > best_dist:
			best_dist = dist
			best_cell = cell
	if best_cell != enemy.grid_pos:
		var path = _pathfinder.find_path(enemy.grid_pos, best_cell, enemy)
		if path.size() >= 2:
			DebugLogger.debug(CAT, "%s se replie vers %s" % [enemy.unit_name, str(best_cell)])
			plan.append({ "type": "move", "path": path })
	return plan

# ============================================================
# COMPORTEMENT MÊLÉE (agressif standard)
# ============================================================

func _decide_melee(enemy: Unit, all_units: Array) -> Array:
	var plan: Array = []

	var target = _find_nearest_enemy(enemy, all_units)
	if target == null:
		DebugLogger.trace(CAT, "%s : aucune cible" % enemy.unit_name)
		return plan

	var dist = _grid.manhattan(enemy.grid_pos, target.grid_pos)
	DebugLogger.debug(CAT, "%s vise %s (dist %d)" % [enemy.unit_name, target.unit_name, dist])

	# Sort offensif prioritaire si une cible est à portée.
	var spell_action = _try_offensive_spell(enemy, all_units)
	if not spell_action.is_empty():
		DebugLogger.info(CAT, "%s → sort %s sur %s" % [
			enemy.unit_name, spell_action["spell"].spell_name, str(spell_action["cell"])])
		plan.append(spell_action)
		if _grid.are_adjacent(enemy.grid_pos, target.grid_pos) and enemy.current_ap >= 1:
			plan.append({ "type": "attack", "target": target })
		return plan

	# Déjà adjacent → attaque directe.
	if _grid.are_adjacent(enemy.grid_pos, target.grid_pos):
		if enemy.current_ap >= 1:
			DebugLogger.info(CAT, "%s → attaque %s (mêlée)" % [enemy.unit_name, target.unit_name])
			plan.append({ "type": "attack", "target": target })
		else:
			DebugLogger.trace(CAT, "%s adjacent mais 0 PA" % enemy.unit_name)
		return plan

	# Sinon, on s'approche.
	var approach_cell = _find_approach_cell(enemy, target)
	if approach_cell != Vector2i(-1, -1):
		var path = _pathfinder.find_path(enemy.grid_pos, approach_cell, enemy)
		var max_steps = enemy.current_mp
		if path.size() > 1:
			var reachable_path = path.slice(0, min(path.size(), max_steps + 1))
			if reachable_path.size() >= 2:
				var final_pos = reachable_path[reachable_path.size() - 1]
				DebugLogger.info(CAT, "%s → s'approche de %s (vers %s)" % [
					enemy.unit_name, target.unit_name, str(final_pos)])
				plan.append({ "type": "move", "path": reachable_path })
				if _grid.are_adjacent(final_pos, target.grid_pos) and enemy.current_ap >= 1:
					DebugLogger.info(CAT, "%s → puis attaque %s" % [enemy.unit_name, target.unit_name])
					plan.append({ "type": "attack", "target": target })
	else:
		DebugLogger.trace(CAT, "%s : aucune case d'approche vers %s" % [enemy.unit_name, target.unit_name])

	return plan

# ============================================================
# CHOIX D'UN SORT OFFENSIF
# ============================================================

func _try_offensive_spell(enemy: Unit, all_units: Array) -> Dictionary:
	for spell in enemy.spells:
		if spell == null:
			continue
		if not spell.deals_damage():
			continue
		if not spell.can_target_enemy:
			continue
		if enemy.current_ap < spell.ap_cost:
			continue
		var targetable = _spell_caster.get_targetable_cells(enemy, spell)
		for cell in targetable:
			var occupant = _grid.get_unit(cell)
			if occupant != null and occupant.is_alive and occupant.team != enemy.team:
				return { "type": "cast", "spell": spell, "cell": cell }
	return {}

# ============================================================
# OUTILS DE DÉCISION
# ============================================================

func _find_nearest_enemy(enemy: Unit, all_units: Array) -> Unit:
	if enemy.has_method("get_forced_target"):
		var forced = enemy.get_forced_target()
		if forced != null:
			return forced
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

func _find_approach_cell(enemy: Unit, target: Unit) -> Vector2i:
	var best_cell = Vector2i(-1, -1)
	var best_dist = 999999
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell = target.grid_pos + dir
		if not _grid.is_valid(cell):
			continue
		if not _grid.is_walkable(cell):
			continue
		var path = _pathfinder.find_path(enemy.grid_pos, cell, enemy)
		if path.size() < 2:
			continue
		var dist = path.size() + int(round(_path_danger_score(path) * 4.0))
		if dist < best_dist:
			best_dist = dist
			best_cell = cell
	return best_cell

func _path_danger_score(path: Array) -> float:
	var score := 0.0
	for cell in path:
		var stored = _grid.get_effect(cell)
		if stored == null:
			continue
		if stored.has("data") and stored["data"].has("data"):
			var effect: TerrainEffectData = stored["data"]["data"]
			if effect != null and effect.dangerous_for_ai:
				score += effect.ai_danger_weight
	return score
