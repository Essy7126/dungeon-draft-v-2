class_name EnemyAI
extends RefCounted

const LogDefinitions = preload("res://debug/log_definitions.gd")
const SupportMageDecision = preload("res://core/ai/support_mage_decision.gd")

var _grid: GridData
var _pathfinder: Pathfinder
var _spell_caster: SpellCaster
var _decision_mover: Unit = null
var _decision_origin := Vector2i(-1, -1)
var _decision_movement_map := {}
var _decision_target_cost_fields := {}

const CAT: LogDefinitions.LogCategory = LogDefinitions.LogCategory.AI

const BEHAVIOR_MELEE := 0
const BEHAVIOR_RANGED := 1
const BEHAVIOR_HEALER := 2

const HEAL_THRESHOLD := 0.70
const TARGET_RANDOM_POOL := 3
func _init(grid: GridData, pathfinder: Pathfinder, spell_caster: SpellCaster) -> void:
	_grid = grid
	_pathfinder = pathfinder
	_spell_caster = spell_caster

func decide(enemy: Unit, all_units: Array) -> Array:
	_begin_decision(enemy)
	var result := _decide_with_prepared_paths(enemy, all_units)
	_end_decision()
	return result


func _decide_with_prepared_paths(enemy: Unit, all_units: Array) -> Array:
	if enemy.ai_profile != null:
		match enemy.ai_profile.strategy:
			EnemyAIProfile.Strategy.SUPPORT_MAGE:
				return SupportMageDecision.decide(self, enemy, all_units)
			EnemyAIProfile.Strategy.FORMATION_MELEE:
				return _decide_formation_melee(enemy, all_units)
			EnemyAIProfile.Strategy.GUARDIAN_CHIEF:
				return _decide_guardian_chief(enemy, all_units)
			EnemyAIProfile.Strategy.RANGED_COMMANDER:
				return _decide_ranged_commander(enemy, all_units)
	match enemy.ai_behavior:
		BEHAVIOR_MELEE:
			return _decide_melee(enemy, all_units)
		BEHAVIOR_RANGED:
			return _decide_ranged(enemy, all_units)
		BEHAVIOR_HEALER:
			return _decide_healer(enemy, all_units)
		_:
			return _decide_melee(enemy, all_units)


func build_action_plan(enemy: Unit, all_units: Array) -> EnemyActionPlan:
	var result := EnemyActionPlan.new()
	for action_value in decide(enemy, all_units):
		var action := action_value as Dictionary
		result.append_action(action)
		if result.target_unit == null:
			result.target_unit = action.get("target") as Unit
	return result

func default_attack_plan(enemy: Unit, all_units: Array) -> Array:
	_begin_decision(enemy)
	var result := _decide_melee(enemy, all_units)
	_end_decision()
	return result

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


func _begin_decision(enemy: Unit) -> void:
	_decision_mover = enemy
	_decision_origin = enemy.grid_pos
	_decision_movement_map.clear()
	_decision_target_cost_fields.clear()
	_pathfinder.sync(enemy)


func _end_decision() -> void:
	_decision_mover = null
	_decision_origin = Vector2i(-1, -1)
	_decision_movement_map.clear()
	_decision_target_cost_fields.clear()


func _can_reuse_decision_paths(from: Vector2i, mover: Unit) -> bool:
	if not _uses_prepared_grid(mover) or from != _decision_origin:
		return false
	if _decision_movement_map.is_empty():
		_decision_movement_map = _pathfinder.build_movement_map(
			_decision_origin,
			-1,
			mover,
			Pathfinder.MovementType.VOLUNTARY,
			false,
		)
	return not _decision_movement_map.is_empty()


func _uses_prepared_grid(mover: Unit) -> bool:
	return _decision_mover != null and mover == _decision_mover


func _find_path(from: Vector2i, to: Vector2i, mover: Unit) -> Array:
	if _can_reuse_decision_paths(from, mover):
		return _pathfinder.path_from_movement_map(
			from,
			to,
			_decision_movement_map,
		)
	return _pathfinder.find_path(
		from,
		to,
		mover,
		not _uses_prepared_grid(mover),
	)


func _get_reachable(from: Vector2i, max_cost: int, mover: Unit) -> Array:
	if _can_reuse_decision_paths(from, mover):
		return _pathfinder.get_reachable_from_movement_map(
			from,
			_decision_movement_map,
			max_cost,
		)
	return _pathfinder.get_reachable(
		from,
		max_cost,
		mover,
		Pathfinder.MovementType.VOLUNTARY,
		not _uses_prepared_grid(mover),
	)


