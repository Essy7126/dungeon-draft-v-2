# core/grid_data.gd
# ============================================================
# DONNÃ‰ES DE LA GRILLE â€” Logique pure, AUCUN visuel.
# Ne dessine rien, ne gÃ¨re pas les clics, ne connaÃ®t pas les pixels.
# Raisonne uniquement en coordonnÃ©es de grille (Vector2i).
#
# C'est la "source de vÃ©ritÃ©" de l'Ã©tat spatial du combat :
# oÃ¹ sont les unitÃ©s, quels types de cases, quels effets actifs.
# ============================================================

class_name GridData
extends RefCounted
# RefCounted = objet lÃ©ger sans prÃ©sence dans la scÃ¨ne (pas un Node).
# Parfait pour de la donnÃ©e pure qui n'a pas besoin d'Ãªtre affichÃ©e.

# ============================================================
# DIMENSIONS
# ============================================================

var cols: int
var rows: int

# ============================================================
# TYPES DE CASES
# Pour ajouter un type : ajoute-le ici ET dans PROPERTIES ci-dessous.
# ============================================================

enum CellType {
	NORMAL,   # Sol standard, marchable, transparent
	WALL,     # Mur : infranchissable, bloque la ligne de vue
	HOLE,     # Trou : infranchissable, mais laisse passer la vue
	LAVA,     # Marchable, infligera des dÃ©gÃ¢ts (gÃ©rÃ© plus tard)
	ICE,      # Marchable, glissant (gÃ©rÃ© plus tard)
	SHADOW,   # Marchable, bloque la vue (brouillard/ombre)
	RUNE,     # Marchable, dÃ©clenchera un effet magique (gÃ©rÃ© plus tard)
}

# PropriÃ©tÃ©s mÃ©caniques de chaque type.
# walkable    : une unitÃ© peut-elle s'y arrÃªter / marcher dessus ?
# transparent : laisse-t-elle passer la ligne de vue ?
const PROPERTIES = {
	CellType.NORMAL : { "walkable": true,  "transparent": true  },
	CellType.WALL   : { "walkable": false, "transparent": false },
	CellType.HOLE   : { "walkable": false, "transparent": true  },
	CellType.LAVA   : { "walkable": true,  "transparent": true  },
	CellType.ICE    : { "walkable": true,  "transparent": true  },
	CellType.SHADOW : { "walkable": true,  "transparent": false },
	CellType.RUNE   : { "walkable": true,  "transparent": true  },
}

# ============================================================
# Ã‰TAT DES CASES
# Trois dictionnaires sÃ©parÃ©s plutÃ´t qu'un gros objet par case.
# Plus simple Ã  lire, plus rapide Ã  interroger.
# ClÃ© = Vector2i(col, row) dans tous les cas.
# ============================================================

var _types: Dictionary = {}     # Vector2i -> CellType
var _units: Dictionary = {}     # Vector2i -> Unit (ou absent si vide)
var _effects: Dictionary = {}   # Vector2i -> { "name": String, "data": Dictionary }
var _terrain_properties: Dictionary = {} # Vector2i -> data-driven permanent overrides
var _surface_properties: Dictionary = {} # Vector2i -> temporary surface overrides
var _vortex_links: Dictionary = {} # Vector2i -> paired destination
var _vortex_network_by_cell: Dictionary = {}
var _dynamic_blockers: Dictionary = {} # Vector2i -> Array[Object]
var _next_combat_order: int = 0

signal occupancy_changed(reason: StringName, unit, from_pos: Vector2i, to_pos: Vector2i)
signal dynamic_blocker_changed(cell: Vector2i)

# ============================================================
# CONSTRUCTION
# AppelÃ© avec GridData.new(15, 10) par exemple.
# ============================================================

func _init(grid_cols: int, grid_rows: int) -> void:
	cols = grid_cols
	rows = grid_rows
	# Toutes les cases dÃ©marrent en NORMAL.
	for x in cols:
		for y in rows:
			_types[Vector2i(x, y)] = CellType.NORMAL

# ============================================================
# VALIDITÃ‰ ET PROPRIÃ‰TÃ‰S
# ============================================================

