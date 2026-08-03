extends GutTest

const Factory = preload("res://test/support/factory.gd")
const NORMAL_PATH := "res://data/units/ennemie/skeleton_melee.tres"
const CHIEF_PATH := "res://data/units/ennemie/skeleton_chief.tres"
const CENTURION_PATH := "res://data/units/ennemie/skeleton_snow_centurion.tres"
const MARK_STATUS_PATH := "res://data/status/enemies/centurion_mark.tres"


func _unit(path: String) -> Unit:
	return Unit.from_data(load(path) as UnitData)


func _spell(unit: Unit, spell_id: StringName) -> Spell:
	for value in unit.spells:
		var spell := value as Spell
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell
	return null


func _hero(name: String = "Hero", hp: int = 200) -> Unit:
	var hero := Unit.new(name, 0, hp, 10, 6, 3, 20)
	hero.unit_id = StringName(name.to_lower())
	return hero


func test_resources_match_the_three_exact_stat_lines() -> void:
	var normal := load(NORMAL_PATH) as UnitData
	assert_eq([normal.max_hp, normal.max_ap, normal.max_mp, normal.initiative], [72, 4, 5, 12])
	assert_eq([normal.armure, normal.resist_magique, normal.esquive, normal.crit_chance], [0.0, 0.0, 0.0, 0.0])
	assert_false(normal.basic_attack_enabled)
	assert_eq(normal.spells.size(), 1)
	assert_eq(normal.spells[0].damage, 18)
	assert_eq(normal.spells[0].bonus_damage_if_marked, 6)

	var chief := load(CHIEF_PATH) as UnitData
	assert_eq([chief.max_hp, chief.max_ap, chief.max_mp, chief.initiative], [220, 6, 2, 6])
	assert_eq([chief.armure, chief.resist_magique], [90.0, 70.0])
	assert_false(chief.basic_attack_enabled)
	assert_eq(chief.spells.size(), 2)

	var centurion := load(CENTURION_PATH) as UnitData
	assert_eq([centurion.max_hp, centurion.max_ap, centurion.max_mp, centurion.initiative], [150, 6, 3, 16])
	assert_eq([centurion.armure, centurion.resist_magique], [15.0, 80.0])
	assert_eq(centurion.resistances[Spell.Element.ICE], 0.5)
	assert_eq(centurion.resistances[Spell.Element.FIRE], -0.25)
	assert_eq(centurion.spells.size(), 5)


func test_formation_macabre_counts_zero_one_two_and_caps_three_neighbors() -> void:
	var grid := GridData.new(7, 7)
	var skeleton := _unit(NORMAL_PATH)
	grid.place_unit(skeleton, Vector2i(3, 3))
	assert_eq(skeleton.armure.get_int(), 0)
	var one := _hero("one")
	grid.place_unit(one, Vector2i(3, 2))
	assert_eq(skeleton.armure.get_int(), 25)
	var two := _unit(NORMAL_PATH)
	grid.place_unit(two, Vector2i(4, 3))
	assert_eq(skeleton.armure.get_int(), 50)
	var three := _hero("three")
	grid.place_unit(three, Vector2i(3, 4))
	assert_eq(skeleton.armure.get_int(), 50)
	assert_true(skeleton.armure.has_source("formation_macabre"))


func test_formation_recalculates_immediately_after_push_and_death() -> void:
	var field := Factory.make_battlefield(8, 5)
	var attacker := _hero("attacker")
	var skeleton := _unit(NORMAL_PATH)
	var neighbor := _hero("neighbor")
	field.grid.place_unit(attacker, Vector2i(0, 2))
	field.grid.place_unit(neighbor, Vector2i(1, 2))
	field.grid.place_unit(skeleton, Vector2i(1, 1))
	assert_eq(skeleton.armure.get_int(), 25)
	field.caster._push_unit(attacker, neighbor, 2)
	assert_eq(skeleton.armure.get_int(), 0)
	field.grid.relocate_unit(neighbor, Vector2i(1, 2))
	assert_eq(skeleton.armure.get_int(), 25)
	neighbor.take_damage(999, attacker, Spell.DamageType.PHYSICAL, Spell.Element.NONE, {"cannot_be_dodged": true})
	assert_eq(skeleton.armure.get_int(), 0)


