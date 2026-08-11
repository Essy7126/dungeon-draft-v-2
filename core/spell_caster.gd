# Point unique de validation des PA, du ciblage et de résolution des sorts.

class_name SpellCaster
extends RefCounted

const LogDefinitions = preload("res://debug/log_definitions.gd")

var _grid: GridData
var _pathfinder: Pathfinder
var _terrain: TerrainEffects
var _encounter_runtime_state: EncounterRuntimeState = null
var _cast_sequence := 0

const CAT_SPELL: LogDefinitions.LogCategory = LogDefinitions.LogCategory.SPELL

func _init(grid: GridData, pathfinder: Pathfinder, terrain: TerrainEffects) -> void:
	_grid = grid
	_pathfinder = pathfinder
	_terrain = terrain


func set_encounter_runtime_state(state: EncounterRuntimeState) -> void:
	_encounter_runtime_state = state

func get_targetable_cells(caster: Unit, spell: Spell) -> Array:
	var result: Array = []
	if spell.is_self_only():
		return [caster.grid_pos]
	var effective_range := get_effective_spell_range(caster, spell)
	for x in _grid.cols:
		for y in _grid.rows:
			var pos = Vector2i(x, y)
			if pos == caster.grid_pos and not spell.can_target_self:
				continue
			if not _grid.is_terrain_interactable(pos):
				continue
			if _grid.manhattan(caster.grid_pos, pos) > effective_range:
				continue
			if _grid.manhattan(caster.grid_pos, pos) < spell.minimum_range:
				continue
			if spell.line_from_caster and not _is_cardinal_line_target(caster.grid_pos, pos):
				continue
			if spell.needs_line_of_sight and not _pathfinder.has_line_of_sight(caster.grid_pos, pos):
				continue
			if _matches_target(caster, spell, pos):
				result.append(pos)
	return result


func get_effective_spell_range(caster: Unit, spell: Spell) -> int:
	if caster == null or spell == null:
		return 0
	var effective_range := spell.spell_range
	for modifier in _gather_modifiers(caster, spell):
		effective_range += int(modifier.get_range_bonus(caster, spell))
	return maxi(0, effective_range)

func get_aoe_cells(
		spell: Spell,
		center: Vector2i,
		origin: Vector2i = Vector2i(-1, -1)
	) -> Array:
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
			if spell.line_from_caster and origin != Vector2i(-1, -1):
				var delta := center - origin
				if _is_cardinal_line_target(origin, center):
					var direction := Vector2i(signi(delta.x), signi(delta.y))
					for distance in range(1, absi(delta.x) + absi(delta.y) + 1):
						var pos := origin + direction * distance
						if _grid.is_valid(pos):
							result.append(pos)
			else:
				result.append(center)
	return result


func _is_cardinal_line_target(origin: Vector2i, target: Vector2i) -> bool:
	var delta := target - origin
	return delta != Vector2i.ZERO and (delta.x == 0 or delta.y == 0)

func _matches_target(caster: Unit, spell: Spell, cell: Vector2i) -> bool:
	var occupant = _grid.get_unit(cell)
	if occupant != null and occupant.team != caster.team:
		return spell.can_target_enemy
	if occupant != null and occupant.team == caster.team:
		if occupant == caster:
			return spell.can_target_self or spell.can_target_ally
		return spell.can_target_ally
	if occupant == null:
		if spell.can_target_free_cell:
			return true
		for modifier in _gather_modifiers(caster, spell):
			if modifier.allows_free_cell_target(caster, spell):
				return true
		return false
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

# `journal` (optionnel) : consigne chaque déplacement résolu (chaînes comprises)
# dans le CastContext, pour les hooks des modifiers. N'affecte pas le rapport.
func _push_unit(caster: Unit, target: Unit, cells: int, collision_damage: int = 0, journal: Array = []) -> Dictionary:
	var result := {
		"pushed": false,
		"collision": false,
		"pushed_away_from_ally": false,
		"landed_on_terrain": false,
		"collision_units": [],
	}
	if cells <= 0 or target == null:
		return result
	cells = target.reduce_forced_movement(cells)
	if cells <= 0:
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
		# Collision EN CHAINE : la cible en percute une autre. Testee AVANT la
		# collision dure, car is_walkable() est aussi faux pour une case OCCUPEE :
		# sinon percuter une unite serait traite comme percuter un mur (pas de
		# degats au bloqueur, pas de transmission d'elan).
		if _grid.has_unit(next):
			had_collision = true
			var blocker = _grid.get_unit(next)
			if not result["collision_units"].has(target):
				result["collision_units"].append(target)
			if blocker != null and not result["collision_units"].has(blocker):
				result["collision_units"].append(blocker)
			if collision_damage > 0:
				# Les deux encaissent le choc...
				_apply_collision_damage(caster, target, collision_damage)
				_apply_collision_damage(caster, blocker, collision_damage)
				# ...et la quantite de mouvement restante est transmise a la
				# percutee, qui peut a son tour en percuter une autre (chaine).
				if blocker != null and blocker.is_alive:
					_push_unit(caster, blocker, maxi(1, cells - i), collision_damage, journal)
			# Si la case s'est liberee (percutee morte ou poussee plus loin), on avance.
			if not _grid.has_unit(next):
				landed_pos = next
			break
		# Collision dure : mur ou bord de grille.
		if not _grid.is_valid(next) or not _grid.is_walkable(next):
			had_collision = true
			if not result["collision_units"].has(target):
				result["collision_units"].append(target)
			if collision_damage > 0:
				_apply_collision_damage(caster, target, collision_damage)
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
		journal.append({
			"unit": target,
			"from": from_pos,
			"to": landed_pos,
			"collision": had_collision,
			"collision_units": result["collision_units"].duplicate(),
		})
		EventBus.unit_pushed.emit(target, from_pos, landed_pos, had_collision)
		DebugLogger.debug(CAT_SPELL, "%s pousse de %s a %s" % [target.unit_name, str(from_pos), str(landed_pos)])
	elif had_collision:
		result["collision"] = true
		journal.append({
			"unit": target,
			"from": from_pos,
			"to": from_pos,
			"collision": true,
			"collision_units": result["collision_units"].duplicate(),
		})
		EventBus.unit_pushed.emit(target, from_pos, from_pos, true)
	return result

