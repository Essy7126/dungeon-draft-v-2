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
	locomotion_capture = "--s22-capture" in OS.get_cmdline_user_args()
	super._ready()


func _exercise() -> void:
	capture_mode = false
	await super._exercise()
	# Studio disables the combat startup that normally connects displacement.
	if not EventBus.unit_pushed.is_connected(battle._on_unit_pushed):
		EventBus.unit_pushed.connect(battle._on_unit_pushed)
	get_window().title = "Passe-Rive — S22 : marche, sorts et ruée"
	var tour := Button.new()
	tour.text = "Essayer marche → sorts → ruée"
	tour.position = Vector2(320, 20)
	tour.size = Vector2(330, 44)
	label.get_parent().get_parent().get_parent().add_child(tour)
	tour.pressed.connect(_tour)
	var dash_button := Button.new()
	dash_button.text = "Ruée / Percée"
	dash_button.position = Vector2(665, 20)
	dash_button.size = Vector2(210, 44)
	tour.get_parent().add_child(dash_button)
	dash_button.pressed.connect(_on_dash_pressed)
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
		_check(backend.get_runtime_state().directional_source.begins_with("autosprite_v1/idle_"), trial)
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
			var floor_start: Vector2 = battle.grid_cell_to_parent_local(path[0], view.get_parent())
			var floor_end: Vector2 = battle.grid_cell_to_parent_local(path[1], view.get_parent())
			var floor_delta := floor_end - floor_start
			var ground_delta := Vector2(floor_delta.x, floor_delta.y * 2.0)
			var floor_distance := ground_delta.length() / absf(visual.scale.x)
			var reference_stride := 300.0 if length >= 3 else 180.0
			var native_scale: float = visual.sprite_profile.display_scale
			var source_stride := reference_stride * native_scale
			var cycle_seconds := 0.60 if length >= 3 else 0.72
			var expected_duration := floor_distance / source_stride * cycle_seconds
			_check(
				is_equal_approx(view.get_movement_segment_duration(path), expected_duration),
				"Exploration cadence at the actual cell scale: " + trial,
			)
			recording = locomotion_capture
			await get_tree().create_timer(0.4).timeout
			hero.current_mp = 30
			# Production request owns PM, tween, facing and distance-driven poses.
			await battle._on_request_move_to(path[-1])
			_check(hero.grid_pos == path[-1], "Actual walk arrives: " + trial)
			_check(
				str(backend.get_runtime_state().animation).begins_with("idle_")
				and not backend.body.visible,
				"Arrival returns to neutral: " + trial,
			)
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
	capture_mode = locomotion_capture
	direction_audit = true
	target_direction = "SE"
	for id in S19.Data.CARDS:
		trial = id
		recording = locomotion_capture
		await _play_card(id)
		await get_tree().create_timer(.35).timeout
		recording = false
	for direction in ["SE", "SW", "NW", "NE"]:
		await _play_dash(direction)
	if locomotion_capture:
		await _scale_boards()
	capture_mode = false
	label.text = "Marche des espaces libres, sorts et ruée. Relancer avec le bouton du haut."


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
	await RenderingServer.frame_post_draw
	if not recording or not is_instance_valid(battle):
		return
	var view: Node2D = battle._unit_views[hero]
	var state: Dictionary = view._optional_visual.sprite_backend.get_runtime_state()
	var shot := get_viewport().get_texture().get_image()
	var center := view.get_global_transform_with_canvas() * Vector2(0, -45)
	var origin := Vector2i(center) - Vector2i(240, 210)
	origin.x = clampi(origin.x, 0, shot.get_width() - 480)
	origin.y = clampi(origin.y, 0, shot.get_height() - 360)
	movie_frames.append(shot.get_region(Rect2i(origin, Vector2i(480, 360))))
	samples.append(
		{
			"trial": trial,
			"state": state,
			"position": [view.position.x, view.position.y],
			"visual_scale": view._optional_visual.scale.x,
			"captured_ms": Time.get_ticks_msec(),
		}
	)


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


var dash_releases := 0


func _release() -> void:
	if current_card == "g_charge":
		dash_releases += 1
		captured_release = true
		release_state = battle._unit_views[hero]._optional_visual.sprite_backend.get_runtime_state()
	else:
		super._release()


func _inspect_contact(caster: Unit, spell: Spell, report: Dictionary) -> void:
	if spell.spell_id == &"class_g_charge":
		return
	super._inspect_contact(caster, spell, report)


func _on_dash_pressed() -> void:
	if busy or walking:
		return
	if target_direction not in ["SE", "SW", "NW", "NE"]:
		label.text = "Percée suit une ligne de cases : choisis SE, SW, NW ou NE."
		return
	await _play_dash(target_direction)


