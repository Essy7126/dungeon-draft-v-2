class_name SpellCaster
extends RefCounted

var _grid: GridData
var _pathfinder: Pathfinder
var _terrain: TerrainEffects

const CAT_SPELL := DebugLogger.LogCategory.SPELL

func _init(grid: GridData, pathfinder: Pathfinder, terrain: TerrainEffects) -> void:
	_grid = grid
	_pathfinder = pathfinder
	_terrain = terrain

func get_targetable_cells(caster: Unit, spell: Spell) -> Array:
	var result: Array = []
	if spell.is_self_only():
		return [caster.grid_pos]
	for x in _grid.cols:
		for y in _grid.rows:
			var pos = Vector2i(x, y)
			if pos == caster.grid_pos and not spell.can_target_self:
				continue
			if _grid.manhattan(caster.grid_pos, pos) > spell.spell_range:
				continue
			if spell.needs_line_of_sight and not _pathfinder.has_line_of_sight(caster.grid_pos, pos):
				continue
			if _matches_target(caster, spell, pos):
				result.append(pos)
	return result

func get_aoe_cells(spell: Spell, center: Vector2i) -> Array:
	var result: Array = []
	match spell.aoe_shape:
		Spell.AoeShape.SINGLE:
			result.append(center)
		Spell.AoeShape.CROSS:
			result.append(center)
			for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				for i in range(1, spell.aoe_size + 1):
					var pos = center + dir * i
					if _grid.is_valid(pos):
						result.append(pos)
		Spell.AoeShape.SQUARE:
			for dx in range(-spell.aoe_size, spell.aoe_size + 1):
				for dy in range(-spell.aoe_size, spell.aoe_size + 1):
					var pos = center + Vector2i(dx, dy)
					if _grid.is_valid(pos):
						result.append(pos)
		Spell.AoeShape.LINE:
			result.append(center)
	return result

func _matches_target(caster: Unit, spell: Spell, cell: Vector2i) -> bool:
	var occupant = _grid.get_unit(cell)
	if occupant != null and occupant.team != caster.team:
		return spell.can_target_enemy
	if occupant != null and occupant.team == caster.team:
		if occupant == caster:
			return spell.can_target_self or spell.can_target_ally
		return spell.can_target_ally
	if occupant == null:
		return spell.can_target_free_cell
	return false

func is_valid_target(caster: Unit, spell: Spell, cell: Vector2i) -> bool:
	if not get_targetable_cells(caster, spell).has(cell):
		return false
	return _matches_target(caster, spell, cell)

func _has_ally_adjacent(unit: Unit) -> bool:
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var pos = unit.grid_pos + dir
		if not _grid.is_valid(pos):
			continue
		var occupant = _grid.get_unit(pos)
		if occupant != null and occupant.team == unit.team and occupant != unit:
			return true
	return false

func _has_angle_advantage(caster: Unit, target_cell: Vector2i) -> bool:
	var target = _grid.get_unit(target_cell)
	if target == null:
		return false
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var pos = target.grid_pos + dir
		if not _grid.is_valid(pos):
			continue
		var occupant = _grid.get_unit(pos)
		if occupant != null and occupant.team == caster.team and occupant != caster:
			return true
	return false