func test_reference_damage_uses_the_central_resolver_rounding() -> void:
	var attacker := _hero("attacker")
	var isolated := _unit(NORMAL_PATH)
	assert_eq(isolated.take_damage(30, attacker).amount, 30)
	isolated.armure.add_modifier(25, Stat.ModType.FLAT, "test")
	assert_eq(isolated.take_damage(30, attacker).amount, 24)
	isolated.armure.remove_modifiers_from("test")
	isolated.armure.add_modifier(50, Stat.ModType.FLAT, "test")
	assert_eq(isolated.take_damage(30, attacker).amount, 20)
	var chief := _unit(CHIEF_PATH)
	assert_eq(chief.take_damage(40, attacker, Spell.DamageType.PHYSICAL).amount, 21)
	assert_eq(chief.take_damage(40, attacker, Spell.DamageType.MAGICAL).amount, 24)
	var centurion := _unit(CENTURION_PATH)
	assert_eq(centurion.take_damage(30, attacker, Spell.DamageType.MAGICAL, Spell.Element.ICE).amount, 8)
	assert_eq(centurion.take_damage(30, attacker, Spell.DamageType.MAGICAL, Spell.Element.FIRE).amount, 21)


func test_bone_blade_uses_only_the_linked_centurion_mark() -> void:
	var field := Factory.make_battlefield(8, 4)
	var skeleton := _unit(NORMAL_PATH)
	var linked := _unit(CENTURION_PATH)
	var other := _unit(CENTURION_PATH)
	var target := _hero("target")
	field.grid.place_unit(skeleton, Vector2i(1, 1))
	field.grid.place_unit(linked, Vector2i(0, 1))
	field.grid.place_unit(other, Vector2i(7, 3))
	field.grid.place_unit(target, Vector2i(2, 1))
	assert_eq(skeleton.linked_commander, linked)
	var blade := _spell(skeleton, &"skeleton_bone_blade")
	var mark := load(MARK_STATUS_PATH) as StatusData
	target.apply_status(mark, other)
	var before := target.current_hp
	field.caster.cast(skeleton, blade, target.grid_pos)
	assert_eq(before - target.current_hp, 18)
	skeleton.start_turn()
	target.remove_status(&"centurion_mark")
	target.apply_status(mark, linked)
	before = target.current_hp
	field.caster.cast(skeleton, blade, target.grid_pos)
	assert_eq(before - target.current_hp, 24)


func test_cooldown_three_is_available_exactly_at_n_plus_three() -> void:
	var field := Factory.make_battlefield(4, 2)
	var chief := _unit(CHIEF_PATH)
	var target := _hero("target")
	field.grid.place_unit(chief, Vector2i(1, 0))
	field.grid.place_unit(target, Vector2i(2, 0))
	var sentence := _spell(chief, &"scarlet_sentence")
	chief.start_turn()
	assert_false(field.caster.cast(chief, sentence, target.grid_pos).get("failed", false))
	assert_eq(chief.get_spell_cooldown_remaining(sentence), 3)
	chief.start_turn()
	assert_false(chief.can_use_spell(sentence))
	chief.start_turn()
	assert_false(chief.can_use_spell(sentence))
	chief.start_turn()
	assert_true(chief.can_use_spell(sentence))


