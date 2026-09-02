@tool
class_name HudVisualSkinData
extends Resource
## Tokens visuels partages par les composants du HUD de combat.
##
## Cette ressource decrit le langage visuel, sans connaitre la structure des
## scenes. Les composants consomment les couleurs, metriques, indices d'etat et
## timings dont ils ont besoin. Une palette neutre permet de valider la
## hierarchie avant de figer la direction coloree.

const INTERACTIVE_STATE_IDS: Array[StringName] = [
	&"normal",
	&"hover",
	&"focus",
	&"pressed",
	&"selected",
	&"selected_locked",
	&"cooldown",
	&"disabled",
	&"unavailable",
	&"resolving",
]

const MOTION_TOKEN_IDS: Array[StringName] = [
	&"instant",
	&"press",
	&"hover",
	&"selection",
	&"panel",
	&"feedback",
]

@export_category("Identity")
@export var skin_id: StringName = &"hud_neutral_v1"
@export var revision := 1
@export var neutral_grayscale := true

@export_category("Surfaces")
@export var surface_backdrop := Color(0.035, 0.035, 0.035, 0.96)
@export var surface_dock := Color(0.07, 0.07, 0.07, 0.96)
@export var surface_panel := Color(0.105, 0.105, 0.105, 0.98)
@export var surface_raised := Color(0.145, 0.145, 0.145, 1.0)
@export var surface_recessed := Color(0.045, 0.045, 0.045, 1.0)
@export var surface_scrim := Color(0.015, 0.015, 0.015, 0.88)

@export_category("Text and contrast")
@export var text_primary := Color(0.96, 0.96, 0.96, 1.0)
@export var text_secondary := Color(0.76, 0.76, 0.76, 1.0)
@export var text_muted := Color(0.56, 0.56, 0.56, 1.0)
@export var text_inverse := Color(0.04, 0.04, 0.04, 1.0)
@export_range(3.0, 7.0, 0.1) var minimum_body_contrast := 4.5
@export_range(3.0, 7.0, 0.1) var minimum_large_text_contrast := 3.0
@export_range(3.0, 7.0, 0.1) var minimum_focus_contrast := 3.0

@export_category("Borders")
@export var border_subtle_color := Color(0.20, 0.20, 0.20, 1.0)
@export var border_default_color := Color(0.34, 0.34, 0.34, 1.0)
@export var border_strong_color := Color(0.58, 0.58, 0.58, 1.0)
@export var border_focus_color := Color(0.97, 0.97, 0.97, 1.0)
@export var border_selected_color := Color(0.86, 0.86, 0.86, 1.0)
@export var border_locked_color := Color(0.72, 0.72, 0.72, 1.0)
@export var border_unavailable_color := Color(0.82, 0.82, 0.82, 1.0)
@export_range(1, 4, 1) var border_thin := 1
@export_range(1, 4, 1) var border_regular := 2
@export_range(1, 6, 1) var border_emphasis := 3
@export_range(2, 6, 1) var focus_ring_width := 3
@export_range(0, 6, 1) var focus_ring_offset := 2

@export_category("Geometry")
@export_range(0, 32, 1) var radius_tight := 4
@export_range(0, 32, 1) var radius_control := 6
@export_range(0, 32, 1) var radius_panel := 8
@export_range(0, 48, 1) var radius_modal := 12
@export_range(32, 999, 1) var radius_round := 999
@export_range(0, 24, 1) var shadow_size := 6
@export var shadow_offset := Vector2(0.0, 2.0)

@export_category("Spacing")
@export_range(0, 64, 1) var space_xxs := 2
@export_range(0, 64, 1) var space_xs := 4
@export_range(0, 64, 1) var space_sm := 6
@export_range(0, 64, 1) var space_md := 8
@export_range(0, 64, 1) var space_lg := 12
@export_range(0, 64, 1) var space_xl := 16
@export_range(0, 64, 1) var space_xxl := 24

@export_category("Typography")
@export var font_regular: Font
@export var font_emphasis: Font
@export var font_numeric: Font
@export_range(8, 48, 1) var font_size_caption := 11
@export_range(8, 48, 1) var font_size_shortcut := 12
@export_range(8, 48, 1) var font_size_body := 14
@export_range(8, 64, 1) var font_size_emphasis := 16
@export_range(8, 72, 1) var font_size_title := 18
@export_range(8, 96, 1) var font_size_display := 24
@export_range(1.0, 2.0, 0.05) var line_height_multiplier := 1.2
@export_range(0, 12, 1) var uppercase_tracking := 1

@export_category("Iconography")
@export var icon_move: Texture2D
@export var icon_end_turn: Texture2D
@export var icon_action_points: Texture2D
@export var icon_movement_points: Texture2D
@export var icon_cooldown: Texture2D
@export var icon_locked: Texture2D
@export var icon_unavailable: Texture2D
@export var icon_resolving: Texture2D
@export var icon_target_valid: Texture2D
@export var icon_target_invalid: Texture2D

