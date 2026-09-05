class_name SkillTreeScreen
extends Control

signal screen_closed
signal evolution_choice_resolved(request_id, upgrade_id)
signal evolution_choice_rejected(request_id, upgrade_id, reason)

const CODEX_STYLE := preload("res://ui/progression/theme/spell_codex_style.gd")

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

var _champion_codex: Control = null
var _champion_read_only := true

var _search_field: LineEdit
var _filter_buttons: Array[Button] = []
var _filter_id: StringName = &"all"
var _search_empty: Label
var _catalog_count: Label
var _spell_banner: PanelContainer
var _spell_banner_icon: TextureRect
var _spell_banner_title: Label
var _spell_banner_meta: Label
var _spell_banner_progress: ProgressBar
var _spell_banner_xp: Label
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
	_build_catalog_tools()
	_apply_codex_chrome()
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
	reset_catalog_filters()
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
	reset_catalog_filters()
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
	reset_catalog_filters()
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
	if character_state.uses_champion_progression():
		_show_champion_codex(character_state)
		return
	_outer_margin.show()
	if is_instance_valid(_champion_codex):
		_champion_codex.hide()
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
	var state := _get_character_state()
	if state != null and state.uses_champion_progression():
		return state.progression_profile.mastery_catalog.doctrines.size()
	return _tab_buttons.size()


func get_tab_buttons() -> Array[SkillTreeDisciplineTab]:
	return _tab_buttons.duplicate()


func get_close_button() -> Button:
	return _close_button


func get_active_theme() -> CharacterHUDThemeData:
	return _active_theme


func is_progression_defined() -> bool:
	var state := _get_character_state()
	return state != null and (state.uses_champion_progression() or not state.get_disciplines().is_empty())


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
	if is_instance_valid(_champion_codex) and _champion_codex.visible:
		return _champion_read_only
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
		var tab_spell := _base_spell_for_discipline(character_state, discipline)
		if tab_spell != null:
			button.set_spell_label(tab_spell.spell_name)
		button.apply_layout_profile(_layout_profile)
		button.disabled = _evolution_mode
		if not _evolution_mode:
			button.pressed.connect(_show_discipline.bind(discipline.discipline_id))
		_tab_buttons.append(button)
	_apply_catalog_filter()


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
	_canvas_title_label.text = "ÉVOLUTIONS"
	for button in _tab_buttons:
		button.set_selected(button.discipline_id == discipline_id)
	var base_spell := _base_spell_for_discipline(character_state, discipline)
	_update_spell_banner(base_spell, discipline, progress)
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
	_spell_banner.hide()
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
	_detail_panel.set_spell_context(_base_spell_for_discipline(character_state, discipline))
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
	var visible_tabs := get_visible_tab_buttons()
	_search_field.focus_neighbor_top = _search_field.get_path_to(_close_button)
	_search_field.focus_neighbor_bottom = _search_field.get_path_to(_filter_buttons[0])
	for filter_button in _filter_buttons:
		filter_button.focus_neighbor_top = filter_button.get_path_to(_search_field)
		filter_button.focus_neighbor_bottom = filter_button.get_path_to(visible_tabs[0] if not visible_tabs.is_empty() else _center_graph_button)
	for index in range(visible_tabs.size()):
		var button := visible_tabs[index]
		if index > 0:
			button.focus_neighbor_top = button.get_path_to(visible_tabs[index - 1])
		else:
			button.focus_neighbor_top = button.get_path_to(_filter_buttons[0])
		if index + 1 < visible_tabs.size():
			button.focus_neighbor_bottom = button.get_path_to(visible_tabs[index + 1])
		else:
			button.focus_neighbor_bottom = button.get_path_to(_center_graph_button)
	var nodes := _graph.get_node_views_in_focus_order()
	if not nodes.is_empty():
		for button in visible_tabs:
			button.focus_neighbor_right = button.get_path_to(nodes[0])
		for node in nodes:
			var old_left := node.get_node_or_null(node.focus_neighbor_left) as Control
			if node.focus_neighbor_left.is_empty() or old_left is SkillTreeDisciplineTab:
				var active_tab := _active_tab()
				var left_target: Control = active_tab if active_tab != null and active_tab.visible else _search_field
				node.focus_neighbor_left = node.get_path_to(left_target)
	_close_button.focus_neighbor_bottom = _close_button.get_path_to(
		visible_tabs[0] if not visible_tabs.is_empty() else _center_graph_button
	)
	_close_button.focus_neighbor_left = _close_button.get_path_to(
		_center_graph_button
	)
	_center_graph_button.focus_neighbor_top = _center_graph_button.get_path_to(_close_button)
	if not visible_tabs.is_empty():
		_center_graph_button.focus_neighbor_left = _center_graph_button.get_path_to(
			visible_tabs[visible_tabs.size() - 1]
		)
	if not nodes.is_empty():
		_center_graph_button.focus_neighbor_bottom = _center_graph_button.get_path_to(
			nodes[0]
		)


