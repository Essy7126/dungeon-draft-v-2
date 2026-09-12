extends Node2D

# Absolute-time sampling keeps pause, reverse scrubbing and captures equivalent.
# This is a bounded rendering experiment, not a new production VFX runtime.
var repo_root: String
var recipe: Dictionary
var groups: Array[Dictionary] = []
var textures: Array[Texture2D] = []
var bounds: Array[Rect2] = []
var study_shader: Shader
var time_ms := 0.0
var playing := true
var show_chips := true
var gray := false
var use_erosion := true
var time_label: Label
var capture_mode := false


func _ready() -> void:
	repo_root = ProjectSettings.globalize_path("res://").path_join("../../..").simplify_path()
	recipe = JSON.parse_string(FileAccess.get_file_as_string("res://recipe.json"))
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	var source: String = repo_root.path_join(recipe.source)
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(source.path_join("preparation_manifest.json"))
	)
	for layer: Dictionary in manifest.layers:
		var b: Array = layer.bounds
		var rect := Rect2(b[0], b[1], b[2] - b[0], b[3] - b[1])
		bounds.append(rect)
		# Runtime upload of the occupied region; the source PNG is never rewritten.
		var original := Image.load_from_file(source.path_join("layers/" + layer.id + ".png"))
		textures.append(ImageTexture.create_from_image(original.get_region(Rect2i(rect))))
	study_shader = Shader.new()
	study_shader.code = FileAccess.get_file_as_string("res://contact.gdshader")
	_build_review()
	_sample(0.0)
	if capture_mode:
		playing = false
		_capture.call_deferred()


func _label(text: String, at: Vector2, size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("d9d6c8"))
	add_child(label)
	return label


func _build_review() -> void:
	_label("FRAPPE DU PÉLÉIDE · étude d’une construction", Vector2(24, 17), 27)
	_label(
		"Même peinture, trois rythmes. Contact fixé ; éclats séparés ; érosion de l’alpha.",
		Vector2(24, 56),
	)
	var names := ["A · sec", "B · référence", "C · ample"]
	var actor := ImageTexture.create_from_image(
		Image.load_from_file(
			repo_root.path_join(
				"art/source/characters/catabase_monsters/rejeton_braise/base_frame_E.png"
			)
		)
	)
	var map_image := Image.load_from_file(
		repo_root.path_join("asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png")
	)
	map_image.resize(1100, int(map_image.get_height() * 1100.0 / map_image.get_width()))
	var map_texture := ImageTexture.create_from_image(
		map_image.get_region(Rect2i(350, 320, 372, 225))
	)
	for column in range(3):
		var x := 24.0 + column * 392.0
		var duration := roundi(
			float(recipe.chips_end_ms.max()) * float(recipe.tempo_factors[column])
		)
		_label("%s / %d ms" % [names[column], duration], Vector2(x, 102), 21)
		_make_effect(Vector2(x + 234, 253), 3.0, float(recipe.tempo_factors[column]))
		_label("Agrandissement ×3 — point de contact +", Vector2(x, 364), 15)
		var bg := Sprite2D.new()
		if column == 2:
			bg.texture = map_texture
			bg.centered = false
			bg.position = Vector2(x, 433)
			add_child(bg)
		else:
			bg.free()
		var target := Sprite2D.new()
		target.texture = actor
		target.position = Vector2(x + 215, 576)
		target.scale = Vector2.ONE * 0.35
		add_child(target)
		_make_effect(Vector2(x + 201, 581), 1.0, 1.0)
		_label(
			["Fond sombre", "Pierre claire", "Décor peint existant"][column],
			Vector2(x, 404),
			19,
		)
	_label(
		"%d px de largeur de référence · cible de référence · composition de laboratoire, hors combat"
		% int(recipe.study_width_px),
		Vector2(24, 669),
		16,
	)
	time_label = _label("", Vector2(24, 706), 18)
	_label(
		"Espace : pause   R : rejouer   ← → : temps   G : silhouette   M : éclats   D : érosion",
		Vector2(24, 740),
		16,
	)


func _make_effect(at: Vector2, zoom: float, tempo: float) -> void:
	var group := Node2D.new()
	group.position = at
	group.scale = Vector2.ONE * zoom
	add_child(group)
	var sprites: Array[Sprite2D] = []
	for i in range(4):
		var sprite := Sprite2D.new()
		sprite.texture = textures[i]
		var material := ShaderMaterial.new()
		material.shader = study_shader
		sprite.material = material
		if i == 0:
			var pivot := Vector2(recipe.source_pivot[0], recipe.source_pivot[1])
			sprite.offset = bounds[i].get_center() - pivot
		group.add_child(sprite)
		sprites.append(sprite)
	groups.append({ "node": group, "sprites": sprites, "tempo": tempo })


func _contact_scale(t: float) -> Vector2:
	var keys: Array = recipe.contact_scale_keys
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t <= float(b[0]):
			var u := clampf((t - float(a[0])) / (float(b[0]) - float(a[0])), 0, 1)
			return Vector2(a[1], a[2]).lerp(Vector2(b[1], b[2]), 1.0 - pow(1.0 - u, 3))
	var last: Array = keys.back()
	return Vector2(last[1], last[2])


