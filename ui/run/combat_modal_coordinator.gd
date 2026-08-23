class_name CombatModalCoordinator
extends RefCounted

## Propriétaire unique des surfaces modales de la run.
## Les écrans restent responsables de leur rendu; ce coordinateur garantit
## simplement qu'une seule surface possède les entrées à un instant donné.

signal active_modal_changed(previous: StringName, current: StringName)

var _active_modal: StringName = &""


func try_open(modal_id: StringName) -> bool:
	if modal_id == &"":
		return false
	if _active_modal == modal_id:
		return true
	if _active_modal != &"":
		return false
	var previous := _active_modal
	_active_modal = modal_id
	active_modal_changed.emit(previous, _active_modal)
	return true


func close(modal_id: StringName) -> bool:
	if modal_id == &"" or _active_modal != modal_id:
		return false
	var previous := _active_modal
	_active_modal = &""
	active_modal_changed.emit(previous, _active_modal)
	return true


func clear() -> void:
	if _active_modal == &"":
		return
	var previous := _active_modal
	_active_modal = &""
	active_modal_changed.emit(previous, _active_modal)


func get_active_modal() -> StringName:
	return _active_modal


func has_active_modal() -> bool:
	return _active_modal != &""


func is_active(modal_id: StringName) -> bool:
	return _active_modal == modal_id
