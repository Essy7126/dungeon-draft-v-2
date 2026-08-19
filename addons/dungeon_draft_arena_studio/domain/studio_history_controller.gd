@tool
class_name StudioHistoryController
extends RefCounted

signal history_changed
signal dirty_state_changed(is_dirty: bool)

const DEFAULT_MAX_STEPS := 100

var undo_redo := UndoRedo.new()
var max_steps := DEFAULT_MAX_STEPS
var _entries: Array[Dictionary] = []
var _current_index := 0
var _saved_fingerprint := ""
var _base_fingerprint := ""
var _fingerprint_provider: Callable
var _snapshot_applier: Callable
var _last_dirty := false


func _init(requested_max_steps := DEFAULT_MAX_STEPS) -> void:
	max_steps = maxi(1, requested_max_steps)
	undo_redo.max_steps = max_steps


func configure(snapshot_applier: Callable, fingerprint_provider: Callable) -> void:
	_snapshot_applier = snapshot_applier
	_fingerprint_provider = fingerprint_provider
	_notify_changed(true)


func record(
		action_name: String,
		before: Dictionary,
		after: Dictionary,
		already_applied := true,
		merge_key := ""
	) -> bool:
	if action_name.strip_edges().is_empty() or before == after:
		_notify_changed()
		return false
	if _current_index < _entries.size():
		_entries.resize(_current_index)
	var stored_before := before.duplicate(true)
	var stored_after := after.duplicate(true)
	var can_merge := not merge_key.is_empty() and _current_index == _entries.size() \
		and not _entries.is_empty() and str(_entries[-1].get("merge_key", "")) == merge_key
	undo_redo.create_action(
		action_name,
		UndoRedo.MERGE_ENDS if can_merge else UndoRedo.MERGE_DISABLE,
	)
	undo_redo.add_do_method(
		Callable(self, "_apply_snapshot").bind(stored_after, 1)
	)
	undo_redo.add_undo_method(
		Callable(self, "_apply_snapshot").bind(stored_before, -1)
	)
	undo_redo.commit_action(not already_applied)
	if can_merge:
		_entries[-1]["after"] = stored_after
		_entries[-1]["after_fingerprint"] = _fingerprint(after)
	else:
		_entries.append({
			"name": action_name,
			"before": stored_before,
			"after": stored_after,
			"before_fingerprint": _fingerprint(before),
			"after_fingerprint": _fingerprint(after),
			"merge_key": merge_key,
		})
		_current_index += 1
	if _entries.size() > max_steps:
		_entries.pop_front()
		_current_index = maxi(0, _current_index - 1)
	_notify_changed()
	return true


func can_undo() -> bool:
	return undo_redo.has_undo()


func can_redo() -> bool:
	return undo_redo.has_redo()


func undo() -> bool:
	if not can_undo():
		return false
	return undo_redo.undo()


func redo() -> bool:
	if not can_redo():
		return false
	return undo_redo.redo()


func clear() -> void:
	undo_redo.clear_history()
	_entries.clear()
	_current_index = 0
	_notify_changed(true)


func get_undo_action_name() -> String:
	return str(_entries[_current_index - 1].get("name", "")) \
		if _current_index > 0 and _current_index <= _entries.size() else ""


func get_redo_action_name() -> String:
	return str(_entries[_current_index].get("name", "")) \
		if _current_index >= 0 and _current_index < _entries.size() else ""


func get_history_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(_entries.size()):
		var entry := _entries[index].duplicate(false)
		entry["index"] = index + 1
		entry["applied"] = index < _current_index
		entry["current"] = index + 1 == _current_index
		entry["saved"] = str(entry.get("after_fingerprint", "")) == _saved_fingerprint
		entry.erase("before")
		entry.erase("after")
		result.append(entry)
	return result


func get_current_index() -> int:
	return _current_index


func jump_to(index: int) -> bool:
	if index < 0 or index > _entries.size():
		return false
	while _current_index > index:
		if not undo():
			return false
	while _current_index < index:
		if not redo():
			return false
	return true


func set_saved_fingerprint(value: String) -> void:
	_saved_fingerprint = value
	if _entries.is_empty():
		_base_fingerprint = current_fingerprint()
	_notify_changed(true)


func get_saved_fingerprint() -> String:
	return _saved_fingerprint


func is_at_saved_state() -> bool:
	if _saved_fingerprint.is_empty():
		return false
	var history_fingerprint := _base_fingerprint
	if _current_index > 0 and _current_index <= _entries.size():
		history_fingerprint = str(_entries[_current_index - 1].get("after_fingerprint", ""))
	return history_fingerprint == _saved_fingerprint


func current_fingerprint() -> String:
	if _fingerprint_provider.is_valid():
		return str(_fingerprint_provider.call())
	return ""


func notify_preview_changed() -> void:
	_notify_changed()


func _apply_snapshot(snapshot: Dictionary, index_delta: int) -> void:
	if _snapshot_applier.is_valid():
		_snapshot_applier.call(snapshot.duplicate(true))
	_current_index = clampi(_current_index + index_delta, 0, _entries.size())
	_notify_changed()


func _notify_changed(force_dirty_signal := false) -> void:
	var dirty := not is_at_saved_state()
	if force_dirty_signal or dirty != _last_dirty:
		_last_dirty = dirty
		dirty_state_changed.emit(dirty)
	history_changed.emit()


static func _fingerprint(snapshot: Dictionary) -> String:
	return JSON.stringify(snapshot).sha256_text()
