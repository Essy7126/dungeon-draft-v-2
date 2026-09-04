class_name SkillTreeScreen
extends Control

signal screen_closed
signal evolution_choice_resolved(request_id, upgrade_id)
signal evolution_choice_rejected(request_id, upgrade_id, reason)

const TAB_SCENE := preload(
	"res://ui/progression/components/skill_tree_discipline_tab.tscn"
)

@export var skin: SkillTreeSkinData = null
@export var visual_map: SkillTreeVisualMapData = null

@onready var _outer_margin: MarginContainer = %OuterMargin
@onready var _main_frame: NinePatchRect = %MainFrame
@onready var _frame_margin: MarginContainer = %FrameMargin
@onready var _main: VBoxContainer = %Main
@onready var _character_header: PanelContainer = %CharacterHeader
@onready var _header_accent: Panel = %HeaderAccent
@onready var _header_portrait: RecraftPortraitView = %HeaderPortrait
@onready var _identity_badge: TextureRect = %IdentityBadge
@onready var _title_label: Label = %TitleLabel
@onready var _discipline_summary_label: Label = %DisciplineSummaryLabel
@onready var _header_summary_label: Label = %HeaderSummaryLabel
@onready var _consultative_label: Label = %ConsultativeLabel
@onready var _branch_navigation: PanelContainer = %BranchNavigation
@onready var _branch_title_label: Label = %BranchTitleLabel
@onready var _tabs_scroll: ScrollContainer = %TabsScroll
@onready var _tabs: VBoxContainer = %DisciplineTabs
@onready var _content_split: HBoxContainer = %ContentSplit
@onready var _canvas_surface: PanelContainer = %CanvasSurface
@onready var _canvas_title_label: Label = %CanvasTitleLabel
@onready var _canvas_hint_label: Label = %CanvasHintLabel
@onready var _center_graph_button: Button = %CenterGraphButton
@onready var _graph_scroll: ScrollContainer = %GraphScroll
@onready var _graph: SkillTreeGraphView = %SkillTreeGraphView
@onready var _empty_state: CenterContainer = %EmptyState
@onready var _empty_state_label: Label = %EmptyStateLabel
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
var _layout_profile: StringName = &"large"
var _active_theme: CharacterHUDThemeData = null
var _pan_active := false
var _pan_mouse_origin := Vector2.ZERO
var _pan_scroll_origin := Vector2.ZERO
var _evolution_mode := false
var _evolution_rank := 0
var _evolution_request_id: StringName = &""
var _evolution_source_spell_id: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PremiumUI.apply(self)
	_main_frame.texture = skin.main_panel_texture if skin != null else null
	_graph.skin = skin
	_graph.visual_map = visual_map
	_detail_panel.skin = skin
	_close_button.pressed.connect(close_screen)
	_detail_panel.get_action_button().pressed.connect(
		_on_evolution_action_pressed
	)
	_center_graph_button.pressed.connect(center_on_inspected_node)
	_graph.node_inspected.connect(_on_node_inspected)
	_graph_scroll.gui_input.connect(_on_graph_scroll_gui_input)
	resized.connect(_on_resized)
	_graph_scroll.resized.connect(_on_graph_scroll_resized)
	hide()


func open_for_character(
		wanted_character_id: StringName,
		controller = null,
		discipline_id: StringName = &"archer"
	) -> bool:
	_reset_evolution_mode()
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
	_reset_evolution_mode()
	_preview_character_state = character_state
	character_id = character_state.character_id if character_state != null else &""
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


func open_for_evolution(
		request: EvolutionRequest,
		controller = null
	) -> bool:
	if request == null or not request.is_valid():
		return false
	_preview_character_state = null
	character_id = request.character_id
	current_discipline_id = request.discipline_id
	progression_controller = controller if controller != null else GameManager
	var character_state := _get_character_state()
	if character_state == null:
		return false
	var progress := character_state.get_discipline_progress(
		request.source_spell_id if request.source_spell_id != &"" \
		else request.discipline_id
	)
	if progress == null \
		or not progress.get_pending_rank_choices().has(request.pending_rank):
		return false
	current_discipline_id = progress.get_skill_tree().discipline_id
	_evolution_mode = true
	_evolution_rank = request.pending_rank
	_evolution_request_id = request.request_id
	_evolution_source_spell_id = request.source_spell_id
	_capture_previous_focus()
	show()
	move_to_front()
	refresh_from_state()
	_apply_evolution_chrome()
	_focus_evolution_choice.call_deferred()
	return true