func test_sentence_prepares_without_damage_then_resolves_and_consumes_activation() -> void:
	var field := Factory.make_battlefield(6, 2)
	var chief := _unit(CHIEF_PATH)
	var target := _hero("target")
	field.grid.place_unit(chief, Vector2i(1, 0))
	field.grid.place_unit(target, Vector2i(2, 0))
	var sentence := _spell(chief, &"scarlet_sentence")
	chief.start_turn()
	var before := target.current_hp
	var prepare := field.caster.cast(chief, sentence, target.grid_pos)
	assert_true(prepare.telegraphed)
	assert_eq(target.current_hp, before)
	assert_false(chief.pending_ability.is_empty())
	chief.start_turn()
	var resolved := field.caster.resolve_pending_activation(chief)
	assert_true(resolved.resolved)
	assert_true(resolved.consume_activation)
	assert_eq(before - target.current_hp, 56)
	assert_eq(target.grid_pos, Vector2i(3, 0))
	assert_eq([chief.current_ap, chief.current_mp], [0, 0])


func test_sentence_fails_if_target_moves_and_is_cancelled_if_chief_dies() -> void:
	var field := Factory.make_battlefield(7, 2)
	var chief := _unit(CHIEF_PATH)
	var target := _hero("target", 400)
	field.grid.place_unit(chief, Vector2i(1, 0))
	field.grid.place_unit(target, Vector2i(2, 0))
	var sentence := _spell(chief, &"scarlet_sentence")
	chief.start_turn()
	field.caster.cast(chief, sentence, target.grid_pos)
	field.grid.relocate_unit(target, Vector2i(4, 0))
	chief.start_turn()
	var failed := field.caster.resolve_pending_activation(chief)
	assert_true(failed.blocked)
	assert_eq(target.current_hp, 400)
	chief.start_turn()
	chief.start_turn()
	field.grid.relocate_unit(target, Vector2i(2, 0))
	field.caster.cast(chief, sentence, target.grid_pos)
	chief.take_damage(9999, target)
	assert_true(chief.pending_ability.is_empty())


func test_colossal_frame_reduces_only_first_forced_move_per_actor_activation() -> void:
	var field := Factory.make_battlefield(10, 2)
	var attacker := _hero("attacker")
	var chief := _unit(CHIEF_PATH)
	field.grid.place_unit(attacker, Vector2i(0, 0))
	field.grid.place_unit(chief, Vector2i(1, 0))
	chief.on_actor_activation_started(attacker)
	field.caster._push_unit(attacker, chief, 1)
	assert_eq(chief.grid_pos, Vector2i(1, 0))
	field.caster._push_unit(attacker, chief, 1)
	assert_eq(chief.grid_pos, Vector2i(2, 0))
	chief.on_actor_activation_started(attacker)
	field.caster._push_unit(attacker, chief, 2)
	assert_eq(chief.grid_pos, Vector2i(3, 0))
	chief.on_actor_activation_started(attacker)
	field.caster._push_unit(attacker, chief, 3)
	assert_eq(chief.grid_pos, Vector2i(5, 0))


func test_mark_replaces_only_same_centurion_and_expires_after_two_target_activations() -> void:
	var field := Factory.make_battlefield(9, 3)
	var centurion := _unit(CENTURION_PATH)
	var other := _unit(CENTURION_PATH)
	var first := _hero("first")
	var second := _hero("second")
	field.grid.place_unit(centurion, Vector2i(0, 1))
	field.grid.place_unit(other, Vector2i(8, 1))
	field.grid.place_unit(first, Vector2i(3, 1))
	field.grid.place_unit(second, Vector2i(4, 1))
	var mark_spell := _spell(centurion, &"centurion_mark")
	field.caster.cast(centurion, mark_spell, first.grid_pos)
	assert_true(first.has_status(&"centurion_mark", centurion))
	centurion.start_turn()
	centurion.start_turn()
	field.caster.cast(centurion, mark_spell, second.grid_pos)
	assert_false(first.has_status(&"centurion_mark", centurion))
	assert_true(second.has_status(&"centurion_mark", centurion))
	second.start_turn()
	second.tick_statuses()
	assert_true(second.has_status(&"centurion_mark", centurion))
	second.start_turn()
	second.tick_statuses()
	assert_false(second.has_status(&"centurion_mark", centurion))
	var status := load(MARK_STATUS_PATH) as StatusData
	first.apply_status(status, centurion)
	first.apply_status(status, other)
	centurion.take_damage(9999, first)
	assert_false(first.has_status(&"centurion_mark", centurion))
	assert_true(first.has_status(&"centurion_mark", other))


