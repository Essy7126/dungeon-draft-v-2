class_name MasteryReactiveEffectRegistry
extends RefCounted

var _handlers: Dictionary = {}
var _labels: Dictionary = {}


func _init() -> void:
	_register_defaults()


func register_effect(
		effect_id: StringName,
		label: String,
		handler: Callable
	) -> bool:
	if effect_id == &"" or label.strip_edges().is_empty() \
			or not handler.is_valid() or _handlers.has(effect_id):
		return false
	_handlers[effect_id] = handler
	_labels[effect_id] = label
	return true


func has_effect(effect_id: StringName) -> bool:
	return _handlers.has(effect_id)


func registered_effect_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for value in _handlers.keys():
		result.append(StringName(value))
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return result


func validate_effect(effect: MasteryReactiveEffectData) -> PackedStringArray:
	var errors := PackedStringArray()
	if effect == null:
		errors.append("REACTIVE_EFFECT_NULL")
		return errors
	errors.append_array(effect.structural_errors())
	if not has_effect(effect.effect_id):
		errors.append("REACTIVE_EFFECT_UNREGISTERED: %s" % effect.effect_id)
	return errors


func resolve(
		effect: MasteryReactiveEffectData,
		context: Dictionary,
		runtime
	) -> Dictionary:
	var errors := validate_effect(effect)
	if not errors.is_empty():
		return {
			"applied": false,
			"reason": &"INVALID_EFFECT",
			"errors": errors,
			"directives": [],
		}
	var handler := _handlers[effect.effect_id] as Callable
	var result: Dictionary = handler.call(effect, context, runtime)
	if not result.has("applied"):
		result["applied"] = false
	if not result.has("reason"):
		result["reason"] = &""
	if not result.has("directives"):
		result["directives"] = []
	return result


func label(effect_id: StringName) -> String:
	return str(_labels.get(effect_id, effect_id))


func _register_defaults() -> void:
	for entry in [
		[MasteryReactiveEffectData.EFFECT_DAMAGE_MULTIPLIER, "Multiplicateur de dégâts", _damage_multiplier],
		[MasteryReactiveEffectData.EFFECT_APPLY_ARMOR_DELTA, "Variation temporaire d’Armure", _armor_delta],
		[MasteryReactiveEffectData.EFFECT_IGNORE_ARMOR, "Ignorer de l’Armure", _ignore_armor],
		[MasteryReactiveEffectData.EFFECT_SET_FLAG, "Mémoriser une condition", _set_flag],
		[MasteryReactiveEffectData.EFFECT_CONSUME_FLAG_DAMAGE, "Consommer une condition offensive", _consume_flag_damage],
		[MasteryReactiveEffectData.EFFECT_TRACK_DISTINCT_OFFENSES, "Suivre les techniques distinctes", _track_distinct_offenses],
		[MasteryReactiveEffectData.EFFECT_TRACK_ABSORPTION, "Cumuler les dégâts absorbés", _track_absorption],
		[MasteryReactiveEffectData.EFFECT_QUEUE_FOLLOWUP, "Proposer un suivi tactique", _queue_followup],
		[MasteryReactiveEffectData.EFFECT_NEXT_ACTIVATION_MP, "Modifier les PM suivants", _next_activation_mp],
		[MasteryReactiveEffectData.EFFECT_IGNORE_ENGAGEMENT, "Ignorer l’engagement", _ignore_engagement],
		[MasteryReactiveEffectData.EFFECT_MODIFY_RANGE, "Modifier la portée", _modify_range],
		[MasteryReactiveEffectData.EFFECT_MODIFY_SHIELD_DAMAGE, "Modifier les dégâts au bouclier", _modify_shield_damage],
		[MasteryReactiveEffectData.EFFECT_GRANT_SHIELD, "Créer un bouclier sourcé", _grant_shield],
		[MasteryReactiveEffectData.EFFECT_GUARD_AURA, "Appliquer l’aura de Garde", _guard_aura],
		[MasteryReactiveEffectData.EFFECT_BLOCK_CONTROL, "Bloquer un contrôle", _block_control],
		[MasteryReactiveEffectData.EFFECT_BASTION_IMPACT, "Résoudre un impact de bastion", _bastion_impact],
		[MasteryReactiveEffectData.EFFECT_AUTOMATIC_ATTACK, "Demander une attaque automatique", _automatic_attack],
		[MasteryReactiveEffectData.EFFECT_CREATE_BARRIER, "Créer une barrière temporaire", _create_barrier],
		[MasteryReactiveEffectData.EFFECT_RAW_DAMAGE_BONUS, "Ajouter des dégâts bruts", _raw_damage_bonus],
		[MasteryReactiveEffectData.EFFECT_RESTORE_SHIELD_SOURCE, "Restaurer une source de bouclier", _restore_shield_source],
		[MasteryReactiveEffectData.EFFECT_MODIFY_MOVEMENT_THRESHOLD, "Modifier un seuil de déplacement", _movement_threshold],
		[MasteryReactiveEffectData.EFFECT_MODIFY_ABSORPTION_THRESHOLD, "Modifier un seuil d’absorption", _absorption_threshold],
		[MasteryReactiveEffectData.EFFECT_MODIFY_CONDITIONAL_BONUS, "Amplifier un bonus conditionnel", _conditional_bonus],
		[MasteryReactiveEffectData.EFFECT_CHOOSE_PROJECTILE_ORIGIN, "Choisir l’origine d’un projectile", _queue_followup],
		[MasteryReactiveEffectData.EFFECT_CHOOSE_SHIELD_CONVERSION, "Choisir le devenir d’un bouclier", _queue_followup],
	]:
		register_effect(entry[0], entry[1], entry[2])


