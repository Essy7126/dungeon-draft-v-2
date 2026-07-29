class_name RecraftPortraitView
extends Control

const METRICS := preload("res://ui/recraft_hud_v1/theme/recraft_hud_metrics_v1.gd")

@onready var portrait_texture: TextureRect = %PortraitTexture
@onready var character_preview: CharacterPreview3D = %CharacterPreview
@onready var frame: TextureRect = %Frame
@onready var active_indicator: Panel = %ActiveIndicator
@onready var placeholder_label: Label = %PlaceholderLabel

var character_data: UnitData = null


func _ready() -> void:
	apply_layout(1.0)
	set_character_data(character_data)


func apply_layout(scale_factor: float) -> void:
	var component_size := METRICS.scaled(METRICS.PORTRAIT_SIZE, scale_factor)
	var inner_size := METRICS.scaled(METRICS.PORTRAIT_INNER_SIZE, scale_factor)
	var inner_margin := roundf((component_size - inner_size) * 0.5)
	custom_minimum_size = Vector2(component_size, component_size)
	portrait_texture.set_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_texture.offset_left = inner_margin
	portrait_texture.offset_top = inner_margin
	portrait_texture.offset_right = -inner_margin
	portrait_texture.offset_bottom = -inner_margin
	character_preview.set_offsets_preset(Control.PRESET_FULL_RECT)
	character_preview.offset_left = inner_margin
	character_preview.offset_top = inner_margin
	character_preview.offset_right = -inner_margin
	character_preview.offset_bottom = -inner_margin
	character_preview.custom_minimum_size = Vector2.ZERO
	character_preview.camera.size = METRICS.PORTRAIT_PREVIEW_CAMERA_SIZE
	placeholder_label.set_offsets_preset(Control.PRESET_FULL_RECT)
	placeholder_label.offset_left = inner_margin
	placeholder_label.offset_top = inner_margin
	placeholder_label.offset_right = -inner_margin
	placeholder_label.offset_bottom = -inner_margin
	placeholder_label.add_theme_font_size_override(
		"font_size", METRICS.scaled_font(30, scale_factor)
	)
	var indicator_inset := METRICS.scaled(1.0, scale_factor)
	active_indicator.set_offsets_preset(Control.PRESET_FULL_RECT)
	active_indicator.offset_left = indicator_inset
	active_indicator.offset_top = indicator_inset
	active_indicator.offset_right = -indicator_inset
	active_indicator.offset_bottom = -indicator_inset


func set_portrait(texture: Texture2D, character_name: String = "") -> void:
	character_data = null
	character_preview.clear_preview()
	character_preview.visible = false
	portrait_texture.texture = texture
	portrait_texture.visible = texture != null
	placeholder_label.visible = texture == null
	placeholder_label.text = character_name.left(1).to_upper() if not character_name.is_empty() else "?"
	tooltip_text = character_name


func set_character_data(data: UnitData) -> void:
	character_data = data
	portrait_texture.texture = null
	portrait_texture.visible = false
	if data == null:
		character_preview.clear_preview()
		character_preview.visible = false
		placeholder_label.visible = true
		placeholder_label.text = "?"
		tooltip_text = ""
		return
	character_preview.visible = true
	character_preview.configure(data)
	placeholder_label.visible = false
	tooltip_text = data.unit_name


func set_active(active: bool) -> void:
	active_indicator.visible = active
	frame.modulate = Color(1.08, 1.04, 0.84, 1.0) if active else Color(0.72, 0.74, 0.78, 0.9)
