# Point unique de validation des PA, du ciblage et de résolution des sorts.

class_name SpellCaster
extends RefCounted

const LogDefinitions = preload("res://debug/log_definitions.gd")

var _grid: GridData
var _pathfinder: Pathfinder
var _terrain: TerrainEffects
var _encounter_runtime_state: EncounterRuntimeState = null
var _action_classification_registry := CombatActionClassificationRegistry.new()
var _cast_sequence := 0

const CAT_SPELL: LogDefinitions.LogCategory = LogDefinitions.LogCategory.SPELL

func _init(grid: GridData, pathfinder: Pathfinder, terrain: TerrainEffects) -> void:
	_grid = grid
	_pathfinder = pathfinder
	_terrain = terrain


func set_encounter_runtime_state(state: EncounterRuntimeState) -> void:
	_encounter_runtime_state = state


func set_action_classification_catalog(
		catalog: CombatActionClassificationCatalogData
	) -> bool:
	_action_classification_registry = CombatActionClassificationRegistry.new()
	return catalog != null and _action_classification_registry.initialize(catalog)


func get_action_classification(spell: Spell) -> StringName:
	return _action_classification_registry.classification_for_spell(spell)

func get_targetable_cells(caster: Unit, spell: Spell) -> Array:
	var result: Array = []
	if caster == null or spell == null or _grid == null:
		return result
	if spell.is_self_only():
		return (
			[caster.grid_pos]
			if _modifier_target_failure(caster, spell, caster.grid_pos) == &""
			else []
		)
	for x in _grid.cols:
		for y in _grid.rows:
			var pos = Vector2i(x, y)
			if _is_base_valid_target(caster, spell, pos) \
					and _modifier_target_failure(caster, spell, pos) == &"":
				result.append(pos)
	return result


func get_effective_spell_range(caster: Unit, spell: Spell) -> int:
	if caster == null or spell == null:
		return 0
	var effective_range := spell.spell_range
	if caster.mastery_combat_adapter != null:
		effective_range = int(caster.mastery_combat_adapter.spell_profile(caster, spell).maximum_range)
	for modifier in _gather_modifiers(caster, spell):
		if modifier is MasterySpellModifierData and caster.mastery_combat_adapter != null:
			continue
		effective_range += int(modifier.get_range_bonus(caster, spell))
	if caster.mastery_combat_adapter != null:
		effective_range += caster.mastery_combat_adapter.range_bonus(caster, spell)
	return maxi(0, effective_range)


## Metadonnees de presentation derivees des memes modificateurs que le cast.
## Cela permet d'animer une ruee sans deviner son identite depuis un nom de sort.
func spell_moves_caster(caster: Unit, spell: Spell) -> bool:
	if caster == null or spell == null:
		return false
	if spell.caster_movement != Spell.CasterMovement.NONE:
		return true
	for modifier in _gather_modifiers(caster, spell):
		if modifier.moves_caster_during_cast(caster, spell):
			return true
	return false


func get_effective_spell_minimum_range(caster: Unit, spell: Spell) -> int:
	if caster == null or spell == null:
		return 0
	var effective_minimum := maxi(0, spell.minimum_range)
	if caster.mastery_combat_adapter != null:
		effective_minimum = int(caster.mastery_combat_adapter.spell_profile(caster, spell).minimum_range)
	for modifier in _gather_modifiers(caster, spell):
		if modifier.ignores_minimum_range(caster, spell):
			return 0
		var override_value := int(
			modifier.get_minimum_range_override(caster, spell)
		)
		if override_value >= 0:
			effective_minimum = maxi(effective_minimum, override_value)
	if caster.mastery_combat_adapter != null:
		effective_minimum = caster.mastery_combat_adapter.minimum_range(caster, spell, effective_minimum)
	return mini(effective_minimum, get_effective_spell_range(caster, spell))

func get_aoe_cells(
		spell: Spell,
		center: Vector2i,
		origin: Vector2i = Vector2i(-1, -1)
	) -> Array:
	var result: Array = []
	var actor := _grid.get_unit(origin) as Unit if _grid != null else null
	if actor != null and actor.mastery_combat_adapter != null:
		var modified: Array = actor.mastery_combat_adapter.preview_target_cells(actor, spell, center)
		if not modified.is_empty():
			return modified
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
			return _is_valid_caster_movement_target(caster, spell, cell)
		for modifier in _gather_modifiers(caster, spell):
			if modifier.allows_free_cell_target(caster, spell):
				return true
		return false
	return false


