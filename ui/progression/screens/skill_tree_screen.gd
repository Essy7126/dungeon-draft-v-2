class_name SkillTreeScreen
extends Control

signal screen_closed

const TAB_SCENE := preload(
	"res://ui/progression/components/skill_tree_discipline_tab.tscn"
)

@export var skin: SkillTreeSkinData = null
@export var visual_map: SkillTreeVisualMapData = null

@onready var _outer_margin: MarginContainer = %OuterMargin
@onready var _main_frame: NinePatchRect = %MainFrame
@onready var _title_label: Label = %TitleLabel
@onready var _consultative_label: Label = %ConsultativeLabel
@onready var _tabs: HBoxContainer = %DisciplineTabs
@onready var _graph_scroll: ScrollContainer = %GraphScroll
@onready var _graph: SkillTreeGraphView = %SkillTreeGraphView
@onready var _detail_panel: SkillTreeNodeDetailPanel = %NodeDetailPanel
@onready var _footer_label: Label = %FooterLabel
@onready var _close_button: Button = %CloseButton

var progression_controller = null
var character_id: StringName = &""
var current_discipline_id: StringName = &"archer"
var _preview_character_state: CharacterRunState = null
var _tab_buttons: Array[SkillTreeDisciplineTab] = []
var _previous_focus_owner: Control = null
var _last_inspected_by_discipline: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main_frame.texture = skin.main_panel_texture if skin != null else null
	_graph.skin = skin
	_graph.visual_map = visual_map
	_detail_panel.skin = skin
	_close_button.pressed.connect(close_screen)
	_graph.node_inspected.connect(_on_node_inspected)
	resized.connect(_on_resized)
	hide()


func open_for_character(
		wanted_character_id: StringName,
		controller = null,
		discipline_id: StringName = &"archer"
	) -> bool:
	_preview_character_state = null
	character_id = wanted_character_id
	current_discipline_id = discipline_id
	progression_controller = controller if controller != null else GameManager
	if _get_character_state() == null:
		hide()
		return false
	_capture_previous_focus()
	show()
	move_to_front()
	refresh_from_state()
	_focus_last_or_first.call_deferred()
	return true


func open_for_state(
		character_state: CharacterRunState,
		discipline_id: StringName = &"archer"
	) -> bool:
	_preview_character_state = character_state
	character_id = (
		character_state.character_id if character_state != null else &""
	)
	current_discipline_id = discipline_id
	if character_state == null:
		hide()
		return false
	_capture_previous_focus()
	show()
	move_to_front()
	refresh_from_state()
	_focus_last_or_first.call_deferred()
	return true


func refresh_from_state() -> void:
	var character_state := _get_character_state()
	if character_state == null:
		hide()
		return
	_title_label.text = "%s — PROGRESSION" % (
		character_state.unit.unit_name.to_upper()
		if character_state.unit != null
		else str(character_state.character_id).to_upper()
	)
	_build_tabs(character_state)
	_show_discipline(current_discipline_id)
	_apply_responsive_layout(size)


func close_screen() -> void:
	if not visible:
		return
	hide()
	screen_closed.emit()
	if is_instance_valid(_previous_focus_owner):
		_previous_focus_owner.grab_focus.call_deferred()
	_previous_focus_owner = null


func get_graph() -> SkillTreeGraphView:
	return _graph


func get_detail_panel() -> SkillTreeNodeDetailPanel:
	return _detail_panel


func get_tab_count() -> int:
	return _tab_buttons.size()


func get_tab_buttons() -> Array[SkillTreeDisciplineTab]:
	return _tab_buttons.duplicate()


func get_close_button() -> Button:
	return _close_button


func get_last_inspected_id(
		discipline_id: StringName = current_discipline_id
	) -> StringName:
	return StringName(_last_inspected_by_discipline.get(
		discipline_id,
		&""
	))


