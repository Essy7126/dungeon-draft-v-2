extends GutTest

const Factory = preload("res://test/support/factory.gd")

const FIRE_TREE := "res://data/characters/mage/disciplines/fire.tres"
const LIGHTNING_TREE := "res://data/characters/mage/disciplines/lightning.tres"
const EARTH_TREE := "res://data/characters/mage/disciplines/earth.tres"
const ELF_ASSASSIN_TREE := "res://data/characters/elf/disciplines/assassin.tres"
const ELF_HEALER_TREE := "res://data/characters/elf/disciplines/healer.tres"
const WARRIOR_BREAKER_TREE := "res://data/characters/warrior/disciplines/breaker.tres"
const WARRIOR_ASSAULT_TREE := "res://data/characters/warrior/disciplines/assault.tres"
const WARRIOR_BULWARK_TREE := "res://data/characters/warrior/disciplines/bulwark.tres"


func _node(tree_path: String, node_id: StringName) -> SkillTreeNodeData:
	var discipline := load(tree_path) as DisciplineData
	for rank_data in discipline.ranks:
		for candidate in rank_data.choices:
			if candidate.upgrade_id == node_id:
				return candidate as SkillTreeNodeData
	return null


func _node_modifiers(tree_path: String, node_ids: Array[StringName]) -> Array[SpellModifier]:
	var result: Array[SpellModifier] = []
	for node_id in node_ids:
		var node := _node(tree_path, node_id)
		assert_not_null(node, str(node_id))
		if node != null:
			result.append_array(node.get_spell_modifiers())
	return result


func _install_modifiers(
		unit: Unit,
		spell_id: StringName,
		modifiers: Array[SpellModifier]
	) -> void:
	unit.set_progression_spell_modifiers_by_spell({spell_id: modifiers})


func test_damage_range_area_terrain_and_ap_cost_run_through_spell_caster() -> void:
	var caster := Factory.make_unit("Mage", 0)
	_install_modifiers(caster, &"mage_fireball", _node_modifiers(FIRE_TREE, [
		&"mage_pyromancy_conflagration",
		&"mage_pyromancy_maitre_des_explosions",
		&"mage_pyromancy_projection_lointaine",
		&"mage_pyromancy_brasier_durable",
	]))
	var terrain := TerrainEffectData.new()
	terrain.effect_name = "feu_test"
	terrain.duration = 2
	terrain.damage = 1
	var spell := Factory.make_spell({
		"spell_id": &"mage_fireball",
		"ap_cost": 2,
		"spell_range": 2,
		"damage": 10,
		"damage_type": Spell.DamageType.MAGICAL,
		"can_target_free_cell": true,
		"terrain_effect": terrain,
	})
	var battlefield := Factory.make_battlefield(8, 5)
	var center := Unit.new("Centre", 1, 100)
	var edge := Unit.new("Bord", 1, 100)
	battlefield.grid.place_unit(caster, Vector2i(0, 2))
	battlefield.grid.place_unit(center, Vector2i(2, 2))
	battlefield.grid.place_unit(edge, Vector2i(3, 2))
	assert_eq(battlefield.caster.get_effective_spell_range(caster, spell), 4)
	var report: Dictionary = battlefield.caster.cast(caster, spell, center.grid_pos)
	assert_false(report.get("failed", false))
	assert_eq(caster.current_ap, 4)
	assert_eq(center.current_hp, 85)
	assert_eq(edge.current_hp, 85)
	assert_true(report["affected_units"].has(edge))
	assert_eq(
		battlefield.grid.get_effect(center.grid_pos)["data"]["duration"],
		3
	)


