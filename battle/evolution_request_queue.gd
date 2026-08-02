class_name EvolutionRequestQueue
extends RefCounted

var _requests: Array[EvolutionRequest] = []
var _known_keys: Dictionary = {}


func enqueue(request: EvolutionRequest) -> bool:
	if request == null or not request.is_valid():
		return false
	var key := request.get_deduplication_key()
	if _known_keys.has(key):
		return false
	_known_keys[key] = true
	_requests.append(request)
	return true


func peek() -> EvolutionRequest:
	return _requests[0] if not _requests.is_empty() else null


func complete_current() -> EvolutionRequest:
	return _requests.pop_front() if not _requests.is_empty() else null


func discard_current() -> EvolutionRequest:
	return complete_current()


func has_pending() -> bool:
	return not _requests.is_empty()


func size() -> int:
	return _requests.size()


func get_requests() -> Array[EvolutionRequest]:
	return _requests.duplicate()


func clear() -> void:
	_requests.clear()
	_known_keys.clear()
