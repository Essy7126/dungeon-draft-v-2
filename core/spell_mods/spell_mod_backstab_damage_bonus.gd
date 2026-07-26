class_name SpellModBackstabDamageBonus
extends SpellModifier

@export var bonus_damage: int = 0


func on_targets_resolved(ctx) -> void:
	if bonus_damage == 0 or ctx.grid == null or ctx.caster == null:
		return
	var target := ctx.grid.get_unit(ctx.cell) as Unit
	if target == null or target.team == ctx.caster.team:
		return
	if not target.is_grid_position_behind(ctx.caster.grid_pos):
		return
	var current_bonus := int(ctx.damage_bonus_by_cell.get(ctx.cell, 0))
	ctx.damage_bonus_by_cell[ctx.cell] = current_bonus + bonus_damage
