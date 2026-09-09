extends GutTest
## Real routes, varied packs, first-contact budgets, immutable authored assets.
const Catalog = preload("res://core/expedition/catabase_monster_encounter_catalog.gd")
const PROGRESSION = preload("res://data/runs/progression/odyssey/achilles_champion_progression_v0.tres")
const STRIKE = preload("res://data/spells/achilles/peleid_strike.tres")
const SEEDS := [2401, 42, 777]
var _source_units: Array[UnitData] = []
var _source_rooms: Array[RoomData] = []


func before_all() -> void:
	for path: String in Catalog.UNIT_PATHS.values():
		_source_units.append(load(path) as UnitData)
	_source_rooms = ExpeditionMapCatalog.all_rooms()


func after_all() -> void:
	_source_units.clear()
	_source_rooms.clear()


func _node(depth: int, reward: String = "melee", kind: String = "normal") -> Dictionary:
	return {"depth": depth, "reward": reward, "kind": kind, "id": "balance_%d" % depth,
		"room_index": ExpeditionRouteCatalog.MAP_BY_DEPTH[depth], "title": "Balance fixture"}


func _unit_signature(data: UnitData) -> Array:
	return [data.unit_id, data.max_hp, data.attack_power, data.max_ap, data.max_mp,
		data.armure, data.resist_magique, data.spells.map(func(spell: Spell):
			return [spell.spell_id, spell.damage, spell.heal, spell.ap_cost, spell.cooldown_activations,
				spell.initial_cooldown, spell.max_uses_per_combat,
				spell.damage_scaling.prowess_coefficient if spell.damage_scaling != null else 0.0])]


func _room_signature(room: RoomData) -> Dictionary:
	var encounter := room.get_encounter_for_wave(0)
	return {"name": room.room_name, "waves": room.waves.duplicate(),
		"enemies": room.enemies.duplicate(), "hero_cells": room.hero_spawn_zone.duplicate(),
		"enemy_cells": room.enemy_spawn_zone.duplicate(), "id": encounter.encounter_id,
		"roster": encounter.roster_units.map(_unit_signature),
		"counts": encounter.roster_counts.duplicate(), "cap": encounter.living_enemy_cap,
		"formations": encounter.formation_profiles.duplicate(),
		"minimum": encounter.minimum_path_distance_by_role.duplicate(),
		"maximum": encounter.maximum_path_distance_by_role.duplicate(),
		"forbidden": encounter.forbidden_initial_spawn_cells.duplicate(),
		"summons": [encounter.shared_normal_summon_budget, encounter.shared_chief_summon_budget]}


func _baseline(depth: int) -> Dictionary:
	var xp := 0
	for previous_depth in range(1, depth):
		if previous_depth in ExpeditionRouteCatalog.HALT_DEPTHS or previous_depth == 11:
			continue
		xp += ExpeditionRunFactory.xp_for(_node(previous_depth))
	var level := PROGRESSION.level_for_xp(xp)
	return {"hp": PROGRESSION.base_hp_for_level(level), "prowess": PROGRESSION.base_prowess_for_level(level)}


func test_all_seeded_route_packs_place_completely_and_cover_six_families() -> void:
	var checked := 0
	for seed_value: int in SEEDS:
		var seen := {}
		for node: Dictionary in ExpeditionRouteCatalog.create_nodes(seed_value):
			if not ExpeditionRouteCatalog.is_combat(str(node.kind)): continue
			var room := ExpeditionRunFactory.make_room(node, seed_value)
			var encounter := room.encounter_definition
			assert_true(encounter.is_valid(), str(node.id))
			var grid := EncounterGridFactory.build_from_room(room)
			var plan := EncounterFormationPlanner.new(grid, Pathfinder.new(grid)).build_plan(
				encounter, room.hero_spawn_zone, room.enemy_spawn_zone, seed_value)
			assert_true(bool(plan.get("valid", false)), "%s seed%d: %s" % [node.id, seed_value, plan.get("reason", "")])
			assert_eq((plan.get("placements", []) as Array).size(), room.enemies.size())
			var cells := {}
			for placement: Dictionary in plan.get("placements", []):
				assert_false(cells.has(placement.cell), "No overlapping bodies")
				assert_false(encounter.forbidden_initial_spawn_cells.has(placement.cell))
				cells[placement.cell] = true
			if Catalog.uses_monsters(node):
				assert_eq(encounter.living_enemy_cap, room.enemies.size())
				assert_eq(encounter.shared_normal_summon_budget + encounter.shared_chief_summon_budget, 0)
				assert_between(room.enemies.size(), 1, 8)
				for role in Catalog.composition_for(node):
					seen[Catalog.Evolution.family_for(role)] = true
			checked += 1
		for family in [&"sentinelle", &"rejeton", &"molosse", &"lamie", &"archer", &"officiant"]:
			assert_true(seen.has(family), "Every route contains family " + str(family))
	assert_gt(checked, 60)


