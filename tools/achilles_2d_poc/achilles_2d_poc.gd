extends Node2D

const GRID_SIZE := Vector2i(10, 8)
const START_CELL := Vector2i(2, 5)
const CAPTURE_TARGET := Vector2i(7, 1)
const INVALID_CELL := Vector2i(-1, -1)
const MOVE_SPEED_PIXELS := 70.0
const PATH_COLOR := Color(0.22, 0.78, 1.0, 0.24)
const CAPTURE_DIR := "res://artifacts/achilles_2d_poc"

@onready var grid_view: IsoGridView = $GridView
@onready var surface_layer: Node2D = $SurfaceLayer
@onready var path_line: Line2D = $SurfaceLayer/PathLine
@onready var destination_marker: Line2D = $SurfaceLayer/DestinationMarker
@onready var y_sorted_world: Node2D = $YSortedWorld
@onready var achilles: Node2D = $YSortedWorld/Achilles
@onready var pillar_north: Node2D = $YSortedWorld/PillarNorth
@onready var pillar_south: Node2D = $YSortedWorld/PillarSouth
@onready var camera: Camera2D = $Camera2D
@onready var state_label: Label = $CanvasLayer/Panel/Margin/VBox/State
@onready var cell_label: Label = $CanvasLayer/Panel/Margin/VBox/Cell
@onready var attack_button: Button = $CanvasLayer/Panel/Margin/VBox/Attack

var grid: GridData
var pathfinder: Pathfinder
var current_cell := START_CELL
var _moving := false
var _capture_mode := false
var _validation := {
	"idle_started": false,
	"walk_started": false,
	"walk_completed": false,
	"attack_started": false,
	"attack_returned_to_idle": false,
	"attack_position_stable": false,
}


func _ready() -> void:
	_build_grid()
	_connect_signals()
	_place_world_nodes()
	achilles.play_idle()
	_validation.idle_started = achilles.animated_sprite.animation == &"idle_SE"
	_update_ui("Idle — choisissez une case accessible.")
	_capture_mode = OS.get_cmdline_user_args().has("--capture-achilles")
	if _capture_mode:
		call_deferred("_run_capture_validation")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A or event.keycode == KEY_SPACE:
			_request_attack()
			get_viewport().set_input_as_handled()


func _build_grid() -> void:
	grid = GridData.new(GRID_SIZE.x, GRID_SIZE.y)
	for wall_cell in [Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3)]:
		grid.set_type(wall_cell, GridData.CellType.WALL)
	grid.set_type(Vector2i(1, 1), GridData.CellType.ICE)
	grid.set_type(Vector2i(8, 5), GridData.CellType.RUNE)
	grid.set_type(Vector2i(1, 6), GridData.CellType.HOLE)
	grid.set_type(Vector2i(8, 6), GridData.CellType.LAVA)
	pathfinder = Pathfinder.new(grid)
	grid_view.setup(grid)
	grid_view.set_render_options(true, true, false, true)


func _connect_signals() -> void:
	grid_view.cell_clicked.connect(_on_cell_clicked)
	attack_button.pressed.connect(_request_attack)
	achilles.action_started.connect(_on_action_started)
	achilles.action_finished.connect(_on_action_finished)


func _place_world_nodes() -> void:
	achilles.position = _cell_position_in(y_sorted_world, current_cell)
	pillar_north.position = _cell_position_in(y_sorted_world, Vector2i(4, 3))
	pillar_south.position = _cell_position_in(y_sorted_world, Vector2i(6, 3))
	destination_marker.visible = false
	var bounds := grid_view.get_map_bounds()
	camera.position = grid_view.to_global(bounds.get_center()) - Vector2(120.0, 8.0)
	camera.zoom = Vector2.ONE


func _on_cell_clicked(cell: Vector2i) -> void:
	if _moving or achilles.is_action_playing() or cell == current_cell:
		return
	var path := pathfinder.find_path(current_cell, cell)
	if path.size() < 2:
		_update_ui("Case inaccessible — choisissez une case colorée marchable.")
		return
	grid_view.clear_highlights()
	grid_view.highlight(path, PATH_COLOR)
	grid_view.set_selected_cell(cell)
	_show_path(path)
	_move_along_path(path)


