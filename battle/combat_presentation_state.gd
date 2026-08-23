class_name CombatPresentationState
extends RefCounted

## État de présentation dérivé du combat.
##
## Cette classe ne décide d'aucune règle de gameplay. Elle rassemble seulement
## les informations nécessaires au HUD afin que tous les widgets voient le
## même état et qu'aucun d'eux ne puisse réactiver les contrôles tout seul.

signal snapshot_changed(snapshot: Dictionary)

enum Phase {
	PLAYER_IDLE,
	PLAYER_TARGETING,
	RESOLVING_ACTION,
	ENEMY_TURN,
	MODAL,
	BATTLE_ENDING,
}

const PHASE_NAMES := {
	Phase.PLAYER_IDLE: &"PLAYER_IDLE",
	Phase.PLAYER_TARGETING: &"PLAYER_TARGETING",
	Phase.RESOLVING_ACTION: &"RESOLVING_ACTION",
	Phase.ENEMY_TURN: &"ENEMY_TURN",
	Phase.MODAL: &"MODAL",
	Phase.BATTLE_ENDING: &"BATTLE_ENDING",
}

var _phase: Phase = Phase.PLAYER_IDLE
var _selection_mode: StringName = &""
var _resolution_kind: StringName = &""
var _lock_reasons: Dictionary = {}
var _feedback_text := ""
var _feedback_kind: StringName = &"info"


func begin_player_turn() -> void:
	_phase = Phase.PLAYER_IDLE
	_selection_mode = &""
	_resolution_kind = &""
	_emit_snapshot()


func begin_targeting(mode: StringName) -> void:
	_phase = Phase.PLAYER_TARGETING
	_selection_mode = mode
	_resolution_kind = &""
	_emit_snapshot()


func begin_resolution(kind: StringName) -> void:
	_phase = Phase.RESOLVING_ACTION
	_selection_mode = &""
	_resolution_kind = kind
	_emit_snapshot()


func begin_enemy_turn() -> void:
	_phase = Phase.ENEMY_TURN
	_selection_mode = &""
	_resolution_kind = &""
	_emit_snapshot()


func begin_modal() -> void:
	_phase = Phase.MODAL
	_selection_mode = &""
	_resolution_kind = &""
	_emit_snapshot()


func begin_battle_ending() -> void:
	_phase = Phase.BATTLE_ENDING
	_selection_mode = &""
	_resolution_kind = &""
	_emit_snapshot()


func set_lock(reason: StringName, active: bool) -> void:
	if reason == &"":
		return
	var changed := false
	if active and not _lock_reasons.has(reason):
		_lock_reasons[reason] = true
		changed = true
	elif not active and _lock_reasons.erase(reason):
		changed = true
	if changed:
		_emit_snapshot()


func clear_locks() -> void:
	if _lock_reasons.is_empty():
		return
	_lock_reasons.clear()
	_emit_snapshot()


func set_feedback(text: String, kind: StringName = &"info") -> void:
	_feedback_text = text.strip_edges()
	_feedback_kind = kind
	_emit_snapshot()


func clear_feedback() -> void:
	if _feedback_text.is_empty():
		return
	_feedback_text = ""
	_feedback_kind = &"info"
	_emit_snapshot()


func is_locked() -> bool:
	return not _lock_reasons.is_empty() \
		or _phase in [
			Phase.RESOLVING_ACTION,
			Phase.ENEMY_TURN,
			Phase.MODAL,
			Phase.BATTLE_ENDING,
		]


func can_accept_player_intent() -> bool:
	return not is_locked() \
		and _phase in [Phase.PLAYER_IDLE, Phase.PLAYER_TARGETING]


func is_targeting() -> bool:
	return _phase == Phase.PLAYER_TARGETING


func get_phase() -> Phase:
	return _phase


func get_snapshot() -> Dictionary:
	var reasons: Array[StringName] = []
	for reason in _lock_reasons.keys():
		reasons.append(StringName(reason))
	reasons.sort()
	return {
		"phase": _phase,
		"phase_name": PHASE_NAMES.get(_phase, &"UNKNOWN"),
		"selection_mode": _selection_mode,
		"resolution_kind": _resolution_kind,
		"input_locked": is_locked(),
		"controls_enabled": can_accept_player_intent(),
		"focus_active": _phase == Phase.PLAYER_TARGETING,
		"ownership": (
			&"player"
			if _phase in [Phase.PLAYER_IDLE, Phase.PLAYER_TARGETING]
			else &"enemy" if _phase == Phase.ENEMY_TURN else &"system"
		),
		"lock_reasons": reasons,
		"feedback_text": _feedback_text,
		"feedback_kind": _feedback_kind,
	}


func _emit_snapshot() -> void:
	snapshot_changed.emit(get_snapshot())
