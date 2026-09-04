class_name ImpactJuice
extends Node

## Feedback d'impact commun au combat.
##
## Les faits V2 sont l'unique source des impacts ordinaires : on ne se branche
## volontairement ni sur les signaux de degats historiques, ni sur les signaux
## `critical_hit` / `lethal_hit_resolved` qui dupliquent leur semantique.
## Collision et hazard restent des marqueurs de moments signature et ne
## declenchent qu'un surclassement de camera, jamais un second impact de degats.

static var juice_enabled := true

const IMPACT_BURST_SCRIPT := preload(
	"res://battle/combat_feedback/combat_impact_burst.gd"
)

const PUNCH_CRITICAL: StringName = &"critical"
const PUNCH_LETHAL: StringName = &"lethal"
const PUNCH_SIGNATURE: StringName = &"signature"

const CRITICAL_FREEZE_TIME := 0.028
const LETHAL_FREEZE_TIME := 0.050
const SIGNATURE_FREEZE_TIME := 0.040
const CRITICAL_PUNCH_TIME := 0.115
const LETHAL_PUNCH_TIME := 0.165
const SIGNATURE_PUNCH_TIME := 0.145
const CRITICAL_PUNCH_AMPLITUDE := 2.2
const LETHAL_PUNCH_AMPLITUDE := 3.6
const SIGNATURE_PUNCH_AMPLITUDE := 3.0
const PUNCH_DEDUP_WINDOW_MS := 90
const MAX_SEEN_EVENT_IDS := 256
const UNIT_IMPACT_OFFSET := Vector2(0.0, -24.0)

var _reduced_motion := false
var _battle_view: Node2D = null
var _effect_root: Node2D = null
var _active_bursts: Array[Node2D] = []
var _seen_event_ids: Dictionary = {}
var _event_id_order: Array[StringName] = []

var _owns_time_scale := false
var _saved_time_scale := 1.0
var _freeze_until_ms := 0
var _freeze_generation := 0

var _camera_ref: WeakRef = null
var _camera_tween: Tween = null
var _camera_generation := 0
var _camera_base_offset := Vector2.ZERO
var _camera_punch_until_ms := 0
var _camera_punch_started_ms := 0
var _camera_punch_duration_ms := 1
var _camera_punch_amplitude := 0.0
var _camera_punch_direction := Vector2.RIGHT
var _last_camera_offset := Vector2.ZERO
var _last_punch_target_id := 0
var _last_punch_at_ms := -PUNCH_DEDUP_WINDOW_MS
var _last_punch_grade := 0

var _debug_burst_count := 0
var _debug_punch_count := 0
var _debug_last_burst_kind: StringName = &""
var _debug_last_punch_kind: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_install_effect_root()
	_connect_events()
	set_reduced_motion(GameManager.is_reduced_motion_enabled())


func _exit_tree() -> void:
	_disconnect_events()
	_clear_bursts()
	_restore_time_scale()
	_restore_camera()
	_battle_view = null
	_seen_event_ids.clear()
	_event_id_order.clear()
	set_process(false)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled:
		_clear_bursts()
		_restore_time_scale()
		_restore_camera()
		_update_process_state()


func is_reduced_motion_enabled() -> bool:
	return _reduced_motion


func _connect_events() -> void:
	_connect_once(EventBus.hp_damage_taken, _on_hp_damage_taken)
	_connect_once(
		EventBus.shield_absorption_resolved, _on_shield_absorption_resolved
	)
	_connect_once(EventBus.heal_received, _on_heal_received)
	_connect_once(EventBus.shield_granted, _on_shield_granted)
	_connect_once(EventBus.collision_impact, _on_collision_impact)
	_connect_once(EventBus.hazard_kill, _on_hazard_kill)
	_connect_once(EventBus.battle_view_ready, _on_battle_view_ready)
	_connect_once(GameManager.reduced_motion_changed, set_reduced_motion)


