extends GutTest

const Factory = preload("res://test/support/factory.gd")
const SPECTRE: UnitData = preload("res://data/units/enemies/spectre_greatsword.tres")
const CLEAVE: Spell = preload("res://data/spells/enemies/spectre_heavy_cleave.tres")
const CATABASE: RunData = preload("res://data/runs/odyssey.tres")
const COURTYARD: EncounterDefinition = preload(
	"res://data/arenas/greek_drawn_courtyard_v1/encounter.tres"
)


func test_spectre_is_an_independent_normal_enemy_with_matching_preview() -> void:
	assert_eq(SPECTRE.unit_name, "Spectre errant")
	assert_eq([SPECTRE.team, SPECTRE.max_hp, SPECTRE.max_ap, SPECTRE.max_mp], [1, 64, 2, 3])
	assert_eq(SPECTRE.ai_profile.strategy, EnemyAIProfile.Strategy.GENERIC_MELEE)
	assert_eq(SPECTRE.ai_behavior, EnemyAI.BEHAVIOR_MELEE)
	assert_eq(SPECTRE.tactical_role_id, &"spectre_greatsword")
	assert_eq(SPECTRE.faction_id, &"catabase_underworld")
	assert_eq(SPECTRE.linked_commander_role_id, &"")
	assert_eq(SPECTRE.proximity_armor_per_living_neighbor, 0)
	assert_eq(SPECTRE.proximity_armor_max_neighbors, 0)
	assert_false(SPECTRE.ai_profile.prefer_living_neighbors)
	assert_false(SPECTRE.basic_attack_enabled)
	assert_null(SPECTRE.preview_visual_scene)
	assert_not_null(SPECTRE.preview_sprite_frames)
	assert_eq(SPECTRE.preview_sprite_animation, &"idle_E")
	assert_true(SPECTRE.preview_sprite_frames.has_animation(&"idle_E"))
	assert_eq(SPECTRE.spells, [CLEAVE])
	assert_eq(SPECTRE.animation_set.get_animation_name(&"cast:spectre_heavy_cleave"), &"attack")


func test_heavy_cleave_is_a_physical_adjacent_strike_with_no_extra_delay() -> void:
	assert_eq([CLEAVE.ap_cost, CLEAVE.minimum_range, CLEAVE.spell_range], [2, 1, 1])
	assert_eq(CLEAVE.damage, 18)
	assert_eq(CLEAVE.damage_type, Spell.DamageType.PHYSICAL)
	assert_eq(CLEAVE.visual_action, Spell.VisualAction.HEAVY)
	assert_eq(CLEAVE.impact_delay_seconds, 0.0, "The visual release is the sole impact clock.")
	assert_eq(CLEAVE.delayed_resolution, Spell.DelayedResolution.NONE)
	assert_eq(CLEAVE.caster_movement, Spell.CasterMovement.NONE)
	assert_false(CLEAVE.can_target_self)
	assert_false(CLEAVE.can_target_ally)
	assert_false(CLEAVE.can_target_free_cell)
	assert_eq(CLEAVE.bonus_damage_if_marked, 0)
	assert_eq(CLEAVE.push_distance, 0)


func test_adjacent_ai_spends_two_ap_on_exactly_one_cleave() -> void:
	var field := Factory.make_battlefield(3, 1)
	var spectre := Unit.from_data(SPECTRE)
	var hero := Unit.new("Achille", 0, 110)
	field.grid.place_unit(spectre, Vector2i(0, 0))
	field.grid.place_unit(hero, Vector2i(1, 0))
	spectre.start_turn()
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	var plan := ai.decide(spectre, [spectre, hero])
	assert_eq(_action_types(plan), ["cast"])
	if plan.size() != 1:
		return
	assert_same(plan[0].spell, CLEAVE)
	var report := field.caster.cast(spectre, CLEAVE, hero.grid_pos)
	assert_false(report.get("failed", false), str(report))
	assert_eq(hero.current_hp, 92)
	assert_eq(spectre.current_ap, 0)
	assert_true(ai.decide(spectre, [spectre, hero]).is_empty(), "No hidden basic attack follows the spell.")