# La position est-elle dans les limites de la grille ?
func is_valid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < cols and pos.y >= 0 and pos.y < rows

# Type de la case (NORMAL par dÃ©faut si hors grille).
func get_type(pos: Vector2i) -> CellType:
	return _types.get(pos, CellType.NORMAL)

# Peut-on marcher sur cette case ? (bon type ET aucune unitÃ© dessus)
func is_walkable(pos: Vector2i, ignore_unit = null) -> bool:
	if not is_valid(pos):
		return false
	if has_unit(pos) and get_unit(pos) != ignore_unit:
		return false
	if not get_terrain_properties(pos)["walkable"]:
		return false
	return not _is_dynamically_blocked_for(pos, &"blocks_movement")

# Le TYPE de la case autorise-t-il l'interaction (survol/clic/ciblage) ?
# Contrairement Ã  is_walkable(), ignore l'occupation par une unitÃ© : on doit
# pouvoir cibler une case occupÃ©e par un ennemi (attaque, sort), seul le
# terrain (WALL, etc.) doit bloquer l'interaction.
func is_terrain_interactable(pos: Vector2i) -> bool:
	if not is_valid(pos):
		return false
	return bool(get_terrain_properties(pos)["walkable"])

# La case laisse-t-elle passer la ligne de vue ?
func is_transparent(pos: Vector2i) -> bool:
	if not is_valid(pos):
		return false
	if not get_terrain_properties(pos)["transparent"]:
		return false
	return not _is_dynamically_blocked_for(pos, &"blocks_line_of_sight")


## Les projectiles disposent de leur propre contrat. Les terrains opaques les
## bloquent par defaut, puis les objets dynamiques peuvent affiner la regle.
func is_projectile_passable(pos: Vector2i) -> bool:
	if not is_valid(pos) or not get_terrain_properties(pos)["projectile_passable"]:
		return false
	return not _is_dynamically_blocked_for(pos, &"blocks_projectiles")


func set_terrain_properties(pos: Vector2i, properties: Dictionary) -> void:
	if not is_valid(pos):
		return
	var defaults: Dictionary = PROPERTIES.get(
		get_type(pos), {"walkable": false, "transparent": false}
	)
	_terrain_properties[pos] = {
		"walkable": bool(properties.get("walkable", defaults.get("walkable", false))),
		"transparent": bool(properties.get("transparent", defaults.get("transparent", false))),
		"projectile_passable": bool(properties.get(
			"projectile_passable", defaults.get("transparent", false)
		)),
		"movement_cost": maxi(1, int(properties.get("movement_cost", 1))),
		"terrain_id": StringName(properties.get("terrain_id", &"")),
		"ai_danger_weight": maxf(0.0, float(properties.get("ai_danger_weight", 0.0))),
	}


func clear_terrain_properties(pos: Vector2i) -> void:
	_terrain_properties.erase(pos)


func set_surface_properties(pos: Vector2i, properties: Dictionary) -> void:
	if not is_valid(pos):
		return
	if properties.is_empty():
		_surface_properties.erase(pos)
		return
	_surface_properties[pos] = properties.duplicate(true)


func clear_surface_properties(pos: Vector2i) -> void:
	_surface_properties.erase(pos)


func get_terrain_properties(pos: Vector2i) -> Dictionary:
	var defaults: Dictionary = PROPERTIES.get(
		get_type(pos), {"walkable": false, "transparent": false}
	)
	var result := {
		"walkable": bool(defaults.get("walkable", false)),
		"transparent": bool(defaults.get("transparent", false)),
		"projectile_passable": bool(defaults.get("transparent", false)),
		"movement_cost": 1,
		"terrain_id": &"",
		"ai_danger_weight": 0.0,
	}
	if _terrain_properties.has(pos):
		result.merge(_terrain_properties[pos] as Dictionary, true)
	if _surface_properties.has(pos):
		result.merge(_surface_properties[pos] as Dictionary, true)
	return result


func get_movement_cost(pos: Vector2i) -> int:
	return maxi(1, int(get_terrain_properties(pos).get("movement_cost", 1)))


func set_vortex_link(entry: Vector2i, destination: Vector2i) -> bool:
	if not is_valid(entry) or not is_valid(destination) or entry == destination:
		return false
	_vortex_links[entry] = destination
	return true


