extends GutTest

const Evolution = preload("res://core/expedition/catabase_monster_evolution_catalog.gd")
const Factory = preload("res://test/support/factory.gd")
const Cleanup = preload("res://test/support/isolated_battlefield_cleanup.gd")
var _grids: Array[GridData] = []
var _sources: Array[UnitData] = []


func before_all() -> void:
	for path: String in Evolution.FAMILY_PATHS.values():
		_sources.append(load(path) as UnitData)


func after_all() -> void:
	_sources.clear()


func after_each() -> void:
	for grid: GridData in _grids:
		for unit: Unit in grid.get_units():
			unit.clear_shield()
			unit.clear_combat_effect_history()
		Cleanup.dispose_grid(grid)
	_grids.clear()


func test_grade_boundaries_and_early_brute_keep_the_teaching_budget() -> void:
	for entry: Array in [[2, 1], [5, 1], [6, 2], [12, 2], [13, 3], [18, 3]]:
		assert_eq(Evolution.grade_for({"depth": entry[0]}), entry[1])
	var brute := Evolution.build_unit(&"brute", {"depth": 2})
	assert_eq(brute.max_mp, 2)
	assert_eq(brute.spells.size(), 1)
	assert_eq(brute.spells[0].ap_cost, brute.max_ap)
	assert_eq(brute.spells[0].spell_range, 1)
	assert_eq(brute.spells[0].pull_distance, 0)


func test_every_role_has_usable_bounded_spells_and_a_presentation() -> void:
	for depth: int in [2, 6, 13, 18]:
		for role: StringName in Evolution.roles():
			var data := Evolution.build_unit(role, {"depth": depth})
			assert_not_null(data, str(role))
			assert_gt(data.max_hp, 0)
			assert_not_null(data.visual_scene)
			assert_false(data.presentation_summary.is_empty())
			assert_eq(data.active_spell_slots, data.spells.size())
			var ids := {}
			for spell: Spell in data.spells:
				assert_lte(spell.ap_cost, data.max_ap, str(role))
				assert_gt(spell.ap_cost, 0)
				assert_lte(spell.minimum_range, spell.spell_range)
				assert_false(ids.has(spell.get_effective_spell_id()), "Availability IDs are distinct inside each kit")
				ids[spell.get_effective_spell_id()] = true
				assert_true(spell.once_per_activation)
				if spell.applied_status != null:
					assert_false(spell.applied_status.skips_turn, "No enemy kit removes a whole turn")
				if spell.is_healing():
					assert_gt(spell.max_uses_per_combat, 0)
					assert_lte(spell.max_uses_per_combat, 3)
					assert_gte(spell.cooldown_activations, 2)


func test_advanced_brute_can_pull_and_strike_or_make_two_melee_attacks() -> void:
	var brute := Evolution.build_unit(&"rabatteur", {"depth": 13})
	assert_eq(brute.max_mp, 4)
	assert_eq(brute.max_ap, 6)
	var pull := _find_spell(brute, &"catabase_evolution_chaine")
	var fracture := _find_spell(brute, &"catabase_evolution_fracture")
	var revers := _find_spell(brute, &"catabase_evolution_revers")
	assert_lte(pull.ap_cost + fracture.ap_cost, brute.max_ap)
	assert_eq(fracture.ap_cost + revers.ap_cost, brute.max_ap)
	assert_gt(pull.cooldown_activations, 1)
	assert_true(pull.needs_line_of_sight)
	var guard := Evolution.build_unit(&"porte_egide", {"depth": 13})
	assert_null(_find_spell(guard, &"catabase_evolution_chaine"))
	assert_lt(guard.max_mp, brute.max_mp)
	assert_not_null(_find_spell(guard, &"catabase_evolution_egide"))


func test_spell_and_status_copies_cannot_mutate_another_room_or_template() -> void:
	var first := Evolution.build_unit(&"fondeur", {"depth": 13})
	var second := Evolution.build_unit(&"fondeur", {"depth": 13})
	first.spells[0].damage_scaling.prowess_coefficient = 999.0
	first.spells[1].applied_status.damage_per_turn = 999
	first.spells[2].terrain_effect.damage = 999
	first.ai_profile.ideal_minimum_range = 99
	first.resistances[1] = 99.0
	assert_ne(second.spells[0].damage_scaling.prowess_coefficient, 999.0)
	assert_ne(second.spells[1].applied_status.damage_per_turn, 999)
	assert_ne(second.spells[2].terrain_effect.damage, 999)
	assert_ne(second.ai_profile.ideal_minimum_range, 99)
	assert_ne(second.resistances.get(1), 99.0)
	var source := load("res://data/spells/catabase_monsters/braise_trait.tres") as Spell
	assert_ne(source.damage_scaling.prowess_coefficient, 999.0)