func _target_edge_cost_field(target: Unit, mover: Unit) -> Dictionary:
	if target == null or mover == null:
		return {}
	var cache_key := target.get_instance_id()
	if _uses_prepared_grid(mover) and _decision_target_cost_fields.has(cache_key):
		return _decision_target_cost_fields[cache_key] as Dictionary
	var edges: Array[Vector2i] = []
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var edge: Vector2i = target.grid_pos + direction
		if _grid.is_walkable(edge, mover):
			edges.append(edge)
	var field := _pathfinder.build_cost_field_to(
		edges,
		mover,
		Pathfinder.MovementType.VOLUNTARY,
		not _uses_prepared_grid(mover),
	)
	if _uses_prepared_grid(mover):
		_decision_target_cost_fields[cache_key] = field
	return field

func _decide_ranged(enemy: Unit, all_units: Array) -> Array:
	var plan: Array = []
	var target = _choose_target(enemy, all_units)
	if target == null:
		return plan

	var dist := _grid.manhattan(enemy.grid_pos, target.grid_pos)
	if enemy.keep_distance and dist < enemy.minimum_range:
		var flee_plan := _decide_flee(enemy, all_units)
		if not flee_plan.is_empty():
			return flee_plan

	var spell_action = _try_offensive_spell(enemy, all_units)
	if not spell_action.is_empty():
		DebugLogger.info(CAT, "%s -> sort %s sur %s" % [enemy.unit_name, spell_action["spell"].spell_name, str(spell_action["cell"])])
		plan.append(spell_action)
		return plan

	var range := _best_offensive_range(enemy)
	var firing_cell := _find_best_ranged_cell(enemy, target, range)
	if firing_cell != Vector2i(-1, -1) and firing_cell != enemy.grid_pos:
		var path = _find_path(enemy.grid_pos, firing_cell, enemy)
		if path.size() >= 2:
			var reachable_path := _pathfinder.trim_path_to_cost(
				path, enemy.current_mp, enemy
			)
			if reachable_path.size() >= 2:
				plan.append({ "type": "move", "path": reachable_path })
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
			var path = _find_path(enemy.grid_pos, approach, enemy)
			if path.size() > 1:
				var reachable = _pathfinder.trim_path_to_cost(
					path, enemy.current_mp, enemy
				)
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
	var reachable = _get_reachable(enemy.grid_pos, enemy.current_mp, enemy)
	var best_cell = enemy.grid_pos
	var best_score := -999999.0
	for cell in reachable:
		var dist := _grid.manhattan(cell, threat.grid_pos)
		var path = _find_path(enemy.grid_pos, cell, enemy)
		var score := float(dist) - _path_danger_score(path) * 4.0
		if score > best_score:
			best_score = score
			best_cell = cell
	if best_cell != enemy.grid_pos:
		var path = _find_path(enemy.grid_pos, best_cell, enemy)
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
		if _grid.are_adjacent(enemy.grid_pos, target.grid_pos) and enemy.can_use_basic_attack():
			plan.append({ "type": "attack", "target": target })
		return plan

	if _grid.are_adjacent(enemy.grid_pos, target.grid_pos):
		if enemy.can_use_basic_attack():
			DebugLogger.info(CAT, "%s -> attaque %s" % [enemy.unit_name, target.unit_name])
			plan.append({ "type": "attack", "target": target })
		return plan

	var approach_cell = _find_approach_cell(enemy, target)
	if approach_cell != Vector2i(-1, -1):
		var path = _find_path(enemy.grid_pos, approach_cell, enemy)
		if path.size() > 1:
			var reachable_path = _pathfinder.trim_path_to_cost(
				path, enemy.current_mp, enemy
			)
			if reachable_path.size() >= 2:
				var final_pos = reachable_path[reachable_path.size() - 1]
				DebugLogger.info(CAT, "%s -> s'approche de %s (vers %s)" % [enemy.unit_name, target.unit_name, str(final_pos)])
				plan.append({ "type": "move", "path": reachable_path })
				if _grid.are_adjacent(final_pos, target.grid_pos) and enemy.can_use_basic_attack():
					plan.append({ "type": "attack", "target": target })
				elif not enemy.basic_attack_enabled:
					# Spell-only melee units need their strike in the same plan as
					# the approach. Project the destination without moving the unit;
					# EnemyTurnRunner revalidates the cast after the real movement.
					for spell_value in _direct_damage_spells(enemy):
						var approach_spell := spell_value as Spell
						if _can_cast_from(enemy, approach_spell, final_pos, target):
							plan.append({
								"type": "cast", "spell": approach_spell,
								"cell": target.grid_pos,
							})
							break
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
		distance_penalty = float(
			_pathfinder.path_movement_cost(path, enemy)
		) * 5.5 + _path_danger_score(path) * 16.0
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
	return _find_path(enemy.grid_pos, approach, enemy)

