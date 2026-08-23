class_name SpellModSkillTreeEffect
extends SpellModifier

## Modificateur générique commun aux douze arbres de la preview. Les valeurs
## restent sérialisées dans les SkillTreeNodeData ; ce script ne contient
## aucune table de personnage, de discipline ou de node.

enum EffectType {
	DAMAGE_ALL,
	DAMAGE_CENTER,
	DAMAGE_LOW_HP,
	DAMAGE_BACKSTAB,
	DAMAGE_BACKSTAB_OR_LOW_HP,
	RANGE,
	HEAL,
	HEAL_LOW_HP,
	SHIELD_TARGET,
	SHIELD_CASTER_IF_ALLY,
	NEXT_TURN_MP_TARGET,
	NEXT_TURN_MP_CASTER,
	STATUS_DOT,
	STATUS_SLOW,
	STATUS_REGEN,
	STATUS_VULNERABILITY,
	STATUS_OUTGOING_DAMAGE,
	AREA_CARDINAL,
	PUSH_BONUS,
	PUSH_EXACT,
	COLLISION_BONUS,
	COLLISION_EXACT,
	TERRAIN_DURATION,
	TERRAIN_DAMAGE,
	CLEANSE,
	ADJACENT_HEAL_RATIO,
	SHIELD_ALLIES_ON_AREA,
	MP_ALLIES_ON_AREA,
	ATTACK_BUFF,
	MOVE_CASTER_TO_TARGET,
	ALLOW_FREE_CELL_TARGET,
	ADJACENT_SHIELD,
	SHIELD_CASTER,
}

enum TargetScope {
	PRIMARY_ENEMY,
	PRIMARY_ALLY,
	AFFECTED_ENEMIES,
	AFFECTED_ALLIES,
	CASTER,
}

enum StatusMode {
	BASE,
	DELTA,
	OVERRIDE,
}

@export var effect_type: EffectType = EffectType.DAMAGE_ALL
@export var target_scope: TargetScope = TargetScope.AFFECTED_ENEMIES
@export var amount: int = 0
@export var secondary_amount: int = 0
@export var effect_group: StringName = &""
@export_range(0, 99) var duration: int = 0
@export_range(1, 99) var charges: int = 1
@export_range(0.0, 1.0, 0.01) var threshold_ratio: float = 0.0
@export_range(0.0, 2.0, 0.01) var ratio: float = 0.0
@export var status_group: StringName = &""
@export var status_name: String = ""
@export var status_mode: StatusMode = StatusMode.BASE
@export var status_damage_type: Spell.DamageType = Spell.DamageType.MAGICAL
@export var status_element: Spell.Element = Spell.Element.NONE
@export var status_timing: StatusData.PeriodicTiming = StatusData.PeriodicTiming.TURN_START
@export var require_backstab: bool = false
@export var require_ally_target: bool = false
## Politique opt-in pour les charges qui ne doivent jamais franchir une case
## bloquee. Le comportement historique reste inchange quand elle est false.
@export var movement_requires_clear_path: bool = false


func get_range_bonus(_caster, _spell) -> int:
	return amount if effect_type == EffectType.RANGE else 0


func allows_free_cell_target(_caster, _spell) -> bool:
	return effect_type == EffectType.ALLOW_FREE_CELL_TARGET


func on_area_resolved(ctx) -> void:
	if ctx != null and effect_type == EffectType.AREA_CARDINAL:
		_expand_cardinal_area(ctx, amount)


