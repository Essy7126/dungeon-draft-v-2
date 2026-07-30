class_name RecraftResourceBarView
extends Control

const METRICS := preload("res://ui/recraft_hud_v1/theme/recraft_hud_metrics_v1.gd")

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

var current_value := 0.0
var maximum_value := 1.0
var preview_cost := 0.0
var preview_gain := 0.0
var resource_color := Color(0.76, 0.18, 0.18)
var _delayed_value := 0.0
var _delayed_tween: Tween
var _layout_scale := 1.0


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
		"font_size", METRICS.scaled_font(METRICS.RESOURCE_VALUE_FONT_SIZE, scale_factor)
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
	value_label.offset_left = METRICS.scaled(24.0, scale_factor)
	value_label.offset_right = -METRICS.scaled(6.0, scale_factor)
	_layout_fills()


func set_frame_texture(texture: Texture2D) -> void:
	frame.visible = texture == null
	theme_frame.texture = texture
	theme_frame.visible = texture != null


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
	main_fill.color = color
	delayed_value_fill.color = color.lightened(0.28)
	resource_icon.texture = icon
	resource_icon.visible = icon != null
	resource_icon_fallback.visible = icon == null
	resource_icon_fallback.text = icon_fallback
	value_label.visible = show_text
	value_label.text = "%d / %d" % [int(round(current_value)), int(round(maximum))]
	if _delayed_tween != null:
		_delayed_tween.kill()
	if animate_change and current_value < previous:
		_delayed_value = previous
		_delayed_tween = create_tween()
		_delayed_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_delayed_tween.tween_method(_set_delayed_value, previous, current_value, 0.32)
	else:
		_delayed_value = current_value
	_layout_fills()


func set_preview(cost: float = 0.0, gain: float = 0.0) -> void:
	preview_cost = maxf(cost, 0.0)
	preview_gain = maxf(gain, 0.0)
	var insufficient := preview_cost > current_value
	value_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.48, 0.42) if insufficient else Color(0.96, 0.94, 0.86)
	)
	_layout_fills()


func clear_preview() -> void:
	set_preview()


func _set_delayed_value(value: float) -> void:
	_delayed_value = value
	_layout_fills()


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
