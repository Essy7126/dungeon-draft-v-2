@tool
class_name SkillTreeStudioMain
extends Control

signal close_confirmed

const GUIDE_STEPS := [
	"1 Personnage", "2 Caractéristiques", "3 Discipline", "4 Sort de base",
	"5 Rangs et XP", "6 Améliorations", "7 Branches", "8 Effets",
	"9 Tester", "10 Sauvegarder",
]
# Replié, on pousse la poignée au maximum vers le bas : le tiroir retombe sur
# la hauteur de sa seule barre.
const COLLAPSED_SPLIT_OFFSET := 100000
const DEFAULT_ANALYSIS_SPLIT_OFFSET := -80
const SCREEN_CHARACTER: StringName = &"character"
const SCREEN_SKILLS: StringName = &"skills"
const SCREEN_ANIMATIONS: StringName = &"animations"
const TUTORIAL_SANDBOX_SERVICE_PATH := (
	"res://addons/dungeon_draft_arena_studio/skill_tree/services/"
	+ "skill_tree_tutorial_sandbox_service.gd"
)

var editor_interface = null
var session := SkillTreeEditSession.new()
var heroes: Array[Dictionary] = []
var validation_messages: Array[SkillTreeValidationMessage] = []
var guided := true
var production_profile := false
var workspace_state := {}

var document_label: Label
var status_label: Label
var guided_toggle: CheckButton
var production_toggle: CheckButton
var undo_button: Button
var redo_button: Button
var save_button: Button
var search_button: Button
var compare_button: Button
var global_unit_button: Button
var validate_button: Button
var test_button: Button
var preview_button: Button
var analysis_button: Button
var orphan_button: Button
var tour_menu_button: MenuButton
var toolbar_panel: PanelContainer
var guide_panel: PanelContainer
var screen_panel: PanelContainer
var skills_screen: Control
var animation_screen: SkillTreeAnimationScreen
var character_screen: SkillTreeCharacterScreen
var spell_creation_dialog: SpellCreationDialog
var character_screen_button: Button
var skills_screen_button: Button
var animation_screen_button: Button
var current_screen: StringName = SCREEN_CHARACTER
var catalog: SkillTreeCatalogPanel
var graph: SkillTreeStudioGraphEdit
var inspector: SkillTreeInspectorPanel
var bottom: SkillTreeBottomPanel
var analysis_drawer: SkillTreeAnalysisDrawer
var analysis_split: VSplitContainer
var screens_box: VBoxContainer
var _analysis_split_offset := DEFAULT_ANALYSIS_SPLIT_OFFSET
var rank_bar: HFlowContainer
var return_to_spell_button: Button
var tour: SkillTreeGuidedTour
var status_dialog: AcceptDialog
var confirm_dialog: ConfirmationDialog
var character_dialog: ConfirmationDialog
var close_dialog: ConfirmationDialog
var draft_dialog: ConfirmationDialog
var save_plan_dialog: SkillTreeSavePlanDialog
var search_dialog: SkillTreeGlobalSearchDialog
var orphan_dialog: SkillTreeOrphanDialog
var compare_dialog: ConfirmationDialog
var compare_run_option: OptionButton
var compare_summary_label: Label
var authority_dialog: ConfirmationDialog
var authority_option: OptionButton
var sandbox_reset_button: Button
var node_dialog: ConfirmationDialog
var node_name_edit: LineEdit
var node_rank_spin: SpinBox
var discipline_dialog: ConfirmationDialog
var discipline_name_edit: LineEdit
var discipline_id_edit: LineEdit
var branch_dialog: ConfirmationDialog
var branch_name_edit: LineEdit
var _pending_character_path := ""
var _pending_authority := {}
var _pending_open_discipline_id: StringName = &""
var _pending_confirm_action: Callable
var _pending_parent_node: SkillUpgradeData = null
var _pending_branch_rank := 2
var _loading := false
var _pending_draft := {}
var _draft_timer: Timer
var last_draft_report := {}
var _post_save_action: Callable
var _pending_search_result := {}
var project_context: StudioProjectContext = null
var shared_reference_graph: StudioReferenceGraphService = null
var context_bar: StudioContextBar = null
var _tour_highlight: Panel
var _tour_highlight_target: Control
var _tutorial_sandbox_service: Object
var _review_applies_save := true
var _context_review_approved := false
var _context_review_pending := false


func setup(
		host_editor_interface,
		undo_manager,
		shared_context: StudioProjectContext = null,
		reference_graph: StudioReferenceGraphService = null
	) -> void:
	editor_interface = host_editor_interface
	session.setup(undo_manager)
	project_context = shared_context
	shared_reference_graph = reference_graph


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	workspace_state = SkillTreeUiStateService.load_state()
	guided = bool(workspace_state.get("guided", true))
	production_profile = bool(workspace_state.get("production_profile", false))
	# Hauteur du tiroir choisie à la poignée lors d'une session précédente.
	var stored_split := int(workspace_state.get("analysis_split", 0))
	if stored_split != 0:
		_analysis_split_offset = stored_split
	_build_ui()
	_connect_session()
	_draft_timer = Timer.new()
	_draft_timer.wait_time = 30.0
	_draft_timer.one_shot = false
	_draft_timer.timeout.connect(_autosave_draft)
	add_child(_draft_timer)
	_draft_timer.start()
	heroes = _run_hero_catalog() if project_context != null \
		else SkillTreeCatalogService.discover_units()
	_refresh_catalog()
	if project_context != null:
		project_context.character_changed.connect(_on_context_character_changed)
		project_context.hero_changed.connect(_on_context_hero_changed)
		project_context.run_changed.connect(_on_context_run_changed)
		project_context.register_transition_handler(
			&"skills", Callable(self, "_context_save"),
			Callable(self, "_context_draft"), Callable(self, "_context_discard")
		)
		if project_context.active_character != null:
			call_deferred(
				"_open_context_character", project_context.active_character, true
			)
		return
	var initial_path := str(workspace_state.get("character_path", ""))
	if not _catalog_contains_path(initial_path):
		initial_path = _default_hero_path()
	if not initial_path.is_empty():
		call_deferred("_open_character", initial_path, true)


func request_close() -> void:
	commit_pending_edits()
	if not session.is_dirty():
		prepare_for_close()
		close_confirmed.emit()
		return
	close_dialog.dialog_text = "Le personnage contient des modifications non sauvegardées.\n\nSauvegarder avant de fermer le Skill Studio ?"
	close_dialog.popup_centered()


func prepare_for_close() -> void:
	commit_pending_edits()
	_save_graph_state()
	if session.is_dirty():
		last_draft_report = SkillTreeDraftService.write_draft(session)
	workspace_state = get_state_snapshot()
	SkillTreeUiStateService.save_state(workspace_state)


func dispose_document() -> void:
	if _draft_timer != null:
		_draft_timer.stop()
	session.release_document(false)
	if project_context != null:
		project_context.set_dirty(&"skills", false)


func _exit_tree() -> void:
	if project_context != null:
		project_context.unregister_transition_handler(&"skills")


func commit_pending_edits() -> void:
	if inspector != null:
		inspector.commit_pending_edits()
	if character_screen != null:
		character_screen.commit_pending_edits()


func get_state_snapshot() -> Dictionary:
	return {
		"guided": guided,
		"production_profile": production_profile,
		"character_path": session.canonical_source_path(),
		"discipline_id": str(session.selected_discipline_id),
		"analysis_split": _analysis_split_offset,
		"window_screen": int(workspace_state.get("window_screen", 0)),
		"window_position": workspace_state.get("window_position", Vector2i(80, 80)),
		"window_size": workspace_state.get("window_size", Vector2i(1660, 940)),
		"window_maximized": bool(workspace_state.get("window_maximized", false)),
	}


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 5)
	add_child(root)
	context_bar = StudioContextBar.new()
	context_bar.setup(project_context, shared_reference_graph)
	root.add_child(context_bar)
	root.add_child(_build_toolbar())
	root.add_child(_build_screen_bar())
	root.add_child(_build_guide_bar())
	# Les écrans et le tiroir se partagent la hauteur restante via une poignée
	# native : c'est elle qui permet de remonter le tiroir aussi haut qu'on veut.
	analysis_split = VSplitContainer.new()
	analysis_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	analysis_split.dragged.connect(_on_analysis_split_dragged)
	root.add_child(analysis_split)
	screens_box = VBoxContainer.new()
	screens_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screens_box.size_flags_stretch_ratio = 3.0
	analysis_split.add_child(screens_box)
	var horizontal := HSplitContainer.new()
	horizontal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal.split_offset = 280
	skills_screen = horizontal
	screens_box.add_child(horizontal)
	catalog = SkillTreeCatalogPanel.new()
	catalog.character_requested.connect(_request_character)
	catalog.discipline_requested.connect(_select_discipline)
	catalog.discipline_document_requested.connect(_request_character_discipline)
	catalog.new_discipline_requested.connect(_show_new_discipline_dialog)
	catalog.duplicate_discipline_requested.connect(_duplicate_discipline)
	catalog.rename_discipline_requested.connect(_rename_discipline_display)
	catalog.delete_discipline_requested.connect(_confirm_detach_discipline)
	horizontal.add_child(catalog)
	var graph_box := VBoxContainer.new()
	graph_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horizontal.add_child(graph_box)
	var tree_context_bar := HBoxContainer.new()
	graph_box.add_child(tree_context_bar)
	return_to_spell_button = Button.new()
	return_to_spell_button.text = "Retour au sort"
	return_to_spell_button.tooltip_text = "Ferme l’arbre contextuel et revient au sort sélectionné dans la fiche."
	return_to_spell_button.pressed.connect(_return_to_spell)
	tree_context_bar.add_child(return_to_spell_button)
	var tree_context_help := Label.new()
	tree_context_help.text = "Arbre de progression du sort sélectionné"
	tree_context_help.add_theme_color_override("font_color", Color(0.72, 0.77, 0.84))
	tree_context_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_context_bar.add_child(tree_context_help)
	rank_bar = HFlowContainer.new()
	rank_bar.add_theme_constant_override("h_separation", 5)
	graph_box.add_child(rank_bar)
	graph = SkillTreeStudioGraphEdit.new()
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.subject_selected.connect(_select_subject)
	graph.prerequisite_requested.connect(_add_prerequisite)
	graph.prerequisite_removal_requested.connect(_remove_prerequisite)
	graph.node_creation_requested.connect(_show_node_dialog)
	graph.nodes_deletion_requested.connect(_confirm_delete_nodes)
	graph.node_duplication_requested.connect(func(node): session.duplicate_node(node))
	graph.nodes_duplication_requested.connect(func(nodes): session.duplicate_nodes(nodes))
	graph.branch_creation_requested.connect(_show_branch_dialog)
	graph.child_creation_requested.connect(_show_child_node_dialog)
	graph_box.add_child(graph)
	bottom = SkillTreeBottomPanel.new()
	bottom.diagnostic_selected.connect(_focus_diagnostic)
	bottom.simulated_node_selected.connect(func(node_id): graph.focus_subject(node_id))
	inspector = SkillTreeInspectorPanel.new()
	inspector.property_change_requested.connect(_change_property)
	inspector.subject_requested.connect(_select_subject)
	inspector.add_modifier_requested.connect(_add_modifier)
	inspector.remove_modifier_requested.connect(_remove_modifier)
	inspector.exclusion_change_requested.connect(func(first, second, enabled):
		session.set_exclusion(first, second, enabled, true)
	)
	inspector.existing_modifier_requested.connect(func(node, modifier):
		session.add_existing_modifier(node, modifier)
	)
	inspector.duplicate_modifier_requested.connect(func(node, modifier):
		session.duplicate_modifier(node, modifier)
	)
	inspector.unique_modifier_requested.connect(func(node, modifier):
		session.make_modifier_unique(node, modifier)
	)
	inspector.move_modifier_requested.connect(func(node, modifier, offset):
		session.move_modifier(node, modifier, offset)
	)
	inspector.inspect_in_godot_requested.connect(func(resource):
		if editor_interface != null:
			editor_interface.inspect_object(resource)
	)
	horizontal.add_child(inspector)
	animation_screen = SkillTreeAnimationScreen.new()
	animation_screen.name = "AnimationScreen"
	animation_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	animation_screen.character_change_requested.connect(func():
		_show_screen(SCREEN_CHARACTER)
	)
	animation_screen.clip_change_requested.connect(_change_animation_clip)
	screens_box.add_child(animation_screen)
	character_screen = SkillTreeCharacterScreen.new()
	character_screen.name = "CharacterScreen"
	character_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_screen.character_chosen.connect(_choose_character)
	character_screen.property_change_requested.connect(_change_property)
	character_screen.team_change_requested.connect(_request_team_change)
	character_screen.spell_edit_requested.connect(_select_subject)
	character_screen.spell_tree_requested.connect(_open_spell_tree)
	character_screen.spell_creation_requested.connect(_show_spell_creation_dialog)
	character_screen.existing_spell_requested.connect(_attach_existing_spell)
	character_screen.spell_detach_requested.connect(_confirm_detach_spell)
	screens_box.add_child(character_screen)
	analysis_drawer = SkillTreeAnalysisDrawer.new()
	analysis_drawer.name = "AnalysisDrawer"
	analysis_drawer.expanded_changed.connect(_on_analysis_expanded_changed)
	analysis_split.add_child(analysis_drawer)
	analysis_drawer.attach_body(bottom)
	# Toute action qui amène l'utilisateur sur un onglet du tiroir (Valider,
	# Tester, Prévisualiser, Analyse, clic sur un diagnostic…) doit le déplier.
	bottom.tab_changed.connect(func(_index): analysis_drawer.open())
	# La ligne d'état rejoint la barre du tiroir : un seul endroit, tout en bas,
	# où lire ce que le Studio a à dire, au lieu de deux zones concurrentes.
	status_label = analysis_drawer.summary_label
	_on_analysis_expanded_changed(analysis_drawer.is_expanded())
	_build_dialogs()
	spell_creation_dialog = SpellCreationDialog.new()
	spell_creation_dialog.spell_creation_requested.connect(_create_spell)
	add_child(spell_creation_dialog)
	_build_tour_highlight()
	_show_screen(current_screen)


