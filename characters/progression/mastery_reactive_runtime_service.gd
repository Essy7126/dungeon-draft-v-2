class_name MasteryReactiveRuntimeService
extends RefCounted

signal effect_evaluated(report: Dictionary)
signal tactical_followup_queued(request: TacticalFollowupRequest)

var registry := MasteryReactiveEffectRegistry.new()
var followup_queue := TacticalFollowupQueue.new()

var _effects: Array[MasteryReactiveEffectData] = []
var _frequency_counters: Dictionary = {}
var _frequency_reservations: Dictionary = {}
var _flags: Dictionary = {}
var _accumulators: Dictionary = {}
var _distinct_offenses: Dictionary = {}
var _resolving_source_ids: Array[StringName] = []
var _telemetry: Array[Dictionary] = []
var _event_serial: int = 0
var _run_serial: int = 0
var _combat_serial: int = 0
var _activation_serial: int = 0


func _init() -> void:
	# A named callable does not capture this RefCounted owner in its own queue.
	followup_queue.request_queued.connect(_on_followup_request_queued)


func _on_followup_request_queued(request: TacticalFollowupRequest) -> void:
	tactical_followup_queued.emit(request)


func configure(effects: Array[MasteryReactiveEffectData], preserve_runtime_state: bool = false) -> PackedStringArray:
	_effects.clear()
	var errors := PackedStringArray()
	var source_ids := {}
	for effect in effects:
		if effect == null:
			errors.append("REACTIVE_EFFECT_NULL")
			continue
		for message in registry.validate_effect(effect):
			errors.append("%s: %s" % [effect.source_id, message])
		if source_ids.has(effect.source_id):
			errors.append("REACTIVE_SOURCE_DUPLICATE: %s" % effect.source_id)
		source_ids[effect.source_id] = true
		_effects.append(effect)
	_effects.sort_custom(_sort_effects)
	if not preserve_runtime_state:
		reset_run()
	return errors


func configure_from_nodes(nodes: Array[SkillTreeNodeData], preserve_runtime_state: bool = false) -> PackedStringArray:
	var effects: Array[MasteryReactiveEffectData] = []
	for node in nodes:
		if node == null:
			continue
		for effect in node.reactive_effects:
			if effect != null:
				effects.append(effect)
	return configure(effects, preserve_runtime_state)


func active_effects() -> Array[MasteryReactiveEffectData]:
	return _effects.duplicate()


func reset_run() -> void:
	_run_serial += 1
	_combat_serial = 0
	_activation_serial = 0
	_event_serial = 0
	_frequency_counters.clear()
	_frequency_reservations.clear()
	_flags.clear()
	_accumulators.clear()
	_distinct_offenses.clear()
	_resolving_source_ids.clear()
	_telemetry.clear()
	followup_queue.clear()


