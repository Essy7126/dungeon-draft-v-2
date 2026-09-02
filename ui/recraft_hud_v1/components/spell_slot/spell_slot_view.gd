class_name RecraftSpellSlotView
extends Button

const METRICS := preload("res://ui/recraft_hud_v1/theme/recraft_hud_metrics_v1.gd")
const VISUAL_THEME_FACTORY := preload(
	"res://ui/recraft_hud_v1/theme/hud_visual_theme_factory.gd"
)

enum VisualState {
	NORMAL,
	HOVER,
	SELECTED,
	DISABLED,
	UNAFFORDABLE,
	COOLDOWN,
	LOCKED,
	SELECTED_LOCKED,
}

@onready var background: ColorRect = %Background
@onready var visual_area: Control = %VisualArea
@onready var spell_icon: TextureRect = %SpellIcon
@onready var frame: TextureRect = %Frame
@onready var refined_frame: Panel = %RefinedFrame
@onready var selection_overlay: Panel = %SelectionOverlay
@onready var focus_overlay: Panel = %FocusOverlay
@onready var hover_overlay: ColorRect = %HoverOverlay
@onready var hover_rail: ColorRect = %HoverRail
@onready var disabled_overlay: ColorRect = %DisabledOverlay
@onready var disabled_bar: ColorRect = %DisabledBar
@onready var unavailable_cross_a: ColorRect = %UnavailableCrossA
@onready var unavailable_cross_b: ColorRect = %UnavailableCrossB
@onready var cooldown_overlay: ColorRect = %CooldownOverlay
@onready var cooldown_disc: Panel = %CooldownDisc
@onready var cooldown_glyph: TextureRect = %CooldownGlyph
@onready var cooldown_label: Label = %CooldownLabel
@onready var state_glyph: TextureRect = %StateGlyph
@onready var selected_marker: ColorRect = %SelectedMarker
@onready var cost_icon: TextureRect = %CostIcon
@onready var cost_label: Label = %CostLabel
@onready var cost_badge: Panel = %CostBadge
@onready var shortcut_label: Label = %ShortcutLabel
@onready var lock_icon: TextureRect = %LockIcon
@onready var lock_rail_left: ColorRect = %LockRailLeft
@onready var lock_rail_right: ColorRect = %LockRailRight
@onready var fallback_label: Label = %FallbackLabel

var visual_state := VisualState.NORMAL
var spell = null
var _hovered := false
var _icon_override: Texture2D = null
var _default_frame_texture: Texture2D = null
var _has_custom_frame := false
var _refined_style := false
var _selection_intensity := 1.0
var _desaturation_intensity := 0.62
var _cooldown_opacity := 0.58
var _state_tween: Tween = null
var _reduced_motion := false
var _cooldown_turns := 0
var _ap_cost := 0
var _motion_target_y := 0.0
var _motion_target_scale := Vector2.ONE
var _visual_skin: HudVisualSkinData = null
var _state_styles: Dictionary = {}


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
	fallback_label.add_theme_font_size_override(
		"font_size", METRICS.scaled_font(24, text_scale)
	)
	cooldown_label.add_theme_font_size_override(
		"font_size", METRICS.scaled_font(17, text_scale)
	)
	var cross_span := minf(46.0, visual_size * 0.72)
	for cross_line in [unavailable_cross_a, unavailable_cross_b]:
		cross_line.offset_left = -cross_span * 0.5
		cross_line.offset_right = cross_span * 0.5
		cross_line.pivot_offset = Vector2(cross_span * 0.5, 1.5)
	_update_pivot()


func configure(
	new_spell,
	ap_cost: int,
	shortcut: String = ""
	) -> void:
	spell = new_spell
	_ap_cost = maxi(ap_cost, 0)
	_icon_override = null
	_refresh_icon()
	fallback_label.text = _fallback_text()
	cost_label.text = str(_ap_cost)
	cost_icon.texture = (
		_visual_skin.icon_action_points if _visual_skin != null else null
	)
	cost_icon.visible = cost_icon.texture != null
	shortcut_label.text = shortcut
	tooltip_text = ""
	_update_accessibility_name()


