extends Node2D
## Visual laboratory for Cards. No SpellCaster calls, no saved-game changes.
const Effect := preload("effect.gd")
const Player := preload("ethereal_reference.gd")
const Catalog := preload("res://vfx/class_cards/class_card_vfx_catalog.gd")
const Profiles := preload("res://vfx/class_cards/class_card_vfx_profiles.gd")
const OUT := "res://artifacts/dev/class_card_vfx/reference_study/"
const TITLES := ["Épée céleste", "Deux Doigts", "Étendard de bravoure", "Cinq états sur une cible"]
const NOTES := [
	"DOFUS Unity · démonstration du 24/09/2024 · épée suspendue, chute, éclatement au sol",
	"WAVEN · prototype de 2018 · main d’eau à deux doigts, jaillissement puis effondrement",
	"WAKFU · vidéo officielle de 2015 · épée plantée et emblèmes au sol · maintien jusqu’au retrait",
	"Fixture Cartes · marque, brûlure, entrave, saignement, faiblesse · comparer leur coexistence",
]
const SOURCES := [
	"https://www.youtube.com/watch?v=Dw2tuzw_CJk&t=39s",
	"https://totaime.wordpress.com/2018/09/13/waven-note-18-les-icones-et-fx-de-sorts/",
	"https://www.youtube.com/watch?v=DoTwvemkBYE&t=38s",
]
const STYLE_NAMES := ["A · Animation cel · retenue", "B · Matière sculptée", "C · Encre & pigments"]
const STYLE_NOTES := [
	"Aplats francs · arêtes lumineuses",
	"Ombres opaques · reflets découpés",
	"Palette mate · traces de matière",
]
const STATE_NAMES := ["Marque", "Brûlure", "Entrave", "Saignement", "Faiblesse"]
const STATE_IDS := ["class_marked", "class_burn", "class_root", "class_bleed", "class_weak"]
const STATE_FAMILIES := ["mark", "fire", "root", "bleed", "weaken"]
const STATE_COLORS := ["ebc075", "e98d54", "a6c499", "d99797", "ab9ac9"]
var remaining := [1, 2, 1, 2, 1]
var selected := 0
var elapsed := 0.0
var tempo := 1.0
var playing := true
var feedback := true
var bright := false
var released := false
var capturing := false
var pulse := 0.0
var effects: Array[Node2D] = []
var tiles: Array[Control] = []
var art_textures: Array[Texture2D] = []
var art_regions: Array = []
var standard_textures: Array[Texture2D] = []
const STANDARD_REGIONS := [[148, 13, 729, 1493], [185, 20, 654, 1477], [143, 28, 739, 1467]]
var holds: Array[Node] = []
var badges: Array[Label] = []
var headings: Array[Label] = []
var captions: Array[Label] = []
var title_label: Label
var source_label: Label
var phase_label: Label
var clock_label: Label
var slider: HSlider
var selector: OptionButton
var play_button: Button
var turn_button: Button
var release_button: Button
var source_button: Button
var backdrop := preload("res://asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png")
var actor := preload("res://assets/characters/Achilles/passe_rive_iso_v1/atlases/strike_E.png")
var font := preload(
	"res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf"
)


