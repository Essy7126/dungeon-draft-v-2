@tool
extends Node2D

const STYLE := preload("res://battle/painted/registered_terrain/terrain_style.gd")
var _palette: Dictionary = {}

@export_range(16.0, 120.0, 1.0) var block_height := 30.0
@export var carved_column := false
@export var bench_section := false

# The points below are an artist's reference drawing in a 108x54 cell space.
# The entire drawing (base, crown, height, carving, shadow and strokes) is
# transformed to the real cell polygon after assembly. It is not a fixed-size
# gameplay footprint and may follow any calibrated affine.
const REFERENCE_SPAN := Vector2(108, 54)
var _drawing_affine := Transform2D.IDENTITY

func configure_palette(value: Dictionary) -> void:
	_palette = value.duplicate(true)
	queue_redraw()

func configure_footprint(cell_polygon_local: PackedVector2Array) -> void:
	if cell_polygon_local.size() != 4:
		return
	var center := (cell_polygon_local[0] + cell_polygon_local[2]) * 0.5
	_drawing_affine = Transform2D(
		(cell_polygon_local[1] - cell_polygon_local[3]) / REFERENCE_SPAN.x,
		(cell_polygon_local[2] - cell_polygon_local[0]) / REFERENCE_SPAN.y,
		center)
	set_meta("greek_prop_tile_span", Vector2(
		cell_polygon_local[1].distance_to(cell_polygon_local[3]),
		cell_polygon_local[2].distance_to(cell_polygon_local[0])))
	set_meta("greek_prop_scaled_height", block_height * _drawing_affine.y.length())
	queue_redraw()

func get_base_footprint() -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in [Vector2(0,-25), Vector2(50,0), Vector2(0,25), Vector2(-50,0)]:
		result.append(_drawing_affine * point)
	return result

const INK := Color("656447")
const TOP := Color("d2c78d")
const LEFT := Color("aea571")
const RIGHT := Color("888759")

func _ready() -> void:
	set_meta(&"greek_prop_ready", true)
	queue_redraw()

func _draw() -> void:
	set_meta(&"greek_prop_draw_count", int(get_meta(&"greek_prop_draw_count", 0)) + 1)
	draw_set_transform_matrix(_drawing_affine)
	var h := block_height
	var base := PackedVector2Array([
		Vector2(0, -25), Vector2(50, 0), Vector2(0, 25), Vector2(-50, 0),
	])
	var crown := PackedVector2Array([
		Vector2(-1, -25-h), Vector2(49, -h+1),
		Vector2(1, 24-h), Vector2(-49, -h-1),
	])
	var shadow := PackedVector2Array([
		Vector2(-51, 5), Vector2(0, -19), Vector2(65, 12),
		Vector2(19, 37), Vector2(-38, 22),
	])
	draw_colored_polygon(shadow, _palette_color("shadow",Color(0.10,0.17,0.13,0.22)))
	_face(PackedVector2Array([crown[3], crown[2], base[2], base[3]]), _palette_color("left",LEFT))
	_face(PackedVector2Array([crown[2], crown[1], base[1], base[2]]), _palette_color("right",RIGHT))
	var chipped_crown := PackedVector2Array([
		Vector2(-1,-25-h), Vector2(8,-21-h), Vector2(43,-4-h),
		Vector2(46,-4-h), Vector2(49,1-h), Vector2(1,24-h),
		Vector2(-39,4-h), Vector2(-39,-h), Vector2(-49,-1-h), Vector2(-27,-14-h),
	])
	_face(chipped_crown, _palette_color("top",TOP))
	draw_polyline(PackedVector2Array([crown[3]+Vector2(3,1), crown[0]+Vector2(1,3), crown[1]+Vector2(-3,1)]), _palette_color("highlight",Color("ead799")), 2.2, true)
	draw_polyline(PackedVector2Array([crown[3]+Vector2(0,8), crown[2]+Vector2(0,8), crown[1]+Vector2(0,8)]), _palette_color("edge_shadow",Color(0.35,0.39,0.27,0.32)), 1.5, true)
	# Original Greek key carving, kept broad enough to read at game scale.
	var key := PackedVector2Array([
		Vector2(-34, 4-h), Vector2(-24, 9-h), Vector2(-24, 16-h),
		Vector2(-13, 22-h), Vector2(-13, 15-h), Vector2(-3, 20-h),
	])
	draw_polyline(key, _palette_color("carving",Color(0.37,0.40,0.28,0.62)), 2.0, true)
	draw_polyline(PackedVector2Array([
		Vector2(29,-h+9), Vector2(24,-h+18), Vector2(28,-h+24), Vector2(25,-h+34),
	]), _palette_color("crack",Color(0.30,0.35,0.24,0.5)), 1.2, true)
	# Sparse brush-like mineral flecks; no noise texture or global post effect.
	draw_line(Vector2(-14,-h-8), Vector2(3,-h+0), _palette_color("fleck_dark",Color(0.72,0.72,0.51,0.4)), 2.2, true)
	draw_line(Vector2(8,-h-7), Vector2(22,-h), _palette_color("fleck_light",Color(0.97,0.93,0.75,0.8)), 1.5, true)
	draw_line(Vector2(-43,9), Vector2(-25,18), _palette_color("moss",Color(0.35,0.44,0.28,0.4)), 3.0, true)
	if carved_column:
		for x in [-29.0, -18.0, -7.0]:
			var offset_y: float = (float(x) + 50.0) * 0.5
			draw_line(Vector2(x, -h+18+offset_y), Vector2(x, -9+offset_y), _palette_color("column",Color(0.42,0.46,0.32,0.5)), 2.0, true)
	if bench_section:
		draw_line(Vector2(-45,-h-2), Vector2(-3,-h+19), _palette_color("bench",Color("e5d399")), 3.0, true)

func _face(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, _palette_color("ink",INK), 1.6, true)




func _palette_color(key: String, fallback: Color) -> Color:
	return STYLE.color(_palette.get(key, fallback), fallback)
