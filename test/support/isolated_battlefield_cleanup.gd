extends RefCounted

## Tests construct RefCounted graphs without a scene owner. Release both the
## occupancy back-reference and TerrainEffects' relay closures at fixture teardown.
static func dispose_grid(grid: GridData) -> void:
	if grid == null:
		return
	for unit: Unit in grid.get_units():
		unit.pending_ability.clear()
		unit.active_statuses.clear()
		grid.remove_unit(unit)
	for connection: Dictionary in grid.occupancy_changed.get_connections():
		var callback: Callable = connection.callable
		var listener := callback.get_object()
		grid.occupancy_changed.disconnect(callback)
		if listener is TerrainSurfaceRuntimeService:
			for declaration: Dictionary in listener.get_signal_list():
				var relay := Signal(listener, StringName(declaration.name))
				for forwarding: Dictionary in relay.get_connections():
					relay.disconnect(forwarding.callable)
			listener.grid = null
