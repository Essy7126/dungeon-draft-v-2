class_name RelicRuntimeService
extends RefCounted

signal active_relics_changed(count: int)
signal effect_evaluated(report: Dictionary)
signal tactical_intent_emitted(intent: Dictionary)

# Motifs renvoyés par manual_activation_state() et activate_relic_manually().
# L'interface s'en sert pour griser un bouton sans avoir à redevenir experte des
# règles de conditions et de fréquence.
const MANUAL_REASON_READY: StringName = &"ready"
const MANUAL_REASON_NOT_IN_COMBAT: StringName = &"not_in_combat"
const MANUAL_REASON_INVALID_HERO: StringName = &"invalid_hero"
const MANUAL_REASON_UNKNOWN_ITEM: StringName = &"unknown_item"
const MANUAL_REASON_NO_MANUAL_EFFECT: StringName = &"no_manual_effect"
const MANUAL_REASON_CONDITION_NOT_MET: StringName = &"condition_not_met"
const MANUAL_REASON_FREQUENCY_EXHAUSTED: StringName = &"frequency_exhausted"
const MANUAL_REASON_BUSY: StringName = &"busy"
const MANUAL_REASON_NO_EFFECT_APPLIED: StringName = &"no_effect_applied"

var registry := RelicEffectRegistry.new()
var action_classification_registry := CombatActionClassificationRegistry.new()
var _inventory: RunInventory = null
var _catalog: ItemCatalog = null
var _action_classification_catalog: CombatActionClassificationCatalogData = null
var _heroes: Array[Unit] = []
var _combat_units: Array = []
var _grid: GridData = null
var _active_relics: Array[Dictionary] = []
var _activations := {}
var _intent_frequency_reservations: Dictionary = {}
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
		heroes: Array,
		classification_catalog: CombatActionClassificationCatalogData = null
	) -> bool:
	dispose()
	if inventory == null or catalog == null:
		return false
	_inventory = inventory
	_catalog = catalog
	_action_classification_catalog = classification_catalog
	action_classification_registry = CombatActionClassificationRegistry.new()
	if classification_catalog != null \
			and not action_classification_registry.initialize(classification_catalog):
		dispose()
		return false
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
	_action_classification_catalog = null
	action_classification_registry = CombatActionClassificationRegistry.new()
	_heroes.clear()
	_combat_units.clear()
	_grid = null
	_active_relics.clear()
	_activations.clear()
	_intent_frequency_reservations.clear()
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
	var catalog := _catalog
	var classification_catalog := _action_classification_catalog
	if not initialize(inventory, catalog, heroes, classification_catalog):
		return false
	if was_in_combat:
		begin_combat(units, grid)
	return true


func begin_combat(units: Array, grid: GridData = null) -> void:
	_combat_serial += 1
	_turn_serial = 0
	_round_number = 0
	_activations.clear()
	_intent_frequency_reservations.clear()
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
	_intent_frequency_reservations.clear()
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
	if str(source_context.get("action_id", "")).begins_with("relic:"):
		return []
	var reports: Array[Dictionary] = []
	if _resolving or not _in_combat:
		return reports
	_resolving = true
	_event_serial += 1
	var context := source_context.duplicate(false)
	context["trigger_id"] = trigger_id
	context["event_serial"] = _event_serial
	var heroes := _trigger_heroes(context)
	for hero in heroes:
		var resolution := registry.resolve_reaction_candidates(
			_trigger_candidates(trigger_id, hero)
		)
		for suppressed in resolution.get("suppressed", []) as Array:
			var report := _suppressed_report(suppressed as Dictionary, hero, context)
			reports.append(report)
			effect_evaluated.emit(report.duplicate(true))
		for candidate in resolution.get("selected", []) as Array:
			var entry := candidate as Dictionary
			var report := _evaluate_effect(
				entry.instance as ItemInstance,
				entry.definition as ItemDefinition,
				int(entry.effect_index),
				entry.effect as ItemReactiveEffectData,
				hero,
				context,
			)
			reports.append(report)
			effect_evaluated.emit(report.duplicate(true))
	_resolving = false
	return reports


