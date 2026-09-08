extends Node2D

## Independent art study: native-image coordinates remain stable at every size.
const PAINTING := preload("res://asset/map/painted/merchant/apothecary_v1/apothecary.png")
const PAINTING_SHADER := preload("res://tools/labs/apothecary_living_map/living_painting.gdshader")
const AtmosphereLayer := preload("res://tools/labs/apothecary_living_map/atmosphere_layer.gd")
const BODY_FONT := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf")
const TITLE_FONT := preload("res://asset/ui/recraft_hud_v1/fonts/cinzel/Cinzel-Variable.ttf")
const NATIVE_SIZE := Vector2(1376.0, 768.0)
const GOLD := Color("d4b37f")
const INK := Color("eee4d1")
const WATER_OUTLINE: Array[Vector2] = [
	Vector2(730, 253), Vector2(741, 249), Vector2(758, 250),
	Vector2(812, 260), Vector2(866, 269), Vector2(913, 281),
	Vector2(943, 286), Vector2(918, 295), Vector2(876, 302),
	Vector2(832, 301), Vector2(785, 293), Vector2(753, 280),
	Vector2(735, 265),
]

@export var map_texture: Texture2D = PAINTING
@export var map_shader: Shader = PAINTING_SHADER
@export var atmosphere_script: Script = AtmosphereLayer
@export var map_title := "L’Apothicairerie du bassin"
@export var magic_caption := "Potions"
@export_file("*.json") var layout_path := ""

var _world: Node2D
var _painting: TextureRect
var _material: ShaderMaterial
var _atmosphere: Node2D
var _chrome: Control
var _top: PanelContainer
var _bottom: PanelContainer
var _status: Label
var _resolution: Label
var _mode_button: Button
var _pause_button: Button
var _strength_slider: HSlider
var _strength_label: Label
var _layer_buttons: Dictionary = {}
var _time := 0.0
var _strength := 1.0
var _effects_enabled := true
var _paused := false
var _chrome_visible := true
var _layers := {&"water": true, &"fire": true, &"magic": true, &"atmosphere": true}
var _ripple_origin := Vector2.ZERO
var _ripple_start := -100.0
var _ripple_count := 0
var _preview_ready := false
var _water_regions: Array[PackedVector2Array] = []
var _water_exclusions: Array[Rect2] = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("141719"))
	if not _load_layout():
		return
	_world = Node2D.new()
	_world.name = "PaintedWorld"
	add_child(_world)
	_painting = TextureRect.new()
	_painting.name = "LivingPainting"
	_painting.texture = map_texture
	_painting.size = NATIVE_SIZE
	_painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painting.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_material = ShaderMaterial.new()
	_material.shader = map_shader
	_painting.material = _material
	_world.add_child(_painting)
	_atmosphere = atmosphere_script.new() as Node2D
	_atmosphere.name = "Atmosphere"
	_world.add_child(_atmosphere)
	_build_interface()
	get_viewport().size_changed.connect(_fit_world)
	_fit_world()
	_apply_effects()
	_preview_ready = true
	if "--clean-preview" in OS.get_cmdline_user_args():
		set_chrome_visible(false)
	if "--original" in OS.get_cmdline_user_args():
		set_effects_enabled(false)
	print("LIVING_MAP_READY: %s; 1376x768, four effect layers; no gameplay state." % map_title)


func _process(delta: float) -> void:
	if not _paused:
		_time += delta
	_apply_effects()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				set_animation_paused(not _paused)
			KEY_TAB:
				set_effects_enabled(not _effects_enabled)
			KEY_H:
				set_chrome_visible(not _chrome_visible)
			KEY_F:
				get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
			KEY_ESCAPE:
				if get_window().mode == Window.MODE_FULLSCREEN:
					get_window().mode = Window.MODE_WINDOWED
				else:
					set_chrome_visible(true)
			_:
				return
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if trigger_ripple(_world.to_local(event.position)):
			get_viewport().set_input_as_handled()


func is_ready_for_preview() -> bool:
	return _preview_ready


func set_effects_enabled(enabled: bool) -> void:
	_effects_enabled = enabled
	_apply_effects()
	_update_labels()


