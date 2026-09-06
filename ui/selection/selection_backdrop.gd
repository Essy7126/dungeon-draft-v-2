class_name SelectionBackdrop
extends Control
## Restrained architectural stage behind the character-selection interface.
## All coordinates share the selection screen's 1600 × 900 design canvas.

const CANVAS := Vector2(1600.0, 900.0)
const INK := Color("10191b")
const GOLD := Color("c5a16b")
const STAGE_CENTER := Vector2(742.0, 686.0)

var _painted: Texture2D
var _ambient: GradientTexture2D
var _floor_light: GradientTexture2D
var _vignette: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://asset/ui/character_selection/sanctuary_v2.png"):
		_painted = load("res://asset/ui/character_selection/sanctuary_v2.png")
	_ambient = _radial_texture(Color(0.17, 0.33, 0.32, 0.72), Color(0.05, 0.10, 0.11, 0.0))
	_floor_light = _radial_texture(Color(0.31, 0.43, 0.37, 0.25), Color(0.10, 0.18, 0.18, 0.0))
	_vignette = _radial_texture(Color(0.025, 0.05, 0.06, 0.0), Color(0.025, 0.05, 0.06, 0.44))
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	var fit := minf(size.x / CANVAS.x, size.y / CANVAS.y)
	var canvas_offset := (size - CANVAS * fit) * 0.5
	draw_set_transform(canvas_offset, 0.0, Vector2.ONE * fit)

	if _ambient != null:
		draw_texture_rect(_ambient, Rect2(116.0, -112.0, 1058.0, 1058.0), false)
	if _painted != null:
		draw_texture_rect(_painted, Rect2(-58, 0, 1600, 900), false, Color.WHITE)
	else:
		_draw_architecture()
		_draw_celestial_seal()
		_draw_floor()
		_draw_plinth()
	_draw_motes()
	if _vignette != null:
		draw_texture_rect(_vignette, Rect2(-80.0, -140.0, 1760.0, 1180.0), false)
	# Keep the header, roster and statistics silhouettes quiet and readable.
	draw_rect(Rect2(0.0, 0.0, 1600.0, 96.0), Color(0.035, 0.060, 0.065, 0.27))
	draw_rect(Rect2(0.0, 802.0, 1600.0, 98.0), Color(0.025, 0.045, 0.050, 0.54))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_architecture() -> void:
	var stone := Color(0.31, 0.39, 0.36, 0.17)
	var edge := Color(0.48, 0.51, 0.42, 0.143)
	# A monumental lintel and two receding columns frame the open stage.
	draw_rect(Rect2(310.0, 124.0, 670.0, 13.0), stone)
	draw_line(Vector2(301.0, 139.0), Vector2(979.0, 139.0), edge, 1.0, true)
	draw_line(Vector2(317.0, 150.0), Vector2(973.0, 150.0), Color(0.45, 0.47, 0.38, 0.078), 1.0, true)
	_draw_column(Vector2(332.0, 155.0), 58.0, 492.0)
	_draw_column(Vector2(900.0, 155.0), 58.0, 492.0)
	# Inner portal lines are deliberately faint so the hero owns the silhouette.
	var portal := PackedVector2Array([
		Vector2(405.0, 608.0), Vector2(405.0, 249.0), Vector2(428.0, 204.0),
		Vector2(471.0, 181.0), Vector2(819.0, 181.0), Vector2(862.0, 204.0),
		Vector2(885.0, 249.0), Vector2(885.0, 608.0),
	])
	draw_polyline(portal, Color(0.42, 0.53, 0.47, 0.098), 1.0, true)
	var beam := PackedVector2Array([
		Vector2(550.0, 150.0), Vector2(740.0, 150.0),
		Vector2(919.0, 732.0), Vector2(374.0, 732.0),
	])
	draw_polygon(beam, PackedColorArray([
		Color(0.55, 0.64, 0.48, 0.027), Color(0.55, 0.64, 0.48, 0.027),
		Color(0.28, 0.42, 0.37, 0.0), Color(0.28, 0.42, 0.37, 0.0),
	]))


func _draw_column(origin: Vector2, width: float, height: float) -> void:
	var face := Color(0.35, 0.42, 0.38, 0.13)
	var edge := Color(0.51, 0.53, 0.44, 0.156)
	draw_rect(Rect2(origin + Vector2(-10.0, 0.0), Vector2(width + 20.0, 10.0)), face)
	draw_rect(Rect2(origin + Vector2(-3.0, 15.0), Vector2(width + 6.0, 12.0)), face)
	var shaft := PackedVector2Array([
		origin + Vector2(5.0, 30.0), origin + Vector2(width - 5.0, 30.0),
		origin + Vector2(width, height - 25.0), origin + Vector2(0.0, height - 25.0),
	])
	draw_colored_polygon(shaft, Color(0.29, 0.38, 0.35, 0.098))
	for i in range(5):
		var inset := 8.0 + float(i) * (width - 16.0) / 4.0
		draw_line(origin + Vector2(inset, 32.0), origin + Vector2(inset, height - 27.0), edge, 1.0, true)
	draw_rect(Rect2(origin + Vector2(-4.0, height - 21.0), Vector2(width + 8.0, 8.0)), face)
	draw_rect(Rect2(origin + Vector2(-11.0, height - 8.0), Vector2(width + 22.0, 8.0)), face)


