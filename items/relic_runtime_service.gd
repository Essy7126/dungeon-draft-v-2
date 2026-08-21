class_name RelicRuntimeService
extends RefCounted

signal active_relics_changed(count: int)
signal effect_evaluated(report: Dictionary)

var registry := RelicEffectRegistry.new()
var _inventory: RunInventory = null
var _catalog: ItemCatalog = null
var _heroes: Array[Unit] = []
var _combat_units: Array = []
var _grid: GridData = null
var _active_relics: Array[Dictionary] = []
var _activations := {}
var _cooldown_until := {}
var _subscriptions_active := false
var _in_combat := false
var _resolving := false
var _turn_serial := 0
var _round_number := 0
var _combat_serial := 0
var _event_serial := 0


func initialize(
		inventory: RunInventory,
		catalog: ItemCatalog,
		heroes: Array
	) -> bool:
	dispose()
	if inventory == null or catalog == null:
		return false
	_inventory = inventory
	_catalog = catalog
	set_heroes(heroes)
	if not _inventory.changed.is_connected(_refresh_active_relics):
		_inventory.changed.connect(_refresh_active_relics)
	_connect_event_bus()
	_refresh_active_relics()
	return true


func dispose() -> void:
	if _inventory != null and _inventory.changed.is_connected(_refresh_active_relics):
		_inventory.changed.disconnect(_refresh_active_relics)
	_disconnect_event_bus()
	_inventory = null
	_catalog = null
	_heroes.clear()
	_combat_units.clear()
	_grid = null
	_active_relics.clear()
	_activations.clear()
	_cooldown_until.clear()
	_in_combat = false
	_resolving = false


func set_heroes(values: Array) -> void:
	_heroes.clear()
	for value in values:
		if value is Unit and (value as Unit).team == 0:
			_heroes.append(value as Unit)


func rebuild_after_restore(inventory: RunInventory, heroes: Array) -> bool:
	if _catalog == null:
		return false
	var was_in_combat := _in_combat
	var units := _combat_units.duplicate()
	var grid := _grid
	if not initialize(inventory, _catalog, heroes):
		return false
	if was_in_combat:
		begin_combat(units, grid)
	return true


func begin_combat(units: Array, grid: GridData = null) -> void:
	_combat_serial += 1
	_turn_serial = 0
	_round_number = 0
	_activations.clear()
	_cooldown_until.clear()
	_combat_units = units.duplicate()
	_grid = grid
	_in_combat = true
	process_trigger(ItemReactiveEffectData.TRIGGER_COMBAT_START, {
		"eligible_heroes": _living_heroes(),
		"active_unit": _living_heroes()[0] if not _living_heroes().is_empty() else null,
		"action_id": StringName("combat_%d" % _combat_serial),
	})


func end_combat() -> void:
	_in_combat = false
	_combat_units.clear()
	_grid = null
	_activations.clear()
	_cooldown_until.clear()
	_resolving = false


func active_relic_count() -> int:
	return _active_relics.size()


func active_relic_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in _active_relics:
		result.append((entry.definition as ItemDefinition).item_id)
	return result


func process_trigger(trigger_id: StringName, source_context: Dictionary) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	if _resolving or not _in_combat:
		return reports
	_resolving = true
	_event_serial += 1
	var context := source_context.duplicate(false)
	context["trigger_id"] = trigger_id
	context["event_serial"] = _event_serial
	var heroes := _trigger_heroes(context)
	for relic in _active_relics:
		var definition := relic.definition as ItemDefinition
		var instance := relic.instance as ItemInstance
		for effect_index in range(definition.reactive_effects.size()):
			var effect := definition.reactive_effects[effect_index]
			if effect == null or not effect.enabled or effect.trigger_id != trigger_id:
				continue
			for hero in heroes:
				var report := _evaluate_effect(instance, definition, effect_index, effect, hero, context)
				reports.append(report)
				effect_evaluated.emit(report.duplicate(true))
	_resolving = false
	return reports


