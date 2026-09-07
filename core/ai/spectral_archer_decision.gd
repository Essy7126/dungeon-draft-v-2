extends RefCounted

const Terrain = preload("res://core/ai/support_mage_terrain.gd")

## Paris shares the audited terrain path evaluation with the Dialectician.
## Planning never changes HP, AP, statuses, occupancy, form, or vortex RNG.
## EnemyTurnRunner revalidates every action against the real state on execution.
static func decide(ai, enemy: Unit, all_units: Array) -> Array:
	if enemy == null or not enemy.is_alive or not enemy.pending_ability.is_empty():
		return []
	var projected := {"ap": enemy.current_ap, "used": {}, "healed": {}, "shielded": {}, "controlled": {}, "displaced": {}}
	var origin := enemy.grid_pos
	var plan: Array = []
	var possible_origins: Array = []
	var candidate := _best_cast(ai, enemy, all_units, origin, projected, possible_origins)
	var teleport := _teleport_placement(ai, enemy, all_units)
	if not teleport.is_empty():
		plan.append({"type": "cast", "spell": teleport.spell, "cell": teleport.cell})
		projected.ap = int(projected.ap) - enemy.get_spell_ap_cost(teleport.spell)
		projected.used[(teleport.spell as Spell).get_effective_spell_id()] = true
		origin = teleport.cell
		candidate = _best_cast(ai, enemy, all_units, origin, projected)
	if enemy.current_mp > 0 and teleport.is_empty():
		var placement := _find_placement(ai, enemy, all_units, projected, candidate)
		if not placement.is_empty():
			origin = placement.cell
			possible_origins = placement.get("origins", [])
			plan.append({"type": "move", "path": placement.path})
			candidate = _best_cast(ai, enemy, all_units, origin, projected, possible_origins)
	for _index in range(2):
		if candidate.is_empty():
			break
		var spell := candidate.spell as Spell
		var target := candidate.target as Unit
		plan.append({"type": "cast", "spell": spell, "cell": candidate.cell})
		projected.ap = int(projected.ap) - enemy.get_spell_ap_cost(spell)
		projected.used[spell.get_effective_spell_id()] = true
		var key := target.get_instance_id()
		if spell.is_healing():
			projected.healed[key] = true
		if spell.shield_grant > 0:
			projected.shielded[key] = true
		if spell.applied_status != null:
			projected.controlled[key] = true
		if spell.push_distance > 0 or spell.pull_distance > 0:
			# Forced displacement is resolved by the combat engine. Never guess
			# the next enemy cell through collisions, holes or vortex networks.
			projected.displaced[key] = true
		candidate = _best_cast(ai, enemy, all_units, origin, projected, possible_origins)
	if plan.is_empty():
		return _approach(ai, enemy, all_units)
	return plan


static func _best_cast(ai, enemy: Unit, units: Array, origin: Vector2i, state: Dictionary, possible_origins: Array = []) -> Dictionary:
	var best: Dictionary = {}
	var forced: Unit = ai._get_forced_target(enemy)
	for spell_value in enemy.spells:
		var spell := spell_value as Spell
		if spell == null or enemy.get_spell_ap_cost(spell) > int(state.ap) or not enemy.can_use_spell(spell):
			continue
		if state.used.has(spell.get_effective_spell_id()) \
				and (spell.once_per_activation or spell.cooldown_activations > 0):
			continue
		for target_value in ai._stable_units(units):
			var target := target_value as Unit
			if target == null or not target.is_alive:
				continue
			var key := target.get_instance_id()
			if state.displaced.has(key):
				continue
			if target.team != enemy.team and forced != null and target != forced:
				continue
			# A random vortex cannot promise a self-target cell. Other targets are
			# allowed only when the same cast is legal from every possible exit.
			if possible_origins.size() > 1 and target == enemy:
				continue
			var cell := origin if target == enemy else target.grid_pos
			if not _can_cast_from(ai, enemy, spell, target, origin, cell):
				continue
			var score := _score(ai, enemy, spell, target, units, origin, state)
			for possible_value in possible_origins:
				var possible: Vector2i = possible_value
				if not _can_cast_from(ai, enemy, spell, target, possible, cell):
					score = 0.0
					break
				score = minf(score, _score(ai, enemy, spell, target, units, possible, state))
			if score <= 0.0:
				continue
			if best.is_empty() or score > float(best.score):
				best = {"spell": spell, "target": target, "cell": cell, "score": score}
	return best


