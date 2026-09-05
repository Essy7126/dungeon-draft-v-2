extends GutTest

const Factory = preload("res://test/support/factory.gd")


func _guard(amount: int) -> Spell:
	return Factory.make_spell({
		"spell_id": &"qa_sourced_guard",
		"ap_cost": 2,
		"spell_range": 0,
		"can_target_enemy": false,
		"can_target_self": true,
		"once_per_activation": true,
		"shield_grant": amount,
	})


func test_new_combat_applies_first_guard_from_new_spell_caster_to_persistent_unit() -> void:
	var hero: Unit = Factory.make_unit("Persistent hero", 0)
	var first_guard: Spell = _guard(10)
	hero.spells.append(first_guard)
	hero.reset_combat_resources()
	hero.start_turn()
	var first_field: Factory.Battlefield = Factory.make_battlefield(3, 3)
	assert_true(first_field.grid.place_unit(hero, Vector2i(1, 1)))
	var first_cast: CastContext = first_field.caster.begin_cast(hero, first_guard, hero.grid_pos)
	assert_false(first_cast.failed)
	var first_report: Dictionary = first_field.caster.resolve_cast(first_cast)
	assert_eq(hero.current_ap, 4)
	assert_eq(hero.get_shield_value(&"qa_sourced_guard"), 10)
	assert_eq(int(first_report.get("shield_increase_total", 0)), 10)
	# Replaying the same resolved context in this combat must have no effect.
	first_field.caster.resolve_cast(first_cast)
	assert_eq(hero.current_ap, 4)
	assert_eq(hero.get_shield_value(&"qa_sourced_guard"), 10)
	assert_eq(hero.get_spell_uses(first_guard), 1)

	first_field.grid.clear_unit(hero.grid_pos)
	var second_guard: Spell = _guard(12)
	hero.spells.clear()
	hero.spells.append(second_guard)
	# This is the existing Battle startup boundary, without replacing the Unit.
	hero.reset_combat_resources()
	assert_eq(hero.current_ap, 6)
	# A persistent shield is deliberately retained, so the new impact must
	# strengthen its source from10 to12 instead of reusing the old combat fact.
	assert_eq(hero.get_shield_value(&"qa_sourced_guard"), 10)
	hero.start_turn()
	var second_field: Factory.Battlefield = Factory.make_battlefield(3, 3)
	assert_true(second_field.grid.place_unit(hero, Vector2i(1, 1)))
	var second_cast: CastContext = second_field.caster.begin_cast(hero, second_guard, hero.grid_pos)
	assert_false(second_cast.failed)
	assert_eq(second_cast.cast_id, first_cast.cast_id, "Fresh SpellCasters reuse local cast IDs across rooms")
	var second_report: Dictionary = second_field.caster.resolve_cast(second_cast)
	assert_eq(hero.current_ap, 4)
	assert_eq(hero.get_shield_value(&"qa_sourced_guard"), 12, "The new combat must apply its own shield impact")
	assert_eq(int(second_report.get("shield_increase_total", 0)), 2)
	assert_eq(hero.get_spell_uses(second_guard), 1)
	second_field.caster.resolve_cast(second_cast)
	assert_eq(hero.current_ap, 4)
	assert_eq(hero.get_shield_value(&"qa_sourced_guard"), 12)
	assert_eq(hero.get_spell_uses(second_guard), 1)


func test_duplicate_unit_impact_stays_idempotent_across_activations_until_new_combat() -> void:
	var hero: Unit = Factory.make_unit()
	hero.reset_combat_resources()
	var metadata: Dictionary = {"impact_id": &"cast_000001:000"}
	var original: CombatEventFact = hero.add_sourced_shield(&"qa_guard", 10, hero, metadata)
	assert_not_null(original)
	# Higher payload deliberately detects reapplication of the same impact.
	var repeated: CombatEventFact = hero.add_sourced_shield(&"qa_guard", 12, hero, metadata)
	assert_same(repeated, original)
	assert_eq(hero.get_shield_value(&"qa_guard"), 10)
	hero.start_turn()
	var next_activation: CombatEventFact = hero.add_sourced_shield(&"qa_guard", 14, hero, metadata)
	assert_same(next_activation, original, "A turn boundary must not clear combat idempotence")
	assert_eq(hero.get_shield_value(&"qa_guard"), 10)

	hero.reset_combat_resources()
	var new_combat: CombatEventFact = hero.add_sourced_shield(&"qa_guard", 12, hero, metadata)
	assert_not_null(new_combat)
	assert_ne(new_combat, original)
	assert_eq(hero.get_shield_value(&"qa_guard"), 12)
	assert_same(hero.add_sourced_shield(&"qa_guard", 20, hero, metadata), new_combat)
	assert_eq(hero.get_shield_value(&"qa_guard"), 12)