func test_frost_lance_damage_and_next_activation_mp_penalty_refresh_without_stack() -> void:
	var field := Factory.make_battlefield(8, 2)
	var centurion := _unit(CENTURION_PATH)
	var target := _hero("target")
	field.grid.place_unit(centurion, Vector2i(0, 0))
	field.grid.place_unit(target, Vector2i(3, 0))
	var lance := _spell(centurion, &"frost_lance")
	var before := target.current_hp
	field.caster.cast(centurion, lance, target.grid_pos)
	assert_eq(before - target.current_hp, 22)
	assert_eq(target.get_status_remaining(&"frosted_movement"), 1)
	centurion.start_turn()
	field.caster.cast(centurion, lance, target.grid_pos)
	assert_eq(target.get_status_remaining(&"frosted_movement"), 1)
	target.start_turn()
	target.process_statuses()
	assert_eq(target.current_mp, 2)
	target.tick_statuses()
	assert_false(target.has_status(&"frosted_movement"))
	var second_centurion := _unit(CENTURION_PATH)
	var immobile := Unit.new("immobile", 0, 200, 10, 6, 0, 20)
	field.grid.place_unit(second_centurion, Vector2i(0, 1))
	field.grid.place_unit(immobile, Vector2i(3, 1))
	field.caster.cast(second_centurion, _spell(second_centurion, &"frost_lance"), immobile.grid_pos)
	immobile.start_turn()
	immobile.process_statuses()
	assert_eq(immobile.current_mp, 0)


func test_aegis_is_non_stacking_magic_resistance_for_one_full_activation() -> void:
	var field := Factory.make_battlefield(8, 3)
	var centurion := _unit(CENTURION_PATH)
	var skeleton := _unit(NORMAL_PATH)
	var chief := _unit(CHIEF_PATH)
	field.grid.place_unit(centurion, Vector2i(0, 1))
	field.grid.place_unit(skeleton, Vector2i(2, 1))
	field.grid.place_unit(chief, Vector2i(3, 1))
	var aegis := _spell(centurion, &"frost_aegis")
	assert_eq(skeleton.current_shield, 0)
	field.caster.cast(centurion, aegis, skeleton.grid_pos)
	assert_eq(skeleton.resist_magique.get_int(), 50)
	assert_eq(skeleton.current_shield, 0)
	skeleton.apply_status(aegis.applied_status, centurion)
	assert_eq(skeleton.resist_magique.get_int(), 50)
	skeleton.start_turn()
	assert_eq(skeleton.resist_magique.get_int(), 50)
	skeleton.tick_statuses()
	assert_eq(skeleton.resist_magique.get_int(), 0)
	centurion.start_turn()
	centurion.start_turn()
	field.caster.cast(centurion, aegis, chief.grid_pos)
	assert_eq(chief.resist_magique.get_int(), 120)


func test_normal_summon_is_delayed_blockable_and_enters_queue_without_activation() -> void:
	var field := Factory.make_battlefield(10, 5)
	var centurion := _unit(CENTURION_PATH)
	var hero := _hero("hero")
	field.grid.place_unit(centurion, Vector2i(1, 2))
	field.grid.place_unit(hero, Vector2i(9, 2))
	var units := [centurion, hero]
	var queue := TurnQueue.new()
	queue.setup(units)
	var summon := _spell(centurion, &"call_bones")
	centurion.start_turn()
	var cell := Vector2i(3, 2)
	var prepared := field.caster.cast(centurion, summon, cell)
	assert_true(prepared.telegraphed)
	assert_null(field.grid.get_unit(cell))
	centurion.start_turn()
	var result := field.caster.resolve_pending_activation(centurion, units, queue)
	assert_true(result.resolved)
	var summoned := result.summoned_unit as Unit
	assert_not_null(summoned)
	assert_eq(summoned.current_hp, 72)
	assert_eq(summoned.activation_index, 0)
	assert_true(queue.get_full_order().has(summoned))


