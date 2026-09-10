class_name GameUIChrome
extends RefCounted
## Shared game palette and original nine-slice chrome, independent of game state.

const CHROME_ROOT := "res://assets/catabase/chrome/"
const INK := Color("100f0e")
const PANEL := Color("211c18")
const BRONZE := Color("8b714c")
const GOLD := Color("d6c29a")
const TEXT := Color("eee5d2")
const MUTED := Color("b7a58d")
const TEAL := Color("8fb9bf")
const DANGER := Color("e29b85")


static func style(kind: String, state: String = "normal") -> StyleBox:
	var control := kind in ["button", "tab", "slot"]
	var horizontal := 14.0 if control else 48.0 if kind == "banner" else 40.0 if kind == "panel" else 18.0
	var vertical := 9.0 if control else 12.0 if kind == "banner" else 40.0 if kind == "panel" else 16.0
	if state == "focus":
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = TEAL
		focus.set_border_width_all(2)
		focus.set_corner_radius_all(5)
		focus.expand_margin_left = 2
		focus.expand_margin_top = 2
		focus.expand_margin_right = 2
		focus.expand_margin_bottom = 2
		return focus
	var art_name := kind
	if control:
		var suffix := (
			state
			if state in ["hover", "pressed", "primary", "selected", "disabled", "locked"]
			else "normal"
		)
		art_name = kind + "_" + suffix
	var chrome_path := CHROME_ROOT + art_name + ".svg"
	var art := load(chrome_path) as Texture2D if ResourceLoader.exists(chrome_path) else null
	var result: StyleBox
	if art != null:
		var painted := StyleBoxTexture.new()
		painted.texture = art
		var slice := 6.0 if kind == "slot" else 14.0 if control else 24.0
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			painted.set_texture_margin(side, slice)
		result = painted
	else:
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = PANEL
		if state in ["primary", "selected"]:
			fallback.bg_color = Color("102d34")
		elif state == "hover":
			fallback.bg_color = Color("30271f")
		elif state in ["disabled", "locked"]:
			fallback.bg_color = Color("181614")
		fallback.border_color = (
			TEAL
			if state == "selected"
			else (
				GOLD
				if state in ["hover", "primary"]
				else BRONZE.darkened(0.25)
			)
		)
		fallback.set_border_width_all(1)
		fallback.set_corner_radius_all(5)
		result = fallback
	result.content_margin_left = horizontal
	result.content_margin_right = horizontal
	result.content_margin_top = vertical
	result.content_margin_bottom = vertical
	return result


static func apply_to_theme(theme: Theme) -> void:
	# Preserve each existing layout's padding and typography.
	for type_name in [
		"Button",
		"OptionButton",
		"PremiumButton",
		"PremiumPrimaryButton",
		"PremiumQuietButton",
		"PremiumTileButton",
		"PremiumOptionButton",
		"DarkMenuButton",
		"DarkMenuBottomButton",
	]:
		if type_name in ["DarkMenuButton", "DarkMenuBottomButton"]:
			theme.set_type_variation(type_name, &"Button")
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var primary: bool = type_name == "PremiumPrimaryButton"
			var art_state: String = (
				"primary"
				if primary and state == "normal"
				else (
					"selected"
					if (primary and state == "hover")
					else "pressed" if state == "hover_pressed" else state
				)
			)
			if type_name == "PremiumTileButton" and state in ["pressed", "hover_pressed"]:
				art_state = "selected"
			var box := style("slot" if type_name == "PremiumTileButton" else "button", art_state)
			if theme.has_stylebox(state, type_name):
				_copy_margins(box, theme.get_stylebox(state, type_name))
			else:
				_set_margins(box, 12, 8)
			theme.set_stylebox(state, type_name, box)
		for state in [
			"font_color",
			"font_hover_color",
			"font_focus_color",
			"font_pressed_color",
			"font_hover_pressed_color",
		]:
			theme.set_color(state, type_name, TEXT)
		theme.set_color("font_disabled_color", type_name, MUTED.darkened(0.15))
	for type_name in [
		"Panel",
		"PanelContainer",
		"PremiumScreen",
		"PremiumPanel",
		"PremiumInset",
		"PremiumHeader",
		"PremiumFooter",
		"PremiumCard",
		"AcceptDialog",
		"PopupPanel",
		"PopupMenu",
		"TooltipPanel",
	]:
		var kind: String = (
			"tooltip"
			if type_name in ["PopupMenu", "TooltipPanel"]
			else (
				"panel"
				if type_name in ["PremiumScreen", "AcceptDialog"]
				else "card"
			)
		)
		var box := style(kind)
		if theme.has_stylebox("panel", type_name):
			_copy_margins(box, theme.get_stylebox("panel", type_name))
		else:
			_set_margins(box, 12, 8)
		theme.set_stylebox("panel", type_name, box)
	for type_name in [
		"Label",
		"RichTextLabel",
		"PopupMenu",
		"LineEdit",
		"TextEdit",
		"CheckBox",
		"CheckButton",
		"TabBar",
	]:
		theme.set_color("font_color", type_name, TEXT)
		theme.set_color("default_color", type_name, TEXT)
		theme.set_color("font_disabled_color", type_name, MUTED)
		theme.set_color("font_hover_color", type_name, TEXT)
	for type_name in ["LineEdit", "TextEdit"]:
		var input := style("card")
		_set_margins(input, 10, 7)
		theme.set_stylebox("normal", type_name, input)
		theme.set_stylebox("focus", type_name, style("button", "focus"))
		theme.set_color("caret_color", type_name, TEXT)
		theme.set_color("selection_color", type_name, Color("24434b"))
	theme.set_stylebox("hover", "PopupMenu", style("button", "selected"))
	for type_name in ["VScrollBar", "HScrollBar"]:
		for state in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
			var bar := StyleBoxFlat.new()
			bar.bg_color = INK if state == "scroll" else GOLD if state != "grabber" else BRONZE
			bar.set_corner_radius_all(3)
			bar.content_margin_left = 4
			bar.content_margin_top = 4
			theme.set_stylebox(state, type_name, bar)
	var separator := StyleBoxLine.new()
	separator.color = BRONZE.darkened(0.45)
	separator.thickness = 1
	theme.set_stylebox("separator", "HSeparator", separator)
	theme.set_stylebox("separator", "VSeparator", separator)

	for entry in [
		["SkillTreeTooltip", "PremiumPanel"],
		["SkillTreeStatusButton", "PremiumTileButton"],
		["SkillTreeTitleLabel", "PremiumTitle"],
		["SkillTreeSectionLabel", "PremiumSubtitle"],
		["SkillTreeMetaLabel", "PremiumBody"],
		["SkillTreeMutedLabel", "PremiumMuted"],
	]:
		theme.set_type_variation(entry[0], entry[1])


static func _copy_margins(target: StyleBox, source: StyleBox) -> void:
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		target.set_content_margin(side, source.get_margin(side))


static func _set_margins(target: StyleBox, horizontal: float, vertical: float) -> void:
	target.content_margin_left = horizontal
	target.content_margin_right = horizontal
	target.content_margin_top = vertical
	target.content_margin_bottom = vertical
