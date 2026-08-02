class_name Interactable
extends Node2D

signal interaction_requested(interactable: Interactable)


func get_interaction_cells(
		_actor: Node,
		_navigation_grid: HubNavigationGrid
	) -> Array[Vector2i]:
	return []


func can_interact(_actor: Node) -> bool:
	return is_inside_tree() and visible and not is_queued_for_deletion()


func get_occupied_cell() -> Vector2i:
	return Vector2i(-1, -1)


func interact(_actor: Node) -> void:
	pass
