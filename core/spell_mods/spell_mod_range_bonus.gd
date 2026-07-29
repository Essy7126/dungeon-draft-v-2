class_name SpellModRangeBonus
extends SpellModifier

@export_range(0, 99) var range_bonus: int = 0


func get_range_bonus(_caster, _spell) -> int:
	return range_bonus
