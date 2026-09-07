class_name ChampionMasteryMinimap
extends Control
## A fixed navigation lens. Its points are graph coordinates, never mastery actions.

signal recenter_requested(graph_point: Vector2)
signal collapsed_changed(collapsed: bool)

const STYLE := preload("res://ui/progression/theme/spell_codex_style.gd")
const EXPANDED_SIZE := Vector2(120, 146)
const COLLAPSED_SIZE := Vector2(68, 26)
var _bounds := Rect2(0, 0, 1, 1)
var _viewport := Rect2()
var _nodes: Array[Dictionary] = []
var _edges: Array[Dictionary] = []
var _selected_id: StringName = &""
var _map_rect := Rect2(10, 30, 100, 106)
var _map_scale := 1.0
var _map_offset := Vector2.ZERO
var _dragging := false
var _collapsed := false
var _toggle: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	size = EXPANDED_SIZE
	tooltip_text = "Carte des maîtrises · Cliquer ou glisser pour se déplacer. Flèches au clavier."
	_toggle = Button.new()
	_toggle.name = "ToggleMap"
	_toggle.position = Vector2(4, 3)
	_toggle.size = Vector2(size.x - 8, 20)
	_toggle.text = "−  CARTE"
	_toggle.add_theme_font_override("font", STYLE.BOLD)
	_toggle.add_theme_font_size_override("font_size", 10)
	_toggle.add_theme_color_override("font_color", STYLE.GOLD)
	_toggle.add_theme_stylebox_override("normal", STYLE.box(Color.TRANSPARENT, Color.TRANSPARENT, 2))
	_toggle.add_theme_stylebox_override("hover", STYLE.box(Color("342b22"), Color("907455"), 2))
	_toggle.add_theme_stylebox_override("pressed", STYLE.box(Color("171410"), STYLE.GOLD, 2))
	_toggle.add_theme_stylebox_override("focus", STYLE.box(Color.TRANSPARENT, STYLE.TEXT, 2))
	_toggle.pressed.connect(func() -> void: set_collapsed(not _collapsed))
	add_child(_toggle)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(_update_geometry)
	_update_geometry()


func update_map(content_bounds: Rect2, nodes: Array[Dictionary], edges: Array[Dictionary], viewport: Rect2, selected_id: StringName) -> void:
	var changed := _bounds != content_bounds or _nodes != nodes or _edges != edges or _viewport != viewport or _selected_id != selected_id
	if not changed:
		return
	_bounds = content_bounds
	_nodes = nodes.duplicate(true)
	_edges = edges.duplicate(true)
	_viewport = viewport
	_selected_id = selected_id
	_update_geometry()


func set_viewport(viewport: Rect2) -> void:
	if _viewport == viewport:
		return
	_viewport = viewport
	queue_redraw()


func set_collapsed(value: bool) -> void:
	if _collapsed == value:
		return
	_collapsed = value
	_dragging = false
	size = COLLAPSED_SIZE if value else EXPANDED_SIZE
	if _toggle != null:
		_toggle.text = "+ CARTE" if value else "−  CARTE"
		_toggle.size.x = size.x - 8
	_update_geometry()
	collapsed_changed.emit(value)


func world_to_map(point: Vector2) -> Vector2:
	return _map_offset + (point - _bounds.position) * _map_scale


func map_to_world(point: Vector2) -> Vector2:
	return _bounds.position + (point - _map_offset) / maxf(_map_scale, 0.0001)


func get_map_snapshot() -> Dictionary:
	var viewport_on_map := Rect2(world_to_map(_viewport.position), _viewport.size * _map_scale).intersection(_map_rect)
	return {
		"content_bounds": _bounds, "viewport": _viewport,
		"map_rect": _map_rect, "viewport_on_map": viewport_on_map,
		"nodes": _nodes.duplicate(true), "dragging": _dragging,
		"collapsed": _collapsed, "selected_node_id": _selected_id,
	}


func _update_geometry() -> void:
	_map_rect = Rect2(10, 30, maxf(1, size.x - 20), maxf(1, size.y - 40))
	_map_scale = minf(_map_rect.size.x / maxf(1, _bounds.size.x), _map_rect.size.y / maxf(1, _bounds.size.y))
	_map_offset = _map_rect.position + (_map_rect.size - _bounds.size * _map_scale) * 0.5
	queue_redraw()


func _request_recenter(local_point: Vector2) -> void:
	var bounded := local_point.clamp(_map_rect.position, _map_rect.end)
	var point := map_to_world(bounded).clamp(_bounds.position, _bounds.end)
	recenter_requested.emit(point)


func _gui_input(event: InputEvent) -> void:
	if _collapsed:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _map_rect.has_point(event.position):
				_dragging = true
				grab_focus()
				_request_recenter(event.position)
			elif not event.pressed:
				_dragging = false
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_MIDDLE]:
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_request_recenter(event.position)
		accept_event()
	elif event is InputEventKey and event.pressed:
		var step := _viewport.size * 0.2
		var direction := Vector2.ZERO
		match event.keycode:
			KEY_LEFT: direction = Vector2(-step.x, 0)
			KEY_RIGHT: direction = Vector2(step.x, 0)
			KEY_UP: direction = Vector2(0, -step.y)
			KEY_DOWN: direction = Vector2(0, step.y)
			KEY_HOME:
				recenter_requested.emit(_bounds.get_center())
				accept_event()
				return
			_: return
		recenter_requested.emit((_viewport.get_center() + direction).clamp(_bounds.position, _bounds.end))
		accept_event()


func _input(event: InputEvent) -> void:
	if _dragging and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = false


func _draw() -> void:
	var background := STYLE.box(Color("171410"), Color("766047"), 5)
	background.shadow_color = Color(0, 0, 0, 0.6)
	background.shadow_size = 5
	draw_style_box(background, Rect2(Vector2.ZERO, size))
	if _collapsed:
		return
	draw_line(Vector2(8, 25), Vector2(size.x - 8, 25), Color("554432"), 1, true)
	var rectangles: Dictionary = {}
	for node in _nodes:
		var world_rect: Rect2 = node.rect
		rectangles[node.id] = Rect2(world_to_map(world_rect.position), world_rect.size * _map_scale)
	for edge in _edges:
		if not rectangles.has(edge.from) or not rectangles.has(edge.to):
			continue
		var from: Rect2 = rectangles[edge.from]
		var to: Rect2 = rectangles[edge.to]
		draw_line(from.get_center(), to.get_center(), Color("69533b"), 1, true)
	for node in _nodes:
		var rect: Rect2 = rectangles[node.id]
		var color := Color("81705c")
		match str(node.state):
			"acquired": color = Color("8cbaa2")
			"available": color = Color("c7a36d")
			"excluded": color = Color("975e55")
		if not bool(node.matched):
			color.a = 0.25
		draw_rect(rect, Color(color, color.a * 0.28), true)
		draw_rect(rect, color, false, 1)
		if str(node.prestige) in ["capstone", "summit", "apotheosis"]:
			var center := rect.get_center()
			draw_circle(center, 2 if str(node.prestige) == "apotheosis" else 1.2, color)
		if node.id == _selected_id:
			draw_rect(rect.grow(2), Color("f1dfbd"), false, 1)
	var view_rect := Rect2(world_to_map(_viewport.position), _viewport.size * _map_scale).intersection(_map_rect)
	if view_rect.has_area():
		draw_rect(view_rect, Color(0.91, 0.79, 0.57, 0.08))
		draw_rect(view_rect, Color("e3c28d"), false, 1.2)
	if has_focus():
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("ecdbb8"), false, 1)