func _move_along_path(path: Array) -> void:
	_moving = true
	attack_button.disabled = true
	achilles.play_walk()
	_validation.walk_started = achilles.animated_sprite.animation == &"walk_SE"
	_update_ui("Walk — déplacement réel sur %d case(s)." % (path.size() - 1))
	for index in range(1, path.size()):
		var next_cell: Vector2i = path[index]
		var target := _cell_position_in(y_sorted_world, next_cell)
		var duration := maxf(achilles.position.distance_to(target) / MOVE_SPEED_PIXELS, 0.18)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(achilles, "position", target, duration)
		await tween.finished
		current_cell = next_cell
	_moving = false
	achilles.play_idle()
	_validation.walk_completed = (
		achilles.animated_sprite.animation == &"idle_SE" and current_cell == path.back()
	)
	attack_button.disabled = false
	grid_view.clear_highlights()
	path_line.clear_points()
	destination_marker.visible = false
	_update_ui("Idle — arrivée sur la case %s." % current_cell)


func _request_attack() -> void:
	if _moving or achilles.is_action_playing():
		return
	attack_button.disabled = true
	achilles.play_attack()
	_update_ui("Attack — la position de grille reste verrouillée.")


func _on_action_started(_animation_name: StringName) -> void:
	_validation.attack_started = (
		achilles.is_action_playing() and achilles.animated_sprite.animation == &"attack_SE"
	)


func _on_action_finished(_animation_name: StringName) -> void:
	_validation.attack_returned_to_idle = (
		not achilles.is_action_playing() and achilles.animated_sprite.animation == &"idle_SE"
	)
	attack_button.disabled = false
	_update_ui("Idle — attaque terminée, retour automatique.")


func _show_path(path: Array) -> void:
	path_line.clear_points()
	for cell in path:
		path_line.add_point(_cell_position_in(surface_layer, cell))
	var destination: Vector2i = path.back()
	destination_marker.position = _cell_position_in(surface_layer, destination)
	destination_marker.visible = true


func _cell_position_in(parent: Node2D, cell: Vector2i) -> Vector2:
	return parent.to_local(grid_view.to_global(grid_view.grid_to_local(cell)))


func _update_ui(message: String) -> void:
	state_label.text = "État : %s" % message
	cell_label.text = "Case Achilles : (%d, %d)" % [current_cell.x, current_cell.y]


func _run_capture_validation() -> void:
	var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	if mkdir_error != OK:
		push_error("Achilles POC: cannot create capture directory (error %d)." % mkdir_error)
		get_tree().quit(1)
		return
	await get_tree().create_timer(1.5).timeout
	await _capture("achilles_idle.png")
	_on_cell_clicked(CAPTURE_TARGET)
	await get_tree().create_timer(0.85).timeout
	await _capture("achilles_walk.png")
	while _moving:
		await get_tree().process_frame
	var position_before_attack: Vector2 = achilles.position
	_request_attack()
	await get_tree().create_timer(0.78).timeout
	await _capture("achilles_attack.png")
	while achilles.is_action_playing():
		await get_tree().process_frame
	_validation.attack_position_stable = achilles.position.is_equal_approx(position_before_attack)
	_validation["final_animation"] = String(achilles.animated_sprite.animation)
	_validation["final_cell"] = [current_cell.x, current_cell.y]
	_validation["y_sort_enabled"] = y_sorted_world.y_sort_enabled
	_validation["foot_anchor_global"] = [
		achilles.foot_anchor.global_position.x,
		achilles.foot_anchor.global_position.y,
	]
	_validation["visual_scale"] = achilles.visual_scale
	_validation["sprite_frames"] = {
		"idle_SE": achilles.animated_sprite.sprite_frames.get_frame_count(&"idle_SE"),
		"walk_SE": achilles.animated_sprite.sprite_frames.get_frame_count(&"walk_SE"),
		"attack_SE": achilles.animated_sprite.sprite_frames.get_frame_count(&"attack_SE"),
	}
	var report_path := "%s/validation_report.json" % CAPTURE_DIR
	var report := FileAccess.open(report_path, FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify(_validation, "\t"))
	var success := true
	for key in [
		"idle_started",
		"walk_started",
		"walk_completed",
		"attack_started",
		"attack_returned_to_idle",
		"attack_position_stable",
	]:
		success = success and bool(_validation[key])
	print("ACHILLES_2D_POC_VALIDATION_%s" % ("OK" if success else "FAILED"))
	get_tree().quit(0 if success else 1)


func _capture(file_name: String) -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		return
	if file_name == "achilles_idle.png":
		var redraw_targets: Array[CanvasItem] = [
			$Backdrop,
			grid_view,
			surface_layer,
			y_sorted_world,
			$CanvasLayer/Panel,
		]
		for target in redraw_targets:
			target.visible = false
		await get_tree().process_frame
		for target in redraw_targets:
			target.visible = true
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.force_draw(false, 0.0)
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path("%s/%s" % [CAPTURE_DIR, file_name]))
	if error != OK:
		push_error("Achilles POC: cannot save %s (error %d)." % [file_name, error])
