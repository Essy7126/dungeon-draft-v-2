extends GutTest

const Factory := preload("res://test/support/factory.gd")
const Cleanup := preload("res://test/support/isolated_battlefield_cleanup.gd")
const Decision := preload("res://core/ai/catabase_monster_decision.gd")
const Evolution := preload("res://core/expedition/catabase_monster_evolution_catalog.gd")
var _grids: Array[GridData] = []


class Battle extends Node:
	var _battle_over := false
	var _hud_port = null
	var enemy_ai: EnemyAI
	var units: Array = []
	var spell_caster: SpellCaster
	var grid: GridData
	var grid_view = null
	var _unit_views := {}
	var deferrals := 0

	func _begin_outcome_deferral() -> void:
		deferrals += 1

	func _finish_outcome_deferral() -> bool:
		deferrals -= 1
		return false


class FastRunner extends EnemyTurnRunner:
	func _wait_seconds_safe(_seconds: float, generation: int, enemy: Unit = null, target: Unit = null, require_target := false) -> bool:
		await get_tree().process_frame
		return _can_continue(generation, enemy, target, require_target)


class ClosingBattle extends "res://battle/battle.gd":
	func _ready() -> void:
		pass


func after_each() -> void:
	for grid: GridData in _grids:
		for unit: Unit in grid.get_units():
			unit.clear_combat_effect_history()
		Cleanup.dispose_grid(grid)
	_grids.clear()


func test_pull_then_strike_uses_real_landing_and_remaining_ap() -> void:
	var f := _field()
	var enemy := _monster(f, Vector2i(1, 1))
	var hero := _hero(f, Vector2i(4, 1))
	var pull := _spell("pull", {"ap_cost": 2, "damage": 3, "spell_range": 4, "pull_distance": 2})
	var strike := _spell("strike", {"ap_cost": 3, "damage": 19, "spell_range": 1})
	enemy.spells.assign([strike, pull])
	var first := _action(f, enemy, [enemy, hero])
	assert_same(first.get("spell"), pull)
	f.caster.cast(enemy, pull, first.cell)
	assert_eq(hero.grid_pos, Vector2i(2, 1))
	var second := _action(f, enemy, [enemy, hero])
	assert_same(second.get("spell"), strike)
	assert_eq(second.cell, hero.grid_pos)
	f.caster.cast(enemy, strike, second.cell)
	assert_eq(enemy.current_ap, 1)
	assert_eq(hero.current_hp, 78)
	assert_true(_plan(f, enemy, [enemy, hero]).is_empty())


func test_runner_replans_after_pull_without_ending_the_activation() -> void:
	var f := _field()
	var enemy := _monster(f, Vector2i(1, 1))
	var hero := _hero(f, Vector2i(4, 1))
	enemy.spells.assign([
		_spell("pull", {"ap_cost": 2, "damage": 3, "spell_range": 4, "pull_distance": 2}),
		_spell("strike", {"ap_cost": 3, "damage": 19, "spell_range": 1}),
	])
	var battle := Battle.new()
	add_child_autofree(battle)
	battle.grid = f.grid
	battle.spell_caster = f.caster
	battle.units = [enemy, hero]
	battle.enemy_ai = EnemyAI.new(f.grid, f.pathfinder, f.caster)
	var runner := FastRunner.new()
	battle.add_child(runner)
	runner.setup(battle)
	await runner.run(enemy)
	assert_eq(runner.last_action_count, 2)
	assert_eq(hero.current_hp, 78)
	assert_eq(hero.grid_pos, Vector2i(2, 1))
	assert_eq(battle.deferrals, 0)


func test_veteran_can_use_two_distinct_melee_attacks_without_repeating_either() -> void:
	var f := _field()
	var enemy := _monster(f, Vector2i(1, 1))
	var hero := _hero(f, Vector2i(2, 1))
	enemy.spells.assign([
		_spell("first", {"ap_cost": 3, "damage": 12, "spell_range": 1}),
		_spell("second", {"ap_cost": 3, "damage": 15, "spell_range": 1}),
	])
	var used: Array = []
	for _index in range(2):
		var action := _action(f, enemy, [enemy, hero])
		used.append(action.spell)
		f.caster.cast(enemy, action.spell, action.cell)
	assert_ne(used[0], used[1])
	assert_eq(hero.current_hp, 73)
	assert_eq(enemy.current_ap, 0)
	assert_true(_plan(f, enemy, [enemy, hero]).is_empty())


