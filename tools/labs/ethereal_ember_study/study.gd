extends Node2D

const Effect := preload("ember.gd")
const LOOP := 2.4
var project_root: String
var out_dir: String
var scenery: Texture2D
var actor: Texture2D
var body_font: FontFile
var title_font: FontFile
var effects: Array[Node2D] = []
var elapsed := 0.0
var speed := 1.0
var playing := true
var capturing := false
var show_effect := true
var timeline: HSlider
var time_label: Label
var phase_label: Label


func _ready() -> void:
	project_root = ProjectSettings.globalize_path("res://").path_join("../../..").simplify_path()
	out_dir = project_root.path_join("artifacts/dev/ethereal_ember_study")
	capturing = "--capture" in OS.get_cmdline_user_args()
	body_font = FontFile.new()
	body_font.load_dynamic_font(
		project_root.path_join(
			"asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf"
		)
	)
	title_font = FontFile.new()
	title_font.load_dynamic_font(
		project_root.path_join("asset/ui/recraft_hud_v1/fonts/cinzel/Cinzel-Variable.ttf")
	)
	scenery = _texture("asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png")
	var sheet := Image.load_from_file(
		project_root.path_join("assets/characters/Achilles/passe_rive_iso_v1/atlases/strike_E.png")
	)
	actor = ImageTexture.create_from_image(sheet.get_region(Rect2i(4, 4, 452, 442)))
	_build()
	_sample(0.0)
	if capturing:
		playing = false
		_capture.call_deferred()


func _texture(path: String) -> ImageTexture:
	var image := Image.load_from_file(project_root.path_join(path))
	assert(image != null and not image.is_empty(), "Texture absente : " + path)
	return ImageTexture.create_from_image(image)


