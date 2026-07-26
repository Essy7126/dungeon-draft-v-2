class_name SpellModApplyStatus
extends SpellModifier

@export var status: StatusData = null


func on_targets_resolved(ctx) -> void:
	if status == null or ctx.grid == null or ctx.caster == null:
		return
	var target := ctx.grid.get_unit(ctx.cell) as Unit
	if target == null or target.team == ctx.caster.team:
		return
	var statuses: Array = ctx.additional_statuses_by_unit.get(target, [])
	if not statuses.has(status):
		statuses.append(status)
	ctx.additional_statuses_by_unit[target] = statuses
