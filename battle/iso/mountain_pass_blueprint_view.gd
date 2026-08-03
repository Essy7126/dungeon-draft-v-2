@tool
class_name MountainPassBlueprintView
extends Node2D

## Vue 2D 16:9 reservee au blueprint artistique du col enneige.
## MountainPassBlockoutData/GridData restent les seules autorites logiques ;
## cette vue dessine un fond, expose la projection existante et route les
## interactions sans deduire la moindre information de gameplay des pixels.

signal cell_hovered(grid_pos: Vector2i)
signal cell_clicked(grid_pos: Vector2i)

enum RenderMode {
	REFERENCE,
	CLEAN,
	LOGIC,
	FOREGROUND_GUIDE,
	DEBUG,
	INTERACTION_ONLY,
	GRID_OVERLAY,
	TERRAIN_OVERLAY,
}

const INVALID_CELL := Vector2i(-1, -1)
const CANVAS_SIZE := Vector2i(1920, 1080)
const CANVAS_RECT := Rect2(Vector2.ZERO, Vector2(CANVAS_SIZE))
const DEFAULT_GRID_ORIGIN := Vector2(960.0, 232.0)
const DEFAULT_AXIS_X := Vector2(48.0, 24.0)
const DEFAULT_AXIS_Y := Vector2(-48.0, 24.0)
const EXPECTED_GRID_BOUNDS := Rect2(288.0, 208.0, 1344.0, 672.0)
const SCENE_USEFUL_BOUNDS := Rect2(24.0, 72.0, 1872.0, 984.0)

const GRAPHIC_CATEGORIES := [
	"DISTANT_BACKGROUND",
	"REAR_MOUNTAINS",
	"REAR_CLIFFS",
	"NON_PLAYABLE_SNOW",
	"WALKABLE_SNOW",
	"OLD_ROAD",
	"ICE",
	"BLOCKED_ROCKS",
	"RUIN",
	"VOID_RAVINES",
	"FRONT_CLIFFS",
	"FOREGROUND_OCCLUSION_GUIDE",
]

const COLOR_SKY := Color("dce9ef")
const COLOR_DISTANT := Color("c7d5dd")
const COLOR_MOUNTAIN := Color("91a5b1")
const COLOR_MOUNTAIN_SNOW := Color("d9e3e8")
const COLOR_REAR_CLIFF := Color("667b88")
const COLOR_NON_PLAYABLE_SNOW := Color("e1e8eb")
const COLOR_WALKABLE_SNOW := Color("f4f7f7")
const COLOR_ROAD := Color("c8c1b3")
const COLOR_ICE := Color("9fd8e8")
const COLOR_BLOCKED_ROCK := Color("53636d")
const COLOR_RUIN := Color("343f47")
const COLOR_RAVINE := Color("354b58")
const COLOR_RAVINE_DEEP := Color("263944")
const COLOR_FRONT_CLIFF := Color("435966")
const COLOR_GRID := Color(0.13, 0.22, 0.28, 0.46)
const COLOR_GRID_STRONG := Color(0.08, 0.15, 0.20, 0.72)
const COLOR_FOREGROUND_GUIDE := Color(0.12, 0.70, 0.67, 0.62)
const COLOR_ALLY := Color("328ee6")
const COLOR_ENEMY := Color("dc554d")

const LOGIC_COLORS := {
	MountainPassBlockoutData.NORMAL: Color("e8eef0"),
	MountainPassBlockoutData.ICE: Color("73cce5"),
	MountainPassBlockoutData.BLOCKED: Color("4c5962"),
	MountainPassBlockoutData.LANDMARK: Color("66506b"),
	MountainPassBlockoutData.VOID: Color("263a46"),
	MountainPassBlockoutData.ALLY_SPAWN: COLOR_ALLY,
	MountainPassBlockoutData.ENEMY_SPAWN: COLOR_ENEMY,
}

@export var blockout_data: MountainPassBlockoutData:
	set(value):
		blockout_data = value
		queue_redraw()