func process_event(
		event_id: StringName,
		source_context: Dictionary = {}
	) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	_event_serial += 1
	if event_id == MasteryReactiveEffectData.EVENT_COMBAT_STARTED:
		# Une requête laissée par le combat précédent ne traverse jamais la
		# frontière de combat. Le nouveau combat reçoit ensuite son propre token.
		followup_queue.expire_scope(&"ACTION")
		followup_queue.expire_scope(&"ACTIVATION")
		followup_queue.expire_scope(&"UNTIL_NEXT_ACTIVATION")
		followup_queue.expire_scope(&"COMBAT")
		_combat_serial += 1
		_activation_serial = 0
		for key in _flags.keys():
			if int((_flags[key] as Dictionary).get("scope", -1)) != MasteryReactiveEffectData.Scope.RUN:
				_flags.erase(key)
		for key in _accumulators.keys():
			if str(key).get_slice("|", 1) != str(MasteryReactiveEffectData.Scope.RUN):
				_accumulators.erase(key)
	if event_id == MasteryReactiveEffectData.EVENT_ACTIVATION_STARTED:
		# ACTIVATION signifie « à résoudre pendant l'activation qui l'a créée ».
		# Le nettoyage précède l'évaluation de l'événement afin qu'un choix créé
		# au nouveau début d'activation reste disponible.
		followup_queue.expire_scope(&"ACTION")
		followup_queue.expire_scope(&"ACTIVATION")
		_activation_serial += 1
		_expire_deferred_flags()
		for key in _accumulators.keys():
			if str(key).get_slice("|", 1) == str(MasteryReactiveEffectData.Scope.UNTIL_NEXT_ACTIVATION):
				_accumulators.erase(key)
		followup_queue.expire_scope(&"UNTIL_NEXT_ACTIVATION")
	var context := source_context.duplicate(false)
	context["event_id"] = event_id
	context["event_serial"] = int(context.get("event_serial", _event_serial))
	context["run_id"] = StringName(context.get("run_id", "run_%d" % _run_serial))
	context["combat_id"] = StringName(context.get("combat_id", "combat_%d" % _combat_serial))
	context["activation_id"] = StringName(context.get(
		"activation_id", "activation_%d" % _activation_serial
	))
	context["action_id"] = StringName(context.get(
		"action_id", "event_%d" % _event_serial
	))
	var reaction_groups := {}
	for effect in _effects:
		if effect.event_id != event_id:
			continue
		if context.has("only_effect_ids") and not (context.get("only_effect_ids", []) as Array).has(effect.effect_id):
			continue
		if context.has("only_source_ids") and not (context.get("only_source_ids", []) as Array).has(effect.source_id):
			continue
		var report := _evaluate_effect(effect, context, reaction_groups)
		reports.append(report)
		_telemetry.append(report.duplicate(true))
		effect_evaluated.emit(report.duplicate(true))
		if bool(report.get("triggered", false)) and effect.reaction_group != &"":
			var group_state: Dictionary = reaction_groups.get(effect.reaction_group, {
				"has_non_stackable": false,
				"count": 0,
			})
			group_state.count = int(group_state.count) + 1
			group_state.has_non_stackable = bool(group_state.has_non_stackable) \
				or not effect.stackable
			reaction_groups[effect.reaction_group] = group_state
	return reports


func telemetry_reports() -> Array[Dictionary]:
	return _telemetry.duplicate(true)


func clear_telemetry() -> void:
	_telemetry.clear()


func set_runtime_flag(
		flag_id: StringName,
		scope: MasteryReactiveEffectData.Scope,
		context: Dictionary,
		payload: Dictionary = {}
	) -> void:
	if flag_id == &"":
		return
	var key := _state_key(flag_id, scope, context)
	var bound_target := StringName(payload.get("target_id", &""))
	if bound_target != &"":
		key += "|target:%s" % bound_target
	_flags[key] = {
		"flag_id": flag_id,
		"scope": scope,
		"scope_token": _scope_token(scope, context),
		"payload": payload.duplicate(true),
		"expires_after_activation": _activation_serial + 1,
	}


func has_runtime_flag(
		flag_id: StringName,
		scope: MasteryReactiveEffectData.Scope,
		context: Dictionary
	) -> bool:
	var key := _flag_key_for_context(flag_id, scope, context)
	if not _flags.has(key):
		return false
	var entry := _flags[key] as Dictionary
	var payload := entry.get("payload", {}) as Dictionary
	var expected := StringName(payload.get("target_id", &""))
	return expected == &"" or expected == StringName(context.get("target_id", &""))


func consume_runtime_flag(
		flag_id: StringName,
		scope: MasteryReactiveEffectData.Scope,
		context: Dictionary
	) -> Dictionary:
	var key := _flag_key_for_context(flag_id, scope, context)
	if not _flags.has(key):
		return {}
	var entry := _flags[key] as Dictionary
	var payload := (entry.get("payload", {}) as Dictionary).duplicate(true)
	var expected_target := StringName(payload.get("target_id", &""))
	var actual_target := StringName(context.get("target_id", &""))
	if expected_target != &"" and expected_target != actual_target:
		return {}
	_flags.erase(key)
	return payload


func track_distinct_offense(
		effect: MasteryReactiveEffectData,
		context: Dictionary
	) -> int:
	var actor_id := StringName(context.get("actor_id", &"actor"))
	var target_id := StringName(context.get("target_id", &"target"))
	var key := "%s|%s|%s|%s" % [
		effect.source_id,
		_scope_token(MasteryReactiveEffectData.Scope.ACTIVATION, context),
		actor_id,
		target_id,
	]
	var spell_ids: Array[StringName] = []
	spell_ids.assign(_distinct_offenses.get(key, []))
	var spell_id := StringName(context.get("spell_id", &""))
	if spell_id != &"" and not spell_ids.has(spell_id):
		spell_ids.append(spell_id)
	_distinct_offenses[key] = spell_ids
	return spell_ids.size()