@export_category("Motion")
@export_range(0.0, 0.5, 0.01) var motion_instant := 0.0
@export_range(0.0, 0.5, 0.01) var motion_press := 0.07
@export_range(0.0, 0.5, 0.01) var motion_hover := 0.09
@export_range(0.0, 0.5, 0.01) var motion_selection := 0.12
@export_range(0.0, 0.8, 0.01) var motion_panel := 0.16
@export_range(0.0, 0.8, 0.01) var motion_feedback := 0.18
@export_range(0.0, 0.1, 0.01) var reduced_motion_duration := 0.0
@export_range(1.0, 1.1, 0.001) var hover_scale := 1.015
@export_range(0.0, 8.0, 0.5) var hover_lift := 2.0
@export_range(0.0, 8.0, 0.5) var pressed_offset := 1.0

@export_category("Interactive state surfaces")
@export var state_normal_background := Color(0.145, 0.145, 0.145, 1.0)
@export var state_hover_background := Color(0.20, 0.20, 0.20, 1.0)
@export var state_focus_background := Color(0.18, 0.18, 0.18, 1.0)
@export var state_pressed_background := Color(0.09, 0.09, 0.09, 1.0)
@export var state_selected_background := Color(0.24, 0.24, 0.24, 1.0)
@export var state_selected_locked_background := Color(0.20, 0.20, 0.20, 1.0)
@export var state_cooldown_background := Color(0.065, 0.065, 0.065, 1.0)
@export var state_disabled_background := Color(0.055, 0.055, 0.055, 1.0)
@export var state_unavailable_background := Color(0.075, 0.075, 0.075, 1.0)
@export var state_resolving_background := Color(0.18, 0.18, 0.18, 1.0)
@export_range(0.0, 1.0, 0.01) var disabled_content_opacity := 0.62
@export_range(0.0, 1.0, 0.01) var cooldown_content_opacity := 0.74
@export_range(0.0, 1.0, 0.01) var locked_content_opacity := 0.82

@export_category("Non-color state cues")
@export var cue_normal: StringName = &"none"
@export var cue_hover: StringName = &"lift"
@export var cue_focus: StringName = &"outer_ring"
@export var cue_pressed: StringName = &"inset"
@export var cue_selected: StringName = &"double_rail"
@export var cue_selected_locked: StringName = &"double_rail_lock"
@export var cue_cooldown: StringName = &"radial_disc_countdown"
@export var cue_disabled: StringName = &"horizontal_bar"
@export var cue_unavailable: StringName = &"diagonal_cross"
@export var cue_resolving: StringName = &"double_rail_progress"


func has_state(state_id: StringName) -> bool:
	return state_id in INTERACTIVE_STATE_IDS


func state_background(state_id: StringName) -> Color:
	match state_id:
		&"hover":
			return state_hover_background
		&"focus":
			return state_focus_background
		&"pressed":
			return state_pressed_background
		&"selected":
			return state_selected_background
		&"selected_locked":
			return state_selected_locked_background
		&"cooldown":
			return state_cooldown_background
		&"disabled":
			return state_disabled_background
		&"unavailable":
			return state_unavailable_background
		&"resolving":
			return state_resolving_background
		_:
			return state_normal_background


func state_border(state_id: StringName) -> Color:
	match state_id:
		&"focus":
			return border_focus_color
		&"selected", &"resolving":
			return border_selected_color
		&"selected_locked", &"locked":
			return border_locked_color
		&"unavailable":
			return border_unavailable_color
		&"pressed", &"cooldown":
			return border_strong_color
		&"disabled":
			return border_subtle_color
		_:
			return border_default_color


func state_text(state_id: StringName) -> Color:
	if state_id in [&"disabled", &"cooldown"]:
		return text_muted
	return text_primary


func state_content_opacity(state_id: StringName) -> float:
	match state_id:
		&"disabled", &"unavailable":
			return disabled_content_opacity
		&"cooldown":
			return cooldown_content_opacity
		&"selected_locked", &"resolving":
			return locked_content_opacity
		_:
			return 1.0


func state_cue(state_id: StringName) -> StringName:
	match state_id:
		&"hover":
			return cue_hover
		&"focus":
			return cue_focus
		&"pressed":
			return cue_pressed
		&"selected":
			return cue_selected
		&"selected_locked":
			return cue_selected_locked
		&"cooldown":
			return cue_cooldown
		&"disabled":
			return cue_disabled
		&"unavailable":
			return cue_unavailable
		&"resolving":
			return cue_resolving
		_:
			return cue_normal


func state_icon(state_id: StringName) -> Texture2D:
	match state_id:
		&"cooldown":
			return icon_cooldown
		&"locked", &"selected_locked":
			return icon_locked
		&"disabled", &"unavailable":
			return icon_unavailable
		&"resolving":
			return icon_resolving
		_:
			return null