func set_layer_enabled(layer: StringName, enabled: bool) -> void:
	if not _layers.has(layer):
		return
	_layers[layer] = enabled
	if _layer_buttons.has(layer):
		(_layer_buttons[layer] as Button).set_pressed_no_signal(enabled)
	_apply_effects()


func set_effect_time(time_seconds: float) -> void:
	_time = maxf(time_seconds, 0.0)
	_apply_effects()


func set_animation_paused(paused: bool) -> void:
	_paused = paused
	_update_labels()


func set_effect_strength(strength: float) -> void:
	_strength = clampf(strength, 0.0, 1.5)
	if _strength_slider != null:
		_strength_slider.set_value_no_signal(_strength)
	_apply_effects()
	_update_labels()


func set_chrome_visible(visible: bool) -> void:
	_chrome_visible = visible
	if _chrome != null:
		_chrome.visible = visible
	_fit_world()


func native_to_viewport(point: Vector2) -> Vector2:
	return _world.get_global_transform_with_canvas() * point


func trigger_ripple(native_point: Vector2) -> bool:
	if not _effects_enabled or not bool(_layers[&"water"]) or _strength <= 0.0:
		return false
	if not Rect2(Vector2.ZERO, NATIVE_SIZE).has_point(native_point):
		return false
	var inside := false
	for polygon: PackedVector2Array in _water_regions:
		inside = inside or Geometry2D.is_point_in_polygon(native_point, polygon)
	if not inside:
		return false
	for exclusion: Rect2 in _water_exclusions:
		if exclusion.has_point(native_point):
			return false
	_ripple_origin = native_point / NATIVE_SIZE
	_ripple_start = _time
	_ripple_count += 1
	_apply_effects()
	return true


func get_effect_state() -> Dictionary:
	return {
		"effects_enabled": _effects_enabled, "paused": _paused,
		"strength": _strength, "effect_time": _time,
		"layers": _layers.duplicate(), "ripple_count": _ripple_count,
		"chrome_visible": _chrome_visible,
	}


func _apply_effects() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("effect_time", _time)
	_material.set_shader_parameter("effect_strength", _strength if _effects_enabled else 0.0)
	_material.set_shader_parameter("water_enabled", bool(_layers[&"water"]))
	_material.set_shader_parameter("fire_enabled", bool(_layers[&"fire"]))
	_material.set_shader_parameter("magic_enabled", bool(_layers[&"magic"]))
	_material.set_shader_parameter("ripple_origin", _ripple_origin)
	var age := _time - _ripple_start
	_material.set_shader_parameter("ripple_age", age if age >= 0.0 and age < 4.0 else -1.0)
	_atmosphere.call("set_effect_state", _time, _strength, _effects_enabled and bool(_layers[&"atmosphere"]), bool(_layers[&"water"]))


func _load_layout() -> bool:
	if layout_path.is_empty():
		_water_regions = [PackedVector2Array(WATER_OUTLINE)]
		_water_exclusions = [Rect2(823, 240, 20, 41), Rect2(881, 255, 18, 35)]
		return true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	if not parsed is Dictionary or not parsed.has("water_regions"):
		push_error("LivingMap: invalid water layout: " + layout_path)
		return false
	for region: Array in parsed.water_regions:
		var polygon := PackedVector2Array()
		for point: Array in region:
			polygon.append(Vector2(float(point[0]), float(point[1])))
		_water_regions.append(polygon)
	for bounds: Array in parsed.get("water_exclusions", []):
		_water_exclusions.append(Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3])))
	return not _water_regions.is_empty()


