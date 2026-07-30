class_name SkillTreeGraphView
extends Control

signal node_inspected(node_view)

const NODE_SCENE := preload(
	"res://ui/progression/components/skill_tree_node_view.tscn"
)
const NODE_SIZE := Vector2(134, 104)
const COLUMN_WIDTH := 178.0
const SIDE_MARGIN := 34.0
const HEADER_HEIGHT := 52.0
const BRANCH_BAND_HEIGHT := 500.0
const BRANCH_GAP := 16.0
const BRANCH_TITLE_HEIGHT := 30.0
const BASE_ID := &"__base_rank_1"
const EAGLE_BRANCH_ID := &"elf_archer_eagle_eye"
const REPEL_BRANCH_ID := &"elf_archer_repel_arrow"

@export var skin: SkillTreeSkinData = null
@export var visual_map: SkillTreeVisualMapData = null

var _discipline: DisciplineData = null
var _progress: DisciplineProgressState = null
var _base_display_name := ""
var _node_views: Dictionary = {}
var _connections: Array[Dictionary] = []
var _rank_headers: Array[Label] = []
var _branch_headers: Array[PanelContainer] = []
var _branch_rects: Array[Rect2] = []


func rebuild(
		discipline: DisciplineData,
		progress: DisciplineProgressState,
		base_display_name: String
	) -> void:
	_clear_graph()
	_discipline = discipline
	_progress = progress
	_base_display_name = base_display_name
	if discipline == null or progress == null:
		custom_minimum_size = Vector2(720, 440)
		queue_redraw()
		return

	var selected_ids := progress.get_selected_upgrade_ids()
	var pending_ranks := progress.get_pending_rank_choices()
	var nodes_by_rank := _nodes_by_rank(discipline)
	var rank_thresholds := _rank_thresholds(discipline)
	var max_rank := _maximum_rank(discipline)
	var graph_width := SIDE_MARGIN * 2.0 + max_rank * COLUMN_WIDTH
	var graph_height := (
		HEADER_HEIGHT
		+ BRANCH_BAND_HEIGHT * 2.0
		+ BRANCH_GAP
		+ 24.0
		if _uses_archer_branch_layout()
		else _generic_graph_height(nodes_by_rank)
	)
	custom_minimum_size = Vector2(graph_width, graph_height)
	size = custom_minimum_size

	for rank_number in range(1, max_rank + 1):
		_add_rank_header(
			rank_number,
			int(rank_thresholds.get(rank_number, 0))
		)

	_create_node_views(
		nodes_by_rank,
		selected_ids,
		pending_ranks
	)
	if _uses_archer_branch_layout():
		_layout_archer_branches(nodes_by_rank)
	else:
		_layout_generic(nodes_by_rank, graph_height)
	_build_connections()
	_configure_focus_navigation()
	queue_redraw()


func get_node_view_count() -> int:
	return _node_views.size()


func get_connection_count() -> int:
	return _connections.size()


func get_connection_states() -> Array[StringName]:
	var states: Array[StringName] = []
	for connection in _connections:
		states.append(connection.get("state", &"compatible"))
	return states


func get_connection_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for connection in _connections:
		result.append({
			"source_id": connection.get("source_id", &""),
			"target_id": connection.get("target_id", &""),
			"state": connection.get("state", &"compatible"),
			"points": (
				connection.get("points", PackedVector2Array())
				as PackedVector2Array
			).duplicate(),
		})
	return result


func get_branch_band_count() -> int:
	return _branch_rects.size()


func get_branch_rects() -> Array[Rect2]:
	return _branch_rects.duplicate()


func get_node_view(node_id: StringName) -> SkillTreeNodeView:
	return _node_views.get(node_id) as SkillTreeNodeView


func get_node_bounds(node_id: StringName) -> Rect2:
	var view := get_node_view(node_id)
	return Rect2(view.position, view.size) if view != null else Rect2()


func get_first_node_view() -> SkillTreeNodeView:
	if _node_views.has(BASE_ID):
		return _node_views[BASE_ID] as SkillTreeNodeView
	for view_value in _node_views.values():
		return view_value as SkillTreeNodeView
	return null


func get_node_views_in_focus_order() -> Array[SkillTreeNodeView]:
	var result: Array[SkillTreeNodeView] = []
	for value in _node_views.values():
		var view := value as SkillTreeNodeView
		if view != null:
			result.append(view)
	result.sort_custom(
		func(a: SkillTreeNodeView, b: SkillTreeNodeView) -> bool:
			if not is_equal_approx(a.position.x, b.position.x):
				return a.position.x < b.position.x
			return a.position.y < b.position.y
	)
	return result


