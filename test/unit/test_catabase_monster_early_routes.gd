extends GutTest

const Early = preload("res://core/expedition/catabase_early_encounters.gd")
const Evolution = preload("res://core/expedition/catabase_monster_evolution_catalog.gd")
const Factory = preload("res://test/support/factory.gd")
const Cleanup = preload("res://test/support/isolated_battlefield_cleanup.gd")
var fields: Array = []


func after_each() -> void:
	for field in fields:
		for unit: Unit in field.grid.get_units():
			unit.clear_combat_effect_history()
		field.terrain.dispose()
		Cleanup.dispose_grid(field.grid)
	fields.clear()


func _field():
	var field = Factory.make_battlefield(10, 5)
	fields.append(field)
	return field


func _node(title: String, depth := 2) -> Dictionary:
	return {
		"title": title,
		"depth": depth,
		"kind": "normal",
		"reward": "melee",
		"id": "early_fixture",
		"room_index": 5,
	}


func _monster(role: StringName, node: Dictionary) -> Unit:
	var data := Evolution.build_unit(role, node)
	Early.tune(data, role, node)
	return Unit.from_data(data)


func test_entry_encounters_keep_identity_when_reward_changes_or_nodes_restore() -> void:
	var signatures := { }
	for title in ["La sente des oliviers", "Le portique des oboles", "Les traces du Léthé"]:
		var node := _node(title)
		var expected := CatabaseMonsterEncounterCatalog.encounter_preview(node)
		signatures[str(expected.roles)] = true
		for reward in ["armor", "elemental", "ranged", "healing"]:
			node.reward = reward
			assert_eq(
				CatabaseMonsterEncounterCatalog.encounter_preview(
					JSON.parse_string(JSON.stringify(node))
				),
				expected,
			)
	assert_eq(signatures.size(), 3)
	assert_true(Early.preview(_node("La sente des oliviers", 13)).is_empty())


func test_mirrored_routes_preserve_first_branch_destinations_and_legacy_v4_restores() -> void:
	var expected := {
		"La sente des oliviers": ["La garde des sources", "Les guetteurs du bosquet"],
		"Le portique des oboles": ["Les percepteurs d'airain"],
		"Les traces du Léthé": ["Les lances oubliées"],
	}
	var seen_lanes := { }
	for seed_value in [2401, 42, 777, 1, 2, 9]:
		var nodes := ExpeditionRouteCatalog.create_nodes(seed_value)
		var by_id := { }
		for node in nodes:
			by_id[str(node.id)] = node
		for node in nodes:
			if not expected.has(str(node.title)):
				continue
			var titles: Array = []
			for edge in node.edges:
				titles.append(str(by_id[edge].title))
			titles.sort()
			assert_eq(titles, expected[node.title], str(seed_value) + ": " + str(node.title))
			if str(node.title) == "La sente des oliviers":
				seen_lanes[int(node.lane)] = true
		var legacy := ExpeditionRouteState.new()
		legacy.initialize(seed_value, 4)
		var restored := ExpeditionRouteState.new()
		assert_true(restored.restore_snapshot(legacy.to_snapshot()))
		assert_eq(restored.to_snapshot(), legacy.to_snapshot())
	assert_eq(seen_lanes.size(), 2, "Exercise both mirrored and unmirrored routes")


func test_early_guard_can_be_pulled_and_spends_its_attack_on_a_bounded_group_ward() -> void:
	var f = _field()
	var guard := _monster(&"brute", _node("Le portique des oboles"))
	var archer := _monster(&"archer", _node("Le portique des oboles"))
	var hero := Factory.make_unit("Achille", 0)
	f.grid.place_unit(hero, Vector2i(1, 2))
	f.grid.place_unit(guard, Vector2i(3, 2))
	f.grid.place_unit(archer, Vector2i(3, 3))
	var ward: Spell = guard.spells[1]
	f.caster.cast(guard, ward, guard.grid_pos)
	assert_gt(guard.current_shield, 0)
	assert_eq(archer.current_shield, guard.current_shield)
	assert_eq(hero.current_shield, 0)
	assert_eq(guard.current_ap, 0)
	var pull := ExpeditionBuildCatalog.new().get_spell("exp_crochet")
	f.caster.cast(hero, pull, guard.grid_pos)
	assert_eq(guard.grid_pos, Vector2i(2, 2), "Early displacement must really move the defender")
	assert_eq(ward.max_uses_per_combat, 2)
	assert_eq(
		Evolution.build_unit(&"brute", { "depth": 13 }).first_forced_movement_reduction_per_activation,
		1,
		"Later anchoring remains intact",
	)


