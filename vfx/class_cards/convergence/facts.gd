extends SpellModifier
## Read-only snapshots for cc2_t08, after attraction and before deaths.


func on_targets_finalized(ctx: CastContext) -> void:
	preload("res://core/expedition/class_card_vfx_facts.gd").new().on_targets_finalized(ctx)
	# Keep the gameplay area intact; the painted arms stop at solid walls.
	ctx.report.card_vfx["arm_cells"] = ctx.affected_cells.filter(
		func(cell):
			return ctx.grid.get_type(cell) != GridData.CellType.WALL,
	)


func on_cast_complete(ctx: CastContext) -> void:
	if not ctx.report.has("card_vfx"):
		return
	var evidence: Dictionary = ctx.report.card_vfx
	evidence["movement"] = ctx.movement.duplicate()
	var contacts: Array[Dictionary] = []
	for fact: Dictionary in evidence.targets:
		var result: DamageResolver.DamageResult = ctx.damage_result_by_unit.get(fact.unit)
		if result != null and (result.hp_damage_applied > 0 or result.shield_damage_absorbed > 0):
			contacts.append({ "unit": fact.unit, "cell": fact.cell })
	evidence["contacts"] = contacts