func test_pull_prefers_an_executors_reach_over_an_uncoordinated_target() -> void:
	var f := _field()
	var puller := _monster(f, Vector2i(1, 1))
	var executor := _monster(f, Vector2i(2, 0))
	executor.spells.assign([_spell("execution", {"damage": 30, "spell_range": 1, "ap_cost": 3})])
	var first := _hero(f, Vector2i(4, 1))
	var second := _hero(f, Vector2i(1, 3))
	second.current_hp = 90
	puller.current_ap = 2
	var pull := _spell("team_pull", {"ap_cost": 2, "damage": 3, "spell_range": 4, "pull_distance": 2})
	puller.spells.assign([pull])
	var action := _action(f, puller, [puller, executor, first, second])
	assert_eq(action.cell, first.grid_pos, "The pull lands this target next to the allied executor")
	f.caster.cast(puller, pull, action.cell)
	assert_true(f.grid.are_adjacent(executor.grid_pos, first.grid_pos))
	assert_false(f.grid.are_adjacent(executor.grid_pos, second.grid_pos))


func test_group_ward_protects_threatened_allies_and_does_not_stack_wastefully() -> void:
	var f := _field()
	var enemy := _monster(f, Vector2i(2, 1))
	var ally := _monster(f, Vector2i(3, 1))
	var hero := _hero(f, Vector2i(4, 1))
	var ward := _spell("ward", {"ap_cost": 3, "spell_range": 0, "can_target_enemy": false,
		"can_target_self": true, "can_target_ally": true, "aoe_shape": Spell.AoeShape.CROSS,
		"aoe_size": 1, "shield_grant": 12, "shield_duration_activations": 2})
	enemy.spells.assign([ward])
	var action := _action(f, enemy, [enemy, ally, hero])
	assert_same(action.get("spell"), ward)
	f.caster.cast(enemy, ward, action.cell)
	assert_eq(enemy.current_shield, 12)
	assert_eq(ally.current_shield, 12)
	assert_eq(hero.current_shield, 0)
	enemy.start_turn()
	enemy.current_mp = 0
	assert_true(_plan(f, enemy, [enemy, ally, hero]).is_empty())


func test_healer_chooses_wounded_ally_and_obeys_combat_charge_limit() -> void:
	var f := _field()
	var healer := _monster(f, Vector2i(1, 1))
	var ally := _monster(f, Vector2i(2, 1))
	var hero := _hero(f, Vector2i(5, 1))
	ally.current_hp = 20
	var heal := _spell("heal", {"ap_cost": 3, "heal": 18, "spell_range": 4,
		"can_target_enemy": false, "can_target_ally": true, "max_uses_per_combat": 2})
	healer.spells.assign([heal])
	for _index in range(2):
		var action := _action(f, healer, [healer, ally, hero])
		assert_same(action.get("spell"), heal)
		assert_eq(action.cell, ally.grid_pos)
		f.caster.cast(healer, heal, action.cell)
		healer.start_turn()
		healer.current_mp = 0
	assert_eq(ally.current_hp, 56)
	assert_eq(healer.get_spell_uses(heal), 2)
	assert_true(_plan(f, healer, [healer, ally, hero]).is_empty())


func test_archer_repositions_out_of_dead_zone_then_fires_from_real_position() -> void:
	var f := _field()
	var archer := _monster(f, Vector2i(3, 1))
	archer.keep_distance = true
	archer.minimum_range = 3
	archer.preferred_range = 4
	archer.current_mp = 2
	var hero := _hero(f, Vector2i(4, 1))
	var arrow := _spell("arrow", {"damage": 12, "ap_cost": 3, "minimum_range": 3, "spell_range": 6})
	archer.spells.assign([arrow])
	var move := _action(f, archer, [archer, hero])
	assert_eq(move.get("type"), "move")
	var path: Array = move.path
	var cost: int = f.pathfinder.path_movement_cost(path, archer)
	archer.spend_mp(cost)
	f.grid.move_unit(archer.grid_pos, path.back())
	var shot := _action(f, archer, [archer, hero])
	assert_eq(shot.get("type"), "cast")
	assert_same(shot.get("spell"), arrow)
	assert_true(f.caster.can_cast(archer, arrow, shot.cell))