func _fit_world() -> void:
	if _world == null:
		return
	var viewport_size := get_viewport_rect().size
	var top_space := 78.0 if _chrome_visible else 0.0
	var bottom_space := 108.0 if _chrome_visible else 0.0
	var available := Vector2(maxf(320.0, viewport_size.x - 24.0), maxf(180.0, viewport_size.y - top_space - bottom_space))
	var factor := minf(available.x / NATIVE_SIZE.x, available.y / NATIVE_SIZE.y)
	_world.scale = Vector2.ONE * factor
	_world.position = Vector2((viewport_size.x - NATIVE_SIZE.x * factor) * 0.5, top_space + (available.y - NATIVE_SIZE.y * factor) * 0.5)
	if _resolution != null:
		_resolution.text = "SOURCE 1376 × 768  ·  AFFICHAGE %d %%" % roundi(factor * 100.0)


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_chrome = Control.new()
	_chrome.name = "PreviewControls"
	_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.theme = _theme()
	canvas.add_child(_chrome)
	_top = PanelContainer.new()
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.offset_left = 20
	_top.offset_right = -20
	_top.offset_top = 10
	_top.offset_bottom = 70
	_top.add_theme_stylebox_override("panel", _panel_style())
	_chrome.add_child(_top)
	var heading := HBoxContainer.new()
	_top.add_child(heading)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	heading.add_child(titles)
	var title := Label.new()
	title.text = map_title
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", INK)
	titles.add_child(title)
	_resolution = Label.new()
	_resolution.add_theme_font_size_override("font_size", 12)
	_resolution.add_theme_color_override("font_color", Color("a5a897"))
	titles.add_child(_resolution)
	_status = Label.new()
	_status.add_theme_color_override("font_color", GOLD)
	heading.add_child(_status)
	_bottom = PanelContainer.new()
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_left = 20
	_bottom.offset_right = -20
	_bottom.offset_top = -96
	_bottom.offset_bottom = -12
	_bottom.add_theme_stylebox_override("panel", _panel_style())
	_chrome.add_child(_bottom)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	_bottom.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	stack.add_child(row)
	_mode_button = _button("Voir l’original")
	_mode_button.name = "CompareOriginal"
	_mode_button.pressed.connect(func() -> void: set_effects_enabled(not _effects_enabled))
	row.add_child(_mode_button)
	_pause_button = _button("Pause")
	_pause_button.name = "PauseAnimation"
	_pause_button.pressed.connect(func() -> void: set_animation_paused(not _paused))
	row.add_child(_pause_button)
	for entry: Array in [[&"water", "Eau"], [&"fire", "Lumières"], [&"magic", magic_caption], [&"atmosphere", "Atmosphère"]]:
		var layer: StringName = entry[0]
		var toggle := _button(str(entry[1]))
		toggle.name = "Layer_" + str(layer)
		toggle.toggle_mode = true
		toggle.button_pressed = true
		toggle.toggled.connect(func(enabled: bool) -> void: set_layer_enabled(layer, enabled))
		_layer_buttons[layer] = toggle
		row.add_child(toggle)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_strength_label = Label.new()
	_strength_label.custom_minimum_size.x = 110
	row.add_child(_strength_label)
	_strength_slider = HSlider.new()
	_strength_slider.name = "Intensity"
	_strength_slider.custom_minimum_size.x = 115
	_strength_slider.min_value = 0.0
	_strength_slider.max_value = 1.5
	_strength_slider.step = 0.05
	_strength_slider.value = _strength
	_strength_slider.value_changed.connect(set_effect_strength)
	row.add_child(_strength_slider)
	var hint := Label.new()
	hint.text = "Cliquer dans l’eau : onde   ·   Espace : pause   ·   Tab : original / animé   ·   F : plein écran   ·   H : masquer les contrôles"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("a5a897"))
	stack.add_child(hint)
	_update_labels()


func _update_labels() -> void:
	if _mode_button == null:
		return
	_mode_button.text = "Voir l’original" if _effects_enabled else "Voir l’animation"
	_pause_button.text = "Reprendre" if _paused else "Pause"
	_status.text = "ORIGINAL" if not _effects_enabled else ("ANIMATION EN PAUSE" if _paused else "ÉTUDE D’AMBIANCE · ANIMÉE")
	_strength_label.text = "Intensité %d %%" % roundi(_strength * 100.0)


func _button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 34
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a2021")
	style.border_color = Color("414438")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = BODY_FONT
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", INK)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("34413c") if state == "pressed" else Color("252d2c")
		style.border_color = GOLD if state in ["hover", "focus"] else Color("526055")
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		theme.set_stylebox(state, "Button", style)
		theme.set_color("font_" + state + "_color", "Button", INK)
	theme.set_color("font_color", "Button", INK)
	return theme
