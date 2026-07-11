# Collision en chaine : une unite poussee dans une autre inflige les degats
# de collision AUX DEUX, transmet la quantite de mouvement restante a la
# percutee, et les deux unites finissent aux bonnes cases.
extends GutTest

const Factory = preload("res://test/support/factory.gd")

# Couloir 8x1 : heros en (0,0), cible A en (1,0), bloqueur B en (3,0).
func _setup_corridor() -> Dictionary:
	var bf := Factory.make_battlefield(8, 1)
	var hero := Factory.make_unit("Heros", 0)
	var a := Factory.make_unit("Cible A", 1)
	var b := Factory.make_unit("Bloqueur B", 1)
	bf.grid.place_unit(hero, Vector2i(0, 0))
	bf.grid.place_unit(a, Vector2i(1, 0))
	bf.grid.place_unit(b, Vector2i(3, 0))
	return { "bf": bf, "hero": hero, "a": a, "b": b }

func test_chaine_degats_aux_deux_et_deplacements() -> void:
	var ctx := _setup_corridor()
	var spell := Factory.make_spell({ "ap_cost": 1, "push_distance": 3, "collision_damage": 10, "spell_range": 5 })
	var report: Dictionary = ctx["bf"].caster.cast(ctx["hero"], spell, Vector2i(1, 0))
	# A avance de 1, percute B : les deux prennent 10.
	assert_eq(ctx["a"].current_hp, 90, "la poussee inflige les degats de collision a la cible")
	assert_eq(ctx["b"].current_hp, 90, "et a l'unite percutee")
	# B recoit l'elan restant (3 - 1 = 2 cases) et libere la case ;
	# A occupe la case liberee.
	assert_eq(ctx["b"].grid_pos, Vector2i(5, 0), "B propulse de (3,0) a (5,0)")
	assert_eq(ctx["a"].grid_pos, Vector2i(3, 0), "A prend la case liberee par B")
	assert_true(report["collision"], "le rapport signale la collision")
	assert_true(report["pushed"], "le rapport signale la poussee")

func test_chaine_stoppee_par_un_mur() -> void:
	# Mur en (4,0) : B ne peut pas bouger, il encaisse le choc de chaine
	# PUIS la collision contre le mur (2 x 10), et A reste derriere lui.
	var ctx := _setup_corridor()
	ctx["bf"].grid.set_type(Vector2i(4, 0), GridData.CellType.WALL)
	var spell := Factory.make_spell({ "ap_cost": 1, "push_distance": 3, "collision_damage": 10, "spell_range": 5 })
	var report: Dictionary = ctx["bf"].caster.cast(ctx["hero"], spell, Vector2i(1, 0))
	assert_eq(ctx["a"].current_hp, 90, "A prend le choc de la percussion")
	assert_eq(ctx["b"].current_hp, 80, "B prend la percussion (10) puis le mur (10)")
	assert_eq(ctx["b"].grid_pos, Vector2i(3, 0), "B bloque par le mur")
	assert_eq(ctx["a"].grid_pos, Vector2i(2, 0), "A s'arrete contre B")
	assert_true(report["collision"])

func test_poussee_simple_sans_obstacle_ne_blesse_personne() -> void:
	# Temoin : sans rien a percuter, la poussee deplace sans degats.
	var bf := Factory.make_battlefield(8, 1)
	var hero := Factory.make_unit("Heros", 0)
	var a := Factory.make_unit("Cible A", 1)
	bf.grid.place_unit(hero, Vector2i(0, 0))
	bf.grid.place_unit(a, Vector2i(1, 0))
	var spell := Factory.make_spell({ "ap_cost": 1, "push_distance": 3, "collision_damage": 10, "spell_range": 5 })
	var report: Dictionary = bf.caster.cast(hero, spell, Vector2i(1, 0))
	assert_eq(a.current_hp, 100, "aucune collision : aucun degat")
	assert_eq(a.grid_pos, Vector2i(4, 0), "poussee pleine de 3 cases")
	assert_false(report["collision"])
