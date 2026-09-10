extends RefCounted
## Unframed painted shortcuts keep native Button input, tooltips and aspect ratio.
const SHADER := preload("res://ui/theme/painted_shortcut.gdshader")
const STATES := ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]
static var _empty := StyleBoxEmpty.new()
static var _material: ShaderMaterial


static func apply(button: Button, enabled: bool) -> void:
	if not button.has_meta("painted_shortcut_original"):
		if not enabled:
			return
		var styles: Dictionary = { }
		for state in STATES:
			styles[state] = button.get_theme_stylebox(state) if button.has_theme_stylebox_override(
				state
			) else null
		button.set_meta(
			"painted_shortcut_original",
			{
				"styles": styles,
				"material": button.material,
				"flat": button.flat,
				"focus_color": button.get_theme_color("icon_focus_color") if button.has_theme_color_override(
					"icon_focus_color"
				) else null,
			},
		)
	if enabled:
		if _material == null:
			_material = ShaderMaterial.new()
			_material.shader = SHADER
		button.material = _material
		button.flat = true
		for state in STATES:
			button.add_theme_stylebox_override(state, _empty)
		button.add_theme_color_override("icon_focus_color", Color(1.3, 1.18, 0.88))
	else:
		var original: Dictionary = button.get_meta("painted_shortcut_original")
		button.material = original.material
		button.flat = original.flat
		for state in STATES:
			if original.styles[state] == null:
				button.remove_theme_stylebox_override(state)
			else:
				button.add_theme_stylebox_override(state, original.styles[state])
		if original.focus_color == null:
			button.remove_theme_color_override("icon_focus_color")
		else:
			button.add_theme_color_override("icon_focus_color", original.focus_color)
