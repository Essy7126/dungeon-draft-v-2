extends GutTest

const RUN: RunData = preload("res://data/runs/odyssey.tres")
const RUNNER = preload("res://tools/odyssey_validation_runner.gd")
const LEGACY_STRIKE: Spell = preload("res://data/spells/achilles/spear_thrust.tres")


func test_live_campaign_validation_uses_the_canonical_profile_loadout() -> void:
	var resolution := RunHeroResolver.resolve_runtime_hero_data(RUN, false)
	assert_true(resolution.is_valid(), str(resolution.errors))
	assert_eq(resolution.heroes.size(), 1)
	if not resolution.is_valid() or resolution.heroes.size() != 1:
		return
	var hero := resolution.heroes[0]
	assert_eq(hero.max_mp, 3, "the resolver keeps the canonical base UnitData movement points")
	assert_true(RUNNER.runtime_hero_contract_is_valid(RUN, hero))
	var state := CharacterRunState.new()
	assert_true(state.initialize(Unit.from_data(hero), hero, hero.active_spell_slots, hero.progression_profile))
	assert_eq(state.unit.max_mp.get_int(), 3, "champion initialization preserves the real three movement points")
	state.dispose()
	var stale := hero.duplicate(false) as UnitData
	stale.max_mp = 4
	assert_false(RUNNER.runtime_hero_contract_is_valid(RUN, stale))
	stale.max_mp = hero.max_mp
	stale.spells = hero.spells.duplicate()
	stale.spells[0] = LEGACY_STRIKE
	assert_false(RUNNER.runtime_hero_contract_is_valid(RUN, stale))
	assert_true(RUNNER.runtime_hero_contract_is_valid(RUN, hero), "checking a stale copy does not change production")


func test_current_five_room_run_requires_four_claims_and_eight_reward_options() -> void:
	assert_eq(RUNNER.expected_transition_counts(RUN), {
		"completed_rooms": 5, "reward_options_seen": 8, "relics_claimed": 4,
	})
	assert_string_contains(RUN.content_profile.description, "cinq rencontres")


func test_transition_expectations_follow_room_count_instead_of_a_three_room_constant() -> void:
	for room_count in [1, 3, 7]:
		var run := RunData.new()
		for _index in range(room_count):
			run.rooms.append(RoomData.new())
		var expected: Dictionary = RUNNER.expected_transition_counts(run)
		assert_eq(expected.completed_rooms, room_count)
		assert_eq(expected.reward_options_seen, 2 * (room_count - 1))
		assert_eq(expected.relics_claimed, room_count - 1)