func _weighted_pick(candidates: Array) -> Dictionary:
	if candidates.is_empty():
		return {}
	# L'IA tactique doit etre reproductible : les candidats sont deja tries par
	# score, et leurs helpers appliquent un departage stable.
	return candidates[0]

func _find_approach_cell(enemy: Unit, target: Unit) -> Vector2i:
	var best_cell = Vector2i(-1, -1)
	var best_dist = 999999
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell = target.grid_pos + dir
		if not _grid.is_valid(cell) or not _grid.is_walkable(cell):
			continue
		var path = _find_path(enemy.grid_pos, cell, enemy)
		if path.size() < 2:
			continue
		var dist = _pathfinder.path_movement_cost(path, enemy) \
			+ int(round(_path_danger_score(path) * 4.0))
		if dist < best_dist:
			best_dist = dist
			best_cell = cell
	return best_cell

func _best_offensive_range(enemy: Unit) -> int:
	var best := 1
	for spell in enemy.spells:
		if spell != null and spell.deals_damage() and spell.can_target_enemy:
			best = maxi(best, spell.spell_range)
	if enemy.maximum_range > 1:
		best = mini(best, enemy.maximum_range)
	return best

func _find_best_ranged_cell(enemy: Unit, target: Unit, max_range: int) -> Vector2i:
	var reachable = _get_reachable(enemy.grid_pos, enemy.current_mp, enemy)
	var best_cell := Vector2i(-1, -1)
	var best_score := -999999.0
	var minimum := clampi(enemy.minimum_range, 1, max_range)
	var desired := clampi(enemy.preferred_range, minimum, max_range)
	for cell in reachable:
		var dist := _grid.manhattan(cell, target.grid_pos)
		if dist > max_range or dist < minimum:
			continue
		if max_range > 1 and not _pathfinder.has_line_of_sight(cell, target.grid_pos):
			continue
		var path = _find_path(enemy.grid_pos, cell, enemy)
		var score: float = 20.0 - abs(float(dist - desired)) * 3.0 - _path_danger_score(path) * 8.0
		if score > best_score:
			best_score = score
			best_cell = cell
	return best_cell

func _path_danger_score(path: Array) -> float:
	var score := 0.0
	var mover := _grid.get_unit(path[0]) as Unit if not path.is_empty() else null
	var target_cell := Vector2i(-1, -1)
	if mover != null:
		var best_distance := INF
		for other_value in _grid.get_units():
			var other := other_value as Unit
			if other == null or not other.is_alive or other.team == mover.team:
				continue
			var distance := mover.grid_pos.distance_to(other.grid_pos)
			if distance < best_distance:
				best_distance = distance
				target_cell = other.grid_pos
	for cell in path:
		var network_cells := _grid.get_vortex_network_cells(cell)
		if network_cells.size() >= 3 and target_cell != Vector2i(-1, -1):
			var report := ArenaVortexNetworkService.evaluate_for_ai(
				_grid, cell, target_cell, mover
			)
			if not bool(report.get("can_use", false)):
				score += 1000.0
			else:
				score += maxf(0.0, -float(report.get("average_utility", 0.0)))
		var stored = _grid.get_effect(cell)
		if stored == null:
			continue
		if stored.has("data") and stored["data"].has("data"):
			var effect: TerrainEffectData = stored["data"]["data"]
			if effect != null and effect.dangerous_for_ai:
				score += effect.ai_danger_weight
	return score


func _stable_units(units: Array) -> Array:
	var result := units.duplicate()
	result.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.get_runtime_stable_id() < b.get_runtime_stable_id()
	)
	return result


func _living_opponents(enemy: Unit, all_units: Array) -> Array:
	return _stable_units(all_units.filter(func(value):
		var unit := value as Unit
		return unit != null and unit.is_alive and unit.team != enemy.team
	))


func _living_allies_with_role(enemy: Unit, all_units: Array, role_id: StringName) -> Array:
	return _stable_units(all_units.filter(func(value):
		var unit := value as Unit
		return unit != null \
			and unit.is_alive \
			and unit.team == enemy.team \
			and unit.tactical_role_id == role_id
	))


func _direct_damage_spells(enemy: Unit) -> Array:
	return enemy.spells.filter(func(value):
		var spell := value as Spell
		return spell != null \
			and spell.delayed_resolution == Spell.DelayedResolution.NONE \
			and spell.deals_damage() \
			and spell.can_target_enemy
	)


func _delayed_strike_spell(enemy: Unit) -> Spell:
	for value in enemy.spells:
		var spell := value as Spell
		if spell != null \
				and spell.delayed_resolution == Spell.DelayedResolution.STRIKE_AND_PUSH:
			return spell
	return null


