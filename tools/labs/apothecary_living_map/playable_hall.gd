extends "res://tools/labs/apothecary_living_map/living_apothecary.gd"

## Walkable painted hall. Navigation, sprite anchors and occlusion all use the
## same source-pixel space; display resizing only transforms PaintedWorld.
const HallPlayer := preload("res://tools/labs/apothecary_living_map/hall_player.gd")
const Navigation := preload("res://hub/sanctuary_prototype/sanctuary_navigation.gd")
const WALK_LAYOUT := "res://tools/labs/apothecary_living_map/hall_walk_layout.json"
const GROUND_RATIO := 0.5
const ARRIVAL_EPSILON := 0.3

@export_range(80.0, 260.0, 5.0) var movement_speed := 165.0
@export_range(3.0, 18.0, 1.0) var foot_clearance := 10.0

var player: HallPlayer
var nav := Navigation.new()
var _walk_layout: Dictionary = {}
var _actors: Node2D
var _walk_ready := false
var _path := PackedVector2Array()
var _path_index := 0
var _target := Vector2.ZERO
var _speed := 0.0
var _destination: FloorMarker
var _hover_marker: FloorMarker
var _effects_row: HBoxContainer
var _effects_button: Button
var _hint: Label
var _effect_settings_visible := false
var _feedback := ""
var _feedback_until := 0.0
var _last_hover := Vector2(INF, INF)
var _landmark_buttons: Array[Button] = []


class FloorMarker extends Node2D:
	var tint := Color(0.96, 0.81, 0.50, 0.8)
	var radius := 12.0
	var clock := 0.0
	var rejected := false

	func update_clock(value: float) -> void:
		clock = value
		queue_redraw()

	func _draw() -> void:
		if rejected:
			draw_line(Vector2(-5, -3), Vector2(5, 3), tint, 1.4, true)
			draw_line(Vector2(-5, 3), Vector2(5, -3), tint, 1.4, true)
			return
		var points := PackedVector2Array()
		var pulse := 1.0 + sin(clock * 3.2) * 0.06
		for index: int in 49:
			var angle := TAU * float(index) / 48.0
			points.append(Vector2(cos(angle), sin(angle) * 0.5) * radius * pulse)
		draw_polyline(points, tint, 1.35, true)
		if radius > 10.0:
			draw_circle(Vector2.ZERO, 1.7, tint, true, -1.0, true)


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WALK_LAYOUT))
	if not parsed is Dictionary:
		push_error("PlayableHall: invalid walk layout.")
		return
	_walk_layout = parsed
	super._ready()
	if not is_ready_for_preview():
		return
	_build_actor_layer()
	nav.foot_radius = foot_clearance
	nav.create_debug_overlay(_world)
	var obstacles: Array[PackedVector2Array] = []
	for outline: Array in _walk_layout.obstacles:
		obstacles.append(_polygon(outline))
	var configured := await nav.configure(_polygon(_walk_layout.walkable_outline), obstacles)
	if not is_inside_tree():
		return
	_walk_ready = configured and player.is_visual_ready() and nav.is_walkable(player.position)
	if not _walk_ready:
		push_error("PlayableHall: navigation, spawn or Achilles sprite initialization failed.")
	_feedback = "Cliquez sur le sol pour guider Achille."
	_feedback_until = 5.0
	_update_labels()
	print("PLAYABLE_HALL_READY: %s; Achilles scale %.2f; navigation radius %.1f." % [_walk_ready, player.display_scale, foot_clearance])


func _exit_tree() -> void:
	_walk_ready = false
	nav.close()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _process(delta: float) -> void:
	advance_world(delta)
	if _walk_ready:
		_update_hover()


