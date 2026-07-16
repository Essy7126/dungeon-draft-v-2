# test/support/factory.gd
# ============================================================
# FABRIQUES POUR LES TESTS UNITAIRES — logique pure uniquement.
# Construit des Unit / EnergyTypeData / Spell / champ de bataille
# minimaux et deterministes (esquive 0, crit 0 : aucun jet aleatoire
# ne peut faire varier les resultats des tests).
# ============================================================
extends RefCounted

const DEFAULT_GAINS := {
	"HIT": 0.0,
	"PROTECT": 0.0,
	"HEAL": 0.0,
	"EXPLOIT": 0.0,
	"TAKE_DAMAGE": 0.0,
}

# Energie de test : plafond 100, seuil d'eveil 50 / 2 tours par defaut.
# `gains` remplace les entrees de la gain_table, `overrides` n'importe
# quelle propriete exportee de EnergyTypeData.
static func make_energy(gains: Dictionary = {}, overrides: Dictionary = {}) -> EnergyTypeData:
	var energy := EnergyTypeData.new()
	energy.energy_id = "test"
	energy.energy_name = "Energie de test"
	energy.max_energy = 100.0
	energy.start_energy = 0.0
	energy.passive_income_per_tier = 0.0
	energy.gain_table = DEFAULT_GAINS.merged(gains, true)
	energy.threshold_gain_multipliers = {}
	energy.awakening_cost = 50.0
	energy.awakening_duration_turns = 2
	for key in overrides:
		energy.set(key, overrides[key])
	return energy

# Unite de test : 100 PV, 6 PA, 3 PM, 20 ATK, defenses nulles.
static func make_unit(p_name := "Testeur", team := 0, force := 0.0) -> Unit:
	var unit := Unit.new(p_name, team, 100, 10, 6, 3, 20)
	unit.force.base_value = force
	return unit

static func make_spell(props: Dictionary = {}) -> Spell:
	var spell := Spell.new()
	spell.spell_name = "Sort de test"
	for key in props:
		spell.set(key, props[key])
	return spell

# Champ de bataille complet (grille + pathfinder + terrain + caster),
# le strict necessaire pour exercer SpellCaster sans scene.
class Battlefield:
	var grid: GridData
	var pathfinder: Pathfinder
	var terrain: TerrainEffects
	var caster: SpellCaster

	func _init(cols: int, rows: int) -> void:
		grid = GridData.new(cols, rows)
		pathfinder = Pathfinder.new(grid)
		terrain = TerrainEffects.new(grid)
		caster = SpellCaster.new(grid, pathfinder, terrain)

static func make_battlefield(cols := 8, rows := 3) -> Battlefield:
	return Battlefield.new(cols, rows)
