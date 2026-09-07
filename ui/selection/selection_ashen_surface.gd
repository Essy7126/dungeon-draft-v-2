class_name SelectionAshenSurface
extends Control
## A decorative layer below native controls: text, focus and hit testing stay native.

const GRAIN := preload("res://asset/ui/character_selection/materials/ash_leather_v1.png")
const SURFACE_SHADER := preload("res://ui/selection/selection_ashen_surface.gdshader")

var _role: StringName = &"panel"
var _base := Color("211c19")
var _edge := Color("655447")
var _selected := false
var _pointer_down := false
var _button: Button
var _state: Dictionary = {}
var _surface_material: ShaderMaterial


func configure(role: StringName, fill: Color, border: Color) -> void:
	_role = role
	_base = fill
	_edge = border
	if is_node_ready():
		_update_material()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	show_behind_parent = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface_material = ShaderMaterial.new()
	_surface_material.shader = SURFACE_SHADER
	material = _surface_material
	_button = get_parent() as Button
	if _button != null:
		_button.button_down.connect(func(): _pointer_down = true)
		_button.button_up.connect(func(): _pointer_down = false)
		_button.mouse_exited.connect(func(): _pointer_down = false)
	resized.connect(_update_size)
	_update_material()
	_update_size()
	_sync_state()
	set_process(_button != null)


func _draw() -> void:
	draw_texture_rect(GRAIN, Rect2(Vector2.ZERO, size), false)


func _process(_delta: float) -> void:
	_sync_state()


func set_selected(selected: bool, accent: Color) -> void:
	_selected = selected
	# Preserve the hero accent in its native marker; the metal stays ash bronze.
	_edge = Color("b89a74") if selected else Color("655447")
	if _role == &"primary":
		_edge = accent
	if is_node_ready():
		_update_material()
		_sync_state()


func get_surface_state() -> Dictionary:
	return _state.duplicate()


func _sync_state() -> void:
	var draw_mode := _button.get_draw_mode() if _button != null else BaseButton.DRAW_NORMAL
	var disabled := draw_mode == BaseButton.DRAW_DISABLED
	if disabled:
		_pointer_down = false
	var next := {
		"role": _role,
		"selected": _selected or (_button != null and _button.toggle_mode and _button.button_pressed),
		"hovered": draw_mode in [BaseButton.DRAW_HOVER, BaseButton.DRAW_HOVER_PRESSED],
		"depressed": _pointer_down and not disabled,
		"disabled": disabled,
	}
	if next == _state:
		return
	_state = next
	_surface_material.set_shader_parameter("hover_amount", 1.0 if next.hovered and not disabled else 0.0)
	_surface_material.set_shader_parameter("selection_amount", 1.0 if next.selected and not disabled else 0.0)
	_surface_material.set_shader_parameter("press_amount", 1.0 if next.depressed else 0.0)
	_surface_material.set_shader_parameter("disabled_amount", 1.0 if disabled else 0.0)


func _update_size() -> void:
	if _surface_material != null:
		_surface_material.set_shader_parameter("surface_size", size)
	queue_redraw()


func _update_material() -> void:
	_surface_material.set_shader_parameter("base_color", _base)
	_surface_material.set_shader_parameter("edge_color", _edge)
	_surface_material.set_shader_parameter("corner_radius", 7.0 if _role == &"window" else 4.0)
	_surface_material.set_shader_parameter("bevel_width", 4.0 if _role in [&"window", &"primary"] else 2.4)
	_surface_material.set_shader_parameter("texture_strength", 0.18 if _role == &"window" else 0.28)
	_surface_material.set_shader_parameter("is_window", _role == &"window")
	_surface_material.set_shader_parameter("is_primary", _role == &"primary")
