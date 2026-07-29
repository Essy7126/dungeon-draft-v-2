class_name RecraftPrimaryButtonView
extends Button

@onready var background: TextureRect = %Background
@onready var label: Label = %Label
@onready var focus_overlay: Panel = %FocusOverlay

var _active := false
var _hovered := false


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_refresh_visuals)
	button_up.connect(_refresh_visuals)
	focus_entered.connect(_refresh_visuals)
	focus_exited.connect(_refresh_visuals)
	resized.connect(_update_pivot)
	_update_pivot()
	_refresh_visuals()


func set_label(text: String) -> void:
	label.text = text
	accessibility_name = text.replace("\n", " ")


func set_active(active: bool) -> void:
	_active = active
	_refresh_visuals()


func refresh_visual_state(active: bool = false) -> void:
	_active = active
	_refresh_visuals()


func _refresh_visuals() -> void:
	if not is_node_ready():
		return
	focus_overlay.visible = has_focus() or _active
	var tint := Color.WHITE
	if disabled:
		tint = Color(0.44, 0.45, 0.48, 0.72)
	elif is_pressed():
		tint = Color(0.76, 0.72, 0.68, 1.0)
	elif _active:
		tint = Color(1.08, 0.93, 0.65, 1.0)
	elif _hovered:
		tint = Color(1.08, 1.04, 0.94, 1.0)
	background.modulate = tint
	label.modulate = Color(0.56, 0.57, 0.59, 0.82) if disabled else Color.WHITE
	var target_scale := Vector2(0.98, 0.98) if is_pressed() else Vector2(1.02, 1.02) if _hovered and not disabled else Vector2.ONE
	scale = target_scale


func _on_mouse_entered() -> void:
	_hovered = true
	_refresh_visuals()


func _on_mouse_exited() -> void:
	_hovered = false
	_refresh_visuals()


func _update_pivot() -> void:
	pivot_offset = size * 0.5