func _draw_celestial_seal() -> void:
	var center := Vector2(STAGE_CENTER.x, 393.0)
	draw_arc(center, 207.0, 0.0, TAU, 120, Color(GOLD, 0.117), 1.0, true)
	draw_arc(center, 192.0, 0.0, TAU, 120, Color(GOLD, 0.072), 1.0, true)
	# Broken outer engraving creates a subtle astrolabe without a solid UI frame.
	for i in range(4):
		var angle := float(i) * PI * 0.5
		draw_arc(center, 216.0, angle + 0.16, angle + PI * 0.5 - 0.16, 32, Color(GOLD, 0.17), 1.0, true)
	for i in range(48):
		var angle := TAU * float(i) / 48.0
		var direction := Vector2(cos(angle), sin(angle))
		var major := i % 6 == 0
		var length := 7.0 if major else 3.0
		draw_line(center + direction * 207.0, center + direction * (207.0 - length), Color(GOLD, 0.22 if major else 0.11), 1.0, true)
	_draw_star(center + Vector2(0.0, -216.0), 6.0, Color(GOLD, 0.52))
	_draw_star(center + Vector2(-216.0, 0.0), 4.0, Color(GOLD, 0.325))
	_draw_star(center + Vector2(216.0, 0.0), 4.0, Color(GOLD, 0.325))
	# Small geometric keystone above the seal echoes ancient metal inlay.
	var keystone := PackedVector2Array([
		Vector2(636.0, 164.0), Vector2(645.0, 158.0),
		Vector2(654.0, 164.0), Vector2(645.0, 170.0), Vector2(636.0, 164.0),
	])
	draw_polyline(keystone, Color(GOLD, 0.325), 1.0, true)


func _draw_floor() -> void:
	if _floor_light != null:
		draw_texture_rect(_floor_light, Rect2(298.0, 566.0, 694.0, 242.0), false)
	var horizon := Vector2(STAGE_CENTER.x, 600.0)
	for end_x in [134.0, 304.0, 474.0, 816.0, 986.0, 1156.0]:
		draw_line(horizon, Vector2(end_x, 814.0), Color(0.41, 0.51, 0.44, 0.045), 1.0, true)
	for offset in [23.0, 47.0, 78.0]:
		var radii := Vector2(246.0 + offset, 47.0 + offset * 0.42)
		draw_polyline(_ellipse(STAGE_CENTER + Vector2(0.0, 15.0), radii), Color(GOLD, 0.035), 1.0, true)


func _draw_plinth() -> void:
	var center := STAGE_CENTER
	var radius := Vector2(198.0, 47.0)
	# Shadow, stone depth, and the inset top are separate shapes, not a flat oval.
	draw_colored_polygon(_ellipse(center + Vector2(0.0, 26.0), Vector2(226.0, 53.0)), Color(0.025, 0.05, 0.055, 0.36))
	draw_colored_polygon(_ellipse(center + Vector2(0.0, 19.0), radius + Vector2(8.0, 0.0)), Color("192a2b"))
	draw_polyline(_ellipse(center + Vector2(0.0, 19.0), radius + Vector2(8.0, 0.0)), Color(GOLD, 0.11), 1.0, true)
	var front := PackedVector2Array()
	for i in range(65):
		var angle := PI * float(i) / 64.0
		front.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	for i in range(64, -1, -1):
		var angle := PI * float(i) / 64.0
		front.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y + 18.0))
	draw_colored_polygon(front, Color("263b39"))
	draw_colored_polygon(_ellipse(center, radius), Color("2c4140"))
	draw_colored_polygon(_ellipse(center, radius - Vector2(14.0, 4.0)), Color("293e3d"))
	draw_polyline(_ellipse(center, radius), Color(GOLD, 0.43), 1.35, true)
	draw_polyline(_ellipse(center, radius - Vector2(10.0, 2.5)), Color(GOLD, 0.12), 1.0, true)
	draw_polyline(_ellipse(center, radius - Vector2(37.0, 10.0)), Color(GOLD, 0.14), 1.0, true)
	for i in range(12):
		var angle := TAU * float(i) / 12.0
		var outer := center + Vector2(cos(angle) * 194.0, sin(angle) * 46.0)
		var inner := center + Vector2(cos(angle) * 169.0, sin(angle) * 40.0)
		draw_line(inner, outer, Color(GOLD, 0.16), 1.0, true)
		if sin(angle) > 0.1:
			draw_line(outer + Vector2(0.0, 2.0), outer + Vector2(0.0, 17.0), Color(0.05, 0.09, 0.09, 0.32), 1.0, true)
	# A single illuminated edge and center sigil give the stone a focal point.
	draw_arc_ellipse(center, radius, 0.24, PI - 0.24, Color(GOLD, 0.21))
	_draw_star(center + Vector2(0.0, 27.0), 6.0, Color(GOLD, 0.30))


func _draw_motes() -> void:
	# Deterministic particles: no process loop or redraw cost while the screen rests.
	for i in range(30):
		var x := 402.0 + fmod(float(i * 127 + 43), 478.0)
		var y := 212.0 + fmod(float(i * 89 + 17), 401.0)
		var alpha := 0.07 + float(i % 4) * 0.022
		draw_circle(Vector2(x, y), 0.7 if i % 5 != 0 else 1.2, Color(0.78, 0.77, 0.56, alpha))


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius), center + Vector2(radius * 0.22, -radius * 0.22),
		center + Vector2(radius, 0.0), center + Vector2(radius * 0.22, radius * 0.22),
		center + Vector2(0.0, radius), center + Vector2(-radius * 0.22, radius * 0.22),
		center + Vector2(-radius, 0.0), center + Vector2(-radius * 0.22, -radius * 0.22),
	])
	draw_colored_polygon(points, color)


func draw_arc_ellipse(center: Vector2, radius: Vector2, from: float, to: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(65):
		var angle := lerpf(from, to, float(i) / 64.0)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_polyline(points, color, 1.0, true)


func _ellipse(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(97):
		var angle := TAU * float(i) / 96.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


func _radial_texture(inner: Color, outer: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, inner)
	gradient.set_color(1, outer)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 512
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture
