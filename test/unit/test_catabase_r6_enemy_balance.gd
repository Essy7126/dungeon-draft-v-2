extends GutTest

const Catalog = preload("res://core/expedition/catabase_monster_encounter_catalog.gd")
const Evolution = preload("res://core/expedition/catabase_monster_evolution_catalog.gd")
const Factory = preload("res://core/expedition/expedition_run_factory.gd")
const PARIS_SOURCE: UnitData = preload("res://data/units/enemies/catabase_shadow_paris.tres")
const SPECTRE_SOURCE: UnitData = preload("res://data/units/enemies/spectre_greatsword.tres")
const COMBAT_DEPTHS := [2, 3, 5, 6, 8, 10, 12, 13, 15, 17]
const FAMILIES := [&"airain", &"styx", &"lethe"]


func _node(depth: int, family: StringName, difficulty := &"normal") -> Dictionary:
	var kind := "elite" if depth in [6, 10, 15] else ("boss" if depth == 20 else "normal")
	return {
		"id": "fixture_%d_%s" % [depth, family],
		"depth": depth,
		"kind": kind,
		"title": "Titre de présentation libre",
		"hint": "Menace de test",
		"reward": "melee",
		"route_family": family,
		"balance_revision": 1,
		"encounter_grade": 1 if depth <= 6 else (2 if depth <= 12 else 3),
		"encounter_profile_id": "catabase_r6_d%02d_%s" % [depth, family],
		"difficulty_id": difficulty,
		"xp_reward": 345 if depth == 20 else 0,
	}


func _encounter(node: Dictionary) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.room_index = maxi(1, int(node.depth))
	assert_true(
		Catalog.configure_encounter(encounter, node),
		str(node.get("encounter_profile_id", node.get("id", "fixture"))),
	)
	return encounter


func _expanded_role_ids(encounter: EncounterDefinition) -> Array[StringName]:
	var result: Array[StringName] = []
	for index in encounter.roster_units.size():
		for _copy in encounter.roster_counts[index]:
			result.append(encounter.roster_units[index].tactical_role_id)
	return result


func _total_hp(encounter: EncounterDefinition) -> int:
	var total := 0
	for index in encounter.roster_units.size():
		total += encounter.roster_units[index].max_hp * encounter.roster_counts[index]
	return total


func _unit_for_role(encounter: EncounterDefinition, role: StringName) -> UnitData:
	var tactical_id := StringName("catabase_evolution_%s" % role)
	for unit: UnitData in encounter.roster_units:
		if unit.tactical_role_id == tactical_id:
			return unit
	return null


func _spell(unit: UnitData, spell_id: StringName) -> Spell:
	for spell: Spell in unit.spells:
		if spell.get_effective_spell_id() == spell_id:
			return spell
	return null


func test_all_fixed_profiles_use_authored_roles_and_explicit_grades() -> void:
	for depth: int in COMBAT_DEPTHS:
		for family: StringName in FAMILIES:
			var node := _node(depth, family)
			assert_eq(Catalog.profile_validation_error(node), "", str(node.encounter_profile_id))
			var expected_roles: Array[StringName] = []
			expected_roles.assign(Catalog.V1_ROLES_BY_DEPTH[depth].get(
					family,
					Catalog.V1_ROLES_BY_DEPTH[depth].get(&"shared", []),
				))
			assert_eq(Catalog.composition_for(node), expected_roles, str(node.encounter_profile_id))
			var encounter := _encounter(node)
			var expected_ids: Array[StringName] = []
			for role: StringName in expected_roles:
				expected_ids.append(StringName("catabase_evolution_%s" % role))
			expected_ids.sort()
			var actual_ids := _expanded_role_ids(encounter)
			actual_ids.sort()
			assert_eq(actual_ids, expected_ids, str(node.encounter_profile_id))
			for unit: UnitData in encounter.roster_units:
				var expected_ap: int = (
					4
					if unit.tactical_role_id == &"catabase_evolution_porteur"
					else [4, 5, 6][int(node.encounter_grade) - 1]
				)
				assert_eq(unit.max_ap, expected_ap)
				assert_eq(
					unit.presentation_badge,
					["INITIÉ", "VÉTÉRAN", "SPÉCIALISTE"][int(node.encounter_grade) - 1],
				)