func _disconnect_events() -> void:
	for entry in [
		[EventBus.hp_damage_taken, Callable(self, "_on_hp_damage_taken")],
		[
			EventBus.shield_absorption_resolved,
			Callable(self, "_on_shield_absorption_resolved"),
		],
		[EventBus.heal_received, Callable(self, "_on_heal_received")],
		[EventBus.shield_granted, Callable(self, "_on_shield_granted")],
		[EventBus.collision_impact, Callable(self, "_on_collision_impact")],
		[EventBus.hazard_kill, Callable(self, "_on_hazard_kill")],
		[EventBus.battle_view_ready, Callable(self, "_on_battle_view_ready")],
		[
			GameManager.reduced_motion_changed,
			Callable(self, "set_reduced_motion"),
		],
	]:
		var signal_value: Signal = entry[0]
		var callback: Callable = entry[1]
		if signal_value.is_connected(callback):
			signal_value.disconnect(callback)


func _connect_once(signal_value: Signal, callback: Callable) -> void:
	if not signal_value.is_connected(callback):
		signal_value.connect(callback)


func _on_battle_view_ready(view: Node) -> void:
	_battle_view = view as Node2D


func _on_hp_damage_taken(fact: CombatEventFact) -> void:
	if not _accept_fact(fact) or fact.amount_applied <= 0:
		return
	var lethal := _is_lethal_target(fact.target)
	var kind := CombatImpactBurst.DAMAGE
	if lethal:
		kind = CombatImpactBurst.LETHAL
	elif fact.is_critical:
		kind = CombatImpactBurst.CRITICAL
	_spawn_burst(
		fact.target,
		kind,
		_damage_strength(fact.amount_applied, kind),
		fact.logical_order,
	)
	if lethal:
		_request_punch(fact.target, fact.source, PUNCH_LETHAL)
	elif fact.is_critical and not fact.is_periodic:
		_request_punch(fact.target, fact.source, PUNCH_CRITICAL)


func _on_shield_absorption_resolved(fact: CombatEventFact) -> void:
	if not _accept_fact(fact) or fact.amount_absorbed <= 0:
		return
	_spawn_burst(
		fact.target,
		CombatImpactBurst.SHIELD_ABSORBED,
		_amount_strength(fact.amount_absorbed),
		fact.logical_order,
	)


func _on_heal_received(fact: CombatEventFact) -> void:
	if not _accept_fact(fact) or fact.amount_applied <= 0:
		return
	_spawn_burst(
		fact.target,
		CombatImpactBurst.HEAL,
		_amount_strength(fact.amount_applied),
		fact.logical_order,
	)


func _on_shield_granted(fact: CombatEventFact) -> void:
	if not _accept_fact(fact) or fact.amount_applied <= 0:
		return
	_spawn_burst(
		fact.target,
		CombatImpactBurst.SHIELD_GRANTED,
		_amount_strength(fact.amount_applied),
		fact.logical_order,
	)


func _on_collision_impact(attacker, victim, _damage: int) -> void:
	_request_punch(victim, attacker, PUNCH_SIGNATURE)


func _on_hazard_kill(unit, _effect_name: String) -> void:
	_request_punch(unit, null, PUNCH_SIGNATURE)


func _accept_fact(fact: CombatEventFact) -> bool:
	if not juice_enabled or fact == null or fact.target == null \
			or not is_inside_tree():
		return false
	if fact.event_id == &"":
		return true
	if _seen_event_ids.has(fact.event_id):
		return false
	_seen_event_ids[fact.event_id] = true
	_event_id_order.append(fact.event_id)
	while _event_id_order.size() > MAX_SEEN_EVENT_IDS:
		_seen_event_ids.erase(_event_id_order.pop_front())
	return true


