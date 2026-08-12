@tool
class_name RoomGridLayout
extends Resource

## Donnees declaratives propres a une salle. Cette ressource ne remplace ni
## GridData ni Pathfinder : elle remplit une instance du moteur commun au
## demarrage du combat, puis GridData reste l'unique autorite spatiale.

const WALKABLE := "."
const BLOCKED := "#"
const VOID := "X"
const LANDMARK := "R"
const ALLY_SPAWN := "A"
const ENEMY_SPAWN := "E"
const SPECIAL := "~"
const ALLOWED_SYMBOLS := ".#XRAE~"

@export var layout_id: StringName = &"room_grid_layout"
@export var debug_name := "Room grid layout"
@export var logical_size := Vector2i(14, 14)

## Une topologie partagee evite de recopier une matrice identique. Quand cette
## propriete est renseignee, layout_rows reste vide et seules les surcharges de
## terrain de la salle sont appliquees par-dessus la base.
@export var base_layout: RoomGridLayout = null
@export var layout_rows := PackedStringArray()

@export_group("Terrain explicite")
@export_enum("NONE:-1", "NORMAL:0", "WALL:1", "HOLE:2", "LAVA:3", "ICE:4", "SHADOW:5", "RUNE:6")
var terrain_cell_type := -1
@export var terrain_cells: Array[Vector2i] = []
## Surcharges cellule -> GridData.CellType pour les arenes produites par Arena
## Studio. Le contrat historique terrain_cell_type/terrain_cells reste intact.
@export var cell_type_overrides: Dictionary = {}
## Surcharges data-driven cellule -> propriétés du terrain permanent.
@export var terrain_property_overrides: Dictionary = {}
## Arêtes spatiales bidirectionnelles cellule -> cellule pour les vortex.
@export var vortex_links: Dictionary = {}
## Réseaux cellule -> {network_id, cells, enabled, allowed_teams}.
@export var vortex_networks: Dictionary = {}
@export var objective_cells: Array[Vector2i] = []
@export var visual_only_cells: Array[Vector2i] = []


func symbol_at(cell: Vector2i) -> String:
	if not is_in_bounds(cell):
		return VOID
	if not layout_rows.is_empty():
		if cell.y >= layout_rows.size() or cell.x >= layout_rows[cell.y].length():
			return VOID
		return layout_rows[cell.y].substr(cell.x, 1)
	if base_layout != null:
		return base_layout.symbol_at(cell)
	return VOID


func resolved_symbol_at(cell: Vector2i) -> String:
	if terrain_cells.has(cell) and _terrain_type_is_walkable():
		return SPECIAL
	return symbol_at(cell)


func resolved_cell_type(cell: Vector2i) -> GridData.CellType:
	if cell_type_overrides.has(cell):
		return int(cell_type_overrides[cell])
	if terrain_cells.has(cell) and terrain_cell_type >= 0:
		return terrain_cell_type
	match symbol_at(cell):
		VOID:
			return GridData.CellType.HOLE
		BLOCKED, LANDMARK:
			return GridData.CellType.WALL
		SPECIAL:
			return GridData.CellType.ICE
		_:
			return GridData.CellType.NORMAL


func apply_to_grid(grid: GridData) -> void:
	if grid == null:
		return
	if base_layout != null:
		base_layout.apply_to_grid(grid)
	else:
		for y in range(mini(grid.rows, logical_size.y)):
			for x in range(mini(grid.cols, logical_size.x)):
				var cell := Vector2i(x, y)
				grid.set_type(cell, resolved_cell_type(cell))
	for cell in terrain_cells:
		if grid.is_valid(cell) and terrain_cell_type >= 0:
			grid.set_type(cell, terrain_cell_type)
	for cell_value in cell_type_overrides:
		if cell_value is Vector2i and grid.is_valid(cell_value):
			grid.set_type(cell_value, int(cell_type_overrides[cell_value]))
	for cell_value in terrain_property_overrides:
		if cell_value is Vector2i and grid.is_valid(cell_value):
			grid.set_terrain_properties(
				cell_value, terrain_property_overrides[cell_value] as Dictionary
			)
	grid.clear_vortex_links()
	grid.clear_vortex_networks()
	for entry_value in vortex_links:
		if entry_value is Vector2i and vortex_links[entry_value] is Vector2i:
			grid.set_vortex_link(entry_value, vortex_links[entry_value])
	var installed := {}
	for entry_value in vortex_networks:
		if not entry_value is Vector2i or not vortex_networks[entry_value] is Dictionary:
			continue
		var network_data := vortex_networks[entry_value] as Dictionary
		var network_id := StringName(network_data.get("network_id", ""))
		if network_id == &"" or installed.has(network_id):
			continue
		installed[network_id] = true
		var cells: Array[Vector2i] = []
		for cell in network_data.get("cells", []):
			if cell is Vector2i:
				cells.append(cell)
		grid.set_vortex_network(
			network_id, cells, int(network_data.get("allowed_teams", 3)),
			bool(network_data.get("enabled", true))
		)


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 \
		and cell.x < logical_size.x and cell.y < logical_size.y


