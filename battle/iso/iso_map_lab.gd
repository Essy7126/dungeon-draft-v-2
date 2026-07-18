class_name IsoMapLab
extends Node2D

const GRID_SIZE := Vector2i(20, 14)
const CAMERA_SAFE_SCALE := 0.90
const INVALID_CELL := Vector2i(-1, -1)

const MARKER_A_START := Vector2i(9, 6)
const MARKER_B_START := Vector2i(10, 6)
const MARKER_C_START := Vector2i(10, 7)

@onready var grid_view: IsoGridView = $IsoGridView
@onready var y_sorted_world: Node2D = $YSortedWorld
@onready var marker_a: Node2D = $YSortedWorld/MarkerA
@onready var marker_b: Node2D = $YSortedWorld/MarkerB
@onready var marker_c: Node2D = $YSortedWorld/MarkerC
@onready var camera: Camera2D = $Camera2D

@onready var hovered_label: Label = $DebugUI/Panel/Margin/VBox/Hovered
@onready var selected_label: Label = $DebugUI/Panel/Margin/VBox/Selected
@onready var marker_label: Label = $DebugUI/Panel/Margin/VBox/Marker
@onready var direction_label: Label = $DebugUI/Panel/Margin/VBox/Direction
@onready var bounds_label: Label = $DebugUI/Panel/Margin/VBox/Bounds
@onready var zoom_label: Label = $DebugUI/Panel/Margin/VBox/Zoom

var grid: GridData = null
var marker_cell := MARKER_A_START
var last_direction := Vector2i.ZERO
var hovered_cell := INVALID_CELL
var selected_cell := INVALID_CELL
var debug_mode_enabled := true


func _ready() -> void:
	grid = GridData.new(GRID_SIZE.x, GRID_SIZE.y)
	grid_view.setup(grid)
	grid_view.cell_hovered.connect(_on_cell_hovered)
	grid_view.cell_clicked.connect(_on_cell_clicked)
	get_viewport().size_changed.connect(_fit_camera)

	_set_marker_cell(marker_a, MARKER_A_START)
	_set_marker_cell(marker_b, MARKER_B_START)
	_set_marker_cell(marker_c, MARKER_C_START)
	marker_cell = MARKER_A_START
	_set_debug_mode(true)
	_fit_camera()
	_update_debug_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if event.keycode == KEY_F1:
		_set_debug_mode(not debug_mode_enabled)
		get_viewport().set_input_as_handled()
		return

	var direction := Vector2i.ZERO
	match event.keycode:
		KEY_RIGHT:
			direction = Vector2i(1, 0)
		KEY_LEFT:
			direction = Vector2i(-1, 0)
		KEY_DOWN:
			direction = Vector2i(0, 1)
		KEY_UP:
			direction = Vector2i(0, -1)

	if direction == Vector2i.ZERO:
		return
	_move_marker(direction)
	get_viewport().set_input_as_handled()


func _move_marker(direction: Vector2i) -> void:
	var destination := marker_cell + direction
	if not grid.is_valid(destination):
		return
	var from_cell := marker_cell
	marker_cell = destination
	last_direction = destination - from_cell
	_set_marker_cell(marker_a, marker_cell)
	_update_debug_ui()


func _set_marker_cell(marker: Node2D, cell: Vector2i) -> void:
	if grid == null or not grid.is_valid(cell):
		return
	var projected_in_grid := grid_view.grid_to_local(cell)
	marker.position = y_sorted_world.to_local(grid_view.to_global(projected_in_grid))


func _fit_camera() -> void:
	if grid_view == null or grid == null:
		return
	var bounds := grid_view.get_map_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	camera.position = to_local(grid_view.to_global(bounds.get_center()))
	var zoom_factor := minf(
		viewport_size.x / bounds.size.x,
		viewport_size.y / bounds.size.y
	) * CAMERA_SAFE_SCALE
	zoom_factor = clampf(zoom_factor, 0.05, 4.0)
	camera.zoom = Vector2(zoom_factor, zoom_factor)
	_update_debug_ui()


func _set_debug_mode(enabled: bool) -> void:
	debug_mode_enabled = enabled
	grid_view.set_debug_draw_enabled(enabled)
	for marker in [marker_a, marker_b, marker_c]:
		marker.get_node("GroundPivot").visible = enabled
	_update_debug_ui()


func _on_cell_hovered(cell: Vector2i) -> void:
	hovered_cell = cell
	_update_debug_ui()


func _on_cell_clicked(cell: Vector2i) -> void:
	selected_cell = cell
	_update_debug_ui()


func _update_debug_ui() -> void:
	if not is_node_ready():
		return
	hovered_label.text = "Survol : %s" % _format_cell(hovered_cell)
	selected_label.text = "Selection : %s" % _format_cell(selected_cell)
	marker_label.text = "Marqueur mobile : %s" % _format_cell(marker_cell)
	direction_label.text = "Direction logique : %s" % str(last_direction)
	var bounds := grid_view.get_map_bounds()
	bounds_label.text = "Bounds : position=%s  taille=%s" % [
		str(bounds.position), str(bounds.size)
	]
	zoom_label.text = "Zoom camera : %.4f  |  debug F1 : %s" % [
		camera.zoom.x, "ON" if debug_mode_enabled else "OFF"
	]


func _format_cell(cell: Vector2i) -> String:
	if cell == INVALID_CELL:
		return "(-, -)"
	return "(%d, %d)" % [cell.x, cell.y]
