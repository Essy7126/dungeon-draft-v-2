extends GutTest

const Lab = preload("res://tools/build_system_lab/card_experiments.gd")
const Factory = preload("res://test/support/factory.gd")
const Cleanup = preload("res://test/support/isolated_battlefield_cleanup.gd")
const PROFILE: ChampionProgressionProfile = preload(
	"res://data/runs/progression/odyssey/achilles_champion_progression_v0.tres"
)
var fields: Array = []


func _field():
	var field = Factory.make_battlefield(9, 7)
	fields.append(field)
	return field


func _actor(team := 0) -> Unit:
	var actor := Factory.make_unit("Lab", team)
	actor.attack_power.base_value = 100
	actor.max_hp.base_value = 600
	actor.current_hp = 600
	return actor


func after_each() -> void:
	for field in fields:
		for actor: Unit in field.grid.get_units():
			actor.clear_combat_effect_history()
		field.terrain.dispose()
		Cleanup.dispose_grid(field.grid)
	fields.clear()


func test_cards_are_independent_and_mastery_does_not_change_discrete_values() -> void:
	for id: String in Lab.IDS:
		var borrowed: Spell = Lab.make_card(id, 0, 100)
		var expert: Spell = Lab.make_card(id, 4, 100)
		assert_not_null(borrowed)
		assert_eq(borrowed.ap_cost, expert.ap_cost, id)
		assert_eq(borrowed.spell_range, expert.spell_range, id)
		assert_eq(borrowed.push_distance, expert.push_distance, id)
		assert_ne(borrowed, expert)
		if borrowed.applied_status != null:
			assert_eq(borrowed.applied_status.duration, expert.applied_status.duration)
			assert_eq(borrowed.applied_status.mp_reduction, expert.applied_status.mp_reduction)
			borrowed.applied_status.duration = 99
			assert_eq(expert.applied_status.duration, 1)
	assert_null(Lab.make_card("unknown", 0, 100))
	assert_null(Lab.make_card("shot", 5, 100))


func test_opening_then_finish_changes_damage_in_the_real_caster() -> void:
	var f = _field()
	var hero := _actor()
	var enemy := _actor(1)
	f.grid.place_unit(hero, Vector2i(2, 2))
	f.grid.place_unit(enemy, Vector2i(3, 2))
	var initial := enemy.current_hp
	assert_false(f.caster.cast(hero, Lab.make_card("opening", 0, 100), enemy.grid_pos).get(
			"failed",
			false,
		))
	assert_false(f.caster.cast(hero, Lab.make_card("finish", 0, 100), enemy.grid_pos).get(
			"failed",
			false,
		))
	assert_eq(initial - enemy.current_hp, 170, "35 + 80 + 55, no defense")
	assert_eq(hero.current_ap, 3, "The setup actually costs one AP")


func test_guard_expires_on_owners_activation_and_does_not_stack() -> void:
	var f = _field()
	var hero := _actor()
	f.grid.place_unit(hero, Vector2i(2, 2))
	var spell: Spell = Lab.make_card("guard", 0, 100)
	assert_false(f.caster.cast(hero, spell, hero.grid_pos).get("failed", false))
	assert_eq(hero.current_shield, 89, "65 % P + 4 % HP")
	assert_true(f.caster.cast(hero, spell, hero.grid_pos).get("failed", false))
	assert_eq(hero.current_shield, 89)
	hero.start_turn()
	assert_eq(hero.current_shield, 0)


func test_foreign_push_repositions_a_real_enemy() -> void:
	var f = _field()
	var hero := _actor()
	var enemy := _actor(1)
	f.grid.place_unit(hero, Vector2i(2, 2))
	f.grid.place_unit(enemy, Vector2i(3, 2))
	assert_false(f.caster.cast(hero, Lab.make_card("repel", 0, 100), enemy.grid_pos).get(
			"failed",
			false,
		))
	assert_eq(enemy.grid_pos, Vector2i(4, 2))
	assert_eq(enemy.current_hp, 525)


