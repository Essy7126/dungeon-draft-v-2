@tool
class_name VFXStudioDocument
extends RefCounted

signal changed
signal dirty_changed(is_dirty: bool)

var source: VFXProfile
var working_copy: VFXProfile
var source_path := ""
var original_fingerprint := ""
var history := StudioHistoryController.new()
var copy_service := VFXProfileCopyService.new()


func _init() -> void:
	history.configure(_apply_history_snapshot, current_fingerprint)
	history.history_changed.connect(func(): changed.emit())
	history.dirty_state_changed.connect(func(value: bool): dirty_changed.emit(value))


func open_profile(profile: VFXProfile) -> bool:
	if profile == null:
		return false
	source = profile
	working_copy = copy_service.duplicate_profile(profile)
	if working_copy == null:
		return false
	source_path = profile.resource_path
	original_fingerprint = VFXProfileSnapshotService.fingerprint(profile)
	history.clear()
	history.set_saved_fingerprint(current_fingerprint())
	changed.emit()
	return true


func record_edit(action_name: String, mutator: Callable) -> bool:
	if working_copy == null or not mutator.is_valid():
		return false
	var before := VFXProfileSnapshotService.to_dictionary(working_copy)
	mutator.call()
	var after := VFXProfileSnapshotService.to_dictionary(working_copy)
	return history.record(action_name, before, after, true)


func current_fingerprint() -> String:
	return VFXProfileSnapshotService.fingerprint(working_copy)


func is_dirty() -> bool:
	return working_copy != null and not history.is_at_saved_state()


func mark_draft_saved() -> void:
	history.set_saved_fingerprint(current_fingerprint())
	changed.emit()


func _apply_history_snapshot(snapshot: Dictionary) -> void:
	working_copy = VFXProfileSnapshotService.from_dictionary(snapshot)
	changed.emit()
