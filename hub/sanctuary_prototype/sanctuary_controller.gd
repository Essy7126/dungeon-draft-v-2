class_name SanctuaryController
extends Node2D

## Interactive visit to the approved Refuge des Braises. All movement/navigation
## coordinates are native image pixels; World alone handles viewport fitting.
const Player := preload("res://hub/sanctuary_prototype/sanctuary_player.gd")
const Navigation := preload("res://hub/sanctuary_prototype/sanctuary_navigation.gd")
const Session := preload("res://hub/sanctuary_prototype/sanctuary_session.gd")
const Panels := preload("res://hub/sanctuary_prototype/sanctuary_panels.gd")
const Resident := preload("res://hub/sanctuary_prototype/sanctuary_resident.gd")
const BACKGROUND := preload("res://asset/hub/sanctuary_prototype/refuge_des_braises_v4.png")
const WATER_SHADER := preload("res://hub/sanctuary_prototype/painted_water.gdshader")
const SMOKE_SHADER := preload("res://hub/sanctuary_prototype/brazier_smoke.gdshader")
const BODY_FONT := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf")
const TITLE_FONT := preload("res://asset/ui/recraft_hud_v1/fonts/cinzel/Cinzel-Variable.ttf")
const LAYOUT_PATH := "res://hub/sanctuary_prototype/refuge_layout.json"
const GOLD := Color("d5b178")
const INK := Color("eee5d2")

@export_range(60.0, 500.0, 5.0) var movement_speed := 210.0
@export_range(0.15, 0.9, 0.01) var player_display_scale := 0.43
@export_range(0.5, 8.0, 0.5) var arrival_tolerance := 1.5
@export_range(80.0, 180.0, 1.0) var interaction_distance := 128.0

var layout: Dictionary = {}
var world: Node2D
var player: Player
var nav: Navigation
var entities: Dictionary = {}

var _session := Session.new()
var _panels: Panels
var _actors: Node2D
var _balance_label: Label
var _status_label: Label
var _debug_label: Label
var _hint_label: Label
var _menu_button: Button
var _world_actions: Array[Button] = []
var _entity_data: Dictionary = {}
var _native_size := Vector2(1536, 1024)
var _ready_for_play := false
var _path := PackedVector2Array()
var _path_index := 0
var _pending_entity: StringName = &""
var _hovered_entity: StringName = &""
var _destination_marker: EntityMarker


class EntityMarker extends Node2D:
	var highlighted := false:
		set(value):
			highlighted = value
			queue_redraw()

	func _draw() -> void:
		var ring := PackedVector2Array()
		for index in range(33):
			var angle := TAU * float(index) / 32.0
			ring.append(Vector2(cos(angle) * 16.0, sin(angle) * 6.0))
		draw_polyline(ring, Color(0.92, 0.77, 0.5, 0.9 if highlighted else 0.45), 1.5, true)


func _ready() -> void:
	_session.bind_runtime(GameManager)
	_build_interface()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	if not parsed is Dictionary:
		_status("Le plan du sanctuaire n'a pas pu être chargé.")
		push_error("SanctuaryPrototype: invalid layout JSON.")
		return
	layout = parsed
	_native_size = _point(layout.get("native_size", [1536, 1024]))
	_build_world()
	nav = Navigation.new()
	nav.foot_radius = 8.0
	nav.create_debug_overlay(world)
	_fit_world()
	get_viewport().size_changed.connect(_fit_world)
	var obstacles: Array[PackedVector2Array] = []
	for obstacle: Array in layout.get("obstacles", []):
		obstacles.append(_polygon(obstacle))
	var configured := await nav.configure(_polygon(layout.get("walkable_outline", [])), obstacles)
	if not is_inside_tree():
		return
	_ready_for_play = configured and player.is_visual_ready() and nav.is_walkable(player.position)
	if not _ready_for_play:
		_status("Le sanctuaire n'est pas encore accessible.")
		push_error("SanctuaryPrototype: navigation, spawn or sprite initialization failed.")
		return
	_status("Achille retrouve le refuge. Approchez-vous d'un habitant.")
	_update_hud()
	_menu_button.grab_focus.call_deferred()


func _exit_tree() -> void:
	_ready_for_play = false
	if nav != null:
		nav.close()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func is_ready_for_play() -> bool:
	return _ready_for_play


func get_player_position() -> Vector2:
	return player.position if is_instance_valid(player) else Vector2.ZERO


func get_session() -> Session:
	return _session


func get_panels() -> Panels:
	return _panels


func request_move(native_point: Vector2) -> bool:
	if not _can_move():
		return false
	_cancel_movement()
	var path := nav.get_path(player.position, native_point)
	if path.is_empty():
		_status("Achille ne peut pas rejoindre cet endroit.")
		return false
	_start_path(path)
	_status("Achille traverse le sanctuaire.")
	return true