func refresh_from_state() -> void:
	var character_state := _get_character_state()
	if character_state == null:
		hide()
		return
	_resolve_current_discipline(character_state)
	_apply_character_identity(character_state)
	_build_tabs(character_state)
	if character_state.get_disciplines().is_empty():
		_show_undefined_progression(character_state)
	else:
		_show_discipline(current_discipline_id)
	_apply_responsive_layout(size)


func close_screen() -> void:
	if not visible:
		return
	if _evolution_mode:
		_footer_label.text = "CHOIX OBLIGATOIRE · sélectionnez une évolution disponible"
		return
	_force_close_screen()


func close_for_run_cleanup() -> void:
	_reset_evolution_mode()
	_force_close_screen()


func _force_close_screen() -> void:
	if not visible:
		return
	_pan_active = false
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


func get_active_theme() -> CharacterHUDThemeData:
	return _active_theme


func is_progression_defined() -> bool:
	var state := _get_character_state()
	return state != null and not state.get_disciplines().is_empty()


func get_last_inspected_id(
		discipline_id: StringName = current_discipline_id
	) -> StringName:
	return StringName(_last_inspected_by_discipline.get(discipline_id, &""))


func get_layout_snapshot() -> Dictionary:
	return {
		"screen": get_rect(),
		"outer": _outer_margin.get_rect(),
		"screen_global": get_global_rect(),
		"outer_global": _outer_margin.get_global_rect(),
		"header_global": _character_header.get_global_rect(),
		"branch_global": _branch_navigation.get_global_rect(),
		"tabs_global": _tabs.get_global_rect(),
		"tabs_scroll_global": _tabs_scroll.get_global_rect(),
		"canvas_global": _canvas_surface.get_global_rect(),
		"graph_scroll_global": _graph_scroll.get_global_rect(),
		"graph_content_global": _graph.get_global_rect(),
		"graph_layout": _graph.get_layout_snapshot(),
		"detail_global": _detail_panel.get_global_rect(),
		"close_global": _close_button.get_global_rect(),
		"footer_global": _footer_label.get_global_rect(),
		"consultative_visible": _consultative_label.visible,
		"detail_minimum_width": _detail_panel.custom_minimum_size.x,
		"branch_minimum_width": _branch_navigation.custom_minimum_size.x,
		"layout_profile": _layout_profile,
		"footer_text": _footer_label.text,
		"footer_visible": _footer_label.visible,
		"empty_state_visible": _empty_state.visible,
	}


func apply_viewport_size_for_test(viewport_size: Vector2) -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = viewport_size
	_apply_responsive_layout(viewport_size)


func is_consultative() -> bool:
	return not _evolution_mode


func is_evolution_choice_mode() -> bool:
	return _evolution_mode


func get_evolution_rank() -> int:
	return _evolution_rank


func get_evolution_request_id() -> StringName:
	return _evolution_request_id


func get_available_evolution_node_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if not _evolution_mode:
		return result
	for view in _graph.get_node_views_in_focus_order():
		if _is_available_evolution_view(view):
			result.append(view.presentation_id)
	return result


func inspect_evolution_node(node_id: StringName) -> bool:
	if not _evolution_mode:
		return false
	var view := _graph.get_node_view(node_id)
	if not _is_available_evolution_view(view):
		_detail_panel.show_evolution_rejection(
			"Ce nœud ne peut pas résoudre le rang %d en attente." % _evolution_rank
		)
		evolution_choice_rejected.emit(
			_evolution_request_id,
			node_id,
			"INVALID_EVOLUTION_NODE",
		)
		return false
	_graph.inspect_node_by_id(node_id)
	_graph.focus_node_by_id(node_id)
	return true


