# SpellCaster.can_afford : la planification (IA) doit donner EXACTEMENT la
# meme reponse que le garde-fou de cast(). En particulier, une unite SANS
# energy_type reste soumise a la verification des PA.
extends GutTest

const Factory = preload("res://test/support/factory.gd")

func test_sans_energie_les_pa_restent_verifies() -> void:
	var bf := Factory.make_battlefield(4, 1)
	var unit := Factory.make_unit() # aucun energy_type
	var spell := Factory.make_spell({ "ap_cost": 4 })
	unit.current_ap = 3
	assert_false(bf.caster.can_afford(unit, spell), "3 PA < cout 4 : refuse, meme sans ecole")
	unit.current_ap = 4
	assert_true(bf.caster.can_afford(unit, spell), "4 PA >= cout 4 : accepte")

func test_can_afford_donne_la_meme_reponse_que_cast() -> void:
	var bf := Factory.make_battlefield(4, 1)
	var hero := Factory.make_unit("Heros", 0)
	var enemy := Factory.make_unit("Ennemi", 1)
	bf.grid.place_unit(hero, Vector2i(0, 0))
	bf.grid.place_unit(enemy, Vector2i(1, 0))
	var spell := Factory.make_spell({ "ap_cost": 4, "damage": 5, "spell_range": 3 })
	# Refus planifie = refus execute.
	hero.current_ap = 3
	assert_false(bf.caster.can_afford(hero, spell))
	assert_true(bf.caster.cast(hero, spell, Vector2i(1, 0)).get("failed", false))
	# Accord planifie = execution acceptee.
	hero.current_ap = 4
	assert_true(bf.caster.can_afford(hero, spell))
	assert_false(bf.caster.cast(hero, spell, Vector2i(1, 0)).get("failed", false))

func test_payoff_sans_ecole_refuse_partout() -> void:
	var bf := Factory.make_battlefield(4, 1)
	var hero := Factory.make_unit("Heros", 0)
	var enemy := Factory.make_unit("Ennemi", 1)
	bf.grid.place_unit(hero, Vector2i(0, 0))
	bf.grid.place_unit(enemy, Vector2i(1, 0))
	var payoff := Factory.make_spell({ "ap_cost": 1, "fervor_cost": 10.0, "damage": 5, "spell_range": 3 })
	assert_false(bf.caster.can_afford(hero, payoff), "payoff sans energy_type : refuse a la planification")
	assert_true(bf.caster.cast(hero, payoff, Vector2i(1, 0)).get("failed", false), "et refuse a l'execution")