func test_step_then_shot_opens_a_previously_illegal_range() -> void:
	var f = _field()
	var hero := _actor()
	var enemy := _actor(1)
	f.grid.place_unit(hero, Vector2i(2, 2))
	f.grid.place_unit(enemy, Vector2i(3, 2))
	var shot: Spell = Lab.make_card("shot", 0, 100)
	assert_true(f.caster.cast(hero, shot, enemy.grid_pos).get("failed", false))
	assert_eq(hero.current_ap, 6, "Invalid targeting must not pay")
	assert_false(f.caster.cast(hero, Lab.make_card("step", 0, 100), Vector2i(1, 2)).get(
			"failed",
			false,
		))
	assert_false(f.caster.cast(hero, shot, enemy.grid_pos).get("failed", false))
	assert_eq(hero.current_ap, 3)
	assert_eq(enemy.current_hp, 500)


func test_frost_reduces_one_enemy_movement_activation() -> void:
	var f = _field()
	var hero := _actor()
	var enemy := _actor(1)
	f.grid.place_unit(hero, Vector2i(1, 2))
	f.grid.place_unit(enemy, Vector2i(3, 2))
	assert_false(f.caster.cast(hero, Lab.make_card("frost", 0, 100), enemy.grid_pos).get(
			"failed",
			false,
		))
	enemy.start_turn()
	enemy.process_statuses()
	assert_eq(enemy.current_mp, 2)
	enemy.tick_statuses()
	enemy.start_turn()
	enemy.process_statuses()
	assert_eq(enemy.current_mp, 3)


func test_blast_hits_two_targets_without_hitting_caster() -> void:
	var f = _field()
	var hero := _actor()
	var enemy := _actor(1)
	var other := _actor(1)
	f.grid.place_unit(hero, Vector2i(2, 2))
	f.grid.place_unit(enemy, Vector2i(3, 2))
	f.grid.place_unit(other, Vector2i(4, 2))
	assert_false(f.caster.cast(hero, Lab.make_card("blast", 0, 100), enemy.grid_pos).get(
			"failed",
			false,
		))
	assert_eq(enemy.current_hp, 520)
	assert_eq(other.current_hp, 520)
	assert_eq(hero.current_hp, 600)
	assert_eq(hero.current_ap, 3)


func test_mastery_crosses_a_kill_threshold_with_identical_targeting_and_cost() -> void:
	for rank in [2, 4]:
		var f = _field()
		var hero := _actor()
		var enemy := _actor(1)
		enemy.current_hp = 90
		enemy.armure.base_value = 50
		f.grid.place_unit(hero, Vector2i(1, 2))
		f.grid.place_unit(enemy, Vector2i(3, 2))
		assert_false(f.caster.cast(hero, Lab.make_card("shot", rank, 100), enemy.grid_pos).get(
				"failed",
				false,
			))
		assert_eq(hero.current_ap, 4)
		assert_eq(enemy.is_alive, rank == 2)
		if rank == 2:
			assert_eq(enemy.current_hp, 10)


func test_two_attack_actions_are_legal_but_control_cannot_repeat() -> void:
	var f = _field()
	var hero := _actor()
	var enemy := _actor(1)
	f.grid.place_unit(hero, Vector2i(1, 2))
	f.grid.place_unit(enemy, Vector2i(3, 2))
	for copy in 2:
		assert_false(f.caster.cast(hero, Lab.make_card("shot", 0, 100), enemy.grid_pos).get(
				"failed",
				false,
			))
	assert_eq(hero.current_ap, 2)
	assert_eq(enemy.current_hp, 400)
	# This tests action availability only; deck ownership remains CatabaseCards' job.


