extends Node2D
## Local Spine kit review. Gameplay movement and damage remain owned by combat.

const DIRECTIONS := ["E", "S", "W", "N"]
const ACTIONS := ["idle", "walk", "attack", "cast", "hit", "death"]
const LABELS := ["Repos", "Marche", "Estoc", "Sort", "Impact reçu", "Disparition"]
const DURATIONS := [2.4, 0.72, 0.8, 0.88, 0.2, 0.8]
const BONES := ["root", "torso", "head", "hand_right", "foot_left", "foot_right"]

var _revision := "sentinelle_kit_v7"
var _sprite: Node2D
var _entry: Object
var _title: Label
var _clock: Label
var _direction_selector: OptionButton
var _action_selector: OptionButton
var _pause: CheckButton
var _seek_bar: HSlider
var _direction := 0
var _action := 0
var _time := 0.0
var _speed := 1.0
var _playing := true
var _repeat := false
var _report_path := ""
var _events: Array = []
var _vanishing := false


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--revision="):
			_revision = argument.trim_prefix("--revision=")
		elif argument.begins_with("--report="):
			_report_path = argument.trim_prefix("--report=")
	RenderingServer.set_default_clear_color(Color("192128"))
	var panel := VBoxContainer.new()
	panel.position = Vector2(28, 24)
	panel.add_theme_constant_override("separation", 12)
	add_child(panel)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	panel.add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var direction := OptionButton.new()
	_direction_selector = direction
	for value in DIRECTIONS:
		direction.add_item("Vue " + value)
	direction.item_selected.connect(
		func(index: int):
			_direction = index
			_load_direction(),
	)
	row.add_child(direction)
	var action := OptionButton.new()
	_action_selector = action
	for value in LABELS:
		action.add_item(value)
	action.item_selected.connect(_select_action)
	row.add_child(action)
	var speed := OptionButton.new()
	for value in ["× 1", "× 0,5", "× 0,25"]:
		speed.add_item(value)
	speed.item_selected.connect(
		func(index: int):
			_speed = [1.0, 0.5, 0.25][index],
	)
	row.add_child(speed)
	var pause := CheckButton.new()
	_pause = pause
	pause.text = "Pause"
	pause.toggled.connect(
		func(value: bool):
			_playing = not value,
	)
	row.add_child(pause)
	var repeat := CheckButton.new()
	repeat.text = "Répéter les actions"
	repeat.toggled.connect(
		func(value: bool):
			_repeat = value,
	)
	row.add_child(repeat)
	var restart := Button.new()
	restart.text = "Rejouer"
	restart.pressed.connect(
		func():
			_select_action(_action)
			pause.button_pressed = false,
	)
	row.add_child(restart)
	_seek_bar = HSlider.new()
	_seek_bar.custom_minimum_size.x = 900
	_seek_bar.step = 0.001
	_seek_bar.value_changed.connect(
		func(value: float):
			_playing = false
			_seek(value),
	)
	panel.add_child(_seek_bar)
	_clock = Label.new()
	panel.add_child(_clock)
	var note := Label.new()
	note.text = "Kit d’essai · 24 clips · Estoc : 0,40 s · Sort : 0,44 s · Disparition : explosion noire"
	panel.add_child(note)
	if not ClassDB.class_exists("SpineSprite"):
		_fail("SpineSprite absent : exécuter tools/spine_trial/install.ps1.")
		return
	if not _load_direction():
		return
	if not _report_path.is_empty():
		_playing = false
		_verify()


func _load_direction() -> bool:
	var metadata_path := "res://artifacts/spine_trial/%s/kit.json" % _revision
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	_vanishing = metadata.get("death", "") == "black_burst_disappearance"
	_direction_selector.select(_direction)
	_entry = null
	if is_instance_valid(_sprite):
		remove_child(_sprite)
		_sprite.queue_free()
	var relative := "%s/%s/sentinelle" % [_revision, DIRECTIONS[_direction]]
	var base := ProjectSettings.globalize_path("res://artifacts/spine_trial/" + relative)
	if not FileAccess.file_exists(base + ".json"):
		_fail("Kit absent : lancer tools/spine_trial/kit.ps1 start.")
		return false
	if DirAccess.copy_absolute(base + ".json", base + ".spine-json") != OK:
		_fail("Copie .spine-json impossible.")
		return false
	var skeleton: Object = ClassDB.instantiate("SpineSkeletonFileResource")
	skeleton.call("load_from_file", base + ".spine-json")
	var atlas: Object = ClassDB.instantiate("SpineAtlasResource")
	atlas.call("load_from_atlas_file", base + ".atlas")
	var data: Object = ClassDB.instantiate("SpineSkeletonDataResource")
	data.call("set_atlas_res", atlas)
	data.call("set_skeleton_file_res", skeleton)
	if not data.call("is_skeleton_data_loaded"):
		_fail("Le runtime n’a pas chargé le squelette.")
		return false
	_sprite = ClassDB.instantiate("SpineSprite")
	_sprite.set("skeleton_data_res", data)
	_sprite.position = Vector2(620, 750)
	_sprite.scale = Vector2.ONE * 1.75
	add_child(_sprite)
	_sprite.call("set_time_scale", 0.0)
	_sprite.connect("animation_event", _on_event)
	_select_action(_action)
	return true


func _on_event(_sender: Object, _state: Object, _track: Object, event: Object) -> void:
	_events.append({ "name": event.call("get_data").call("get_event_name"), "time": event.call(
				"get_time"
			) })