func confirm_evolution_choice(node_id: StringName = &"") -> bool:
	if not _evolution_mode:
		return false
	var wanted_id := node_id
	if wanted_id == &"":
		wanted_id = _detail_panel.current_presentation_id
	var view := _graph.get_node_view(wanted_id)
	if not _is_available_evolution_view(view):
		return inspect_evolution_node(wanted_id)
	if progression_controller == null \
			or not progression_controller.has_method("choose_progression_upgrade"):
		_reject_evolution_choice(wanted_id, "Contrôleur de progression indisponible.")
		return false
	var accepted: bool = progression_controller.choose_progression_upgrade(
		character_id,
		_evolution_source_spell_id \
		if _evolution_source_spell_id != &"" else current_discipline_id,
		_evolution_rank,
		wanted_id
	)
	if not accepted:
		_reject_evolution_choice(
			wanted_id,
			"Le resolver a refusé ce choix : prérequis ou exclusion invalide."
		)
		return false
	var completed_request_id := _evolution_request_id
	_reset_evolution_mode()
	_force_close_screen()
	evolution_choice_resolved.emit(completed_request_id, wanted_id)
	return true


func get_footer_text() -> String:
	return _footer_label.text


func center_on_inspected_node() -> void:
	var wanted_id := get_last_inspected_id()
	var view := _graph.get_node_view(wanted_id)
	if view == null:
		view = _graph.get_first_node_view()
	if view == null:
		_graph_scroll.scroll_horizontal = 0
		_graph_scroll.scroll_vertical = 0
		return
	var target := view.position + view.size * 0.5
	_graph_scroll.scroll_horizontal = maxi(
		int(target.x - _graph_scroll.size.x * 0.5), 0
	)
	_graph_scroll.scroll_vertical = maxi(
		int(target.y - _graph_scroll.size.y * 0.5), 0
	)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var closes_with_shortcut: bool = (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_K
	)
	if event.is_action_pressed("ui_cancel") or closes_with_shortcut:
		get_viewport().set_input_as_handled()
		if _evolution_mode:
			_footer_label.text = (
				"CHOIX OBLIGATOIRE · le combat reprendra après confirmation"
			)
		else:
			close_screen()


func _build_tabs(character_state: CharacterRunState) -> void:
	for button in _tab_buttons:
		if button.get_parent() == _tabs:
			_tabs.remove_child(button)
		button.queue_free()
	_tab_buttons.clear()
	var disciplines := character_state.get_disciplines()
	for discipline_index in range(disciplines.size()):
		var discipline := disciplines[discipline_index]
		if discipline == null:
			continue
		if _evolution_mode and discipline.discipline_id != current_discipline_id:
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
			discipline.discipline_id == current_discipline_id,
			character_state.character_id,
			_branch_icon(character_state, discipline_index, discipline)
		)
		button.apply_layout_profile(_layout_profile)
		button.disabled = _evolution_mode
		if not _evolution_mode:
			button.pressed.connect(_show_discipline.bind(discipline.discipline_id))
		_tab_buttons.append(button)


func _show_discipline(discipline_id: StringName) -> void:
	if _evolution_mode and discipline_id != current_discipline_id:
		return
	var character_state := _get_character_state()
	if character_state == null:
		return
	var discipline := _find_discipline(character_state, discipline_id)
	var progress := character_state.get_discipline_progress(discipline_id)
	if discipline == null or progress == null:
		return
	current_discipline_id = discipline_id
	_empty_state.hide()
	_graph_scroll.show()
	_canvas_title_label.text = "%s · CHEMIN DE PROGRESSION" % discipline.display_name.to_upper()
	for button in _tab_buttons:
		button.set_selected(button.discipline_id == discipline_id)
	var base_spell := _base_spell_for_discipline(character_state, discipline)
	var base_icon := _base_icon_for_graph(character_state, base_spell)
	_graph.rebuild(
		discipline,
		progress,
		base_spell.spell_name if base_spell != null else discipline.display_name,
		base_icon,
		character_state.character_id
	)
	_queue_graph_layout()
	var next_rank := progress.get_next_rank_data()
	_footer_label.text = "%s · Rang %d · %s%s" % [
		discipline.display_name,
		progress.rank,
		(
			"%d / %d XP · prochain rang %d" % [
				progress.xp,
				next_rank.required_total_xp,
				next_rank.rank,
			]
			if next_rank != null
			else _maximum_progress_label(discipline, progress)
		),
		(
			" · CHOIX EN ATTENTE"
			if not progress.get_pending_rank_choices().is_empty()
			else ""
		),
	]
	if _evolution_mode:
		_footer_label.text = "%s · RANG %d · CHOIX OBLIGATOIRE" % [
			discipline.display_name.to_upper(),
			_evolution_rank,
		]
	_update_header_branch_summary(character_state, discipline)
	var wanted_id := StringName(
		_last_inspected_by_discipline.get(discipline_id, &"")
	)
	var first_view := (
		_graph.get_node_view(wanted_id)
		if wanted_id != &""
		else _graph.get_first_node_view()
	)
	if first_view != null:
		_graph.inspect_node_by_id(first_view.presentation_id)
	else:
		_detail_panel.set_empty()
	_configure_focus_navigation()
	if visible:
		_focus_last_or_first.call_deferred()


