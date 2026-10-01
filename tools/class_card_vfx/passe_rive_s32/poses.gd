extends Node2D
const Backend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const PROFILE := preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
const FACINGS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
var actors: Array[Node2D] = []
var output := ""
var capturing := false
var samples: Array = []
var elapsed := 0.0
var started := false
var compact := false


func _ready() -> void:
	get_window().title = "Passe-Rive — Recentrage · huit directions"
	get_window().size = Vector2i(1440, 820)
	get_tree().root.content_scale_size = Vector2i(1440, 820)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--recenter-output="):
			output = arg.trim_prefix("--recenter-output=") + "/"
		if arg == "--recenter-capture":
			capturing = true
	for i in FACINGS.size():
		var actor := Backend.new()
		add_child(actor)
		actor.configure(PROFILE)
		actor.set_backend_active(true)
		actor.set_cards_mode(true)
		actor.set_process(false)
		actor.position = Vector2(180 + (i % 4) * 360, 315 + (i / 4) * 360)
		actor.scale = Vector2.ONE * 2.0
		actor.play_idle(FACINGS[i])
		actors.append(actor)
		var marker := Polygon2D.new()
		marker.name = "HandProbe"
		marker.polygon = PackedVector2Array(
			[Vector2(-2, 0), Vector2(0, -2), Vector2(2, 0), Vector2(0, 2)]
		)
		marker.color = Color(1, .3, .1)
		actor.add_child(marker)
		marker.hide()
	queue_redraw()
	if capturing:
		set_process(false)
		_capture_movie.call_deferred()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1440, 820), Color("222930"))
	var font := ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(25, 35),
		"RECENTRAGE — concentration puis pioche · huit directions · ×2",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		24,
		Color.WHITE,
	)
	for i in FACINGS.size():
		var origin := Vector2((i % 4) * 360, 60 + (i / 4) * 360)
		draw_rect(
			Rect2(origin + Vector2(8, 8), Vector2(344, 344)),
			Color("36413d") if i % 2 == 0 else Color("746c57"),
		)
		draw_line(origin + Vector2(15, 255), origin + Vector2(345, 255), Color(1, 1, 1, .16))
		draw_string(
			font,
			origin + Vector2(20, 38),
			FACINGS[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			24,
			Color.WHITE,
		)
	draw_string(
		font,
		Vector2(25, 810),
		"Échelle constante · pioche 360 ms · retour au repos natif · aucune direction miroir",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		Color.WHITE,
	)


func _step(delta: float) -> void:
	elapsed += delta
	if not started and elapsed >= .3:
		started = true
		for i in actors.size():
			actors[i].play_action(FACINGS[i], &"cast", { "spell_id": "cc2_n08" })
	elif started:
		for actor in actors:
			actor.advance_simulation(delta)
			if actor.get_runtime_state().release_emitted:
				actor.confirm_recenter("cc2_n08", 3 if compact else 2)


func _process(delta: float) -> void:
	_advance_preview(delta)


func _advance_preview(delta: float) -> void:
	_step(delta)
	if elapsed >= 1.6:
		elapsed = 0.0
		started = false
		compact = not compact
		for i in actors.size():
			actors[i].play_idle(FACINGS[i])


func _capture_movie() -> void:
	DirAccess.make_dir_recursive_absolute(output + "frames")
	for frame in 96:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output + "frames/%03d.png" % frame)
		var states: Array = []
		for actor in actors:
			states.append(actor.get_runtime_state())
		samples.append({ "frame": frame, "time": elapsed, "compact": compact, "states": states })
		_advance_preview(1.0 / 30.0)
	FileAccess.open(output + "samples.json", FileAccess.WRITE).store_string(
		JSON.stringify(samples, "\t")
	)
	print("RECENTER_DIRECTIONS_CAPTURED " + output)
	get_tree().quit(0)