func accumulate_absorption(
		effect: MasteryReactiveEffectData,
		context: Dictionary
	) -> Dictionary:
	var key := _state_key(effect.flag_id, effect.scope, context)
	var current := int(_accumulators.get(key, 0))
	current += maxi(0, int(context.get("absorbed_damage", 0)))
	var cap := 0
	if effect.cap_max_hp_ratio > 0.0:
		cap = int(round(float(context.get("max_hp", 0)) * effect.cap_max_hp_ratio))
	if cap > 0:
		current = mini(current, cap)
	_accumulators[key] = current
	var threshold_ratio := effect.minimum_absorbed_max_hp_ratio
	var threshold_override := float(context.get("absorption_threshold_override", -1.0))
	if threshold_override >= 0.0:
		threshold_ratio = minf(threshold_ratio, threshold_override)
	var threshold := int(ceil(float(context.get("max_hp", 0)) * threshold_ratio))
	return {
		"accumulated": current,
		"threshold": threshold,
		"threshold_reached": current >= threshold and threshold > 0,
	}


func queue_followup(
		effect: MasteryReactiveEffectData,
		context: Dictionary
	) -> Dictionary:
	var request := TacticalFollowupRequest.new()
	request.source_id = effect.source_id
	request.request_type = effect.followup_request_type
	request.optional = effect.optional
	request.expiry_scope = MasteryReactiveEffectData.scope_id(effect.scope)
	request.expiry_token = _scope_token(effect.scope, context)
	request.created_event_serial = _event_serial
	request.priority = effect.priority
	request.requires_preview = true
	for value in context.get("valid_cells", []):
		if value is Vector2i and not request.valid_cells.has(value):
			request.valid_cells.append(value)
	for value in context.get("valid_targets", []):
		if value != null and not request.valid_targets.has(value):
			request.valid_targets.append(value)
	request.valid_option_ids = effect.valid_option_ids.duplicate()
	# Le choix d'origine peut etre fourni par l'integration sous forme de deux
	# cellules previsualisees, sans creer de deplacement implicite.
	for value in context.get("origin_cells", []):
		if value is Vector2i and not request.valid_cells.has(value):
			request.valid_cells.append(value)
	return followup_queue.enqueue(request)


func _evaluate_effect(
		effect: MasteryReactiveEffectData,
		context: Dictionary,
		reaction_groups: Dictionary
	) -> Dictionary:
	var base := {
		"event_serial": _event_serial,
		"event_id": context.event_id,
		"source_id": effect.source_id,
		"effect_id": effect.effect_id,
		"reaction_group": effect.reaction_group,
		"priority": effect.priority,
		"stackable": effect.stackable,
		"scope": MasteryReactiveEffectData.scope_id(effect.scope),
		"frequency_before": _frequency_count(effect, context),
		"triggered": false,
		"reason": &"",
		"directives": [],
	}
	var validation_errors := registry.validate_effect(effect)
	if not validation_errors.is_empty():
		base.reason = &"INVALID_EFFECT"
		base.errors = validation_errors
		return base
	if _reaction_group_blocked(effect, reaction_groups):
		base.reason = &"REACTION_GROUP_CONFLICT"
		return base
	if _is_recursive(effect, context):
		base.reason = &"RECURSION_GUARD"
		return base
	if not _conditions_pass(effect, context):
		base.reason = &"CONDITIONS_NOT_MET"
		return base
	if not _frequency_available(effect, context):
		base.reason = &"FREQUENCY_EXHAUSTED"
		return base
	_resolving_source_ids.append(effect.source_id)
	var resolution := registry.resolve(effect, context, self)
	_resolving_source_ids.erase(effect.source_id)
	base.triggered = bool(resolution.get("applied", false))
	base.reason = StringName(resolution.get("reason", &""))
	base.directives = resolution.get("directives", [])
	if bool(base.triggered):
		_consume_frequency(effect, context)
		if effect.frequency != MasteryReactiveEffectData.Frequency.UNLIMITED:
			var reservation := StringName("%s:%d:%d" % [effect.source_id, _run_serial, _event_serial])
			_frequency_reservations[reservation] = _frequency_key(effect, context)
			base["frequency_reservation"] = reservation
	base.frequency_after = _frequency_count(effect, context)
	return base


