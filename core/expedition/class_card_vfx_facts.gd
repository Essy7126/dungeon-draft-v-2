extends SpellModifier
## Presentation evidence only. Captures pre-impact facts without changing resolution.
const IDS := ["g_hook", "t_glacier", "a_reap", "r_scatter"]


func on_targets_finalized(ctx: CastContext) -> void:
	var targets: Array[Dictionary] = []
	for cell: Vector2i in ctx.affected_cells:
		var target: Unit = ctx.grid.get_unit(cell)
		if target != null and target.team != ctx.caster.team:
			targets.append(
				{ "unit": target, "cell": cell, "execute": target.get_hp_ratio() <= .35 }
			)
	ctx.report["card_vfx"] = {
		"origin": ctx.caster.grid_pos,
		"cells": ctx.affected_cells.duplicate(),
		"targets": targets,
	}


func on_cast_complete(ctx: CastContext) -> void:
	if ctx.report.has("card_vfx"):
		ctx.report.card_vfx["movement"] = ctx.movement.duplicate()