@export var render_mode := RenderMode.REFERENCE:
	set(value):
		render_mode = value
		queue_redraw()

@export_group("Calibration blueprint 16:9")
@export var grid_origin := DEFAULT_GRID_ORIGIN:
	set(value):
		grid_origin = value
		queue_redraw()
@export var axis_x := DEFAULT_AXIS_X:
	set(value):
		axis_x = value
		queue_redraw()
@export var axis_y := DEFAULT_AXIS_Y:
	set(value):
		axis_y = value
		queue_redraw()
@export var camera_zoom := Vector2.ONE
@export var camera_offset := Vector2.ZERO

@export_group("Apercu laboratoire")
@export var show_unit_preview := false:
	set(value):
		show_unit_preview = value
		queue_redraw()

var grid: GridData = null
var _hovered_cell := INVALID_CELL
var _selected_cell := INVALID_CELL
var _highlights: Dictionary = {}


func _ready() -> void:
	queue_redraw()


func setup(grid_data: GridData) -> void:
	grid = grid_data
	_hovered_cell = INVALID_CELL
	_selected_cell = INVALID_CELL
	_highlights.clear()
	queue_redraw()


func grid_to_local(cell: Vector2i) -> Vector2:
	return grid_origin + float(cell.x) * axis_x + float(cell.y) * axis_y


func grid_to_world(cell: Vector2i) -> Vector2:
	return grid_to_local(cell)


func local_to_grid(local_position: Vector2) -> Vector2i:
	var local := local_position - grid_origin
	var determinant := axis_x.x * axis_y.y - axis_y.x * axis_x.y
	if is_zero_approx(determinant):
		return INVALID_CELL
	var raw_x := (local.x * axis_y.y - axis_y.x * local.y) / determinant
	var raw_y := (axis_x.x * local.y - local.x * axis_x.y) / determinant
	return Vector2i(roundi(raw_x), roundi(raw_y))


func world_to_grid(local_position: Vector2) -> Vector2i:
	return local_to_grid(local_position)


func get_cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var center := grid_to_local(cell)
	var half_width := absf(axis_x.x - axis_y.x) * 0.5
	var half_height := absf(axis_x.y + axis_y.y) * 0.5
	return PackedVector2Array([
		center + Vector2(0.0, -half_height),
		center + Vector2(half_width, 0.0),
		center + Vector2(0.0, half_height),
		center + Vector2(-half_width, 0.0),
	])


func get_map_bounds() -> Rect2:
	return CANVAS_RECT


func get_logical_bounds() -> Rect2:
	return _bounds_for_cells(_all_logical_cells())


func get_scene_useful_bounds() -> Rect2:
	return SCENE_USEFUL_BOUNDS


func get_pixel_size() -> Vector2:
	return Vector2(CANVAS_SIZE)


func highlight(cells: Array, color: Color) -> void:
	for cell in cells:
		if cell is Vector2i and _is_logical_cell(cell):
			_highlights[cell] = color
	queue_redraw()


func clear_highlights() -> void:
	_highlights.clear()
	queue_redraw()


func set_selected_cell(cell: Vector2i) -> void:
	if _is_interactable(cell):
		_selected_cell = cell
		queue_redraw()


func clear_selection() -> void:
	_selected_cell = INVALID_CELL
	queue_redraw()


func get_hovered_cell() -> Vector2i:
	return _hovered_cell


func get_selected_cell() -> Vector2i:
	return _selected_cell


func update_hover(local_position: Vector2) -> Vector2i:
	var cell := _valid_cell_at(local_position)
	if cell != _hovered_cell:
		_hovered_cell = cell
		queue_redraw()
		cell_hovered.emit(cell)
	return cell


