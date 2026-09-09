extends RefCounted

const Terrain = preload("res://core/ai/support_mage_terrain.gd")
const SupportRules = preload("res://core/ai/catabase_monster_support_rules.gd")
const PROFILE_PREFIX := "catabase_evolution_"
const INVALID_CELL := Vector2i(-1, -1)


static func handles(enemy: Unit) -> bool:
	return enemy != null and enemy.ai_profile != null \
		and String(enemy.ai_profile.profile_id).begins_with(PROFILE_PREFIX)


## One decision, one real action. EnemyTurnRunner replans after its resolution:
## AP, cooldowns, shields and displaced targets are never optimistically mutated.
static func decide(ai, enemy: Unit, units: Array) -> Array:
	if not enemy.is_alive or enemy.activation_consumed or not enemy.pending_ability.is_empty():
		return []
	var opponents: Array = ai._living_opponents(enemy, units)
	if opponents.is_empty():
		return []
	var origin := enemy.grid_pos
	var current := _best_cast(ai, enemy, units, origin)
	var placement := _best_placement(ai, enemy, units, current)
	if not placement.is_empty():
		return [{"type": "move", "path": placement.path}]
	if not current.is_empty():
		return [{"type": "cast", "spell": current.spell, "cell": current.cell}]
	return []


static func _best_cast(ai, enemy: Unit, units: Array, origin: Vector2i) -> Dictionary:
	var best := {}
	var forced: Unit = ai._get_forced_target(enemy)
	for spell_value in enemy.spells:
		var spell := spell_value as Spell
		if spell == null or not enemy.can_use_spell(spell) \
				or enemy.get_spell_ap_cost(spell) > enemy.current_ap:
			continue
		for target_value in ai._stable_units(units):
			var target := target_value as Unit
			if target == null or not target.is_alive:
				continue
			if target.team != enemy.team and forced != null and target != forced:
				continue
			var cell := origin if target == enemy else target.grid_pos
			if not _can_cast_from(ai, enemy, spell, target, origin, cell):
				continue
			var score := _score_cast(ai, enemy, spell, target, origin, cell, units)
			if score > 0.0 and (best.is_empty() or score > float(best.score)):
				best = {"spell": spell, "target": target, "cell": cell, "score": score}
	return best


static func _can_cast_from(ai, enemy: Unit, spell: Spell, target: Unit, origin: Vector2i, cell: Vector2i) -> bool:
	if not SupportRules.can_cast(ai.get_grid(), enemy, spell, origin):
		return false
	if target == enemy:
		if not spell.can_target_self and not spell.can_target_ally:
			return false
	elif target.team == enemy.team:
		if not spell.can_target_ally:
			return false
	elif not spell.can_target_enemy:
		return false
	if origin == enemy.grid_pos:
		return ai.get_spell_caster().can_cast(enemy, spell, cell)
	var distance: int = ai.get_grid().manhattan(origin, cell)
	if distance < ai.get_spell_caster().get_effective_spell_minimum_range(enemy, spell) \
			or distance > ai.get_spell_caster().get_effective_spell_range(enemy, spell):
		return false
	if spell.line_from_caster and (origin == cell or (origin.x != cell.x and origin.y != cell.y)):
		return false
	if spell.needs_line_of_sight and not ai.get_pathfinder().has_line_of_sight(origin, cell):
		return false
	if ai.get_spell_caster().get_action_classification(spell) == &"PROJECTILE" \
			and not ai.get_pathfinder().has_projectile_path(origin, cell):
		return false
	return true


