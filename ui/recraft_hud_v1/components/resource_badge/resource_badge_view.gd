class_name RecraftResourceBadgeView
extends Control

const METRICS := preload("res://ui/recraft_hud_v1/theme/recraft_hud_metrics_v1.gd")

@onready var base: TextureRect = %Base
@onready var color_overlay: Panel = %ColorOverlay
@onready var icon: TextureRect = %Icon
@onready var icon_fallback: Label = %IconFallback
@onready var value_label: Label = %ValueLabel
@onready var empty_overlay: ColorRect = %EmptyOverlay


func _ready() -> void:
	apply_layout(1.0)
	set_badge(0, 0, Color.WHITE, null, "")


func apply_layout(scale_factor: float) -> void:
	var badge_size := METRICS.scaled(METRICS.RESOURCE_BADGE_SIZE, scale_factor)
	custom_minimum_size = Vector2(badge_size, badge_size)
	var frame_inset := METRICS.scaled(5.0, scale_factor)
	color_overlay.set_offsets_preset(Control.PRESET_FULL_RECT)
	color_overlay.offset_left = frame_inset
	color_overlay.offset_top = frame_inset
	color_overlay.offset_right = -frame_inset
	color_overlay.offset_bottom = -frame_inset
	icon.set_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = METRICS.scaled(11.0, scale_factor)
	icon.offset_top = METRICS.scaled(7.0, scale_factor)
	icon.offset_right = -METRICS.scaled(11.0, scale_factor)
	icon.offset_bottom = -METRICS.scaled(17.0, scale_factor)
	icon_fallback.set_offsets_preset(Control.PRESET_FULL_RECT)
	icon_fallback.offset_top = METRICS.scaled(3.0, scale_factor)
	icon_fallback.offset_bottom = -METRICS.scaled(21.0, scale_factor)
	icon_fallback.add_theme_font_size_override(
		"font_size", METRICS.scaled_font(METRICS.SECONDARY_FONT_SIZE, scale_factor)
	)
	value_label.set_offsets_preset(Control.PRESET_FULL_RECT)
	value_label.offset_top = METRICS.scaled(13.0, scale_factor)
	value_label.offset_bottom = -METRICS.scaled(3.0, scale_factor)
	value_label.add_theme_font_size_override(
		"font_size", METRICS.scaled_font(15, scale_factor)
	)
	empty_overlay.set_offsets_preset(Control.PRESET_FULL_RECT)
	empty_overlay.offset_left = frame_inset
	empty_overlay.offset_top = frame_inset
	empty_overlay.offset_right = -frame_inset
	empty_overlay.offset_bottom = -frame_inset


func set_badge(
	value: int,
	maximum: int,
	color: Color,
	icon_texture: Texture2D = null,
	icon_text: String = ""
) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.34)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	color_overlay.add_theme_stylebox_override("panel", style)
	icon.texture = icon_texture
	icon.visible = icon_texture != null
	icon_fallback.visible = icon_texture == null
	icon_fallback.text = icon_text
	value_label.text = str(value)
	empty_overlay.visible = value <= 0
	tooltip_text = "%s : %d / %d" % [icon_text, value, maximum]
