class_name ForestArenaIntegrationMap
extends RefCounted

enum CellCategory {
	PLAYABLE,
	BORDER,
	VOID,
}

const CATEGORY_NAMES := ["PLAYABLE", "BORDER", "VOID"]

var document: ArenaMapDocument = null
var grid_size := Vector2i.ZERO
var border_thickness := 1
var _states: Dictionary = {}
var _categories: Dictionary = {}
var _errors := PackedStringArray()
var _warnings := PackedStringArray()


func load_from_path(path: String, requested_border_thickness := 1) -> bool:
	_states.clear()
	_categories.clear()
	_errors.clear()
	_warnings.clear()
	border_thickness = maxi(1, requested_border_thickness)
	if not FileAccess.file_exists(path):
		_errors.append("JSON absent : %s" % path)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_errors.append("JSON invalide : racine non dictionnaire.")
		return false
	var raw := parsed as Dictionary
	document = ArenaMapSerializer.load_json(path)
	if document == null:
		_errors.append("ArenaMapSerializer refuse le JSON.")
		return false
	_errors.append_array(document.validation_errors())
	grid_size = document.grid_size
	var projection: Dictionary = raw.get("projection", {})
	if int(projection.get("tile_width", 0)) != 64 \
			or int(projection.get("tile_height", 0)) != 32 \
			or str(projection.get("layout", "")) != "diamond_down":
		_errors.append("Projection attendue : 64 x 32 diamond_down.")
	var raw_cells = raw.get("cells", [])
	if not raw_cells is Array:
		_errors.append("Le champ cells doit etre un tableau.")
		return false
	for raw_state in raw_cells:
		if not raw_state is Dictionary:
			_errors.append("Une cellule JSON n'est pas un dictionnaire.")
			continue
		var state := (raw_state as Dictionary).duplicate(true)
		var cell := Vector2i(int(state.get("x", -1)), int(state.get("y", -1)))
		if not document.is_valid_cell(cell):
			_errors.append("Cellule hors grille : %s." % cell)
			continue
		if _states.has(cell):
			_errors.append("Cellule dupliquee : %s." % cell)
			continue
		state["base"] = str(state.get("base", "STONE")).to_upper()
		state["surface"] = str(state.get("surface", "NONE")).to_upper()
		state["special"] = str(state.get("special", "NONE")).to_upper()
		state["wall"] = str(state.get("wall", "NONE")).to_upper()
		_states[cell] = state
	if _states.size() != grid_size.x * grid_size.y:
		_errors.append("Le JSON doit decrire exactement %d cellules, trouve %d." % [
			grid_size.x * grid_size.y, _states.size(),
		])
	_build_categories()
	_validate_category_conflicts()
	return _errors.is_empty()


func _build_categories() -> void:
	for cell in _states:
		var state: Dictionary = _states[cell]
		if str(state.base) == "VOID":
			_categories[cell] = CellCategory.VOID
			continue
		var explicit := str(state.get("category", state.get("type", ""))).to_upper()
		if explicit == "BORDER":
			_categories[cell] = CellCategory.BORDER
			continue
		if _is_in_derived_border(cell):
			_categories[cell] = CellCategory.BORDER
		else:
			_categories[cell] = CellCategory.PLAYABLE


func _is_in_derived_border(cell: Vector2i) -> bool:
	return cell.x < border_thickness or cell.y < border_thickness \
			or cell.x >= grid_size.x - border_thickness \
			or cell.y >= grid_size.y - border_thickness


func _validate_category_conflicts() -> void:
	for cell in _states:
		var state: Dictionary = _states[cell]
		var category := get_category(cell)
		if category == CellCategory.BORDER:
			if str(state.wall) != "NONE":
				_errors.append("Mur interdit sur BORDER : %s." % cell)
			if str(state.special) in ["ALLY_SPAWN", "ENEMY_SPAWN", "OBJECTIVE"]:
				_errors.append("%s interdit sur BORDER : %s." % [state.special, cell])
			if str(state.surface) != "NONE":
				_warnings.append("Surface JSON ignoree sur BORDER : %s." % cell)
		elif category == CellCategory.VOID:
			if str(state.wall) != "NONE" or str(state.special) != "NONE" \
					or str(state.surface) != "NONE":
				_errors.append("Une cellule VOID contient du gameplay : %s." % cell)
	for special in ["ALLY_SPAWN", "ENEMY_SPAWN", "OBJECTIVE"]:
		for cell in special_cells(special):
			if get_category(cell) != CellCategory.PLAYABLE:
				_errors.append("%s hors PLAYABLE : %s." % [special, cell])
			if str(get_state(cell).wall) != "NONE":
				_errors.append("%s sous un mur : %s." % [special, cell])


func validation_errors() -> PackedStringArray:
	return _errors.duplicate()


func validation_warnings() -> PackedStringArray:
	return _warnings.duplicate()


func all_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			result.append(Vector2i(x, y))
	return result


func cells_in_category(category: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in all_cells():
		if get_category(cell) == category:
			result.append(cell)
	return result


func get_category(cell: Vector2i) -> int:
	return int(_categories.get(cell, CellCategory.VOID))


func get_category_name(cell: Vector2i) -> String:
	return CATEGORY_NAMES[get_category(cell)]


func get_state(cell: Vector2i) -> Dictionary:
	return (_states.get(cell, {}) as Dictionary).duplicate(true)


func special_cells(special_name: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _states:
		if str((_states[cell] as Dictionary).special) == special_name:
			result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return result


func static_wall_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _states:
		if get_category(cell) == CellCategory.PLAYABLE \
				and str((_states[cell] as Dictionary).wall) != "NONE":
			result.append(cell)
	return result


func apply_to_grid(grid: GridData) -> void:
	assert(grid != null and grid.cols == grid_size.x and grid.rows == grid_size.y)
	for cell in all_cells():
		match get_category(cell):
			CellCategory.BORDER:
				grid.set_type(cell, GridData.CellType.WALL)
			CellCategory.VOID:
				grid.set_type(cell, GridData.CellType.HOLE)
			CellCategory.PLAYABLE:
				grid.set_type(cell, _base_to_grid_type(str(get_state(cell).base)))


func _base_to_grid_type(base_name: String) -> int:
	match base_name:
		"LAVA":
			return GridData.CellType.LAVA
		"ICE":
			return GridData.CellType.ICE
		"SHADOW":
			return GridData.CellType.SHADOW
		"RUNE":
			return GridData.CellType.RUNE
		_:
			return GridData.CellType.NORMAL