func _spawn_burst(
		target,
		kind: StringName,
		strength: float,
		variation_seed: int
	) -> void:
	if not juice_enabled or not is_inside_tree() \
			or not is_instance_valid(_effect_root):
		return
	var local_position_value = _impact_local_position(target)
	if local_position_value == null:
		return
	var burst := IMPACT_BURST_SCRIPT.new() as CombatImpactBurst
	burst.configure(kind, strength, _reduced_motion, variation_seed)
	burst.position = local_position_value as Vector2
	burst.finished.connect(_on_burst_finished.bind(burst), CONNECT_ONE_SHOT)
	_effect_root.add_child(burst)
	_active_bursts.append(burst)
	_debug_burst_count += 1
	_debug_last_burst_kind = kind


func _on_burst_finished(burst: Node2D) -> void:
	_active_bursts.erase(burst)


func _clear_bursts() -> void:
	for burst in _active_bursts.duplicate():
		if is_instance_valid(burst):
			burst.queue_free()
	_active_bursts.clear()


func _install_effect_root() -> void:
	if is_instance_valid(_effect_root):
		return
	_effect_root = Node2D.new()
	_effect_root.name = "CombatImpactLayer"
	_effect_root.z_index = 55
	add_child(_effect_root)


func _impact_local_position(target):
	if not is_instance_valid(_effect_root):
		return null
	var target_canvas := target as CanvasItem
	if target_canvas is Node2D and is_instance_valid(target_canvas):
		return _effect_root.to_local(
			(target_canvas as Node2D).to_global(Vector2.ZERO)
		)
	if get_tree() != null:
		for candidate in get_tree().get_nodes_in_group("unit_views"):
			if candidate is Node2D and candidate.get("unit") == target:
				return _effect_root.to_local(
					(candidate as Node2D).to_global(UNIT_IMPACT_OFFSET)
				)
	if is_instance_valid(_battle_view) and target is Unit:
		var unit := target as Unit
		if unit.grid_pos != Vector2i(-1, -1):
			var cell_local: Vector2
			if _battle_view.has_method("grid_to_local"):
				cell_local = _battle_view.grid_to_local(unit.grid_pos)
			else:
				cell_local = _battle_view.grid_to_world(unit.grid_pos)
			return _effect_root.to_local(
				_battle_view.to_global(cell_local) + UNIT_IMPACT_OFFSET
			)
	return null


func _is_lethal_target(target) -> bool:
	return target is Unit \
		and (not (target as Unit).is_alive or (target as Unit).current_hp <= 0)


func _damage_strength(amount: int, kind: StringName) -> float:
	var base := _amount_strength(amount)
	if kind == CombatImpactBurst.CRITICAL:
		base += 0.22
	elif kind == CombatImpactBurst.LETHAL:
		base += 0.38
	return clampf(base, 0.55, 1.65)


func _amount_strength(amount: int) -> float:
	return clampf(0.68 + sqrt(float(maxi(amount, 1))) * 0.075, 0.55, 1.35)


func _request_punch(target, source, kind: StringName) -> void:
	if not juice_enabled or _reduced_motion or not is_inside_tree():
		return
	var now := Time.get_ticks_msec()
	var target_id := _instance_id_or_zero(target)
	var grade := _punch_grade(kind)
	if target_id != 0 and target_id == _last_punch_target_id \
			and now - _last_punch_at_ms <= PUNCH_DEDUP_WINDOW_MS:
		if grade > _last_punch_grade:
			_upgrade_active_punch(kind, now)
			_last_punch_grade = grade
		return
	_last_punch_target_id = target_id
	_last_punch_at_ms = now
	_last_punch_grade = grade
	_debug_punch_count += 1
	_debug_last_punch_kind = kind
	_start_freeze(_freeze_duration(kind), now)
	_start_camera_punch(
		target,
		source,
		_punch_duration(kind),
		_punch_amplitude(kind),
		now,
	)


func _upgrade_active_punch(kind: StringName, now: int) -> void:
	_debug_last_punch_kind = kind
	_start_freeze(_freeze_duration(kind), now)
	var upgraded_duration_ms := maxi(1, int(_punch_duration(kind) * 1000.0))
	_camera_punch_started_ms = now
	_camera_punch_duration_ms = upgraded_duration_ms
	_camera_punch_until_ms = now + upgraded_duration_ms
	_camera_punch_amplitude = maxf(
		_camera_punch_amplitude, _punch_amplitude(kind)
	)
	if _camera_ref != null:
		_begin_camera_tween(_punch_duration(kind))
	_update_process_state()


func _start_freeze(duration: float, now: int) -> void:
	if duration <= 0.0 or _reduced_motion:
		return
	_freeze_until_ms = maxi(_freeze_until_ms, now + int(duration * 1000.0))
	if not _owns_time_scale:
		_saved_time_scale = Engine.time_scale
		_owns_time_scale = true
		Engine.time_scale = 0.0
	_freeze_generation += 1
	var generation := _freeze_generation
	var remaining_seconds := maxf(
		0.001, float(_freeze_until_ms - now) / 1000.0
	)
	var timer := get_tree().create_timer(
		remaining_seconds, true, false, true
	)
	timer.timeout.connect(
		_on_freeze_timeout.bind(generation), CONNECT_ONE_SHOT
	)
	_update_process_state()


func _on_freeze_timeout(generation: int) -> void:
	if generation != _freeze_generation or not is_inside_tree():
		return
	_restore_time_scale()
	_update_process_state()


func _start_camera_punch(
		target,
		source,
		duration: float,
		amplitude: float,
		now: int
	) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		_update_process_state()
		return
	_adopt_camera(camera)
	_camera_punch_started_ms = now
	_camera_punch_duration_ms = maxi(1, int(duration * 1000.0))
	_camera_punch_until_ms = now + _camera_punch_duration_ms
	_camera_punch_amplitude = amplitude
	_camera_punch_direction = _impact_direction(source, target)
	_last_camera_offset = (
		_camera_base_offset + _camera_punch_direction * _camera_punch_amplitude
	)
	camera.offset = _last_camera_offset
	_begin_camera_tween(duration)
	_update_process_state()


func _begin_camera_tween(duration: float) -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.set_ignore_time_scale(true)
	_camera_tween.tween_method(
		Callable(self, "_apply_camera_punch_progress"),
		0.0,
		1.0,
		maxf(duration, 0.001),
	)
	var active_tween := _camera_tween
	active_tween.finished.connect(
		_on_camera_tween_finished.bind(active_tween), CONNECT_ONE_SHOT
	)
	_camera_generation += 1
	var generation := _camera_generation
	var timer := get_tree().create_timer(
		maxf(duration, 0.001), true, false, true
	)
	timer.timeout.connect(
		_on_camera_timeout.bind(generation), CONNECT_ONE_SHOT
	)


func _on_camera_timeout(generation: int) -> void:
	if generation != _camera_generation or not is_inside_tree():
		return
	_restore_camera()
	_update_process_state()


func _on_camera_tween_finished(tween: Tween) -> void:
	if tween != _camera_tween:
		return
	_camera_tween = null
	_restore_camera()
	_update_process_state()


func _adopt_camera(camera: Camera2D) -> void:
	var previous := _camera_ref.get_ref() as Camera2D if _camera_ref != null else null
	if previous == camera:
		return
	if is_instance_valid(previous):
		previous.offset = _camera_base_offset
	_camera_ref = weakref(camera)
	_camera_base_offset = camera.offset
	_last_camera_offset = camera.offset


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if not juice_enabled or _reduced_motion:
		_restore_time_scale()
		_restore_camera()
		_update_process_state()
		return
	if _owns_time_scale and now >= _freeze_until_ms:
		_restore_time_scale()
	_process_camera_punch(now)
	_update_process_state()


func _process_camera_punch(now: int) -> void:
	var camera := _camera_ref.get_ref() as Camera2D if _camera_ref != null else null
	if not is_instance_valid(camera) or now >= _camera_punch_until_ms:
		_restore_camera()
		return
	var elapsed := now - _camera_punch_started_ms
	var progress := clampf(
		float(elapsed) / float(maxi(_camera_punch_duration_ms, 1)), 0.0, 1.0
	)
	_apply_camera_punch_progress(progress)


