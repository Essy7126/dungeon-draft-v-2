@tool
class_name TemporaryBarrierData
extends Resource

const EXPIRY_UNTIL_NEXT_ACTIVATION: StringName = &"UNTIL_NEXT_ACTIVATION"

@export_range(1, 9, 1) var line_length: int = 3
@export var blocks_projectiles: bool = true
@export_range(0, 9, 1) var enemy_movement_surcharge: int = 1
@export var expiry_scope: StringName = EXPIRY_UNTIL_NEXT_ACTIVATION
@export_range(0.0, 1.0, 0.01) var personal_shield_multiplier: float = 0.75


func is_valid() -> bool:
	return line_length > 0 and enemy_movement_surcharge >= 0 \
		and expiry_scope == EXPIRY_UNTIL_NEXT_ACTIVATION \
		and is_finite(personal_shield_multiplier) \
		and personal_shield_multiplier >= 0.0 \
		and personal_shield_multiplier <= 1.0
