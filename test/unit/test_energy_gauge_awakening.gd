# EnergyGauge isolee : seuil d'eveil (activation, depense, duree, expiration)
# et reset combat (retour a start_energy, eveil purge).
extends GutTest

const Factory = preload("res://test/support/factory.gd")

# La jauge tient son porteur en weakref : on le garde vivant le temps du test.
var _owner_unit: Unit = null

func before_each() -> void:
	_owner_unit = Factory.make_unit()

func _make_gauge(cost := 50.0, duration := 2, start := 0.0) -> EnergyGauge:
	var gauge := EnergyGauge.new(_owner_unit)
	gauge.energy_type = Factory.make_energy({}, {
		"awakening_cost": cost,
		"awakening_duration_turns": duration,
		"start_energy": start,
	})
	return gauge

func test_activable_seulement_au_cout_atteint() -> void:
	var gauge := _make_gauge()
	gauge.current_energy = 49.9
	assert_false(gauge.can_activate_awakening())
	assert_false(gauge.activate_awakening())
	gauge.current_energy = 50.0
	assert_true(gauge.can_activate_awakening())

func test_activation_depense_et_pose_l_etat() -> void:
	var gauge := _make_gauge(50.0, 2)
	gauge.current_energy = 60.0
	assert_true(gauge.activate_awakening())
	assert_true(gauge.charge_threshold_active)
	assert_almost_eq(gauge.current_energy, 10.0, 0.0001, "60 - cout 50 = 10")
	assert_eq(gauge.awakening_turns_remaining, 2)
	assert_false(gauge.can_activate_awakening(), "pas de re-activation pendant l'eveil")

func test_la_duree_expire_et_emet_awakening_expired() -> void:
	var gauge := _make_gauge(50.0, 2)
	gauge.current_energy = 50.0
	gauge.activate_awakening()
	watch_signals(gauge)
	gauge.tick_awakening()
	assert_true(gauge.charge_threshold_active, "encore actif apres 1 tour sur 2")
	assert_signal_not_emitted(gauge, "awakening_expired")
	gauge.tick_awakening()
	assert_false(gauge.charge_threshold_active, "expire apres 2 tours")
	assert_eq(gauge.awakening_turns_remaining, 0)
	assert_signal_emitted(gauge, "awakening_expired")

func test_duree_minimale_d_un_tour() -> void:
	var gauge := _make_gauge(50.0, 0)
	gauge.current_energy = 50.0
	gauge.activate_awakening()
	assert_eq(gauge.awakening_turns_remaining, 1, "duree 0 remontee a 1 tour")

func test_reset_revient_a_start_energy_et_purge_l_eveil() -> void:
	var gauge := _make_gauge(50.0, 2, 12.0)
	gauge.current_energy = 77.0
	gauge.activate_awakening()
	assert_true(gauge.charge_threshold_active)
	gauge.reset()
	assert_almost_eq(gauge.current_energy, 12.0, 0.0001, "retour a start_energy")
	assert_false(gauge.charge_threshold_active, "eveil purge")
	assert_eq(gauge.awakening_turns_remaining, 0)

func test_reset_sans_energie_revient_a_zero() -> void:
	var gauge := EnergyGauge.new(_owner_unit)
	gauge.current_energy = 33.0
	gauge.reset()
	assert_almost_eq(gauge.current_energy, 0.0, 0.0001)
