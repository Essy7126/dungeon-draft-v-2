class_name MasteryCombatAdapter
extends RefCounted

## Executes the pure mastery registry against the current battle. Choices and
## automatic actions are queued until the action has reached a safe point.
signal choices_changed
signal barrier_changed(cells: Array)
signal reaction_priority_selected(group: StringName, ordered_effect_ids: Array[StringName])

var grid: GridData
var caster: SpellCaster
var pathfinder: Pathfinder
var terrain: TerrainEffects
var _units: Array = []
var _state: Dictionary = {}
var _casts: Dictionary = {}
var _automatic: Array[Dictionary] = []
var _automatic_chain: Array[StringName] = []
var _flushing := false
var _connected := false
var _relic_executor = null
var _relic_service = null
var _serial := 0
var _temporary_armor: Array[Dictionary] = []
var _barriers: Array[Dictionary] = []
var _reaction_commands: Array[Dictionary] = []
var _reaction_choices: Dictionary = {}
var reaction_priority_overrides: Dictionary = {}

class ProjectileBarrier:
	extends RefCounted
	func blocks_projectiles() -> bool:
		return true
	func blocks_line_of_sight() -> bool:
		return false
	func blocks_movement() -> bool:
		return false

func configure(p_grid: GridData, p_caster: SpellCaster, p_terrain: TerrainEffects,
		p_pathfinder: Pathfinder, combat_units: Array, relic_service = null) -> void:
	grid = p_grid
	caster = p_caster
	terrain = p_terrain
	pathfinder = p_pathfinder
	_units = combat_units.duplicate()
	for unit in _units:
		attach_unit(unit)
	EventBus.hit_resolved.connect(_on_hit)
	EventBus.turn_started.connect(_on_activation_started)
	EventBus.turn_ended.connect(_on_activation_ended)
	EventBus.voluntary_movement_resolved.connect(_on_voluntary_movement)
	_connected = true
	_relic_service = relic_service
	if ResourceLoader.exists("res://battle/relic_tactical_intent_executor.gd"):
		_relic_executor = load("res://battle/relic_tactical_intent_executor.gd").new()
		_relic_executor.configure(grid, caster, self)
		if _relic_service != null:
			_relic_service.tactical_intent_emitted.connect(handle_relic_intent)
	for unit in _units:
		dispatch(unit, &"combat_started")

func attach_unit(unit: Unit) -> void:
	if unit == null:
		return
	unit.mastery_combat_adapter = self
	if not _units.has(unit):
		_units.append(unit)
	_state[unit] = {"hp_lost": 0, "moved": 0, "guard_initial": 0,
		"guard_source": &"", "guard_before_activation": 0, "guard_aura": {},
		"control": {}, "engagement": 0, "range": {}, "origin": {},
		"conversion_bonus": 0, "movement_threshold_delta": 0,
		"absorption_threshold": -1.0, "conditional_bonus_scale": 1.0}

func dispose() -> void:
	if _connected:
		EventBus.hit_resolved.disconnect(_on_hit)
		EventBus.turn_started.disconnect(_on_activation_started)
		EventBus.turn_ended.disconnect(_on_activation_ended)
		EventBus.voluntary_movement_resolved.disconnect(_on_voluntary_movement)
		_connected = false
	if _relic_executor != null:
		if _relic_service != null and _relic_service.tactical_intent_emitted.is_connected(handle_relic_intent):
			_relic_service.tactical_intent_emitted.disconnect(handle_relic_intent)
		_relic_executor.dispose()
	for entry in _temporary_armor:
		entry.target.armure.remove_modifiers_from(entry.source)
	_temporary_armor.clear()
	for unit in _units:
		_clear_guard_aura(unit)
		_remove_barriers(unit)
		if unit.mastery_runtime != null:
			unit.mastery_runtime.followup_queue.clear()
		if unit.mastery_combat_adapter == self:
			unit.mastery_combat_adapter = null
	_units.clear()
	_state.clear()
	_casts.clear()
	_automatic.clear()
	_reaction_commands.clear()
	_reaction_choices.clear()

func _data(unit: Unit) -> Dictionary:
	return _state.get(unit, {})

func _guard(unit: Unit) -> ShieldInstance:
	for shield in unit.get_shield_instances():
		if shield.tags.has(&"guard"):
			return shield
	return null

func context_for(actor: Unit, extra: Dictionary = {}) -> Dictionary:
	var target := extra.get("target") as Unit
	var state := _data(actor)
	var guard := _guard(actor)
	var context := {"actor": actor, "actor_id": StringName(actor.get_runtime_stable_id()),
		"activation_id": StringName("%s:%d" % [actor.get_runtime_stable_id(), actor.activation_index]),
		"caster_cell": actor.grid_pos, "caster_facing": actor.facing_dir,
		"defender_cell": actor.grid_pos, "defender_facing": actor.facing_dir,
		"max_hp": actor.max_hp.get_int(), "caster_hp_ratio": actor.get_hp_ratio(),
		"guard_active": guard != null, "guard_source_id": guard.source_id if guard != null else state.get("guard_source", &""),
		"initial_shield": guard.initial_value if guard != null else state.get("guard_initial", 0),
		"moved_cells": state.get("moved", 0), "origin_source_chain": _automatic_chain.duplicate(),
		"hp_lost_since_previous_activation": state.get("hp_lost", 0),
		"absorption_threshold_override": state.get("absorption_threshold", -1.0)}
	if target != null:
		context.merge({"target": target, "target_id": StringName(target.get_runtime_stable_id()),
			"target_hp_ratio": target.get_hp_ratio(), "target_armor": target.armure.get_int(),
			"distance": grid.manhattan(actor.grid_pos, target.grid_pos)}, true)
	context.merge(extra, true)
	return context