func inspect_node_by_id(node_id: StringName) -> bool:
	var view := get_node_view(node_id)
	if view == null:
		return false
	_on_node_inspection(view)
	return true


func focus_node_by_id(node_id: StringName) -> bool:
	var view := get_node_view(node_id)
	if view == null:
		return false
	view.grab_focus.call_deferred()
	return true


func _draw() -> void:
	for index in range(_branch_rects.size()):
		var color_name := (
			"branch_eagle" if index == 0 else "branch_repel"
		)
		draw_rect(
			_branch_rects[index],
			_theme_graph_color(color_name, Color(0.1, 0.12, 0.14, 0.2)),
			true
		)
	for connection in _connections:
		var points := (
			connection.get("points", PackedVector2Array())
			as PackedVector2Array
		)
		if points.size() < 2:
			continue
		var connection_state: StringName = connection.get(
			"state",
			&"compatible"
		)
		if connection_state == &"incompatible":
			var incompatible_color := _theme_graph_color(
				"connection_incompatible",
				Color(0.24, 0.18, 0.2, 0.75)
			)
			for index in range(points.size() - 1):
				draw_dashed_line(
					points[index],
					points[index + 1],
					incompatible_color,
					2.0,
					8.0,
					true
				)
			continue
		var color_name := (
			"connection_selected"
			if connection_state == &"selected"
			else (
				"connection_available"
				if connection_state == &"available"
				else "connection_compatible"
			)
		)
		var width := (
			3.5
			if connection_state == &"selected"
			else 2.5 if connection_state == &"available" else 2.0
		)
		draw_polyline(
			points,
			_theme_graph_color(color_name, Color(0.42, 0.5, 0.56)),
			width,
			true
		)


func _nodes_by_rank(discipline: DisciplineData) -> Dictionary:
	var result := {}
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		if rank_data.rank == 1 and rank_data.choices.is_empty():
			result[1] = [null]
		else:
			result[rank_data.rank] = rank_data.choices.duplicate()
	return result


func _rank_thresholds(discipline: DisciplineData) -> Dictionary:
	var result := {}
	for rank_data in discipline.ranks:
		if rank_data != null:
			result[rank_data.rank] = rank_data.required_total_xp
	return result


func _maximum_rank(discipline: DisciplineData) -> int:
	var max_rank := 1
	for rank_data in discipline.ranks:
		if rank_data != null:
			max_rank = maxi(max_rank, rank_data.rank)
	return max_rank


func _create_node_views(
		nodes_by_rank: Dictionary,
		selected_ids: Array[StringName],
		pending_ranks: Array[int]
	) -> void:
	var rank_numbers: Array = nodes_by_rank.keys()
	rank_numbers.sort()
	for rank_number_value in rank_numbers:
		var rank_number := int(rank_number_value)
		for node_value in nodes_by_rank[rank_number]:
			var view := NODE_SCENE.instantiate() as SkillTreeNodeView
			var node_id := BASE_ID
			if node_value != null:
				node_id = (node_value as SkillUpgradeData).upgrade_id
			view.name = _safe_node_name(node_id)
			add_child(view)
			view.size = NODE_SIZE
			view.inspection_requested.connect(_on_node_inspection)
			var visual := (
				visual_map.get_visual(node_id)
				if visual_map != null
				else null
			)
			if node_value == null:
				view.configure_base(
					_discipline,
					_base_display_name,
					SkillTreeVisualPresentation.describe_base_rank(
						_progress,
						0
					),
					skin,
					visual
				)
			else:
				var node := node_value as SkillUpgradeData
				view.configure_node(
					_discipline,
					node,
					SkillTreeVisualPresentation.describe_node(
						_discipline,
						node,
						_progress,
						selected_ids,
						pending_ranks
					),
					skin,
					visual
				)
			_node_views[node_id] = view


