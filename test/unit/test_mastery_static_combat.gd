extends GutTest

const Factory = preload("res://test/support/factory.gd")
const Adapter = preload("res://battle/mastery_combat_adapter.gd")
const CATALOG_PATH := "res://data/characters/achilles/doctrines/achilles_mastery_catalog.tres"
var field
var hero: Unit
var enemies: Array[Unit] = []
var adapter

func after_each() -> void:
	_dispose()

func test_pelion_reach_has_real_three_to_eight_range_and_distance_damage() -> void:
	for data in [[3, 80], [4, 100], [6, 125], [8, 125]]:
		_fixture([&"achilles_chiron_pelion_reach"], [Vector2i(1 + data[0], 2)])
		var shot := _spell("pelion_shot")
		assert_eq(field.caster.get_effective_spell_minimum_range(hero, shot), 3)
		assert_eq(field.caster.get_effective_spell_range(hero, shot), 8)
		assert_false(field.caster.is_valid_target(hero, shot, Vector2i(3, 2)))
		var report: Dictionary = field.caster.cast(hero, shot, enemies[0].grid_pos)
		assert_false(report.get("failed", false), str(report))
		assert_eq(1000 - enemies[0].current_hp, data[1], "Distance %d" % data[0])
		assert_eq(hero.current_ap, 3)
		assert_eq(shot.minimum_range, 2, "The shared spell remains unchanged")
		assert_eq(shot.spell_range, 6)

func test_close_shot_has_real_one_to_five_range_conditional_damage_and_push() -> void:
	for data in [[1, 125], [3, 125], [4, 100], [5, 85]]:
		_fixture([&"achilles_chiron_close_shot"], [Vector2i(1 + data[0], 2)])
		var shot := _spell("pelion_shot")
		var origin := enemies[0].grid_pos
		assert_eq(field.caster.get_effective_spell_minimum_range(hero, shot), 1)
		assert_eq(field.caster.get_effective_spell_range(hero, shot), 5)
		var report: Dictionary = field.caster.cast(hero, shot, origin)
		assert_false(report.get("failed", false), str(report))
		assert_eq(1000 - enemies[0].current_hp, data[1], "Distance %d" % data[0])
		assert_eq(enemies[0].grid_pos, origin + Vector2i.RIGHT)

func test_scourge_hits_two_cells_at_120_and_70_percent_with_one_paid_cast() -> void:
	_fixture([&"achilles_wrath_scourge_of_troy"], [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)])
	var strike := _spell("peleid_strike")
	assert_eq(strike.get_scaled_damage(hero), 110)
	var report: Dictionary = field.caster.cast(hero, strike, enemies[0].grid_pos)
	assert_false(report.get("failed", false), str(report))
	assert_eq(1000 - enemies[0].current_hp, 132)
	assert_eq(1000 - enemies[1].current_hp, 77)
	assert_eq(enemies[2].current_hp, 1000)
	assert_eq((report.get("damaged_enemies", []) as Array).size(), 2)
	assert_eq(hero.current_ap, 3)
	assert_false(field.caster.can_cast(hero, strike, enemies[0].grid_pos), "Manual use is consumed once")

func test_death_line_pierces_empty_cells_to_three_targets_at_100_70_40_percent() -> void:
	_fixture([&"achilles_chiron_death_line"],
		[Vector2i(3, 2), Vector2i(5, 2), Vector2i(7, 2), Vector2i(8, 2)])
	var shot := _spell("pelion_shot")
	var report: Dictionary = field.caster.cast(hero, shot, enemies[0].grid_pos)
	assert_false(report.get("failed", false), str(report))
	assert_eq(1000 - enemies[0].current_hp, 100)
	assert_eq(1000 - enemies[1].current_hp, 70)
	assert_eq(1000 - enemies[2].current_hp, 40)
	assert_eq(enemies[3].current_hp, 1000)
	assert_eq((report.get("damaged_enemies", []) as Array).size(), 3)

func test_volley_overrides_prerequisite_piercing_with_three_lateral_70_percent_hits() -> void:
	_fixture([&"achilles_chiron_piercing_arrow", &"achilles_chiron_centaur_volley"],
		[Vector2i(4, 2), Vector2i(4, 1), Vector2i(4, 3), Vector2i(5, 2)])
	var shot := _spell("pelion_shot")
	assert_eq(field.caster.get_effective_spell_minimum_range(hero, shot), 2)
	assert_eq(field.caster.get_effective_spell_range(hero, shot), 5)
	assert_false(adapter.spell_profile(hero, shot).piercing_enabled)
	var report: Dictionary = field.caster.cast(hero, shot, enemies[0].grid_pos)
	assert_false(report.get("failed", false), str(report))
	for index in range(3):
		assert_eq(1000 - enemies[index].current_hp, 70)
	assert_eq(enemies[3].current_hp, 1000, "The unit behind is not part of the fan")

