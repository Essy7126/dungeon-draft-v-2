# battle/enemy_turn_runner.gd
# ============================================================
# ENEMY TURN RUNNER — exécution du tour d'une unité ennemie (IA).
#
# Extrait de battle.gd par COMPOSITION. battle.gd reste le chef d'orchestre :
# il appelle `await run(enemy)` depuis _on_turn_started pour l'équipe ennemie.
#
# Ce module orchestre UNIQUEMENT l'exécution du plan d'IA (décision + actions
# move / attack / cast, avec leur cadencement). Il s'appuie sur battle.gd pour :
#   - les systèmes de jeu (enemy_ai, spell_caster, grid, grid_view, units) ;
#   - les animations (_animate_move, _animate_attack), qui vivent dans la vue ;
#   - l'état de fin de combat (_battle_over), pour s'interrompre proprement.
# D'où la référence-retour `_battle` : le tour ennemi est intrinsèquement tissé
# avec la machinerie visuelle et de tour du combat — on isole le DÉROULÉ de l'IA
# sans déplacer la couche visuelle, qui reste la responsabilité de battle.gd.
#
# C'est un Node (ajouté sous battle) pour disposer de get_tree() : les timers
# de cadencement (délais entre actions) en dépendent.
# ============================================================

class_name EnemyTurnRunner
extends Node

var _battle = null

func setup(battle) -> void:
	_battle = battle

# Exécute le tour complet de l'unité ennemie : décision d'IA puis déroulé des
# actions, en s'interrompant si le combat se termine ou si l'ennemi meurt.
func run(enemy: Unit) -> void:
	await get_tree().create_timer(0.3).timeout
	var plan = _battle.enemy_ai.decide(enemy, _battle.units)
	for action in plan:
		if _battle._battle_over:
			return
		# Sécurité : une action précédente a pu tuer l'ennemi (réaction de terrain).
		if not enemy.is_alive:
			return
		match action["type"]:
			"move":
				await _execute_move(enemy, action["path"])
			"attack":
				await _execute_attack(enemy, action["target"])
			"cast":
				await _execute_cast(enemy, action["spell"], action["cell"])
		await get_tree().create_timer(0.2).timeout

func _execute_cast(enemy: Unit, spell: Spell, cell: Vector2i) -> void:
	if enemy.current_ap < spell.ap_cost:
		return
	if not _battle.spell_caster.is_valid_target(enemy, spell, cell):
		return
	enemy.spend_ap(spell.ap_cost)
	_battle.spell_caster.cast(enemy, spell, cell)
	_battle.grid_view.queue_redraw()
	await get_tree().create_timer(0.3).timeout

func _execute_move(enemy: Unit, path: Array) -> void:
	if path.size() < 2:
		return
	var destination = path[path.size() - 1]
	var cost = path.size() - 1
	enemy.spend_mp(cost)
	_battle.grid.move_unit(enemy.grid_pos, destination)
	enemy.grid_pos = destination
	await _battle._animate_move(enemy, path)

func _execute_attack(enemy: Unit, target: Unit) -> void:
	if not is_instance_valid(target) or not target.is_alive:
		return
	if not _battle.grid.are_adjacent(enemy.grid_pos, target.grid_pos):
		return
	enemy.spend_ap(1)
	var result = target.take_damage(
		enemy.get_attack(),        # dégâts bruts
		enemy,                     # l'attaquant → active son crit
		Spell.DamageType.PHYSICAL, # catégorie
		Spell.Element.NONE)        # pas d'élément
	if result != null and not result.dodged:
		EventBus.basic_attack_performed.emit(enemy, target)
	await _battle._animate_attack(enemy, target)