func _ready() -> void:
	get_window().title = "VFX Cartes · DA retenue : animation cel"
	get_viewport().msaa_2d = Viewport.MSAA_4X
	var regions: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tools/class_card_vfx/reference_study/art/regions.json")
	)
	for id in ["cel", "sculpted", "painted"]:
		var bitmap := Image.load_from_file(
			ProjectSettings.globalize_path(
				"res://tools/class_card_vfx/reference_study/art/%s.png" % id
			)
		)
		assert(bitmap != null and not bitmap.is_empty(), "Missing study art: " + id)
		art_textures.append(ImageTexture.create_from_image(bitmap))
		art_regions.append(regions[id].regions)
		var standard_bitmap := Image.load_from_file(
			ProjectSettings.globalize_path(
				"res://tools/class_card_vfx/reference_study/art/standard_%s.png" % id
			)
		)
		assert(
			standard_bitmap != null and not standard_bitmap.is_empty(),
			"Missing standard art: " + id,
		)
		standard_textures.append(ImageTexture.create_from_image(standard_bitmap))
	get_window().size = Vector2i(1440, 1040)
	get_tree().root.content_scale_size = Vector2i(1440, 1040)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	capturing = "--capture" in OS.get_cmdline_user_args()
	_text("CATABASE / RUN CARTES / ÉTUDES D’ANIMATION", Vector2(24, 18), 14, Color("abc2b8"))
	title_label = _text("", Vector2(24, 42), 32, Color("f0e5ce"))
	source_label = _text("", Vector2(25, 89), 16, Color("b6c9bd"))
	selector = OptionButton.new()
	selector.position = Vector2(912, 35)
	selector.size = Vector2(328, 40)
	for name_value in TITLES:
		selector.add_item(name_value)
	selector.item_selected.connect(_select)
	add_child(selector)
	source_button = _button("Voir la référence", Vector2(1250, 35), 166, _open_source)
	for i in 3:
		headings.append(_text(STYLE_NAMES[i], Vector2(40 + i * 472, 133), 21, Color("efdfbd")))
		captions.append(_text(STYLE_NOTES[i], Vector2(40 + i * 472, 162), 14, Color("a8bbb4")))
		_text("VUE RAPPROCHÉE ×1,6", Vector2(40 + i * 472, 205), 12, Color("d8decf"))
		_text(
			"TAILLE DE JEU · ÉCHELLE DE RÉFÉRENCE",
			Vector2(40 + i * 472, 598),
			12,
			Color("a9bdb3"),
		)
	phase_label = _text("", Vector2(25, 872), 18, Color("ead4a1"))
	play_button = _button("Pause", Vector2(24, 916), 95, _toggle_play)
	_button("Rejouer", Vector2(130, 916), 100, _restart)
	_button("×1 / ×0,25", Vector2(241, 916), 119, _toggle_tempo)
	_button("Réaction cible", Vector2(371, 916), 153, _toggle_feedback)
	_button("Fond clair / sombre", Vector2(535, 916), 188, _toggle_background)
	turn_button = _button("Fin d’activation", Vector2(734, 916), 166, _advance_turn)
	release_button = _button("Retirer l’étendard", Vector2(912, 916), 183, _release)
	clock_label = _text("", Vector2(1170, 925), 17, Color("d1dcd1"))
	slider = HSlider.new()
	slider.position = Vector2(25, 972)
	slider.size = Vector2(1070, 24)
	slider.min_value = 0
	slider.max_value = Effect.DURATION
	slider.step = 1.0 / 30.0
	slider.value_changed.connect(_seek)
	add_child(slider)
	_text("Espace : pause  R : rejouer  ← → : image", Vector2(25, 1014), 12, Color("92a99e"))
	_text(
		"Études redessinées · pas encore intégrées au combat",
		Vector2(985, 1014),
		12,
		Color("92a99e"),
	)
	_select(0)
	if capturing:
		playing = false
		_capture.call_deferred()


func _text(value: String, at: Vector2, size_value: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	label.z_index = 10
	add_child(label)
	return label


func _button(value: String, at: Vector2, width: float, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = Vector2(width, 38)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	add_child(button)
	return button


func _select(index: int) -> void:
	selected = index
	selector.select(index)
	released = false
	remaining = [1, 2, 1, 2, 1]
	pulse = 0.0
	elapsed = 0.0
	title_label.text = TITLES[index]
	source_label.text = NOTES[index]
	source_button.disabled = index == 3
	turn_button.disabled = index != 3
	release_button.disabled = index != 2
	for i in 3:
		headings[i].text = (
			["Actuel · cinq auras", "Signaux localisés", "Étiquettes seules"][i]
			if index == 3
			else STYLE_NAMES[i]
		)
		captions[i].text = (
			[
				"Archive éthérée du 22 septembre",
				"Marque en haut · entrave aux pieds",
				"Corps dégagé · impulsion au déclenchement",
			][i]
			if index == 3
			else STYLE_NOTES[i]
		)
	_build_tiles()
	_sample()


func _build_tiles() -> void:
	for hold in holds:
		hold.cancel()
	holds.clear()
	for tile in tiles:
		tile.queue_free()
	for badge in badges:
		badge.queue_free()
	tiles.clear()
	badges.clear()
	effects.clear()
	for column in 3:
		for row in 2:
			var tile := Control.new()
			tile.position = Vector2(24 + column * 472, 190 if row == 0 else 620)
			tile.size = Vector2(448, 389 if row == 0 else 240)
			tile.clip_contents = true
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tile)
			tiles.append(tile)
			var fx := Effect.new()
			fx.study = selected
			fx.treatment = column
			fx.actor = actor
			fx.atlas = art_textures[column]
			fx.art_regions = art_regions[column]
			fx.standard_art = standard_textures[column]
			fx.standard_region = STANDARD_REGIONS[column]
			fx.position = Vector2(222, (300 if selected == 3 else 335) if row == 0 else 205)
			fx.scale = Vector2.ONE * (1.6 if row == 0 else 1.0)
			tile.add_child(fx)
			effects.append(fx)
			if selected == 3 and column == 0:
				for i in 5:
					if remaining[i] <= 0:
						continue
					var entry := Profiles.state(Catalog.feedback(STATE_FAMILIES[i]), STATE_IDS[i])
					var hold := Player.new()
					tile.add_child(hold)
					hold.manual = true
					hold.configure(
						entry,
						fx.global_position,
						92 * float(entry.width) * fx.scale.x,
						fx,
						true,
					)
					holds.append(hold)
		if selected == 3:
			for i in 5:
				if remaining[i] <= 0:
					continue
				var badge := _text(
					"%s · %d act." % [STATE_NAMES[i], remaining[i]],
					Vector2(40 + column * 472 + (i % 3) * 140, 533 + (i / 3) * 25),
					13,
					Color(STATE_COLORS[i]),
				)
				badges.append(badge)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1440, 1040), Color("111e1d"))
	for i in 3:
		for rect in [Rect2(24 + i * 472, 190, 448, 389), Rect2(24 + i * 472, 620, 448, 240)]:
			draw_rect(rect, Color("203b31"))
			draw_texture_rect_region(
				backdrop,
				rect,
				Rect2(450, 350, 850, 570),
				Color(.84, .87, .75) if bright else Color(.40, .47, .42),
			)
			var chosen := selected < 3 and i == 0
			draw_rect(
				rect,
				Color("e6c47c") if chosen else Color("516b5d"),
				false,
				2 if chosen else 1,
			)
	draw_line(Vector2(24, 120), Vector2(1416, 120), Color("597163"), 1)


