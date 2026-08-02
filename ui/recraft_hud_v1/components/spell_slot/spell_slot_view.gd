class_name RecraftSpellSlotView
extends Button

const METRICS := preload("res://ui/recraft_hud_v1/theme/recraft_hud_metrics_v1.gd")

enum VisualState {
	NORMAL,
	HOVER,
	SELECTED,
	DISABLED,
	UNAFFORDABLE,
	COOLDOWN,
	LOCKED,
}

@onready var background: ColorRect = %Background
@onready var visual_area: Control = %VisualArea
@onready var spell_icon: TextureRect = %SpellIcon
@onready var frame: TextureRect = %Frame
@onready var refined_frame: Panel = %RefinedFrame
@onready var selection_overlay: Panel = %SelectionOverlay
@onready var hover_overlay: ColorRect = %HoverOverlay
@onready var disabled_overlay: ColorRect = %DisabledOverlay
@onready var cooldown_overlay: ColorRect = %CooldownOverlay
@onready var cooldown_label: Label = %CooldownLabel
@onready var cost_icon: Label = %CostIcon
@onready var cost_label: Label = %CostLabel
@onready var cost_badge: Panel = %CostBadge
@onready var shortcut_label: Label = %ShortcutLabel
@onready var lock_icon: Label = %LockIcon
@onready var fallback_label: Label = %FallbackLabel

var visual_state := VisualState.NORMAL
var spell = null
var _hovered := false
var _icon_override: Texture2D = null
var _default_frame_texture: Texture2D = null
var _refined_style := false
var _selection_intensity := 1.0
var _desaturation_intensity := 0.62
var _cooldown_opacity := 0.58
var _state_tween: Tween = null


func _ready() -> void:
	_default_frame_texture = frame.texture
	if spell_icon.material != null:
		spell_icon.material = spell_icon.material.duplicate()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_refresh_visuals)
	focus_exited.connect(_refresh_visuals)
	resized.connect(_update_pivot)
	apply_layout(1.0)
	_update_pivot()
	_refresh_visuals()


func apply_layout(scale_factor: float) -> void:
	apply_calibrated_layout(
		METRICS.scaled(METRICS.SPELL_VISUAL_SIZE, scale_factor),
		METRICS.scaled(METRICS.SPELL_ICON_SIZE, scale_factor),
		METRICS.scaled(METRICS.SPELL_SHORTCUT_HEIGHT, scale_factor),
		scale_factor
	)


func apply_calibrated_layout(
		visual_size: float,
		icon_size: float,
		shortcut_height: float,
		text_scale: float
	) -> void:
	visual_size = roundf(visual_size)
	icon_size = minf(roundf(icon_size), visual_size)
	shortcut_height = roundf(shortcut_height)
	custom_minimum_size = Vector2(visual_size, visual_size)
	var icon_inset := roundf((visual_size - icon_size) * 0.5)
	visual_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shortcut_label.position = Vector2(4.0, 4.0)
	shortcut_label.size = Vector2(26.0, 24.0)
	for icon_control in [background, spell_icon, fallback_label]:
		icon_control.offset_left = icon_inset
		icon_control.offset_top = icon_inset
		icon_control.offset_right = -icon_inset
		icon_control.offset_bottom = -icon_inset
	var cost_size := (Vector2(50.0, 24.0) * text_scale).round()
	cost_badge.offset_left = -cost_size.x
	cost_badge.offset_top = -cost_size.y
	shortcut_label.add_theme_font_size_override(
		"font_size",
		METRICS.scaled_font(16, text_scale)
	)
	cost_label.add_theme_font_size_override(
		"font_size",
		METRICS.scaled_font(15, text_scale)
	)
	cost_icon.add_theme_font_size_override(
		"font_size", METRICS.scaled_font(8, text_scale)
	)
	fallback_label.add_theme_font_size_override(
		"font_size", METRICS.scaled_font(24, text_scale)
	)
	cooldown_label.add_theme_font_size_override(
		"font_size", METRICS.scaled_font(22, text_scale)
	)
	lock_icon.add_theme_font_size_override(
		"font_size", METRICS.scaled_font(20, text_scale)
	)
	_update_pivot()


func configure(
	new_spell,
	ap_cost: int,
	shortcut: String = ""
) -> void:
	spell = new_spell
	_icon_override = null
	_refresh_icon()
	fallback_label.text = _fallback_text()
	cost_icon.text = ""
	cost_label.text = "%d PA" % maxi(ap_cost, 0)
	shortcut_label.text = shortcut
	tooltip_text = ""
	accessibility_name = _accessible_description(ap_cost)


func set_icon_override(texture: Texture2D) -> void:
	_icon_override = texture
	_refresh_icon()


func get_displayed_icon() -> Texture2D:
	return spell_icon.texture


func set_frame_override(texture: Texture2D) -> void:
	frame.texture = texture if texture != null else _default_frame_texture


func set_refined_style(enabled: bool) -> void:
	_refined_style = enabled
	frame.visible = not enabled
	refined_frame.visible = enabled
	_refresh_visuals()