func interact_with(id: StringName) -> bool:
	if not _can_move():
		return false
	_cancel_movement()
	if not _entity_data.has(id):
		return false
	var data: Dictionary = _entity_data[id]
	var approach := _point(data.approach)
	var path := nav.get_path(player.position, approach)
	if path.is_empty():
		_status("Impossible de rejoindre %s depuis ici." % String(data.name).to_lower())
		return false
	_pending_entity = id
	_start_path(path)
	if not _panels.is_open():
		_status("En route vers %s…" % String(data.name).to_lower())
	return true


func reset_visit() -> void:
	if not _ready_for_play or _panels.is_open():
		return
	_cancel_movement()
	player.position = _point(layout.spawn)
	player.face_for_direction(Vector2(-2.0, 1.0))
	player.play_idle()
	_update_hud()
	_status("Achille retrouve l'entrée du sanctuaire.")


func _can_move() -> bool:
	return _ready_for_play and not _panels.is_open()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		if nav != null:
			nav.debug_enabled = not nav.debug_enabled
			_debug_label.visible = nav.debug_enabled
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not _panels.is_open():
		return_to_menu()
		get_viewport().set_input_as_handled()
		return
	if not _can_move():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var native_point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
			var id := _entity_at_point(native_point)
			if id != &"":
				interact_with(id)
			else:
				request_move(native_point)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_movement()
			_status("Achille s'arrête.")
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				var nearest := _nearest_entity()
				if nearest != &"":
					interact_with(nearest)
				else:
					_status("Approchez-vous d'un habitant pour lui parler.")
			KEY_I:
				_open_inventory()
			KEY_1:
				interact_with(&"merchant")
			KEY_2:
				interact_with(&"oracle")
			KEY_3:
				interact_with(&"passage")
			_:
				return
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _ready_for_play:
		return
	if _panels.is_open():
		if not _path.is_empty():
			_cancel_movement()
		return
	for action in _world_actions:
		action.disabled = not _ready_for_play
	_update_hover()
	if _debug_label.visible:
		_debug_label.text = "Achille %.0f, %.0f · %d étapes restantes · F1 : masquer" % [player.position.x, player.position.y, maxi(0, _path.size() - _path_index)]
	var distance_left := movement_speed * maxf(delta, 0.0)
	while not _path.is_empty() and distance_left > 0.0:
		if _path_index >= _path.size():
			_complete_path()
			break
		var offset := _path[_path_index] - player.position
		var distance := offset.length()
		if distance <= arrival_tolerance:
			player.position = _path[_path_index]
			_path_index += 1
			continue
		var direction := offset / distance
		player.play_walk(direction)
		var travelled := minf(distance, distance_left)
		player.position += direction * travelled
		distance_left -= travelled
		if travelled >= distance:
			player.position = _path[_path_index]
			_path_index += 1
	if not _path.is_empty() and _path_index >= _path.size():
		_complete_path()


func _start_path(path: PackedVector2Array) -> void:
	_path = path.duplicate()
	_path_index = 0
	_destination_marker.position = _path[-1]
	_destination_marker.show()
	while _path_index < _path.size() and player.position.distance_to(_path[_path_index]) <= arrival_tolerance:
		_path_index += 1
	if _path_index >= _path.size():
		_complete_path()


func _cancel_movement() -> void:
	_path.clear()
	_path_index = 0
	_pending_entity = &""
	if is_instance_valid(_destination_marker):
		_destination_marker.hide()
	if is_instance_valid(player):
		player.cancel_movement_feedback()


func _complete_path() -> void:
	var id := _pending_entity
	_cancel_movement()
	if id == &"" or not _entity_data.has(id):
		_status("Le refuge est à vous. Cliquez pour poursuivre la visite.")
		return
	var data: Dictionary = _entity_data[id]
	if player.position.distance_to(_point(data.approach)) > arrival_tolerance + 0.5 \
			or player.position.distance_to(_point(data.position)) > interaction_distance:
		_status("Approchez-vous encore pour commencer l'échange.")
		return
	player.face_for_direction(_point(data.position) - player.position)
	match id:
		&"merchant":
			_panels.open_shop()
			_status("Achille consulte les offres du marchand.")
		&"oracle":
			_panels.open_oracle()
			_status("Achille écoute l'oracle.")
		&"passage":
			_panels.open_departure()
			_status("Achille se prépare à reprendre le chemin.")


func _open_inventory() -> void:
	if not _can_move():
		return
	_cancel_movement()
	_panels.open_inventory()


