class_name ArenaMapDocument
extends RefCounted

## Document versionne et independant du rendu. Une cellule peut porter un sol,
## un effet temporaire, un marqueur special ou un mur. Les coordonnees restent
## exclusivement logiques.

signal changed(cell: Vector2i, previous: Dictionary, current: Dictionary)
signal resized(previous_size: Vector2i, current_size: Vector2i)
signal metadata_changed()
signal reset_completed()

const SCHEMA_VERSION := 1

enum BaseTile {
	VOID,
	STONE,
	WATER,
	ICE,
	LAVA,
	SHADOW,
	RUNE,
}

enum SurfaceEffect {
	NONE,
	FIRE,
	WATER,
	ICE,
}

enum SpecialTile {
	NONE,
	ALLY_SPAWN,
	ENEMY_SPAWN,
	OBJECTIVE,
	DECOR_ANCHOR,
}

enum WallType {
	NONE,
	BASE,
	FIRE,
	ICE,
}

enum EditLayer {
	BASE,
	SURFACE,
	SPECIAL,
	WALL,
}

const BASE_NAMES := ["VOID", "STONE", "WATER", "ICE", "LAVA", "SHADOW", "RUNE"]
const SURFACE_NAMES := ["NONE", "FIRE", "WATER", "ICE"]
const SPECIAL_NAMES := ["NONE", "ALLY_SPAWN", "ENEMY_SPAWN", "OBJECTIVE", "DECOR_ANCHOR"]
const WALL_NAMES := ["NONE", "BASE", "FIRE", "ICE"]
const LAYER_NAMES := ["SOL", "EFFET", "SPECIAL", "MUR"]

var map_id := "new_arena"
var display_name := "Nouvelle arene"
var map_kind := "reference"
var theme_id := "neutral"
var decor_prompt := "Construire le decor autour de l'arene sans modifier sa grille."
var tags: PackedStringArray = PackedStringArray()
var grid_size := Vector2i(12, 10)
var _cells: Dictionary = {}


func _init(size: Vector2i = Vector2i(12, 10)) -> void:
	reset(size)


func reset(size: Vector2i, base_tile: int = BaseTile.STONE) -> void:
	grid_size = Vector2i(maxi(1, size.x), maxi(1, size.y))
	_cells.clear()
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			_cells[Vector2i(x, y)] = _default_cell(base_tile)
	reset_completed.emit()


func resize(new_size: Vector2i, fill_tile: int = BaseTile.STONE) -> void:
	new_size = Vector2i(maxi(1, new_size.x), maxi(1, new_size.y))
	if new_size == grid_size:
		return
	var previous_size := grid_size
	var previous_cells := _cells
	grid_size = new_size
	_cells = {}
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := Vector2i(x, y)
			_cells[cell] = previous_cells.get(cell, _default_cell(fill_tile)).duplicate(true)
	resized.emit(previous_size, grid_size)


func set_metadata(
		new_map_id: String,
		new_display_name: String,
		new_kind: String,
		new_theme_id: String,
		new_decor_prompt: String
	) -> void:
	map_id = _sanitize_id(new_map_id)
	display_name = new_display_name.strip_edges()
	map_kind = new_kind.strip_edges().to_lower()
	theme_id = _sanitize_id(new_theme_id)
	decor_prompt = new_decor_prompt.strip_edges()
	metadata_changed.emit()


func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func get_cell(cell: Vector2i) -> Dictionary:
	return _cells.get(cell, _default_cell(BaseTile.VOID)).duplicate(true)