func _summon_spell(enemy: Unit, summon_type: StringName) -> Spell:
	for value in enemy.spells:
		var spell := value as Spell
		if spell != null and spell.is_summon() and spell.summon_type == summon_type:
			return spell
	return null


func _mark_spell(enemy: Unit) -> Spell:
	var mark_id := enemy.ai_profile.marked_status_id
	for value in enemy.spells:
		var spell := value as Spell
		if spell != null and spell.applied_status != null \
				and spell.applied_status.get_effective_status_id() == mark_id:
			return spell
	return null


func _magic_armor_spell(enemy: Unit) -> Spell:
	for value in enemy.spells:
		var spell := value as Spell
		if spell != null and spell.applied_status != null \
				and spell.applied_status.stat_modifiers.has(&"resist_magique"):
			return spell
	return null


func _marked_target(enemy: Unit, all_units: Array, _source: Unit = null) -> Unit:
	if enemy == null or enemy.ai_profile == null:
		return null
	for value in _living_opponents(enemy, all_units):
		var target := value as Unit
		for entry_value in target.get_active_statuses():
			var entry := entry_value as Dictionary
			var status := entry.get("data") as StatusData
			var source := entry.get("source") as Unit
			if status == null \
					or status.get_effective_status_id() != enemy.ai_profile.marked_status_id \
					or source == null or not source.is_alive \
					or source.team != enemy.team:
				continue
			if enemy.faction_id != &"" and source.faction_id != enemy.faction_id:
				continue
			if source.tactical_role_id == enemy.ai_profile.commander_role_id:
				return target
	return null


func _is_designated_mark_caster(enemy: Unit, mark: Spell, all_units: Array) -> bool:
	if enemy == null or mark == null or enemy.ai_profile == null:
		return false
	var candidates: Array = []
	for value in all_units:
		var candidate := value as Unit
		if candidate == null or not candidate.is_alive \
				or candidate.team != enemy.team \
				or candidate.tactical_role_id != enemy.ai_profile.commander_role_id:
			continue
		var candidate_mark := _mark_spell(candidate)
		if candidate_mark != null and candidate.can_use_spell(candidate_mark):
			candidates.append(candidate)
	candidates.sort_custom(func(a: Unit, b: Unit) -> bool:
		if a.get_initiative() != b.get_initiative():
			return a.get_initiative() > b.get_initiative()
		return a.get_runtime_stable_id() < b.get_runtime_stable_id()
	)
	return not candidates.is_empty() and candidates[0] == enemy


func _can_cast_from(
		enemy: Unit,
		spell: Spell,
		origin: Vector2i,
		target: Unit
	) -> bool:
	if enemy == null or spell == null or target == null or not target.is_alive \
			or target.team == enemy.team or not enemy.can_use_spell(spell):
		return false
	var distance := _grid.manhattan(origin, target.grid_pos)
	if distance < spell.minimum_range \
			or distance > _spell_caster.get_effective_spell_range(enemy, spell):
		return false
	if spell.line_from_caster:
		var delta := target.grid_pos - origin
		if delta == Vector2i.ZERO or (delta.x != 0 and delta.y != 0):
			return false
	if spell.needs_line_of_sight \
			and not _pathfinder.has_line_of_sight(origin, target.grid_pos):
		return false
	return true


func _move_then_cast(
		enemy: Unit,
		target: Unit,
		spell: Spell,
		all_units: Array,
		prefer_neighbors := false,
		protect_commander := false
	) -> Array:
	if enemy == null or target == null or spell == null:
		return []
	if _can_cast_from(enemy, spell, enemy.grid_pos, target) \
			and _spell_caster.can_cast(enemy, spell, target.grid_pos):
		return [{"type": "cast", "spell": spell, "cell": target.grid_pos}]
	if enemy.current_mp <= 0:
		return []
	var cells := _get_reachable(enemy.grid_pos, enemy.current_mp, enemy)
	var scored: Array = []
	for cell_value in cells:
		var cell := cell_value as Vector2i
		if not _can_cast_from(enemy, spell, cell, target):
			continue
		var path := _find_path(enemy.grid_pos, cell, enemy)
		var movement_cost := _pathfinder.path_movement_cost(path, enemy)
		if path.size() < 2 or movement_cost > enemy.current_mp:
			continue
		scored.append({
			"cell": cell,
			"path": path,
			"cost": movement_cost,
			"neighbors": _living_neighbor_count(cell, enemy) if prefer_neighbors else 0,
			"protection": _commander_protection_score(cell, enemy, all_units) \
				if protect_commander else 0,
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.cost) != int(b.cost):
			return int(a.cost) < int(b.cost)
		if int(a.neighbors) != int(b.neighbors):
			return int(a.neighbors) > int(b.neighbors)
		if int(a.protection) != int(b.protection):
			return int(a.protection) > int(b.protection)
		var ca: Vector2i = a.cell
		var cb: Vector2i = b.cell
		return ca.y < cb.y or (ca.y == cb.y and ca.x < cb.x)
	)
	if scored.is_empty():
		return []
	return [
		{"type": "move", "path": scored[0].path},
		{"type": "cast", "spell": spell, "cell": target.grid_pos},
	]


