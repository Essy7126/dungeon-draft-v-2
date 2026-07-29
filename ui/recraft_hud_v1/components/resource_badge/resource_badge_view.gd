class_name RecraftResourceBadgeView
extends Control

@onready var color_overlay: Panel = %ColorOverlay
@onready var icon: TextureRect = %Icon
@onready var icon_fallback: Label = %IconFallback
@onready var value_label: Label = %ValueLabel
@onready var empty_overlay: ColorRect = %EmptyOverlay


func _ready() -> void:
	set_badge(0, 0, Color.WHITE, null, "")


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
