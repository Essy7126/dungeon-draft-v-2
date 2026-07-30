class_name SkillTreeGraphView
extends Control

signal node_inspected(node_view)

const NODE_SCENE := preload(
	"res://ui/progression/components/skill_tree_node_view.tscn"
)
const BASE_ID := &"__base_rank_1"
const EAGLE_BRANCH_ID := &"elf_archer_eagle_eye"
const REPEL_BRANCH_ID := &"elf_archer_repel_arrow"
const PROFILE_LARGE := &"large"
const PROFILE_MEDIUM := &"medium"
const PROFILE_COMPACT := &"compact"

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
var _rank_centers: Dictionary = {}
var _layout_profile: StringName = PROFILE_LARGE
var _layout_spec: Dictionary = {}
var _viewport_size := Vector2(1920.0, 1080.0)
var _available_size := Vector2(1320.0, 860.0)
var _layout_debug_enabled := false


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
		size = custom_minimum_size
		queue_redraw()
		return

	_create_node_views(
		_nodes_by_rank(discipline),
		progress.get_selected_upgrade_ids(),
		progress.get_pending_rank_choices()
	)
	_reflow_layout()


func apply_layout(
		viewport_size: Vector2,
		available_size: Vector2
	) -> void:
	_viewport_size = viewport_size
	_available_size = Vector2(
		maxf(available_size.x, 1.0),
		maxf(available_size.y, 1.0)
	)
	if _discipline != null and _progress != null:
		_reflow_layout()


func set_layout_debug_enabled(value: bool) -> void:
	_layout_debug_enabled = value
	queue_redraw()


func is_layout_debug_enabled() -> bool:
	return _layout_debug_enabled


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
		var state: StringName = connection.get("state", &"compatible")
		result.append({
			"source_id": connection.get("source_id", &""),
			"target_id": connection.get("target_id", &""),
			"state": state,
			"width": get_connection_width(state),
			"points": (
				connection.get("points", PackedVector2Array())
				as PackedVector2Array
			).duplicate(),
			"crosses_intermediate": _connection_intersection_count(
				connection.get("points", PackedVector2Array()),
				connection.get("source") as SkillTreeNodeView,
				connection.get("target") as SkillTreeNodeView
			) > 0,
		})
	return result


func get_connection_width(state: StringName) -> float:
	var scale := float(_layout_spec.get("line_scale", 1.0))
	match state:
		&"selected":
			return 4.5 * scale
		&"available":
			return 3.8 * scale
		&"incompatible":
			return 2.8 * scale
	return 2.8 * scale


func get_branch_band_count() -> int:
	return _branch_rects.size()


func get_branch_rects() -> Array[Rect2]:
	return _branch_rects.duplicate()


func get_rank_center(rank_number: int) -> float:
	return float(_rank_centers.get(rank_number, 0.0))


func get_node_view(node_id: StringName) -> SkillTreeNodeView:
	return _node_views.get(node_id) as SkillTreeNodeView


func get_node_bounds(node_id: StringName) -> Rect2:
	var view := get_node_view(node_id)
	return Rect2(view.position, view.size) if view != null else Rect2()


func get_visual_node_bounds(node_id: StringName) -> Rect2:
	var view := get_node_view(node_id)
	if view == null:
		return Rect2()
	var local_frame := view.get_visual_frame_rect()
	return Rect2(view.position + local_frame.position, local_frame.size)


func get_layout_snapshot() -> Dictionary:
	var first_bounds := get_visual_node_bounds(BASE_ID)
	var right_edge := 0.0
	for value in _node_views.values():
		var view := value as SkillTreeNodeView
		if view != null and view.get_rank() == 5:
			right_edge = maxf(
				right_edge,
				get_visual_node_bounds(view.presentation_id).end.x
			)
	var used_span := maxf(0.0, right_edge - first_bounds.position.x)
	return {
		"profile": _layout_profile,
		"viewport_size": _viewport_size,
		"available_size": _available_size,
		"graph_size": size,
		"rank_centers": _rank_centers.duplicate(),
		"used_span": used_span,
		"used_width_ratio": (
			used_span / size.x if size.x > 0.0 else 0.0
		),
		"side_margin": float(_layout_spec.get("side_margin", 0.0)),
		"column_gap": float(_layout_spec.get("column_gap", 0.0)),
		"branch_gap": float(_layout_spec.get("branch_gap", 0.0)),
		"branch_title_font": int(
			_layout_spec.get("branch_title_font", 0)
		),
		"rank_title_font": int(
			_layout_spec.get("rank_title_font", 0)
		),
	}


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
		var accent_name := (
			"branch_eagle_accent"
			if index == 0
			else "branch_repel_accent"
		)
		var branch_rect := _branch_rects[index]
		draw_rect(
			branch_rect,
			_theme_graph_color(
				color_name,
				Color(0.1, 0.12, 0.14, 0.2)
			),
			true
		)
		draw_line(
			Vector2(branch_rect.position.x + 18.0, branch_rect.position.y + 6.0),
			Vector2(branch_rect.end.x - 18.0, branch_rect.position.y + 6.0),
			_theme_graph_color(
				accent_name,
				Color(0.5, 0.55, 0.5, 0.7)
			),
			2.0 * float(_layout_spec.get("line_scale", 1.0)),
			true
		)
	_draw_root_branch_trunk()
	for connection in _connections:
		_draw_connection(connection)
	if _layout_debug_enabled:
		_draw_layout_debug()


func _draw_connection(connection: Dictionary) -> void:
	var points := (
		connection.get("points", PackedVector2Array())
		as PackedVector2Array
	)
	if points.size() < 2:
		return
	var state: StringName = connection.get("state", &"compatible")
	var width := get_connection_width(state)
	var underlay := _theme_graph_color(
		"connection_underlay",
		Color(0.015, 0.02, 0.028, 0.86)
	)
	var color_name := (
		"connection_selected"
		if state == &"selected"
		else (
			"connection_available"
			if state == &"available"
			else (
				"connection_incompatible"
				if state == &"incompatible"
				else "connection_compatible"
			)
		)
	)
	var color := _theme_graph_color(
		color_name,
		Color(0.42, 0.5, 0.56)
	)
	if state == &"incompatible":
		for index in range(points.size() - 1):
			draw_dashed_line(
				points[index],
				points[index + 1],
				underlay,
				width + 2.0,
				9.0,
				true
			)
			draw_dashed_line(
				points[index],
				points[index + 1],
				color,
				width,
				9.0,
				true
			)
		return
	_draw_polyline_with_joints(points, underlay, width + 2.0)
	_draw_polyline_with_joints(points, color, width)


func _draw_root_branch_trunk() -> void:
	if not _uses_archer_branch_layout():
		return
	var root := get_node_view(BASE_ID)
	var eagle := get_node_view(EAGLE_BRANCH_ID)
	var repel := get_node_view(REPEL_BRANCH_ID)
	if root == null or eagle == null or repel == null:
		return
	var root_anchor := root.position + root.get_connection_anchor(&"right")
	var eagle_anchor := eagle.position + eagle.get_connection_anchor(&"left")
	var repel_anchor := repel.position + repel.get_connection_anchor(&"left")
	var fork_x := lerpf(root_anchor.x, eagle_anchor.x, 0.48)
	var trunk_points := PackedVector2Array([
		Vector2(fork_x, eagle_anchor.y),
		Vector2(fork_x, repel_anchor.y),
	])
	var root_points := PackedVector2Array([
		root_anchor,
		Vector2(fork_x, root_anchor.y),
	])
	var eagle_points := PackedVector2Array([
		Vector2(fork_x, eagle_anchor.y),
		eagle_anchor,
	])
	var repel_points := PackedVector2Array([
		Vector2(fork_x, repel_anchor.y),
		repel_anchor,
	])
	var width := 3.2 * float(_layout_spec.get("line_scale", 1.0))
	var underlay := _theme_graph_color(
		"connection_underlay",
		Color(0.012, 0.016, 0.023, 0.9)
	)
	var color := _theme_graph_color(
		"connection_compatible",
		Color(0.5, 0.59, 0.67, 0.94)
	)
	for points in [trunk_points, root_points, eagle_points, repel_points]:
		_draw_polyline_with_joints(points, underlay, width + 2.0)
		_draw_polyline_with_joints(points, color, width)


func _draw_polyline_with_joints(
		points: PackedVector2Array,
		color: Color,
		width: float
	) -> void:
	draw_polyline(points, color, width, true)
	for index in range(1, points.size() - 1):
		draw_circle(points[index], width * 0.5, color, true)