func _apply_camera_punch_progress(progress: float) -> void:
	var camera := _camera_ref.get_ref() as Camera2D if _camera_ref != null else null
	if not is_instance_valid(camera):
		return
	if not juice_enabled or _reduced_motion:
		camera.offset = _camera_base_offset
		return
	progress = clampf(progress, 0.0, 1.0)
	var remaining := pow(1.0 - progress, 1.45)
	var perpendicular := Vector2(
		-_camera_punch_direction.y, _camera_punch_direction.x
	)
	var impulse := (
		_camera_punch_direction * cos(progress * TAU * 1.25)
		+ perpendicular * sin(progress * TAU * 2.0) * 0.28
	) * _camera_punch_amplitude * remaining
	_last_camera_offset = _camera_base_offset + impulse
	camera.offset = _last_camera_offset


func _restore_time_scale() -> void:
	_freeze_generation += 1
	if not _owns_time_scale:
		return
	if is_zero_approx(Engine.time_scale):
		Engine.time_scale = _saved_time_scale
	_owns_time_scale = false
	_freeze_until_ms = 0


func _restore_camera() -> void:
	_camera_generation += 1
	var tween := _camera_tween
	_camera_tween = null
	if tween != null and tween.is_valid():
		tween.kill()
	var camera := _camera_ref.get_ref() as Camera2D if _camera_ref != null else null
	if is_instance_valid(camera):
		camera.offset = _camera_base_offset
	_camera_ref = null
	_camera_punch_until_ms = 0
	_camera_punch_started_ms = 0
	_camera_punch_amplitude = 0.0


func _update_process_state() -> void:
	set_process(_owns_time_scale or _camera_ref != null)


func _impact_direction(source, target) -> Vector2:
	var source_position = _impact_local_position(source)
	var target_position = _impact_local_position(target)
	if source_position is Vector2 and target_position is Vector2:
		var delta := (target_position as Vector2) - (source_position as Vector2)
		if not delta.is_zero_approx():
			return delta.normalized()
	return Vector2(1.0, -0.28).normalized()


func _instance_id_or_zero(value) -> int:
	return value.get_instance_id() if is_instance_valid(value) else 0


func _punch_grade(kind: StringName) -> int:
	match kind:
		PUNCH_LETHAL:
			return 3
		PUNCH_SIGNATURE:
			return 2
		_:
			return 1


func _freeze_duration(kind: StringName) -> float:
	match kind:
		PUNCH_LETHAL:
			return LETHAL_FREEZE_TIME
		PUNCH_SIGNATURE:
			return SIGNATURE_FREEZE_TIME
		_:
			return CRITICAL_FREEZE_TIME


func _punch_duration(kind: StringName) -> float:
	match kind:
		PUNCH_LETHAL:
			return LETHAL_PUNCH_TIME
		PUNCH_SIGNATURE:
			return SIGNATURE_PUNCH_TIME
		_:
			return CRITICAL_PUNCH_TIME


func _punch_amplitude(kind: StringName) -> float:
	match kind:
		PUNCH_LETHAL:
			return LETHAL_PUNCH_AMPLITUDE
		PUNCH_SIGNATURE:
			return SIGNATURE_PUNCH_AMPLITUDE
		_:
			return CRITICAL_PUNCH_AMPLITUDE


func get_debug_snapshot() -> Dictionary:
	var live_bursts := 0
	for burst in _active_bursts:
		if is_instance_valid(burst) and not burst.is_queued_for_deletion():
			live_bursts += 1
	return {
		"active_burst_count": live_bursts,
		"burst_count": _debug_burst_count,
		"punch_count": _debug_punch_count,
		"last_burst_kind": _debug_last_burst_kind,
		"last_punch_kind": _debug_last_punch_kind,
		"reduced_motion": _reduced_motion,
		"owns_time_scale": _owns_time_scale,
		"camera_punch_active": _camera_ref != null,
		"seen_event_count": _seen_event_ids.size(),
	}