func dispatch(actor: Unit, event_id: StringName, extra: Dictionary = {}) -> Array[Dictionary]:
	var directives: Array[Dictionary] = []
	if actor == null or actor.mastery_runtime == null or not _state.has(actor):
		return directives
	var context := context_for(actor, extra)
	# Optional geometry is computed now, then checked again when selected.
	context["valid_cells"] = _free_cells(actor, 2)
	context["origin_cells"] = extra.get("origin_cells", [])
	if not context.has("valid_targets"):
		context["valid_targets"] = _reaction_targets(actor, context)
	for report in actor.mastery_runtime.process_event(event_id, context):
		for directive in report.get("directives", []):
			if report.has("frequency_reservation"):
				directive["frequency_reservation"] = report.frequency_reservation
			directives.append(directive)
			_apply_directive(actor, directive, context)
	choices_changed.emit()
	return directives

func before_activation_start(unit: Unit) -> void:
	if not _state.has(unit):
		return
	var guard := _guard(unit)
	_data(unit).guard_before_activation = guard.value if guard != null else 0

func _on_activation_started(unit: Unit) -> void:
	if not _state.has(unit):
		return
	var state := _data(unit)
	_clear_guard_aura(unit)
	_remove_barriers(unit)
	for index in range(_temporary_armor.size() - 1, -1, -1):
		var entry := _temporary_armor[index]
		if entry.owner == unit:
			entry.target.armure.remove_modifiers_from(entry.source)
			_temporary_armor.remove_at(index)
	state.moved = 0
	state.engagement = 0
	state.control = {}
	state.range = {}
	state.origin = {}
	state.conversion_bonus = 0
	dispatch(unit, &"activation_started", {"guard_active": int(state.guard_before_activation) > 0})
	state.hp_lost = 0
	if _relic_executor != null:
		_relic_executor.on_activation_started(unit)

func _on_activation_ended(unit: Unit, _reason: StringName) -> void:
	dispatch(unit, &"activation_ended")
	if _relic_executor != null:
		_relic_executor.on_activation_ended(unit)
	if unit != null and unit.mastery_runtime != null:
		unit.mastery_runtime.followup_queue.expire_scope(&"ACTIVATION")
		unit.mastery_runtime.followup_queue.expire_scope(&"ACTION")

func prepare_cast(ctx: CastContext) -> void:
	if ctx.caster == null or not _state.has(ctx.caster):
		return
	var extra := {"target": ctx.primary_target, "spell_id": ctx.spell.get_effective_spell_id(),
		"action_id": ctx.action_id, "caster_cell": ctx.caster.grid_pos,
		"distance": grid.manhattan(projectile_origin(ctx.caster, ctx.spell), ctx.cell)}
	var event_sources: Array[StringName] = []
	if ctx.caster.mastery_runtime != null:
		for effect in ctx.caster.mastery_runtime.active_effects():
			if effect.effect_id != &"track_distinct_offenses" and not _is_target_bound_damage(ctx.caster, effect):
				event_sources.append(effect.source_id)
	extra["only_source_ids"] = event_sources
	var profile := spell_profile(ctx.caster, ctx.spell)
	# Snapshot before damage, shield consumption and projectile-origin cleanup.
	# Presentation fields never enter the rules registry.
	var visual := AchillesSpellVisualResolver.resolve(ctx.spell, ctx.caster, profile)
	visual["origin_cell"] = projectile_origin(ctx.caster, ctx.spell)
	visual["cell"] = ctx.cell
	visual["action_id"] = ctx.action_id
	_apply_static_cast_profile(ctx, profile)
	var visual_target_cells := {}
	for cell in ctx.affected_cells:
		var target := grid.get_unit(cell) as Unit
		if target != null:
			visual_target_cells[target] = cell
	var directives := dispatch(ctx.caster, &"spell_cast", extra)
	_casts[ctx.action_id] = {"actor": ctx.caster, "directives": directives,
		"spell": ctx.spell, "origin": ctx.caster.grid_pos, "cell": ctx.cell, "profile": profile,
		"visual_presentation": visual, "visual_feedback": [], "visual_target_cells": visual_target_cells}
	if ctx.spell.get_effective_spell_id() == &"achilles_peleid_strike":
		var bonus := int(_data(ctx.caster).conversion_bonus)
		if bonus > 0:
			directives.append({"kind": &"raw_damage_bonus", "amount": bonus})
			_data(ctx.caster).conversion_bonus = 0

func complete_cast(ctx: CastContext) -> void:
	if ctx.caster == null or not _state.has(ctx.caster):
		return
	var entry: Dictionary = _casts.get(ctx.action_id, {})
	var guard := _guard(ctx.caster)
	if guard != null:
		_data(ctx.caster).guard_initial = guard.initial_value
		_data(ctx.caster).guard_source = guard.source_id
	for directive in entry.get("directives", []):
		if StringName(directive.get("kind", &"")) in [&"guard_aura", &"temporary_barrier"]:
			_apply_guard_directive(ctx.caster, directive)
	for movement in ctx.movement:
		var moved := movement.get("unit") as Unit
		if moved == ctx.caster:
			movement_resolved(ctx.caster, movement, ctx.spell.get_effective_spell_id(), ctx.action_id)
		elif moved != null:
			dispatch(ctx.caster, &"collision" if bool(movement.get("collision", false)) else &"unit_moved",
				{"target": moved, "forced_move": true, "collision": movement.get("collision", false),
				"spell_id": ctx.spell.get_effective_spell_id(), "action_id": ctx.action_id})
	if _relic_executor != null:
		_relic_executor.on_spell_completed(ctx.caster, ctx.spell, ctx.report)
	var hit_cells: Array[Vector2i] = []
	var target_cells: Dictionary = entry.get("visual_target_cells", {})
	for target in ctx.report.get("damaged_enemies", []):
		if target_cells.has(target):
			hit_cells.append(target_cells[target])
	ctx.report["visual_impact_cells"] = hit_cells
	ctx.report["visual_presentation"] = (entry.get("visual_presentation", {}) as Dictionary).duplicate(true)
	ctx.report["visual_feedback"] = (entry.get("visual_feedback", []) as Array).duplicate(true)
	_casts.erase(ctx.action_id)
	for unit in _units:
		_data(unit).control = {}
	if ctx.spell.get_effective_spell_id() == &"achilles_pelion_shot":
		_data(ctx.caster).origin = {}