func _build_toolbar() -> Control:
	toolbar_panel = PanelContainer.new()
	var panel := toolbar_panel
	panel.custom_minimum_size.y = 72
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	panel.add_child(rows)
	var identity := HBoxContainer.new()
	rows.add_child(identity)
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 6)
	bar.add_theme_constant_override("v_separation", 4)
	rows.add_child(bar)
	var title := Label.new()
	title.text = "STUDIO DES PERSONNAGES ET COMPÉTENCES"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.48, 0.86, 1.0))
	identity.add_child(title)
	document_label = Label.new()
	document_label.text = "Aucun personnage"
	document_label.clip_text = true
	document_label.custom_minimum_size.x = 150
	document_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(document_label)
	undo_button = _button(bar, "Annuler", "Annuler la dernière modification", _undo)
	redo_button = _button(bar, "Rétablir", "Rétablir la modification annulée", _redo)
	search_button = _button(bar, "Rechercher", "Recherche globale (Ctrl+F)", func():
		search_dialog.set_catalog(heroes)
		search_dialog.open_and_focus()
	)
	compare_button = _button(
		bar, "Comparer parties", "Choisir explicitement la partie à comparer",
		_compare_with_other_run
	)
	global_unit_button = _button(
		bar, "Ouvrir la fiche générale",
		"Ouvre volontairement la fiche commune du personnage, sans progression de partie.",
		_open_current_global_unit
	)
	validate_button = _button(
		bar, "Valider", "Expliquer les problèmes sans modifier les données", _validate
	)
	test_button = _button(
		bar, "Tester", "Ouvrir le simulateur de progression", _test
	)
	preview_button = _button(
		bar, "Prévisualiser", "Comparer le sort via la sandbox runtime réelle",
		_preview_runtime
	)
	analysis_button = _button(
		bar, "Analyse complète", "Énumérer les chemins et lancer les lints de conception",
		_run_full_analysis
	)
	orphan_button = _button(
		bar, "Orphelins", "Lister et gérer les Resources devenues inaccessibles",
		_show_orphans
	)
	save_button = _button(bar, "Sauvegarder", "Revoir le plan, puis appliquer la transaction", _request_save_review)
	guided_toggle = CheckButton.new()
	guided_toggle.text = "Mode guidé"
	guided_toggle.button_pressed = guided
	guided_toggle.tooltip_text = "Affiche les descriptions, exemples et champs essentiels."
	guided_toggle.toggled.connect(_set_guided)
	bar.add_child(guided_toggle)
	production_toggle = CheckButton.new()
	production_toggle.text = "Contrat actuel"
	production_toggle.button_pressed = production_profile
	production_toggle.visible = not guided
	production_toggle.tooltip_text = "Vérifie facultativement le preset 0/2/4/8/4 et les seize chemins."
	production_toggle.toggled.connect(func(value):
		production_profile = value
		_refresh_document()
	)
	bar.add_child(production_toggle)
	tour_menu_button = MenuButton.new()
	tour_menu_button.text = "?"
	tour_menu_button.custom_minimum_size.x = 34
	tour_menu_button.tooltip_text = "Tutoriel complet ou accès direct à un chapitre"
	var tutorial_menu := tour_menu_button.get_popup()
	tutorial_menu.add_item("Parcours complet", 0)
	tutorial_menu.add_separator()
	for index in range(SkillTreeGuidedTour.CHAPTERS.size()):
		var chapter := SkillTreeGuidedTour.CHAPTERS[index] as Array
		var item_id := index + 1
		tutorial_menu.add_item(str(chapter[SkillTreeGuidedTour.CHAPTER_TITLE]), item_id)
		tutorial_menu.set_item_metadata(
			tutorial_menu.get_item_index(item_id), chapter[SkillTreeGuidedTour.CHAPTER_ID]
		)
	tutorial_menu.id_pressed.connect(_open_tutorial_menu_item)
	bar.add_child(tour_menu_button)
	return panel


func _build_screen_bar() -> Control:
	screen_panel = PanelContainer.new()
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	screen_panel.add_child(bar)
	character_screen_button = _screen_button(
		bar, "Personnage",
		"Choisir le personnage sur lequel travailler.",
		SCREEN_CHARACTER
	)
	# L'arbre de compétences est désormais une vue contextuelle ouverte depuis
	# un sort. Il ne constitue plus un espace principal du Studio.
	skills_screen_button = null
	animation_screen_button = _screen_button(
		bar, "Animations",
		"Quelle animation joue chaque moment du personnage : repos, marche, mort…",
		SCREEN_ANIMATIONS
	)
	return screen_panel


func _screen_button(
		parent: Control, text: String, tooltip: String, screen: StringName
	) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.set_meta("base_tooltip", tooltip)
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(170, 34)
	button.pressed.connect(func(): _show_screen(screen))
	parent.add_child(button)
	return button


## Un seul écran visible à la fois. Le personnage ouvert ne change pas d'un
## écran à l'autre, mais chaque écran ne montre que ce qui le concerne : les
## outils des compétences disparaissent ailleurs, et tant qu'aucun personnage
## n'est choisi, seul l'écran Personnage est accessible.
func _show_screen(screen: StringName) -> void:
	var has_document := session.working_unit != null
	current_screen = screen
	if not [SCREEN_CHARACTER, SCREEN_SKILLS, SCREEN_ANIMATIONS].has(current_screen) \
			or (current_screen != SCREEN_CHARACTER and not has_document):
		current_screen = SCREEN_CHARACTER
	var on_character := current_screen == SCREEN_CHARACTER
	var on_skills := current_screen == SCREEN_SKILLS
	var on_animations := current_screen == SCREEN_ANIMATIONS
	_update_screen_buttons()
	if character_screen != null:
		character_screen.visible = on_character
	if skills_screen != null:
		skills_screen.visible = on_skills
	if animation_screen != null:
		animation_screen.visible = on_animations
	if guide_panel != null:
		guide_panel.visible = on_skills
	# Le tiroir ne parle que des compétences : il disparaît ailleurs plutôt que
	# d'occuper une ligne pour rien.
	if analysis_drawer != null:
		analysis_drawer.visible = on_skills
	for button in [
		search_button, compare_button, validate_button, test_button,
		preview_button, analysis_button, orphan_button,
	]:
		if button != null:
			button.visible = on_skills
	if global_unit_button != null:
		global_unit_button.visible = has_document
	if production_toggle != null:
		production_toggle.visible = on_skills and not guided
	if animation_screen != null and not on_animations:
		animation_screen.suspend()
	if on_animations:
		animation_screen.resume()
		_refresh_animation_screen()
	elif on_character:
		_refresh_character_screen()


## Les écrans de travail restent inaccessibles tant qu'aucun personnage n'est
## choisi : c'est la garantie qu'on n'ouvre jamais le Studio sur des données
## qui n'appartiennent à personne.
func _update_screen_buttons() -> void:
	var has_document := session.working_unit != null
	for entry in [
		[character_screen_button, current_screen == SCREEN_CHARACTER, true],
		[skills_screen_button, current_screen == SCREEN_SKILLS, has_document],
		[animation_screen_button, current_screen == SCREEN_ANIMATIONS, has_document],
	]:
		var button := entry[0] as Button
		if button == null:
			continue
		button.button_pressed = bool(entry[1])
		button.disabled = not bool(entry[2])
		button.tooltip_text = "Choisissez d’abord un personnage." if button.disabled \
			else str(button.get_meta("base_tooltip", ""))


func _choose_character(path: String) -> void:
	_request_character(path)
	_show_screen(SCREEN_CHARACTER)


func _refresh_character_screen() -> void:
	if character_screen == null or not character_screen.visible:
		return
	character_screen.set_catalog(heroes, _current_catalog_path())
	character_screen.set_document(
		session.working_unit, _current_catalog_path(), validation_messages, guided,
		session.standalone_spells
	)


func _request_team_change(unit: UnitData, team: int) -> void:
	if unit == null or unit != session.working_unit or team == unit.team:
		return
	var next_label := "Personnage jouable" if team == 0 else "Ennemi"
	confirm_dialog.dialog_text = (
		"Changer l’équipe de « %s » vers « %s » ?\n\n"
		+ "Le personnage changera de groupe dans le catalogue. "
		+ "Cette modification reste annulable et ne sera appliquée au fichier "
		+ "de production qu’après sauvegarde."
	) % [unit.unit_name, next_label]
	confirm_dialog.ok_button_text = "Changer l’équipe"
	_pending_confirm_action = func() -> void:
		session.change_property(unit, &"team", team, "Changer l’équipe de %s" % unit.unit_name)
	confirm_dialog.popup_centered()


func _open_spell_tree(discipline_id: StringName) -> void:
	commit_pending_edits()
	if discipline_id == &"" or not session.select_discipline(discipline_id):
		_show_status(
			"Arbre indisponible",
			"Aucune discipline du personnage ne correspond à ce sort."
		)
		return
	var spell := session.current_spell()
	if spell != null:
		session.select_subject(spell)
		character_screen.select_spell(spell)
	_refresh_document()
	_show_screen(SCREEN_SKILLS)