func _draw_layout_debug() -> void:
	var debug_color := Color(0.15, 0.86, 1.0, 0.85)
	draw_rect(Rect2(Vector2.ZERO, size), debug_color, false, 2.0)
	for value in _node_views.values():
		var view := value as SkillTreeNodeView
		if view == null:
			continue
		var bounds := Rect2(view.position, view.size)
		draw_rect(bounds, Color(0.3, 1.0, 0.48, 0.78), false, 1.0)
		draw_circle(
			view.position + view.get_connection_anchor(&"left"),
			3.5,
			Color(1.0, 0.4, 0.2, 0.95)
		)
		draw_circle(
			view.position + view.get_connection_anchor(&"right"),
			3.5,
			Color(1.0, 0.4, 0.2, 0.95)
		)
	var font := ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(12.0, size.y - 12.0),
		"zone %.0f × %.0f · disponible %.0f × %.0f · écart %.0f"
		% [
			size.x,
			size.y,
			_available_size.x,
			_available_size.y,
			float(_layout_spec.get("column_gap", 0.0)),
		],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		debug_color
	)


func _reflow_layout() -> void:
	if _discipline == null or _progress == null:
		return
	_layout_profile = _profile_for_viewport(_viewport_size)
	_layout_spec = _make_layout_spec(_layout_profile)
	for value in _node_views.values():
		var view := value as SkillTreeNodeView
		if view != null:
			view.apply_layout_profile(_layout_profile)

	var max_rank := _maximum_rank(_discipline)
	var graph_width := maxf(
		_available_size.x,
		float(_layout_spec["minimum_width"])
	)
	var graph_height := _generic_graph_height(
		_nodes_by_rank(_discipline)
	)
	if _uses_archer_branch_layout():
		graph_height = maxf(
			_available_size.y,
			float(_layout_spec["minimum_height"])
		)
		_layout_spec["branch_height"] = (
			graph_height
			- float(_layout_spec["header_height"])
			- float(_layout_spec["branch_gap"])
			- float(_layout_spec["bottom_margin"])
		) * 0.5
	custom_minimum_size = Vector2(graph_width, graph_height)
	size = custom_minimum_size
	_compute_rank_centers(max_rank)
	_clear_layout_chrome()
	for rank_number in range(1, max_rank + 1):
		_add_rank_header(
			rank_number,
			int(_rank_thresholds(_discipline).get(rank_number, 0))
		)
	var nodes_by_rank := _nodes_by_rank(_discipline)
	if _uses_archer_branch_layout():
		_layout_archer_branches(nodes_by_rank)
	else:
		_layout_generic(nodes_by_rank, graph_height)
	_build_connections()
	_configure_focus_navigation()
	queue_redraw()


func _make_layout_spec(profile: StringName) -> Dictionary:
	if profile == PROFILE_MEDIUM:
		return {
			"minimum_width": 1080.0,
			"side_margin": 48.0,
			"minimum_height": 724.0,
			"header_height": 38.0,
			"branch_height": 329.0,
			"branch_gap": 22.0,
			"bottom_margin": 6.0,
			"branch_title_height": 34.0,
			"branch_title_font": 15,
			"rank_title_font": 13,
			"rank4_offset": 70.0,
			"line_scale": 0.9,
		}
	if profile == PROFILE_COMPACT:
		return {
			"minimum_width": 1040.0,
			"side_margin": 44.0,
			"minimum_height": 662.0,
			"header_height": 36.0,
			"branch_height": 300.0,
			"branch_gap": 20.0,
			"bottom_margin": 6.0,
			"branch_title_height": 31.0,
			"branch_title_font": 13,
			"rank_title_font": 12,
			"rank4_offset": 64.0,
			"line_scale": 0.82,
		}
	return {
		"minimum_width": 1150.0,
		"side_margin": 52.0,
		"minimum_height": 790.0,
		"header_height": 40.0,
		"branch_height": 359.0,
		"branch_gap": 26.0,
		"bottom_margin": 6.0,
		"branch_title_height": 38.0,
		"branch_title_font": 16,
		"rank_title_font": 14,
		"rank4_offset": 76.0,
		"line_scale": 1.0,
	}


func _profile_for_viewport(viewport_size: Vector2) -> StringName:
	if viewport_size.x <= 1320.0 or viewport_size.y <= 760.0:
		return PROFILE_COMPACT
	if viewport_size.x <= 1650.0 or viewport_size.y <= 940.0:
		return PROFILE_MEDIUM
	return PROFILE_LARGE


