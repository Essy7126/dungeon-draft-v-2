class_name CatabaseRunValidationContract
extends RefCounted
## Pure contract shared by the headless probe and its unit tests.
## It deliberately contains no enemy selection based on the hero build.

const SCHEMA_VERSION := 1
const ROUTE_POLICY_ID := "seeded_lane_v1"
const EXPECTED_COMBAT_DEPTHS: Array[int] = [1, 2, 3, 5, 6, 8, 10, 12, 13, 15, 17, 20]
const DEFAULT_SEEDS: Array[int] = [2401]
const DIFFICULTIES: Array[String] = ["normal", "easy"]
const POLICIES: Dictionary = {
	"balanced": {
		"attribute_order": [&"vitality", &"power", &"resolve"],
		"manual_item_hp_ratio": 0.32,
		"reward_priority": ["supplies", "relic:", "discover:", "spell:", "item:"],
	},
	"survival": {
		"attribute_order": [&"vitality"],
		"manual_item_hp_ratio": 0.52,
		"reward_priority": ["supplies", "relic:", "item:", "discover:", "spell:"],
	},
	"pressure": {
		"attribute_order": [&"power", &"vitality"],
		"manual_item_hp_ratio": 0.22,
		"reward_priority": ["discover:", "spell:", "relic:", "supplies", "item:"],
	},
}
const REQUIRED_COMBAT_METRICS: Array[String] = [
	"depth",
	"node_id",
	"hp_entry",
	"hp_after_combat",
	"hp_after_level",
	"hp_after_provisions",
	"hp_after_refuge",
	"level_entry",
	"level_after",
	"raw_damage_received_known",
	"resolved_damage_before_shield",
	"hp_damage_received",
	"turns",
	"seconds",
	"death_cause",
]


static func weapon_ids() -> Array[String]:
	var result: Array[String] = []
	for weapon: String in CatabasePreparationCatalog.WEAPONS:
		result.append(weapon)
	result.sort()
	return result


static func policy_ids() -> Array[String]:
	var result: Array[String] = []
	for policy: String in POLICIES:
		result.append(policy)
	result.sort()
	return result


static func choose_route_node(available: Array, seed_value: int, depth: int) -> Dictionary:
	if available.is_empty():
		return { }
	var ordered: Array[Dictionary] = []
	for value in available:
		if value is Dictionary:
			ordered.append((value as Dictionary).duplicate(true))
	ordered.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("id", "")) < str(right.get("id", "")),
	)
	if ordered.is_empty():
		return { }
	# Only the public seed and the destination depth choose a lane. Weapon,
	# current HP, inventory and prior combat performance are absent by design.
	var index := posmod(seed_value * 31 + depth * 17, ordered.size())
	return ordered[index].duplicate(true)


static func reward_matches(option_id: String, selector: String) -> bool:
	return option_id == selector or (selector.ends_with(":") and option_id.begins_with(selector))


static func classify_bot_outcome(won: bool, metrics: Dictionary) -> String:
	if won:
		return "room_cleared"
	var termination := str(metrics.get("termination", ""))
	var turns := maxi(1, int(metrics.get("turns", 0)))
	var idle_ratio := float(metrics.get("idle_turns", 0)) / float(turns)
	var repeat_ratio := float(metrics.get("hero_turn_position_repeats", 0)) / float(turns)
	if termination in ["turn_cap", "activation_cap", "policy_stall"] \
			or idle_ratio >= 0.25 \
			or (turns >= 8 and repeat_ratio >= 0.35):
		return "bot_limitation_suspected"
	var total := maxi(0, int(metrics.get("resolved_damage_before_shield", 0)))
	var largest := 0
	for value in (metrics.get("resolved_damage_by_ability", { }) as Dictionary).values():
		largest = maxi(largest, int(value))
	if total > 0 and float(largest) / float(total) >= 0.55:
		return "concentrated_matchup_pressure_to_review"
	return "bot_combat_loss"


static func missing_metric_keys(metrics: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: String in REQUIRED_COMBAT_METRICS:
		if not metrics.has(key):
			result.append(key)
	return result