func test_encounter_numbers_and_specialties_create_different_tactical_problems() -> void:
	var fixtures := [[2, "melee", 2], [2, "ranged", 3], [6, "vitality", 5],
		[6, "elemental", 4], [9, "mobility", 6], [10, "control", 2],
		[11, "vitality", 7], [16, "signature", 1], [18, "control", 8]]
	for fixture: Array in fixtures:
		var node := _node(fixture[0], fixture[1])
		var room := ExpeditionRunFactory.make_room(node, 2401)
		assert_eq(room.enemies.size(), int(fixture[2]), str(fixture))
		var preview := Catalog.encounter_preview(node)
		assert_eq(preview.count, room.enemies.size(), "Preview and actual pack agree")
		assert_false(str(preview.counterplay).is_empty())
	for depth in [6, 14]:
		var room := ExpeditionRunFactory.make_room(_node(depth, "vitality" if depth == 6 else "melee"), 42)
		assert_eq(room.enemies.size(), 5)
		for data in room.enemies:
			assert_eq(data.max_mp, 2, "Five colosses keep their deliberate mobility weakness")
	var early := ExpeditionRunFactory.make_room(_node(2), 42).enemies[0]
	var late := ExpeditionRunFactory.make_room(_node(15), 42).enemies[0]
	assert_eq(early.spells.size(), 1)
	assert_eq(early.max_mp, 2)
	assert_gte(late.spells.size(), 3)
	assert_eq(late.max_mp, 4)
	assert_gt(late.max_hp, early.max_hp)
	assert_gt(late.attack_power, early.attack_power)


func test_elite_budget_increases_resistance_without_free_ap_or_movement() -> void:
	for depth in [2, 3, 5, 6, 9, 10, 11, 13, 14, 15, 16, 17, 18]:
		var normal := ExpeditionRunFactory.make_room(_node(depth), 42)
		var elite := ExpeditionRunFactory.make_room(_node(depth, "melee", "elite"), 42)
		assert_eq(elite.enemies.size(), normal.enemies.size())
		for index in normal.enemies.size():
			var base := normal.enemies[index]
			var stronger := elite.enemies[index]
			assert_eq(stronger.unit_id, base.unit_id)
			assert_gt(stronger.max_hp, base.max_hp)
			assert_gte(stronger.attack_power, base.attack_power)
			assert_lte(float(stronger.max_hp) / base.max_hp, 1.20)
			assert_eq(stronger.max_ap, base.max_ap)
			assert_eq(stronger.max_mp, base.max_mp)


func test_dense_packs_have_smaller_individual_budgets_and_post_halt_relief() -> void:
	for pair in [[10, "control", 10, "ranged"], [15, "signature", 18, "control"]]:
		var compact := _node(pair[0], pair[1])
		var dense := _node(pair[2], pair[3])
		assert_gt(Catalog.hp_factor(compact), Catalog.hp_factor(dense))
		assert_gt(Catalog.attack_factor(compact), Catalog.attack_factor(dense))
	for pair in [[11, 13], [15, 17]]:
		var peak := ExpeditionRunFactory.make_room(_node(pair[0], "melee", "elite"), 42)
		var recovery := ExpeditionRunFactory.make_room(_node(pair[1]), 42)
		var peak_hp := 0
		var recovery_hp := 0
		for data in peak.enemies: peak_hp += data.max_hp
		for data in recovery.enemies: recovery_hp += data.max_hp
		assert_lt(recovery_hp, peak_hp, "A halt opens onto a lower resistance budget")