func _nearest_entity() -> StringName:
	var best: StringName = &""
	var distance := interaction_distance
	for id: StringName in _entity_data:
		var candidate := player.position.distance_to(_point(_entity_data[id].position))
		if candidate <= distance:
			distance = candidate
			best = id
	return best


func _entity_at_point(point: Vector2) -> StringName:
	for id: StringName in entities:
		var marker: Node2D = entities[id]
		if Rect2(marker.position + Vector2(-46, -105), Vector2(92, 143)).has_point(point):
			return id
	return &""


func _update_hover() -> void:
	var id := _entity_at_point(world.to_local(get_global_mouse_position()))
	if id == _hovered_entity:
		return
	_hovered_entity = id
	for entity_id: StringName in entities:
		var marker: EntityMarker = entities[entity_id]
		marker.highlighted = entity_id == id
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if id != &"" else Input.CURSOR_ARROW)
	if _hint_label != null:
		_hint_label.text = "Cliquer pour rejoindre %s" % String(_entity_data[id].name).to_lower() if id != &"" else "Clic : se déplacer · Clic droit : arrêter · Échap : retour"


func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	var background := Sprite2D.new()
	background.name = "PaintedBackground"
	background.texture = BACKGROUND
	background.centered = false
	world.add_child(background)
	var water_root := Node2D.new()
	water_root.name = "Water"
	world.add_child(water_root)
	for index in layout.get("water_polygons", []).size():
		var water := Polygon2D.new()
		water.name = "Water_%d" % index
		water.polygon = _polygon(layout.water_polygons[index])
		water.uv = water.polygon.duplicate()
		water.texture = BACKGROUND
		var material := ShaderMaterial.new()
		material.shader = WATER_SHADER
		material.set_shader_parameter("image_size", _native_size)
		water.material = material
		water_root.add_child(water)
	_actors = Node2D.new()
	_actors.name = "Actors"
	_actors.y_sort_enabled = true
	world.add_child(_actors)
	for data: Dictionary in layout.get("entities", []):
		var id := StringName(data.id)
		_entity_data[id] = data.duplicate(true)
		var marker := EntityMarker.new()
		marker.name = "Entity_" + String(id)
		marker.position = _point(data.position)
		marker.set_meta(&"entity_id", id)
		_actors.add_child(marker)
		Resident.attach_to(marker, id)
		entities[id] = marker
		var caption := _label(String(data.name), 17, INK)
		caption.name = "NameLabel"
		caption.position = Vector2(-80, 14)
		caption.size = Vector2(160, 24)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_color_override("font_outline_color", Color(0.08, 0.075, 0.06, 0.95))
		caption.add_theme_constant_override("outline_size", 5)
		marker.add_child(caption)
	player = Player.new()
	player.name = "Achilles"
	player.display_scale = player_display_scale
	player.position = _point(layout.spawn)
	_actors.add_child(player)
	for index in layout.get("foreground", []).size():
		var data: Dictionary = layout.foreground[index]
		var anchor := _point(data.anchor)
		var group := Node2D.new()
		group.name = "Foreground_%d" % index
		group.position = anchor
		var cutout := Polygon2D.new()
		var points := _polygon(data.polygon)
		cutout.uv = points.duplicate()
		for vertex in points.size():
			points[vertex] -= anchor
		cutout.polygon = points
		cutout.texture = BACKGROUND
		group.add_child(cutout)
		_actors.add_child(group)
	_destination_marker = EntityMarker.new()
	_destination_marker.name = "Destination"
	_destination_marker.highlighted = true
	_destination_marker.scale = Vector2.ONE * 0.55
	_destination_marker.hide()
	world.add_child(_destination_marker)
	var atmosphere := Node2D.new()
	atmosphere.name = "Atmosphere"
	world.add_child(atmosphere)
	for index in layout.get("smoke_emitters", []).size():
		var data: Dictionary = layout.smoke_emitters[index]
		var smoke := ColorRect.new()
		smoke.name = "Smoke_%d" % index
		smoke.size = _point(data["size"])
		smoke.position = _point(data.position) - Vector2(smoke.size.x * 0.5, smoke.size.y)
		smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = SMOKE_SHADER
		material.set_shader_parameter("phase", float(index) * 1.93)
		smoke.material = material
		atmosphere.add_child(smoke)


