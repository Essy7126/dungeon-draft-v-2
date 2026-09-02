extends GutTest

const NEUTRAL_SKIN_PATH := "res://data/ui/hud_visual_skin_neutral_v1.tres"
const VisualThemeFactory := preload(
	"res://ui/recraft_hud_v1/theme/hud_visual_theme_factory.gd"
)
const REGULAR_FONT_PATH := (
	"res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/"
	+ "AtkinsonHyperlegible-Regular.otf"
)
const EMPHASIS_FONT_PATH := (
	"res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/"
	+ "AtkinsonHyperlegible-Bold.otf"
)
const ICON_ROOT := "res://asset/ui/recraft_hud_v1/icons/achilles_v1"
const EXPECTED_ICON_PATHS := {
	"icon_move": ICON_ROOT + "/action_move.svg",
	"icon_end_turn": ICON_ROOT + "/action_end_turn.svg",
	"icon_action_points": ICON_ROOT + "/resource_action_points.svg",
	"icon_movement_points": ICON_ROOT + "/resource_movement_points.svg",
	"icon_cooldown": ICON_ROOT + "/state_cooldown.svg",
	"icon_locked": ICON_ROOT + "/state_locked.svg",
	"icon_unavailable": ICON_ROOT + "/state_unavailable.svg",
	"icon_resolving": ICON_ROOT + "/state_resolving.svg",
	"icon_target_valid": ICON_ROOT + "/target_valid.svg",
	"icon_target_invalid": ICON_ROOT + "/target_invalid.svg",
}


func test_neutral_preset_loads_as_a_complete_typed_contract() -> void:
	var skin := load(NEUTRAL_SKIN_PATH) as HudVisualSkinData

	assert_not_null(skin)
	if skin == null:
		return
	assert_eq(skin.skin_id, &"hud_neutral_v1")
	assert_eq(skin.revision, 1)
	assert_not_null(skin.font_regular)
	assert_not_null(skin.font_emphasis)
	assert_not_null(skin.font_numeric)
	var issues := skin.validation_issues()
	assert_eq(issues.size(), 0, "\n".join(issues))


func test_neutral_preset_uses_embedded_font_files() -> void:
	var skin := load(NEUTRAL_SKIN_PATH) as HudVisualSkinData

	assert_not_null(skin)
	if skin == null:
		return
	assert_true(skin.font_regular is FontFile)
	assert_true(skin.font_emphasis is FontFile)
	assert_true(skin.font_numeric is FontFile)
	assert_eq(skin.font_regular.resource_path, REGULAR_FONT_PATH)
	assert_eq(skin.font_emphasis.resource_path, EMPHASIS_FONT_PATH)
	assert_same(skin.font_numeric, skin.font_regular)
	assert_gt((skin.font_regular as FontFile).data.size(), 0)
	assert_gt((skin.font_emphasis as FontFile).data.size(), 0)


func test_neutral_preset_integrates_every_semantic_icon() -> void:
	var skin := load(NEUTRAL_SKIN_PATH) as HudVisualSkinData

	assert_not_null(skin)
	if skin == null:
		return
	for property_name in EXPECTED_ICON_PATHS:
		var icon := skin.get(property_name) as Texture2D
		var expected_path := EXPECTED_ICON_PATHS[property_name] as String
		assert_not_null(icon, property_name)
		if icon == null:
			continue
		assert_eq(icon.resource_path, expected_path, property_name)
		assert_eq(icon.get_size(), Vector2(64.0, 64.0), property_name)

	assert_same(skin.state_icon(&"cooldown"), skin.icon_cooldown)
	assert_same(skin.state_icon(&"locked"), skin.icon_locked)
	assert_same(skin.state_icon(&"selected_locked"), skin.icon_locked)
	assert_same(skin.state_icon(&"disabled"), skin.icon_unavailable)
	assert_same(skin.state_icon(&"unavailable"), skin.icon_unavailable)
	assert_same(skin.state_icon(&"resolving"), skin.icon_resolving)
	assert_same(skin.target_icon(true), skin.icon_target_valid)
	assert_same(skin.target_icon(false), skin.icon_target_invalid)
	assert_null(skin.state_icon(&"normal"))


func test_neutral_preset_keeps_hierarchy_independent_from_hue() -> void:
	var skin := load(NEUTRAL_SKIN_PATH) as HudVisualSkinData

	assert_not_null(skin)
	if skin == null:
		return
	assert_true(skin.neutral_grayscale)
	assert_true(skin.uses_only_neutral_colors())
	assert_gt(skin.surface_raised.get_luminance(), skin.surface_dock.get_luminance())
	assert_gt(skin.surface_panel.get_luminance(), skin.surface_recessed.get_luminance())


func test_text_and_focus_tokens_meet_declared_contrast_thresholds() -> void:
	var skin := load(NEUTRAL_SKIN_PATH) as HudVisualSkinData

	assert_not_null(skin)
	if skin == null:
		return
	assert_gte(
		HudVisualSkinData.contrast_ratio(skin.text_primary, skin.surface_dock),
		skin.minimum_body_contrast
	)
	assert_gte(
		HudVisualSkinData.contrast_ratio(skin.text_secondary, skin.surface_dock),
		skin.minimum_body_contrast
	)
	assert_gte(
		HudVisualSkinData.contrast_ratio(skin.border_focus_color, skin.surface_dock),
		skin.minimum_focus_contrast
	)