func _show_undefined_progression(character_state: CharacterRunState) -> void:
	current_discipline_id = &""
	_empty_state.show()
	_graph_scroll.hide()
	_graph.rebuild(null, null, "")
	_canvas_title_label.text = "PROGRESSION"
	var character_name := (
		character_state.unit.unit_name
		if character_state.unit != null
		else str(character_state.character_id)
	)
	_empty_state_label.text = (
		"PROGRESSION NON DÉFINIE\n\n"
		+ "Aucune branche n’existe dans les données de %s.\n"
		% character_name
		+ "Aucun rang ni node fictif n’est affiché."
	)
	_detail_panel.set_progression_undefined(character_name)
	_discipline_summary_label.text = "Aucune branche définie"
	_header_summary_label.text = "Données de progression absentes"
	_footer_label.text = "%s · PROGRESSION NON DÉFINIE" % character_name
	_configure_focus_navigation()


func _on_node_inspected(view: SkillTreeNodeView) -> void:
	if view == null:
		return
	var character_state := _get_character_state()
	var discipline := view.discipline_data
	if character_state == null or discipline == null:
		return
	_last_inspected_by_discipline[discipline.discipline_id] = view.presentation_id
	if not view.is_content_revealed():
		_detail_panel.configure_locked(discipline, view.get_rank(), character_id)
		return
	if view.is_base_rank:
		var base_spell := _base_spell_for_discipline(character_state, discipline)
		_detail_panel.configure_base(
			discipline,
			base_spell.spell_name if base_spell != null else discipline.display_name,
			base_spell.description if base_spell != null else discipline.description,
			view.visual_presentation,
			view.node_visual,
			_base_icon_for_graph(character_state, base_spell)
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
	if _evolution_mode:
		var available := _is_available_evolution_view(view)
		_detail_panel.configure_evolution_action(
			available,
			"CHOISIR CETTE ÉVOLUTION" if available else "CHOIX INDISPONIBLE",
			"" if available else str(view.visual_presentation.get(
				"reason",
				"Ce nœud ne peut pas résoudre le rang en attente."
			)),
		)


func _configure_focus_navigation() -> void:
	for index in range(_tab_buttons.size()):
		var button := _tab_buttons[index]
		if index > 0:
			button.focus_neighbor_top = button.get_path_to(_tab_buttons[index - 1])
		else:
			button.focus_neighbor_top = button.get_path_to(_close_button)
		if index + 1 < _tab_buttons.size():
			button.focus_neighbor_bottom = button.get_path_to(_tab_buttons[index + 1])
		else:
			button.focus_neighbor_bottom = button.get_path_to(_center_graph_button)
	var nodes := _graph.get_node_views_in_focus_order()
	if not nodes.is_empty():
		for button in _tab_buttons:
			button.focus_neighbor_right = button.get_path_to(nodes[0])
		for node in nodes:
			if node.focus_neighbor_left.is_empty():
				var active_tab := _active_tab()
				if active_tab != null:
					node.focus_neighbor_left = node.get_path_to(active_tab)
	_close_button.focus_neighbor_bottom = _close_button.get_path_to(
		_tab_buttons[0] if not _tab_buttons.is_empty() else _center_graph_button
	)
	_close_button.focus_neighbor_left = _close_button.get_path_to(
		_center_graph_button
	)
	_center_graph_button.focus_neighbor_top = _center_graph_button.get_path_to(_close_button)
	if not _tab_buttons.is_empty():
		_center_graph_button.focus_neighbor_left = _center_graph_button.get_path_to(
			_tab_buttons[_tab_buttons.size() - 1]
		)
	if not nodes.is_empty():
		_center_graph_button.focus_neighbor_bottom = _center_graph_button.get_path_to(
			nodes[0]
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
	elif not _tab_buttons.is_empty():
		_tab_buttons[0].grab_focus()
	else:
		_close_button.grab_focus()


func _focus_evolution_choice() -> void:
	if not visible or not _evolution_mode:
		return
	for view in _graph.get_node_views_in_focus_order():
		if not _is_available_evolution_view(view):
			continue
		_graph.inspect_node_by_id(view.presentation_id)
		_graph.focus_node_by_id(view.presentation_id)
		center_on_inspected_node.call_deferred()
		return
	_footer_label.text = "ERREUR · aucun choix valide pour le rang %d" % _evolution_rank


func _is_available_evolution_view(view: SkillTreeNodeView) -> bool:
	if view == null or view.is_base_rank or view.is_rank_gate():
		return false
	return view.get_rank() == _evolution_rank \
		and int(view.visual_presentation.get("state", -1)) \
		== SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE


func _on_evolution_action_pressed() -> void:
	if _evolution_mode:
		confirm_evolution_choice()


func _reject_evolution_choice(node_id: StringName, reason: String) -> void:
	_detail_panel.show_evolution_rejection(reason)
	evolution_choice_rejected.emit(
		_evolution_request_id,
		node_id,
		reason,
	)


func _apply_evolution_chrome() -> void:
	if not _evolution_mode:
		return
	_consultative_label.text = "ÉVOLUTION DISPONIBLE\nChoix requis pour reprendre le combat"
	_consultative_label.show()
	_branch_title_label.text = "DISCIPLINE CONCERNÉE"
	_close_button.text = "CHOIX REQUIS"
	_close_button.disabled = true
	_canvas_title_label.text = "%s · RANG %d À RÉSOUDRE" % [
		_canvas_title_label.text.get_slice(" · ", 0),
		_evolution_rank,
	]


func _reset_evolution_mode() -> void:
	_evolution_mode = false
	_evolution_rank = 0
	_evolution_request_id = &""
	_evolution_source_spell_id = &""
	if is_instance_valid(_close_button):
		_close_button.text = "FERMER"
		_close_button.disabled = false
	if is_instance_valid(_consultative_label):
		_consultative_label.text = "CONSULTATION\nProgression de la run"
	if is_instance_valid(_branch_title_label):
		_branch_title_label.text = "BRANCHES"


func _capture_previous_focus() -> void:
	_previous_focus_owner = get_viewport().gui_get_focus_owner() as Control


func _active_tab() -> SkillTreeDisciplineTab:
	for button in _tab_buttons:
		if button.discipline_id == current_discipline_id:
			return button
	return null


func _on_resized() -> void:
	if is_node_ready():
		_apply_responsive_layout(size)


func _on_graph_scroll_resized() -> void:
	if is_node_ready():
		_queue_graph_layout()


func _apply_responsive_layout(viewport_size: Vector2) -> void:
	var compact := viewport_size.x <= 1320.0 or viewport_size.y <= 760.0
	var medium := viewport_size.x <= 1650.0 or viewport_size.y <= 940.0
	_layout_profile = &"compact" if compact else &"medium" if medium else &"large"
	var presentation_scale := (
		clampf(
			minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0),
			1.0,
			1.18
		)
		if not medium
		else 1.0
	)
	var screen_margin := 8.0 if compact else 12.0 if medium else 18.0
	var wanted_size := Vector2(
		minf(viewport_size.x - screen_margin * 2.0, 1700.0 * presentation_scale),
		minf(viewport_size.y - screen_margin * 2.0, 940.0 * presentation_scale)
	)
	_outer_margin.set_anchors_preset(Control.PRESET_CENTER)
	_outer_margin.offset_left = -wanted_size.x * 0.5
	_outer_margin.offset_top = -wanted_size.y * 0.5
	_outer_margin.offset_right = wanted_size.x * 0.5
	_outer_margin.offset_bottom = wanted_size.y * 0.5
	var frame_margin := 10 if compact else 16 if medium else roundi(22.0 * presentation_scale)
	_frame_margin.add_theme_constant_override("margin_left", frame_margin)
	_frame_margin.add_theme_constant_override("margin_right", frame_margin)
	_frame_margin.add_theme_constant_override(
		"margin_top",
		10 if compact else 14 if medium else roundi(18.0 * presentation_scale)
	)
	_frame_margin.add_theme_constant_override(
		"margin_bottom",
		9 if compact else 12 if medium else roundi(15.0 * presentation_scale)
	)
	_main.add_theme_constant_override("separation", 5 if compact else 7 if medium else 8)
	_content_split.add_theme_constant_override("separation", 6 if compact else 8 if medium else 10)
	_character_header.custom_minimum_size.y = (
		86.0 if compact else 96.0 if medium else 104.0 * presentation_scale
	)
	_header_portrait.apply_layout(
		0.66 if compact else 0.74 if medium else 0.78 * presentation_scale
	)
	_identity_badge.custom_minimum_size = Vector2.ONE * (
		30.0 if compact else 34.0 if medium else 38.0 * presentation_scale
	)
	_title_label.add_theme_font_size_override(
		"font_size",
		21 if compact else 24 if medium else roundi(27.0 * presentation_scale)
	)
	_discipline_summary_label.add_theme_font_size_override(
		"font_size",
		12 if compact else 13 if medium else roundi(14.0 * presentation_scale)
	)
	_header_summary_label.add_theme_font_size_override(
		"font_size",
		11 if compact else 12 if medium else roundi(13.0 * presentation_scale)
	)
	_consultative_label.add_theme_font_size_override(
		"font_size",
		10 if compact else 11 if medium else roundi(12.0 * presentation_scale)
	)
	_consultative_label.visible = viewport_size.x >= 1460.0
	_branch_navigation.custom_minimum_size.x = (
		206.0 if compact else 226.0 if medium else 252.0 * presentation_scale
	)
	_branch_title_label.add_theme_font_size_override(
		"font_size",
		12 if compact else 13 if medium else roundi(14.0 * presentation_scale)
	)
	_tabs.add_theme_constant_override("separation", 5 if compact else 6 if medium else 7)
	for button in _tab_buttons:
		button.apply_layout_profile(_layout_profile)
	var detail_width := (
		286.0 if compact else 326.0 if medium else 360.0 * presentation_scale
	)
	_detail_panel.custom_minimum_size.x = detail_width
	_detail_panel.apply_layout_profile(_layout_profile)
	_close_button.custom_minimum_size = Vector2(
		94.0 if compact else 104.0 if medium else 112.0 * presentation_scale,
		34.0 if compact else 38.0 if medium else 42.0 * presentation_scale
	)
	_canvas_hint_label.visible = not compact
	_footer_label.custom_minimum_size.y = 18.0 if compact else 20.0 if medium else 22.0
	_footer_label.add_theme_font_size_override(
		"font_size",
		11 if compact else 12 if medium else roundi(13.0 * presentation_scale)
	)
	_queue_graph_layout()


func _queue_graph_layout() -> void:
	if is_inside_tree():
		_apply_graph_layout.call_deferred()


func _apply_graph_layout() -> void:
	if not is_instance_valid(_graph_scroll) or not is_instance_valid(_graph):
		return
	if not _graph_scroll.visible or _graph_scroll.size.x < 100.0 or _graph_scroll.size.y < 100.0:
		return
	_graph.apply_layout(
		size,
		Vector2(maxf(_graph_scroll.size.x, 1.0), maxf(_graph_scroll.size.y, 1.0))
	)


func _on_graph_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_pan_active = event.pressed
		if _pan_active:
			_pan_mouse_origin = event.position
			_pan_scroll_origin = Vector2(
				_graph_scroll.scroll_horizontal,
				_graph_scroll.scroll_vertical
			)
		_graph_scroll.accept_event()
	elif event is InputEventMouseMotion and _pan_active:
		var delta: Vector2 = event.position - _pan_mouse_origin
		_graph_scroll.scroll_horizontal = maxi(int(_pan_scroll_origin.x - delta.x), 0)
		_graph_scroll.scroll_vertical = maxi(int(_pan_scroll_origin.y - delta.y), 0)
		_graph_scroll.accept_event()


func _get_character_state() -> CharacterRunState:
	if _preview_character_state != null:
		return _preview_character_state
	if progression_controller == null or not progression_controller.has_method("get_character_state"):
		return null
	return progression_controller.get_character_state(character_id) as CharacterRunState


func _resolve_current_discipline(character_state: CharacterRunState) -> void:
	if _find_discipline(character_state, current_discipline_id) != null:
		return
	var disciplines := character_state.get_disciplines()
	current_discipline_id = (
		disciplines[0].discipline_id
		if not disciplines.is_empty() and disciplines[0] != null
		else &""
	)


func _apply_character_identity(character_state: CharacterRunState) -> void:
	var unit := character_state.unit
	_active_theme = CharacterHUDThemeCatalog.resolve_refined(unit)
	var character_name := unit.unit_name if unit != null else str(character_state.character_id)
	_title_label.text = "%s · PROGRESSION" % character_name.to_upper()
	var accent := Color(0.62, 0.48, 0.26, 1.0)
	if _active_theme != null:
		accent = _active_theme.primary_color
		_identity_badge.texture = _active_theme.discipline_emblem_texture
		if _active_theme.portrait_texture != null:
			_header_portrait.set_portrait(_active_theme.portrait_texture, character_name)
		elif unit != null and unit.character_data != null:
			_header_portrait.set_character_data(unit.character_data)
		else:
			_header_portrait.set_portrait(null, character_name)
	else:
		_identity_badge.texture = null
		_header_portrait.set_portrait(null, character_name)
	_header_portrait.set_refined_style(true)
	_header_portrait.set_discipline_emblem(null)
	_header_portrait.set_active(true)
	_header_accent.modulate = accent.lightened(0.22)
	_identity_badge.modulate = Color.WHITE
	_title_label.add_theme_color_override("font_color", accent.lightened(0.34))
	_detail_panel.set_accent(accent)
	_update_header_summary(character_state)


func _update_header_summary(character_state: CharacterRunState) -> void:
	var acquired := 0
	var pending := 0
	for progress_value in character_state.get_discipline_progressions().values():
		var progress := progress_value as DisciplineProgressState
		if progress == null:
			continue
		acquired += progress.get_selected_upgrade_ids().size()
		pending += progress.get_pending_rank_choices().size()
	_header_summary_label.text = "%d choix acquis · %d choix disponibles" % [acquired, pending]


func _update_header_branch_summary(
		character_state: CharacterRunState,
		discipline: DisciplineData
	) -> void:
	_discipline_summary_label.text = "%d branches · %s active" % [
		character_state.get_disciplines().size(),
		discipline.display_name,
	]
	_update_header_summary(character_state)


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
	if character_state == null or character_state.unit == null or discipline == null:
		return null
	for spell in character_state.unit.spells:
		if spell != null and spell.skill_tree == discipline:
			return spell as Spell
	return null


func _branch_icon(
		character_state: CharacterRunState,
		_discipline_index: int,
		discipline: DisciplineData
	) -> Texture2D:
	if discipline != null and discipline.icon != null:
		return discipline.icon
	if character_state.character_id == &"elf":
		return null
	if _active_theme == null or character_state.unit == null:
		return null
	var base_spell := _base_spell_for_discipline(character_state, discipline)
	return (
		_active_theme.get_spell_icon_for(base_spell)
		if base_spell != null
		else _active_theme.discipline_emblem_texture
	)


func _base_icon_for_graph(
		character_state: CharacterRunState,
		base_spell: Spell
	) -> Texture2D:
	if character_state.character_id == &"elf" or _active_theme == null:
		return null
	return _active_theme.get_spell_icon_for(base_spell)


func _spell_display_name(
		character_state: CharacterRunState,
		spell_id: StringName
	) -> String:
	if character_state == null or character_state.unit == null or spell_id == &"":
		return ""
	for spell in character_state.unit.spells:
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell.spell_name
	return ""


func _node_name_map(discipline: DisciplineData) -> Dictionary:
	var result := {}
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		for node in rank_data.choices:
			if node != null:
				result[node.upgrade_id] = node.display_name
	return result


func _maximum_progress_label(
		discipline: DisciplineData,
		progress: DisciplineProgressState
	) -> String:
	var has_choices := false
	for rank_data in discipline.ranks:
		if rank_data != null and not rank_data.choices.is_empty():
			has_choices = true
			break
	return (
		"%d XP · RANG MAXIMUM" % progress.xp
		if has_choices
		else "%d XP · PROGRESSION NON DÉFINIE" % progress.xp
	)
