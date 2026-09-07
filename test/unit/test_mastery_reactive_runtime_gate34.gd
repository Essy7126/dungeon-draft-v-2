extends GutTest

const MASTERY_CATALOG: MasteryCatalogData = preload(
	"res://data/characters/achilles/doctrines/achilles_mastery_catalog.tres"
)


func test_all_authored_reactive_effects_are_registered_and_sources_are_stable() -> void:
	var registry := MasteryReactiveEffectRegistry.new()
	var source_ids: Dictionary = {}
	var nodes: Array[SkillTreeNodeData] = []
	for node_value: Variant in MASTERY_CATALOG.node_catalog().values():
		var node: SkillTreeNodeData = node_value as SkillTreeNodeData
		if node != null:
			nodes.append(node)
			for effect: MasteryReactiveEffectData in node.reactive_effects:
				assert_true(registry.has_effect(effect.effect_id), str(effect.effect_id))
				assert_false(source_ids.has(effect.source_id), str(effect.source_id))
				source_ids[effect.source_id] = true
				assert_true(effect.is_structurally_valid(), "\n".join(effect.structural_errors()))
				if effect.automatic_action:
					assert_false(effect.spends_action_points)
					assert_false(effect.awards_xp)
					assert_false(effect.consumes_manual_spell_use)
					assert_true(effect.anti_recursion)
	var runtime := MasteryReactiveRuntimeService.new()
	var errors: PackedStringArray = runtime.configure_from_nodes(nodes)
	assert_true(errors.is_empty(), "\n".join(errors))
	assert_eq(runtime.active_effects().size(), source_ids.size())


func test_priority_and_nonstackable_reaction_group_are_deterministic() -> void:
	var high := _damage_effect(&"test.high", 200, false)
	var low := _damage_effect(&"test.low", 100, false)
	var runtime := MasteryReactiveRuntimeService.new()
	var effects: Array[MasteryReactiveEffectData] = [low, high]
	assert_true(runtime.configure(effects).is_empty())
	var reports: Array[Dictionary] = runtime.process_event(
		MasteryReactiveEffectData.EVENT_SPELL_CAST,
		{"spell_id": &"test_spell"},
	)
	assert_eq(reports.size(), 2)
	assert_eq(reports[0].source_id, &"test.high")
	assert_true(reports[0].triggered)
	assert_eq(reports[1].source_id, &"test.low")
	assert_false(reports[1].triggered)
	assert_eq(reports[1].reason, &"REACTION_GROUP_CONFLICT")
	assert_eq(runtime.telemetry_reports().size(), 2)


func test_automatic_action_has_no_cost_and_cannot_recurse_on_its_source() -> void:
	var effect := MasteryReactiveEffectData.new()
	effect.source_id = &"test.auto_counter"
	effect.effect_id = MasteryReactiveEffectData.EFFECT_AUTOMATIC_ATTACK
	effect.event_id = MasteryReactiveEffectData.EVENT_PROJECTILE_RECEIVED
	effect.target_spell_id = &"achilles_pelion_shot"
	effect.automatic_action = true
	effect.anti_recursion = true
	effect.reaction_group = &"test_auto"
	effect.stackable = false
	var runtime := MasteryReactiveRuntimeService.new()
	var effects: Array[MasteryReactiveEffectData] = [effect]
	assert_true(runtime.configure(effects).is_empty())
	var first: Array[Dictionary] = runtime.process_event(
		MasteryReactiveEffectData.EVENT_PROJECTILE_RECEIVED,
		{"valid_targets": [&"enemy_a"]},
	)
	assert_true(first[0].triggered)
	var directive: Dictionary = first[0].directives[0]
	assert_eq(directive.kind, &"automatic_attack")
	assert_false(directive.spends_action_points)
	assert_false(directive.awards_xp)
	assert_false(directive.consumes_manual_spell_use)
	assert_eq(directive.origin_source_chain_append, effect.source_id)
	var recursive: Array[Dictionary] = runtime.process_event(
		MasteryReactiveEffectData.EVENT_PROJECTILE_RECEIVED,
		{"origin_source_chain": [effect.source_id]},
	)
	assert_false(recursive[0].triggered)
	assert_eq(recursive[0].reason, &"RECURSION_GUARD")
	var no_target: Array[Dictionary] = runtime.process_event(
		MasteryReactiveEffectData.EVENT_PROJECTILE_RECEIVED,
	)
	assert_false(no_target[0].triggered)
	assert_eq(no_target[0].reason, &"NO_VALID_TARGET")
	var blocked_los: Array[Dictionary] = runtime.process_event(
		MasteryReactiveEffectData.EVENT_PROJECTILE_RECEIVED,
		{"valid_targets": [&"enemy_a"], "line_of_sight_valid": false},
	)
	assert_false(blocked_los[0].triggered)
	assert_eq(blocked_los[0].reason, &"LINE_OF_SIGHT_BLOCKED")


