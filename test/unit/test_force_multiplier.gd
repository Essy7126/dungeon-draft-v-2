# Multiplicateur de Force : 1 + Force/100.
# Il s'applique aux deplacements forces et aux degats de collision.
extends GutTest

const Factory = preload("res://test/support/factory.gd")

func test_multiplicateur_de_base() -> void:
	assert_almost_eq(Factory.make_unit("F0", 0, 0.0).get_force_multiplier(), 1.0, 0.0001)
	assert_almost_eq(Factory.make_unit("F50", 0, 50.0).get_force_multiplier(), 1.5, 0.0001)
	assert_almost_eq(Factory.make_unit("F100", 0, 100.0).get_force_multiplier(), 2.0, 0.0001)

func test_distance_de_poussee_scalee_par_la_force() -> void:
	# Force 100 -> multiplicateur x2 : une poussee de 2 devient 4 cases.
	var bf := Factory.make_battlefield(8, 3)
	var hero := Factory.make_unit("Heros", 0, 100.0)
	var enemy := Factory.make_unit("Cible", 1)
	bf.grid.place_unit(hero, Vector2i(0, 1))
	bf.grid.place_unit(enemy, Vector2i(1, 1))
	var spell := Factory.make_spell({ "ap_cost": 1, "push_distance": 2, "spell_range": 5 })
	var report: Dictionary = bf.caster.cast(hero, spell, Vector2i(1, 1))
	assert_true(report["pushed"], "la cible doit avoir ete poussee")
	assert_eq(enemy.grid_pos, Vector2i(5, 1), "poussee de 2 x2 = 4 cases : (1,1) -> (5,1)")

func test_distance_de_poussee_sans_force() -> void:
	var bf := Factory.make_battlefield(8, 3)
	var hero := Factory.make_unit("Heros", 0, 0.0)
	var enemy := Factory.make_unit("Cible", 1)
	bf.grid.place_unit(hero, Vector2i(0, 1))
	bf.grid.place_unit(enemy, Vector2i(1, 1))
	var spell := Factory.make_spell({ "ap_cost": 1, "push_distance": 2, "spell_range": 5 })
	bf.caster.cast(hero, spell, Vector2i(1, 1))
	assert_eq(enemy.grid_pos, Vector2i(3, 1), "sans Force la poussee reste de 2 cases")

func test_degats_de_collision_scales_par_la_force() -> void:
	# Mur juste derriere la cible : la poussee percute, degats = 10 x2 = 20.
	var bf := Factory.make_battlefield(8, 3)
	bf.grid.set_type(Vector2i(2, 1), GridData.CellType.WALL)
	var hero := Factory.make_unit("Heros", 0, 100.0)
	var enemy := Factory.make_unit("Cible", 1)
	bf.grid.place_unit(hero, Vector2i(0, 1))
	bf.grid.place_unit(enemy, Vector2i(1, 1))
	var spell := Factory.make_spell({ "ap_cost": 1, "push_distance": 1, "collision_damage": 10, "spell_range": 5 })
	var report: Dictionary = bf.caster.cast(hero, spell, Vector2i(1, 1))
	assert_true(report["collision"], "la poussee doit finir en collision")
	assert_eq(enemy.grid_pos, Vector2i(1, 1), "bloquee par le mur : ne bouge pas")
	assert_eq(enemy.current_hp, 80, "degats de collision 10 x (1 + 100/100) = 20")
