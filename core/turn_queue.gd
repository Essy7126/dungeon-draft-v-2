# core/turn_queue.gd
# ============================================================
# TURN QUEUE — File d'initiative et ordre des tours.
# Logique pure.
#
# Trie les unités par initiative décroissante, gère l'unité active,
# et fait tourner les tours en boucle (rounds successifs).
# Les unités mortes sont automatiquement sautées.
# ============================================================

class_name TurnQueue
extends RefCounted

# ============================================================
# DONNÉES
# ============================================================

# Toutes les unités du combat, dans leur ordre d'initiative (trié).
var _order: Array = []

# Index de l'unité active dans _order.
var _current_index: int = -1

# Numéro du round en cours (commence à 1).
var round_number: int = 0

# ============================================================
# SIGNAUX
# ============================================================

signal turn_started(unit)       # Une nouvelle unité commence son tour
signal round_started(number)    # Un nouveau round commence
signal queue_changed            # L'ordre a changé (pour rafraîchir la barre UI)

# ============================================================
# CONSTRUCTION ET INITIALISATION
# ============================================================

# Initialise la file avec la liste des unités du combat.
func setup(units: Array) -> void:
	_order = units.duplicate()
	_sort_by_initiative()
	_current_index = -1
	round_number = 0
	queue_changed.emit()

# Trie les unités par initiative décroissante.
# Départage stable en cas d'égalité : équipe joueur (0) avant ennemis (1),
# puis ordre d'ajout (préserve un ordre cohérent d'un round à l'autre).
func _sort_by_initiative() -> void:
	# On garde l'index d'origine pour un départage stable.
	var indexed = []
	for i in _order.size():
		indexed.append({ "unit": _order[i], "original": i })

	indexed.sort_custom(func(a, b):
		var ua = a["unit"]
		var ub = b["unit"]
		# 1. Initiative décroissante
		if ua.get_initiative() != ub.get_initiative():
			return ua.get_initiative() > ub.get_initiative()
		# 2. Égalité : équipe la plus basse d'abord (joueur avant ennemis)
		if ua.team != ub.team:
			return ua.team < ub.team
		# 3. Toujours égalité : ordre d'ajout
		return a["original"] < b["original"]
	)

	# On reconstruit _order trié.
	_order.clear()
	for entry in indexed:
		_order.append(entry["unit"])

# ============================================================
# PROGRESSION DES TOURS
# ============================================================

# Passe à l'unité suivante vivante. C'est LA méthode appelée en fin de tour.
func advance() -> void:
	if _order.is_empty():
		return

	# On cherche la prochaine unité vivante.
	# Limite de sécurité : on ne boucle pas indéfiniment si tout le monde est mort.
	var attempts = 0
	var max_attempts = _order.size() + 1

	while attempts < max_attempts:
		_current_index += 1

		# Fin de la liste → nouveau round, on repart au début.
		if _current_index >= _order.size():
			_current_index = 0
			round_number += 1
			round_started.emit(round_number)

		attempts += 1

		# Unité vivante trouvée → c'est son tour.
		var unit = _order[_current_index]
		if unit.is_alive:
			unit.start_turn()       # Recharge PA/PM, vieillit les buffs
			turn_started.emit(unit)
			return

	# Si on sort de la boucle, c'est que personne n'est vivant.
	# Le BattleManager détectera la fin de combat de son côté.

# Démarre le tout premier tour du combat.
func start() -> void:
	round_number = 1
	round_started.emit(round_number)
	_current_index = -1
	advance()

# ============================================================
# GESTION DES MORTS
# ============================================================

# Retire une unité morte de la file (appelé quand une unité meurt).
# On ne la retire pas physiquement pour ne pas casser l'index courant :
# elle sera simplement sautée par advance() car is_alive == false.
# Mais on rafraîchit l'UI.
func on_unit_died(_unit) -> void:
	queue_changed.emit()

# ============================================================
# LECTURE (UI, IA, conditions de victoire)
# ============================================================

# L'unité dont c'est le tour actuellement.
func get_current_unit():
	if _current_index < 0 or _current_index >= _order.size():
		return null
	return _order[_current_index]

# La liste ordonnée des unités vivantes (pour la barre de portraits).
func get_living_order() -> Array:
	return _order.filter(func(u): return u.is_alive)

# Liste ordonnée complète (vivants + morts), pour l'UI si besoin.
func get_full_order() -> Array:
	return _order.duplicate()

# Combien d'unités vivantes dans une équipe donnée ?
# Sert à détecter la victoire/défaite.
func count_living_in_team(team: int) -> int:
	var count = 0
	for unit in _order:
		if unit.is_alive and unit.team == team:
			count += 1
	return count