func _sample() -> void:
	var active: Array[String] = []
	for i in remaining.size():
		if remaining[i] > 0:
			active.append(STATE_NAMES[i])
	for fx in effects:
		fx.feedback = feedback
		fx.released = released
		fx.states = active
		fx.state_pulse = pulse
		fx.sample(elapsed)
	for hold in holds:
		hold.sample(elapsed + 2.0)
	slider.set_value_no_signal(elapsed)
	clock_label.text = "%.2f s / 2.40 · ×%.2f" % [elapsed, tempo]
	phase_label.text = effects[0].phase() if not effects.is_empty() else ""
	if selected == 3:
		phase_label.text = "%d états actifs · durées avancées uniquement par « Fin d’activation »" % active.size()
	play_button.text = "Pause" if playing else "Lecture"


func _process(delta: float) -> void:
	if capturing:
		return
	pulse = maxf(0.0, pulse - delta * 2.5)
	if playing:
		elapsed += delta * tempo
		if elapsed > Effect.DURATION:
			elapsed = Effect.DURATION if selected >= 2 else fmod(elapsed, Effect.DURATION)
	_sample()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			_toggle_play()
		KEY_R:
			_restart()
		KEY_LEFT:
			_seek(maxf(0, elapsed - 1.0 / 30))
		KEY_RIGHT:
			_seek(minf(Effect.DURATION, elapsed + 1.0 / 30))


func _seek(value: float) -> void:
	playing = false
	elapsed = value
	_sample()


func _restart() -> void:
	elapsed = 0
	pulse = 0.0
	released = false
	playing = true
	if selected == 3:
		remaining = [1, 2, 1, 2, 1]
		_build_tiles()
	_sample()


func _toggle_play() -> void:
	playing = not playing
	_sample()


func _toggle_tempo() -> void:
	tempo = .25 if tempo == 1.0 else 1.0
	_sample()


func _toggle_feedback() -> void:
	feedback = not feedback
	_sample()


func _toggle_background() -> void:
	bright = not bright
	queue_redraw()


func _advance_turn() -> void:
	if selected != 3:
		return
	for i in remaining.size():
		remaining[i] = maxi(0, remaining[i] - 1)
	pulse = .85
	_build_tiles()
	_sample()


func _release() -> void:
	if selected == 2:
		released = true
		_sample()


func _open_source() -> void:
	if selected < SOURCES.size():
		OS.shell_open(SOURCES[selected])


func _frame(value: float) -> Image:
	elapsed = value
	_sample()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _fingerprint(image_value: Image, rect := Rect2i(26, 190, 442, 389)) -> String:
	return image_value.get_region(rect).get_data().hex_encode().sha256_text()