func _return_to_spell() -> void:
	commit_pending_edits()
	var spell := session.current_spell()
	if spell != null:
		character_screen.select_spell(spell)
	_show_screen(SCREEN_CHARACTER)


## Replié, la poignée est poussée à fond vers le bas : le tiroir retombe sur sa
## barre. La hauteur choisie par l'utilisateur est conservée à part et restaurée
## telle quelle à la réouverture.
func _on_analysis_expanded_changed(expanded: bool) -> void:
	if analysis_split == null:
		return
	analysis_split.split_offset = _analysis_split_offset if expanded \
		else COLLAPSED_SPLIT_OFFSET


func _on_analysis_split_dragged(offset: int) -> void:
	if analysis_drawer == null or not analysis_drawer.is_expanded():
		return
	_analysis_split_offset = offset


func _refresh_animation_screen() -> void:
	# Écran caché : inutile d'instancier le modèle 3D et de le faire tourner.
	# Il se reconstruira à l'affichage, avec l'état à jour.
	if animation_screen == null or not animation_screen.visible:
		return
	animation_screen.set_catalog(heroes, _current_catalog_path())
	animation_screen.set_guided(guided)
	animation_screen.set_document(session.working_unit, _current_catalog_path())


func _show_spell_creation_dialog() -> void:
	if session.working_unit == null or spell_creation_dialog == null:
		return
	commit_pending_edits()
	spell_creation_dialog.setup(
		heroes, session.working_unit, session.known_spell_ids()
	)
	spell_creation_dialog.open_dialog()


func _create_spell(data: Dictionary) -> void:
	var spell := session.create_spell(
		StringName(data.get("template", SkillTreeEditSession.SPELL_TEMPLATE_SIMPLE_ATTACK)),
		str(data.get("display_name", "")),
		bool(data.get("attach_to_character", true)),
		heroes
	)
	if spell == null:
		_show_status(
			"Création impossible",
			"Le sort n’a pas pu être créé. Vérifiez qu’un personnage est ouvert et que l’emplacement du fichier reste libre."
		)
		return
	_show_screen(SCREEN_CHARACTER)
	session.select_subject(spell)
	_refresh_document()
	# On atterrit directement sur la fiche du nouveau sort, ouverte en édition,
	# dans l'onglet Sorts du personnage : aucune étape supplémentaire imposée.
	if character_screen != null:
		character_screen.select_spell(spell, true)


func _attach_existing_spell(spell: Spell) -> void:
	if spell == null:
		return
	commit_pending_edits()
	if not session.attach_existing_spell(spell):
		_show_status(
			"Ajout impossible",
			"Ce personnage connaît déjà un sort portant cet identifiant stable."
		)
		return
	_refresh_document()
	if character_screen != null:
		character_screen.select_spell(session.selected_subject as Spell)


func _confirm_detach_spell(spell: Spell) -> void:
	if spell == null or session.working_unit == null:
		return
	confirm_dialog.dialog_text = "Retirer « %s » de %s ?\n\nLe sort et son arbre ne seront plus disponibles pour ce personnage. Leurs fichiers restent sur le disque, et les autres personnages qui les utilisent ne changent pas." % [
		spell.spell_name, session.working_unit.unit_name,
	]
	confirm_dialog.ok_button_text = "Retirer le sort"
	_pending_confirm_action = func() -> void:
		if not session.detach_spell(spell):
			_show_status(
				"Retrait impossible",
				"Ce sort ne fait plus partie de la liste du personnage."
			)
			return
		_refresh_document()
	confirm_dialog.popup_centered()


func _change_animation_clip(
		action_id: StringName, clip_name: StringName, event_label: String
	) -> void:
	if session.working_unit == null:
		return
	session.set_animation_clip(action_id, clip_name, event_label)


func _build_guide_bar() -> Control:
	guide_panel = PanelContainer.new()
	var panel := guide_panel
	var box := VBoxContainer.new()
	panel.add_child(box)
	# La ligne d'état vit dans la barre du tiroir d'analyse, tout en bas.
	var steps := HFlowContainer.new()
	steps.add_theme_constant_override("h_separation", 4)
	box.add_child(steps)
	for index in range(GUIDE_STEPS.size()):
		var step := Button.new()
		step.text = GUIDE_STEPS[index]
		step.flat = true
		step.tooltip_text = _step_help(index)
		step.pressed.connect(_activate_step.bind(index))
		steps.add_child(step)
	sandbox_reset_button = Button.new()
	sandbox_reset_button.text = "↺ Réinitialiser l’exercice"
	sandbox_reset_button.tooltip_text = (
		"Restaure seulement la fixture initiale possédée par le tutoriel."
	)
	sandbox_reset_button.visible = false
	sandbox_reset_button.pressed.connect(_confirm_restore_tutorial_sandbox)
	steps.add_child(sandbox_reset_button)
	return panel


func _build_dialogs() -> void:
	tour = SkillTreeGuidedTour.new()
	tour.target_requested.connect(_show_tour_target)
	tour.sandbox_requested.connect(_start_tutorial_sandbox)
	tour.visibility_changed.connect(func():
		if not tour.visible:
			_clear_tour_highlight()
	)
	add_child(tour)
	status_dialog = AcceptDialog.new()
	status_dialog.title = "Skill Studio"
	add_child(status_dialog)
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Confirmer la modification"
	confirm_dialog.confirmed.connect(func():
		if _pending_confirm_action.is_valid():
			_pending_confirm_action.call()
		_pending_confirm_action = Callable()
	)
	add_child(confirm_dialog)
	character_dialog = ConfirmationDialog.new()
	character_dialog.title = "Changer de personnage"
	character_dialog.ok_button_text = "Sauvegarder puis ouvrir"
	character_dialog.add_button("Abandonner les modifications", true, "discard")
	character_dialog.confirmed.connect(func():
		_request_save_review(func():
			if not _pending_authority.is_empty():
				_open_authority(_pending_authority)
			else:
				_open_character(_pending_character_path)
			_pending_authority.clear()
		)
	)
	character_dialog.custom_action.connect(func(action):
		if action == "discard":
			character_dialog.hide()
			if session.source_unit != null:
				SkillTreeDraftService.clear_for_source(session.canonical_source_path())
			if not _pending_authority.is_empty():
				_open_authority(_pending_authority)
				_pending_authority.clear()
			else:
				_open_character(_pending_character_path)
	)
	add_child(character_dialog)
	authority_dialog = ConfirmationDialog.new()
	authority_dialog.title = "Choisir l’autorité du personnage"
	authority_dialog.ok_button_text = "Ouvrir cette autorité"
	var authority_box := VBoxContainer.new()
	authority_box.custom_minimum_size = Vector2(680, 130)
	authority_dialog.add_child(authority_box)
	var authority_help := Label.new()
	authority_help.text = (
		"Ce personnage possède plusieurs progressions hors de la partie active. "
		+ "Choisissez explicitement la partie et le profil à ouvrir."
	)
	authority_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	authority_box.add_child(authority_help)
	authority_option = OptionButton.new()
	authority_option.fit_to_longest_item = false
	authority_box.add_child(authority_option)
	authority_dialog.confirmed.connect(_open_selected_authority)
	add_child(authority_dialog)
	close_dialog = ConfirmationDialog.new()
	close_dialog.title = "Fermer le Skill Studio"
	close_dialog.ok_button_text = "Sauvegarder et fermer"
	close_dialog.add_button("Fermer sans sauvegarder", true, "discard")
	close_dialog.confirmed.connect(func():
		_request_save_review(func():
			prepare_for_close()
			close_confirmed.emit()
		)
	)
	close_dialog.custom_action.connect(func(action):
		if action == "discard":
			close_dialog.hide()
			prepare_for_close()
			close_confirmed.emit()
	)
	add_child(close_dialog)
	draft_dialog = ConfirmationDialog.new()
	draft_dialog.title = "Brouillon récupérable"
	draft_dialog.ok_button_text = "Restaurer"
	draft_dialog.add_button("Comparer", true, "compare")
	draft_dialog.add_button("Abandonner", true, "abandon")
	draft_dialog.confirmed.connect(_restore_pending_draft)
	draft_dialog.custom_action.connect(func(action):
		if action == "compare":
			var comparison := SkillTreeDraftService.compare(_pending_draft)
			_show_status(
				"Comparaison du brouillon",
				"Source modifiée depuis l'ouverture : %s\nEmpreinte source : %s\nEmpreinte brouillon : %s" % [
					"oui" if comparison.get("source_changed", false) else "non",
					comparison.get("source_fingerprint", "inconnue"),
					comparison.get("draft_fingerprint", "inconnue"),
				]
			)
		elif action == "abandon":
			SkillTreeDraftService.abandon(_pending_draft)
			_pending_draft.clear()
			draft_dialog.hide()
	)
	add_child(draft_dialog)
	save_plan_dialog = SkillTreeSavePlanDialog.new()
	save_plan_dialog.confirmed.connect(_apply_reviewed_save)
	save_plan_dialog.canceled.connect(_cancel_save_review)
	save_plan_dialog.navigation_requested.connect(_navigate_to_logical_owner)
	add_child(save_plan_dialog)
	search_dialog = SkillTreeGlobalSearchDialog.new()
	search_dialog.result_requested.connect(_open_search_result)
	add_child(search_dialog)
	orphan_dialog = SkillTreeOrphanDialog.new()
	orphan_dialog.action_requested.connect(_handle_orphan_action)
	add_child(orphan_dialog)
	compare_dialog = ConfirmationDialog.new()
	compare_dialog.title = "Comparer deux parties"
	compare_dialog.ok_button_text = "Comparer"
	var compare_box := VBoxContainer.new()
	compare_box.custom_minimum_size = Vector2(500, 130)
	compare_dialog.add_child(compare_box)
	compare_summary_label = Label.new()
	compare_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	compare_box.add_child(compare_summary_label)
	compare_run_option = OptionButton.new()
	compare_run_option.tooltip_text = "Partie de référence comparée à la partie active."
	compare_box.add_child(compare_run_option)
	compare_dialog.confirmed.connect(_compare_selected_run)
	add_child(compare_dialog)
	node_dialog = ConfirmationDialog.new()
	node_dialog.title = "Ajouter une amélioration"
	node_dialog.ok_button_text = "Créer l’amélioration"
	var node_box := VBoxContainer.new()
	node_dialog.add_child(node_box)
	var node_help := Label.new()
	node_help.text = "Choisissez un nom compréhensible et le rang où cette amélioration sera proposée."
	node_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node_box.add_child(node_help)
	node_name_edit = LineEdit.new()
	node_name_edit.placeholder_text = "Exemple : Flèches brûlantes"
	node_box.add_child(node_name_edit)
	node_rank_spin = SpinBox.new()
	node_rank_spin.min_value = 2
	node_rank_spin.max_value = 99
	node_rank_spin.step = 1
	node_box.add_child(node_rank_spin)
	node_dialog.confirmed.connect(_create_node)
	add_child(node_dialog)
	discipline_dialog = ConfirmationDialog.new()
	discipline_dialog.title = "Nouvelle discipline"
	discipline_dialog.ok_button_text = "Créer la discipline"
	var discipline_box := VBoxContainer.new()
	discipline_dialog.add_child(discipline_box)
	var discipline_help := Label.new()
	discipline_help.text = "Le preset Dungeon Draft crée cinq rangs aux seuils 0 / 5 / 12 / 21 / 30. Vous pourrez ensuite créer librement vos branches."
	discipline_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	discipline_box.add_child(discipline_help)
	discipline_name_edit = LineEdit.new()
	discipline_name_edit.placeholder_text = "Nom affiché, par exemple Alchimie"
	discipline_box.add_child(discipline_name_edit)
	discipline_id_edit = LineEdit.new()
	discipline_id_edit.placeholder_text = "Identifiant stable, par exemple mage_alchemy"
	discipline_box.add_child(discipline_id_edit)
	discipline_dialog.confirmed.connect(_create_discipline)
	add_child(discipline_dialog)
	branch_dialog = ConfirmationDialog.new()
	branch_dialog.title = "Assistant de branche"
	branch_dialog.ok_button_text = "Créer la branche complète"
	var branch_box := VBoxContainer.new()
	branch_dialog.add_child(branch_box)
	var branch_help := Label.new()
	branch_help.text = "Le Studio créera une amélioration dans chaque rang restant et les reliera avec des prérequis. Toute la branche pourra être annulée en une fois."
	branch_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	branch_box.add_child(branch_help)
	branch_name_edit = LineEdit.new()
	branch_name_edit.placeholder_text = "Exemple : Voie du feu"
	branch_box.add_child(branch_name_edit)
	branch_dialog.confirmed.connect(_create_branch)
	add_child(branch_dialog)