func _damage_multiplier(effect, _context, _runtime) -> Dictionary:
	return _applied(_directive(effect, &"damage_multiplier", {
		"multiplier": effect.multiplier,
		"target_spell_id": effect.target_spell_id,
	}))


func _armor_delta(effect, context, _runtime) -> Dictionary:
	return _applied(_directive(effect, &"armor_delta", {
		"amount": effect.flat_value,
		"target": context.get("target"),
		"expires_at": MasteryReactiveEffectData.scope_id(effect.scope),
	}))


func _ignore_armor(effect, _context, _runtime) -> Dictionary:
	return _applied(_directive(effect, &"ignore_armor", {
		"amount": effect.flat_value,
		"target_spell_id": effect.target_spell_id,
	}))


func _set_flag(effect, context, runtime) -> Dictionary:
	runtime.set_runtime_flag(effect.flag_id, effect.scope, context, {
		"target_id": context.get("target_id", &"") if effect.flag_target_bound else &"",
		"spell_id": context.get("spell_id", &""),
		"source_id": effect.source_id,
	})
	return _applied(_directive(effect, &"flag_set", {"flag_id": effect.flag_id}))


func _consume_flag_damage(effect, context, runtime) -> Dictionary:
	var payload: Dictionary = runtime.consume_runtime_flag(effect.flag_id, effect.scope, context)
	if payload.is_empty():
		return _not_applied(&"FLAG_NOT_AVAILABLE")
	return _applied(_directive(effect, &"damage_multiplier", {
		"multiplier": effect.multiplier,
		"target_spell_id": effect.target_spell_id,
		"consumed_flag_id": effect.flag_id,
	}))


func _track_distinct_offenses(effect, context, runtime) -> Dictionary:
	var distinct_count: int = int(runtime.track_distinct_offense(effect, context))
	if distinct_count < 2:
		return _not_applied(&"DISTINCT_OFFENSE_THRESHOLD_NOT_REACHED")
	var value: float = effect.multiplier if distinct_count == 2 else effect.secondary_multiplier
	return _applied(_directive(effect, &"damage_multiplier", {
		"multiplier": value,
		"distinct_offense_count": distinct_count,
	}))