func _compute_rank_centers(max_rank: int) -> void:
	_rank_centers.clear()
	if max_rank <= 0:
		return
	var root := get_node_view(BASE_ID)
	var capstone_width := 174.0
	var root_width := 160.0
	if root != null:
		root_width = root.size.x
	for value in _node_views.values():
		var view := value as SkillTreeNodeView
		if view != null and view.get_rank() >= 5:
			capstone_width = view.size.x
			break
	var side_margin := float(_layout_spec["side_margin"])
	var left_center := side_margin + root_width * 0.5
	var right_center := size.x - side_margin - capstone_width * 0.5
	if max_rank == 1:
		_rank_centers[1] = (left_center + right_center) * 0.5
		_layout_spec["column_gap"] = 0.0
		return
	var regular_gap := (
		(right_center - left_center)
		/ (float(max_rank - 2) + 0.84)
		if max_rank > 2
		else right_center - left_center
	)
	_rank_centers[1] = left_center
	_rank_centers[2] = left_center + regular_gap * 0.84
	for rank_number in range(3, max_rank + 1):
		_rank_centers[rank_number] = (
			float(_rank_centers[rank_number - 1]) + regular_gap
		)
	_layout_spec["column_gap"] = regular_gap


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
	var header_height := float(_layout_spec["header_height"])
	var branch_height := float(_layout_spec["branch_height"])
	var branch_gap := float(_layout_spec["branch_gap"])
	var eagle_top := header_height
	var repel_top := eagle_top + branch_height + branch_gap
	var rank_two_view := get_node_view(EAGLE_BRANCH_ID)
	var band_left := (
		get_rank_center(2)
		- (rank_two_view.size.x * 0.5 if rank_two_view != null else 68.0)
		- 22.0
	)
	var band_right := size.x - float(_layout_spec["side_margin"]) + 10.0
	_branch_rects = [
		Rect2(
			band_left,
			eagle_top,
			band_right - band_left,
			branch_height
		),
		Rect2(
			band_left,
			repel_top,
			band_right - band_left,
			branch_height
		),
	]
	_add_branch_header(
		"BRANCHE ŒIL D’AIGLE",
		_branch_rects[0],
		&"branch_eagle_accent"
	)
	_add_branch_header(
		"BRANCHE FLÈCHE DE RECUL",
		_branch_rects[1],
		&"branch_repel_accent"
	)

	var base_view := get_node_view(BASE_ID)
	if base_view != null:
		var branches_center := (
			_branch_rects[0].get_center().y
			+ _branch_rects[1].get_center().y
		) * 0.5
		_place_centered(
			base_view,
			get_rank_center(1),
			branches_center
		)
	for branch_index in range(2):
		var branch_id := (
			EAGLE_BRANCH_ID if branch_index == 0 else REPEL_BRANCH_ID
		)
		_layout_archer_branch(
			branch_id,
			_branch_rects[branch_index],
			nodes_by_rank
		)


func _layout_archer_branch(
		branch_id: StringName,
		band_rect: Rect2,
		nodes_by_rank: Dictionary
	) -> void:
	var capstone_height := 0.0
	for node_value in nodes_by_rank.get(5, []):
		if node_value == null:
			continue
		var node := node_value as SkillUpgradeData
		if _main_branch_id(node.upgrade_id, {}) != branch_id:
			continue
		var capstone := get_node_view(node.upgrade_id)
		if capstone != null:
			capstone_height = maxf(capstone_height, capstone.size.y)
	var title_height := float(_layout_spec["branch_title_height"])
	var content_top := band_rect.position.y + title_height + 7.0
	var content_bottom := band_rect.end.y - 6.0
	var row_centers := [
		content_top + capstone_height * 0.5,
		content_bottom - capstone_height * 0.5,
	]
	var branch_root := get_node_view(branch_id)
	if branch_root != null:
		_place_centered(
			branch_root,
			get_rank_center(2),
			band_rect.get_center().y
		)

	var rank_three_views := _branch_views(
		nodes_by_rank.get(3, []),
		branch_id
	)
	var rank_three_rows := {}
	for index in range(rank_three_views.size()):
		var view := rank_three_views[index]
		var row_index := mini(index, 1)
		_place_centered(
			view,
			get_rank_center(3),
			float(row_centers[row_index])
		)
		rank_three_rows[view.presentation_id] = row_index

	var parent_child_counts := {}
	var rank_four_views := _branch_views(
		nodes_by_rank.get(4, []),
		branch_id
	)
	for view in rank_four_views:
		var parent_id := _first_prerequisite(view.node_data)
		var row_index := int(rank_three_rows.get(parent_id, 0))
		var sibling_index := int(parent_child_counts.get(parent_id, 0))
		parent_child_counts[parent_id] = sibling_index + 1
		var horizontal_offset := float(_layout_spec["rank4_offset"])
		var wanted_x := get_rank_center(4) + (
			-horizontal_offset if sibling_index == 0 else horizontal_offset
		)
		_place_centered(
			view,
			wanted_x,
			float(row_centers[row_index])
		)

	var rank_five_views := _branch_views(
		nodes_by_rank.get(5, []),
		branch_id
	)
	for index in range(rank_five_views.size()):
		_place_centered(
			rank_five_views[index],
			get_rank_center(5),
			float(row_centers[mini(index, 1)])
		)