func _with_commander_reposition(
		enemy: Unit,
		actions: Array,
		all_units: Array
	) -> Array:
	if actions.is_empty():
		return actions
	var reposition := _commander_reposition(enemy, all_units)
	if not reposition.is_empty():
		actions.append(reposition[0])
	return actions


func _adjacent_opponents(enemy: Unit, all_units: Array) -> Array:
	return _living_opponents(enemy, all_units).filter(func(value):
		return _grid.are_adjacent(enemy.grid_pos, (value as Unit).grid_pos)
	)


func _expected_spell_damage(enemy: Unit, spell: Spell, target: Unit) -> int:
	var raw := spell.damage
	var has_bonus := target.has_status(spell.bonus_damage_status_id)
	if spell.bonus_requires_linked_status_source:
		has_bonus = enemy.target_has_linked_source_status(
			target,
			spell.bonus_damage_status_id
		)
	if has_bonus:
		raw += spell.bonus_damage_if_marked
	var context := DamageResolver.HitContext.new()
	context.attacker = enemy
	context.raw_damage = raw
	context.category = spell.damage_type
	context.element = spell.element
	context.cannot_be_dodged = true
	return DamageResolver.compute(target, context).amount


func _cast_action(enemy: Unit, spell: Spell, target_cell: Vector2i) -> Dictionary:
	if spell != null and _spell_caster.can_cast(enemy, spell, target_cell):
		return {"type": "cast", "spell": spell, "cell": target_cell}
	return {}


func _living_neighbor_count(cell: Vector2i, moving_unit: Unit) -> int:
	var count := 0
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var occupant := _grid.get_unit(cell + direction) as Unit
		if occupant != null and occupant != moving_unit and occupant.is_alive:
			count += 1
	return count


func _path_distance_to_target_edge(cell: Vector2i, target: Unit, mover: Unit) -> int:
	if _grid.are_adjacent(cell, target.grid_pos):
		return 0
	var cost_field := _target_edge_cost_field(target, mover)
	if _grid.vortex_links().is_empty():
		return int(cost_field.get(cell, 999999))
	# Le champ inverse ne represente pas encore les aretes dirigees des vortex.
	# Ces salles conservent le calcul de reference, mais profitent tout de meme
	# de la file de priorite optimisee dans Pathfinder.
	var best := 999999
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var edge: Vector2i = target.grid_pos + direction
		if edge != cell and not _grid.is_walkable(edge):
			continue
		var path := _find_path(cell, edge, mover)
		if not path.is_empty():
			best = mini(best, _pathfinder.path_movement_cost(path, mover))
	return best


func _commander_protection_score(cell: Vector2i, enemy: Unit, all_units: Array) -> int:
	var commander := enemy.linked_commander
	if commander == null or not commander.is_alive or enemy.ai_profile == null:
		return -999999
	var score := -_grid.manhattan(cell, commander.grid_pos) \
		* enemy.ai_profile.commander_distance_penalty_per_cell
	for value in _living_opponents(enemy, all_units):
		var hero := value as Unit
		var direct := _grid.manhattan(hero.grid_pos, commander.grid_pos)
		var through := _grid.manhattan(hero.grid_pos, cell) \
			+ _grid.manhattan(cell, commander.grid_pos)
		if through == direct:
			score += enemy.ai_profile.commander_path_block_bonus
	return score


func _movement_toward(
		enemy: Unit,
		target: Unit,
		all_units: Array,
		prefer_neighbors: bool,
		protect_commander: bool
	) -> Array:
	if target == null or enemy.current_mp <= 0:
		return []
	var candidates := _get_reachable(enemy.grid_pos, enemy.current_mp, enemy)
	candidates.append(enemy.grid_pos)
	var scored: Array = []
	for cell_value in candidates:
		var cell: Vector2i = cell_value
		var distance := _path_distance_to_target_edge(cell, target, enemy)
		if distance >= 999999:
			continue
		scored.append({
			"cell": cell,
			"distance": distance,
			"neighbors": _living_neighbor_count(cell, enemy) if prefer_neighbors else 0,
			"protection": _commander_protection_score(cell, enemy, all_units) \
				if protect_commander else 0,
		})
	if scored.is_empty():
		return []
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.distance) != int(b.distance):
			return int(a.distance) < int(b.distance)
		if int(a.neighbors) != int(b.neighbors):
			return int(a.neighbors) > int(b.neighbors)
		if int(a.protection) != int(b.protection):
			return int(a.protection) > int(b.protection)
		var cell_a: Vector2i = a.cell
		var cell_b: Vector2i = b.cell
		return cell_a.y < cell_b.y or (cell_a.y == cell_b.y and cell_a.x < cell_b.x)
	)
	var destination: Vector2i = scored[0].cell
	if destination == enemy.grid_pos:
		return []
	var path := _find_path(enemy.grid_pos, destination, enemy)
	return [{"type": "move", "path": path}] if path.size() >= 2 else []