func before_hit(target: Unit, hit: DamageResolver.HitContext) -> void:
	if not _state.has(target):
		return
	var guard_before := _guard(target)
	if guard_before != null:
		_data(target).guard_source = guard_before.source_id
		_data(target).guard_initial = guard_before.initial_value
	if _relic_executor != null:
		_relic_executor.on_before_hit(target, hit)
	var actor := hit.attacker as Unit
	var entry: Dictionary = _casts.get(hit.action_id, {})
	var multiplier := _target_damage_multiplier(actor, target, hit, entry) * _distinct_damage_multiplier(actor, target, hit)
	var bonus := 0
	hit.pen_flat += float((entry.get("profile", {}) as Dictionary).get("ignore_armor_flat", 0))
	for directive in entry.get("directives", []):
		var spell_id := StringName(directive.get("target_spell_id", &""))
		if spell_id != &"" and spell_id != hit.ability_id:
			continue
		match StringName(directive.get("kind", &"")):
			&"damage_multiplier":
				var effect := _effect(actor, StringName(directive.get("source_id", &""))) if actor != null else null
				if effect != null and effect.effect_id == &"damage_multiplier" and effect.frequency == MasteryReactiveEffectData.Frequency.UNLIMITED:
					continue # Re-evaluated against this actual target below, not the preview's primary victim.
				var value := float(directive.get("multiplier", 1.0))
				var scale := float((entry.get("profile", {}) as Dictionary).get("conditional_bonus_scale", 1.0)) * float(_data(actor).get("conditional_bonus_scale", 1.0))
				multiplier *= 1.0 + (value - 1.0) * scale if value > 1.0 else value
			&"raw_damage_bonus": bonus += int(directive.get("amount", 0))
			&"ignore_armor": hit.pen_flat += float(directive.get("amount", 0))
	hit.raw_damage = maxi(0, int(round(float(hit.raw_damage) * multiplier)) + bonus)
	var incoming := {"target": actor, "attacker_cell": actor.grid_pos if actor != null else target.grid_pos,
		"attack_classification": hit.attack_classification, "action_id": hit.action_id,
		"spell_id": hit.ability_id, "enemy_source": actor != null and actor.team != target.team,
		"valid_targets": [actor] if actor != null and actor.is_alive else [],
		"only_effect_ids": [&"modify_shield_damage", &"block_control"]}
	var defensive := dispatch(target, &"damage_received", incoming)
	if hit.attack_classification == &"PROJECTILE":
		defensive.append_array(dispatch(target, &"projectile_received", incoming))
	var shield_multiplier := 1.0
	var best_priority := -2147483648
	for directive in defensive:
		if StringName(directive.get("kind", &"")) == &"shield_damage_multiplier" 				and int(directive.get("priority", 0)) > best_priority:
			shield_multiplier = float(directive.get("multiplier", 1.0))
			best_priority = int(directive.get("priority", 0))
	hit.guard_damage_multiplier *= maxf(0.01, shield_multiplier)

func _on_hit(fact: CombatEventFact) -> void:
	var target := fact.target as Unit
	var source := fact.source as Unit
	if target == null or not _state.has(target):
		return
	_data(target).hp_lost = int(_data(target).hp_lost) + fact.amount_applied
	var guard_absorbed := 0
	var guard_broken := false
	for absorption in fact.source_absorption:
		if (absorption.get("tags", []) as Array).has(&"guard"):
			guard_absorbed += int(absorption.get("amount_absorbed", 0))
			guard_broken = guard_broken or fact.broken_source_ids.has(StringName(absorption.get("source_id", &"")))
	var incoming := {"target": source, "spell_id": fact.ability_id, "action_id": fact.action_id,
		"attack_classification": fact.attack_classification, "guard_active": fact.guard_absorbed or _guard(target) != null,
		"enemy_source": source != null and source.team != target.team,
		"absorbed_damage": guard_absorbed, "origin_source_chain": _automatic_chain.duplicate()}
	incoming["only_effect_ids"] = [&"automatic_attack"]
	incoming["attacker_cell"] = source.grid_pos if source != null else target.grid_pos
	incoming["valid_targets"] = [source] if source != null and source.is_alive else []
	dispatch(target, &"damage_received", incoming)
	if fact.attack_classification == &"PROJECTILE" and guard_absorbed > 0 and guard_absorbed * 2 >= fact.amount_resolved:
		dispatch(target, &"projectile_received", incoming)
	incoming.erase("only_effect_ids")
	if fact.amount_absorbed > 0:
		dispatch(target, &"damage_absorbed", incoming)
	if not fact.broken_source_ids.is_empty():
		# The guard trigger is tied to a guard source, never a collateral shield.
		if guard_broken:
			dispatch(target, &"shield_destroyed", incoming)
	if _guard(target) == null:
		_clear_guard_aura(target)
	if source != null and source.team != target.team and fact.amount_resolved > 0:
		var outgoing := {"target": target, "spell_id": fact.ability_id, "action_id": fact.action_id,
			"attack_classification": fact.attack_classification, "origin_source_chain": _automatic_chain.duplicate()}
		dispatch(source, &"damage_dealt", outgoing)
		if target.current_hp <= 0:
			outgoing["elimination"] = true
			dispatch(source, &"elimination", outgoing)
	if _relic_executor != null:
		_relic_executor.on_hit(fact)

func _on_voluntary_movement(unit: Unit, path: Array, _cost: int, action_id: StringName) -> void:
	if unit == null or path.size() < 2:
		return
	movement_resolved(unit, {"unit": unit, "from": path[0], "to": unit.grid_pos,
		"distance": maxi(0, path.find(unit.grid_pos))}, &"", action_id)