# Degats de collision : applique le choc a une victime (cible poussee ou percutee).
func _apply_collision_damage(caster: Unit, victim, amount: int) -> void:
	if victim == null or not victim.is_alive:
		return
	victim.take_damage(amount, caster, Spell.DamageType.PHYSICAL, Spell.Element.NONE)
	EventBus.collision_impact.emit(caster, victim, amount)
	DebugLogger.debug(CAT_SPELL, "Collision : %s subit %d" % [victim.unit_name, amount])

# Attire la cible VERS le lanceur (Crochet). S'arrete avant le lanceur / obstacle.
func _pull_unit(caster: Unit, target: Unit, cells: int, journal: Array = []) -> Dictionary:
	var result := { "pushed": false, "collision": false, "pushed_away_from_ally": false, "landed_on_terrain": false }
	if cells <= 0 or target == null:
		return result
	cells = target.reduce_forced_movement(cells)
	if cells <= 0:
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
		journal.append({ "unit": target, "from": from_pos, "to": landed_pos, "collision": false })
		EventBus.unit_pushed.emit(target, from_pos, landed_pos, false)
		DebugLogger.debug(CAT_SPELL, "%s attire %s en %s" % [caster.unit_name, target.unit_name, str(landed_pos)])
	return result

func _teleport_behind_target(caster: Unit, target: Unit, journal: Array = []) -> bool:
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
	journal.append({ "unit": caster, "from": from_pos, "to": destination, "collision": false })
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

func _has_status(unit: Unit, status_id: StringName) -> bool:
	if unit == null or not unit.has_method("get_active_statuses"):
		return false
	if status_id == &"":
		return false
	for entry in unit.get_active_statuses():
		var sd: StatusData = entry.get("data")
		if sd != null and sd.get_effective_status_id() == status_id:
			return true
	return false

# L'IA et le cast utilisent le même garde-fou de ressources.
func can_afford(caster: Unit, spell: Spell) -> bool:
	if caster == null or spell == null:
		return false
	return caster.can_use_spell(spell)


func can_cast(caster: Unit, spell: Spell, cell: Vector2i) -> bool:
	return caster != null \
		and spell != null \
		and caster.can_use_spell(spell) \
		and is_valid_target(caster, spell, cell) \
		and _special_condition_failure(caster, spell) == &""


func _special_condition_failure(caster: Unit, spell: Spell) -> StringName:
	if not spell.is_delayed():
		return &""
	if not caster.pending_ability.is_empty():
		return &"pending_ability"
	if not spell.is_summon():
		return &""
	if spell.summon_unit_data == null:
		return &"summon_data"
	if _encounter_runtime_state != null:
		var encounter_failure := _encounter_runtime_state.can_prepare_summon(
			caster,
			spell,
			_grid.count_living_in_team(caster.team),
		)
		if encounter_failure != &"":
			return encounter_failure
	if spell.condition_hp_at_or_below >= 0 \
			and caster.current_hp > spell.condition_hp_at_or_below:
		return &"hp_condition"
	if _living_summon_cap(spell) > 0 \
			and _grid.count_living_in_team(caster.team) >= _living_summon_cap(spell):
		return &"team_limit"
	if spell.requires_absent_unit_id != &"" and (
		_grid.has_living_unit_id(caster.team, spell.requires_absent_unit_id)
		or _grid.has_pending_summon_unit_id(caster.team, spell.requires_absent_unit_id)
	):
		return &"required_unit_present"
	return &""


func _prepare_delayed_resolution(ctx: CastContext) -> void:
	var caster: Unit = ctx.caster
	var spell: Spell = ctx.spell
	if spell.is_summon() and _encounter_runtime_state != null:
		_encounter_runtime_state.commit_prepared_summon(caster, spell)
	caster.pending_ability = {
		"spell": spell,
		"cell": ctx.cell,
		"target": ctx.primary_target,
		"prepared_activation": caster.activation_index,
		"source_ability_id": spell.get_effective_spell_id(),
	}
	ctx.report["telegraphed"] = true
	ctx.report["delayed"] = true
	var payload := {
		"cell": ctx.cell,
		"target": ctx.primary_target,
		"label": spell.telegraph_label,
		"color": spell.telegraph_color,
		"resolution": spell.delayed_resolution,
	}
	EventBus.ability_telegraphed.emit(caster, spell, payload)
	if spell.is_summon():
		EventBus.summon_telegraphed.emit(caster, spell, ctx.cell)