func modify_voluntary_transition_cost(
		unit: Unit,
		from_cell: Vector2i,
		to_cell: Vector2i,
		base_cost: int
	) -> int:
	if not _in_combat or unit == null or unit.team != 0 or base_cost <= 0:
		return maxi(0, base_cost)
	var reduction := 0
	var context := {
		"trigger_hero": unit, "active_unit": unit, "voluntary": true,
		"distance": 1, "from_cell": from_cell, "to_cell": to_cell,
		"preview_query": true,
	}
	for relic in _active_relics:
		var definition := relic.definition as ItemDefinition
		var instance := relic.instance as ItemInstance
		for effect_index in range(definition.reactive_effects.size()):
			var effect := definition.reactive_effects[effect_index]
			if effect == null or not effect.enabled \
					or effect.trigger_id != ItemReactiveEffectData.TRIGGER_VOLUNTARY_MOVE_PREPARED \
					or effect.result_id != ItemReactiveEffectData.RESULT_REDUCE_VOLUNTARY_MOVE_COST:
				continue
			if registry.validate_effect(effect).is_empty() \
					and _conditions_pass(effect, unit, context, instance, effect_index) \
					and _frequency_available(effect, instance, effect_index, unit, context):
				reduction += maxi(0, int(round(effect.value)))
	return maxi(0, base_cost - reduction)


func can_intercept(
		unit: Unit,
		trigger_id: StringName,
		context: Dictionary
	) -> bool:
	if not _in_combat or unit == null:
		return false
	var query := context.duplicate(false)
	query["trigger_hero"] = unit
	query["active_unit"] = context.get("active_unit", unit)
	for relic in _active_relics:
		var definition := relic.definition as ItemDefinition
		var instance := relic.instance as ItemInstance
		for effect_index in range(definition.reactive_effects.size()):
			var effect := definition.reactive_effects[effect_index]
			if effect != null and effect.enabled and effect.trigger_id == trigger_id \
					and effect.result_id == ItemReactiveEffectData.RESULT_CANCEL_IN_PROGRESS \
					and registry.validate_effect(effect).is_empty() \
					and _conditions_pass(effect, unit, query, instance, effect_index) \
					and _frequency_available(effect, instance, effect_index, unit, query):
				return true
	return false


func try_intercept(
		unit: Unit,
		trigger_id: StringName,
		source_context: Dictionary
	) -> bool:
	if _resolving or not can_intercept(unit, trigger_id, source_context):
		return false
	_resolving = true
	_event_serial += 1
	var context := source_context.duplicate(false)
	context.merge({
		"trigger_id": trigger_id,
		"trigger_hero": unit,
		"active_unit": context.get("active_unit", unit),
		"event_serial": _event_serial,
		"interceptable": true,
	}, true)
	for relic in _active_relics:
		var definition := relic.definition as ItemDefinition
		var instance := relic.instance as ItemInstance
		for effect_index in range(definition.reactive_effects.size()):
			var effect := definition.reactive_effects[effect_index]
			if effect == null or not effect.enabled or effect.trigger_id != trigger_id \
					or effect.result_id != ItemReactiveEffectData.RESULT_CANCEL_IN_PROGRESS:
				continue
			var report := _evaluate_effect(instance, definition, effect_index, effect, unit, context)
			effect_evaluated.emit(report.duplicate(true))
			if bool(report.get("triggered", false)):
				_resolving = false
				return true
	_resolving = false
	return false


func _evaluate_effect(
		instance: ItemInstance,
		definition: ItemDefinition,
		effect_index: int,
		effect: ItemReactiveEffectData,
		hero: Unit,
		context: Dictionary
	) -> Dictionary:
	var report := {
		"item_id": definition.item_id, "instance_id": instance.instance_id,
		"effect_index": effect_index, "trigger_id": effect.trigger_id,
		"scenario_id": context.get("scenario_id", &""),
		"triggered": false, "hero": hero,
		"target": null, "reason": "", "before": {}, "after": {},
		"remaining": -1,
	}
	var validation := registry.validate_effect(effect)
	if not validation.is_empty():
		report.reason = str(validation[0].get("message", "Combinaison invalide."))
		return report
	if effect.trigger_id == ItemReactiveEffectData.TRIGGER_HP_THRESHOLD_CROSSED \
			and not (
				float(context.get("hp_before_ratio", 0.0)) > effect.threshold
				and float(context.get("hp_after_ratio", 1.0)) <= effect.threshold
			):
		report.reason = "Le seuil de PV configuré n’a pas été franchi."
		return report
	if not _conditions_pass(effect, hero, context, instance, effect_index):
		report.reason = "Une condition configurée n’est pas remplie."
		return report
	if not _frequency_available(effect, instance, effect_index, hero, context):
		report.reason = "La fréquence de recharge est épuisée."
		report.remaining = 0
		return report
	var targets := _resolve_targets(effect.target_id, hero, context)
	if targets.is_empty():
		report.reason = "La cible configurée est absente de l’événement."
		return report
	var before := _targets_snapshot(targets)
	var applied := _apply_result(effect, targets, hero, context, instance, effect_index)
	if not applied:
		report.reason = "Le résultat n’a produit aucun effet valide."
		return report
	_consume_frequency(effect, instance, effect_index, hero, context)
	report.triggered = true
	report.reason = "Déclencheur, conditions, cible et fréquence validés."
	report.target = targets[0] if targets.size() == 1 else targets
	report.before = before
	report.after = _targets_snapshot(targets)
	report.remaining = _remaining_activations(effect, instance, effect_index, hero, context)
	return report