func movement_resolved(actor: Unit, movement: Dictionary, spell_id: StringName = &"", action_id: StringName = &"") -> void:
	if not _state.has(actor) or not actor.is_alive:
		return
	var from_cell: Vector2i = movement.get("from", actor.grid_pos)
	var to_cell: Vector2i = movement.get("to", actor.grid_pos)
	var distance := int(movement.get("distance", grid.manhattan(from_cell, to_cell)))
	_data(actor).moved = int(_data(actor).moved) + distance
	if spell_id == &"":
		_data(actor).engagement = 0
	var threshold_delta := int(_data(actor).movement_threshold_delta)
	for value in actor.spells:
		threshold_delta = mini(threshold_delta, int(spell_profile(actor, value).get("movement_threshold_delta", 0)))
	var context := {"spell_id": spell_id, "action_id": action_id,
		"moved_cells": distance - threshold_delta if distance > 0 else 0, "ended_in_contact": not _adjacent_enemies(actor).is_empty(),
		"origin_cells": [from_cell, to_cell], "from": from_cell, "to": to_cell}
	dispatch(actor, &"movement_resolved", context)
	context.moved_cells = int(_data(actor).moved) - threshold_delta
	dispatch(actor, &"distance_travelled", context)
	if _relic_executor != null:
		_relic_executor.on_movement(actor, movement)

func _apply_directive(actor: Unit, directive: Dictionary, context: Dictionary) -> void:
	var state := _data(actor)
	var target := context.get("target") as Unit
	var source := StringName(directive.get("source_id", &"mastery"))
	match StringName(directive.get("kind", &"")):
		&"armor_delta":
			if target != null and target.team != actor.team:
				# Multiple branches of one effect refresh instead of silently stacking.
				var key := "mastery:%s:%s" % [actor.get_runtime_stable_id(), str(source).get_slice(".", 0)]
				target.armure.remove_modifiers_from(key)
				target.armure.add_modifier(float(directive.get("amount", 0)), Stat.ModType.FLAT, key)
				_temporary_armor.append({"owner": actor, "target": target, "source": key})
		&"next_activation_mp":
			if target != null and not blocks_control(target, &"mp_loss"):
				target.queue_next_turn_mp_modifier(int(directive.get("amount", 0)))
		&"ignore_engagement": state.engagement = maxi(int(state.engagement), int(directive.get("points", 0)))
		&"block_control": state.control = directive.duplicate()
		&"grant_sourced_shield":
			var amount := int(directive.get("flat_value", 0)) + int(round(actor.max_hp.get_int() * float(directive.get("max_hp_ratio", 0.0))))
			actor.add_shield(amount, actor, {"shield_source_id": source, "expires_after_activations": 1})
		&"restore_shield_source":
			var amount := int(round(int(state.guard_initial) * float(directive.get("initial_value_ratio", 0.0))))
			actor.add_sourced_shield(StringName(state.guard_source), actor.get_shield_value(StringName(state.guard_source)) + amount,
				actor, {"tags": [&"guard", &"achilles_guard"], "expires_after_activations": 1})
		&"bastion_impact":
			_reaction_commands.append({"actor": actor, "action_id": context.get("action_id", &""),
				"group": &"guard_dash_conversion", "source_id": source, "kind": &"bastion",
				"directive": directive.duplicate(), "context": context.duplicate()})
		&"automatic_attack":
			var queued := false
			var spell_id := StringName(directive.get("spell_id", &""))
			for candidate in directive.get("valid_targets", []):
				if _automatic_target_valid(actor, _spell(actor, spell_id), candidate):
					var command := {"actor": actor, "action_id": context.get("action_id", &""),
						"group": &"projectile_counter" if context.get("attack_classification", &"") == &"PROJECTILE" else &"automatic_counterattack",
						"source_id": source, "kind": &"automatic", "spell_id": spell_id,
						"target": candidate, "multiplier": float(directive.get("damage_multiplier", 1.0)),
						"chain": _automatic_chain.duplicate(), "directive": directive.duplicate()}
					queued = true
					_reaction_commands.append(command)
					break
			if not queued:
				actor.mastery_runtime.refund_frequency(StringName(directive.get("frequency_reservation", &"")))
		&"movement_threshold_delta": state.movement_threshold_delta = int(directive.get("amount", 0))
		&"absorption_threshold_override":
			state.absorption_threshold = float(directive.get("max_hp_ratio", -1.0))
		&"conditional_bonus_scale": state.conditional_bonus_scale = float(directive.get("multiplier", 1.0))
		&"tactical_followup_queued":
			var request := actor.mastery_runtime.followup_queue._find(StringName(directive.get("request_id", &"")))
			var effect := _effect(actor, source)
			if request != null and effect != null:
				if request.request_type in [&"free_move", &"orthogonal_step"]:
					request.valid_cells.assign(_free_cells(actor, maxi(1, effect.maximum_cells)))
				elif request.request_type == &"projectile_origin":
					request.valid_cells.assign(context.get("origin_cells", []))

func _effect(actor: Unit, source_id: StringName) -> MasteryReactiveEffectData:
	if actor.mastery_runtime != null:
		for effect in actor.mastery_runtime.active_effects():
			if effect.source_id == source_id:
				return effect
	return null

func _apply_guard_directive(actor: Unit, directive: Dictionary) -> void:
	var guard := _guard(actor)
	if guard == null:
		return
	match StringName(directive.get("kind", &"")):
		&"guard_aura":
			_clear_guard_aura(actor)
			_data(actor).guard_aura = directive.duplicate()
			actor.armure.add_modifier(float(directive.get("armor_bonus", 0)), Stat.ModType.FLAT, "mastery_guard_aura")
		&"temporary_barrier":
			_remove_barriers(actor)
			var facing := actor._snap_to_cardinal(actor.facing_dir)
			var side := Vector2i(-facing.y, facing.x)
			var cells: Array = []
			var blocker := ProjectileBarrier.new()
			var length := maxi(1, int(directive.get("line_length", 3)))
			for offset in range(-int(length / 2), length - int(length / 2)):
				var cell := actor.grid_pos + facing + side * offset
				if grid.is_valid(cell):
					grid.register_dynamic_blocker(cell, blocker)
					cells.append(cell)
			_barriers.append({"owner": actor, "cells": cells, "blocker": blocker,
				"surcharge": int(directive.get("enemy_movement_surcharge", 1))})
			# The authored personal shield penalty is already in the shared static profile.
			actor.shield_changed.emit(actor)
			barrier_changed.emit(barrier_cells())

