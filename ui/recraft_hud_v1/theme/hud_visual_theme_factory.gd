class_name HudVisualThemeFactory
extends RefCounted
## Traduit les tokens HudVisualSkinData en Theme Godot partage.
##
## Les scenes gardent leur structure et leur layout, tandis que les couleurs,
## fontes, surfaces et etats viennent tous de la meme ressource de skin.


static func build(skin: HudVisualSkinData) -> Theme:
	var theme := Theme.new()
	if skin == null:
		return theme
	theme.default_font = skin.font_regular
	theme.default_font_size = skin.font_size_body
	theme.set_color(&"font_color", &"Label", skin.text_primary)
	theme.set_color(&"font_shadow_color", &"Label", skin.surface_scrim)
	theme.set_constant(&"shadow_offset_x", &"Label", 1)
	theme.set_constant(&"shadow_offset_y", &"Label", 1)
	theme.set_color(&"font_color", &"Button", skin.text_primary)
	theme.set_color(&"font_hover_color", &"Button", skin.text_primary)
	theme.set_color(&"font_focus_color", &"Button", skin.text_primary)
	theme.set_color(&"font_pressed_color", &"Button", skin.text_primary)
	theme.set_color(&"font_disabled_color", &"Button", skin.text_muted)

	_add_panel_variation(
		theme, skin, &"HudDockPanel", &"Panel", skin.surface_backdrop,
		skin.border_strong_color, skin.border_thin, skin.radius_panel, true
	)
	_add_panel_variation(
		theme, skin, &"HudIdentityPanel", &"Panel", skin.surface_panel,
		skin.border_default_color, skin.border_regular, skin.radius_panel, true
	)
	_add_panel_variation(
		theme, skin, &"HudActionPanel", &"Panel", skin.surface_dock,
		skin.border_default_color, skin.border_thin, skin.radius_panel, true
	)
	_add_panel_variation(
		theme, skin, &"HudResourcePanel", &"Panel", skin.surface_recessed,
		skin.border_default_color, skin.border_thin, skin.radius_control, false
	)
	_add_panel_variation(
		theme, skin, &"HudSurface", &"PanelContainer", skin.surface_panel,
		skin.border_default_color, skin.border_thin, skin.radius_panel, true
	)
	_add_panel_variation(
		theme, skin, &"HudTooltip", &"PanelContainer", skin.surface_panel,
		skin.border_strong_color, skin.border_regular, skin.radius_panel, true,
		skin.space_lg
	)
	_add_panel_variation(
		theme, skin, &"HudInspect", &"PanelContainer", skin.surface_backdrop,
		skin.border_default_color, skin.border_thin, skin.radius_modal, true,
		skin.space_lg
	)
	_add_panel_variation(
		theme, skin, &"HudLog", &"PanelContainer", skin.surface_backdrop,
		skin.border_default_color, skin.border_thin, skin.radius_panel, true,
		skin.space_md
	)

	var context_style := make_panel_style(
		skin,
		skin.surface_scrim,
		skin.border_strong_color,
		skin.border_thin,
		skin.radius_control,
		true,
		skin.space_md
	)
	context_style.border_width_left = skin.border_emphasis
	theme.set_type_variation(&"HudContextLabel", &"Label")
	theme.set_stylebox(&"normal", &"HudContextLabel", context_style)
	theme.set_font(&"font", &"HudContextLabel", skin.font_emphasis)
	theme.set_font_size(&"font_size", &"HudContextLabel", skin.font_size_emphasis)
	theme.set_color(&"font_color", &"HudContextLabel", skin.text_primary)

	_add_button_variation(theme, skin, &"HudPrimaryButton", skin.border_regular)
	_add_button_variation(theme, skin, &"HudUtilityButton", skin.border_thin)
	_add_button_variation(theme, skin, &"HudSpellSlot", skin.border_thin)

	_add_label_variation(
		theme, skin, &"HudEyebrow", skin.font_emphasis,
		skin.font_size_caption, skin.text_secondary
	)
	_add_label_variation(
		theme, skin, &"HudTitle", skin.font_emphasis,
		skin.font_size_title, skin.text_primary
	)
	_add_label_variation(
		theme, skin, &"HudBody", skin.font_regular,
		skin.font_size_body, skin.text_primary
	)
	_add_label_variation(
		theme, skin, &"HudMuted", skin.font_regular,
		skin.font_size_caption, skin.text_secondary
	)
	_add_label_variation(
		theme, skin, &"HudSection", skin.font_emphasis,
		skin.font_size_body, skin.text_primary
	)

	theme.set_type_variation(&"HudRichText", &"RichTextLabel")
	theme.set_font(&"normal_font", &"HudRichText", skin.font_regular)
	theme.set_font(&"bold_font", &"HudRichText", skin.font_emphasis)
	theme.set_font_size(&"normal_font_size", &"HudRichText", skin.font_size_body)
	theme.set_font_size(&"bold_font_size", &"HudRichText", skin.font_size_body)
	theme.set_color(&"default_color", &"HudRichText", skin.text_primary)

	var separator := StyleBoxLine.new()
	separator.color = skin.border_subtle_color
	separator.thickness = skin.border_thin
	theme.set_type_variation(&"HudSeparator", &"HSeparator")
	theme.set_stylebox(&"separator", &"HudSeparator", separator)
	return theme


