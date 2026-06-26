# core/ai/enemy_behavior_spell_user.gd
class_name EnemyBehaviorSpellUser
extends BossBehavior

@export var preferred_spell: Spell = null
@export var fallback_to_default: bool = true

func decide(enemy, all_units, ai) -> Array:
	var action := _spell_action(enemy, preferred_spell, all_units, ai)
	if not action.is_empty():
		return [action]
	return ai.default_attack_plan(enemy, all_units) if fallback_to_default else []

func _spell_action(enemy, spell: Spell, all_units: Array, ai) -> Dictionary:
	if spell == null:
		return {}
	var caster = ai.get_spell_caster()
	if caster != null and caster.has_method("can_afford") and not caster.can_afford(enemy, spell):
		return {}
	if spell.is_self_only():
		return { "type": "cast", "spell": spell, "cell": enemy.grid_pos }
	var targetable: Array = caster.get_targetable_cells(enemy, spell)
	if targetable.is_empty():
		return {}
	if spell.can_target_enemy:
		var cell := _nearest_enemy_cell(enemy, all_units, ai, targetable)
		if cell != Vector2i(-1, -1):
			return { "type": "cast", "spell": spell, "cell": cell }
	if spell.can_target_free_cell:
		var free_cell := _best_free_cell_near_enemy(enemy, all_units, ai, targetable)
		if free_cell != Vector2i(-1, -1):
			return { "type": "cast", "spell": spell, "cell": free_cell }
	return {}

func _nearest_enemy_cell(enemy, all_units: Array, ai, targetable: Array) -> Vector2i:
	var grid = ai.get_grid()
	var best := Vector2i(-1, -1)
	var best_dist := 999999
	for unit in all_units:
		if unit == null or not unit.is_alive or unit.team == enemy.team:
			continue
		if not targetable.has(unit.grid_pos):
			continue
		var dist: int = grid.manhattan(enemy.grid_pos, unit.grid_pos)
		if dist < best_dist:
			best_dist = dist
			best = unit.grid_pos
	return best

func _best_free_cell_near_enemy(enemy, all_units: Array, ai, targetable: Array) -> Vector2i:
	var target = ai.find_nearest_hero(enemy, all_units)
	if target == null:
		return targetable[0]
	var grid = ai.get_grid()
	var best := Vector2i(-1, -1)
	var best_dist := 999999
	for cell in targetable:
		var dist: int = grid.manhattan(cell, target.grid_pos)
		if dist < best_dist:
			best_dist = dist
			best = cell
	return best