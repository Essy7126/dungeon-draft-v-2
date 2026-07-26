class_name CharacterPreview3D
extends Control

@export var unit_data: UnitData = null

@onready var viewport_container: SubViewportContainer = $ViewportContainer
@onready var preview_viewport: SubViewport = $ViewportContainer/PreviewViewport
@onready var visual_root: Node3D = $ViewportContainer/PreviewViewport/PreviewWorld/VisualRoot
@onready var camera: Camera3D = $ViewportContainer/PreviewViewport/PreviewWorld/Camera3D
@onready var fallback_panel: PanelContainer = $FallbackPanel
@onready var fallback_label: Label = $FallbackPanel/FallbackLabel

var _visual_instance: Node3D = null


func _ready() -> void:
	camera.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)
	configure(unit_data)


func _exit_tree() -> void:
	clear_preview()
	if is_instance_valid(preview_viewport):
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func configure(source) -> void:
	clear_preview()
	var visual_scene: PackedScene = null
	var display_name := "Personnage"
	if source is UnitData:
		unit_data = source as UnitData
		visual_scene = unit_data.preview_visual_scene
		display_name = unit_data.unit_name
	elif source is PackedScene:
		unit_data = null
		visual_scene = source as PackedScene
	else:
		unit_data = null

	if visual_scene == null:
		_show_fallback(display_name)
		return
	var candidate := visual_scene.instantiate()
	if not candidate is Node3D:
		candidate.free()
		_show_fallback(display_name)
		return
	_visual_instance = candidate as Node3D
	visual_root.add_child(_visual_instance)
	var authored_scale := _visual_instance.scale
	_visual_instance.transform = Transform3D.IDENTITY
	_visual_instance.scale = authored_scale
	if _visual_instance.has_method("reset_to_idle"):
		_visual_instance.reset_to_idle()
	elif _visual_instance.has_method("play_idle"):
		_visual_instance.play_idle()
	viewport_container.visible = true
	fallback_panel.visible = false


func clear_preview() -> void:
	if not is_instance_valid(_visual_instance):
		_visual_instance = null
		return
	if _visual_instance.get_parent() != null:
		_visual_instance.get_parent().remove_child(_visual_instance)
	_visual_instance.free()
	_visual_instance = null


func get_visual_instance() -> Node3D:
	return _visual_instance if is_instance_valid(_visual_instance) else null


func is_using_fallback() -> bool:
	return fallback_panel.visible


func _show_fallback(display_name: String) -> void:
	viewport_container.visible = false
	fallback_panel.visible = true
	fallback_label.text = "%s\nAperçu 3D indisponible" % display_name