func get_layout_snapshot() -> Dictionary:
	return {
		"screen": get_rect(),
		"outer": _outer_margin.get_rect(),
		"screen_global": get_global_rect(),
		"outer_global": _outer_margin.get_global_rect(),
		"tabs_global": _tabs.get_global_rect(),
		"graph_scroll_global": _graph_scroll.get_global_rect(),
		"detail_global": _detail_panel.get_global_rect(),
		"close_global": _close_button.get_global_rect(),
		"footer_global": _footer_label.get_global_rect(),
		"consultative_visible": _consultative_label.visible,
		"detail_minimum_width": _detail_panel.custom_minimum_size.x,
	}


func apply_viewport_size_for_test(viewport_size: Vector2) -> void:
	size = viewport_size
	_apply_responsive_layout(viewport_size)


func is_consultative() -> bool:
	return true


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_screen()


func _build_tabs(character_state: CharacterRunState) -> void:
	for button in _tab_buttons:
		if button.get_parent() == _tabs:
			_tabs.remove_child(button)
		button.queue_free()
	_tab_buttons.clear()
	for discipline in character_state.get_disciplines():
		if discipline == null:
			continue
		var progress := character_state.get_discipline_progress(
			discipline.discipline_id
		)
		var button := TAB_SCENE.instantiate() as SkillTreeDisciplineTab
		_tabs.add_child(button)
		button.configure(
			discipline,
			progress,
			skin,
			discipline.discipline_id == current_discipline_id
		)
		button.pressed.connect(
			_show_discipline.bind(discipline.discipline_id)
		)
		_tab_buttons.append(button)


func _show_discipline(discipline_id: StringName) -> void:
	var character_state := _get_character_state()
	if character_state == null:
		return
	var discipline := _find_discipline(character_state, discipline_id)
	var progress := character_state.get_discipline_progress(discipline_id)
	if discipline == null or progress == null:
		return
	current_discipline_id = discipline_id
	for button in _tab_buttons:
		button.set_selected(button.discipline_id == discipline_id)
	var base_spell := _base_spell_for_discipline(
		character_state,
		discipline
	)
	_graph.rebuild(
		discipline,
		progress,
		base_spell.spell_name if base_spell != null else discipline.display_name
	)
	var next_rank := progress.get_next_rank_data()
	_footer_label.text = "%s — Rang %d — %s%s" % [
		discipline.display_name,
		progress.rank,
		(
			"%d / %d XP" % [progress.xp, next_rank.required_total_xp]
			if next_rank != null
			else "%d XP — RANG MAXIMUM" % progress.xp
		),
		(
			" — CHOIX EN ATTENTE"
			if not progress.get_pending_rank_choices().is_empty()
			else ""
		),
	]
	var wanted_id := StringName(
		_last_inspected_by_discipline.get(discipline_id, &"")
	)
	var first_view := (
		_graph.get_node_view(wanted_id)
		if wanted_id != &""
		else _graph.get_first_node_view()
	)
	if first_view != null:
		_on_node_inspected(first_view)
	else:
		_detail_panel.set_empty()
	_configure_focus_navigation()
	if visible:
		_focus_last_or_first.call_deferred()


func _on_node_inspected(view: SkillTreeNodeView) -> void:
	if view == null:
		return
	var character_state := _get_character_state()
	var discipline := view.discipline_data
	if character_state == null or discipline == null:
		return
	_last_inspected_by_discipline[discipline.discipline_id] = (
		view.presentation_id
	)
	if view.is_base_rank:
		var base_spell := _base_spell_for_discipline(
			character_state,
			discipline
		)
		_detail_panel.configure_base(
			discipline,
			base_spell.spell_name if base_spell != null else discipline.display_name,
			(
				base_spell.description
				if base_spell != null
				else discipline.description
			),
			view.visual_presentation,
			view.node_visual
		)
		return
	var node := view.node_data
	_detail_panel.configure_node(
		discipline,
		node,
		view.visual_presentation,
		_node_name_map(discipline),
		_spell_display_name(character_state, node.target_spell_id),
		view.node_visual
	)