func _trigger_candidates(trigger_id: StringName, hero: Unit) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for relic in _active_relics:
		var definition := relic.definition as ItemDefinition
		var instance := relic.instance as ItemInstance
		if definition == null or instance == null:
			continue
		for effect_index in range(definition.reactive_effects.size()):
			var effect := definition.reactive_effects[effect_index]
			if effect == null or not effect.enabled or effect.trigger_id != trigger_id:
				continue
			candidates.append({
				"instance": instance,
				"definition": definition,
				"effect_index": effect_index,
				"effect": effect,
				"persistent_order": int(relic.get("persistent_order", 0)) * 1000 + effect_index,
				"stable_id": "%s:%d:%s" % [
					instance.instance_id, effect_index,
					hero.get_runtime_stable_id() if hero != null else &"",
				],
			})
	return candidates


func _suppressed_report(
		candidate: Dictionary,
		hero: Unit,
		context: Dictionary
	) -> Dictionary:
	var definition := candidate.get("definition") as ItemDefinition
	var instance := candidate.get("instance") as ItemInstance
	var effect := candidate.get("effect") as ItemReactiveEffectData
	return {
		"item_id": definition.item_id if definition != null else &"",
		"instance_id": instance.instance_id if instance != null else &"",
		"effect_index": int(candidate.get("effect_index", -1)),
		"trigger_id": effect.trigger_id if effect != null else &"",
		"reaction_group": effect.reaction_group if effect != null else &"",
		"priority": effect.priority if effect != null else 0,
		"scenario_id": context.get("scenario_id", &""),
		"triggered": false,
		"hero": hero,
		"target": null,
		"reason": "Réaction écartée par la priorité du groupe exclusif.",
		"reason_code": candidate.get("suppression_reason", &"reaction_group_conflict"),
		"winner_stable_id": candidate.get("winner_stable_id", &""),
		"before": {}, "after": {}, "remaining": -1,
	}


# ============================================================
# ACTIVATION MANUELLE — le joueur choisit le moment
# ============================================================
# process_trigger() balaie tous les reliques et tous les héros concernés par un
# événement. Une activation manuelle est l'inverse : une seule relique, un seul
# héros, à la demande. On réutilise donc les mêmes briques privées
# (_conditions_pass, _frequency_available, _evaluate_effect) sans les dupliquer,
# pour que les compteurs de fréquence restent partagés avec le chemin
# automatique.


# Liste les reliques que le joueur peut déclencher lui-même, pour alimenter la
# barre d'objets du combat.
func manual_activation_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for relic in _active_relics:
		var definition := relic.definition as ItemDefinition
		if definition != null and definition.has_manual_activation():
			result.append({
				"instance_id": (relic.instance as ItemInstance).instance_id,
				"definition": definition,
			})
	return result


# Réponse sans effet de bord : dit à l'interface si le bouton doit être
# cliquable, et pourquoi il ne l'est pas.
func manual_activation_state(hero: Unit, instance_id: StringName) -> Dictionary:
	if not _in_combat:
		return _manual_state(false, MANUAL_REASON_NOT_IN_COMBAT, "Aucun combat en cours.")
	if hero == null or hero.team != 0 or not hero.is_alive:
		return _manual_state(false, MANUAL_REASON_INVALID_HERO, "Aucun héros actif.")
	var relic := _find_active_relic(instance_id)
	if relic.is_empty():
		return _manual_state(false, MANUAL_REASON_UNKNOWN_ITEM, "Cet objet n’est plus dans ton sac.")
	var context := _manual_context(hero, instance_id, true)
	var definition := relic.definition as ItemDefinition
	var instance := relic.instance as ItemInstance
	var manual_effect_found := false
	var blocked_by_frequency := false
	for effect_index in range(definition.reactive_effects.size()):
		var effect := definition.reactive_effects[effect_index]
		if effect == null or not effect.enabled or not effect.is_manual_trigger():
			continue
		manual_effect_found = true
		if not registry.validate_effect(effect).is_empty():
			continue
		if not _conditions_pass(effect, hero, context, instance, effect_index):
			continue
		if not _frequency_available(effect, instance, effect_index, hero, context):
			blocked_by_frequency = true
			continue
		return _manual_state(
			true,
			MANUAL_REASON_READY,
			"Prêt à être utilisé.",
			_remaining_activations(effect, instance, effect_index, hero, context),
		)
	if not manual_effect_found:
		return _manual_state(
			false, MANUAL_REASON_NO_MANUAL_EFFECT, "Cet objet ne s’active pas à la main."
		)
	if blocked_by_frequency:
		return _manual_state(
			false, MANUAL_REASON_FREQUENCY_EXHAUSTED, "Déjà utilisé, il faut attendre.", 0
		)
	return _manual_state(
		false, MANUAL_REASON_CONDITION_NOT_MET, "Les conditions ne sont pas réunies."
	)