func click_at(local_position: Vector2) -> Vector2i:
	var cell := _valid_cell_at(local_position)
	if cell != INVALID_CELL:
		set_selected_cell(cell)
		cell_clicked.emit(cell)
	return cell


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if CANVAS_SIZE != Vector2i(1920, 1080):
		errors.append("Le canvas blueprint doit faire 1920x1080.")
	if axis_x != DEFAULT_AXIS_X or axis_y != DEFAULT_AXIS_Y:
		errors.append("La projection doit conserver axis_x=(48,24) et axis_y=(-48,24).")
	if not is_equal_approx(absf(axis_x.x - axis_y.x), 96.0) \
			or not is_equal_approx(absf(axis_x.y + axis_y.y), 48.0):
		errors.append("Chaque cellule doit mesurer 96x48 pixels.")
	if get_logical_bounds() != EXPECTED_GRID_BOUNDS:
		errors.append("Les bounds de grille doivent etre %s." % EXPECTED_GRID_BOUNDS)
	if blockout_data == null:
		errors.append("MountainPassBlockoutData est requis.")
	elif not blockout_data.validation_errors().is_empty():
		errors.append_array(blockout_data.validation_errors())
	else:
		if blockout_data.void_cells().size() != 32:
			errors.append("Le layout doit conserver exactement 32 cellules VOID.")
		if get_reference_grid_cells().size() != 164:
			errors.append("La plateforme visuelle doit contenir 164 cellules non-VOID.")
		var obstacle_sizes: Array[int] = []
		for group in get_obstacle_visual_groups():
			obstacle_sizes.append(group.size())
		obstacle_sizes.sort()
		if obstacle_sizes != [1, 1, 1, 2, 2, 4]:
			errors.append("Les volumes obstacles doivent conserver les empreintes 1,1,1,2,2,4.")
	return errors


func _unhandled_input(event: InputEvent) -> void:
	if grid == null:
		return
	if event is InputEventMouseMotion:
		update_hover(get_local_mouse_position())
	elif event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click_at(get_local_mouse_position())


func _draw() -> void:
	if blockout_data == null:
		return
	match render_mode:
		RenderMode.FOREGROUND_GUIDE:
			_draw_foreground_guide()
		RenderMode.LOGIC:
			_draw_logic_blueprint()
		RenderMode.INTERACTION_ONLY:
			_draw_runtime_overlays()
			_draw_units_if_enabled()
		RenderMode.GRID_OVERLAY:
			_draw_grid_overlay(false)
			_draw_runtime_overlays()
			_draw_units_if_enabled()
		RenderMode.TERRAIN_OVERLAY:
			_draw_grid_overlay(true)
			_draw_runtime_overlays()
			_draw_units_if_enabled()
		_:
			_draw_continuous_environment()
			if render_mode == RenderMode.REFERENCE:
				_draw_reference_grid()
			_draw_obstacle_volumes()
			_draw_front_cliffs()
			if render_mode == RenderMode.DEBUG:
				_draw_debug_overlay()


