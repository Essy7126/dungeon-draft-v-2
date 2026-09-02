class_name CombatHighlightMarker
extends RefCounted

## Sémantique visuelle redondante avec la couleur des cases.
## Chaque famille de portée conserve sa teinte historique et reçoit une forme.

const MOVE: StringName = &"move"
const CONTROL_LIMITED: StringName = &"control_limited"
const ATTACK: StringName = &"attack"
const SPELL: StringName = &"spell"
const AOE: StringName = &"aoe"
const DEPLOYMENT: StringName = &"deployment"
const TARGET_VALID: StringName = &"target_valid"
const TARGET_INVALID: StringName = &"target_invalid"

const SHAPE_RING_CHECK: StringName = &"ring_check"
const SHAPE_BARRED_CIRCLE: StringName = &"barred_circle"

const INK := Color(0.97, 0.97, 0.91, 0.94)
const SHADOW := Color(0.015, 0.02, 0.025, 0.82)


static func entry(color: Color, marker: StringName = &"") -> Dictionary:
	return {"color": color, "marker": marker}


## Construit un marqueur de feedback superposable aux surbrillances de portee.
## La forme reste la source de verite : la couleur peut volontairement etre
## identique pour les cibles valides et invalides.
static func feedback_entry(
	is_valid_target: bool,
	color: Color = INK
	) -> Dictionary:
	var marker := TARGET_VALID if is_valid_target else TARGET_INVALID
	return {
		"color": color,
		"marker": marker,
		"shape": shape_for_marker(marker),
		"valid": is_valid_target,
	}


static func color_of(value) -> Color:
	return (
		value.get("color", Color.TRANSPARENT)
		if value is Dictionary
		else Color(value)
	)


static func marker_of(value) -> StringName:
	return (
		StringName(value.get("marker", &""))
		if value is Dictionary
		else &""
	)


static func shape_for_marker(marker: StringName) -> StringName:
	match marker:
		TARGET_VALID:
			return SHAPE_RING_CHECK
		TARGET_INVALID:
			return SHAPE_BARRED_CIRCLE
		_:
			return &""


static func shape_of(value) -> StringName:
	if value is Dictionary and value.has("shape"):
		return StringName(value["shape"])
	return shape_for_marker(marker_of(value))


static func radius_for_polygon(
	center: Vector2,
	polygon: PackedVector2Array
	) -> float:
	var radius := INF
	for point in polygon:
		radius = minf(radius, center.distance_to(point))
	return maxf(radius * 0.52, 5.0) if is_finite(radius) else 8.0


static func draw(
	canvas: CanvasItem,
	center: Vector2,
	marker: StringName,
	radius: float,
	ink: Color = INK
	) -> void:
	if canvas == null or marker == &"":
		return
	radius = maxf(radius, 5.0)
	match marker:
		MOVE:
			canvas.draw_circle(center, radius * 0.28 + 1.5, SHADOW)
			canvas.draw_circle(center, radius * 0.28, ink)
		CONTROL_LIMITED:
			var gap := radius * 0.22
			_draw_line(
				canvas,
				center + Vector2(-radius * 0.62, -gap),
				center + Vector2(radius * 0.62, -gap),
				ink,
			)
			_draw_line(
				canvas,
				center + Vector2(-radius * 0.62, gap),
				center + Vector2(radius * 0.62, gap),
				ink,
			)
		ATTACK:
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -radius * 0.62),
				center + Vector2(radius * 0.62, 0.0),
				center + Vector2(0.0, radius * 0.62),
				center + Vector2(-radius * 0.62, 0.0),
				center + Vector2(0.0, -radius * 0.62),
			])
			canvas.draw_polyline(diamond, SHADOW, 4.0, true)
			canvas.draw_polyline(diamond, ink, 2.0, true)
		SPELL:
			_draw_line(
				canvas,
				center + Vector2(-radius * 0.62, 0.0),
				center + Vector2(radius * 0.62, 0.0),
				ink,
			)
			_draw_line(
				canvas,
				center + Vector2(0.0, -radius * 0.62),
				center + Vector2(0.0, radius * 0.62),
				ink,
			)
		AOE:
			canvas.draw_arc(center, radius * 0.56, 0.0, TAU, 24, SHADOW, 4.0, true)
			canvas.draw_arc(center, radius * 0.56, 0.0, TAU, 24, ink, 2.0, true)
			canvas.draw_circle(center, 2.2, ink)
		DEPLOYMENT:
			var half := radius * 0.5
			var square := PackedVector2Array([
				center + Vector2(-half, -half),
				center + Vector2(half, -half),
				center + Vector2(half, half),
				center + Vector2(-half, half),
				center + Vector2(-half, -half),
			])
			canvas.draw_polyline(square, SHADOW, 4.0, true)
			canvas.draw_polyline(square, ink, 2.0, true)
		TARGET_VALID:
			_draw_ring(canvas, center, radius * 0.66, ink)
			_draw_line(
				canvas,
				center + Vector2(-radius * 0.34, radius * 0.02),
				center + Vector2(-radius * 0.08, radius * 0.29),
				ink,
			)
			_draw_line(
				canvas,
				center + Vector2(-radius * 0.08, radius * 0.29),
				center + Vector2(radius * 0.39, -radius * 0.28),
				ink,
			)
		TARGET_INVALID:
			_draw_ring(canvas, center, radius * 0.66, ink)
			_draw_line(
				canvas,
				center + Vector2(-radius * 0.39, -radius * 0.39),
				center + Vector2(radius * 0.39, radius * 0.39),
				ink,
			)
			_draw_line(
				canvas,
				center + Vector2(radius * 0.39, -radius * 0.39),
				center + Vector2(-radius * 0.39, radius * 0.39),
				ink,
			)


static func draw_feedback(
	canvas: CanvasItem,
	center: Vector2,
	value: Dictionary,
	radius: float
	) -> void:
	draw(canvas, center, marker_of(value), radius, color_of(value))


static func _draw_ring(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	ink: Color
	) -> void:
	canvas.draw_arc(center, radius, 0.0, TAU, 32, SHADOW, 5.0, true)
	canvas.draw_arc(center, radius, 0.0, TAU, 32, ink, 2.5, true)


static func _draw_line(
	canvas: CanvasItem,
	from: Vector2,
	to: Vector2,
	ink: Color = INK
	) -> void:
	canvas.draw_line(from, to, SHADOW, 4.0, true)
	canvas.draw_line(from, to, ink, 2.0, true)
