@tool
class_name ItemReactiveEffectData
extends Resource

const TRIGGER_COMBAT_START: StringName = &"combat_start"
const TRIGGER_TURN_START: StringName = &"turn_start"
const TRIGGER_TURN_END: StringName = &"turn_end"
const TRIGGER_ACTION_RESOLVED: StringName = &"action_resolved"
const TRIGGER_AP_AFTER_ACTION: StringName = &"ap_after_action"
const TRIGGER_VOLUNTARY_MOVE_PREPARED: StringName = &"voluntary_move_prepared"
const TRIGGER_VOLUNTARY_MOVE_RESOLVED: StringName = &"voluntary_move_resolved"
const TRIGGER_HP_LOST: StringName = &"hp_lost"
const TRIGGER_HP_THRESHOLD_CROSSED: StringName = &"hp_threshold_crossed"
const TRIGGER_UNIT_KILLED: StringName = &"unit_killed"
const TRIGGER_ADJACENT_ENEMY_TURN_END: StringName = &"adjacent_enemy_turn_end"

const TARGET_TRIGGER_HERO: StringName = &"trigger_hero"
const TARGET_DAMAGE_SOURCE: StringName = &"damage_source"
const TARGET_KILLED_UNIT: StringName = &"killed_unit"
const TARGET_ACTIVE_UNIT: StringName = &"active_unit"
const TARGET_ALL_CONTROLLED_HEROES: StringName = &"all_controlled_heroes"

const RESULT_CURRENT_AP: StringName = &"current_ap"
const RESULT_NEXT_TURN_AP: StringName = &"next_turn_ap"
const RESULT_CURRENT_MP: StringName = &"current_mp"
const RESULT_NEXT_TURN_MP: StringName = &"next_turn_mp"
const RESULT_HEAL_FLAT: StringName = &"heal_flat"
const RESULT_HEAL_MAX_HP_PERCENT: StringName = &"heal_max_hp_percent"
const RESULT_PAY_HP_FLAT: StringName = &"pay_hp_flat"
const RESULT_PAY_HP_PERCENT: StringName = &"pay_hp_percent"
const RESULT_REDUCE_VOLUNTARY_MOVE_COST: StringName = &"reduce_voluntary_move_cost"
const RESULT_CANCEL_IN_PROGRESS: StringName = &"cancel_in_progress"

const FREQUENCY_UNLIMITED: StringName = &"unlimited"
const FREQUENCY_ACTION: StringName = &"per_action"
const FREQUENCY_TURN: StringName = &"per_turn"
const FREQUENCY_ROUND: StringName = &"per_round"
const FREQUENCY_COMBAT: StringName = &"per_combat"
const FREQUENCY_COOLDOWN_TURNS: StringName = &"cooldown_turns"

@export var enabled := true
@export var trigger_id: StringName = TRIGGER_COMBAT_START
@export var conditions: Array[ItemReactiveConditionData] = []
@export var target_id: StringName = TARGET_TRIGGER_HERO
@export var result_id: StringName = RESULT_HEAL_FLAT
@export var value := 1.0
@export var threshold := 0.5
@export var frequency_id: StringName = FREQUENCY_UNLIMITED
@export_range(1, 99, 1) var max_activations := 1
@export_range(1, 99, 1) var recharge_turns := 1


func is_structurally_valid() -> bool:
	if trigger_id == &"" or target_id == &"" or result_id == &"" \
			or frequency_id == &"" or not is_finite(value) \
			or not is_finite(threshold) or max_activations <= 0:
		return false
	if frequency_id == FREQUENCY_COOLDOWN_TURNS and recharge_turns <= 0:
		return false
	for condition in conditions:
		if condition == null or not condition.is_valid():
			return false
	return true

