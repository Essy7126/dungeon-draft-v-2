# Gain_table : chaque verbe (HIT/PROTECT/HEAL/EXPLOIT/TAKE_DAMAGE) credite
# exactement la valeur definie dans le .tres de l'ecole, et le plafond
# max_energy n'est jamais depasse.
extends GutTest

const Factory = preload("res://test/support/factory.gd")

const ENERGY_PATHS := [
	"res://data/energy/rage.tres",
	"res://data/energy/foi.tres",
	"res://data/energy/nature.tres",
	"res://data/energy/ombre.tres",
]

const VERBS := [
	EnergyTypeData.VERB_HIT,
	EnergyTypeData.VERB_PROTECT,
	EnergyTypeData.VERB_HEAL,
	EnergyTypeData.VERB_EXPLOIT,
	EnergyTypeData.VERB_TAKE_DAMAGE,
]

func _unit_with(energy: EnergyTypeData) -> Unit:
	var unit := Factory.make_unit()
	unit.energy_type = energy
	unit.current_energy = 0.0
	return unit

func test_chaque_verbe_credite_la_valeur_du_tres() -> void:
	# Force 0, pas de seuil actif, pas de terrain : le gain doit etre
	# EXACTEMENT la valeur de la gain_table du .tres, pour les 4 ecoles.
	for path in ENERGY_PATHS:
		var energy: EnergyTypeData = load(path)
		assert_not_null(energy, "ressource introuvable : %s" % path)
		for verb in VERBS:
			var unit := _unit_with(energy)
			var expected := float(energy.gain_table.get(verb, 0.0))
			var gained := unit.generate_fervor_from_verb(verb)
			assert_almost_eq(gained, expected, 0.0001, "%s / %s" % [energy.energy_id, verb])
			assert_almost_eq(unit.current_energy, expected, 0.0001, "%s / %s (reserve)" % [energy.energy_id, verb])

func test_verbe_inconnu_ne_credite_rien() -> void:
	var unit := _unit_with(Factory.make_energy({ "HIT": 10.0 }))
	assert_almost_eq(unit.generate_fervor_from_verb("DANSER"), 0.0, 0.0001)
	assert_almost_eq(unit.current_energy, 0.0, 0.0001)

func test_take_damage_credite_via_le_flux_de_degats_reel() -> void:
	# Encaisser un coup passe par take_damage -> generation TAKE_DAMAGE.
	# Foi paie 8 par coup encaisse (valeur du .tres).
	var energy: EnergyTypeData = load("res://data/energy/foi.tres")
	var unit := _unit_with(energy)
	unit.take_damage(10)
	var expected := float(energy.gain_table.get(EnergyTypeData.VERB_TAKE_DAMAGE, 0.0))
	assert_almost_eq(unit.current_energy, expected, 0.0001, "Foi doit crediter TAKE_DAMAGE sur un coup encaisse")

func test_plafond_max_energy_jamais_depasse() -> void:
	var unit := _unit_with(Factory.make_energy({}, { "max_energy": 100.0 }))
	unit.current_energy = 95.0
	var real := unit.generate_energy(500.0)
	assert_almost_eq(real, 5.0, 0.0001, "le gain reel est tronque au plafond")
	assert_almost_eq(unit.current_energy, 100.0, 0.0001)

func test_plafond_tenu_sous_generation_repetee_par_verbe() -> void:
	var unit := _unit_with(Factory.make_energy({ "EXPLOIT": 16.0 }))
	for i in 20:
		unit.generate_fervor_from_verb(EnergyTypeData.VERB_EXPLOIT)
	assert_almost_eq(unit.current_energy, 100.0, 0.0001, "20 x 16 doit saturer a max_energy = 100")