func _build_interface() -> void:
	var matte_layer := CanvasLayer.new()
	matte_layer.layer = -10
	add_child(matte_layer)
	var matte := ColorRect.new()
	matte.color = Color("151b19")
	matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	matte_layer.add_child(matte)
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "SanctuaryUI"
	ui_layer.layer = 20
	add_child(ui_layer)
	var hud := Control.new()
	hud.name = "HUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hud)
	var top := PanelContainer.new()
	top.name = "TopBar"
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 16
	top.add_theme_stylebox_override("panel", _panel_style())
	hud.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	top.add_child(row)
	_menu_button = _button("Menu · Échap")
	_menu_button.name = "SanctuaryMenuButton"
	_menu_button.tooltip_text = "Revenir au menu principal"
	_menu_button.pressed.connect(return_to_menu)
	row.add_child(_menu_button)
	var title := _label("Refuge des Braises", 24, INK)
	title.add_theme_font_override("font", TITLE_FONT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	_balance_label = _label("", 18, GOLD)
	_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_balance_label)
	var inventory := _button("Inventaire · I")
	inventory.name = "InventoryButton"
	inventory.pressed.connect(_open_inventory)
	row.add_child(inventory)
	var bottom := PanelContainer.new()
	bottom.name = "VisitHint"
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 20
	bottom.offset_right = -20
	bottom.offset_top = -128
	bottom.offset_bottom = -16
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_stylebox_override("panel", _panel_style())
	hud.add_child(bottom)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 4)
	bottom.add_child(content)
	_status_label = _label("Le sanctuaire se prépare…", 16, INK)
	_status_label.name = "VisitStatus"
	content.add_child(_status_label)
	var shortcuts := HBoxContainer.new()
	shortcuts.name = "SanctuaryDestinations"
	shortcuts.add_theme_constant_override("separation", 10)
	content.add_child(shortcuts)
	for target in [[&"merchant", "Marchand · 1"], [&"oracle", "Oracle · 2"], [&"passage", "Passage · 3"]]:
		var action := _button(target[1])
		action.name = "Visit_" + String(target[0])
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.pressed.connect(interact_with.bind(target[0]))
		shortcuts.add_child(action)
		_world_actions.append(action)
	_hint_label = _label("Clic : se déplacer · Clic droit : arrêter · Échap : retour", 13, Color("b8b7a5"))
	content.add_child(_hint_label)
	_debug_label = _label("", 12, GOLD)
	_debug_label.hide()
	content.add_child(_debug_label)
	_panels = Panels.new()
	_panels.name = "SanctuaryPanels"
	_panels.setup(_session)
	ui_layer.add_child(_panels)
	_panels.session_changed.connect(_update_hud)
	_panels.closed.connect(func() -> void:
		_status("Achille reprend sa visite du sanctuaire.")
		_update_hud()
	)
	_wire_world_focus(inventory)


func _wire_world_focus(inventory: Button) -> void:
	var controls: Array[Button] = [_menu_button, inventory]
	controls.append_array(_world_actions)
	for index in controls.size():
		var current := controls[index]
		current.focus_next = current.get_path_to(controls[(index + 1) % controls.size()])
		current.focus_previous = current.get_path_to(controls[posmod(index - 1, controls.size())])


func return_to_menu() -> void:
	_cancel_movement()
	_return_from_visit.call_deferred()


func _return_from_visit() -> void:
	var result := _session.return_from_visit()
	if not bool(result.get("success", false)):
		_status(str(result.get("message", "Le retour n'a pas pu être confirmé.")))


func _fit_world() -> void:
	if not is_instance_valid(world):
		return
	var viewport_size := get_viewport_rect().size
	var usable := Rect2(Vector2(20, 88), Vector2(maxf(1, viewport_size.x - 40), maxf(1, viewport_size.y - 228)))
	var fit := minf(usable.size.x / _native_size.x, usable.size.y / _native_size.y)
	world.scale = Vector2.ONE * fit
	world.position = usable.position + (usable.size - _native_size * fit) * 0.5
	for caption: Label in world.find_children("NameLabel", "Label", true, false):
		caption.scale = Vector2.ONE / fit
		caption.position = Vector2(-80.0 / fit, 14.0 / fit)
		caption.add_theme_font_size_override("font_size", 13)
		caption.add_theme_constant_override("outline_size", 2)


func _update_hud() -> void:
	var context := _session.get_context()
	_balance_label.text = "%d %s" % [int(context.get("balance", 0)), str(context.get("currency_label", "oboles"))] if str(context.get("mode", "")) == "halt" else "Avant le départ"
	_menu_button.text = str(context.get("return_label", "Menu principal"))
	_menu_button.tooltip_text = _menu_button.text + " · Échap"


func _status(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(128, 38)
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_stylebox_override("normal", _panel_style())
	var hover := _panel_style()
	hover.bg_color = Color("3b3b2ef2")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var focus := _panel_style()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("eed1a1")
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b241ee8")
	style.border_color = Color(0.65, 0.55, 0.35, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value.size() >= 2 else Vector2.ZERO


func _polygon(value: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Array in value:
		result.append(_point(point))
	return result