func set_icon_override(texture: Texture2D) -> void:
	_icon_override = texture
	_refresh_icon()


func get_displayed_icon() -> Texture2D:
	return spell_icon.texture


func set_frame_override(texture: Texture2D) -> void:
	_has_custom_frame = texture != null
	frame.texture = texture if texture != null else _default_frame_texture


func set_refined_style(enabled: bool) -> void:
	_refined_style = enabled
	frame.visible = not enabled or _has_custom_frame
	refined_frame.visible = enabled and not _has_custom_frame
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


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	_refresh_visuals()


func is_reduced_motion_enabled() -> bool:
	return _reduced_motion


func apply_visual_skin(skin: HudVisualSkinData) -> void:
	_visual_skin = skin
	_state_styles.clear()
	if skin == null:
		_refresh_visuals()
		return
	for state_id in HudVisualSkinData.INTERACTIVE_STATE_IDS:
		_state_styles[state_id] = VISUAL_THEME_FACTORY.make_control_style(
			skin, state_id, skin.border_thin, skin.radius_control
		)
	var selection_style := VISUAL_THEME_FACTORY.make_control_style(
		skin, &"selected", skin.border_emphasis, skin.radius_control
	)
	selection_overlay.add_theme_stylebox_override("panel", selection_style)
	var focus_style := VISUAL_THEME_FACTORY.make_control_style(
		skin,
		&"focus",
		skin.focus_ring_width,
		skin.radius_control + skin.focus_ring_offset
	)
	focus_style.draw_center = false
	focus_overlay.add_theme_stylebox_override("panel", focus_style)
	refined_frame.add_theme_stylebox_override(
		"panel", _state_styles.get(_visual_state_id())
	)
	cost_badge.add_theme_stylebox_override(
		"panel",
		VISUAL_THEME_FACTORY.make_panel_style(
			skin,
			skin.surface_recessed,
			skin.border_default_color,
			skin.border_thin,
			skin.radius_tight
		)
	)
	shortcut_label.add_theme_stylebox_override(
		"normal",
		VISUAL_THEME_FACTORY.make_panel_style(
			skin,
			skin.surface_recessed,
			skin.border_default_color,
			skin.border_thin,
			skin.radius_tight
		)
	)
	cooldown_disc.add_theme_stylebox_override(
		"panel",
		VISUAL_THEME_FACTORY.make_panel_style(
			skin,
			skin.surface_scrim,
			skin.border_strong_color,
			skin.border_regular,
			skin.radius_round
		)
	)
	shortcut_label.add_theme_font_override("font", skin.font_emphasis)
	shortcut_label.add_theme_color_override("font_color", skin.text_primary)
	cost_label.add_theme_font_override("font", skin.font_numeric)
	cost_label.add_theme_color_override("font_color", skin.text_primary)
	cooldown_label.add_theme_font_override("font", skin.font_numeric)
	cooldown_label.add_theme_color_override("font_color", skin.text_primary)
	fallback_label.add_theme_font_override("font", skin.font_emphasis)
	fallback_label.add_theme_color_override("font_color", skin.text_secondary)
	cost_icon.texture = skin.icon_action_points
	cost_icon.visible = cost_icon.texture != null
	cooldown_glyph.texture = skin.icon_cooldown
	lock_icon.texture = skin.icon_locked
	selected_marker.color = skin.border_selected_color
	hover_rail.color = skin.border_focus_color
	disabled_bar.color = skin.border_unavailable_color
	unavailable_cross_a.color = skin.border_unavailable_color
	unavailable_cross_b.color = skin.border_unavailable_color
	lock_rail_left.color = skin.border_locked_color
	lock_rail_right.color = skin.border_locked_color
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
	_cooldown_turns = maxi(cooldown_turns, 0)
	disabled = state in [
		VisualState.DISABLED,
		VisualState.UNAFFORDABLE,
		VisualState.COOLDOWN,
		VisualState.LOCKED,
		VisualState.SELECTED_LOCKED,
	]
	cooldown_label.text = str(maxi(_cooldown_turns, 1))
	_update_accessibility_name()
	_refresh_visuals()