static func _score_cast(ai, enemy: Unit, spell: Spell, target: Unit, origin: Vector2i, cell: Vector2i, units: Array) -> float:
	var area: Array = ai.get_spell_caster().get_aoe_cells(spell, cell, origin)
	# Legacy delayed strikes follow one target, not an area. Their telegraph is
	# cancelled by the existing resolver when that target escapes range or LOS.
	if spell.is_delayed():
		area = [cell]
	var score := 0.0
	var shield := spell.get_scaled_shield(enemy)
	for value in units:
		var affected := value as Unit
		if affected == null or not affected.is_alive:
			continue
		var affected_cell := origin if affected == enemy else affected.grid_pos
		if not area.has(affected_cell) or (affected == enemy and spell.exclude_caster_from_area_effects):
			continue
		if affected.team == enemy.team:
			if spell.is_healing():
				var missing := affected.max_hp.get_int() - affected.current_hp
				if affected.get_hp_ratio() < enemy.ai_profile.support_heal_threshold \
						and missing >= maxi(5, spell.heal / 3):
					score += 105.0 + mini(missing, spell.get_scaled_heal(enemy)) * 1.5
			if shield > 0 and affected.current_shield < shield / 2:
				var distance := _nearest_distance(ai, affected.team, affected_cell, units)
				if distance <= enemy.ai_profile.support_protection_distance:
					score += 48.0 + mini(shield, 60) * 0.6
			if spell.applied_status != null and not affected.has_status(spell.applied_status.get_effective_status_id()):
				var buff := spell.applied_status
				if buff.outgoing_damage_modifier > 0 and _can_threaten(ai, affected, affected_cell, units):
					score += 75.0 + buff.outgoing_damage_modifier * 2.0
			if spell.deals_damage() and not spell.exclude_allies_from_area_effects:
				score -= 100.0 + _expected_damage(enemy, spell, affected) * 3.0
			if spell.terrain_effect != null:
				score -= 25.0 + Terrain.cell_risk(ai, affected_cell) * 10.0
			continue
		if spell.deals_damage():
			var expected := _expected_damage(enemy, spell, affected)
			score += 15.0 + expected * (1.1 if spell.is_delayed() else 1.8)
			if expected >= affected.current_hp + affected.current_shield and not spell.is_delayed():
				score += 120.0
			score += (1.0 - affected.get_hp_ratio()) * 18.0
		if spell.applied_status != null and not affected.has_status(spell.applied_status.get_effective_status_id()):
			var status := spell.applied_status
			if status.mp_reduction > 0:
				score += 22.0 if affected.max_mp.get_int() > 0 else 0.0
			elif status.get_effective_status_id() == &"catabase_chasse":
				score += 12.0 + _mark_followers(enemy, affected, units) * 18.0
			else:
				score += 12.0
		if spell.terrain_effect != null:
			# Do not continually paint an already occupied hazard instead of attacking.
			score += 22.0 if Terrain.cell_risk(ai, affected_cell) <= 0.0 else 3.0
	if target.team != enemy.team:
		if spell.push_distance > 0:
			score += Terrain.push_bonus(ai, target, origin, spell.push_distance) * 3.0
		if spell.pull_distance > 0:
			score += _pull_score(ai, enemy, target, spell, origin, units)
	return score


static func _can_threaten(ai, ally: Unit, origin: Vector2i, units: Array) -> bool:
	for spell: Spell in ally.spells:
		if spell.deals_damage() and _nearest_distance(ai, ally.team, origin, units) \
				<= ally.max_mp.get_int() + spell.spell_range:
			return true
	return false


static func _expected_damage(enemy: Unit, spell: Spell, target: Unit) -> int:
	var raw := spell.get_scaled_damage(enemy)
	var marked := target.has_status(spell.bonus_damage_status_id)
	if spell.bonus_requires_linked_status_source:
		marked = enemy.target_has_linked_source_status(target, spell.bonus_damage_status_id)
	if marked:
		raw += spell.bonus_damage_if_marked
	var context := DamageResolver.HitContext.new()
	context.attacker = enemy
	context.raw_damage = raw
	context.category = spell.damage_type
	context.element = spell.element
	context.cannot_be_dodged = true
	return DamageResolver.compute(target, context).amount


static func _mark_followers(enemy: Unit, target: Unit, units: Array) -> int:
	var count := 0
	for value in units:
		var ally := value as Unit
		if ally == null or not ally.is_alive or ally.team != enemy.team:
			continue
		for spell: Spell in ally.spells:
			if spell.bonus_damage_status_id == &"catabase_chasse" and spell.bonus_damage_if_marked > 0:
				var distance := absi(ally.grid_pos.x - target.grid_pos.x) + absi(ally.grid_pos.y - target.grid_pos.y)
				if distance <= ally.max_mp.get_int() + maxi(1, spell.spell_range):
					count += 1
				break
	return count


