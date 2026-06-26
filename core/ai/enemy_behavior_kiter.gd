# core/ai/enemy_behavior_kiter.gd
class_name EnemyBehaviorKiter
extends BossBehavior

@export var preferred_spell: Spell = null
@export var keep_distance: int = 3
@export var fallback_to_default: bool = true

func decide(enemy, all_units, ai) -> Array:
	var plan: Array = []
	var cast_action := _spell_action(enemy, all_units, ai)
	if not cast_action.is_empty():
		plan.append(cast_action)
	var flee_action := _flee_action(enemy, all_units, ai)
	if not flee_action.is_empty():
		plan.append(flee_action)
	if not plan.is_empty():
		return plan
	return ai.default_attack_plan(enemy, all_units) if fallback_to_default else []

func _spell_action(enemy, all_units: Array, ai) -> Dictionary:
	if preferred_spell == null:
		return {}
	var caster = ai.get_spell_caster()
	if caster != null and caster.has_method("can_afford") and not caster.can_afford(enemy, preferred_spell):
		return {}
	var targetable: Array = caster.get_targetable_cells(enemy, preferred_spell)
	for unit in all_units:
		if unit == null or not unit.is_alive or unit.team == enemy.team:
			continue
		if targetable.has(unit.grid_pos):
			return { "type": "cast", "spell": preferred_spell, "cell": unit.grid_pos }
	return {}

func _flee_action(enemy, all_units: Array, ai) -> Dictionary:
	var threat = ai.find_nearest_hero(enemy, all_units)
	if threat == null:
		return {}
	var grid = ai.get_grid()
	if grid.manhattan(enemy.grid_pos, threat.grid_pos) >= keep_distance:
		return {}
	var reachable: Array = ai.get_pathfinder().get_reachable(enemy.grid_pos, enemy.current_mp, enemy)
	var best_cell: Vector2i = enemy.grid_pos
	var best_dist: int = grid.manhattan(enemy.grid_pos, threat.grid_pos)
	for cell in reachable:
		var dist: int = grid.manhattan(cell, threat.grid_pos)
		if dist > best_dist:
			best_dist = dist
			best_cell = cell
	if best_cell == enemy.grid_pos:
		return {}
	var path: Array = ai.get_pathfinder().find_path(enemy.grid_pos, best_cell, enemy)
	if path.size() < 2:
		return {}
	return { "type": "move", "path": path }