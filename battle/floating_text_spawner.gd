class_name CombatFeedbackController
extends Node2D

const FloatingTextScene := preload("res://battle/floating_text.tscn")
const DEFAULT_SETTINGS: CombatFeedbackSettings = preload(
	"res://battle/combat_feedback/combat_feedback_settings.tres"
)

@export var settings: CombatFeedbackSettings = DEFAULT_SETTINGS

var _pool: Array[FloatingCombatText] = []
var _active: Dictionary = {}
var _pending: Array[Dictionary] = []
var _seen_event_ids: Dictionary = {}
var _battle_view: Node2D = null
var _canvas_layer: CanvasLayer = null
var _feedback_root: Control = null


func _ready() -> void:
	z_index = 100
	_install_screen_layer()
	_connect_events()
	_prewarm()
	set_process(true)


func _exit_tree() -> void:
	_disconnect_events()
	clear_feedback()


func _process(_delta: float) -> void:
	_drain_pending()
	for instance_value in _active.keys():
		var instance := instance_value as FloatingCombatText
		if not is_instance_valid(instance):
			_active.erase(instance_value)
			continue
		var entry := _active[instance] as Dictionary
		var target_ref := entry.get("target_ref") as WeakRef
		var target = target_ref.get_ref() if target_ref != null else null
		if target != null:
			entry["last_anchor"] = _screen_anchor_for(target)
		instance.screen_anchor = _clamp_anchor(
			entry.get("last_anchor", get_viewport_rect().size * 0.5)
			+ entry.get("lane_offset", Vector2.ZERO)
		)


func _install_screen_layer() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "CombatFeedbackLayer"
	_canvas_layer.layer = 90
	add_child(_canvas_layer)
	_feedback_root = Control.new()
	_feedback_root.name = "FeedbackRoot"
	_feedback_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_feedback_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_feedback_root)


func _connect_events() -> void:
	_connect_once(EventBus.hp_damage_taken, _on_hp_damage_taken)
	_connect_once(EventBus.heal_received, _on_heal_received)
	_connect_once(EventBus.shield_absorption_resolved, _on_shield_absorbed)
	_connect_once(EventBus.shield_granted, _on_shield_granted)
	_connect_once(EventBus.attack_dodge_resolved, _on_attack_dodged)
	_connect_once(EventBus.attack_immune, _on_attack_immune)
	_connect_once(EventBus.status_added, _on_status_added)
	_connect_once(EventBus.combat_status_expired, _on_status_expired)
	_connect_once(EventBus.battle_view_ready, _register_battle_view)


func _disconnect_events() -> void:
	for entry in [
		[EventBus.hp_damage_taken, Callable(self, "_on_hp_damage_taken")],
		[EventBus.heal_received, Callable(self, "_on_heal_received")],
		[EventBus.shield_absorption_resolved, Callable(self, "_on_shield_absorbed")],
		[EventBus.shield_granted, Callable(self, "_on_shield_granted")],
		[EventBus.attack_dodge_resolved, Callable(self, "_on_attack_dodged")],
		[EventBus.attack_immune, Callable(self, "_on_attack_immune")],
		[EventBus.status_added, Callable(self, "_on_status_added")],
		[EventBus.combat_status_expired, Callable(self, "_on_status_expired")],
		[EventBus.battle_view_ready, Callable(self, "_register_battle_view")],
	]:
		var signal_value: Signal = entry[0]
		var callback: Callable = entry[1]
		if signal_value.is_connected(callback):
			signal_value.disconnect(callback)


func _connect_once(signal_value: Signal, callback: Callable) -> void:
	if not signal_value.is_connected(callback):
		signal_value.connect(callback)


func _register_battle_view(view: Node) -> void:
	_battle_view = view as Node2D


func _on_hp_damage_taken(fact: CombatEventFact) -> void:
	submit_fact(fact)


func _on_heal_received(fact: CombatEventFact) -> void:
	if fact.amount_applied > 0:
		submit_fact(fact)


func _on_shield_absorbed(fact: CombatEventFact) -> void:
	if fact.amount_absorbed > 0:
		submit_fact(fact)


func _on_shield_granted(fact: CombatEventFact) -> void:
	if fact.amount_applied > 0:
		submit_fact(fact)


func _on_attack_dodged(fact: CombatEventFact) -> void:
	submit_fact(fact)


func _on_attack_immune(fact: CombatEventFact) -> void:
	submit_fact(fact)


func _on_status_added(fact: CombatEventFact) -> void:
	submit_fact(fact)


func _on_status_expired(fact: CombatEventFact) -> void:
	submit_fact(fact)


func submit_fact(fact: CombatEventFact) -> bool:
	if fact == null or fact.target == null or not is_inside_tree():
		return false
	if fact.event_id != &"" and _seen_event_ids.has(fact.event_id):
		return false
	if fact.event_id != &"":
		_seen_event_ids[fact.event_id] = true
	var target_pending := 0
	for queued in _pending:
		if queued.get("target") == fact.target:
			target_pending += 1
	var delay_index := maxi(fact.sequence_index, target_pending)
	_pending.append({
		"fact": fact,
		"target": fact.target,
		"ready_at": Time.get_ticks_msec() + int(
			float(delay_index) * settings.sequence_interval * 1000.0
		),
	})
	return true