func _decide_formation_melee(enemy: Unit, all_units: Array) -> Array:
	var damage_spells := _direct_damage_spells(enemy)
	var blade := damage_spells[0] as Spell if not damage_spells.is_empty() else null
	var adjacent := _adjacent_opponents(enemy, all_units)
	if blade != null and enemy.can_use_spell(blade):
		for value in adjacent:
			var target := value as Unit
			if _expected_spell_damage(enemy, blade, target) >= target.current_hp:
				var lethal := _cast_action(enemy, blade, target.grid_pos)
				if not lethal.is_empty():
					return [lethal]
		var marked := _marked_target(enemy, all_units, enemy.linked_commander)
		if marked != null and adjacent.has(marked):
			var marked_action := _cast_action(enemy, blade, marked.grid_pos)
			if not marked_action.is_empty():
				return [marked_action]
		adjacent.sort_custom(func(a: Unit, b: Unit) -> bool:
			if not is_equal_approx(a.get_hp_ratio(), b.get_hp_ratio()):
				return a.get_hp_ratio() < b.get_hp_ratio()
			return a.get_runtime_stable_id() < b.get_runtime_stable_id()
		)
		if not adjacent.is_empty():
			var weak_action := _cast_action(enemy, blade, (adjacent[0] as Unit).grid_pos)
			if not weak_action.is_empty():
				return [weak_action]
	var chase := _marked_target(enemy, all_units, enemy.linked_commander)
	if chase == null:
		chase = _nearest_accessible_opponent(enemy, all_units)
	if blade != null:
		var move_and_blade := _move_then_cast(
			enemy,
			chase,
			blade,
			all_units,
			true,
			false,
		)
		if not move_and_blade.is_empty():
			return move_and_blade
	return _movement_toward(enemy, chase, all_units, true, false)


func _nearest_accessible_opponent(enemy: Unit, all_units: Array) -> Unit:
	var candidates: Array = []
	for value in _living_opponents(enemy, all_units):
		var target := value as Unit
		var distance := _path_distance_to_target_edge(enemy.grid_pos, target, enemy)
		if distance < 999999:
			candidates.append({"unit": target, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.distance) != int(b.distance):
			return int(a.distance) < int(b.distance)
		return (a.unit as Unit).get_runtime_stable_id() \
			< (b.unit as Unit).get_runtime_stable_id()
	)
	return candidates[0].unit as Unit if not candidates.is_empty() else null


func _decide_guardian_chief(enemy: Unit, all_units: Array) -> Array:
	if not enemy.pending_ability.is_empty():
		return []
	var sentence := _delayed_strike_spell(enemy)
	var opponents := _living_opponents(enemy, all_units)
	var marked := _marked_target(enemy, all_units, enemy.linked_commander)
	if sentence != null and enemy.can_use_spell(sentence):
		if marked != null:
			var marked_sentence := _move_then_cast(
				enemy, marked, sentence, all_units, false, true
			)
			if not marked_sentence.is_empty():
				return marked_sentence
		var wounded := opponents.filter(func(value):
			return (value as Unit).get_hp_ratio() \
				< enemy.ai_profile.sentence_hp_ratio_threshold
		)
		wounded.sort_custom(func(a: Unit, b: Unit) -> bool:
			if not is_equal_approx(a.get_hp_ratio(), b.get_hp_ratio()):
				return a.get_hp_ratio() < b.get_hp_ratio()
			return a.get_runtime_stable_id() < b.get_runtime_stable_id()
		)
		for value in wounded:
			var sentence_plan := _move_then_cast(
				enemy, value as Unit, sentence, all_units, false, true
			)
			if not sentence_plan.is_empty():
				return sentence_plan
	var direct := _direct_damage_spells(enemy)
	var strike := direct[0] as Spell if not direct.is_empty() else null
	if strike != null and enemy.can_use_spell(strike):
		for value in opponents:
			var target := value as Unit
			if _expected_spell_damage(enemy, strike, target) < target.current_hp:
				continue
			var lethal := _move_then_cast(
				enemy, target, strike, all_units, false, true
			)
			if not lethal.is_empty():
				return lethal
		if marked != null:
			var marked_strike := _move_then_cast(
				enemy, marked, strike, all_units, false, true
			)
			if not marked_strike.is_empty():
				return marked_strike
	opponents.sort_custom(func(a: Unit, b: Unit) -> bool:
		if not is_equal_approx(a.get_hp_ratio(), b.get_hp_ratio()):
			return a.get_hp_ratio() < b.get_hp_ratio()
		return a.get_runtime_stable_id() < b.get_runtime_stable_id()
	)
	if strike != null:
		for value in opponents:
			var weak_strike := _move_then_cast(
				enemy, value as Unit, strike, all_units, false, true
			)
			if not weak_strike.is_empty():
				return weak_strike
	var chase := marked
	if chase == null:
		chase = _nearest_accessible_opponent(enemy, all_units)
	var movement := _movement_toward(enemy, chase, all_units, false, true)
	if not movement.is_empty():
		return movement
	if enemy.linked_commander != null and enemy.linked_commander.is_alive:
		return _movement_toward(
			enemy,
			enemy.linked_commander,
			all_units,
			false,
			true,
		)
	return []


