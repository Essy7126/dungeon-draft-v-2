extends Node2D

var root_path: String
var recipe: Dictionary
var pivot: Vector2
var layers: Array[Dictionary] = []
var elapsed := 0.0
var tempo := 1.0
var playing := true
var capturing := false
var show_effect := true
var timeline: HSlider
var clock_label: Label
var body_font: FontFile
var title_font: FontFile
var tempo_buttons: Array[Button] = []
var scenery_texture: Texture2D


func _ready() -> void:
	root_path = ProjectSettings.globalize_path("res://").path_join("../../..").simplify_path()
	recipe = JSON.parse_string(FileAccess.get_file_as_string("res://recipe.json"))
	var metadata: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://generated/preview.json")
	)
	pivot = Vector2(metadata.pivot[0], metadata.pivot[1])
	body_font = FontFile.new()
	body_font.load_dynamic_font(
		root_path.path_join(
			"asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf"
		)
	)
	title_font = FontFile.new()
	title_font.load_dynamic_font(
		root_path.path_join("asset/ui/recraft_hud_v1/fonts/cinzel/Cinzel-Variable.ttf")
	)
	capturing = "--capture" in OS.get_cmdline_user_args()
	_build()
	_sample(0.0)
	if capturing:
		playing = false
		_capture.call_deferred()


func _texture(path: String) -> ImageTexture:
	var im := Image.load_from_file(path)
	assert(im != null and not im.is_empty(), "Missing review texture: " + path)
	return ImageTexture.create_from_image(im)


func _text(
	value: String,
	at: Vector2,
	size: int,
	color := Color("dbddcb"),
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


func _button(value: String, at: Vector2, width: float, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = Vector2(width, 40)
	button.add_theme_font_override("font", body_font)
	button.add_theme_font_size_override("font_size", 17)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("28493f") if state == "pressed" else Color("182d2c")
		style.border_color = Color("8ea78c") if state in ["pressed", "focus"] else Color("39544b")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	add_child(button)
	return button


func _build() -> void:
	_text("C A T A B A S E    /    É T U D E   D E   S O I N", Vector2(26, 19), 15, Color("9fb298"))
	_text("Souffle du laurier", Vector2(24, 46), 34, Color("e5ddbd"), true)
	_text(
		"Une remontée de sève, un éclat d’ivoire, puis le calme.",
		Vector2(26, 97),
		18,
		Color("a2b5af"),
	)
	scenery_texture = _texture(root_path.path_join(recipe.background))
	queue_redraw()
	var rear := _texture(ProjectSettings.globalize_path("res://generated/rear.png"))
	var front := _texture(ProjectSettings.globalize_path("res://generated/front.png"))
	var full_actor := Image.load_from_file(root_path.path_join(recipe.actor_atlas))
	var r: Array = recipe.actor_region
	var actor := ImageTexture.create_from_image(
		full_actor.get_region(Rect2i(r[0], r[1], r[2], r[3]))
	)
	_make_effect(Vector2(335, 513), 2.1, actor, rear, front)
	_make_effect(Vector2(1058, 376), 1.65, null, rear, front)
	_make_effect(Vector2(1058, 616), 1.0, actor, rear, front)
	_text("DANS LE SANCTUAIRE", Vector2(42, 151), 15, Color("eee6c9"))
	_text("Agrandissement ×2,1", Vector2(42, 627), 15, Color("eee6c9"))
	_text("LE MOUVEMENT", Vector2(882, 151), 15, Color("c5b27e"))
	_text("Effet seul · même séquence", Vector2(882, 181), 16, Color("8ca89d"))
	_text("TAILLE DE JEU", Vector2(882, 445), 15, Color("c5b27e"))
	_text("Achille reste immobile", Vector2(882, 475), 16, Color("8ca89d"))
	_text("RYTHME", Vector2(26, 681), 13, Color("8ca89d"))
	for i in range(3):
		var factor: float = recipe.tempo_factors[i]
		var button := _button(
			["Vif", "Naturel", "Ample"][i],
			Vector2(24 + i * 116, 705),
			104,
			_set_tempo.bind(factor),
		)
		button.toggle_mode = true
		button.button_pressed = i == 1
		tempo_buttons.append(button)
	_button("Rejouer", Vector2(432, 705), 110, _restart)
	_button("Pause / lecture", Vector2(554, 705), 150, _toggle_play)
	_button("Avec / sans effet", Vector2(716, 705), 170, _toggle_effect)
	clock_label = _text("", Vector2(916, 714), 17, Color("c6d6c6"))
	timeline = HSlider.new()
	timeline.position = Vector2(25, 759)
	timeline.size = Vector2(859, 20)
	timeline.min_value = 0
	timeline.max_value = 2.4
	timeline.step = 1.0 / 30.0
	timeline.value_changed.connect(_seek)
	add_child(timeline)
	_text("Espace : pause   R : rejouer   ← → : image", Vector2(914, 755), 14, Color("8ca89d"))


func _make_effect(
	at: Vector2,
	zoom: float,
	actor_texture: Texture2D,
	rear_texture: Texture2D,
	front_texture: Texture2D,
) -> void:
	var group := Node2D.new()
	group.position = at
	group.scale = Vector2.ONE * zoom
	add_child(group)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.34, 0.73, 0.56, 0.36))
	gradient.set_color(1, Color(0.15, 0.40, 0.33, 0))
	var glow := GradientTexture2D.new()
	glow.width = 128
	glow.height = 128
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(0.5, 1.0)
	var halo := Sprite2D.new()
	halo.texture = glow
	halo.scale = Vector2(1.0, 0.43)
	group.add_child(halo)
	var rear := _flipbook(group, rear_texture)
	if actor_texture != null:
		var actor := Sprite2D.new()
		actor.texture = actor_texture
		actor.centered = false
		var p: Array = recipe.actor_pivot_in_region
		actor.position = -Vector2(p[0], p[1]) * float(recipe.actor_game_scale)
		actor.scale = Vector2.ONE * float(recipe.actor_game_scale)
		group.add_child(actor)
	var front := _flipbook(group, front_texture)
	layers.append({ "rear": rear, "front": front, "halo": halo })


