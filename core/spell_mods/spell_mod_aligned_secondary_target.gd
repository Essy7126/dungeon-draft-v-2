class_name SpellModAlignedSecondaryTarget
extends SpellModifier

@export_range(0.0, 1.0, 0.01) var damage_ratio: float = 0.5


func on_damage_resolved(ctx) -> void:
	if ctx == null \
			or ctx.grid == null \
			or ctx.caster == null \
			or ctx.primary_target == null:
		return
	var primary := ctx.primary_target as Unit
	var primary_result = ctx.damage_result_by_unit.get(primary)
	if primary_result == null or primary_result.dodged or primary_result.amount <= 0:
		return
	var raw_direction: Vector2i = primary.grid_pos - ctx.caster.grid_pos
	var direction := Vector2i.ZERO
	if abs(raw_direction.x) >= abs(raw_direction.y):
		direction = Vector2i(signi(raw_direction.x), 0)
	else:
		direction = Vector2i(0, signi(raw_direction.y))
	if direction == Vector2i.ZERO:
		return

	var candidate_cell := primary.grid_pos + direction
	while ctx.grid.is_valid(candidate_cell):
		if not ctx.grid.is_terrain_interactable(candidate_cell):
			return
		var candidate := ctx.grid.get_unit(candidate_cell) as Unit
		if candidate != null:
			if candidate.team != ctx.caster.team and candidate != primary:
				_apply_secondary_damage(ctx, candidate, primary_result.amount)
			return
		candidate_cell += direction


func _apply_secondary_damage(
		ctx,
		target: Unit,
		primary_final_damage: int
	) -> void:
	if target == null or not target.is_alive:
		return
	var amount := maxi(
		0,
		int(floor(float(primary_final_damage) * damage_ratio))
	)
	if amount <= 0:
		return
	var result = target.take_damage(
		amount,
		ctx.caster,
		ctx.spell.damage_type,
		ctx.spell.element,
		{
			"ignore_defense": true,
			"cannot_be_dodged": true,
			"disable_fervor_reaction": true,
		}
	)
	if result == null:
		return
	ctx.damage_result_by_unit[target] = result
	if not ctx.report["affected_units"].has(target):
		ctx.report["affected_units"].append(target)
	if result.amount > 0 and not ctx.report["damaged_enemies"].has(target):
		ctx.report["damaged_enemies"].append(target)