func _track_absorption(effect, context, runtime) -> Dictionary:
	var accumulated: Dictionary = runtime.accumulate_absorption(effect, context)
	if not bool(accumulated.get("threshold_reached", false)):
		return _not_applied(&"ABSORPTION_THRESHOLD_NOT_REACHED", {
			"accumulated": accumulated.get("accumulated", 0),
		})
	runtime.set_runtime_flag(effect.flag_id, effect.scope, context, {
		"absorbed_amount": accumulated.get("accumulated", 0),
		"initial_shield": context.get("initial_shield", 0),
		"target_id": context.get("target_id", &"") if effect.flag_target_bound else &"",
	})
	return _applied(_directive(effect, &"absorption_threshold_reached", {
		"flag_id": effect.flag_id,
		"absorbed_amount": accumulated.get("accumulated", 0),
	}))


func _queue_followup(effect, context, runtime) -> Dictionary:
	var queued: Dictionary = runtime.queue_followup(effect, context)
	if not bool(queued.get("accepted", false)):
		return _not_applied(StringName(queued.get("reason", &"FOLLOWUP_REJECTED")))
	return _applied(_directive(effect, &"tactical_followup_queued", queued))


func _next_activation_mp(effect, context, _runtime) -> Dictionary:
	return _applied(_directive(effect, &"next_activation_mp", {
		"amount": effect.flat_value,
		"target": context.get("target"),
		"stackable": effect.stackable,
	}))


func _ignore_engagement(effect, _context, _runtime) -> Dictionary:
	return _applied(_directive(effect, &"ignore_engagement", {
		"points": maxi(1, effect.flat_value),
		"target_spell_id": effect.target_spell_id,
	}))


func _modify_range(effect, _context, _runtime) -> Dictionary:
	return _applied(_directive(effect, &"range_delta", {
		"amount": effect.flat_value,
		"minimum_range_override": effect.minimum_range_override,
		"target_spell_id": effect.target_spell_id,
	}))


func _modify_shield_damage(effect, context, _runtime) -> Dictionary:
	var value: float = effect.multiplier
	var sector := StringName(context.get("facing_sector", &"ANY"))
	if effect.directional_guard != null:
		if context.has("defender_cell") and context.has("defender_facing") \
				and context.has("attacker_cell"):
			value = DirectionalSectorResolver.damage_multiplier(
				effect.directional_guard,
				context.defender_cell,
				context.defender_facing,
				context.attacker_cell,
			)
			sector = DirectionalSectorResolver.classify(
				context.defender_cell,
				context.defender_facing,
				context.attacker_cell,
			)
	return _applied(_directive(effect, &"shield_damage_multiplier", {
		"multiplier": value,
		"facing_sector": sector,
	}))


func _grant_shield(effect, _context, _runtime) -> Dictionary:
	return _applied(_directive(effect, &"grant_sourced_shield", {
		"source_id": effect.source_id,
		"flat_value": effect.flat_value,
		"max_hp_ratio": effect.ratio_value,
		"expiry_scope": MasteryReactiveEffectData.scope_id(effect.scope),
	}))


func _guard_aura(effect, _context, _runtime) -> Dictionary:
	return _applied(_directive(effect, &"guard_aura", {
		"armor_bonus": effect.flat_value,
		"push_immunity": bool(effect.secondary_value & 1),
		"pull_immunity": bool(effect.secondary_value & 2),
	}))


func _block_control(effect, _context, _runtime) -> Dictionary:
	return _applied(_directive(effect, &"block_control", {
		"blocks_push": bool(effect.flat_value & 1),
		"blocks_pull": bool(effect.flat_value & 2),
		"blocks_mp_loss": bool(effect.flat_value & 4),
	}))


