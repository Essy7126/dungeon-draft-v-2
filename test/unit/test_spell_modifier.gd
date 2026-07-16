# SpellModifier : les hooks du pipeline de cast permettent de transformer un
# sort en donnee, sans toucher au code de SpellCaster.
extends GutTest

const Factory = preload("res://test/support/factory.gd")

# Modifier de test : pose un terrain sur la case d'ARRIVEE de chaque
# deplacement force, via le hook on_movement_resolved et ctx.movement.
class TerrainOnArrivalMod:
	extends SpellModifier
	var effect: TerrainEffectData = null

	func on_movement_resolved(ctx) -> void:
		for move in ctx.movement:
			if move["to"] != move["from"]:
				ctx.terrain.place_effect(move["to"], effect, ctx.caster, ctx.spell)

func _make_effect(effect_name: String) -> TerrainEffectData:
	var effect := TerrainEffectData.new()
	effect.effect_name = effect_name
	effect.duration = 2
	return effect

func test_modifier_pose_un_terrain_a_l_arrivee_de_la_poussee() -> void:
	var bf := Factory.make_battlefield(8, 1)
	var hero := Factory.make_unit("Heros", 0)
	var enemy := Factory.make_unit("Cible", 1)
	bf.grid.place_unit(hero, Vector2i(0, 0))
	bf.grid.place_unit(enemy, Vector2i(1, 0))
	var spell := Factory.make_spell({ "ap_cost": 1, "push_distance": 3, "spell_range": 5 })
	var mod := TerrainOnArrivalMod.new()
	mod.effect = _make_effect("marque_test")
	spell.modifiers.append(mod)
	var report: Dictionary = bf.caster.cast(hero, spell, Vector2i(1, 0))
	assert_true(report["pushed"], "la cible doit avoir ete poussee")
	assert_eq(enemy.grid_pos, Vector2i(4, 0), "poussee pleine de 3 cases")
	var placed = bf.terrain.get_effect_data(Vector2i(4, 0))
	assert_not_null(placed, "un terrain doit avoir ete pose a l'arrivee")
	if placed != null:
		assert_eq(placed.effect_name, "marque_test")

func test_modifier_filtre_par_nom_de_sort() -> void:
	# Un modifier cible sur un AUTRE sort ne doit pas se declencher.
	var bf := Factory.make_battlefield(8, 1)
	var hero := Factory.make_unit("Heros", 0)
	var enemy := Factory.make_unit("Cible", 1)
	bf.grid.place_unit(hero, Vector2i(0, 0))
	bf.grid.place_unit(enemy, Vector2i(1, 0))
	var spell := Factory.make_spell({ "ap_cost": 1, "push_distance": 3, "spell_range": 5 })
	var mod := TerrainOnArrivalMod.new()
	mod.effect = _make_effect("marque_test")
	mod.target_spell_name = "Un autre sort"
	spell.modifiers.append(mod)
	bf.caster.cast(hero, spell, Vector2i(1, 0))
	assert_null(bf.terrain.get_effect_data(Vector2i(4, 0)), "modifier filtre : aucun terrain pose")

func test_brassard_incendiaire_de_bout_en_bout() -> void:
	# Grandeur nature : le reward reel (TraitData -> TraitSpellModifier ->
	# SpellModStatusOnPush) enflamme les ennemis percutes par le vrai
	# Coup d'epaule. Mur derriere la cible pour garantir la collision.
	var bf := Factory.make_battlefield(8, 1)
	bf.grid.set_type(Vector2i(2, 0), GridData.CellType.WALL)
	var hero := Factory.make_unit("Guerrier", 0)
	var enemy := Factory.make_unit("Gobelin", 1)
	bf.grid.place_unit(hero, Vector2i(0, 0))
	bf.grid.place_unit(enemy, Vector2i(1, 0))
	hero.add_trait_from_data(load("res://data/traits/reward_epaule_enflamme.tres"))
	var spell: Spell = load("res://data/spells/Guerrier/coup_épaule.tres")
	var expected_status: StatusData = load("res://data/status/core/bruleure.tres")
	var report: Dictionary = bf.caster.cast(hero, spell, Vector2i(1, 0))
	assert_false(report.get("failed", false), "le cast doit reussir (3 PA sur 6)")
	assert_true(report["collision"], "la poussee contre le mur doit percuter")
	var burn_count := 0
	for entry in enemy.get_active_statuses():
		if entry["data"].status_name == expected_status.status_name:
			burn_count += 1
	assert_eq(burn_count, 1, "l'ennemi percute doit avoir exactement une Brulure")

func test_brassard_inactif_sur_un_autre_sort() -> void:
	# Le porteur du Brassard qui lance un sort de poussee QUELCONQUE
	# n'enflamme pas : la transformation est liee a Coup d'epaule.
	var bf := Factory.make_battlefield(8, 1)
	bf.grid.set_type(Vector2i(2, 0), GridData.CellType.WALL)
	var hero := Factory.make_unit("Guerrier", 0)
	var enemy := Factory.make_unit("Gobelin", 1)
	bf.grid.place_unit(hero, Vector2i(0, 0))
	bf.grid.place_unit(enemy, Vector2i(1, 0))
	hero.add_trait_from_data(load("res://data/traits/reward_epaule_enflamme.tres"))
	var spell := Factory.make_spell({ "ap_cost": 1, "damage": 3, "push_distance": 1, "collision_damage": 5, "spell_range": 5 })
	bf.caster.cast(hero, spell, Vector2i(1, 0))
	assert_eq(enemy.get_active_statuses().size(), 0, "aucun statut : le Brassard ne vise que Coup d'epaule")