func resolve_pending_activation(
		caster: Unit,
		all_units: Array = [],
		turn_queue = null,
		on_spawn: Callable = Callable()
	) -> Dictionary:
	var result := {
		"had_pending": false,
		"resolved": false,
		"blocked": false,
		"consume_activation": false,
		"summoned_unit": null,
		"reason": &"",
	}
	if caster == null or caster.pending_ability.is_empty():
		return result
	result["had_pending"] = true
	var pending := caster.pending_ability.duplicate()
	caster.pending_ability.clear()
	if _encounter_runtime_state != null:
		_encounter_runtime_state.clear_pending(caster)
	EventBus.telegraph_cleared.emit(caster)
	var spell := pending.get("spell") as Spell
	var cell: Vector2i = pending.get("cell", Vector2i(-1, -1))
	if spell == null or not caster.is_alive:
		result["blocked"] = true
		result["reason"] = &"caster_dead"
		EventBus.pending_ability_cancelled.emit(caster, pending, result["reason"])
		return result
	if spell.delayed_resolution == Spell.DelayedResolution.STRIKE_AND_PUSH:
		result["consume_activation"] = spell.consumes_activation_on_resolution
		caster.activation_consumed = bool(result["consume_activation"])
		if caster.activation_consumed:
			caster.current_ap = 0
			caster.current_mp = 0
			EventBus.ap_changed.emit(caster, caster.current_ap, caster.max_ap.get_int())
		var target := pending.get("target") as Unit
		if target == null or not target.is_alive \
				or not _grid.are_adjacent(caster.grid_pos, target.grid_pos):
			result["blocked"] = true
			result["reason"] = &"target_not_adjacent"
			EventBus.pending_ability_blocked.emit(caster, spell, result["reason"])
			return result
		target.take_damage(spell.damage, caster, spell.damage_type, spell.element)
		if target.is_alive and spell.push_distance > 0:
			_push_unit(caster, target, spell.push_distance)
		result["resolved"] = true
		EventBus.pending_ability_resolved.emit(caster, spell, result)
		return result
	if spell.delayed_resolution != Spell.DelayedResolution.SUMMON:
		result["blocked"] = true
		result["reason"] = &"unsupported_resolution"
		return result
	var failure := &""
	if not _grid.is_valid(cell) or not _grid.is_walkable(cell) or _grid.has_unit(cell):
		failure = &"cell_blocked"
	elif _living_summon_cap(spell) > 0 \
			and _grid.count_living_in_team(caster.team) >= _living_summon_cap(spell):
		failure = &"team_limit"
	elif spell.requires_absent_unit_id != &"" \
			and _grid.has_living_unit_id(caster.team, spell.requires_absent_unit_id):
		failure = &"required_unit_present"
	if failure != &"":
		result["blocked"] = true
		result["reason"] = failure
		EventBus.pending_ability_blocked.emit(caster, spell, failure)
		EventBus.summon_blocked.emit(caster, spell, cell, failure)
		return result
	var summoned := Unit.from_data(spell.summon_unit_data)
	if spell.summon_starting_hp > 0:
		summoned.current_hp = mini(spell.summon_starting_hp, summoned.max_hp.get_int())
	for spell_id_value in spell.summon_initial_cooldowns:
		summoned.set_initial_spell_cooldown(
			StringName(spell_id_value),
			int(spell.summon_initial_cooldowns[spell_id_value])
		)
	if not _grid.place_unit(summoned, cell):
		result["blocked"] = true
		result["reason"] = &"placement_failed"
		EventBus.summon_blocked.emit(caster, spell, cell, result["reason"])
		return result
	if not all_units.has(summoned):
		all_units.append(summoned)
	if turn_queue != null and turn_queue.has_method("add_unit"):
		turn_queue.add_unit(summoned)
	if on_spawn.is_valid():
		on_spawn.call(summoned)
	result["resolved"] = true
	result["summoned_unit"] = summoned
	EventBus.summon_resolved.emit(
		caster,
		summoned,
		cell,
		spell.get_effective_spell_id()
	)
	EventBus.pending_ability_resolved.emit(caster, spell, result)
	return result


func cancel_pending_for_unit(caster: Unit, reason: StringName = &"cancelled") -> void:
	if caster == null:
		return
	if _encounter_runtime_state != null:
		_encounter_runtime_state.clear_pending(caster)
	if caster.pending_ability.is_empty():
		return
	var pending := caster.pending_ability.duplicate()
	var spell := pending.get("spell") as Spell
	caster.pending_ability.clear()
	EventBus.pending_ability_cancelled.emit(caster, pending, reason)
	if spell != null and spell.is_summon():
		EventBus.summon_cancelled.emit(
			caster,
			spell,
			pending.get("cell", Vector2i(-1, -1)),
			reason,
		)
	EventBus.telegraph_cleared.emit(caster)


func _living_summon_cap(spell: Spell) -> int:
	if _encounter_runtime_state != null \
			and _encounter_runtime_state.definition != null:
		return _encounter_runtime_state.definition.living_enemy_cap
	return spell.summon_max_living_team if spell != null else 0

# ============================================================
# LE PIPELINE DE CAST
# ============================================================

func cast(caster: Unit, spell: Spell, cell: Vector2i) -> Dictionary:
	return resolve_cast(begin_cast(caster, spell, cell))