func _select_action(index: int) -> void:
	_action = index
	_action_selector.select(index)
	if not is_instance_valid(_sprite):
		return
	var state: Object = _sprite.call("get_animation_state")
	state.call("clear_tracks")
	_sprite.call("get_skeleton").call("set_to_setup_pose")
	_events.clear()
	_entry = state.call("set_animation", ACTIONS[index], false, 0)
	_time = 0.0
	_playing = _report_path.is_empty()
	_pause.set_pressed_no_signal(not _playing)
	_seek_bar.set_block_signals(true)
	_seek_bar.max_value = DURATIONS[index]
	_seek_bar.set_block_signals(false)
	_title.text = "Sentinelle d’airain · %s · %s" % [DIRECTIONS[_direction], LABELS[index]]
	_seek(0.0)


func _seek(value: float) -> void:
	if not is_instance_valid(_entry):
		return
	_time = clampf(value, 0.0, DURATIONS[_action])
	_entry.call("set_track_time", _time)
	_sprite.call("update_skeleton", 0.0)
	_seek_bar.set_value_no_signal(_time)
	_clock.text = "%.2f / %.2f s" % [_time, DURATIONS[_action]]


func _process(delta: float) -> void:
	if not _playing or not is_instance_valid(_entry):
		return
	var next := _time + delta * _speed
	if next > DURATIONS[_action]:
		if _action < 2 or _repeat:
			next = fmod(next, DURATIONS[_action])
		else:
			next = DURATIONS[_action]
			_playing = false
			_pause.set_pressed_no_signal(true)
	_seek(next)


func _pose() -> Array:
	var result: Array = []
	for bone in BONES:
		var transform: Transform2D = _sprite.call("get_global_bone_transform", bone)
		result.append_array(
			[
				transform.origin.x,
				transform.origin.y,
				transform.x.x,
				transform.x.y,
				transform.y.x,
				transform.y.y,
			]
		)
	return result


func _difference(first: Array, second: Array) -> float:
	var result := 0.0
	for index in range(first.size()):
		result = maxf(result, absf(float(first[index]) - float(second[index])))
	return result


func _visibility() -> Dictionary:
	var result := { "body": 0.0, "fx": 0.0 }
	for slot in _sprite.call("get_skeleton").call("get_slots"):
		var name: String = slot.call("get_data").call("get_name")
		var color: Color = slot.call("get_color")
		var key := "fx" if name.begins_with("vanish_") else "body"
		result[key] = maxf(result[key], color.a)
	return result


func _verify() -> void:
	var checks: Array = []
	for direction in range(DIRECTIONS.size()):
		_direction = direction
		if not _load_direction():
			return
		for action in range(ACTIONS.size()):
			_select_action(action)
			var poses: Array = []
			var visibility: Array = []
			for step in range(5):
				_seek(DURATIONS[action] * step / 4.0)
				await RenderingServer.frame_post_draw
				poses.append(_pose())
				visibility.append(_visibility())
				if action == 5 and step == 1 and _vanishing:
					var burst_capture := _report_path.get_base_dir().path_join(
						"%s_burst.png" % DIRECTIONS[direction]
					)
					get_viewport().get_texture().get_image().save_png(burst_capture)
			var observed_events := _events.duplicate(true)
			var duration: float = _entry.call("get_animation").call("get_duration")
			var moving := maxf(_difference(poses[0], poses[1]), _difference(poses[0], poses[2])) > 0.1
			var endpoint := _difference(poses[0], poses[4])
			var endpoint_ok := endpoint > 10.0 if action == 5 else endpoint < 0.01
			if action == 5 and _vanishing:
				moving = visibility[1].fx > 0.1
				endpoint_ok = visibility[4].body == 0.0 and visibility[4].fx == 0.0
			var expected_events: Array = [
				[],
				["footstep_left", "footstep_right"],
				["attack_release"],
				["cast_release"],
				[],
				["death_burst", "vanish"] if _vanishing else ["body_landed"],
			][action]
			var names: Array = observed_events.map(
				func(value: Dictionary):
					return value.name,
			)
			var events_ok := names == expected_events
			_seek(DURATIONS[action] if action == 5 else DURATIONS[action] * 0.5)
			await RenderingServer.frame_post_draw
			var capture := _report_path.get_base_dir().path_join(
				"%s_%s.png" % [DIRECTIONS[direction], ACTIONS[action]]
			)
			var capture_ok := get_viewport().get_texture().get_image().save_png(capture) == OK
			checks.append(
				{
					"direction": DIRECTIONS[direction],
					"action": ACTIONS[action],
					"moving": moving,
					"duration": duration,
					"endpoint_difference": endpoint,
					"events": observed_events,
					"visibility": visibility,
					"events_ok": events_ok,
					"capture": capture,
					"passed": moving and endpoint_ok and events_ok and capture_ok
					and absf(duration - DURATIONS[action]) < 0.00001,
				}
			)
	_finish(
		{
			"passed": checks.size() == 24
			and checks.all(
				func(check: Dictionary):
					return check.passed,
			),
			"revision": _revision,
			"checks": checks,
		}
	)


func _fail(message: String) -> void:
	_title.text = message
	if not _report_path.is_empty():
		_finish({ "passed": false, "error": message })


func _finish(report: Dictionary) -> void:
	var output := FileAccess.open(_report_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	get_tree().quit(0 if report.passed else 1)
