class_name CharacterTurnIntroBanner
extends Control

const ENTER_DURATION := 0.30
const HOLD_DURATION := 1.40
const EXIT_DURATION := 0.30
const TEXTURE_RATIO := 468.0 / 1245.0

@onready var presentation: Control = %Presentation
@onready var banner_texture: TextureRect = %BannerTexture
@onready var portrait_view: RecraftPortraitView = %PortraitView
@onready var turn_label: Label = %TurnLabel
@onready var character_name_label: Label = %CharacterName
@onready var discipline_label: Label = %DisciplineName

var presentation_count := 0
var _active_tween: Tween
var _rest_position := Vector2.ZERO
var _last_unit_id := StringName()
var _last_presented_frame := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	if not resized.is_connected(_apply_responsive_layout):
		resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _exit_tree() -> void:
	if resized.is_connected(_apply_responsive_layout):
		resized.disconnect(_apply_responsive_layout)


func present(unit, theme: CharacterHUDThemeData) -> bool:
	if unit == null or theme == null or theme.turn_banner_texture == null:
		return false
	var frame := Engine.get_process_frames()
	var unit_id := StringName(unit.unit_id)
	if (
		unit_id == _last_unit_id
		and (frame == _last_presented_frame or visible)
	):
		return false
	_last_unit_id = unit_id
	_last_presented_frame = frame
	presentation_count += 1

	banner_texture.texture = theme.turn_banner_texture
	if theme.portrait_texture != null:
		portrait_view.set_portrait(theme.portrait_texture, unit.unit_name)
	else:
		portrait_view.set_character_data(unit.character_data)
	portrait_view.set_discipline_emblem(
		theme.discipline_emblem_texture,
		Color.WHITE
	)
	portrait_view.set_active(true)
	turn_label.text = _turn_title(String(unit.unit_name))
	character_name_label.text = (
		theme.display_name
		if not theme.display_name.is_empty()
		else String(unit.unit_name)
	)
	var discipline_parts: Array[String] = []
	if not theme.discipline_name.is_empty():
		discipline_parts.append(theme.discipline_name)
	if not theme.energy_name.is_empty():
		discipline_parts.append(theme.energy_name)
	discipline_label.text = " · ".join(discipline_parts)
	for label in [turn_label, character_name_label, discipline_label]:
		label.add_theme_color_override("font_color", theme.text_color)

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_apply_responsive_layout()
	presentation.position = _rest_position + Vector2(0.0, -28.0)
	presentation.modulate.a = 0.0
	visible = true
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(
		presentation, "modulate:a", 1.0, ENTER_DURATION
	)
	_active_tween.parallel().tween_property(
		presentation, "position", _rest_position, ENTER_DURATION
	)
	_active_tween.tween_interval(HOLD_DURATION)
	_active_tween.set_ease(Tween.EASE_IN)
	_active_tween.tween_property(
		presentation, "modulate:a", 0.0, EXIT_DURATION
	)
	_active_tween.parallel().tween_property(
		presentation,
		"position",
		_rest_position + Vector2(0.0, -12.0),
		EXIT_DURATION
	)
	_active_tween.tween_callback(_finish_presentation)
	return true


func hide_immediately() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_finish_presentation()


func total_animation_duration() -> float:
	return ENTER_DURATION + HOLD_DURATION + EXIT_DURATION


func get_presentation_size() -> Vector2:
	return presentation.size if is_instance_valid(presentation) else Vector2.ZERO


func _turn_title(character_name: String) -> String:
	var upper_name := character_name.to_upper()
	if (
		not upper_name.is_empty()
		and upper_name.left(1) in ["A", "E", "I", "O", "U", "Y", "É", "È", "Ê"]
	):
		return "TOUR DE L'%s" % upper_name
	return "TOUR DE %s" % upper_name


func _finish_presentation() -> void:
	visible = false
	presentation.modulate.a = 0.0


func _apply_responsive_layout() -> void:
	if not is_node_ready():
		return
	var available_height := maxf(size.y, 720.0)
	var available_width := maxf(size.x, 1280.0)
	var target_width := clampf(available_width * 0.19, 330.0, 420.0)
	var banner_height := minf(
		target_width / TEXTURE_RATIO,
		available_height * 0.72
	)
	var banner_width := banner_height * TEXTURE_RATIO
	presentation.anchor_left = 0.5
	presentation.anchor_top = 0.0
	presentation.anchor_right = 0.5
	presentation.anchor_bottom = 0.0
	var top_margin := clampf(available_height * 0.018, 12.0, 28.0)
	presentation.offset_left = -banner_width * 0.5
	presentation.offset_right = banner_width * 0.5
	presentation.offset_top = top_margin
	presentation.offset_bottom = top_margin + banner_height
	_rest_position = presentation.position
	var content_inset := banner_width * 0.12
	var top_inset := banner_height * 0.13
	var bottom_inset := banner_height * 0.18
	%Content.offset_left = content_inset
	%Content.offset_top = top_inset
	%Content.offset_right = -content_inset
	%Content.offset_bottom = -bottom_inset
	var portrait_size := clampf(banner_width * 0.36, 76.0, 112.0)
	portrait_view.custom_minimum_size = Vector2(portrait_size, portrait_size)
	portrait_view.apply_layout(portrait_size / 96.0)
	var text_scale := clampf(banner_width / 293.0, 0.9, 1.22)
	turn_label.add_theme_font_size_override(
		"font_size", maxi(int(round(18.0 * text_scale)), 16)
	)
	character_name_label.add_theme_font_size_override(
		"font_size", maxi(int(round(14.0 * text_scale)), 13)
	)
	discipline_label.add_theme_font_size_override(
		"font_size", maxi(int(round(11.0 * text_scale)), 10)
	)