func set_cooldown(turns: int) -> void:
	set_visual_state(VisualState.COOLDOWN if turns > 0 else VisualState.NORMAL, turns)


func set_locked(locked: bool) -> void:
	set_visual_state(VisualState.LOCKED if locked else VisualState.NORMAL)


func set_selected_locked(locked: bool) -> void:
	set_visual_state(
		VisualState.SELECTED_LOCKED if locked else VisualState.SELECTED
	)


func _refresh_visuals() -> void:
	if not is_node_ready():
		return
	var selected := visual_state in [VisualState.SELECTED, VisualState.SELECTED_LOCKED]
	var hovered := _hovered and not disabled
	var focused := has_focus()
	var locked := visual_state in [VisualState.LOCKED, VisualState.SELECTED_LOCKED]
	selection_overlay.visible = selected
	selection_overlay.modulate = Color(1.0, 1.0, 1.0, _selection_intensity)
	focus_overlay.visible = focused
	hover_overlay.visible = hovered and not selected
	hover_rail.visible = hovered and not selected
	selected_marker.visible = selected
	disabled_overlay.visible = visual_state in [VisualState.DISABLED, VisualState.UNAFFORDABLE]
	disabled_bar.visible = visual_state == VisualState.DISABLED
	unavailable_cross_a.visible = visual_state == VisualState.UNAFFORDABLE
	unavailable_cross_b.visible = visual_state == VisualState.UNAFFORDABLE
	cooldown_overlay.visible = visual_state == VisualState.COOLDOWN
	cooldown_overlay.color = Color(0.02, 0.02, 0.02, _cooldown_opacity)
	cooldown_disc.visible = visual_state == VisualState.COOLDOWN
	cooldown_glyph.visible = visual_state == VisualState.COOLDOWN
	cooldown_label.visible = visual_state == VisualState.COOLDOWN
	lock_icon.visible = locked
	lock_rail_left.visible = locked
	lock_rail_right.visible = locked
	state_glyph.visible = visual_state == VisualState.UNAFFORDABLE
	state_glyph.texture = (
		_visual_skin.icon_unavailable if _visual_skin != null else null
	)
	disabled_overlay.color = Color(0.04, 0.04, 0.04, 0.6)
	if _visual_skin != null:
		var state_id := _visual_state_id()
		background.color = _visual_skin.state_background(state_id)
		refined_frame.add_theme_stylebox_override(
			"panel", _state_styles.get(state_id)
		)
		cooldown_overlay.color = _visual_skin.surface_scrim
		disabled_overlay.color = Color(
			_visual_skin.surface_scrim.r,
			_visual_skin.surface_scrim.g,
			_visual_skin.surface_scrim.b,
			0.62
		)
	frame.modulate = (
		Color(1.08, 1.08, 1.08, 1.0)
		if selected
		else Color(0.5, 0.5, 0.5, 0.72)
		if disabled
		else Color.WHITE
	)
	refined_frame.modulate = (
		Color(1.15, 1.15, 1.15, 1.0)
		if selected
		else Color(0.62, 0.62, 0.62, 0.8)
		if disabled
		else Color.WHITE
	)
	if not _refined_style:
		if spell_icon.material is ShaderMaterial:
			spell_icon.material.set_shader_parameter("saturation", 1.0)
			spell_icon.material.set_shader_parameter("brightness", 1.0)
		spell_icon.modulate = (
			Color(0.66, 0.66, 0.66, 0.86)
			if visual_state == VisualState.COOLDOWN
			else Color(0.43, 0.43, 0.43, 0.72)
			if disabled
			else Color(0.9, 0.9, 0.9, 1.0)
		)
		_animate_state_transform(selected, hovered, focused)
		return
	spell_icon.modulate = Color.WHITE
	var saturation := (
		1.0
		if _visual_skin != null and not _visual_skin.neutral_grayscale
		else 0.14
	)
	var brightness := 0.96
	if visual_state == VisualState.HOVER:
		brightness = 1.06
	elif selected:
		brightness = 1.03
	elif visual_state in [VisualState.DISABLED, VisualState.UNAFFORDABLE]:
		saturation *= 1.0 - _desaturation_intensity
		brightness = 0.68
	elif visual_state == VisualState.COOLDOWN:
		saturation = 0.04
		brightness = 0.76
	elif visual_state in [VisualState.LOCKED, VisualState.SELECTED_LOCKED]:
		saturation = 0.0
		brightness = 0.62
	if spell_icon.material is ShaderMaterial:
		spell_icon.material.set_shader_parameter("saturation", saturation)
		spell_icon.material.set_shader_parameter("brightness", brightness)
	cost_label.modulate = (
		Color(1.0, 1.0, 1.0, 1.0)
		if visual_state == VisualState.UNAFFORDABLE
		else Color(0.86, 0.86, 0.86, 1.0)
	)
	cost_badge.modulate = (
		Color(1.18, 1.18, 1.18, 1.0)
		if visual_state == VisualState.UNAFFORDABLE
		else Color.WHITE
	)
	_animate_state_transform(selected, hovered, focused)


