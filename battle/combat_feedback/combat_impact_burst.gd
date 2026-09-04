class_name CombatImpactBurst
extends Node2D

signal finished

const DAMAGE: StringName = &"damage"
const CRITICAL: StringName = &"critical"
const LETHAL: StringName = &"lethal"
const SHIELD_ABSORBED: StringName = &"shield_absorbed"
const SHIELD_GRANTED: StringName = &"shield_granted"
const HEAL: StringName = &"heal"
const SIGNATURE: StringName = &"signature"

const MIN_STRENGTH := 0.55
const MAX_STRENGTH := 1.65

var effect_kind: StringName = DAMAGE
var strength := 1.0
var reduced_motion := false

var _elapsed := 0.0
var _duration := 0.34
var _phase_seed := 0.0


func configure(
		kind: StringName,
		intensity: float,
		use_reduced_motion: bool,
		variation_seed: int = 0
	) -> void:
	effect_kind = kind
	strength = clampf(intensity, MIN_STRENGTH, MAX_STRENGTH)
	reduced_motion = use_reduced_motion
	_duration = _duration_for_kind(kind)
	if reduced_motion:
		_duration = minf(_duration, 0.18)
	_phase_seed = float(posmod(variation_seed, 12)) * TAU / 12.0
	_elapsed = 0.0
	queue_redraw()


func _ready() -> void:
	z_index = 0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= _duration:
		finished.emit()
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_elapsed / maxf(_duration, 0.001), 0.0, 1.0)
	var fade := pow(1.0 - progress, 1.65)
	var motion := 0.28 if reduced_motion else ease(progress, -1.6)
	var color := _color_for_kind(effect_kind)
	var radius := _base_radius_for_kind(effect_kind) * strength
	var ring_radius := radius * (0.78 + motion * 0.72)
	var core_radius := radius * (0.34 - minf(motion * 0.16, 0.14))

	draw_circle(
		Vector2.ZERO,
		maxf(core_radius, 2.0),
		_with_alpha(color, fade * 0.18),
	)
	draw_arc(
		Vector2.ZERO,
		ring_radius,
		0.0,
		TAU,
		32,
		_with_alpha(color, fade * 0.92),
		maxf(1.4, 2.5 * strength * (1.0 - progress * 0.45)),
		true,
	)

	if effect_kind in [SHIELD_ABSORBED, SHIELD_GRANTED]:
		_draw_shield_rings(radius, motion, fade, color)
	elif effect_kind == HEAL:
		_draw_heal_mark(radius, motion, fade, color)
	else:
		_draw_impact_rays(radius, motion, fade, color)

	if effect_kind in [CRITICAL, LETHAL, SIGNATURE]:
		draw_arc(
			Vector2.ZERO,
			ring_radius * 1.34,
			-phase_seed() - PI * 0.15,
			-phase_seed() + PI * 0.72,
			18,
			_with_alpha(Color(1.0, 0.88, 0.52), fade * 0.72),
			maxf(1.0, 1.8 * strength),
			true,
		)


func _draw_impact_rays(
		radius: float,
		motion: float,
		fade: float,
		color: Color
	) -> void:
	var ray_count := 10 if effect_kind in [CRITICAL, LETHAL, SIGNATURE] else 7
	var inner_radius := radius * (0.48 + motion * 0.28)
	var outer_radius := radius * (0.92 + motion * 0.82)
	for index in range(ray_count):
		var angle := _phase_seed + TAU * float(index) / float(ray_count)
		var direction := Vector2.RIGHT.rotated(angle)
		var alternating := 0.82 if index % 2 == 0 else 1.0
		draw_line(
			direction * inner_radius,
			direction * outer_radius * alternating,
			_with_alpha(color, fade * 0.88),
			maxf(1.0, 2.1 * strength * (1.0 - progress_ratio() * 0.55)),
			true,
		)


func _draw_shield_rings(
		radius: float,
		motion: float,
		fade: float,
		color: Color
	) -> void:
	var inner := radius * (0.46 + motion * 0.24)
	draw_arc(
		Vector2.ZERO, inner, 0.0, TAU, 24,
		_with_alpha(Color(0.9, 0.97, 1.0), fade * 0.8),
		maxf(1.0, 1.7 * strength), true,
	)
	for index in range(6):
		var angle := _phase_seed + TAU * float(index) / 6.0
		var direction := Vector2.RIGHT.rotated(angle)
		draw_circle(
			direction * radius * (0.62 + motion * 0.38),
			maxf(1.3, 2.1 * strength),
			_with_alpha(color, fade * 0.86),
		)


func _draw_heal_mark(
		radius: float,
		motion: float,
		fade: float,
		color: Color
	) -> void:
	var half_length := radius * (0.28 + motion * 0.08)
	var width := maxf(1.2, 2.0 * strength)
	var ink := _with_alpha(color, fade * 0.9)
	draw_line(Vector2(-half_length, 0.0), Vector2(half_length, 0.0), ink, width, true)
	draw_line(Vector2(0.0, -half_length), Vector2(0.0, half_length), ink, width, true)


func progress_ratio() -> float:
	return clampf(_elapsed / maxf(_duration, 0.001), 0.0, 1.0)


func get_debug_snapshot() -> Dictionary:
	return {
		"kind": effect_kind,
		"strength": strength,
		"reduced_motion": reduced_motion,
		"elapsed": _elapsed,
		"duration": _duration,
	}


func _duration_for_kind(kind: StringName) -> float:
	match kind:
		LETHAL:
			return 0.46
		CRITICAL, SIGNATURE:
			return 0.40
		SHIELD_ABSORBED, SHIELD_GRANTED:
			return 0.36
		HEAL:
			return 0.38
		_:
			return 0.32


func _base_radius_for_kind(kind: StringName) -> float:
	match kind:
		LETHAL:
			return 28.0
		CRITICAL, SIGNATURE:
			return 24.0
		SHIELD_ABSORBED, SHIELD_GRANTED:
			return 22.0
		HEAL:
			return 20.0
		_:
			return 18.0


func _color_for_kind(kind: StringName) -> Color:
	match kind:
		CRITICAL:
			return Color(1.0, 0.72, 0.18)
		LETHAL:
			return Color(1.0, 0.20, 0.12)
		SHIELD_ABSORBED:
			return Color(0.30, 0.68, 1.0)
		SHIELD_GRANTED:
			return Color(0.36, 0.88, 1.0)
		HEAL:
			return Color(0.34, 1.0, 0.52)
		SIGNATURE:
			return Color(1.0, 0.52, 0.12)
		_:
			return Color(1.0, 0.34, 0.20)


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(color.a * alpha, 0.0, 1.0))


func phase_seed() -> float:
	return _phase_seed
