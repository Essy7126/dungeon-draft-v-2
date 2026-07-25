class_name SpellModHealBonus
extends SpellModifier

@export var bonus_heal: int = 0


func on_targets_resolved(ctx) -> void:
	if bonus_heal == 0 or ctx.grid == null or ctx.caster == null:
		return
	var target := ctx.grid.get_unit(ctx.cell) as Unit
	if target == null or target.team != ctx.caster.team:
		return
	var current_bonus := int(ctx.heal_bonus_by_unit.get(target, 0))
	ctx.heal_bonus_by_unit[target] = current_bonus + bonus_heal