func _draw_continuous_environment() -> void:
	# DISTANT_BACKGROUND : aucune couleur de studio, le ciel remplit le 16:9.
	draw_rect(CANVAS_RECT, COLOR_SKY)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 92), Vector2(1920, 92), Vector2(1920, 360),
		Vector2(0, 410),
	]), COLOR_DISTANT)

	# REAR_MOUNTAINS : masses continues coupees par l'acces du col.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 390), Vector2(0, 165), Vector2(170, 280),
		Vector2(340, 118), Vector2(520, 286), Vector2(690, 150),
		Vector2(820, 334), Vector2(820, 420),
	]), COLOR_MOUNTAIN)
	draw_colored_polygon(PackedVector2Array([
		Vector2(1100, 410), Vector2(1100, 320), Vector2(1260, 145),
		Vector2(1400, 285), Vector2(1580, 105), Vector2(1750, 270),
		Vector2(1920, 155), Vector2(1920, 430),
	]), COLOR_MOUNTAIN)
	draw_colored_polygon(PackedVector2Array([
		Vector2(40, 348), Vector2(170, 268), Vector2(340, 135),
		Vector2(505, 292), Vector2(680, 170), Vector2(800, 338),
		Vector2(800, 370), Vector2(40, 405),
	]), COLOR_MOUNTAIN_SNOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(1120, 350), Vector2(1260, 165), Vector2(1400, 302),
		Vector2(1580, 125), Vector2(1748, 288), Vector2(1920, 178),
		Vector2(1920, 385), Vector2(1120, 390),
	]), COLOR_MOUNTAIN_SNOW)

	# REAR_CLIFFS et NON_PLAYABLE_SNOW encadrent la route sans enceinte.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 375), Vector2(330, 330), Vector2(650, 390),
		Vector2(790, 474), Vector2(595, 530), Vector2(275, 505),
		Vector2(0, 600),
	]), COLOR_REAR_CLIFF)
	draw_colored_polygon(PackedVector2Array([
		Vector2(1920, 365), Vector2(1600, 325), Vector2(1330, 378),
		Vector2(1160, 460), Vector2(1335, 520), Vector2(1645, 500),
		Vector2(1920, 585),
	]), COLOR_REAR_CLIFF)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 505), Vector2(340, 430), Vector2(665, 500),
		Vector2(780, 620), Vector2(650, 820), Vector2(320, 955),
		Vector2(0, 935),
	]), COLOR_NON_PLAYABLE_SNOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(1920, 490), Vector2(1600, 425), Vector2(1300, 495),
		Vector2(1160, 610), Vector2(1290, 815), Vector2(1600, 945),
		Vector2(1920, 925),
	]), COLOR_NON_PLAYABLE_SNOW)
	draw_rect(Rect2(0, 850, 1920, 230), Color("dbe4e8"))

	_draw_road_approaches()
	_draw_void_landscape()
	_draw_walkable_cells()
	_draw_cliff_transitions()


func _draw_road_approaches() -> void:
	# OLD_ROAD entre par le bas-gauche et ressort par le haut-droit.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 815), Vector2(0, 900), Vector2(360, 780),
		Vector2(610, 690), Vector2(725, 615), Vector2(645, 560),
		Vector2(500, 630), Vector2(260, 720),
	]), COLOR_ROAD)
	draw_colored_polygon(PackedVector2Array([
		Vector2(1260, 520), Vector2(1400, 445), Vector2(1610, 368),
		Vector2(1920, 300), Vector2(1920, 375), Vector2(1650, 430),
		Vector2(1440, 505), Vector2(1330, 570),
	]), COLOR_ROAD)


func _draw_void_landscape() -> void:
	# VOID_RAVINES : une masse continue par groupe de X, jamais une face
	# superieure en losange. Les cellules restent uniquement logiques.
	var groups := get_void_visual_groups()
	for group_index in range(groups.size()):
		var group: Array[Vector2i] = groups[group_index]
		var hull := _footprint_hull(group)
		if hull.is_empty():
			continue
		var center := _polygon_centroid(hull)
		var ravine := PackedVector2Array()
		for point_index in range(hull.size()):
			var factor := 1.08 + 0.035 * float(point_index % 2)
			ravine.append(center + (hull[point_index] - center) * factor)
		var color := COLOR_RAVINE_DEEP if group_index % 2 == 0 else COLOR_RAVINE
		draw_colored_polygon(ravine, color)
		var depth := PackedVector2Array()
		for point in ravine:
			depth.append(center + (point - center) * 0.67 + Vector2(0, 7))
		draw_colored_polygon(depth, color.darkened(0.16))
		_draw_outline(depth, color.lightened(0.08), 1.5)