func on_targets_resolved(ctx) -> void:
	if ctx == null or ctx.caster == null or ctx.spell == null:
		return
	match effect_type:
		EffectType.DAMAGE_ALL:
			_add_damage_to_units(ctx, _units_for_scope(ctx), amount)
		EffectType.DAMAGE_CENTER:
			_add_damage_to_cell(ctx, ctx.cell, amount)
		EffectType.DAMAGE_LOW_HP:
			var low_target := ctx.primary_target as Unit
			if _is_enemy(ctx, low_target) and _is_below_threshold(low_target):
				_add_grouped_damage_to_cell(ctx, low_target.grid_pos, amount)
		EffectType.DAMAGE_BACKSTAB:
			var backstab_target := ctx.primary_target as Unit
			if _is_enemy(ctx, backstab_target) \
					and backstab_target.is_grid_position_behind(ctx.caster.grid_pos):
				_add_damage_to_cell(ctx, backstab_target.grid_pos, amount)
		EffectType.DAMAGE_BACKSTAB_OR_LOW_HP:
			var execute_target := ctx.primary_target as Unit
			if _is_enemy(ctx, execute_target) and (
					execute_target.is_grid_position_behind(ctx.caster.grid_pos)
					or _is_below_threshold(execute_target)
			):
				_add_damage_to_cell(ctx, execute_target.grid_pos, amount)
		EffectType.HEAL:
			_add_heal_to_units(ctx, _units_for_scope(ctx), amount)
		EffectType.HEAL_LOW_HP:
			var heal_target := ctx.primary_target as Unit
			if _is_ally(ctx, heal_target) and _is_below_threshold(heal_target):
				_add_heal(ctx, heal_target, amount)
		EffectType.SHIELD_TARGET:
			_add_shield_to_units(ctx, _units_for_scope(ctx), amount)
		EffectType.STATUS_DOT:
			_merge_status_for_units(ctx, _units_for_scope(ctx), &"dot")
		EffectType.STATUS_SLOW:
			_merge_status_for_units(ctx, _units_for_scope(ctx), &"slow")
		EffectType.STATUS_REGEN:
			_merge_status_for_units(ctx, _units_for_scope(ctx), &"regen")
		EffectType.STATUS_VULNERABILITY:
			_merge_status_for_units(ctx, _units_for_scope(ctx), &"vulnerability")
		EffectType.STATUS_OUTGOING_DAMAGE:
			_merge_status_for_units(ctx, _units_for_scope(ctx), &"outgoing")
		EffectType.PUSH_BONUS:
			_set_push_for_units(ctx, _units_for_scope(ctx), amount, false)
		EffectType.PUSH_EXACT:
			_set_push_for_units(ctx, _units_for_scope(ctx), amount, true)
		EffectType.COLLISION_BONUS:
			ctx.collision_damage_bonus += amount
		EffectType.COLLISION_EXACT:
			ctx.collision_damage_override = maxi(ctx.collision_damage_override, amount)
		EffectType.TERRAIN_DURATION:
			ctx.skill_tree_terrain_spec["duration_delta"] = int(
				ctx.skill_tree_terrain_spec.get("duration_delta", 0)
			) + amount
		EffectType.TERRAIN_DAMAGE:
			ctx.skill_tree_terrain_spec["damage_delta"] = int(
				ctx.skill_tree_terrain_spec.get("damage_delta", 0)
			) + amount
		EffectType.SHIELD_ALLIES_ON_AREA:
			_add_shield_to_units(ctx, _affected_allies(ctx), amount)
		_:
			pass


func on_targets_finalized(ctx) -> void:
	if ctx == null:
		return
	_finalize_grouped_damage(ctx)
	if not _is_status_effect():
		return
	var group := _effective_status_group()
	if ctx.skill_tree_status_groups_finalized.has(group):
		return
	ctx.skill_tree_status_groups_finalized[group] = true
	for unit_value in ctx.skill_tree_status_specs_by_unit:
		var unit := unit_value as Unit
		if unit == null:
			continue
		var groups := ctx.skill_tree_status_specs_by_unit[unit] as Dictionary
		if not groups.has(group):
			continue
		var status := _build_status(groups[group] as Dictionary)
		if status == null:
			continue
		var statuses: Array = ctx.additional_statuses_by_unit.get(unit, [])
		statuses.append(status)
		ctx.additional_statuses_by_unit[unit] = statuses