func test_once_per_activation_frequency_resets_only_on_the_next_activation() -> void:
	var effect := _damage_effect(&"test.once_per_activation", 100, true)
	effect.frequency = MasteryReactiveEffectData.Frequency.ONCE_PER_ACTIVATION
	effect.max_triggers = 1
	var runtime := MasteryReactiveRuntimeService.new()
	var effects: Array[MasteryReactiveEffectData] = [effect]
	assert_true(runtime.configure(effects).is_empty())
	runtime.process_event(MasteryReactiveEffectData.EVENT_ACTIVATION_STARTED)
	var first: Array[Dictionary] = runtime.process_event(
		MasteryReactiveEffectData.EVENT_SPELL_CAST,
	)
	var exhausted: Array[Dictionary] = runtime.process_event(
		MasteryReactiveEffectData.EVENT_SPELL_CAST,
	)
	assert_true(first[0].triggered)
	assert_false(exhausted[0].triggered)
	assert_eq(exhausted[0].reason, &"FREQUENCY_EXHAUSTED")
	runtime.process_event(MasteryReactiveEffectData.EVENT_ACTIVATION_STARTED)
	var reset: Array[Dictionary] = runtime.process_event(
		MasteryReactiveEffectData.EVENT_SPELL_CAST,
	)
	assert_true(reset[0].triggered)


func test_followup_queue_validates_choice_without_silent_movement() -> void:
	var effect := MasteryReactiveEffectData.new()
	effect.source_id = &"test.optional_step"
	effect.effect_id = MasteryReactiveEffectData.EFFECT_QUEUE_FOLLOWUP
	effect.event_id = MasteryReactiveEffectData.EVENT_ELIMINATION
	effect.scope = MasteryReactiveEffectData.Scope.ACTIVATION
	effect.followup_request_type = TacticalFollowupRequest.TYPE_FREE_MOVE
	effect.optional = true
	var runtime := MasteryReactiveRuntimeService.new()
	var effects: Array[MasteryReactiveEffectData] = [effect]
	assert_true(runtime.configure(effects).is_empty())
	var choices: Array[Vector2i] = [Vector2i(2, 3), Vector2i(3, 3)]
	var reports: Array[Dictionary] = runtime.process_event(
		MasteryReactiveEffectData.EVENT_ELIMINATION,
		{"valid_cells": choices},
	)
	assert_true(reports[0].triggered)
	var request: TacticalFollowupRequest = runtime.followup_queue.peek()
	assert_not_null(request)
	assert_eq(request.valid_cells, choices)
	var invalid: Dictionary = runtime.followup_queue.resolve_choice(
		request.request_id, Vector2i(99, 99),
	)
	assert_false(invalid.resolved)
	assert_same(runtime.followup_queue.peek(), request)
	var resolved: Dictionary = runtime.followup_queue.resolve_choice(
		request.request_id, choices[0],
	)
	assert_true(resolved.resolved)
	assert_true(resolved.execute_at_safe_point)
	assert_false(resolved.spends_action_points)
	assert_false(resolved.awards_xp)
	assert_false(resolved.consumes_manual_spell_use)
	assert_null(runtime.followup_queue.peek())

	# Un choix non résolu ne survit jamais à la prochaine activation.
	runtime.process_event(
		MasteryReactiveEffectData.EVENT_ELIMINATION,
		{"valid_cells": choices, "activation_id": &"old_activation"},
	)
	assert_not_null(runtime.followup_queue.peek())
	runtime.process_event(MasteryReactiveEffectData.EVENT_ACTIVATION_STARTED)
	assert_null(runtime.followup_queue.peek())