func _build_tour_highlight() -> void:
	_tour_highlight = Panel.new()
	_tour_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tour_highlight.z_index = 4096
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.78, 1.0, 0.08)
	style.border_color = Color(0.36, 0.86, 1.0, 0.96)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	_tour_highlight.add_theme_stylebox_override("panel", style)
	add_child(_tour_highlight)
	_tour_highlight.hide()
	set_process(false)


func _process(_delta: float) -> void:
	_update_tour_highlight()


func _open_tutorial_menu_item(item_id: int) -> void:
	if item_id == 0:
		tour.start()
		return
	var popup := tour_menu_button.get_popup()
	var item_index := popup.get_item_index(item_id)
	if item_index < 0:
		return
	var chapter_id := StringName(popup.get_item_metadata(item_index))
	if chapter_id != &"":
		tour.start_chapter(chapter_id)


func _show_tour_target(target: StringName) -> void:
	# Le tutoriel décrit l'écran Compétences : on y revient avant de pointer un
	# élément, sinon la mise en évidence viserait un panneau masqué.
	_show_screen(SCREEN_SKILLS)
	_prepare_tour_subject(target)
	var control := _tour_control(target)
	if control == null:
		_clear_tour_highlight()
		return
	_tour_highlight_target = control
	set_process(true)
	_update_tour_highlight.call_deferred()


func _prepare_tour_subject(target: StringName) -> void:
	var page_id := tour.current_page_id() if tour != null else &""
	match target:
		&"inspector_character":
			if session.working_unit != null:
				session.select_subject(session.working_unit)
		&"inspector_discipline":
			if session.current_discipline() != null:
				session.select_subject(session.current_discipline())
		&"rank_bar":
			var discipline := session.current_discipline()
			if discipline != null and not discipline.ranks.is_empty():
				session.select_subject(discipline.ranks[0])
		&"inspector_node", &"inspector_relations":
			var node := _first_tour_node(target == &"inspector_relations")
			if node != null:
				session.select_subject(node)
		&"inspector_spell", &"inspector_spell_appearance", \
				&"inspector_spell_advanced":
			if session.current_spell() != null:
				session.select_subject(session.current_spell())
		&"inspector_effect", &"inspector_effect_advanced":
			var modifier := _first_tour_modifier()
			if modifier != null:
				session.select_subject(modifier)
			else:
				status_label.text = "Ajoutez d’abord un effet pour afficher ses paramètres."
	if target in [
		&"inspector_spell_advanced", &"inspector_effect_advanced", &"inspector_advanced",
	] and guided:
		_set_guided(false)
	_select_tour_tab(target, page_id)
	match target:
		&"bottom_errors", &"validation":
			bottom.current_tab = 0
		&"bottom_statistics":
			bottom.current_tab = 1
		&"bottom_simulator":
			bottom.current_tab = 2
		&"bottom_preview":
			bottom.current_tab = 3
		&"bottom_analysis":
			bottom.current_tab = 4


func _select_tour_tab(target: StringName, page_id: StringName) -> void:
	if inspector == null or inspector.tabs == null:
		return
	var tab_name := "Général"
	match target:
		&"inspector_relations":
			tab_name = "Relations"
		&"inspector_spell_appearance":
			tab_name = "Apparence"
		&"inspector_spell_advanced", &"inspector_effect_advanced", &"inspector_advanced":
			tab_name = "Avancé"
		&"inspector_effect":
			tab_name = "Effets"
		&"inspector_node":
			tab_name = "Effets" if page_id in [&"effect_model", &"effect_lifecycle"] \
				else "Général"
		&"inspector_discipline":
			tab_name = "Sort" if page_id == &"base_spell_link" else "Général"
		&"inspector_spell":
			if page_id == &"spell_direct_effects":
				tab_name = "Effets"
			elif page_id in [&"spell_cost_range", &"spell_availability", &"spell_targets"]:
				tab_name = "Sort"
	for index in range(inspector.tabs.get_tab_count()):
		if inspector.tabs.get_tab_title(index) == tab_name \
				and not inspector.tabs.is_tab_hidden(index):
			inspector.tabs.current_tab = index
			return


func _tour_control(target: StringName) -> Control:
	match target:
		&"studio_overview":
			return self
		&"context_bar":
			return context_bar
		&"context_run":
			return context_bar.run_option if context_bar != null else null
		&"context_hero":
			return context_bar.hero_option if context_bar != null else null
		&"context_room_scope":
			return context_bar.scope_option if context_bar != null else null
		&"toolbar":
			return toolbar_panel
		&"history":
			return undo_button
		&"document_state":
			return document_label
		&"mode_toggles":
			return guided_toggle
		&"catalog", &"catalog_actions":
			return catalog
		&"rank_bar":
			return rank_bar
		&"graph":
			return graph
		&"inspector_character", &"inspector_discipline", &"inspector_node", \
				&"inspector_relations", &"inspector_spell", &"inspector_spell_appearance", \
				&"inspector_spell_advanced", &"inspector_effect", \
				&"inspector_effect_advanced", &"inspector_advanced":
			return inspector
		&"validation":
			return validate_button
		&"bottom_errors", &"bottom_statistics", &"bottom_simulator", \
				&"bottom_preview", &"bottom_analysis":
			return bottom
		&"compare_runs":
			return compare_button
		&"search":
			return search_button
		&"save":
			return save_button
		&"orphans":
			return orphan_button
		&"sandbox":
			return tour_menu_button
		_:
			return guide_panel


func _first_tour_node(require_relations := false) -> SkillUpgradeData:
	if session.selected_subject is SkillUpgradeData \
			and (not require_relations or session.selected_subject is SkillTreeNodeData):
		return session.selected_subject as SkillUpgradeData
	var discipline := session.current_discipline()
	if discipline == null:
		return null
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		for node in rank_data.choices:
			if node != null and (not require_relations or node is SkillTreeNodeData):
				return node
	return null


func _first_tour_modifier() -> SpellModifier:
	if session.selected_subject is SpellModifier:
		return session.selected_subject as SpellModifier
	var selected_node := session.selected_subject as SkillUpgradeData
	if selected_node != null:
		for modifier in selected_node.spell_modifiers:
			if modifier != null:
				return modifier
	var discipline := session.current_discipline()
	if discipline != null:
		for rank_data in discipline.ranks:
			if rank_data == null:
				continue
			for node in rank_data.choices:
				if node == null:
					continue
				for modifier in node.spell_modifiers:
					if modifier != null:
						return modifier
	return null


func _update_tour_highlight() -> void:
	if _tour_highlight == null or _tour_highlight_target == null \
			or not is_instance_valid(_tour_highlight_target) \
			or not _tour_highlight_target.is_visible_in_tree():
		if _tour_highlight != null:
			_tour_highlight.hide()
		return
	var own_rect := get_global_rect()
	var target_rect := _tour_highlight_target.get_global_rect()
	_tour_highlight.position = target_rect.position - own_rect.position - Vector2(4, 4)
	_tour_highlight.size = target_rect.size + Vector2(8, 8)
	_tour_highlight.show()
	_tour_highlight.move_to_front()


func _clear_tour_highlight() -> void:
	_tour_highlight_target = null
	if _tour_highlight != null:
		_tour_highlight.hide()
	set_process(false)


