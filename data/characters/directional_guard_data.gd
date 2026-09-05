@tool
class_name DirectionalGuardData
extends Resource

@export_range(0.0, 3.0, 0.01) var front_damage_multiplier: float = 0.65
@export_range(0.0, 3.0, 0.01) var side_damage_multiplier: float = 1.15
@export_range(0.0, 3.0, 0.01) var rear_damage_multiplier: float = 1.15


func is_valid() -> bool:
	return is_finite(front_damage_multiplier) \
		and is_finite(side_damage_multiplier) \
		and is_finite(rear_damage_multiplier) \
		and front_damage_multiplier >= 0.0 \
		and side_damage_multiplier >= 0.0 \
		and rear_damage_multiplier >= 0.0