func _conditions_pass(
		effect: MasteryReactiveEffectData,
		context: Dictionary
	) -> bool:
	var spell_id := StringName(context.get("spell_id", &""))
	if not effect.valid_spell_ids.is_empty() and not effect.valid_spell_ids.has(spell_id):
		return false
	if effect.required_flag_id != &"" \
			and not has_runtime_flag(effect.required_flag_id, effect.scope, context):
		return false
	if effect.requires_guard and not bool(context.get("guard_active", false)):
		return false
	if effect.requires_enemy_source and not bool(context.get("enemy_source", false)):
		return false
	if effect.requires_elimination and not bool(context.get("elimination", false)):
		return false
	if effect.requires_collision_or_forced_move and not (
		bool(context.get("collision", false)) or bool(context.get("forced_move", false))
	):
		return false
	if effect.requires_contact_after_move \
			and not bool(context.get("ended_in_contact", false)):
		return false
	if effect.required_attack_classification \
			!= MasteryReactiveEffectData.AttackClassification.ANY:
		var required_classification := MasteryReactiveEffectData.attack_classification_id(
			effect.required_attack_classification
		)
		if StringName(context.get("attack_classification", &"")) \
				!= required_classification:
			return false
	if not _facing_condition_passes(effect, context):
		return false
	var distance := int(context.get("distance", 0))
	if distance < effect.minimum_distance:
		return false
	if effect.maximum_distance >= 0 and distance > effect.maximum_distance:
		return false
	if int(context.get("moved_cells", 0)) < effect.minimum_moved_cells:
		return false
	if effect.caster_hp_ratio_at_most >= 0.0 \
			and float(context.get("caster_hp_ratio", 1.0)) \
				> effect.caster_hp_ratio_at_most:
		return false
	if effect.target_hp_ratio_at_most >= 0.0 \
			and float(context.get("target_hp_ratio", 1.0)) \
				> effect.target_hp_ratio_at_most:
		return false
	if effect.target_armor_at_most >= 0 \
			and int(context.get("target_armor", 2147483647)) \
				> effect.target_armor_at_most:
		return false
	if effect.minimum_absorbed_max_hp_ratio > 0.0 \
			and effect.effect_id != MasteryReactiveEffectData.EFFECT_TRACK_ABSORPTION:
		var absorbed_ratio := _safe_ratio(
			int(context.get("absorbed_damage", 0)), int(context.get("max_hp", 0))
		)
		if absorbed_ratio < effect.minimum_absorbed_max_hp_ratio:
			return false
	if effect.minimum_hp_lost_max_hp_ratio > 0.0:
		var hp_loss_ratio := _safe_ratio(
			int(context.get("hp_lost_since_previous_activation", context.get("hp_lost", 0))),
			int(context.get("max_hp", 0)),
		)
		if hp_loss_ratio < effect.minimum_hp_lost_max_hp_ratio:
			return false
	return true


func _facing_condition_passes(
		effect: MasteryReactiveEffectData,
		context: Dictionary
	) -> bool:
	if effect.required_facing_sector == MasteryReactiveEffectData.FacingSector.ANY:
		return true
	var actual := StringName(context.get("facing_sector", &""))
	if context.has("defender_cell") and context.has("defender_facing") \
			and context.has("attacker_cell"):
		actual = DirectionalSectorResolver.classify(
			context.defender_cell,
			context.defender_facing,
			context.attacker_cell,
		)
	if effect.required_facing_sector == MasteryReactiveEffectData.FacingSector.SIDE_OR_REAR:
		return actual in [DirectionalSectorResolver.SECTOR_SIDE, DirectionalSectorResolver.SECTOR_REAR]
	return actual == MasteryReactiveEffectData.facing_sector_id(
		effect.required_facing_sector
	)


func _reaction_group_blocked(
		effect: MasteryReactiveEffectData,
		groups: Dictionary
	) -> bool:
	if effect.reaction_group == &"" or not groups.has(effect.reaction_group):
		return false
	var state := groups[effect.reaction_group] as Dictionary
	return bool(state.get("has_non_stackable", false)) or not effect.stackable


func _is_recursive(
		effect: MasteryReactiveEffectData,
		context: Dictionary
	) -> bool:
	if not effect.anti_recursion:
		return false
	if _resolving_source_ids.has(effect.source_id):
		return true
	for value in context.get("origin_source_chain", []):
		if StringName(value) == effect.source_id:
			return true
	return StringName(context.get("automatic_source_id", &"")) == effect.source_id