func _start_tutorial_sandbox() -> void:
	commit_pending_edits()
	if session.is_dirty():
		_request_save_review(_start_tutorial_sandbox)
		return
	if not ResourceLoader.exists(TUTORIAL_SANDBOX_SERVICE_PATH):
		_show_status(
			"Exercice sandbox en préparation",
			"Le tutoriel est raccordé. Son service de fixture sécurisé sera ajouté à l’étape suivante."
		)
		return
	var script := ResourceLoader.load(
		TUTORIAL_SANDBOX_SERVICE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	if script == null:
		_show_status("Exercice indisponible", "Le service sandbox ne peut pas être chargé.")
		return
	_tutorial_sandbox_service = script.new()
	if _tutorial_sandbox_service == null \
			or not _tutorial_sandbox_service.has_method("start"):
		_show_status("Exercice indisponible", "Le service sandbox ne respecte pas son contrat.")
		return
	var result := _tutorial_sandbox_service.call("start", session)
	if not result is Dictionary or not bool((result as Dictionary).get("ok", false)):
		_show_status(
			"Exercice indisponible",
			str((result as Dictionary).get("error", "Erreur inconnue.")) \
				if result is Dictionary else "Réponse sandbox invalide."
		)
		return
	_upsert_tutorial_catalog_entry((result as Dictionary).get("catalog_entry", {}))
	_refresh_document()
	status_label.text = str((result as Dictionary).get(
		"message", "Exercice sandbox chargé ; aucune donnée de production n’est modifiée."
	))
	tour.start_chapter(&"sandbox")


func _confirm_restore_tutorial_sandbox() -> void:
	if not _tutorial_sandbox_is_active():
		return
	confirm_dialog.dialog_text = (
		"Restaurer le personnage vide initial de l’exercice ?\n\n"
		+ "Les modifications sandbox non sauvegardées seront abandonnées. "
		+ "Aucun fichier de production ne sera touché."
	)
	confirm_dialog.ok_button_text = "Restaurer l’exercice"
	_pending_confirm_action = _restore_tutorial_sandbox
	confirm_dialog.popup_centered()


func _restore_tutorial_sandbox() -> void:
	var result: Variant = _tutorial_sandbox_service.call("restore_initial", session)
	if not result is Dictionary or not bool((result as Dictionary).get("ok", false)):
		_show_status(
			"Restauration impossible",
			str((result as Dictionary).get("error", "Erreur inconnue.")) \
				if result is Dictionary else "Réponse sandbox invalide."
		)
		return
	_upsert_tutorial_catalog_entry((result as Dictionary).get("catalog_entry", {}))
	_refresh_document()
	status_label.text = str((result as Dictionary).get(
		"message", "L’exercice a été réinitialisé."
	))


func _upsert_tutorial_catalog_entry(entry_value: Variant) -> void:
	if not entry_value is Dictionary:
		return
	var entry := entry_value as Dictionary
	var path := str(entry.get("path", ""))
	if path.is_empty():
		return
	for index in range(heroes.size()):
		if str(heroes[index].get("path", "")) == path:
			heroes[index] = entry
			return
	heroes.push_front(entry)


func _tutorial_sandbox_is_active() -> bool:
	return _tutorial_sandbox_service != null \
		and _tutorial_sandbox_service.has_method("is_active") \
		and bool(_tutorial_sandbox_service.call("is_active", session))


func _prepare_tutorial_sandbox_for_save() -> Dictionary:
	if not _tutorial_sandbox_is_active():
		return {"ok": true}
	var result: Variant = _tutorial_sandbox_service.call("prepare_for_save", session)
	return result as Dictionary if result is Dictionary \
		else {"ok": false, "error": "Réponse sandbox invalide."}


func _save_options() -> Dictionary:
	if not _tutorial_sandbox_is_active() \
			or not _tutorial_sandbox_service.has_method("save_options"):
		return {}
	var options: Variant = _tutorial_sandbox_service.call("save_options")
	return options as Dictionary if options is Dictionary else {}


func _validation_roots() -> PackedStringArray:
	var options := _save_options()
	var roots: Variant = options.get("allowed_roots")
	return (roots as PackedStringArray).duplicate() \
		if roots is PackedStringArray else PackedStringArray(["res://data/"])


func _connect_session() -> void:
	session.document_changed.connect(_refresh_document)
	session.selection_changed.connect(func(_subject): _refresh_inspector())
	session.history_changed.connect(_refresh_history)


func _request_character(path: String) -> void:
	_pending_open_discipline_id = &""
	_request_character_path(path)


func _request_character_discipline(path: String, discipline_id: StringName) -> void:
	_pending_open_discipline_id = discipline_id
	_request_character_path(path)


func _request_character_path(path: String) -> void:
	commit_pending_edits()
	if path.is_empty():
		return
	var entry := _catalog_entry_for_path(path)
	if entry.is_empty():
		_open_character(path)
		return
	var authorities: Array = entry.get("profile_authorities", [])
	var active_authority := _authority_for_active_run(authorities)
	if not active_authority.is_empty():
		_request_authority(active_authority)
		return
	if authorities.size() == 1:
		_request_authority(authorities[0] as Dictionary)
		return
	if authorities.size() > 1:
		_show_authority_choice(entry)
		return
	_request_authority(RunContentCatalogService.global_unit_authority(
		entry.get("unit_resource", entry.get("resource")) as UnitData
	))


func _catalog_entry_for_path(path: String) -> Dictionary:
	for entry in heroes:
		if str(entry.get("path", "")) == path:
			return entry
	return {}


func _authority_for_active_run(authorities: Array) -> Dictionary:
	if project_context == null or project_context.active_run == null:
		return {}
	for authority_value in authorities:
		var authority := authority_value as Dictionary
		if authority.get("run") == project_context.active_run or (
			str(authority.get("run_path", "")) \
				== project_context.active_run.resource_path
		):
			return authority
	return {}


func _show_authority_choice(entry: Dictionary) -> void:
	authority_option.clear()
	for authority_value in entry.get("profile_authorities", []):
		var authority := authority_value as Dictionary
		authority_option.add_item("%s — %s" % [
			authority.get("run_name", "Partie sans nom"),
			authority.get("profile_path", "Profil sans chemin"),
		])
		authority_option.set_item_metadata(
			authority_option.item_count - 1, authority
		)
	var unit := entry.get("unit_resource", entry.get("resource")) as UnitData
	var global_authority := RunContentCatalogService.global_unit_authority(unit)
	authority_option.add_item("Ouvrir la fiche générale — %s" % global_authority.unit_path)
	authority_option.set_item_metadata(
		authority_option.item_count - 1, global_authority
	)
	authority_option.select(0)
	authority_dialog.popup_centered(Vector2i(720, 240))


func _open_selected_authority() -> void:
	if authority_option.item_count == 0:
		return
	var authority := authority_option.get_selected_metadata() as Dictionary
	_request_authority(authority)


func _request_authority(authority: Dictionary) -> void:
	if authority.is_empty() or _authority_is_open(authority):
		return
	var authority_type := StringName(authority.get("authority", &""))
	if project_context != null:
		var requested := {}
		if authority_type == RunContentCatalogService.AUTHORITY_PROGRESSION_PROFILE:
			requested = project_context.request_progression_authority(
				authority.get("run") as RunData,
				authority.get("hero_profile") as RunHeroProfile,
				&"skills"
			)
		else:
			requested = project_context.request_global_character(
				str(authority.get("unit_path", "")), &"skills"
			)
		if not requested.get("ok", false) \
				and requested.get("status", &"") != &"REQUIRES_DECISION":
			_show_status(
				"Changement impossible", str(requested.get("error", "Erreur inconnue."))
			)
		elif requested.get("status", &"") == &"UNCHANGED":
			_open_authority(authority)
		return
	if session.is_dirty():
		_pending_authority = authority
		_pending_character_path = str(authority.get("unit_path", ""))
		character_dialog.dialog_text = "Le personnage actuel contient des modifications non sauvegardées.\n\nChoisissez si vous voulez les sauvegarder, les abandonner ou rester sur ce personnage."
		character_dialog.popup_centered()
		return
	_open_authority(authority)


func _authority_is_open(authority: Dictionary) -> bool:
	var authority_type := StringName(authority.get("authority", &""))
	if authority_type == RunContentCatalogService.AUTHORITY_PROGRESSION_PROFILE:
		return session.is_profile_authoritative() \
			and session.canonical_source_path() == str(authority.get("profile_path", ""))
	return not session.is_profile_authoritative() \
		and _current_catalog_path() == str(authority.get("unit_path", ""))


func _open_authority(authority: Dictionary, initial := false) -> void:
	if StringName(authority.get("authority", &"")) \
			== RunContentCatalogService.AUTHORITY_PROGRESSION_PROFILE:
		_open_profile_authority(
			authority.get("run") as RunData,
			authority.get("hero_profile") as RunHeroProfile,
			initial
		)
	else:
		_open_character(str(authority.get("unit_path", "")), initial)


func _open_current_global_unit() -> void:
	var path := _current_catalog_path()
	if path.is_empty():
		return
	var entry := _catalog_entry_for_path(path)
	var unit := entry.get("unit_resource") as UnitData
	if unit == null:
		unit = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) \
			as UnitData
	_request_authority(RunContentCatalogService.global_unit_authority(unit))


func _open_character(path: String, initial := false) -> void:
	commit_pending_edits()
	if not ResourceLoader.exists(path):
		_show_status("Personnage introuvable", "La Resource n’existe plus : %s" % path)
		return
	_save_graph_state()
	var unit := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as UnitData
	if unit == null or not session.open(unit):
		_show_status("Ouverture impossible", "Le fichier choisi n’est pas une unité valide.")
		return
	if initial:
		var remembered := StringName(workspace_state.get("discipline_id", &""))
		if remembered != &"":
			session.select_discipline(remembered)
	elif _pending_open_discipline_id != &"":
		session.select_discipline(_pending_open_discipline_id)
	_pending_open_discipline_id = &""
	status_label.text = "Personnage chargé. Choisissez une discipline ou modifiez ses caractéristiques."
	_refresh_document()
	_focus_pending_search_result()
	_offer_draft(path)


func _open_context_hero(hero: RunHeroProfile, initial := false) -> void:
	if project_context == null or project_context.active_run == null or hero == null:
		return
	if session.is_profile_authoritative() and hero.progression_profile != null \
			and session.canonical_source_path() \
			== hero.progression_profile.resource_path:
		return
	_open_profile_authority(project_context.active_run, hero, initial)


func _open_profile_authority(
		run_data: RunData,
		hero: RunHeroProfile,
		initial := false
	) -> void:
	if run_data == null or hero == null:
		return
	commit_pending_edits()
	_save_graph_state()
	if not session.open_progression(run_data, hero):
		_show_status(
			"Ouverture impossible",
			"Le profil de progression %s n'est pas exploitable." % hero.character_id
		)
		return
	if initial:
		var remembered := StringName(workspace_state.get("discipline_id", &""))
		if remembered != &"":
			session.select_discipline(remembered)
	elif _pending_open_discipline_id != &"":
		session.select_discipline(_pending_open_discipline_id)
	_pending_open_discipline_id = &""
	status_label.text = (
		"Profil canonique chargé depuis « %s ». L’adaptateur UnitData reste hors sauvegarde."
		% run_data.run_name
	)
	_refresh_document()
	_focus_pending_search_result()
	_offer_draft(session.canonical_source_path())


func _open_context_character(character: UnitData, initial := false) -> void:
	if project_context == null or character == null:
		return
	var hero := project_context.active_hero
	if hero != null and hero.base_unit_data != null \
			and hero.base_unit_data.resource_path == character.resource_path:
		_open_context_hero(hero, initial)
		return
	if not session.is_profile_authoritative() and session.source_unit != null \
			and session.source_unit.resource_path == character.resource_path:
		return
	_open_character(character.resource_path, initial)


func _on_context_character_changed(character: UnitData) -> void:
	if character != null:
		_open_context_character(character)


func _on_context_hero_changed(hero: RunHeroProfile) -> void:
	if hero != null and project_context != null \
			and project_context.active_authority \
			== RunContentCatalogService.AUTHORITY_PROGRESSION_PROFILE:
		_open_context_hero(hero)


func _on_context_run_changed(_run_data: RunData) -> void:
	heroes = _run_hero_catalog()
	_refresh_catalog()


func _select_discipline(discipline_id: StringName) -> void:
	commit_pending_edits()
	if session.selected_discipline_id == discipline_id:
		return
	_save_graph_state()
	if session.select_discipline(discipline_id):
		status_label.text = "Discipline sélectionnée. Le graphe affiche ses vrais rangs et prérequis."
		_refresh_document()


func _select_subject(subject) -> void:
	if subject is Resource:
		session.select_subject(subject)


func _change_property(
		target,
		property_name: StringName,
		value,
		action_name: String
	) -> void:
	if target is DisciplineData and property_name == &"discipline_id":
		var new_id := StringName(value)
		if _project_id_collision("discipline", new_id):
			_show_status("Renommage refusé", "Cet identifiant de discipline existe déjà dans un autre personnage du projet.")
			return
		confirm_dialog.dialog_text = "Changer cet identifiant mettra à jour toutes les références connues dans une seule action.\n\nAncien : %s\nNouveau : %s\n\nRapport :\n• 1 discipline\n• %d amélioration(s)\n• %d sort associé\n\nLes sauvegardes de parties existantes peuvent encore utiliser l’ancien identifiant." % [
			target.discipline_id, new_id, session.all_nodes(target).size(),
			1 if session.current_spell() != null else 0,
		]
		confirm_dialog.ok_button_text = "Mettre à jour les références"
		_pending_confirm_action = func():
			if not session.rename_discipline_id(new_id):
				_show_status("Renommage refusé", "L’identifiant est vide ou déjà utilisé.")
			_refresh_document()
		confirm_dialog.popup_centered()
		return
	if target is SkillUpgradeData and property_name == &"upgrade_id":
		var new_node_id := StringName(value)
		if _project_id_collision("node", new_node_id):
			_show_status("Renommage refusé", "Cet identifiant de nœud existe déjà dans un autre personnage du projet.")
			return
		var prerequisite_references := 0
		var exclusion_references := 0
		for candidate in session.all_nodes():
			if candidate is SkillTreeNodeData:
				prerequisite_references += 1 if candidate.prerequisite_node_ids.has(target.upgrade_id) else 0
				exclusion_references += 1 if candidate.excluded_node_ids.has(target.upgrade_id) else 0
		confirm_dialog.dialog_text = "Changer cet identifiant mettra à jour tous les prérequis et exclusions connus.\n\nAncien : %s\nNouveau : %s\n\nRapport : %d prérequis et %d exclusion(s)." % [
			target.upgrade_id, new_node_id, prerequisite_references, exclusion_references,
		]
		confirm_dialog.ok_button_text = "Mettre à jour les références"
		_pending_confirm_action = func():
			if not session.rename_node_id(target, new_node_id):
				_show_status("Renommage refusé", "L’identifiant est vide ou déjà utilisé.")
			_refresh_document()
		confirm_dialog.popup_centered()
		return
	if target is SkillUpgradeData and property_name == &"rank":
		if not session.move_node(target, int(value)):
			_show_status("Déplacement refusé", "Choisissez un rang existant supérieur au rang 1.")
		return
	if target is SkillUpgradeData and property_name == &"target_spell_id":
		session.change_node_target_spell(target, StringName(value))
		return
	if target is Spell and property_name == &"spell_id":
		var new_spell_id := StringName(value)
		if _project_id_collision("spell", new_spell_id):
			_show_status("Renommage refusé", "Cet identifiant de sort existe déjà dans un autre personnage du projet.")
			return
		confirm_dialog.dialog_text = "Changer cet identifiant mettra à jour toutes les améliorations qui ciblent ce sort.\n\nAncien : %s\nNouveau : %s\n\nUne sauvegarde de partie existante peut encore conserver l’ancien identifiant." % [
			target.get_effective_spell_id(), new_spell_id,
		]
		confirm_dialog.ok_button_text = "Mettre à jour les références"
		_pending_confirm_action = func():
			if not session.rename_spell_id(target, new_spell_id):
				_show_status("Renommage refusé", "L’identifiant est vide ou déjà utilisé.")
		confirm_dialog.popup_centered()
		return
	if target is UnitData and property_name == &"unit_id":
		if _project_id_collision("unit", StringName(value)):
			_show_status("Renommage refusé", "Cet identifiant de personnage existe déjà dans le projet.")
			return
		confirm_dialog.dialog_text = "L’identifiant du personnage peut être utilisé par les sauvegardés, les scènes, les tests et les thèmes.\n\nAncien : %s\nNouveau : %s\n\nLe Studio ne peut mettre à jour que les références contenues dans les Resources ouvertes." % [
			target.get_effective_unit_id(), StringName(value),
		]
		confirm_dialog.ok_button_text = "Changer malgré l’avertissement"
		_pending_confirm_action = func():
			session.change_property(target, property_name, StringName(value), action_name)
		confirm_dialog.popup_centered()
		return
	session.change_property(target, property_name, value, action_name)


