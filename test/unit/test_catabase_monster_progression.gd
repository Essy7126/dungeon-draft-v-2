extends GutTest
## Production route/formation checks and baseline-kit difficulty budgets.

const Catalog = preload("res://core/expedition/catabase_monster_encounter_catalog.gd")
const PROGRESSION = preload("res://data/runs/progression/odyssey/achilles_champion_progression_v0.tres")
const STRIKE = preload("res://data/spells/achilles/peleid_strike.tres")
const GUARD = preload("res://data/spells/achilles/bronze_guard.tres")
const DEPTHS := [2, 3, 5, 6, 9, 10, 11, 13, 14, 15, 16, 17, 18]
const SEEDS := [2401, 42, 777]
var _source_units: Array[UnitData] = []
var _source_rooms: Array[RoomData] = []


func before_all() -> void:
	# Keep the authored sources alive while comparing hundreds of runtime
	# copies. ResourceLoader's weak cache otherwise reloads the large painted
	# resources between unrelated tests; it is not part of the logic under test.
	for path: String in Catalog.UNIT_PATHS.values():
		_source_units.append(load(path) as UnitData)
	_source_rooms = ExpeditionMapCatalog.all_rooms()


func after_all() -> void:
	_source_units.clear()
	_source_rooms.clear()


func _node(depth: int, reward: String = "melee", kind: String = "normal") -> Dictionary:
	return {"depth": depth, "reward": reward, "kind": kind, "id": "balance_%d" % depth,
		"room_index": ExpeditionRouteCatalog.MAP_BY_DEPTH[depth], "title": "Balance fixture"}


func _family_stats(depth: int, kind: String = "normal") -> Dictionary:
	var stats := {}
	for reward: String in ["melee", "mobility"]:
		for data: UnitData in ExpeditionRunFactory.make_room(_node(depth, reward, kind), 2401).enemies:
			stats[str(data.unit_id)] = [data.max_hp, data.attack_power]
	return stats


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


func _unit_signature(data: UnitData) -> Array:
	return [data.unit_id, data.max_hp, data.attack_power, data.max_ap, data.max_mp,
		data.armure, data.resist_magique, data.spells.map(func(spell: Spell):
			return [spell.spell_id, spell.damage, spell.ap_cost, spell.cooldown_activations, spell.initial_cooldown,
				spell.damage_scaling.prowess_coefficient if spell.damage_scaling != null else 0.0])]


func _total_hp(room: RoomData) -> int:
	var total := 0
	for data: UnitData in room.enemies:
		total += data.max_hp
	return total


func _baseline(depth: int) -> Dictionary:
	var xp := 0
	for previous_depth in range(1, depth):
		# The library can be a lore halt and depth16 can be skipped. Neither
		# optional victory is required to satisfy this conservative baseline.
		if previous_depth in ExpeditionRouteCatalog.HALT_DEPTHS or previous_depth == 11:
			continue
		xp += ExpeditionRunFactory.xp_for(_node(previous_depth))
	var level := PROGRESSION.level_for_xp(xp)
	return {"hp": PROGRESSION.base_hp_for_level(level), "prowess": PROGRESSION.base_prowess_for_level(level)}