func _conditions_pass(
		effect: ItemReactiveEffectData,
		hero: Unit,
		context: Dictionary,
		instance: ItemInstance,
		effect_index: int
	) -> bool:
	for condition in effect.conditions:
		if condition == null:
			return false
		match condition.condition_id:
			&"trigger_team":
				if hero.team != condition.team:
					return false
			&"enemy_source_required":
				if not bool(context.get("enemy_source", false)):
					return false
			&"real_hp_loss_positive":
				if int(context.get("hp_loss", 0)) <= 0:
					return false
			&"hp_percent":
				if not _compare(_hp_ratio(hero), condition.comparison, condition.value):
					return false
			&"ap":
				if not _compare(float(hero.current_ap), condition.comparison, condition.value):
					return false
			&"mp":
				if not _compare(float(hero.current_mp), condition.comparison, condition.value):
					return false
			&"adjacent_unit":
				var active := context.get("active_unit") as Unit
				if active == null or not _are_adjacent(hero, active):
					return false
			&"voluntary_only":
				if not bool(context.get("voluntary", false)):
					return false
			&"minimum_distance":
				if float(context.get("distance", 0)) < condition.value:
					return false
			&"kill_by_hero":
				if context.get("killer") != hero:
					return false
			&"first_in_frequency":
				if _activation_count(effect, instance, effect_index, hero, context) != 0:
					return false
			_:
				return false
	return true


func _resolve_targets(target_id: StringName, hero: Unit, context: Dictionary) -> Array[Unit]:
	var result: Array[Unit] = []
	match target_id:
		ItemReactiveEffectData.TARGET_TRIGGER_HERO:
			result.append(hero)
		ItemReactiveEffectData.TARGET_DAMAGE_SOURCE:
			var source := context.get("damage_source") as Unit
			if source != null:
				result.append(source)
		ItemReactiveEffectData.TARGET_KILLED_UNIT:
			var killed := context.get("killed_unit") as Unit
			if killed != null:
				result.append(killed)
		ItemReactiveEffectData.TARGET_ACTIVE_UNIT:
			var active := context.get("active_unit") as Unit
			if active != null:
				result.append(active)
		ItemReactiveEffectData.TARGET_ALL_CONTROLLED_HEROES:
			result = _living_heroes()
	return result


