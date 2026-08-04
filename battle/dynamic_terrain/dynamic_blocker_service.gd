class_name DynamicBlockerService
extends RefCounted

## Facade generique entre les objets temporaires, GridData et Pathfinder.
## Elle ne possede aucune grille secondaire et ne touche jamais au CellType de
## base lors d'un enregistrement ou d'un retrait.

signal blocker_registered(cell: Vector2i, blocker)
signal blocker_unregistered(cell: Vector2i, blocker)
signal pathfinding_refreshed()
signal line_of_sight_refreshed()
signal projectile_paths_refreshed()

var grid: GridData = null
var pathfinder: Pathfinder = null
var refresh_count := 0


func configure(grid_data: GridData, existing_pathfinder: Pathfinder) -> void:
	assert(grid_data != null, "DynamicBlockerService requiert GridData.")
	assert(existing_pathfinder != null, "DynamicBlockerService requiert Pathfinder.")
	grid = grid_data
	pathfinder = existing_pathfinder


func can_register_dynamic_blocker(cell: Vector2i) -> bool:
	if grid == null or not grid.is_valid(cell) or grid.has_unit(cell):
		return false
	if grid.is_cell_dynamically_blocked(cell):
		return false
	var terrain := grid.get_type(cell)
	return terrain != GridData.CellType.HOLE and terrain != GridData.CellType.WALL


func register_dynamic_blocker(cell: Vector2i, blocker) -> bool:
	if not can_register_dynamic_blocker(cell):
		return false
	if not grid.register_dynamic_blocker(cell, blocker):
		return false
	_connect_blocker(cell, blocker)
	refresh_all()
	blocker_registered.emit(cell, blocker)
	return true


func unregister_dynamic_blocker(cell: Vector2i, blocker) -> bool:
	if grid == null or not grid.unregister_dynamic_blocker(cell, blocker):
		return false
	_disconnect_blocker(blocker)
	refresh_all()
	blocker_unregistered.emit(cell, blocker)
	return true


func is_cell_dynamically_blocked(cell: Vector2i) -> bool:
	return grid != null and grid.is_cell_dynamically_blocked(cell)


func get_blocker(cell: Vector2i):
	if grid == null:
		return null
	var blockers := grid.get_dynamic_blockers(cell)
	return blockers[0] if not blockers.is_empty() else null


func clear() -> void:
	if grid == null:
		return
	var cells: Array = []
	for x in range(grid.cols):
		for y in range(grid.rows):
			var cell := Vector2i(x, y)
			if grid.is_cell_dynamically_blocked(cell):
				cells.append(cell)
	for cell in cells:
		for blocker in grid.get_dynamic_blockers(cell):
			unregister_dynamic_blocker(cell, blocker)


func refresh_all() -> void:
	refresh_pathfinding()
	refresh_line_of_sight()
	refresh_projectile_paths()


func refresh_pathfinding() -> void:
	if pathfinder != null:
		pathfinder.sync()
	refresh_count += 1
	pathfinding_refreshed.emit()


func refresh_line_of_sight() -> void:
	line_of_sight_refreshed.emit()


func refresh_projectile_paths() -> void:
	projectile_paths_refreshed.emit()


func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	return pathfinder != null and pathfinder.has_line_of_sight(from, to)


func has_projectile_path(from: Vector2i, to: Vector2i) -> bool:
	return pathfinder != null and pathfinder.has_projectile_path(from, to)


func _connect_blocker(cell: Vector2i, blocker) -> void:
	if blocker == null or not blocker.has_signal("blocking_changed"):
		return
	var callback := Callable(self, "_on_blocking_changed").bind(cell, blocker)
	if not blocker.is_connected("blocking_changed", callback):
		blocker.connect("blocking_changed", callback)


func _disconnect_blocker(blocker) -> void:
	if blocker == null or not is_instance_valid(blocker) or not blocker.has_signal("blocking_changed"):
		return
	for connection in blocker.get_signal_connection_list("blocking_changed"):
		var callable: Callable = connection["callable"]
		if callable.get_object() == self:
			blocker.disconnect("blocking_changed", callable)


func _on_blocking_changed(_wall, blocking: bool, cell: Vector2i, blocker) -> void:
	if not blocking:
		unregister_dynamic_blocker(cell, blocker)