func test_all_combat_nodes_place_the_complete_roster_on_three_real_seeded_routes() -> void:
	var checked := 0
	for seed_value: int in SEEDS:
		var seen := {}
		for node: Dictionary in ExpeditionRouteCatalog.create_nodes(seed_value):
			if not ExpeditionRouteCatalog.is_combat(str(node.kind)): continue
			var room := ExpeditionRunFactory.make_room(node, seed_value)
			var encounter := room.encounter_definition
			assert_true(encounter.is_valid(), str(node.id))
			assert_lte(room.enemies.size(), room.enemy_spawn_zone.size(), "Fits authored spawn capacity")
			var grid := EncounterGridFactory.build_from_room(room)
			var planner := EncounterFormationPlanner.new(grid, Pathfinder.new(grid))
			var plan := planner.build_plan(encounter, room.hero_spawn_zone, room.enemy_spawn_zone, seed_value)
			assert_true(bool(plan.get("valid", false)), "%s seed%d: %s" % [node.id, seed_value, plan.get("reason", "")])
			assert_eq((plan.get("placements", []) as Array).size(), room.enemies.size())
			var cells := {}
			for placement: Dictionary in plan.get("placements", []):
				assert_false(cells.has(placement.cell), "No overlapping bodies")
				assert_false(encounter.forbidden_initial_spawn_cells.has(placement.cell), "Foreground restrictions retained")
				cells[placement.cell] = true
			if Catalog.uses_monsters(node):
				assert_eq(encounter.living_enemy_cap, room.enemies.size())
				assert_eq(encounter.shared_normal_summon_budget + encounter.shared_chief_summon_budget, 0)
				var identities := {}
				for data: UnitData in room.enemies:
					identities[data.unit_id] = true
					seen[str(data.unit_id)] = true
				assert_eq(identities.size(), room.enemies.size(), "Distinct roles; no duplicate controller or tank")
			checked += 1
		for path: String in Catalog.UNIT_PATHS.values():
			assert_true(seen.has(str((load(path) as UnitData).unit_id)), "All four families present in each seeded route")
	assert_gt(checked, 60, "Every branch, including optional combats, was inspected")


func test_hp_and_attack_rise_by_depth_while_the_four_roles_stay_differentiated() -> void:
	var previous := {}
	for depth: int in DEPTHS:
		var stats := _family_stats(depth)
		for id: String in stats:
			if previous.has(id):
				assert_gt(int(stats[id][0]), int(previous[id][0]), "%s HP at depth%d" % [id, depth])
				assert_gte(int(stats[id][1]), int(previous[id][1]))
			previous[id] = stats[id]
		assert_gt(int(stats.catabase_sentinelle_airain[0]), int(stats.catabase_rejeton_braise[0]))
		assert_gt(int(stats.catabase_molosse_styx[0]), int(stats.catabase_rejeton_braise[0]))
		if stats.has("catabase_lamie_lethe"):
			assert_gt(int(stats.catabase_lamie_lethe[0]), int(stats.catabase_molosse_styx[0]))
	assert_eq(_family_stats(2).catabase_sentinelle_airain[0], 35, "A forgiving first defender")
	assert_eq(_family_stats(2).catabase_rejeton_braise[0], 19, "Fragile first shooter")
	assert_eq(_family_stats(18).catabase_sentinelle_airain[0], 226, "Late defender survives several canonical strikes")
	assert_eq(_family_stats(18).catabase_rejeton_braise[0], 122)


func test_elites_increase_stats_without_adding_an_extra_action_or_stacked_roles() -> void:
	for depth: int in DEPTHS:
		var normal := ExpeditionRunFactory.make_room(_node(depth), 42)
		var elite := ExpeditionRunFactory.make_room(_node(depth, "melee", "elite"), 42)
		assert_eq(elite.enemies.size(), normal.enemies.size())
		for index in normal.enemies.size():
			var base := normal.enemies[index]
			var stronger := elite.enemies[index]
			assert_eq(stronger.unit_id, base.unit_id)
			assert_gt(stronger.max_hp, base.max_hp)
			assert_gt(stronger.attack_power, base.attack_power)
			assert_lte(float(stronger.max_hp) / base.max_hp, 1.20)
			assert_lte(float(stronger.attack_power) / base.attack_power, 1.20)
			assert_eq(stronger.max_ap, base.max_ap)
			assert_eq(stronger.max_mp, base.max_mp)


func test_recovery_rooms_offer_two_threats_before_three_role_pressure_returns() -> void:
	for seed_value: int in SEEDS:
		for node: Dictionary in ExpeditionRouteCatalog.create_nodes(seed_value):
			if not Catalog.uses_monsters(node): continue
			var expected_count := 2 if int(node.depth) < 10 or int(node.depth) in [13, 17] else 3
			assert_eq(ExpeditionRunFactory.make_room(node, seed_value).enemies.size(), expected_count, str(node.id))
	for pair in [[11, 13], [15, 17]]:
		var peak := ExpeditionRunFactory.make_room(_node(pair[0], "melee", "elite" if pair[0] == 15 else "normal"), 2401)
		var recovery := ExpeditionRunFactory.make_room(_node(pair[1]), 2401)
		assert_lt(_total_hp(recovery), _total_hp(peak), "Less total HP after the halt, despite stronger individual foes")
	var hold := ExpeditionRunFactory.make_room(_node(14, "armor"), 2401)
	var flank := ExpeditionRunFactory.make_room(_node(14, "mobility"), 2401)
	assert_ne(hold.encounter_definition.formation_profiles, flank.encounter_definition.formation_profiles, "Room intent affects real formations")


