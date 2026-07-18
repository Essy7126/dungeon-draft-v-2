extends Node2D

## Laboratoire de calibration non destructif de la premiere carte foret.
## Cette transformation a ete validee sur une capture runtime Godot 4.6.3.

const GRID_SIZE := Vector2i(10, 8)
const CONTROL_CELLS := [
	Vector2i(0, 0),
	Vector2i(9, 0),
	Vector2i(0, 7),
	Vector2i(9, 7),
	Vector2i(5, 4),
	Vector2i(4, 0),
	Vector2i(4, 7),
	Vector2i(0, 3),
	Vector2i(9, 3),
]
@export_range(0.0, 1.0, 0.05) var background_opacity := 1.0
@export var provisional_calibration := false

@onready var forest_sprite: Sprite2D = $ForestBackground/ForestSprite
@onready var grid_view: IsoGridView = $IsoGridView
@onready var markers: Node2D = $YSortedWorld/ControlMarkers
@onready var calibration_overlay: Node2D = $CalibrationOverlay
@onready var camera: Camera2D = $Camera2D
@onready var status_label: Label = $UI/Panel/Margin/VBox/Status
@onready var mode_label: Label = $UI/Panel/Margin/VBox/Mode

var _mode := 0
var _marker_cell := Vector2i(4, 3)
var _grid_visible := true
var _initial_background_position := Vector2.ZERO
var _initial_background_scale := Vector2.ONE
var _initial_background_rotation_degrees := 0.0


func _ready() -> void:
	_initial_background_position = forest_sprite.position
	_initial_background_scale = forest_sprite.scale
	_initial_background_rotation_degrees = forest_sprite.rotation_degrees
	grid_view.setup(GridData.new(GRID_SIZE.x, GRID_SIZE.y))
	grid_view.set_render_options(false, true, true, true)
	_apply_background_opacity()
	_build_control_overlay()
	_build_markers()
	_refresh_ui()
	call_deferred("_fit_camera")
	if not get_viewport().size_changed.is_connected(_fit_camera):
		get_viewport().size_changed.connect(_fit_camera)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var changed := false
	match event.keycode:
		KEY_F1:
			_mode = (_mode + 1) % 2
			changed = true
		KEY_G:
			_grid_visible = not _grid_visible
			grid_view.set_render_options(false, _grid_visible, _grid_visible, _grid_visible)
			changed = true
		KEY_H:
			forest_sprite.visible = not forest_sprite.visible
			changed = true
		KEY_R:
			_reset_calibration()
			changed = true
		KEY_MINUS:
			background_opacity = clampf(background_opacity - 0.05, 0.0, 1.0)
			changed = true
		KEY_EQUAL:
			background_opacity = clampf(background_opacity + 0.05, 0.0, 1.0)
			changed = true
		_:
			changed = _handle_background_key(event) if _mode == 0 else _handle_marker_key(event)
	if changed:
		_apply_background_opacity()
		_update_marker_positions()
		_refresh_ui()
		call_deferred("_fit_camera")


func _handle_background_key(event: InputEventKey) -> bool:
	var move_step := 8.0 if event.shift_pressed else 1.0
	var scale_step := 0.01 if event.shift_pressed else 0.001
	var rotation_step := 1.0 if event.shift_pressed else 0.1
	match event.keycode:
		KEY_I: forest_sprite.position.y -= move_step
		KEY_K: forest_sprite.position.y += move_step
		KEY_J: forest_sprite.position.x -= move_step
		KEY_L: forest_sprite.position.x += move_step
		KEY_Q: forest_sprite.scale.x = maxf(0.05, forest_sprite.scale.x - scale_step)
		KEY_E: forest_sprite.scale.x += scale_step
		KEY_Z: forest_sprite.scale.y = maxf(0.05, forest_sprite.scale.y - scale_step)
		KEY_C: forest_sprite.scale.y += scale_step
		KEY_U: forest_sprite.rotation_degrees -= rotation_step
		KEY_O: forest_sprite.rotation_degrees += rotation_step
		_: return false
	return true