func _draw_cliff_transitions() -> void:
	# Une pente/falaise technique couvre chaque arête PLATFORME -> VOID.
	# Elle s'enfonce partiellement dans le ravin et ne ferme jamais le losange X.
	var edges := get_platform_void_edges()
	edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _edge_midpoint(a).y < _edge_midpoint(b).y
	)
	for edge in edges:
		var face := get_cliff_transition_polygon(edge)
		var direction: Vector2i = edge["direction"]
		var color := COLOR_FRONT_CLIFF if direction in [Vector2i.RIGHT, Vector2i.DOWN] else COLOR_REAR_CLIFF
		draw_colored_polygon(face, color)
		var shared := _edge_points(edge["cell"], direction)
		draw_line(shared[0], shared[1], color.lightened(0.28), 2.0, true)
		var inner_a := shared[0].lerp(face[3], 0.76)
		var inner_b := shared[1].lerp(face[2], 0.76)
		draw_line(inner_a, inner_b, color.darkened(0.16), 1.5, true)


func _draw_walkable_cells() -> void:
	for cell in _sorted_cells(_all_logical_cells()):
		var symbol := blockout_data.symbol_at(cell)
		if symbol == MountainPassBlockoutData.VOID:
			continue
		var color := COLOR_WALKABLE_SNOW
		if symbol == MountainPassBlockoutData.ICE:
			color = COLOR_ICE
		elif blockout_data.is_road_cell(cell):
			color = COLOR_ROAD
		draw_colored_polygon(get_cell_polygon(cell), color)


func _draw_obstacle_volumes() -> void:
	# Un volume bas par composante logique : 1x1, 1x2 ou ruine 2x2.
	var groups := get_obstacle_visual_groups()
	groups.sort_custom(func(a: Array, b: Array) -> bool:
		return _group_depth(a) < _group_depth(b)
	)
	for group in groups:
		var ruin := blockout_data.symbol_at(group[0]) == MountainPassBlockoutData.LANDMARK
		var height := 14.0 if ruin else (12.0 if group.size() == 2 else 10.0)
		_draw_low_volume(
			group,
			COLOR_RUIN if ruin else COLOR_BLOCKED_ROCK,
			COLOR_RUIN.darkened(0.24) if ruin else COLOR_BLOCKED_ROCK.darkened(0.22),
			height,
			ruin
		)


func _draw_low_volume(
	group: Array,
	top_color: Color,
	side_color: Color,
	height: float,
	ruin: bool
) -> void:
	var hull := _footprint_hull(group)
	if hull.is_empty():
		return
	var center := _polygon_centroid(hull)
	var inset_factor := 0.84 if group.size() >= 4 else (0.80 if group.size() == 2 else 0.72)
	var base := PackedVector2Array()
	var top := PackedVector2Array()
	for point in hull:
		var inset := center + (point - center) * inset_factor
		base.append(inset)
		top.append(center + (inset - center) * 0.96 + Vector2(0, -height))
	for index in range(base.size()):
		var next := (index + 1) % base.size()
		draw_colored_polygon(PackedVector2Array([
			base[index], base[next], top[next], top[index],
		]), side_color)
	draw_colored_polygon(top, top_color)
	_draw_outline(base, side_color.darkened(0.18), 1.5)
	_draw_outline(top, top_color.lightened(0.28), 2.0)
	if ruin:
		# Deux cassures sur le sommet, sans subdiviser le volume 2x2.
		draw_line(center + Vector2(-56, -height - 5), center + Vector2(8, -height - 5), top_color.lightened(0.30), 5.0, true)
		draw_line(center + Vector2(8, -height - 5), center + Vector2(43, -height + 2), top_color.lightened(0.30), 5.0, true)


func _draw_front_cliffs() -> void:
	# FRONT_CLIFFS : masses de bord reliees au paysage, hors bounds logiques.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 905), Vector2(250, 925), Vector2(430, 875),
		Vector2(520, 930), Vector2(405, 1080), Vector2(0, 1080),
	]), COLOR_FRONT_CLIFF)
	draw_colored_polygon(PackedVector2Array([
		Vector2(1920, 900), Vector2(1680, 925), Vector2(1510, 875),
		Vector2(1425, 940), Vector2(1540, 1080), Vector2(1920, 1080),
	]), COLOR_FRONT_CLIFF)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 900), Vector2(245, 914), Vector2(410, 870),
		Vector2(475, 910), Vector2(360, 950), Vector2(0, 965),
	]), COLOR_MOUNTAIN_SNOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(1920, 895), Vector2(1680, 914), Vector2(1525, 870),
		Vector2(1460, 915), Vector2(1570, 950), Vector2(1920, 960),
	]), COLOR_MOUNTAIN_SNOW)


