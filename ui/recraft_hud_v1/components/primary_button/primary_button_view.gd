class_name RecraftPrimaryButtonView
extends Button

const METRICS := preload("res://ui/recraft_hud_v1/theme/recraft_hud_metrics_v1.gd")

@onready var background: TextureRect = %Background
@onready var action_icon: TextureRect = %ActionIcon
@onready var label: Label = %Label
@onready var focus_overlay: Panel = %FocusOverlay
@onready var refined_background: Panel = %RefinedBackground
@onready var refined_top_edge: Panel = %RefinedTopEdge

var _active := false
var _hovered := false
var _compact_icon_mode := false
var _compact_icon_size := 56.0
var _default_background_texture: Texture2D = null
var _refined_style := false
var _refined_primary := false


func _ready() -> void:
	_default_background_texture = background.texture
	if custom_minimum_size == Vector2.ZERO:
		apply_layout(METRICS.ACTION_BUTTON_SIZE, METRICS.ACTION_BUTTON_FONT_SIZE)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_refresh_visuals)
	button_up.connect(_refresh_visuals)
	focus_entered.connect(_refresh_visuals)
	focus_exited.connect(_refresh_visuals)
	resized.connect(_update_pivot)
	_update_pivot()
	_refresh_visuals()


func apply_layout(button_size: Vector2, font_size: int) -> void:
	custom_minimum_size = button_size
	set_text_size(font_size)
	if is_node_ready():
		_apply_content_layout()


func set_label(text: String) -> void:
	label.text = text
	accessibility_name = text.replace("\n", " ")


func set_text_size(font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)


func set_icon(texture: Texture2D) -> void:
	action_icon.texture = texture
	action_icon.visible = texture != null
	if is_node_ready():
		_apply_content_layout()


func set_background_texture(
	texture: Texture2D,
	stretch_to_fit: bool = false
	) -> void:
	background.texture = (
		texture if texture != null else _default_background_texture
	)
	background.stretch_mode = (
		TextureRect.STRETCH_SCALE
		if texture != null and stretch_to_fit
		else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)


func set_compact_icon_mode(enabled: bool, icon_size: float = 56.0) -> void:
	_compact_icon_mode = enabled
	_compact_icon_size = maxf(icon_size, 16.0)
	if is_node_ready():
		_apply_content_layout()


func set_active(active: bool) -> void:
	_active = active
	_refresh_visuals()


func set_refined_style(enabled: bool, primary: bool = false) -> void:
	_refined_style = enabled
	_refined_primary = primary
	background.visible = not enabled
	refined_background.visible = enabled
	refined_top_edge.visible = enabled
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
	if _refined_style:
		var style := StyleBoxFlat.new()
		style.bg_color = (
			Color(0.12, 0.105, 0.065, 0.98)
			if _refined_primary
			else Color(0.052, 0.06, 0.055, 0.98)
		)
		if disabled:
			style.bg_color = Color(0.035, 0.038, 0.038, 0.9)
		elif is_pressed():
			style.bg_color = style.bg_color.darkened(0.2)
		elif _hovered or _active:
			style.bg_color = style.bg_color.lightened(0.1)
		style.border_width_left = 2 if _refined_primary else 1
		style.border_width_top = 2 if _refined_primary else 1
		style.border_width_right = 2 if _refined_primary else 1
		style.border_width_bottom = 2 if _refined_primary else 1
		style.border_color = Color(0.65, 0.51, 0.27, 0.92 if _refined_primary else 0.7)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
		style.shadow_size = 3 if _refined_primary else 2
		style.shadow_offset = Vector2(0.0, 1.0)
		style.corner_radius_top_left = 7
		style.corner_radius_top_right = 7
		style.corner_radius_bottom_left = 7
		style.corner_radius_bottom_right = 7
		refined_background.add_theme_stylebox_override("panel", style)
		refined_top_edge.modulate = Color(
			1.0,
			1.0,
			1.0,
			0.82 if _refined_primary else 0.52
		)
	label.modulate = Color(0.56, 0.57, 0.59, 0.82) if disabled else Color.WHITE
	action_icon.modulate = Color(0.48, 0.49, 0.5, 0.72) if disabled else Color.WHITE
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


func _apply_content_layout() -> void:
	if _compact_icon_mode:
		action_icon.set_anchors_preset(Control.PRESET_CENTER)
		action_icon.offset_left = -_compact_icon_size * 0.5
		action_icon.offset_top = -_compact_icon_size * 0.5 - 5.0
		action_icon.offset_right = _compact_icon_size * 0.5
		action_icon.offset_bottom = _compact_icon_size * 0.5 - 5.0
		label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		label.offset_left = 4.0
		label.offset_top = -20.0
		label.offset_right = -4.0
		label.offset_bottom = -2.0
		return
	var icon_size := minf(
		22.0,
		maxf(16.0, custom_minimum_size.y - 8.0)
	)
	action_icon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	action_icon.offset_left = 5.0
	action_icon.offset_top = -icon_size * 0.5
	action_icon.offset_right = 5.0 + icon_size
	action_icon.offset_bottom = icon_size * 0.5
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 29.0 if action_icon.texture != null else 6.0
	label.offset_top = 2.0
	label.offset_right = -6.0
	label.offset_bottom = -2.0