func _focus_last_or_first() -> void:
	if is_instance_valid(_champion_codex) and _champion_codex.visible:
		return
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
		_close_button.text = "Fermer  ×"
		_close_button.disabled = false
	if is_instance_valid(_consultative_label):
		_consultative_label.text = "GRIMOIRE\nApprenez par l’action"
	if is_instance_valid(_branch_title_label):
		_branch_title_label.text = "VOS SORTS"


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
		226.0 if compact else 248.0 if medium else 270.0 * presentation_scale
	)
	_branch_title_label.add_theme_font_size_override(
		"font_size",
		12 if compact else 13 if medium else roundi(14.0 * presentation_scale)
	)
	_tabs.add_theme_constant_override("separation", 5 if compact else 6 if medium else 7)
	for button in _tab_buttons:
		button.apply_layout_profile(_layout_profile)
	var detail_width := (
		304.0 if compact else 346.0 if medium else 388.0 * presentation_scale
	)
	_detail_panel.custom_minimum_size.x = detail_width
	_detail_panel.apply_layout_profile(_layout_profile)
	_close_button.custom_minimum_size = Vector2(
		94.0 if compact else 104.0 if medium else 112.0 * presentation_scale,
		34.0 if compact else 38.0 if medium else 42.0 * presentation_scale
	)
	_canvas_hint_label.visible = viewport_size.x >= 1800.0
	_spell_banner_title.add_theme_font_size_override("font_size", 21 if compact else 25)
	_spell_banner_meta.add_theme_font_size_override("font_size", 13 if compact else 15)
	_spell_banner.custom_minimum_size.y = 114 if compact else 124
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
	_title_label.text = "Sorts & maîtrises"
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
	_identity_badge.hide()
	_title_label.add_theme_color_override("font_color", CODEX_STYLE.TEXT)
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
	_header_summary_label.text = "%d évolutions acquises · %d choix en attente" % [acquired, pending]


