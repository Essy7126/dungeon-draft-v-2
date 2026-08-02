class_name HubCharacterPreview
extends Node2D

## Wrapper visuel minimal autour du sprite de secours Elfe existant.
## Le pivot local (0, 0) est le contact des pieds avec le sol.


func set_facing(_direction: Vector2i) -> void:
	# Le frame idle historique ne contient qu'une orientation exploitable.
	pass


func get_logical_foot_position() -> Vector2:
	return Vector2.ZERO