func _layout_archer_branches(nodes_by_rank: Dictionary) -> void:
	var eagle_top := HEADER_HEIGHT
	var repel_top := eagle_top + BRANCH_BAND_HEIGHT + BRANCH_GAP
	var band_left := _rank_x(2) - 18.0
	var band_width := size.x - band_left - 18.0
	_branch_rects = [
		Rect2(band_left, eagle_top, band_width, BRANCH_BAND_HEIGHT),
		Rect2(band_left, repel_top, band_width, BRANCH_BAND_HEIGHT),
	]
	_add_branch_header("BRANCHE ŒIL D’AIGLE", _branch_rects[0])
	_add_branch_header("BRANCHE FLÈCHE DE RECUL", _branch_rects[1])

	var base_view := get_node_view(BASE_ID)
	if base_view != null:
		base_view.position = Vector2(
			_rank_x(1),
			(size.y - NODE_SIZE.y) * 0.5
		)
	for rank_number in range(2, 6):
		var eagle_nodes: Array[SkillTreeNodeView] = []
		var repel_nodes: Array[SkillTreeNodeView] = []
		for node_value in nodes_by_rank.get(rank_number, []):
			if node_value == null:
				continue
			var node := node_value as SkillUpgradeData
			var view := get_node_view(node.upgrade_id)
			var branch_id := _main_branch_id(node.upgrade_id, {})
			if branch_id == EAGLE_BRANCH_ID:
				eagle_nodes.append(view)
			elif branch_id == REPEL_BRANCH_ID:
				repel_nodes.append(view)
		_place_branch_column(eagle_nodes, rank_number, eagle_top)
		_place_branch_column(repel_nodes, rank_number, repel_top)


func _place_branch_column(
		views: Array[SkillTreeNodeView],
		rank_number: int,
		band_top: float
	) -> void:
	if views.is_empty():
		return
	var content_top := band_top + BRANCH_TITLE_HEIGHT + 12.0
	var content_height := (
		BRANCH_BAND_HEIGHT
		- BRANCH_TITLE_HEIGHT
		- 24.0
	)
	var step := (
		(content_height - NODE_SIZE.y) / float(views.size() - 1)
		if views.size() > 1
		else 0.0
	)
	var y := (
		content_top
		if views.size() > 1
		else content_top + (content_height - NODE_SIZE.y) * 0.5
	)
	for view in views:
		view.position = Vector2(_rank_x(rank_number), y)
		y += step


func _layout_generic(
		nodes_by_rank: Dictionary,
		graph_height: float
	) -> void:
	for rank_number_value in nodes_by_rank:
		var rank_number := int(rank_number_value)
		var rank_nodes: Array = nodes_by_rank[rank_number]
		var column_height := (
			rank_nodes.size() * NODE_SIZE.y
			+ maxf(rank_nodes.size() - 1, 0) * 14.0
		)
		var y := HEADER_HEIGHT + maxf(
			0.0,
			(graph_height - HEADER_HEIGHT - column_height) * 0.5
		)
		for node_value in rank_nodes:
			var node_id := (
				BASE_ID
				if node_value == null
				else (node_value as SkillUpgradeData).upgrade_id
			)
			var view := get_node_view(node_id)
			if view != null:
				view.position = Vector2(_rank_x(rank_number), y)
			y += NODE_SIZE.y + 14.0


func _generic_graph_height(nodes_by_rank: Dictionary) -> float:
	var max_count := 1
	for rank_nodes in nodes_by_rank.values():
		max_count = maxi(max_count, (rank_nodes as Array).size())
	return maxf(
		520.0,
		HEADER_HEIGHT
		+ max_count * NODE_SIZE.y
		+ maxf(max_count - 1, 0) * 14.0
		+ 38.0
	)


func _build_connections() -> void:
	_connections.clear()
	if _discipline == null:
		return
	for rank_data in _discipline.ranks:
		if rank_data == null:
			continue
		for node in rank_data.choices:
			if not node is SkillTreeNodeData:
				continue
			var target := get_node_view(node.upgrade_id)
			if target == null:
				continue
			for prerequisite_id in (
				node as SkillTreeNodeData
			).prerequisite_node_ids:
				var source := get_node_view(prerequisite_id)
				if source == null:
					continue
				_connections.append({
					"source": source,
					"target": target,
					"source_id": prerequisite_id,
					"target_id": node.upgrade_id,
					"state": _connection_state(source, target),
					"points": _connection_points(source, target),
				})


func _connection_points(
		source: SkillTreeNodeView,
		target: SkillTreeNodeView
	) -> PackedVector2Array:
	var start := source.position + source.get_connection_anchor(&"right")
	var finish := target.position + target.get_connection_anchor(&"left")
	var middle_x := (start.x + finish.x) * 0.5
	return PackedVector2Array([
		start,
		Vector2(middle_x, start.y),
		Vector2(middle_x, finish.y),
		finish,
	])