func test_heal_shield_mobility_and_cleanse_are_applied_to_the_real_target() -> void:
	var caster := Factory.make_unit("Elfe", 0)
	_install_modifiers(caster, &"elf_sylvan_heal", _node_modifiers(ELF_HEALER_TREE, [
		&"elf_healer_seve_abondante",
		&"elf_healer_ecorce_protectrice",
		&"elf_healer_garde_mobile",
		&"elf_healer_purification",
	]))
	var spell := Factory.make_spell({
		"spell_id": &"elf_sylvan_heal",
		"spell_range": 3,
		"can_target_enemy": false,
		"can_target_ally": true,
		"heal": 7,
	})
	var ally := Unit.new("Allié", 0, 100)
	ally.current_hp = 50
	var poison := StatusData.new()
	poison.status_id = &"test_poison"
	poison.status_name = "Poison"
	poison.duration = 2
	poison.damage_per_turn = 2
	ally.apply_status(poison)
	var battlefield := Factory.make_battlefield(5, 3)
	battlefield.grid.place_unit(caster, Vector2i(0, 1))
	battlefield.grid.place_unit(ally, Vector2i(1, 1))
	var report: Dictionary = battlefield.caster.cast(caster, spell, ally.grid_pos)
	assert_eq(ally.current_hp, 62)
	assert_eq(ally.current_shield, 5)
	assert_eq(ally.next_turn_mp_bonus, 1)
	assert_true(ally.get_active_statuses().is_empty())
	assert_true(report["healed_units"].has(ally))
	assert_true(report["shielded_units"].has(ally))


func test_dot_and_outgoing_damage_reduction_have_runtime_effects() -> void:
	var elf := Factory.make_unit("Elfe", 0)
	_install_modifiers(elf, &"elf_sneak_strike", _node_modifiers(ELF_ASSASSIN_TREE, [
		&"elf_assassin_lame_venimeuse",
		&"elf_assassin_affaiblissement",
	]))
	var strike := Factory.make_spell({
		"spell_id": &"elf_sneak_strike",
		"spell_range": 1,
		"damage": 7,
	})
	var enemy := Unit.new("Ennemi", 1, 100)
	var battlefield := Factory.make_battlefield(4, 1)
	battlefield.grid.place_unit(elf, Vector2i(0, 0))
	battlefield.grid.place_unit(enemy, Vector2i(1, 0))
	battlefield.caster.cast(elf, strike, enemy.grid_pos)
	var after_strike := enemy.current_hp
	enemy.process_statuses()
	assert_eq(enemy.current_hp, after_strike - 2)
	var elf_hp := elf.current_hp
	elf.take_damage(5, enemy, Spell.DamageType.PHYSICAL)
	assert_eq(elf.current_hp, elf_hp - 3)


func test_conductivity_arc_splashes_once_to_an_adjacent_enemy() -> void:
	var mage := Factory.make_unit("Mage", 0)
	_install_modifiers(mage, &"mage_thunderstorm", _node_modifiers(LIGHTNING_TREE, [
		&"mage_fulguromancy_conductivite",
		&"mage_fulguromancy_arc_secondaire",
	]))
	var storm := Factory.make_spell({
		"spell_id": &"mage_thunderstorm",
		"spell_range": 4,
		"damage": 0,
		"damage_type": Spell.DamageType.MAGICAL,
	})
	var primary := Unit.new("Primaire", 1, 100)
	var adjacent := Unit.new("Adjacent", 1, 100)
	var battlefield := Factory.make_battlefield(6, 3)
	battlefield.grid.place_unit(mage, Vector2i(0, 1))
	battlefield.grid.place_unit(primary, Vector2i(2, 1))
	battlefield.grid.place_unit(adjacent, Vector2i(2, 0))
	battlefield.caster.cast(mage, storm, primary.grid_pos)
	assert_eq(primary.get_active_statuses().size(), 1)
	primary.take_damage(5, mage, Spell.DamageType.PHYSICAL)
	assert_eq(primary.current_hp, 92)
	assert_eq(adjacent.current_hp, 97)
	primary.take_damage(5, mage, Spell.DamageType.PHYSICAL)
	assert_eq(primary.current_hp, 87)
	assert_eq(adjacent.current_hp, 97)


