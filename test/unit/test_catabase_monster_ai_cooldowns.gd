extends GutTest

const Factory := preload("res://test/support/factory.gd")
const Cleanup := preload("res://test/support/isolated_battlefield_cleanup.gd")
const IDS := ["sentinelle_airain", "rejeton_braise", "molosse_styx", "lamie_lethe"]
var _fixture_grids: Array[GridData] = []


func after_each() -> void:
	for grid in _fixture_grids:
		Cleanup.dispose_grid(grid)
	_fixture_grids.clear()


func test_all_monsters_use_primary_while_special_is_initially_or_temporarily_unavailable() -> void:
	for id: String in IDS:
		var field := Factory.make_battlefield(10, 3)
		_fixture_grids.append(field.grid)
		var data := load("res://data/units/enemies/catabase_%s.tres" % id) as UnitData
		var enemy := Unit.from_data(data)
		var hero := Factory.make_unit("Héros", 0)
		field.grid.place_unit(enemy, Vector2i(2, 1))
		field.grid.place_unit(hero, Vector2i(3 if data.combat_style == 0 else 5, 1))
		var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
		var primary := enemy.spells[0] as Spell
		var special := enemy.spells[1] as Spell
		enemy.start_turn()
		assert_false(enemy.can_use_spell(special), id + " has an introductory cooldown")
		_assert_chosen_spell(ai, enemy, hero, primary)
		enemy.start_turn()
		assert_true(enemy.can_use_spell(special))
		_assert_chosen_spell(ai, enemy, hero, special)
		enemy.mark_spell_used(special)
		enemy.start_turn()
		assert_false(enemy.can_use_spell(special))
		_assert_chosen_spell(ai, enemy, hero, primary)


func test_generic_ai_does_not_plan_already_used_or_wrong_form_spell() -> void:
	var field := Factory.make_battlefield(5, 1)
	_fixture_grids.append(field.grid)
	var enemy := Factory.make_unit("Ennemi", 1)
	var hero := Factory.make_unit("Héros", 0)
	field.grid.place_unit(enemy, Vector2i(1, 0))
	field.grid.place_unit(hero, Vector2i(2, 0))
	var primary := Factory.make_spell({"spell_id": &"available", "damage": 5})
	var exhausted := Factory.make_spell({"spell_id": &"already_used", "damage": 100, "once_per_activation": true})
	var wrong_form := Factory.make_spell({"spell_id": &"other_form", "damage": 200, "required_combat_form": &"infernal"})
	for spell: Spell in [primary, exhausted, wrong_form]:
		enemy.add_spell(spell)
	enemy.start_turn()
	enemy.mark_spell_used(exhausted)
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	_assert_chosen_spell(ai, enemy, hero, primary)


func _assert_chosen_spell(ai: EnemyAI, enemy: Unit, hero: Unit, expected: Spell) -> void:
	var plan := ai.decide(enemy, [enemy, hero])
	assert_gt(plan.size(), 0, enemy.unit_name)
	if plan.is_empty():
		return
	assert_eq(plan[0].get("type"), "cast")
	assert_same(plan[0].get("spell"), expected, enemy.unit_name + " must select a usable spell")
	assert_eq(ai.get_spell_caster().get_cast_failure_reason(enemy, expected, hero.grid_pos), &"")