func _label(
	value: String,
	at: Vector2,
	size: int,
	color := Color("a0b7ac"),
	title := false,
) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_override("font", title_font if title else body_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _button(value: String, at: Vector2, width: float, action: Callable) -> void:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = Vector2(width, 40)
	button.add_theme_font_override("font", body_font)
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("29453d") if state in ["pressed", "hover"] else Color("132924")
		style.border_color = Color("947c51") if state == "focus" else Color("3f5950")
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	add_child(button)


func _build() -> void:
	_label("C A T A B A S E    /    É T U D E   V F X   0 1", Vector2(32, 23), 13)
	_label("Éclat de braise", Vector2(30, 47), 36, Color("e9ddbd"), true)
	_label("Éthéré · lumière, transparence et volutes", Vector2(33, 102), 18)
	_label("DANS LE SANCTUAIRE", Vector2(52, 168), 13, Color("efdfb9"))
	_label("Agrandissement × 1,8", Vector2(52, 652), 14, Color("d7d6ba"))
	_label("À TAILLE DE JEU", Vector2(958, 168), 13, Color("d5bd88"))
	_label("Fond clair", Vector2(958, 195), 15)
	_label("Fond sombre", Vector2(958, 458), 15)
	_make_group(Vector2(429, 562), 1.8, true)
	_make_group(Vector2(1112, 374), 1.0, true)
	_make_group(Vector2(1112, 646), 1.0, true)
	_button("Rejouer", Vector2(32, 722), 110, _restart)
	_button(
		"Pause / lecture",
		Vector2(154, 722),
		145,
		func():
			playing = not playing,
	)
	_button(
		"Ralenti × 0,5",
		Vector2(311, 722),
		132,
		func():
			speed = 0.5,
	)
	_button(
		"Vitesse normale",
		Vector2(455, 722),
		148,
		func():
			speed = 1.0,
	)
	_button("Avec / sans effet", Vector2(615, 722), 154, _toggle_effect)
	phase_label = _label("", Vector2(965, 722), 19, Color("e9ce9b"))
	time_label = _label("", Vector2(1179, 752), 15)
	timeline = HSlider.new()
	timeline.position = Vector2(33, 787)
	timeline.size = Vector2(735, 22)
	timeline.max_value = LOOP
	timeline.step = 1.0 / 60.0
	timeline.value_changed.connect(
		func(value):
			playing = false
			_sample(value),
	)
	add_child(timeline)
	_label("Espace : pause    R : rejouer    ← → : image", Vector2(811, 791), 14)
	_label(
		"Prototype animé dans Godot · personnage immobile · effet local sans modification des règles",
		Vector2(33, 834),
		12,
		Color("708c81"),
	)


func _make_group(at: Vector2, zoom: float, with_actor: bool) -> void:
	var group := Node2D.new()
	group.position = at
	group.scale = Vector2.ONE * zoom
	add_child(group)
	if with_actor:
		var sprite := Sprite2D.new()
		sprite.texture = actor
		sprite.centered = false
		sprite.position = Vector2(-114, 0) - Vector2(194, 434) * 0.31
		sprite.scale = Vector2.ONE * 0.31
		group.add_child(sprite)
	var effect := Effect.new()
	effect.position = Vector2(21, 0)
	group.add_child(effect)
	effects.append(effect)


func _draw() -> void:
	draw_line(Vector2(33, 135), Vector2(1327, 135), Color("53624a"), 1)
	var main := Rect2(32, 153, 880, 537)
	draw_texture_rect_region(scenery, main, Rect2(575, 335, 984, 600), Color(0.70, 0.75, 0.69))
	draw_rect(main, Color("466051"), false)
	var light := Rect2(941, 153, 386, 270)
	draw_texture_rect_region(scenery, light, Rect2(750, 430, 600, 420), Color(0.97, 0.98, 0.91))
	draw_rect(light, Color("466051"), false)
	var dark := Rect2(941, 438, 386, 252)
	draw_texture_rect_region(scenery, dark, Rect2(750, 430, 600, 392), Color(0.29, 0.38, 0.35))
	draw_rect(dark, Color("466051"), false)


func _sample(time: float) -> void:
	elapsed = clampf(time, 0.0, LOOP)
	for effect in effects:
		effect.sample(elapsed if show_effect else 0.0)
	timeline.set_value_no_signal(elapsed)
	time_label.text = "%.2f s  /  %.1f s" % [elapsed, LOOP]
	if elapsed < 0.16:
		phase_label.text = "01 · Naissance"
	elif elapsed < 0.48:
		phase_label.text = "02 · Incandescence"
	elif elapsed < 1.0:
		phase_label.text = "03 · Volutes"
	elif elapsed < 1.9:
		phase_label.text = "04 · Dissipation"
	else:
		phase_label.text = "05 · Calme"


func _restart() -> void:
	_sample(0.0)
	playing = true


func _toggle_effect() -> void:
	show_effect = not show_effect
	_sample(elapsed)


func _process(delta: float) -> void:
	if playing and not capturing:
		_sample(fmod(elapsed + delta * speed, LOOP))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			playing = not playing
		KEY_R:
			_restart()
		KEY_LEFT:
			playing = false
			_sample(elapsed - 1.0 / 60.0)
		KEY_RIGHT:
			playing = false
			_sample(elapsed + 1.0 / 60.0)


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("frames"))
	for frame in 72:
		_sample(frame / 30.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		assert(image.save_png(out_dir.path_join("frames/%03d.png" % frame)) == OK)
		if frame == 11:
			image.save_png(out_dir.path_join("poster.png"))
	var report := {
		"frames": 72,
		"fps": 30,
		"duration": LOOP,
		"viewport": [1360, 860],
		"renderer": RenderingServer.get_current_rendering_method(),
		"effect_duration": Effect.DURATION,
		"source": "Unmodified Godot viewport captures",
		"backgrounds": ["sanctuary", "light", "dark"],
	}
	var file := FileAccess.open(out_dir.path_join("capture_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	get_tree().quit()
