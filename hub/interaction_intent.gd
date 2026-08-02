class_name InteractionIntent
extends RefCounted

var id: int
var destination := Vector2(INF, INF)
var cancelled := false
var _target_ref: WeakRef = null


func _init(p_id: int, target: Interactable) -> void:
	id = p_id
	_target_ref = weakref(target)


func cancel() -> void:
	cancelled = true


func has_destination() -> bool:
	return destination.is_finite()


func get_target() -> Interactable:
	if cancelled or _target_ref == null:
		return null
	return _target_ref.get_ref() as Interactable
