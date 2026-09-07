@tool
class_name MasterySpellModifierData
extends SpellModifier

## Transformations statiques et inspectables. Les effets conditionnels ou
## temporels appartiennent a MasteryReactiveEffectData.
enum EffectType {
	DAMAGE_MULTIPLIER,
	SHIELD_MULTIPLIER,
	RANGE_DELTA,
	RANGE_BOUNDS,
	PUSH_DISTANCE,
	IGNORE_ARMOR_FLAT,
	LINE_TARGETS,
	FAN_TARGETS,
	PIERCING_ENABLED,
	ENGAGEMENT_PENALTY_IGNORE,
	GUARD_ARMOR,
	PUSH_IMMUNITY,
	PULL_IMMUNITY,
	CONDITIONAL_BONUS_SCALE,
	MOVEMENT_THRESHOLD_DELTA,
}

@export var effect_type: EffectType = EffectType.DAMAGE_MULTIPLIER
@export var multiplier: float = 1.0
@export var flat_value: int = 0
@export var minimum_range: int = -1
@export var maximum_range: int = -1
@export_range(0, 9, 1) var maximum_targets: int = 0
@export var target_multipliers: PackedFloat32Array = PackedFloat32Array()
@export var enabled_value: bool = true
@export var minimum_value: int = 0


func get_range_bonus(_caster, _spell) -> int:
	return flat_value if effect_type == EffectType.RANGE_DELTA else 0


func is_structurally_valid() -> bool:
	if not is_finite(multiplier) or multiplier < 0.0:
		return false
	match effect_type:
		EffectType.RANGE_BOUNDS:
			return minimum_range >= 0 and maximum_range >= minimum_range
		EffectType.LINE_TARGETS, EffectType.FAN_TARGETS:
			if maximum_targets <= 0 \
					or target_multipliers.size() != maximum_targets:
				return false
			for value in target_multipliers:
				if value < 0.0:
					return false
			return true
		EffectType.RANGE_DELTA, EffectType.PUSH_DISTANCE, EffectType.IGNORE_ARMOR_FLAT, EffectType.GUARD_ARMOR:
			return flat_value >= 0
	return true