func _branch_views(
		node_values: Array,
		branch_id: StringName
	) -> Array[SkillTreeNodeView]:
	var result: Array[SkillTreeNodeView] = []
	for node_value in node_values:
		if node_value == null:
			continue
		var node := node_value as SkillUpgradeData
		if _main_branch_id(node.upgrade_id, {}) != branch_id:
			continue
		var view := get_node_view(node.upgrade_id)
		if view != null:
			result.append(view)
	return result


func _place_centered(
		view: SkillTreeNodeView,
		center_x: float,
		center_y: float
	) -> void:
	view.position = Vector2(
		center_x - view.size.x * 0.5,
		center_y - view.size.y * 0.5
	)


func _layout_generic(
		nodes_by_rank: Dictionary,
		graph_height: float
	) -> void:
	var header_height := float(_layout_spec["header_height"])
	for rank_number_value in nodes_by_rank:
		var rank_number := int(rank_number_value)
		var rank_nodes: Array = nodes_by_rank[rank_number]
		var views: Array[SkillTreeNodeView] = []
		var column_height := 0.0
		for node_value in rank_nodes:
			var node_id := (
				BASE_ID
				if node_value == null
				else (node_value as SkillUpgradeData).upgrade_id
			)
			var view := get_node_view(node_id)
			if view != null:
				views.append(view)
				column_height += view.size.y
		column_height += maxf(views.size() - 1, 0) * 18.0
		var y := header_height + maxf(
			0.0,
			(graph_height - header_height - column_height) * 0.5
		)
		for view in views:
			view.position = Vector2(
				get_rank_center(rank_number) - view.size.x * 0.5,
				y
			)
			y += view.size.y + 18.0


