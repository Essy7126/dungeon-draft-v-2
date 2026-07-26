class_name SpellModCentralCellDamageBonus
extends SpellModifier

@export var bonus_damage: int = 0


func on_targets_resolved(ctx) -> void:
	if bonus_damage == 0:
		return
	var current_bonus := int(ctx.damage_bonus_by_cell.get(ctx.cell, 0))
	ctx.damage_bonus_by_cell[ctx.cell] = current_bonus + bonus_damage
