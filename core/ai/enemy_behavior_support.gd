# core/ai/enemy_behavior_support.gd
class_name EnemyBehaviorSupport
extends BossBehavior

@export var support_spell: Spell = null
@export_range(0.05, 1.0) var heal_threshold: float = 0.70
@export var fallback_to_default: bool = true

func decide(enemy, all_units, ai) -> Array:
	var action := _support_action(enemy, all_units, ai)
	if not action.is_empty():
		return [action]
	return ai.default_attack_plan(enemy, all_units) if fallback_to_default else []

func _support_action(enemy, all_units: Array, ai) -> Dictionary:
	if support_spell == null:
		return {}
	var caster = ai.get_spell_caster()
	if caster != null and caster.has_method("can_afford") and not caster.can_afford(enemy, support_spell):
		return {}
	var targetable: Array = caster.get_targetable_cells(enemy, support_spell)
	if targetable.is_empty():
		return {}
	var wounded = _most_wounded_ally(enemy, all_units)
	if wounded != null and targetable.has(wounded.grid_pos):
		return { "type": "cast", "spell": support_spell, "cell": wounded.grid_pos }
	if support_spell.can_target_self and enemy.get_hp_ratio() < heal_threshold and targetable.has(enemy.grid_pos):
		return { "type": "cast", "spell": support_spell, "cell": enemy.grid_pos }
	return {}

func _most_wounded_ally(enemy, all_units: Array):
	var best = null
	var best_ratio: float = heal_threshold
	for unit in all_units:
		if unit == null or not unit.is_alive or unit.team != enemy.team:
			continue
		var ratio: float = unit.get_hp_ratio()
		if ratio < best_ratio:
			best_ratio = ratio
			best = unit
	return best