func test_profile_identity_is_strict_and_never_falls_back_to_seed_or_title() -> void:
	var node := _node(8, &"styx")
	node.encounter_profile_id = &"catabase_r6_d08_airain"
	node.id = "catabase:2401:anything"
	node.title = "Les chaînes sous les arches"
	assert_false(Catalog.profile_validation_error(node).is_empty())
	assert_true(Catalog.encounter_preview(node).is_empty())
	node = _node(6, &"lethe")
	node.encounter_grade = 2
	assert_false(
		Catalog.profile_validation_error(node).is_empty(),
		"VI refuses the depth-derived Veteran grade",
	)


func test_pack_hp_is_normalized_and_x_elites_have_exact_reference_budget() -> void:
	var prowess_by_depth := {
		2: 22,
		3: 27,
		5: 33,
		6: 40,
		8: 48,
		10: 57,
		12: 68,
		13: 82,
		15: 100,
		17: 106,
	}
	for depth: int in COMBAT_DEPTHS:
		var totals: Array[int] = []
		for family: StringName in FAMILIES:
			var encounter := _encounter(_node(depth, family))
			var expected := roundi(
				float(prowess_by_depth[depth]) * float(Catalog.V1_PACK_HP_WEIGHTS[depth])
			)
			var actual := _total_hp(encounter)
			assert_between(
				actual,
				expected - encounter.get_initial_enemy_count(),
				expected + encounter.get_initial_enemy_count(),
			)
			totals.append(actual)
		assert_lte(
			totals.max() - totals.min(),
			4,
			"Route families share the pack budget at depth %d" % depth,
		)
	var elite := _encounter(_node(10, &"airain"))
	assert_eq(_unit_for_role(elite, &"rabatteur").max_hp, 194)
	assert_eq(_unit_for_role(elite, &"executeur").max_hp, 194)


func test_reference_damage_and_easy_factors_apply_once_to_secondary_effects() -> void:
	var normal_hunt := _encounter(_node(8, &"styx", &"normal"))
	var easy_hunt := _encounter(_node(8, &"styx", &"easy"))
	assert_eq(_unit_for_role(normal_hunt, &"conducteur").attack_power, 17)
	assert_eq(_unit_for_role(normal_hunt, &"molosse").attack_power, 29)
	assert_eq(_unit_for_role(easy_hunt, &"conducteur").attack_power, 14)
	assert_eq(_unit_for_role(easy_hunt, &"molosse").attack_power, 23)
	assert_almost_eq(float(_total_hp(easy_hunt)), float(_total_hp(normal_hunt)) * 0.90, 2.0)
	var normal_furnace := _unit_for_role(_encounter(_node(13, &"airain")), &"fondeur")
	var easy_furnace := _unit_for_role(_encounter(_node(13, &"airain", &"easy")), &"fondeur")
	assert_eq(normal_furnace.attack_power, 60)
	assert_eq(easy_furnace.attack_power, 48)
	var normal_fire := _spell(normal_furnace, &"catabase_evolution_brasier").terrain_effect.damage
	var easy_fire := _spell(easy_furnace, &"catabase_evolution_brasier").terrain_effect.damage
	assert_eq(easy_fire, roundi(float(normal_fire) * 0.80))


