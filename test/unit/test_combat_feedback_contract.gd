extends GutTest

const Factory = preload("res://test/support/factory.gd")
const FeedbackSettings = preload(
	"res://battle/combat_feedback/combat_feedback_settings.tres"
)


func test_damage_facts_are_post_mutation_and_never_show_theoretical_damage() -> void:
	var target := Factory.make_unit("Cible", 1)
	var attacker := Factory.make_unit("Attaquant", 0)
	target.add_shield(20)
	var shield_facts: Array[CombatEventFact] = []
	var hp_facts: Array[CombatEventFact] = []
	var hp_seen_in_callback: Array[int] = []
	var hit_facts: Array[CombatEventFact] = []
	var on_shield := func(fact: CombatEventFact): shield_facts.append(fact)
	var on_hp := func(fact: CombatEventFact):
		hp_facts.append(fact)
		hp_seen_in_callback.append(target.current_hp)
	var on_hit := func(fact: CombatEventFact): hit_facts.append(fact)
	EventBus.shield_absorption_resolved.connect(on_shield)
	EventBus.hp_damage_taken.connect(on_hp)
	EventBus.hit_resolved.connect(on_hit)
	target.take_damage(50, attacker, Spell.DamageType.PHYSICAL, Spell.Element.NONE, {
		"ignore_defense": true,
		"cannot_be_dodged": true,
		"impact_id": &"damage_contract:0",
	})
	EventBus.shield_absorption_resolved.disconnect(on_shield)
	EventBus.hp_damage_taken.disconnect(on_hp)
	EventBus.hit_resolved.disconnect(on_hit)
	assert_eq(target.current_shield, 0)
	assert_eq(target.current_hp, 70)
	assert_eq(shield_facts.size(), 1)
	assert_eq(shield_facts[0].amount_absorbed, 20)
	assert_eq(hp_facts.size(), 1)
	assert_eq(hp_facts[0].amount_applied, 30)
	assert_eq(hp_seen_in_callback, [70])
	assert_eq(hit_facts.size(), 1)
	assert_eq(hit_facts[0].amount_resolved, 50)
	assert_eq(hit_facts[0].amount_applied, 30)
	assert_eq(hit_facts[0].amount_absorbed, 20)
	var payload := FloatingCombatText.describe_fact(
		hp_facts[0], FeedbackSettings.style_for_fact(hp_facts[0])
	)
	assert_eq(payload["amount_text"], "−30")
	assert_false(str(payload["amount_text"]).contains("50"))


func test_heal_fact_separates_effective_healing_from_overheal() -> void:
	var target := Factory.make_unit("Cible", 1)
	target.current_hp = 88
	var facts: Array[CombatEventFact] = []
	var on_heal := func(fact: CombatEventFact): facts.append(fact)
	EventBus.heal_received.connect(on_heal)
	var returned := target.heal(30, null, {"impact_id": &"heal_contract:0"})
	EventBus.heal_received.disconnect(on_heal)
	assert_eq(target.current_hp, 100)
	assert_eq(facts.size(), 1)
	assert_same(returned, facts[0])
	assert_eq(returned.amount_applied, 12)
	assert_eq(returned.overheal, 18)
	var payload := FloatingCombatText.describe_fact(
		returned, FeedbackSettings.style_for_fact(returned)
	)
	assert_eq(payload["amount_text"], "+12")


func test_dodge_and_immunity_use_semantic_labels_without_zero_artifacts() -> void:
	var target := Factory.make_unit("Cible", 1)
	var dodge_result := DamageResolver.DamageResult.new(40)
	dodge_result.amount = 0
	dodge_result.dodged = true
	var ctx := DamageResolver.HitContext.new()
	ctx.impact_id = &"dodge_contract:0"
	var dodge_facts: Array[CombatEventFact] = []
	var on_dodge := func(fact: CombatEventFact): dodge_facts.append(fact)
	EventBus.attack_dodge_resolved.connect(on_dodge)
	target._apply_damage_result(dodge_result, null, ctx)
	EventBus.attack_dodge_resolved.disconnect(on_dodge)
	assert_eq(dodge_facts.size(), 1)
	var dodge_payload := FloatingCombatText.describe_fact(
		dodge_facts[0], FeedbackSettings.style_for_fact(dodge_facts[0])
	)
	assert_true(str(dodge_payload["amount_text"]).contains("ESQUIVE"))
	assert_false(str(dodge_payload["amount_text"]).contains("0"))
	var immune := CombatEventFact.create(&"attack_immune", target)
	var immune_payload := FloatingCombatText.describe_fact(
		immune, FeedbackSettings.style_for_fact(immune)
	)
	assert_true(str(immune_payload["amount_text"]).contains("IMMUN"))
	assert_false(str(immune_payload["amount_text"]).contains("0"))