func target_icon(valid: bool) -> Texture2D:
	return icon_target_valid if valid else icon_target_invalid


func motion_duration(token_id: StringName, reduced_motion := false) -> float:
	if reduced_motion:
		return reduced_motion_duration
	match token_id:
		&"press":
			return motion_press
		&"hover":
			return motion_hover
		&"selection":
			return motion_selection
		&"panel":
			return motion_panel
		&"feedback":
			return motion_feedback
		_:
			return motion_instant


func uses_only_neutral_colors(tolerance := 0.001) -> bool:
	for color_value in _palette_colors():
		if (
			absf(color_value.r - color_value.g) > tolerance
			or absf(color_value.g - color_value.b) > tolerance
		):
			return false
	return true


func validation_issues() -> PackedStringArray:
	var issues := PackedStringArray()
	if skin_id == &"":
		issues.append("skin_id must not be empty")
	if revision < 1:
		issues.append("revision must be at least 1")
	if neutral_grayscale and not uses_only_neutral_colors():
		issues.append("neutral_grayscale is enabled but chromatic colors are present")
	if font_regular == null or font_emphasis == null or font_numeric == null:
		issues.append("regular, emphasis and numeric fonts must be assigned")
	if not _strictly_increasing([
		space_xxs, space_xs, space_sm, space_md, space_lg, space_xl, space_xxl,
	]):
		issues.append("spacing tokens must be strictly increasing")
	if not _strictly_increasing([
		font_size_caption,
		font_size_shortcut,
		font_size_body,
		font_size_emphasis,
		font_size_title,
		font_size_display,
	]):
		issues.append("typography tokens must be strictly increasing")
	if not _non_decreasing([radius_tight, radius_control, radius_panel, radius_modal]):
		issues.append("corner radius tokens must be non-decreasing")
	if not _non_decreasing([border_thin, border_regular, border_emphasis]):
		issues.append("border width tokens must be non-decreasing")
	if contrast_ratio(text_primary, surface_dock) < minimum_body_contrast:
		issues.append("primary text does not meet body contrast on the dock")
	if contrast_ratio(text_secondary, surface_dock) < minimum_body_contrast:
		issues.append("secondary text does not meet body contrast on the dock")
	if contrast_ratio(border_focus_color, surface_dock) < minimum_focus_contrast:
		issues.append("focus ring does not meet non-text contrast on the dock")
	if motion_press > motion_hover or motion_hover > motion_selection:
		issues.append("micro-interaction durations must follow press <= hover <= selection")
	if not is_zero_approx(reduced_motion_duration):
		issues.append("reduced motion duration must be zero")
	for state_id in INTERACTIVE_STATE_IDS:
		if state_cue(state_id) == &"":
			issues.append("state '%s' is missing a non-color cue" % state_id)
	return issues


static func contrast_ratio(foreground: Color, background: Color) -> float:
	var opaque_foreground := _composite_over(foreground, background)
	var lighter := maxf(
		_relative_luminance(opaque_foreground),
		_relative_luminance(background)
	)
	var darker := minf(
		_relative_luminance(opaque_foreground),
		_relative_luminance(background)
	)
	return (lighter + 0.05) / (darker + 0.05)


func _palette_colors() -> Array[Color]:
	return [
		surface_backdrop,
		surface_dock,
		surface_panel,
		surface_raised,
		surface_recessed,
		surface_scrim,
		text_primary,
		text_secondary,
		text_muted,
		text_inverse,
		border_subtle_color,
		border_default_color,
		border_strong_color,
		border_focus_color,
		border_selected_color,
		border_locked_color,
		border_unavailable_color,
		state_normal_background,
		state_hover_background,
		state_focus_background,
		state_pressed_background,
		state_selected_background,
		state_selected_locked_background,
		state_cooldown_background,
		state_disabled_background,
		state_unavailable_background,
		state_resolving_background,
	]


static func _strictly_increasing(values: Array) -> bool:
	for index in range(1, values.size()):
		if float(values[index]) <= float(values[index - 1]):
			return false
	return true


static func _non_decreasing(values: Array) -> bool:
	for index in range(1, values.size()):
		if float(values[index]) < float(values[index - 1]):
			return false
	return true


static func _composite_over(foreground: Color, background: Color) -> Color:
	return Color(
		foreground.r * foreground.a + background.r * (1.0 - foreground.a),
		foreground.g * foreground.a + background.g * (1.0 - foreground.a),
		foreground.b * foreground.a + background.b * (1.0 - foreground.a),
		1.0
	)


static func _relative_luminance(color_value: Color) -> float:
	return (
		0.2126 * _srgb_to_linear(color_value.r)
		+ 0.7152 * _srgb_to_linear(color_value.g)
		+ 0.0722 * _srgb_to_linear(color_value.b)
	)


static func _srgb_to_linear(channel: float) -> float:
	if channel <= 0.04045:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)