# Déclenche pour ce héros tous les effets manuels disponibles de cette relique,
# exactement comme process_trigger le ferait pour un déclencheur automatique.
func activate_relic_manually(hero: Unit, instance_id: StringName) -> Dictionary:
	var reports: Array[Dictionary] = []
	if _resolving:
		return _manual_result(false, MANUAL_REASON_BUSY, "Une autre action est en cours.", reports)
	var state := manual_activation_state(hero, instance_id)
	if not bool(state.get("available", false)):
		return _manual_result(
			false,
			StringName(state.get("reason", MANUAL_REASON_CONDITION_NOT_MET)),
			str(state.get("message", "")),
			reports,
		)
	var relic := _find_active_relic(instance_id)
	var definition := relic.definition as ItemDefinition
	var instance := relic.instance as ItemInstance
	_resolving = true
	_event_serial += 1
	var context := _manual_context(hero, instance_id, false)
	var applied := false
	for effect_index in range(definition.reactive_effects.size()):
		var effect := definition.reactive_effects[effect_index]
		if effect == null or not effect.enabled or not effect.is_manual_trigger():
			continue
		var report := _evaluate_effect(instance, definition, effect_index, effect, hero, context)
		reports.append(report)
		effect_evaluated.emit(report.duplicate(true))
		applied = applied or bool(report.get("triggered", false))
	_resolving = false
	if not applied:
		return _manual_result(
			false, MANUAL_REASON_NO_EFFECT_APPLIED, "L’objet n’a rien changé.", reports
		)
	return _manual_result(true, MANUAL_REASON_READY, "Objet activé.", reports)


func _find_active_relic(instance_id: StringName) -> Dictionary:
	for relic in _active_relics:
		var instance := relic.instance as ItemInstance
		if instance != null and instance.instance_id == instance_id:
			return relic
	return {}


# L'activation manuelle est sa propre action : chaque clic reçoit son propre
# action_id, pour qu'une fréquence « une fois par action » ne bloque jamais le
# clic suivant. La variante « aperçu » sert aux requêtes sans effet de bord.
func _manual_context(hero: Unit, instance_id: StringName, preview: bool) -> Dictionary:
	return {
		"trigger_hero": hero,
		"active_unit": hero,
		"trigger_id": ItemReactiveEffectData.TRIGGER_MANUAL_ACTIVATION,
		"event_serial": _event_serial,
		"manual": true,
		"preview_query": preview,
		"action_id": StringName(
			"manual_%s_preview" % instance_id
			if preview
			else "manual_%s_%d" % [instance_id, _event_serial]
		),
	}


func _manual_state(
		available: bool,
		reason: StringName,
		message: String,
		remaining := -1
	) -> Dictionary:
	return {
		"available": available,
		"reason": reason,
		"message": message,
		"remaining": remaining,
	}