func on_damage_resolved(ctx) -> void:
	if ctx == null or ctx.caster == null:
		return
	match effect_type:
		EffectType.SHIELD_CASTER_IF_ALLY:
			var protected := ctx.primary_target as Unit
			if protected != null and protected != ctx.caster \
					and protected.team == ctx.caster.team:
				_grant_shield_now(ctx, ctx.caster, amount)
		EffectType.SHIELD_CASTER:
			_grant_shield_now(ctx, ctx.caster, amount)
		EffectType.CLEANSE:
			for unit in _units_for_scope(ctx):
				_cleanse(unit, amount)
		EffectType.ADJACENT_HEAL_RATIO:
			_apply_adjacent_heal(ctx)
		EffectType.MOVE_CASTER_TO_TARGET:
			_move_caster_to_target(ctx)
		EffectType.ADJACENT_SHIELD:
			_apply_adjacent_shield(ctx)
		_:
			pass


func on_terrain_resolved(ctx) -> void:
	if ctx == null or ctx.skill_tree_terrain_finalized:
		return
	ctx.skill_tree_terrain_finalized = true


func on_movement_resolved(ctx) -> void:
	if ctx == null \
			or ctx.collision_damage_resolved \
			or (ctx.collision_damage_bonus <= 0 \
			and ctx.collision_damage_override < 0):
		return
	ctx.collision_damage_resolved = true
	var collision_amount: int = (
		ctx.collision_damage_override
		if ctx.collision_damage_override >= 0
		else ctx.collision_damage_bonus
	)
	var victims: Array[Unit] = []
	for movement_value in ctx.movement:
		var movement := movement_value as Dictionary
		if not bool(movement.get("collision", false)):
			continue
		var collision_units: Array = movement.get("collision_units", [])
		if collision_units.is_empty():
			collision_units = [movement.get("unit")]
		for victim_value in collision_units:
			var victim := victim_value as Unit
			if _is_enemy(ctx, victim) and not victims.has(victim):
				victims.append(victim)
	for victim in victims:
		if not victim.is_alive:
			continue
		var result = victim.take_damage(
			collision_amount,
			ctx.caster,
			Spell.DamageType.PHYSICAL,
			Spell.Element.NONE
		)
		if result != null and result.amount > 0:
			_append_affected(ctx, victim, true)


func on_cast_complete(ctx) -> void:
	if ctx == null or ctx.caster == null:
		return
	match effect_type:
		EffectType.NEXT_TURN_MP_TARGET:
			var target := ctx.primary_target as Unit
			if target != null and _condition_passes(ctx, target):
				target.queue_next_turn_mp_modifier(amount)
		EffectType.NEXT_TURN_MP_CASTER:
			if _condition_passes(ctx, ctx.primary_target as Unit):
				ctx.caster.queue_next_turn_mp_modifier(amount)
		EffectType.MP_ALLIES_ON_AREA:
			for ally in _affected_allies(ctx):
				ally.queue_next_turn_mp_modifier(amount)
		EffectType.ATTACK_BUFF:
			_apply_attack_buff(ctx)
		_:
			pass


func _units_for_scope(ctx) -> Array:
	match target_scope:
		TargetScope.PRIMARY_ENEMY:
			var enemy := ctx.primary_target as Unit
			return [enemy] if _is_enemy(ctx, enemy) else []
		TargetScope.PRIMARY_ALLY:
			var ally := ctx.primary_target as Unit
			return [ally] if _is_ally(ctx, ally) else []
		TargetScope.AFFECTED_ALLIES:
			return _affected_allies(ctx)
		TargetScope.CASTER:
			return [ctx.caster]
		_:
			return _affected_enemies(ctx)


func _affected_enemies(ctx) -> Array[Unit]:
	return _affected_units_for_team(ctx, false)


func _affected_allies(ctx) -> Array[Unit]:
	return _affected_units_for_team(ctx, true)


func _affected_units_for_team(ctx, wants_allies: bool) -> Array[Unit]:
	var result: Array[Unit] = []
	for cell in ctx.affected_cells:
		var unit := ctx.grid.get_unit(cell) as Unit
		if unit == null:
			continue
		var is_ally: bool = unit.team == ctx.caster.team
		if is_ally == wants_allies and not result.has(unit):
			result.append(unit)
	return result


func _is_enemy(ctx, unit: Unit) -> bool:
	return unit != null and unit.team != ctx.caster.team


