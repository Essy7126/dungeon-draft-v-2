@tool
class_name SkillTreeStudioGraphEdit
extends GraphEdit

signal subject_selected(subject)
signal prerequisite_requested(child: SkillTreeNodeData, parent: SkillUpgradeData)
signal prerequisite_removal_requested(child: SkillTreeNodeData, parent_id: StringName)
signal node_creation_requested(rank: int)
signal nodes_deletion_requested(nodes: Array[SkillUpgradeData])
signal node_duplication_requested(node: SkillUpgradeData)
signal branch_creation_requested(rank: int)
signal child_creation_requested(parent: SkillUpgradeData, rank: int)

const ROOT_NAME := &"skill_root"
const COLUMN_WIDTH := 300.0
const ROW_HEIGHT := 176.0

var discipline: DisciplineData = null
var base_spell: Spell = null
var messages: Array[SkillTreeValidationMessage] = []
var resource_by_graph_name := {}
var graph_name_by_node_id := {}
var _saved_positions := {}
var _popup: PopupMenu
var _popup_rank := 2
var _copied_node_id: StringName = &""


func _ready() -> void:
	minimap_enabled = true
	minimap_size = Vector2(210, 140)
	show_zoom_label = true
	show_arrange_button = false
	panning_scheme = GraphEdit.SCROLL_PANS
	right_disconnects = true
	connection_lines_curvature = 0.35
	connection_lines_thickness = 3.0
	connection_request.connect(_on_connection_request)
	disconnection_request.connect(_on_disconnection_request)
	connection_to_empty.connect(_on_connection_to_empty)
	node_selected.connect(_on_node_selected)
	delete_nodes_request.connect(_on_delete_nodes_request)
	copy_nodes_request.connect(_copy_selected_node)
	paste_nodes_request.connect(_paste_copied_node)
	duplicate_nodes_request.connect(_duplicate_selected_node)
	popup_request.connect(_on_popup_request)
	_popup = PopupMenu.new()
	_popup.add_item("Ajouter une amélioration dans ce rang", 1)
	_popup.add_item("Recentrer et organiser l’arbre", 2)
	_popup.add_separator()
	_popup.add_item("Dupliquer le nœud sélectionné", 3)
	_popup.add_item("Créer une branche complète…", 4)
	_popup.add_item("Supprimer la sélection…", 5)
	_popup.id_pressed.connect(_on_popup_action)
	add_child(_popup)


func display(
		p_discipline: DisciplineData,
		p_base_spell: Spell,
		p_messages: Array[SkillTreeValidationMessage] = [],
		graph_state: Dictionary = {}
	) -> void:
	discipline = p_discipline
	base_spell = p_base_spell
	messages = p_messages
	_saved_positions = graph_state.get("positions", {}) as Dictionary
	_clear_graph()
	if discipline == null:
		return
	_add_root()
	for rank_data in _sorted_ranks():
		var row := 0
		for node in rank_data.choices:
			if node == null:
				continue
			_add_upgrade_node(node, rank_data.required_total_xp, row)
			row += 1
	_add_connections()
	zoom = clampf(float(graph_state.get("zoom", 1.0)), zoom_min, zoom_max)
	var wanted_scroll := graph_state.get("scroll_offset", Vector2.ZERO) as Vector2
	call_deferred("_apply_scroll", wanted_scroll)


func get_graph_state() -> Dictionary:
	var positions := {}
	for child in get_children():
		if child is GraphNode and child.name != ROOT_NAME:
			var node := resource_by_graph_name.get(child.name) as SkillUpgradeData
			if node != null:
				positions[str(node.upgrade_id)] = child.position_offset
	return {
		"scroll_offset": scroll_offset,
		"zoom": zoom,
		"positions": positions,
	}


func organize() -> void:
	var rows_by_rank := {}
	for child in get_children():
		if not child is GraphNode:
			continue
		if child.name == ROOT_NAME:
			child.position_offset = Vector2(30.0, 120.0)
			continue
		var node := resource_by_graph_name.get(child.name) as SkillUpgradeData
		if node == null:
			continue
		var row := int(rows_by_rank.get(node.rank, 0))
		child.position_offset = _automatic_position(node.rank, row)
		rows_by_rank[node.rank] = row + 1
	scroll_offset = Vector2.ZERO


func focus_subject(subject_id: StringName) -> void:
	var graph_name := graph_name_by_node_id.get(subject_id, StringName()) as StringName
	var graph_node := get_node_or_null(NodePath(str(graph_name))) as GraphNode
	if graph_node == null:
		return
	for child in get_children():
		if child is GraphNode:
			child.selected = child == graph_node
	scroll_offset = graph_node.position_offset - size * 0.35
	subject_selected.emit(resource_by_graph_name.get(graph_name))