func _push_unit(caster: Unit, target: Unit, cells: int, collision_damage: int = 0) -> Dictionary:
	var result := { "pushed": false, "collision": false, "pushed_away_from_ally": false, "landed_on_terrain": false }
	if cells <= 0 or target == null:
		return result
	var raw_dir := target.grid_pos - caster.grid_pos
	var dir: Vector2i
	if abs(raw_dir.x) >= abs(raw_dir.y):
		dir = Vector2i(sign(raw_dir.x), 0)
	else:
		dir = Vector2i(0, sign(raw_dir.y))
	if dir == Vector2i.ZERO:
		return result
	var from_pos := target.grid_pos
	var landed_pos := from_pos
	var had_collision := false
	for i in range(cells):
		var next := landed_pos + dir
		# Collision dure : mur ou bord de grille.
		if not _grid.is_valid(next) or not _grid.is_walkable(next):
			had_collision = true
			if collision_damage > 0:
				_apply_collision_damage(caster, target, collision_damage)
			break
		# Collision EN CHAINE : la cible en percute une autre.
		if _grid.has_unit(next):
			had_collision = true
			var blocker = _grid.get_unit(next)
			if collision_damage > 0:
				# Les deux encaissent le choc...
				_apply_collision_damage(caster, target, collision_damage)
				_apply_collision_damage(caster, blocker, collision_damage)
				# ...et l'elan restant est transmis a la percutee, qui peut a son
				# tour en percuter une autre (la chaine se propage).
				if blocker != null and blocker.is_alive:
					_push_unit(caster, blocker, maxi(1, cells - i), collision_damage)
			# Si la case s'est liberee (percutee morte ou poussee plus loin), on avance.
			if not _grid.has_unit(next):
				landed_pos = next
			break
		landed_pos = next
	# La cible a pu mourir d'une collision (mur/hasard) avant tout deplacement.
	if not target.is_alive:
		result["collision"] = had_collision
		return result
	if landed_pos != from_pos:
		if not _grid.relocate_unit(target, landed_pos):
			return result
		if _terrain.get_effect_data(landed_pos) != null:
			result["landed_on_terrain"] = true
			_terrain.on_enter_cell(target, landed_pos)
		result["pushed"] = true
		result["collision"] = had_collision
		result["pushed_away_from_ally"] = _pushed_away_from_ally(caster, from_pos, landed_pos)
		EventBus.unit_pushed.emit(target, from_pos, landed_pos, had_collision)
		DebugLogger.debug(CAT_SPELL, "%s pousse de %s a %s" % [target.unit_name, str(from_pos), str(landed_pos)])
	elif had_collision:
		result["collision"] = true
		EventBus.unit_pushed.emit(target, from_pos, from_pos, true)
	return result

# Degats de collision : applique le choc a une victime (cible poussee ou percutee).
func _apply_collision_damage(caster: Unit, victim, amount: int) -> void:
	if victim == null or not victim.is_alive:
		return
	victim.take_damage(amount, caster, Spell.DamageType.PHYSICAL, Spell.Element.NONE)
	DebugLogger.debug(CAT_SPELL, "Collision : %s subit %d" % [victim.unit_name, amount])

# Attire la cible VERS le lanceur (Crochet). S'arrete avant le lanceur / obstacle.
func _pull_unit(caster: Unit, target: Unit, cells: int) -> Dictionary:
	var result := { "pushed": false, "collision": false, "pushed_away_from_ally": false, "landed_on_terrain": false }
	if cells <= 0 or target == null:
		return result
	var raw_dir := caster.grid_pos - target.grid_pos
	var dir: Vector2i
	if abs(raw_dir.x) >= abs(raw_dir.y):
		dir = Vector2i(sign(raw_dir.x), 0)
	else:
		dir = Vector2i(0, sign(raw_dir.y))
	if dir == Vector2i.ZERO:
		return result
	var from_pos := target.grid_pos
	var landed_pos := from_pos
	for _i in range(cells):
		var next := landed_pos + dir
		if next == caster.grid_pos or not _grid.is_valid(next) or not _grid.is_walkable(next) or _grid.has_unit(next):
			break
		landed_pos = next
	if landed_pos != from_pos:
		if not _grid.relocate_unit(target, landed_pos):
			return result
		if _terrain.get_effect_data(landed_pos) != null:
			result["landed_on_terrain"] = true
			_terrain.on_enter_cell(target, landed_pos)
		# Un deplacement force : compte comme une poussee pour la generation EXPLOIT.
		result["pushed"] = true
		EventBus.unit_pushed.emit(target, from_pos, landed_pos, false)
		DebugLogger.debug(CAT_SPELL, "%s attire %s en %s" % [caster.unit_name, target.unit_name, str(landed_pos)])
	return result