func test_directional_sectors_and_guard_multipliers_are_cardinal_and_stable() -> void:
	var guard := DirectionalGuardData.new()
	guard.front_damage_multiplier = 0.5
	guard.side_damage_multiplier = 0.75
	guard.rear_damage_multiplier = 1.0
	var defender := Vector2i(4, 4)
	var facing := Vector2i(1, 0)
	assert_eq(
		DirectionalSectorResolver.classify(defender, facing, Vector2i(5, 4)),
		DirectionalSectorResolver.SECTOR_FRONT,
	)
	assert_eq(
		DirectionalSectorResolver.classify(defender, facing, Vector2i(4, 3)),
		DirectionalSectorResolver.SECTOR_SIDE,
	)
	assert_eq(
		DirectionalSectorResolver.classify(defender, facing, Vector2i(3, 4)),
		DirectionalSectorResolver.SECTOR_REAR,
	)
	assert_almost_eq(
		DirectionalSectorResolver.damage_multiplier(
			guard, defender, facing, Vector2i(5, 4),
		),
		0.5,
		0.0001,
	)


func test_temporary_barrier_declares_next_activation_expiry_for_executor() -> void:
	var node: SkillTreeNodeData = MASTERY_CATALOG.node_catalog()[
		&"achilles_aeacus_myrmidon_rampart"
	]
	var runtime := MasteryReactiveRuntimeService.new()
	var nodes: Array[SkillTreeNodeData] = [node]
	assert_true(runtime.configure_from_nodes(nodes).is_empty())
	var reports: Array[Dictionary] = runtime.process_event(
		MasteryReactiveEffectData.EVENT_SPELL_CAST,
		{
			"spell_id": &"achilles_bronze_guard",
			"caster_cell": Vector2i(4, 4),
			"caster_facing": Vector2i(1, 0),
		},
	)
	assert_true(reports[0].triggered)
	var directive: Dictionary = reports[0].directives[0]
	assert_eq(directive.kind, &"temporary_barrier")
	assert_eq(directive.line_length, 3)
	assert_true(directive.blocks_projectiles)
	assert_eq(directive.enemy_movement_surcharge, 1)
	assert_eq(
		directive.expiry_scope,
		TemporaryBarrierData.EXPIRY_UNTIL_NEXT_ACTIVATION,
	)
	assert_almost_eq(directive.personal_shield_multiplier, 0.75, 0.0001)


func _damage_effect(
		source_id: StringName,
		priority: int,
		stackable: bool
	) -> MasteryReactiveEffectData:
	var effect := MasteryReactiveEffectData.new()
	effect.source_id = source_id
	effect.effect_id = MasteryReactiveEffectData.EFFECT_DAMAGE_MULTIPLIER
	effect.event_id = MasteryReactiveEffectData.EVENT_SPELL_CAST
	effect.reaction_group = &"test_damage"
	effect.priority = priority
	effect.stackable = stackable
	effect.multiplier = 1.2
	return effect


func test_guard_absorption_bonus_survives_owner_next_activation_on_another_target() -> void:
	var runtime := MasteryReactiveRuntimeService.new()
	var node := MASTERY_CATALOG.node_catalog().get(&"achilles_aeacus_active_guard") as SkillTreeNodeData
	runtime.configure_from_nodes([node])
	runtime.process_event(&"combat_started", {"combat_id": &"combat"})
	runtime.process_event(&"activation_started", {"combat_id": &"combat", "activation_id": &"first"})
	runtime.process_event(&"damage_absorbed", {"combat_id": &"combat", "activation_id": &"first", "actor_id": &"hero", "target_id": &"hero", "guard_active": true, "absorbed_damage": 15, "max_hp": 110})
	runtime.process_event(&"activation_started", {"combat_id": &"combat", "activation_id": &"second"})
	var reports := runtime.process_event(&"spell_cast", {"combat_id": &"combat", "activation_id": &"second", "actor_id": &"hero", "target_id": &"enemy", "spell_id": &"achilles_peleid_strike"})
	assert_true(reports[0].triggered, str(reports))
	assert_almost_eq(float(reports[0].directives[0].multiplier), 1.15, 0.00001)


