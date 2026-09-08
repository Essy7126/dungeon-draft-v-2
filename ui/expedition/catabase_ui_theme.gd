class_name CatabaseUITheme
extends RefCounted
## Painted presentation only. Missing art keeps every control usable.

const ART_ROOT := "res://assets/catabase/painted/ui/"
const INK := Color("0d1b23")
const PANEL := Color("142a30")
const BRONZE := Color("957344")
const GOLD := Color("e0ba76")
const TEXT := Color("f3ead7")
const MUTED := Color("a9bab7")
const TEAL := Color("74d5cb")
const DANGER := Color("e29b85")
static var _theme: Theme = null
static var _textures: Dictionary = {}
static var _presentation_textures: Dictionary = {}

# Source borders are measured on the final exports, before their UI reduction.
const SOURCE_SLICES := {
	"panel": Vector4(70, 70, 70, 70),
	"card": Vector4(30, 30, 30, 30),
	"tooltip": Vector4(24, 24, 24, 24),
	"banner": Vector4(100, 16, 100, 16),
	"slot": Vector4(17, 17, 17, 17),
	"portrait_frame": Vector4(26, 26, 26, 26),
	"button": Vector4(38, 28, 38, 28),
	"tab": Vector4(38, 24, 38, 24),
}


static func texture(name: String) -> Texture2D:
	var path := ART_ROOT + name + ".png"
	if _textures.has(path):
		return _textures[path] as Texture2D
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var loaded := ResourceLoader.load(path, "Texture2D") as Texture2D
	if loaded != null:
		_textures[path] = loaded
	return loaded


static func icon(group: String, name: String) -> Texture2D:
	return texture(group + "/" + name) if not name.is_empty() else null