static func _pull_score(ai, enemy: Unit, target: Unit, spell: Spell, origin: Vector2i, units: Array) -> float:
	if target.mastery_combat_adapter != null and target.mastery_combat_adapter.blocks_control(target, &"pull"):
		return 0.0
	var distance := spell.pull_distance
	if not target._forced_movement_reduction_used:
		distance = maxi(0, distance - target.first_forced_movement_reduction_per_activation)
	var raw := origin - target.grid_pos
	var direction := Vector2i(signi(raw.x), 0) if absi(raw.x) >= absi(raw.y) else Vector2i(0, signi(raw.y))
	var landing := target.grid_pos
	var grid: GridData = ai.get_grid()
	for _step in range(distance):
		var next := landing + direction
		if next == origin or not grid.is_walkable(next, target):
			break
		landing = next
	if landing == target.grid_pos:
		return 0.0
	var score := maxf(0.0, Terrain.cell_risk(ai, landing) - Terrain.cell_risk(ai, target.grid_pos)) * 18.0
	if grid.has_vortex(landing):
		return score # Do not promise a combo from an unknown teleport exit.
	var remaining_ap := enemy.current_ap - enemy.get_spell_ap_cost(spell)
	for followup: Spell in enemy.spells:
		if followup != spell and followup.deals_damage() and enemy.can_use_spell(followup) \
				and enemy.get_spell_ap_cost(followup) <= remaining_ap \
				and grid.manhattan(origin, landing) <= followup.spell_range \
				and grid.manhattan(origin, landing) >= followup.minimum_range:
			score += 65.0
			break
	for value in units:
		var ally := value as Unit
		if ally != null and ally != enemy and ally.is_alive and ally.team == enemy.team \
				and _has_melee_attack(ally) \
				and grid.manhattan(ally.grid_pos, landing) == 1 \
				and grid.manhattan(ally.grid_pos, target.grid_pos) > 1:
			score += 70.0 if ally.pending_ability.get("target") == target else 28.0
	return score


static func _has_melee_attack(ally: Unit) -> bool:
	for spell: Spell in ally.spells:
		if spell.deals_damage() and spell.spell_range <= 1:
			return true
	return false


static func _nearest_distance(ai, team: int, cell: Vector2i, units: Array) -> int:
	var distance := 999
	for value in units:
		var target := value as Unit
		if target != null and target.is_alive and target.team != team:
			distance = mini(distance, ai.get_grid().manhattan(cell, target.grid_pos))
	return distance


static func _position_score(ai, enemy: Unit, cell: Vector2i, units: Array) -> float:
	var distance := _nearest_distance(ai, enemy.team, cell, units)
	var score := -Terrain.cell_risk(ai, cell) * 35.0
	if enemy.keep_distance:
		score -= maxi(0, enemy.minimum_range - distance) * 35.0
		score -= absi(distance - enemy.preferred_range) * 3.0
	var convoy := _convoy_link(enemy, units)
	if not convoy.is_empty():
		var anchor := convoy.unit as Unit
		var supply_distance: int = ai.get_grid().manhattan(cell, anchor.grid_pos)
		score -= maxi(0, supply_distance - int(convoy.radius)) * 55.0
	return score


static func _best_placement(ai, enemy: Unit, units: Array, current: Dictionary) -> Dictionary:
	if enemy.current_mp <= 0:
		return {}
	var best := {}
	var origin := enemy.grid_pos
	var baseline := float(current.get("score", 0.0)) + _position_score(ai, enemy, origin, units)
	var nearest := _movement_goal(ai, enemy, units)
	if nearest == null:
		return {}
	var convoy := _convoy_link(enemy, units)
	var can_act := false
	for spell: Spell in enemy.spells:
		if enemy.can_use_spell(spell) and enemy.get_spell_ap_cost(spell) <= enemy.current_ap:
			can_act = true
			break
	for cell_value in ai._get_reachable(origin, enemy.current_mp, enemy):
		var path: Array = ai._find_path(origin, cell_value, enemy)
		var info := Terrain.path_info(ai, enemy, path)
		if info.is_empty() or not (info.random_exits as Array).is_empty():
			continue
		var cell: Vector2i = info.cell
		if not convoy.is_empty() and bool(convoy.porter):
			var anchor := convoy.unit as Unit
			var grid: GridData = ai.get_grid()
			if grid.manhattan(origin, anchor.grid_pos) <= int(convoy.radius) \
					and grid.manhattan(cell, anchor.grid_pos) > int(convoy.radius) \
					and Terrain.cell_risk(ai, origin) <= Terrain.cell_risk(ai, cell):
				continue # A supplied porter does not abandon the convoi to chase a shot.
		var candidate := _best_cast(ai, enemy, units, cell)
		var score := float(candidate.get("score", 0.0)) + _position_score(ai, enemy, cell, units) \
			- float(info.risk) * 20.0 - int(info.cost) * 2.0
		if current.is_empty() and candidate.is_empty() and can_act:
			# Safe approach before the next turn; actual path length handles walls.
			var before: int = ai._path_distance_to_target_edge(origin, nearest, enemy)
			var after: int = ai._path_distance_to_target_edge(cell, nearest, enemy)
			if before < 999 and after < before:
				score += (before - after) * 8.0
		if score <= baseline + 1.0:
			continue
		if best.is_empty() or score > float(best.score):
			best = {"path": path, "score": score}
	return best