func _generic_graph_height(nodes_by_rank: Dictionary) -> float:
	var max_count := 1
	var max_node_height := 150.0
	for rank_nodes in nodes_by_rank.values():
		max_count = maxi(max_count, (rank_nodes as Array).size())
	for value in _node_views.values():
		var view := value as SkillTreeNodeView
		if view != null:
			max_node_height = maxf(max_node_height, view.size.y)
	return maxf(
		520.0,
		float(_layout_spec["header_height"])
		+ max_count * max_node_height
		+ maxf(max_count - 1, 0) * 18.0
		+ 36.0
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
	var direct := PackedVector2Array([
		start,
		Vector2(middle_x, start.y),
		Vector2(middle_x, finish.y),
		finish,
	])
	if _connection_intersection_count(direct, source, target) == 0:
		return direct
	var branch_rect := _shared_branch_rect(source, target)
	if branch_rect.size == Vector2.ZERO:
		return direct
	var title_height := float(_layout_spec["branch_title_height"])
	var corridors := [
		branch_rect.position.y + title_height + 2.0,
		branch_rect.end.y - 3.0,
	]
	var best := direct
	var best_intersections := _connection_intersection_count(
		direct,
		source,
		target
	)
	var best_length := _polyline_length(direct)
	var elbow_offset := 18.0 * float(_layout_spec["line_scale"])
	for corridor_value in corridors:
		var corridor_y := float(corridor_value)
		var first_x := start.x + elbow_offset
		var last_x := finish.x - elbow_offset
		if last_x <= first_x:
			continue
		var candidate := PackedVector2Array([
			start,
			Vector2(first_x, start.y),
			Vector2(first_x, corridor_y),
			Vector2(last_x, corridor_y),
			Vector2(last_x, finish.y),
			finish,
		])
		var intersection_count := _connection_intersection_count(
			candidate,
			source,
			target
		)
		var candidate_length := _polyline_length(candidate)
		if (
			intersection_count < best_intersections
			or (
				intersection_count == best_intersections
				and candidate_length < best_length
			)
		):
			best = candidate
			best_intersections = intersection_count
			best_length = candidate_length
	return best


func _connection_intersection_count(
		points: PackedVector2Array,
		source: SkillTreeNodeView,
		target: SkillTreeNodeView
	) -> int:
	if source == null or target == null:
		return 0
	var count := 0
	for value in _node_views.values():
		var intermediate := value as SkillTreeNodeView
		if (
			intermediate == null
			or intermediate == source
			or intermediate == target
		):
			continue
		var local_frame := intermediate.get_visual_frame_rect()
		var bounds := Rect2(
			intermediate.position + local_frame.position,
			local_frame.size
		).grow(3.0)
		var intersects := false
		for index in range(points.size() - 1):
			if _segment_intersects_rect(
				points[index],
				points[index + 1],
				bounds
			):
				intersects = true
				break
		if intersects:
			count += 1
	return count


func _segment_intersects_rect(
		from: Vector2,
		to: Vector2,
		rect: Rect2
	) -> bool:
	if rect.has_point(from) or rect.has_point(to):
		return true
	var top_left := rect.position
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_right := rect.end
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	for edge in [
		[top_left, top_right],
		[top_right, bottom_right],
		[bottom_right, bottom_left],
		[bottom_left, top_left],
	]:
		if Geometry2D.segment_intersects_segment(
			from,
			to,
			edge[0],
			edge[1]
		) != null:
			return true
	return false


func _shared_branch_rect(
		source: SkillTreeNodeView,
		target: SkillTreeNodeView
	) -> Rect2:
	var source_center := source.position + source.size * 0.5
	var target_center := target.position + target.size * 0.5
	for branch_rect in _branch_rects:
		if (
			branch_rect.has_point(source_center)
			and branch_rect.has_point(target_center)
		):
			return branch_rect
	return Rect2()


func _polyline_length(points: PackedVector2Array) -> float:
	var result := 0.0
	for index in range(points.size() - 1):
		result += points[index].distance_to(points[index + 1])
	return result


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


func _first_prerequisite(node: SkillUpgradeData) -> StringName:
	if not node is SkillTreeNodeData:
		return &""
	var prerequisites := (
		node as SkillTreeNodeData
	).prerequisite_node_ids
	return prerequisites[0] if not prerequisites.is_empty() else &""


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
	header.position = Vector2(
		get_rank_center(rank_number) - 82.0,
		2.0
	)
	header.size = Vector2(164.0, float(_layout_spec["header_height"]) - 5.0)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override(
		"font_size",
		int(_layout_spec["rank_title_font"])
	)
	header.add_theme_color_override(
		"font_color",
		_theme_graph_color(
			"rank_title",
			Color(0.82, 0.84, 0.86)
		)
	)
	header.add_theme_color_override(
		"font_outline_color",
		Color(0.02, 0.025, 0.03, 0.9)
	)
	header.add_theme_constant_override("outline_size", 3)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	_rank_headers.append(header)


func _add_branch_header(
		title: String,
		band_rect: Rect2,
		accent_color_name: StringName
	) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SkillTreeBranchTitle"
	panel.position = band_rect.position + Vector2(16.0, 9.0)
	panel.size = Vector2(
		310.0 if _layout_profile == PROFILE_LARGE else 276.0,
		float(_layout_spec["branch_title_height"]) - 10.0
	)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override(
		"font_size",
		int(_layout_spec["branch_title_font"])
	)
	label.add_theme_color_override(
		"font_color",
		_theme_graph_color(
			accent_color_name,
			Color(0.9, 0.82, 0.62)
		)
	)
	panel.add_child(label)
	add_child(panel)
	move_child(panel, 0)
	_branch_headers.append(panel)


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


func _clear_layout_chrome() -> void:
	_branch_rects.clear()
	for header in _rank_headers:
		if is_instance_valid(header):
			remove_child(header)
			header.queue_free()
	_rank_headers.clear()
	for header in _branch_headers:
		if is_instance_valid(header):
			remove_child(header)
			header.queue_free()
	_branch_headers.clear()


func _clear_graph() -> void:
	_node_views.clear()
	_connections.clear()
	_rank_headers.clear()
	_branch_headers.clear()
	_branch_rects.clear()
	_rank_centers.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
