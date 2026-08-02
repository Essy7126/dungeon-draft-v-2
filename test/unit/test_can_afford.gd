extends GutTest

const Factory = preload("res://test/support/factory.gd")

func test_planning_checks_ap() -> void:
	var battlefield := Factory.make_battlefield(4, 1)
	var unit := Factory.make_unit()
	var spell := Factory.make_spell({"ap_cost": 4})
	unit.current_ap = 3
	assert_false(battlefield.caster.can_afford(unit, spell))
	unit.current_ap = 4
	assert_true(battlefield.caster.can_afford(unit, spell))

func test_planning_and_cast_agree() -> void:
	var battlefield := Factory.make_battlefield(4, 1)
	var hero := Factory.make_unit("Heros", 0)
	var enemy := Factory.make_unit("Ennemi", 1)
	battlefield.grid.place_unit(hero, Vector2i(0, 0))
	battlefield.grid.place_unit(enemy, Vector2i(1, 0))
	var spell := Factory.make_spell({"ap_cost": 4, "damage": 5, "spell_range": 3})
	hero.current_ap = 3
	assert_false(battlefield.caster.can_afford(hero, spell))
	assert_true(battlefield.caster.cast(hero, spell, Vector2i(1, 0)).get("failed", false))
	hero.current_ap = 4
	assert_true(battlefield.caster.can_afford(hero, spell))
	assert_false(battlefield.caster.cast(hero, spell, Vector2i(1, 0)).get("failed", false))