func spawn_fact_immediate(
		fact: CombatEventFact,
		freeze_for_snapshot := false,
		legacy_preset := false
	) -> FloatingCombatText:
	if fact == null or fact.target == null or _active.size() >= settings.max_active:
		return null
	var instance := _acquire()
	var slot := _active_count_for_target(fact.target)
	var lane := slot % settings.max_visible_per_target
	var side := -1.0 if lane % 2 == 0 else 1.0
	var row := float(lane / 2)
	var lane_offset := Vector2(
		side * settings.horizontal_step * (row + 1.0),
		-settings.stack_step * row
	)
	var anchor := _screen_anchor_for(fact.target)
	_active[instance] = {
		"target_ref": weakref(fact.target),
		"last_anchor": anchor,
		"lane_offset": lane_offset,
	}
	instance.screen_anchor = _clamp_anchor(anchor + lane_offset)
	instance.play_fact(
		fact, settings.style_for_fact(fact), settings,
		freeze_for_snapshot, legacy_preset
	)
	return instance


func _drain_pending() -> void:
	var now := Time.get_ticks_msec()
	var index := 0
	while index < _pending.size() and _active.size() < settings.max_active:
		var entry := _pending[index] as Dictionary
		if now < int(entry.get("ready_at", now)):
			index += 1
			continue
		var fact := entry.get("fact") as CombatEventFact
		_pending.remove_at(index)
		spawn_fact_immediate(fact)


func _prewarm() -> void:
	for _index in settings.prewarm_count:
		var instance := _create_instance()
		instance.reset_for_pool()
		_pool.append(instance)


func _acquire() -> FloatingCombatText:
	if _pool.is_empty():
		return _create_instance()
	return _pool.pop_back()


func _create_instance() -> FloatingCombatText:
	var instance := FloatingTextScene.instantiate() as FloatingCombatText
	_feedback_root.add_child(instance)
	instance.finished.connect(_release)
	return instance


func _release(instance: FloatingCombatText) -> void:
	if not is_instance_valid(instance):
		return
	_active.erase(instance)
	instance.reset_for_pool()
	if not _pool.has(instance):
		_pool.append(instance)


func _active_count_for_target(target) -> int:
	var count := 0
	for entry_value in _active.values():
		var entry := entry_value as Dictionary
		var target_ref := entry.get("target_ref") as WeakRef
		if target_ref != null and target_ref.get_ref() == target:
			count += 1
	return count


func _screen_anchor_for(target) -> Vector2:
	if target is Control:
		var control := target as Control
		return control.global_position + control.size * 0.5
	if target is CanvasItem:
		return (target as CanvasItem).get_global_transform_with_canvas().origin
	if get_tree() != null:
		for candidate in get_tree().get_nodes_in_group("unit_views"):
			if candidate is Node2D and candidate.get("unit") == target:
				return candidate.get_global_transform_with_canvas().origin \
					+ _scaled_anchor_offset(target)
	if is_instance_valid(_battle_view) and target.get("grid_pos") != null:
		var cell_local: Vector2
		if _battle_view.has_method("grid_to_local"):
			cell_local = _battle_view.grid_to_local(target.grid_pos)
		else:
			cell_local = _battle_view.grid_to_world(target.grid_pos)
		var world_position := _battle_view.to_global(cell_local)
		return get_viewport().get_canvas_transform() * world_position \
			+ _scaled_anchor_offset(target)
	return get_viewport_rect().size * 0.5


func _scaled_anchor_offset(_target) -> Vector2:
	return Vector2(0.0, -72.0) * maxf(0.66, get_viewport_rect().size.y / 1080.0)


func _clamp_anchor(value: Vector2) -> Vector2:
	var size := get_viewport_rect().size
	var margin := settings.viewport_margin
	return Vector2(
		clampf(value.x, margin, maxf(margin, size.x - margin)),
		clampf(value.y, margin, maxf(margin, size.y - margin))
	)


func set_text_scale(value: float) -> void:
	settings.text_scale = clampf(value, 0.5, 2.0)


func set_reduced_motion(enabled: bool) -> void:
	settings.reduced_motion = enabled


func clear_feedback() -> void:
	_pending.clear()
	_seen_event_ids.clear()
	for instance_value in _active.keys():
		var instance := instance_value as FloatingCombatText
		if is_instance_valid(instance):
			instance.reset_for_pool()
			if not _pool.has(instance):
				_pool.append(instance)
	_active.clear()


func get_debug_snapshot() -> Dictionary:
	return {
		"pool_size": _pool.size(),
		"active_count": _active.size(),
		"pending_count": _pending.size(),
		"seen_event_count": _seen_event_ids.size(),
		"max_active": settings.max_active,
		"prewarm_count": settings.prewarm_count,
	}
