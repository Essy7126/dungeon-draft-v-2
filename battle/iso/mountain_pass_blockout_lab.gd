@tool
extends Node2D

## Laboratoire de calibration non destructif du blockout.
## F1 alterne reference/debug, M parcourt tous les modes, U affiche les pivots
## d'unites, et G masque/affiche la grille via les modes clean/reference.

@onready var view: MountainPassBlockoutView = $IsoGridView
@onready var camera: Camera2D = $Camera2D
@onready var status_label: Label = $DebugUI/Panel/Margin/VBox/Status
@onready var help_label: Label = $DebugUI/Panel/Margin/VBox/Help

var _grid: GridData = null


func _ready() -> void:
	if view.blockout_data == null:
		view.blockout_data = load("res://data/maps/mountain_pass_blockout.tres")
	_grid = GridData.new(
		view.blockout_data.logical_size.x,
		view.blockout_data.logical_size.y
	)
	view.blockout_data.apply_to_grid(_grid)
	view.setup(_grid)
	if not Engine.is_editor_hint():
		camera.make_current()
		if not get_viewport().size_changed.is_connected(_fit_camera):
			get_viewport().size_changed.connect(_fit_camera)
		call_deferred("_fit_camera")
	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			view.render_mode = (
				MountainPassBlockoutView.RenderMode.REFERENCE
				if view.render_mode == MountainPassBlockoutView.RenderMode.DEBUG
				else MountainPassBlockoutView.RenderMode.DEBUG
			)
		KEY_M:
			view.render_mode = (view.render_mode + 1) % MountainPassBlockoutView.RenderMode.size()
		KEY_G:
			view.render_mode = (
				MountainPassBlockoutView.RenderMode.CLEAN
				if view.render_mode == MountainPassBlockoutView.RenderMode.REFERENCE
				else MountainPassBlockoutView.RenderMode.REFERENCE
			)
		KEY_U:
			view.show_unit_preview = not view.show_unit_preview
		_:
			return
	_refresh_ui()


func _fit_camera() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(view):
		return
	var frame := view.get_map_bounds()
	var viewport_size := get_viewport_rect().size
	if frame.size.x <= 0.0 or frame.size.y <= 0.0 \
			or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	camera.position = frame.get_center() + view.camera_offset
	var fit := minf(viewport_size.x / frame.size.x, viewport_size.y / frame.size.y) * 0.96
	camera.zoom = Vector2(fit, fit) * view.camera_zoom
	_refresh_ui()


func _refresh_ui() -> void:
	if not is_instance_valid(status_label) or view.blockout_data == null:
		return
	var data := view.blockout_data
	var counts := data.layout_counts()
	status_label.text = (
		"mode=%s  origine=%s\naxis_x=%s  axis_y=%s  scale=%.2f\n"
		+ "plateforme=%s  falaises=%d\n"
		+ "walkable=%d  blocked=%d  void=%d  ICE=%d  A=%d  E=%d\n"
		+ "camera zoom=%s offset=%s  unites=%s"
	) % [
		MountainPassBlockoutView.RenderMode.keys()[view.render_mode],
		view.grid_origin,
		view.axis_x,
		view.axis_y,
		view.preview_scale,
		view.get_platform_bounds(),
		view._cliff_edges().size(),
		data.walkable_cells().size(),
		data.blocked_cells().size(),
		data.void_cells().size(),
		counts[MountainPassBlockoutData.ICE],
		counts[MountainPassBlockoutData.ALLY_SPAWN],
		counts[MountainPassBlockoutData.ENEMY_SPAWN],
		view.camera_zoom,
		view.camera_offset,
		"ON" if view.show_unit_preview else "OFF",
	]
	help_label.text = "F1 reference/debug | M modes | G grille | U silhouettes | clic/survol actifs"

