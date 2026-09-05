@tool
class_name ItemSpellModifierData
extends SpellModifier

## Effets d'equipement appliques au pipeline de sort commun. Aucune branche
## ne depend d'un item_id : les Resources composent librement ces filtres.

@export_range(-1.0, 5.0, 0.01) var damage_percent := 0.0
@export_enum("ANY:-1", "PHYSICAL:0", "MAGICAL:1") var damage_type_filter := -1
@export var require_elemental_damage := false
@export_range(-1.0, 1.0, 0.01) var target_hp_at_or_below := -1.0
@export_range(-1.0, 1.0, 0.01) var target_hp_at_or_above := -1.0
@export_range(-10, 10, 1) var range_bonus := 0
@export_range(-1, 20, 1) var minimum_range_override := -1
@export_range(-1, 20, 1) var target_distance_at_least := -1
@export_range(-1, 20, 1) var target_distance_at_most := -1
@export_range(0, 20, 1) var minimum_prior_moved_cells := 0
@export_range(0, 20, 1) var minimum_mp_spent := 0
@export var require_hp_lost_since_previous_activation := false
@export var require_target_moved_or_collided := false
@export var require_guard_destroyed := false
@export_range(0, 10, 1) var push_bonus := 0
@export_range(-1.0, 5.0, 0.01) var healing_and_shield_percent := 0.0


func is_valid_modifier() -> bool:
	return not is_zero_approx(damage_percent) \
		or range_bonus != 0 \
		or minimum_range_override >= 0 \
		or push_bonus > 0 \
		or not is_zero_approx(healing_and_shield_percent)


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


func get_range_bonus(caster, spell) -> int:
	if spell == null or spell.spell_range <= 0:
		return 0
	var history: Dictionary = caster.get_equipment_condition_facts() if caster is Unit else {}
	return range_bonus if _history_conditions_pass(history) else 0


## Contrat spécifique au sort, consulté par la validation commune des cibles.
func get_minimum_range_override(_caster, spell) -> int:
	return minimum_range_override if spell != null and spell.spell_range > 0 else -1


func on_targets_resolved(ctx) -> void:
	if ctx == null or ctx.caster == null or ctx.spell == null:
		return
	if not is_zero_approx(damage_percent) and ctx.spell.deals_damage():
		for cell_value in ctx.affected_cells:
			var cell := cell_value as Vector2i
			var target := ctx.grid.get_unit(cell) as Unit
			if target == null or target.team == ctx.caster.team \
					or not _target_condition_passes(ctx, target):
				continue
			var current_damage: int = ctx.spell.get_scaled_damage(ctx.caster) + int(
				ctx.damage_bonus_by_cell.get(cell, 0)
			)
			var bonus := _scaled_delta(current_damage, damage_percent)
			if bonus != 0:
				ctx.damage_bonus_by_cell[cell] = int(
					ctx.damage_bonus_by_cell.get(cell, 0)
				) + bonus
	if not is_zero_approx(healing_and_shield_percent):
		for cell_value in ctx.affected_cells:
			var cell := cell_value as Vector2i
			var ally := ctx.grid.get_unit(cell) as Unit
			if ally == null or ally.team != ctx.caster.team:
				continue
			if ctx.spell.heal > 0:
				ctx.heal_bonus_by_unit[ally] = int(
					ctx.heal_bonus_by_unit.get(ally, 0)
				) + _scaled_delta(ctx.spell.heal, healing_and_shield_percent)
			var scaled_shield: int = ctx.spell.get_scaled_shield(ctx.caster)
			if scaled_shield > 0:
				ctx.additional_shield_by_unit[ally] = int(
					ctx.additional_shield_by_unit.get(ally, 0)
				) + _scaled_delta(scaled_shield, healing_and_shield_percent)
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


func _target_condition_passes(ctx, target: Unit) -> bool:
	if target_hp_at_or_below >= 0.0 \
			and target.get_hp_ratio() > target_hp_at_or_below:
		return false
	if target_hp_at_or_above >= 0.0 \
			and target.get_hp_ratio() <= target_hp_at_or_above:
		return false
	var distance: int = int(ctx.grid.manhattan(ctx.caster.grid_pos, target.grid_pos))
	if target_distance_at_least >= 0 and distance < target_distance_at_least:
		return false
	if target_distance_at_most >= 0 and distance > target_distance_at_most:
		return false
	# Une condition d'historique ne devient vraie que si le rapport de cast
	# contient un fait autoritaire ; l'absence de fournisseur échoue fermement.
	var history := ctx.report.get("equipment_condition_facts", {}) as Dictionary
	if ctx.caster is Unit:
		history = (ctx.caster as Unit).get_equipment_condition_facts(target)
	return _history_conditions_pass(history)


func _history_conditions_pass(history: Dictionary) -> bool:
	if minimum_prior_moved_cells > 0 and minimum_prior_moved_cells > int(history.get("prior_moved_cells", -1)):
		return false
	if minimum_mp_spent > 0 and minimum_mp_spent > int(history.get("mp_spent", -1)):
		return false
	if require_hp_lost_since_previous_activation \
			and not bool(history.get("hp_lost_since_previous_activation", false)):
		return false
	if require_target_moved_or_collided \
			and not bool(history.get("target_moved_or_collided", false)):
		return false
	if require_guard_destroyed \
			and not bool(history.get("guard_destroyed", false)):
		return false
	return true


func _scaled_delta(base_value: int, ratio: float) -> int:
	var result := int(round(float(base_value) * ratio))
	if result == 0 and base_value > 0 and not is_zero_approx(ratio):
		return 1 if ratio > 0.0 else -1
	return result


func runtime_requirements() -> Array[StringName]:
	var result: Array[StringName] = []
	if minimum_range_override >= 0:
		result.append(&"minimum_range_override_hook")
	if minimum_prior_moved_cells > 0:
		result.append(&"prior_moved_cells_fact")
	if minimum_mp_spent > 0:
		result.append(&"mp_spent_fact")
	if require_hp_lost_since_previous_activation:
		result.append(&"hp_lost_since_previous_activation_fact")
	if require_target_moved_or_collided:
		result.append(&"target_moved_or_collided_fact")
	if require_guard_destroyed:
		result.append(&"guard_destroyed_fact")
	return result