func test_summon_failure_keeps_cost_use_and_cooldown_and_global_cap() -> void:
	var field := Factory.make_battlefield(12, 5)
	var centurion := _unit(CENTURION_PATH)
	field.grid.place_unit(centurion, Vector2i(1, 2))
	var summon := _spell(centurion, &"call_bones")
	centurion.start_turn()
	var cell := Vector2i(3, 2)
	field.caster.cast(centurion, summon, cell)
	var blocker := _hero("blocker")
	field.grid.place_unit(blocker, cell)
	centurion.start_turn()
	var failed := field.caster.resolve_pending_activation(centurion)
	assert_true(failed.blocked)
	assert_eq(centurion.get_spell_uses(summon), 1)
	assert_gt(centurion.get_spell_cooldown_remaining(summon), 0)
	field.grid.remove_unit(blocker)
	for index in 5:
		var extra := _unit(NORMAL_PATH)
		field.grid.place_unit(extra, Vector2i(5 + index, 1))
	assert_eq(field.grid.count_living_in_team(1), 6)
	centurion.start_turn()
	centurion.start_turn()
	assert_false(field.caster.can_cast(centurion, summon, cell))


func test_summon_death_cancels_pending_and_only_one_can_be_prepared() -> void:
	var field := Factory.make_battlefield(10, 5)
	var centurion := _unit(CENTURION_PATH)
	var hero := _hero("hero", 400)
	field.grid.place_unit(centurion, Vector2i(1, 2))
	field.grid.place_unit(hero, Vector2i(9, 2))
	var call_bones := _spell(centurion, &"call_bones")
	var raise := _spell(centurion, &"raise_chief")
	centurion.current_hp = 75
	centurion.start_turn()
	var summon_cell := Vector2i(3, 2)
	assert_false(field.caster.cast(centurion, call_bones, summon_cell).get("failed", false))
	assert_false(centurion.pending_ability.is_empty())
	centurion.current_ap = centurion.max_ap.get_int()
	assert_false(field.caster.can_cast(centurion, raise, Vector2i(3, 3)))
	centurion.take_damage(9999, hero)
	assert_true(centurion.pending_ability.is_empty())
	assert_null(field.grid.get_unit(summon_cell))


func test_normal_and_chief_summon_combat_use_caps_are_runtime_state() -> void:
	var field := Factory.make_battlefield(12, 6)
	var centurion := _unit(CENTURION_PATH)
	var hero := _hero("hero", 400)
	field.grid.place_unit(centurion, Vector2i(1, 2))
	field.grid.place_unit(hero, Vector2i(10, 2))
	var units := [centurion, hero]
	var queue := TurnQueue.new()
	queue.setup(units)
	var call_bones := _spell(centurion, &"call_bones")
	centurion.start_turn()
	field.caster.cast(centurion, call_bones, Vector2i(3, 2))
	centurion.start_turn()
	assert_true(field.caster.resolve_pending_activation(centurion, units, queue).resolved)
	centurion.start_turn()
	centurion.start_turn()
	field.caster.cast(centurion, call_bones, Vector2i(3, 3))
	centurion.start_turn()
	assert_true(field.caster.resolve_pending_activation(centurion, units, queue).resolved)
	assert_eq(centurion.get_spell_uses(call_bones), 2)
	centurion.start_turn()
	centurion.start_turn()
	assert_false(centurion.can_use_spell(call_bones))

	var raise_centurion := _unit(CENTURION_PATH)
	var raise_field := Factory.make_battlefield(10, 5)
	raise_field.grid.place_unit(raise_centurion, Vector2i(1, 2))
	raise_centurion.current_hp = 75
	var raise := _spell(raise_centurion, &"raise_chief")
	raise_centurion.start_turn()
	raise_field.caster.cast(raise_centurion, raise, Vector2i(3, 2))
	raise_centurion.start_turn()
	var raised := raise_field.caster.resolve_pending_activation(raise_centurion)
	assert_true(raised.resolved)
	assert_eq(raise_centurion.get_spell_uses(raise), 1)
	(raised.summoned_unit as Unit).take_damage(9999, raise_centurion)
	raise_centurion.start_turn()
	assert_false(raise_centurion.can_use_spell(raise))


