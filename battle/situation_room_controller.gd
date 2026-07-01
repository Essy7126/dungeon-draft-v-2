# battle/situation_room_controller.gd
# ============================================================
# SITUATION ROOM CONTROLLER — le cadre dynamique d'une salle-situation.
#
# Trois rouages (design §10) :
#   - une SOURCE COUPABLE : un totem immobile qui spawn un renfort tous les N
#     rounds. Le detruire arrete les spawns.
#   - une MENACE QUI S'AGGRAVE : la lave s'etend d'1 case/round (plafonnee).
#   - un OBJECTIF != tuer tout le monde : detruire le totem = victoire.
#
# Composant AUTONOME (comme enemy_turn_runner / deployment_controller) : il tient
# une reference-retour vers battle et REUTILISE ses primitives (_place,
# _end_battle, units, terrain_effects, grid, grid_view, turn_queue.add_unit).
# Aucune logique de situation n'est ajoutee a battle.gd (qui ne fait que
# l'instancier si la salle est configuree).
#
# Cadence via EventBus.round_started : le controleur ne connait pas la TurnQueue.
# ============================================================

class_name SituationRoomController
extends Node

var _battle = null

# Config (fournie par la RoomData via battle).
var _totem_data: UnitData = null
var _spawn_data: UnitData = null
var _totem_cell: Vector2i = Vector2i(-1, -1)
var _spawn_period: int = 2
var _lava_effect: TerrainEffectData = null
var _lava_origin: Vector2i = Vector2i(-1, -1)
var _lava_cap: int = 8

# Etat.
var _totem = null
var _lava_cells: Array = []
var _seeded := false
var _active := true

func setup(battle, config: Dictionary) -> void:
	_battle = battle
	_totem_data = config.get("totem_data")
	_spawn_data = config.get("spawn_data")
	_totem_cell = config.get("totem_cell", Vector2i(-1, -1))
	_spawn_period = maxi(1, int(config.get("spawn_period", 2)))
	_lava_effect = config.get("lava_effect")
	_lava_origin = config.get("lava_origin", Vector2i(-1, -1))
	_lava_cap = maxi(0, int(config.get("lava_cap", 8)))
	EventBus.round_started.connect(_on_round_started)
	EventBus.unit_died.connect(_on_unit_died)

func _on_round_started(round_number: int) -> void:
	if not _active or _battle == null:
		return
	# Round 1 : on plante le decor une fois le combat pret (unites/grille/queue OK).
	if not _seeded:
		_seeded = true
		_spawn_totem()
		_seed_lava()
		return
	_expand_lava()
	if _totem != null and _totem.is_alive and round_number % _spawn_period == 0:
		_spawn_reinforcement()

# --- Source coupable ---

func _spawn_totem() -> void:
	if _totem_data == null:
		return
	var cell := _resolve_cell(_totem_cell)
	if cell == Vector2i(-1, -1):
		return
	_totem = Unit.from_data(_totem_data)
	_battle._place(_totem, cell)
	_battle.units.append(_totem)
	if _battle.turn_queue != null:
		_battle.turn_queue.add_unit(_totem)
	_battle.grid_view.queue_redraw()
	DebugLogger.info(DebugLogger.LogCategory.COMBAT, "Salle-situation : totem place en %s" % str(cell))

func _spawn_reinforcement() -> void:
	if _spawn_data == null or _totem == null:
		return
	var cell := _free_cell_near(_totem.grid_pos)
	if cell == Vector2i(-1, -1):
		return
	var gob = Unit.from_data(_spawn_data)
	_battle._place(gob, cell)
	_battle.units.append(gob)
	if _battle.turn_queue != null:
		_battle.turn_queue.add_unit(gob)
	_battle.grid_view.queue_redraw()
	DebugLogger.info(DebugLogger.LogCategory.COMBAT, "Salle-situation : le totem invoque un renfort en %s" % str(cell))

# --- Menace qui s'aggrave : la lave s'etend ---

func _seed_lava() -> void:
	if _lava_effect == null or not _battle.grid.is_valid(_lava_origin):
		return
	_place_lava(_lava_origin)

func _expand_lava() -> void:
	if _lava_effect == null or _lava_cells.size() >= _lava_cap:
		return
	# Une seule nouvelle case par round, adjacente a la lave existante.
	for lava in _lava_cells.duplicate():
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = lava + dir
			if _battle.grid.is_valid(n) and _battle.grid.is_walkable(n) and not (n in _lava_cells):
				_place_lava(n)
				return

func _place_lava(cell: Vector2i) -> void:
	_battle.terrain_effects.place_effect(cell, _lava_effect)
	if not (cell in _lava_cells):
		_lava_cells.append(cell)
	_battle.grid_view.queue_redraw()

# --- Objectif : detruire le totem = victoire ---

func _on_unit_died(unit) -> void:
	if unit == _totem and _active:
		_active = false
		DebugLogger.info(DebugLogger.LogCategory.COMBAT, "Salle-situation : totem detruit -> victoire")
		if _battle.has_method("_end_battle"):
			_battle._end_battle(true)

# --- Utilitaires ---

# Renvoie la case demandee si libre, sinon une case libre voisine, sinon (-1,-1).
func _resolve_cell(cell: Vector2i) -> Vector2i:
	if _battle.grid.is_valid(cell) and _battle.grid.is_walkable(cell) and not _battle.grid.has_unit(cell):
		return cell
	return _free_cell_near(cell)

func _free_cell_near(center: Vector2i) -> Vector2i:
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var n: Vector2i = center + dir
		if _battle.grid.is_valid(n) and _battle.grid.is_walkable(n) and not _battle.grid.has_unit(n):
			return n
	return Vector2i(-1, -1)