func _update_header_branch_summary(
		character_state: CharacterRunState,
		discipline: DisciplineData
	) -> void:
	_discipline_summary_label.text = "%s  ·  %d sorts  ·  %s" % [
		character_state.unit.unit_name, character_state.get_disciplines().size(), discipline.display_name,
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


func _build_catalog_tools() -> void:
	var branch_content := _branch_title_label.get_parent() as VBoxContainer
	_branch_title_label.text = "VOS SORTS"
	_catalog_count = Label.new()
	_catalog_count.name = "CatalogCount"
	CODEX_STYLE.label(_catalog_count)
	_catalog_count.add_theme_font_size_override("font_size", 13)
	branch_content.add_child(_catalog_count)
	branch_content.move_child(_catalog_count, 1)
	_search_field = LineEdit.new()
	_search_field.name = "SpellSearch"
	_search_field.placeholder_text = "Rechercher un sort…"
	_search_field.clear_button_enabled = true
	_search_field.custom_minimum_size = Vector2(0, 38)
	_search_field.add_theme_font_override("font", CODEX_STYLE.BODY)
	_search_field.add_theme_font_size_override("font_size", 14)
	_search_field.add_theme_color_override("font_color", CODEX_STYLE.TEXT)
	_search_field.add_theme_stylebox_override("normal", CODEX_STYLE.box(CODEX_STYLE.INK, CODEX_STYLE.BORDER, 5, 9))
	_search_field.add_theme_stylebox_override("focus", CODEX_STYLE.box(CODEX_STYLE.INK, CODEX_STYLE.GOLD, 5, 9))
	branch_content.add_child(_search_field)
	branch_content.move_child(_search_field, 2)
	_search_field.text_changed.connect(func(_value: String): _apply_catalog_filter())
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 5)
	branch_content.add_child(filters)
	branch_content.move_child(filters, 3)
	for index in range(2):
		var button := Button.new()
		button.text = ["Tous", "Choix prêts"][index]
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		filters.add_child(button)
		CODEX_STYLE.button(button)
		button.pressed.connect(set_spell_filter.bind([&"all", &"pending"][index]))
		_filter_buttons.append(button)
	_search_empty = Label.new()
	_search_empty.text = "Aucun sort correspondant.\nEffacez la recherche ou affichez tous les sorts."
	_search_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_search_empty.add_theme_font_size_override("font_size", 14)
	CODEX_STYLE.label(_search_empty)
	branch_content.add_child(_search_empty)
	branch_content.move_child(_search_empty, 4)
	_search_empty.hide()
	var canvas_content := _canvas_title_label.get_parent().get_parent() as VBoxContainer
	_spell_banner = PanelContainer.new()
	_spell_banner.name = "ActiveSpellBanner"
	_spell_banner.add_theme_stylebox_override("panel", CODEX_STYLE.box(Color("20322f"), Color("4d5e50"), 7, 15))
	canvas_content.add_child(_spell_banner)
	canvas_content.move_child(_spell_banner, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_spell_banner.add_child(row)
	_spell_banner_icon = TextureRect.new()
	_spell_banner_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spell_banner_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_spell_banner_icon.custom_minimum_size = Vector2(66, 66)
	_spell_banner_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_spell_banner_icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 5)
	row.add_child(copy)
	_spell_banner_title = Label.new()
	_spell_banner_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	CODEX_STYLE.label(_spell_banner_title, true)
	copy.add_child(_spell_banner_title)
	_spell_banner_meta = Label.new()
	_spell_banner_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CODEX_STYLE.label(_spell_banner_meta)
	copy.add_child(_spell_banner_meta)
	_spell_banner_progress = ProgressBar.new()
	_spell_banner_progress.custom_minimum_size.y = 5
	_spell_banner_progress.show_percentage = false
	_spell_banner_progress.add_theme_stylebox_override("background", CODEX_STYLE.box(CODEX_STYLE.INK, Color.TRANSPARENT, 2))
	_spell_banner_progress.add_theme_stylebox_override("fill", CODEX_STYLE.box(CODEX_STYLE.GOLD, Color.TRANSPARENT, 2))
	copy.add_child(_spell_banner_progress)
	_spell_banner_xp = Label.new()
	_spell_banner_xp.add_theme_font_size_override("font_size", 12)
	CODEX_STYLE.label(_spell_banner_xp)
	copy.add_child(_spell_banner_xp)


func _apply_codex_chrome() -> void:
	_main_frame.hide()
	for node in find_children("*Ornament", "Control", true, false):
		node.hide()
	var frame := _outer_margin.get_node("Frame") as PanelContainer
	frame.add_theme_stylebox_override("panel", CODEX_STYLE.box(Color("0e191c"), Color("607065"), 12))
	_character_header.add_theme_stylebox_override("panel", CODEX_STYLE.box(CODEX_STYLE.INK, Color("394b47"), 7))
	_branch_navigation.add_theme_stylebox_override("panel", CODEX_STYLE.box(CODEX_STYLE.SURFACE, Color("394b47"), 7))
	_canvas_surface.add_theme_stylebox_override("panel", CODEX_STYLE.box(Color("142225"), Color("394b47"), 7))
	_header_accent.hide()
	_identity_badge.hide()
	for label in [_discipline_summary_label, _header_summary_label, _consultative_label, _branch_title_label, _canvas_title_label, _canvas_hint_label, _footer_label]:
		CODEX_STYLE.label(label)
	CODEX_STYLE.label(_title_label, true)
	_title_label.add_theme_color_override("font_color", CODEX_STYLE.TEXT)
	_branch_title_label.add_theme_color_override("font_color", CODEX_STYLE.GOLD)
	_canvas_title_label.add_theme_color_override("font_color", CODEX_STYLE.GOLD)
	_consultative_label.text = "GRIMOIRE\nApprenez par l’action"
	_canvas_hint_label.text = "Sélectionnez un choix pour l’inspecter"
	_close_button.text = "Fermer  ×"
	_close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_center_graph_button.text = "Recentrer"
	CODEX_STYLE.button(_close_button)
	CODEX_STYLE.button(_center_graph_button)