func _handle_marker_key(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_LEFT: _marker_cell.x -= 1
		KEY_RIGHT: _marker_cell.x += 1
		KEY_UP: _marker_cell.y -= 1
		KEY_DOWN: _marker_cell.y += 1
		_: return false
	_marker_cell.x = clampi(_marker_cell.x, 0, GRID_SIZE.x - 1)
	_marker_cell.y = clampi(_marker_cell.y, 0, GRID_SIZE.y - 1)
	return true


func _reset_calibration() -> void:
	forest_sprite.position = _initial_background_position
	forest_sprite.scale = _initial_background_scale
	forest_sprite.rotation_degrees = _initial_background_rotation_degrees
	background_opacity = 1.0
	_marker_cell = Vector2i(4, 3)
	forest_sprite.visible = true


func _apply_background_opacity() -> void:
	if not is_instance_valid(forest_sprite):
		return
	forest_sprite.modulate.a = background_opacity


func _build_control_overlay() -> void:
	for cell in CONTROL_CELLS:
		var outline := Line2D.new()
		outline.name = "Cell_%d_%d" % [cell.x, cell.y]
		outline.width = 2.5
		outline.default_color = Color(1.0, 0.3, 0.75, 0.95)
		outline.closed = true
		outline.points = grid_view.get_cell_polygon(cell)
		calibration_overlay.add_child(outline)


func _build_markers() -> void:
	for cell in CONTROL_CELLS:
		var marker := Polygon2D.new()
		marker.name = "Marker_%d_%d" % [cell.x, cell.y]
		marker.polygon = PackedVector2Array([
			Vector2(0.0, -6.0), Vector2(8.0, 0.0),
			Vector2(0.0, 6.0), Vector2(-8.0, 0.0),
		])
		marker.color = Color(1.0, 0.82, 0.18, 0.95)
		marker.set_meta("grid_cell", cell)
		markers.add_child(marker)
	var movable := Polygon2D.new()
	movable.name = "MovableMarker"
	movable.polygon = PackedVector2Array([
		Vector2(0.0, -9.0), Vector2(11.0, 0.0),
		Vector2(0.0, 9.0), Vector2(-11.0, 0.0),
	])
	movable.color = Color(0.2, 1.0, 0.75, 1.0)
	movable.set_meta("movable", true)
	markers.add_child(movable)
	_update_marker_positions()


func _update_marker_positions() -> void:
	if not is_instance_valid(markers) or not is_instance_valid(grid_view):
		return
	for marker in markers.get_children():
		if marker.has_meta("movable"):
			marker.position = grid_view.grid_to_local(_marker_cell)
		else:
			marker.position = grid_view.grid_to_local(marker.get_meta("grid_cell"))


func _fit_camera() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(grid_view):
		return
	var frame_rect := grid_view.get_map_bounds()
	if forest_sprite.texture != null:
		frame_rect = frame_rect.merge(_rect_in_lab(forest_sprite, forest_sprite.get_rect()))
	camera.position = frame_rect.get_center()
	var viewport_size := get_viewport_rect().size
	var zoom_factor := minf(
		viewport_size.x / frame_rect.size.x,
		viewport_size.y / frame_rect.size.y
	) * 0.9
	camera.zoom = Vector2(zoom_factor, zoom_factor)
	camera.make_current()


func _rect_in_lab(source: Node2D, rect: Rect2) -> Rect2:
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.end,
		rect.position + Vector2(0.0, rect.size.y),
	]
	var first := to_local(source.to_global(corners[0]))
	var minimum := first
	var maximum := first
	for corner in corners.slice(1):
		var converted := to_local(source.to_global(corner))
		minimum = minimum.min(converted)
		maximum = maximum.max(converted)
	return Rect2(minimum, maximum - minimum)


func _refresh_ui() -> void:
	if not is_instance_valid(status_label):
		return
	var calibration_state := "PROVISOIRE" if provisional_calibration else "VALIDEE"
	mode_label.text = "Mode F1 : %s" % ("fond" if _mode == 0 else "marqueur")
	status_label.text = (
		"Calibration %s\nposition=%s  scale=%s\nrotation=%.2f deg  opacite=%.2f\n"
		+ "marqueur=%s  grille=%s  fond=%s"
	) % [
		calibration_state,
		forest_sprite.position,
		forest_sprite.scale,
		forest_sprite.rotation_degrees,
		background_opacity,
		_marker_cell,
		_grid_visible,
		forest_sprite.visible,
	]
