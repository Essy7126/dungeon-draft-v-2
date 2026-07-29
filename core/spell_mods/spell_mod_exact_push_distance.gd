class_name SpellModExactPushDistance
extends SpellModifier

@export_range(0, 99) var push_distance: int = 0


func on_targets_resolved(ctx) -> void:
	if ctx == null or ctx.grid == null or ctx.caster == null:
		return
	var target := ctx.grid.get_unit(ctx.cell) as Unit
	if target == null or target.team == ctx.caster.team:
		return
	ctx.push_distance_override_by_unit[target] = push_distance
