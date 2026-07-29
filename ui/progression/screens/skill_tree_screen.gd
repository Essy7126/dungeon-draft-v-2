class_name SkillTreeScreen
extends Control

signal screen_closed

@onready var _title_label: Label = %TitleLabel
@onready var _tabs: HBoxContainer = %DisciplineTabs
@onready var _graph: SkillTreeGraphView = %SkillTreeGraphView
@onready var _detail_panel: SkillTreeNodeDetailPanel = %NodeDetailPanel
@onready var _footer_label: Label = %FooterLabel
@onready var _close_button: Button = %CloseButton

var progression_controller = null
var character_id: StringName = &""
var current_discipline_id: StringName = &"archer"
var _preview_character_state: CharacterRunState = null
var _tab_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close_button.pressed.connect(close_screen)
	_graph.node_inspected.connect(_on_node_inspected)
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
	show()
	move_to_front()
	refresh_from_state()
	_close_button.grab_focus.call_deferred()
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
	show()
	move_to_front()
	refresh_from_state()
	_close_button.grab_focus.call_deferred()
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


func close_screen() -> void:
	if not visible:
		return
	hide()
	screen_closed.emit()


func get_graph() -> SkillTreeGraphView:
	return _graph


func get_detail_panel() -> SkillTreeNodeDetailPanel:
	return _detail_panel


func get_tab_count() -> int:
	return _tab_buttons.size()


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
		var button := Button.new()
		button.text = "%s · R%d" % [
			discipline.display_name,
			progress.rank if progress != null else 1,
		]
		button.toggle_mode = true
		button.button_pressed = (
			discipline.discipline_id == current_discipline_id
		)
		button.pressed.connect(
			_show_discipline.bind(discipline.discipline_id)
		)
		_tabs.add_child(button)
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
		button.button_pressed = button.text.begins_with(
			discipline.display_name
		)
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
	_footer_label.text = "%s — Rang %d — %s" % [
		discipline.display_name,
		progress.rank,
		(
			"%d/%d XP" % [progress.xp, next_rank.required_total_xp]
			if next_rank != null
			else "%d XP — rang maximum" % progress.xp
		),
	]
	var first_view := _graph.get_first_node_view()
	if first_view != null:
		_on_node_inspected(first_view)
	else:
		_detail_panel.set_empty()


func _on_node_inspected(view: SkillTreeNodeView) -> void:
	if view == null:
		return
	var character_state := _get_character_state()
	var discipline := view.discipline_data
	if character_state == null or discipline == null:
		return
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
			view.visual_presentation
		)
		return
	var node := view.node_data
	_detail_panel.configure_node(
		discipline,
		node,
		view.visual_presentation,
		_node_name_map(discipline),
		_spell_display_name(character_state, node.target_spell_id)
	)


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
		return str(spell_id)
	for spell in character_state.unit.spells:
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell.spell_name
	return str(spell_id)


func _node_name_map(discipline: DisciplineData) -> Dictionary:
	var result := {}
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		for node in rank_data.choices:
			if node != null:
				result[node.upgrade_id] = node.display_name
	return result
