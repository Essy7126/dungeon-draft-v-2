@tool
class_name SkillTreeStudioMain
extends Control

signal close_confirmed

const GUIDE_STEPS := [
	"1 Personnage", "2 Caractéristiques", "3 Discipline", "4 Sort de base",
	"5 Rangs et XP", "6 Améliorations", "7 Branches", "8 Effets",
	"9 Tester", "10 Sauvegarder",
]

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
var catalog: SkillTreeCatalogPanel
var graph: SkillTreeStudioGraphEdit
var inspector: SkillTreeInspectorPanel
var bottom: SkillTreeBottomPanel
var rank_bar: HFlowContainer
var tour: SkillTreeGuidedTour
var status_dialog: AcceptDialog
var confirm_dialog: ConfirmationDialog
var character_dialog: ConfirmationDialog
var close_dialog: ConfirmationDialog
var draft_dialog: ConfirmationDialog
var save_plan_dialog: SkillTreeSavePlanDialog
var search_dialog: SkillTreeGlobalSearchDialog
var orphan_dialog: SkillTreeOrphanDialog
var node_dialog: ConfirmationDialog
var node_name_edit: LineEdit
var node_rank_spin: SpinBox
var discipline_dialog: ConfirmationDialog
var discipline_name_edit: LineEdit
var discipline_id_edit: LineEdit
var branch_dialog: ConfirmationDialog
var branch_name_edit: LineEdit
var _pending_character_path := ""
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
	_build_ui()
	_connect_session()
	_draft_timer = Timer.new()
	_draft_timer.wait_time = 30.0
	_draft_timer.one_shot = false
	_draft_timer.timeout.connect(_autosave_draft)
	add_child(_draft_timer)
	_draft_timer.start()
	heroes = _run_hero_catalog() if project_context != null \
		else SkillTreeCatalogService.discover_heroes()
	_refresh_catalog()
	if project_context != null:
		project_context.hero_changed.connect(_on_context_hero_changed)
		project_context.run_changed.connect(_on_context_run_changed)
		project_context.register_transition_handler(
			&"skills", Callable(self, "_context_save"),
			Callable(self, "_context_draft"), Callable(self, "_context_discard")
		)
		if project_context.active_hero != null:
			call_deferred("_open_context_hero", project_context.active_hero, true)
		return
	var initial_path := str(workspace_state.get("character_path", ""))
	if not _catalog_contains_path(initial_path) and not heroes.is_empty():
		initial_path = str(heroes[0].get("path", ""))
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


func get_state_snapshot() -> Dictionary:
	return {
		"guided": guided,
		"production_profile": production_profile,
		"character_path": session.canonical_source_path(),
		"discipline_id": str(session.selected_discipline_id),
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
	root.add_child(_build_guide_bar())
	var horizontal := HSplitContainer.new()
	horizontal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal.split_offset = 280
	root.add_child(horizontal)
	catalog = SkillTreeCatalogPanel.new()
	catalog.character_requested.connect(_request_character)
	catalog.discipline_requested.connect(_select_discipline)
	catalog.discipline_document_requested.connect(_request_character_discipline)
	catalog.new_discipline_requested.connect(_show_new_discipline_dialog)
	catalog.duplicate_discipline_requested.connect(_duplicate_discipline)
	catalog.rename_discipline_requested.connect(_rename_discipline_display)
	catalog.delete_discipline_requested.connect(_confirm_detach_discipline)
	horizontal.add_child(catalog)
	var center_split := VSplitContainer.new()
	center_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_split.split_offset = 610
	horizontal.add_child(center_split)
	var graph_box := VBoxContainer.new()
	center_split.add_child(graph_box)
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
	center_split.add_child(bottom)
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
	_build_dialogs()


func _build_toolbar() -> Control:
	var panel := PanelContainer.new()
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
	_button(bar, "Rechercher", "Recherche globale (Ctrl+F)", func():
		search_dialog.set_catalog(heroes)
		search_dialog.open_and_focus()
	)
	_button(bar, "Comparer runs", "Comparer ce heros avec la premiere autre run", _compare_with_other_run)
	_button(bar, "Valider", "Expliquer les problèmes sans modifier les données", _validate)
	_button(bar, "Tester", "Ouvrir le simulateur de progression", _test)
	_button(bar, "Prévisualiser", "Comparer le sort via la sandbox runtime réelle", _preview_runtime)
	_button(bar, "Analyse complète", "Énumérer les chemins et lancer les lints de conception", _run_full_analysis)
	_button(bar, "Orphelins", "Lister et gérer les Resources devenues inaccessibles", _show_orphans)
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
	_button(bar, "Visite guidée", "Explique les notions essentielles pas à pas", func(): tour.start())
	return panel


func _build_guide_bar() -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	panel.add_child(box)
	status_label = Label.new()
	status_label.text = "Commencez par choisir un personnage."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)
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
	return panel


