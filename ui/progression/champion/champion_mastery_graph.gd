class_name ChampionMasteryGraph
extends Control
## Read-only map of the runtime mastery prerequisites. Purchases belong to the host.

signal node_inspected(node_id: StringName)
signal navigation_changed(snapshot: Dictionary)

const STYLE := preload("res://ui/progression/theme/spell_codex_style.gd")
const ASHEN := preload("res://ui/selection/selection_ashen_surface.gd")
const ICONS: SkillTreeIconCatalog = preload("res://data/ui/skill_tree_icon_catalog_refined.tres")
const GRAIN := preload("res://asset/ui/character_selection/materials/ash_leather_v1.png")
const BACKDROP := preload("res://asset/ui/progression/mastery_atlas/canvas_v1.png")
const DOCTRINE_ICONS := {
	&"achilles_wrath_of_peleus": preload("res://asset/ui/progression/mastery_atlas/wrath_v1.tres"),
	&"achilles_lesson_of_chiron": preload("res://asset/ui/progression/mastery_atlas/chiron_v1.tres"),
	&"achilles_aegis_of_aeacus": preload("res://asset/ui/progression/mastery_atlas/aeacus_v1.tres"),
}
const CARD := Vector2(226, 80)
const MIN_ZOOM := 0.5
const READABLE_ZOOM := 0.78
const MAX_ZOOM := 1.75
const GOLD := Color("c4a171")
const TEXT := Color("f0e6d5")
const MUTED := Color("b5a99b")
const ACQUIRED := Color("8cbaa2")

var _state: CharacterRunState
var _section_id: StringName = &""
var _selected_id: StringName = &""
var _query := ""
var _canvas: Control
var _buttons: Dictionary = {}
var _nodes: Dictionary = {}
var _matches: Dictionary = {}
var _edges: Array[Dictionary] = []
var _labels: Array[Dictionary] = []
var _bounds := Rect2(0, 0, 542, 610)
var _zoom := 1.0
var _target_zoom := 1.0
var _pan := Vector2.ZERO
var _target_pan := Vector2.ZERO
var _panning := false
var _reduced_motion := false
var _clock := 0.0
var _pulse_ids: Dictionary = {}
var _previous_acquired: Dictionary = {}
var _fit_pending := true
var _built := false
var _has_synced_state := false


func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	_canvas = Control.new()
	_canvas.name = "MasteryWorld"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_built = true
	resized.connect(_on_resized)
	_rebuild()


func configure(state: CharacterRunState, section_id: StringName) -> void:
	var changed := state != _state or section_id != _section_id
	_state = state
	_section_id = section_id
	if changed:
		_selected_id = &""
		_query = ""
		_previous_acquired.clear()
		_pulse_ids.clear()
		_has_synced_state = false
		_fit_pending = true
	_rebuild()


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	if value:
		_pulse_ids.clear()
		_zoom = _target_zoom
		_pan = _target_pan
		_apply_transform()


func set_search_query(query: String) -> void:
	_query = query.strip_edges().to_lower()
	_filter_nodes()
	if _matches.size() == 1:
		center_on_node(StringName(_matches.keys()[0]))
	_emit_navigation()


func inspect_node(node_id: StringName) -> void:
	_selected_id = node_id
	_refresh_styles()
	queue_redraw()
	_emit_navigation()


func get_node_buttons() -> Dictionary:
	return _matches.duplicate()


func get_all_node_buttons() -> Dictionary:
	return _buttons.duplicate()


func get_zoom() -> float:
	return _target_zoom


func get_pan_offset() -> Vector2:
	return _target_pan


func get_navigation_snapshot() -> Dictionary:
	return {
		"zoom": _target_zoom, "displayed_zoom": _zoom,
		"pan_offset": _target_pan, "viewport_size": size,
		"graph_bounds": _bounds, "node_count": _buttons.size(),
		"visible_count": _matches.size(), "selected_node_id": _selected_id,
		"section_id": _section_id, "query": _query,
		"min_zoom": MIN_ZOOM, "max_zoom": MAX_ZOOM, "readable_zoom": READABLE_ZOOM,
		"edges": _edges.duplicate(true), "reduced_motion": _reduced_motion,
	}