func test_starting_kit_can_clear_packs_and_initial_volley_is_bounded() -> void:
	for node: Dictionary in ExpeditionRouteCatalog.create_nodes(2401):
		if not Catalog.uses_monsters(node): continue
		var baseline := _baseline(int(node.depth))
		var raw_strike := SpellScalingResolver.resolve_from_values(STRIKE.damage_scaling, baseline.prowess, baseline.hp)
		var room := ExpeditionRunFactory.make_room(node, 2401)
		var kill_strikes := 0
		var raw_volley := 0
		for data: UnitData in room.enemies:
			var defender := Unit.from_data(data)
			var context := DamageResolver.HitContext.new()
			context.raw_damage = raw_strike
			context.cannot_be_dodged = true
			var strike_damage := DamageResolver.compute(defender, context).amount
			kill_strikes += ceili(float(data.max_hp) / maxi(1, strike_damage))
			# Knapsack: legal AP budget, at most one use of each initial direct spell.
			# Position, cover and armor can only reduce this conservative exposure.
			var budget: Array[int] = []
			budget.resize(data.max_ap + 1)
			budget.fill(0)
			for spell in data.spells:
				if not spell.deals_damage() or spell.is_delayed() or spell.initial_cooldown > 0:
					continue
				var damage := SpellScalingResolver.resolve_from_values(spell.damage_scaling, data.attack_power, data.max_hp) if spell.damage_scaling != null else spell.damage
				for ap in range(data.max_ap, spell.ap_cost - 1, -1):
					budget[ap] = maxi(budget[ap], budget[ap - spell.ap_cost] + damage)
			raw_volley += budget[data.max_ap]
		assert_lte(kill_strikes, 26 if str(node.kind) == "elite" else 22, "%s: baseline hits to clear, excluding optional build gains" % node.id)
		assert_lte(float(raw_volley) / baseline.hp, 0.60, "%s: complete affordable initial volley" % node.id)


func test_tutorial_bronze_champion_and_boss_keep_authored_cast_stats_and_spawn_rules() -> void:
	for seed_value: int in SEEDS:
		for node: Dictionary in ExpeditionRouteCatalog.create_nodes(seed_value):
			if int(node.depth) not in [1, 7, 20]: continue
			var source := ExpeditionMapCatalog.get_room(int(node.room_index)).get_encounter_for_wave(0)
			var actual := ExpeditionRunFactory.make_room(node, seed_value).encounter_definition
			assert_eq(actual.roster_counts, source.roster_counts)
			assert_eq(actual.formation_profiles, source.formation_profiles)
			assert_eq(actual.minimum_path_distance_by_role, source.minimum_path_distance_by_role)
			assert_eq(actual.forbidden_initial_spawn_cells, source.forbidden_initial_spawn_cells)
			var multiplier := (1.20 if str(node.kind) == "elite" else 1.0) * (1.0 + maxi(0, int(node.depth) - 5) * 0.07)
			for index in source.roster_units.size():
				assert_eq(actual.roster_units[index].unit_id, source.roster_units[index].unit_id)
				assert_eq(actual.roster_units[index].max_hp, roundi(source.roster_units[index].max_hp * multiplier))
				assert_eq(actual.roster_units[index].attack_power, roundi(source.roster_units[index].attack_power * multiplier))
	assert_false(Catalog.uses_monsters(_node(20)))


func test_factory_does_not_mutate_any_source_room_unit_or_shared_spell() -> void:
	var source_rooms := {}
	var source_units := {}
	for index in ExpeditionMapCatalog.ROOM_COUNT:
		source_rooms[index] = _room_signature(ExpeditionMapCatalog.get_room(index))
	for path: String in Catalog.UNIT_PATHS.values():
		source_units[path] = _unit_signature(load(path) as UnitData)
	for seed_value: int in SEEDS:
		for node: Dictionary in ExpeditionRouteCatalog.create_nodes(seed_value):
			if ExpeditionRouteCatalog.is_combat(str(node.kind)):
				ExpeditionRunFactory.make_room(node, seed_value)
	for index in ExpeditionMapCatalog.ROOM_COUNT:
		assert_eq(_room_signature(ExpeditionMapCatalog.get_room(index)), source_rooms[index])
	for path: String in source_units:
		assert_eq(_unit_signature(load(path) as UnitData), source_units[path])


func test_saved_nodes_rebuild_identically_without_adapting_to_player_stats() -> void:
	for seed_value: int in SEEDS:
		for node: Dictionary in ExpeditionRouteCatalog.create_nodes(seed_value):
			if not ExpeditionRouteCatalog.is_combat(str(node.kind)): continue
			var restored := JSON.parse_string(JSON.stringify(node)) as Dictionary
			restored["hero_hp"] = 1
			restored["hero_level"] = 14
			restored["equipment_power"] = 9999
			var before := ExpeditionRunFactory.make_room(node, seed_value).encounter_definition
			var after := ExpeditionRunFactory.make_room(restored, seed_value).encounter_definition
			assert_eq(after.encounter_id, before.encounter_id)
			assert_eq(after.roster_units.map(_unit_signature), before.roster_units.map(_unit_signature))
			assert_eq(after.roster_counts, before.roster_counts)
			assert_eq(after.formation_profiles, before.formation_profiles)
