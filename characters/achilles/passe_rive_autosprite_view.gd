class_name PasseRiveAutoSpriteView
extends AchillesIsoUnitView

var _stride_position := Vector2.ZERO


func _ready() -> void:
	super._ready()
	EventBus.attack_dodged.connect(_on_attack_dodged)


func _exit_tree() -> void:
	if EventBus.attack_dodged.is_connected(_on_attack_dodged):
		EventBus.attack_dodged.disconnect(_on_attack_dodged)
	super._exit_tree()


func _on_attack_dodged(target: Unit, _attacker: Unit) -> void:
	if (
		target == _unit and not _closing and not _dead
		and sprite_backend is PasseRiveAutoSpriteBackend
	):
		(sprite_backend as PasseRiveAutoSpriteBackend).play_dodge(_facing)


func _begin_movement_feedback(
	from_cell: Vector2i,
	to_cell: Vector2i,
	action_id: StringName,
) -> void:
	_stride_position = (get_parent() as Node2D).position
	super._begin_movement_feedback(from_cell, to_cell, action_id)


func update_movement_stride(_step_index: int, _progress: float) -> void:
	if _closing or _dead or _action_pending or not _movement_feedback_owned:
		return
	var current := (get_parent() as Node2D).position
	var delta := current - _stride_position
	_stride_position = current
	if sprite_backend is PasseRiveAutoSpriteBackend:
		(sprite_backend as PasseRiveAutoSpriteBackend).advance_ground_distance(
			Vector2(delta.x, delta.y * 2.0).length()
		)