func test_push_and_collision_override_are_resolved_after_the_spell_hit() -> void:
	var mage := Factory.make_unit("Mage", 0)
	_install_modifiers(mage, &"mage_seismic_wave", _node_modifiers(EARTH_TREE, [
		&"mage_geomancy_impact_tectonique",
	]))
	var wave := Factory.make_spell({
		"spell_id": &"mage_seismic_wave",
		"spell_range": 3,
		"damage": 0,
		"push_distance": 1,
	})
	var enemy := Unit.new("Ennemi", 1, 100)
	var battlefield := Factory.make_battlefield(4, 1)
	battlefield.grid.place_unit(mage, Vector2i(0, 0))
	battlefield.grid.place_unit(enemy, Vector2i(2, 0))
	var report: Dictionary = battlefield.caster.cast(mage, wave, enemy.grid_pos)
	assert_eq(enemy.grid_pos, Vector2i(3, 0))
	assert_eq(enemy.current_hp, 92)
	assert_true(report["pushed"])
	assert_true(report["collision"])


func test_interceptor_enables_free_targeting_and_charge_movement() -> void:
	var warrior := Factory.make_unit("Guerrier", 0)
	_install_modifiers(warrior, &"warrior_charge", _node_modifiers(WARRIOR_ASSAULT_TREE, [
		&"warrior_assault_intercepteur",
	]))
	var charge := load("res://data/spells/Guerrier/charge.tres") as Spell
	var battlefield := Factory.make_battlefield(6, 1)
	battlefield.grid.place_unit(warrior, Vector2i(0, 0))
	assert_true(battlefield.caster.is_valid_target(warrior, charge, Vector2i(3, 0)))
	var report: Dictionary = battlefield.caster.cast(warrior, charge, Vector2i(3, 0))
	assert_false(report.get("failed", false))
	assert_eq(warrior.grid_pos, Vector2i(3, 0))
	assert_eq(warrior.current_ap, 4)


func test_attack_order_buffs_exactly_the_next_attack() -> void:
	var warrior := Factory.make_unit("Guerrier", 0)
	_install_modifiers(warrior, &"warrior_guard", _node_modifiers(WARRIOR_BULWARK_TREE, [
		&"warrior_bulwark_ordre_dassaut",
		&"warrior_bulwark_commandement",
	]))
	var guard := load("res://data/spells/Guerrier/garde.tres") as Spell
	var ally := Factory.make_unit("Allié", 0)
	var enemy := Unit.new("Ennemi", 1, 100)
	var battlefield := Factory.make_battlefield(5, 1)
	battlefield.grid.place_unit(warrior, Vector2i(0, 0))
	battlefield.grid.place_unit(ally, Vector2i(1, 0))
	battlefield.grid.place_unit(enemy, Vector2i(3, 0))
	battlefield.caster.cast(warrior, guard, ally.grid_pos)
	enemy.take_damage(5, ally, Spell.DamageType.PHYSICAL)
	assert_eq(enemy.current_hp, 91)
	enemy.take_damage(5, ally, Spell.DamageType.PHYSICAL)
	assert_eq(enemy.current_hp, 86)


func test_execution_threshold_upgrade_replaces_instead_of_stacking() -> void:
	var warrior := Factory.make_unit("Guerrier", 0)
	_install_modifiers(warrior, &"warrior_heavy_strike", _node_modifiers(WARRIOR_BREAKER_TREE, [
		&"warrior_breaker_executeur",
		&"warrior_breaker_coup_fatal",
	]))
	var strike := Factory.make_spell({
		"spell_id": &"warrior_heavy_strike",
		"spell_range": 1,
		"damage": 8,
	})
	var battlefield := Factory.make_battlefield(3, 1)
	var target := Unit.new("Cible", 1, 100)
	target.current_hp = 45
	battlefield.grid.place_unit(warrior, Vector2i(0, 0))
	battlefield.grid.place_unit(target, Vector2i(1, 0))
	battlefield.caster.cast(warrior, strike, target.grid_pos)
	assert_eq(target.current_hp, 33)
	target.current_hp = 35
	warrior.current_ap = warrior.max_ap.get_int()
	battlefield.caster.cast(warrior, strike, target.grid_pos)
	assert_eq(target.current_hp, 23)