func _teleport_behind_target(caster: Unit, target: Unit) -> bool:
	if caster == null or target == null:
		return false
	var raw_dir := target.grid_pos - caster.grid_pos
	var dir: Vector2i
	if abs(raw_dir.x) >= abs(raw_dir.y):
		dir = Vector2i(sign(raw_dir.x), 0)
	else:
		dir = Vector2i(0, sign(raw_dir.y))
	if dir == Vector2i.ZERO:
		return false
	var destination := target.grid_pos + dir
	if not _grid.is_valid(destination) or not _grid.is_walkable(destination) or _grid.has_unit(destination):
		return false
	var from_pos := caster.grid_pos
	if not _grid.relocate_unit(caster, destination):
		return false
	EventBus.unit_pushed.emit(caster, from_pos, destination, false)
	DebugLogger.debug(CAT_SPELL, "%s se replace en %s" % [caster.unit_name, str(destination)])
	return true

func _pushed_away_from_ally(caster: Unit, from_pos: Vector2i, to_pos: Vector2i) -> bool:
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var adj: Vector2i = from_pos + dir
		if not _grid.is_valid(adj):
			continue
		var occupant: Unit = _grid.get_unit(adj)
		if occupant != null and occupant.team == caster.team and occupant != caster:
			return not (to_pos - occupant.grid_pos).length() < 1.5
	return false

func _has_status(unit: Unit, status_name: String) -> bool:
	if unit == null or not unit.has_method("get_active_statuses"):
		return false
	for entry in unit.get_active_statuses():
		var sd: StatusData = entry.get("data")
		if sd != null and sd.status_name == status_name:
			return true
	return false

func can_afford(caster: Unit, spell: Spell, imprinted: bool = false) -> bool:
	if caster == null or spell == null:
		return false
	if not caster.has_energy():
		return true
	return caster.can_afford_spell_resources(spell, imprinted)

