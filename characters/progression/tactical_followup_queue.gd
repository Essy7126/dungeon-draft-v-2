class_name TacticalFollowupQueue
extends RefCounted

signal request_queued(request: TacticalFollowupRequest)
signal request_resolved(result: Dictionary)
signal request_expired(request_id: StringName)

var _requests: Array[TacticalFollowupRequest] = []
var _next_serial: int = 1


func enqueue(request: TacticalFollowupRequest) -> Dictionary:
	if request == null:
		return _result(false, &"INVALID_REQUEST")
	if request.request_id == &"":
		request.request_id = StringName("%s:%d" % [request.source_id, _next_serial])
		_next_serial += 1
	if not request.is_structurally_valid():
		return _result(false, &"INVALID_REQUEST")
	if _find(request.request_id) != null:
		return _result(false, &"DUPLICATE_REQUEST")
	_requests.append(request)
	_requests.sort_custom(func(a: TacticalFollowupRequest, b: TacticalFollowupRequest) -> bool:
		if a.priority == b.priority:
			return str(a.request_id) < str(b.request_id)
		return a.priority > b.priority
	)
	request_queued.emit(request)
	return {
		"accepted": true,
		"reason": &"",
		"request_id": request.request_id,
	}


func pending_requests() -> Array[TacticalFollowupRequest]:
	return _requests.duplicate()


func peek() -> TacticalFollowupRequest:
	return _requests[0] if not _requests.is_empty() else null


## Cette methode ne deplace et n'attaque jamais. Elle valide uniquement le
## choix puis rend une commande explicite a l'orchestrateur, qui la resoudra a
## son prochain point sûr (hors animation).
func resolve_choice(
		request_id: StringName,
		chosen_cell: Variant = null,
		chosen_target: Variant = null,
		chosen_option_id: StringName = &""
	) -> Dictionary:
	var request := _find(request_id)
	if request == null:
		return _result(false, &"UNKNOWN_REQUEST")
	var has_choice := false
	if chosen_cell is Vector2i:
		if not request.accepts_cell(chosen_cell):
			return _result(false, &"INVALID_CELL")
		has_choice = true
	if chosen_target != null:
		if not request.accepts_target(chosen_target):
			return _result(false, &"INVALID_TARGET")
		has_choice = true
	if chosen_option_id != &"":
		if not request.accepts_option(chosen_option_id):
			return _result(false, &"INVALID_OPTION")
		has_choice = true
	if not has_choice:
		return _result(false, &"CHOICE_REQUIRED")
	_requests.erase(request)
	var result := {
		"resolved": true,
		"reason": &"",
		"request_id": request.request_id,
		"source_id": request.source_id,
		"request_type": request.request_type,
		"chosen_cell": chosen_cell,
		"chosen_target": chosen_target,
		"chosen_option_id": chosen_option_id,
		"execute_at_safe_point": true,
		"spends_action_points": false,
		"awards_xp": false,
		"consumes_manual_spell_use": false,
	}
	request_resolved.emit(result.duplicate(false))
	return result


func decline(request_id: StringName) -> Dictionary:
	var request := _find(request_id)
	if request == null:
		return _result(false, &"UNKNOWN_REQUEST")
	if not request.optional:
		return _result(false, &"REQUEST_NOT_OPTIONAL")
	_requests.erase(request)
	var result := {
		"resolved": true,
		"declined": true,
		"reason": &"",
		"request_id": request_id,
		"execute_at_safe_point": true,
	}
	request_resolved.emit(result.duplicate(true))
	return result


func expire_scope(scope_id: StringName, scope_token: StringName = &"") -> int:
	var expired: Array[TacticalFollowupRequest] = []
	for request in _requests:
		if request.expiry_scope != scope_id:
			continue
		if scope_token != &"" and request.expiry_token != scope_token:
			continue
		expired.append(request)
	for request in expired:
		_requests.erase(request)
		request_expired.emit(request.request_id)
	return expired.size()


func clear() -> void:
	_requests.clear()


func _find(request_id: StringName) -> TacticalFollowupRequest:
	for request in _requests:
		if request.request_id == request_id:
			return request
	return null


func _result(success: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": success,
		"resolved": success,
		"reason": reason,
	}