func _flipbook(parent: Node2D, texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.hframes = int(recipe.columns)
	sprite.vframes = int(recipe.rows)
	sprite.offset = (Vector2(0.5, 0.5) - pivot) * float(recipe.frame_size)
	sprite.scale = Vector2.ONE * 256.0 / float(recipe.frame_size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(sprite)
	return sprite


func _restart() -> void:
	playing = true
	_sample(0.0)


func _toggle_play() -> void:
	playing = not playing


func _toggle_effect() -> void:
	show_effect = not show_effect
	_sample(elapsed)


func _seek(value: float) -> void:
	playing = false
	_sample(value)


func _set_tempo(factor: float) -> void:
	tempo = factor
	for i in range(tempo_buttons.size()):
		tempo_buttons[i].button_pressed = is_equal_approx(float(recipe.tempo_factors[i]), factor)
	_sample(0.0)
	playing = true


func _sample(time: float) -> void:
	elapsed = time
	var local := time / tempo
	var frame := clampi(floori(local * float(recipe.fps)), 0, int(recipe.frames) - 1)
	var active := show_effect and local >= 0 and local < float(recipe.frames) / float(recipe.fps)
	for layer in layers:
		layer.rear.frame = frame
		layer.front.frame = frame
		layer.rear.visible = active
		layer.front.visible = active
		layer.halo.visible = active
		layer.halo.modulate.a = smoothstep(0.0, 0.12, local) * (1 - smoothstep(0.45, 1.05, local))
	clock_label.text = "%.2f s  /  %.2f s" % [maxf(time, 0), 1.2 * tempo]
	timeline.set_value_no_signal(maxf(time, 0))


func _process(delta: float) -> void:
	if playing:
		_sample(fmod(elapsed + delta, 2.4 * tempo))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			playing = not playing
		KEY_R:
			_sample(0.0)
			playing = true
		KEY_LEFT:
			playing = false
			_sample(maxf(0, elapsed - 1.0 / 30.0))
		KEY_RIGHT:
			playing = false
			_sample(minf(2.4 * tempo, elapsed + 1.0 / 30.0))


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("101d1e"))
	if scenery_texture != null:
		var source_height := float(scenery_texture.get_height())
		var source_width := source_height * 810.0 / 520.0
		var source_rect := Rect2(
			(scenery_texture.get_width() - source_width) * 0.5,
			0,
			source_width,
			source_height,
		)
		draw_texture_rect_region(scenery_texture, Rect2(24, 136, 810, 520), source_rect)
	draw_line(Vector2(24, 123), Vector2(1256, 123), Color("425447"))
	for rect in [Rect2(858, 136, 398, 274), Rect2(858, 430, 398, 226)]:
		draw_rect(rect, Color("152827"))
		draw_rect(rect, Color("344a40"), false, 1)
	for i in range(5):
		var y := 354.0 + i * 8
		draw_line(Vector2(887, y), Vector2(1227, y), Color(0.25, 0.35, 0.3, 0.14))


func _image_at(time: float) -> Image:
	_sample(time)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _capture() -> void:
	var out := root_path.path_join("artifacts/dev/heal_vfx_study")
	DirAccess.make_dir_recursive_absolute(out.path_join("godot_frames"))
	var area := Rect2i(24, 210, 810, 410)
	var empty := await _image_at(-1)
	var peak := await _image_at(0.36)
	await _image_at(0.70)
	var replay := await _image_at(0.36)
	var finished := await _image_at(1.6)
	var checks := {
		"visible_effect": peak.get_region(area).get_data() != empty.get_region(area).get_data(),
		"deterministic_replay": peak.get_region(area).get_data()
		== replay.get_region(area).get_data(),
		"clean_end": empty.get_region(area).get_data() == finished.get_region(area).get_data(),
		"side_panel_uncovered": absf(empty.get_pixel(1210, 250).r - Color("152827").r) < 0.01,
	}
	for factor in [0.75, 1.3]:
		tempo = factor
		var variant := await _image_at(0.36 * factor)
		checks["tempo_%s_same_pose" % factor] = peak.get_region(area).get_data() == variant \
				.get_region(area) \
				.get_data()
	tempo = 1.0
	show_effect = false
	var without := await _image_at(0.36)
	checks["effect_toggle"] = without.get_region(area).get_data() == empty \
			.get_region(area) \
			.get_data()
	show_effect = true
	var errors: Array[String] = []
	for index in range(72):
		var image := await _image_at(index / 30.0)
		if image.save_png(out.path_join("godot_frames/%03d.png" % index)) != OK:
			errors.append("frame_%03d" % index)
		if index == 11:
			if image.save_png(out.path_join("poster.png")) != OK:
				errors.append("poster")
	var ok := errors.is_empty()
	for value in checks.values():
		ok = ok and value
	var report := {
		"ok": ok,
		"checks": checks,
		"save_errors": errors,
		"capture_frames": 72,
		"fps": 30,
		"godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"scope": "Isolated visual prototype with static real actor and existing scenery. No gameplay, healing values, audio or combat timing validation.",
	}
	var file := FileAccess.open(out.path_join("godot_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	layers.clear()
	tempo_buttons.clear()
	body_font = null
	title_font = null
	scenery_texture = null
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)
