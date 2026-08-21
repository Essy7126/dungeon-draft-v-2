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

const MAX_ACTION_STEPS := EnemyActionPlan.MAX_STEPS

var _battle = null
var _closing := false
var _operation_generation := 0
var last_action_count := 0


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


func _wait_process_frame_safe(generation: int, enemy: Unit = null) -> bool:
	if not _can_continue(generation, enemy):
		return false
	var tree := get_tree()
	if tree == null:
		return false
	await tree.process_frame
	return _can_continue(generation, enemy)


# Exécute le tour complet de l'unité ennemie : décision d'IA puis déroulé des
# actions, en s'interrompant dès que la salle ferme ou que l'unité disparaît.
func run(enemy: Unit) -> void:
	if _closing:
		return
	var generation := _operation_generation
	if not await _wait_seconds_safe(0.3, generation, enemy):
		return
	var plan: EnemyActionPlan = _battle.enemy_ai.build_action_plan(
		enemy,
		_battle.units,
	)
	# La planification est synchrone. Reprendre les actions a la frame suivante
	# empeche son delta CPU d'etre consomme par le premier tween de mouvement.
	if not await _wait_process_frame_safe(generation, enemy):
		return
	last_action_count = 0
	for action in plan.to_actions():
		if last_action_count >= MAX_ACTION_STEPS:
			break
		if not _can_continue(generation, enemy):
			return
		match action["type"]:
			"move":
				await _execute_move(enemy, action["path"], generation)
			"attack":
				await _execute_attack(enemy, action["target"], generation)
			"cast":
				await _execute_cast(enemy, action["spell"], action["cell"], generation)
		last_action_count += 1
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
	var report: Dictionary = _battle.spell_caster.resolve_cast(context)
	EventBus.ap_after_action_changed.emit(
		enemy, context.ap_before, enemy.current_ap, context.action_id
	)
	EventBus.action_resolved.emit(
		enemy, context.action_id, &"spell", report.duplicate(false)
	)
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
	if path[0] != enemy.grid_pos:
		return
	var previous: Vector2i = path[0]
	for index in range(1, path.size()):
		var step: Vector2i = path[index]
		if not _battle.pathfinder.is_vortex_edge(previous, step) \
				and (_battle.grid.manhattan(previous, step) != 1 \
				or not _battle.grid.is_walkable(step)):
			return
		previous = step
	var breakdown: Dictionary = _battle.pathfinder.path_cost_breakdown(path, enemy)
	var cost := int(breakdown.get("total", 0))
	var base_cost := int(breakdown.get("unmodified_total", cost))
	var action_id: StringName = _battle._next_action_id(&"enemy_move")
	if cost > enemy.current_mp:
		return
	EventBus.voluntary_movement_prepared.emit(
		enemy, path.duplicate(), base_cost, cost, action_id
	)
	if not enemy.spend_mp(cost):
		return
	await _battle._animate_move(enemy, path)
	if not _can_continue(generation, enemy):
		return
	EventBus.voluntary_movement_resolved.emit(
		enemy, path.duplicate(), cost, action_id
	)
	EventBus.action_resolved.emit(enemy, action_id, &"voluntary_movement", {
		"distance": maxi(0, path.size() - 1), "paid_mp": cost,
	})


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
	var action_id: StringName = _battle._next_action_id(&"enemy_basic_attack")
	var ap_before := enemy.current_ap
	if not _can_continue(generation, enemy, target, true) \
			or not enemy.spend_ap(enemy.get_basic_attack_ap_cost()):
		return
	var result = target.take_damage(
		enemy.get_attack(),
		enemy,
		Spell.DamageType.PHYSICAL,
		Spell.Element.NONE,
		{"action_id": action_id, "impact_id": StringName("%s:000" % action_id)}
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
	EventBus.ap_after_action_changed.emit(enemy, ap_before, enemy.current_ap, action_id)
	EventBus.action_resolved.emit(enemy, action_id, &"basic_attack", {"target": target})