func _is_ally(ctx, unit: Unit) -> bool:
	return unit != null and unit.team == ctx.caster.team


func _is_below_threshold(unit: Unit) -> bool:
	if unit == null or threshold_ratio <= 0.0:
		return false
	return float(unit.current_hp) / float(maxi(1, unit.max_hp.get_int())) < threshold_ratio


func _add_damage_to_units(ctx, units: Array, bonus: int) -> void:
	for unit in units:
		_add_damage_to_cell(ctx, unit.grid_pos, bonus)


func _add_damage_to_cell(ctx, cell: Vector2i, bonus: int) -> void:
	if bonus == 0:
		return
	var target := ctx.grid.get_unit(cell) as Unit
	if not _is_enemy(ctx, target):
		return
	ctx.damage_bonus_by_cell[cell] = int(ctx.damage_bonus_by_cell.get(cell, 0)) + bonus


func _add_grouped_damage_to_cell(ctx, cell: Vector2i, bonus: int) -> void:
	if effect_group == &"":
		_add_damage_to_cell(ctx, cell, bonus)
		return
	var groups: Dictionary = ctx.skill_tree_damage_groups_by_cell.get(cell, {})
	groups[effect_group] = maxi(int(groups.get(effect_group, 0)), bonus)
	ctx.skill_tree_damage_groups_by_cell[cell] = groups


func _finalize_grouped_damage(ctx) -> void:
	if ctx.skill_tree_damage_groups_finalized:
		return
	ctx.skill_tree_damage_groups_finalized = true
	for cell_value in ctx.skill_tree_damage_groups_by_cell:
		var cell := cell_value as Vector2i
		var groups := ctx.skill_tree_damage_groups_by_cell[cell] as Dictionary
		for bonus_value in groups.values():
			_add_damage_to_cell(ctx, cell, int(bonus_value))


func _add_heal_to_units(ctx, units: Array, bonus: int) -> void:
	for unit in units:
		_add_heal(ctx, unit, bonus)


func _add_heal(ctx, unit: Unit, bonus: int) -> void:
	if bonus == 0 or not _is_ally(ctx, unit):
		return
	ctx.heal_bonus_by_unit[unit] = int(ctx.heal_bonus_by_unit.get(unit, 0)) + bonus


func _add_shield_to_units(ctx, units: Array, shield: int) -> void:
	for unit in units:
		if _is_ally(ctx, unit):
			ctx.additional_shield_by_unit[unit] = int(
				ctx.additional_shield_by_unit.get(unit, 0)
			) + shield


func _set_push_for_units(
		ctx,
		units: Array,
		distance: int,
		exact: bool
	) -> void:
	for unit in units:
		if not _is_enemy(ctx, unit):
			continue
		var resolved := distance
		if not exact:
			resolved += int(ctx.push_distance_override_by_unit.get(
				unit,
				ctx.spell.push_distance
			))
		ctx.push_distance_override_by_unit[unit] = maxi(0, resolved)


func _expand_cardinal_area(ctx, layers: int) -> void:
	if layers <= 0 or ctx.grid == null:
		return
	var center: Vector2i = ctx.cell
	var extent := 0
	for cell_value in ctx.affected_cells:
		var cell := cell_value as Vector2i
		if cell.x == center.x or cell.y == center.y:
			extent = maxi(extent, abs(cell.x - center.x) + abs(cell.y - center.y))
	for layer in range(1, layers + 1):
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var candidate: Vector2i = center + direction * (extent + layer)
			if ctx.grid.is_valid(candidate) and not ctx.affected_cells.has(candidate):
				ctx.affected_cells.append(candidate)