static func _can_cast_from(ai, enemy: Unit, spell: Spell, target: Unit, origin: Vector2i, cell: Vector2i) -> bool:
	if target == enemy:
		if not spell.can_target_self:
			return false
	elif target.team == enemy.team:
		if not spell.can_target_ally:
			return false
	elif not spell.can_target_enemy:
		return false
	if origin == enemy.grid_pos:
		return ai.get_spell_caster().can_cast(enemy, spell, cell)
	var grid: GridData = ai.get_grid()
	var distance := grid.manhattan(origin, cell)
	if distance < ai.get_spell_caster().get_effective_spell_minimum_range(enemy, spell) \
			or distance > ai.get_spell_caster().get_effective_spell_range(enemy, spell):
		return false
	if spell.line_from_caster and origin.x != cell.x and origin.y != cell.y:
		return false
	if spell.needs_line_of_sight and not ai.get_pathfinder().has_line_of_sight(origin, cell):
		return false
	if ai.get_spell_caster().get_action_classification(spell) == &"PROJECTILE" \
			and not ai.get_pathfinder().has_projectile_path(origin, cell):
		return false
	return true


static func _score(ai, enemy: Unit, spell: Spell, target: Unit, units: Array, origin: Vector2i, state: Dictionary) -> float:
	if spell.caster_movement != Spell.CasterMovement.NONE:
		return 0.0
	var expected: int = ai._expected_spell_damage(enemy, spell, target)
	var distance: int = ai.get_grid().manhattan(origin, target.grid_pos)
	if expected >= target.current_hp + target.current_shield:
		return 500.0 - enemy.get_spell_ap_cost(spell) + expected * 0.01
	var id := spell.get_effective_spell_id()
	if spell.pull_distance > 0:
		var bonus := _pull_benefit(ai, enemy, target, origin)
		if bonus > 0.0:
			return 230.0 + bonus
		return 95.0 if enemy.combat_form_id == &"infernal" and distance > 2 else 45.0
	if id == &"paris_ice_arrow":
		if target.has_status(&"frozen") or state.controlled.has(target.get_instance_id()):
			return 50.0
		return 160.0
	if id == &"paris_fire_arrow":
		return 60.0 if target.has_status(&"burn") else 140.0
	if id == &"paris_infernal_sweep":
		var grid: GridData = ai.get_grid()
		var hits := 0
		for value in units:
			var other := value as Unit
			if other != null and other.is_alive and other.team != enemy.team \
					and grid.manhattan(other.grid_pos, target.grid_pos) <= 1:
				hits += 1
		# Do not surround the demon with his own fire when a plain whip works.
		return 180.0 + hits * 10.0 if hits >= 2 and distance > 1 else 65.0
	return 90.0 + (1.0 - target.get_hp_ratio()) * 10.0 if spell.deals_damage() else 0.0


static func _pull_benefit(ai, enemy: Unit, target: Unit, origin: Vector2i) -> float:
	if target.mastery_combat_adapter != null and target.mastery_combat_adapter.blocks_control(target, &"pull"):
		return 0.0
	if not target._forced_movement_reduction_used and target.first_forced_movement_reduction_per_activation > 0:
		return 0.0
	var raw := origin - target.grid_pos
	var direction := Vector2i(signi(raw.x), 0) if absi(raw.x) >= absi(raw.y) else Vector2i(0, signi(raw.y))
	var landing := target.grid_pos + direction
	var grid: GridData = ai.get_grid()
	if landing == origin or not grid.is_walkable(landing, target):
		return 0.0
	var benefit := Terrain.cell_risk(ai, landing) * 10.0
	if grid.has_vortex(landing) and (grid.can_unit_use_vortex_network(landing, target) \
			or grid.can_traverse_vortex(landing, target)):
		benefit += 18.0
	return minf(50.0, benefit)


static func _teleport_placement(ai, enemy: Unit, units: Array) -> Dictionary:
	var spell: Spell = null
	for value in enemy.spells:
		if value is Spell and (value as Spell).caster_movement == Spell.CasterMovement.TARGET_CELL:
			spell = value
			break
	if spell == null or not enemy.can_use_spell(spell):
		return {}
	var grid: GridData = ai.get_grid()
	var distance := _nearest_opponent_distance(grid, enemy.team, enemy.grid_pos, units)
	var danger := Terrain.cell_risk(ai, enemy.grid_pos)
	var infernal := enemy.combat_form_id == &"infernal"
	if danger <= 0.0 and ((infernal and distance <= 3) or (not infernal and distance > 2)):
		return {}
	var baseline := absf(distance - enemy.preferred_range) * 10.0 + danger * 25.0
	var best: Dictionary = {}
	for value in ai.get_spell_caster().get_targetable_cells(enemy, spell):
		var cell: Vector2i = value
		# A following cast needs a known origin. Existing vortex networks are
		# still available to ordinary walking through the shared terrain planner.
		if grid.has_vortex(cell) or Terrain.cell_risk(ai, cell) > 0.0:
			continue
		if not ai.get_spell_caster().can_cast(enemy, spell, cell):
			continue
		var nearest := _nearest_opponent_distance(grid, enemy.team, cell, units)
		if nearest < enemy.minimum_range:
			continue
		var gain := baseline - absf(nearest - enemy.preferred_range) * 10.0
		if gain > 8.0 and (best.is_empty() or gain > float(best.gain)):
			best = {"spell": spell, "cell": cell, "gain": gain}
	return best


