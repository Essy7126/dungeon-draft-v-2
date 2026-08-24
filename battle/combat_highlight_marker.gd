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

const INK := Color(0.97, 0.97, 0.91, 0.94)
const SHADOW := Color(0.015, 0.02, 0.025, 0.82)


static func entry(color: Color, marker: StringName = &"") -> Dictionary:
	return {"color": color, "marker": marker}


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
	radius: float
	) -> void:
	if canvas == null or marker == &"":
		return
	radius = maxf(radius, 5.0)
	match marker:
		MOVE:
			canvas.draw_circle(center, radius * 0.28 + 1.5, SHADOW)
			canvas.draw_circle(center, radius * 0.28, INK)
		CONTROL_LIMITED:
			var gap := radius * 0.22
			_draw_line(
				canvas,
				center + Vector2(-radius * 0.62, -gap),
				center + Vector2(radius * 0.62, -gap),
			)
			_draw_line(
				canvas,
				center + Vector2(-radius * 0.62, gap),
				center + Vector2(radius * 0.62, gap),
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
			canvas.draw_polyline(diamond, INK, 2.0, true)
		SPELL:
			_draw_line(
				canvas,
				center + Vector2(-radius * 0.62, 0.0),
				center + Vector2(radius * 0.62, 0.0),
			)
			_draw_line(
				canvas,
				center + Vector2(0.0, -radius * 0.62),
				center + Vector2(0.0, radius * 0.62),
			)
		AOE:
			canvas.draw_arc(center, radius * 0.56, 0.0, TAU, 24, SHADOW, 4.0, true)
			canvas.draw_arc(center, radius * 0.56, 0.0, TAU, 24, INK, 2.0, true)
			canvas.draw_circle(center, 2.2, INK)
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
			canvas.draw_polyline(square, INK, 2.0, true)


static func _draw_line(
	canvas: CanvasItem,
	from: Vector2,
	to: Vector2
	) -> void:
	canvas.draw_line(from, to, SHADOW, 4.0, true)
	canvas.draw_line(from, to, INK, 2.0, true)