func _clear_guard_aura(actor: Unit) -> void:
	actor.armure.remove_modifiers_from("mastery_guard_aura")
	if _state.has(actor):
		_data(actor).guard_aura = {}

func blocks_control(unit: Unit, kind: StringName) -> bool:
	var state := _data(unit)
	if state.is_empty():
		return false
	var aura: Dictionary = state.get("guard_aura", {})
	var control: Dictionary = state.get("control", {})
	match kind:
		&"push": return bool(aura.get("push_immunity", false)) or bool(control.get("blocks_push", false))
		&"pull": return bool(aura.get("pull_immunity", false)) or bool(control.get("blocks_pull", false))
		&"mp_loss": return bool(control.get("blocks_mp_loss", false))
	return false

func _bastion(actor: Unit, directive: Dictionary, context: Dictionary) -> void:
	var guard := _guard(actor)
	if guard == null:
		return
	var spent := mini(guard.value, int(round(guard.value * float(directive.get("shield_consumption_ratio", 0.0)))))
	actor.consume_shield_source(guard.source_id, spent)
	if _guard(actor) == null:
		_clear_guard_aura(actor)
	var raw := mini(spent, int(round(actor.max_hp.get_int() * float(directive.get("damage_cap_max_hp_ratio", 0.0)))))
	var visual_targets: Array[Vector2i] = []
	for target in _adjacent_enemies(actor):
		visual_targets.append(target.grid_pos)
		target.take_damage(raw, actor, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
			{"ability_id": context.get("spell_id", &""), "action_id": context.get("action_id", &""), "attack_classification": &"MELEE"})
		if target.is_alive:
			var journal: Array = []
			caster._push_unit(actor, target, int(directive.get("push_adjacent_distance", 1)), 0, journal)
			for move in journal:
				dispatch(actor, &"collision" if move.get("collision", false) else &"unit_moved", {"target": move.unit, "forced_move": true, "collision": move.get("collision", false)})
	actor.shield_changed.emit(actor)
	# Reactions may resolve after complete_cast erased its entry, or after a
	# player choice. Publish the fact now; the view still waits for arrival.
	var spell := _spell(actor, StringName(context.get("spell_id", &"")))
	if spell != null:
		var visual := AchillesSpellVisualResolver.resolve(spell, actor, spell_profile(actor, spell))
		visual.merge({"variant": &"bastion", "effect_variant": &"dash_bastion",
			"guard_active": bool(context.get("guard_active", true)),
			"movement_arrival_only": true, "action_id": context.get("action_id", &""),
			"origin_cell": context.get("from", actor.grid_pos), "cell": actor.grid_pos}, true)
		var report := {"cell": actor.grid_pos, "visual_feedback": [{"kind": &"bastion_impact",
			"cell": actor.grid_pos, "target_cells": visual_targets, "shield_spent": spent, "raw_damage": raw}]}
		EventBus.spell_visual_resolved.emit(actor, spell, report, visual)

func _remove_barriers(actor: Unit) -> void:
	for index in range(_barriers.size() - 1, -1, -1):
		var entry := _barriers[index]
		if entry.owner == actor:
			for cell in entry.cells:
				grid.unregister_dynamic_blocker(cell, entry.blocker)
			_barriers.remove_at(index)
	barrier_changed.emit(barrier_cells())

func barrier_cells() -> Array:
	var cells: Array = []
	for entry in _barriers:
		cells.append_array(entry.cells)
	return cells

## Read-only presentation snapshot of the actual registered blockers.
func barrier_visual_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _barriers:
		result.append({"owner": entry.owner, "cells": entry.cells.duplicate()})
	return result

func modify_movement_cost(unit: Unit, from_cell: Vector2i, to_cell: Vector2i, cost: int) -> int:
	var result := cost
	if _relic_service != null:
		result = _relic_service.modify_voluntary_transition_cost(unit, from_cell, to_cell, result)
	var ignored := int(_data(unit).get("engagement", 0))
	result -= mini(ignored, pathfinder.get_disengagement_cost(unit, from_cell, to_cell))
	for entry in _barriers:
		if entry.owner.team != unit.team and entry.cells.has(to_cell):
			result += int(entry.surcharge)
	return maxi(0, result)

func _preview_range_effects(actor: Unit, spell: Spell) -> Array[MasteryReactiveEffectData]:
	var result: Array[MasteryReactiveEffectData] = []
	if actor.mastery_runtime == null:
		return result
	var context := context_for(actor, {"spell_id": spell.get_effective_spell_id()})
	for effect in actor.mastery_runtime.active_effects():
		if effect.effect_id == &"modify_range" and actor.mastery_runtime._conditions_pass(effect, context) 				and actor.mastery_runtime._frequency_available(effect, context):
			result.append(effect)
	return result

func range_bonus(actor: Unit, spell: Spell) -> int:
	var bonus := 0
	for effect in _preview_range_effects(actor, spell):
		bonus += effect.flat_value
	return bonus

func minimum_range(actor: Unit, spell: Spell, base: int) -> int:
	var value := base
	for effect in _preview_range_effects(actor, spell):
		if effect.minimum_range_override >= 0:
			value = effect.minimum_range_override
	return maxi(0, value)

func projectile_origin(actor: Unit, spell: Spell) -> Vector2i:
	var origin: Dictionary = _data(actor).get("origin", {})
	if spell != null and origin.get("spell_id", &"") == spell.get_effective_spell_id():
		return origin.get("cell", actor.grid_pos)
	return actor.grid_pos

