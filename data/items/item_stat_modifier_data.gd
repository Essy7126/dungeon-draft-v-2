@tool
class_name ItemStatModifierData
extends Resource

enum ModifierType {
	FLAT,
	PERCENT,
}

const SUPPORTED_STAT_IDS: Array[StringName] = [
	&"max_hp",
	&"initiative",
	&"max_ap",
	&"max_mp",
	&"attack_power",
	&"armure",
	&"resist_magique",
	&"esquive",
	&"crit_chance",
	&"crit_multi",
	&"force",
	&"resistance_ice",
]

@export var stat_id: StringName = &""
@export var value := 0.0
@export var modifier_type: ModifierType = ModifierType.FLAT


func is_valid() -> bool:
	return stat_id in SUPPORTED_STAT_IDS and not is_zero_approx(value)


func to_snapshot() -> Dictionary:
	return {
		"stat_id": str(stat_id),
		"value": value,
		"modifier_type": int(modifier_type),
	}
