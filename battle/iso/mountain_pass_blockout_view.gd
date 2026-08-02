@tool
class_name MountainPassBlockoutView
extends Node2D

signal cell_hovered(grid_pos: Vector2i)
signal cell_clicked(grid_pos: Vector2i)

enum RenderMode { REFERENCE, CLEAN, DEBUG, LOGIC_MASK, HEIGHT_GUIDE }
const INVALID_CELL := Vector2i(-1, -1)
const CANVAS_SIZE := Vector2(2048, 2048)
const MODE_TEXTURES := [
	preload("res://artifacts/maps/mountain_pass_blockout/mountain_pass_blockout_reference.png"),
	preload("res://artifacts/maps/mountain_pass_blockout/mountain_pass_blockout_clean.png"),
	preload("res://artifacts/maps/mountain_pass_blockout/mountain_pass_blockout_debug.png"),
	preload("res://artifacts/maps/mountain_pass_blockout/mountain_pass_blockout_logic_mask.png"),
	preload("res://artifacts/maps/mountain_pass_blockout/mountain_pass_blockout_height_guide.png"),
]

@export var blockout_data: MountainPassBlockoutData:
	set(value): blockout_data=value;queue_redraw()
@export var render_mode := RenderMode.REFERENCE:
	set(value): render_mode=clampi(value,0,RenderMode.size()-1);queue_redraw()
@export_group("Calibration")
@export var grid_origin := Vector2(1024,650):
	set(value): grid_origin=value;queue_redraw()
@export_range(0.1,2.0,0.01) var preview_scale := 0.75
@export var axis_x := Vector2(48,24):
	set(value): axis_x=value;queue_redraw()
@export var axis_y := Vector2(-48,24):
	set(value): axis_y=value;queue_redraw()
@export_range(0.0,160.0,1.0) var cliff_depth := 58.0
@export_range(0.0,100.0,1.0) var obstacle_height := 34.0
@export_range(0.0,120.0,1.0) var landmark_height := 50.0
@export var camera_zoom := Vector2.ONE
@export var camera_offset := Vector2.ZERO
@export_group("Debug")
@export var show_calibration_overlay := false:
	set(value): show_calibration_overlay=value;queue_redraw()

var grid: GridData = null
var _hovered_cell := INVALID_CELL
var _selected_cell := INVALID_CELL
var _highlights: Dictionary = {}

func _ready() -> void: queue_redraw()

func setup(grid_data: GridData) -> void:
	grid=grid_data;_hovered_cell=INVALID_CELL;_selected_cell=INVALID_CELL;_highlights.clear();queue_redraw()

func grid_to_local(cell: Vector2i) -> Vector2:
	return grid_origin+float(cell.x)*axis_x+float(cell.y)*axis_y

func grid_to_world(cell: Vector2i) -> Vector2: return grid_to_local(cell)

func local_to_grid(point: Vector2) -> Vector2i:
	var local:=point-grid_origin
	var determinant:=axis_x.x*axis_y.y-axis_y.x*axis_x.y
	if is_zero_approx(determinant): return INVALID_CELL
	return Vector2i(roundi((local.x*axis_y.y-axis_y.x*local.y)/determinant),roundi((axis_x.x*local.y-local.x*axis_x.y)/determinant))

func world_to_grid(point: Vector2) -> Vector2i: return local_to_grid(point)

func get_cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var center:=grid_to_local(cell)
	var half_width:=absf(axis_x.x-axis_y.x)*0.5
	var half_height:=absf(axis_x.y+axis_y.y)*0.5
	return PackedVector2Array([center+Vector2(0,-half_height),center+Vector2(half_width,0),center+Vector2(0,half_height),center+Vector2(-half_width,0)])

func get_map_bounds() -> Rect2: return Rect2(Vector2.ZERO,CANVAS_SIZE)
func get_pixel_size() -> Vector2: return CANVAS_SIZE
func get_hovered_cell() -> Vector2i: return _hovered_cell
func get_selected_cell() -> Vector2i: return _selected_cell

func highlight(cells: Array,color: Color) -> void:
	for cell in cells:
		if cell is Vector2i and _is_logical(cell): _highlights[cell]=color
	queue_redraw()

func clear_highlights() -> void: _highlights.clear();queue_redraw()
func set_selected_cell(cell: Vector2i) -> void:
	if _is_interactable(cell): _selected_cell=cell;queue_redraw()
func clear_selection() -> void: _selected_cell=INVALID_CELL;queue_redraw()

func update_hover(point: Vector2) -> Vector2i:
	var cell:=_valid_cell_at(point)
	if cell!=_hovered_cell: _hovered_cell=cell;queue_redraw();cell_hovered.emit(cell)
	return cell

func click_at(point: Vector2) -> Vector2i:
	var cell:=_valid_cell_at(point)
	if cell!=INVALID_CELL: set_selected_cell(cell);cell_clicked.emit(cell)
	return cell

func _unhandled_input(event: InputEvent) -> void:
	if grid==null:return
	if event is InputEventMouseMotion:update_hover(get_local_mouse_position())
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:click_at(get_local_mouse_position())

func _draw() -> void:
	var texture: Texture2D=MODE_TEXTURES[render_mode]
	draw_texture_rect(texture,Rect2(Vector2.ZERO,CANVAS_SIZE),false)
	for cell in _highlights: draw_colored_polygon(get_cell_polygon(cell),_highlights[cell])
	if _is_logical(_selected_cell): _outline(get_cell_polygon(_selected_cell),Color("ffc44d"),3.0)
	if _is_logical(_hovered_cell): _outline(get_cell_polygon(_hovered_cell),Color("72e6ff"),2.0)
	if show_calibration_overlay:_draw_calibration()

func _draw_calibration() -> void:
	if blockout_data==null:return
	var font:=ThemeDB.fallback_font
	for y in range(blockout_data.logical_size.y):
		for x in range(blockout_data.logical_size.x):
			var cell:=Vector2i(x,y);var polygon:=get_cell_polygon(cell);var center:=grid_to_local(cell)
			_outline(polygon,Color(0.95,0.2,0.55,0.62),1.0);draw_circle(center,2.2,Color("15212a"))
			draw_string(font,center+Vector2(-16,-5),"%d,%d"%[x,y],HORIZONTAL_ALIGNMENT_CENTER,32,9,Color("15212a"))
	draw_circle(grid_origin,7.0,Color("ffcf4a"));draw_line(grid_origin,grid_origin+axis_x*2.0,Color("ef9131"),4.0);draw_line(grid_origin,grid_origin+axis_y*2.0,Color("48b8e8"),4.0)

func _valid_cell_at(point: Vector2) -> Vector2i:
	var candidate:=local_to_grid(point)
	return candidate if _is_interactable(candidate) else INVALID_CELL

func _is_interactable(cell: Vector2i) -> bool:
	if grid!=null:return grid.is_terrain_interactable(cell)
	if not _is_logical(cell):return false
	return blockout_data.symbol_at(cell) in [MountainPassBlockoutData.NORMAL,MountainPassBlockoutData.ICE,MountainPassBlockoutData.ALLY_SPAWN,MountainPassBlockoutData.ENEMY_SPAWN]

func _is_logical(cell: Vector2i) -> bool:
	return blockout_data!=null and cell.x>=0 and cell.y>=0 and cell.x<blockout_data.logical_size.x and cell.y<blockout_data.logical_size.y

func _outline(polygon: PackedVector2Array,color: Color,width: float) -> void:
	var closed:=PackedVector2Array(polygon);closed.append(polygon[0]);draw_polyline(closed,color,width,true)