func test_collector_supply_line_is_enforced_by_runtime_and_ai() -> void:
	var f := _field()
	var healer := _monster(f, Vector2i(1, 1))
	var ally := _monster(f, Vector2i(2, 1))
	var hero := _hero(f, Vector2i(5, 1))
	ally.current_hp = 20
	var heal := _spell("supply_heal", {"ap_cost": 3, "heal": 20, "spell_range": 4,
		"can_target_enemy": false, "can_target_ally": true, "max_uses_per_combat": 3})
	heal.set_meta("catabase_requires_role_nearby", &"catabase_evolution_porteur")
	heal.set_meta("catabase_support_radius", 2)
	healer.spells.assign([heal])
	assert_eq(f.caster.get_cast_failure_reason(healer, heal, ally.grid_pos), &"support_out_of_range")
	assert_true(_plan(f, healer, [healer, ally, hero]).is_empty())
	f.caster.cast(healer, heal, ally.grid_pos)
	assert_eq(healer.current_ap, 6)
	assert_eq(healer.get_spell_uses(heal), 0)
	assert_eq(ally.current_hp, 20)
	var porter := _monster(f, Vector2i(1, 2))
	porter.tactical_role_id = &"catabase_evolution_porteur"
	assert_eq(f.caster.get_cast_failure_reason(healer, heal, ally.grid_pos), &"")
	var action := _action(f, healer, [healer, ally, hero, porter])
	f.caster.cast(healer, heal, action.cell)
	assert_eq(ally.current_hp, 40)
	healer.start_turn()
	healer.current_mp = 0
	f.grid.move_unit(porter.grid_pos, Vector2i(7, 2))
	assert_eq(f.caster.get_cast_failure_reason(healer, heal, ally.grid_pos), &"support_out_of_range")
	f.grid.move_unit(porter.grid_pos, Vector2i(1, 2))
	porter.is_alive = false
	assert_eq(f.caster.get_cast_failure_reason(healer, heal, ally.grid_pos), &"support_out_of_range")
	assert_eq(healer.get_spell_uses(heal), 1)


func test_authored_porter_joins_collector_and_keeps_the_supply_radius_when_attacking() -> void:
	var f := _field()
	var collector := Unit.from_data(Evolution.build_unit(&"collecteur", {"depth": 15}))
	var porter := Unit.from_data(Evolution.build_unit(&"porteur", {"depth": 15}))
	var hero := _hero(f, Vector2i(9, 1))
	f.grid.place_unit(collector, Vector2i(2, 1))
	f.grid.place_unit(porter, Vector2i(7, 1))
	collector.start_turn()
	porter.start_turn()
	var units := [collector, porter, hero]
	var action := _action(f, porter, units)
	assert_eq(action.get("type"), "move", "The porter escorts its collector even when a shot is already available")
	_apply_move(f, porter, action.path)
	assert_lte(f.grid.manhattan(porter.grid_pos, collector.grid_pos), 2)
	porter.start_turn()
	action = _action(f, porter, units)
	if action.get("type") == "move":
		_apply_move(f, porter, action.path)
	else:
		f.caster.cast(porter, action.spell, action.cell)
	assert_lte(f.grid.manhattan(porter.grid_pos, collector.grid_pos), 2)
	for next: Dictionary in _plan(f, porter, units):
		if next.get("type") == "move":
			_apply_move(f, porter, next.path)
	assert_lte(f.grid.manhattan(porter.grid_pos, collector.grid_pos), 2, "Subsequent offensive repositioning preserves supply")


func test_authored_collector_reconnects_for_a_heal_then_fights_after_porter_death() -> void:
	var f := _field()
	var collector := Unit.from_data(Evolution.build_unit(&"collecteur", {"depth": 15}))
	var porter := Unit.from_data(Evolution.build_unit(&"porteur", {"depth": 15}))
	var ally := _monster(f, Vector2i(5, 2))
	ally.current_hp = 20
	var hero := _hero(f, Vector2i(1, 3))
	f.grid.place_unit(collector, Vector2i(1, 1))
	f.grid.place_unit(porter, Vector2i(6, 1))
	collector.start_turn()
	var units := [collector, porter, ally, hero]
	var action := _action(f, collector, units)
	assert_eq(action.get("type"), "move")
	_apply_move(f, collector, action.path)
	assert_lte(f.grid.manhattan(collector.grid_pos, porter.grid_pos), 2)
	action = _action(f, collector, units)
	var heal := action.get("spell") as Spell
	assert_not_null(heal)
	assert_true(heal.is_healing())
	assert_eq(action.cell, ally.grid_pos)
	f.caster.cast(collector, heal, action.cell)
	assert_gt(ally.current_hp, 20)
	porter.is_alive = false
	collector.start_turn()
	collector.current_mp = 0
	f.grid.move_unit(hero.grid_pos, collector.grid_pos + Vector2i(0, 2))
	action = _action(f, collector, units)
	assert_eq(action.get("type"), "cast")
	assert_false((action.spell as Spell).is_healing(), "A dead porter disables only dependent healing")
	assert_true(f.caster.can_cast(collector, action.spell, action.cell))


