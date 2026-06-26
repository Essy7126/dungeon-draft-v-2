# core/ai/enemy_behavior_hazard_placer.gd
class_name EnemyBehaviorHazardPlacer
extends BossBehavior

@export var hazard_spell: Spell = null
@export var every_n_turns: int = 1
@export var fallback_to_default: bool = true

var _turn_index: int = 0

func decide(enemy, all_units, ai) -> Array:
	_turn_index += 1
	if every_n_turns <= 1 or _turn_index % every_n_turns == 0:
		var action := _hazard_action(enemy, all_units, ai)
		if not action.is_empty():
			return [action]
	return ai.default_attack_plan(enemy, all_units) if fallback_to_default else []

func _hazard_action(enemy, all_units: Array, ai) -> Dictionary:
	if hazard_spell == null:
		return {}
	var caster = ai.get_spell_caster()
	if caster != null and caster.has_method("can_afford") and not caster.can_afford(enemy, hazard_spell):
		return {}
	var targetable: Array = caster.get_targetable_cells(enemy, hazard_spell)
	if targetable.is_empty():
		return {}
	var target = ai.find_nearest_hero(enemy, all_units)
	if target != null and targetable.has(target.grid_pos):
		return { "type": "cast", "spell": hazard_spell, "cell": target.grid_pos }
	if target != null and hazard_spell.can_target_free_cell:
		var grid = ai.get_grid()
		var best := Vector2i(-1, -1)
		var best_dist := 999999
		for cell in targetable:
			var dist: int = grid.manhattan(cell, target.grid_pos)
			if dist < best_dist:
				best_dist = dist
				best = cell
		if best != Vector2i(-1, -1):
			return { "type": "cast", "spell": hazard_spell, "cell": best }
	return { "type": "cast", "spell": hazard_spell, "cell": targetable[0] }