@tool
class_name PaintedHaltCanvas
extends Control

## Free-floor authoring shares the Studio's fit/zoom/gesture conventions.
## Geometry always remains normalized to the original painting.
signal selection_changed
signal help_changed(text: String)

const ScaleReference := preload("res://hub/painted_halt/halt_scale_reference.gd")
const COLORS := [
	Color("70dbc4"),
	Color("ef816f"),
	Color("66bfe5"),
	Color("ecc388"),
	Color("8ecff5"),
	Color("91ba6d"),
	Color("e2be8a"),
	Color("cba1e8"),
	Color("ffa963"),
	Color("ffffff"),
	Color("efd572"),
]

var document: PaintedHaltDocument
var texture: Texture2D
var layer := "outline"
var selected_shape := 0
var selected_vertex := -1
var visible_layers: Dictionary = { }
var zoom := 1.0
var pan := Vector2.ZERO
var drawing := false
var draft: Array = []
var show_art := true
var show_scale_reference := true
var scale_reference_position := Vector2(-1, -1)
var _dragging := false
var _panning := false
var _before: Dictionary = { }
var _painting: TextureRect
var _preview_shader: ShaderMaterial
var _effect_clock := 0.0
var effects_enabled := true


func _ready() -> void:
	clip_contents = true
	var background := ColorRect.new()
	background.color = Color("111e24")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_painting = TextureRect.new()
	_painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_painting.show_behind_parent = true
	add_child(_painting)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	custom_minimum_size = Vector2(420, 320)
	resized.connect(queue_redraw)
	for key in PaintedHaltDocument.LAYERS:
		visible_layers[key] = true


func set_document(value: PaintedHaltDocument, image: Image = null) -> void:
	if document != null and document.changed.is_connected(_on_document_changed):
		document.changed.disconnect(_on_document_changed)
	document = value
	document.changed.connect(_on_document_changed)
	_preview_shader = null
	_painting.material = null
	texture = ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null
	selected_shape = 0
	selected_vertex = -1
	scale_reference_position = Vector2(-1, -1)
	fit()


func fit() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()


func image_rect() -> Rect2:
	var source := Vector2(1600, 900)
	if texture != null:
		source = texture.get_size()
	var scale_factor := minf(maxf(1, size.x - 48) / source.x, maxf(1, size.y - 48) / source.y) * zoom
	var extent := source * scale_factor
	return Rect2((size - extent) * 0.5 + pan, extent)


func to_canvas(point: Array) -> Vector2:
	var rect := image_rect()
	return rect.position + Vector2(float(point[0]), float(point[1])) * rect.size


func to_normalized(point: Vector2) -> Vector2:
	var rect := image_rect()
	return (point - rect.position) / rect.size


func set_layer(value: String) -> void:
	cancel_gesture()
	layer = value
	selected_shape = (
		0
		if document != null and not document.manifest.is_empty()
		and not document.shapes(layer).is_empty()
		else -1
	)
	selected_vertex = -1
	selection_changed.emit()
	queue_redraw()


func begin_shape() -> void:
	cancel_gesture()
	drawing = true
	draft.clear()
	grab_focus()
	help_changed.emit(
		(
			"Cliquer les sommets · Entrée ou double clic : terminer · Échap : annuler"
			if not document.is_anchor(layer)
			else "Cliquer pour placer le point"
		)
	)
	queue_redraw()


func finish_shape() -> void:
	if not drawing or draft.size() < (1 if document.is_anchor(layer) else 3):
		return
	selected_shape = document.add_shape(layer, draft)
	drawing = false
	draft.clear()
	selected_vertex = -1
	selection_changed.emit()
	queue_redraw()


func cancel_gesture() -> bool:
	var active := _dragging or drawing or _panning
	if _dragging:
		document.manifest = _before.duplicate(true)
		document.changed.emit()
	_dragging = false
	_panning = false
	drawing = false
	draft.clear()
	queue_redraw()
	return active


func delete_selection() -> void:
	if selected_vertex >= 0:
		document.remove_point(layer, selected_shape, selected_vertex)
		selected_vertex = -1
	elif document.remove_shape(layer, selected_shape):
		selected_shape = mini(selected_shape, document.shapes(layer).size() - 1)
	selection_changed.emit()
	queue_redraw()