func _is_valid_caster_movement_target(
		caster: Unit,
		spell: Spell,
		cell: Vector2i
	) -> bool:
	if spell.caster_movement == Spell.CasterMovement.NONE:
		return true
	if spell.caster_movement != Spell.CasterMovement.TARGET_CELL \
			or caster == null or not _grid.is_walkable(cell):
		return false
	if not spell.movement_requires_clear_path:
		return true
	var delta := cell - caster.grid_pos
	if delta == Vector2i.ZERO or (delta.x != 0 and delta.y != 0):
		return false
	var direction := Vector2i(signi(delta.x), signi(delta.y))
	var distance := absi(delta.x) + absi(delta.y)
	for step in range(1, distance + 1):
		var traversed_cell := caster.grid_pos + direction * step
		if not _grid.is_walkable(traversed_cell, caster):
			return false
	return true

func is_valid_target(caster: Unit, spell: Spell, cell: Vector2i) -> bool:
	return _is_base_valid_target(caster, spell, cell) \
		and _modifier_target_failure(caster, spell, cell) == &""


func _is_base_valid_target(
		caster: Unit,
		spell: Spell,
		cell: Vector2i
	) -> bool:
	if caster == null or spell == null or _grid == null:
		return false
	if spell.is_self_only():
		return cell == caster.grid_pos
	if cell == caster.grid_pos and not spell.can_target_self:
		return false
	if not _grid.is_terrain_interactable(cell):
		return false
	var origin := get_cast_origin(caster, spell)
	var distance := _grid.manhattan(origin, cell)
	if distance > get_effective_spell_range(caster, spell) \
			or distance < get_effective_spell_minimum_range(caster, spell):
		return false
	if spell.line_from_caster \
			and not _is_cardinal_line_target(origin, cell):
		return false
	if spell.needs_line_of_sight \
			and not _pathfinder.has_line_of_sight(origin, cell):
		return false
	if get_action_classification(spell) == &"PROJECTILE" and not _pathfinder.has_projectile_path(origin, cell):
		return false
	return _matches_target(caster, spell, cell)


func get_cast_origin(caster: Unit, spell: Spell) -> Vector2i:
	return caster.mastery_combat_adapter.projectile_origin(caster, spell) if caster.mastery_combat_adapter != null else caster.grid_pos


func _modifier_target_failure(
		caster: Unit,
		spell: Spell,
		cell: Vector2i
	) -> StringName:
	for modifier in _gather_modifiers(caster, spell):
		var reason: StringName = modifier.get_target_cell_failure_reason(
			caster, spell, cell, _grid
		)
		if reason != &"":
			return reason
	return &""

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
	if target.mastery_combat_adapter != null and target.mastery_combat_adapter.blocks_control(target, &"push"):
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
	if had_collision and collision_damage <= 0:
		EventBus.collision_impact.emit(caster, target, 0)
	if caster != null and (had_collision or landed_pos != from_pos):
		caster.record_target_moved_or_collided(target)
	# La cible a pu mourir d'une collision (mur/hasard) avant tout deplacement.
	if not target.is_alive:
		result["collision"] = had_collision
		return result
	if landed_pos != from_pos:
		if not _grid.relocate_unit(target, landed_pos):
			return result
		var relocation := _terrain.consume_relocation_result(target, landed_pos)
		var resolved_pos := relocation.get("destination", landed_pos) as Vector2i
		if _terrain.get_effect_data(landed_pos) != null \
				or bool(relocation.get("applied", false)) \
				or bool(relocation.get("destination_effect_applied", false)):
			result["landed_on_terrain"] = true
		result["pushed"] = true
		result["collision"] = had_collision
		result["pushed_away_from_ally"] = _pushed_away_from_ally(
			caster, from_pos, resolved_pos
		)
		journal.append({
			"unit": target,
			"from": from_pos,
			"to": resolved_pos,
			"collision": had_collision,
			"collision_units": result["collision_units"].duplicate(),
		})
		EventBus.unit_pushed.emit(target, from_pos, resolved_pos, had_collision)
		DebugLogger.debug(CAT_SPELL, "%s pousse de %s a %s" % [
			target.unit_name, str(from_pos), str(resolved_pos),
		])
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
	if target != null and target.mastery_combat_adapter != null and target.mastery_combat_adapter.blocks_control(target, &"pull"):
		return result
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
		var relocation := _terrain.consume_relocation_result(target, landed_pos)
		var resolved_pos := relocation.get("destination", landed_pos) as Vector2i
		if _terrain.get_effect_data(landed_pos) != null \
				or bool(relocation.get("applied", false)) \
				or bool(relocation.get("destination_effect_applied", false)):
			result["landed_on_terrain"] = true
		# Un deplacement force : compte comme une poussee pour la generation EXPLOIT.
		result["pushed"] = true
		journal.append({
			"unit": target, "from": from_pos, "to": resolved_pos,
			"collision": false,
		})
		EventBus.unit_pushed.emit(target, from_pos, resolved_pos, false)
		DebugLogger.debug(CAT_SPELL, "%s attire %s en %s" % [
			caster.unit_name, target.unit_name, str(resolved_pos),
		])
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
	var relocation := _terrain.consume_relocation_result(caster, destination)
	var resolved_destination := relocation.get(
		"destination", destination
	) as Vector2i
	journal.append({
		"unit": caster, "from": from_pos, "to": resolved_destination,
		"collision": false,
	})
	EventBus.unit_pushed.emit(caster, from_pos, resolved_destination, false)
	DebugLogger.debug(CAT_SPELL, "%s se replace en %s" % [
		caster.unit_name, str(resolved_destination),
	])
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
	return get_cast_failure_reason(caster, spell, cell) == &""


