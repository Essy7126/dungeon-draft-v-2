class_name CombatHudPort
extends RefCounted

## Adaptateur progressif entre Battle / PersistentRunUI et les HUD de combat.
##
## Le HUD historique et Recraft restent des implementations distinctes. Ce
## port exprime leur plus petit contrat commun, evite les appels disperses et
## permet de prouver un bind/unbind sans donner au HUD l'autorite gameplay.

const REQUIRED_SIGNALS: Array[StringName] = [
	&"move_pressed",
	&"attack_pressed",
	&"spell_pressed",
	&"end_turn_pressed",
]
const OPTIONAL_SIGNALS: Array[StringName] = [
	&"item_activation_requested",
]
const REQUIRED_METHODS: Array[StringName] = [
	&"set_player_controls_enabled",
	&"update_info",
	&"build_spell_buttons",
	&"set_active_mode",
]
const INTENT_BINDINGS := {
	&"move_pressed": &"_on_move_pressed",
	&"attack_pressed": &"_on_attack_pressed",
	&"spell_pressed": &"_on_spell_pressed",
	&"end_turn_pressed": &"_on_end_turn_pressed",
	&"item_activation_requested": &"_on_item_activation_requested",
}

var _hud_ref: WeakRef = null
var _context_ref: WeakRef = null
var _connections: Array[Dictionary] = []


func _init(hud: Object = null) -> void:
	attach(hud)


func attach(hud: Object) -> void:
	disconnect_intents()
	_hud_ref = weakref(hud) if is_instance_valid(hud) else null


func detach() -> void:
	disconnect_intents()
	_hud_ref = null


func get_hud():
	if _hud_ref == null:
		return null
	var hud = _hud_ref.get_ref()
	return hud if is_instance_valid(hud) else null


func audit_contract() -> Dictionary:
	var hud = get_hud()
	var missing_signals: Array[StringName] = []
	var missing_methods: Array[StringName] = []
	if hud == null:
		missing_signals.assign(REQUIRED_SIGNALS)
		missing_methods.assign(REQUIRED_METHODS)
	else:
		for signal_name in REQUIRED_SIGNALS:
			if not hud.has_signal(signal_name):
				missing_signals.append(signal_name)
		for method_name in REQUIRED_METHODS:
			if not hud.has_method(method_name):
				missing_methods.append(method_name)
	return {
		"valid": missing_signals.is_empty() and missing_methods.is_empty(),
		"missing_signals": missing_signals,
		"missing_methods": missing_methods,
		"supports_presentation_snapshot": (
			hud != null and hud.has_method("apply_presentation_snapshot")
		),
		"supports_context_binding": (
			hud != null and hud.has_method("bind_combat_context")
		),
		"supports_items": (
			hud != null and hud.has_signal("item_activation_requested")
		),
	}


func is_contract_valid() -> bool:
	return bool(audit_contract().get("valid", false))


func connect_intents(context: Object) -> bool:
	disconnect_intents()
	var hud = get_hud()
	if hud == null or not is_instance_valid(context):
		return false
	_context_ref = weakref(context)
	for signal_name in INTENT_BINDINGS:
		var method_name: StringName = INTENT_BINDINGS[signal_name]
		if not hud.has_signal(signal_name) or not context.has_method(method_name):
			continue
		var callback := Callable(context, method_name)
		if not hud.is_connected(signal_name, callback):
			hud.connect(signal_name, callback)
		_connections.append({
			"signal": signal_name,
			"callback": callback,
		})
	return not _connections.is_empty()


func disconnect_intents() -> void:
	var hud = get_hud()
	if hud != null:
		for connection in _connections:
			var signal_name := StringName(connection.get("signal", &""))
			var callback: Callable = connection.get("callback", Callable())
			if signal_name != &"" and callback.is_valid() \
					and hud.is_connected(signal_name, callback):
				hud.disconnect(signal_name, callback)
	_connections.clear()
	_context_ref = null


func get_connected_context():
	if _context_ref == null:
		return null
	var context = _context_ref.get_ref()
	return context if is_instance_valid(context) else null


func get_connection_count() -> int:
	return _connections.size()


func get_lifecycle_snapshot() -> Dictionary:
	var hud = get_hud()
	var connected_context = get_connected_context()
	var bound_context = get_bound_context()
	return {
		"hud_attached": hud != null,
		"contract_valid": is_contract_valid(),
		"intent_connection_count": _connections.size(),
		"connected_context_id": (
			connected_context.get_instance_id()
			if connected_context != null else 0
		),
		"bound_context_id": (
			bound_context.get_instance_id() if bound_context != null else 0
		),
	}


func set_controls_enabled(enabled: bool) -> bool:
	return _call(&"set_player_controls_enabled", [enabled])


func are_controls_enabled() -> bool:
	var hud = get_hud()
	if hud == null:
		return false
	if hud.has_method("are_player_controls_enabled"):
		return bool(hud.call("are_player_controls_enabled"))
	return bool(hud.get("_player_controls_enabled"))


func update_info(unit) -> bool:
	return _call(&"update_info", [unit])


func build_actions(unit) -> bool:
	return _call(&"build_spell_buttons", [unit])


func set_active_mode(mode: String, spell = null) -> bool:
	return _call(&"set_active_mode", [mode, spell])


func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	var hud = get_hud()
	if hud == null:
		return false
	if hud.has_method("apply_presentation_snapshot"):
		hud.call("apply_presentation_snapshot", snapshot)
		return true
	return set_controls_enabled(bool(snapshot.get("controls_enabled", false)))


func show_feedback(message: String, kind: StringName = &"warning") -> bool:
	return _call_optional(&"show_context_feedback", [message, kind])


func bind_context(context: Node) -> bool:
	return _call_optional(&"bind_combat_context", [context])


func unbind_context() -> bool:
	return _call_optional(&"unbind_combat_context")


func refresh_from_context() -> bool:
	return _call_optional(&"refresh_from_context")


func get_bound_context():
	var hud = get_hud()
	if hud != null and hud.has_method("get_combat_context"):
		return hud.call("get_combat_context")
	return get_connected_context()


func set_ui_mode(mode: int) -> bool:
	return _call_optional(&"set_ui_mode", [mode])


func set_reduced_motion(enabled: bool) -> bool:
	return _call_optional(&"set_reduced_motion", [enabled])


func get_turn_intro_banner():
	var hud = get_hud()
	if hud != null and hud.has_method("get_turn_intro_banner"):
		return hud.call("get_turn_intro_banner")
	return null


func _call(method: StringName, arguments: Array = []) -> bool:
	var hud = get_hud()
	if hud == null or not hud.has_method(method):
		return false
	hud.callv(method, arguments)
	return true


func _call_optional(method: StringName, arguments: Array = []) -> bool:
	return _call(method, arguments)