## Valide et engage les couts au release, sans appliquer les impacts.
## Le CastContext retourne est ensuite resolu exactement une fois par resolve_cast().
func begin_cast(
		caster: Unit,
		spell: Spell,
		cell: Vector2i
	) -> CastContext:
	var ctx := CastContext.new()
	_cast_sequence += 1
	ctx.cast_id = StringName("cast_%06d" % _cast_sequence)
	ctx.action_id = ctx.cast_id
	ctx.caster = caster
	ctx.spell = spell
	ctx.cell = cell
	ctx.grid = _grid
	ctx.terrain = _terrain
	if caster == null or spell == null:
		ctx.failed = true
		ctx.report = _failed_report(caster, spell, cell, "arguments")
		return ctx
	if not caster.can_afford_spell_resources(spell):
		ctx.failed = true
		ctx.report = _failed_report(caster, spell, cell, "pa")
		return ctx
	if not caster.can_use_spell(spell):
		ctx.failed = true
		ctx.report = _failed_report(caster, spell, cell, "availability")
		return ctx
	if not is_valid_target(caster, spell, cell):
		ctx.failed = true
		ctx.report = _failed_report(caster, spell, cell, "target")
		return ctx
	var special_reason := _special_condition_failure(caster, spell)
	if special_reason != &"":
		ctx.failed = true
		ctx.report = _failed_report(caster, spell, cell, String(special_reason))
		return ctx
	ctx.modifiers = _gather_modifiers(caster, spell)

	if not _resolve_costs(ctx):
		return ctx
	caster.mark_spell_used(spell)
	_run_hook(ctx, "on_costs_resolved")
	ctx.costs_committed = true
	return ctx


## Termine un cast engage. Un second appel retourne le meme rapport sans
## reappliquer degats, mouvements, XP ou evenements.
func resolve_cast(ctx: CastContext) -> Dictionary:
	if ctx == null:
		return _failed_report(null, null, Vector2i.ZERO, "context")
	if ctx.failed or ctx.resolved:
		return ctx.report
	ctx.resolved = true

	_resolve_targets(ctx)
	if ctx.spell.is_delayed():
		_prepare_delayed_resolution(ctx)
		_finalize_effectiveness(ctx)
		EventBus.spell_cast.emit(ctx.caster, ctx.spell, ctx.report)
		return ctx.report
	_run_hook(ctx, "on_area_resolved")
	_run_hook(ctx, "on_targets_resolved")
	_run_hook(ctx, "on_targets_finalized")

	_resolve_impacts(ctx)
	_run_hook(ctx, "on_damage_resolved")
	_run_hook(ctx, "on_terrain_resolved")

	_resolve_movement(ctx)
	_run_hook(ctx, "on_movement_resolved")

	_log_cast_resolution(ctx)
	_run_hook(ctx, "on_cast_complete")
	_finalize_effectiveness(ctx)

	EventBus.spell_cast.emit(ctx.caster, ctx.spell, ctx.report)
	return ctx.report

# Les modifiers actifs viennent des données du sort et de la progression.
func _gather_modifiers(caster: Unit, spell: Spell) -> Array:
	var mods: Array = []
	if spell != null:
		for m in spell.modifiers:
			if m is SpellModifier and m.applies_to(spell) and not mods.has(m):
				mods.append(m)
	if caster != null:
		for m in caster.get_progression_spell_modifiers():
			if m is SpellModifier and m.applies_to(spell) and not mods.has(m):
				mods.append(m)
		for m in caster.get_equipment_spell_modifiers():
			if m is SpellModifier and m.applies_to(spell) and not mods.has(m):
				mods.append(m)
	return mods

func _run_hook(ctx: CastContext, hook: String) -> void:
	for m in ctx.modifiers:
		m.call(hook, ctx)

# --- Étape 1 : coût en PA. ---
# Renvoie false (et pose le rapport d'échec) si le lanceur ne peut pas payer.
func _resolve_costs(ctx: CastContext) -> bool:
	var caster: Unit = ctx.caster
	var spell: Spell = ctx.spell
	ctx.ap_cost = caster.get_spell_ap_cost(spell)
	if caster.current_ap < ctx.ap_cost:
		DebugLogger.info(CAT_SPELL, "%s ne peut pas lancer %s (PA insuffisants : %d/%d)" % [caster.unit_name, spell.spell_name, caster.current_ap, ctx.ap_cost])
		ctx.failed = true
		ctx.report = _failed_report(caster, spell, ctx.cell, "pa")
		return false
	caster.spend_ap(ctx.ap_cost)
	DebugLogger.info(CAT_SPELL, "%s lance %s sur %s" % [caster.unit_name, spell.spell_name, str(ctx.cell)], {
		"PA": ctx.ap_cost, "portee": get_effective_spell_range(caster, spell),
		"zone": spell.aoe_size if spell.aoe_shape != Spell.AoeShape.SINGLE else 0,
	})
	return true

