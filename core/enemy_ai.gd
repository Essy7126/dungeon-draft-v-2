class_name EnemyAI
extends RefCounted

var _grid: GridData
var _pathfinder: Pathfinder
var _spell_caster: SpellCaster

const CAT := DebugLogger.LogCategory.AI

const BEHAVIOR_MELEE := 0
const BEHAVIOR_RANGED := 1
const BEHAVIOR_HEALER := 2

const HEAL_THRESHOLD := 0.70
const TARGET_RANDOM_POOL := 3
const MIN_RANGED_DISTANCE := 3

func _init(grid: GridData, pathfinder: Pathfinder, spell_caster: SpellCaster) -> void:
	_grid = grid
	_pathfinder = pathfinder
	_spell_caster = spell_caster

func decide(enemy: Unit, all_units: Array) -> Array:
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

func default_attack_plan(enemy: Unit, all_units: Array) -> Array:
	return _decide_melee(enemy, all_units)

func find_target_cell_for_spell(enemy: Unit, spell: Spell) -> Vector2i:
	var targetable = _spell_caster.get_targetable_cells(enemy, spell)
	var forced = _get_forced_target(enemy)
	if forced != null and targetable.has(forced.grid_pos):
		return forced.grid_pos
	var candidates: Array = []
	for cell in targetable:
		var occ = _grid.get_unit(cell)
		if occ != null and occ.is_alive and occ.team != enemy.team:
			candidates.append({ "cell": cell, "score": _score_target(enemy, occ) })
	if candidates.is_empty():
		return Vector2i(-1, -1)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	return candidates[0]["cell"]

func find_nearest_hero(enemy: Unit, all_units: Array) -> Unit:
	return _choose_target(enemy, all_units)

func get_grid() -> GridData:
	return _grid

func get_pathfinder() -> Pathfinder:
	return _pathfinder

func get_spell_caster() -> SpellCaster:
	return _spell_caster

func _decide_ranged(enemy: Unit, all_units: Array) -> Array:
	var plan: Array = []
	var target = _choose_target(enemy, all_units)
	if target == null:
		return plan

	var spell_action = _try_offensive_spell(enemy, all_units)
	if not spell_action.is_empty():
		DebugLogger.info(CAT, "%s -> sort %s sur %s" % [enemy.unit_name, spell_action["spell"].spell_name, str(spell_action["cell"])])
		plan.append(spell_action)
		return plan

	var dist := _grid.manhattan(enemy.grid_pos, target.grid_pos)
	if dist < MIN_RANGED_DISTANCE:
		var flee_plan := _decide_flee(enemy, all_units)
		if not flee_plan.is_empty():
			return flee_plan

	var range := _best_offensive_range(enemy)
	var firing_cell := _find_best_ranged_cell(enemy, target, range)
	if firing_cell != Vector2i(-1, -1) and firing_cell != enemy.grid_pos:
		var path = _pathfinder.find_path(enemy.grid_pos, firing_cell, enemy)
		if path.size() >= 2:
			plan.append({ "type": "move", "path": path.slice(0, min(path.size(), enemy.current_mp + 1)) })
			return plan

	return _decide_melee(enemy, all_units)

func _decide_healer(enemy: Unit, all_units: Array) -> Array:
	var plan: Array = []
	var heal_spell = _find_heal_spell(enemy)

	if heal_spell == null or enemy.current_ap < heal_spell.ap_cost:
		DebugLogger.debug(CAT, "%s (soigneur) : pas de soin dispo -> attaque faible" % enemy.unit_name)
		return _decide_melee(enemy, all_units)

	var heal_target = _find_heal_target_in_range(enemy, heal_spell, all_units)
	if heal_target != Vector2i(-1, -1):
		DebugLogger.info(CAT, "%s (soigneur) -> soigne en %s" % [enemy.unit_name, str(heal_target)])
		plan.append({ "type": "cast", "spell": heal_spell, "cell": heal_target })
		return plan

	var wounded = _find_most_wounded_ally(enemy, all_units)
	if wounded != null:
		var approach = _find_approach_cell(enemy, wounded)
		if approach != Vector2i(-1, -1):
			var path = _pathfinder.find_path(enemy.grid_pos, approach, enemy)
			if path.size() > 1:
				var reachable = path.slice(0, min(path.size(), enemy.current_mp + 1))
				if reachable.size() >= 2:
					plan.append({ "type": "move", "path": reachable })
		return plan

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
		if not u.is_alive or u.team != enemy.team:
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