func test_raised_chief_has_154_hp_and_sentence_blocked_first_activation() -> void:
	var field := Factory.make_battlefield(10, 5)
	var centurion := _unit(CENTURION_PATH)
	var hero := _hero("hero")
	field.grid.place_unit(centurion, Vector2i(1, 2))
	field.grid.place_unit(hero, Vector2i(9, 2))
	centurion.current_hp = 75
	var raise := _spell(centurion, &"raise_chief")
	centurion.start_turn()
	field.caster.cast(centurion, raise, Vector2i(3, 2))
	centurion.start_turn()
	var result := field.caster.resolve_pending_activation(centurion)
	assert_true(result.resolved)
	var chief := result.summoned_unit as Unit
	assert_eq(chief.current_hp, 154)
	var sentence := _spell(chief, &"scarlet_sentence")
	chief.start_turn()
	assert_false(chief.can_use_spell(sentence))
	chief.start_turn()
	assert_true(chief.can_use_spell(sentence))


func test_tactical_ai_is_deterministic_and_prioritizes_mark_and_lethal() -> void:
	var field := Factory.make_battlefield(9, 5)
	var centurion := _unit(CENTURION_PATH)
	var skeleton := _unit(NORMAL_PATH)
	var weak := _hero("a_weak", 18)
	var marked := _hero("b_marked", 200)
	field.grid.place_unit(centurion, Vector2i(0, 2))
	field.grid.place_unit(skeleton, Vector2i(3, 2))
	field.grid.place_unit(weak, Vector2i(4, 2))
	field.grid.place_unit(marked, Vector2i(3, 3))
	marked.apply_status(load(MARK_STATUS_PATH) as StatusData, centurion)
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	var first := ai.decide(skeleton, [centurion, skeleton, weak, marked])
	var second := ai.decide(skeleton, [marked, weak, skeleton, centurion])
	assert_eq(first[0].type, "cast")
	assert_eq(first[0].cell, weak.grid_pos)
	assert_eq(second[0].cell, weak.grid_pos)


func test_centurion_mark_scoring_and_safe_reposition_are_reproducible() -> void:
	var field := Factory.make_battlefield(12, 7)
	var centurion := _unit(CENTURION_PATH)
	var normal_a := _unit(NORMAL_PATH)
	var normal_b := _unit(NORMAL_PATH)
	var hero_a := _hero("hero_a")
	var hero_b := _hero("hero_b")
	field.grid.place_unit(centurion, Vector2i(2, 3))
	field.grid.place_unit(normal_a, Vector2i(3, 2))
	field.grid.place_unit(normal_b, Vector2i(3, 4))
	field.grid.place_unit(hero_a, Vector2i(6, 3))
	field.grid.place_unit(hero_b, Vector2i(8, 3))
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	var plan := ai.decide(centurion, [hero_b, normal_b, centurion, hero_a, normal_a])
	# Les invocations sont prioritaires quand il reste moins de deux normaux ; ici
	# les deux sont presents, la marque doit donc viser le score de chemin minimal.
	assert_eq(plan[0].type, "cast")
	assert_eq(plan[0].spell.get_effective_spell_id(), &"centurion_mark")
	assert_eq(plan[0].cell, hero_a.grid_pos)
	var repeat := ai.decide(centurion, [normal_a, hero_a, centurion, hero_b, normal_b])
	assert_eq(repeat[0].cell, plan[0].cell)


