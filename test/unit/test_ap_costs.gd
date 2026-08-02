extends GutTest

const Factory = preload("res://test/support/factory.gd")

func _setup_duel() -> Dictionary:
	var battlefield := Factory.make_battlefield(8, 3)
	var hero := Factory.make_unit("Heros", 0)
	var enemy := Factory.make_unit("Ennemi", 1)
	battlefield.grid.place_unit(hero, Vector2i(0, 0))
	battlefield.grid.place_unit(enemy, Vector2i(1, 0))
	return {"battlefield": battlefield, "hero": hero}

func test_spend_ap_decrements_and_refuses_overdraft() -> void:
	var unit := Factory.make_unit()
	assert_eq(unit.current_ap, 6)
	assert_true(unit.spend_ap(2))
	assert_eq(unit.current_ap, 4)
	assert_false(unit.spend_ap(5))
	assert_eq(unit.current_ap, 4)

func test_affordability_depends_only_on_ap() -> void:
	var unit := Factory.make_unit()
	var spell := Factory.make_spell({"ap_cost": 4})
	unit.current_ap = 3
	assert_false(unit.can_afford_spell_resources(spell))
	unit.current_ap = 4
	assert_true(unit.can_afford_spell_resources(spell))

func test_failed_cast_spends_no_ap() -> void:
	var duel := _setup_duel()
	var hero: Unit = duel["hero"]
	hero.current_ap = 2
	var spell := Factory.make_spell({"ap_cost": 4, "damage": 5, "spell_range": 3})
	var report: Dictionary = duel["battlefield"].caster.cast(hero, spell, Vector2i(1, 0))
	assert_true(report.get("failed", false))
	assert_eq(report.get("reason", ""), "pa")
	assert_eq(hero.current_ap, 2)

func test_successful_cast_spends_ap() -> void:
	var duel := _setup_duel()
	var hero: Unit = duel["hero"]
	var spell := Factory.make_spell({"ap_cost": 4, "damage": 5, "spell_range": 3})
	var report: Dictionary = duel["battlefield"].caster.cast(hero, spell, Vector2i(1, 0))
	assert_false(report.get("failed", false))
	assert_eq(hero.current_ap, 2)