static func _nearest_opponent_distance(grid: GridData, team: int, cell: Vector2i, units: Array) -> int:
	var nearest := 999
	for value in units:
		var target := value as Unit
		if target != null and target.is_alive and target.team != team:
			nearest = mini(nearest, grid.manhattan(cell, target.grid_pos))
	return nearest


static func _find_placement(ai, enemy: Unit, units: Array, state: Dictionary, current: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var grid: GridData = ai.get_grid()
	var current_risk := Terrain.cell_risk(ai, enemy.grid_pos)
	var current_score := float(current.get("score", 0.0)) - current_risk * 30.0
	for cell_value in ai._get_reachable(enemy.grid_pos, enemy.current_mp, enemy):
		var path: Array = ai._find_path(enemy.grid_pos, cell_value, enemy)
		var info := Terrain.path_info(ai, enemy, path)
		if info.is_empty():
			continue
		var origins: Array = info.random_exits
		var cell: Vector2i = info.cell if origins.is_empty() else origins[0]
		var candidate := _best_cast(ai, enemy, units, cell, state, origins)
		if candidate.is_empty() and current_risk <= 0.0:
			continue
		# Keep established casting poses on neutral ground. Moving while able
		# to cast needs a real terrain reason: danger, useful TP, or a push.
		if not current.is_empty() and current_risk <= 0.0:
			var terrain_push := false
			if not candidate.is_empty():
				var spell := candidate.spell as Spell
				terrain_push = spell.push_distance > 0 \
					and Terrain.push_bonus(ai, candidate.target, cell, spell.push_distance) > 0.0
			if not terrain_push and not _path_uses_transport(grid, path):
				continue
		var range_penalty := 0.0
		var end_risk := Terrain.cell_risk(ai, cell)
		var evaluated_origins: Array = origins if not origins.is_empty() else [cell]
		for value in evaluated_origins:
			var nearest := _nearest_opponent_distance(grid, enemy.team, value, units)
			range_penalty = maxf(range_penalty, absf(nearest - enemy.preferred_range) * 4.0)
			end_risk = maxf(end_risk, Terrain.cell_risk(ai, value))
		var score: float = float(candidate.get("score", 0.0)) - int(info.cost) * 2.0 \
			- float(info.risk) * 20.0 - end_risk * 30.0 - range_penalty
		if score <= current_score:
			continue
		if best.is_empty() or score > float(best.score):
			best = {"cell": cell, "path": path, "score": score, "origins": origins}
	return best


static func _path_uses_transport(grid: GridData, path: Array) -> bool:
	for index in range(1, path.size()):
		if grid.get_vortex_network_cells(path[index]).size() >= 2 \
				or grid.get_vortex_destination(path[index]) != Vector2i(-1, -1):
			return true
	return false


static func _approach(ai, enemy: Unit, units: Array) -> Array:
	if enemy.current_mp <= 0 or enemy.current_ap < 2:
		return []
	var target: Unit = ai._nearest_accessible_opponent(enemy, units)
	if target == null:
		return []
	var grid: GridData = ai.get_grid()
	var start_distance := grid.manhattan(enemy.grid_pos, target.grid_pos)
	var best_score := 0.0
	var best_path: Array = []
	for cell_value in ai._get_reachable(enemy.grid_pos, enemy.current_mp, enemy):
		var path: Array = ai._find_path(enemy.grid_pos, cell_value, enemy)
		var info := Terrain.path_info(ai, enemy, path)
		if info.is_empty():
			continue
		var destinations: Array = info.random_exits if not info.random_exits.is_empty() else [info.cell]
		var progress := INF
		var end_risk := 0.0
		for destination in destinations:
			var distance := grid.manhattan(destination, target.grid_pos)
			if distance < enemy.minimum_range:
				progress = -INF
				break
			progress = minf(progress, absf(start_distance - enemy.preferred_range) - absf(distance - enemy.preferred_range))
			end_risk = maxf(end_risk, Terrain.cell_risk(ai, destination))
		var score: float = progress * 8.0 - int(info.cost) * 2.0 - float(info.risk) * 20.0 - end_risk * 30.0
		if score > best_score:
			best_score = score
			best_path = path
	return [{"type": "move", "path": best_path}] if best_path.size() >= 2 else []