func _frequency_available(
		effect: MasteryReactiveEffectData,
		context: Dictionary
	) -> bool:
	if effect.frequency == MasteryReactiveEffectData.Frequency.UNLIMITED:
		return true
	return _frequency_count(effect, context) < effect.max_triggers


func _frequency_count(
		effect: MasteryReactiveEffectData,
		context: Dictionary
	) -> int:
	return int(_frequency_counters.get(_frequency_key(effect, context), 0))


func _consume_frequency(
		effect: MasteryReactiveEffectData,
		context: Dictionary
	) -> void:
	if effect.frequency == MasteryReactiveEffectData.Frequency.UNLIMITED:
		return
	var key := _frequency_key(effect, context)
	_frequency_counters[key] = int(_frequency_counters.get(key, 0)) + 1


func _frequency_key(
		effect: MasteryReactiveEffectData,
		context: Dictionary
	) -> String:
	var token := "unlimited"
	match effect.frequency:
		MasteryReactiveEffectData.Frequency.ONCE_PER_ACTION:
			token = str(context.get("action_id", context.get("event_serial", 0)))
		MasteryReactiveEffectData.Frequency.ONCE_PER_ACTIVATION, MasteryReactiveEffectData.Frequency.ONCE_UNTIL_NEXT_ACTIVATION:
			token = str(context.get("activation_id", _activation_serial))
		MasteryReactiveEffectData.Frequency.ONCE_PER_COMBAT:
			token = str(context.get("combat_id", _combat_serial))
		MasteryReactiveEffectData.Frequency.ONCE_PER_RUN:
			token = str(context.get("run_id", _run_serial))
	return "%s|%s|%s" % [effect.source_id, effect.frequency, token]


func _state_key(
		state_id: StringName,
		scope: MasteryReactiveEffectData.Scope,
		context: Dictionary
	) -> String:
	return "%s|%s|%s|%s" % [
		state_id,
		scope,
		_scope_token(scope, context),
		StringName(context.get("actor_id", &"actor")),
	]


func _scope_token(
		scope: MasteryReactiveEffectData.Scope,
		context: Dictionary
	) -> StringName:
	match scope:
		MasteryReactiveEffectData.Scope.ACTION:
			return StringName(context.get("action_id", "event_%d" % _event_serial))
		MasteryReactiveEffectData.Scope.UNTIL_NEXT_ACTIVATION:
			return StringName(context.get("combat_id", "combat_%d" % _combat_serial))
		MasteryReactiveEffectData.Scope.ACTIVATION:
			return StringName(context.get("activation_id", "activation_%d" % _activation_serial))
		MasteryReactiveEffectData.Scope.COMBAT:
			return StringName(context.get("combat_id", "combat_%d" % _combat_serial))
		MasteryReactiveEffectData.Scope.RUN:
			return StringName(context.get("run_id", "run_%d" % _run_serial))
	return &""


func _safe_ratio(value: int, maximum: int) -> float:
	return 0.0 if maximum <= 0 else float(maxi(0, value)) / float(maximum)


func _sort_effects(a: MasteryReactiveEffectData, b: MasteryReactiveEffectData) -> bool:
	if a.priority == b.priority:
		return str(a.source_id) < str(b.source_id)
	return a.priority > b.priority


func _expire_deferred_flags() -> void:
	for key in _flags.keys():
		var entry := _flags[key] as Dictionary
		if int(entry.get("scope", -1)) == MasteryReactiveEffectData.Scope.UNTIL_NEXT_ACTIVATION and int(entry.get("expires_after_activation", -1)) < _activation_serial:
			_flags.erase(key)


## An unchosen shared reaction never spends its activation/combat charge.
func refund_frequency(reservation: StringName) -> bool:
	if not _frequency_reservations.has(reservation):
		return false
	var key := str(_frequency_reservations[reservation])
	_frequency_reservations.erase(reservation)
	_frequency_counters[key] = maxi(0, int(_frequency_counters.get(key, 0)) - 1)
	return true


func _flag_key_for_context(flag_id: StringName, scope: MasteryReactiveEffectData.Scope, context: Dictionary) -> String:
	var key := _state_key(flag_id, scope, context)
	var target := StringName(context.get("target_id", &""))
	var targeted_key := "%s|target:%s" % [key, target]
	return targeted_key if target != &"" and _flags.has(targeted_key) else key