func set_layer(cell: Vector2i, layer: int, value: int) -> bool:
	if not is_valid_cell(cell) or layer < EditLayer.BASE or layer > EditLayer.WALL:
		return false
	var previous := get_cell(cell)
	var current := previous.duplicate(true)
	match layer:
		EditLayer.BASE:
			if value < BaseTile.VOID or value > BaseTile.RUNE:
				return false
			current.base = value
			if value == BaseTile.VOID:
				current.surface = SurfaceEffect.NONE
				current.special = SpecialTile.NONE
				current.wall = WallType.NONE
		EditLayer.SURFACE:
			if value < SurfaceEffect.NONE or value > SurfaceEffect.ICE \
					or int(current.base) == BaseTile.VOID:
				return false
			current.surface = value
			if value != SurfaceEffect.NONE:
				current.wall = WallType.NONE
		EditLayer.SPECIAL:
			if value < SpecialTile.NONE or value > SpecialTile.DECOR_ANCHOR \
					or int(current.base) == BaseTile.VOID:
				return false
			current.special = value
			if value != SpecialTile.NONE:
				current.wall = WallType.NONE
		EditLayer.WALL:
			if value < WallType.NONE or value > WallType.ICE \
					or int(current.base) == BaseTile.VOID:
				return false
			current.wall = value
			if value != WallType.NONE:
				current.surface = SurfaceEffect.NONE
				current.special = SpecialTile.NONE
	if current == previous:
		return false
	_cells[cell] = current
	changed.emit(cell, previous, current.duplicate(true))
	return true


func set_cell(cell: Vector2i, state: Dictionary) -> bool:
	if not is_valid_cell(cell):
		return false
	var normalized := _normalize_cell(state)
	var previous := get_cell(cell)
	if previous == normalized:
		return false
	_cells[cell] = normalized
	changed.emit(cell, previous, normalized.duplicate(true))
	return true


func fill_layer(layer: int, value: int) -> int:
	var changed_count := 0
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if set_layer(Vector2i(x, y), layer, value):
				changed_count += 1
	return changed_count


func all_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			result.append(Vector2i(x, y))
	return result


func active_cells() -> Array[Vector2i]:
	return all_cells().filter(func(cell: Vector2i):
		return int(_cells[cell].base) != BaseTile.VOID
	)


func cells_with(layer: int, value: int) -> Array[Vector2i]:
	var field := _field_for_layer(layer)
	if field.is_empty():
		return []
	return all_cells().filter(func(cell: Vector2i):
		return int(_cells[cell][field]) == value
	)


func counts() -> Dictionary:
	var result := {
		"total": grid_size.x * grid_size.y,
		"active": active_cells().size(),
		"void": cells_with(EditLayer.BASE, BaseTile.VOID).size(),
		"surfaces": 0,
		"specials": 0,
		"walls": 0,
	}
	for cell in all_cells():
		var state := _cells[cell] as Dictionary
		if int(state.surface) != SurfaceEffect.NONE:
			result.surfaces += 1
		if int(state.special) != SpecialTile.NONE:
			result.specials += 1
		if int(state.wall) != WallType.NONE:
			result.walls += 1
	return result


func snapshot() -> Dictionary:
	return to_dict().duplicate(true)


func restore_snapshot(data: Dictionary) -> bool:
	return load_from_dict(data)


func to_dict() -> Dictionary:
	var serialized_cells: Array[Dictionary] = []
	for cell in all_cells():
		var state := _cells[cell] as Dictionary
		serialized_cells.append({
			"x": cell.x,
			"y": cell.y,
			"base": BASE_NAMES[int(state.base)],
			"surface": SURFACE_NAMES[int(state.surface)],
			"special": SPECIAL_NAMES[int(state.special)],
			"wall": WALL_NAMES[int(state.wall)],
		})
	return {
		"schema_version": SCHEMA_VERSION,
		"map_id": map_id,
		"display_name": display_name,
		"map_kind": map_kind,
		"theme_id": theme_id,
		"decor_prompt": decor_prompt,
		"tags": Array(tags),
		"grid_size": [grid_size.x, grid_size.y],
		"projection": {"tile_width": 64, "tile_height": 32, "layout": "diamond_down"},
		"cells": serialized_cells,
	}


