extends Control
## Instant, dismissible speech. The owner decides when movement may resume.
signal dismissed

const CHROME := preload("res://ui/theme/game_ui_chrome.gd")
const BODY_FONT := preload(
	"res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf"
)
const TITLE_FONT := preload("res://asset/ui/recraft_hud_v1/fonts/cinzel/Cinzel-Variable.ttf")
var _row: HBoxContainer
var _bubble: PanelContainer
var _portrait: TextureRect
var _speaker: Label
var _role: Label
var _body: Label
var _hint: Label
var continue_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = CatabaseUITheme.get_theme()
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_portrait = TextureRect.new()
	_portrait.name = "SpeakerPortrait"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://ui/dialogue/portrait_mask.gdshader")
	_portrait.material = mask
	_row.add_child(_portrait)
	_bubble = PanelContainer.new()
	_bubble.name = "SpeechBubble"
	_bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = CHROME.PANEL
	style.border_color = CHROME.BRONZE
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	_bubble.add_theme_stylebox_override("panel", style)
	_row.add_child(_bubble)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_bubble.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	content.add_child(header)
	_speaker = _label(header, "SpeakerName", CHROME.GOLD)
	_speaker.add_theme_font_override("font", TITLE_FONT)
	_role = _label(header, "SpeakerRole", CHROME.MUTED)
	_role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_body = _label(content, "SpeechText", CHROME.TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("line_spacing", 4)
	var footer := HBoxContainer.new()
	content.add_child(footer)
	_hint = _label(footer, "SpeechHint", CHROME.MUTED)
	_hint.text = "Espace / Entrée · Poursuivre"
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	continue_button = Button.new()
	continue_button.name = "ContinueDialogue"
	continue_button.text = "Poursuivre"
	continue_button.theme_type_variation = &"PremiumPrimaryButton"
	continue_button.custom_minimum_size = Vector2(140, 40)
	continue_button.pressed.connect(dismiss)
	footer.add_child(continue_button)
	resized.connect(_layout)
	_row.resized.connect(_position_row)
	_row.minimum_size_changed.connect(_fit_height)
	_bubble.resized.connect(queue_redraw)
	_layout()
	hide()


func _label(parent: Node, node_name: String, tint: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label


func present(speaker: String, role: String, body: String, portrait: Texture2D) -> void:
	_speaker.text = speaker
	_role.text = role
	_body.text = body
	_portrait.texture = portrait
	show()
	_layout()
	continue_button.grab_focus()


func dismiss() -> void:
	if not visible:
		return
	continue_button.release_focus()
	hide()
	dismissed.emit()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			dismiss()


func _layout() -> void:
	if _row == null:
		return
	var factor := clampf(size.y / 900.0, 0.85, 1.2)
	var width := minf(1120.0 * factor, size.x - 48.0)
	_row.add_theme_constant_override("separation", 20)
	_portrait.custom_minimum_size = Vector2.ONE * 184.0 * factor
	_speaker.add_theme_font_size_override("font_size", roundi(25 * factor))
	_role.add_theme_font_size_override("font_size", maxi(14, roundi(15 * factor)))
	_body.add_theme_font_size_override("font_size", maxi(18, roundi(21 * factor)))
	_hint.add_theme_font_size_override("font_size", maxi(13, roundi(14 * factor)))
	_row.size = Vector2(width, 250.0 * factor)
	_fit_height.call_deferred()
	_position_row()


func _fit_height() -> void:
	# Word wrapping settles after the containers receive their actual width.
	# Reclaim its temporary minimum height, including on the first appearance.
	var factor := clampf(size.y / 900.0, 0.85, 1.2)
	_row.size.y = maxf(250.0 * factor, _row.get_combined_minimum_size().y)
	_position_row()


func _position_row() -> void:
	var factor := clampf(size.y / 900.0, 0.85, 1.2)
	_row.position = Vector2((size.x - _row.size.x) * 0.5, size.y - _row.size.y - 26.0 * factor)
	queue_redraw()


func _draw() -> void:
	if _bubble == null:
		return
	var tip := _row.position + _bubble.position + Vector2(0, 76)
	var points := PackedVector2Array(
		[tip + Vector2(1, -12), tip + Vector2(-16, 0), tip + Vector2(1, 12)]
	)
	draw_colored_polygon(points, CHROME.PANEL)
	draw_polyline(points, CHROME.BRONZE, 1.0, true)