func _apply_result(
		effect: ItemReactiveEffectData,
		targets: Array[Unit],
		hero: Unit,
		context: Dictionary,
		instance: ItemInstance,
		effect_index: int
	) -> bool:
	if effect.result_id == ItemReactiveEffectData.RESULT_REDUCE_VOLUNTARY_MOVE_COST:
		return true
	if effect.result_id == ItemReactiveEffectData.RESULT_CANCEL_IN_PROGRESS:
		context["cancelled"] = true
		return true
	var changed := false
	for target in targets:
		if target == null or not target.is_alive:
			continue
		var amount := int(round(effect.value))
		match effect.result_id:
			ItemReactiveEffectData.RESULT_CURRENT_AP:
				var before_ap := target.current_ap
				target.current_ap = maxi(0, target.current_ap + amount)
				EventBus.ap_changed.emit(target, target.current_ap, target.max_ap.get_int())
				target.stats_changed.emit(target)
				changed = changed or before_ap != target.current_ap
			ItemReactiveEffectData.RESULT_NEXT_TURN_AP:
				target.next_turn_ap_modifier += amount
				changed = amount != 0 or changed
			ItemReactiveEffectData.RESULT_CURRENT_MP:
				var before_mp := target.current_mp
				target.current_mp = maxi(0, target.current_mp + amount)
				target.stats_changed.emit(target)
				changed = changed or before_mp != target.current_mp
			ItemReactiveEffectData.RESULT_NEXT_TURN_MP:
				target.queue_next_turn_mp_modifier(amount)
				changed = amount != 0 or changed
			ItemReactiveEffectData.RESULT_HEAL_FLAT:
				var before_hp := target.current_hp
				target.heal(maxi(0, amount), hero, _result_metadata(instance, effect_index))
				changed = changed or before_hp != target.current_hp
			ItemReactiveEffectData.RESULT_HEAL_MAX_HP_PERCENT:
				var before_hp := target.current_hp
				target.heal(maxi(0, int(round(target.max_hp.get_int() * effect.value))), hero, _result_metadata(instance, effect_index))
				changed = changed or before_hp != target.current_hp
			ItemReactiveEffectData.RESULT_PAY_HP_FLAT, ItemReactiveEffectData.RESULT_PAY_HP_PERCENT:
				var cost := maxi(0, amount) if effect.result_id == ItemReactiveEffectData.RESULT_PAY_HP_FLAT \
					else maxi(0, int(round(target.max_hp.get_int() * effect.value)))
				var paid := mini(maxi(0, target.current_hp - 1), cost)
				if paid > 0:
					target.current_hp -= paid
					target.hp_changed.emit(target)
					EventBus.health_cost_paid.emit(target, paid, _result_metadata(instance, effect_index))
					changed = true
	return changed


func _frequency_available(
		effect: ItemReactiveEffectData,
		instance: ItemInstance,
		effect_index: int,
		hero: Unit,
		context: Dictionary
	) -> bool:
	if effect.frequency_id == ItemReactiveEffectData.FREQUENCY_UNLIMITED:
		return true
	var base_key := _effect_hero_key(instance, effect_index, hero)
	if effect.frequency_id == ItemReactiveEffectData.FREQUENCY_COOLDOWN_TURNS \
			and _turn_serial < int(_cooldown_until.get(base_key, 0)):
		return false
	return _activation_count(effect, instance, effect_index, hero, context) < effect.max_activations


func _consume_frequency(
		effect: ItemReactiveEffectData,
		instance: ItemInstance,
		effect_index: int,
		hero: Unit,
		context: Dictionary
	) -> void:
	if effect.frequency_id == ItemReactiveEffectData.FREQUENCY_UNLIMITED:
		return
	var key := _frequency_key(effect, instance, effect_index, hero, context)
	_activations[key] = int(_activations.get(key, 0)) + 1
	if effect.frequency_id == ItemReactiveEffectData.FREQUENCY_COOLDOWN_TURNS \
			and int(_activations[key]) >= effect.max_activations:
		_cooldown_until[_effect_hero_key(instance, effect_index, hero)] = _turn_serial + effect.recharge_turns


func _activation_count(effect, instance, effect_index, hero, context) -> int:
	return int(_activations.get(_frequency_key(effect, instance, effect_index, hero, context), 0))


func _remaining_activations(effect, instance, effect_index, hero, context) -> int:
	if effect.frequency_id == ItemReactiveEffectData.FREQUENCY_UNLIMITED:
		return -1
	return maxi(0, effect.max_activations - _activation_count(effect, instance, effect_index, hero, context))


func _frequency_key(effect, instance, effect_index, hero, context) -> String:
	var scope := "combat:%d" % _combat_serial
	match effect.frequency_id:
		ItemReactiveEffectData.FREQUENCY_ACTION:
			scope = "action:%s" % context.get("action_id", "event_%d" % context.get("event_serial", _event_serial))
		ItemReactiveEffectData.FREQUENCY_TURN:
			scope = "turn:%d" % _turn_serial
		ItemReactiveEffectData.FREQUENCY_ROUND:
			scope = "round:%d" % _round_number
		ItemReactiveEffectData.FREQUENCY_COOLDOWN_TURNS:
			scope = "cooldown:%d" % int(_cooldown_until.get(_effect_hero_key(instance, effect_index, hero), 0))
	return "%s:%s" % [_effect_hero_key(instance, effect_index, hero), scope]