# --- Étape 2 : cibles. Squelette du rapport (contrat : clés figées) et
# cellules de la zone d'effet. Les lectures tactiques (allié adjacent, angle)
# se font ICI, AVANT tout effet : c'est l'état du terrain au moment du cast.
func _resolve_targets(ctx: CastContext) -> void:
	ctx.state_before_by_unit.clear()
	for unit_value in _grid.get_units():
		var snapshot_unit := unit_value as Unit
		if snapshot_unit != null:
			ctx.state_before_by_unit[snapshot_unit] = _snapshot_unit_effect_state(
				snapshot_unit
			)
	ctx.report = {
		"caster": ctx.caster, "spell": ctx.spell, "cell": ctx.cell,
		"affected_units": [], "damaged_enemies": [], "healed_units": [], "shielded_units": [],
		"healing_by_unit": {},
		"hp_damage_total": 0, "shield_absorbed_total": 0,
		"healing_total": 0, "shield_increase_total": 0,
		"status_changed_units": [], "status_change_count": 0,
		"controlled_enemies": [], "drained_units": [], "terrain_changed": [],
		"crits": [], "dodges": [], "ally_adjacent_to_caster": _has_ally_adjacent(ctx.caster),
		"angle_advantage": _has_angle_advantage(ctx.caster, ctx.cell), "pushed": false,
		"collision": false, "pushed_away_from_ally": false, "landed_on_terrain": false,
	}
	ctx.affected_cells = get_aoe_cells(
		ctx.spell,
		ctx.cell,
		ctx.caster.grid_pos
	)
	ctx.primary_target = _grid.get_unit(ctx.cell) as Unit

# --- Étape 3 : impacts. Par cellule : effets sur l'unité PUIS terrains du
# sort — l'ordre par cellule est préservé (une réaction de terrain peut
# blesser ; son ordre relatif aux dégâts des cellules suivantes compte). ---
func _resolve_impacts(ctx: CastContext) -> void:
	for sequence_index in ctx.affected_cells.size():
		var target_cell = ctx.affected_cells[sequence_index]
		var target = _grid.get_unit(target_cell)
		if target != null and not (
				ctx.spell.exclude_caster_from_area_effects
				and target == ctx.caster
			):
			_resolve_unit_impact(ctx, target, target_cell, sequence_index)
		_resolve_cell_terrain(ctx, target_cell)

# Effets directs du sort sur UNE unité touchée : dégâts, soins, statuts,
# provocation, drains, bouclier. Alimente les listes du rapport.
func _resolve_unit_impact(
		ctx: CastContext,
		target,
		target_cell: Vector2i,
		sequence_index: int = 0
	) -> void:
	var caster: Unit = ctx.caster
	var spell: Spell = ctx.spell
	var report: Dictionary = ctx.report
	var affected := false
	var cell_bonus := int(ctx.damage_bonus_by_cell.get(target_cell, 0))
	if spell.deals_damage() or cell_bonus != 0:
		var hp_before_damage: int = target.current_hp
		var shield_before_damage: int = target.current_shield
		var base_dmg := spell.damage + cell_bonus
		var has_bonus_status := _has_status(target, spell.bonus_damage_status_id)
		if spell.bonus_requires_linked_status_source:
			has_bonus_status = caster.target_has_linked_source_status(
				target,
				spell.bonus_damage_status_id
			)
		if spell.bonus_damage_if_marked > 0 and has_bonus_status:
			base_dmg += spell.bonus_damage_if_marked
		var impact_id := StringName("%s:%03d" % [ctx.cast_id, sequence_index])
		var damage_result = target.take_damage(
			base_dmg,
			caster,
			spell.damage_type,
			spell.element,
			{
				"bonus_crit_chance": spell.crit_chance,
				"action_id": ctx.action_id,
				"cast_id": ctx.cast_id,
				"impact_id": impact_id,
				"sequence_index": sequence_index,
				"ability_id": spell.get_effective_spell_id(),
			}
		)
		if damage_result != null:
			ctx.damage_result_by_unit[target] = damage_result
			if damage_result.is_crit:
				report["crits"].append(target)
			if damage_result.dodged:
				report["dodges"].append(target)
			var hp_loss := maxi(0, hp_before_damage - target.current_hp)
			var shield_loss := maxi(0, shield_before_damage - target.current_shield)
			report["hp_damage_total"] += hp_loss
			report["shield_absorbed_total"] += shield_loss
			if hp_loss + shield_loss > 0 and target.team != caster.team \
					and not report["damaged_enemies"].has(target):
				report["damaged_enemies"].append(target)
		affected = true
	if spell.is_healing():
		var before_hp: int = target.current_hp
		var heal_amount := spell.heal + int(ctx.heal_bonus_by_unit.get(target, 0))
		if spell.heal_bonus_effect_name.strip_edges() != "":
			var heal_effect := _terrain.get_effect_data(target.grid_pos)
			if heal_effect != null and heal_effect.effect_name == spell.heal_bonus_effect_name:
				heal_amount = maxi(0, int(round(float(heal_amount) * spell.heal_bonus_multiplier)))
		target.heal(heal_amount, ctx.caster, {
			"action_id": ctx.action_id,
			"cast_id": ctx.cast_id,
			"impact_id": StringName("%s:%03d" % [ctx.cast_id, sequence_index]),
			"sequence_index": sequence_index,
			"ability_id": spell.get_effective_spell_id(),
		})
		report["healing_by_unit"][target] = target.current_hp - before_hp
		report["healing_total"] += maxi(0, target.current_hp - before_hp)
		if target.current_hp > before_hp and not report["healed_units"].has(target):
			report["healed_units"].append(target)
		affected = true
	if spell.applied_status != null:
		var status_source := caster if spell.status_source_scoped else null
		var status_before := _status_state_signature(
			target,
			spell.applied_status.get_effective_status_id(),
			status_source,
		)
		if spell.replaces_same_source_status:
			for unit_value in _grid.get_units():
				var existing_unit := unit_value as Unit
				if existing_unit != null:
					existing_unit.remove_status(
						spell.applied_status.get_effective_status_id(),
						caster,
						true
					)
		target.apply_status(
			spell.applied_status,
			status_source
		)
		_register_status_change(
			report,
			target,
			status_before,
			_status_state_signature(
				target,
				spell.applied_status.get_effective_status_id(),
				status_source,
			),
		)
		affected = true
	for extra_status_value in ctx.additional_statuses_by_unit.get(target, []):
		var extra_status := extra_status_value as StatusData
		if extra_status != null:
			var extra_before := _status_state_signature(
				target,
				extra_status.get_effective_status_id(),
				null,
			)
			target.apply_status(extra_status)
			_register_status_change(
				report,
				target,
				extra_before,
				_status_state_signature(
					target,
					extra_status.get_effective_status_id(),
					null,
				),
			)
			affected = true
	if spell.forces_taunt and target.team != caster.team:
		target.apply_taunt(caster, spell.taunt_duration)
		if not report["controlled_enemies"].has(target):
			report["controlled_enemies"].append(target)
		affected = true
	if target.team != caster.team and spell.ap_drain > 0:
		var before_ap_modifier: int = target.next_turn_ap_modifier
		if spell.ap_drain > 0:
			# Drain de PA : ampute le budget du PROCHAIN tour de la cible.
			target.next_turn_ap_modifier -= spell.ap_drain
			DebugLogger.debug(CAT_SPELL, "%s draine %d PA a %s (prochain tour)" % [caster.unit_name, spell.ap_drain, target.unit_name])
		if target.next_turn_ap_modifier != before_ap_modifier \
				and not report["drained_units"].has(target):
			report["drained_units"].append(target)
		affected = true
	var raw_shield := spell.shield_grant \
		+ int(ctx.additional_shield_by_unit.get(target, 0))
	if raw_shield > 0 and target.team == caster.team:
		var before_shield: int = target.current_shield
		target.add_shield(raw_shield, ctx.caster, {
			"action_id": ctx.action_id,
			"cast_id": ctx.cast_id,
			"impact_id": StringName("%s:%03d" % [ctx.cast_id, sequence_index]),
			"sequence_index": sequence_index,
			"ability_id": spell.get_effective_spell_id(),
		})
		report["shield_increase_total"] += maxi(0, target.current_shield - before_shield)
		if target.current_shield > before_shield and not report["shielded_units"].has(target):
			report["shielded_units"].append(target)
		affected = true
	if affected and not report["affected_units"].has(target):
		report["affected_units"].append(target)