func test_tactical_ai_formation_and_commander_protection_break_movement_ties() -> void:
	var formation_field := Factory.make_battlefield(7, 6)
	var skeleton := _unit(NORMAL_PATH)
	var target := _hero("target")
	var neighbor := _hero("neighbor")
	formation_field.grid.place_unit(skeleton, Vector2i(1, 2))
	formation_field.grid.place_unit(target, Vector2i(5, 2))
	formation_field.grid.place_unit(neighbor, Vector2i(2, 4))
	formation_field.grid.set_type(Vector2i(2, 2), GridData.CellType.WALL)
	skeleton.current_mp = 2
	var formation_ai := EnemyAI.new(
		formation_field.grid,
		formation_field.pathfinder,
		formation_field.caster
	)
	var formation_plan := formation_ai.decide(skeleton, [target, neighbor, skeleton])
	assert_eq(formation_plan[0].type, "move")
	assert_eq(formation_plan[0].path[-1], Vector2i(2, 3))

	var guard_field := Factory.make_battlefield(7, 6)
	var chief := _unit(CHIEF_PATH)
	var commander := _unit(CENTURION_PATH)
	var guard_target := _hero("guard_target")
	guard_field.grid.place_unit(chief, Vector2i(1, 2))
	guard_field.grid.place_unit(commander, Vector2i(1, 4))
	guard_field.grid.place_unit(guard_target, Vector2i(5, 2))
	guard_field.grid.set_type(Vector2i(2, 2), GridData.CellType.WALL)
	chief.current_mp = 2
	var guard_ai := EnemyAI.new(guard_field.grid, guard_field.pathfinder, guard_field.caster)
	var guard_plan := guard_ai.decide(chief, [guard_target, chief, commander])
	assert_eq(guard_plan[0].type, "move")
	assert_eq(guard_plan[0].path[-1], Vector2i(2, 3))


func test_centurion_repositions_out_of_adjacency_and_respects_enemy_cap() -> void:
	var field := Factory.make_battlefield(10, 7)
	var centurion := _unit(CENTURION_PATH)
	var hero := _hero("hero")
	field.grid.place_unit(centurion, Vector2i(3, 3))
	field.grid.place_unit(hero, Vector2i(4, 3))
	centurion.current_ap = 0
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	var safe_plan := ai.decide(centurion, [hero, centurion])
	assert_eq(safe_plan[0].type, "move")
	var destination: Vector2i = safe_plan[0].path[-1]
	assert_gte(field.grid.manhattan(destination, hero.grid_pos), 4)

	for index in 5:
		var normal := _unit(NORMAL_PATH)
		field.grid.place_unit(normal, Vector2i(index, 6))
	centurion.start_turn()
	var capped_plan := ai.decide(centurion, field.grid.get_units())
	assert_false(capped_plan.is_empty())
	if capped_plan[0].type == "cast":
		assert_ne(capped_plan[0].spell.get_effective_spell_id(), &"call_bones")


func test_telegraph_layer_tracks_prepare_and_resolution_lifecycle() -> void:
	var field := Factory.make_battlefield(5, 2)
	var chief := _unit(CHIEF_PATH)
	var target := _hero("target")
	field.grid.place_unit(chief, Vector2i(1, 0))
	field.grid.place_unit(target, Vector2i(2, 0))
	var grid_view := Node2D.new()
	add_child_autofree(grid_view)
	var layer := TacticalTelegraphLayer.new()
	grid_view.add_child(layer)
	layer.setup(grid_view)
	chief.start_turn()
	field.caster.cast(chief, _spell(chief, &"scarlet_sentence"), target.grid_pos)
	assert_eq(layer.get_telegraph_count(), 1)
	chief.start_turn()
	field.caster.resolve_pending_activation(chief)
	assert_eq(layer.get_telegraph_count(), 0)