func _capture() -> void:
	var output := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(output)
	var checks: Array[Dictionary] = []
	var counts := []
	for index in 3:
		_select(index)
		var folder := output.path_join(["celestial", "water_hand", "standard"][index])
		DirAccess.make_dir_recursive_absolute(folder)
		var clear := await _frame(0.0)
		var before := _fingerprint(clear)
		var peak := await _frame([.76, .46, .85][index])
		peak.save_png(folder.path_join("poster.png"))
		checks.append({ "name": "visible_%d" % index, "passed": _fingerprint(peak) != before })
		var replay := await _frame([.76, .46, .85][index])
		checks.append(
			{
				"name": "deterministic_replay_%d" % index,
				"passed": _fingerprint(replay) == _fingerprint(peak),
			}
		)
		var material_frame := await _frame([.52, .46, .85][index])
		var signatures := []
		for column in 3:
			signatures.append(
				_fingerprint(material_frame, Rect2i(26 + column * 472, 190, 442, 389))
			)
		checks.append(
			{
				"name": "three_distinct_treatments_%d" % index,
				"passed": signatures[0] != signatures[1] and signatures[1] != signatures[2]
				and signatures[0] != signatures[2],
			}
		)
		material_frame.save_png(folder.path_join("material.png"))
		var last := await _frame(2.3)
		checks.append(
			{
				"name": "tail_or_persistence_%d" % index,
				"passed": (
					(_fingerprint(last) != before)
					if index == 2
					else (_fingerprint(last) == before)
				),
			}
		)
		if index == 2:
			var long_hold := await _frame(600.0)
			checks.append(
				{
					"name": "standard_survives_clock",
					"passed": _fingerprint(long_hold) == _fingerprint(last),
				}
			)
			_release()
			var removed := await _frame(600.0)
			checks.append(
				{ "name": "standard_explicit_removal", "passed": _fingerprint(removed) == before }
			)
			released = false
		for frame in 72:
			var rendered := await _frame(frame / 30.0)
			rendered.save_png(folder.path_join("%03d.png" % frame))
		counts.append({ "id": index, "frames": 72 })
	_select(3)
	var stack := await _frame(2.0)
	stack.save_png(output.path_join("states_five.png"))
	checks.append({ "name": "production_five_holds_two_scales", "passed": holds.size() == 10 })
	var settled := await _frame(600.0)
	checks.append(
		{
			"name": "fixture_states_not_timed_out",
			"passed": remaining == [1, 2, 1, 2, 1] and holds.size() == 10,
		}
	)
	_advance_turn()
	var after_turn := await _frame(2.0)
	after_turn.save_png(output.path_join("states_two.png"))
	checks.append(
		{
			"name": "fixture_first_activation",
			"passed": remaining == [0, 1, 0, 1, 0] and holds.size() == 4,
		}
	)
	_advance_turn()
	var after_second := await _frame(2.0)
	after_second.save_png(output.path_join("states_clear.png"))
	checks.append(
		{
			"name": "fixture_second_activation",
			"passed": remaining == [0, 0, 0, 0, 0] and holds.is_empty(),
		}
	)
	_restart()
	checks.append(
		{
			"name": "restart_restores_fixture",
			"passed": remaining == [1, 2, 1, 2, 1] and holds.size() == 10,
		}
	)
	_seek(.5)
	checks.append({ "name": "seek_pauses", "passed": not playing and is_equal_approx(elapsed, .5) })
	_toggle_tempo()
	checks.append({ "name": "quarter_speed", "passed": is_equal_approx(tempo, .25) })
	_toggle_feedback()
	checks.append({ "name": "feedback_toggle", "passed": not effects[0].feedback })
	_toggle_background()
	var clear_background := await _frame(.5)
	clear_background.save_png(output.path_join("states_light.png"))
	checks.append(
		{
			"name": "background_toggle",
			"passed": bright and _fingerprint(clear_background) != _fingerprint(stack),
		}
	)
	var passed := checks.all(
		func(c: Dictionary) -> bool:
			return c.passed,
	)
	var report := {
		"passed": passed,
		"checks": checks,
		"captures": counts,
		"frames": 216,
		"scope": "isolated visual study; fixture durations, no live combat",
		"renderer": RenderingServer.get_video_adapter_name(),
		"engine": Engine.get_version_info().string,
	}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("REFERENCE_STUDY ", JSON.stringify(report))
	for hold in holds:
		hold.cancel()
	get_tree().quit(0 if passed else 1)