func test_hound_prefers_pushing_into_existing_fire_over_plain_bite() -> void:
	var f := _field()
	var dog := _monster(f, Vector2i(1, 1))
	var hero := _hero(f, Vector2i(2, 1))
	var fire := TerrainEffectData.new()
	fire.surface_id = &"catabase_test_fire"
	fire.trigger = TerrainEffectData.Trigger.ON_ENTER
	fire.damage = 12
	fire.can_be_dodged = false
	f.terrain.place_effect(Vector2i(3, 1), fire)
	var push := _spell("push", {"damage": 5, "push_distance": 1, "spell_range": 1, "ap_cost": 3})
	dog.spells.assign([_spell("bite", {"damage": 14, "spell_range": 1, "ap_cost": 3}), push])
	var action := _action(f, dog, [dog, hero])
	assert_same(action.get("spell"), push)
	f.caster.cast(dog, push, action.cell)
	assert_eq(hero.grid_pos, Vector2i(3, 1))
	assert_lt(hero.current_hp, 95, "The existing fire resolves on forced entry")


func test_conductor_marks_for_melee_allies_and_hound_consumes_real_damage_bonus() -> void:
	var f := _field()
	var conductor := _monster(f, Vector2i(1, 1))
	var dog := _monster(f, Vector2i(3, 1))
	var hero := _hero(f, Vector2i(4, 1))
	var status := StatusData.new()
	status.status_id = &"catabase_chasse"
	status.duration = 2
	var mark := _spell("mark", {"ap_cost": 2, "spell_range": 5, "applied_status": status})
	conductor.spells.assign([mark])
	var bite := _spell("bite", {"damage": 10, "spell_range": 1, "ap_cost": 3,
		"bonus_damage_status_id": &"catabase_chasse", "bonus_damage_if_marked": 5})
	dog.spells.assign([bite])
	var action := _action(f, conductor, [conductor, dog, hero])
	assert_same(action.get("spell"), mark)
	f.caster.cast(conductor, mark, action.cell)
	assert_true(hero.has_status(&"catabase_chasse"))
	action = _action(f, dog, [conductor, dog, hero])
	f.caster.cast(dog, action.spell, action.cell)
	assert_eq(hero.current_hp, 85)


func test_oracle_buffs_an_ally_who_can_reach_the_hero() -> void:
	var f := _field()
	var oracle := _monster(f, Vector2i(1, 1))
	var brute := _monster(f, Vector2i(3, 1))
	var hero := _hero(f, Vector2i(4, 1))
	brute.spells.assign([_spell("strike", {"damage": 10, "spell_range": 1})])
	var buff := StatusData.new()
	buff.status_id = &"catabase_test_presage"
	buff.outgoing_damage_modifier = 5
	var spell := _spell("presage", {"ap_cost": 2, "minimum_range": 1, "spell_range": 4,
		"can_target_enemy": false, "can_target_ally": true, "applied_status": buff})
	oracle.spells.assign([spell])
	var action := _action(f, oracle, [oracle, brute, hero])
	assert_same(action.get("spell"), spell)
	assert_eq(action.cell, brute.grid_pos)
	f.caster.cast(oracle, spell, action.cell)
	assert_true(brute.has_status(buff.status_id))


func test_self_centered_sweep_is_selected_for_multiple_opponents() -> void:
	var f := _field()
	var brute := _monster(f, Vector2i(2, 1))
	var first := _hero(f, Vector2i(3, 1))
	var second := _hero(f, Vector2i(2, 2))
	var sweep := _spell("sweep", {"damage": 11, "ap_cost": 3, "spell_range": 0,
		"can_target_enemy": false, "can_target_self": true, "aoe_shape": Spell.AoeShape.CROSS,
		"aoe_size": 1, "exclude_allies_from_area_effects": true, "exclude_caster_from_area_effects": true})
	brute.spells.assign([_spell("strike", {"damage": 15, "ap_cost": 3, "spell_range": 1}), sweep])
	var action := _action(f, brute, [brute, first, second])
	assert_same(action.get("spell"), sweep)
	f.caster.cast(brute, sweep, action.cell)
	assert_eq(brute.current_hp, 100)
	assert_eq(first.current_hp, 89)
	assert_eq(second.current_hp, 89)