func advance_world(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	if not _paused:
		_time += delta
		if _walk_ready:
			_advance_movement(delta)
	_apply_effects()
	if is_instance_valid(player):
		player.set_environment_time(_time, player.position)
	if is_instance_valid(_destination):
		_destination.update_clock(_time)
		if not is_player_moving() and _time > _feedback_until:
			_destination.hide()
	_update_labels()


func is_ready_for_play() -> bool:
	return _walk_ready


func get_player_position() -> Vector2:
	return player.position if is_instance_valid(player) else Vector2.ZERO


func get_navigation_service() -> RefCounted:
	return nav


func get_player_visual_state() -> Dictionary:
	if not is_instance_valid(player):
		return {}
	var state := player.get_visual_state()
	state["visible"] = player.is_visible_in_tree()
	state["backend"] = "achilles_sprite_2d"
	return state


func is_player_moving() -> bool:
	return not _path.is_empty() and _path_index < _path.size()


func get_walk_state() -> Dictionary:
	var path_points: Array = []
	for point: Vector2 in _path:
		path_points.append([point.x, point.y])
	return {
		"path": path_points, "path_index": _path_index,
		"moving": is_player_moving(), "paused": _paused,
		"target": [_target.x, _target.y],
		"player_position": [get_player_position().x, get_player_position().y],
		"player_facing": player.get_facing() if is_instance_valid(player) else "",
		"navigation_ready": nav.is_navigation_ready(),
		"speed": _speed,
	}


func request_move(native_point: Vector2) -> bool:
	if not _walk_ready or _paused or not native_point.is_finite():
		return false
	var candidate := nav.get_path(player.position, native_point)
	if candidate.is_empty():
		_feedback = "Ce passage est inaccessible."
		_feedback_until = _time + 1.8
		return false
	# Keep the current valid journey when an invalid click is rejected. A valid
	# replacement starts at the current feet, never at the preceding destination.
	_path = candidate
	_path_index = 0
	_target = native_point
	while _path_index < _path.size() and player.position.distance_to(_path[_path_index]) <= ARRIVAL_EPSILON:
		_path_index += 1
	_destination.position = _target
	_destination.rejected = false
	_destination.tint = Color(0.96, 0.81, 0.50, 0.8)
	_destination.show()
	_feedback = ""
	_feedback_until = _time
	if not is_player_moving():
		_finish_movement()
	else:
		player.play_walk(_path[_path_index] - player.position)
	_update_labels()
	return true


func stop_movement() -> void:
	_path.clear()
	_path_index = 0
	_speed = 0.0
	if is_instance_valid(player):
		player.cancel_movement_feedback()
	if is_instance_valid(_destination):
		_destination.hide()
	_feedback = ""
	_feedback_until = _time
	_update_labels()


func _advance_movement(delta: float) -> void:
	if not is_player_moving():
		return
	var remaining := 0.0
	var previous := player.position
	for index: int in range(_path_index, _path.size()):
		remaining += _ground_distance(_path[index] - previous)
		previous = _path[index]
	var desired := minf(movement_speed, sqrt(2.0 * 650.0 * remaining))
	_speed = move_toward(_speed, desired, 850.0 * delta)
	var distance_left := _speed * delta
	while is_player_moving() and distance_left > 0.0:
		var offset := _path[_path_index] - player.position
		var distance := _ground_distance(offset)
		if distance <= ARRIVAL_EPSILON:
			player.position = _path[_path_index]
			_path_index += 1
			continue
		var travelled := minf(distance, distance_left)
		var next_position := player.position + offset * (travelled / distance)
		if not nav.is_walkable(next_position):
			stop_movement()
			_feedback = "Le passage est trop étroit."
			_feedback_until = _time + 2.0
			return
		player.play_walk(offset)
		player.position = next_position
		player.advance_ground_stride(travelled)
		distance_left -= travelled
		if travelled >= distance:
			player.position = _path[_path_index]
			_path_index += 1
	if not is_player_moving():
		_finish_movement()


func _finish_movement() -> void:
	_path.clear()
	_path_index = 0
	_speed = 0.0
	player.play_idle()
	_feedback_until = _time + 0.4


func _ground_distance(offset: Vector2) -> float:
	return Vector2(offset.x, offset.y / GROUND_RATIO).length()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1, KEY_2, KEY_3]:
			_move_to_landmark(int(event.keycode) - int(KEY_1))
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F1:
			nav.debug_enabled = not nav.debug_enabled
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and is_player_moving():
			stop_movement()
			get_viewport().set_input_as_handled()
			return
	super._input(event)


func _unhandled_input(event: InputEvent) -> void:
	if not _walk_ready:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			stop_movement()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var native := _world.to_local(event.position)
			# Water remains responsive but can never become a movement target.
			if not trigger_ripple(native):
				if not request_move(native) and Rect2(Vector2.ZERO, NATIVE_SIZE).has_point(native):
					_destination.position = native
					_destination.rejected = true
					_destination.tint = Color(0.87, 0.55, 0.40, 0.8)
					_destination.show()
					_feedback_until = _time + 1.0
			get_viewport().set_input_as_handled()


func _update_hover() -> void:
	var native := _world.get_local_mouse_position()
	if native.distance_squared_to(_last_hover) < 2.0:
		return
	_last_hover = native
	var screen := get_viewport().get_mouse_position()
	var over_ui := _chrome_visible and (_top.get_global_rect().has_point(screen) or _bottom.get_global_rect().has_point(screen))
	_hover_marker.visible = not over_ui and not _paused and nav.is_walkable(native)
	_hover_marker.position = native