func _best_summon_cell(enemy: Unit, spell: Spell, all_units: Array) -> Vector2i:
	var cells := _spell_caster.get_targetable_cells(enemy, spell)
	var heroes := _living_opponents(enemy, all_units)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var safety_a := 999999
		var safety_b := 999999
		for value in heroes:
			var hero := value as Unit
			safety_a = mini(safety_a, _grid.manhattan(a, hero.grid_pos))
			safety_b = mini(safety_b, _grid.manhattan(b, hero.grid_pos))
		if safety_a != safety_b:
			return safety_a > safety_b
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	for cell_value in cells:
		var cell: Vector2i = cell_value
		if _spell_caster.can_cast(enemy, spell, cell):
			return cell
	return Vector2i(-1, -1)


func _mark_target_score(enemy: Unit, hero: Unit, normals: Array) -> Dictionary:
	var path_sum := 0
	for value in normals:
		var normal := value as Unit
		var distance := _path_distance_to_target_edge(normal.grid_pos, hero, normal)
		path_sum += distance if distance < 999999 else 100000
	return {
		"unit": hero,
		"path_sum": path_sum,
		"hp_ratio": hero.get_hp_ratio(),
		"commander_distance": _grid.manhattan(enemy.grid_pos, hero.grid_pos),
	}


func _best_mark_target(enemy: Unit, spell: Spell, all_units: Array) -> Unit:
	var targetable := _spell_caster.get_targetable_cells(enemy, spell)
	var normals := _living_allies_with_role(
		enemy,
		all_units,
		enemy.ai_profile.normal_role_id
	)
	var scored: Array = []
	for value in _living_opponents(enemy, all_units):
		var hero := value as Unit
		if targetable.has(hero.grid_pos):
			scored.append(_mark_target_score(enemy, hero, normals))
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.path_sum) != int(b.path_sum):
			return int(a.path_sum) < int(b.path_sum)
		if not is_equal_approx(float(a.hp_ratio), float(b.hp_ratio)):
			return float(a.hp_ratio) < float(b.hp_ratio)
		if int(a.commander_distance) != int(b.commander_distance):
			return int(a.commander_distance) < int(b.commander_distance)
		return (a.unit as Unit).get_runtime_stable_id() \
			< (b.unit as Unit).get_runtime_stable_id()
	)
	return scored[0].unit as Unit if not scored.is_empty() else null


func _best_aegis_target(enemy: Unit, spell: Spell, all_units: Array) -> Unit:
	var status_id := spell.applied_status.get_effective_status_id()
	var targetable := _spell_caster.get_targetable_cells(enemy, spell)
	for value in _living_allies_with_role(enemy, all_units, enemy.ai_profile.chief_role_id):
		var chief := value as Unit
		if targetable.has(chief.grid_pos) and not chief.has_status(status_id):
			return chief
	var normals := _living_allies_with_role(enemy, all_units, enemy.ai_profile.normal_role_id)
	normals.sort_custom(func(a: Unit, b: Unit) -> bool:
		var neighbors_a := _living_neighbor_count(a.grid_pos, a)
		var neighbors_b := _living_neighbor_count(b.grid_pos, b)
		if neighbors_a != neighbors_b:
			return neighbors_a > neighbors_b
		return a.get_runtime_stable_id() < b.get_runtime_stable_id()
	)
	for value in normals:
		var normal := value as Unit
		if targetable.has(normal.grid_pos) and not normal.has_status(status_id):
			return normal
	return null