func _merge_status_for_units(ctx, units: Array, kind: StringName) -> void:
	var group := _effective_status_group()
	for unit in units:
		if unit == null:
			continue
		var groups: Dictionary = ctx.skill_tree_status_specs_by_unit.get(unit, {})
		var spec: Dictionary = groups.get(group, {
			"kind": kind,
			"name": status_name,
			"base_amount": 0,
			"amount_delta": 0,
			"override_amount": null,
			"base_duration": 0,
			"duration_delta": 0,
			"override_duration": null,
			"charges": 1,
			"splash_damage": 0,
			"damage_type": status_damage_type,
			"element": status_element,
			"timing": status_timing,
		})
		spec["kind"] = kind
		if not status_name.is_empty():
			spec["name"] = status_name
		spec["charges"] = maxi(int(spec.get("charges", 1)), charges)
		spec["splash_damage"] = maxi(
			int(spec.get("splash_damage", 0)),
			secondary_amount
		)
		match status_mode:
			StatusMode.DELTA:
				spec["amount_delta"] = int(spec.get("amount_delta", 0)) + amount
				spec["duration_delta"] = int(spec.get("duration_delta", 0)) + duration
			StatusMode.OVERRIDE:
				spec["override_amount"] = amount
				spec["override_duration"] = duration
			_:
				spec["base_amount"] = (
					mini(int(spec.get("base_amount", 0)), amount)
					if kind == &"outgoing"
					else maxi(int(spec.get("base_amount", 0)), amount)
				)
				spec["base_duration"] = maxi(int(spec.get("base_duration", 0)), duration)
		groups[group] = spec
		ctx.skill_tree_status_specs_by_unit[unit] = groups


func _build_status(spec: Dictionary) -> StatusData:
	var kind := StringName(spec.get("kind", &""))
	var resolved_amount := int(spec.get("base_amount", 0)) + int(
		spec.get("amount_delta", 0)
	)
	var resolved_duration := int(spec.get("base_duration", 0)) + int(
		spec.get("duration_delta", 0)
	)
	if spec.get("override_amount") != null:
		resolved_amount = int(spec["override_amount"])
	if spec.get("override_duration") != null:
		resolved_duration = int(spec["override_duration"])
	var group := _effective_status_group()
	var display := str(spec.get("name", ""))
	if display.is_empty():
		display = str(group).replace("_", " ").capitalize()
	if kind == &"vulnerability":
		var vulnerability := ChargedDamageVulnerabilityData.new()
		vulnerability.status_id = group
		vulnerability.status_name = display
		vulnerability.description = "%+d dégâts sur les %d prochaines attaques." % [
			resolved_amount,
			int(spec.get("charges", 1)),
		]
		vulnerability.duration = 99
		vulnerability.max_charges = int(spec.get("charges", 1))
		vulnerability.bonus_damage = resolved_amount
		vulnerability.adjacent_splash_damage = int(
			spec.get("splash_damage", 0)
		)
		vulnerability.trigger_damage_type = int(spec.get(
			"damage_type",
			Spell.DamageType.PHYSICAL
		))
		return vulnerability
	var status := StatusData.new()
	status.status_id = group
	status.status_name = display
	status.duration = maxi(1, resolved_duration)
	match kind:
		&"dot":
			status.damage_per_turn = maxi(0, resolved_amount)
			status.damage_type = int(spec.get("damage_type", Spell.DamageType.MAGICAL))
			status.element = int(spec.get("element", Spell.Element.NONE))
			status.damage_timing = int(spec.get(
				"timing",
				StatusData.PeriodicTiming.TURN_START
			))
		&"slow":
			status.mp_reduction = maxi(0, resolved_amount)
		&"regen":
			status.heal_per_turn = maxi(0, resolved_amount)
		&"outgoing":
			status.outgoing_damage_modifier = resolved_amount
	return status


func _effective_status_group() -> StringName:
	if status_group != &"":
		return status_group
	return StringName("skill_tree_%s" % modifier_name.to_snake_case())


func _is_status_effect() -> bool:
	return effect_type in [
		EffectType.STATUS_DOT,
		EffectType.STATUS_SLOW,
		EffectType.STATUS_REGEN,
		EffectType.STATUS_VULNERABILITY,
		EffectType.STATUS_OUTGOING_DAMAGE,
	]


func _grant_shield_now(ctx, unit: Unit, shield: int) -> void:
	if unit == null or shield <= 0:
		return
	var before := unit.current_shield
	unit.add_shield(shield, ctx.caster)
	if unit.current_shield > before:
		_append_affected(ctx, unit, false)
		if not ctx.report["shielded_units"].has(unit):
			ctx.report["shielded_units"].append(unit)