func _decide_flee(enemy: Unit, all_units: Array) -> Array:
	var plan: Array = []
	var threat = _choose_target(enemy, all_units)
	if threat == null:
		return plan
	var reachable = _pathfinder.get_reachable(enemy.grid_pos, enemy.current_mp, enemy)
	var best_cell = enemy.grid_pos
	var best_score := -999999.0
	for cell in reachable:
		var dist := _grid.manhattan(cell, threat.grid_pos)
		var path = _pathfinder.find_path(enemy.grid_pos, cell, enemy)
		var score := float(dist) - _path_danger_score(path) * 4.0
		if score > best_score:
			best_score = score
			best_cell = cell
	if best_cell != enemy.grid_pos:
		var path = _pathfinder.find_path(enemy.grid_pos, best_cell, enemy)
		if path.size() >= 2:
			DebugLogger.debug(CAT, "%s se replie vers %s" % [enemy.unit_name, str(best_cell)])
			plan.append({ "type": "move", "path": path })
	return plan

func _decide_melee(enemy: Unit, all_units: Array) -> Array:
	var plan: Array = []
	var target = _choose_target(enemy, all_units)
	if target == null:
		DebugLogger.trace(CAT, "%s : aucune cible" % enemy.unit_name)
		return plan

	var dist := _grid.manhattan(enemy.grid_pos, target.grid_pos)
	DebugLogger.debug(CAT, "%s vise %s (score, dist %d)" % [enemy.unit_name, target.unit_name, dist])

	var spell_action = _try_offensive_spell(enemy, all_units)
	if not spell_action.is_empty():
		DebugLogger.info(CAT, "%s -> sort %s sur %s" % [enemy.unit_name, spell_action["spell"].spell_name, str(spell_action["cell"])])
		plan.append(spell_action)
		if _grid.are_adjacent(enemy.grid_pos, target.grid_pos) and enemy.current_ap >= 1:
			plan.append({ "type": "attack", "target": target })
		return plan

	if _grid.are_adjacent(enemy.grid_pos, target.grid_pos):
		if enemy.current_ap >= 1:
			DebugLogger.info(CAT, "%s -> attaque %s" % [enemy.unit_name, target.unit_name])
			plan.append({ "type": "attack", "target": target })
		return plan

	var approach_cell = _find_approach_cell(enemy, target)
	if approach_cell != Vector2i(-1, -1):
		var path = _pathfinder.find_path(enemy.grid_pos, approach_cell, enemy)
		if path.size() > 1:
			var reachable_path = path.slice(0, min(path.size(), enemy.current_mp + 1))
			if reachable_path.size() >= 2:
				var final_pos = reachable_path[reachable_path.size() - 1]
				DebugLogger.info(CAT, "%s -> s'approche de %s (vers %s)" % [enemy.unit_name, target.unit_name, str(final_pos)])
				plan.append({ "type": "move", "path": reachable_path })
				if _grid.are_adjacent(final_pos, target.grid_pos) and enemy.current_ap >= 1:
					plan.append({ "type": "attack", "target": target })
	else:
		DebugLogger.trace(CAT, "%s : aucune case d'approche vers %s" % [enemy.unit_name, target.unit_name])
	return plan

func _try_offensive_spell(enemy: Unit, all_units: Array) -> Dictionary:
	var forced = _get_forced_target(enemy)
	var candidates: Array = []
	for spell in enemy.spells:
		if spell == null or not spell.deals_damage() or not spell.can_target_enemy:
			continue
		if enemy.current_ap < spell.ap_cost:
			continue
		var targetable = _spell_caster.get_targetable_cells(enemy, spell)
		for cell in targetable:
			var occupant = _grid.get_unit(cell)
			if occupant == null or not occupant.is_alive or occupant.team == enemy.team:
				continue
			if forced != null and occupant != forced:
				continue
			var score := _score_target(enemy, occupant) + float(spell.damage) * 1.4 + float(spell.spell_range)
			candidates.append({ "type": "cast", "spell": spell, "cell": cell, "score": score })
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	return _weighted_pick(candidates.slice(0, min(candidates.size(), TARGET_RANDOM_POOL)))

func _find_nearest_enemy(enemy: Unit, all_units: Array) -> Unit:
	return _choose_target(enemy, all_units)