func _draw_reference_grid() -> void:
	for cell in get_reference_grid_cells():
		_draw_outline(get_cell_polygon(cell), COLOR_GRID, 1.0)


func _draw_logic_blueprint() -> void:
	draw_rect(CANVAS_RECT, Color("d6e2e8"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 390), Vector2(340, 140), Vector2(690, 370),
		Vector2(960, 250), Vector2(1260, 370), Vector2(1590, 130),
		Vector2(1920, 385), Vector2(1920, 1080), Vector2(0, 1080),
	]), Color("b9c8d0"))
	for cell in _sorted_cells(_all_logical_cells()):
		var symbol := blockout_data.symbol_at(cell)
		draw_colored_polygon(get_cell_polygon(cell), LOGIC_COLORS[symbol])
		_draw_outline(get_cell_polygon(cell), COLOR_GRID_STRONG, 1.0)
		draw_circle(grid_to_local(cell), 2.4, COLOR_GRID_STRONG)
	for group in get_obstacle_visual_groups():
		_draw_outline(_footprint_hull(group), Color(0.08, 0.12, 0.16, 0.82), 2.5)


func _draw_foreground_guide() -> void:
	# FOREGROUND_OCCLUSION_GUIDE : zones pixel-alignees, toutes sous y=900,
	# donc hors des bounds de la grille (bas exact y=880).
	for polygon in _foreground_polygons():
		draw_colored_polygon(polygon, COLOR_FOREGROUND_GUIDE)
		_draw_outline(polygon, COLOR_FOREGROUND_GUIDE.lightened(0.18), 2.0)


func _draw_debug_overlay() -> void:
	var font := ThemeDB.fallback_font
	for cell in _all_logical_cells():
		var symbol := blockout_data.symbol_at(cell)
		var overlay: Color = LOGIC_COLORS[symbol]
		overlay.a = 0.42 if symbol != MountainPassBlockoutData.VOID else 0.66
		draw_colored_polygon(get_cell_polygon(cell), overlay)
		_draw_outline(get_cell_polygon(cell), COLOR_GRID_STRONG, 1.0)
		var center := grid_to_local(cell)
		draw_circle(center, 2.8, Color("14242d"))
		draw_string(
			font,
			center + Vector2(-24, -6),
			"%d,%d %s" % [cell.x, cell.y, symbol],
			HORIZONTAL_ALIGNMENT_CENTER,
			48,
			10,
			Color("14242d")
		)
	draw_rect(get_logical_bounds(), Color("e43c92"), false, 3.0)
	draw_rect(SCENE_USEFUL_BOUNDS, Color("21a87d"), false, 3.0)
	draw_circle(grid_origin, 7.0, Color("ffd14d"))
	_draw_arrow(grid_origin, grid_origin + axis_x * 2.0, Color("ed9136"))
	_draw_arrow(grid_origin, grid_origin + axis_y * 2.0, Color("43aee5"))
	draw_string(font, grid_origin + Vector2(12, -10), "ORIGIN 960,232", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("14242d"))
	draw_string(font, grid_origin + axis_x * 2.0 + Vector2(8, -4), "axis_x 48,24", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("7d4210"))
	draw_string(font, grid_origin + axis_y * 2.0 + Vector2(-104, -4), "axis_y -48,24", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("155a7b"))
	draw_string(font, Vector2(300, 196), "GRID BOUNDS 288,208 1344x672", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("8b1454"))
	draw_string(font, Vector2(36, 96), "SCENE USEFUL 24,72 1872x984", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("126b52"))