func _effect_hero_key(instance: ItemInstance, effect_index: int, hero: Unit) -> String:
	return "%s:%d:%s" % [instance.instance_id, effect_index, hero.get_runtime_stable_id()]


func _trigger_heroes(context: Dictionary) -> Array[Unit]:
	var explicit := context.get("eligible_heroes", []) as Array
	if not explicit.is_empty():
		var result: Array[Unit] = []
		for value in explicit:
			if value is Unit and (value as Unit).team == 0 and (value as Unit).is_alive:
				result.append(value as Unit)
		return result
	var hero := context.get("trigger_hero") as Unit
	var result: Array[Unit] = []
	if hero != null and hero.team == 0 and hero.is_alive:
		result.append(hero)
	return result


func _living_heroes() -> Array[Unit]:
	var result: Array[Unit] = []
	for hero in _heroes:
		if hero != null and hero.is_alive:
			result.append(hero)
	return result


func _targets_snapshot(targets: Array[Unit]) -> Dictionary:
	var result := {}
	for target in targets:
		if target != null:
			result[target.get_runtime_stable_id()] = {
				"hp": target.current_hp, "ap": target.current_ap, "mp": target.current_mp,
				"next_ap": target.next_turn_ap_modifier,
				"next_mp": target.next_turn_mp_bonus - target.next_turn_mp_penalty,
			}
	return result


func _result_metadata(instance: ItemInstance, effect_index: int) -> Dictionary:
	return {
		"action_id": StringName("relic_%s_%d" % [instance.instance_id, effect_index]),
		"impact_id": StringName("relic_%s_%d_%d" % [instance.instance_id, effect_index, _event_serial]),
		"origin": &"relic",
		"relic_instance_id": instance.instance_id,
	}


func _compare(left: float, comparison: StringName, right: float) -> bool:
	match comparison:
		&"equal": return is_equal_approx(left, right)
		&"less": return left < right
		&"less_or_equal": return left <= right
		&"greater": return left > right
		&"greater_or_equal": return left >= right
	return false


func _hp_ratio(unit: Unit) -> float:
	return float(unit.current_hp) / float(maxi(1, unit.max_hp.get_int()))


func _are_adjacent(first: Unit, second: Unit) -> bool:
	return first != null and second != null \
		and abs(first.grid_pos.x - second.grid_pos.x) + abs(first.grid_pos.y - second.grid_pos.y) == 1


func _refresh_active_relics() -> void:
	_active_relics.clear()
	if _inventory != null and _catalog != null:
		for instance in _inventory.get_slots():
			if instance == null:
				continue
			var definition := _catalog.get_definition(instance.definition_id)
			if definition != null and definition.is_relic():
				_active_relics.append({"instance": instance, "definition": definition})
	active_relics_changed.emit(_active_relics.size())


func _connect_event_bus() -> void:
	if _subscriptions_active:
		return
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.round_started.connect(_on_round_started)
	EventBus.action_resolved.connect(_on_action_resolved)
	EventBus.ap_after_action_changed.connect(_on_ap_after_action_changed)
	EventBus.voluntary_movement_prepared.connect(_on_voluntary_movement_prepared)
	EventBus.voluntary_movement_resolved.connect(_on_voluntary_movement_resolved)
	EventBus.hp_damage_taken.connect(_on_hp_damage_taken)
	EventBus.unit_killed.connect(_on_unit_killed)
	_subscriptions_active = true


func _disconnect_event_bus() -> void:
	if not _subscriptions_active:
		return
	for pair in [
		[EventBus.combat_started, _on_combat_started], [EventBus.combat_ended, _on_combat_ended],
		[EventBus.turn_started, _on_turn_started], [EventBus.turn_ended, _on_turn_ended],
		[EventBus.round_started, _on_round_started], [EventBus.action_resolved, _on_action_resolved],
		[EventBus.ap_after_action_changed, _on_ap_after_action_changed],
		[EventBus.voluntary_movement_prepared, _on_voluntary_movement_prepared],
		[EventBus.voluntary_movement_resolved, _on_voluntary_movement_resolved],
		[EventBus.hp_damage_taken, _on_hp_damage_taken], [EventBus.unit_killed, _on_unit_killed],
	]:
		var event_signal := pair[0] as Signal
		var callback := pair[1] as Callable
		if event_signal.is_connected(callback):
			event_signal.disconnect(callback)
	_subscriptions_active = false


