# battle/enemy_turn_runner.gd
# ============================================================
# ENEMY TURN RUNNER — exécution annulable du tour d'une unité ennemie.
#
# Le runner appartient à une Battle éphémère. Chaque attente conserve la
# génération de l'opération et revalide le runner, la Battle et les unités
# avant de reprendre. Une transition de salle invalide ainsi immédiatement
# toutes les opérations de l'ancienne scène.
# ============================================================

class_name EnemyTurnRunner
extends Node

var _battle = null
var _closing := false
var _operation_generation := 0


func setup(battle) -> void:
	_battle = battle
	_closing = false
	_operation_generation += 1


func cancel_pending_actions() -> void:
	_closing = true
	_operation_generation += 1


func _exit_tree() -> void:
	cancel_pending_actions()
	_battle = null


func is_closing() -> bool:
	return _closing


func _can_continue(
	generation: int,
	enemy: Unit = null,
	target: Unit = null,
	require_target := false
	) -> bool:
	if _closing or generation != _operation_generation or not is_inside_tree():
		return false
	if not is_instance_valid(_battle) or not _battle.is_inside_tree():
		return false
	if _battle._battle_over:
		return false
	if enemy != null and (not is_instance_valid(enemy) or not enemy.is_alive):
		return false
	if require_target and (
			target == null or not is_instance_valid(target) or not target.is_alive
		):
		return false
	return true


func _wait_seconds_safe(
	seconds: float,
	generation: int,
	enemy: Unit = null,
	target: Unit = null,
	require_target := false
	) -> bool:
	if not _can_continue(generation, enemy, target, require_target):
		return false
	var tree := get_tree()
	if tree == null:
		return false
	await tree.create_timer(maxf(seconds, 0.001)).timeout
	return _can_continue(generation, enemy, target, require_target)


# Exécute le tour complet de l'unité ennemie : décision d'IA puis déroulé des
# actions, en s'interrompant dès que la salle ferme ou que l'unité disparaît.
func run(enemy: Unit) -> void:
	if _closing:
		return
	var generation := _operation_generation
	if not await _wait_seconds_safe(0.3, generation, enemy):
		return
	var plan = _battle.enemy_ai.decide(enemy, _battle.units)
	for action in plan:
		if not _can_continue(generation, enemy):
			return
		match action["type"]:
			"move":
				await _execute_move(enemy, action["path"], generation)
			"attack":
				await _execute_attack(enemy, action["target"], generation)
			"cast":
				await _execute_cast(enemy, action["spell"], action["cell"], generation)
		if not await _wait_seconds_safe(0.2, generation, enemy):
			return


func _execute_cast(
	enemy: Unit,
	spell: Spell,
	cell: Vector2i,
	generation: int = -1
	) -> void:
	if generation < 0:
		generation = _operation_generation
	if not _can_continue(generation, enemy) or spell == null:
		return
	if not enemy.can_use_spell(spell):
		return
	if not _battle.spell_caster.is_valid_target(enemy, spell, cell):
		return
	var target := _battle.grid.get_unit(cell) as Unit
	var view = _battle._unit_views.get(enemy)
	var has_action_visual := false
	if is_instance_valid(view):
		if view.has_method("prepare_spell_visual"):
			var visual_ready: bool = await view.prepare_spell_visual(cell, spell)
			if not visual_ready \
					or not _can_continue(generation, enemy, target, target != null):
				return
			has_action_visual = view.has_method("has_optional_visual") \
				and view.has_optional_visual()
		elif view.has_method("face_grid_direction"):
			view.face_grid_direction(cell - enemy.grid_pos)
	if not _can_continue(generation, enemy, target, target != null):
		return
	var context: CastContext = _battle.spell_caster.begin_cast(enemy, spell, cell)
	if context.failed:
		return
	if spell.impact_delay_seconds > 0.0:
		VFXManager.play_spell_vfx(enemy, spell, cell)
		if not await _wait_seconds_safe(
			spell.impact_delay_seconds,
			generation,
			enemy,
			target,
			target != null
		):
			return
	if not _can_continue(generation, enemy, target, target != null):
		return
	_battle.spell_caster.resolve_cast(context)
	if not _can_continue(generation, enemy):
		return
	if is_instance_valid(_battle.grid_view):
		_battle.grid_view.queue_redraw()
	if has_action_visual and is_instance_valid(view) \
			and view.has_method("wait_for_action_visual_finished"):
		await view.wait_for_action_visual_finished()
		if not _can_continue(generation, enemy):
			return
	else:
		await _wait_seconds_safe(0.3, generation, enemy)


func _execute_move(enemy: Unit, path: Array, generation: int = -1) -> void:
	if generation < 0:
		generation = _operation_generation
	if not _can_continue(generation, enemy) or path.size() < 2:
		return
	var destination = path[path.size() - 1]
	var cost = path.size() - 1
	enemy.spend_mp(cost)
	_battle.grid.move_unit(enemy.grid_pos, destination)
	enemy.grid_pos = destination
	await _battle._animate_move(enemy, path)
	if not _can_continue(generation, enemy):
		return


func _execute_attack(
	enemy: Unit,
	target: Unit,
	generation: int = -1
	) -> void:
	if generation < 0:
		generation = _operation_generation
	if not _can_continue(generation, enemy, target, true):
		return
	if not enemy.basic_attack_enabled:
		return
	if not _battle.grid.are_adjacent(enemy.grid_pos, target.grid_pos):
		return
	var view = _battle._unit_views.get(enemy)
	var has_action_visual := false
	if is_instance_valid(view) and view.has_method("prepare_basic_attack_visual"):
		var visual_ready: bool = await view.prepare_basic_attack_visual(target.grid_pos)
		if not visual_ready or not _can_continue(generation, enemy, target, true):
			return
		has_action_visual = view.has_method("has_optional_visual") \
			and view.has_optional_visual()
	if not _can_continue(generation, enemy, target, true) \
			or not enemy.spend_ap(enemy.get_basic_attack_ap_cost()):
		return
	var result = target.take_damage(
		enemy.get_attack(),
		enemy,
		Spell.DamageType.PHYSICAL,
		Spell.Element.NONE
	)
	if result != null and not result.dodged:
		EventBus.basic_attack_performed.emit(enemy, target)
	if not _can_continue(generation, enemy):
		return
	if has_action_visual and is_instance_valid(view) \
			and view.has_method("wait_for_action_visual_finished"):
		await view.wait_for_action_visual_finished()
		if not _can_continue(generation, enemy):
			return
	else:
		await _battle._animate_attack(enemy, target)
		if not _can_continue(generation, enemy):
			return