# Terrain porté par le sort, posé sur une cellule.
func _resolve_cell_terrain(ctx: CastContext, target_cell: Vector2i) -> void:
	var spell: Spell = ctx.spell
	var terrain_payloads: Array = []
	if spell.has_terrain_effect():
		var terrain_payload := spell.terrain_effect
		if not ctx.skill_tree_terrain_spec.is_empty():
			terrain_payload = spell.terrain_effect.duplicate(true) as TerrainEffectData
			terrain_payload.duration = maxi(
				0,
				terrain_payload.duration + int(
					ctx.skill_tree_terrain_spec.get("duration_delta", 0)
				)
			)
			terrain_payload.damage = maxi(
				0,
				terrain_payload.damage + int(
					ctx.skill_tree_terrain_spec.get("damage_delta", 0)
				)
			)
		terrain_payloads.append(terrain_payload)
	for terrain_data in terrain_payloads:
		var terrain_result: Dictionary = _terrain.place_effect(target_cell, terrain_data, ctx.caster, spell)
		if terrain_result.get("changed", false) and not ctx.report["terrain_changed"].has(target_cell):
			ctx.report["terrain_changed"].append(target_cell)

# --- Étape 4 : déplacements forcés. La Force scale multiplicativement
# poussée, attraction et dégâts de collision/souffle. ---
func _resolve_movement(ctx: CastContext) -> void:
	var caster: Unit = ctx.caster
	var spell: Spell = ctx.spell
	var report: Dictionary = ctx.report
	var force_mult := caster.get_force_multiplier()
	var eff_push := int(round(spell.push_distance * force_mult))
	var eff_collision := int(round(spell.collision_damage * force_mult))
	var eff_pull := int(round(spell.pull_distance * force_mult))
	if spell.push_all_adjacent and spell.push_distance > 0:
		# On recense d'abord les ennemis entasses autour du lanceur : le souffle
		# scale avec leur nombre (recompense d'avoir regroupe avant de detoner).
		var cluster: Array = []
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var adj = _grid.get_unit(caster.grid_pos + dir)
			if adj != null and adj.team != caster.team:
				cluster.append(adj)
		var blast: int = int(round(spell.cluster_bonus_damage * cluster.size() * force_mult))
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
			var adjacent_push = _push_unit(caster, adjacent_target, eff_push, eff_collision, ctx.movement)
			report["pushed"] = report["pushed"] or adjacent_push["pushed"]
			report["collision"] = report["collision"] or adjacent_push["collision"]
			report["pushed_away_from_ally"] = report["pushed_away_from_ally"] or adjacent_push["pushed_away_from_ally"]
			report["landed_on_terrain"] = report["landed_on_terrain"] or adjacent_push.get("landed_on_terrain", false)
			if adjacent_push["pushed"] and not report["affected_units"].has(adjacent_target):
				report["affected_units"].append(adjacent_target)
	elif spell.push_distance > 0 or not ctx.push_distance_override_by_unit.is_empty():
		var push_targets: Array = []
		if spell.push_affected_units:
			for affected_cell in ctx.affected_cells:
				var affected_target = _grid.get_unit(affected_cell)
				if affected_target != null \
						and affected_target.team != caster.team \
						and affected_target.is_alive \
						and not push_targets.has(affected_target):
					push_targets.append(affected_target)
		else:
			var selected_target = ctx.primary_target
			if selected_target != null and selected_target.team != caster.team:
				push_targets.append(selected_target)
		for push_target in push_targets:
			var resolved_push_distance := eff_push
			if ctx.push_distance_override_by_unit.has(push_target):
				resolved_push_distance = maxi(
					0,
					int(ctx.push_distance_override_by_unit[push_target])
				)
			var push_result = _push_unit(
				caster,
				push_target,
				resolved_push_distance,
				eff_collision,
				ctx.movement
			)
			report["pushed"] = report["pushed"] or push_result["pushed"]
			report["collision"] = report["collision"] or push_result["collision"]
			report["pushed_away_from_ally"] = (
				report["pushed_away_from_ally"]
				or push_result["pushed_away_from_ally"]
			)
			report["landed_on_terrain"] = (
				report["landed_on_terrain"]
				or push_result.get("landed_on_terrain", false)
			)
	if spell.pull_distance > 0:
		var pull_target = _grid.get_unit(ctx.cell)
		if pull_target != null and pull_target.team != caster.team:
			var pull_result = _pull_unit(caster, pull_target, eff_pull, ctx.movement)
			report["pushed"] = report["pushed"] or pull_result["pushed"]
			report["landed_on_terrain"] = report["landed_on_terrain"] or pull_result.get("landed_on_terrain", false)
	if spell.teleport_behind_target:
		var teleport_target = _grid.get_unit(ctx.cell)
		if teleport_target != null and teleport_target.team != caster.team and _teleport_behind_target(caster, teleport_target, ctx.movement):
			report["angle_advantage"] = true
	for push_target_value in ctx.additional_push_by_unit:
		var push_target := push_target_value as Unit
		if push_target == null or not push_target.is_alive or push_target.team == caster.team:
			continue
		if ctx.push_distance_override_by_unit.has(push_target):
			continue
		var push_cells := maxi(0, int(ctx.additional_push_by_unit[push_target_value]))
		var extra_push := _push_unit(caster, push_target, push_cells, 0, ctx.movement)
		report["pushed"] = report["pushed"] or extra_push["pushed"]
		report["collision"] = report["collision"] or extra_push["collision"]
		report["pushed_away_from_ally"] = report["pushed_away_from_ally"] or extra_push["pushed_away_from_ally"]
		report["landed_on_terrain"] = report["landed_on_terrain"] or extra_push.get("landed_on_terrain", false)
		if extra_push["pushed"] and not report["affected_units"].has(push_target):
			report["affected_units"].append(push_target)