func test_export_actual_route_catalog_xp_and_lab_breakpoints() -> void:
	var report := {
		"schema": 1,
		"scope": "audit and isolated spell experiments; not simulated wins",
		"routes": [],
		"progression": [],
		"catalog": [],
		"lab_values": [],
	}
	for seed_value in [2401, 7126, 19073]:
		var nodes := ExpeditionRouteCatalog.create_nodes(seed_value)
		var rows := []
		for node in nodes:
			rows.append(
				{
					"id": node.id,
					"depth": node.depth,
					"kind": node.kind,
					"family": node.route_family,
					"hidden": node.hidden,
					"edges": node.edges,
					"xp": ExpeditionRunFactory.xp_for(node),
				}
			)
		report.routes.append({ "seed": seed_value, "nodes": rows })
	for policy in ["power", "wisdom_then_power"]:
		var hero := _actor()
		var state := ChampionProgressionState.new()
		var profile := PROFILE.duplicate(false) as ChampionProgressionProfile
		profile.mastery_point_levels = PackedInt32Array()
		profile.purchased_mastery_cap = 0
		assert_true(state.initialize(profile, hero))
		var rows := []
		for node in report.routes[0].nodes:
			if node.xp <= 0 or node.family not in ["common", "airain"]:
				continue
			state.begin_encounter()
			var before := state.current_level
			var gain := state.award_encounter_xp(StringName(node.id), node.xp, true)
			assert_true(gain.get("granted", false), str(gain))
			while state.unspent_attribute_points > 0:
				var stat: StringName = (
					&"wisdom"
					if (policy == "wisdom_then_power" and state.wisdom_points < 5)
					else &"power"
				)
				assert_true(state.spend_attribute(stat))
			rows.append(
				{
					"depth": node.depth,
					"level_before": before,
					"level_after": state.current_level,
					"xp": state.current_xp,
					"prowess": hero.attack_power.get_int(),
					"hp": hero.max_hp.get_int(),
					"wisdom": state.wisdom_points,
					"power": state.power_points,
				}
			)
		report.progression.append({ "policy": policy, "rows": rows })
		state.dispose()
	var total := 0
	var halt_points := 0
	for depth in ExpeditionBuildState.DEPTH_POINTS:
		var points: int = ExpeditionBuildState.DEPTH_POINTS[depth]
		total += points
		var row: Array = report.routes[0].nodes.filter(
			func(n):
				return n.depth == depth,
		)
		if row.all(
			func(n):
				return n.xp == 0,
		):
			halt_points += points
	report["legacy_points"] = { "total": total, "on_noncombat_depths": halt_points }
	var catalog := ExpeditionBuildCatalog.new()
	for id in catalog.card_spell_ids():
		var spell := catalog.get_spell(id)
		assert_not_null(spell, id)
		if spell == null:
			continue
		report.catalog.append(
			{
				"id": id,
				"axis": catalog.get_spell_axis(id),
				"cost": spell.ap_cost,
				"has_card_rarity": CatabaseCards.RARITIES.has(id),
				"damage_at_P18_HP110": SpellScalingResolver.resolve_from_values(
					spell.damage_scaling,
					18,
					110,
					1,
					spell.damage,
				),
				"damage_at_P100_HP600": SpellScalingResolver.resolve_from_values(
					spell.damage_scaling,
					100,
					600,
					10,
					spell.damage,
				),
			}
		)
	for level in [1, 5, 10, 13]:
		for rank in [0, 2, 4]:
			var p := PROFILE.base_prowess_for_level(level)
			var hp := PROFILE.base_hp_for_level(level)
			for id: String in Lab.IDS:
				var spell: Spell = Lab.make_card(id, rank, p)
				var raw := SpellScalingResolver.resolve_from_values(
					spell.damage_scaling,
					p,
					hp,
					level,
					spell.damage,
				)
				var target := _actor(1)
				target.armure.base_value = 50
				target.resist_magique.base_value = 50
				var hit := DamageResolver.HitContext.new()
				hit.raw_damage = raw
				hit.category = spell.damage_type
				hit.element = spell.element
				report.lab_values.append(
					{
						"id": id,
						"level": level,
						"mastery": rank,
						"raw": raw,
						"after_50_defense": DamageResolver.compute(target, hit).amount,
						"shield": SpellScalingResolver.resolve_from_values(
							spell.shield_scaling,
							p,
							hp,
							level,
							spell.shield_grant,
						),
					}
				)
	var hashes := { }
	for path in [
		"core/expedition/catabase_route_v6.gd",
		"core/expedition/expedition_run_factory.gd",
		"core/expedition/expedition_build_state.gd",
		"core/expedition/expedition_build_catalog.gd",
		"core/expedition/catabase_cards.gd",
		"core/damage_resolver.gd",
		"core/spell_scaling_resolver.gd",
		"core/spell_caster.gd",
		"units/unit.gd",
		"characters/progression/champion_progression_state.gd",
		"data/runs/progression/champion_progression_profile.gd",
		"data/runs/progression/odyssey/achilles_champion_progression_v0.tres",
		"tools/build_system_lab/card_experiments.gd",
		"test/unit/test_build_system_lab.gd",
	]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	report["source_sha256"] = hashes
	var output := "res://artifacts/dev/build_system_lab"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output + "/engine_audit.json", FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