func test_early_fournaise_announces_then_loses_its_target_at_contact() -> void:
	var f = _field()
	var enemy := _monster(&"fondeur", _node("La sente des oliviers"))
	var hero := Factory.make_unit("Achille", 0)
	f.grid.place_unit(enemy, Vector2i(2, 2))
	f.grid.place_unit(hero, Vector2i(5, 2))
	enemy.start_turn()
	var spell: Spell = enemy.spells[1]
	assert_false(f.caster.can_cast(enemy, spell, hero.grid_pos), "One full initial activation of warning")
	enemy.start_turn()
	assert_true(f.caster.can_cast(enemy, spell, hero.grid_pos))
	f.caster.cast(enemy, spell, hero.grid_pos)
	assert_eq(hero.current_hp, 100, "Preparation deals no immediate damage")
	assert_false(enemy.pending_ability.is_empty())
	f.grid.relocate_unit(hero, Vector2i(3, 2))
	enemy.start_turn()
	var result: Dictionary = f.caster.resolve_pending_activation(enemy, [hero, enemy])
	assert_true(bool(result.blocked))
	assert_eq(hero.current_hp, 100)
	assert_true(enemy.pending_ability.is_empty())


func test_cinder_removes_one_mp_for_one_activation_and_never_pa() -> void:
	var f = _field()
	var enemy := _monster(&"conducteur", _node("Les guetteurs du bosquet", 3))
	var hero := Factory.make_unit("Achille", 0)
	f.grid.place_unit(enemy, Vector2i(2, 2))
	f.grid.place_unit(hero, Vector2i(5, 2))
	enemy.start_turn()
	var cinder: Spell = enemy.spells[1]
	assert_false(f.caster.can_cast(enemy, cinder, hero.grid_pos))
	enemy.start_turn()
	f.caster.cast(enemy, cinder, hero.grid_pos)
	hero.start_turn()
	assert_false(ArenaTerrainStatusTimingService.resolve_activation_start(hero, f.terrain))
	assert_eq(hero.current_mp, 2)
	assert_eq(hero.current_ap, 6)
	ArenaTerrainStatusTimingService.resolve_activation_end(hero)
	hero.start_turn()
	ArenaTerrainStatusTimingService.resolve_activation_start(hero, f.terrain)
	assert_eq(hero.current_mp, 3)


func test_water_healer_cannot_heal_self_and_exhausts_two_real_heals() -> void:
	var f = _field()
	var healer := _monster(&"officiant", _node("Les traces du Léthé"))
	var hound := _monster(&"molosse", _node("Les traces du Léthé"))
	f.grid.place_unit(healer, Vector2i(2, 2))
	f.grid.place_unit(hound, Vector2i(3, 2))
	healer.current_hp = 10
	hound.current_hp = 1
	var heal: Spell = healer.spells[1]
	assert_false(f.caster.can_cast(healer, heal, healer.grid_pos))
	for index in 2:
		healer.start_turn()
		healer.start_turn()
		assert_true(f.caster.can_cast(healer, heal, hound.grid_pos))
		var before := hound.current_hp
		f.caster.cast(healer, heal, hound.grid_pos)
		assert_gt(hound.current_hp, before)
		assert_eq(healer.current_ap, 0, "Healing replaces the attack")
	healer.start_turn()
	healer.start_turn()
	assert_false(f.caster.can_cast(healer, heal, hound.grid_pos))
	assert_eq(healer.current_hp, 10)


func test_water_duel_floor_has_no_inherited_lava_and_keeps_reachable_deployment() -> void:
	var room := ExpeditionMapCatalog.get_room_for_node(_node("Les duellistes du gué", 6))
	var grid := EncounterGridFactory.build_from_room(room)
	for y in grid.rows:
		for x in grid.cols:
			assert_ne(grid.get_type(Vector2i(x, y)), GridData.CellType.LAVA)
	assert_gt(room.hero_spawn_zone.size(), 0)
	assert_true(grid.is_walkable(room.hero_spawn_zone[0]))


func test_early_tuning_cannot_mutate_shared_templates_or_other_builds() -> void:
	var node := _node("Les guetteurs du bosquet", 3)
	var first := _monster(&"fondeur", node)
	var second := _monster(&"fondeur", node)
	first.spells[1].damage_scaling.prowess_coefficient = 99.0
	assert_eq(second.spells[1].damage_scaling.prowess_coefficient, 1.8)
	var source := load("res://data/spells/catabase_monsters/braise_fournaise.tres") as Spell
	assert_eq(source.damage_scaling.prowess_coefficient, 1.4)
	assert_not_null(source.applied_status)
