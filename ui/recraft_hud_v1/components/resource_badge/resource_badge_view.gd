class_name RecraftResourceBadgeView
extends Control

const METRICS := preload("res://ui/recraft_hud_v1/theme/recraft_hud_metrics_v1.gd")
const VISUAL_THEME_FACTORY := preload(
	"res://ui/recraft_hud_v1/theme/hud_visual_theme_factory.gd"
)

@onready var base: TextureRect = %Base
@onready var color_overlay: Panel = %ColorOverlay
@onready var icon: TextureRect = %Icon
@onready var icon_fallback: Label = %IconFallback
@onready var value_label: Label = %ValueLabel
@onready var empty_overlay: ColorRect = %EmptyOverlay

var _refined_style := false
var _visual_skin: HudVisualSkinData = null
var _badge_style: StyleBoxFlat = null


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
		"font_size", METRICS.scaled_font(17, scale_factor)
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
	var style := _badge_style
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = Color(color.r, color.g, color.b, 0.3 if _refined_style else 0.34)
		var radius := 9 if _refined_style else 15
		style.corner_radius_top_left = radius
		style.corner_radius_top_right = radius
		style.corner_radius_bottom_left = radius
		style.corner_radius_bottom_right = radius
		if _refined_style:
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = Color(color.r, color.g, color.b, 0.64)
	color_overlay.add_theme_stylebox_override("panel", style)
	icon.texture = icon_texture
	icon.visible = icon_texture != null
	icon_fallback.visible = icon_texture == null
	icon_fallback.text = icon_text
	value_label.text = str(value)
	empty_overlay.visible = value <= 0
	tooltip_text = "%s : %d / %d" % [icon_text, value, maximum]


func set_refined_style(enabled: bool) -> void:
	_refined_style = enabled
	base.visible = not enabled
	if _visual_skin != null:
		apply_visual_skin(_visual_skin)


func apply_visual_skin(skin: HudVisualSkinData) -> void:
	_visual_skin = skin
	_badge_style = null
	if skin == null:
		return
	_badge_style = VISUAL_THEME_FACTORY.make_panel_style(
		skin,
		skin.surface_raised,
		skin.border_strong_color,
		skin.border_thin,
		skin.radius_control,
		true
	)
	color_overlay.add_theme_stylebox_override("panel", _badge_style)
	icon.modulate = skin.text_primary
	icon_fallback.add_theme_font_override("font", skin.font_emphasis)
	icon_fallback.add_theme_color_override("font_color", skin.text_secondary)
	value_label.add_theme_font_override("font", skin.font_numeric)
	value_label.add_theme_color_override("font_color", skin.text_primary)
	empty_overlay.color = Color(
		skin.surface_scrim.r,
		skin.surface_scrim.g,
		skin.surface_scrim.b,
		0.62
	)