func test_aeacus_summit_amplifies_scaled_guard_before_shield_creation_multiplier() -> void:
	_fixture([&"achilles_summit_aeacus"], [], 100.0, 600.0)
	hero.shield_creation_multiplier = 1.1
	var guard := _spell("bronze_guard")
	assert_eq(guard.get_scaled_shield(hero), 55)
	var report: Dictionary = field.caster.cast(hero, guard, hero.grid_pos)
	assert_false(report.get("failed", false), str(report))
	assert_eq(hero.get_shield_value(guard.spell_id), 73, "round((600*5% + 100*25%)*1.2*1.1)")
	assert_eq(hero.current_ap, 4)
	assert_eq(hero.get_shield_instances().size(), 1)
	assert_true(hero.get_shield_instances()[0].tags.has(&"guard"))
	hero.start_turn()
	assert_eq(hero.get_shield_value(guard.spell_id), 0)

func test_wrath_summit_scales_bonus_only_and_leaves_range_penalty_unchanged() -> void:
	_fixture([&"achilles_chiron_pelion_reach", &"achilles_summit_wrath"], [Vector2i(7, 2)])
	var shot := _spell("pelion_shot")
	var report: Dictionary = field.caster.cast(hero, shot, enemies[0].grid_pos)
	assert_false(report.get("failed", false), str(report))
	assert_eq(1000 - enemies[0].current_hp, 129, "25% bonus becomes 28.75%, not 43.75%")
	_fixture([&"achilles_chiron_pelion_reach", &"achilles_summit_wrath"], [Vector2i(4, 2)])
	report = field.caster.cast(hero, shot, enemies[0].grid_pos)
	assert_false(report.get("failed", false), str(report))
	assert_eq(1000 - enemies[0].current_hp, 80, "A penalty is not a positive conditional bonus")

func test_chiron_summit_range_is_applied_once_with_production_spell_modifier_map() -> void:
	_fixture([&"achilles_summit_chiron"], [Vector2i(8, 2)])
	var shot := _spell("pelion_shot")
	assert_eq(field.caster.get_effective_spell_range(hero, shot), 7)
	var report: Dictionary = field.caster.cast(hero, shot, enemies[0].grid_pos)
	assert_false(report.get("failed", false), str(report))
	assert_eq(1000 - enemies[0].current_hp, 100)

func _fixture(ids: Array, positions: Array, prowess: float = 200.0, max_hp: float = 1000.0) -> void:
	_dispose()
	field = Factory.make_battlefield(14, 5)
	hero = Factory.make_unit("Achille", 0)
	hero.attack_power.base_value = prowess
	hero.max_hp.base_value = max_hp
	hero.current_hp = int(max_hp)
	field.grid.set_unit(Vector2i(1, 2), hero)
	var catalog := load(CATALOG_PATH) as MasteryCatalogData
	var nodes: Array[SkillTreeNodeData] = []
	for id in ids:
		var node := catalog.node_catalog().get(id) as SkillTreeNodeData
		assert_not_null(node, str(id))
		nodes.append(node.duplicate(true) as SkillTreeNodeData)
	hero.mastery_nodes.assign(nodes)
	hero.set_progression_spell_modifiers_by_spell(MasteryStaticModifierResolver.modifiers_by_spell(nodes))
	hero.mastery_runtime = MasteryReactiveRuntimeService.new()
	assert_true(hero.mastery_runtime.configure_from_nodes(nodes).is_empty())
	for index in positions.size():
		var enemy := Factory.make_unit("Ennemi_%d" % index, 1)
		enemy.max_hp.base_value = 1000
		enemy.current_hp = 1000
		field.grid.set_unit(positions[index], enemy)
		enemies.append(enemy)
	adapter = Adapter.new()
	adapter.configure(field.grid, field.caster, field.terrain, field.pathfinder, [hero] + enemies)
	assert_true(field.caster.set_action_classification_catalog(load("res://data/characters/achilles/attack_classifications.tres")))

func _spell(file: String) -> Spell:
	return load("res://data/spells/achilles/%s.tres" % file) as Spell

func _dispose() -> void:
	if adapter != null:
		adapter.dispose()
		adapter = null
	if field != null:
		for unit in field.grid.get_units():
			field.grid.clear_unit(unit.grid_pos)
	field = null
	hero = null
	enemies.clear()
