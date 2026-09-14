extends GutTest

const Contract = preload("res://tools/catabase_run_balance_validation/run_validation_contract.gd")
const Probe = preload("res://tools/catabase_run_balance_validation/full_run_probe.gd")


func test_contract_exposes_all_six_real_preparation_presets() -> void:
	assert_eq(Contract.weapon_ids(), ["arc", "disque", "hampe", "lame", "marteau", "xiphos"])
	for weapon: String in Contract.weapon_ids():
		assert_true(
			CatabasePreparationCatalog.valid(CatabasePreparationCatalog.preset(weapon)),
			weapon,
		)


func test_three_analysis_policies_are_explicit_and_bounded() -> void:
	assert_eq(Contract.policy_ids(), ["balanced", "pressure", "survival"])
	for policy: String in Contract.policy_ids():
		assert_between(float(Contract.POLICIES[policy].manual_item_hp_ratio), 0.0, 1.0)
		assert_false((Contract.POLICIES[policy].attribute_order as Array).is_empty())


func test_route_choice_is_stable_under_input_order_and_has_no_build_argument() -> void:
	var left := [
		{ "id": "d02_2", "depth": 2 },
		{ "id": "d02_0", "depth": 2 },
		{ "id": "d02_1", "depth": 2 },
	]
	var right := left.duplicate(true)
	right.reverse()
	assert_eq(Contract.choose_route_node(left, 2401, 2), Contract.choose_route_node(right, 2401, 2))


func test_metric_contract_separates_raw_resolved_and_hp_damage() -> void:
	var complete := { }
	for key: String in Contract.REQUIRED_COMBAT_METRICS:
		complete[key] = null
	assert_true(Contract.missing_metric_keys(complete).is_empty())
	complete.erase("raw_damage_received_known")
	assert_eq(Contract.missing_metric_keys(complete), ["raw_damage_received_known"])


func test_diagnostic_never_turns_a_policy_stall_into_a_balance_verdict() -> void:
	var stalled := {
		"termination": "turn_cap",
		"turns": 10,
		"idle_turns": 4,
		"resolved_damage_before_shield": 100,
		"resolved_damage_by_ability": { "one_spell": 100 },
	}
	assert_eq(Contract.classify_bot_outcome(false, stalled), "bot_limitation_suspected")
	var concentrated := stalled.duplicate(true)
	concentrated.termination = "hero_dead"
	concentrated.idle_turns = 0
	assert_eq(
		Contract.classify_bot_outcome(false, concentrated),
		"concentrated_matchup_pressure_to_review",
	)
	var oscillating := concentrated.duplicate(true)
	oscillating.turns = 20
	oscillating.hero_turn_position_repeats = 12
	assert_eq(Contract.classify_bot_outcome(false, oscillating), "bot_limitation_suspected")
	assert_not_null(Probe, "The complete-run probe must parse with its contract test")
