# EnergyGauge isolee : generation par verbe (gain_table), plafond max_energy,
# multiplicateurs externes passes en parametres par l'appelant.
# Les tests existants qui passent par Unit restent les tests d'integration.
extends GutTest

const Factory = preload("res://test/support/factory.gd")

func _make_gauge(gains: Dictionary = {}, overrides: Dictionary = {}) -> EnergyGauge:
	# L'unite proprietaire ne sert QUE de charge utile aux signaux EventBus.
	var gauge := EnergyGauge.new(Factory.make_unit())
	gauge.energy_type = Factory.make_energy(gains, overrides)
	return gauge

func test_generation_par_verbe_credite_la_gain_table() -> void:
	var gauge := _make_gauge({ "HIT": 4.0, "PROTECT": 12.0, "HEAL": 14.0, "EXPLOIT": 16.0, "TAKE_DAMAGE": 8.0 })
	for verb in ["HIT", "PROTECT", "HEAL", "EXPLOIT", "TAKE_DAMAGE"]:
		gauge.current_energy = 0.0
		var expected := float(gauge.energy_type.gain_table[verb])
		assert_almost_eq(gauge.generate_from_verb(verb), expected, 0.0001, verb)
		assert_almost_eq(gauge.current_energy, expected, 0.0001, "%s (reserve)" % verb)

func test_verbe_inconnu_ou_sans_energie() -> void:
	var gauge := _make_gauge({ "HIT": 10.0 })
	assert_almost_eq(gauge.generate_from_verb("DANSER"), 0.0, 0.0001)
	var sans_ecole := EnergyGauge.new(Factory.make_unit())
	assert_almost_eq(sans_ecole.generate_from_verb("HIT"), 0.0, 0.0001, "sans energy_type : aucun gain")

func test_plafond_max_energy_tronque_le_gain() -> void:
	var gauge := _make_gauge({}, { "max_energy": 100.0 })
	gauge.current_energy = 95.0
	assert_almost_eq(gauge.generate(500.0), 5.0, 0.0001, "le gain reel est tronque au plafond")
	assert_almost_eq(gauge.current_energy, 100.0, 0.0001)
	assert_almost_eq(gauge.generate(10.0), 0.0, 0.0001, "a plein, plus aucun gain")

func test_multiplicateurs_externes_appliques_au_gain() -> void:
	# Terrain et multiplicateur global : passes en parametres par l'appelant.
	var gauge := _make_gauge({ "HIT": 10.0, "EXPLOIT": 10.0 })
	assert_almost_eq(gauge.generate_from_verb("HIT", "", 2.0, 1.5), 30.0, 0.0001, "10 x terrain 2.0 x global 1.5")
	# Le multiplicateur exploit (Force) ne touche QUE le verbe EXPLOIT.
	gauge.current_energy = 0.0
	assert_almost_eq(gauge.generate_from_verb("EXPLOIT", "", 1.0, 1.0, 1.5), 15.0, 0.0001, "EXPLOIT x Force 1.5")
	gauge.current_energy = 0.0
	assert_almost_eq(gauge.generate_from_verb("HIT", "", 1.0, 1.0, 1.5), 10.0, 0.0001, "HIT insensible au multiplicateur exploit")

func test_multiplicateur_de_seuil_pendant_l_eveil() -> void:
	var gauge := _make_gauge({ "HIT": 10.0 })
	gauge.energy_type.threshold_gain_multipliers = { "HIT": 2.0 }
	gauge.charge_threshold_active = true
	assert_almost_eq(gauge.generate_from_verb("HIT"), 20.0, 0.0001, "gain double pendant le seuil actif")

func test_depense_et_refus_de_decouvert() -> void:
	var gauge := _make_gauge()
	gauge.current_energy = 30.0
	assert_true(gauge.spend(20.0))
	assert_almost_eq(gauge.current_energy, 10.0, 0.0001)
	assert_false(gauge.spend(11.0), "10 < 11 : refus")
	assert_almost_eq(gauge.current_energy, 10.0, 0.0001, "un refus ne depense rien")
	assert_true(gauge.spend(0.0), "cout nul : toujours accepte")
