@tool
class_name PaintedMapCalibration
extends Node2D

## Laboratoire generique. Assigner une RoomData peinte dans l'inspecteur puis
## utiliser les boutons pour inspecter/capturer la calibration sans lancer un
## combat et sans instancier de second moteur de grille.

@export var room_data: RoomData:
	set(value):
		room_data = value
		_refresh_configuration()

@export_group("Visibilite")
@export var show_image := true:
	set(value):
		show_image = value
		_refresh_visibility()
@export var show_grid := true:
	set(value):
		show_grid = value
		_refresh_visibility()
@export var show_foreground := true:
	set(value):
		show_foreground = value
		_refresh_visibility()
@export var show_terrain := true:
	set(value):
		show_terrain = value
		_refresh_visibility()
@export var show_spawns := true:
	set(value):
		show_spawns = value
		_refresh_visibility()
@export var show_coordinates := true:
	set(value):
		show_coordinates = value
		_refresh_visibility()
@export var export_path := "res://artifacts/maps/painted_run_integration/calibration_tool_capture.png"

@export_tool_button("Afficher/masquer image") var toggle_image_button = _toggle_image
@export_tool_button("Afficher/masquer grille") var toggle_grid_button = _toggle_grid
@export_tool_button("Afficher/masquer foreground") var toggle_foreground_button = _toggle_foreground
@export_tool_button("Afficher/masquer terrains") var toggle_terrain_button = _toggle_terrain
@export_tool_button("Afficher/masquer spawns") var toggle_spawns_button = _toggle_spawns
@export_tool_button("Exporter capture") var export_capture_button = export_capture

var _preview_grid: GridData = null


func _ready() -> void:
	_refresh_configuration()
	call_deferred("_fit_camera")
	if not get_viewport().size_changed.is_connected(_fit_camera):
		get_viewport().size_changed.connect(_fit_camera)


func _refresh_configuration() -> void:
	if not is_inside_tree():
		return
	var background := get_node_or_null("PaintedBackground/BackgroundSprite") as Sprite2D
	var foreground := get_node_or_null("PaintedForeground/ForegroundSprite") as Sprite2D
	var view := get_node_or_null("IsoGridView") as PaintedGridView
	if room_data == null \
			or room_data.grid_layout == null \
			or room_data.painted_map_visual_data == null:
		if background != null:
			background.texture = null
		if foreground != null:
			foreground.texture = null
		return
	var visual := room_data.painted_map_visual_data
	if background != null:
		background.texture = visual.load_background_texture()
		background.centered = false
		background.position = visual.image_offset
		background.scale = visual.image_scale
	if foreground != null:
		foreground.texture = visual.load_foreground_texture()
		foreground.centered = false
		foreground.position = visual.foreground_offset
		foreground.scale = visual.foreground_scale
	var world := get_node_or_null("YSortedWorld") as Node2D
	if world != null:
		for child in world.get_children():
			if child.is_in_group("painted_foreground_occluders"):
				child.queue_free()
		var occluder := visual.create_foreground_occluder(
			background.texture if background != null else null
		)
		if occluder != null:
			world.add_child(occluder)
	_preview_grid = GridData.new(
		room_data.grid_layout.logical_size.x,
		room_data.grid_layout.logical_size.y
	)
	room_data.grid_layout.apply_to_grid(_preview_grid)
	if view != null:
		view.configure(
			visual,
			room_data.grid_layout,
			room_data.hero_spawn_zone,
			room_data.enemy_spawn_zone
		)
		view.setup(_preview_grid)
	_refresh_visibility()
	_refresh_status()
	call_deferred("_fit_camera")


func _refresh_visibility() -> void:
	if not is_inside_tree():
		return
	var background := get_node_or_null("PaintedBackground") as Node2D
	var foreground := get_node_or_null("PaintedForeground") as Node2D
	var y_sorted_world := get_node_or_null("YSortedWorld") as Node2D
	var view := get_node_or_null("IsoGridView") as PaintedGridView
	if background != null:
		background.visible = show_image
	if foreground != null:
		foreground.visible = show_foreground \
			and (foreground.get_node("ForegroundSprite") as Sprite2D).texture != null
	if y_sorted_world != null:
		for child in y_sorted_world.get_children():
			if child.is_in_group("painted_foreground_occluders"):
				child.visible = show_foreground
	if view != null:
		view.draw_grid_lines = show_grid
		view.draw_cell_centers = show_grid
		view.draw_map_bounds = true
		view.set_debug_layers(
			show_terrain,
			true,
			show_coordinates,
			show_spawns,
			true
		)
		view.queue_redraw()


func _refresh_status() -> void:
	var label := get_node_or_null("UI/Panel/Margin/Status") as Label
	if label == null:
		return
	if room_data == null or room_data.painted_map_visual_data == null:
		label.text = "Assigner une RoomData peinte dans l'inspecteur."
		return
	var visual := room_data.painted_map_visual_data
	label.text = (
		"%s\norigin=%s  axis_x=%s  axis_y=%s\nRMS=%.3f px  max=%.3f px"
		% [
			visual.debug_name,
			visual.grid_origin,
			visual.axis_x,
			visual.axis_y,
			visual.calibration_rms(),
			visual.calibration_max_error(),
		]
	)


func _fit_camera() -> void:
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera == null or room_data == null or room_data.painted_map_visual_data == null:
		return
	var visual := room_data.painted_map_visual_data
	var frame := visual.image_rect()
	if frame.size.x <= 0.0 or frame.size.y <= 0.0:
		return
	camera.position = frame.get_center() + visual.camera_offset
	var viewport_size := get_viewport_rect().size
	var zoom_factor := maxf(
		viewport_size.x / frame.size.x,
		viewport_size.y / frame.size.y
	) * visual.camera_zoom
	camera.zoom = Vector2(zoom_factor, zoom_factor)
	camera.make_current()


func export_capture() -> void:
	if not is_inside_tree():
		push_warning("La scene de calibration doit etre ouverte ou executee.")
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(export_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("Echec de l'export de calibration : %s" % error_string(error))


func _toggle_image() -> void:
	show_image = not show_image


func _toggle_grid() -> void:
	show_grid = not show_grid


func _toggle_foreground() -> void:
	show_foreground = not show_foreground


func _toggle_terrain() -> void:
	show_terrain = not show_terrain


func _toggle_spawns() -> void:
	show_spawns = not show_spawns