func _add_prerequisite(child: SkillTreeNodeData, parent: SkillUpgradeData) -> void:
	if not session.add_prerequisite(child, parent):
		_show_status("Connexion refusée", "Un prérequis doit appartenir à un rang inférieur et ne peut pas être dupliqué.")


func _remove_prerequisite(child: SkillTreeNodeData, parent_id: StringName) -> void:
	session.remove_prerequisite(child, parent_id)


func _show_node_dialog(rank: int) -> void:
	if session.current_discipline() == null:
		return
	_pending_parent_node = null
	node_name_edit.text = ""
	node_rank_spin.max_value = _maximum_rank()
	node_rank_spin.value = clampi(rank, 2, _maximum_rank())
	node_dialog.popup_centered(Vector2i(520, 260))
	node_name_edit.grab_focus()


func _show_child_node_dialog(parent: SkillUpgradeData, rank: int) -> void:
	_show_node_dialog(rank)
	_pending_parent_node = parent
	node_dialog.dialog_text = "Cette amélioration sera créée au rang %d avec « %s » comme prérequis." % [
		rank, parent.display_name,
	]


func _create_node() -> void:
	var node := session.add_node(
		int(node_rank_spin.value), node_name_edit.text, _pending_parent_node
	)
	if node == null:
		_show_status("Création impossible", "Le rang choisi n’existe pas ou le document n’est pas prêt.")
	_pending_parent_node = null
	node_dialog.dialog_text = ""


func _show_branch_dialog(rank: int) -> void:
	_pending_branch_rank = clampi(rank, 2, _maximum_rank())
	branch_name_edit.text = ""
	branch_dialog.dialog_text = "Départ : rang %d · arrivée : rang %d" % [
		_pending_branch_rank, _maximum_rank(),
	]
	branch_dialog.popup_centered(Vector2i(560, 280))
	branch_name_edit.grab_focus()


func _create_branch() -> void:
	var created := session.add_linear_branch(branch_name_edit.text, _pending_branch_rank)
	if created.is_empty():
		_show_status("Création impossible", "Aucun rang compatible n’est disponible pour cette branche.")


func _confirm_delete_nodes(nodes: Array[SkillUpgradeData]) -> void:
	if nodes.is_empty():
		return
	var affected_prerequisites := 0
	var affected_exclusions := 0
	var removed_ids: Array[StringName] = []
	var names := PackedStringArray()
	for node in nodes:
		removed_ids.append(node.upgrade_id)
		names.append(node.display_name)
	for candidate in session.all_nodes():
		if candidate is SkillTreeNodeData:
			for node_id in removed_ids:
				affected_prerequisites += 1 if candidate.prerequisite_node_ids.has(node_id) else 0
				affected_exclusions += 1 if candidate.excluded_node_ids.has(node_id) else 0
	var paths_lost := SkillTreePathService.final_configurations(
		session.current_discipline()
	).filter(func(configuration: Array) -> bool:
		return removed_ids.any(func(node_id): return configuration.has(node_id))
	).size()
	confirm_dialog.dialog_text = "Supprimer %d amélioration(s) ?\n\n%s\n\nPrérequis reconnectés ou retirés : %d\nExclusions retirées : %d\nChemins finaux concernés : %d\n\nLes descendants seront reconnectés aux prérequis encore valides. Les fichiers externes éventuels ne seront pas effacés automatiquement du disque." % [
		nodes.size(), "\n".join(names), affected_prerequisites, affected_exclusions,
		paths_lost,
	]
	confirm_dialog.ok_button_text = "Supprimer et reconnecter"
	_pending_confirm_action = func(): session.remove_nodes(nodes)
	confirm_dialog.popup_centered()


func _add_modifier(node: SkillUpgradeData) -> void:
	session.add_default_modifier(node)


func _remove_modifier(node: SkillUpgradeData, modifier: SpellModifier) -> void:
	confirm_dialog.dialog_text = "Retirer l’effet « %s » de cette amélioration ?\nCette action pourra être annulée." % modifier.modifier_name
	confirm_dialog.ok_button_text = "Retirer l’effet"
	_pending_confirm_action = func(): session.remove_modifier(node, modifier)
	confirm_dialog.popup_centered()


func _show_new_discipline_dialog() -> void:
	if session.working_unit == null:
		return
	discipline_name_edit.text = ""
	discipline_id_edit.text = "%s_" % session.working_unit.get_effective_unit_id()
	discipline_dialog.popup_centered(Vector2i(560, 300))
	discipline_name_edit.grab_focus()


func _create_discipline() -> void:
	var discipline := session.add_discipline(
		discipline_name_edit.text, StringName(discipline_id_edit.text.strip_edges())
	)
	if discipline == null:
		_show_status("Création impossible", "L’identifiant est vide ou déjà utilisé.")


func _duplicate_discipline() -> void:
	var copy := session.duplicate_current_discipline()
	if copy == null:
		_show_status("Duplication impossible", "Sélectionnez d’abord une discipline.")


func _rename_discipline_display() -> void:
	var discipline := session.current_discipline()
	if discipline != null:
		session.select_subject(discipline)
		status_label.text = "Modifiez « Nom affiché » à droite. L’identifiant stable restera inchangé."


func _confirm_detach_discipline() -> void:
	var discipline := session.current_discipline()
	if discipline == null:
		return
	confirm_dialog.dialog_text = "Retirer « %s » du personnage ?\n\nLa discipline et son sort de base ne seront plus référencés après sauvegarde. Leurs fichiers existants ne seront pas supprimés du disque." % discipline.display_name
	confirm_dialog.ok_button_text = "Retirer du personnage"
	_pending_confirm_action = func(): session.detach_current_discipline()
	confirm_dialog.popup_centered()


func _refresh_document() -> void:
	if _loading:
		return
	_loading = true
	validation_messages = SkillTreeEditorValidator.validate_unit(
		session.working_unit, production_profile, heroes, _validation_roots()
	) if session.working_unit != null else []
	_refresh_catalog()
	_rebuild_rank_bar()
	var graph_state := graph.get_graph_state() if graph.discipline == session.current_discipline() \
		else SkillTreeUiStateService.load_graph_state(session.selected_discipline_id)
	graph.display(
		session.current_discipline(), session.current_spell(),
		validation_messages, graph_state
	)
	bottom.set_context(session.current_discipline(), validation_messages)
	_refresh_inspector()
	_refresh_history()
	var summary := SkillTreeEditorValidator.summary(validation_messages)
	if session.working_unit != null:
		var authority_label := "Profil de progression" \
			if session.is_profile_authoritative() else "Fiche générale"
		document_label.text = "%s%s" % [
			"%s · %s · %s" % [
				project_context.active_run.run_name if project_context != null \
					and project_context.active_run != null else "Legacy",
				session.working_unit.unit_name,
				authority_label,
			],
			" · MODIFIÉ" if session.is_dirty() else "",
		]
		status_label.text = "%d erreur(s) · %d avertissement(s) · %s" % [
			summary.get("errors", 0), summary.get("warnings", 0),
			"modifications non sauvegardées" if session.is_dirty() else "document sauvegardé",
		]
		if project_context != null:
			project_context.set_dirty(&"skills", session.is_dirty(), {
				"profile_path": session.canonical_source_path(),
				"character_id": str(session.working_unit.get_effective_unit_id()),
			})
	if sandbox_reset_button != null:
		sandbox_reset_button.visible = _tutorial_sandbox_is_active()
	if global_unit_button != null:
		global_unit_button.visible = session.working_unit != null
		global_unit_button.disabled = session.working_unit == null \
			or not session.is_profile_authoritative()
	_update_screen_buttons()
	_refresh_animation_screen()
	_refresh_character_screen()
	_loading = false


func _refresh_inspector() -> void:
	if inspector == null:
		return
	# Le sort possède déjà son éditeur complet derrière « Modifier le sort »
	# dans la fiche Personnage. Le répéter à droite de l'arbre réduit inutilement
	# la surface du graphe. L'inspecteur reste disponible pour les disciplines,
	# rangs, améliorations et effets qui ne disposent pas de cet autre éditeur.
	inspector.visible = current_screen == SCREEN_SKILLS \
		and not session.selected_subject is Spell
	if not inspector.visible:
		return
	inspector.set_context(
		session.working_unit, session.current_discipline(), session.current_spell(),
		session.selected_subject, validation_messages, guided
	)


func _refresh_catalog() -> void:
	if catalog == null:
		return
	catalog.set_catalog(
		heroes,
		_current_catalog_path(),
		session.selected_discipline_id,
		session.is_dirty()
	)
	catalog.set_guided(guided)
	if search_dialog != null:
		search_dialog.set_catalog(heroes)


func _refresh_history() -> void:
	if undo_button == null:
		return
	undo_button.disabled = not session.history_can_undo()
	redo_button.disabled = not session.history_can_redo()
	undo_button.tooltip_text = "Annuler : %s" % session.history_undo_name() \
		if session.history_can_undo() else "Rien à annuler"
	save_button.disabled = session.working_unit == null or not session.is_dirty()