func _animate_state_transform(selected: bool, hovered: bool, focused: bool) -> void:
	var hover_lift := _visual_skin.hover_lift if _visual_skin != null else 1.0
	var target_y := -hover_lift * 1.5 if selected else -hover_lift if hovered or focused else 0.0
	var target_scale := (
		Vector2.ONE * (
			minf((_visual_skin.hover_scale if _visual_skin != null else 1.015) + 0.01, 1.04)
		)
		if selected
		else Vector2.ONE * (
			_visual_skin.hover_scale if _visual_skin != null else 1.012
		)
		if hovered
		else Vector2.ONE
	)
	if (
		is_equal_approx(_motion_target_y, target_y)
		and _motion_target_scale.is_equal_approx(target_scale)
		and _state_tween != null
		and _state_tween.is_valid()
	):
		return
	_motion_target_y = target_y
	_motion_target_scale = target_scale
	if _state_tween != null and _state_tween.is_valid():
		_state_tween.kill()
	_state_tween = null
	if _reduced_motion:
		visual_area.position.y = 0.0
		scale = Vector2.ONE
		return
	_state_tween = create_tween()
	_state_tween.set_parallel(true)
	_state_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var duration := (
		_visual_skin.motion_duration(&"selection" if selected else &"hover", _reduced_motion)
		if _visual_skin != null
		else 0.11
	)
	_state_tween.tween_property(visual_area, "position:y", target_y, duration)
	_state_tween.tween_property(self, "scale", target_scale, duration)


func _visual_state_id() -> StringName:
	match visual_state:
		VisualState.HOVER:
			return &"hover"
		VisualState.SELECTED:
			return &"selected"
		VisualState.DISABLED:
			return &"disabled"
		VisualState.UNAFFORDABLE:
			return &"unavailable"
		VisualState.COOLDOWN:
			return &"cooldown"
		VisualState.LOCKED:
			return &"selected_locked"
		VisualState.SELECTED_LOCKED:
			return &"resolving"
		_:
			return &"normal"


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


func _update_accessibility_name() -> void:
	if not is_node_ready():
		return
	var state_description := ""
	match visual_state:
		VisualState.SELECTED:
			state_description = ", sélectionné"
		VisualState.DISABLED:
			state_description = ", indisponible"
		VisualState.UNAFFORDABLE:
			state_description = ", PA insuffisants"
		VisualState.COOLDOWN:
			state_description = ", récupération, %d tour(s)" % maxi(_cooldown_turns, 1)
		VisualState.LOCKED:
			state_description = ", verrouillé"
		VisualState.SELECTED_LOCKED:
			state_description = ", sélectionné, résolution en cours"
	accessibility_name = _accessible_description(_ap_cost) + state_description


func get_visual_cue_snapshot() -> Dictionary:
	return {
		"state": visual_state,
		"hover": hover_rail.visible,
		"focus": focus_overlay.visible,
		"selected": selection_overlay.visible and selected_marker.visible,
		"disabled_bar": disabled_bar.visible,
		"unavailable_cross": unavailable_cross_a.visible and unavailable_cross_b.visible,
		"cooldown_disc": cooldown_disc.visible,
		"locked_rails": lock_rail_left.visible and lock_rail_right.visible,
		"reduced_motion": _reduced_motion,
	}