func test_factory_secondary_scaling_changes_effect_strength_but_not_control_duration() -> void:
	var healer := Evolution.build_unit(&"guerisseur", {"depth": 13})
	var heal := _find_spell(healer, &"catabase_evolution_soin")
	var base_heal := heal.heal
	Evolution.scale_secondary_effects(healer, 2.0, 3.0)
	assert_eq(heal.heal, base_heal * 2)
	assert_eq(heal.max_uses_per_combat, 3)
	var lamie := Evolution.build_unit(&"tisseuse", {"depth": 13})
	Evolution.scale_secondary_effects(lamie, 2.0, 3.0)
	var field := _find_spell(lamie, &"catabase_evolution_givre").terrain_effect
	assert_eq(field.applied_status.mp_reduction, 1)
	assert_eq(field.applied_status.duration, 1)
	assert_eq(field.duration, 2)
	var dog := Evolution.build_unit(&"deplaceur", {"depth": 13})
	Evolution.scale_secondary_effects(dog, 2.0, 3.0)
	assert_eq(dog.spells[0].bonus_damage_if_marked, 9)


func test_ward_protects_real_allies_and_not_the_opposing_team() -> void:
	var field := Factory.make_battlefield(7, 7)
	_grids.append(field.grid)
	var guard := Unit.from_data(Evolution.build_unit(&"porte_egide", {"depth": 13}))
	var ally := Factory.make_unit("Allié", 1)
	var hero := Factory.make_unit("Héros", 0)
	field.grid.place_unit(guard, Vector2i(3, 3))
	field.grid.place_unit(ally, Vector2i(3, 4))
	field.grid.place_unit(hero, Vector2i(4, 3))
	guard.start_turn()
	var ward := guard.spells[1] as Spell
	assert_eq(field.caster.get_cast_failure_reason(guard, ward, guard.grid_pos), &"")
	field.caster.cast(guard, ward, guard.grid_pos)
	assert_gt(guard.current_shield, 0)
	assert_gt(ally.current_shield, 0)
	assert_eq(hero.current_shield, 0)


func test_collecteur_has_a_finite_porter_dependency() -> void:
	var collector := Evolution.build_unit(&"collecteur", {"depth": 18})
	var heal := _find_spell(collector, &"catabase_evolution_soin")
	assert_eq(heal.get_meta("catabase_requires_role_nearby"), &"catabase_evolution_porteur")
	assert_eq(heal.get_meta("catabase_support_radius"), 2)
	assert_eq(heal.max_uses_per_combat, 3)
	var porter := Evolution.build_unit(&"porteur", {"depth": 18})
	assert_lte(porter.max_hp, collector.max_hp / 2)
	assert_eq(_find_spell(porter, &"catabase_evolution_tribut").max_uses_per_combat, 1)


func test_conductor_mark_increases_real_bite_damage_and_dies_with_its_source() -> void:
	var field := Factory.make_battlefield(8, 3)
	_grids.append(field.grid)
	var conductor := Unit.from_data(Evolution.build_unit(&"conducteur", {"depth": 6}))
	var dog := Unit.from_data(Evolution.build_unit(&"deplaceur", {"depth": 13}))
	var hero := Factory.make_unit("Héros", 0)
	field.grid.place_unit(conductor, Vector2i(1, 1))
	field.grid.place_unit(dog, Vector2i(3, 1))
	field.grid.place_unit(hero, Vector2i(4, 1))
	conductor.start_turn()
	conductor.start_turn()
	dog.start_turn()
	var mark := conductor.spells[1] as Spell
	assert_eq(field.caster.get_cast_failure_reason(conductor, mark, hero.grid_pos), &"")
	field.caster.cast(conductor, mark, hero.grid_pos)
	var bite := dog.spells[0] as Spell
	var marked_hit: Dictionary = field.caster.cast(dog, bite, hero.grid_pos)
	assert_eq(marked_hit.hp_damage_total, bite.get_scaled_damage(dog) + bite.bonus_damage_if_marked)
	conductor.take_damage(9999, hero)
	dog.start_turn()
	var unmarked_hit: Dictionary = field.caster.cast(dog, bite, hero.grid_pos)
	assert_eq(unmarked_hit.hp_damage_total, bite.get_scaled_damage(dog), "Killing the conductor removes its synergy")


func test_champion_and_midrun_elite_have_their_advertised_actions() -> void:
	var champion := Evolution.build_unit(&"champion", {"depth": 16})
	assert_eq(champion.max_ap, 6)
	assert_eq(champion.max_mp, 4)
	assert_eq(champion.spells.size(), 4)
	assert_eq(champion.max_hp, 150)
	assert_eq(champion.attack_power, 24)
	var ward := _find_spell(champion, &"catabase_evolution_egide_champion")
	assert_true(ward.is_self_only())
	assert_not_null(_find_spell(Evolution.build_unit(&"rabatteur", {"depth": 10}), &"catabase_evolution_chaine"))
	assert_not_null(_find_spell(Evolution.build_unit(&"executeur", {"depth": 10}), &"catabase_evolution_execution"))


func _find_spell(data: UnitData, id: StringName) -> Spell:
	for spell: Spell in data.spells:
		if spell.get_effective_spell_id() == id:
			return spell
	return null
