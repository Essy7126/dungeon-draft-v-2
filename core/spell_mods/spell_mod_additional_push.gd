class_name SpellModAdditionalPush
extends SpellModifier

@export_range(0, 99) var push_distance: int = 0


func on_targets_resolved(ctx) -> void:
	if push_distance <= 0 or ctx.grid == null or ctx.caster == null:
		return
	var target := ctx.grid.get_unit(ctx.cell) as Unit
	if target == null or target.team == ctx.caster.team:
		return
	var current_distance := int(ctx.additional_push_by_unit.get(target, 0))
	ctx.additional_push_by_unit[target] = current_distance + push_distance
