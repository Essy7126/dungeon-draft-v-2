extends Interactable

var occupied_world_position := Vector2(1000.0, 1200.0)
var approaches := PackedVector2Array()


func get_interaction_positions(
		_actor: Node,
		_navigation_region: HubNavigationRegion2D
	) -> PackedVector2Array:
	return approaches.duplicate()


func get_occupied_world_position() -> Vector2:
	return occupied_world_position
