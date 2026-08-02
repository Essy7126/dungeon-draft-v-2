class_name HubInteractionResolver
extends Node


func resolve(
		actor: Node,
		target: Interactable,
		navigation_grid: HubNavigationGrid,
		intent: InteractionIntent
	) -> Dictionary:
	if actor == null or target == null or intent == null \
		or not target.can_interact(actor):
		return {}
	var actor_cell: Vector2i = actor.get_meta(
		&"hub_current_cell", HubNavigationGrid.INVALID_CELL
	)
	if not navigation_grid.is_valid(actor_cell):
		return {}

	var best_cell := HubNavigationGrid.INVALID_CELL
	var best_path: Array[Vector2i] = []
	var best_cost := INF
	for approach_cell in target.get_interaction_cells(actor, navigation_grid):
		if not navigation_grid.is_walkable(approach_cell, intent):
			continue
		var path := navigation_grid.get_path(actor_cell, approach_cell, intent)
		if path.is_empty():
			continue
		var path_cost := navigation_grid.get_path_cost(path)
		if best_path.is_empty() or path_cost < best_cost \
			or (is_equal_approx(path_cost, best_cost) \
			and _cell_before(approach_cell, best_cell)):
			best_cell = approach_cell
			best_path = path
			best_cost = path_cost

	if best_path.is_empty() or not navigation_grid.reserve(best_cell, intent):
		return {}
	intent.destination = best_cell
	return {
		"cell": best_cell,
		"path": best_path,
		"distance": best_cost,
	}


func _cell_before(a: Vector2i, b: Vector2i) -> bool:
	return b == HubNavigationGrid.INVALID_CELL or a.y < b.y \
		or (a.y == b.y and a.x < b.x)
