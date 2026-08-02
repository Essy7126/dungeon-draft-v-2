class_name PostCombatRewardData
extends Resource

enum RewardType {
	TEAM_HEAL_PERCENT,
	HERO_MAX_HP,
	NEXT_COMBAT_SHIELD,
}

enum TargetPolicy {
	TEAM,
	EXPLICIT_HERO,
}

@export var reward_id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D = null
@export var reward_type: RewardType = RewardType.TEAM_HEAL_PERCENT
@export var value := 0.0
@export var target_policy: TargetPolicy = TargetPolicy.TEAM


func is_valid() -> bool:
	return reward_id != &"" and display_name != "" and value > 0.0