func test_fixed_monster_resources_are_owned_by_each_encounter() -> void:
	var first := _unit_for_role(_encounter(_node(13, &"airain")), &"fondeur")
	var second := _unit_for_role(_encounter(_node(13, &"airain")), &"fondeur")
	var source := load("res://data/spells/catabase_monsters/braise_fournaise.tres") as Spell
	var source_coefficient := source.damage_scaling.prowess_coefficient
	first.spells[1].damage_scaling.prowess_coefficient = 999.0
	first.spells[2].terrain_effect.damage = 999
	assert_ne(second.spells[1].damage_scaling.prowess_coefficient, 999.0)
	assert_ne(second.spells[2].terrain_effect.damage, 999)
	assert_eq(source.damage_scaling.prowess_coefficient, source_coefficient)


func test_paris_profile_owns_final_normal_and_easy_numbers() -> void:
	var normal := _encounter(_node(20, &"common", &"normal"))
	assert_eq(normal.roster_counts, PackedInt32Array([1, 2]))
	var paris := normal.roster_units[0]
	var spectre := normal.roster_units[1]
	assert_eq([paris.max_hp, paris.max_ap, paris.max_mp], [560, 4, 3])
	assert_eq([spectre.max_hp, spectre.max_ap, spectre.max_mp], [150, 2, 3])
	assert_eq(paris.combat_form_change.below_hp_percent, 20)
	assert_true(paris.combat_form_change.restore_full_hp)
	assert_eq(paris.combat_form_change.shield_grant, 30)
	for spell: Spell in paris.spells + paris.combat_form_change.spells:
		assert_eq(spell.damage, int(Catalog.V1_PARIS_DAMAGE[spell.get_effective_spell_id()]))
	assert_eq(_spell(spectre, &"spectre_heavy_cleave").damage, 70)
	assert_eq(_spell(paris, &"paris_fire_arrow").terrain_effect.damage, 20)
	assert_eq(_spell(paris, &"paris_fire_arrow").applied_status.damage_per_turn, 12)
	var easy := _encounter(_node(20, &"common", &"easy"))
	assert_eq([easy.roster_units[0].max_hp, easy.roster_units[1].max_hp], [504, 135])
	assert_eq(_spell(easy.roster_units[0], &"paris_spectral_arrow").damage, 64)
	assert_eq(_spell(easy.roster_units[1], &"spectre_heavy_cleave").damage, 56)
	assert_eq(_spell(easy.roster_units[0], &"paris_fire_arrow").terrain_effect.damage, 16)
	assert_eq(_spell(easy.roster_units[0], &"paris_fire_arrow").applied_status.damage_per_turn, 10)
	assert_eq([PARIS_SOURCE.max_hp, SPECTRE_SOURCE.max_hp], [120, 64])
	assert_eq(PARIS_SOURCE.spells[0].damage, 16)


func test_balanced_paris_keeps_nonlethal_threshold_and_fatal_finisher() -> void:
	var paris_data := _encounter(_node(20, &"common")).roster_units[0]
	var paris := Unit.from_data(paris_data)
	paris.take_damage(448)
	assert_eq(paris.current_hp, 112)
	assert_eq(paris.combat_form_id, &"spectral")
	paris.take_damage(1)
	assert_eq(paris.current_hp, 560)
	assert_eq(paris.current_shield, 30)
	assert_eq(paris.combat_form_id, &"infernal")
	var finished := Unit.from_data(paris_data)
	finished.take_damage(560)
	assert_false(finished.is_alive)
	assert_eq(finished.combat_form_id, &"spectral")