func _on_document_changed() -> void:
	selected_shape = mini(selected_shape, document.shapes(layer).size() - 1)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if document == null or document.manifest.is_empty():
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var before := to_normalized(event.position)
			zoom = clampf(
				zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15),
				0.35,
				8.0,
			)
			pan += event.position - to_canvas([before.x, before.y])
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.alt_pressed and event.pressed:
				scale_reference_position = to_normalized(event.position).clamp(
					Vector2.ZERO,
					Vector2.ONE,
				)
				show_scale_reference = true
				queue_redraw()
				accept_event()
				return
			grab_focus()
			if event.pressed:
				_press(event.position, event.double_click)
			elif _dragging:
				_dragging = false
				document.commit(_before, "Déplacer le point")
				selection_changed.emit()
			accept_event()
	elif event is InputEventMouseMotion:
		if _panning:
			pan += event.relative
			queue_redraw()
		elif _dragging:
			var point := to_normalized(event.position).clamp(Vector2.ZERO, Vector2.ONE)
			if selected_vertex == -2:
				var field: String = {
					"foreground": "anchor",
					"cascades": "splash",
					"landmarks": "focus",
				}[layer]
				document.shapes(layer)[selected_shape][field] = [point.x, point.y]
			else:
				document.set_point(layer, selected_shape, selected_vertex, point)
			queue_redraw()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			cancel_gesture()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			finish_shape()
		elif event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
			delete_selection()
		else:
			return
		accept_event()


func _press(position_value: Vector2, double_click: bool) -> void:
	var normalized := to_normalized(position_value)
	if not Rect2(Vector2.ZERO, Vector2.ONE).has_point(normalized):
		return
	if drawing:
		if double_click:
			finish_shape()
		else:
			draft.append([normalized.x, normalized.y])
			if document.is_anchor(layer):
				finish_shape()
		queue_redraw()
		return
	if double_click and not document.is_anchor(layer) and selected_shape >= 0:
		var polygon := document.points(layer, selected_shape)
		var nearest := -1
		var distance := 15.0
		for i in polygon.size():
			var projected := Geometry2D.get_closest_point_to_segment(
				position_value,
				to_canvas(polygon[i]),
				to_canvas(polygon[(i + 1) % polygon.size()]),
			)
			if projected.distance_to(position_value) < distance:
				distance = projected.distance_to(position_value)
				nearest = i
		if nearest >= 0:
			document.insert_point(layer, selected_shape, nearest, normalized)
			selected_vertex = nearest + 1
			selection_changed.emit()
		return
	selected_vertex = -1
	var distance := 12.0
	for shape_index in document.shapes(layer).size():
		var polygon := document.points(layer, shape_index)
		for i in polygon.size():
			var candidate := to_canvas(polygon[i]).distance_to(position_value)
			if candidate < distance:
				distance = candidate
				selected_shape = shape_index
				selected_vertex = i
		if layer in ["foreground", "cascades", "landmarks"]:
			var field: String = {
				"foreground": "anchor",
				"cascades": "splash",
				"landmarks": "focus",
			}[layer]
			var anchor: Array = document.shapes(layer)[shape_index].get(
				field,
				document.shapes(layer)[shape_index].get("point", [0.5, 0.5]),
			)
			var candidate := to_canvas(anchor).distance_to(position_value)
			# The visible cross wins when its initial anchor coincides with a vertex.
			if candidate <= distance:
				distance = candidate
				selected_shape = shape_index
				selected_vertex = -2
	if selected_vertex != -1:
		_before = document.manifest.duplicate(true)
		_dragging = true
	else:
		for shape_index in document.shapes(layer).size():
			var polygon := _canvas_polygon(document.points(layer, shape_index))
			if polygon.size() >= 3 and Geometry2D.is_point_in_polygon(position_value, polygon):
				selected_shape = shape_index
	selection_changed.emit()
	queue_redraw()