func has_directional_guard(actor: Unit) -> bool:
	if actor.mastery_runtime == null:
		return false
	for effect in actor.mastery_runtime.active_effects():
		if effect.directional_guard != null or effect.temporary_barrier != null:
			return true
	return false

func _spell(actor: Unit, spell_id: StringName) -> Spell:
	if actor == null:
		return null
	for value in actor.spells:
		var spell := value as Spell
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell
	return null

func _automatic_target_valid(actor: Unit, spell: Spell, target: Unit) -> bool:
	if actor == null or target == null or spell == null or not actor.is_alive or not target.is_alive or target.current_hp <= 0 or actor.team == target.team:
		return false
	var distance := grid.manhattan(actor.grid_pos, target.grid_pos)
	return distance >= caster.get_effective_spell_minimum_range(actor, spell) 		and distance <= caster.get_effective_spell_range(actor, spell) 		and (not spell.needs_line_of_sight or pathfinder.has_line_of_sight(actor.grid_pos, target.grid_pos)) 		and (caster.get_action_classification(spell) != &"PROJECTILE" or pathfinder.has_projectile_path(actor.grid_pos, target.grid_pos))

func queue_automatic(actor: Unit, spell_id: StringName, target: Unit, multiplier: float, source_id: StringName, reaction: Dictionary = {}) -> void:
	if _automatic_chain.has(source_id) or _automatic_chain.size() >= 8:
		if not reaction.is_empty():
			_refund_reaction(reaction)
		return
	var chain := _automatic_chain.duplicate()
	chain.append(source_id)
	_automatic.append({"actor": actor, "spell_id": spell_id, "target": target,
		"multiplier": multiplier, "chain": chain, "reaction": reaction})

func flush_automatic() -> void:
	if _flushing:
		return
	_flushing = true
	_resolve_reaction_commands()
	var count := 0
	while not _automatic.is_empty() and count < 32:
		var command: Dictionary = _automatic.pop_front()
		var actor := command.actor as Unit
		var target := command.target as Unit
		var spell := _spell(actor, command.spell_id)
		if not _automatic_target_valid(actor, spell, target):
			var reaction: Dictionary = command.get("reaction", {})
			if not reaction.is_empty():
				_refund_reaction(reaction)
			continue
		count += 1
		_automatic_chain.assign(command.chain)
		_serial += 1
		var visual := AchillesSpellVisualResolver.resolve(spell, actor, spell_profile(actor, spell))
		visual.merge({"automatic": true, "source_chain": command.chain.duplicate(),
			"origin_cell": projectile_origin(actor, spell), "cell": target.grid_pos}, true)
		var report := caster.cast_automatic(actor, spell, target.grid_pos, float(command.multiplier), StringName("mastery_auto_%d" % _serial))
		if not bool(report.get("failed", false)):
			EventBus.spell_visual_resolved.emit(actor, spell, report, visual)
		_resolve_reaction_commands()
	_automatic_chain.clear()
	_flushing = false

func _reaction_targets(actor: Unit, context: Dictionary) -> Array:
	var result: Array = []
	var preferred := context.get("target") as Unit
	if preferred != null and preferred.is_alive and preferred.current_hp > 0 and preferred.team != actor.team:
		result.append(preferred)
	for unit in grid.get_units():
		if unit != actor and unit.is_alive and unit.current_hp > 0 and unit.team != actor.team and not result.has(unit):
			result.append(unit)
	result.sort_custom(func(a: Unit, b: Unit) -> bool:
		var da := grid.manhattan(actor.grid_pos, a.grid_pos)
		var db := grid.manhattan(actor.grid_pos, b.grid_pos)
		return da < db if da != db else a.get_runtime_stable_id() < b.get_runtime_stable_id())
	return result

func _adjacent_enemies(actor: Unit) -> Array:
	var result: Array = []
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var unit := grid.get_unit(actor.grid_pos + direction) as Unit
		if unit != null and unit.is_alive and unit.team != actor.team:
			result.append(unit)
	return result

func _free_cells(actor: Unit, maximum: int) -> Array:
	var result: Array = []
	var frontier: Array = [actor.grid_pos]
	var distance: Dictionary = {actor.grid_pos: 0}
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = cell + direction
			if not grid.is_walkable(next, actor) or distance.has(next) or int(distance[cell]) >= maximum:
				continue
			distance[next] = int(distance[cell]) + 1
			result.append(next)
			frontier.append(next)
	return result

func pending_choice(actor: Unit) -> TacticalFollowupRequest:
	if actor == null or actor.mastery_runtime == null:
		return null
	return actor.mastery_runtime.followup_queue.peek()

func choice_path(actor: Unit, request: TacticalFollowupRequest, cell: Vector2i) -> Array:
	if request == null or not request.valid_cells.has(cell):
		return []
	var effect := _effect(actor, request.source_id)
	var maximum := maxi(1, effect.maximum_cells) if effect != null else 1
	if not _free_cells(actor, maximum).has(cell):
		return []
	return _free_path(actor, cell, maximum)

func resolve_choice(actor: Unit, request: TacticalFollowupRequest, cell: Variant = null, option: StringName = &"") -> Dictionary:
	if pending_choice(actor) != request:
		return {"resolved": false, "reason": &"EXPIRED"}
	if request.request_type in [&"free_move", &"orthogonal_step"]:
		if not cell is Vector2i or choice_path(actor, request, cell).is_empty():
			return {"resolved": false, "reason": &"INVALID_CELL"}
	var result := actor.mastery_runtime.followup_queue.resolve_choice(request.request_id, cell, null, option)
	if not result.get("resolved", false):
		return result
	var state := _data(actor)
	if request.request_type == &"reaction_choice":
		_resolve_reaction_choice(request, option)
	elif request.request_type == &"projectile_origin":
		var chosen: Vector2i = cell if cell is Vector2i else request.valid_cells[0 if option == &"dash_start" else request.valid_cells.size() - 1]
		var effect := _effect(actor, request.source_id)
		state.origin = {"spell_id": effect.target_spell_id if effect != null else &"", "cell": chosen}
	elif request.request_type == &"shield_conversion":
		var remaining := int(state.guard_before_activation)
		if option == &"retain_half_as_new_shield":
			actor.add_sourced_shield(request.source_id, int(round(remaining * 0.5)), actor, {"expires_after_activations": 1})
		elif option == &"convert_remaining_to_next_strike":
			state.conversion_bonus = remaining
	choices_changed.emit()
	return result