func _add_root() -> void:
	var root := GraphNode.new()
	root.name = ROOT_NAME
	root.title = "RANG 1 — SORT DE BASE"
	root.custom_minimum_size = Vector2(238, 116)
	root.position_offset = Vector2(30.0, 120.0)
	if base_spell != null and base_spell.icon != null:
		var icon := TextureRect.new()
		icon.texture = base_spell.icon
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		root.add_child(icon)
	var name_label := Label.new()
	name_label.text = base_spell.spell_name if base_spell != null else "Sort non associé"
	name_label.add_theme_font_size_override("font_size", 16)
	root.add_child(name_label)
	var help := Label.new()
	help.text = "La racine est acquise dès le début.\nLes nœuds du rang 2 y sont reliés automatiquement."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 220
	help.add_theme_color_override("font_color", Color(0.72, 0.78, 0.84))
	root.add_child(help)
	root.set_slot(0, false, 0, Color.WHITE, true, 0, Color(0.35, 0.78, 1.0))
	add_child(root)
	resource_by_graph_name[ROOT_NAME] = base_spell


func _add_upgrade_node(
		node: SkillUpgradeData,
		required_xp: int,
		row: int
	) -> void:
	var graph_name := _graph_name(node.upgrade_id)
	var view := GraphNode.new()
	view.name = graph_name
	view.title = "RANG %d · %d XP" % [node.rank, required_xp]
	view.custom_minimum_size = Vector2(252, 138)
	var saved_position: Variant = _saved_positions.get(str(node.upgrade_id))
	view.position_offset = saved_position as Vector2 \
		if saved_position is Vector2 else _automatic_position(node.rank, row)
	if node.icon != null:
		var icon := TextureRect.new()
		icon.texture = node.icon
		icon.custom_minimum_size = Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		view.add_child(icon)
	var title := Label.new()
	title.text = node.display_name if not node.display_name.is_empty() else "Amélioration sans nom"
	title.add_theme_font_size_override("font_size", 15)
	title.clip_text = true
	view.add_child(title)
	var summary := Label.new()
	summary.text = SkillTreeEffectSummaryService.summarize_node(node)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size = Vector2(228, 48)
	summary.max_lines_visible = 3
	summary.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	view.add_child(summary)
	if node is SkillTreeNodeData and not node.excluded_node_ids.is_empty():
		var exclusion := Label.new()
		exclusion.text = "⛔ Exclut %d amélioration(s)" % node.excluded_node_ids.size()
		exclusion.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		view.add_child(exclusion)
	var node_errors := _messages_for(node.upgrade_id)
	if not node_errors.is_empty():
		var error_label := Label.new()
		error_label.text = "⚠ %d problème(s) — cliquez pour les détails" % node_errors.size()
		error_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.3))
		view.add_child(error_label)
	view.set_slot(
		0,
		true,
		0,
		Color(0.35, 0.78, 1.0),
		true,
		0,
		Color(0.35, 0.78, 1.0)
	)
	add_child(view)
	resource_by_graph_name[graph_name] = node
	graph_name_by_node_id[node.upgrade_id] = graph_name


func _add_connections() -> void:
	for node in _all_nodes():
		var child_name := graph_name_by_node_id.get(node.upgrade_id, &"") as StringName
		if child_name == &"":
			continue
		if node.rank == 2:
			connect_node(ROOT_NAME, 0, child_name, 0)
			continue
		if not node is SkillTreeNodeData:
			continue
		for prerequisite_id in node.prerequisite_node_ids:
			var parent_name := graph_name_by_node_id.get(prerequisite_id, &"") as StringName
			if parent_name != &"":
				connect_node(parent_name, 0, child_name, 0)


func _on_connection_request(
		from_node: StringName,
		_from_port: int,
		to_node: StringName,
		_to_port: int
	) -> void:
	if from_node == ROOT_NAME:
		return
	var parent := resource_by_graph_name.get(from_node) as SkillUpgradeData
	var child := resource_by_graph_name.get(to_node) as SkillTreeNodeData
	if parent != null and child != null:
		prerequisite_requested.emit(child, parent)


func _on_disconnection_request(
		from_node: StringName,
		_from_port: int,
		to_node: StringName,
		_to_port: int
	) -> void:
	if from_node == ROOT_NAME:
		return
	var parent := resource_by_graph_name.get(from_node) as SkillUpgradeData
	var child := resource_by_graph_name.get(to_node) as SkillTreeNodeData
	if parent != null and child != null:
		prerequisite_removal_requested.emit(child, parent.upgrade_id)


