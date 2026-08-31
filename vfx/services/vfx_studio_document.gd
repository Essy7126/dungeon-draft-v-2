@tool
class_name VFXStudioDocument
extends RefCounted

signal changed
signal dirty_changed(is_dirty: bool)

var source: VFXProfile
var working_copy: VFXProfile
var source_path := ""
var original_fingerprint := ""
var saved_as_draft := false
var draft_path := ""
var draft_sha256 := ""
var _saved_snapshot := {}
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
	saved_as_draft = false
	draft_path = ""
	draft_sha256 = ""
	_saved_snapshot = VFXProfileSnapshotService.to_dictionary(working_copy, true)
	history.clear()
	history.set_saved_fingerprint(current_fingerprint())
	changed.emit()
	return true


func record_edit(action_name: String, mutator: Callable) -> bool:
	if working_copy == null or not mutator.is_valid():
		return false
	var before_fingerprint := current_fingerprint()
	var before := VFXProfileSnapshotService.to_dictionary(working_copy, true)
	mutator.call()
	var after := VFXProfileSnapshotService.to_dictionary(working_copy, true)
	return history.record(
		action_name, before, after, true, "",
		before_fingerprint, current_fingerprint()
	)


func current_fingerprint() -> String:
	return VFXProfileSnapshotService.fingerprint(working_copy)


func is_dirty() -> bool:
	return working_copy != null and not history.is_at_saved_state()


func mark_draft_saved(path := "", sha256 := "") -> void:
	saved_as_draft = true
	draft_path = path
	draft_sha256 = sha256
	_saved_snapshot = VFXProfileSnapshotService.to_dictionary(working_copy, true)
	history.set_saved_fingerprint(current_fingerprint())
	changed.emit()


func mark_draft_loaded(path := "", sha256 := "") -> void:
	saved_as_draft = true
	draft_path = path
	draft_sha256 = sha256
	_saved_snapshot = VFXProfileSnapshotService.to_dictionary(working_copy, true)
	history.set_saved_fingerprint(current_fingerprint())
	changed.emit()


func discard_changes() -> bool:
	if _saved_snapshot.is_empty():
		return false
	var restored := VFXProfileSnapshotService.from_dictionary(
		_saved_snapshot.duplicate(true)
	)
	if restored == null:
		return false
	working_copy = restored
	history.clear()
	history.set_saved_fingerprint(current_fingerprint())
	changed.emit()
	return true


## Capture l'autorité et la working copy pour les transactions multi-domaines.
## L'historique peut être reconstruit à son checkpoint sans exposer ses
## structures internes ; le contenu et l'état dirty restent ainsi restaurables.
func snapshot_state() -> Dictionary:
	return {
		"source": source,
		"source_path": source_path,
		"original_fingerprint": original_fingerprint,
		"saved_as_draft": saved_as_draft,
		"draft_path": draft_path,
		"draft_sha256": draft_sha256,
		"saved_snapshot": _saved_snapshot.duplicate(true),
		"working_copy": VFXProfileSnapshotService.to_dictionary(working_copy, true),
		"history": history.snapshot_state(),
	}


func restore_state(state: Dictionary) -> bool:
	var restored := VFXProfileSnapshotService.from_dictionary(
		state.get("working_copy", {}) as Dictionary
	)
	if restored == null:
		return false
	source = state.get("source") as VFXProfile
	source_path = str(state.get("source_path", ""))
	original_fingerprint = str(state.get("original_fingerprint", ""))
	saved_as_draft = bool(state.get("saved_as_draft", false))
	draft_path = str(state.get("draft_path", ""))
	draft_sha256 = str(state.get("draft_sha256", ""))
	_saved_snapshot = (state.get("saved_snapshot", {}) as Dictionary).duplicate(true)
	if _saved_snapshot.is_empty():
		_saved_snapshot = VFXProfileSnapshotService.to_dictionary(restored, true)
	working_copy = restored
	var history_state := state.get("history", {}) as Dictionary
	if history_state.is_empty() or not history.restore_state(history_state):
		return false
	changed.emit()
	return true


func _apply_history_snapshot(snapshot: Dictionary) -> void:
	working_copy = VFXProfileSnapshotService.from_dictionary(snapshot)
	changed.emit()