func _connection_state(
		source: SkillTreeNodeView,
		target: SkillTreeNodeView
	) -> StringName:
	var source_state: int = source.visual_presentation.get(
		"state",
		SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE
	)
	var target_state: int = target.visual_presentation.get(
		"state",
		SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE
	)
	if (
		source_state
		== SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED
		and target_state
		== SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED
	):
		return &"selected"
	if (
		source_state
		== SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH
		or target_state
		== SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH
	):
		return &"incompatible"
	if (
		target_state
		== SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE
	):
		return &"available"
	return &"compatible"


func _main_branch_id(
		node_id: StringName,
		visited: Dictionary
	) -> StringName:
	if node_id == EAGLE_BRANCH_ID or node_id == REPEL_BRANCH_ID:
		return node_id
	if visited.has(node_id):
		return &""
	visited[node_id] = true
	var node := _find_node(node_id)
	if not node is SkillTreeNodeData:
		return &""
	for prerequisite_id in (
		node as SkillTreeNodeData
	).prerequisite_node_ids:
		var branch_id := _main_branch_id(prerequisite_id, visited)
		if branch_id != &"":
			return branch_id
	return &""


func _find_node(node_id: StringName) -> SkillUpgradeData:
	if _discipline == null:
		return null
	for rank_data in _discipline.ranks:
		if rank_data == null:
			continue
		for node in rank_data.choices:
			if node != null and node.upgrade_id == node_id:
				return node
	return null


func _configure_focus_navigation() -> void:
	var ordered := get_node_views_in_focus_order()
	for index in range(ordered.size()):
		var view := ordered[index]
		view.focus_neighbor_left = _neighbor_path(view, Vector2.LEFT, ordered)
		view.focus_neighbor_right = _neighbor_path(view, Vector2.RIGHT, ordered)
		view.focus_neighbor_top = _neighbor_path(view, Vector2.UP, ordered)
		view.focus_neighbor_bottom = _neighbor_path(view, Vector2.DOWN, ordered)
		if index > 0:
			view.focus_previous = view.get_path_to(ordered[index - 1])
		if index + 1 < ordered.size():
			view.focus_next = view.get_path_to(ordered[index + 1])


func _neighbor_path(
		source: SkillTreeNodeView,
		direction: Vector2,
		views: Array[SkillTreeNodeView]
	) -> NodePath:
	var source_center := source.position + source.size * 0.5
	var best: SkillTreeNodeView = null
	var best_score := INF
	for candidate in views:
		if candidate == source:
			continue
		var delta := candidate.position + candidate.size * 0.5 - source_center
		var primary := delta.dot(direction)
		if primary <= 2.0:
			continue
		var perpendicular := absf(delta.cross(direction))
		var score := primary + perpendicular * 1.8
		if score < best_score:
			best_score = score
			best = candidate
	return source.get_path_to(best) if best != null else NodePath()


func _add_rank_header(rank_number: int, threshold: int) -> void:
	var header := Label.new()
	header.text = "RANG %d\n%d XP" % [rank_number, threshold]
	header.position = Vector2(_rank_x(rank_number), 6.0)
	header.size = Vector2(NODE_SIZE.x, 40.0)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override(
		"font_color",
		Color(0.78, 0.8, 0.82)
	)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	_rank_headers.append(header)


func _add_branch_header(title: String, band_rect: Rect2) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SkillTreeBranchTitle"
	panel.position = band_rect.position + Vector2(10.0, 5.0)
	panel.size = Vector2(238.0, 25.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override(
		"font_color",
		Color(0.9, 0.82, 0.62)
	)
	panel.add_child(label)
	add_child(panel)
	move_child(panel, 0)
	_branch_headers.append(panel)


func _rank_x(rank_number: int) -> float:
	return SIDE_MARGIN + float(rank_number - 1) * COLUMN_WIDTH


func _uses_archer_branch_layout() -> bool:
	return (
		_discipline != null
		and _discipline.discipline_id == &"archer"
		and _maximum_rank(_discipline) >= 5
	)


func _safe_node_name(node_id: StringName) -> String:
	return (
		"Node_%s" % str(node_id)
	).replace("-", "_").replace(" ", "_")


func _theme_graph_color(name: StringName, fallback: Color) -> Color:
	return (
		get_theme_color(name, "SkillTreeGraphView")
		if has_theme_color(name, "SkillTreeGraphView")
		else fallback
	)


func _on_node_inspection(view: SkillTreeNodeView) -> void:
	node_inspected.emit(view)


func _clear_graph() -> void:
	_node_views.clear()
	_connections.clear()
	_rank_headers.clear()
	_branch_headers.clear()
	_branch_rects.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
