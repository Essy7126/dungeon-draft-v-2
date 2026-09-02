class_name RecraftResourceBarView
extends Control

const METRICS := preload("res://ui/recraft_hud_v1/theme/recraft_hud_metrics_v1.gd")
const VISUAL_THEME_FACTORY := preload(
	"res://ui/recraft_hud_v1/theme/hud_visual_theme_factory.gd"
)

@onready var trough: ColorRect = %Trough
@onready var delayed_value_fill: ColorRect = %DelayedValueFill
@onready var main_fill: ColorRect = %MainFill
@onready var cost_preview_fill: ColorRect = %CostPreviewFill
@onready var gain_preview_fill: ColorRect = %GainPreviewFill
@onready var frame: TextureRect = %Frame
@onready var theme_frame: NinePatchRect = %ThemeFrame
@onready var resource_icon: TextureRect = %ResourceIcon
@onready var resource_icon_fallback: Label = %ResourceIconFallback
@onready var value_label: Label = %ValueLabel
@onready var refined_frame: Panel = %RefinedFrame

var current_value := 0.0
var maximum_value := 1.0
var preview_cost := 0.0
var preview_gain := 0.0
var resource_color := Color(0.76, 0.18, 0.18)
var _delayed_value := 0.0
var _delayed_tween: Tween
var _layout_scale := 1.0
var _visual_skin: HudVisualSkinData = null
var _reduced_motion := false
var _is_critical_health := false
var _hide_inline_marker := false


func _ready() -> void:
	resized.connect(_layout_fills)
	apply_layout(1.0)
	_layout_fills()


func apply_layout(scale_factor: float) -> void:
	_apply_layout(
		METRICS.scaled_vector(METRICS.RESOURCE_BAR_SIZE, scale_factor),
		scale_factor
	)


func apply_calibrated_layout(
	bar_size: Vector2,
	text_scale: float
	) -> void:
	_apply_layout(bar_size.round(), text_scale)


func _apply_layout(bar_size: Vector2, scale_factor: float) -> void:
	_layout_scale = scale_factor
	custom_minimum_size = bar_size
	value_label.add_theme_font_size_override(
		"font_size", maxi(17 if bar_size.y >= 28.0 else 12, METRICS.scaled_font(METRICS.RESOURCE_VALUE_FONT_SIZE, scale_factor))
	)
	resource_icon_fallback.add_theme_font_size_override(
		"font_size", METRICS.scaled_font(METRICS.SECONDARY_FONT_SIZE, scale_factor)
	)
	var icon_size := METRICS.scaled(14.0, scale_factor)
	var icon_left := METRICS.scaled(8.0, scale_factor)
	resource_icon.position = Vector2(
		icon_left,
		roundf((custom_minimum_size.y - icon_size) * 0.5)
	)
	resource_icon.size = Vector2(icon_size, icon_size)
	resource_icon_fallback.position = Vector2(
		icon_left,
		roundf((custom_minimum_size.y - icon_size) * 0.5)
	)
	resource_icon_fallback.size = Vector2(icon_size, icon_size)
	value_label.offset_left = METRICS.scaled(
		6.0 if _hide_inline_marker else 24.0,
		scale_factor
	)
	value_label.offset_right = -METRICS.scaled(6.0, scale_factor)
	_layout_fills()


func set_frame_texture(texture: Texture2D) -> void:
	frame.visible = texture == null
	theme_frame.texture = texture
	theme_frame.visible = texture != null


func set_refined_style(enabled: bool) -> void:
	refined_frame.visible = enabled and theme_frame.texture == null
	if enabled:
		frame.visible = false
		theme_frame.visible = theme_frame.texture != null
	if _visual_skin != null:
		_apply_visual_frame()


func apply_visual_skin(skin: HudVisualSkinData) -> void:
	_visual_skin = skin
	if skin == null:
		return
	_apply_visual_frame()
	trough.color = skin.surface_recessed
	cost_preview_fill.color = Color(
		skin.surface_scrim.r,
		skin.surface_scrim.g,
		skin.surface_scrim.b,
		0.82
	)
	gain_preview_fill.color = Color(
		skin.text_secondary.r,
		skin.text_secondary.g,
		skin.text_secondary.b,
		0.58
	)
	resource_icon.modulate = skin.text_primary
	resource_icon_fallback.add_theme_font_override("font", skin.font_emphasis)
	resource_icon_fallback.add_theme_color_override("font_color", skin.text_secondary)
	value_label.add_theme_font_override("font", skin.font_numeric)
	value_label.add_theme_color_override("font_color", skin.text_primary)
	_apply_resource_colors(_is_critical_health)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if not enabled:
		return
	if _delayed_tween != null and _delayed_tween.is_valid():
		_delayed_tween.kill()
	_delayed_tween = null
	_delayed_value = current_value
	_layout_fills()


func is_reduced_motion_enabled() -> bool:
	return _reduced_motion


