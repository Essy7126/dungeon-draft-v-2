class_name HubInteractionResolver
extends Node


func resolve(
		actor: Node2D,
		target: Interactable,
		navigation_region: HubNavigationRegion2D,
		intent: InteractionIntent
	) -> Dictionary:
	if actor == null or target == null or intent == null \
		or navigation_region == null or not target.can_interact(actor):
		return {}

	var best_position := HubNavigationRegion2D.INVALID_WORLD_POSITION
	var best_path := PackedVector2Array()
	var best_distance := INF
	for approach_position in target.get_interaction_positions(
			actor, navigation_region
		):
		if not navigation_region.is_world_position_navigable(approach_position) \
			or navigation_region.is_world_position_reserved(
				approach_position, intent
			):
			continue
		var path := navigation_region.get_world_path(
			actor.global_position, approach_position
		)
		if path.is_empty():
			continue
		var path_distance := navigation_region.get_path_length(path)
		if best_path.is_empty() or path_distance < best_distance \
			or (is_equal_approx(path_distance, best_distance) \
			and _position_before(approach_position, best_position)):
			best_position = approach_position
			best_path = path
			best_distance = path_distance

	if best_path.is_empty() or not navigation_region.reserve_world_position(
			best_position, intent
		):
		return {}
	intent.destination = best_position
	return {
		"position": best_position,
		"path": best_path,
		"distance": best_distance,
	}


func _position_before(a: Vector2, b: Vector2) -> bool:
	return not b.is_finite() or a.y < b.y \
		or (is_equal_approx(a.y, b.y) and a.x < b.x)