func _build_dialogs() -> void:
	tour = SkillTreeGuidedTour.new()
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
		_request_save_review(_open_character.bind(_pending_character_path))
	)
	character_dialog.custom_action.connect(func(action):
		if action == "discard":
			character_dialog.hide()
			if session.source_unit != null:
				SkillTreeDraftService.clear_for_source(session.canonical_source_path())
			_open_character(_pending_character_path)
	)
	add_child(character_dialog)
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
	save_plan_dialog.navigation_requested.connect(_navigate_to_logical_owner)
	add_child(save_plan_dialog)
	search_dialog = SkillTreeGlobalSearchDialog.new()
	search_dialog.result_requested.connect(_open_search_result)
	add_child(search_dialog)
	orphan_dialog = SkillTreeOrphanDialog.new()
	orphan_dialog.action_requested.connect(_handle_orphan_action)
	add_child(orphan_dialog)
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
	if path.is_empty() or path == _current_catalog_path():
		return
	if project_context != null:
		for hero in RunContentCatalogService.heroes_for_run(project_context.active_run):
			if hero != null and hero.base_unit_data != null \
					and hero.base_unit_data.resource_path == path:
				project_context.request_hero(hero.character_id, &"skills")
				return
	if session.is_dirty():
		_pending_character_path = path
		character_dialog.dialog_text = "Le personnage actuel contient des modifications non sauvegardées.\n\nChoisissez si vous voulez les sauvegarder, les abandonner ou rester sur ce personnage."
		character_dialog.popup_centered()
		return
	_open_character(path)


func _open_character(path: String, initial := false) -> void:
	commit_pending_edits()
	if not ResourceLoader.exists(path):
		_show_status("Personnage introuvable", "La Resource n’existe plus : %s" % path)
		return
	_save_graph_state()
	var unit := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as UnitData
	if unit == null or not session.open(unit):
		_show_status("Ouverture impossible", "Le fichier choisi n’est pas un UnitData valide.")
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
	commit_pending_edits()
	_save_graph_state()
	if not session.open_progression(project_context.active_run, hero):
		_show_status(
			"Ouverture impossible",
			"Le profil de progression %s n'est pas exploitable." % hero.character_id
		)
		return
	if initial:
		var remembered := StringName(workspace_state.get("discipline_id", &""))
		if remembered != &"":
			session.select_discipline(remembered)
	status_label.text = "Profil charge depuis la run active. La vue UnitData est non sauvegardable."
	_refresh_document()
	_offer_draft(session.canonical_source_path())


