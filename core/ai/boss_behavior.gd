# core/ai/boss_behavior.gd
# ============================================================
# BOSS BEHAVIOR — Classe de base d'un comportement de boss.
# Chaque boss spécialise cette classe et surcharge decide().
#
# C'est une Resource : la LOGIQUE est dans le script (le pattern du
# boss), les RÉGLAGES sont des @export remplis dans le .tres associé
# (sort signature, fréquence, seuils...).
#
# Pour créer un nouveau boss :
#   1. nouveau script  res://core/ai/boss_xxx.gd  extends BossBehavior
#   2. surcharge decide()
#   3. crée un .tres de ce type, règle ses @export
#   4. assigne-le au champ boss_behavior d'une UnitData
# Aucune modification d'enemy_ai.gd ni de battle.gd nécessaire.
# ============================================================

class_name BossBehavior
extends Resource

# Décide les actions du boss à son tour.
#   boss      : l'unité boss (Unit)
#   all_units : toutes les unités du combat
#   ai        : l'EnemyAI (accès grille, pathfinder, sorts + helpers publics)
# Renvoie un PLAN d'actions, au même format que EnemyAI :
#   { "type": "move",   "path": [...] }
#   { "type": "attack", "target": Unit }
#   { "type": "cast",   "spell": Spell, "cell": Vector2i }
func decide(boss, all_units, ai) -> Array:
	# Par défaut : comportement agressif standard. Les boss surchargent.
	return ai.default_attack_plan(boss, all_units)