func cells_for(symbol: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(logical_size.y):
		for x in range(logical_size.x):
			var cell := Vector2i(x, y)
			if symbol_at(cell) == symbol:
				result.append(cell)
	return result


func walkable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(logical_size.y):
		for x in range(logical_size.x):
			var cell := Vector2i(x, y)
			if GridData.PROPERTIES[resolved_cell_type(cell)]["walkable"]:
				result.append(cell)
	return result


func blocked_cells() -> Array[Vector2i]:
	var result := cells_for(BLOCKED)
	result.append_array(cells_for(LANDMARK))
	return result


func void_cells() -> Array[Vector2i]:
	return cells_for(VOID)


func landmark_cells() -> Array[Vector2i]:
	return cells_for(LANDMARK)


func layout_counts() -> Dictionary:
	var counts := {
		WALKABLE: 0,
		BLOCKED: 0,
		VOID: 0,
		LANDMARK: 0,
		ALLY_SPAWN: 0,
		ENEMY_SPAWN: 0,
		SPECIAL: 0,
	}
	for y in range(logical_size.y):
		for x in range(logical_size.x):
			var symbol := resolved_symbol_at(Vector2i(x, y))
			counts[symbol] = int(counts.get(symbol, 0)) + 1
	return counts


func composed_ascii(
		hero_spawn_cells: Array[Vector2i],
		enemy_spawn_cells: Array[Vector2i]
	) -> PackedStringArray:
	var rows := PackedStringArray()
	for y in range(logical_size.y):
		var row := ""
		for x in range(logical_size.x):
			var cell := Vector2i(x, y)
			var symbol := resolved_symbol_at(cell)
			if hero_spawn_cells.has(cell):
				symbol = ALLY_SPAWN
			elif enemy_spawn_cells.has(cell):
				symbol = ENEMY_SPAWN
			row += symbol
		rows.append(row)
	return rows


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if logical_size.x <= 0 or logical_size.y <= 0:
		errors.append("logical_size doit etre strictement positif.")
	if base_layout == self:
		errors.append("base_layout ne peut pas se referencer lui-meme.")
	if base_layout != null:
		if not layout_rows.is_empty():
			errors.append("Un layout derive ne doit pas recopier layout_rows.")
		if base_layout.logical_size != logical_size:
			errors.append("Le layout derive doit conserver la taille de sa base.")
	else:
		if layout_rows.size() != logical_size.y:
			errors.append("Le layout de base doit contenir %d lignes." % logical_size.y)
		for y in range(layout_rows.size()):
			var row := layout_rows[y]
			if row.length() != logical_size.x:
				errors.append("La ligne %d doit contenir %d symboles." % [y, logical_size.x])
			for x in range(row.length()):
				var symbol := row.substr(x, 1)
				if ALLOWED_SYMBOLS.find(symbol) < 0:
					errors.append("Symbole inconnu '%s' en (%d, %d)." % [symbol, x, y])
	if terrain_cell_type < -1 or terrain_cell_type > GridData.CellType.RUNE:
		errors.append("terrain_cell_type est inconnu.")
	if terrain_cell_type < 0 and not terrain_cells.is_empty():
		errors.append("Des cellules de terrain existent sans type explicite.")
	var unique_terrain := {}
	for cell in terrain_cells:
		if unique_terrain.has(cell):
			errors.append("Cellule de terrain dupliquee : %s." % cell)
		unique_terrain[cell] = true
		if not is_in_bounds(cell):
			errors.append("Cellule de terrain hors grille : %s." % cell)
		elif symbol_at(cell) in [VOID, BLOCKED, LANDMARK]:
			errors.append("Terrain special sur une cellule non praticable : %s." % cell)
	for cell_value in cell_type_overrides:
		if not cell_value is Vector2i:
			errors.append("Une cle de surcharge de terrain n'est pas une cellule.")
			continue
		var cell := cell_value as Vector2i
		var value := int(cell_type_overrides[cell])
		if not is_in_bounds(cell):
			errors.append("Surcharge de terrain hors grille : %s." % cell)
		if value < GridData.CellType.NORMAL or value > GridData.CellType.RUNE:
			errors.append("Type de surcharge inconnu en %s." % cell)
	for cell_value in terrain_property_overrides:
		if not cell_value is Vector2i or not is_in_bounds(cell_value):
			errors.append("Surcharge de propriétés de terrain invalide : %s." % cell_value)
	for entry_value in vortex_links:
		if not entry_value is Vector2i or not vortex_links[entry_value] is Vector2i:
			errors.append("Arête de vortex invalide.")
			continue
		var destination := vortex_links[entry_value] as Vector2i
		if not is_in_bounds(entry_value) or not is_in_bounds(destination) \
				or entry_value == destination:
			errors.append("Arête de vortex hors contrat : %s -> %s." % [entry_value, destination])
	return errors


func _terrain_type_is_walkable() -> bool:
	return terrain_cell_type >= 0 \
		and bool(GridData.PROPERTIES[terrain_cell_type]["walkable"])
