extends GutTest

const Factory = preload("res://test/support/factory.gd")
const CATABASE_RUN: RunData = preload("res://data/runs/odyssey.tres")
const HELLSPAWN_DATA: UnitData = preload(
	"res://data/units/enemies/catabase_frail_hellspawn.tres"
)


func test_opening_enemy_reads_as_a_weak_underworld_creature() -> void:
	var room := CATABASE_RUN.rooms[0]
	var encounter := room.encounter_definition
	assert_eq(room.room_name, "Catabase I — Le Rejeton chétif")
	assert_eq(room.enemies.size(), 1)
	assert_same(room.enemies[0], HELLSPAWN_DATA)
	assert_eq(HELLSPAWN_DATA.unit_id, &"catabase_frail_hellspawn")
	assert_eq(HELLSPAWN_DATA.unit_name, "Rejeton chétif des Enfers")
	assert_true(HELLSPAWN_DATA.description.contains("Faible créature infernale"))
	assert_false(HELLSPAWN_DATA.description.contains("PLACEHOLDER"))
	assert_eq(HELLSPAWN_DATA.team, 1)
	assert_lt(HELLSPAWN_DATA.max_hp, 110)
	assert_eq([HELLSPAWN_DATA.armure, HELLSPAWN_DATA.resist_magique], [0.0, 0.0])
	assert_eq(encounter.get_initial_enemy_count(), 1)
	assert_eq(encounter.living_enemy_cap, 1)
	assert_eq(encounter.roster_units, [HELLSPAWN_DATA])
	assert_eq(
		encounter.minimum_path_distance_by_role.get(
			HELLSPAWN_DATA.tactical_role_id
		),
		5,
	)
	assert_eq(
		encounter.maximum_path_distance_by_role.get(
			HELLSPAWN_DATA.tactical_role_id
		),
		7,
	)


func test_opening_enemy_spell_and_ai_ranges_share_one_contract() -> void:
	assert_eq(HELLSPAWN_DATA.ai_behavior, EnemyAI.BEHAVIOR_RANGED)
	assert_true(HELLSPAWN_DATA.keep_distance)
	assert_eq(
		[
			HELLSPAWN_DATA.minimum_range,
			HELLSPAWN_DATA.preferred_range,
			HELLSPAWN_DATA.maximum_range,
		],
		[3, 6, 7],
	)
	assert_false(HELLSPAWN_DATA.basic_attack_enabled)
	assert_eq(HELLSPAWN_DATA.spells.size(), 1)
	var spell := HELLSPAWN_DATA.spells[0]
	assert_eq(spell.spell_id, &"catabase_hellspawn_shadow_bolt")
	assert_eq([spell.minimum_range, spell.spell_range], [3, 7])
	assert_eq([spell.ap_cost, HELLSPAWN_DATA.max_ap], [4, 4])
	assert_eq(spell.damage, 18)
	assert_eq(spell.element, Spell.Element.SHADOW)
	assert_true(spell.needs_line_of_sight)
	assert_true(spell.once_per_activation)
	assert_eq(spell.delayed_resolution, Spell.DelayedResolution.RANGED_STRIKE)
	assert_true(spell.consumes_activation_on_resolution)
	assert_true(spell.telegraph_label.contains("ligne de vue"))
	assert_false(spell.telegraph_label.to_lower().contains("fatal"))


func test_ranged_ai_prepares_the_trait_when_achilles_is_in_opening_range() -> void:
	var field := Factory.make_battlefield(10, 1)
	var hellspawn := Unit.from_data(HELLSPAWN_DATA)
	var achilles := Unit.new("Achille", 0, 110)
	field.grid.place_unit(hellspawn, Vector2i(0, 0))
	field.grid.place_unit(achilles, Vector2i(6, 0))
	hellspawn.start_turn()
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)

	var plan := ai.decide(hellspawn, [hellspawn, achilles])

	assert_eq(plan.size(), 1, str(plan))
	assert_eq(plan[0].type, "cast")
	assert_eq(plan[0].spell, HELLSPAWN_DATA.spells[0])
	assert_eq(plan[0].cell, achilles.grid_pos)
	var report := field.caster.cast(
		hellspawn,
		plan[0].spell,
		plan[0].cell,
	)
	assert_false(report.get("failed", false), str(report))
	assert_true(report.get("telegraphed", false))
	assert_false(hellspawn.pending_ability.is_empty())
	assert_eq(achilles.current_hp, 110)


func test_opening_formation_is_valid_for_twenty_deterministic_seeds() -> void:
	var room := CATABASE_RUN.rooms[0]
	assert_true(
		room.encounter_definition.is_valid(),
		str(room.encounter_definition.validation_errors()),
	)
	var logical_size := room.grid_layout.logical_size
	var grid := GridData.new(logical_size.x, logical_size.y)
	room.grid_layout.apply_to_grid(grid)
	var planner := EncounterFormationPlanner.new(grid, Pathfinder.new(grid))
	for seed in range(20):
		var plan := planner.build_plan(
			room.encounter_definition,
			room.hero_spawn_zone,
			room.enemy_spawn_zone,
			seed,
		)
		assert_true(plan.get("valid", false), "seed %d : %s" % [seed, plan])
		assert_eq((plan.get("placements", []) as Array).size(), 1)
