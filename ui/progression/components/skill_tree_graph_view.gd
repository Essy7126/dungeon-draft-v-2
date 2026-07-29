class_name SkillTreeGraphView
extends Control

signal node_inspected(node_view)

const NODE_SCENE := preload(
	"res://ui/progression/components/skill_tree_node_view.tscn"
)
const NODE_SIZE := Vector2(210, 120)
const COLUMN_WIDTH := 250.0
const ROW_GAP := 18.0
const HEADER_HEIGHT := 42.0
const SIDE_MARGIN := 26.0
const BASE_ID := &"__base_rank_1"

var _discipline: DisciplineData = null
var _progress: DisciplineProgressState = null
var _base_display_name := ""
var _node_views: Dictionary = {}
var _connections: Array[Dictionary] = []
var _rank_headers: Array[Label] = []


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
		custom_minimum_size = Vector2(700, 420)
		queue_redraw()
		return

	var selected_ids := progress.get_selected_upgrade_ids()
	var pending_ranks := progress.get_pending_rank_choices()
	var nodes_by_rank: Dictionary = {}
	var rank_thresholds: Dictionary = {}
	var max_rank := 1
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		max_rank = maxi(max_rank, rank_data.rank)
		rank_thresholds[rank_data.rank] = rank_data.required_total_xp
		if rank_data.rank == 1 and rank_data.choices.is_empty():
			nodes_by_rank[1] = [null]
		else:
			nodes_by_rank[rank_data.rank] = rank_data.choices.duplicate()

	var max_count := 1
	for rank_value in nodes_by_rank.values():
		max_count = maxi(max_count, (rank_value as Array).size())
	var graph_height := maxf(
		520.0,
		HEADER_HEIGHT + max_count * NODE_SIZE.y
		+ maxf(max_count - 1, 0) * ROW_GAP + 50.0
	)
	var graph_width := (
		SIDE_MARGIN * 2.0 + max_rank * COLUMN_WIDTH
	)
	custom_minimum_size = Vector2(graph_width, graph_height)
	size = custom_minimum_size

	for rank_number in range(1, max_rank + 1):
		_add_rank_header(
			rank_number,
			int(rank_thresholds.get(rank_number, 0))
		)
		var rank_nodes: Array = nodes_by_rank.get(rank_number, [])
		var column_height := (
			rank_nodes.size() * NODE_SIZE.y
			+ maxf(rank_nodes.size() - 1, 0) * ROW_GAP
		)
		var y := HEADER_HEIGHT + maxf(
			0.0,
			(graph_height - HEADER_HEIGHT - column_height) * 0.5
		)
		for node_value in rank_nodes:
			var view := NODE_SCENE.instantiate() as SkillTreeNodeView
			add_child(view)
			view.position = Vector2(
				SIDE_MARGIN + float(rank_number - 1) * COLUMN_WIDTH,
				y
			)
			view.size = NODE_SIZE
			view.inspection_requested.connect(_on_node_inspection)
			if node_value == null:
				var base_presentation := (
					SkillTreeVisualPresentation.describe_base_rank(
						progress,
						int(rank_thresholds.get(1, 0))
					)
				)
				view.configure_base(
					discipline,
					base_display_name,
					base_presentation
				)
				_node_views[BASE_ID] = view
			else:
				var node := node_value as SkillUpgradeData
				var presentation := SkillTreeVisualPresentation.describe_node(
					discipline,
					node,
					progress,
					selected_ids,
					pending_ranks
				)
				view.configure_node(discipline, node, presentation)
				_node_views[node.upgrade_id] = view
			y += NODE_SIZE.y + ROW_GAP

	_build_connections()
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


func get_node_view(node_id: StringName) -> SkillTreeNodeView:
	return _node_views.get(node_id) as SkillTreeNodeView


func get_first_node_view() -> SkillTreeNodeView:
	if _node_views.has(BASE_ID):
		return _node_views[BASE_ID] as SkillTreeNodeView
	for view_value in _node_views.values():
		return view_value as SkillTreeNodeView
	return null


func inspect_node_by_id(node_id: StringName) -> bool:
	var view := get_node_view(node_id)
	if view == null:
		return false
	_on_node_inspection(view)
	return true


func _draw() -> void:
	for connection in _connections:
		var source := connection.get("source") as SkillTreeNodeView
		var target := connection.get("target") as SkillTreeNodeView
		if source == null or target == null:
			continue
		var start := source.position + Vector2(NODE_SIZE.x, NODE_SIZE.y * 0.5)
		var finish := target.position + Vector2(0.0, NODE_SIZE.y * 0.5)
		var middle_x := (start.x + finish.x) * 0.5
		var points := PackedVector2Array([
			start,
			Vector2(middle_x, start.y),
			Vector2(middle_x, finish.y),
			finish,
		])
		var connection_state: StringName = connection.get(
			"state",
			&"compatible"
		)
		if connection_state == &"incompatible":
			var color := get_theme_color(
				"connection_incompatible",
				"SkillTreeGraphView"
			)
			for index in range(points.size() - 1):
				draw_dashed_line(
					points[index],
					points[index + 1],
					color,
					2.0,
					8.0,
					true
				)
		else:
			var color_name := (
				"connection_selected"
				if connection_state == &"selected"
				else "connection_compatible"
			)
			draw_polyline(
				points,
				get_theme_color(color_name, "SkillTreeGraphView"),
				3.0 if connection_state == &"selected" else 2.0,
				true
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
				})


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
	return &"compatible"


func _add_rank_header(rank_number: int, threshold: int) -> void:
	var header := Label.new()
	header.text = "RANG %d · %d XP" % [rank_number, threshold]
	header.position = Vector2(
		SIDE_MARGIN + float(rank_number - 1) * COLUMN_WIDTH,
		8.0
	)
	header.size = Vector2(NODE_SIZE.x, 28.0)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override(
		"font_color",
		Color(0.72, 0.76, 0.8)
	)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	_rank_headers.append(header)


func _on_node_inspection(view: SkillTreeNodeView) -> void:
	node_inspected.emit(view)


func _clear_graph() -> void:
	_node_views.clear()
	_connections.clear()
	_rank_headers.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