func _configure_focus_navigation() -> void:
	if _tab_buttons.is_empty():
		return
	for index in range(_tab_buttons.size()):
		var button := _tab_buttons[index]
		if index > 0:
			button.focus_neighbor_left = button.get_path_to(
				_tab_buttons[index - 1]
			)
		if index + 1 < _tab_buttons.size():
			button.focus_neighbor_right = button.get_path_to(
				_tab_buttons[index + 1]
			)
	var nodes := _graph.get_node_views_in_focus_order()
	if not nodes.is_empty():
		for button in _tab_buttons:
			button.focus_neighbor_bottom = button.get_path_to(nodes[0])
		for node in nodes:
			if node.focus_neighbor_top.is_empty():
				var active_tab := _active_tab()
				if active_tab != null:
					node.focus_neighbor_top = node.get_path_to(active_tab)
			if node.focus_neighbor_right.is_empty():
				node.focus_neighbor_right = node.get_path_to(_close_button)
	_close_button.focus_neighbor_left = _close_button.get_path_to(
		_tab_buttons[_tab_buttons.size() - 1]
	)
	if not nodes.is_empty():
		_close_button.focus_neighbor_bottom = _close_button.get_path_to(
			nodes[nodes.size() - 1]
		)


func _focus_last_or_first() -> void:
	if not visible:
		return
	var wanted_id := get_last_inspected_id()
	if wanted_id != &"" and _graph.focus_node_by_id(wanted_id):
		return
	var first := _graph.get_first_node_view()
	if first != null:
		first.grab_focus()
	else:
		_close_button.grab_focus()


func _capture_previous_focus() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	_previous_focus_owner = owner as Control


func _active_tab() -> SkillTreeDisciplineTab:
	for button in _tab_buttons:
		if button.discipline_id == current_discipline_id:
			return button
	return null


func _on_resized() -> void:
	if is_node_ready():
		_apply_responsive_layout(size)


func _apply_responsive_layout(viewport_size: Vector2) -> void:
	var compact := viewport_size.x <= 1320.0 or viewport_size.y <= 760.0
	var medium := viewport_size.x <= 1650.0 or viewport_size.y <= 940.0
	var margin := 10.0 if compact else 18.0 if medium else 28.0
	_outer_margin.offset_left = margin
	_outer_margin.offset_top = margin
	_outer_margin.offset_right = -margin
	_outer_margin.offset_bottom = -margin
	_detail_panel.custom_minimum_size.x = (
		318.0 if compact else 352.0 if medium else 400.0
	)
	_title_label.add_theme_font_size_override(
		"font_size",
		18 if compact else 21 if medium else 24
	)
	_consultative_label.visible = viewport_size.x >= 1460.0


func _get_character_state() -> CharacterRunState:
	if _preview_character_state != null:
		return _preview_character_state
	if progression_controller == null \
			or not progression_controller.has_method("get_character_state"):
		return null
	return progression_controller.get_character_state(
		character_id
	) as CharacterRunState


func _find_discipline(
		character_state: CharacterRunState,
		discipline_id: StringName
	) -> DisciplineData:
	for discipline in character_state.get_disciplines():
		if discipline != null and discipline.discipline_id == discipline_id:
			return discipline
	return null


func _base_spell_for_discipline(
		character_state: CharacterRunState,
		discipline: DisciplineData
	) -> Spell:
	if character_state == null \
			or character_state.unit == null \
			or discipline == null:
		return null
	var discipline_index := character_state.disciplines.find(discipline)
	if discipline_index < 0 \
			or discipline_index >= character_state.unit.spells.size():
		return null
	return character_state.unit.spells[discipline_index] as Spell


func _spell_display_name(
		character_state: CharacterRunState,
		spell_id: StringName
	) -> String:
	if character_state == null or character_state.unit == null:
		return "Sort de la discipline"
	for spell in character_state.unit.spells:
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell.spell_name
	return "Sort de la discipline"


func _node_name_map(discipline: DisciplineData) -> Dictionary:
	var result := {}
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		for node in rank_data.choices:
			if node != null:
				result[node.upgrade_id] = node.display_name
	return result