func _on_combat_started(units: Array, grid: GridData) -> void:
	begin_combat(units, grid)


func _on_combat_ended(_victory: bool) -> void:
	end_combat()


func _on_turn_started(unit: Unit) -> void:
	if not _in_combat:
		return
	_turn_serial += 1
	process_trigger(ItemReactiveEffectData.TRIGGER_TURN_START, _unit_context(unit))


func _on_turn_ended(unit: Unit, _reason: StringName) -> void:
	if not _in_combat:
		return
	process_trigger(ItemReactiveEffectData.TRIGGER_TURN_END, _unit_context(unit))
	if unit != null and unit.team != 0:
		var adjacent: Array[Unit] = []
		for hero in _living_heroes():
			if _are_adjacent(hero, unit):
				adjacent.append(hero)
		process_trigger(ItemReactiveEffectData.TRIGGER_ADJACENT_ENEMY_TURN_END, {
			"active_unit": unit, "eligible_heroes": adjacent,
		})


func _on_round_started(number: int) -> void:
	_round_number = number


func _on_action_resolved(actor: Unit, action_id: StringName, kind: StringName, metadata: Dictionary) -> void:
	var context := _unit_context(actor)
	context.merge(metadata, true)
	context["action_id"] = action_id
	context["action_kind"] = kind
	process_trigger(ItemReactiveEffectData.TRIGGER_ACTION_RESOLVED, context)


func _on_ap_after_action_changed(unit: Unit, before: int, after: int, action_id: StringName) -> void:
	var context := _unit_context(unit)
	context.merge({"ap_before": before, "ap_after": after, "action_id": action_id}, true)
	process_trigger(ItemReactiveEffectData.TRIGGER_AP_AFTER_ACTION, context)


func _on_voluntary_movement_prepared(unit: Unit, path: Array, base_cost: int, effective_cost: int, action_id: StringName) -> void:
	var context := _unit_context(unit)
	context.merge({
		"path": path, "distance": maxi(0, path.size() - 1), "voluntary": true,
		"base_cost": base_cost, "effective_cost": effective_cost,
		"action_id": action_id, "interceptable": true,
	}, true)
	process_trigger(ItemReactiveEffectData.TRIGGER_VOLUNTARY_MOVE_PREPARED, context)


func _on_voluntary_movement_resolved(unit: Unit, path: Array, paid_cost: int, action_id: StringName) -> void:
	var context := _unit_context(unit)
	context.merge({
		"path": path, "distance": maxi(0, path.size() - 1), "voluntary": true,
		"paid_cost": paid_cost, "action_id": action_id,
	}, true)
	process_trigger(ItemReactiveEffectData.TRIGGER_VOLUNTARY_MOVE_RESOLVED, context)


func _on_hp_damage_taken(fact: CombatEventFact) -> void:
	if fact == null or not fact.target is Unit or (fact.target as Unit).team != 0:
		return
	var target := fact.target as Unit
	var source := fact.source as Unit
	var before_ratio := float(target.current_hp + fact.amount_applied) / float(maxi(1, target.max_hp.get_int()))
	var after_ratio := _hp_ratio(target)
	var context := _unit_context(target)
	context.merge({
		"damage_source": source, "enemy_source": source != null and source.team != target.team,
		"hp_loss": fact.amount_applied, "hp_before_ratio": before_ratio,
		"hp_after_ratio": after_ratio, "action_id": fact.action_id,
	}, true)
	process_trigger(ItemReactiveEffectData.TRIGGER_HP_LOST, context)
	process_trigger(ItemReactiveEffectData.TRIGGER_HP_THRESHOLD_CROSSED, context)


func _on_unit_killed(unit: Unit, killer: Unit) -> void:
	if killer == null or killer.team != 0:
		return
	var context := _unit_context(killer)
	context.merge({"killer": killer, "killed_unit": unit}, true)
	process_trigger(ItemReactiveEffectData.TRIGGER_UNIT_KILLED, context)


func _unit_context(unit: Unit) -> Dictionary:
	return {
		"trigger_hero": unit if unit != null and unit.team == 0 else null,
		"active_unit": unit,
	}