func handle_relic_intent(intent: Dictionary) -> void:
	var actor: Unit = null
	for unit in _units:
		if unit.get_runtime_stable_id() == str(intent.get("actor_id", "")):
			actor = unit
			break
	if actor == null or _relic_executor == null:
		return
	var kind := StringName(intent.get("intent_id", &""))
	if kind in [&"guard_dash_conversion", &"projectile_counter"]:
		_reaction_commands.append({"actor": actor, "action_id": intent.get("action_id", &""),
			"group": kind, "source_id": StringName("relic:%s" % intent.get("item_id", kind)),
			"kind": &"relic", "intent": intent.duplicate(true)})
	else:
		_relic_executor.execute_intent(intent)

func _resolve_reaction_commands() -> void:
	var grouped := {}
	var pending := _reaction_commands.duplicate()
	_reaction_commands.clear()
	for command in pending:
		var key := "%s:%s:%s" % [command.actor.get_runtime_stable_id(), command.action_id, command.group]
		if not grouped.has(key):
			grouped[key] = []
		grouped[key].append(command)
	for key in grouped:
		var commands: Array = grouped[key]
		if commands.size() == 1:
			_execute_reaction(commands[0])
			continue
		var group := StringName(commands[0].group)
		var preferences: Array = reaction_priority_overrides.get(group, [])
		var chosen: Dictionary = {}
		# Dash conversions always ask: spending a guard is an explicit choice.
		if group != &"guard_dash_conversion":
			for preference in preferences:
				for command in commands:
					if command.source_id == preference:
						chosen = command
						break
				if not chosen.is_empty():
					break
		if not chosen.is_empty():
			for command in commands:
				if command != chosen:
					_refund_reaction(command)
			_execute_reaction(chosen)
			continue
		var actor := commands[0].actor as Unit
		if actor.mastery_runtime == null:
			_execute_reaction(commands[0])
			continue
		var request := TacticalFollowupRequest.new()
		request.source_id = &"shared_reaction_choice"
		request.request_type = &"reaction_choice"
		request.optional = false
		request.expiry_scope = &"COMBAT"
		request.priority = 1000
		for command in commands:
			request.valid_option_ids.append(StringName(command.source_id))
		var queued := actor.mastery_runtime.followup_queue.enqueue(request)
		if queued.get("accepted", false):
			_reaction_choices[request.request_id] = commands

func _execute_reaction(command: Dictionary) -> void:
	if command.actor == null or not command.actor.is_alive:
		_refund_reaction(command)
		return
	match StringName(command.kind):
		&"relic": _relic_executor.execute_intent(command.intent)
		&"bastion": _bastion(command.actor, command.directive, command.context)
		&"automatic":
			if not _automatic_target_valid(command.actor, _spell(command.actor, command.spell_id), command.target):
				_refund_reaction(command)
				return
			var previous := _automatic_chain.duplicate()
			_automatic_chain.assign(command.get("chain", []))
			queue_automatic(command.actor, command.spell_id, command.target, command.multiplier, command.source_id, command)
			_automatic_chain.assign(previous)

func _resolve_reaction_choice(request: TacticalFollowupRequest, option: StringName) -> void:
	var commands: Array = _reaction_choices.get(request.request_id, [])
	_reaction_choices.erase(request.request_id)
	var ordered: Array[StringName] = [option]
	var group: StringName = &""
	for command in commands:
		group = StringName(command.group)
		if command.source_id == option:
			_execute_reaction(command)
		else:
			_refund_reaction(command)
			ordered.append(StringName(command.source_id))
	if group != &"":
		reaction_priority_overrides[group] = ordered
		reaction_priority_selected.emit(group, ordered)

func reaction_option_label(source: StringName) -> String:
	if str(source).contains("mobile_bastion"):
		return "Bastion mobile · consommer 20 % de la Garde"
	if str(source).contains("pelion_sentinel"):
		return "Sentinelle du Pélion · Tir de réponse à 60 %"
	if str(source).begins_with("relic:"):
		if str(source).contains("anchor") or str(source).contains("thetis"):
			return "Ancre de Thétis · consommer 30 % de la Garde"
		if str(source).contains("mirror") or str(source).contains("athena"):
			return "Miroir d’Athéna · renvoyer 50 % des dégâts absorbés"
	return str(source).replace("_", " ")


func spell_profile(actor: Unit, spell: Spell) -> Dictionary:
	return MasteryStaticModifierResolver.resolve_spell_profile(spell, actor.mastery_nodes)

func _apply_static_cast_profile(ctx: CastContext, profile: Dictionary) -> void:
	var actor := ctx.caster
	var spell := ctx.spell
	var shape_cells := preview_target_cells(actor, spell, ctx.cell)
	if not shape_cells.is_empty():
		ctx.affected_cells = shape_cells
	var base := spell.get_scaled_damage(actor)
	for index in ctx.affected_cells.size():
		var cell: Vector2i = ctx.affected_cells[index]
		var modified := MasteryStaticModifierResolver.resolve_target_damage(base, profile, index)
		ctx.damage_bonus_by_cell[cell] = int(ctx.damage_bonus_by_cell.get(cell, 0)) + modified - base
		var target := grid.get_unit(cell) as Unit
		if target != null and int(profile.get("push_distance", 0)) != spell.push_distance:
			ctx.push_distance_override_by_unit[target] = int(profile.push_distance)
	var shield_base := spell.get_scaled_shield(actor)
	if shield_base > 0:
		ctx.additional_shield_by_unit[actor] = int(ctx.additional_shield_by_unit.get(actor, 0)) \
			+ MasteryStaticModifierResolver.resolve_shield_amount(shield_base, profile) - shield_base

