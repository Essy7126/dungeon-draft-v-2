extends "res://tools/class_card_vfx/passe_rive_s22_locomotion.gd"
## Native Godot captures: unchanged drawings, common palette, shared neutral joins.


func _ready() -> void:
	super._ready()
	locomotion_capture = false


func _exercise() -> void:
	capture_mode = false
	await super._exercise()
	if "--room-scale-only" not in OS.get_cmdline_user_args():
		await _scale_boards(true)
		await _transitions()
	await _room_audit()
	_finish()


func _transitions() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 110
	add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("303b3e")
	background.size = Vector2(1440, 950)
	canvas.add_child(background)
	var profile = preload("res://data/visuals/achilles/passe_rive_autosprite_profile_v1.tres")
	var Backend = preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
	var actors: Array[Node] = []
	for i in S19.Data.CARDS.size():
		var actor = Backend.new()
		canvas.add_child(actor)
		actor.configure(profile)
		actor.set_backend_active(true)
		actor.set_cards_mode(true)
		actor.set_process(false)
		actor.position = Vector2(105 + i * 200, 280)
		actor.scale = Vector2.ONE * 1.8
		actor.play_idle("SE")
		actors.append(actor)
		var title := Label.new()
		title.text = S19.Data.CARDS.keys()[i]
		title.position = actor.position + Vector2(-55, 25)
		canvas.add_child(title)
	for frame_index in 75:
		var time := float(frame_index) / 30.0 - .3
		for i in actors.size():
			var actor: Node = actors[i]
			var id: String = S19.Data.CARDS.keys()[i]
			var card: Dictionary = S19.card(id)
			if frame_index == 9:
				actor.play_action("SE", &"cast", { "spell_id": "class_" + id })
			if time >= 0.0 and time < card.body_duration_ms / 1000.0:
				actor._sample_action_at(time)
			elif time >= card.body_duration_ms / 1000.0:
				actor.cancel_action()
				actor.play_idle("SE")
		await _capture("transition_%03d" % frame_index)
	canvas.queue_free()
	await get_tree().process_frame


