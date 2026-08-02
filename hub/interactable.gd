class_name Interactable
extends Node2D

signal interaction_requested(interactable: Interactable)


func get_interaction_positions(
		_actor: Node,
		_navigation_region: HubNavigationRegion2D
	) -> PackedVector2Array:
	return PackedVector2Array()


func can_interact(_actor: Node) -> bool:
	return is_inside_tree() and visible and not is_queued_for_deletion()


func get_occupied_world_position() -> Vector2:
	return global_position


func get_max_interaction_distance() -> float:
	return 96.0


func interact(_actor: Node) -> void:
	pass
