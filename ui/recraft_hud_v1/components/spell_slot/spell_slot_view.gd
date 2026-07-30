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
@onready var selection_overlay: Panel = %SelectionOverlay
@onready var hover_overlay: ColorRect = %HoverOverlay
@onready var disabled_overlay: ColorRect = %DisabledOverlay
@onready var cooldown_overlay: ColorRect = %CooldownOverlay
@onready var cooldown_label: Label = %CooldownLabel
@onready var cost_icon: Label = %CostIcon
@onready var cost_label: Label = %CostLabel
@onready var cost_badge: Panel = %CostBadge
@onready var energy_cost_badge: Panel = %EnergyCostBadge
@onready var energy_cost_label: Label = %EnergyCostLabel
@onready var shortcut_label: Label = %ShortcutLabel
@onready var lock_icon: Label = %LockIcon
@onready var imprint_label: Label = %ImprintLabel
@onready var fallback_label: Label = %FallbackLabel

var visual_state := VisualState.NORMAL
var spell = null
var imprinted := false
var _hovered := false
var _icon_override: Texture2D = null
var _default_frame_texture: Texture2D = null


func _ready() -> void:
	_default_frame_texture = frame.texture
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
	custom_minimum_size = Vector2(
		visual_size,
		visual_size + shortcut_height
	)
	var icon_inset := roundf((visual_size - icon_size) * 0.5)
	shortcut_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shortcut_label.offset_bottom = shortcut_height
	visual_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visual_area.offset_top = shortcut_height
	for icon_control in [background, spell_icon, fallback_label]:
		icon_control.offset_left = icon_inset
		icon_control.offset_top = icon_inset
		icon_control.offset_right = -icon_inset
		icon_control.offset_bottom = -icon_inset
	var cost_size := METRICS.scaled_vector(
		METRICS.SPELL_COST_BADGE_SIZE,
		text_scale
	)
	cost_badge.offset_left = -cost_size.x
	cost_badge.offset_top = -cost_size.y
	var energy_size := METRICS.scaled_vector(
		METRICS.SPELL_ENERGY_BADGE_SIZE,
		text_scale
	)
	energy_cost_badge.offset_top = -energy_size.y
	energy_cost_badge.offset_right = energy_size.x
	shortcut_label.add_theme_font_size_override(
		"font_size",
		METRICS.scaled_font(METRICS.SHORTCUT_FONT_SIZE, text_scale)
	)
	cost_label.add_theme_font_size_override(
		"font_size",
		METRICS.scaled_font(METRICS.COST_FONT_SIZE, text_scale)
	)
	energy_cost_label.add_theme_font_size_override(
		"font_size",
		METRICS.scaled_font(METRICS.SECONDARY_FONT_SIZE, text_scale)
	)
	cost_icon.add_theme_font_size_override(
		"font_size", METRICS.scaled_font(8, text_scale)
	)
	imprint_label.add_theme_font_size_override(
		"font_size",
		METRICS.scaled_font(METRICS.SECONDARY_FONT_SIZE, text_scale)
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
	energy_cost: float = 0.0,
	energy_name: String = "",
	shortcut: String = "",
	is_imprinted: bool = false
) -> void:
	spell = new_spell
	imprinted = is_imprinted
	_icon_override = null
	_refresh_icon()
	fallback_label.text = _fallback_text()
	cost_icon.text = "PA"
	cost_label.text = str(maxi(ap_cost, 0))
	var energy_abbreviation := energy_name.left(1).to_upper()
	energy_cost_label.text = (
		"%d%s" % [int(energy_cost), energy_abbreviation]
		if energy_cost > 0.0
		else ""
	)
	energy_cost_badge.visible = energy_cost > 0.0
	shortcut_label.text = shortcut
	imprint_label.visible = imprinted
	tooltip_text = ""
	accessibility_name = _accessible_description(ap_cost, energy_cost, energy_name)


func set_icon_override(texture: Texture2D) -> void:
	_icon_override = texture
	_refresh_icon()


func get_displayed_icon() -> Texture2D:
	return spell_icon.texture


func set_frame_override(texture: Texture2D) -> void:
	frame.texture = texture if texture != null else _default_frame_texture


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
	hover_overlay.visible = hovered and not selected
	disabled_overlay.visible = visual_state in [VisualState.DISABLED, VisualState.UNAFFORDABLE]
	cooldown_overlay.visible = visual_state == VisualState.COOLDOWN
	cooldown_label.visible = visual_state == VisualState.COOLDOWN
	lock_icon.visible = visual_state == VisualState.LOCKED
	disabled_overlay.color = (
		Color(0.42, 0.06, 0.06, 0.62)
		if visual_state == VisualState.UNAFFORDABLE
		else Color(0.03, 0.04, 0.055, 0.68)
	)
	frame.modulate = (
		Color(1.12, 1.08, 0.82, 1.0)
		if selected
		else Color(0.52, 0.54, 0.58, 0.78)
		if disabled
		else Color.WHITE
	)
	spell_icon.modulate = Color(0.5, 0.5, 0.52, 0.78) if disabled else Color.WHITE
	var target_scale := Vector2(1.025, 1.025) if hovered or selected else Vector2.ONE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target_scale, 0.08)


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


func _accessible_description(ap_cost: int, energy_cost: float, energy_name: String) -> String:
	var display_name: String = spell.spell_name if spell != null else "Sort"
	var parts := ["%s, %d PA" % [display_name, ap_cost]]
	if energy_cost > 0.0:
		parts.append("%d %s" % [int(energy_cost), energy_name])
	if imprinted:
		parts.append("Empreinte")
	return ", ".join(parts)
