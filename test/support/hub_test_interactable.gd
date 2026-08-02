extends Interactable

var occupied_cell := Vector2i(8, 8)
var approaches: Array[Vector2i] = []
var enabled := true
var interaction_count := 0


func get_interaction_cells(
		_actor: Node,
		_navigation_grid: HubNavigationGrid
	) -> Array[Vector2i]:
	return approaches.duplicate()


func get_occupied_cell() -> Vector2i:
	return occupied_cell


func can_interact(actor: Node) -> bool:
	return enabled and super.can_interact(actor)


func interact(_actor: Node) -> void:
	interaction_count += 1