func test_delayed_strike_ends_planning_and_escape_cancels_the_hit() -> void:
	var f := _field()
	var enemy := _monster(f, Vector2i(1, 1))
	var hero := _hero(f, Vector2i(2, 1))
	var heavy := _spell("heavy", {"damage": 35, "ap_cost": 3, "spell_range": 1,
		"delayed_resolution": Spell.DelayedResolution.STRIKE_AND_PUSH, "consumes_activation_on_resolution": true})
	enemy.spells.assign([heavy])
	var action := _action(f, enemy, [enemy, hero])
	f.caster.cast(enemy, heavy, action.cell)
	assert_false(enemy.pending_ability.is_empty())
	assert_eq(hero.current_hp, 100)
	assert_true(_plan(f, enemy, [enemy, hero]).is_empty())
	f.grid.move_unit(hero.grid_pos, Vector2i(4, 1))
	enemy.start_turn()
	var resolved: Dictionary = f.caster.resolve_pending_activation(enemy, [enemy, hero])
	assert_true(resolved.blocked)
	assert_eq(hero.current_hp, 100)
	assert_true(_plan(f, enemy, [enemy, hero]).is_empty())


func test_decision_does_not_consume_resources_or_change_occupancy() -> void:
	var f := _field()
	var enemy := _monster(f, Vector2i(1, 1))
	enemy.current_mp = 3
	var hero := _hero(f, Vector2i(5, 1))
	var strike := _spell("strike", {"damage": 20, "spell_range": 1, "ap_cost": 3})
	enemy.spells.assign([strike])
	var plan := _plan(f, enemy, [enemy, hero])
	assert_false(plan.is_empty())
	assert_eq(enemy.current_ap, 6)
	assert_eq(enemy.current_mp, 3)
	assert_eq(enemy.get_spell_uses(strike), 0)
	assert_eq(enemy.grid_pos, Vector2i(1, 1))
	assert_same(f.grid.get_unit(enemy.grid_pos), enemy)
	assert_eq(hero.current_hp, 100)
	assert_true(hero.active_statuses.is_empty())


func test_legacy_profiles_remain_outside_reactive_planning() -> void:
	var enemy := Factory.make_unit("Legacy", 1)
	assert_false(Decision.handles(enemy))
	enemy.ai_profile = EnemyAIProfile.new()
	enemy.ai_profile.profile_id = &"paris_spectral"
	assert_false(Decision.handles(enemy))
	enemy.ai_profile.profile_id = &"catabase_evolution_rabatteur"
	assert_true(Decision.handles(enemy))


func test_battle_shutdown_releases_support_fact_cycles_without_changing_combat_results() -> void:
	var f := _field()
	var enemy := _monster(f, Vector2i(1, 1))
	var ally := _monster(f, Vector2i(2, 1))
	ally.current_hp = 30
	var heal := _spell("closing_heal", {"ap_cost": 3, "heal": 18, "spell_range": 3,
		"can_target_enemy": false, "can_target_ally": true})
	enemy.spells.assign([heal])
	f.caster.cast(enemy, heal, ally.grid_pos)
	assert_false(ally._resolved_combat_effects.is_empty())
	var battle := ClosingBattle.new()
	add_child_autofree(battle)
	battle.units = [enemy, ally]
	battle._begin_battle_shutdown()
	assert_true(ally._resolved_combat_effects.is_empty())
	assert_eq(ally.current_hp, 48)
	assert_eq(enemy.current_ap, 3)
	assert_eq(enemy.current_mp, 0)
	assert_eq(enemy.get_spell_uses(heal), 1)


func _field() -> Factory.Battlefield:
	var f = Factory.make_battlefield(10, 4)
	_grids.append(f.grid)
	return f


func _monster(f, cell: Vector2i) -> Unit:
	var enemy := Factory.make_unit("Monstre", 1)
	enemy.ai_profile = EnemyAIProfile.new()
	enemy.ai_profile.profile_id = &"catabase_evolution_test"
	enemy.current_mp = 0
	f.grid.place_unit(enemy, cell)
	return enemy


func _hero(f, cell: Vector2i) -> Unit:
	var hero := Factory.make_unit("Héros", 0)
	f.grid.place_unit(hero, cell)
	return hero


func _spell(id: String, properties: Dictionary) -> Spell:
	properties.spell_id = StringName("catabase_test_" + id)
	properties.once_per_activation = true
	return Factory.make_spell(properties)


func _plan(f, enemy: Unit, units: Array) -> Array:
	return EnemyAI.new(f.grid, f.pathfinder, f.caster).decide(enemy, units)


func _apply_move(f, unit: Unit, path: Array) -> void:
	var cost: int = f.pathfinder.path_movement_cost(path, unit)
	assert_true(unit.spend_mp(cost))
	f.grid.move_unit(unit.grid_pos, path.back())


func _action(f, enemy: Unit, units: Array) -> Dictionary:
	var plan := _plan(f, enemy, units)
	assert_eq(plan.size(), 1, "One action is followed by a fresh decision on the resolved board")
	return plan[0] if not plan.is_empty() else {}