## Autorite unique pour la validation d'un cast. L'interface et begin_cast()
## consultent exactement les memes gardes afin qu'un sort indisponible ne
## demarre jamais une animation qui devra ensuite etre annulee.
func get_cast_failure_reason(
		caster: Unit,
		spell: Spell,
		cell: Vector2i
	) -> StringName:
	if caster == null or spell == null:
		return &"arguments"
	var availability_reason := caster.get_spell_availability_reason(spell)
	if availability_reason != &"":
		return availability_reason
	if not _is_base_valid_target(caster, spell, cell):
		return &"target"
	var modifier_failure := _modifier_target_failure(caster, spell, cell)
	if modifier_failure != &"":
		return modifier_failure
	return _special_condition_failure(caster, spell)


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
	if spell.delayed_resolution in [
		Spell.DelayedResolution.STRIKE_AND_PUSH,
		Spell.DelayedResolution.RANGED_STRIKE,
	]:
		result["consume_activation"] = spell.consumes_activation_on_resolution
		caster.activation_consumed = bool(result["consume_activation"])
		if caster.activation_consumed:
			caster.current_ap = 0
			caster.current_mp = 0
			EventBus.ap_changed.emit(caster, caster.current_ap, caster.max_ap.get_int())
		var target := pending.get("target") as Unit
		if target == null or not target.is_alive:
			result["blocked"] = true
			result["reason"] = &"target_unavailable"
			EventBus.pending_ability_blocked.emit(caster, spell, result["reason"])
			return result
		var target_still_valid := (
			_grid.are_adjacent(caster.grid_pos, target.grid_pos)
			if spell.delayed_resolution == Spell.DelayedResolution.STRIKE_AND_PUSH
			else is_valid_target(caster, spell, target.grid_pos)
		)
		if not target_still_valid:
			result["blocked"] = true
			result["reason"] = (
				&"target_not_adjacent"
				if spell.delayed_resolution == Spell.DelayedResolution.STRIKE_AND_PUSH
				else &"target_escaped_telegraph"
			)
			EventBus.pending_ability_blocked.emit(caster, spell, result["reason"])
			return result
		target.take_damage(
			spell.get_scaled_damage(caster),
			caster,
			spell.damage_type,
			spell.element,
		)
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


