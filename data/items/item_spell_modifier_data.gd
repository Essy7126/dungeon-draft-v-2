class_name ItemSpellModifierData
extends SpellModifier

## Effets d'equipement appliques au pipeline de sort commun. Aucune branche
## ne depend d'un item_id : les Resources composent librement ces filtres.

@export_range(0.0, 5.0, 0.01) var damage_percent := 0.0
@export_enum("ANY:-1", "PHYSICAL:0", "MAGICAL:1") var damage_type_filter := -1
@export var require_elemental_damage := false
@export_range(-1.0, 1.0, 0.01) var target_hp_at_or_below := -1.0
@export_range(0, 10, 1) var range_bonus := 0
@export_range(0, 10, 1) var push_bonus := 0
@export_range(0.0, 5.0, 0.01) var healing_and_shield_percent := 0.0


func is_valid_modifier() -> bool:
	return damage_percent > 0.0 \
		or range_bonus > 0 \
		or push_bonus > 0 \
		or healing_and_shield_percent > 0.0


func applies_to(spell) -> bool:
	if not super(spell):
		return false
	if spell == null:
		return false
	if damage_type_filter >= 0 and spell.damage_type != damage_type_filter:
		return false
	if require_elemental_damage and spell.element == Spell.Element.NONE:
		return false
	return true


func get_range_bonus(_caster, spell) -> int:
	return range_bonus if spell != null and spell.spell_range > 0 else 0


func on_targets_resolved(ctx) -> void:
	if ctx == null or ctx.caster == null or ctx.spell == null:
		return
	if damage_percent > 0.0 and ctx.spell.deals_damage():
		for cell_value in ctx.affected_cells:
			var cell := cell_value as Vector2i
			var target := ctx.grid.get_unit(cell) as Unit
			if target == null or target.team == ctx.caster.team \
					or not _target_condition_passes(target):
				continue
			var current_damage: int = ctx.spell.damage + int(
				ctx.damage_bonus_by_cell.get(cell, 0)
			)
			var bonus: int = maxi(1, int(round(float(current_damage) * damage_percent)))
			ctx.damage_bonus_by_cell[cell] = int(
				ctx.damage_bonus_by_cell.get(cell, 0)
			) + bonus
	if healing_and_shield_percent > 0.0:
		for cell_value in ctx.affected_cells:
			var cell := cell_value as Vector2i
			var ally := ctx.grid.get_unit(cell) as Unit
			if ally == null or ally.team != ctx.caster.team:
				continue
			if ctx.spell.heal > 0:
				ctx.heal_bonus_by_unit[ally] = int(
					ctx.heal_bonus_by_unit.get(ally, 0)
				) + maxi(1, int(round(
					float(ctx.spell.heal) * healing_and_shield_percent
				)))
			if ctx.spell.shield_grant > 0:
				ctx.additional_shield_by_unit[ally] = int(
					ctx.additional_shield_by_unit.get(ally, 0)
				) + maxi(1, int(round(
					float(ctx.spell.shield_grant) * healing_and_shield_percent
				)))
	if push_bonus > 0:
		for cell_value in ctx.affected_cells:
			var target := ctx.grid.get_unit(cell_value as Vector2i) as Unit
			if target == null or target.team == ctx.caster.team:
				continue
			ctx.push_distance_override_by_unit[target] = maxi(
				int(ctx.push_distance_override_by_unit.get(
					target,
					ctx.spell.push_distance,
				)),
				ctx.spell.push_distance + push_bonus,
			)


func _target_condition_passes(target: Unit) -> bool:
	return target_hp_at_or_below < 0.0 \
		or target.get_hp_ratio() <= target_hp_at_or_below
