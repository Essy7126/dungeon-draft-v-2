class_name RecraftPortraitView
extends Control

const METRICS := preload("res://ui/recraft_hud_v1/theme/recraft_hud_metrics_v1.gd")
const VISUAL_THEME_FACTORY := preload(
	"res://ui/recraft_hud_v1/theme/hud_visual_theme_factory.gd"
)

@onready var portrait_texture: TextureRect = %PortraitTexture
@onready var character_preview: CharacterPreview3D = %CharacterPreview
@onready var frame: TextureRect = %Frame
@onready var active_indicator: Panel = %ActiveIndicator
@onready var placeholder_label: Label = %PlaceholderLabel
@onready var discipline_emblem: TextureRect = %DisciplineEmblem

var character_data: UnitData = null
var _default_frame_texture: Texture2D = null
var _has_custom_frame := false
var _discipline_emblem_scale := 1.0
var _visual_skin: HudVisualSkinData = null


func _ready() -> void:
	_default_frame_texture = frame.texture
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
	var emblem_size := METRICS.scaled(
		36.0 * _discipline_emblem_scale,
		scale_factor
	)
	discipline_emblem.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	discipline_emblem.offset_left = -emblem_size - indicator_inset
	discipline_emblem.offset_top = -emblem_size - indicator_inset
	discipline_emblem.offset_right = -indicator_inset
	discipline_emblem.offset_bottom = -indicator_inset


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
	if _visual_skin != null:
		frame.modulate = (
			_visual_skin.text_primary
			if active
			else Color(
				_visual_skin.text_secondary.r,
				_visual_skin.text_secondary.g,
				_visual_skin.text_secondary.b,
				0.9
			)
		)
		return
	frame.modulate = Color(1.08, 1.04, 0.84, 1.0) if active else Color(0.72, 0.74, 0.78, 0.9)


func set_portrait_frame(texture: Texture2D) -> void:
	_has_custom_frame = texture != null
	frame.texture = texture if texture != null else _default_frame_texture
	frame.visible = true


func set_refined_style(enabled: bool) -> void:
	frame.visible = not enabled or _has_custom_frame


func apply_visual_skin(skin: HudVisualSkinData) -> void:
	_visual_skin = skin
	if skin == null:
		return
	active_indicator.add_theme_stylebox_override(
		"panel",
		VISUAL_THEME_FACTORY.make_panel_style(
			skin,
			Color.TRANSPARENT,
			skin.border_focus_color,
			skin.border_regular,
			skin.radius_round if not skin.neutral_grayscale else skin.radius_control
		)
	)
	placeholder_label.add_theme_font_override("font", skin.font_emphasis)
	placeholder_label.add_theme_color_override("font_color", skin.text_secondary)
	discipline_emblem.modulate = skin.text_primary
	set_active(active_indicator.visible)


func set_discipline_emblem(
		texture: Texture2D,
		accent_color := Color.WHITE,
		size_scale := 1.0
	) -> void:
	_discipline_emblem_scale = clampf(size_scale, 0.5, 1.0)
	discipline_emblem.texture = texture
	discipline_emblem.visible = texture != null
	discipline_emblem.modulate = (
		_visual_skin.text_primary
		if _visual_skin != null and _visual_skin.neutral_grayscale
		else accent_color
	)
	if is_node_ready():
		var current_scale := (
			custom_minimum_size.x / METRICS.PORTRAIT_SIZE
			if custom_minimum_size.x > 0.0
			else 1.0
		)
		apply_layout(current_scale)