func cast_automatic(actor: Unit, spell: Spell, cell: Vector2i, multiplier: float, action_id: StringName) -> Dictionary:
	if actor == null or spell == null or not actor.is_alive or not is_valid_target(actor, spell, cell):
		return _failed_report(actor, spell, cell, "automatic_target")
	var ctx := CastContext.new()
	ctx.caster = actor
	ctx.spell = spell
	ctx.cell = cell
	ctx.grid = _grid
	ctx.terrain = _terrain
	ctx.cast_id = action_id
	ctx.action_id = action_id
	ctx.ap_before = actor.current_ap
	ctx.costs_committed = true
	ctx.modifiers = _gather_modifiers(actor, spell)
	ctx.set_meta("automatic_cast", true)
	ctx.set_meta("automatic_multiplier", maxf(0.0, multiplier))
	var report := resolve_cast(ctx)
	report["automatic"] = true
	report["awards_xp"] = false
	report["spends_action_points"] = false
	report["consumes_manual_spell_use"] = false
	return report


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
	ctx.ap_before = caster.current_ap if caster != null else 0
	var failure_reason := get_cast_failure_reason(caster, spell, cell)
	if failure_reason != &"":
		ctx.failed = true
		ctx.report = _failed_report(caster, spell, cell, String(failure_reason))
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
	# A committed old-form shot cannot resolve after a health-triggered form
	# change. Costs already paid remain paid; there is no duplicate refund.
	if ctx.spell != null and ctx.spell.required_combat_form != &"" \
			and (ctx.caster == null or ctx.caster.combat_form_id != ctx.spell.required_combat_form):
		ctx.failed = true
		ctx.report = _failed_report(ctx.caster, ctx.spell, ctx.cell, "combat_form")
		return ctx.report

	_resolve_targets(ctx)
	if ctx.spell.is_delayed():
		_prepare_delayed_resolution(ctx)
		_finalize_effectiveness(ctx)
		EventBus.spell_cast.emit(ctx.caster, ctx.spell, ctx.report)
		return ctx.report
	_run_hook(ctx, "on_area_resolved")
	_run_hook(ctx, "on_targets_resolved")
	_run_hook(ctx, "on_targets_finalized")
	if ctx.caster.mastery_combat_adapter != null:
		ctx.caster.mastery_combat_adapter.prepare_cast(ctx)

	_resolve_impacts(ctx)
	_run_hook(ctx, "on_damage_resolved")
	_run_hook(ctx, "on_terrain_resolved")

	_resolve_movement(ctx)
	_run_hook(ctx, "on_movement_resolved")

	_log_cast_resolution(ctx)
	_run_hook(ctx, "on_cast_complete")
	_finalize_effectiveness(ctx)
	if ctx.caster.mastery_combat_adapter != null:
		ctx.caster.mastery_combat_adapter.complete_cast(ctx)
	if not bool(ctx.get_meta("automatic_cast", false)):
		EventBus.spell_cast.emit(ctx.caster, ctx.spell, ctx.report)
	# A battle-owned movement keeps its already-reserved reactions queued
	# until the unit view reaches the resolved cell. Headless casts stay immediate.
	if ctx.caster.mastery_combat_adapter != null \
			and not bool(ctx.get_meta("defer_automatic_reactions", false)):
		ctx.caster.mastery_combat_adapter.flush_automatic()
	return ctx.report