func get_cast_origin(actor: Unit, spell: Spell) -> Vector2i:
	return projectile_origin(actor, spell)


func preview_target_cells(actor: Unit, spell: Spell, center: Vector2i) -> Array:
	var profile := spell_profile(actor, spell)
	var result: Array = []
	var shape := StringName(profile.get("target_shape", &"SINGLE"))
	if shape == &"LINE":
		var cells: Array = [center]
		var direction := actor._snap_to_cardinal(center - get_cast_origin(actor, spell))
		var maximum := int(profile.get("maximum_targets", 1))
		if bool(profile.get("piercing_enabled", false)):
			var hits := 1
			var next := center + direction
			while grid.is_valid(next) and hits < maximum and grid.manhattan(get_cast_origin(actor, spell), next) <= caster.get_effective_spell_range(actor, spell):
				if not grid.is_projectile_passable(next):
					break
				var candidate := grid.get_unit(next) as Unit
				if candidate != null and candidate.team != actor.team and candidate.is_alive:
					cells.append(next)
					hits += 1
				next += direction
		else:
			for index in range(1, maximum):
				var cell: Vector2i = center + direction * index
				if grid.is_valid(cell) and grid.is_terrain_interactable(cell):
					cells.append(cell)
		result = cells
	elif shape == &"FAN":
		var direction := actor._snap_to_cardinal(center - get_cast_origin(actor, spell))
		var side := Vector2i(-direction.y, direction.x)
		result = [center]
		for offset in [-1, 1]:
			var cell: Vector2i = center + side * offset
			if grid.is_valid(cell) and pathfinder.has_line_of_sight(get_cast_origin(actor, spell), cell):
				result.append(cell)
	return result


func _free_path(actor: Unit, destination: Vector2i, maximum: int) -> Array:
	var frontier: Array = [actor.grid_pos]
	var distance: Dictionary = {actor.grid_pos: 0}
	var previous := {}
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if cell == destination:
			var path: Array = [cell]
			while previous.has(cell):
				cell = previous[cell]
				path.push_front(cell)
			return path
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = cell + direction
			if not grid.is_walkable(next, actor) or distance.has(next) or int(distance[cell]) >= maximum:
				continue
			distance[next] = int(distance[cell]) + 1
			previous[next] = cell
			frontier.append(next)
	return []

func on_unit_died(unit: Unit) -> void:
	_clear_guard_aura(unit)
	_remove_barriers(unit)
	if unit.mastery_runtime != null:
		unit.mastery_runtime.followup_queue.clear()


func _target_damage_multiplier(actor: Unit, target: Unit, hit: DamageResolver.HitContext, cast: Dictionary) -> float:
	if actor == null or actor.mastery_runtime == null or cast.is_empty():
		return 1.0
	var spell := cast.get("spell") as Spell
	var context := context_for(actor, {"target": target, "spell_id": hit.ability_id,
		"action_id": hit.action_id, "distance": grid.manhattan(projectile_origin(actor, spell), target.grid_pos)})
	var multiplier := 1.0
	var groups := {}
	var scale := float((cast.get("profile", {}) as Dictionary).get("conditional_bonus_scale", 1.0)) 		* float(_data(actor).get("conditional_bonus_scale", 1.0))
	for effect in actor.mastery_runtime.active_effects():
		if effect.event_id != &"spell_cast" or effect.effect_id != &"damage_multiplier" 				or effect.frequency != MasteryReactiveEffectData.Frequency.UNLIMITED:
			continue
		if not actor.mastery_runtime._conditions_pass(effect, context) or actor.mastery_runtime._is_recursive(effect, context):
			continue
		if effect.reaction_group != &"" and groups.has(effect.reaction_group) and (bool(groups[effect.reaction_group]) or not effect.stackable):
			continue
		var value := effect.multiplier
		multiplier *= 1.0 + (value - 1.0) * scale if value > 1.0 else value
		groups[effect.reaction_group] = not effect.stackable
	return multiplier


func _refund_reaction(command: Dictionary) -> void:
	if StringName(command.get("kind", &"")) == &"relic":
		if _relic_service != null:
			_relic_service.refund_tactical_intent(command.intent)
	else:
		var actor := command.get("actor") as Unit
		if actor != null and actor.mastery_runtime != null:
			actor.mastery_runtime.refund_frequency(StringName((command.get("directive", {}) as Dictionary).get("frequency_reservation", &"")))


func _distinct_damage_multiplier(actor: Unit, target: Unit, hit: DamageResolver.HitContext) -> float:
	if actor == null or actor.mastery_runtime == null or target.team == actor.team or hit.raw_damage <= 0:
		return 1.0
	var target_sources: Array[StringName] = []
	for effect in actor.mastery_runtime.active_effects():
		if effect.effect_id == &"track_distinct_offenses" or _is_target_bound_damage(actor, effect):
			target_sources.append(effect.source_id)
	var context := {"target": target, "spell_id": hit.ability_id, "action_id": hit.action_id,
		"only_source_ids": target_sources}
	var result := 1.0
	var profile := spell_profile(actor, _spell(actor, hit.ability_id))
	var scale := float(profile.get("conditional_bonus_scale", 1.0))
	for directive in dispatch(actor, &"spell_cast", context):
		if directive.get("kind", &"") == &"damage_multiplier":
			result *= 1.0 + (float(directive.get("multiplier", 1.0)) - 1.0) * scale
	return result


func _is_target_bound_damage(actor: Unit, effect: MasteryReactiveEffectData) -> bool:
	if effect.effect_id != &"consume_flag_damage" or effect.flag_id == &"":
		return false
	for source in actor.mastery_runtime.active_effects():
		if source.flag_id == effect.flag_id and source.flag_target_bound:
			return true
	return false
