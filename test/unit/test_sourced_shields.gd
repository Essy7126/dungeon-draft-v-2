extends GutTest

const Factory = preload("res://test/support/factory.gd")


func test_sources_coexist_and_only_a_stronger_value_replaces_same_source() -> void:
	var unit := Factory.make_unit()
	assert_not_null(unit.add_sourced_shield(&"guard", 12))
	assert_not_null(unit.add_sourced_shield(&"ward", 8))
	assert_eq(unit.current_shield, 20)
	assert_eq(unit.get_shield_value(&"guard"), 12)
	assert_null(unit.add_sourced_shield(&"guard", 10))
	assert_eq(unit.get_shield_value(&"guard"), 12)
	assert_not_null(unit.add_sourced_shield(&"guard", 15))
	assert_eq(unit.get_shield_value(&"guard"), 15)
	assert_eq(unit.get_shield_value(&"ward"), 8)
	assert_eq(unit.current_shield, 23)


func test_source_break_is_observable_while_aggregate_shield_survives() -> void:
	var unit := Factory.make_unit()
	unit.add_sourced_shield(&"guard", 5, null, {"priority": 10})
	unit.add_sourced_shield(&"ward", 7, null, {"priority": 0})
	var broken_sources: Array[StringName] = []
	var aggregate_breaks := [0]
	var on_source_broken := func(_unit, source_id: StringName):
		broken_sources.append(source_id)
	var on_aggregate_broken := func(_unit): aggregate_breaks[0] += 1
	unit.shield_source_broken.connect(on_source_broken)
	EventBus.shield_broken.connect(on_aggregate_broken)
	unit.take_damage(5, null, Spell.DamageType.PHYSICAL, Spell.Element.NONE, {
		"ignore_defense": true,
		"cannot_be_dodged": true,
	})
	EventBus.shield_broken.disconnect(on_aggregate_broken)
	assert_eq(broken_sources, [&"guard"])
	assert_eq(aggregate_breaks[0], 0)
	assert_eq(unit.get_shield_value(&"guard"), 0)
	assert_eq(unit.get_shield_value(&"ward"), 7)
	assert_eq(unit.current_shield, 7)


func test_absorption_order_is_priority_then_age_then_source_id() -> void:
	var unit := Factory.make_unit()
	unit.add_sourced_shield(&"later", 3, null, {
		"priority": 1,
		"created_activation": 2,
	})
	unit.add_sourced_shield(&"beta", 4, null, {
		"priority": 1,
		"created_activation": 1,
	})
	unit.add_sourced_shield(&"alpha", 5, null, {
		"priority": 1,
		"created_activation": 1,
	})
	unit.take_damage(6, null, Spell.DamageType.PHYSICAL, Spell.Element.NONE, {
		"ignore_defense": true,
		"cannot_be_dodged": true,
	})
	assert_eq(unit.get_shield_value(&"alpha"), 0)
	assert_eq(unit.get_shield_value(&"beta"), 3)
	assert_eq(unit.get_shield_value(&"later"), 3)


func test_expiration_is_scoped_to_start_of_owners_next_activation() -> void:
	var unit := Factory.make_unit()
	unit.add_shield(9, null, {
		"shield_source_id": &"bronze_guard",
		"expires_after_activations": 1,
	})
	unit.add_sourced_shield(&"persistent", 4)
	assert_eq(unit.current_shield, 13)
	unit.start_turn()
	assert_eq(unit.get_shield_value(&"bronze_guard"), 0)
	assert_eq(unit.get_shield_value(&"persistent"), 4)
	assert_eq(unit.current_shield, 4)


func test_snapshot_restore_is_explicit_atomic_and_preserves_sources() -> void:
	var source := Factory.make_unit()
	source.add_sourced_shield(&"guard", 8, null, {
		"priority": 4,
		"expires_after_activations": 1,
		"tags": [&"spell", &"defense"],
	})
	source.add_sourced_shield(&"ward", 6)
	var snapshot := source.get_shield_instances_snapshot()
	var restored := Factory.make_unit()
	assert_true(restored.restore_shield_instances_snapshot(snapshot))
	assert_eq(restored.get_shield_instances_snapshot(), snapshot)
	var before := restored.get_shield_instances_snapshot()
	var invalid := snapshot.duplicate(true)
	invalid.append(snapshot[0].duplicate(true))
	assert_false(restored.restore_shield_instances_snapshot(invalid))
	assert_eq(restored.get_shield_instances_snapshot(), before)


func test_legacy_aggregate_api_remains_a_compatible_view() -> void:
	var unit := Factory.make_unit()
	unit.current_shield = 11
	assert_eq(unit.current_shield, 11)
	assert_eq(unit.get_shield_value(Unit.LEGACY_SHIELD_SOURCE_ID), 11)
	unit.add_shield(15)
	assert_eq(unit.current_shield, 15)
	assert_eq(unit.get_shield_value(Unit.LEGACY_SHIELD_SOURCE_ID), 15)
	unit.clear_shield()
	assert_eq(unit.current_shield, 0)


func test_guard_creation_scaling_and_effectiveness_keep_absorption_source_facts() -> void:
	var defender := Factory.make_unit()
	var attacker := Unit.new("Adversaire", 1, 100)
	defender.shield_creation_multiplier = 1.5
	defender.add_shield(10, defender, {
		"shield_source_id": &"guard",
		"tags": [&"guard"],
	})
	assert_eq(defender.get_shield_value(&"guard"), 15)
	defender.set_equipment_guard_effectiveness(&"equipment_fixture", 2.0, 1.0)
	var facts: Array[CombatEventFact] = []
	var record := func(fact: CombatEventFact): facts.append(fact)
	EventBus.shield_absorption_resolved.connect(record)
	defender.take_damage(10, attacker, Spell.DamageType.PHYSICAL, Spell.Element.NONE, {
		"ignore_defense": true,
		"cannot_be_dodged": true,
		"attack_classification": &"MELEE",
	})
	EventBus.shield_absorption_resolved.disconnect(record)
	assert_eq(defender.get_shield_value(&"guard"), 10)
	assert_eq(facts.size(), 1)
	if facts.is_empty():
		return
	assert_eq(facts[0].amount_absorbed, 10)
	assert_true(facts[0].guard_absorbed)
	assert_eq(facts[0].attack_classification, &"MELEE")
	assert_eq(facts[0].source_absorption[0]["shield_points_spent"], 5)
	assert_eq(facts[0].source_absorption[0]["source_id"], &"guard")