func _build_actor_layer() -> void:
	_destination = FloorMarker.new()
	_destination.name = "Destination"
	_destination.hide()
	_world.add_child(_destination)
	_world.move_child(_destination, 1)
	_hover_marker = FloorMarker.new()
	_hover_marker.name = "WalkableCursor"
	_hover_marker.radius = 7.0
	_hover_marker.tint = Color(0.83, 0.81, 0.66, 0.32)
	_hover_marker.hide()
	_world.add_child(_hover_marker)
	_world.move_child(_hover_marker, 2)
	_actors = Node2D.new()
	_actors.name = "DepthSortedActors"
	_actors.y_sort_enabled = true
	_world.add_child(_actors)
	_world.move_child(_actors, 3)
	player = HallPlayer.new()
	player.name = "Achilles"
	player.position = _point(_walk_layout.spawn)
	player.initial_facing = "E"
	_actors.add_child(player)
	for data: Dictionary in _walk_layout.foreground:
		var anchor := _point(data.anchor)
		var group := Node2D.new()
		group.name = "Foreground_" + str(data.id)
		group.position = anchor
		var cutout := Polygon2D.new()
		var points := _polygon(data.polygon)
		cutout.uv = points.duplicate()
		for index: int in points.size():
			points[index] -= anchor
		cutout.polygon = points
		cutout.texture = map_texture
		cutout.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# Share the animated material so occlusion never freezes the fountain.
		cutout.material = _material
		group.add_child(cutout)
		_actors.add_child(group)


func _build_interface() -> void:
	super._build_interface()
	var stack := _bottom.get_child(0) as VBoxContainer
	_effects_row = stack.get_child(0) as HBoxContainer
	_effects_row.hide()
	_hint = stack.get_child(1) as Label
	_hint.text = "Clic : déplacement   ·   Clic droit : arrêter   ·   Espace : pause   ·   F : plein écran   ·   H : masquer l’interface"
	var travel := HBoxContainer.new()
	travel.add_theme_constant_override("separation", 10)
	stack.add_child(travel)
	stack.move_child(travel, 0)
	var caption := Label.new()
	caption.text = "REJOINDRE"
	caption.add_theme_color_override("font_color", GOLD)
	caption.add_theme_font_size_override("font_size", 12)
	travel.add_child(caption)
	var names := ["1 · Reliques", "2 · Poteries", "3 · Arcanes"]
	for index: int in 3:
		var button := _button(names[index])
		button.name = "WalkTo_%d" % index
		button.pressed.connect(_move_to_landmark.bind(index))
		_landmark_buttons.append(button)
		travel.add_child(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	travel.add_child(spacer)
	_effects_button = _button("Réglages visuels")
	_effects_button.toggle_mode = true
	_effects_button.toggled.connect(_show_effect_settings)
	travel.add_child(_effects_button)
	_pause_button.reparent(travel)
	_update_labels()


func _show_effect_settings(visible: bool) -> void:
	_effect_settings_visible = visible
	_effects_row.visible = visible
	_fit_world()


func _move_to_landmark(index: int) -> void:
	if index >= 0 and index < _walk_layout.get("landmarks", []).size():
		request_move(_point(_walk_layout.landmarks[index].approach))


func _update_labels() -> void:
	super._update_labels()
	if _status == null:
		return
	_status.text = "PRÉPARATION…" if not _walk_ready else ("EN PAUSE" if _paused else ("ACHILLE EN MARCHE" if is_player_moving() else "LA HALLE VOUS ACCUEILLE"))
	if _time < _feedback_until and not _feedback.is_empty():
		_status.text = _feedback
	for button: Button in _landmark_buttons:
		button.disabled = not _walk_ready or _paused
	if _resolution != null:
		_resolution.text = "ACHILLE  ·  HALLE MARCHANDE"


func _fit_world() -> void:
	if _world == null:
		return
	var viewport_size := get_viewport_rect().size
	var top_space := 78.0 if _chrome_visible else 0.0
	var bottom_space := (142.0 if _effect_settings_visible else 96.0) if _chrome_visible else 0.0
	var available := Vector2(maxf(320.0, viewport_size.x - 24.0), maxf(180.0, viewport_size.y - top_space - bottom_space))
	var factor := minf(available.x / NATIVE_SIZE.x, available.y / NATIVE_SIZE.y)
	_world.scale = Vector2.ONE * factor
	_world.position = Vector2((viewport_size.x - NATIVE_SIZE.x * factor) * 0.5, top_space + (available.y - NATIVE_SIZE.y * factor) * 0.5)
	if _bottom != null:
		_bottom.offset_top = -bottom_space + 8.0
	_last_hover = Vector2(INF, INF)


func _point(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))


func _polygon(values: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for item: Array in values:
		points.append(_point(item))
	return points
