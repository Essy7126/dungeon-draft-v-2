# Couts en PA : un sort est refuse si current_ap < ap_cost, la depense
# decremente correctement, et un sort payoff (fervor_cost > 0) exige
# AUSSI current_energy >= fervor_cost.
extends GutTest

const Factory = preload("res://test/support/factory.gd")

# Champ minimal : heros en (0,0), ennemi en (1,0).
func _setup_duel() -> Dictionary:
	var bf := Factory.make_battlefield(8, 3)
	var hero := Factory.make_unit("Heros", 0)
	var enemy := Factory.make_unit("Ennemi", 1)
	bf.grid.place_unit(hero, Vector2i(0, 0))
	bf.grid.place_unit(enemy, Vector2i(1, 0))
	return { "bf": bf, "hero": hero, "enemy": enemy }

func test_spend_ap_decremente_et_refuse_le_decouvert() -> void:
	var unit := Factory.make_unit()
	assert_eq(unit.current_ap, 6, "PA de depart = max_ap = 6")
	assert_true(unit.spend_ap(2))
	assert_eq(unit.current_ap, 4)
	assert_false(unit.spend_ap(5), "5 PA demandes, 4 disponibles : refus")
	assert_eq(unit.current_ap, 4, "un refus ne doit rien depenser")

func test_can_afford_refuse_si_pa_insuffisants() -> void:
	var unit := Factory.make_unit()
	unit.energy_type = Factory.make_energy()
	var spell := Factory.make_spell({ "ap_cost": 4 })
	unit.current_ap = 3
	assert_false(unit.can_afford_spell_resources(spell), "3 PA < cout 4 : refus")
	unit.current_ap = 4
	assert_true(unit.can_afford_spell_resources(spell), "4 PA >= cout 4 : accepte")

func test_cast_refuse_sans_pa_et_ne_depense_rien() -> void:
	var duel := _setup_duel()
	var hero: Unit = duel["hero"]
	hero.energy_type = Factory.make_energy()
	hero.current_energy = 50.0
	hero.current_ap = 2
	var spell := Factory.make_spell({ "ap_cost": 4, "damage": 5, "spell_range": 3 })
	var report: Dictionary = duel["bf"].caster.cast(hero, spell, Vector2i(1, 0))
	assert_true(report.get("failed", false), "le cast doit echouer")
	assert_eq(report.get("reason", ""), "pa")
	assert_eq(hero.current_ap, 2, "aucun PA depense sur un refus")
	assert_almost_eq(hero.current_energy, 50.0, 0.0001, "aucune Ferveur depensee sur un refus")

func test_cast_reussi_decremente_les_pa() -> void:
	var duel := _setup_duel()
	var hero: Unit = duel["hero"]
	var spell := Factory.make_spell({ "ap_cost": 4, "damage": 5, "spell_range": 3 })
	var report: Dictionary = duel["bf"].caster.cast(hero, spell, Vector2i(1, 0))
	assert_false(report.get("failed", false), "le cast doit reussir")
	assert_eq(hero.current_ap, 2, "6 PA - 4 = 2")

func test_payoff_exige_aussi_la_ferveur() -> void:
	var duel := _setup_duel()
	var hero: Unit = duel["hero"]
	hero.energy_type = Factory.make_energy()
	var payoff := Factory.make_spell({ "ap_cost": 1, "fervor_cost": 30.0, "damage": 5, "spell_range": 3 })
	# PA largement suffisants, mais 20 de Ferveur < 30 : refus.
	hero.current_energy = 20.0
	assert_false(hero.can_afford_spell_resources(payoff), "PA ok mais Ferveur insuffisante")
	var report: Dictionary = duel["bf"].caster.cast(hero, payoff, Vector2i(1, 0))
	assert_true(report.get("failed", false))
	assert_eq(report.get("reason", ""), "fervor")
	assert_eq(hero.current_ap, 6, "les PA ne doivent pas etre debites si la Ferveur manque")

func test_payoff_depense_pa_et_ferveur() -> void:
	var duel := _setup_duel()
	var hero: Unit = duel["hero"]
	hero.energy_type = Factory.make_energy()
	hero.current_energy = 40.0
	var payoff := Factory.make_spell({ "ap_cost": 2, "fervor_cost": 30.0, "damage": 5, "spell_range": 3 })
	assert_true(hero.can_afford_spell_resources(payoff))
	var report: Dictionary = duel["bf"].caster.cast(hero, payoff, Vector2i(1, 0))
	assert_false(report.get("failed", false))
	assert_eq(hero.current_ap, 4, "6 PA - 2 = 4")
	assert_almost_eq(hero.current_energy, 10.0, 0.0001, "40 Ferveur - 30 = 10")

func test_payoff_impossible_sans_type_energie() -> void:
	# Une unite sans ecole (energy_type null) ne peut jamais payer un payoff.
	var unit := Factory.make_unit()
	var payoff := Factory.make_spell({ "ap_cost": 1, "fervor_cost": 10.0 })
	assert_false(unit.can_afford_spell_resources(payoff))
	# Mais un sort normal (fervor_cost 0) reste jouable.
	var normal := Factory.make_spell({ "ap_cost": 1 })
	assert_true(unit.can_afford_spell_resources(normal))