func set_search_query(query: String) -> void:
	if _search_field == null or _evolution_mode:
		return
	_search_field.text = query
	_apply_catalog_filter()


func set_spell_filter(filter_id: StringName) -> void:
	if filter_id not in [&"all", &"pending"] or _evolution_mode:
		return
	_filter_id = filter_id
	_apply_catalog_filter()


func reset_catalog_filters() -> void:
	_filter_id = &"all"
	if _search_field != null:
		_search_field.text = ""


func get_visible_tab_buttons() -> Array[SkillTreeDisciplineTab]:
	var result: Array[SkillTreeDisciplineTab] = []
	for tab in _tab_buttons:
		if is_instance_valid(tab) and tab.visible:
			result.append(tab)
	return result


func _apply_catalog_filter() -> void:
	if _search_field == null:
		return
	_search_field.editable = not _evolution_mode
	var state := _get_character_state()
	var query := _search_field.text.strip_edges().to_lower()
	var visible_count := 0
	for tab in _tab_buttons:
		var discipline := _find_discipline(state, tab.discipline_id) if state != null else null
		var spell := _base_spell_for_discipline(state, discipline)
		var haystack := discipline.display_name.to_lower() if discipline != null else ""
		if spell != null:
			haystack += " " + spell.spell_name.to_lower()
		# Future upgrade names and mechanics are never searched before revelation.
		var matches_query := query.is_empty() or haystack.contains(query)
		var matches_filter := _filter_id == &"all" or tab.has_pending_badge()
		tab.visible = _evolution_mode or (matches_query and matches_filter)
		if tab.visible:
			visible_count += 1
	_catalog_count.text = "%d / %d sorts" % [visible_count, _tab_buttons.size()]
	_search_empty.visible = visible_count == 0
	for i in range(_filter_buttons.size()):
		_filter_buttons[i].disabled = _evolution_mode
		CODEX_STYLE.selected(_filter_buttons[i], _filter_id == [&"all", &"pending"][i])
	_configure_focus_navigation()


func _update_spell_banner(spell: Spell, discipline: DisciplineData, progress: DisciplineProgressState) -> void:
	_spell_banner.visible = spell != null
	if spell == null:
		return
	_spell_banner_title.text = spell.spell_name
	_spell_banner_icon.texture = _active_theme.get_spell_icon_for(spell) if _active_theme != null else spell.icon
	_spell_banner_meta.text = "%s  ·  Rang %d  ·  %d PA" % [discipline.display_name, progress.rank, spell.ap_cost]
	var next_rank := progress.get_next_rank_data()
	_spell_banner_progress.max_value = maxf(float(next_rank.required_total_xp), 1.0) if next_rank != null else maxf(float(progress.xp), 1.0)
	_spell_banner_progress.value = progress.xp if next_rank != null else _spell_banner_progress.max_value
	if not progress.get_pending_rank_choices().is_empty():
		_spell_banner_xp.text = "Un choix d’évolution est prêt · inspectez les voies"
	elif next_rank != null:
		_spell_banner_xp.text = "%d / %d XP  ·  Utilisez ce sort pour progresser" % [progress.xp, next_rank.required_total_xp]
	else:
		_spell_banner_xp.text = "%d XP  ·  Maîtrise au rang maximum" % progress.xp


func _show_champion_codex(state: CharacterRunState) -> void:
	_outer_margin.hide()
	if not is_instance_valid(_champion_codex):
		var codex_script = load("res://ui/progression/champion/champion_codex.gd")
		_champion_codex = codex_script.new()
		add_child(_champion_codex)
		_champion_codex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_champion_codex.close_requested.connect(close_screen)
		_champion_codex.build_changed.connect(func() -> void:
			if GameManager.get_character_state(character_id) == _get_character_state():
				GameManager.champion_build_changed.emit(character_id)
		)
	_champion_read_only = _preview_character_state != null or not GameManager.can_edit_champion_build()
	_champion_codex.configure(state, _champion_read_only)
	_champion_codex.select_section(current_discipline_id)
	_champion_codex.show()
	_champion_codex.move_to_front()


func get_champion_codex() -> Control:
	return _champion_codex