func _bastion_impact(effect, _context, _runtime) -> Dictionary:
	return _applied(_directive(effect, &"bastion_impact", {
		"shield_consumption_ratio": effect.ratio_value,
		"damage_cap_max_hp_ratio": effect.cap_max_hp_ratio,
		"push_adjacent_distance": effect.flat_value,
	}))


func _automatic_attack(effect, context, _runtime) -> Dictionary:
	var valid_targets: Array = context.get("valid_targets", [])
	if valid_targets.is_empty():
		return _not_applied(&"NO_VALID_TARGET")
	if effect.requires_line_of_sight \
			and context.has("line_of_sight_valid") \
			and not bool(context.get("line_of_sight_valid", false)):
		return _not_applied(&"LINE_OF_SIGHT_BLOCKED")
	return _applied(_directive(effect, &"automatic_attack", {
		"spell_id": effect.target_spell_id,
		"damage_multiplier": effect.multiplier,
		"valid_targets": valid_targets,
		"requires_line_of_sight": effect.requires_line_of_sight,
		"spends_action_points": false,
		"awards_xp": false,
		"consumes_manual_spell_use": false,
		"origin_source_chain_append": effect.source_id,
	}))


func _create_barrier(effect, context, _runtime) -> Dictionary:
	var barrier: TemporaryBarrierData = effect.temporary_barrier
	return _applied(_directive(effect, &"temporary_barrier", {
		"origin_cell": context.get("caster_cell"),
		"facing": context.get("caster_facing"),
		"line_length": barrier.line_length,
		"blocks_projectiles": barrier.blocks_projectiles,
		"enemy_movement_surcharge": barrier.enemy_movement_surcharge,
		"expiry_scope": barrier.expiry_scope,
		"personal_shield_multiplier": barrier.personal_shield_multiplier,
	}))


func _raw_damage_bonus(effect, context, runtime) -> Dictionary:
	var payload: Dictionary = runtime.consume_runtime_flag(effect.flag_id, effect.scope, context)
	if payload.is_empty():
		return _not_applied(&"FLAG_NOT_AVAILABLE")
	var amount := mini(
		int(payload.get("absorbed_amount", 0)),
		int(round(float(context.get("max_hp", 0)) * effect.cap_max_hp_ratio))
	)
	return _applied(_directive(effect, &"raw_damage_bonus", {
		"amount": maxi(0, amount),
		"target_spell_id": effect.target_spell_id,
	}))


func _restore_shield_source(effect, context, _runtime) -> Dictionary:
	return _applied(_directive(effect, &"restore_shield_source", {
		"source_id": context.get("guard_source_id", &""),
		"initial_value_ratio": effect.ratio_value,
	}))


func _movement_threshold(effect, _context, _runtime) -> Dictionary:
	return _applied(_directive(effect, &"movement_threshold_delta", {
		"amount": effect.flat_value,
		"minimum": effect.secondary_value,
	}))


func _absorption_threshold(effect, _context, _runtime) -> Dictionary:
	return _applied(_directive(effect, &"absorption_threshold_override", {
		"max_hp_ratio": effect.ratio_value,
	}))


func _conditional_bonus(effect, _context, _runtime) -> Dictionary:
	return _applied(_directive(effect, &"conditional_bonus_scale", {
		"multiplier": effect.multiplier,
	}))


func _directive(
		effect: MasteryReactiveEffectData,
		kind: StringName,
		values: Dictionary
	) -> Dictionary:
	var result := values.duplicate(false)
	result["kind"] = kind
	result["source_id"] = effect.source_id
	result["reaction_group"] = effect.reaction_group
	result["priority"] = effect.priority
	result["scope"] = MasteryReactiveEffectData.scope_id(effect.scope)
	return result


func _applied(directive: Dictionary) -> Dictionary:
	return {"applied": true, "reason": &"", "directives": [directive]}


func _not_applied(reason: StringName, values: Dictionary = {}) -> Dictionary:
	var result := values.duplicate(false)
	result["applied"] = false
	result["reason"] = reason
	result["directives"] = []
	return result