func clear_vortex_links() -> void:
	_vortex_links.clear()


func clear_vortex_networks() -> void:
	_vortex_network_by_cell.clear()


func set_vortex_network(
		network_id: StringName,
		cells: Array[Vector2i],
		allowed_teams := 3,
		enabled := true
	) -> bool:
	var unique: Array[Vector2i] = []
	for cell in cells:
		if is_valid(cell) and not unique.has(cell):
			unique.append(cell)
	if network_id == &"" or unique.is_empty():
		return false
	var data := {
		"network_id": network_id,
		"cells": unique,
		"allowed_teams": allowed_teams,
		"enabled": enabled,
	}
	for cell in unique:
		_vortex_network_by_cell[cell] = data
	if enabled and unique.size() == 2:
		_vortex_links[unique[0]] = unique[1]
		_vortex_links[unique[1]] = unique[0]
	return true


func get_vortex_network(entry: Vector2i) -> Dictionary:
	return (_vortex_network_by_cell.get(entry, {}) as Dictionary).duplicate(true)


func get_vortex_network_cells(entry: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in get_vortex_network(entry).get("cells", []):
		if cell is Vector2i:
			result.append(cell)
	return result


func get_vortex_destination(entry: Vector2i) -> Vector2i:
	return _vortex_links.get(entry, Vector2i(-1, -1)) as Vector2i


func has_vortex(entry: Vector2i) -> bool:
	return _vortex_links.has(entry) or _vortex_network_by_cell.has(entry)


func valid_vortex_destinations(entry: Vector2i, ignore_unit = null) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var network := get_vortex_network(entry)
	if network.is_empty() or not bool(network.get("enabled", false)):
		return result
	if ignore_unit is Unit:
		var team_bit := 1 << clampi((ignore_unit as Unit).team, 0, 1)
		if int(network.get("allowed_teams", 3)) & team_bit == 0:
			return result
	for destination in network.get("cells", []):
		if not destination is Vector2i or destination == entry:
			continue
		if not is_valid(destination) or get_type(destination) in [
			CellType.HOLE, CellType.WALL,
		] or not is_walkable(destination):
			continue
		var occupant = get_unit(destination)
		if occupant != null and occupant != ignore_unit:
			continue
		result.append(destination)
	return result


func can_unit_use_vortex_network(entry: Vector2i, unit: Unit) -> bool:
	var network := get_vortex_network(entry)
	if network.is_empty() or not bool(network.get("enabled", false)):
		return false
	if unit == null:
		return true
	return int(network.get("allowed_teams", 3)) & (1 << clampi(unit.team, 0, 1)) != 0


func vortex_links() -> Dictionary:
	return _vortex_links.duplicate(true)


func can_traverse_vortex(entry: Vector2i, ignore_unit = null) -> bool:
	var destination := get_vortex_destination(entry)
	return destination != Vector2i(-1, -1) and is_walkable(destination, ignore_unit)


## Enregistre des objets temporaires sans ecraser le CellType de base. Cette
## superposition permet de retirer un mur sans rendre praticable un trou, une
## lave locale ou un obstacle permanent.
func register_dynamic_blocker(pos: Vector2i, blocker) -> bool:
	if not is_valid(pos) or blocker == null or not is_instance_valid(blocker):
		return false
	var blockers: Array = _valid_dynamic_blockers(pos)
	if blockers.has(blocker):
		return false
	blockers.append(blocker)
	_dynamic_blockers[pos] = blockers
	dynamic_blocker_changed.emit(pos)
	return true


func unregister_dynamic_blocker(pos: Vector2i, blocker) -> bool:
	if not _dynamic_blockers.has(pos):
		return false
	var blockers: Array = _valid_dynamic_blockers(pos)
	var removed := false
	if blocker == null:
		removed = not blockers.is_empty()
		blockers.clear()
	else:
		removed = blockers.has(blocker)
		if removed:
			blockers.erase(blocker)
	if blockers.is_empty():
		_dynamic_blockers.erase(pos)
	else:
		_dynamic_blockers[pos] = blockers
	if removed:
		dynamic_blocker_changed.emit(pos)
	return removed


func clear_dynamic_blockers() -> void:
	var changed_cells := _dynamic_blockers.keys()
	_dynamic_blockers.clear()
	for cell in changed_cells:
		dynamic_blocker_changed.emit(cell)


func is_cell_dynamically_blocked(pos: Vector2i) -> bool:
	return not _valid_dynamic_blockers(pos).is_empty()


func get_dynamic_blockers(pos: Vector2i) -> Array:
	return _valid_dynamic_blockers(pos).duplicate()


func _is_dynamically_blocked_for(pos: Vector2i, capability: StringName) -> bool:
	for blocker in _valid_dynamic_blockers(pos):
		if blocker.has_method(capability) and bool(blocker.call(capability)):
			return true
	return false


func _valid_dynamic_blockers(pos: Vector2i) -> Array:
	var blockers: Array = _dynamic_blockers.get(pos, [])
	var valid: Array = []
	for blocker in blockers:
		if blocker != null and is_instance_valid(blocker):
			valid.append(blocker)
	if valid.is_empty():
		_dynamic_blockers.erase(pos)
	else:
		_dynamic_blockers[pos] = valid
	return valid

# ============================================================
# MODIFICATION DES TYPES (sorts de terrain, gÃ©nÃ©ration de map)
# ============================================================

func set_type(pos: Vector2i, type: CellType) -> void:
	if is_valid(pos):
		_types[pos] = type

# ============================================================
# GESTION DES UNITÃ‰S
# On stocke juste QUI est oÃ¹. Le dÃ©placement visuel est gÃ©rÃ© ailleurs.
# ============================================================

func has_unit(pos: Vector2i) -> bool:
	return _units.has(pos)

func get_unit(pos: Vector2i):
	return _units.get(pos, null)


func get_units() -> Array:
	var result: Array = []
	for unit_value in _units.values():
		if unit_value != null and not result.has(unit_value):
			result.append(unit_value)
	return result


func count_living_in_team(team: int) -> int:
	var count := 0
	for unit_value in get_units():
		var unit := unit_value as Unit
		if unit != null and unit.is_alive and unit.team == team:
			count += 1
	return count


func has_living_unit_id(team: int, unit_id: StringName) -> bool:
	for unit_value in get_units():
		var unit := unit_value as Unit
		if unit != null and unit.is_alive and unit.team == team and unit.unit_id == unit_id:
			return true
	return false


func has_pending_summon_unit_id(team: int, unit_id: StringName) -> bool:
	for unit_value in get_units():
		var unit := unit_value as Unit
		if unit == null or not unit.is_alive or unit.team != team or unit.pending_ability.is_empty():
			continue
		var spell := unit.pending_ability.get("spell") as Spell
		if spell != null and spell.summon_unit_data != null \
				and spell.summon_unit_data.get_effective_unit_id() == unit_id:
			return true
	return false


func _refresh_tactical_links() -> void:
	var living := get_units().filter(func(value):
		var unit := value as Unit
		return unit != null and unit.is_alive
	)
	for unit_value in living:
		var unit := unit_value as Unit
		if unit.linked_commander_role_id == &"":
			continue
		if unit.linked_commander != null and unit.linked_commander.is_alive \
				and find_unit(unit.linked_commander) != Vector2i(-1, -1):
			continue
		var candidates: Array = []
		for candidate_value in living:
			var candidate := candidate_value as Unit
			if candidate == unit or candidate.team != unit.team \
					or candidate.tactical_role_id != unit.linked_commander_role_id:
				continue
			if unit.faction_id != &"" and candidate.faction_id != unit.faction_id:
				continue
			candidates.append(candidate)
		candidates.sort_custom(func(a: Unit, b: Unit) -> bool:
			var distance_a := manhattan(unit.grid_pos, a.grid_pos)
			var distance_b := manhattan(unit.grid_pos, b.grid_pos)
			if distance_a != distance_b:
				return distance_a < distance_b
			return a.get_runtime_stable_id() < b.get_runtime_stable_id()
		)
		unit.linked_commander = candidates[0] if not candidates.is_empty() else null


func refresh_proximity_passives() -> void:
	_refresh_tactical_links()
	for unit_value in get_units():
		var unit := unit_value as Unit
		if unit != null:
			unit.refresh_proximity_passive(self)


func _after_occupancy_change(
		reason: StringName,
		unit,
		from_pos: Vector2i,
		to_pos: Vector2i
	) -> void:
	refresh_proximity_passives()
	occupancy_changed.emit(reason, unit, from_pos, to_pos)

func place_unit(unit, pos: Vector2i) -> bool:
	if unit == null or not is_valid(pos):
		return false
	# Le placement est atomique : une destination occupée ne doit jamais retirer
	# l'unité de sa case actuelle avant de signaler l'échec.
	if _units.has(pos) and _units[pos] != unit:
		return false
	var previous := find_unit(unit)
	if previous != Vector2i(-1, -1):
		_units.erase(previous)
	_units[pos] = unit
	if unit.combat_order < 0:
		unit.combat_order = _next_combat_order
		_next_combat_order += 1
	unit.grid_context = self
	unit.grid_pos = pos
	_after_occupancy_change(&"placed", unit, previous, pos)
	return true

func remove_unit(unit) -> void:
	if unit == null:
		return
	var pos := find_unit(unit)
	if pos == Vector2i(-1, -1) and is_valid(unit.grid_pos):
		pos = unit.grid_pos
	if pos != Vector2i(-1, -1):
		_units.erase(pos)
	unit.grid_context = null
	unit.grid_pos = Vector2i(-1, -1)
	_after_occupancy_change(&"removed", unit, pos, Vector2i(-1, -1))

func relocate_unit(unit, to: Vector2i) -> bool:
	if unit == null or not is_valid(to):
		return false
	var from := find_unit(unit)
	if from == Vector2i(-1, -1):
		from = unit.grid_pos
	if from == to:
		unit.grid_pos = to
		return true
	if _units.has(to):
		return false
	if from != Vector2i(-1, -1):
		_units.erase(from)
	_units[to] = unit
	unit.grid_context = self
	unit.grid_pos = to
	_after_occupancy_change(&"relocated", unit, from, to)
	return true

func set_unit(pos: Vector2i, unit) -> bool:
	return place_unit(unit, pos)

func clear_unit(pos: Vector2i) -> void:
	var unit = _units.get(pos, null)
	_units.erase(pos)
	if unit != null and unit.grid_pos == pos:
		unit.grid_context = null
		unit.grid_pos = Vector2i(-1, -1)
	_after_occupancy_change(&"cleared", unit, pos, Vector2i(-1, -1))

# DÃ©place une unitÃ© d'une case Ã  une autre dans les donnÃ©es.
func move_unit(from: Vector2i, to: Vector2i) -> void:
	var unit = _units.get(from, null)
	if unit != null:
		relocate_unit(unit, to)

# Retourne la position d'une unitÃ© donnÃ©e (ou Vector2i(-1,-1) si absente).
func find_unit(unit) -> Vector2i:
	for pos in _units:
		if _units[pos] == unit:
			return pos
	return Vector2i(-1, -1)


func on_unit_became_dead(dead_unit: Unit) -> void:
	for unit_value in get_units():
		var unit := unit_value as Unit
		if unit == null:
			continue
		unit.remove_statuses_from_source(dead_unit)
		if unit.linked_commander == dead_unit:
			unit.linked_commander = null
	refresh_proximity_passives()

# ============================================================
# EFFETS DE TERRAIN (sorts actifs avec durÃ©e, dÃ©gÃ¢ts, etc.)
# StockÃ©s Ã  part. Le contenu de "data" est libre.
# ============================================================

func set_effect(pos: Vector2i, effect_name: String, data: Dictionary = {}) -> void:
	if is_valid(pos):
		_effects[pos] = { "name": effect_name, "data": data }

func get_effect(pos: Vector2i):
	return _effects.get(pos, null)

func clear_effect(pos: Vector2i) -> void:
	_effects.erase(pos)

# ============================================================
# UTILITAIRES DE DISTANCE
# ============================================================

# Distance de Manhattan : nombre de pas orthogonaux entre deux cases.
# C'est la distance "Dofus" (pas de diagonale).
func manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return manhattan(a, b) == 1