func load_from_dict(data: Dictionary) -> bool:
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		return false
	var size_data = data.get("grid_size", [])
	if not size_data is Array or size_data.size() != 2:
		return false
	var size := Vector2i(int(size_data[0]), int(size_data[1]))
	if size.x <= 0 or size.y <= 0:
		return false
	map_id = _sanitize_id(str(data.get("map_id", "new_arena")))
	display_name = str(data.get("display_name", "Nouvelle arene"))
	map_kind = str(data.get("map_kind", "reference"))
	theme_id = _sanitize_id(str(data.get("theme_id", "neutral")))
	decor_prompt = str(data.get("decor_prompt", ""))
	tags = PackedStringArray(data.get("tags", []))
	grid_size = size
	_cells.clear()
	var default_base := maxi(0, BASE_NAMES.find(str(data.get("default_base", "VOID"))))
	for cell in all_cells():
		_cells[cell] = _default_cell(default_base)
	for entry_value in data.get("cells", []):
		if not entry_value is Dictionary:
			continue
		var entry := entry_value as Dictionary
		var cell := Vector2i(int(entry.get("x", -1)), int(entry.get("y", -1)))
		if not is_valid_cell(cell):
			continue
		var existing := _cells[cell] as Dictionary
		_cells[cell] = {
			"base": maxi(0, BASE_NAMES.find(str(entry.get("base", BASE_NAMES[int(existing.base)])))),
			"surface": maxi(0, SURFACE_NAMES.find(str(entry.get("surface", SURFACE_NAMES[int(existing.surface)])))),
			"special": maxi(0, SPECIAL_NAMES.find(str(entry.get("special", SPECIAL_NAMES[int(existing.special)])))),
			"wall": maxi(0, WALL_NAMES.find(str(entry.get("wall", WALL_NAMES[int(existing.wall)])))),
		}
		_cells[cell] = _normalize_cell(_cells[cell])
	reset_completed.emit()
	metadata_changed.emit()
	return validation_errors().is_empty()


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if map_id.is_empty():
		errors.append("map_id est requis.")
	if display_name.strip_edges().is_empty():
		errors.append("display_name est requis.")
	if grid_size.x <= 0 or grid_size.y <= 0:
		errors.append("La taille doit etre positive.")
	if _cells.size() != grid_size.x * grid_size.y:
		errors.append("Le document ne contient pas exactement une entree par cellule.")
	for cell in _cells:
		if not is_valid_cell(cell):
			errors.append("Cellule hors grille : %s." % cell)
		var state := _cells[cell] as Dictionary
		if int(state.base) == BaseTile.VOID and (
				int(state.surface) != SurfaceEffect.NONE
				or int(state.special) != SpecialTile.NONE
				or int(state.wall) != WallType.NONE
			):
			errors.append("Une cellule VOID porte un contenu : %s." % cell)
	return errors


func _default_cell(base_tile: int) -> Dictionary:
	return {
		"base": clampi(base_tile, BaseTile.VOID, BaseTile.RUNE),
		"surface": SurfaceEffect.NONE,
		"special": SpecialTile.NONE,
		"wall": WallType.NONE,
	}


func _normalize_cell(state: Dictionary) -> Dictionary:
	var normalized := {
		"base": clampi(int(state.get("base", BaseTile.VOID)), BaseTile.VOID, BaseTile.RUNE),
		"surface": clampi(int(state.get("surface", SurfaceEffect.NONE)), SurfaceEffect.NONE, SurfaceEffect.ICE),
		"special": clampi(int(state.get("special", SpecialTile.NONE)), SpecialTile.NONE, SpecialTile.DECOR_ANCHOR),
		"wall": clampi(int(state.get("wall", WallType.NONE)), WallType.NONE, WallType.ICE),
	}
	if normalized.base == BaseTile.VOID:
		normalized.surface = SurfaceEffect.NONE
		normalized.special = SpecialTile.NONE
		normalized.wall = WallType.NONE
	elif normalized.wall != WallType.NONE:
		normalized.surface = SurfaceEffect.NONE
		normalized.special = SpecialTile.NONE
	return normalized


func _field_for_layer(layer: int) -> String:
	return ["base", "surface", "special", "wall"][layer] \
			if layer >= 0 and layer < EditLayer.size() else ""


func _sanitize_id(value: String) -> String:
	var result := value.strip_edges().to_lower().replace(" ", "_")
	var safe := ""
	for character in result:
		if character.to_ascii_buffer()[0] in range(48, 58) \
				or character.to_ascii_buffer()[0] in range(97, 123) \
				or character in ["_", "-"]:
			safe += character
	return safe if not safe.is_empty() else "new_arena"