static func _movement_goal(ai, enemy: Unit, units: Array) -> Unit:
	var convoy := _convoy_link(enemy, units)
	if not convoy.is_empty():
		var anchor := convoy.unit as Unit
		if ai.get_grid().manhattan(enemy.grid_pos, anchor.grid_pos) > int(convoy.radius):
			return anchor
	var best: Unit = null
	var best_score := 0.0
	for spell: Spell in enemy.spells:
		if not spell.can_target_ally or not enemy.can_use_spell(spell) \
				or enemy.get_spell_ap_cost(spell) > enemy.current_ap:
			continue
		var required_role := StringName(spell.get_meta("catabase_requires_role_nearby", &""))
		if required_role != &"" and _nearest_support(enemy, units, required_role) == null:
			continue
		for value in units:
			var ally := value as Unit
			if ally == null or ally == enemy or not ally.is_alive or ally.team != enemy.team:
				continue
			var score := 0.0
			if spell.is_healing() and ally.get_hp_ratio() < enemy.ai_profile.support_heal_threshold:
				score = 100.0 * (1.0 - ally.get_hp_ratio())
			elif spell.get_scaled_shield(enemy) > 0 and ally.current_shield < spell.get_scaled_shield(enemy) / 2 \
					and _nearest_distance(ai, ally.team, ally.grid_pos, units) <= enemy.ai_profile.support_protection_distance:
				score = 35.0
			score -= ai.get_grid().manhattan(enemy.grid_pos, ally.grid_pos)
			if score > best_score:
				best_score = score
				best = ally
	return best if best != null else ai._nearest_accessible_opponent(enemy, units)


static func _convoy_link(enemy: Unit, units: Array) -> Dictionary:
	# Porters escort a living collector while it still has healing charges,
	# including during a healing cooldown. Their own attack does not break it.
	if enemy.tactical_role_id == &"catabase_evolution_porteur":
		var best := {}
		var nearest := 999999
		for value in units:
			var ally := value as Unit
			if ally == null or ally == enemy or not ally.is_alive or ally.team != enemy.team:
				continue
			for spell: Spell in ally.spells:
				if not spell.is_healing() or StringName(spell.get_meta("catabase_requires_role_nearby", &"")) != enemy.tactical_role_id:
					continue
				if spell.max_uses_per_combat > 0 and ally.get_spell_uses(spell) >= spell.max_uses_per_combat:
					continue
				var distance := _distance(enemy.grid_pos, ally.grid_pos)
				if distance < nearest:
					nearest = distance
					best = {"unit": ally, "radius": int(spell.get_meta("catabase_support_radius", 2)), "porter": true}
		return best
	# A collector reconnects only when a legal, useful heal needs supply.
	# Dead or exhausted porters never trap it in an impossible support plan.
	for spell: Spell in enemy.spells:
		var required_role := StringName(spell.get_meta("catabase_requires_role_nearby", &""))
		if required_role == &"" or not spell.is_healing() or not enemy.can_use_spell(spell) \
				or enemy.get_spell_ap_cost(spell) > enemy.current_ap:
			continue
		var needs_heal := false
		for value in units:
			var ally := value as Unit
			if ally != null and ally.is_alive and ally.team == enemy.team \
					and (ally != enemy or spell.can_target_self or (spell.can_target_ally and spell.minimum_range == 0)) \
					and ally.get_hp_ratio() < enemy.ai_profile.support_heal_threshold \
					and ally.max_hp.get_int() - ally.current_hp >= maxi(5, spell.heal / 3):
				needs_heal = true
				break
		if needs_heal:
			var porter := _nearest_support(enemy, units, required_role)
			if porter != null:
				return {"unit": porter, "radius": int(spell.get_meta("catabase_support_radius", 2)), "porter": false}
	return {}


static func _nearest_support(enemy: Unit, units: Array, role: StringName) -> Unit:
	var nearest: Unit = null
	var distance := 999999
	for value in units:
		var ally := value as Unit
		if ally != null and ally != enemy and ally.is_alive and ally.team == enemy.team and ally.tactical_role_id == role:
			var candidate := _distance(enemy.grid_pos, ally.grid_pos)
			if candidate < distance:
				distance = candidate
				nearest = ally
	return nearest


static func _distance(first: Vector2i, second: Vector2i) -> int:
	return absi(first.x - second.x) + absi(first.y - second.y)