func _on_node_selected(node: Node) -> void:
	if node is GraphNode:
		subject_selected.emit(resource_by_graph_name.get(node.name))


func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	var resources: Array[SkillUpgradeData] = []
	for graph_name in nodes:
		var resource := resource_by_graph_name.get(graph_name) as SkillUpgradeData
		if resource != null:
			resources.append(resource)
	if not resources.is_empty():
		nodes_deletion_requested.emit(resources)


func _on_popup_request(at_position: Vector2) -> void:
	_popup_rank = _rank_from_graph_x(at_position.x)
	_popup.position = Vector2i(get_screen_position() + at_position)
	_popup.popup()


func _on_popup_action(id: int) -> void:
	if id == 1:
		node_creation_requested.emit(_popup_rank)
	elif id == 2:
		organize()
	elif id == 3:
		var selected := _selected_upgrade()
		if selected != null:
			node_duplication_requested.emit(selected)
	elif id == 4:
		branch_creation_requested.emit(_popup_rank)
	elif id == 5:
		var selected_nodes := _selected_upgrades()
		if not selected_nodes.is_empty():
			nodes_deletion_requested.emit(selected_nodes)


func _on_connection_to_empty(
		from_node: StringName,
		_from_port: int,
		_release_position: Vector2
	) -> void:
	var parent := resource_by_graph_name.get(from_node) as SkillUpgradeData
	if parent != null and parent.rank < _maximum_rank():
		child_creation_requested.emit(parent, parent.rank + 1)


func _rank_from_graph_x(screen_x: float) -> int:
	var graph_x := (screen_x + scroll_offset.x) / maxf(zoom, 0.01)
	return clampi(roundi(graph_x / COLUMN_WIDTH) + 1, 2, _maximum_rank())


func _automatic_position(rank: int, row: int) -> Vector2:
	return Vector2(30.0 + float(rank - 1) * COLUMN_WIDTH, 30.0 + row * ROW_HEIGHT)


func _messages_for(subject_id: StringName) -> Array[SkillTreeValidationMessage]:
	return messages.filter(func(message: SkillTreeValidationMessage) -> bool:
		return message.subject_id == subject_id
	)


func _all_nodes() -> Array[SkillUpgradeData]:
	var result: Array[SkillUpgradeData] = []
	for rank_data in _sorted_ranks():
		for node in rank_data.choices:
			if node != null:
				result.append(node)
	return result


func _sorted_ranks() -> Array[DisciplineRankData]:
	var result: Array[DisciplineRankData] = []
	if discipline != null:
		for rank_data in discipline.ranks:
			if rank_data != null:
				result.append(rank_data)
	result.sort_custom(func(a: DisciplineRankData, b: DisciplineRankData) -> bool:
		return a.rank < b.rank
	)
	return result


func _maximum_rank() -> int:
	var result := 2
	for rank_data in _sorted_ranks():
		result = maxi(result, rank_data.rank)
	return result


func _graph_name(node_id: StringName) -> StringName:
	return StringName("upgrade_%s" % str(node_id).sha256_text().substr(0, 16))


func _apply_scroll(value: Vector2) -> void:
	scroll_offset = value


func _clear_graph() -> void:
	clear_connections()
	resource_by_graph_name.clear()
	graph_name_by_node_id.clear()
	for child in get_children():
		if child is GraphNode:
			remove_child(child)
			child.queue_free()


func _selected_upgrade() -> SkillUpgradeData:
	var nodes := _selected_upgrades()
	return nodes[0] if not nodes.is_empty() else null


func _selected_upgrades() -> Array[SkillUpgradeData]:
	var result: Array[SkillUpgradeData] = []
	for child in get_children():
		if child is GraphNode and child.selected:
			var resource := resource_by_graph_name.get(child.name) as SkillUpgradeData
			if resource != null:
				result.append(resource)
	return result


func _copy_selected_node() -> void:
	var selected := _selected_upgrade()
	if selected != null:
		_copied_node_id = selected.upgrade_id


func _paste_copied_node() -> void:
	if _copied_node_id == &"":
		return
	var copied := resource_by_graph_name.get(
		graph_name_by_node_id.get(_copied_node_id, &"")
	) as SkillUpgradeData
	if copied != null:
		node_duplication_requested.emit(copied)


func _duplicate_selected_node() -> void:
	var selected := _selected_upgrade()
	if selected != null:
		node_duplication_requested.emit(selected)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or not key.ctrl_pressed:
		return
	var selected := _selected_upgrade()
	if key.keycode == KEY_C and selected != null:
		_copy_selected_node()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_V and _copied_node_id != &"":
		_paste_copied_node()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_D and selected != null:
		_duplicate_selected_node()
		get_viewport().set_input_as_handled()
