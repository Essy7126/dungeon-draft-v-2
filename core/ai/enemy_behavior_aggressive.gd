# core/ai/enemy_behavior_aggressive.gd
class_name EnemyBehaviorAggressive
extends BossBehavior

func decide(enemy, all_units, ai) -> Array:
	return ai.default_attack_plan(enemy, all_units)