func test_critical_periodic_and_order_metadata_survive_resolution() -> void:
	var target := Factory.make_unit("Cible", 1)
	var attacker := Factory.make_unit("Attaquant", 0)
	var facts: Array[CombatEventFact] = []
	var on_hp := func(fact: CombatEventFact): facts.append(fact)
	EventBus.hp_damage_taken.connect(on_hp)
	target.take_damage(10, attacker, Spell.DamageType.PHYSICAL, Spell.Element.NONE, {
		"ignore_defense": true,
		"cannot_be_dodged": true,
		"force_crit": true,
		"action_id": &"action_1",
		"cast_id": &"cast_1",
		"impact_id": &"cast_1:0",
		"sequence_index": 0,
	})
	target.take_damage(6, attacker, Spell.DamageType.MAGICAL, Spell.Element.FIRE, {
		"ignore_defense": true,
		"cannot_be_dodged": true,
		"is_periodic": true,
		"status_id": &"poison",
		"action_id": &"poison_tick",
		"sequence_index": 1,
	})
	target.take_damage(6, attacker, Spell.DamageType.MAGICAL, Spell.Element.FIRE, {
		"ignore_defense": true,
		"cannot_be_dodged": true,
		"is_periodic": true,
		"status_id": &"poison",
		"action_id": &"poison_tick",
		"sequence_index": 2,
	})
	EventBus.hp_damage_taken.disconnect(on_hp)
	assert_eq(facts.size(), 3)
	assert_true(facts[0].is_critical)
	assert_eq(String(facts[0].cast_id), "cast_1")
	assert_eq(facts[0].sequence_index, 0)
	assert_true(facts[1].is_periodic)
	assert_eq(facts[1].status_id, &"poison")
	assert_eq(facts[1].sequence_index, 1)
	assert_eq(facts[2].sequence_index, 2)
	assert_lt(facts[0].logical_order, facts[1].logical_order)
	assert_lt(facts[1].logical_order, facts[2].logical_order)


func test_explicit_impact_ids_make_damage_heal_and_shield_idempotent() -> void:
	var target := Factory.make_unit("Cible", 1)
	var damage_options := {
		"ignore_defense": true,
		"cannot_be_dodged": true,
		"impact_id": &"same_damage",
	}
	var first_damage := target.take_damage(10, null, 0, 0, damage_options)
	var second_damage := target.take_damage(10, null, 0, 0, damage_options)
	assert_same(first_damage, second_damage)
	assert_eq(target.current_hp, 90)
	var heal_options := {"impact_id": &"same_heal"}
	var first_heal := target.heal(5, null, heal_options)
	var second_heal := target.heal(5, null, heal_options)
	assert_same(first_heal, second_heal)
	assert_eq(target.current_hp, 95)
	var shield_options := {"impact_id": &"same_shield"}
	var first_shield := target.add_shield(12, null, shield_options)
	var second_shield := target.add_shield(12, null, shield_options)
	assert_same(first_shield, second_shield)
	assert_eq(target.current_shield, 12)


func test_feedback_controller_deduplicates_bounds_bursts_and_cleans_up() -> void:
	var controller := CombatFeedbackController.new()
	controller.settings = FeedbackSettings.duplicate(true)
	add_child_autofree(controller)
	var target := Control.new()
	target.size = Vector2(100.0, 100.0)
	add_child_autofree(target)
	await get_tree().process_frame
	var duplicate := CombatEventFact.create(
		&"hp_damage_taken", target, null, {"amount_applied": 8}
	)
	assert_true(controller.submit_fact(duplicate))
	assert_false(controller.submit_fact(duplicate))
	for index in range(100):
		controller.submit_fact(CombatEventFact.create(
			&"hp_damage_taken", target, null, {
				"amount_applied": index + 1,
				"sequence_index": 0,
			}
		))
	await get_tree().process_frame
	var snapshot := controller.get_debug_snapshot()
	assert_lte(int(snapshot["active_count"]), int(snapshot["max_active"]))
	assert_eq(
		int(snapshot["active_count"]) + int(snapshot["pending_count"]),
		101
	)
	target.queue_free()
	await get_tree().process_frame
	controller.clear_feedback()
	snapshot = controller.get_debug_snapshot()
	assert_eq(snapshot["active_count"], 0)
	assert_eq(snapshot["pending_count"], 0)
	assert_gte(snapshot["pool_size"], snapshot["prewarm_count"])
