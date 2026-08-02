# test/support/factory.gd
# ============================================================
# FABRIQUES POUR LES TESTS UNITAIRES — logique pure uniquement.
# Construit des Unit / Spell / champ de bataille
# minimaux et deterministes (esquive 0, crit 0 : aucun jet aleatoire
# ne peut faire varier les resultats des tests).
# ============================================================
extends RefCounted

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

# Champ de bataille complet (grille + pathfinder + terrain + lanceur),
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