func _rebuild_rank_bar() -> void:
	for child in rank_bar.get_children():
		rank_bar.remove_child(child)
		child.queue_free()
	var discipline := session.current_discipline()
	if discipline == null:
		return
	var label := Label.new()
	label.text = "Rangs :"
	rank_bar.add_child(label)
	var ranks := discipline.ranks.duplicate()
	ranks.sort_custom(func(a, b): return a != null and (b == null or a.rank < b.rank))
	for rank_data in ranks:
		if rank_data == null:
			continue
		var button := Button.new()
		button.text = "R%d · %d XP · %d choix" % [
			rank_data.rank, rank_data.required_total_xp, rank_data.choices.size(),
		]
		button.tooltip_text = "Modifier le seuil d’XP cumulé du rang %d." % rank_data.rank
		button.pressed.connect(func(): session.select_subject(rank_data))
		rank_bar.add_child(button)
	var add := Button.new()
	add.text = "+ Amélioration"
	add.tooltip_text = "Ajoute un nœud dans un rang existant."
	add.pressed.connect(_show_node_dialog.bind(2))
	rank_bar.add_child(add)
	var add_rank := Button.new()
	add_rank.text = "+ Rang"
	add_rank.tooltip_text = "Ajoute un rang après le dernier avec un seuil d’XP progressif."
	add_rank.pressed.connect(func(): session.add_rank())
	rank_bar.add_child(add_rank)
	var remove_rank := Button.new()
	remove_rank.text = "− Dernier rang"
	remove_rank.tooltip_text = "Retire le dernier rang après avoir annoncé ses améliorations."
	remove_rank.pressed.connect(_confirm_remove_last_rank)
	rank_bar.add_child(remove_rank)
	var preset := Button.new()
	preset.text = "Preset 0/5/12/21/30"
	preset.tooltip_text = "Applique le preset Dungeon Draft actuel à une discipline de cinq rangs."
	preset.disabled = discipline.ranks.size() != 5
	preset.pressed.connect(func(): session.apply_current_xp_preset())
	rank_bar.add_child(preset)
	var distribute := Button.new()
	distribute.text = "Répartir l’XP"
	distribute.tooltip_text = "Répartit régulièrement les seuils entre zéro et le dernier seuil actuel."
	distribute.pressed.connect(func(): session.distribute_xp_automatically())
	rank_bar.add_child(distribute)
	var organize := Button.new()
	organize.text = "Organiser"
	organize.tooltip_text = "Replace visuellement les nœuds sans changer le gameplay."
	organize.pressed.connect(graph.organize)
	rank_bar.add_child(organize)


func _confirm_remove_last_rank() -> void:
	var discipline := session.current_discipline()
	if discipline == null or discipline.ranks.size() <= 1:
		_show_status("Suppression impossible", "Une discipline doit conserver au moins son rang 1.")
		return
	var last_rank: DisciplineRankData = null
	for rank_data in discipline.ranks:
		if rank_data != null and (last_rank == null or rank_data.rank > last_rank.rank):
			last_rank = rank_data
	if last_rank == null:
		return
	confirm_dialog.dialog_text = "Supprimer le rang %d ?\n\n%d amélioration(s) seront retirées de l’arbre. Les exclusions qui les citent seront nettoyées. Cette action pourra être annulée." % [
		last_rank.rank, last_rank.choices.size(),
	]
	confirm_dialog.ok_button_text = "Supprimer le dernier rang"
	_pending_confirm_action = func(): session.remove_last_rank()
	confirm_dialog.popup_centered()


func _focus_diagnostic(message: SkillTreeValidationMessage) -> void:
	if message.subject_id != &"":
		var node := session.find_node(message.subject_id)
		if node != null:
			graph.focus_subject(message.subject_id)
			return
		if message.subject_id == session.selected_discipline_id:
			session.select_subject(session.current_discipline())
	if message.rank > 0:
		for rank_data in session.current_discipline().ranks:
			if rank_data != null and rank_data.rank == message.rank:
				session.select_subject(rank_data)
				return


func _validate() -> void:
	commit_pending_edits()
	_refresh_document()
	bottom.current_tab = 0
	# Régler l'onglet sur sa valeur actuelle n'émet aucun signal : on déplie
	# explicitement, sinon le résultat demandé resterait caché.
	analysis_drawer.open()
	var summary := SkillTreeEditorValidator.summary(validation_messages)
	status_label.text = "Validation terminée : %d erreur(s), %d avertissement(s)." % [
		summary.get("errors", 0), summary.get("warnings", 0),
	]


func _test() -> void:
	commit_pending_edits()
	_refresh_document()
	bottom.select_simulator_tab()
	analysis_drawer.open()
	status_label.text = "Simulation isolée ouverte. Elle ne modifie aucune partie réelle."


func _preview_runtime() -> void:
	commit_pending_edits()
	var spell := session.current_spell()
	if spell == null:
		_show_status("Prévisualisation impossible", "La discipline sélectionnée ne possède pas de sort racine.")
		return
	var modifiers: Array[SpellModifier] = []
	var subject := session.selected_subject
	if subject is SkillUpgradeData:
		for modifier in (subject as SkillUpgradeData).spell_modifiers:
			if modifier != null:
				modifiers.append(modifier)
	elif subject is SpellModifier:
		modifiers.append(subject)
	var report := SkillTreeRuntimePreviewService.preview(spell, modifiers)
	bottom.set_preview(report)
	analysis_drawer.open()
	status_label.text = "Prévisualisation runtime terminée : %d scénario(s), %d modificateur(s)." % [
		(report.get("scenarios", []) as Array).size(), modifiers.size(),
	]


func _run_full_analysis() -> void:
	commit_pending_edits()
	var discipline := session.current_discipline()
	if discipline == null:
		return
	status_label.text = "Analyse complète en cours…"
	var report := SkillTreeDesignAnalysisService.analyze(discipline)
	bottom.set_analysis(report)
	analysis_drawer.open()
	status_label.text = "Analyse complète terminée en %.2f ms." % (
		float(report.get("duration_usec", 0)) / 1000.0
	)


func _compare_with_other_run() -> void:
	if project_context == null or project_context.active_run == null \
			or project_context.active_hero == null:
		_show_status("Comparaison impossible", "Aucun contexte partie/héros actif.")
		return
	compare_run_option.clear()
	for run_data in RunContentCatalogService.discover_runs():
		if run_data == null or run_data == project_context.active_run:
			continue
		compare_run_option.add_item(run_data.run_name)
		compare_run_option.set_item_metadata(compare_run_option.item_count - 1, run_data)
		compare_run_option.set_item_tooltip(
			compare_run_option.item_count - 1, run_data.resource_path
		)
	if compare_run_option.item_count == 0:
		_show_status("Comparaison impossible", "Aucune autre partie n'est disponible.")
		return
	compare_summary_label.text = "Partie active : %s\nHéros : %s\n\nChoisissez la partie de référence. La comparaison ne changera pas le contexte." % [
		project_context.active_run.run_name,
		project_context.active_hero.base_unit_data.unit_name \
			if project_context.active_hero.base_unit_data != null \
			else str(project_context.active_hero.character_id),
	]
	compare_run_option.select(0)
	compare_dialog.popup_centered(Vector2i(560, 260))


func _compare_selected_run() -> void:
	if project_context == null or project_context.active_run == null \
			or project_context.active_hero == null or compare_run_option.item_count == 0:
		return
	var other := compare_run_option.get_selected_metadata() as RunData
	if other == null:
		_show_status("Comparaison impossible", "La partie de référence est introuvable.")
		return
	var report := SkillTreeRunComparisonService.compare(
		project_context.active_run, other, project_context.active_hero.character_id
	)
	_show_status(
		"Comparaison · %s ↔ %s" % [project_context.active_run.run_name, other.run_name],
		SkillTreeRunComparisonService.format_report(report)
	)


func _show_orphans() -> void:
	if session.working_unit == null:
		return
	var candidates: Array[Resource] = []
	for work_value in session.source_to_work.values():
		var work := work_value as Resource
		if work != null:
			candidates.append(work)
	for resource_value in session.new_resource_paths:
		var resource := resource_value as Resource
		if resource != null and not candidates.has(resource):
			candidates.append(resource)
	var index := SkillTreeReferenceIndex.new().build(session.working_unit, candidates)
	orphan_dialog.set_records(index.orphaned_resources())
	orphan_dialog.popup_centered_ratio(0.78)


func _handle_orphan_action(
		action: StringName, record: Dictionary, confirmation_token: String
	) -> void:
	var resource := record.get("resource") as Resource
	if resource == null:
		return
	var candidates: Array[Resource] = []
	for work_value in session.source_to_work.values():
		if work_value is Resource:
			candidates.append(work_value)
	var index := SkillTreeReferenceIndex.new().build(session.working_unit, candidates)
	var report := {}
	match action:
		&"ADOPT":
			report = SkillTreeLifecycleService.adopt_discipline(session, resource as DisciplineData)
		&"ARCHIVE":
			report = SkillTreeLifecycleService.archive_resource(resource, index)
		&"DELETE":
			report = SkillTreeLifecycleService.delete_permanently(
				resource, index, confirmation_token
			)
	if report.get("ok", false):
		orphan_dialog.hide()
		_refresh_document()
		status_label.text = "Opération %s terminée ; une récupération est disponible si un fichier a été retiré." % action
	else:
		_show_status("Opération refusée", str(report.get("error", "Erreur inconnue.")))


func _save() -> Dictionary:
	commit_pending_edits()
	_save_graph_state()
	var sandbox_prepare := _prepare_tutorial_sandbox_for_save()
	if not bool(sandbox_prepare.get("ok", false)):
		var preparation_failure := {
			"ok": false,
			"step": "SANDBOX_PATHS",
			"error": str(sandbox_prepare.get("error", "Chemins sandbox invalides.")),
		}
		_show_status("Sauvegarde impossible", str(preparation_failure.error))
		return preparation_failure
	var sandbox_active := _tutorial_sandbox_is_active()
	var result := SkillTreeSaveService.save(
		session, editor_interface, _save_options()
	)
	if not result.get("ok", false) \
			and str(result.get("error", "")).strip_edges().is_empty():
		result["step"] = str(result.get("step", "INTERRUPTED"))
		result["error"] = (
			"La transaction a été interrompue avant de renvoyer son résultat. "
			+ "Le fichier peut déjà correspondre aux modifications : rouvrez le "
			+ "document avant de réessayer."
		)
	if result.get("ok", false):
		if sandbox_active:
			_tutorial_sandbox_service.call("configure_session", session)
			_upsert_tutorial_catalog_entry(
				_tutorial_sandbox_service.call("catalog_entry", session)
			)
		else:
			heroes = _run_hero_catalog() if project_context != null \
				else SkillTreeCatalogService.discover_units()
		_refresh_document()
		status_label.text = str(result.get("message", "Sauvegarde terminée."))
	else:
		if result.has("validation"):
			validation_messages = result.validation
			bottom.set_context(session.current_discipline(), validation_messages)
			bottom.current_tab = 0
		_show_status("Sauvegarde impossible", str(result.get("error", "Erreur inconnue.")))
	return result


func _request_save_review(
		post_save_action: Callable = Callable(),
		apply_save := true
	) -> void:
	commit_pending_edits()
	var sandbox_prepare := _prepare_tutorial_sandbox_for_save()
	if not bool(sandbox_prepare.get("ok", false)):
		_show_status(
			"Sauvegarde impossible",
			str(sandbox_prepare.get("error", "Chemins sandbox invalides."))
		)
		return
	_refresh_document()
	if SkillTreeEditorValidator.has_errors(validation_messages):
		bottom.current_tab = 0
		_show_status("Sauvegarde impossible", "Corrigez les erreurs bloquantes avant de revoir le plan.")
		return
	_post_save_action = post_save_action
	_review_applies_save = apply_save
	var plan := SkillTreeSaveTransactionService.build_plan(session, _save_options())
	if not session.is_dirty():
		_apply_post_save_action()
		return
	save_plan_dialog.get_ok_button().text = (
		"Appliquer la transaction" if apply_save else "Approuver et continuer"
	)
	save_plan_dialog.set_plan(plan)
	save_plan_dialog.popup_centered_ratio(0.82)