func test_deferred_flag_expires_after_the_following_owner_activation() -> void:
	var runtime := MasteryReactiveRuntimeService.new()
	var context := {"combat_id": &"combat", "actor_id": &"hero"}
	runtime.process_event(&"activation_started", context)
	runtime.set_runtime_flag(&"deferred", MasteryReactiveEffectData.Scope.UNTIL_NEXT_ACTIVATION, context, {"ready": true})
	runtime.process_event(&"activation_started", context)
	assert_true(runtime.has_runtime_flag(&"deferred", MasteryReactiveEffectData.Scope.UNTIL_NEXT_ACTIVATION, context))
	runtime.process_event(&"activation_started", context)
	assert_false(runtime.has_runtime_flag(&"deferred", MasteryReactiveEffectData.Scope.UNTIL_NEXT_ACTIVATION, context))


func test_target_bound_flags_reject_another_target_without_consuming() -> void:
	var runtime := MasteryReactiveRuntimeService.new()
	var context := {"activation_id": &"activation", "actor_id": &"hero", "target_id": &"marked"}
	runtime.set_runtime_flag(&"mark", MasteryReactiveEffectData.Scope.ACTIVATION, context, {"target_id": &"marked"})
	var other := context.duplicate()
	other.target_id = &"other"
	assert_false(runtime.has_runtime_flag(&"mark", MasteryReactiveEffectData.Scope.ACTIVATION, other))
	assert_true(runtime.consume_runtime_flag(&"mark", MasteryReactiveEffectData.Scope.ACTIVATION, other).is_empty())
	assert_false(runtime.consume_runtime_flag(&"mark", MasteryReactiveEffectData.Scope.ACTIVATION, context).is_empty())


func test_target_bound_marks_coexist_and_consume_only_the_selected_victim() -> void:
	var runtime := MasteryReactiveRuntimeService.new()
	var first := {"activation_id": &"activation", "actor_id": &"hero", "target_id": &"enemy_a"}
	var second := first.duplicate()
	second.target_id = &"enemy_b"
	runtime.set_runtime_flag(&"mark", MasteryReactiveEffectData.Scope.ACTIVATION, first, {"target_id": &"enemy_a"})
	runtime.set_runtime_flag(&"mark", MasteryReactiveEffectData.Scope.ACTIVATION, second, {"target_id": &"enemy_b"})
	assert_true(runtime.has_runtime_flag(&"mark", MasteryReactiveEffectData.Scope.ACTIVATION, first))
	assert_true(runtime.has_runtime_flag(&"mark", MasteryReactiveEffectData.Scope.ACTIVATION, second))
	assert_false(runtime.consume_runtime_flag(&"mark", MasteryReactiveEffectData.Scope.ACTIVATION, first).is_empty())
	assert_false(runtime.has_runtime_flag(&"mark", MasteryReactiveEffectData.Scope.ACTIVATION, first))
	assert_true(runtime.has_runtime_flag(&"mark", MasteryReactiveEffectData.Scope.ACTIVATION, second))


func test_refused_frequency_reservation_is_refunded_exactly_once() -> void:
	var effect := _damage_effect(&"reserved", 100, true)
	effect.frequency = MasteryReactiveEffectData.Frequency.ONCE_PER_COMBAT
	var runtime := MasteryReactiveRuntimeService.new()
	assert_true(runtime.configure([effect]).is_empty())
	var first := runtime.process_event(&"spell_cast", {"combat_id": &"combat"})
	assert_true(first[0].triggered)
	assert_true(runtime.refund_frequency(first[0].frequency_reservation))
	assert_false(runtime.refund_frequency(first[0].frequency_reservation))
	var second := runtime.process_event(&"spell_cast", {"combat_id": &"combat"})
	assert_true(second[0].triggered)
	assert_false(runtime.process_event(&"spell_cast", {"combat_id": &"combat"})[0].triggered)