func _draw_grid_overlay(show_terrain: bool) -> void:
	for cell in _all_logical_cells():
		var symbol := blockout_data.symbol_at(cell)
		if not show_terrain and symbol == MountainPassBlockoutData.VOID:
			continue
		var polygon := get_cell_polygon(cell)
		if show_terrain:
			var overlay: Color = LOGIC_COLORS[symbol]
			overlay.a = 0.34
			draw_colored_polygon(polygon, overlay)
		_draw_outline(polygon, COLOR_GRID, 1.0)


func _draw_runtime_overlays() -> void:
	for cell in _highlights:
		draw_colored_polygon(get_cell_polygon(cell), _highlights[cell])
	if _is_logical_cell(_selected_cell):
		_draw_outline(get_cell_polygon(_selected_cell), Color("ffc44d"), 3.0)
	if _is_logical_cell(_hovered_cell):
		_draw_outline(get_cell_polygon(_hovered_cell), Color("72e6ff"), 2.0)


func _draw_units_if_enabled() -> void:
	if not show_unit_preview:
		return
	var ally_cells := blockout_data.ally_spawn_cells()
	var enemy_cells := blockout_data.enemy_spawn_cells()
	for index in range(mini(3, ally_cells.size())):
		_draw_unit_silhouette(ally_cells[index], Color("3c8fd9"))
	for index in range(mini(3, enemy_cells.size())):
		_draw_unit_silhouette(enemy_cells[index], Color("c8534f"))


func _draw_unit_silhouette(cell: Vector2i, color: Color) -> void:
	var feet := grid_to_local(cell)
	_draw_ellipse_shape(feet + Vector2(0, -2), Vector2(21, 7), Color(0.05, 0.08, 0.10, 0.34))
	draw_colored_polygon(PackedVector2Array([
		feet + Vector2(-16, -2), feet + Vector2(-12, -39),
		feet + Vector2(-7, -58), feet + Vector2(0, -65),
		feet + Vector2(7, -58), feet + Vector2(12, -39),
		feet + Vector2(16, -2),
	]), color)
	draw_circle(feet + Vector2(0, -70), 9.0, color.lightened(0.12))


func get_reference_grid_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _all_logical_cells():
		if blockout_data.symbol_at(cell) != MountainPassBlockoutData.VOID:
			result.append(cell)
	return result


func get_platform_void_edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell in get_reference_grid_cells():
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var neighbor: Vector2i = cell + direction
			if not _is_logical_cell(neighbor):
				continue
			if blockout_data.symbol_at(neighbor) == MountainPassBlockoutData.VOID:
				result.append({
					"cell": cell,
					"void_cell": neighbor,
					"direction": direction,
				})
	return result


func get_cliff_transition_polygon(edge: Dictionary) -> PackedVector2Array:
	var direction: Vector2i = edge["direction"]
	var shared := _edge_points(edge["cell"], direction)
	var into_void := _direction_to_screen(direction) * 0.46
	return PackedVector2Array([
		shared[0], shared[1], shared[1] + into_void, shared[0] + into_void,
	])


func get_void_visual_groups() -> Array:
	var remaining := {}
	for cell in blockout_data.void_cells():
		remaining[cell] = true
	var groups: Array = []
	while not remaining.is_empty():
		var seed: Vector2i = remaining.keys()[0]
		var group: Array[Vector2i] = []
		var frontier: Array[Vector2i] = [seed]
		remaining.erase(seed)
		while not frontier.is_empty():
			var current: Vector2i = frontier.pop_front()
			group.append(current)
			for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				var neighbor: Vector2i = current + direction
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					frontier.append(neighbor)
		groups.append(group)
	return groups


func get_obstacle_visual_groups() -> Array:
	return blockout_data.obstacle_groups()