func _manual_result(
		success: bool,
		reason: StringName,
		message: String,
		reports: Array[Dictionary]
	) -> Dictionary:
	return {
		"success": success,
		"reason": reason,
		"message": message,
		"reports": reports,
	}


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
		"reaction_group": effect.reaction_group,
		"priority": effect.priority,
		"tactical_intent": {},
	}
	if int(context.get("relic_reaction_depth", 0)) > 0:
		report.reason = "Une réaction issue d'une relique ne peut pas réamorcer une relique."
		report.reason_code = &"recursive_reaction_blocked"
		return report
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
	context.erase("tactical_intent")
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
	report.tactical_intent = (context.get("tactical_intent", {}) as Dictionary).duplicate(true)
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
			&"minimum_hp_loss_ratio":
				if float(context.get("hp_loss", 0)) \
						< float(hero.max_hp.get_int()) * condition.value:
					return false
			&"fully_absorbed":
				if not bool(context.get("fully_absorbed", false)):
					return false
			&"projectile":
				if not bool(context.get("projectile", false)):
					return false
			&"ability_id":
				if StringName(context.get("spell_id", &"")) != condition.string_name_value:
					return false
			&"guard_active":
				if not hero.get_shield_instances().any(func(shield: ShieldInstance) -> bool: return shield.tags.has(&"guard")):
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
		ItemReactiveEffectData.TARGET_EVENT_TARGET:
			var event_target := context.get("event_target") as Unit
			if event_target != null:
				result.append(event_target)
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
	var result_descriptor := registry.descriptor(
		RelicEffectRegistry.KIND_RESULT, effect.result_id
	)
	if StringName(result_descriptor.get(
			"execution", RelicEffectRegistry.EXECUTION_RUNTIME
		)) == RelicEffectRegistry.EXECUTION_INTENT:
		var intent := registry.build_tactical_intent(effect, {
			"item_id": instance.definition_id,
			"instance_id": instance.instance_id,
			"effect_index": effect_index,
			"actor_id": hero.get_runtime_stable_id() if hero != null else &"",
			"target_ids": _stable_target_ids(targets),
			"damage_source_id": _stable_unit_id(context.get("damage_source")),
			"event_target_id": _stable_unit_id(context.get("event_target")),
			"spell_id": StringName(context.get("spell_id", &"")),
			"hp_loss": int(context.get("hp_loss", 0)),
			"amount_absorbed": int(context.get("amount_absorbed", 0)),
			"action_id": StringName(context.get("action_id", &"")),
			"event_serial": _event_serial,
			"relic_reaction_depth": 1,
		})
		if intent.is_empty():
			return false
		if effect.frequency_id != ItemReactiveEffectData.FREQUENCY_UNLIMITED:
			var reservation := StringName("%s:%d:%s:%d" % [instance.instance_id, effect_index, _stable_unit_id(hero), _event_serial])
			var cooldown_key := _effect_hero_key(instance, effect_index, hero)
			_intent_frequency_reservations[reservation] = {
				"key": _frequency_key(effect, instance, effect_index, hero, context),
				"cooldown_key": cooldown_key,
				"cooldown_before": int(_cooldown_until.get(cooldown_key, 0)),
			}
			intent["frequency_reservation"] = reservation
		context["tactical_intent"] = intent
		tactical_intent_emitted.emit(intent.duplicate(true))
		return true
	if effect.result_id == ItemReactiveEffectData.RESULT_GRANT_SHIELD_MAX_HP:
		var shield_amount := maxi(1, int(ceil(float(hero.max_hp.get_int()) * effect.value)))
		var shield_options := _result_metadata(instance, effect_index)
		shield_options.merge({
			"shield_source_id": StringName("relic:%s" % instance.instance_id),
			"tags": [&"relic", &"emergency_guard"],
		}, true)
		return hero.add_shield(shield_amount, hero, shield_options) != null
	if effect.result_id == ItemReactiveEffectData.RESULT_LETHAL_REPRIEVE_CONSUME:
		var parameters := registry.parameter_values(effect)
		if hero.current_hp > 0 or _inventory == null \
				or not bool(parameters.get("consume_relic", false)):
			return false
		hero.current_hp = int(parameters.get("remaining_hp", 1))
		hero.hp_changed.emit(hero)
		var shield_amount := maxi(1, int(ceil(float(hero.max_hp.get_int()) * effect.value)))
		var shield_options := _result_metadata(instance, effect_index)
		shield_options.merge({
			"shield_source_id": StringName("relic:%s" % instance.instance_id),
			"tags": [&"relic", &"lethal_reprieve"],
		}, true)
		hero.add_shield(shield_amount, hero, shield_options)
		return bool(_inventory.remove_quantity(instance.instance_id, 1).get("success", false))
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
				target.heal(maxi(0, int(ceil(target.max_hp.get_int() * effect.value))), hero, _result_metadata(instance, effect_index))
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


func _stable_target_ids(targets: Array[Unit]) -> Array[StringName]:
	var result: Array[StringName] = []
	for target in targets:
		if target != null:
			result.append(target.get_runtime_stable_id())
	return result


func _stable_unit_id(value) -> StringName:
	return value.get_runtime_stable_id() if value is Unit else &""


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
		ItemReactiveEffectData.FREQUENCY_ACTIVATION:
			scope = "activation:%d" % (hero.activation_index if hero != null else -1)
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
		var persistent_order := 0
		for instance in _inventory.get_slots():
			if instance == null:
				persistent_order += 1
				continue
			var definition := _catalog.get_definition(instance.definition_id)
			if definition != null and definition.is_relic():
				_active_relics.append({
					"instance": instance,
					"definition": definition,
					"persistent_order": persistent_order,
				})
			persistent_order += 1
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
	EventBus.shield_absorption_resolved.connect(_on_shield_absorption_resolved)
	EventBus.hit_resolved.connect(_on_hit_resolved)
	EventBus.collision_impact.connect(_on_collision_impact)
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.lethal_hit_resolved.connect(_on_lethal_hit_resolved)
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
		[EventBus.shield_absorption_resolved, _on_shield_absorption_resolved],
		[EventBus.hit_resolved, _on_hit_resolved],
		[EventBus.collision_impact, _on_collision_impact],
		[EventBus.spell_cast, _on_spell_cast],
		[EventBus.lethal_hit_resolved, _on_lethal_hit_resolved],
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
	if target.current_hp <= 0:
		process_trigger(ItemReactiveEffectData.TRIGGER_LETHAL_HIT, context)