static func _presentation_texture(name: String, source: Texture2D) -> Texture2D:
	if _presentation_textures.has(name):
		return _presentation_textures[name] as Texture2D
	var image := source.get_image()
	if image == null or image.is_empty():
		return source
	if image.is_compressed() and image.decompress() != OK:
		return source
	if name == "banner":
		# The upper frieze is a complete horizontal plate. Its square body is
		# intentionally excluded from compact headers, preserving the foliage.
		image = image.get_region(Rect2i(0, 0, image.get_width(), mini(94, image.get_height())))
	var target_width := 96 if name.begins_with("slot_") or name == "portrait_frame" else 224
	var ratio := float(target_width) / float(image.get_width())
	image.resize(target_width, maxi(1, roundi(image.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
	var presented := ImageTexture.create_from_image(image)
	_presentation_textures[name] = presented
	return presented


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
		var suffix := state if state in ["primary", "selected", "disabled", "locked"] else "normal"
		if kind == "tab" and suffix not in ["normal", "selected"]:
			suffix = "normal"
		elif kind == "slot" and suffix in ["primary", "disabled"]:
			suffix = "locked" if suffix == "disabled" else "selected"
		elif kind == "button" and suffix == "locked":
			suffix = "disabled"
		art_name = kind + "_" + suffix
	var art := texture(art_name)
	var result: StyleBox
	if art != null:
		var painted := StyleBoxTexture.new()
		painted.texture = _presentation_texture(art_name, art)
		var ratio := float(painted.texture.get_width()) / float(art.get_width())
		var source_slices: Vector4 = SOURCE_SLICES.get(kind, Vector4(32, 32, 32, 32))
		painted.set_texture_margin(SIDE_LEFT, roundf(source_slices.x * ratio))
		painted.set_texture_margin(SIDE_TOP, roundf(source_slices.y * ratio))
		painted.set_texture_margin(SIDE_RIGHT, roundf(source_slices.z * ratio))
		painted.set_texture_margin(SIDE_BOTTOM, roundf(source_slices.w * ratio))
		painted.modulate_color = Color(1.10, 1.08, 1.03) if state == "hover" else (Color(0.78, 0.86, 0.85) if state == "pressed" else Color.WHITE)
		result = painted
	else:
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = PANEL
		if state in ["primary", "selected"]:
			fallback.bg_color = Color("274342")
		elif state == "hover":
			fallback.bg_color = Color("294147")
		elif state in ["disabled", "locked"]:
			fallback.bg_color = Color("122127")
		fallback.border_color = TEAL if state == "selected" else GOLD if state in ["hover", "primary"] else BRONZE.darkened(0.25)
		fallback.set_border_width_all(1)
		fallback.set_corner_radius_all(5)
		result = fallback
	result.content_margin_left = horizontal
	result.content_margin_right = horizontal
	result.content_margin_top = vertical
	result.content_margin_bottom = vertical
	return result


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = PremiumUI.get_theme().duplicate(true) as Theme
	_theme.default_font_size = 17
	for type_name in ["Button", "OptionButton", "PremiumButton", "PremiumPrimaryButton", "PremiumQuietButton", "PremiumTileButton", "PremiumOptionButton", "DarkMenuButton", "DarkMenuBottomButton"]:
		if type_name not in ["Button", "OptionButton"]:
			_theme.set_type_variation(type_name, "OptionButton" if type_name == "PremiumOptionButton" else "Button")
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var art_state: String = "primary" if type_name == "PremiumPrimaryButton" and state == "normal" else "pressed" if state == "hover_pressed" else state
			if type_name == "PremiumTileButton" and state in ["pressed", "hover_pressed"]:
				art_state = "selected"
			_theme.set_stylebox(state, type_name, style("slot" if type_name == "PremiumTileButton" else "button", art_state))
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_theme.set_color(color_name, type_name, TEXT)
		for color_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
			_theme.set_color(color_name, type_name, Color.WHITE)
		_theme.set_color("icon_disabled_color", type_name, Color(1, 1, 1, 0.65))
		_theme.set_color("font_disabled_color", type_name, MUTED.darkened(0.18))
		_theme.set_font_size("font_size", type_name, 16)
		_theme.set_font("font", type_name, PremiumUI.SKIN.font_regular)
		_theme.set_constant("h_separation", type_name, 8)
		_theme.set_constant("icon_max_width", type_name, 26)
	for type_name in ["PanelContainer", "PremiumScreen", "PremiumPanel", "PremiumInset", "PremiumHeader", "PremiumFooter", "PremiumCard"]:
		var art_kind := "slot" if type_name == "PremiumInset" else "panel" if type_name == "PanelContainer" else "card"
		if type_name in ["PremiumHeader", "PremiumFooter"]:
			art_kind = "banner"
		var painted_style := style(art_kind)
		if type_name != "PanelContainer":
			# The modal scenes already own their padding and exact icon dimensions.
			var previous := _theme.get_stylebox("panel", type_name)
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				painted_style.set_content_margin(side, previous.get_margin(side))
		_theme.set_stylebox("panel", type_name, painted_style)
	_theme.set_stylebox("panel", "PopupMenu", style("tooltip"))
	_theme.set_stylebox("panel", "TooltipPanel", style("tooltip"))
	_theme.set_stylebox("normal", "LineEdit", style("card"))
	_theme.set_stylebox("focus", "LineEdit", style("button", "focus"))
	_theme.set_color("font_color", "LineEdit", TEXT)
	_theme.set_color("font_color", "Label", TEXT)
	_theme.set_color("font_color", "PopupMenu", TEXT)
	_theme.set_color("font_hover_color", "PopupMenu", TEXT)
	_theme.set_stylebox("hover", "PopupMenu", style("button", "selected"))
	_theme.set_font_size("font_size", "PopupMenu", 16)
	_theme.set_type_variation("DarkMenuTitle", "Label")
	_theme.set_font("font", "DarkMenuTitle", PremiumUI.SKIN.font_emphasis)
	_theme.set_font_size("font_size", "DarkMenuTitle", 28)
	_theme.set_color("font_color", "DarkMenuTitle", TEXT)
	for type_name in ["PremiumTitle", "PremiumSubtitle", "PremiumDisplay", "PremiumBody", "PremiumEyebrow"]:
		_theme.set_color("font_color", type_name, TEXT if type_name == "PremiumBody" else GOLD)
	_theme.set_color("font_color", "PremiumMuted", MUTED)
	_theme.set_color("font_color", "PremiumPositive", TEAL)
	_theme.set_stylebox("panel", "AcceptDialog", style("panel"))
	return _theme


static func apply(root: Control) -> void:
	root.theme = get_theme()


static func apply_button(button: Button, primary: bool = false, selected: bool = false, icon_name: String = "") -> void:
	bind_button_motion(button)
	button.theme_type_variation = &"PremiumPrimaryButton" if primary else &"PremiumButton"
	button.add_theme_stylebox_override("normal", style("button", "selected" if selected else "primary" if primary else "normal"))
	button.add_theme_stylebox_override("hover", style("button", "selected" if selected else "hover"))
	button.add_theme_stylebox_override("pressed", style("button", "pressed"))
	button.add_theme_stylebox_override("hover_pressed", style("button", "pressed"))
	button.add_theme_stylebox_override("focus", style("button", "focus"))
	button.add_theme_stylebox_override("disabled", style("button", "disabled"))
	if not icon_name.is_empty():
		button.icon = icon("nav", icon_name)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 24)
		_reserve_button_icon(button, 24)


static func apply_tab(button: Button, selected: bool, icon_name: String = "") -> void:
	apply_button(button, false, selected, icon_name)
	button.toggle_mode = true
	button.set_pressed_no_signal(selected)
	button.set_meta("catabase_selected", selected)
	button.add_theme_stylebox_override("normal", style("tab", "selected" if selected else "normal"))
	button.add_theme_stylebox_override("hover", style("tab", "selected" if selected else "hover"))
	button.add_theme_stylebox_override("pressed", style("tab", "selected"))
	button.add_theme_stylebox_override("hover_pressed", style("tab", "selected"))
	_reserve_button_icon(button, button.get_theme_constant("icon_max_width"))


static func apply_inventory(root: Control, enabled: bool) -> void:
	_restoreable_theme(root, enabled)
	_inventory_action_footer(root, enabled)
	var header_margin := root.find_child("HeaderMargin", true, false) as MarginContainer
	if header_margin != null:
		if not header_margin.has_meta("catabase_header_margins"):
			header_margin.set_meta("catabase_header_margins", Vector2i(header_margin.get_theme_constant("margin_left"), header_margin.get_theme_constant("margin_top")))
		var original: Vector2i = header_margin.get_meta("catabase_header_margins")
		header_margin.add_theme_constant_override("margin_left", 44 if enabled else original.x)
		header_margin.add_theme_constant_override("margin_top", 16 if enabled else original.y)
	for name in ["CloseButton", "EquipButton", "UseButton", "UnequipButton"]:
		var button := root.find_child(name, true, false) as Button
		if button == null:
			continue
		_restoreable_icon(button, enabled, "close" if name == "CloseButton" else "check" if name == "UseButton" else "equipment", 22)
		bind_button_motion(button, enabled)


static func _inventory_action_footer(root: Control, enabled: bool) -> void:
	var panel := root.find_child("DetailPanel", true, false) as PanelContainer
	var scroll := root.find_child("DetailScroll", true, false) as ScrollContainer
	var actions := root.find_child("Actions", true, false) as HBoxContainer
	var feedback := root.find_child("Feedback", true, false) as Label
	if panel == null or scroll == null or actions == null:
		return
	var layout := panel.get_node_or_null("CatabaseDetailLayout") as VBoxContainer
	if enabled and layout == null:
		# Keep the existing action buttons and signals, but outside the long
		# description/statistics scroll so they remain reachable at 720p.
		actions.set_meta("catabase_original_parent", actions.get_parent())
		actions.set_meta("catabase_original_index", actions.get_index())
		layout = VBoxContainer.new()
		layout.name = "CatabaseDetailLayout"
		layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
		layout.add_theme_constant_override("separation", 4)
		panel.add_child(layout)
		var inset := MarginContainer.new()
		inset.name = "CatabaseDetailViewport"
		inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
		inset.add_theme_constant_override("margin_top", 14)
		inset.add_theme_constant_override("margin_left", 8)
		inset.add_theme_constant_override("margin_right", 8)
		layout.add_child(inset)
		scroll.reparent(inset, false)
		var footer := MarginContainer.new()
		footer.name = "CatabaseActionInset"
		footer.add_theme_constant_override("margin_left", 16)
		footer.add_theme_constant_override("margin_right", 16)
		footer.add_theme_constant_override("margin_bottom", 10)
		layout.add_child(footer)
		var footer_content := VBoxContainer.new()
		footer_content.name = "CatabaseActionFooter"
		footer_content.add_theme_constant_override("separation", 6)
		footer.add_child(footer_content)
		if feedback != null:
			feedback.set_meta("catabase_original_parent", feedback.get_parent())
			feedback.set_meta("catabase_original_index", feedback.get_index())
			feedback.reparent(footer_content, false)
		actions.reparent(footer_content, false)
	elif not enabled and layout != null:
		var original := actions.get_meta("catabase_original_parent") as Node if actions.has_meta("catabase_original_parent") else null
		if is_instance_valid(original):
			actions.reparent(original, false)
			original.move_child(actions, mini(int(actions.get_meta("catabase_original_index")), original.get_child_count() - 1))
		if feedback != null and feedback.has_meta("catabase_original_parent"):
			var feedback_parent := feedback.get_meta("catabase_original_parent") as Node
			if is_instance_valid(feedback_parent):
				feedback.reparent(feedback_parent, false)
				feedback_parent.move_child(feedback, mini(int(feedback.get_meta("catabase_original_index")), feedback_parent.get_child_count() - 1))
		scroll.reparent(panel, false)
		panel.remove_child(layout)
		layout.queue_free()


static func apply_pause(root: Node, enabled: bool) -> void:
	var pause_root := root.find_child("PauseRoot", true, false) as Control
	if pause_root == null:
		return
	_restoreable_theme(pause_root, enabled)
	var confirmation := root.find_child("ExitConfirmation", true, false) as ConfirmationDialog
	if confirmation != null:
		if not confirmation.has_meta("catabase_original_theme"):
			confirmation.set_meta("catabase_original_theme", {"theme": confirmation.theme})
		confirmation.theme = get_theme() if enabled else confirmation.get_meta("catabase_original_theme").get("theme")
	var frame := root.find_child("MainFrame", true, false) as TextureRect
	if frame != null:
		if not frame.has_meta("catabase_original_visible"):
			frame.set_meta("catabase_original_visible", frame.visible)
		var painted := frame.get_parent().get_node_or_null("CatabasePaintedFrame") as Panel
		if enabled and painted == null:
			painted = Panel.new()
			painted.name = "CatabasePaintedFrame"
			painted.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			painted.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.get_parent().add_child(painted)
			frame.get_parent().move_child(painted, frame.get_index() + 1)
		if painted != null:
			painted.add_theme_stylebox_override("panel", style("panel"))
			painted.visible = enabled
		frame.visible = false if enabled else bool(frame.get_meta("catabase_original_visible"))
	for pair in [["HeaderTexture", "banner"], ["BottomTexture", "button_normal"]]:
		var view := root.find_child(pair[0], true, false) as TextureRect
		if view == null:
			continue
		if not view.has_meta("catabase_original_visible"):
			view.set_meta("catabase_original_visible", view.visible)
		view.visible = false if enabled else bool(view.get_meta("catabase_original_visible"))
		if pair[0] == "HeaderTexture":
			var plate := view.get_parent().get_node_or_null("CatabaseHeaderPlate") as Panel
			if enabled and plate == null:
				plate = Panel.new()
				plate.name = "CatabaseHeaderPlate"
				plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
				view.get_parent().add_child(plate)
				view.get_parent().move_child(plate, view.get_index() + 1)
			if plate != null:
				plate.add_theme_stylebox_override("panel", style("banner"))
				plate.visible = enabled
	var close := root.find_child("CloseButton", true, false) as TextureButton
	if close != null:
		for property in ["texture_normal", "texture_pressed", "texture_hover", "texture_focused"]:
			var key: String = "catabase_original_" + property
			if not close.has_meta(key):
				close.set_meta(key, {"texture": close.get(property)})
			var art := icon("nav", "close")
			close.set(property, art if enabled and art != null else close.get_meta(key).get("texture"))
	var symbols := {"ResumeButton": "continue", "EquipmentButton": "equipment", "OptionsButton": "settings", "ReturnButton": "home", "AbandonButton": "close", "CharactersButton": "lock", "CompendiumButton": "lock"}
	for name in symbols:
		var button := root.find_child(name, true, false) as Button
		if button == null:
			continue
		# DarkMenuButton scenes carry their own theme; replacing only PauseRoot
		# would leave the previous crimson spear buttons visible.
		_restoreable_theme(button, enabled)
		_restoreable_icon(button, enabled, symbols[name], 24)
		bind_button_motion(button, enabled)
		if button.has_method("_sync_emphasis"):
			button.call("_sync_emphasis")


static func _restoreable_icon(button: Button, enabled: bool, icon_name: String, extent: int) -> void:
	if not button.has_meta("catabase_original_icon"):
		button.set_meta("catabase_original_icon", {
			"icon": button.icon, "expand_icon": button.expand_icon,
			"minimum_size": button.custom_minimum_size,
			"has_icon_max_width": button.has_theme_constant_override("icon_max_width"),
			"icon_max_width": button.get_theme_constant("icon_max_width"),
		})
	var original: Dictionary = button.get_meta("catabase_original_icon")
	if enabled:
		button.icon = icon("nav", icon_name)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", extent)
		_reserve_button_icon(button, extent)
	else:
		button.icon = original.get("icon")
		button.expand_icon = bool(original.expand_icon)
		button.custom_minimum_size = original.minimum_size
		if bool(original.has_icon_max_width):
			button.add_theme_constant_override("icon_max_width", int(original.icon_max_width))
		else:
			button.remove_theme_constant_override("icon_max_width")


static func _reserve_button_icon(button: Button, extent: int) -> void:
	if button.icon == null:
		return
	var font := button.get_theme_font("font")
	var font_size := button.get_theme_font_size("font_size")
	var text_width := 0.0
	for line in button.text.split("\n"):
		text_width = maxf(text_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var normal := button.get_theme_stylebox("normal")
	button.custom_minimum_size.x = maxf(button.custom_minimum_size.x,
		text_width + extent + button.get_theme_constant("h_separation") + normal.get_margin(SIDE_LEFT) + normal.get_margin(SIDE_RIGHT))


static func bind_button_motion(button: Button, enabled: bool = true) -> void:
	button.set_meta("catabase_motion_enabled", enabled)
	if not enabled:
		button.set_meta("catabase_pointer_down", false)
	if not button.has_meta("catabase_motion_bound"):
		button.set_meta("catabase_motion_bound", true)
		button.set_meta("catabase_motion_base", button.self_modulate)
		button.set_meta("catabase_pointer_down", false)
		button.mouse_entered.connect(_update_button_motion.bind(button))
		button.mouse_exited.connect(_update_button_motion.bind(button))
		button.focus_entered.connect(_update_button_motion.bind(button))
		button.focus_exited.connect(_update_button_motion.bind(button))
		button.button_down.connect(_set_button_down.bind(button, true))
		button.button_up.connect(_set_button_down.bind(button, false))
	_update_button_motion(button, not enabled)


static func _set_button_down(button: Button, down: bool) -> void:
	button.set_meta("catabase_pointer_down", down)
	_update_button_motion(button)


static func _update_button_motion(button: Button, instant: bool = false) -> void:
	if not is_instance_valid(button):
		return
	var previous := button.get_meta("catabase_motion_tween") as Tween if button.has_meta("catabase_motion_tween") else null
	if previous != null and previous.is_valid():
		previous.kill()
	var base: Color = button.get_meta("catabase_motion_base", Color.WHITE)
	var enabled := bool(button.get_meta("catabase_motion_enabled", false)) and not button.disabled
	var down := enabled and bool(button.get_meta("catabase_pointer_down", false))
	var highlighted := enabled and (button.is_hovered() or button.has_focus())
	var gain := 0.90 if down else 1.06 if highlighted else 1.0
	var target := Color(base.r * gain, base.g * gain, base.b * gain, base.a)
	var reduced := GameManager.is_reduced_motion_enabled()
	var duration := PremiumUI.SKIN.motion_duration(&"press" if down else &"hover", reduced)
	if instant or reduced or not button.is_inside_tree() or is_zero_approx(duration) or button.self_modulate.is_equal_approx(target):
		button.self_modulate = target
		return
	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "self_modulate", target, duration)
	button.set_meta("catabase_motion_tween", tween)


static func reveal(control: Control) -> void:
	var previous := control.get_meta("catabase_reveal_tween") as Tween if control.has_meta("catabase_reveal_tween") else null
	if previous != null and previous.is_valid():
		previous.kill()
	if not control.has_meta("catabase_reveal_alpha"):
		control.set_meta("catabase_reveal_alpha", control.modulate.a)
	var target := float(control.get_meta("catabase_reveal_alpha"))
	var reduced := GameManager.is_reduced_motion_enabled()
	var duration := minf(0.18, PremiumUI.SKIN.motion_duration(&"panel", reduced))
	if reduced or not control.is_inside_tree() or is_zero_approx(duration):
		control.modulate.a = target
		return
	control.modulate.a = target * 0.82
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", target, duration)
	control.set_meta("catabase_reveal_tween", tween)


static func finish_motion(root: Node) -> void:
	if root is InventoryItemTile:
		(root as InventoryItemTile).finish_motion()
	if root is Button and root.has_meta("catabase_motion_bound"):
		_update_button_motion(root as Button, true)
	if root is Control and root.has_meta("catabase_reveal_alpha"):
		var previous := root.get_meta("catabase_reveal_tween") as Tween if root.has_meta("catabase_reveal_tween") else null
		if previous != null and previous.is_valid():
			previous.kill()
		var control := root as Control
		control.modulate.a = float(root.get_meta("catabase_reveal_alpha"))
	for child in root.get_children():
		finish_motion(child)


static func _restoreable_theme(root: Control, enabled: bool) -> void:
	if not root.has_meta("catabase_original_theme"):
		root.set_meta("catabase_original_theme", {"theme": root.theme})
	root.theme = get_theme() if enabled else root.get_meta("catabase_original_theme").get("theme")