func _apply_reviewed_save() -> void:
	if not _review_applies_save:
		_review_applies_save = true
		_apply_post_save_action()
		return
	var result := _save()
	if result.get("ok", false):
		_apply_post_save_action()


func _cancel_save_review() -> void:
	_post_save_action = Callable()
	_review_applies_save = true
	_context_review_pending = false


func _apply_post_save_action() -> void:
	if _post_save_action.is_valid():
		var action := _post_save_action
		_post_save_action = Callable()
		action.call()


func _navigate_to_logical_owner(owner: String) -> void:
	if owner.begins_with("node:"):
		graph.focus_subject(StringName(owner.trim_prefix("node:")))
	elif owner.begins_with("discipline:"):
		session.select_discipline(StringName(owner.trim_prefix("discipline:").get_slice("/", 0)))


func _undo() -> void:
	if session.history_undo():
		_refresh_document()


func _redo() -> void:
	if session.history_redo():
		_refresh_document()


func _set_guided(value: bool) -> void:
	guided = value
	production_toggle.visible = not guided and current_screen == SCREEN_SKILLS
	_refresh_inspector()
	_refresh_catalog()
	_refresh_animation_screen()
	_refresh_character_screen()
	status_label.text = "Mode guidé actif : les explications et exemples sont visibles." \
		if guided else "Mode avancé actif : tous les paramètres techniques sont accessibles."


func _activate_step(index: int) -> void:
	status_label.text = _step_help(index)
	match index:
		0, 1:
			session.select_subject(session.working_unit)
		2:
			session.select_subject(session.current_discipline())
		3:
			session.select_subject(session.current_spell())
		4:
			var discipline := session.current_discipline()
			if discipline != null and not discipline.ranks.is_empty():
				session.select_subject(discipline.ranks[0])
		5:
			_show_node_dialog(2)
		6:
			graph.grab_focus()
		7:
			var node := session.selected_subject as SkillUpgradeData
			if node != null:
				if node.spell_modifiers.is_empty():
					_add_modifier(node)
				else:
					session.select_subject(node.spell_modifiers[0])
		8:
			_test()
		9:
			_request_save_review()


func _step_help(index: int) -> String:
	var descriptions := [
		"Choisissez le héros dont vous voulez modifier les données.",
		"Réglez ses PV, PA, PM, initiative, attaque et défenses de base.",
		"Choisissez ou créez le chemin de progression associé à un sort.",
		"Vérifiez le sort racine que les améliorations vont transformer.",
		"Définissez les seuils d’XP cumulés de chaque rang.",
		"Ajoutez les choix proposés au joueur.",
		"Reliez les prérequis. Plusieurs liaisons sont toutes obligatoires.",
		"Décrivez les transformations du sort avec des modificateurs.",
		"Essayez l’arbre sans modifier la progression réelle.",
		"Validez puis enregistrez les vraies Resources avec une récupération.",
	]
	return descriptions[clampi(index, 0, descriptions.size() - 1)]


func _save_graph_state() -> void:
	if graph != null and session.selected_discipline_id != &"":
		SkillTreeUiStateService.save_graph_state(
			session.selected_discipline_id, graph.get_graph_state()
		)


func _show_status(title: String, text: String) -> void:
	status_dialog.title = title
	status_dialog.dialog_text = text
	status_dialog.popup_centered()


func _maximum_rank() -> int:
	var result := 2
	var discipline := session.current_discipline()
	if discipline != null:
		for rank_data in discipline.ranks:
			if rank_data != null:
				result = maxi(result, rank_data.rank)
	return result


## Personnage préchargé quand aucun n'a encore été ouvert. On préfère un
## personnage déjà pourvu de disciplines : un châssis expérimental encore vide
## donnerait un écran Compétences désert au premier lancement.
func _default_hero_path() -> String:
	for entry in heroes:
		if not bool(entry.get("is_enemy", false)) \
				and int(entry.get("discipline_count", 0)) > 0:
			return str(entry.get("path", ""))
	return str(heroes[0].get("path", "")) if not heroes.is_empty() else ""


func _catalog_contains_path(path: String) -> bool:
	return not path.is_empty() and heroes.any(func(entry: Dictionary) -> bool:
		return str(entry.get("path", "")) == path
	)


func _project_id_collision(kind: String, value: StringName) -> bool:
	var current_path := _current_catalog_path()
	return value != &"" and SkillTreeReferenceIndex.project_id_exists(
		heroes, kind, value, current_path
	)


func _open_search_result(result: Dictionary) -> void:
	# Un résultat de recherche désigne toujours un élément de l'écran
	# Compétences : on l'affiche pour que la sélection reste visible.
	_show_screen(SCREEN_SKILLS)
	var path := str(result.get("character_path", ""))
	var discipline_id := StringName(result.get("discipline_id", &""))
	_pending_search_result = result.duplicate(true)
	var authority := _authority_for_search_result(result)
	if not authority.is_empty() and not _authority_is_open(authority):
		_pending_open_discipline_id = discipline_id
		_request_authority(authority)
		return
	if path == _current_catalog_path():
		if discipline_id != &"":
			session.select_discipline(discipline_id)
		_focus_pending_search_result()
		return
	_pending_open_discipline_id = discipline_id
	_request_character_path(path)


func _authority_for_search_result(result: Dictionary) -> Dictionary:
	var entry := _catalog_entry_for_path(str(result.get("character_path", "")))
	if entry.is_empty():
		return {}
	var profile_path := str(result.get("profile_path", ""))
	if not profile_path.is_empty():
		for authority_value in entry.get("profile_authorities", []):
			var authority := authority_value as Dictionary
			if str(authority.get("profile_path", "")) == profile_path:
				return authority
	return RunContentCatalogService.global_unit_authority(
		entry.get("unit_resource", entry.get("resource")) as UnitData
	)


func _focus_pending_search_result() -> void:
	if _pending_search_result.is_empty():
		return
	var node_id := StringName(_pending_search_result.get("node_id", &""))
	var discipline_id := StringName(_pending_search_result.get("discipline_id", &""))
	if discipline_id != &"" and session.selected_discipline_id != discipline_id:
		session.select_discipline(discipline_id)
	if node_id != &"":
		var node := session.find_node(node_id)
		if node != null:
			session.select_subject(node)
			graph.focus_subject(node_id)
	_pending_search_result.clear()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.ctrl_pressed and key.keycode == KEY_F:
		search_dialog.set_catalog(heroes)
		search_dialog.open_and_focus()
		get_viewport().set_input_as_handled()
	elif key.ctrl_pressed and key.keycode == KEY_S:
		_request_save_review()
		get_viewport().set_input_as_handled()
	elif not _text_control_has_focus() and key.ctrl_pressed \
			and key.keycode == KEY_Z and not key.shift_pressed:
		_undo()
		get_viewport().set_input_as_handled()
	elif not _text_control_has_focus() and key.ctrl_pressed \
			and (key.keycode == KEY_Y or key.keycode == KEY_Z and key.shift_pressed):
		_redo()
		get_viewport().set_input_as_handled()


func _autosave_draft() -> void:
	if session.is_dirty():
		last_draft_report = SkillTreeDraftService.write_draft(session)


func _context_save() -> Dictionary:
	if not session.is_dirty():
		return {"ok": true, "message": "Aucun changement à sauvegarder."}
	if _context_review_approved:
		_context_review_approved = false
		return _save()
	if not _context_review_pending:
		_context_review_pending = true
		_request_context_save_review.call_deferred()
	return {
		"ok": false,
		"step": "REVIEW_REQUIRED",
		"error": "La revue détaillée de la sauvegarde est requise.",
	}


func _request_context_save_review() -> void:
	_context_review_pending = false
	_request_save_review(func():
		_context_review_approved = true
		if project_context != null and project_context.has_pending_transition():
			project_context.resolve_pending_transition(StudioProjectContext.ACTION_SAVE)
	, false)


func _context_draft() -> Dictionary:
	last_draft_report = SkillTreeDraftService.write_draft(session)
	return last_draft_report


func _context_discard() -> Dictionary:
	var ok := session.reopen_from_disk()
	if ok:
		_refresh_document()
	return {"ok": ok, "error": "Le profil canonique n'a pas pu être recharge." if not ok else ""}


func _run_hero_catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if project_context == null or project_context.active_run == null:
		return result
	for hero in RunContentCatalogService.heroes_for_run(project_context.active_run):
		if hero == null or hero.base_unit_data == null or hero.progression_profile == null:
			continue
		var view := RunContentCatalogService.as_editable_unit_view(
			hero.base_unit_data, hero.progression_profile
		)
		var authorities := RunContentCatalogService.progression_authorities_for_unit(
			hero.base_unit_data
		)
		result.append({
			"id": hero.character_id,
			"name": hero.base_unit_data.unit_name,
			"path": hero.base_unit_data.resource_path,
			"unit_resource": hero.base_unit_data,
			"unit_path": hero.base_unit_data.resource_path,
			"profile_path": hero.progression_profile.resource_path,
			"progression_profile": hero.progression_profile,
			"hero_profile": hero,
			"hero_path": hero.resource_path,
			"run": project_context.active_run,
			"run_path": project_context.active_run.resource_path,
			"run_name": project_context.active_run.run_name,
			"authority": RunContentCatalogService.AUTHORITY_PROGRESSION_PROFILE,
			"profile_authorities": authorities,
			"resource": view,
			"spell_count": hero.progression_profile.spells.size(),
			"discipline_count": _skill_tree_count(hero.progression_profile.spells),
			"invalid": not hero.validation_errors().is_empty(),
		})
	# Un personnage absent de la partie en cours reste modifiable : on l'ajoute
	# depuis le disque, sans profil de progression. Sans cela, la liste du
	# Studio serait limitée à l'équipe de la partie active.
	var in_run := {}
	for entry in result:
		in_run[StringName(entry.get("id", &""))] = true
	for entry in SkillTreeCatalogService.discover_units():
		if in_run.has(StringName(entry.get("id", &""))):
			continue
		var outside := entry.duplicate()
		outside["outside_run"] = true
		result.append(outside)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0
	)
	return result


func _skill_tree_count(spells: Array[Spell]) -> int:
	var seen := {}
	for spell in spells:
		if spell != null and spell.skill_tree != null:
			seen[spell.skill_tree.get_instance_id()] = true
	return seen.size()


func _current_catalog_path() -> String:
	if session.source_hero_profile != null and session.source_hero_profile.base_unit_data != null:
		return session.source_hero_profile.base_unit_data.resource_path
	return session.source_unit.resource_path if session.source_unit != null else ""


func _offer_draft(source_path: String) -> void:
	_pending_draft = SkillTreeDraftService.latest_for_source(source_path)
	if _pending_draft.is_empty():
		return
	draft_dialog.dialog_text = "Un brouillon non sauvegardé a été trouvé pour ce personnage.\n\nDate : %s\n\nChoisissez Restaurer, Comparer ou Abandonner. Il ne sera jamais restauré silencieusement." % _pending_draft.get("created_at", "inconnue")
	draft_dialog.popup_centered()


func _restore_pending_draft() -> void:
	var result := SkillTreeDraftService.restore(session, _pending_draft)
	if not result.get("ok", false):
		_show_status("Restauration impossible", str(result.get("error", "Erreur inconnue.")))
		return
	_pending_draft.clear()
	_refresh_document()
	status_label.text = "Brouillon restauré dans la version en cours ; aucune source n'a été écrite."


func _text_control_has_focus() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return true
	return focused != null and focused.get_parent() is SpinBox


func _button(
		parent: Node,
		text: String,
		tooltip: String,
		callback: Callable
	) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