func test_each_interactive_state_exposes_a_non_color_cue() -> void:
	var skin := load(NEUTRAL_SKIN_PATH) as HudVisualSkinData

	assert_not_null(skin)
	if skin == null:
		return
	for state_id in HudVisualSkinData.INTERACTIVE_STATE_IDS:
		assert_true(skin.has_state(state_id), str(state_id))
		assert_ne(skin.state_cue(state_id), &"", str(state_id))

	assert_ne(skin.state_cue(&"selected"), skin.state_cue(&"selected_locked"))
	assert_ne(skin.state_cue(&"disabled"), skin.state_cue(&"unavailable"))
	assert_ne(skin.state_cue(&"cooldown"), skin.state_cue(&"resolving"))
	assert_eq(skin.state_cue(&"focus"), &"outer_ring")


func test_motion_contract_is_short_and_has_a_strict_reduced_mode() -> void:
	var skin := load(NEUTRAL_SKIN_PATH) as HudVisualSkinData

	assert_not_null(skin)
	if skin == null:
		return
	assert_lte(skin.motion_duration(&"hover"), 0.12)
	assert_lte(skin.motion_duration(&"selection"), 0.12)
	assert_gt(skin.motion_duration(&"feedback"), skin.motion_duration(&"selection"))
	for token_id in HudVisualSkinData.MOTION_TOKEN_IDS:
		assert_almost_eq(skin.motion_duration(token_id, true), 0.0, 0.0001)


func test_theme_factory_builds_every_essential_hud_variation() -> void:
	var skin := load(NEUTRAL_SKIN_PATH) as HudVisualSkinData

	assert_not_null(skin)
	if skin == null:
		return
	var theme := VisualThemeFactory.build(skin)
	assert_not_null(theme)
	assert_same(theme.default_font, skin.font_regular)
	assert_eq(theme.default_font_size, skin.font_size_body)

	var expected_bases := {
		&"HudDockPanel": &"Panel",
		&"HudIdentityPanel": &"Panel",
		&"HudActionPanel": &"Panel",
		&"HudResourcePanel": &"Panel",
		&"HudSurface": &"PanelContainer",
		&"HudTooltip": &"PanelContainer",
		&"HudInspect": &"PanelContainer",
		&"HudLog": &"PanelContainer",
		&"HudContextLabel": &"Label",
		&"HudPrimaryButton": &"Button",
		&"HudUtilityButton": &"Button",
		&"HudSpellSlot": &"Button",
		&"HudEyebrow": &"Label",
		&"HudTitle": &"Label",
		&"HudBody": &"Label",
		&"HudMuted": &"Label",
		&"HudSection": &"Label",
		&"HudRichText": &"RichTextLabel",
		&"HudSeparator": &"HSeparator",
	}
	for variation in expected_bases:
		assert_eq(
			theme.get_type_variation_base(variation),
			expected_bases[variation],
			str(variation)
		)

	_assert_panel_variation(
		theme,
		skin,
		&"HudTooltip",
		skin.surface_panel,
		skin.border_strong_color,
		skin.border_regular,
		skin.radius_panel,
		skin.space_lg
	)
	_assert_panel_variation(
		theme,
		skin,
		&"HudInspect",
		skin.surface_backdrop,
		skin.border_default_color,
		skin.border_thin,
		skin.radius_modal,
		skin.space_lg
	)
	_assert_panel_variation(
		theme,
		skin,
		&"HudLog",
		skin.surface_backdrop,
		skin.border_default_color,
		skin.border_thin,
		skin.radius_panel,
		skin.space_md
	)
	assert_true(theme.has_stylebox(&"normal", &"HudPrimaryButton"))
	assert_true(theme.has_stylebox(&"hover", &"HudUtilityButton"))
	assert_true(theme.has_stylebox(&"disabled", &"HudSpellSlot"))
	assert_same(theme.get_font(&"font", &"HudTitle"), skin.font_emphasis)
	assert_same(
		theme.get_font(&"normal_font", &"HudRichText"),
		skin.font_regular
	)
	assert_same(
		theme.get_font(&"bold_font", &"HudRichText"),
		skin.font_emphasis
	)
	assert_true(theme.has_stylebox(&"separator", &"HudSeparator"))
	assert_true(theme.get_stylebox(
		&"separator", &"HudSeparator"
	) is StyleBoxLine)


func _assert_panel_variation(
		theme: Theme,
		skin: HudVisualSkinData,
		variation: StringName,
		expected_background: Color,
		expected_border: Color,
		expected_border_width: int,
		expected_radius: int,
		expected_margin: int
	) -> void:
	assert_true(theme.has_stylebox(&"panel", variation), str(variation))
	var style := theme.get_stylebox(&"panel", variation) as StyleBoxFlat
	assert_not_null(style, str(variation))
	if style == null:
		return
	assert_eq(style.bg_color, expected_background, str(variation))
	assert_eq(style.border_color, expected_border, str(variation))
	assert_eq(style.border_width_left, expected_border_width, str(variation))
	assert_eq(style.border_width_top, expected_border_width, str(variation))
	assert_eq(style.border_width_right, expected_border_width, str(variation))
	assert_eq(style.border_width_bottom, expected_border_width, str(variation))
	for radius in [
		style.corner_radius_top_left,
		style.corner_radius_top_right,
		style.corner_radius_bottom_left,
		style.corner_radius_bottom_right,
	]:
		assert_eq(radius, expected_radius, str(variation))
	assert_eq(style.shadow_color, Color(0.0, 0.0, 0.0, 0.52), str(variation))
	assert_eq(style.shadow_size, skin.shadow_size, str(variation))
	assert_eq(style.shadow_offset, skin.shadow_offset, str(variation))
	for margin in [
		style.content_margin_left,
		style.content_margin_top,
		style.content_margin_right,
		style.content_margin_bottom,
	]:
		assert_almost_eq(
			margin,
			float(expected_margin),
			0.001,
			str(variation)
		)