func test_factory_consumes_r6_final_values_without_legacy_multipliers() -> void:
	var opening_node: Dictionary = { }
	var elite_node: Dictionary = { }
	var boss_node: Dictionary = { }
	for node: Dictionary in ExpeditionRouteCatalog.create_nodes(2401, 6, "normal"):
		var profile_id := str(node.get("encounter_profile_id", ""))
		if profile_id == "catabase_r6_d01_common":
			opening_node = node
		if profile_id == "catabase_r6_d10_airain":
			elite_node = node
		if profile_id == "catabase_r6_d20_common":
			boss_node = node
	assert_false(opening_node.is_empty())
	assert_false(elite_node.is_empty())
	assert_false(boss_node.is_empty())
	var opening_room := Factory.make_room(opening_node, 2401)
	assert_eq(opening_room.enemies[0].max_hp, 52)
	assert_eq(opening_room.enemies[0].spells[0].damage, 18)
	var easy_opening_node: Dictionary = ExpeditionRouteCatalog.create_nodes(2401, 6, "easy")[0]
	var easy_opening_room := Factory.make_room(easy_opening_node, 2401)
	assert_eq(easy_opening_room.enemies[0].max_hp, 47)
	assert_eq(easy_opening_room.enemies[0].spells[0].damage, 14)
	assert_eq(PARIS_SOURCE.max_hp, 120)
	var elite_room := Factory.make_room(elite_node, 2401)
	assert_not_null(elite_room)
	assert_eq(elite_room.enemies.size(), 2)
	for unit: UnitData in elite_room.encounter_definition.roster_units:
		assert_eq(unit.max_hp, 194)
	assert_eq(Factory.enemy_hp_multiplier(elite_node), 1.0)
	assert_eq(Factory.enemy_attack_multiplier(elite_node), 1.0)
	assert_eq(Factory.xp_for(elite_node), 245)
	var boss_room := Factory.make_room(boss_node, 2401)
	assert_eq(boss_room.enemies.size(), 3)
	assert_eq(boss_room.encounter_definition.roster_units[0].max_hp, 560)
	assert_eq(Factory.xp_for(boss_node), 345)


func test_fixed_regular_profiles_bound_initial_approach_without_touching_legacy() -> void:
	for depth: int in COMBAT_DEPTHS:
		for family: StringName in FAMILIES:
			var encounter := _encounter(_node(depth, family))
			for unit: UnitData in encounter.roster_units:
				assert_eq(encounter.minimum_path_distance_by_role[unit.tactical_role_id], 5)
				assert_eq(encounter.maximum_path_distance_by_role[unit.tactical_role_id], 7)
	var legacy := _encounter(
		{ "depth": 2, "kind": "normal", "reward": "melee", "title": "fixture" }
	)
	for unit: UnitData in legacy.roster_units:
		assert_gt(legacy.maximum_path_distance_by_role[unit.tactical_role_id], 7)


func test_fixed_regular_packs_fit_real_maps_inside_the_approach_band() -> void:
	for node: Dictionary in ExpeditionRouteCatalog.create_nodes(2401, 6, "normal"):
		if not Catalog.uses_monsters(node):
			continue
		var room := Factory.make_room(node, 2401)
		assert_not_null(room, str(node.encounter_profile_id))
		var grid := EncounterGridFactory.build_from_room(room)
		var pathfinder := Pathfinder.new(grid)
		var plan := EncounterFormationPlanner.new(grid, pathfinder).build_plan(
			room.encounter_definition,
			room.hero_spawn_zone,
			room.enemy_spawn_zone,
			2401,
		)
		assert_true(bool(plan.get("valid", false)), "%s : %s" % [node.encounter_profile_id, plan])
		assert_eq((plan.get("placements", []) as Array).size(), room.enemies.size())
		for placement: Dictionary in plan.get("placements", []):
			var shortest := 999999
			for hero_cell: Vector2i in room.hero_spawn_zone:
				var path := pathfinder.find_path(hero_cell, placement.cell)
				if not path.is_empty():
					shortest = mini(shortest, path.size() - 1)
			assert_between(shortest, 5, 7, str(node.encounter_profile_id))


func test_revision_five_keeps_depth_grades_and_title_owned_opening_packs() -> void:
	var legacy := {
		"depth": 6,
		"kind": "elite",
		"title": "Les duellistes du gué",
		"reward": "melee",
	}
	assert_false(Catalog.uses_fixed_balance(legacy))
	assert_eq(Evolution.grade_for(legacy), 2)
	assert_eq(Catalog.composition_for(legacy), [&"molosse", &"molosse", &"officiant"])