func _on_context_hero_changed(hero: RunHeroProfile) -> void:
	if hero != null:
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
		confirm_dialog.dialog_text = "Changer cet identifiant mettra à jour toutes les références connues dans une seule action.\n\nAncien : %s\nNouveau : %s\n\nRapport :\n• 1 discipline\n• %d amélioration(s)\n• %d sort associé\n\nLes sauvegardes de runs existantes peuvent encore utiliser l’ancien identifiant." % [
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
		confirm_dialog.dialog_text = "Changer cet identifiant mettra à jour toutes les améliorations qui ciblent ce sort.\n\nAncien : %s\nNouveau : %s\n\nUne sauvegarde de run existante peut encore conserver l’ancien identifiant." % [
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
		confirm_dialog.dialog_text = "L’identifiant du personnage peut être utilisé par les sauvegardes, les scènes, les tests et les thèmes.\n\nAncien : %s\nNouveau : %s\n\nLe Studio ne peut mettre à jour que les références contenues dans les Resources ouvertes." % [
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
		session.working_unit, production_profile, heroes
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
		document_label.text = "%s%s" % [
			"%s · %s" % [
				project_context.active_run.run_name if project_context != null \
					and project_context.active_run != null else "Legacy",
				session.working_unit.unit_name,
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
				"character_id": str(project_context.active_hero.character_id) \
					if project_context.active_hero != null else "",
			})
	_loading = false


func _refresh_inspector() -> void:
	if inspector == null:
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
	var summary := SkillTreeEditorValidator.summary(validation_messages)
	status_label.text = "Validation terminée : %d erreur(s), %d avertissement(s)." % [
		summary.get("errors", 0), summary.get("warnings", 0),
	]


func _test() -> void:
	commit_pending_edits()
	_refresh_document()
	bottom.select_simulator_tab()
	status_label.text = "Simulation isolée ouverte. Elle ne modifie aucune run réelle."


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
	status_label.text = "Analyse complète terminée en %.2f ms." % (
		float(report.get("duration_usec", 0)) / 1000.0
	)


func _compare_with_other_run() -> void:
	if project_context == null or project_context.active_run == null \
			or project_context.active_hero == null:
		_show_status("Comparaison impossible", "Aucun contexte run/heros actif.")
		return
	var other: RunData = null
	for run_data in RunContentCatalogService.discover_runs():
		if run_data != project_context.active_run:
			other = run_data
			break
	if other == null:
		_show_status("Comparaison impossible", "Aucune autre run n'est disponible.")
		return
	var report := SkillTreeRunComparisonService.compare(
		project_context.active_run, other, project_context.active_hero.character_id
	)
	_show_status("Comparaison entre runs", SkillTreeRunComparisonService.format_report(report))


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
	var result := SkillTreeSaveService.save(session, editor_interface)
	if result.get("ok", false):
		heroes = _run_hero_catalog() if project_context != null \
			else SkillTreeCatalogService.discover_heroes()
		_refresh_document()
		status_label.text = str(result.get("message", "Sauvegarde terminée."))
	else:
		if result.has("validation"):
			validation_messages = result.validation
			bottom.set_context(session.current_discipline(), validation_messages)
			bottom.current_tab = 0
		_show_status("Sauvegarde impossible", str(result.get("error", "Erreur inconnue.")))
	return result


func _request_save_review(post_save_action: Callable = Callable()) -> void:
	commit_pending_edits()
	_refresh_document()
	if SkillTreeEditorValidator.has_errors(validation_messages):
		bottom.current_tab = 0
		_show_status("Sauvegarde impossible", "Corrigez les erreurs bloquantes avant de revoir le plan.")
		return
	_post_save_action = post_save_action
	var plan := SkillTreeSaveTransactionService.build_plan(session)
	if not session.is_dirty():
		_apply_post_save_action()
		return
	save_plan_dialog.set_plan(plan)
	save_plan_dialog.popup_centered_ratio(0.82)


func _apply_reviewed_save() -> void:
	var result := _save()
	if result.get("ok", false):
		_apply_post_save_action()


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
	production_toggle.visible = not guided
	_refresh_inspector()
	_refresh_catalog()
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
			_save()


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
	var path := str(result.get("character_path", ""))
	var discipline_id := StringName(result.get("discipline_id", &""))
	var current_path := _current_catalog_path()
	_pending_search_result = result.duplicate(true)
	if path == current_path:
		if discipline_id != &"":
			session.select_discipline(discipline_id)
		_focus_pending_search_result()
		return
	_pending_open_discipline_id = discipline_id
	_request_character_path(path)


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
		commit_pending_edits()
		_save()
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
	return _save()


func _context_draft() -> Dictionary:
	last_draft_report = SkillTreeDraftService.write_draft(session)
	return last_draft_report


func _context_discard() -> Dictionary:
	var ok := session.reopen_from_disk()
	if ok:
		_refresh_document()
	return {"ok": ok, "error": "Le profil canonique n'a pas pu etre recharge." if not ok else ""}


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
		result.append({
			"id": hero.character_id,
			"name": hero.base_unit_data.unit_name,
			"path": hero.base_unit_data.resource_path,
			"profile_path": hero.progression_profile.resource_path,
			"resource": view,
			"discipline_count": hero.progression_profile.disciplines.size(),
			"invalid": not hero.validation_errors().is_empty(),
		})
	return result


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
	status_label.text = "Brouillon restauré dans la copie de travail ; aucune source n'a été écrite."


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
