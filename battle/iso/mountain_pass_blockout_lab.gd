@tool
extends Node2D

## Laboratoire non destructif du blueprint 2D. Les PNG sont de simples fonds ;
## MountainPassBlockoutData/GridData pilotent toujours grille, clics et overlays.

const BLUEPRINT_PATHS := [
	"res://artifacts/maps/mountain_pass_blueprint/mountain_pass_blueprint_clean.png",
	"res://artifacts/maps/mountain_pass_blueprint/mountain_pass_blueprint_reference.png",
	"res://artifacts/maps/mountain_pass_blueprint/mountain_pass_blueprint_logic.png",
	"res://artifacts/maps/mountain_pass_blueprint/mountain_pass_blueprint_debug.png",
]
const BLUEPRINT_NAMES := ["CLEAN", "REFERENCE", "LOGIC", "DEBUG"]
const FOREGROUND_PATH := "res://artifacts/maps/mountain_pass_blueprint/mountain_pass_blueprint_foreground_guide.png"

@onready var background: Sprite2D = $BlueprintBackground
@onready var view: MountainPassBlueprintView = $IsoGridView
@onready var foreground: Sprite2D = $ForegroundGuide
@onready var camera: Camera2D = $Camera2D
@onready var status_label: Label = $DebugUI/Panel/Margin/VBox/Status
@onready var help_label: Label = $DebugUI/Panel/Margin/VBox/Help

var _grid: GridData = null
var _background_mode := 0
var _show_grid := true
var _show_terrain := false


func _ready() -> void:
	if view.blockout_data == null:
		view.blockout_data = load("res://data/maps/mountain_pass_blockout.tres")
	_grid = GridData.new(
		view.blockout_data.logical_size.x,
		view.blockout_data.logical_size.y
	)
	view.blockout_data.apply_to_grid(_grid)
	view.setup(_grid)
	_load_exported_textures()
	_update_overlay_mode()
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
		KEY_M:
			_background_mode = (_background_mode + 1) % BLUEPRINT_PATHS.size()
			_load_background_texture()
		KEY_G:
			_show_grid = not _show_grid
			if not _show_grid:
				_show_terrain = false
			_update_overlay_mode()
		KEY_T:
			_show_terrain = not _show_terrain
			_show_grid = true
			_update_overlay_mode()
		KEY_F:
			foreground.visible = not foreground.visible
		KEY_U:
			view.show_unit_preview = not view.show_unit_preview
		_:
			return
	_refresh_ui()


func _load_exported_textures() -> void:
	_load_background_texture()
	if ResourceLoader.exists(FOREGROUND_PATH):
		foreground.texture = load(FOREGROUND_PATH) as Texture2D
	else:
		foreground.texture = null
		push_warning("Guide de foreground absent : executer tools/export_mountain_pass_blockout.ps1")


func _load_background_texture() -> void:
	var path: String = str(BLUEPRINT_PATHS[_background_mode])
	if ResourceLoader.exists(path):
		background.texture = load(path) as Texture2D
	else:
		background.texture = null
		push_warning("Blueprint absent : %s" % path)


func _update_overlay_mode() -> void:
	if _show_terrain:
		view.render_mode = MountainPassBlueprintView.RenderMode.TERRAIN_OVERLAY
	elif _show_grid:
		view.render_mode = MountainPassBlueprintView.RenderMode.GRID_OVERLAY
	else:
		view.render_mode = MountainPassBlueprintView.RenderMode.INTERACTION_ONLY


func _fit_camera() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(view):
		return
	var frame := view.get_map_bounds()
	var viewport_size := get_viewport_rect().size
	if frame.size.x <= 0.0 or frame.size.y <= 0.0 \
			or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	camera.position = frame.get_center() + view.camera_offset
	var fit := minf(viewport_size.x / frame.size.x, viewport_size.y / frame.size.y)
	camera.zoom = Vector2(fit, fit) * view.camera_zoom
	_refresh_ui()


func _refresh_ui() -> void:
	if not is_instance_valid(status_label) or view.blockout_data == null:
		return
	var data := view.blockout_data
	var counts := data.layout_counts()
	status_label.text = (
		"fond=%s  grille=%s  terrains=%s  foreground=%s  unites=%s\n"
		+ "canvas=1920x1080  origine=%s  axis_x=%s  axis_y=%s\n"
		+ "grid_bounds=%s  cellule=96x48  categories=%d\n"
		+ "walkable=%d  blocked=%d  VOID=%d  ICE=%d  A=%d  E=%d"
	) % [
		BLUEPRINT_NAMES[_background_mode],
		"ON" if _show_grid else "OFF",
		"ON" if _show_terrain else "OFF",
		"ON" if foreground.visible else "OFF",
		"ON" if view.show_unit_preview else "OFF",
		view.grid_origin,
		view.axis_x,
		view.axis_y,
		view.get_logical_bounds(),
		MountainPassBlueprintView.GRAPHIC_CATEGORIES.size(),
		data.walkable_cells().size(),
		data.blocked_cells().size(),
		counts[MountainPassBlockoutData.VOID],
		counts[MountainPassBlockoutData.ICE],
		counts[MountainPassBlockoutData.ALLY_SPAWN],
		counts[MountainPassBlockoutData.ENEMY_SPAWN],
	]
	help_label.text = "M fonds | G grille | T terrains | F foreground | U silhouettes | clic/survol actifs"
