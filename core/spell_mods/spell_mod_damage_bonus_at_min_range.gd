class_name SpellModDamageBonusAtMinRange
extends SpellModifier

@export_range(0, 99) var minimum_range: int = 0
@export var bonus_damage: int = 0


func on_targets_resolved(ctx) -> void:
	if bonus_damage == 0 or ctx.grid == null or ctx.caster == null:
		return
	if ctx.grid.manhattan(ctx.caster.grid_pos, ctx.cell) < minimum_range:
		return
	var current_bonus := int(ctx.damage_bonus_by_cell.get(ctx.cell, 0))
	ctx.damage_bonus_by_cell[ctx.cell] = current_bonus + bonus_damage