func _sample(t: float) -> void:
	time_ms = t
	var unit_scale := float(recipe.study_width_px) / float(recipe.source_width_px)
	for group: Dictionary in groups:
		var local_time := t / float(group.tempo)
		var main: Sprite2D = group.sprites[0]
		main.visible = local_time >= 0 and local_time < float(recipe.contact_erosion_ms[1])
		main.scale = _contact_scale(local_time) * unit_scale
		var erosion := clampf(
			inverse_lerp(
				float(recipe.contact_erosion_ms[0]),
				float(recipe.contact_erosion_ms[1]),
				local_time,
			),
			0,
			1,
		)
		main.material.set_shader_parameter("erosion", erosion if use_erosion else 0.0)
		main.modulate.a = 1.0 - erosion if not use_erosion else 1.0
		main.material.set_shader_parameter("silhouette", gray)
		for i in range(3):
			var chip: Sprite2D = group.sprites[i + 1]
			var u := clampf(
				inverse_lerp(
					float(recipe.chips_start_ms[i]),
					float(recipe.chips_end_ms[i]),
					local_time,
				),
				0,
				1,
			)
			chip.visible = show_chips and local_time >= float(recipe.chips_start_ms[i]) and u < 1
			var travel: Array = recipe.chips_travel_px[i]
			var target := Vector2(travel[0], travel[1])
			chip.position = target * (0.2 + 0.8 * (1.0 - pow(1.0 - u, 3)))
			chip.position.y += float(recipe.chip_gravity_px) * u * u
			chip.rotation = deg_to_rad(float(recipe.chips_rotation_deg[i])) * u
			chip.scale = Vector2.ONE * unit_scale * lerpf(0.75, 0.5, u)
			chip.modulate.a = 1.0 - smoothstep(0.35, 1.0, u)
			chip.material.set_shader_parameter("silhouette", gray)
	time_label.text = "t = %03d ms   |   Peinture candidate : cette étude ne valide pas la DA finale." % maxi(
		0,
		int(t),
	)


func _process(delta: float) -> void:
	if playing:
		_sample(fmod(time_ms + delta * 1000.0, 1400.0))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			playing = not playing
		KEY_R:
			time_ms = 0.0
		KEY_G:
			gray = not gray
		KEY_M:
			show_chips = not show_chips
		KEY_D:
			use_erosion = not use_erosion
		KEY_LEFT:
			playing = false
			time_ms = maxf(0, time_ms - 1000.0 / 60.0)
		KEY_RIGHT:
			playing = false
			time_ms = minf(600, time_ms + 1000.0 / 60.0)
	_sample(time_ms)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1200, 780), Color("172127"))
	for column in range(3):
		var x := 24.0 + column * 392.0
		draw_rect(Rect2(x, 138, 372, 215), Color("263238"))
		draw_line(Vector2(x + 228, 253), Vector2(x + 240, 253), Color("697575"))
		draw_line(Vector2(x + 234, 247), Vector2(x + 234, 259), Color("697575"))
		draw_rect(Rect2(x, 433, 372, 225), Color("202b30") if column == 0 else Color("d5ceba"))


func _frame_at(t: float) -> Image:
	_sample(t)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _capture() -> void:
	var output := repo_root.path_join("artifacts/dev/peleid_contact_study")
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	var before := await _frame_at(-1)
	var first := await _frame_at(50)
	await _frame_at(180)
	var repeat := await _frame_at(50)
	var after := await _frame_at(600)
	var panel := Rect2i(24, 138, 1156, 215)
	var replay_equal := first.get_region(panel).get_data() == repeat.get_region(panel).get_data()
	var end_clean := before.get_region(panel).get_data() == after.get_region(panel).get_data()
	var visible_contact := first.get_region(panel).get_data() != before.get_region(panel).get_data()
	var save_errors: Array[String] = []
	for t in [0, 33, 65, 100, 150, 250, 432]:
		var frame := await _frame_at(t)
		if frame.save_png(output.path_join("t_%03d.png" % t)) != OK:
			save_errors.append("t_%03d" % t)
	for index in range(84):
		var frame := await _frame_at(index * 1000.0 / 60.0)
		if frame.save_png(output.path_join("frames/%03d.png" % index)) != OK:
			save_errors.append("frame_%03d" % index)
	var report := {
		"scope": "isolated painted cutout study; no gameplay, audio, production import or performance certification",
		"godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"replay_pixels_equal": replay_equal,
		"end_pixels_equal_to_empty": end_clean,
		"contact_changes_pixels": visible_contact,
		"save_errors": save_errors,
		"sequence_frames": 84,
		"sequence_fps": 60,
		"source_art_status": recipe.status,
	}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	# Dispose scene-owned textures before the renderer is torn down.
	groups.clear()
	textures.clear()
	study_shader = null
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(
		0 if replay_equal and end_clean and visible_contact and save_errors.is_empty() else 1
	)
