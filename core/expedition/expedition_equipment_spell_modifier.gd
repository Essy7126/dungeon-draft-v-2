class_name ExpeditionEquipmentSpellModifier
extends SpellModifier

## Equipment uses the existing successful-cast pipeline and never grants free
## actions, recursive hits or healing outside Achilles' finite encounter reserve.
@export var valid_spell_ids: Array[StringName] = []
@export var caster_hp_at_or_below := -1.0
@export var damage_percent := 0.0
@export var armor_damage_ratio := 0.0
@export var armor_damage_cap := 8
@export var heal_percent := 0.0
@export var require_guard := false


func applies_to(spell) -> bool:
	return super(spell) and (valid_spell_ids.is_empty() or spell.get_effective_spell_id() in valid_spell_ids)


func on_targets_resolved(ctx) -> void:
	if caster_hp_at_or_below >= 0.0 and ctx.caster.get_hp_ratio() > caster_hp_at_or_below:
		return
	if require_guard and ctx.caster.current_shield <= 0:
		return
	for cell in ctx.affected_cells:
		var target := ctx.grid.get_unit(cell) as Unit
		if target == null:
			continue
		if target.team != ctx.caster.team and ctx.spell.deals_damage():
			var bonus := int(round(ctx.spell.get_scaled_damage(ctx.caster) * damage_percent))
			bonus += mini(armor_damage_cap, maxi(0, int(floor(ctx.caster.armure.get_value() * armor_damage_ratio))))
			ctx.damage_bonus_by_cell[cell] = int(ctx.damage_bonus_by_cell.get(cell, 0)) + bonus
		elif target == ctx.caster and ctx.spell.is_healing() and heal_percent > 0.0:
			# The spell's own reserve limiter runs after these bonuses are summed.
			var bonus := int(floor(ctx.spell.get_scaled_heal(ctx.caster) * heal_percent))
			ctx.heal_bonus_by_unit[target] = int(ctx.heal_bonus_by_unit.get(target, 0)) + bonus