func _on_shield_absorption_resolved(fact: CombatEventFact) -> void:
	if fact == null or not fact.target is Unit or (fact.target as Unit).team != 0:
		return
	var hero := fact.target as Unit
	process_trigger(ItemReactiveEffectData.TRIGGER_SHIELD_ABSORPTION, {
		"trigger_hero": hero,
		"event_target": hero,
		"damage_source": fact.source,
		"amount_absorbed": fact.amount_absorbed,
		"attack_classification": fact.attack_classification,
		"guard_absorbed": fact.guard_absorbed,
		"source_absorption": fact.source_absorption.duplicate(true),
		"action_id": fact.action_id,
	})


func _on_hit_resolved(fact: CombatEventFact) -> void:
	if fact == null or not fact.target is Unit or (fact.target as Unit).team != 0:
		return
	var hero := fact.target as Unit
	var guard_absorbed := 0
	for absorption in fact.source_absorption:
		if (absorption.get("tags", []) as Array).has(&"guard"):
			guard_absorbed += int(absorption.get("amount_absorbed", 0))
	var classification := fact.attack_classification
	if classification == &"":
		classification = action_classification_registry.classification_for_ability(
			fact.ability_id
		)
	process_trigger(ItemReactiveEffectData.TRIGGER_HIT_RESOLVED, {
		"trigger_hero": hero,
		"event_target": hero,
		"damage_source": fact.source,
		"amount_absorbed": guard_absorbed,
		"fully_absorbed": fact.guard_absorbed and fact.amount_resolved > 0 \
			and fact.amount_applied == 0 \
			and guard_absorbed == fact.amount_resolved,
		"guard_absorbed": fact.guard_absorbed,
		"source_absorption": fact.source_absorption.duplicate(true),
		"attack_classification": classification,
		"projectile": classification == &"PROJECTILE",
		"action_id": fact.action_id,
	})


func _on_collision_impact(attacker, victim, damage: int) -> void:
	if not attacker is Unit or not victim is Unit or (attacker as Unit).team != 0:
		return
	process_trigger(ItemReactiveEffectData.TRIGGER_COLLISION_IMPACT, {
		"trigger_hero": attacker,
		"active_unit": attacker,
		"event_target": victim,
		"collision_damage": damage,
		"action_id": StringName("collision_%d" % _event_serial),
	})


func _on_spell_cast(caster, spell, report: Dictionary) -> void:
	if not caster is Unit or (caster as Unit).team != 0 or not spell is Spell or bool(report.get("automatic", false)):
		return
	process_trigger(ItemReactiveEffectData.TRIGGER_SPELL_CAST, {
		"trigger_hero": caster,
		"active_unit": caster,
		"spell_id": (spell as Spell).get_effective_spell_id(),
		"action_id": StringName(report.get("action_id", &"")),
	})


func _on_lethal_hit_resolved(target, attacker, _origin_cell: Vector2i) -> void:
	if not target is Unit or (target as Unit).team != 0:
		return
	process_trigger(ItemReactiveEffectData.TRIGGER_LETHAL_HIT, {
		"trigger_hero": target,
		"event_target": target,
		"damage_source": attacker,
		"action_id": StringName("lethal_%d" % _event_serial),
	})


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


func refund_tactical_intent(intent: Dictionary) -> bool:
	var reservation := StringName(intent.get("frequency_reservation", &""))
	if not _intent_frequency_reservations.has(reservation):
		return false
	var entry := _intent_frequency_reservations[reservation] as Dictionary
	_intent_frequency_reservations.erase(reservation)
	_activations[entry.key] = maxi(0, int(_activations.get(entry.key, 0)) - 1)
	_cooldown_until[entry.cooldown_key] = int(entry.cooldown_before)
	return true