func _canvas_polygon(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Array in points:
		result.append(to_canvas(point))
	return result


func _draw() -> void:
	var rect := image_rect()
	if _painting != null:
		_painting.visible = texture != null and show_art
		_painting.texture = texture
		_painting.position = rect.position
		_painting.size = rect.size
	if texture == null or not show_art:
		draw_rect(Rect2(Vector2.ZERO, size), Color("111e24"))
		draw_rect(rect, Color("1c3038"))
		for i in 17:
			var x := rect.position.x + rect.size.x * i / 16.0
			draw_line(
				Vector2(x, rect.position.y),
				Vector2(x, rect.end.y),
				Color(0.38, 0.55, 0.58, 0.18),
			)
		for i in 10:
			var y := rect.position.y + rect.size.y * i / 9.0
			draw_line(
				Vector2(rect.position.x, y),
				Vector2(rect.end.x, y),
				Color(0.38, 0.55, 0.58, 0.18),
			)
	if document == null or document.manifest.is_empty():
		return
	for layer_index in PaintedHaltDocument.LAYERS.size():
		var key: String = PaintedHaltDocument.LAYERS[layer_index]
		if not visible_layers.get(key, true):
			continue
		var color: Color = COLORS[layer_index]
		for index in document.shapes(key).size():
			var points := _canvas_polygon(document.points(key, index))
			var selected := layer == key and selected_shape == index
			if document.is_anchor(key):
				if points.is_empty():
					continue
				draw_circle(points[0], 7.0 if selected else 5.0, color)
				draw_arc(points[0], 11, 0, TAU, 24, color, 1.5, true)
				var label: String = document.shapes(key)[index].get("title", key) if key != "spawn" else "Arrivée"
				draw_string(
					ThemeDB.fallback_font,
					points[0] + Vector2(14, 5),
					label,
					HORIZONTAL_ALIGNMENT_LEFT,
					190,
					13,
					color,
				)
			elif points.size() >= 3:
				if not Geometry2D.triangulate_polygon(points).is_empty():
					draw_colored_polygon(points, Color(color, 0.15 if selected else 0.045))
				points.append(points[0])
				draw_polyline(
					points,
					Color(color, 1.0 if layer == key else 0.35),
					2.0 if selected else 1.0,
					true,
				)
				if selected:
					for vertex in points.size() - 1:
						draw_circle(
							points[vertex],
							6 if selected_vertex == vertex else 4,
							Color.WHITE if selected_vertex == vertex else color,
						)
			if selected and key in ["foreground", "cascades", "landmarks"]:
				var field: String = {
					"foreground": "anchor",
					"cascades": "splash",
					"landmarks": "focus",
				}[key]
				var anchor := to_canvas(
					document.shapes(key)[index].get(
						field,
						document.shapes(key)[index].get("point", [0.5, 0.5]),
					)
				)
				draw_line(anchor - Vector2(9, 0), anchor + Vector2(9, 0), Color.WHITE, 2)
				draw_line(anchor - Vector2(0, 9), anchor + Vector2(0, 9), Color.WHITE, 2)
	_draw_scale_reference()
	var draft_points := _canvas_polygon(draft)
	if draft_points.size() >= 2:
		draw_polyline(draft_points, Color("f6dc8f"), 2, true)
	for point in draft_points:
		draw_circle(point, 4, Color("f6dc8f"))
	draw_rect(rect, Color("4e6971"), false, 1)


func update_material_preview(definition: Dictionary, prepared: Dictionary) -> void:
	_preview_shader = ShaderMaterial.new()
	_preview_shader.shader = preload("res://hub/painted_halt/living_materials.gdshader")
	_preview_shader.set_shader_parameter(
		"materials",
		ImageTexture.create_from_image(prepared.materials),
	)
	_preview_shader.set_shader_parameter("flow_map", ImageTexture.create_from_image(prepared.flow))
	_preview_shader.set_shader_parameter("has_flow_map", true)
	_preview_shader.set_shader_parameter("source_size", texture.get_size())
	_preview_shader.set_shader_parameter("water_color", Color(str(definition.water.get(
					"tint",
					"#48d896",
				))))
	var torches := PackedVector4Array()
	var strengths := PackedVector4Array()
	for torch: Dictionary in definition.get("torches", []):
		torches.append(Vector4(torch.point[0], torch.point[1], torch.radius[0], torch.radius[1]))
		strengths.append(
			Vector4(
				float(torch.get("flame_strength", 1.0)),
				float(torch.get("light_strength", 1.0)),
				0,
				0,
			)
		)
	_preview_shader.set_shader_parameter("torch_count", torches.size())
	while torches.size() < 12:
		torches.append(Vector4.ZERO)
		strengths.append(Vector4.ZERO)
	_preview_shader.set_shader_parameter("torches", torches)
	_preview_shader.set_shader_parameter("torch_strength", strengths)
	_painting.material = _preview_shader if effects_enabled else null


func _process(delta: float) -> void:
	if _preview_shader != null and is_visible_in_tree() and effects_enabled:
		_effect_clock += delta
		_preview_shader.set_shader_parameter("effect_time", _effect_clock)


func set_effects_enabled(enabled: bool) -> void:
	effects_enabled = enabled
	_painting.material = _preview_shader if enabled else null


func _draw_scale_reference() -> void:
	if not show_scale_reference:
		return
	var at := scale_reference_position
	if at.x < 0:
		var spawn: Array = document.manifest.world.get("spawn", [])
		if spawn.size() != 2:
			return
		at = Vector2(spawn[0], spawn[1])
	var ground := to_canvas([at.x, at.y])
	var height := ScaleReference.height_ratio(document.manifest) * image_rect().size.y
	var sprite_rect := ScaleReference.texture_rect(document.manifest, ground, image_rect().size.y)
	draw_texture_rect(ScaleReference.texture(), sprite_rect, false, Color(1, 1, 1, 0.85))
	var ruler := ground + Vector2(-height * 0.27, 0)
	draw_line(ruler, ruler - Vector2(0, height), Color("efd572"), 2)
	for fraction in [0.0, 0.5, 1.0]:
		var tick := ruler - Vector2(0, height * fraction)
		draw_line(tick - Vector2(5, 0), tick + Vector2(5, 0), Color("efd572"), 2)
	draw_string(
		ThemeDB.fallback_font,
		ruler + Vector2(-10, 18),
		"Achille · Alt+clic",
		HORIZONTAL_ALIGNMENT_LEFT,
		160,
		13,
		Color("efd572"),
	)