func test_canonical_starting_kit_keeps_kill_cost_and_pack_exposure_bounded_without_optional_xp() -> void:
	for node: Dictionary in ExpeditionRouteCatalog.create_nodes(2401):
		if not Catalog.uses_monsters(node): continue
		var baseline := _baseline(int(node.depth))
		var raw_strike := SpellScalingResolver.resolve_from_values(STRIKE.damage_scaling, baseline.prowess, baseline.hp)
		var shield := SpellScalingResolver.resolve_from_values(GUARD.shield_scaling, baseline.prowess, baseline.hp)
		var raw_pack_damage := 0
		var room := ExpeditionRunFactory.make_room(node, 2401)
		for data: UnitData in room.enemies:
			var defender := Unit.from_data(data)
			var context := DamageResolver.HitContext.new()
			context.raw_damage = raw_strike
			context.cannot_be_dodged = true
			var strike_damage := DamageResolver.compute(defender, context).amount
			var strikes_to_kill := ceili(float(data.max_hp) / strike_damage)
			assert_between(strikes_to_kill, 2, 7, "%s %s: base strike after actual armor" % [node.id, data.unit_id])
			for spell: Spell in data.spells:
				if spell.visual_action == Spell.VisualAction.HEAVY: continue
				raw_pack_damage += SpellScalingResolver.resolve_from_values(spell.damage_scaling, data.attack_power, data.max_hp)
		assert_lte(float(raw_pack_damage) / baseline.hp, 0.24, "%s: full primary volley <=24%% baseline HP" % node.id)
		assert_lte(float(maxi(0, raw_pack_damage - shield)) / baseline.hp, 0.15, "%s: starting guard limits exposure" % node.id)


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
			var legacy_multiplier := (1.20 if str(node.kind) == "elite" else 1.0) * (1.0 + maxi(0, int(node.depth) - 5) * 0.07)
			for index in source.roster_units.size():
				assert_eq(actual.roster_units[index].unit_id, source.roster_units[index].unit_id)
				assert_eq(actual.roster_units[index].max_hp, roundi(source.roster_units[index].max_hp * legacy_multiplier))
				assert_eq(actual.roster_units[index].attack_power, roundi(source.roster_units[index].attack_power * legacy_multiplier))
	# Pending placeholders also preserve Paris instead of temporarily replacing him.
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
		assert_eq(_room_signature(ExpeditionMapCatalog.get_room(index)), source_rooms[index], "Authored room %d unchanged" % index)
	for path: String in source_units:
		assert_eq(_unit_signature(load(path) as UnitData), source_units[path], path)


func test_serialized_route_nodes_rebuild_the_same_encounters_without_build_rubberbanding() -> void:
	for seed_value: int in SEEDS:
		for node: Dictionary in ExpeditionRouteCatalog.create_nodes(seed_value):
			if not ExpeditionRouteCatalog.is_combat(str(node.kind)): continue
			var restored := JSON.parse_string(JSON.stringify(node)) as Dictionary
			# These irrelevant fields deliberately describe opposite player states.
			restored["hero_hp"] = 1
			restored["hero_level"] = 14
			restored["equipment_power"] = 9999
			var before := ExpeditionRunFactory.make_room(node, seed_value).encounter_definition
			var after := ExpeditionRunFactory.make_room(restored, seed_value).encounter_definition
			assert_eq(after.encounter_id, before.encounter_id, "Stable reward/save identity")
			assert_eq(after.roster_units.map(_unit_signature), before.roster_units.map(_unit_signature))
			assert_eq(after.roster_counts, before.roster_counts)
			assert_eq(after.formation_profiles, before.formation_profiles)
