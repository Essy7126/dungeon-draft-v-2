extends "res://tools/class_card_vfx/passe_rive_s19_arena.gd"
## Real Battle walking, then casts, in the same Studio fixture as the spell audit.
var locomotion_capture := false
var recording := false
var samples: Array[Dictionary] = []
var movie_frames: Array[Image] = []
var record_elapsed := 0.0
var trial := ""
var walking := false


func _ready() -> void:
	hud_enabled = true
	locomotion_capture = "--s21-capture" in OS.get_cmdline_user_args()
	super._ready()


func _exercise() -> void:
	capture_mode = false
	await super._exercise()
	get_window().title = "Passe-Rive — marche et repos neutres"
	var tour := Button.new()
	tour.text = "Essayer marche → arrêt → sorts"
	tour.position = Vector2(320, 20)
	tour.size = Vector2(330, 44)
	label.get_parent().get_parent().get_parent().add_child(tour)
	tour.pressed.connect(_tour)
	if locomotion_capture:
		await _tour()
		_finish()


func _tour() -> void:
	if busy or walking:
		return
	walking = true
	var view: Node2D = battle._unit_views[hero]
	var visual: PasseRiveAutoSpriteView = view._optional_visual
	var backend: Node = visual.sprite_backend
	for direction in DIRECTIONS:
		visual.set_facing(DIRECTIONS[direction])
		visual.play_idle()
		trial = "idle_" + direction
		await get_tree().create_timer(0.12).timeout
		_check(backend.get_runtime_state().directional_source.begins_with("PR_LOCOMOTION_"), trial)
		if locomotion_capture:
			await _capture(trial)
	for step in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		for length in [1, 3]:
			var path := _find_straight_path(step, length)
			_check(not path.is_empty(), "Walkable straight path %s × %d" % [step, length])
			if path.is_empty():
				continue
			_move(hero, path[0])
			view.synchronize_external_movement()
			visual.set_facing(step)
			visual.play_idle()
			battle.camera.global_position = view.global_position + Vector2(0, -35)
			trial = "%s_%d" % [backend.get_runtime_state().facing, length]
			label.text = "Marche %s · %d case(s) · mains libres" % [
				backend.get_runtime_state().facing,
				length,
			]
			_check(
				is_equal_approx(view.get_movement_segment_duration(path), 0.72),
				"Same walking speed: " + trial,
			)
			recording = locomotion_capture
			await get_tree().create_timer(0.4).timeout
			hero.current_mp = 30
			# Production request owns PM, tween, facing and distance-driven poses.
			await battle._on_request_move_to(path[-1])
			_check(hero.grid_pos == path[-1], "Actual walk arrives: " + trial)
			_check(backend.body.current_clip == "PR_IDLE", "Arrival returns to neutral: " + trial)
			await get_tree().create_timer(0.4).timeout
			recording = false
			if locomotion_capture:
				await _capture("arrived_" + trial)
	# A real bent path checks that phase is not restarted at a corner.
	trial = "corner"
	var corner := _find_corner_path()
	_check(not corner.is_empty(), "A walkable corner is available")
	if not corner.is_empty():
		_move(hero, corner[0])
		view.synchronize_external_movement()
		battle.camera.global_position = view.global_position + Vector2(0, -35)
		recording = locomotion_capture
		await battle._animate_move(hero, corner)
		await get_tree().create_timer(0.4).timeout
		recording = false
		_check(hero.grid_pos == corner[-1], "Corner path arrives")
	walking = false
	capture_mode = locomotion_capture
	direction_audit = true
	target_direction = "SE"
	for id in ["r_shot", "a_dagger", "t_fire"]:
		trial = id
		recording = locomotion_capture
		await _play_card(id)
		await get_tree().create_timer(.35).timeout
		recording = false
	capture_mode = false
	label.text = "Marche et repos neutres. Les sorts restent disponibles à gauche."


func _find_straight_path(step: Vector2i, length: int) -> Array:
	var best: Array = []
	var best_score := -1
	for start in _central_cells():
		var path: Array = []
		for i in range(length + 1):
			var cell: Vector2i = start + step * i
			if not battle.grid.is_walkable(cell) or (
					battle.grid.has_unit(cell) and cell != hero.grid_pos
				):
				break
			path.append(cell)
		if path.size() == length + 1:
			var score := 0
			for cell in path:
				for y in range(-1, 2):
					for x in range(-1, 2):
						if battle.grid.is_walkable(cell + Vector2i(x, y)):
							score += 1
			if score > best_score:
				best_score = score
				best = path
	return best


func _find_corner_path() -> Array:
	for start in _central_cells():
		var path: Array = [
			start,
			start + Vector2i.RIGHT,
			start + Vector2i(2, 0),
			start + Vector2i(2, 1),
			start + Vector2i(2, 2),
		]
		var valid := true
		for cell in path:
			if not battle.grid.is_walkable(cell) or (
					battle.grid.has_unit(cell) and cell != hero.grid_pos
				):
				valid = false
		if valid:
			return path
	return []


func _process(delta: float) -> void:
	if not recording or not is_instance_valid(battle):
		return
	record_elapsed += delta
	if record_elapsed < 1.0 / 12.0:
		return
	record_elapsed = 0.0
	var view: Node2D = battle._unit_views[hero]
	var state: Dictionary = view._optional_visual.sprite_backend.get_runtime_state()
	samples.append(
		{
			"trial": trial,
			"state": state,
			"position": [view.position.x, view.position.y],
			"visual_scale": view._optional_visual.scale.x,
		}
	)
	await RenderingServer.frame_post_draw
	if not is_instance_valid(view):
		return
	var shot := get_viewport().get_texture().get_image()
	var center := view.get_global_transform_with_canvas() * Vector2(0, -45)
	var origin := Vector2i(center) - Vector2i(240, 210)
	origin.x = clampi(origin.x, 0, shot.get_width() - 480)
	origin.y = clampi(origin.y, 0, shot.get_height() - 360)
	movie_frames.append(shot.get_region(Rect2i(origin, Vector2i(480, 360))))


func _finish() -> void:
	FileAccess.open(output_path + "locomotion_samples.json", FileAccess.WRITE).store_string(
		JSON.stringify(samples, "\t")
	)
	for i in range(movie_frames.size()):
		_check(
			movie_frames[i].save_png(output_path + "frames/%04d.png" % i) == OK,
			"Movie frame %d" % i,
		)
	movie_frames.clear()
	super._finish()
