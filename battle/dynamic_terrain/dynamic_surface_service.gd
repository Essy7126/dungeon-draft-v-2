class_name DynamicSurfaceService
extends RefCounted

## Couche de surfaces branchee sur l'unique GridData du combat. Elle conserve
## le type de terrain de base, stocke l'effet dans GridData et expose les API
## de rendu attendues par les adaptateurs visuels.

signal surface_changed(cell: Vector2i, previous_surface: int, surface: int)
signal steam_requested(cell: Vector2i)

var grid: GridData = null
var configs: Dictionary = {}
var _states: Dictionary = {}


func configure(grid_data: GridData, surface_configs: Array[SurfaceConfig]) -> void:
	assert(grid_data != null, "DynamicSurfaceService requiert le GridData existant.")
	grid = grid_data
	configs.clear()
	for config in surface_configs:
		if config != null:
			configs[config.surface] = config
	_states.clear()
	for y in range(grid.rows):
		for x in range(grid.cols):
			var cell := Vector2i(x, y)
			if grid.is_terrain_interactable(cell):
				var state := CellSurfaceState.new()
				state.configure_base(grid.get_type(cell))
				_states[cell] = state


func apply_surface_effect(cell: Vector2i, effect: int, source_unit = null) -> Dictionary:
	if not has_state(cell) or not configs.has(effect):
		return {"handled": false, "surface": get_surface(cell), "steam": false}
	var previous := get_surface(cell)
	var result := TerrainInteractionResolver.resolve(previous, effect)
	var next_surface: int = int(result.surface)
	if next_surface == CellSurfaceState.DynamicSurface.NONE:
		clear_surface(cell)
	else:
		set_surface(cell, next_surface, source_unit)
	if bool(result.steam):
		steam_requested.emit(cell)
	result["handled"] = true
	result["previous_surface"] = previous
	return result


func set_surface(cell: Vector2i, surface: int, source_unit = null) -> bool:
	if not has_state(cell) or not configs.has(surface):
		return false
	var state := get_state(cell)
	var previous: int = state.dynamic_surface
	var config := configs[surface] as SurfaceConfig
	state.configure(surface, config.duration_turns, source_unit, config.gameplay_flags)
	grid.set_effect(cell, config.display_name, {
		"duration_turns": state.duration_turns,
		"source_unit": source_unit,
		"gameplay_flags": state.gameplay_flags.duplicate(true),
	})
	surface_changed.emit(cell, previous, surface)
	return true


func clear_surface(cell: Vector2i) -> bool:
	if not has_state(cell):
		return false
	var state := get_state(cell)
	var previous: int = state.dynamic_surface
	state.clear_dynamic()
	grid.clear_effect(cell)
	if previous != CellSurfaceState.DynamicSurface.NONE:
		surface_changed.emit(cell, previous, CellSurfaceState.DynamicSurface.NONE)
	return true


func refresh_surface_layer() -> void:
	for cell in _states:
		var state := get_state(cell)
		if state.dynamic_surface == CellSurfaceState.DynamicSurface.NONE:
			grid.clear_effect(cell)
			continue
		var config := configs.get(state.dynamic_surface) as SurfaceConfig
		if config != null:
			grid.set_effect(cell, config.display_name, {
				"duration_turns": state.duration_turns,
				"source_unit": state.source_unit,
				"gameplay_flags": state.gameplay_flags.duplicate(true),
			})


func advance_turn() -> Array[Vector2i]:
	var expired: Array[Vector2i] = []
	for cell in _states:
		var state := get_state(cell)
		if not state.is_dynamic():
			continue
		state.duration_turns = maxi(0, state.duration_turns - 1)
		if state.duration_turns == 0:
			expired.append(cell)
		else:
			refresh_cell(cell)
	for cell in expired:
		clear_surface(cell)
	return expired


func refresh_cell(cell: Vector2i) -> void:
	if not has_state(cell):
		return
	var state := get_state(cell)
	if not state.is_dynamic():
		grid.clear_effect(cell)
		return
	var config := configs.get(state.dynamic_surface) as SurfaceConfig
	if config != null:
		grid.set_effect(cell, config.display_name, {
			"duration_turns": state.duration_turns,
			"source_unit": state.source_unit,
			"gameplay_flags": state.gameplay_flags.duplicate(true),
		})


func reset() -> void:
	for cell in _states:
		clear_surface(cell)


func has_state(cell: Vector2i) -> bool:
	return _states.has(cell)


func get_state(cell: Vector2i) -> CellSurfaceState:
	return _states.get(cell) as CellSurfaceState


func get_surface(cell: Vector2i) -> int:
	var state := get_state(cell)
	return state.dynamic_surface if state != null else CellSurfaceState.DynamicSurface.NONE


func get_turn_start_damage(cell: Vector2i) -> int:
	var config := configs.get(get_surface(cell)) as SurfaceConfig
	return config.turn_start_damage if config != null else 0


func is_surface_walkable(cell: Vector2i) -> bool:
	if not has_state(cell):
		return false
	var config := configs.get(get_surface(cell)) as SurfaceConfig
	return config == null or config.walkable


func get_movement_cost(cell: Vector2i) -> int:
	var config := configs.get(get_surface(cell)) as SurfaceConfig
	return config.movement_cost if config != null else 1


func state_count() -> int:
	return _states.size()


func state_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _states:
		cells.append(cell)
	return cells