# --- Étape 5 : journalisation du résultat. ---
func _status_state_signature(
		unit: Unit,
		status_id: StringName,
		source: Unit
	) -> Dictionary:
	if unit == null or status_id == &"":
		return {}
	for entry_value in unit.get_active_statuses():
		var entry := entry_value as Dictionary
		var data := entry.get("data") as StatusData
		if data == null or data.get_effective_status_id() != status_id \
				or (source != null and entry.get("source") != source):
			continue
		return {
			"remaining": int(entry.get("remaining", 0)),
			"charges": int(entry.get("charges", 0)),
			"damage_per_turn": data.damage_per_turn,
			"heal_per_turn": data.heal_per_turn,
			"mp_reduction": data.mp_reduction,
			"ap_reduction": data.ap_reduction,
			"outgoing_damage_modifier": data.outgoing_damage_modifier,
			"stat_modifiers": data.stat_modifiers.duplicate(true),
		}
	return {}


func _register_status_change(
		report: Dictionary,
		unit: Unit,
		before: Dictionary,
		after: Dictionary
	) -> void:
	if before == after or after.is_empty():
		return
	report["status_change_count"] = int(report.get("status_change_count", 0)) + 1
	var changed_units: Array = report.get("status_changed_units", [])
	if unit != null and not changed_units.has(unit):
		changed_units.append(unit)
	report["status_changed_units"] = changed_units