static func make_panel_style(
		skin: HudVisualSkinData,
		background: Color,
		border: Color,
		border_width: int,
		radius: int,
		with_shadow := false,
		content_margin := 0
	) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	_set_borders(style, border_width, border)
	_set_radii(style, radius)
	if content_margin > 0:
		style.content_margin_left = content_margin
		style.content_margin_top = content_margin
		style.content_margin_right = content_margin
		style.content_margin_bottom = content_margin
	if with_shadow:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
		style.shadow_size = skin.shadow_size
		style.shadow_offset = skin.shadow_offset
	return style


static func make_control_style(
		skin: HudVisualSkinData,
		state_id: StringName,
		border_width: int = -1,
		radius: int = -1
	) -> StyleBoxFlat:
	var resolved_border := border_width if border_width >= 0 else skin.border_thin
	var resolved_radius := radius if radius >= 0 else skin.radius_control
	if state_id == &"focus":
		resolved_border = skin.focus_ring_width
	var style := make_panel_style(
		skin,
		skin.state_background(state_id),
		skin.state_border(state_id),
		resolved_border,
		resolved_radius,
		state_id in [&"normal", &"selected"]
	)
	return style


static func _add_panel_variation(
		theme: Theme,
		skin: HudVisualSkinData,
		variation: StringName,
		base_type: StringName,
		background: Color,
		border: Color,
		border_width: int,
		radius: int,
		with_shadow: bool,
		content_margin := 0
	) -> void:
	theme.set_type_variation(variation, base_type)
	theme.set_stylebox(
		&"panel",
		variation,
		make_panel_style(
			skin, background, border, border_width, radius,
			with_shadow, content_margin
		)
	)


static func _add_button_variation(
		theme: Theme,
		skin: HudVisualSkinData,
		variation: StringName,
		border_width: int
	) -> void:
	theme.set_type_variation(variation, &"Button")
	for state_id in [&"normal", &"hover", &"focus", &"pressed", &"disabled"]:
		theme.set_stylebox(
			state_id,
			variation,
			make_control_style(skin, state_id, border_width)
		)
	theme.set_font(&"font", variation, skin.font_emphasis)
	theme.set_font_size(&"font_size", variation, skin.font_size_body)
	theme.set_color(&"font_color", variation, skin.text_primary)
	theme.set_color(&"font_hover_color", variation, skin.text_primary)
	theme.set_color(&"font_focus_color", variation, skin.text_primary)
	theme.set_color(&"font_pressed_color", variation, skin.text_primary)
	theme.set_color(&"font_disabled_color", variation, skin.text_muted)


static func _add_label_variation(
		theme: Theme,
		skin: HudVisualSkinData,
		variation: StringName,
		font: Font,
		font_size: int,
		color: Color
	) -> void:
	theme.set_type_variation(variation, &"Label")
	theme.set_font(&"font", variation, font)
	theme.set_font_size(&"font_size", variation, font_size)
	theme.set_color(&"font_color", variation, color)


static func _set_borders(style: StyleBoxFlat, width: int, color: Color) -> void:
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.border_color = color


static func _set_radii(style: StyleBoxFlat, radius: int) -> void:
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
