extends GutTest

const Factory = preload("res://test/support/factory.gd")
const Executor = preload("res://battle/relic_tactical_intent_executor.gd")
var field
var hero: Unit
var enemy: Unit
var executor
var _intent_serial := 0

func before_each() -> void:
	field = Factory.make_battlefield(8, 5)
	hero = Factory.make_unit("Achille", 0)
	enemy = Factory.make_unit("Ennemi", 1)
	field.grid.set_unit(Vector2i(2, 2), hero)
	field.grid.set_unit(Vector2i(3, 2), enemy)
	executor = Executor.new()
	executor.configure(field.grid, field.caster, null)

func after_each() -> void:
	executor.dispose()

func test_vengeance_damage_and_guard_are_scoped_to_marked_enemy() -> void:
	executor.handle_intent(_intent("patroclus_ashes", {"damage_source_id": enemy.get_runtime_stable_id()}))
	var outgoing := _hit(hero, &"strike", 40)
	executor.on_before_hit(enemy, outgoing)
	assert_eq(outgoing.raw_damage, 50)
	hero.add_sourced_shield(&"guard", 100, hero, {"tags": [&"guard"]})
	var incoming := _hit(enemy, &"strike", 100)
	executor.on_before_hit(hero, incoming)
	assert_almost_eq(incoming.guard_damage_multiplier, 0.8, 0.0001)
	hero.take_hit(incoming)
	assert_eq(hero.get_shield_value(&"guard"), 20)
	var other := Factory.make_unit("Autre", 1)
	var neutral := _hit(other, &"strike", 100)
	executor.on_before_hit(hero, neutral)
	assert_eq(neutral.guard_damage_multiplier, 1.0)
	var terrain_hit := _hit(null, &"terrain", 10)
	executor.on_before_hit(enemy, terrain_hit)
	assert_eq(terrain_hit.raw_damage, 10, "A hit without an attacker never reads a missing mark")

func test_dash_waives_minimum_for_next_shot_and_expires_at_activation_end() -> void:
	var shot := Factory.make_spell({"spell_id": &"achilles_pelion_shot", "minimum_range": 2, "spell_range": 6})
	executor.handle_intent(_intent("centaur_step"))
	assert_eq(field.caster.get_effective_spell_minimum_range(hero, shot), 0)
	var hit := _hit(hero, shot.spell_id, 100)
	executor.on_before_hit(enemy, hit)
	assert_eq(hit.raw_damage, 115)
	executor.on_spell_completed(hero, shot, {})
	assert_eq(field.caster.get_effective_spell_minimum_range(hero, shot), 2)
	var next := _hit(hero, shot.spell_id, 100)
	executor.on_before_hit(enemy, next)
	assert_eq(next.raw_damage, 100)
	executor.handle_intent(_intent("centaur_step"))
	executor.on_activation_ended(hero)
	assert_eq(field.caster.get_effective_spell_minimum_range(hero, shot), 2)

func test_dual_technique_applies_to_second_and_cannot_rearm_in_activation() -> void:
	var strike := Factory.make_spell({"spell_id": &"achilles_peleid_strike"})
	var shot := Factory.make_spell({"spell_id": &"achilles_pelion_shot"})
	executor.handle_intent(_intent("pelion_shard", {"spell_id": strike.spell_id}))
	var hit := _hit(hero, shot.spell_id, 40)
	executor.on_before_hit(enemy, hit)
	assert_eq(hit.raw_damage, 50)
	assert_eq(hit.pen_flat, 25.0)
	executor.on_spell_completed(hero, shot, {})
	executor.handle_intent(_intent("pelion_shard", {"spell_id": shot.spell_id}, 1))
	var third := _hit(hero, strike.spell_id, 40)
	executor.on_before_hit(enemy, third)
	assert_eq(third.raw_damage, 40)
	executor.on_activation_started(hero)
	executor.handle_intent(_intent("pelion_shard", {"spell_id": shot.spell_id}, 1))
	var reversed := _hit(hero, strike.spell_id, 40)
	executor.on_before_hit(enemy, reversed)
	assert_eq(reversed.raw_damage, 50)

func test_mirror_uses_damage_physics_and_duplicate_intent_does_not_reflect_twice() -> void:
	enemy.armure.base_value = 100
	var intent := _intent("athena_mirror", {"damage_source_id": enemy.get_runtime_stable_id(), "amount_absorbed": 80})
	executor.execute_intent(intent)
	assert_eq(enemy.current_hp, 80, "40 reflected physical damage is mitigated by 100 armor")
	executor.execute_intent(intent)
	assert_eq(enemy.current_hp, 80)

func test_anchor_consumes_only_guard_preserves_expiry_and_pushes_nearby_enemy() -> void:
	hero.add_sourced_shield(&"guard", 100, hero, {"tags": [&"guard"], "expires_after_activations": 1})
	hero.add_sourced_shield(&"other", 50, hero)
	var before := hero.get_shield_instances_snapshot()
	executor.handle_intent(_intent("thetis_anchor"))
	assert_eq(hero.get_shield_value(&"guard"), 70)
	assert_eq(hero.get_shield_value(&"other"), 50)
	assert_eq(enemy.current_hp, 70)
	assert_eq(enemy.grid_pos, Vector2i(4, 2))
	assert_eq(hero.get_shield_instances_snapshot()[0].expiry_policy, before[0].expiry_policy)

func test_nail_debuff_refreshes_and_only_next_strike_hits_cell_behind() -> void:
	var behind := Factory.make_unit("Derriere", 1)
	field.grid.set_unit(Vector2i(4, 2), behind)
	enemy.armure.base_value = 80
	var collision := _intent("hephaestus_nail", {"event_target_id": enemy.get_runtime_stable_id()})
	executor.handle_intent(collision)
	executor.handle_intent(_intent("hephaestus_nail", {"event_target_id": enemy.get_runtime_stable_id()}))
	assert_eq(enemy.armure.get_int(), 40, "Repeated collisions refresh the same source")
	var strike := Factory.make_spell({"spell_id": &"achilles_peleid_strike", "damage": 40})
	var hit := _hit(hero, strike.spell_id, 40)
	executor.on_before_hit(enemy, hit)
	executor.on_spell_completed(hero, strike, {"action_id": hit.action_id})
	assert_eq(behind.current_hp, 80)
	executor.on_spell_completed(hero, strike, {})
	assert_eq(behind.current_hp, 80)
	executor.dispose()
	assert_eq(enemy.armure.get_int(), 80)

func _intent(file: String, extra: Dictionary = {}, effect_index: int = 0) -> Dictionary:
	var item := load("res://data/items/definitions/odyssey/%s.tres" % file) as ItemDefinition
	_intent_serial += 1
	var data := {"actor_id": hero.get_runtime_stable_id(), "item_id": item.item_id,
		"instance_id": "test_%s" % file, "effect_index": effect_index,
		"event_serial": _intent_serial, "action_id": "action_%d" % _intent_serial}
	data.merge(extra, true)
	return RelicEffectRegistry.new().build_tactical_intent(item.reactive_effects[effect_index], data)

func _hit(actor: Unit, ability: StringName, amount: int) -> DamageResolver.HitContext:
	var ctx := DamageResolver.HitContext.new()
	ctx.attacker = actor
	ctx.raw_damage = amount
	ctx.ability_id = ability
	ctx.attack_classification = &"MELEE"
	ctx.action_id = &"manual_test"
	return ctx