func set_resource(
	value: float,
	maximum: float,
	color: Color,
	icon: Texture2D = null,
	icon_fallback: String = "",
	show_text: bool = true,
	animate_change: bool = true
) -> void:
	var previous := current_value
	current_value = clampf(value, 0.0, maxf(maximum, 0.0))
	maximum_value = maxf(maximum, 0.0001)
	resource_color = color
	_is_critical_health = icon_fallback == "PV" and current_value / maximum_value <= 0.25
	_hide_inline_marker = (
		icon_fallback == "PV"
		and _visual_skin != null
		and not _visual_skin.neutral_grayscale
	)
	_apply_resource_colors(_is_critical_health)
	resource_icon.texture = icon
	resource_icon.visible = icon != null and not _hide_inline_marker
	resource_icon_fallback.visible = icon == null and not _hide_inline_marker
	resource_icon_fallback.text = icon_fallback
	value_label.offset_left = METRICS.scaled(
		6.0 if _hide_inline_marker else 24.0,
		_layout_scale
	)
	value_label.visible = show_text
	value_label.text = "%d / %d" % [int(round(current_value)), int(round(maximum))]
	value_label.add_theme_color_override("font_color", _resource_text_color())
	if _delayed_tween != null:
		_delayed_tween.kill()
	if animate_change and current_value < previous and not _reduced_motion:
		_delayed_value = previous
		_delayed_tween = create_tween()
		_delayed_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var duration := (
			_visual_skin.motion_duration(&"panel", _reduced_motion)
			if _visual_skin != null
			else 0.32
		)
		_delayed_tween.tween_method(_set_delayed_value, previous, current_value, duration)
	else:
		_delayed_value = current_value
	_layout_fills()


func set_preview(cost: float = 0.0, gain: float = 0.0) -> void:
	preview_cost = maxf(cost, 0.0)
	preview_gain = maxf(gain, 0.0)
	var insufficient := preview_cost > current_value
	value_label.add_theme_color_override(
		"font_color",
		_visual_skin.text_primary
		if _visual_skin != null
		else Color(1.0, 0.48, 0.42)
		if insufficient
		else Color(0.96, 0.94, 0.86)
	)
	_layout_fills()


func clear_preview() -> void:
	set_preview()


func _set_delayed_value(value: float) -> void:
	_delayed_value = value
	_layout_fills()


func _apply_visual_frame() -> void:
	if _visual_skin == null or not is_node_ready():
		return
	refined_frame.add_theme_stylebox_override(
		"panel",
		VISUAL_THEME_FACTORY.make_panel_style(
			_visual_skin,
			Color.TRANSPARENT,
			_visual_skin.border_strong_color,
			_visual_skin.border_thin,
			_visual_skin.radius_tight
		)
	)


func _apply_resource_colors(is_critical: bool) -> void:
	if _visual_skin != null and _visual_skin.neutral_grayscale:
		main_fill.color = (
			_visual_skin.text_primary
			if is_critical
			else _visual_skin.border_selected_color
		)
		delayed_value_fill.color = _visual_skin.border_strong_color
		return
	main_fill.color = resource_color.lightened(0.12) if is_critical else resource_color
	delayed_value_fill.color = resource_color.lightened(0.28)


func _resource_text_color() -> Color:
	if _visual_skin != null:
		return _visual_skin.text_primary
	return Color(1.0, 0.78, 0.7) if _is_critical_health else Color(0.96, 0.94, 0.86)


func _layout_fills() -> void:
	if not is_node_ready():
		return
	var insets := METRICS.RESOURCE_BAR_INSETS * _layout_scale
	var bar_rect := Rect2(
		Vector2(insets.x, insets.y),
		Vector2(
			maxf(size.x - insets.x - insets.z, 1.0),
			maxf(size.y - insets.y - insets.w, 1.0)
		)
	)
	_set_rect(trough, bar_rect.position, bar_rect.size)
	var current_ratio := clampf(current_value / maximum_value, 0.0, 1.0)
	var delayed_ratio := clampf(_delayed_value / maximum_value, 0.0, 1.0)
	_set_rect(delayed_value_fill, bar_rect.position, Vector2(bar_rect.size.x * delayed_ratio, bar_rect.size.y))
	_set_rect(main_fill, bar_rect.position, Vector2(bar_rect.size.x * current_ratio, bar_rect.size.y))

	var cost_start := clampf((current_value - preview_cost) / maximum_value, 0.0, current_ratio)
	_set_rect(
		cost_preview_fill,
		bar_rect.position + Vector2(bar_rect.size.x * cost_start, 0.0),
		Vector2(bar_rect.size.x * (current_ratio - cost_start), bar_rect.size.y)
	)
	cost_preview_fill.visible = preview_cost > 0.0

	var gain_end := clampf((current_value + preview_gain) / maximum_value, current_ratio, 1.0)
	_set_rect(
		gain_preview_fill,
		bar_rect.position + Vector2(bar_rect.size.x * current_ratio, 0.0),
		Vector2(bar_rect.size.x * (gain_end - current_ratio), bar_rect.size.y)
	)
	gain_preview_fill.visible = preview_gain > 0.0


func _set_rect(control: Control, new_position: Vector2, new_size: Vector2) -> void:
	control.position = new_position
	control.size = Vector2(maxf(new_size.x, 0.0), maxf(new_size.y, 0.0))