func _commander_reposition(enemy: Unit, all_units: Array) -> Array:
	var heroes := _living_opponents(enemy, all_units)
	if heroes.is_empty() or enemy.current_mp <= 0:
		return []
	var cells := _get_reachable(enemy.grid_pos, enemy.current_mp, enemy)
	cells.append(enemy.grid_pos)
	var scored: Array = []
	for cell_value in cells:
		var cell: Vector2i = cell_value
		var nearest := 999999
		for value in heroes:
			nearest = mini(nearest, _grid.manhattan(cell, (value as Unit).grid_pos))
		var unsafe := enemy.ai_profile.avoid_hero_adjacency and nearest <= 1
		var range_penalty := 0
		if nearest < enemy.ai_profile.ideal_minimum_range:
			range_penalty = enemy.ai_profile.ideal_minimum_range - nearest
		elif nearest > enemy.ai_profile.ideal_maximum_range:
			range_penalty = nearest - enemy.ai_profile.ideal_maximum_range
		scored.append({"cell": cell, "unsafe": unsafe, "penalty": range_penalty})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.unsafe) != bool(b.unsafe):
			return not bool(a.unsafe)
		if int(a.penalty) != int(b.penalty):
			return int(a.penalty) < int(b.penalty)
		var cell_a: Vector2i = a.cell
		var cell_b: Vector2i = b.cell
		return cell_a.y < cell_b.y or (cell_a.y == cell_b.y and cell_a.x < cell_b.x)
	)
	var destination: Vector2i = scored[0].cell
	if destination == enemy.grid_pos:
		return []
	var path := _find_path(enemy.grid_pos, destination, enemy)
	return [{"type": "move", "path": path}] if path.size() >= 2 else []


func _decide_ranged_commander(enemy: Unit, all_units: Array) -> Array:
	if not enemy.pending_ability.is_empty():
		return []
	var marked := _marked_target(enemy, all_units)
	var mark := _mark_spell(enemy)
	if marked == null and mark != null and enemy.can_use_spell(mark) \
			and _is_designated_mark_caster(enemy, mark, all_units):
		var mark_target := _best_mark_target(enemy, mark, all_units)
		if mark_target != null:
			var mark_action := _cast_action(enemy, mark, mark_target.grid_pos)
			if not mark_action.is_empty():
				return _with_commander_reposition(
					enemy,
					[mark_action],
					all_units,
				)
	var chief_summon := _summon_spell(enemy, &"chief")
	if chief_summon != null \
			and enemy.current_hp <= enemy.ai_profile.commander_emergency_hp \
			and enemy.can_use_spell(chief_summon):
		var chief_cell := _best_summon_cell(enemy, chief_summon, all_units)
		if chief_cell != Vector2i(-1, -1):
			return _with_commander_reposition(enemy, [{
				"type": "cast", "spell": chief_summon, "cell": chief_cell,
			}], all_units)
	var normals := _living_allies_with_role(enemy, all_units, enemy.ai_profile.normal_role_id)
	var normal_summon := _summon_spell(enemy, &"normal")
	if normals.size() < enemy.ai_profile.summon_when_normals_below \
			and normal_summon != null and enemy.can_use_spell(normal_summon):
		var normal_cell := _best_summon_cell(enemy, normal_summon, all_units)
		if normal_cell != Vector2i(-1, -1):
			return _with_commander_reposition(enemy, [{
				"type": "cast", "spell": normal_summon, "cell": normal_cell,
			}], all_units)
	var aegis := _magic_armor_spell(enemy)
	if aegis != null and enemy.can_use_spell(aegis):
		var aegis_target := _best_aegis_target(enemy, aegis, all_units)
		if aegis_target != null:
			return _with_commander_reposition(enemy, [{
				"type": "cast", "spell": aegis, "cell": aegis_target.grid_pos,
			}], all_units)
	var direct := _direct_damage_spells(enemy)
	var frost_lance := direct[0] as Spell if not direct.is_empty() else null
	if frost_lance != null:
		if marked != null:
			var marked_lance := _cast_action(enemy, frost_lance, marked.grid_pos)
			if not marked_lance.is_empty():
				return _with_commander_reposition(enemy, [marked_lance], all_units)
			var move_marked_lance := _move_then_cast(
				enemy, marked, frost_lance, all_units
			)
			if not move_marked_lance.is_empty():
				return move_marked_lance
		var nearest := _nearest_accessible_opponent(enemy, all_units)
		if nearest != null:
			var lance := _cast_action(enemy, frost_lance, nearest.grid_pos)
			if not lance.is_empty():
				return _with_commander_reposition(enemy, [lance], all_units)
			var move_lance := _move_then_cast(
				enemy, nearest, frost_lance, all_units
			)
			if not move_lance.is_empty():
				return move_lance
	return _commander_reposition(enemy, all_units)