func test_ai_plans_legal_approach_and_cleave_in_the_same_activation() -> void:
	var field := Factory.make_battlefield(5, 1)
	var spectre := Unit.from_data(SPECTRE)
	var hero := Unit.new("Achille", 0, 110)
	field.grid.place_unit(spectre, Vector2i(0, 0))
	field.grid.place_unit(hero, Vector2i(4, 0))
	spectre.start_turn()
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	var plan := ai.decide(spectre, [spectre, hero])
	assert_eq(_action_types(plan), ["move", "cast"])
	assert_eq(spectre.grid_pos, Vector2i(0, 0), "Planning must not move the model or alter occupancy.")
	assert_eq(spectre.current_mp, 3)
	assert_eq(spectre.current_ap, 2)
	if plan.size() != 2:
		return
	var path: Array = plan[0].path
	assert_eq(path, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])
	var cost := field.pathfinder.path_movement_cost(path, spectre)
	assert_eq(cost, 3)
	assert_true(spectre.spend_mp(cost))
	for index in range(1, path.size()):
		assert_true(field.grid.is_walkable(path[index], spectre))
		field.grid.move_unit(spectre.grid_pos, path[index])
	assert_true(field.caster.can_cast(spectre, plan[1].spell, plan[1].cell))
	var report := field.caster.cast(spectre, plan[1].spell, plan[1].cell)
	assert_false(report.get("failed", false), str(report))
	assert_eq([spectre.current_mp, spectre.current_ap, hero.current_hp], [0, 0, 92])


func test_approach_does_not_plan_a_cut_beyond_range_or_without_ap() -> void:
	var field := Factory.make_battlefield(7, 1)
	var spectre := Unit.from_data(SPECTRE)
	var hero := Unit.new("Achille", 0, 110)
	field.grid.place_unit(spectre, Vector2i(0, 0))
	field.grid.place_unit(hero, Vector2i(6, 0))
	spectre.start_turn()
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	assert_eq(_action_types(ai.decide(spectre, [spectre, hero])), ["move"])
	field.grid.move_unit(hero.grid_pos, Vector2i(4, 0))
	spectre.current_ap = 1
	assert_eq(_action_types(ai.decide(spectre, [spectre, hero])), ["move"])


func test_levitation_does_not_cross_holes_or_walls() -> void:
	for blocked_type in [GridData.CellType.HOLE, GridData.CellType.WALL]:
		var field := Factory.make_battlefield(5, 1)
		var spectre := Unit.from_data(SPECTRE)
		var hero := Unit.new("Achille", 0, 110)
		field.grid.place_unit(spectre, Vector2i(0, 0))
		field.grid.place_unit(hero, Vector2i(4, 0))
		field.grid.set_type(Vector2i(2, 0), blocked_type)
		spectre.start_turn()
		var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
		assert_false(field.grid.is_walkable(Vector2i(2, 0), spectre))
		assert_true(field.pathfinder.find_path(spectre.grid_pos, Vector2i(3, 0), spectre).is_empty())
		assert_true(ai.decide(spectre, [spectre, hero]).is_empty(), str(blocked_type))


func test_levitation_does_not_cross_an_occupied_chokepoint() -> void:
	var field := Factory.make_battlefield(5, 1)
	var spectre := Unit.from_data(SPECTRE)
	var hero := Unit.new("Achille", 0, 110)
	var ally := Unit.new("Bloqueur", 1, 100)
	field.grid.place_unit(spectre, Vector2i(0, 0))
	field.grid.place_unit(ally, Vector2i(2, 0))
	field.grid.place_unit(hero, Vector2i(4, 0))
	spectre.start_turn()
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	assert_true(ai.decide(spectre, [spectre, hero, ally]).is_empty())
	assert_same(field.grid.get_unit(Vector2i(2, 0)), ally)