func _room_audit() -> void:
	(label.get_parent().get_parent().get_parent() as CanvasLayer).hide()
	var results: Array[Dictionary] = []
	var Appearance = preload("res://characters/achilles/2d/passe_rive_appearance.gd")
	# Current production room, followed by differently calibrated catalog rooms.
	var paths := [
		"res://data/rooms/odyssey/room_01.tres",
		"res://data/rooms/odyssey/room_05.tres",
		"res://data/rooms/catabase_expansion/room_06_porteurs.tres",
		"res://data/rooms/catabase_expansion/room_15_moirai.tres",
		"tactical:forge",
		"tactical:garden",
		"tactical:convoy",
		"tactical:hourglass",
		"tactical:reservoir",
	]
	for path in paths:
		battle.queue_free()
		await get_tree().process_frame
		var room: RoomData
		if path.begins_with("tactical:"):
			room = preload("res://core/expedition/card_tactical_room_catalog.gd").replace_room(
				load("res://data/rooms/odyssey/room_01.tres"),
				path.trim_prefix("tactical:"),
			)
		else:
			room = load(path) as RoomData
		GameManager.rooms[0] = room
		get_tree().set_meta(
			&"arena_studio_test_options",
			{
				"active": true,
				"spawn_heroes": true,
				"spawn_enemies": false,
				"deployment_enabled": false,
				"combat_enabled": false,
				"hud_enabled": true,
			},
		)
		battle = room.battle_scene.instantiate()
		add_child(battle)
		get_tree().remove_meta(&"arena_studio_test_options")
		var deadline := Time.get_ticks_msec() + 15000
		while not battle.runtime_ready_state and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		_check(battle.runtime_ready_state, "Room ready: " + path)
		await get_tree().create_timer(.4).timeout
		var visual: Node2D = battle._unit_views[hero]._optional_visual
		visual.set_facing(Vector2i.RIGHT)
		visual.play_idle()
		await get_tree().process_frame
		var actual: float = Appearance.SOURCE_HEIGHT * visual.sprite_profile.display_scale
		actual *= visual.get_global_transform_with_canvas().y.length()
		var owner: Node2D = battle._unit_views[hero]
		var authored: Vector2 = owner._painted_optional_base_scale * owner.get_painted_visual_scale()
		var expected: float = Appearance.SOURCE_HEIGHT * visual.sprite_profile.display_scale * authored.y
		expected *= (visual.get_parent() as Node2D).get_global_transform_with_canvas().y.length()
		_check(visual.scale.is_equal_approx(authored), "No per-hero framing compensation: " + path)
		_check(absf(actual - expected) < .1, "Stature follows calibrated terrain: " + path)
		results.append(
			{ "room": path, "height": actual, "expected": expected, "view_scale": visual.scale.x }
		)
		await _capture("room_" + path.get_file().get_basename().replace(":", "_"))
		var initial := visual.scale
		battle.camera.zoom *= 1.5
		await get_tree().process_frame
		await get_tree().process_frame
		_check(visual.scale == initial, "Explicit inspection zoom stays effective: " + path)
		var zoom_height: float = Appearance.SOURCE_HEIGHT * visual.sprite_profile.display_scale
		zoom_height *= visual.get_global_transform_with_canvas().y.length()
		_check(absf(zoom_height / actual - 1.5) < .001, "Zoom magnifies complete room: " + path)
		if path.ends_with("room_01.tres") or path == "tactical:forge":
			get_window().size = Vector2i(1280, 720)
			get_tree().root.content_scale_size = Vector2i(1280, 720)
			await get_tree().process_frame
			await get_tree().process_frame
			var resized: float = Appearance.SOURCE_HEIGHT * visual.sprite_profile.display_scale
			resized *= visual.get_global_transform_with_canvas().y.length()
			var resize_target: float = Appearance.SOURCE_HEIGHT
			resize_target *= visual.sprite_profile.display_scale
			var parent_canvas := (visual.get_parent() as Node2D).get_global_transform_with_canvas()
			resize_target *= authored.y * parent_canvas.y.length()
			_check(
				absf(resized - resize_target) < .1,
				"Resize preserves terrain-relative stature: " + path,
			)
			get_window().size = Vector2i(1440, 950)
			get_tree().root.content_scale_size = Vector2i(1440, 950)
			await get_tree().process_frame
			await get_tree().process_frame
	battle.queue_free()
	await get_tree().process_frame
	var Hall = preload("res://hub/painted_halt/living_halt.gd")
	for id in [
		"seuil_crossroads",
		"underworld_threshold",
		"companions_quarry",
		"stele_names",
		"emerald_sanctuary",
		"bronze_forge",
		"bronze_workshop_pilot",
		"threshold_actual",
	]:
		var hall
		if id == "threshold_actual":
			hall = preload("res://hub/catabase_threshold/catabase_threshold.gd").new()
			hall._entry_run = GameManager.get_active_run_data()
			hall.manifest_path = "res://data/halts/underworld_threshold_v1.json"
		else:
			hall = Hall.new()
			hall.manifest_path = "res://data/halts/" + id + "_v1.json"
		hall.preview_mode = false
		hall.audio_enabled = false
		add_child(hall)
		var deadline := Time.get_ticks_msec() + 15000
		while not hall._ready_for_play and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		_check(hall._ready_for_play, "Halt ready: " + id)
		if hall.player != null:
			hall.player.face_for_direction(Vector2(2, 1))
			hall.player.play_idle()
			await get_tree().process_frame
			var actual: float = Appearance.SOURCE_HEIGHT * hall.player.display_scale
			actual *= hall.player.get_global_transform_with_canvas().y.length()
			var expected: float = Hall.ScaleReference.height_ratio(hall.definition)
			expected *= Hall.ScaleReference.world_height(hall.definition)
			expected *= hall.world.get_global_transform_with_canvas().y.length()
			_check(absf(actual - expected) < .1, "Authored halt stature: " + id)
			results.append(
				{
					"room": id,
					"height": actual,
					"expected": expected,
					"display_scale": hall.player.display_scale,
				}
			)
			await _capture("room_" + id)
			hall.zoom = 1.5
			hall._fit_world()
			var magnified: float = Appearance.SOURCE_HEIGHT * hall.player.display_scale
			magnified *= hall.player.get_global_transform_with_canvas().y.length()
			_check(absf(magnified / actual - 1.5) < .001, "Halt manual zoom: " + id)
		hall.queue_free()
		await get_tree().process_frame
	FileAccess.open(output_path + "rooms.json", FileAccess.WRITE).store_string(
		JSON.stringify(results, "\t")
	)
