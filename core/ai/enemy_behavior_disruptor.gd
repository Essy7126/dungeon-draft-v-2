# core/ai/enemy_behavior_disruptor.gd
class_name EnemyBehaviorDisruptor
extends BossBehavior

@export var disrupt_spell: Spell = null
@export var prefer_high_resources: bool = true
@export var fallback_to_default: bool = true

func decide(enemy, all_units, ai) -> Array:
	var action := _disrupt_action(enemy, all_units, ai)
	if not action.is_empty():
		return [action]
	return ai.default_attack_plan(enemy, all_units) if fallback_to_default else []

func _disrupt_action(enemy, all_units: Array, ai) -> Dictionary:
	if disrupt_spell == null:
		return {}
	var caster = ai.get_spell_caster()
	if caster != null and caster.has_method("can_afford") and not caster.can_afford(enemy, disrupt_spell):
		return {}
	var targetable: Array = caster.get_targetable_cells(enemy, disrupt_spell)
	if targetable.is_empty():
		return {}
	var best := Vector2i(-1, -1)
	var best_score := -999999.0
	var grid = ai.get_grid()
	for unit in all_units:
		if unit == null or not unit.is_alive or unit.team == enemy.team:
			continue
		if not targetable.has(unit.grid_pos):
			continue
		var resource_score: float = float(unit.current_elan + unit.current_energy)
		var distance_penalty: float = float(grid.manhattan(enemy.grid_pos, unit.grid_pos))
		var score: float = resource_score - distance_penalty if prefer_high_resources else -distance_penalty
		if score > best_score:
			best_score = score
			best = unit.grid_pos
	if best != Vector2i(-1, -1):
		return { "type": "cast", "spell": disrupt_spell, "cell": best }
	return {}