func _cleanse(unit: Unit, maximum: int) -> void:
	if unit == null or maximum <= 0:
		return
	unit.cleanse_simple_negative_statuses(maximum)


func _apply_adjacent_heal(ctx) -> void:
	var target := ctx.primary_target as Unit
	if not _is_ally(ctx, target):
		return
	var main_heal := int(ctx.report["healing_by_unit"].get(target, 0))
	var shared := maxi(0, int(floor(float(main_heal) * ratio)))
	if shared <= 0:
		return
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var ally := ctx.grid.get_unit(target.grid_pos + direction) as Unit
		if not _is_ally(ctx, ally) or ally == target:
			continue
		var before := ally.current_hp
		ally.heal(shared, ctx.caster)
		ctx.report["healing_by_unit"][ally] = ally.current_hp - before
		if ally.current_hp > before:
			_append_affected(ctx, ally, false)
			if not ctx.report["healed_units"].has(ally):
				ctx.report["healed_units"].append(ally)


func _move_caster_to_target(ctx) -> void:
	var destination: Vector2i = ctx.cell
	var target := ctx.primary_target as Unit
	if target != null and target != ctx.caster:
		var delta: Vector2i = target.grid_pos - ctx.caster.grid_pos
		var direction := Vector2i(signi(delta.x), signi(delta.y))
		if delta.x != 0 and delta.y != 0:
			return
		destination = target.grid_pos - direction
	if destination == ctx.caster.grid_pos:
		return
	if not ctx.grid.is_valid(destination) \
			or not ctx.grid.is_walkable(destination) \
			or ctx.grid.has_unit(destination):
		return
	var origin: Vector2i = ctx.caster.grid_pos
	if movement_requires_clear_path:
		var travel_delta := destination - origin
		if travel_delta.x != 0 and travel_delta.y != 0:
			return
		var travel_direction := Vector2i(
			signi(travel_delta.x), signi(travel_delta.y)
		)
		var cursor := origin + travel_direction
		while cursor != destination:
			if not ctx.grid.is_valid(cursor) \
					or not ctx.grid.is_walkable(cursor) \
					or ctx.grid.has_unit(cursor):
				return
			cursor += travel_direction
	if ctx.grid.relocate_unit(ctx.caster, destination):
		ctx.movement.append({
			"unit": ctx.caster,
			"from": origin,
			"to": destination,
			"collision": false,
		})
		# The grid remains authoritative. This presentation event keeps the
		# UnitView aligned with the resolved cell, just like native teleports
		# and forced movement handled by SpellCaster.
		EventBus.unit_pushed.emit(ctx.caster, origin, destination, false)


func _apply_adjacent_shield(ctx) -> void:
	var center := ctx.primary_target as Unit
	if center == null:
		center = ctx.caster
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var ally := ctx.grid.get_unit(center.grid_pos + direction) as Unit
		if _is_ally(ctx, ally):
			_grant_shield_now(ctx, ally, amount)


func _apply_attack_buff(ctx) -> void:
	var target := ctx.primary_target as Unit
	if not _is_ally(ctx, target):
		return
	var buff := ChargedOutgoingDamageData.new()
	buff.status_id = _effective_status_group()
	buff.status_name = status_name if not status_name.is_empty() else "Ordre de guerre"
	buff.description = "%+d dégâts sur la prochaine attaque." % amount
	buff.duration = 99
	buff.max_charges = maxi(1, charges)
	buff.bonus_damage = amount
	target.apply_status(buff)


func _condition_passes(ctx, target: Unit) -> bool:
	if require_ally_target and not _is_ally(ctx, target):
		return false
	if require_backstab:
		return _is_enemy(ctx, target) \
			and target.is_grid_position_behind(ctx.caster.grid_pos)
	return true


func _append_affected(ctx, unit: Unit, damaged: bool) -> void:
	if not ctx.report["affected_units"].has(unit):
		ctx.report["affected_units"].append(unit)
	if damaged and not ctx.report["damaged_enemies"].has(unit):
		ctx.report["damaged_enemies"].append(unit)