func test_planned_cut_is_revalidated_after_target_or_ap_changes() -> void:
	var field := Factory.make_battlefield(5, 2)
	var spectre := Unit.from_data(SPECTRE)
	var hero := Unit.new("Achille", 0, 110)
	field.grid.place_unit(spectre, Vector2i(0, 0))
	field.grid.place_unit(hero, Vector2i(4, 0))
	spectre.start_turn()
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	var plan := ai.decide(spectre, [spectre, hero])
	assert_eq(_action_types(plan), ["move", "cast"])
	if plan.size() != 2:
		return
	var path: Array = plan[0].path
	for index in range(1, path.size()):
		field.grid.move_unit(spectre.grid_pos, path[index])
	var planned_cell: Vector2i = plan[1].cell
	field.grid.move_unit(hero.grid_pos, Vector2i(4, 1))
	assert_false(field.caster.can_cast(spectre, CLEAVE, planned_cell), "An empty destination cannot receive the cut.")
	assert_false(field.caster.can_cast(spectre, CLEAVE, hero.grid_pos), "A target outside melee range cannot receive the cut.")
	field.grid.move_unit(hero.grid_pos, planned_cell)
	spectre.current_ap = 1
	assert_false(field.caster.can_cast(spectre, CLEAVE, planned_cell))
	spectre.current_ap = 2
	assert_true(field.caster.can_cast(spectre, CLEAVE, planned_cell))
	var ally := Unit.new("Allié du spectre", 1, 100)
	field.grid.clear_unit(hero.grid_pos)
	field.grid.place_unit(ally, planned_cell)
	assert_false(field.caster.can_cast(spectre, CLEAVE, planned_cell), "An ally occupying the cell is not a valid replacement target.")
	assert_eq(spectre.current_ap, 2, "Validation itself spends no resources.")


func test_existing_basic_melee_keeps_its_move_and_attack_plan() -> void:
	var field := Factory.make_battlefield(5, 1)
	var guard_data := load("res://data/units/enemies/odyssey_guard.tres") as UnitData
	var guard := Unit.from_data(guard_data)
	var hero := Unit.new("Achille", 0, 110)
	field.grid.place_unit(guard, Vector2i(0, 0))
	field.grid.place_unit(hero, Vector2i(4, 0))
	guard.start_turn()
	var ai := EnemyAI.new(field.grid, field.pathfinder, field.caster)
	assert_eq(_action_types(ai.decide(guard, [guard, hero])), ["move", "attack"])


func test_one_spectre_is_accessible_in_catabase_and_the_greek_courtyard() -> void:
	assert_eq(_roster_ids(COURTYARD), [&"odyssey_skirmisher", &"spectre_greatsword"])
	assert_true(COURTYARD.is_valid(), str(COURTYARD.validation_errors()))
	var room := CATABASE.rooms[1]
	var expected: Array[StringName] = [&"odyssey_skirmisher", &"odyssey_skirmisher", &"spectre_greatsword"]
	assert_eq(_roster_ids(room.encounter_definition), expected)
	assert_eq(_unit_ids(room.enemies), expected, "Authoring fallback and authoritative encounter agree.")
	assert_eq(room.encounter_definition.living_enemy_cap, 3)
	assert_eq(room.encounter_definition.encounter_id, &"catabase_room_02")
	assert_eq(_roster_ids(CATABASE.rooms[0].encounter_definition), [&"catabase_frail_hellspawn"])
	for profile_path in [
		"res://data/arenas/greek_drawn_courtyard_v1/presentation.tres",
		"res://data/arenas/ashen_hell_courtyard_v1/presentation.tres",
	]:
		var profile := load(profile_path) as BattlePresentationProfile
		assert_not_null(profile.profile_for_unit(&"spectre_greatsword"))
		assert_true(profile.validation_errors().is_empty(), str(profile.validation_errors()))


func test_catabase_spectre_formation_is_valid_across_twelve_seeds() -> void:
	var room := CATABASE.rooms[1]
	var logical_size := room.grid_layout.logical_size
	var grid := GridData.new(logical_size.x, logical_size.y)
	room.grid_layout.apply_to_grid(grid)
	var planner := EncounterFormationPlanner.new(grid, Pathfinder.new(grid))
	for seed_value in range(12):
		var plan := planner.build_plan(room.encounter_definition, room.hero_spawn_zone, room.enemy_spawn_zone, seed_value)
		assert_true(plan.get("valid", false), "seed %d: %s" % [seed_value, plan])
		assert_eq((plan.get("placements", []) as Array).size(), 3)


func _action_types(plan: Array) -> Array[String]:
	var result: Array[String] = []
	for action in plan:
		result.append(str(action.get("type", "")))
	return result


func _roster_ids(encounter: EncounterDefinition) -> Array[StringName]:
	return _unit_ids(encounter.expanded_roster())


func _unit_ids(roster: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in roster:
		result.append((value as UnitData).get_effective_unit_id())
	return result