func _play_dash(direction: String) -> void:
	var path := _find_straight_path(
		DIRECTIONS[direction],
		1 if direction in ["E", "W", "S", "N"] else 2,
	)
	_check(not path.is_empty(), "Dash path " + direction)
	if path.is_empty():
		return
	var view: Node2D = battle._unit_views[hero]
	var visual: Node = view._optional_visual
	var backend: Node = visual.sprite_backend
	_move(hero, path[0])
	view.synchronize_external_movement()
	visual.set_facing(DIRECTIONS[direction])
	visual.play_idle()
	battle.camera.global_position = view.global_position + Vector2(0, -35)
	hero.start_turn()
	# Let the production turn banner clear before recording the character.
	await get_tree().create_timer(1.8).timeout
	hero.current_ap = hero.max_ap.get_int()
	session.cards.hand.assign([session.cards.add_copy("g_charge")])
	current_card = "g_charge"
	busy = true
	trial = "dash_" + direction
	dash_releases = 0
	last_report = { }
	recording = locomotion_capture
	label.text = "Ruée · " + direction + " · départ, trajet, réception"
	await get_tree().create_timer(.3).timeout
	var spell := Cards.make_spell("g_charge")
	var rejection: StringName = battle.spell_caster.get_cast_failure_reason(hero, spell, path[-1])
	_check(rejection == &"", trial + " is a legal cast: " + str(rejection))
	battle._on_request_cast_spell(spell, path[-1])
	var seen_travel := false
	var seen_landing := false
	var landing_at_destination := true
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline:
		var state: Dictionary = backend.get_runtime_state()
		if state.stem == "dash" and state.action_pending and state.release_emitted:
			seen_travel = seen_travel or (state.frame >= 2 and state.frame <= 13)
		if state.landing_pending:
			seen_landing = true
			var destination: Vector2 = battle.grid_cell_to_parent_local(path[-1], view.get_parent())
			landing_at_destination = landing_at_destination and view.position.distance_to(
					destination
				) < .1
		if seen_landing and not state.landing_pending and not battle._spell_resolution_pending:
			break
		await get_tree().process_frame
	_check(seen_travel, trial + " native travel frames visible")
	_check(seen_landing and landing_at_destination, trial + " landing starts on destination only")
	_check(dash_releases == 1, trial + " exactly one release")
	_check(hero.grid_pos == path[-1], trial + " real gameplay arrival")
	_check(
		not last_report.is_empty() and not last_report.get("failed", false),
		trial + " real card resolves",
	)
	_check(
		str(backend.get_runtime_state().animation).begins_with("idle_"),
		trial + " returns to neutral",
	)
	casts.append(
		{
			"id": "g_charge",
			"direction": direction,
			"release": release_state,
			"report": _compact_report(),
		}
	)
	await get_tree().create_timer(.4).timeout
	recording = false
	busy = false


func _scale_boards(raw_source_poses := false) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	var background := ColorRect.new()
	background.size = Vector2(1440, 950)
	background.color = Color("303b3e")
	canvas.add_child(background)
	var profile = preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
	var Backend = preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
	for direction in ["E", "SE", "S", "NE", "N"]:
		var actors: Array[Node] = []
		for row in 3:
			var ids := [""]
			ids.append_array(S19.Data.CARDS.keys())
			for col in ids.size():
				var actor = Backend.new()
				canvas.add_child(actor)
				actors.append(actor)
				actor.configure(profile)
				actor.set_backend_active(true)
				actor.set_cards_mode(true)
				actor.set_process(false)
				actor.position = Vector2(90 + col * 178, 250 + row * 290)
				actor.scale = Vector2.ONE * 1.8
				actor.play_idle(direction)
				if col > 0:
					var card: Dictionary = S19.card(ids[col])
					actor.play_action(direction, &"cast", { "spell_id": "class_" + ids[col] })
					actor._sample_action_at(
						[0.0, card.confirm_ms / 1000.0, card.body_duration_ms / 1000.0 - .01][row]
					)
					if raw_source_poses:
						actor.body.modulate = Color.WHITE
						actor.animated_sprite.hide()
				var title := Label.new()
				title.text = ("Repos " + direction if col == 0 else ids[col]) + " · " + [
					"départ",
					"contact",
					"retour",
				][row]
				title.position = Vector2(12 + col * 178, 265 + row * 290)
				canvas.add_child(title)
				actors.append(title)
		await _capture("scale_" + direction)
		for actor in actors:
			actor.queue_free()
		await get_tree().process_frame
	canvas.queue_free()