func _edge_points(cell: Vector2i, direction: Vector2i) -> PackedVector2Array:
	var polygon := get_cell_polygon(cell)
	match direction:
		Vector2i.UP:
			return PackedVector2Array([polygon[0], polygon[1]])
		Vector2i.RIGHT:
			return PackedVector2Array([polygon[1], polygon[2]])
		Vector2i.DOWN:
			return PackedVector2Array([polygon[2], polygon[3]])
		_:
			return PackedVector2Array([polygon[3], polygon[0]])


func _edge_midpoint(edge: Dictionary) -> Vector2:
	var points := _edge_points(edge["cell"], edge["direction"])
	return (points[0] + points[1]) * 0.5


func _direction_to_screen(direction: Vector2i) -> Vector2:
	match direction:
		Vector2i.UP:
			return -axis_y
		Vector2i.RIGHT:
			return axis_x
		Vector2i.DOWN:
			return axis_y
		_:
			return -axis_x


func _footprint_hull(group: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for cell in group:
		points.append_array(get_cell_polygon(cell))
	if points.is_empty():
		return points
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.resize(hull.size() - 1)
	return hull


func _polygon_centroid(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var result := Vector2.ZERO
	for point in polygon:
		result += point
	return result / float(polygon.size())


func _group_depth(group: Array) -> float:
	var result := -INF
	for cell in group:
		result = maxf(result, grid_to_local(cell).y)
	return result


func _all_logical_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if blockout_data == null:
		return result
	for y in range(blockout_data.logical_size.y):
		for x in range(blockout_data.logical_size.x):
			result.append(Vector2i(x, y))
	return result


func _sorted_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result := cells.duplicate()
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var point_a := grid_to_local(a)
		var point_b := grid_to_local(b)
		return point_a.x < point_b.x if is_equal_approx(point_a.y, point_b.y) else point_a.y < point_b.y
	)
	return result


func _foreground_polygons() -> Array[PackedVector2Array]:
	return [
		PackedVector2Array([
			Vector2(0, 930), Vector2(90, 897), Vector2(205, 920),
			Vector2(295, 1005), Vector2(270, 1080), Vector2(0, 1080),
		]),
		PackedVector2Array([
			Vector2(1920, 925), Vector2(1825, 897), Vector2(1710, 925),
			Vector2(1625, 1010), Vector2(1650, 1080), Vector2(1920, 1080),
		]),
	]


func _bounds_for_cells(cells: Array[Vector2i]) -> Rect2:
	if cells.is_empty():
		return Rect2(grid_origin, Vector2.ZERO)
	var minimum := get_cell_polygon(cells[0])[0]
	var maximum := minimum
	for cell in cells:
		for point in get_cell_polygon(cell):
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _valid_cell_at(local_position: Vector2) -> Vector2i:
	var candidate := local_to_grid(local_position)
	return candidate if _is_interactable(candidate) else INVALID_CELL


func _is_interactable(cell: Vector2i) -> bool:
	if grid != null:
		return grid.is_terrain_interactable(cell)
	if not _is_logical_cell(cell):
		return false
	return blockout_data.symbol_at(cell) in [
		MountainPassBlockoutData.NORMAL,
		MountainPassBlockoutData.ICE,
		MountainPassBlockoutData.ALLY_SPAWN,
		MountainPassBlockoutData.ENEMY_SPAWN,
	]


func _is_logical_cell(cell: Vector2i) -> bool:
	return blockout_data != null \
		and cell.x >= 0 and cell.y >= 0 \
		and cell.x < blockout_data.logical_size.x \
		and cell.y < blockout_data.logical_size.y


func _draw_outline(polygon: PackedVector2Array, color: Color, width: float) -> void:
	if polygon.is_empty():
		return
	var closed := PackedVector2Array(polygon)
	closed.append(polygon[0])
	draw_polyline(closed, color, width, true)


func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, color, 4.0)
	var direction := (to - from).normalized()
	var normal := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([
		to,
		to - direction * 15.0 + normal * 7.0,
		to - direction * 15.0 - normal * 7.0,
	]), color)


func _draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color, segments: int = 28) -> void:
	var polygon := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		polygon.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(polygon, color)
