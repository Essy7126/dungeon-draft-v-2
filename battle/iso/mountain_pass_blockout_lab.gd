@tool
extends Node2D

@onready var view: MountainPassBlockoutView=$IsoGridView
@onready var camera: Camera2D=$Camera2D
@onready var status: Label=$DebugUI/Panel/Margin/VBox/Status

func _ready() -> void:
	var grid:=GridData.new(14,14);view.blockout_data.apply_to_grid(grid);view.setup(grid)
	if not Engine.is_editor_hint():camera.make_current();call_deferred("_fit_camera");get_viewport().size_changed.connect(_fit_camera)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.keycode:
		KEY_F1:view.render_mode=MountainPassBlockoutView.RenderMode.REFERENCE if view.render_mode==MountainPassBlockoutView.RenderMode.DEBUG else MountainPassBlockoutView.RenderMode.DEBUG
		KEY_M:view.render_mode=(view.render_mode+1)%MountainPassBlockoutView.RenderMode.size()
		KEY_G:view.show_calibration_overlay=not view.show_calibration_overlay
		_:return
	_refresh()

func _fit_camera() -> void:
	var viewport:=get_viewport_rect().size;var fit:=minf(viewport.x/2048.0,viewport.y/2048.0)*0.96
	camera.position=Vector2(1024,1024)+view.camera_offset;camera.zoom=Vector2(fit,fit)*view.camera_zoom

func _refresh() -> void:
	if not is_instance_valid(status):return
	var counts:=view.blockout_data.layout_counts()
	status.text="mode=%s  origin=%s  axis_x=%s  axis_y=%s\nplatform=%s  cliff_edges=%d\nwalkable=153 blocked=11 void=32 ICE=%d A=%d E=%d overlay=%s"%[MountainPassBlockoutView.RenderMode.keys()[view.render_mode],view.grid_origin,view.axis_x,view.axis_y,view.blockout_data.platform_bounds(),view.blockout_data.cliff_edges().size(),counts[MountainPassBlockoutData.ICE],counts[MountainPassBlockoutData.ALLY_SPAWN],counts[MountainPassBlockoutData.ENEMY_SPAWN],view.show_calibration_overlay]