# Les modifiers actifs viennent des données du sort et de la progression.
func _gather_modifiers(caster: Unit, spell: Spell) -> Array:
	var mods: Array = []
	if spell != null:
		for m in spell.modifiers:
			if m is SpellModifier and m.applies_to(spell) and not mods.has(m):
				mods.append(m)
	if caster != null:
		for m in caster.get_progression_spell_modifiers_for(
				spell.get_effective_spell_id()
			):
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
		"automatic": bool(ctx.get_meta("automatic_cast", false)),
		"awards_xp": not bool(ctx.get_meta("automatic_cast", false)),
		"caster": ctx.caster, "spell": ctx.spell, "cell": ctx.cell,
		"action_id": ctx.action_id, "ap_before": ctx.ap_before,
		"ap_after": ctx.caster.current_ap,
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
	ctx.report["equipment_condition_facts"] = (
		ctx.caster.get_equipment_condition_facts(ctx.primary_target)
		if ctx.caster != null else {
			"prior_moved_cells": 0,
			"mp_spent": 0,
			"hp_lost_since_previous_activation": false,
			"target_moved_or_collided": false,
			"guard_destroyed": false,
		}
	)

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
			) and not (
				ctx.spell.exclude_allies_from_area_effects
				and target.team == ctx.caster.team
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
		var base_dmg := spell.get_scaled_damage(caster) + cell_bonus
		var has_bonus_status := _has_status(target, spell.bonus_damage_status_id)
		if spell.bonus_requires_linked_status_source:
			has_bonus_status = caster.target_has_linked_source_status(
				target,
				spell.bonus_damage_status_id
			)
		if spell.bonus_damage_if_marked > 0 and has_bonus_status:
			base_dmg += spell.bonus_damage_if_marked
		base_dmg = int(round(base_dmg * float(ctx.get_meta("automatic_multiplier", 1.0))))
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
				"attack_classification": get_action_classification(spell),
				"impact_origin_cell": _damage_impact_origin_cell(ctx),
			}
		)
		if damage_result != null:
			ctx.damage_result_by_unit[target] = damage_result
			if damage_result.is_crit:
				report["crits"].append(target)
			if damage_result.dodged:
				report["dodges"].append(target)
			# Applied hit facts survive reactive healing or a new form shield.
			var hp_loss: int = damage_result.hp_damage_applied if damage_result.hp_damage_applied >= 0 \
				else maxi(0, hp_before_damage - target.current_hp)
			var shield_loss: int = damage_result.shield_damage_absorbed if damage_result.shield_damage_absorbed >= 0 \
				else maxi(0, shield_before_damage - target.current_shield)
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
	var raw_shield := spell.get_scaled_shield(caster) \
		+ int(ctx.additional_shield_by_unit.get(target, 0))
	if raw_shield > 0 and target.team == caster.team:
		var before_shield: int = target.current_shield
		target.add_shield(raw_shield, ctx.caster, {
			"action_id": ctx.action_id,
			"cast_id": ctx.cast_id,
			"impact_id": StringName("%s:%03d" % [ctx.cast_id, sequence_index]),
			"sequence_index": sequence_index,
			"ability_id": spell.get_effective_spell_id(),
			"shield_source_id": spell.get_effective_spell_id(),
			"tags": spell.shield_tags.duplicate(),
			"expires_after_activations": spell.shield_duration_activations,
		})
		report["shield_increase_total"] += maxi(0, target.current_shield - before_shield)
		if target.current_shield > before_shield and not report["shielded_units"].has(target):
			report["shielded_units"].append(target)
		affected = true
	if affected and not report["affected_units"].has(target):
		report["affected_units"].append(target)


func _damage_impact_origin_cell(ctx: CastContext) -> Vector2i:
	if ctx == null or ctx.caster == null or ctx.spell == null:
		return Vector2i(-1, -1)
	if ctx.spell.aoe_shape != Spell.AoeShape.SINGLE \
			or ctx.affected_cells.size() > 1:
		return ctx.cell
	return get_cast_origin(ctx.caster, ctx.spell)

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
	_resolve_caster_movement(ctx)
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
			report["angle_advantage"] = bool(report["angle_advantage"]) \
				or _grid.are_adjacent(caster.grid_pos, teleport_target.grid_pos)
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


func _resolve_caster_movement(ctx: CastContext) -> void:
	if ctx == null or ctx.caster == null or ctx.spell == null \
			or ctx.spell.caster_movement == Spell.CasterMovement.NONE:
		return
	if ctx.spell.caster_movement != Spell.CasterMovement.TARGET_CELL \
			or not _is_valid_caster_movement_target(
				ctx.caster,
				ctx.spell,
				ctx.cell,
			):
		return
	var origin := ctx.caster.grid_pos
	if not _grid.relocate_unit(ctx.caster, ctx.cell):
		return
	# GridData owns terrain entry; consume its resolved destination so a portal
	# or hazard is applied once and the presentation follows the actual endpoint.
	var relocation := _terrain.consume_relocation_result(ctx.caster, ctx.cell)
	var destination := relocation.get("destination", ctx.cell) as Vector2i
	ctx.report["caster_movement_from"] = origin
	ctx.report["caster_movement_to"] = destination
	ctx.caster.record_runtime_movement(_grid.manhattan(origin, ctx.cell))
	ctx.movement.append({
		"unit": ctx.caster,
		"from": origin,
		"to": destination,
		"collision": false,
		"voluntary": true,
	})
	# Use the same presentation event as modifier-based dashes and teleports.
	# GridData has already resolved terrain entry; views follow its final cell
	# without replaying gameplay movement or depending on a particular spell id.
	EventBus.unit_pushed.emit(ctx.caster, origin, destination, false)
	if _terrain.get_effect_data(ctx.cell) != null \
			or bool(relocation.get("applied", false)) \
			or bool(relocation.get("destination_effect_applied", false)):
		ctx.report["landed_on_terrain"] = true

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