func _snapshot_unit_effect_state(unit: Unit) -> Dictionary:
	var statuses: Array[Dictionary] = []
	for entry_value in unit.get_active_statuses():
		var entry := entry_value as Dictionary
		var data := entry.get("data") as StatusData
		var source := entry.get("source") as Unit
		if data == null:
			continue
		statuses.append({
			"id": data.get_effective_status_id(),
			"source": source.get_runtime_stable_id() if source != null else "",
			"remaining": int(entry.get("remaining", 0)),
			"charges": int(entry.get("charges", 0)),
			"damage_per_turn": data.damage_per_turn,
			"heal_per_turn": data.heal_per_turn,
			"mp_reduction": data.mp_reduction,
			"ap_reduction": data.ap_reduction,
			"outgoing_damage_modifier": data.outgoing_damage_modifier,
			"stat_modifiers": data.stat_modifiers.duplicate(true),
		})
	statuses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var key_a := "%s:%s" % [str(a.id), str(a.source)]
		var key_b := "%s:%s" % [str(b.id), str(b.source)]
		return key_a < key_b
	)
	return {
		"hp": unit.current_hp,
		"shield": unit.current_shield,
		"position": unit.grid_pos,
		"alive": unit.is_alive,
		"statuses": statuses,
		"next_turn_ap_modifier": unit.next_turn_ap_modifier,
		"next_turn_mp_modifier": (
			unit.next_turn_mp_bonus - unit.next_turn_mp_penalty
		),
		"taunt_source": (
			unit.taunt_source.get_runtime_stable_id()
			if unit.taunt_source is Unit else ""
		),
		"taunt_turns": unit.taunt_turns,
	}


func _finalize_effectiveness(ctx: CastContext) -> void:
	var report := ctx.report
	var reasons: Array[StringName] = []
	if int(report.get("hp_damage_total", 0)) > 0:
		reasons.append(&"hp_damage")
	if int(report.get("shield_absorbed_total", 0)) > 0:
		reasons.append(&"shield_absorbed")
	if int(report.get("healing_total", 0)) > 0 \
			or not (report.get("healed_units", []) as Array).is_empty():
		reasons.append(&"healing")
	if int(report.get("shield_increase_total", 0)) > 0 \
			or not (report.get("shielded_units", []) as Array).is_empty():
		reasons.append(&"shield_increased")
	if int(report.get("status_change_count", 0)) > 0:
		reasons.append(&"status_changed")
	if not (report.get("controlled_enemies", []) as Array).is_empty():
		reasons.append(&"control")
	if not (report.get("drained_units", []) as Array).is_empty():
		reasons.append(&"resource_changed")
	if not (report.get("terrain_changed", []) as Array).is_empty():
		reasons.append(&"terrain_changed")
	if not ctx.movement.is_empty():
		reasons.append(&"movement")
	if bool(report.get("telegraphed", false)):
		reasons.append(&"tactical_state_prepared")
	for unit_value in ctx.state_before_by_unit:
		var unit := unit_value as Unit
		if unit == null:
			continue
		var before := ctx.state_before_by_unit[unit] as Dictionary
		var after := _snapshot_unit_effect_state(unit)
		if int(after.get("hp", 0)) < int(before.get("hp", 0)) \
				and not reasons.has(&"hp_damage"):
			reasons.append(&"hp_damage")
		elif int(after.get("hp", 0)) > int(before.get("hp", 0)) \
				and not reasons.has(&"healing"):
			reasons.append(&"healing")
		if int(after.get("shield", 0)) < int(before.get("shield", 0)) \
				and not reasons.has(&"shield_absorbed"):
			reasons.append(&"shield_absorbed")
		elif int(after.get("shield", 0)) > int(before.get("shield", 0)) \
				and not reasons.has(&"shield_increased"):
			reasons.append(&"shield_increased")
		if after.get("statuses", []) != before.get("statuses", []) \
				and not reasons.has(&"status_changed"):
			reasons.append(&"status_changed")
		if after.get("position") != before.get("position") \
				and not reasons.has(&"movement"):
			reasons.append(&"movement")
		if (after.get("next_turn_ap_modifier", 0) \
				!= before.get("next_turn_ap_modifier", 0) \
				or after.get("next_turn_mp_modifier", 0) \
				!= before.get("next_turn_mp_modifier", 0)) \
				and not reasons.has(&"resource_changed"):
			reasons.append(&"resource_changed")
		if (after.get("taunt_source", "") != before.get("taunt_source", "") \
				or after.get("taunt_turns", 0) != before.get("taunt_turns", 0)) \
				and not reasons.has(&"control"):
			reasons.append(&"control")
	report["effect_reasons"] = reasons
	report["effective_cast"] = not reasons.is_empty()
	report["did_change_combat_state"] = report["effective_cast"]
	report["movement_count"] = ctx.movement.size()
	ctx.report = report


func _log_cast_resolution(ctx: CastContext) -> void:
	var report: Dictionary = ctx.report
	var spell: Spell = ctx.spell
	var hit_names: Array = []
	for u in report["affected_units"]:
		hit_names.append(u.unit_name)
	DebugLogger.debug(CAT_SPELL, "%s : %d unite(s), %d terrain(s)" % [spell.spell_name, report["affected_units"].size(), report["terrain_changed"].size()], { "cibles": hit_names })

func _failed_report(caster: Unit, spell: Spell, cell: Vector2i, reason: String) -> Dictionary:
	return {
		"caster": caster, "spell": spell, "cell": cell, "failed": true, "reason": reason,
		"affected_units": [], "damaged_enemies": [], "healed_units": [], "shielded_units": [],
		"healing_by_unit": {},
		"hp_damage_total": 0, "shield_absorbed_total": 0,
		"healing_total": 0, "shield_increase_total": 0,
		"status_changed_units": [], "status_change_count": 0,
		"controlled_enemies": [], "drained_units": [], "terrain_changed": [], "crits": [], "dodges": [],
		"effective_cast": false, "did_change_combat_state": false,
		"effect_reasons": [], "movement_count": 0,
	}
