extends GutTest

const Factory = preload("res://test/support/factory.gd")


func test_two_activation_shield_uses_beneficiary_clock_and_preserves_other_sources() -> void:
	var mage := Factory.make_unit("Mage", 1)
	var ally := Factory.make_unit("Allié", 1)
	mage.start_turn()
	mage.start_turn()
	ally.add_sourced_shield(&"philosopher_aegis", 20, mage, {"expires_after_activations": 2})
	ally.add_sourced_shield(&"permanent_ward", 7)
	mage.start_turn()
	mage.start_turn()
	assert_eq(ally.current_shield, 27, "Caster activations do not consume an ally's protection.")
	ally.start_turn()
	assert_eq(ally.current_shield, 27)
	ally.start_turn()
	assert_eq(ally.get_shield_value(&"philosopher_aegis"), 0)
	assert_eq(ally.get_shield_value(&"permanent_ward"), 7)


func test_duration_snapshot_keeps_absolute_expiry_after_restore() -> void:
	var original := Factory.make_unit()
	original.add_sourced_shield(&"aegis", 20, null, {"expires_after_activations": 3})
	original.start_turn()
	var snapshot := original.get_shield_instances_snapshot()
	assert_eq(snapshot[0].expires_activation, 3)
	var restored := Factory.make_unit()
	restored.start_turn()
	assert_true(restored.restore_shield_instances_snapshot(snapshot))
	assert_eq(restored.get_shield_instances_snapshot(), snapshot)
	restored.start_turn()
	assert_eq(restored.current_shield, 20)
	restored.start_turn()
	assert_eq(restored.current_shield, 0)


func test_invalid_duration_snapshot_is_rejected_without_mutating_shields() -> void:
	var unit := Factory.make_unit()
	unit.add_sourced_shield(&"aegis", 20, null, {"expires_after_activations": 2})
	var before := unit.get_shield_instances_snapshot()
	var invalid := before.duplicate(true)
	invalid[0].expires_activation = invalid[0].created_activation
	assert_false(unit.restore_shield_instances_snapshot(invalid))
	assert_eq(unit.get_shield_instances_snapshot(), before)
	invalid[0].erase("expires_activation")
	assert_false(unit.restore_shield_instances_snapshot(invalid))
	assert_eq(unit.get_shield_instances_snapshot(), before)


func test_legacy_snapshot_without_duration_field_remains_loadable() -> void:
	var unit := Factory.make_unit()
	unit.add_sourced_shield(&"guard", 8, null, {"expires_after_activations": 1})
	var legacy := unit.get_shield_instances_snapshot()
	legacy[0].erase("expires_activation")
	var restored := Factory.make_unit()
	assert_true(restored.restore_shield_instances_snapshot(legacy))
	assert_eq(restored.current_shield, 8)
	restored.start_turn()
	assert_eq(restored.current_shield, 0)
