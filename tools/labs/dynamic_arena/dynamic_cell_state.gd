class_name DynamicCellState
extends RefCounted

## Etat logique des surfaces du laboratoire.
## Les textures ne sont jamais consultees pour determiner la praticabilite.

signal cell_surface_changed(
	cell: Vector2i,
	previous_surface: int,
	surface: int,
	walkability_changed: bool
)
signal cell_blocking_changed(cell: Vector2i, blocked: bool)

enum Surface {
	STONE,
	WATER,
	ICE,
	LAVA,
}

const DEFAULT_WALKABILITY := {
	Surface.STONE: true,
	Surface.WATER: true,
	Surface.ICE: true,
	Surface.LAVA: false,
}

const SURFACE_NAMES := {
	Surface.STONE: "STONE",
	Surface.WATER: "WATER",
	Surface.ICE: "ICE",
	Surface.LAVA: "LAVA",
}

var grid: GridData = null
var _surfaces: Dictionary = {}
var _blocking_objects: Dictionary = {}
var _walkability: Dictionary = DEFAULT_WALKABILITY.duplicate()


func configure(
	grid_data: GridData,
	default_surface: int = Surface.STONE,
	walkability_overrides: Dictionary = {}
	) -> void:
	assert(grid_data != null, "DynamicCellState requiert un GridData existant.")
	grid = grid_data
	_walkability = DEFAULT_WALKABILITY.duplicate()
	for surface in walkability_overrides:
		if Surface.values().has(int(surface)):
			_walkability[int(surface)] = bool(walkability_overrides[surface])
	reset(default_surface, false)


func reset(default_surface: int = Surface.STONE, emit_changes := true) -> void:
	if grid == null:
		return
	assert(Surface.values().has(default_surface), "Surface de reset inconnue.")
	var previous := _surfaces.duplicate()
	_surfaces.clear()
	_blocking_objects.clear()
	for x in range(grid.cols):
		for y in range(grid.rows):
			var cell := Vector2i(x, y)
			var old_surface: int = int(previous.get(cell, default_surface))
			_surfaces[cell] = default_surface
			_apply_cell_to_grid(cell)
			if emit_changes and old_surface != default_surface:
				cell_surface_changed.emit(
					cell,
					old_surface,
					default_surface,
					is_surface_walkable(old_surface) != is_surface_walkable(default_surface)
				)


func set_surface(cell: Vector2i, surface: int) -> bool:
	if grid == null or not grid.is_valid(cell) or not Surface.values().has(surface):
		return false
	var previous := get_surface(cell)
	if previous == surface:
		return false
	var was_walkable := is_effectively_walkable(cell)
	_surfaces[cell] = surface
	_apply_cell_to_grid(cell)
	var walkability_changed := was_walkable != is_effectively_walkable(cell)
	cell_surface_changed.emit(cell, previous, surface, walkability_changed)
	return true


func cycle_surface(cell: Vector2i) -> int:
	var next_surface := (get_surface(cell) + 1) % Surface.size()
	set_surface(cell, next_surface)
	return next_surface


func get_surface(cell: Vector2i) -> int:
	return int(_surfaces.get(cell, Surface.STONE))


func get_surface_name(cell: Vector2i) -> String:
	return surface_name(get_surface(cell))


func surface_name(surface: int) -> String:
	return str(SURFACE_NAMES.get(surface, "UNKNOWN"))


func is_surface_walkable(surface: int) -> bool:
	return bool(_walkability.get(surface, false))


func is_effectively_walkable(cell: Vector2i) -> bool:
	if grid == null or not grid.is_valid(cell) or has_blocker(cell):
		return false
	return is_surface_walkable(get_surface(cell))


func set_blocker(cell: Vector2i, blocked: bool) -> bool:
	if grid == null or not grid.is_valid(cell):
		return false
	if has_blocker(cell) == blocked:
		return false
	if blocked:
		_blocking_objects[cell] = true
	else:
		_blocking_objects.erase(cell)
	_apply_cell_to_grid(cell)
	cell_blocking_changed.emit(cell, blocked)
	return true


func has_blocker(cell: Vector2i) -> bool:
	return bool(_blocking_objects.get(cell, false))


func state_count() -> int:
	return _surfaces.size()


func _apply_cell_to_grid(cell: Vector2i) -> void:
	if not is_effectively_walkable(cell):
		grid.set_type(cell, GridData.CellType.WALL)
		return
	match get_surface(cell):
		Surface.ICE:
			grid.set_type(cell, GridData.CellType.ICE)
		Surface.LAVA:
			# Cette branche n'est utilisee que si la regle locale rend la lave
			# praticable. La regle de production de GridData reste intacte.
			grid.set_type(cell, GridData.CellType.LAVA)
		_:
			grid.set_type(cell, GridData.CellType.NORMAL)
