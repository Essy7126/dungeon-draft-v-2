class_name RecraftPortraitView
extends Control

@onready var portrait_texture: TextureRect = %PortraitTexture
@onready var frame: TextureRect = %Frame
@onready var active_indicator: Panel = %ActiveIndicator
@onready var placeholder_label: Label = %PlaceholderLabel


func set_portrait(texture: Texture2D, character_name: String = "") -> void:
	portrait_texture.texture = texture
	portrait_texture.visible = texture != null
	placeholder_label.visible = texture == null
	placeholder_label.text = character_name.left(1).to_upper() if not character_name.is_empty() else "?"
	tooltip_text = character_name


func set_active(active: bool) -> void:
	active_indicator.visible = active
	frame.modulate = Color(1.08, 1.04, 0.84, 1.0) if active else Color(0.72, 0.74, 0.78, 0.9)
