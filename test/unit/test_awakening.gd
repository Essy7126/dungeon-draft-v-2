# Seuil d'eveil : atteindre awakening_cost rend l'Eveil activable ;
# l'activation depense la jauge et pose l'etat ; la duree expire au bon tour.
#
# NOTE DE CONSTAT : dans le code reel, franchir awakening_cost ne declenche
# PAS l'Eveil automatiquement — il devient ACTIVABLE (can_activate_awakening)
# et c'est activate_awakening() qui depense le cout et pose l'etat. Les tests
# ci-dessous verifient ce comportement reel.
extends GutTest

const Factory = preload("res://test/support/factory.gd")

func _unit_with_awakening(cost := 50.0, duration := 2) -> Unit:
	var unit := Factory.make_unit()
	unit.energy_type = Factory.make_energy({}, {
		"awakening_cost": cost,
		"awakening_duration_turns": duration,
	})
	return unit

func test_sous_le_seuil_non_activable() -> void:
	var unit := _unit_with_awakening()
	unit.current_energy = 49.9
	assert_false(unit.can_activate_awakening(), "49.9 < 50 : pas activable")
	assert_false(unit.activate_awakening(), "l'activation doit etre refusee")
	assert_false(unit.charge_threshold_active)
	assert_almost_eq(unit.current_energy, 49.9, 0.0001, "un refus ne depense rien")

func test_franchir_le_seuil_rend_activable_sans_auto_declencher() -> void:
	var unit := _unit_with_awakening()
	unit.generate_energy(60.0)
	assert_false(unit.charge_threshold_active, "gagner de l'energie ne declenche pas l'Eveil tout seul")
	assert_true(unit.can_activate_awakening(), "au-dela du cout, l'Eveil devient activable")

func test_activation_depense_le_cout_et_pose_l_etat() -> void:
	var unit := _unit_with_awakening(50.0, 2)
	unit.current_energy = 60.0
	assert_true(unit.activate_awakening())
	assert_true(unit.charge_threshold_active, "l'etat d'eveil doit etre actif")
	assert_almost_eq(unit.current_energy, 10.0, 0.0001, "60 - cout 50 = 10")
	assert_eq(unit.awakening_turns_remaining, 2)
	assert_false(unit.can_activate_awakening(), "pas de re-activation pendant l'Eveil")

func test_la_duree_expire_correctement() -> void:
	var unit := _unit_with_awakening(50.0, 2)
	unit.current_energy = 50.0
	unit.activate_awakening()
	# tick_statuses est appele en fin de tour de l'unite : 2 tours de duree.
	unit.tick_statuses()
	assert_true(unit.charge_threshold_active, "encore actif apres 1 tour sur 2")
	assert_eq(unit.awakening_turns_remaining, 1)
	unit.tick_statuses()
	assert_false(unit.charge_threshold_active, "expire apres 2 tours")
	assert_eq(unit.awakening_turns_remaining, 0)

func test_duree_minimale_d_un_tour() -> void:
	# Une duree configuree a 0 est remontee a 1 tour (maxi(1, ...)).
	var unit := _unit_with_awakening(50.0, 0)
	unit.current_energy = 50.0
	unit.activate_awakening()
	assert_eq(unit.awakening_turns_remaining, 1)
	unit.tick_statuses()
	assert_false(unit.charge_threshold_active)

func test_effets_de_l_eveil_sur_les_payoffs() -> void:
	# Pendant l'Eveil, les multiplicateurs d'ecole s'appliquent aux sorts.
	var unit := Factory.make_unit()
	unit.energy_type = Factory.make_energy({}, {
		"awakening_cost": 50.0,
		"awakening_duration_turns": 2,
		"awakening_damage_multiplier": 1.5,
	})
	var spell := Factory.make_spell({ "damage": 10 })
	assert_eq(unit.get_modified_spell_damage(spell, 10), 10, "hors Eveil : degats inchanges")
	unit.current_energy = 50.0
	unit.activate_awakening()
	assert_eq(unit.get_modified_spell_damage(spell, 10), 15, "en Eveil : 10 x 1.5 = 15")