func cast(caster: Unit, spell: Spell, cell: Vector2i, imprinted: bool = false) -> Dictionary:
	var elan_cost := 0.0
	var fervor_cost := 0.0
	if caster.has_energy():
		elan_cost = caster.get_spell_elan_cost(spell)
		fervor_cost = caster.get_spell_fervor_cost(spell, imprinted)
		if not caster.can_afford_elan(elan_cost):
			DebugLogger.info(CAT_SPELL, "%s ne peut pas lancer %s (Elan insuffisant : %d/%d)" % [caster.unit_name, spell.spell_name, int(caster.current_elan), int(elan_cost)])
			return _failed_report(caster, spell, cell, "elan")
		if not caster.can_afford_energy(fervor_cost):
			DebugLogger.info(CAT_SPELL, "%s ne peut pas lancer %s (Ferveur insuffisante : %d/%d)" % [caster.unit_name, spell.spell_name, int(caster.current_energy), int(fervor_cost)])
			return _failed_report(caster, spell, cell, "fervor")
		caster.spend_elan(elan_cost, spell.spell_name)
		caster.spend_energy(fervor_cost, spell.spell_name)
	DebugLogger.info(CAT_SPELL, "%s lance %s sur %s" % [caster.unit_name, spell.spell_name, str(cell)], {
		"Elan": int(elan_cost), "Ferveur": int(fervor_cost), "empreinte": imprinted, "portee": spell.spell_range,
		"zone": spell.aoe_size if spell.aoe_shape != Spell.AoeShape.SINGLE else 0,
	})
	var report = {
		"caster": caster, "spell": spell, "cell": cell, "imprinted": imprinted,
		"affected_units": [], "damaged_enemies": [], "healed_units": [], "shielded_units": [],
		"controlled_enemies": [], "drained_units": [], "terrain_changed": [],
		"crits": [], "dodges": [], "ally_adjacent_to_caster": _has_ally_adjacent(caster),
		"angle_advantage": _has_angle_advantage(caster, cell), "pushed": false,
		"collision": false, "pushed_away_from_ally": false, "landed_on_terrain": false,
	}
	var affected_cells = get_aoe_cells(spell, cell)
	for target_cell in affected_cells:
		var target = _grid.get_unit(target_cell)
		if target != null:
			var affected := false
			if spell.deals_damage():
				var raw_damage := spell.damage + (spell.imprint_damage_bonus if imprinted else 0)
				var base_dmg := caster.get_modified_spell_damage(spell, raw_damage)
				if spell.bonus_damage_if_marked > 0 and _has_status(target, "Marque"):
					base_dmg += spell.bonus_damage_if_marked
				var damage_result = target.take_damage(base_dmg, caster, spell.damage_type, spell.element, { "bonus_crit_chance": spell.crit_chance })
				if damage_result != null:
					if damage_result.is_crit:
						report["crits"].append(target)
					if damage_result.dodged:
						report["dodges"].append(target)
					elif damage_result.amount > 0 and target.team != caster.team and not report["damaged_enemies"].has(target):
						report["damaged_enemies"].append(target)
				affected = true
			if spell.is_healing():
				var before_hp: int = target.current_hp
				var raw_heal := spell.heal + (spell.imprint_heal_bonus if imprinted else 0)
				var heal_amount := caster.get_modified_spell_heal(spell, raw_heal)
				if spell.heal_bonus_effect_name.strip_edges() != "":
					var heal_effect := _terrain.get_effect_data(target.grid_pos)
					if heal_effect != null and heal_effect.effect_name == spell.heal_bonus_effect_name:
						heal_amount = maxi(0, int(round(float(heal_amount) * spell.heal_bonus_multiplier)))
				target.heal(heal_amount)
				if target.current_hp > before_hp and not report["healed_units"].has(target):
					report["healed_units"].append(target)
				affected = true
			if spell.applied_status != null:
				target.apply_status(spell.applied_status)
				affected = true
			if imprinted and spell.imprint_status != null:
				target.apply_status(spell.imprint_status)
				affected = true
			if spell.forces_taunt and target.team != caster.team:
				target.apply_taunt(caster, spell.taunt_duration)
				if not report["controlled_enemies"].has(target):
					report["controlled_enemies"].append(target)
				affected = true
			if target.team != caster.team and (spell.elan_drain > 0.0 or spell.fervor_drain > 0.0):
				if spell.elan_drain > 0.0 and target.has_method("spend_elan"):
					target.spend_elan(minf(target.current_elan, spell.elan_drain), spell.spell_name)
				if spell.fervor_drain > 0.0 and target.has_energy():
					target.spend_energy(minf(target.current_energy, spell.fervor_drain), spell.spell_name)
				if not report["drained_units"].has(target):
					report["drained_units"].append(target)
				affected = true
			var raw_shield := spell.shield_grant + (spell.imprint_shield_bonus if imprinted else 0)
			if raw_shield > 0 and target.team == caster.team:
				var before_shield: int = target.current_shield
				target.add_shield(caster.get_modified_spell_shield(spell, raw_shield))
				if target.current_shield > before_shield and not report["shielded_units"].has(target):
					report["shielded_units"].append(target)
				affected = true
			if affected and not report["affected_units"].has(target):
				report["affected_units"].append(target)
		var terrain_payloads: Array = []
		if spell.has_terrain_effect():
			terrain_payloads.append(spell.terrain_effect)
		if imprinted and spell.imprint_terrain_effect != null:
			terrain_payloads.append(spell.imprint_terrain_effect)
		for terrain_data in terrain_payloads:
			var terrain_result: Dictionary = _terrain.place_effect(target_cell, terrain_data, caster, spell)
			if terrain_result.get("changed", false) and not report["terrain_changed"].has(target_cell):
				report["terrain_changed"].append(target_cell)
	if spell.push_all_adjacent and spell.push_distance > 0:
		# On recense d'abord les ennemis entasses autour du lanceur : le souffle
		# scale avec leur nombre (recompense d'avoir regroupe avant de detoner).
		var cluster: Array = []
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var adj = _grid.get_unit(caster.grid_pos + dir)
			if adj != null and adj.team != caster.team:
				cluster.append(adj)
		var blast: int = spell.cluster_bonus_damage * cluster.size()
		for adjacent_target in cluster:
			# Degats de souffle (scalent avec la taille du paquet) AVANT la poussee.
			if blast > 0 and adjacent_target.is_alive:
				adjacent_target.take_damage(blast, caster, Spell.DamageType.PHYSICAL, Spell.Element.NONE)
				if not report["damaged_enemies"].has(adjacent_target):
					report["damaged_enemies"].append(adjacent_target)
				if not report["affected_units"].has(adjacent_target):
					report["affected_units"].append(adjacent_target)
			# Puis la projection vers l'exterieur (peut percuter mur/hasard).
			if not adjacent_target.is_alive:
				continue
			var adjacent_push = _push_unit(caster, adjacent_target, spell.push_distance, spell.collision_damage)
			report["pushed"] = report["pushed"] or adjacent_push["pushed"]
			report["collision"] = report["collision"] or adjacent_push["collision"]
			report["pushed_away_from_ally"] = report["pushed_away_from_ally"] or adjacent_push["pushed_away_from_ally"]
			report["landed_on_terrain"] = report["landed_on_terrain"] or adjacent_push.get("landed_on_terrain", false)
			if adjacent_push["pushed"] and not report["affected_units"].has(adjacent_target):
				report["affected_units"].append(adjacent_target)
	elif spell.push_distance > 0:
		var push_target = _grid.get_unit(cell)
		if push_target != null and push_target.team != caster.team:
			var push_result = _push_unit(caster, push_target, spell.push_distance, spell.collision_damage)
			report["pushed"] = push_result["pushed"]
			report["collision"] = push_result["collision"]
			report["pushed_away_from_ally"] = push_result["pushed_away_from_ally"]
			report["landed_on_terrain"] = push_result.get("landed_on_terrain", false)
	if spell.pull_distance > 0:
		var pull_target = _grid.get_unit(cell)
		if pull_target != null and pull_target.team != caster.team:
			var pull_result = _pull_unit(caster, pull_target, spell.pull_distance)
			report["pushed"] = report["pushed"] or pull_result["pushed"]
			report["landed_on_terrain"] = report["landed_on_terrain"] or pull_result.get("landed_on_terrain", false)
	if spell.teleport_behind_target:
		var teleport_target = _grid.get_unit(cell)
		if teleport_target != null and teleport_target.team != caster.team and _teleport_behind_target(caster, teleport_target):
			report["angle_advantage"] = true
	var hit_names: Array = []
	for u in report["affected_units"]:
		hit_names.append(u.unit_name)
	DebugLogger.debug(CAT_SPELL, "%s : %d unite(s), %d terrain(s)" % [spell.spell_name, report["affected_units"].size(), report["terrain_changed"].size()], { "cibles": hit_names })
	if spell.energy_generated > 0.0 and caster.has_energy() and _spell_had_real_effect(report):
		caster.generate_energy(spell.energy_generated, spell.spell_name)
	EventBus.spell_cast.emit(caster, spell, report)
	return report

func _spell_had_real_effect(report: Dictionary) -> bool:
	return not report.get("affected_units", []).is_empty() \
		or not report.get("terrain_changed", []).is_empty() \
		or bool(report.get("pushed", false)) \
		or bool(report.get("collision", false)) \
		or bool(report.get("landed_on_terrain", false))

func _failed_report(caster: Unit, spell: Spell, cell: Vector2i, reason: String) -> Dictionary:
	return {
		"caster": caster, "spell": spell, "cell": cell, "imprinted": false, "failed": true, "reason": reason,
		"affected_units": [], "damaged_enemies": [], "healed_units": [], "shielded_units": [],
		"controlled_enemies": [], "drained_units": [], "terrain_changed": [], "crits": [], "dodges": [],
	}