func zoom_by(factor: float, anchor: Vector2 = Vector2(-1, -1)) -> void:
	if not is_finite(factor) or factor <= 0.0:
		return
	if anchor.x < 0 or anchor.y < 0:
		anchor = size * 0.5
	var graph_point := (anchor - _target_pan) / _target_zoom
	_target_zoom = clampf(_target_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	_target_pan = anchor - graph_point * _target_zoom
	_clamp_pan()
	_snap_if_reduced()
	_emit_navigation()


func fit_graph() -> void:
	if size.x < 1 or size.y < 1:
		_fit_pending = true
		return
	_fit_pending = false
	_target_zoom = clampf(minf((size.x - 30) / _bounds.size.x, (size.y - 22) / _bounds.size.y), READABLE_ZOOM, 1.15)
	var scaled := _bounds.size * _target_zoom
	_target_pan = (size - scaled) * 0.5 - _bounds.position * _target_zoom
	var selected := _buttons.get(_selected_id) as Button
	# Default framing preserves legible names; the wheel still offers a 50% overview.
	if scaled.y > size.y - 22:
		_target_pan.y = size.y * 0.5 - (selected.position.y + CARD.y * 0.5) * _target_zoom if selected != null else 12.0
	if scaled.x > size.x - 30 and selected != null:
		_target_pan.x = size.x * 0.5 - (selected.position.x + CARD.x * 0.5) * _target_zoom
	_zoom = _target_zoom
	_pan = _target_pan
	_apply_transform()
	_emit_navigation()


func fit_to_view() -> void:
	fit_graph()


func center_on_node(node_id: StringName) -> void:
	var button := _buttons.get(node_id) as Button
	if button == null:
		return
	_target_pan = size * 0.5 - (button.position + CARD * 0.5) * _target_zoom
	_clamp_pan()
	_snap_if_reduced()
	_emit_navigation()


func _rebuild() -> void:
	if not _built:
		return
	var restore_focus := false
	for button: Button in _buttons.values():
		restore_focus = restore_focus or button.has_focus()
	for child in _canvas.get_children():
		_canvas.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_nodes.clear()
	_edges.clear()
	_labels.clear()
	if _state == null or _state.champion_progression == null:
		return
	var catalog := _state.progression_profile.mastery_catalog
	var doctrine := SkillTreeResolver.champion_doctrine_by_id(catalog.doctrines, _section_id)
	var nodes: Array[SkillTreeNodeData] = SkillTreeResolver.champion_doctrine_nodes(doctrine) if doctrine != null else catalog.get_advanced_nodes()
	var tiers: Dictionary = {}
	for node in nodes:
		if not tiers.has(node.tier):
			tiers[node.tier] = []
		tiers[node.tier].append(node)
		_nodes[node.upgrade_id] = node
	var ordered: Array = tiers.keys()
	ordered.sort()
	# Apotheoses depend on summits; junctions are a separate route, not an intermediate rung.
	if doctrine == null and ordered == [6, 7, 8]:
		ordered = [6, 8, 7]
	var max_columns := 2 if doctrine != null else 3
	_bounds = Rect2(0, 0, 22 + max_columns * (CARD.x + 30), 30 + ordered.size() * 116)
	if doctrine == null:
		_bounds.size.y += 72
	var row := 0
	for tier in ordered:
		var group: Array = tiers[tier]
		var row_width: float = group.size() * CARD.x + (group.size() - 1) * 30
		var start_x := (_bounds.size.x - row_width) * 0.5
		var row_y := 26.0 + row * (140.0 if doctrine == null else 116.0)
		for index in group.size():
			var node := group[index] as SkillTreeNodeData
			var button := _make_node(node)
			button.position = Vector2(start_x + index * (CARD.x + 30), row_y + 14)
			_canvas.add_child(button)
			_buttons[node.upgrade_id] = button
			if doctrine == null:
				_labels.append({"position": button.position + Vector2(3, CARD.y + 15), "text": _advanced_requirement(node), "color": MUTED, "font_size": 11})
		var heading := "PALIER %d" % int(tier)
		if int(tier) == 5:
			heading = "CAPSTONES · CHOIX EXCLUSIF"
		elif int(tier) == 6:
			heading = "SOMMETS · NIVEAU 13"
		elif int(tier) == 7:
			heading = "JONCTIONS · NIVEAU 14"
		elif int(tier) == 8:
			heading = "APOTHÉOSES · NIVEAU 14"
		_labels.append({"position": Vector2(23, row_y - 1), "text": heading, "color": GOLD, "font_size": 11})
		row += 1
	_build_edges()
	_refresh_styles()
	_filter_nodes()
	_wire_focus()
	if _fit_pending:
		fit_graph()
	if restore_focus and _buttons.has(_selected_id):
		(_buttons[_selected_id] as Button).grab_focus()
	queue_redraw()
	_emit_navigation()


func _make_node(node: SkillTreeNodeData) -> Button:
	var button := Button.new()
	button.name = str(node.upgrade_id)
	button.size = CARD
	button.custom_minimum_size = CARD
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_contents = true
	button.set_meta("mastery_id", node.upgrade_id)
	button.pressed.connect(_choose_node.bind(node.upgrade_id))
	button.focus_entered.connect(_focus_node.bind(node.upgrade_id))
	button.gui_input.connect(_node_input.bind(node.upgrade_id))
	var surface := ASHEN.new()
	surface.name = "AshenMaterial"
	surface.configure(&"panel", Color("29221e"), Color("655447"))
	button.add_child(surface)
	var icon_frame := Panel.new()
	icon_frame.position = Vector2(9, 11)
	icon_frame.size = Vector2(57, 57)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel", STYLE.box(Color("141211"), Color("796044"), 7))
	button.add_child(icon_frame)
	var icon := TextureRect.new()
	icon.name = "MasteryIcon"
	icon.position = Vector2(16, 18)
	icon.size = Vector2(43, 43)
	icon.texture = _node_icon(node)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var title := Label.new()
	title.name = "MasteryName"
	title.position = Vector2(75, 8)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	title.custom_maximum_size = Vector2(143, 48)
	title.add_theme_font_override("font", STYLE.BOLD)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_constant_override("line_spacing", 0)
	title.add_theme_color_override("font_color", TEXT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A maximum width is required for Label wrapping; assign geometry after fonts and wrapping.
	title.text = node.display_name
	title.size = Vector2(143, 48)
	var title_height := minf(48.0, 2.0 * title.get_line_height())
	title.custom_maximum_size.y = title_height
	title.size.y = title_height
	button.add_child(title)
	var status := Label.new()
	status.name = "MasteryStatus"
	status.position = Vector2(75, 56)
	status.size = Vector2(143, 18)
	status.add_theme_font_override("font", STYLE.BODY)
	status.add_theme_font_size_override("font_size", 11)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(status)
	return button


func _node_icon(node: SkillTreeNodeData) -> Texture2D:
	if node.node_type == SkillTreeNodeData.NodeType.ROOT and DOCTRINE_ICONS.has(node.doctrine_id):
		return DOCTRINE_ICONS[node.doctrine_id] as Texture2D
	if node.node_type == SkillTreeNodeData.NodeType.SPECIALIST_SUMMIT and node.requires_completed_tree_ids.size() == 1:
		var emblem := DOCTRINE_ICONS.get(node.requires_completed_tree_ids[0]) as Texture2D
		if emblem != null:
			return emblem
	return ICONS.get_node_icon(node.upgrade_id, _semantic(node))


func _semantic(node: SkillTreeNodeData) -> StringName:
	var axis := str(node.effect_axis)
	if "guard" in axis or "shield" in axis or "absorp" in axis or "defense" in axis:
		return &"defense"
	if "move" in axis or "step" in axis or "mobility" in axis:
		return &"movement"
	if "range" in axis:
		return &"range"
	if "heal" in axis or "sustain" in axis:
		return &"heal"
	if "push" in axis or "collision" in axis:
		return &"push"
	return &"damage"


func _refresh_styles() -> void:
	if _state == null:
		return
	var acquired := _state.champion_progression.selected_node_ids
	var catalog := _state.progression_profile.mastery_catalog.node_catalog()
	for id: StringName in _buttons:
		var button := _buttons[id] as Button
		var node := _nodes[id] as SkillTreeNodeData
		var chosen := acquired.has(id)
		var decision := _state.evaluate_mastery_node(id)
		var available := bool(decision.get("allowed", false))
		var excluded := false
		for selected_node_id: StringName in acquired:
			var other := catalog.get(selected_node_id) as SkillTreeNodeData
			if not chosen and (node.excluded_node_ids.has(selected_node_id) or (other != null and node.exclusive_group != &"" and other.exclusive_group == node.exclusive_group)):
				excluded = true
		var state_id := "acquired" if chosen else ("excluded" if excluded else ("available" if available else "locked"))
		var color := ACQUIRED if chosen else (Color("b57e71") if excluded else (GOLD if available else Color("786957")))
		var selected := id == _selected_id
		var normal := STYLE.box(Color(0, 0, 0, 0.06), TEXT if selected else color, 5)
		normal.set_border_width_all(2 if selected else 1)
		normal.shadow_color = Color(0, 0, 0, 0.5)
		normal.shadow_size = 5
		normal.shadow_offset = Vector2(0, 3)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", STYLE.box(Color(0.4, 0.32, 0.2, 0.13), Color("ead1a3"), 5))
		button.add_theme_stylebox_override("pressed", STYLE.box(Color(0.1, 0.08, 0.06, 0.35), GOLD, 5))
		var focus := STYLE.box(Color.TRANSPARENT, TEXT, 5)
		focus.set_border_width_all(2)
		button.add_theme_stylebox_override("focus", focus)
		button.set_meta("mastery_state", state_id)
		button.set_meta("decision", decision.duplicate())
		var surface := button.get_node("AshenMaterial") as SelectionAshenSurface
		surface.set_selected(selected or chosen, color)
		var status := button.get_node("MasteryStatus") as Label
		status.text = "✓ ACQUIS" if chosen else ("× CHOIX EXCLU" if excluded else "%d PMa · %s" % [node.mastery_cost, "DISPONIBLE" if available else _reason_text(node, decision)])
		status.add_theme_color_override("font_color", color if chosen or available or excluded else MUTED)
		button.tooltip_text = "%s\n%s\n%s" % [node.display_name, node.description, status.text]
		if chosen and not _previous_acquired.has(id) and _has_synced_state and not _reduced_motion:
			_pulse_ids[id] = _clock
	for id: StringName in acquired:
		_previous_acquired[id] = true
	_has_synced_state = true


func _reason_text(node: SkillTreeNodeData, decision: Dictionary) -> String:
	match str(decision.get("reason_id", "")):
		"LEVEL_GATE":
			var level := node.required_champion_level
			if node.node_type == SkillTreeNodeData.NodeType.CAPSTONE:
				var profile := _state.champion_progression.profile
				level = maxi(level, profile.second_capstone_level if not _state.champion_progression.selected_capstone_ids.is_empty() else profile.first_capstone_level)
			return "NIV. %d" % level
		"INSUFFICIENT_MASTERY":
			return "POINTS REQUIS"
		"TREE_NOT_COMPLETE":
			return "DOCTRINE"
		"TREE_POINTS_GATE":
			return "SEUIL REQUIS"
	return "PRÉREQUIS"


func _advanced_requirement(node: SkillTreeNodeData) -> String:
	var catalog := _state.progression_profile.mastery_catalog
	var chunks := PackedStringArray()
	for id in node.requires_completed_tree_ids:
		var doctrine := SkillTreeResolver.champion_doctrine_by_id(catalog.doctrines, id)
		chunks.append("%s complète" % _short_doctrine(doctrine))
	for requirement in node.doctrine_point_requirements:
		var doctrine := SkillTreeResolver.champion_doctrine_by_id(catalog.doctrines, requirement.tree_id)
		chunks.append("%s %d" % [_short_doctrine(doctrine), requirement.minimum_points])
	return " + ".join(chunks)


func _short_doctrine(doctrine: DisciplineData) -> String:
	if doctrine == null:
		return "Doctrine"
	if "wrath" in str(doctrine.discipline_id):
		return "Colère"
	if "chiron" in str(doctrine.discipline_id):
		return "Chiron"
	if "aeacus" in str(doctrine.discipline_id):
		return "Rempart"
	return doctrine.display_name


func _build_edges() -> void:
	for id: StringName in _nodes:
		var node := _nodes[id] as SkillTreeNodeData
		for parent in node.prerequisite_node_ids:
			if _buttons.has(parent):
				_edges.append({"from": parent, "to": id, "kind": "all"})
		for parent in node.requires_any_node_ids:
			if _buttons.has(parent):
				_edges.append({"from": parent, "to": id, "kind": "any"})


func _filter_nodes() -> void:
	_matches.clear()
	for id: StringName in _buttons:
		var button := _buttons[id] as Button
		var node := _nodes[id] as SkillTreeNodeData
		var decision := _state.evaluate_mastery_node(id)
		var searchable := "%s %s %s %s %s" % [node.display_name, node.description, _reason_text(node, decision), button.get_meta("mastery_state", ""), (button.get_node("MasteryStatus") as Label).text]
		var matches := _query.is_empty() or searchable.to_lower().contains(_query)
		button.modulate.a = 1.0 if matches else 0.18
		button.mouse_filter = Control.MOUSE_FILTER_STOP if matches else Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL if matches else Control.FOCUS_NONE
		if matches:
			_matches[id] = button
	_wire_focus()
	queue_redraw()


func _wire_focus() -> void:
	var ids := _matches.keys()
	for index in ids.size():
		var button := _matches[ids[index]] as Button
		button.focus_next = button.get_path_to(_matches[ids[index + 1]]) if index < ids.size() - 1 else NodePath()
		button.focus_previous = button.get_path_to(_matches[ids[index - 1]]) if index > 0 else NodePath()


func _choose_node(id: StringName) -> void:
	inspect_node(id)
	node_inspected.emit(id)


func _focus_node(id: StringName) -> void:
	_choose_node(id)
	var button := _buttons.get(id) as Button
	if button != null and not Rect2(Vector2(16, 16), size - Vector2(32, 32)).encloses(Rect2(button.position * _target_zoom + _target_pan, CARD * _target_zoom)):
		center_on_node(id)


func _node_input(event: InputEvent, id: StringName) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_MIDDLE]:
		_gui_input(event)
		(_buttons[id] as Button).accept_event()
	elif event is InputEventMouseMotion and _panning:
		_gui_input(event)
		(_buttons[id] as Button).accept_event()
	elif event is InputEventKey and event.pressed:
		var direction := Vector2.ZERO
		match event.keycode:
			KEY_LEFT: direction = Vector2.LEFT
			KEY_RIGHT: direction = Vector2.RIGHT
			KEY_UP: direction = Vector2.UP
			KEY_DOWN: direction = Vector2.DOWN
		if direction != Vector2.ZERO:
			_focus_direction(id, direction)
			(_buttons[id] as Button).accept_event()


func _focus_direction(id: StringName, direction: Vector2) -> void:
	var from := (_buttons[id] as Button).position
	var best: Button
	var best_score := INF
	for other_id: StringName in _matches:
		if id == other_id:
			continue
		var candidate := _matches[other_id] as Button
		var offset := candidate.position - from
		var forward := offset.dot(direction)
		if forward <= 1:
			continue
		var perpendicular := absf(offset.cross(direction))
		var score := forward + perpendicular * 2.0
		if score < best_score:
			best_score = score
			best = candidate
	if best != null:
		best.grab_focus()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_by(1.12, get_local_mouse_position())
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_by(1.0 / 1.12, get_local_mouse_position())
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			_panning = event.pressed
			mouse_default_cursor_shape = Control.CURSOR_MOVE if _panning else Control.CURSOR_DRAG
			accept_event()
	elif event is InputEventMouseMotion and _panning:
		_target_pan += event.relative
		_clamp_pan()
		_pan = _target_pan
		_apply_transform()
		_emit_navigation()
		accept_event()
	elif event is InputEventMagnifyGesture:
		zoom_by(event.factor, event.position)
		accept_event()
	elif event is InputEventPanGesture:
		_target_pan -= event.delta * 18
		_clamp_pan()
		_snap_if_reduced()
		_emit_navigation()
		accept_event()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_HOME: fit_graph()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: zoom_by(1.15)
			KEY_MINUS, KEY_KP_SUBTRACT: zoom_by(1.0 / 1.15)
			_: return
		accept_event()


func _input(event: InputEvent) -> void:
	if _panning and event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
		_panning = false
		mouse_default_cursor_shape = Control.CURSOR_DRAG


func _clamp_pan() -> void:
	var scaled := _bounds.size * _target_zoom
	_target_pan.x = clampf(_target_pan.x, minf(size.x - 80 - scaled.x, 80), maxf(80, size.x - 80))
	_target_pan.y = clampf(_target_pan.y, minf(size.y - 80 - scaled.y, 80), maxf(80, size.y - 80))


func _on_resized() -> void:
	if _built:
		fit_graph()


func _snap_if_reduced() -> void:
	if _reduced_motion:
		_zoom = _target_zoom
		_pan = _target_pan
		_apply_transform()


func _apply_transform() -> void:
	if _canvas != null:
		_canvas.position = _pan
		_canvas.scale = Vector2.ONE * _zoom
	queue_redraw()


func _emit_navigation() -> void:
	navigation_changed.emit(get_navigation_snapshot())


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	# Reduced motion snaps transform changes synchronously; idle graphs need no redraw.
	if _reduced_motion and is_equal_approx(_zoom, _target_zoom) and _pan.is_equal_approx(_target_pan):
		return
	if not _reduced_motion:
		_clock += delta
	var blend := 1.0 if _reduced_motion else 1.0 - exp(-delta * 16.0)
	_zoom = lerpf(_zoom, _target_zoom, blend)
	_pan = _pan.lerp(_target_pan, blend)
	for id in _pulse_ids.keys():
		if _clock - float(_pulse_ids[id]) > 1.3:
			_pulse_ids.erase(id)
	_apply_transform()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("151312"))
	var texture_size := BACKDROP.get_size()
	var scale_factor := maxf(size.x / texture_size.x, size.y / texture_size.y)
	var rendered := texture_size * scale_factor
	draw_texture_rect(BACKDROP, Rect2((size - rendered) * 0.5, rendered), false, Color(0.68, 0.59, 0.48, 0.30))
	draw_texture_rect(GRAIN, Rect2(Vector2.ZERO, size), false, Color(0.6, 0.49, 0.39, 0.05))
	var center := size * Vector2(0.5, 0.5)
	for radius in [120.0, 210.0, 305.0]:
		draw_arc(center, radius, 0, TAU, 96, Color(0.63, 0.47, 0.28, 0.05), 1.0, true)
	if _canvas == null:
		return
	draw_set_transform(_pan, 0, Vector2.ONE * _zoom)
	# Every edge comes from the resolver's actual AND/OR prerequisite arrays.
	for edge in _edges:
		var source := _buttons.get(edge.from) as Button
		var target := _buttons.get(edge.to) as Button
		if source == null or target == null:
			continue
		var start := source.position + Vector2(CARD.x * 0.5, CARD.y)
		var finish := target.position + Vector2(CARD.x * 0.5, 0)
		var active := str(source.get_meta("mastery_state", "")) == "acquired"
		var highlighted: bool = edge.to == _selected_id or edge.from == _selected_id
		var alpha := 1.0 if _query.is_empty() or _matches.has(edge.to) or _matches.has(edge.from) else 0.2
		var color := ACQUIRED if active else (GOLD if highlighted else Color("554735"))
		color.a = alpha
		var points := PackedVector2Array()
		var curve := Curve2D.new()
		curve.add_point(start, Vector2.ZERO, Vector2(0, 18))
		curve.add_point(finish, Vector2(0, -18), Vector2.ZERO)
		for index in 21:
			points.append(curve.sample(0, index / 20.0))
		draw_polyline(points, Color(color, alpha * 0.10), 8, true)
		draw_polyline(points, color, 1.7 if active or highlighted else 1.0, true)
		if active and not _reduced_motion:
			var t := fposmod(_clock * 0.33, 1.0)
			draw_circle(curve.sample(0, t), 2.1, Color("d7e5c4"))
		if str(edge.kind) == "any" and (_nodes[edge.to] as SkillTreeNodeData).requires_any_node_ids.size() > 1 and source.position.x < target.position.x:
			var middle := (start + finish) * 0.5
			draw_circle(middle, 10, Color("191612"))
			draw_string(STYLE.BOLD, middle + Vector2(-7, 3.5), "OU", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MUTED)
	for entry in _labels:
		draw_string(STYLE.BODY, entry.position, entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, entry.font_size, entry.color)
	for id in _pulse_ids:
		if not _buttons.has(id):
			continue
		var progress := clampf((_clock - float(_pulse_ids[id])) / 1.3, 0.0, 1.0)
		var rect := Rect2((_buttons[id] as Button).position, CARD).grow(3 + progress * 14)
		draw_rect(rect, Color(0.73, 0.88, 0.64, (1.0 - progress) * 0.8), false, 2, true)
	draw_set_transform(Vector2.ZERO)
	if not _query.is_empty() and _matches.is_empty():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.06, 0.055, 0.66))
		draw_string(STYLE.BOLD, Vector2(24, size.y * 0.5), "Aucune maîtrise ne correspond.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT)
