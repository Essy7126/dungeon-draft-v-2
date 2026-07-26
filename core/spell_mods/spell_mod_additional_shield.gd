class_name SpellModAdditionalShield
extends SpellModifier

@export_range(0, 999) var shield_amount: int = 0


func on_targets_resolved(ctx) -> void:
	if shield_amount <= 0 or ctx.grid == null or ctx.caster == null:
		return
	var target := ctx.grid.get_unit(ctx.cell) as Unit
	if target == null or target.team != ctx.caster.team:
		return
	var current_amount := int(ctx.additional_shield_by_unit.get(target, 0))
	ctx.additional_shield_by_unit[target] = current_amount + shield_amount