func set_polish_tuning(
		selection_intensity: float = 1.0,
		desaturation_intensity: float = 0.62,
		cooldown_opacity: float = 0.58
	) -> void:
	_selection_intensity = clampf(selection_intensity, 0.0, 1.4)
	_desaturation_intensity = clampf(desaturation_intensity, 0.0, 1.0)
	_cooldown_opacity = clampf(cooldown_opacity, 0.2, 0.85)
	_refresh_visuals()


func _refresh_icon() -> void:
	if not is_node_ready():
		return
	var icon: Texture2D = _icon_override
	if icon == null and spell != null:
		icon = spell.icon
	spell_icon.texture = icon
	fallback_label.visible = icon == null


func set_visual_state(state: VisualState, cooldown_turns: int = 0) -> void:
	visual_state = state
	disabled = state in [
		VisualState.DISABLED,
		VisualState.UNAFFORDABLE,
		VisualState.COOLDOWN,
		VisualState.LOCKED,
	]
	cooldown_label.text = str(maxi(cooldown_turns, 1))
	_refresh_visuals()


func set_cooldown(turns: int) -> void:
	set_visual_state(VisualState.COOLDOWN if turns > 0 else VisualState.NORMAL, turns)


func set_locked(locked: bool) -> void:
	set_visual_state(VisualState.LOCKED if locked else VisualState.NORMAL)


func _refresh_visuals() -> void:
	if not is_node_ready():
		return
	var selected := visual_state == VisualState.SELECTED
	var hovered := _hovered and not disabled
	selection_overlay.visible = selected or has_focus()
	selection_overlay.modulate = Color(1.0, 1.0, 1.0, _selection_intensity)
	hover_overlay.visible = hovered and not selected
	disabled_overlay.visible = visual_state in [VisualState.DISABLED, VisualState.UNAFFORDABLE]
	cooldown_overlay.visible = visual_state == VisualState.COOLDOWN
	cooldown_overlay.color = Color(0.015, 0.02, 0.025, _cooldown_opacity)
	cooldown_label.visible = visual_state == VisualState.COOLDOWN
	lock_icon.visible = visual_state == VisualState.LOCKED
	disabled_overlay.color = Color(0.035, 0.04, 0.045, 0.6)
	frame.modulate = (
		Color(1.12, 1.08, 0.82, 1.0)
		if selected
		else Color(0.52, 0.54, 0.58, 0.78)
		if disabled
		else Color.WHITE
	)
	if not _refined_style:
		if spell_icon.material is ShaderMaterial:
			spell_icon.material.set_shader_parameter("saturation", 1.0)
			spell_icon.material.set_shader_parameter("brightness", 1.0)
		spell_icon.modulate = (
			Color(0.66, 0.66, 0.64, 0.86)
			if visual_state == VisualState.COOLDOWN
			else Color(0.42, 0.43, 0.44, 0.72)
			if disabled
			else Color(0.9, 0.9, 0.88, 1.0)
		)
		visual_area.position.y = 0.0
		scale = Vector2(1.015, 1.015) if hovered or selected else Vector2.ONE
		return
	spell_icon.modulate = Color.WHITE
	scale = Vector2.ONE
	var saturation := 0.9
	var brightness := 0.96
	if visual_state == VisualState.HOVER:
		saturation = 0.96
		brightness = 1.06
	elif selected:
		saturation = 0.95
		brightness = 1.03
	elif visual_state in [VisualState.DISABLED, VisualState.UNAFFORDABLE]:
		saturation = 1.0 - _desaturation_intensity
		brightness = 0.68
	elif visual_state == VisualState.COOLDOWN:
		saturation = 0.5
		brightness = 0.76
	if spell_icon.material is ShaderMaterial:
		spell_icon.material.set_shader_parameter("saturation", saturation)
		spell_icon.material.set_shader_parameter("brightness", brightness)
	cost_label.modulate = (
		Color(1.0, 0.58, 0.3, 1.0)
		if visual_state == VisualState.UNAFFORDABLE
		else Color.WHITE
	)
	cost_badge.modulate = (
		Color(1.0, 0.72, 0.55, 1.0)
		if visual_state == VisualState.UNAFFORDABLE
		else Color.WHITE
	)
	var target_y := -2.0 if selected else -1.0 if hovered else 0.0
	if _state_tween != null and _state_tween.is_valid():
		_state_tween.kill()
	_state_tween = create_tween()
	_state_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(visual_area, "position:y", target_y, 0.1)


func _on_mouse_entered() -> void:
	_hovered = true
	if visual_state == VisualState.NORMAL:
		visual_state = VisualState.HOVER
	_refresh_visuals()


func _on_mouse_exited() -> void:
	_hovered = false
	if visual_state == VisualState.HOVER:
		visual_state = VisualState.NORMAL
	_refresh_visuals()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _fallback_text() -> String:
	if spell == null:
		return "?"
	var display_name: String = spell.spell_name
	return display_name.left(1).to_upper() if not display_name.is_empty() else "?"


func _accessible_description(ap_cost: int) -> String:
	var display_name: String = spell.spell_name if spell != null else "Sort"
	return "%s, %d PA" % [display_name, ap_cost]