func _choose_target(enemy: Unit, all_units: Array) -> Unit:
	var forced = _get_forced_target(enemy)
	if forced != null:
		return forced
	var scored: Array = []
	for u in all_units:
		if not u.is_alive or u.team == enemy.team:
			continue
		scored.append({ "target": u, "score": _score_target(enemy, u) })
	if scored.is_empty():
		return null
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	var picked := _weighted_pick(scored.slice(0, min(scored.size(), TARGET_RANDOM_POOL)))
	return picked.get("target", scored[0]["target"])

func _get_forced_target(enemy: Unit):
	if enemy.has_method("get_forced_target"):
		var forced = enemy.get_forced_target()
		if forced != null and forced.is_alive:
			return forced
	return null

func _score_target(enemy: Unit, target: Unit) -> float:
	var score := 0.0
	score += float(target.get_attack()) * 1.25
	score += (1.0 - target.get_hp_ratio()) * 38.0
	score += _fragility_score(target)
	var path = _path_to_target_edge(enemy, target)
	var distance_penalty := float(_grid.manhattan(enemy.grid_pos, target.grid_pos)) * 4.0
	if not path.is_empty():
		distance_penalty = float(maxi(0, path.size() - 1)) * 5.5 + _path_danger_score(path) * 16.0
	score -= distance_penalty
	return score

func _fragility_score(target: Unit) -> float:
	var max_hp := float(maxi(1, target.max_hp.get_int()))
	var low_hp_bonus := maxf(0.0, 110.0 - max_hp) * 0.16
	var armor_penalty := target.armure.get_value() * 0.18 + target.resist_magique.get_value() * 0.12
	var dodge_penalty := target.esquive.get_value() * 18.0
	return low_hp_bonus - armor_penalty - dodge_penalty

func _path_to_target_edge(enemy: Unit, target: Unit) -> Array:
	if _grid.are_adjacent(enemy.grid_pos, target.grid_pos):
		return [enemy.grid_pos, target.grid_pos]
	var approach := _find_approach_cell(enemy, target)
	if approach == Vector2i(-1, -1):
		return []
	return _pathfinder.find_path(enemy.grid_pos, approach, enemy)

func _weighted_pick(candidates: Array) -> Dictionary:
	if candidates.is_empty():
		return {}
	if candidates.size() == 1:
		return candidates[0]
	var lowest := float(candidates[candidates.size() - 1]["score"])
	var total := 0.0
	for c in candidates:
		total += maxf(1.0, float(c["score"]) - lowest + 1.0)
	var roll := randf() * total
	var cursor := 0.0
	for c in candidates:
		cursor += maxf(1.0, float(c["score"]) - lowest + 1.0)
		if roll <= cursor:
			return c
	return candidates[0]

func _find_approach_cell(enemy: Unit, target: Unit) -> Vector2i:
	var best_cell = Vector2i(-1, -1)
	var best_dist = 999999
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell = target.grid_pos + dir
		if not _grid.is_valid(cell) or not _grid.is_walkable(cell):
			continue
		var path = _pathfinder.find_path(enemy.grid_pos, cell, enemy)
		if path.size() < 2:
			continue
		var dist = path.size() + int(round(_path_danger_score(path) * 4.0))
		if dist < best_dist:
			best_dist = dist
			best_cell = cell
	return best_cell

func _best_offensive_range(enemy: Unit) -> int:
	var best := 1
	for spell in enemy.spells:
		if spell != null and spell.deals_damage() and spell.can_target_enemy:
			best = maxi(best, spell.spell_range)
	return best

func _find_best_ranged_cell(enemy: Unit, target: Unit, max_range: int) -> Vector2i:
	var reachable = _pathfinder.get_reachable(enemy.grid_pos, enemy.current_mp, enemy)
	var best_cell := Vector2i(-1, -1)
	var best_score := -999999.0
	var desired := maxi(MIN_RANGED_DISTANCE, mini(max_range, 5))
	for cell in reachable:
		var dist := _grid.manhattan(cell, target.grid_pos)
		if dist > max_range or dist < MIN_RANGED_DISTANCE:
			continue
		if max_range > 1 and not _pathfinder.has_line_of_sight(cell, target.grid_pos):
			continue
		var path = _pathfinder.find_path(enemy.grid_pos, cell, enemy)
		var score: float = 20.0 - abs(float(dist - desired)) * 3.0 - _path_danger_score(path) * 8.0
		if score > best_score:
			best_score = score
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
