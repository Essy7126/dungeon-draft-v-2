@tool
class_name ArenaStudioMain
extends Control

signal history_state_changed
signal integrate_room_requested(plan: Dictionary)

enum WorkspaceMode {
	EDITOR,
	DYNAMIC_CONSTRUCTION,
	PREVIEW,
}

const TEST_RUNNER_SCENE := "res://addons/dungeon_draft_arena_studio/test/arena_studio_test_runner.tscn"
const TEST_REQUEST := "user://arena_studio/test_request.json"
const TEST_WORK_ROOT := "user://dungeon_draft_studio/arena_studio/tests"
const GUIDED_PREVIEW_TIMEOUT_MS := 30_000
const TERRAIN_SIM_FIREBALL := "res://data/spells/Mage/boule_de_feu.tres"
const TERRAIN_SIM_ICE_WALL := "res://data/spells/mur_de_glace.tres"
const TERRAIN_SIM_WATER := "res://data/terrain/eau.tres"
const TerrainHeaderBarComponent = preload(
	"res://addons/dungeon_draft_arena_studio/ui/terrain/terrain_header_bar.gd"
)
## Vocabulaire utilisateur des outils. Il suit TerrainVocabulary : « Sols » et
## « Points de départ » remplacent « Terrains » et « Spawns » dans tout le
## parcours nominal.
const TOOL_LABELS := [
	"Sélection", "Déplacer la vue", "Ajouter des cases", "Retirer des cases",
	"Bordure", "Murs et obstacles", "Sols", "Points de départ", "Vérification",
	"Transformer la grille",
	"Ancres",
]
const TOOL_HELP := [
	["1", "Sélectionner une cellule", "Annuler la sélection"],
	["2", "Déplacer la vue", "Annuler le déplacement"],
	["3", "Ajouter ou peindre", "Annuler le trait"],
	["4", "Retirer des cellules", "Annuler le trait"],
	["5", "Peindre la bordure", "Annuler le trait"],
	["6", "Placer un obstacle", "Retirer l’obstacle"],
	["7", "Peindre un sol", "Restaurer le sol"],
	["8", "Placer un point de départ", "Retirer le point de départ"],
	["9", "Choisir la case d’origine", "Effacer la vérification"],
	["0", "Déplacer la grille ou une poignée", "Annuler le geste"],
	["A", "Ajouter ou déplacer une ancre", "Supprimer l’ancre"],
]
## Touche de chaque outil, dans l'ordre de TOOL_LABELS. Ce tableau est
## l'autorite unique du raccourci affiche et du raccourci reellement traite par
## _unhandled_key_input() : les deux ne peuvent plus diverger.
const TOOL_SHORTCUT_KEYS := [
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_A,
]
## Compatibilite de creation uniquement. Le navigateur d'autorite est derive
## de StudioProjectContext.active_run.rooms.
const LEGACY_CALIBRATION_TEMPLATES := [
	["Forêt — Gué forestier", &"room_01_forest"],
	["Volcan — Caldeira", &"room_05_volcano"],
	["Espace — Station orbitale", &"room_06_space"],
]
const TEST_CONFIGURATIONS := [
	["Sans personnages", &"no_characters"],
	["Trio de héros", &"hero_trio"],
	["Rencontre réelle", &"real_encounter"],
	["Test des clics", &"clicks"],
	["Test des spawns", &"spawns"],
	["Test de l'occlusion", &"occlusion"],
	["Déplacement", &"movement"],
	["Vue", &"view"],
	["Ligne de vue", &"line_of_sight"],
	["Obstacles", &"obstacles"],
	["Terrains", &"terrains"],
	["Spawns", &"spawns"],
	["Superposition / occlusion", &"y_sort"],
	["Partie complète", &"full_run"],
]

## Libelle affiche de chaque mode visuel. L'index suit strictement
## ArenaDefinition.VisualMode : PAINTED, MODULAR, HYBRID.
const VISUAL_MODE_LABELS := ["Peinte", "Modulaire", "Hybride"]

var arena: ArenaDefinition = null
var edit_session: ArenaEditSession = null
var validation_report: ArenaValidationReport = null
var editor_interface = null
var editor_undo_redo = null
var dirty: bool:
	get:
		return edit_session != null and edit_session.is_dirty()

var canvas: ArenaStudioCanvas
var runtime_preview: ArenaRuntimePreview
var title_label: Label
var status_label: Label

## --- Refonte Terrain : ecrans, rail, palettes et guidage -------------------
var screen_stack: Control
var header_bar: PanelContainer
var home_panel: TerrainHomePanel
var creation_wizard: TerrainCreationWizard
var editor_screen: Control
var workflow_rail: TerrainWorkflowRail
var tool_palette: TerrainToolPalette
var floor_palette: TerrainFloorPalette
var guidance_panel: TerrainGuidancePanel
var validation_panel: TerrainValidationPanel
var finalize_panel: TerrainFinalizePanel
var inspector_panel: TerrainInspectorPanel
var guided_toggle: CheckButton
var preview_option: OptionButton
var document_state_label: Label
var home_button: Button
var new_terrain_button: Button
var open_terrain_button: Button
var inspector_drawer_button: Button
var palette_scroll: ScrollContainer
var glossary_dialog: AcceptDialog

var guided := true
var current_step := TerrainWorkflowService.Step.START
var guidance_visible := true
var _workflow_steps: Array[Dictionary] = []
var _readiness := TerrainWorkflowService.READINESS_INCOMPLETE
var _tested_once := false
var _draft_saved := false
var _integration_label := ""
var _inspector_forced_open := false
var _compact_layout := false
var _shell_toolbar_allowed := true
var _guidance_hidden_for_drawer := false
var library_list: ItemList
var tool_list: ItemList
var active_tool_label: Label
var shape_option: OptionButton
var obstacle_option: OptionButton
var terrain_option: OptionButton
var spawn_option: OptionButton
var dynamic_palette: VBoxContainer
var dynamic_terrain_option: OptionButton
var dynamic_base_terrain_option: OptionButton
var dynamic_wall_option: OptionButton
var dynamic_special_option: OptionButton
var dynamic_document_label: Label
var hybrid_floor_policy_panel: VBoxContainer
var hybrid_floor_policy_option: OptionButton
var dynamic_width_spin: SpinBox
var dynamic_height_spin: SpinBox
var verification_option: OptionButton
var test_configuration_option: OptionButton
var inspector_label: Label
var calibration_label: Label
var advanced_panel: VBoxContainer
var advanced_values: Array[SpinBox] = []
var validation_list: ItemList
var validation_title: Label
var recovery_button: Button
var compare_button: CheckButton
var last_operation_label: Label
var restore_name_edit: LineEdit
var restore_points_list: ItemList
var restore_delete_dialog: ConfirmationDialog
var recovery_restore_dialog: ConfirmationDialog
var _pending_recovery_candidate: Dictionary = {}
var _pending_restore_delete_path := ""
var _pending_vortex_cell := GridTransformService.INVALID_CELL
var terrain_replace_dialog: ConfirmationDialog
var terrain_replace_from: OptionButton
var terrain_replace_to: OptionButton
var terrain_replace_summary: Label
var backdrop_dialog: ConfirmationDialog
var backdrop_source_option: OptionButton
var backdrop_mode_option: OptionButton
var backdrop_summary: Label
var backdrop_compare_slider: HSlider
var backdrop_compare_value_label: Label
var backdrop_state_label: Label
var backdrop_image_dialog: FileDialog
var _backdrop_sources: Array[ArenaBackdropSourceDefinition] = []
var backdrop_transaction := ArenaBackdropTransactionService.new()
var vortex_dialog: ConfirmationDialog
var vortex_network_option: OptionButton
var vortex_summary: Label
var vortex_name_edit: LineEdit
var _active_vortex_network_id: StringName = &""
var _recent_terrain_ids: Array[StringName] = []
var layer_controls := {}
var transform_controls := {}
var transform_panel: VBoxContainer
var angle_mode_option: OptionButton
var new_dialog: ConfirmationDialog
var new_name_edit: LineEdit
var new_id_edit: LineEdit
var new_image_edit: LineEdit
var new_width_spin: SpinBox
var new_height_spin: SpinBox
var new_orientation_option: OptionButton
var new_template_option: OptionButton
var new_visual_mode_option: OptionButton
var image_dialog: FileDialog
var open_dialog: FileDialog
var art_manifest_dialog: FileDialog
var art_reimport_dialog: ConfirmationDialog
var art_floor_policy_option: OptionButton
var _pending_art_directory := ""
var production_dialog: ConfirmationDialog
var production_tabs: TabContainer
var production_name_edit: LineEdit
var production_id_edit: LineEdit
var production_theme_edit: LineEdit
var production_mode_option: OptionButton
var production_destination_edit: LineEdit
var production_run_option: OptionButton
var production_action_option: OptionButton
var production_index_spin: SpinBox
var _production_runs: Array[RunData] = []
var production_summary_text: RichTextLabel
var production_validation_text: RichTextLabel
var production_preview_text: RichTextLabel
var production_plan_text: RichTextLabel
var production_resolution_text: RichTextLabel
var production_resolution_buttons := {}
var production_dashboard_text: RichTextLabel
var production_result_text: RichTextLabel
var destination_panel: PanelContainer
var destination_run_option: OptionButton
var destination_action_option: OptionButton
var destination_room_option: OptionButton
var destination_summary_label: Label
var destination_details_text: RichTextLabel
var destination_integrate_button: Button
var destination_resolve_button: Button
var destination_tour_button: Button
var integration_replace_dialog: ConfirmationDialog
var integration_warning_dialog: ConfirmationDialog
var integration_warning_text: RichTextLabel
var integration_warning_justification: LineEdit
var guided_tour: ArenaStudioGuidedTour
var _destination_runs: Array[RunData] = []
var _destination_syncing := false
var _destination_last_plan := {}
var _production_last_plan := {}
var bundle_resolution_dialog: ConfirmationDialog
var bundle_resolution_confirmation_text: RichTextLabel
var _pending_bundle_resolution_action: StringName = &""
var _integration_running := false
var _pending_integration_warning_flow: StringName = &""
var _pending_integration_warnings: Array[Dictionary] = []
var migration_dialog: ConfirmationDialog
var painted_dynamic_dialog: ConfirmationDialog
var lab_import_dialog: ConfirmationDialog
var lab_import_summary: RichTextLabel
var lab_import_thumbnail: TextureRect
var _pending_migration_arena: ArenaDefinition = null
var _pending_migration_key := ""
var _pending_migration_transfer_id := ""
var top_bar: Control
var root_container: VBoxContainer
var vertical_split: VSplitContainer
var horizontal_split: HSplitContainer
var center_and_right_split: HSplitContainer
var left_panel: Control
var right_panel: Control
var bottom_drawer: VBoxContainer
var bottom_drawer_content: Control
var bottom_drawer_button: Button
var view_stack: Control
var canvas_navigation: Control
var dynamic_mode_button: Button
var focus_map_enabled := false
var workspace_preset := 0
var preview_view := 0
var workspace_mode := WorkspaceMode.EDITOR
var _last_hovered_cell := GridTransformService.INVALID_CELL
var _pre_focus_state := {}

var _fallback_undo := UndoRedo.new()
var _sessions: Dictionary = {}
var _stroke_before := {}
var _stroke_changed := false
var _stroke_cell_count := 0
var _stroke_transform_commit := false
var _history_refresh_suppressed := false
var _verification_source := GridTransformService.INVALID_CELL
var _last_test_log := "Aucun test direct lancé depuis cette session."
var _recovery_timer: Timer
var _transfer_poll_timer: Timer
var _announced_transfer_id := ""
var _painted_logic_only_active := false
var _pending_lab_arena: ArenaDefinition = null
var _pending_lab_manifest := {}
var _pending_lab_transfer_id := ""
var project_context: StudioProjectContext = null
var shared_reference_graph: StudioReferenceGraphService = null
var run_authoring := ArenaRunAuthoringService.new()
var stroke_batch := ArenaStrokeBatchService.new()
var _last_stroke_result := {}


func setup(
		host_editor_interface,
		undo_manager,
		shared_context: StudioProjectContext = null,
		reference_graph: StudioReferenceGraphService = null
	) -> void:
	editor_interface = host_editor_interface
	editor_undo_redo = undo_manager
	project_context = shared_context
	shared_reference_graph = reference_graph


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	_build_dialogs()
	_connect_canvas()
	_recovery_timer = Timer.new()
	_recovery_timer.one_shot = true
	_recovery_timer.wait_time = 0.4
	_recovery_timer.timeout.connect(_flush_recovery)
	add_child(_recovery_timer)
	_transfer_poll_timer = Timer.new()
	_transfer_poll_timer.wait_time = 2.0
	_transfer_poll_timer.timeout.connect(_poll_lab_transfers)
	add_child(_transfer_poll_timer)
	_transfer_poll_timer.start()
	_refresh_recovery_button()
	if project_context != null:
		project_context.context_changed.connect(_refresh_destination_panel.bind())
		project_context.room_changed.connect(_on_context_room_changed)
		project_context.run_changed.connect(_on_context_run_changed)
		project_context.register_transition_handler(
			&"arena", Callable(self, "_context_save"),
			Callable(self, "_context_draft"), Callable(self, "_context_discard"),
			Callable(), Callable(), Callable(),
			Callable(self, "_context_is_dirty"),
			Callable(self, "_context_snapshot"),
			Callable(self, "_context_restore")
		)
		project_context.register_transition_handler(
			&"arena_run", Callable(self, "_context_run_save"),
			Callable(self, "_context_run_draft"), Callable(self, "_context_run_discard"),
			Callable(), Callable(), Callable(),
			Callable(run_authoring, "is_dirty"),
			Callable(run_authoring, "snapshot"),
			Callable(run_authoring, "restore_snapshot")
		)
		if project_context.active_run != null:
			run_authoring.open(project_context.active_run, shared_reference_graph)
		run_authoring.changed.connect(_on_run_authoring_changed)
	_refresh_run_browser()
	_restore_terrain_ui_state()
	ensure_initial_arena_loaded()
	_refresh_destination_panel()
	# L'ouverture automatique de la salle active reste une commodite : elle ne
	# remplace jamais l'accueil, qui reste le point d'entree du domaine.
	show_home()
	call_deferred("_poll_lab_transfers")


func _exit_tree() -> void:
	if project_context != null:
		project_context.unregister_transition_handler(&"arena")
		project_context.unregister_transition_handler(&"arena_run")


func ensure_initial_arena_loaded() -> void:
	if arena != null:
		return
	if project_context != null and _open_context_room(project_context.active_room()):
		return
	if editor_interface == null:
		load_production(&"room_01_forest")
		return
	var filesystem = editor_interface.get_resource_filesystem()
	if filesystem != null and filesystem.is_scanning():
		_set_status("Initialisation du projet en cours — Arena Studio attend la fin du scan.")
		if not filesystem.filesystem_changed.is_connected(_on_initial_filesystem_ready):
			filesystem.filesystem_changed.connect(_on_initial_filesystem_ready)
		return
	load_production(&"room_01_forest")


func _on_initial_filesystem_ready() -> void:
	var filesystem = editor_interface.get_resource_filesystem() if editor_interface != null else null
	if filesystem != null and filesystem.is_scanning():
		return
	if filesystem != null and filesystem.filesystem_changed.is_connected(_on_initial_filesystem_ready):
		filesystem.filesystem_changed.disconnect(_on_initial_filesystem_ready)
	call_deferred("ensure_initial_arena_loaded")


func load_production(arena_id: StringName) -> bool:
	var session_key := "production:%s" % arena_id
	if _sessions.has(session_key):
		_activate_session(_sessions[session_key] as ArenaEditSession)
		_set_status("Terrain repris avec son historique.")
		show_editor()
		return true
	var imported := ArenaLegacyImporter.import_production(arena_id)
	if imported == null:
		_set_status("Impossible d'ouvrir la carte de production demandée.", true)
		return false
	_set_arena(imported, false, session_key)
	_set_status("Carte de production ouverte sans modifier ses ressources sources.")
	return true


func _build_interface() -> void:
	root_container = VBoxContainer.new()
	root_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_container.add_theme_constant_override("separation", 4)
	add_child(root_container)
	_build_shared_controls()
	# Barre historique du Studio : conservee pour la compatibilite des hotes
	# autonomes. StudioWorkspace la masque ; l'en-tete Terrain construit juste
	# apres reste visible dans tous les hotes.
	top_bar = _build_top_bar()
	root_container.add_child(top_bar)
	header_bar = _build_header()
	root_container.add_child(header_bar)

	# Les trois écrans sont des frères directs de la colonne racine : aucun
	# conteneur intermédiaire n'est ajouté, pour que la disposition du canvas
	# se stabilise en une seule passe comme avant la refonte.
	screen_stack = root_container
	home_panel = TerrainHomePanel.new()
	home_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	home_panel.edit_active_room_requested.connect(_on_home_edit_active_room)
	home_panel.create_requested.connect(show_creation_wizard)
	home_panel.open_requested.connect(_show_open_dialog)
	home_panel.sandbox_requested.connect(_start_guided_sandbox)
	home_panel.recent_selected.connect(_on_recent_selected)
	home_panel.glossary_requested.connect(show_glossary)
	root_container.add_child(home_panel)
	creation_wizard = TerrainCreationWizard.new()
	creation_wizard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	creation_wizard.create_confirmed.connect(_create_from_wizard_config)
	creation_wizard.cancelled.connect(show_home)
	creation_wizard.image_requested.connect(_show_image_dialog)
	creation_wizard.hide()
	root_container.add_child(creation_wizard)
	_build_editor_screen()

	status_label = Label.new()
	status_label.text = "Studio Terrain prêt."
	status_label.custom_minimum_size.y = 28
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.76, 0.86, 0.94))
	root_container.add_child(status_label)
	resized.connect(_apply_responsive_layout)
	call_deferred("_apply_responsive_layout")


func _build_editor_screen() -> void:
	vertical_split = VSplitContainer.new()
	vertical_split.name = "TerrainEditorScreen"
	vertical_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vertical_split.split_offset = -42
	# `editor_screen` désigne l'écran d'édition : c'est le split lui-même.
	editor_screen = vertical_split
	root_container.add_child(vertical_split)

	horizontal_split = HSplitContainer.new()
	horizontal_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_split.split_offset = 188
	vertical_split.add_child(horizontal_split)
	left_panel = _build_left_panel()
	horizontal_split.add_child(left_panel)

	center_and_right_split = HSplitContainer.new()
	center_and_right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_and_right_split.split_offset = -324
	horizontal_split.add_child(center_and_right_split)
	center_and_right_split.add_child(_build_canvas_panel())
	right_panel = _build_right_panel()
	center_and_right_split.add_child(right_panel)
	bottom_drawer = _build_bottom_drawer()
	vertical_split.add_child(bottom_drawer)
	inspector_drawer_button = Button.new()
	inspector_drawer_button.name = "TerrainInspectorDrawerButton"
	inspector_drawer_button.text = "Ouvrir l'inspecteur ▸"
	inspector_drawer_button.tooltip_text = (
		"L'inspecteur est replié faute de place : l'ouvrir en tiroir par-dessus le canvas."
	)
	inspector_drawer_button.focus_mode = Control.FOCUS_ALL
	inspector_drawer_button.visible = false
	inspector_drawer_button.pressed.connect(toggle_inspector_drawer)
	root_container.add_child(inspector_drawer_button)


## Controles partages construits une seule fois puis reparentes dans la palette
## contextuelle, l'inspecteur ou l'etape finale selon l'etape ouverte.
func _build_shared_controls() -> void:
	library_list = ItemList.new()
	library_list.name = "TerrainRunRoomList"
	library_list.item_activated.connect(_on_library_activated)
	# Modele interne de l'outil actif. La liste n'est plus affichee : les
	# palettes contextuelles sont l'interface, mais tout le code existant
	# continue de lire et d'ecrire la selection ici.
	tool_list = ItemList.new()
	tool_list.name = "TerrainToolModel"
	tool_list.visible = false
	for index in range(TOOL_LABELS.size()):
		tool_list.add_item(TOOL_LABELS[index])
		tool_list.set_item_tooltip(index, "%s — raccourci %s" % [
			TOOL_LABELS[index], TOOL_HELP[index][0],
		])
	tool_list.select(ArenaStudioCanvas.Tool.SELECT)
	tool_list.item_selected.connect(_on_tool_selected)
	add_child(tool_list)
	shape_option = OptionButton.new()
	shape_option.name = "TerrainShapeOption"
	shape_option.tooltip_text = "Forme du pinceau"
	for label in ["Pinceau continu", "Rectangle", "Remplissage contigu", "Sélection multiple"]:
		shape_option.add_item(label)
	shape_option.item_selected.connect(func(index): canvas.brush_shape = index)
	obstacle_option = OptionButton.new()
	obstacle_option.name = "TerrainObstacleOption"
	obstacle_option.tooltip_text = "Type d'obstacle placé par le pinceau"
	for label in ["Mur complet", "Obstacle bas", "Décor traversable", "Falaise"]:
		obstacle_option.add_item(label)
	terrain_option = OptionButton.new()
	terrain_option.name = "TerrainFloorOption"
	terrain_option.tooltip_text = "Sols permanents autorisés par le terrain courant"
	terrain_option.item_selected.connect(func(_index):
		canvas.set_brush_preview_terrain(StringName(
			terrain_option.get_selected_metadata()
		))
	)
	spawn_option = OptionButton.new()
	spawn_option.name = "TerrainSpawnOption"
	spawn_option.tooltip_text = "Élément placé par l'outil Points de départ"
	for label in [
		"Héros 1 — Elfe", "Héros 2 — Mage", "Héros 3 — Guerrier", "Ennemi",
		"Groupe ennemi", "Zone d'invocation",
	]:
		spawn_option.add_item(label)
	verification_option = OptionButton.new()
	verification_option.name = "TerrainVerificationOption"
	verification_option.add_item("Vérifier les déplacements")
	verification_option.add_item("Tester une ligne de vue")
	verification_option.item_selected.connect(_on_verification_kind_selected)
	test_configuration_option = OptionButton.new()
	test_configuration_option.name = "TerrainTestConfigurationOption"
	for configuration in TEST_CONFIGURATIONS:
		test_configuration_option.add_item(configuration[0])
	dynamic_mode_button = Button.new()
	dynamic_mode_button.name = "TerrainDynamicConstructionButton"
	dynamic_mode_button.text = "Construction dynamique"
	dynamic_mode_button.tooltip_text = (
		"Mode avancé : éditer sols, murs et points de départ comme un document de tuiles."
	)
	dynamic_mode_button.toggle_mode = true
	dynamic_mode_button.focus_mode = Control.FOCUS_ALL
	dynamic_mode_button.pressed.connect(show_dynamic_construction)


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 42
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	panel.add_child(bar)
	title_label = Label.new()
	title_label.text = "DUNGEON DRAFT ARENA STUDIO %s" % StudioVersion.PRODUCT_VERSION
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.52, 0.88, 1.0))
	title_label.custom_minimum_size.x = 260
	bar.add_child(title_label)
	var new_button := _add_button(bar, "+ Nouvelle", _show_new_dialog)
	new_button.tooltip_text = "Créer une nouvelle arène"
	_add_button(bar, "Ouvrir", _show_open_dialog)
	_add_button(bar, "Sauvegarder", save_arena)
	var prepare_button := _add_button(bar, "Préparer", prepare_automatically)
	prepare_button.tooltip_text = "Préparer automatiquement la carte"
	_add_button(bar, "Valider", validate_arena)
	var test_button := _add_button(bar, "▶ Tester", test_arena)
	test_button.tooltip_text = "Tester la version en cours dans la vraie scène"
	var tour_button := _add_button(bar, "? Glossaire", show_glossary)
	tour_button.tooltip_text = "Consulter la définition des mots du Studio Terrain"
	return panel


## En-tete permanent du domaine Terrain. Contrairement a `top_bar`, il n'est
## jamais masque par un hote : c'est lui qui garantit l'acces a l'accueil, a la
## creation, a l'ouverture et au mode guide dans le vrai StudioWorkspace.
func _build_header() -> PanelContainer:
	var header: Variant = TerrainHeaderBarComponent.new()
	header.home_requested.connect(show_home)
	header.create_requested.connect(show_creation_wizard)
	header.open_requested.connect(_show_open_dialog)
	header.guided_toggled.connect(set_guided)
	header.preview_selected.connect(_on_preview_option_selected)
	home_button = header.home_button
	new_terrain_button = header.new_terrain_button
	open_terrain_button = header.open_terrain_button
	guided_toggle = header.guided_toggle
	preview_option = header.preview_option
	document_state_label = header.document_state_label
	return header


## Le rail des etapes remplace la liste plate d'outils dans la colonne gauche.
func _build_left_panel() -> Control:
	workflow_rail = TerrainWorkflowRail.new()
	workflow_rail.step_selected.connect(set_current_step)
	workflow_rail.primary_action_requested.connect(_on_step_primary_action)
	return workflow_rail


func _build_canvas_panel() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guidance_panel = TerrainGuidancePanel.new()
	guidance_panel.continue_requested.connect(_on_guidance_continue)
	guidance_panel.previous_requested.connect(_on_guidance_previous)
	guidance_panel.hidden_requested.connect(func(): set_guidance_visible(false))
	guidance_panel.glossary_requested.connect(show_glossary)
	box.add_child(guidance_panel)
	tool_palette = TerrainToolPalette.new()
	tool_palette.tool_requested.connect(_select_tool_from_palette)
	tool_palette.action_requested.connect(_on_palette_action)
	# La palette est bornée en hauteur et défile : le canvas reste la zone
	# prioritaire, même en 1280 × 720 et même avec une palette de sols riche.
	palette_scroll = ScrollContainer.new()
	palette_scroll.name = "TerrainPaletteScroll"
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	palette_scroll.custom_minimum_size.y = 132
	palette_scroll.size_flags_vertical = Control.SIZE_FILL
	palette_scroll.add_child(tool_palette)
	tool_palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(palette_scroll)
	_populate_tool_palette()
	# Le contrat « OUTIL ACTIF » vit desormais dans la palette contextuelle :
	# une seule etiquette, jamais deux sources de verite.
	active_tool_label = tool_palette.contract_label
	_refresh_active_tool_contract(ArenaStudioCanvas.Tool.SELECT)
	var navigation := HBoxContainer.new()
	canvas_navigation = navigation
	_add_button(navigation, "Recentrer", func(): canvas.recenter_grid())
	_add_button(navigation, "Adapter à l'image", func(): canvas.fit_to_image())
	var hint := Label.new()
	hint.text = "Molette : zoom • Clic milieu : déplacer"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	navigation.add_child(hint)
	box.add_child(navigation)
	view_stack = Control.new()
	view_stack.name = "ViewStack"
	view_stack.custom_minimum_size = Vector2(420, 100)
	view_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(view_stack)
	canvas = ArenaStudioCanvas.new()
	canvas.custom_minimum_size = Vector2(420, 100)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_stack.add_child(canvas)
	runtime_preview = ArenaRuntimePreview.new()
	runtime_preview.name = "ArenaRuntimePreview"
	runtime_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	runtime_preview.hide()
	view_stack.add_child(runtime_preview)
	return box


func _build_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 295
	inspector_panel = TerrainInspectorPanel.new()
	inspector_panel.close_requested.connect(func(): set_inspector_drawer_open(false))
	panel.add_child(inspector_panel)

	# Section « Case survolée » — toujours utile, quelle que soit l'etape.
	inspector_label = Label.new()
	inspector_label.name = "TerrainHoveredCellLabel"
	inspector_label.text = "Survolez une case."
	inspector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_label.custom_minimum_size = Vector2(0, 64)
	inspector_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_panel.host_control(&"selection", inspector_label)

	# Forme
	inspector_panel.host_control(&"shape", _hint_label(
		"Ajoutez ou retirez des cases, puis créez la bordure qui referme la zone."
	))
	inspector_panel.host_control(&"shape", _inspector_button(
		"Préparer automatiquement le terrain", prepare_automatically,
		"Crée une zone jouable, une bordure et des points de départ proposés."
	))
	inspector_panel.host_control(&"shape", _inspector_button(
		"Créer la bordure de sécurité", create_safety_border,
		"Entoure la zone jouable d'une bordure non jouable."
	))

	# Sols
	inspector_panel.host_control(&"floors", _hint_label(
		"Le sol choisi dans la palette est appliqué par le pinceau."
	))
	inspector_panel.host_control(&"floors", terrain_option)
	inspector_panel.host_control(&"floors", _inspector_button(
		"Remplacer un sol par un autre…", _show_terrain_replace_dialog,
		"Échanger partout un type de sol contre un autre."
	))

	# Obstacles et points de depart
	inspector_panel.host_control(&"content", _hint_label(
		"Choisissez ce que pose le pinceau, puis cliquez sur la grille."
	))
	inspector_panel.host_control(&"content", obstacle_option)
	inspector_panel.host_control(&"content", spawn_option)
	inspector_panel.host_control(&"content", _inspector_button(
		"Placer les héros", func(): _select_tool_and_preset(ArenaStudioCanvas.Tool.SPAWN, 0),
		"Sélectionner l'outil Points de départ, réglé sur Héros 1."
	))
	inspector_panel.host_control(&"content", _inspector_button(
		"Placer les ennemis", func(): _select_tool_and_preset(ArenaStudioCanvas.Tool.SPAWN, 4),
		"Sélectionner l'outil Points de départ, réglé sur Groupe ennemi."
	))
	dynamic_palette = _build_dynamic_palette()
	dynamic_palette.hide()
	inspector_panel.host_control(&"content", dynamic_palette)

	# Decor
	calibration_label = Label.new()
	calibration_label.name = "TerrainCalibrationLabel"
	calibration_label.text = "Alignement à vérifier"
	calibration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	calibration_label.custom_minimum_size.y = 40
	calibration_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28))
	inspector_panel.host_control(&"scenery", calibration_label)
	inspector_panel.host_control(&"scenery", _inspector_button(
		"Choisir l'illustration…", _show_backdrop_dialog,
		"Importer ou remplacer l'illustration de fond et le premier plan."
	))
	inspector_panel.host_control(&"scenery", _inspector_button(
		"Aligner la grille en 3 clics", start_calibration,
		"Cliquer trois centres de cases pour poser la grille sur l'illustration."
	))
	inspector_panel.host_control(&"scenery", _inspector_button(
		"Réseaux de vortex…", _show_vortex_dialog,
		"Créer ou modifier les passages de téléportation."
	))

	# Verification
	inspector_panel.host_control(&"verify", _hint_label(
		"Cliquez une case d'origine, puis une case d'arrivée."
	))
	inspector_panel.host_control(&"verify", verification_option)
	inspector_panel.host_control(&"verify", _inspector_button(
		"Vérifier le terrain", validate_arena,
		"Relancer la vérification complète et remplir le tiroir de validation."
	))

	# Etape finale
	finalize_panel = TerrainFinalizePanel.new()
	finalize_panel.draft_requested.connect(save_draft)
	finalize_panel.test_requested.connect(test_arena)
	finalize_panel.integrate_requested.connect(_on_integrate_destination_pressed)
	destination_panel = _build_destination_panel()
	finalize_panel.host_test_control(test_configuration_option)
	finalize_panel.host_destination_control(destination_panel)
	inspector_panel.host_control(&"finalize", finalize_panel)

	# --- Sections avancees -------------------------------------------------
	advanced_panel = VBoxContainer.new()
	advanced_panel.name = "TerrainNumericCalibration"
	var fields := GridContainer.new()
	fields.columns = 2
	for label in ["Origine X", "Origine Y", "Axe droite X", "Axe droite Y", "Axe gauche X", "Axe gauche Y"]:
		var field_label := Label.new()
		field_label.text = label
		fields.add_child(field_label)
		var spin := SpinBox.new()
		spin.min_value = -10000
		spin.max_value = 10000
		spin.step = 0.1
		spin.allow_greater = true
		spin.allow_lesser = true
		advanced_values.append(spin)
		fields.add_child(spin)
	advanced_panel.add_child(fields)
	_add_button(advanced_panel, "Appliquer les valeurs", _apply_advanced_values)
	_add_button(advanced_panel, "Ajuster avec les ancres multipoints", fit_multipoint_calibration)
	inspector_panel.host_control(&"calibration", advanced_panel)
	inspector_panel.host_control(&"calibration", _build_transform_panel())
	inspector_panel.host_control(&"layers", _build_layers_panel())
	inspector_panel.host_control(&"simulation", _build_surface_preview_palette())
	inspector_panel.host_control(&"simulation", dynamic_mode_button)

	library_list.custom_minimum_size.y = 78
	inspector_panel.host_control(&"run", library_list)
	var run_actions := HFlowContainer.new()
	run_actions.add_theme_constant_override("h_separation", 4)
	_add_button(run_actions, "Insérer", func(): _attach_current_arena(true))
	_add_button(run_actions, "Remplacer", func(): _attach_current_arena(false))
	_add_button(run_actions, "Dupliquer", _duplicate_run_room)
	_add_button(run_actions, "Rendre spécifique", _make_run_room_specific)
	_add_button(run_actions, "Monter", func(): _move_run_room(-1))
	_add_button(run_actions, "Descendre", func(): _move_run_room(1))
	_add_button(run_actions, "Retirer", _remove_run_room)
	_add_button(run_actions, "Annuler (partie)", func(): run_authoring.undo())
	_add_button(run_actions, "Rétablir (partie)", func(): run_authoring.redo())
	_add_button(run_actions, "Sauver la partie", _save_run_sequence)
	_add_button(run_actions, "Recharger la partie", _reload_run_sequence)
	inspector_panel.host_control(&"run", run_actions)
	inspector_panel.host_control(&"run", _inspector_button(
		"Enregistrer le terrain comme ressource canonique", save_arena,
		"Écriture transactionnelle dans res://data/arenas, avec plan et rollback."
	))

	var recovery_actions := VBoxContainer.new()
	recovery_actions.add_theme_constant_override("separation", 3)
	_add_button(recovery_actions, "Exporter le rapport", export_report)
	_add_button(recovery_actions, "Copier le rapport pour Codex", copy_report_for_codex)
	recovery_button = _add_button(
		recovery_actions, "Restaurer la récupération", restore_latest_recovery
	)
	recovery_button.tooltip_text = "Restaurer la sauvegarde automatique de récupération"
	inspector_panel.host_control(&"recovery", recovery_actions)
	inspector_panel.host_control(&"recovery", _build_restore_points_panel())
	return panel


func _hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.72, 0.77, 0.84))
	return label


func _inspector_button(label: String, callback: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	return button


# =============================================================================
# Refonte Terrain — ecrans, parcours, guidage et contrats de sauvegarde
# =============================================================================

func _populate_tool_palette() -> void:
	floor_palette = TerrainFloorPalette.new()
	floor_palette.terrain_selected.connect(_select_quick_terrain)
	floor_palette.brush_size_changed.connect(func(size): canvas.brush_size = size)
	tool_palette.host_wide_control(TerrainWorkflowService.Step.FLOORS, floor_palette)
	tool_palette.host_control(TerrainWorkflowService.Step.SHAPE, shape_option)
	tool_palette.add_action_button(
		TerrainWorkflowService.Step.START, &"open_home",
		"Revenir à l'accueil", "Choisir un autre terrain ou en créer un."
	)
	tool_palette.add_action_button(
		TerrainWorkflowService.Step.SCENERY, &"choose_backdrop",
		"Illustration…", "Choisir l'illustration de fond et le premier plan."
	)
	tool_palette.add_action_button(
		TerrainWorkflowService.Step.SCENERY, &"calibrate",
		"Aligner en 3 clics", "Poser la grille sur l'illustration."
	)
	tool_palette.add_action_button(
		TerrainWorkflowService.Step.VERIFY, &"validate",
		"Vérifier le terrain", "Relancer la vérification complète."
	)
	tool_palette.add_action_button(
		TerrainWorkflowService.Step.FINALIZE, &"test",
		"Tester le combat", "Lancer le vrai combat sur la version en cours."
	)


func _on_palette_action(action: StringName) -> void:
	match action:
		&"open_home":
			show_home()
		&"choose_backdrop":
			_show_backdrop_dialog()
		&"calibrate":
			start_calibration()
		&"validate":
			validate_arena()
		&"test":
			test_arena()


func _select_tool_from_palette(tool: int) -> void:
	tool_list.select(tool)
	_on_tool_selected(tool)


## --- Ecrans ----------------------------------------------------------------

func show_home() -> void:
	if screen_stack == null:
		return
	cancel_active_gesture()
	home_panel.refresh({
		"active_room_label": _active_room_label(),
		"active_room_available": not _active_room_label().is_empty(),
		"recents": TerrainStudioUiStateService.recents(),
	})
	home_panel.show()
	creation_wizard.hide()
	editor_screen.hide()
	if inspector_drawer_button != null:
		inspector_drawer_button.hide()
	_set_status("Accueil des terrains — choisissez par quoi commencer.")


func show_creation_wizard() -> void:
	if screen_stack == null:
		return
	cancel_active_gesture()
	creation_wizard.start()
	creation_wizard.set_advanced(not guided)
	home_panel.hide()
	creation_wizard.show()
	editor_screen.hide()
	if inspector_drawer_button != null:
		inspector_drawer_button.hide()
	_set_status("Choisissez comment construire ce terrain.")


func show_editor() -> void:
	if screen_stack == null:
		return
	home_panel.hide()
	creation_wizard.hide()
	editor_screen.show()
	_apply_responsive_layout()


func is_home_visible() -> bool:
	return home_panel != null and home_panel.visible


func _active_room_label() -> String:
	if project_context == null:
		return ""
	var room := project_context.active_room()
	if room == null:
		return ""
	var run_name := "Partie"
	if project_context.active_run != null \
			and not str(project_context.active_run.run_name).strip_edges().is_empty():
		run_name = str(project_context.active_run.run_name)
	return "%s · Salle %d — %s" % [
		run_name, project_context.active_room_index + 1,
		room.room_name if not str(room.room_name).is_empty() else "sans nom",
	]


func _on_home_edit_active_room() -> void:
	if project_context != null and _open_context_room(project_context.active_room()):
		show_editor()
		set_current_step(TerrainWorkflowService.Step.SHAPE)
		return
	_set_status(
		"Aucune salle active n'a pu être ouverte. Créez un terrain ou ouvrez-en un.",
		true
	)


func _on_recent_selected(entry: Dictionary) -> void:
	var session_key := str(entry.get("session_key", ""))
	if _sessions.has(session_key):
		_activate_session(_sessions[session_key] as ArenaEditSession)
		show_editor()
		return
	var path := str(entry.get("path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		_open_canonical(path)
		show_editor()
		return
	_set_status("Ce terrain récent n'est plus disponible.", true)


func show_glossary() -> void:
	if glossary_dialog == null:
		return
	glossary_dialog.popup_centered()


## --- Mode guide / mode avance ---------------------------------------------

func set_guided(value: bool) -> void:
	guided = value
	if guided_toggle != null and guided_toggle.button_pressed != value:
		guided_toggle.set_pressed_no_signal(value)
	_apply_guided_visibility()
	TerrainStudioUiStateService.set_value("guided", guided)
	# Le shell partage la meme notion de mode : dispositions, laboratoire et
	# transferts suivent l'interrupteur du domaine Terrain.
	history_state_changed.emit()
	_set_status(
		"Mode guidé actif : les réglages techniques sont masqués." if guided
		else "Mode avancé actif : tous les réglages techniques sont accessibles."
	)


func is_guided() -> bool:
	return guided


## Renvoie les controles qui ne doivent jamais etre visibles en mode guide.
func advanced_only_controls() -> Array[Control]:
	var result: Array[Control] = []
	for control in [
		advanced_panel, transform_panel, dynamic_mode_button, top_bar,
	]:
		if control != null:
			result.append(control as Control)
	if inspector_panel != null:
		for section_id in inspector_panel.sections:
			var entry := inspector_panel.sections[section_id] as Dictionary
			if bool(entry.advanced):
				result.append(entry.container as Control)
	return result


func _apply_guided_visibility() -> void:
	if inspector_panel != null:
		inspector_panel.set_context(current_step, guided)
	if tool_palette != null:
		tool_palette.set_advanced(not guided)
	if creation_wizard != null:
		creation_wizard.set_advanced(not guided)
	if canvas != null:
		canvas.show_technical = not guided
		canvas.queue_redraw()
	if advanced_panel != null:
		advanced_panel.visible = not guided
	if transform_panel != null:
		transform_panel.visible = not guided \
			and canvas != null \
			and canvas.active_tool == ArenaStudioCanvas.Tool.TRANSFORM_GRID
	if dynamic_mode_button != null:
		dynamic_mode_button.visible = not guided
	if top_bar != null:
		top_bar.visible = _shell_toolbar_allowed and not guided and size.y >= 760.0


func _sync_drawer_split() -> void:
	if vertical_split == null or bottom_drawer_content == null:
		return
	vertical_split.split_offset = -220 if bottom_drawer_content.visible else -42


## --- Parcours --------------------------------------------------------------

func set_current_step(step: int) -> void:
	current_step = clampi(step, 0, TerrainWorkflowService.STEP_COUNT - 1)
	if workflow_rail != null:
		workflow_rail.set_current_step(current_step)
	if tool_palette != null:
		tool_palette.set_active_step(current_step)
	if inspector_panel != null:
		inspector_panel.set_context(current_step, guided)
	TerrainStudioUiStateService.set_value("step", current_step)
	var default_tool := _default_tool_for_step(current_step)
	if default_tool >= 0 and canvas != null and canvas.active_tool != default_tool:
		_select_tool_from_palette(default_tool)
	_refresh_workflow()


func _default_tool_for_step(step: int) -> int:
	match step:
		TerrainWorkflowService.Step.SHAPE:
			return ArenaStudioCanvas.Tool.ADD_CELL
		TerrainWorkflowService.Step.FLOORS:
			return ArenaStudioCanvas.Tool.TERRAIN
		TerrainWorkflowService.Step.CONTENT:
			return ArenaStudioCanvas.Tool.SPAWN
		TerrainWorkflowService.Step.VERIFY:
			return ArenaStudioCanvas.Tool.VERIFY
	return -1


func _step_for_tool(tool: int) -> int:
	match tool:
		ArenaStudioCanvas.Tool.ADD_CELL, ArenaStudioCanvas.Tool.REMOVE_CELL, \
		ArenaStudioCanvas.Tool.BORDER:
			return TerrainWorkflowService.Step.SHAPE
		ArenaStudioCanvas.Tool.TERRAIN:
			return TerrainWorkflowService.Step.FLOORS
		ArenaStudioCanvas.Tool.OBSTACLE, ArenaStudioCanvas.Tool.SPAWN:
			return TerrainWorkflowService.Step.CONTENT
		ArenaStudioCanvas.Tool.TRANSFORM_GRID, ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS:
			return TerrainWorkflowService.Step.SCENERY
		ArenaStudioCanvas.Tool.VERIFY:
			return TerrainWorkflowService.Step.VERIFY
	return -1


func _on_step_primary_action(step: int) -> void:
	match step:
		TerrainWorkflowService.Step.START:
			show_home()
		TerrainWorkflowService.Step.SHAPE:
			_select_tool_from_palette(ArenaStudioCanvas.Tool.ADD_CELL)
		TerrainWorkflowService.Step.FLOORS:
			_select_tool_from_palette(ArenaStudioCanvas.Tool.TERRAIN)
		TerrainWorkflowService.Step.CONTENT:
			_select_tool_and_preset(ArenaStudioCanvas.Tool.SPAWN, 0)
		TerrainWorkflowService.Step.SCENERY:
			_show_backdrop_dialog()
		TerrainWorkflowService.Step.VERIFY:
			validate_arena()
		TerrainWorkflowService.Step.FINALIZE:
			test_arena()


func workflow_steps() -> Array[Dictionary]:
	return _workflow_steps


func readiness() -> String:
	return _readiness


func _refresh_workflow() -> void:
	if workflow_rail == null:
		return
	_workflow_steps = TerrainWorkflowService.evaluate(arena, validation_report, {
		"has_report": validation_report != null,
		"dirty": dirty,
		"is_new_document": edit_session != null and edit_session.is_new_document,
		"tested": _tested_once,
		"integration_label": _integration_label,
	})
	var integration_available := bool(_destination_last_plan.get("can_integrate", false))
	_readiness = TerrainWorkflowService.readiness(
		_workflow_steps, validation_report, integration_available
	)
	workflow_rail.set_steps(_workflow_steps, _readiness)
	if guidance_panel != null and current_step < _workflow_steps.size():
		guidance_panel.show_step(current_step, _workflow_steps[current_step])
		guidance_panel.visible = guidance_visible and not _guidance_hidden_for_drawer
	if validation_panel != null:
		validation_panel.set_report(validation_report, _readiness)
	if finalize_panel != null:
		finalize_panel.set_readiness(_readiness, _integration_detail())
	if document_state_label != null:
		document_state_label.text = "%s — %s" % [
			arena.display_name if arena != null else "Aucun terrain",
			TerrainWorkflowService.document_state_text(
				dirty, _integration_label, _draft_saved
			),
		]


func _integration_detail() -> String:
	if _integration_label.is_empty():
		return "Ce terrain n'a pas encore été intégré à une partie."
	return "Dernière intégration : %s." % _integration_label


## --- Guidage ---------------------------------------------------------------

func set_guidance_visible(value: bool) -> void:
	guidance_visible = value
	if guidance_panel != null:
		guidance_panel.visible = value
	TerrainStudioUiStateService.set_value("guidance_visible", value)
	if not value:
		_set_status(
			"Guidage masqué. Le rail des étapes à gauche continue d'indiquer la suite."
		)


func _on_guidance_continue() -> void:
	set_current_step(mini(current_step + 1, TerrainWorkflowService.STEP_COUNT - 1))


func _on_guidance_previous() -> void:
	set_current_step(maxi(current_step - 1, 0))


## --- Apercu ----------------------------------------------------------------

func _on_preview_option_selected(index: int) -> void:
	if index == ArenaRuntimePreview.ViewMode.LOGIC:
		_show_editor_canvas(workspace_mode == WorkspaceMode.DYNAMIC_CONSTRUCTION)
		preview_view = index
		return
	set_preview_view(index)


## --- Inspecteur en tiroir --------------------------------------------------

func toggle_inspector_drawer() -> void:
	set_inspector_drawer_open(not _inspector_forced_open)


func set_inspector_drawer_open(value: bool) -> void:
	_inspector_forced_open = value
	_apply_responsive_layout()


func inspector_is_reachable() -> bool:
	if right_panel == null:
		return false
	return right_panel.visible \
		or (inspector_drawer_button != null and inspector_drawer_button.visible)


## --- Brouillon -------------------------------------------------------------

func save_draft() -> void:
	if arena == null:
		_set_status("Aucun terrain n'est ouvert.", true)
		return
	var result := ArenaDraftSaveService.save(arena, {
		"session_key": edit_session.session_key if edit_session != null else "",
		"integration_label": _integration_label,
	})
	if not bool(result.get("ok", false)):
		_set_status(
			"Le brouillon n'a pas pu être enregistré : %s" % result.get("error", "erreur"),
			true
		)
		return
	_draft_saved = true
	_refresh_workflow()
	_set_status(
		"Brouillon enregistré dans votre dossier personnel. Aucune partie n'a été modifiée."
	)


## --- Etat persistant -------------------------------------------------------

func _restore_terrain_ui_state() -> void:
	var state := TerrainStudioUiStateService.load_state()
	guidance_visible = bool(state.get("guidance_visible", true))
	set_guided(bool(state.get("guided", true)))
	set_guidance_visible(guidance_visible)
	set_current_step(int(state.get("step", TerrainWorkflowService.Step.START)))
	if preview_option != null:
		preview_option.select(clampi(int(state.get("preview_view", 0)), 0, 2))


func _remember_recent_document() -> void:
	if edit_session == null or arena == null:
		return
	TerrainStudioUiStateService.remember_recent(
		"%s (%d × %d)" % [arena.display_name, arena.grid_size.x, arena.grid_size.y],
		edit_session.session_key,
		edit_session.source_path
	)


## --- Validation actionnable ------------------------------------------------

func _on_validation_show(message: ArenaValidationMessage) -> void:
	if message == null or message.cell == GridTransformService.INVALID_CELL:
		return
	show_editor()
	canvas.center_on_cell(message.cell)
	_refresh_inspector(message.cell)
	_set_status("Vue recentrée sur la case (%d, %d)." % [message.cell.x, message.cell.y])


func _on_validation_select(message: ArenaValidationMessage) -> void:
	if message == null or message.cell == GridTransformService.INVALID_CELL:
		return
	show_editor()
	_select_tool_from_palette(ArenaStudioCanvas.Tool.SELECT)
	canvas.selected_cells = [message.cell]
	canvas.center_on_cell(message.cell)
	canvas.queue_redraw()
	_refresh_inspector(message.cell)
	_set_status("Case (%d, %d) sélectionnée." % [message.cell.x, message.cell.y])


func _on_validation_auto_fix(message: ArenaValidationMessage) -> void:
	if arena == null or edit_session == null or message == null:
		return
	var before := arena.to_snapshot()
	var result := ArenaValidationFixService.apply(arena, message)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("message", "Correction impossible.")), true)
		return
	if bool(result.get("changed", false)):
		_commit_change(str(result.get("action", "Correction automatique")),
			before, arena.to_snapshot())
		_refresh_all()
	validate_arena()
	_set_status("%s Vous pouvez annuler avec Ctrl+Z." % result.get("message", ""))


## --- Raccourcis clavier ----------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	if _text_control_has_focus():
		return
	if editor_screen == null or not editor_screen.visible:
		return
	var index := TOOL_SHORTCUT_KEYS.find(key.keycode)
	if index < 0 or index >= TOOL_LABELS.size():
		return
	if index in [
		ArenaStudioCanvas.Tool.TRANSFORM_GRID,
		ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS,
	] and guided:
		return
	_select_tool_from_palette(index)
	get_viewport().set_input_as_handled()


func _text_control_has_focus() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var focused := viewport.gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return true
	var parent := focused.get_parent() if focused != null else null
	return parent is SpinBox


## Liste ordonnee des actions primaires atteignables au clavier. Le test de
## parcours clavier se base sur cette liste ; elle doit rester complete.
func primary_action_controls() -> Array[Control]:
	var result: Array[Control] = []
	for control in [
		home_button, new_terrain_button, open_terrain_button, guided_toggle,
		preview_option, inspector_drawer_button,
	]:
		if control != null:
			result.append(control as Control)
	if workflow_rail != null:
		for button in workflow_rail.buttons:
			result.append(button as Control)
		if workflow_rail.primary_button != null:
			result.append(workflow_rail.primary_button as Control)
	if guidance_panel != null:
		for control in [
			guidance_panel.previous_button, guidance_panel.continue_button,
			guidance_panel.hide_button, guidance_panel.glossary_button,
		]:
			if control != null:
				result.append(control as Control)
	if tool_palette != null:
		for key in tool_palette.tool_buttons:
			result.append(tool_palette.tool_buttons[key] as Control)
	if finalize_panel != null:
		for control in [
			finalize_panel.draft_button, finalize_panel.test_button,
			finalize_panel.integrate_button,
		]:
			if control != null:
				result.append(control as Control)
	if bottom_drawer_button != null:
		result.append(bottom_drawer_button as Control)
	return result


func _build_destination_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "RoomDestinationPanel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	box.add_child(_section_label("DESTINATION DE LA SALLE"))
	var selectors := GridContainer.new()
	selectors.columns = 2
	box.add_child(selectors)
	selectors.add_child(_plain_label("Partie :"))
	destination_run_option = OptionButton.new()
	destination_run_option.name = "DestinationRunOption"
	destination_run_option.clip_text = true
	destination_run_option.custom_minimum_size.x = 132
	destination_run_option.item_selected.connect(_on_destination_run_selected)
	selectors.add_child(destination_run_option)
	selectors.add_child(_plain_label("Action :"))
	destination_action_option = OptionButton.new()
	destination_action_option.name = "DestinationActionOption"
	destination_action_option.clip_text = true
	destination_action_option.custom_minimum_size.x = 132
	for entry in [
		["Mettre à jour l’arène — recommandé", ArenaProductionAttachmentService.UPDATE],
		["Créer une nouvelle salle", ArenaProductionAttachmentService.APPEND],
		["Insérer avant", ArenaProductionAttachmentService.INSERT_BEFORE],
		["Insérer après", ArenaProductionAttachmentService.INSERT_AFTER],
		["Remplacer toute la salle — avancé", ArenaProductionAttachmentService.REPLACE],
		["Produire sans intégrer", ArenaProductionAttachmentService.NONE],
	]:
		destination_action_option.add_item(entry[0])
		destination_action_option.set_item_metadata(
			destination_action_option.item_count - 1, entry[1]
		)
	destination_action_option.item_selected.connect(func(_index): _refresh_destination_panel())
	selectors.add_child(destination_action_option)
	selectors.add_child(_plain_label("Salle :"))
	destination_room_option = OptionButton.new()
	destination_room_option.name = "DestinationRoomOption"
	destination_room_option.clip_text = true
	destination_room_option.custom_minimum_size.x = 132
	destination_room_option.item_selected.connect(func(_index): _refresh_destination_panel())
	selectors.add_child(destination_room_option)
	destination_summary_label = Label.new()
	destination_summary_label.name = "DestinationSummary"
	destination_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	destination_summary_label.add_theme_color_override(
		"font_color", Color(0.72, 0.91, 1.0)
	)
	box.add_child(destination_summary_label)
	destination_details_text = RichTextLabel.new()
	destination_details_text.name = "DestinationDetails"
	destination_details_text.bbcode_enabled = true
	destination_details_text.custom_minimum_size.y = 118
	destination_details_text.fit_content = false
	destination_details_text.scroll_active = true
	box.add_child(destination_details_text)
	var buttons := HFlowContainer.new()
	box.add_child(buttons)
	destination_integrate_button = _add_button(
		buttons, "Intégrer à la partie", _on_integrate_destination_pressed
	)
	destination_integrate_button.name = "IntegrateIntoRunButton"
	destination_integrate_button.clip_text = true
	destination_integrate_button.custom_minimum_size.x = 168
	destination_resolve_button = _add_button(
		buttons, "Résoudre les fichiers présents…", _open_destination_bundle_resolver
	)
	destination_resolve_button.name = "ResolveDestinationBundleButton"
	destination_resolve_button.visible = false
	destination_tour_button = _add_button(buttons, "Visite guidée", _show_guided_tour)
	destination_tour_button.tooltip_text = "Commencer la visite à l’étape Destination"
	return panel


func _refresh_destination_panel(_unused = {}) -> void:
	if destination_run_option == null or destination_action_option == null:
		return
	if _history_refresh_suppressed:
		_mark_destination_plan_obsolete()
		return
	_destination_syncing = true
	var previous_run_path := ""
	if destination_run_option.selected >= 0 \
			and destination_run_option.selected < _destination_runs.size():
		previous_run_path = _destination_runs[destination_run_option.selected].resource_path
	if previous_run_path.is_empty() and project_context != null \
			and project_context.active_run != null:
		previous_run_path = project_context.active_run.resource_path
	_destination_runs = RunContentCatalogService.discover_runs()
	destination_run_option.clear()
	var selected_run_index := 0
	for index in range(_destination_runs.size()):
		var run_data := _destination_runs[index]
		destination_run_option.add_item("%s — %s" % [
			ArenaIntegrationService.run_short_label(run_data), run_data.run_name,
		])
		destination_run_option.set_item_tooltip(index, run_data.resource_path)
		if run_data.resource_path == previous_run_path:
			selected_run_index = index
	if not _destination_runs.is_empty():
		destination_run_option.select(selected_run_index)
	var selected_run := _selected_destination_run()
	var previous_room_index := destination_room_option.selected
	if previous_room_index < 0 and project_context != null \
			and selected_run == project_context.active_run:
		previous_room_index = project_context.active_room_index
	destination_room_option.clear()
	if selected_run != null:
		for index in range(selected_run.rooms.size()):
			var room := selected_run.rooms[index]
			destination_room_option.add_item("%d — %s" % [
				index + 1, room.room_name if room != null else "Salle absente",
			])
			destination_room_option.set_item_tooltip(
				index, room.resource_path if room != null else "Référence absente"
			)
	if destination_room_option.item_count > 0:
		destination_room_option.select(clampi(
			previous_room_index, 0, destination_room_option.item_count - 1
		))
	_destination_syncing = false
	var action := _selected_destination_action()
	destination_room_option.disabled = action in [
		ArenaProductionAttachmentService.NONE,
		ArenaProductionAttachmentService.APPEND,
	]
	var target_index := _selected_destination_room_index()
	var candidate := _destination_candidate()
	_destination_last_plan = ArenaIntegrationService.plan(
		candidate, selected_run, action, target_index,
		ArenaProductionService.suggested_destination(candidate), shared_reference_graph,
		_integration_gate_options(candidate, selected_run)
	) if candidate != null else {"ok": false, "error": "Aucune arène ouverte."}
	_render_destination_plan(_destination_last_plan)


func _render_destination_plan(plan: Dictionary) -> void:
	if destination_summary_label == null or destination_details_text == null:
		return
	var action := _selected_destination_action()
	var run_data := _selected_destination_run()
	var run_label := ArenaIntegrationService.run_short_label(run_data)
	var target_index := int(plan.get("target_index", _selected_destination_room_index()))
	var room_number := target_index + 1
	var affected_files := PackedStringArray()
	for path in plan.get("affected_files", []):
		affected_files.append(str(path))
	var result_label := "Production isolée"
	if action == ArenaProductionAttachmentService.UPDATE:
		result_label = "%s / Salle %d — gameplay conservé" % [run_label, room_number]
	elif action == ArenaProductionAttachmentService.REPLACE:
		result_label = "%s / Salle %d — remplacement complet" % [run_label, room_number]
	elif action == ArenaProductionAttachmentService.APPEND:
		result_label = "%s / Nouvelle salle %d" % [run_label, room_number]
	elif action in [ArenaProductionAttachmentService.INSERT_BEFORE, ArenaProductionAttachmentService.INSERT_AFTER]:
		result_label = "%s / Salle insérée en position %d" % [run_label, room_number]
	destination_summary_label.text = "Résultat : %s\nPortée : %s" % [
		result_label, plan.get("scope", "Unique à cette partie"),
	]
	var lines := PackedStringArray([
		"[b]Action prévue[/b] : %s" % plan.get("action_label", "Indisponible"),
		"[b]Partie[/b] : %s" % plan.get("run_path", ""),
		"[b]Salle cible[/b] : %s" % plan.get("target_room_path", ""),
		"[b]Terrain final[/b] : %s" % plan.get("new_arena_path", ""),
		"[b]Partagée[/b] : %s" % ("oui — copie spécifique automatique" if plan.get("shared", false) else "non"),
		"[b]Index[/b] : %d ; salles %d → %d" % [
			target_index, int(plan.get("before_count", 0)), int(plan.get("after_count", 0)),
		],
		"[b]Fichiers affectés (%d)[/b]" % affected_files.size(),
	])
	for path in affected_files:
		lines.append("• %s" % path)
	var gate := plan.get("gate_report", {}) as Dictionary
	var readiness := plan.get("readiness_report") as ArenaReadinessReport
	var resolution := plan.get("bundle_resolution", {}) as Dictionary
	var blockers: Array = gate.get("blocking_errors", [])
	var warnings: Array = gate.get("acknowledgement_warnings", [])
	var unacknowledged := int(gate.get("unacknowledged_warning_count", 0))
	lines.append("")
	if readiness != null:
		lines.append("[b]DONNÉES ARENA[/b] : %s — %s" % [
			readiness.data_report.state_name(), readiness.data_report.summary,
		])
		lines.append("[b]JEU RÉEL[/b] : %s — %s" % [
			readiness.runtime_scene_report.state_name(),
			readiness.runtime_scene_report.summary,
		])
		lines.append("[b]PRODUCTION[/b] : %s — %s" % [
			readiness.production_report.state_name(),
			readiness.production_report.summary,
		])
		lines.append("[b]INTÉGRATION[/b] : %s — %s" % [
			readiness.integration_report.state_name(),
			readiness.integration_report.summary,
		])
		lines.append("")
	if blockers.is_empty():
		lines.append("[color=green][b]ARÈNE PRÊTE À INTÉGRER[/b][/color]")
		lines.append("✓ Vérifications automatiques terminées")
	else:
		lines.append("[color=red][b]Pourquoi l'intégration est-elle indisponible ?[/b][/color]")
		for issue in blockers:
			lines.append("[color=red]✕ %s[/color]" % (issue as Dictionary).get(
				"message", (issue as Dictionary).get("code", "Blocage technique")
			))
	if not warnings.is_empty():
		lines.append("")
		lines.append("[color=orange][b]%d avertissement(s) de conception — %d à confirmer[/b][/color]" % [
			warnings.size(), unacknowledged,
		])
		for issue in warnings:
			var accepted := bool((issue as Dictionary).get("acknowledged", false))
			lines.append("[color=%s]• %s%s[/color]" % [
				"green" if accepted else "orange",
				(issue as Dictionary).get("message", "Avertissement"),
				" — choix accepté" if accepted else "",
			])
	if bool(resolution.get("required", false)):
		lines.append("")
		lines.append("[color=orange][b]Dossier de production déjà présent[/b][/color]")
		lines.append(str(resolution.get("explanation", "État à examiner.")))
		lines.append("Action recommandée : [b]%s[/b]" % resolution.get(
			"recommended_label", "Examiner les fichiers"
		))
	lines.append("")
	lines.append("[color=light_blue]%d information(s)[/color]" % (
		gate.get("information", []) as Array
	).size())
	destination_details_text.text = "\n".join(lines)
	var enabled := blockers.is_empty() and not _integration_running
	destination_integrate_button.disabled = not enabled
	var integrate_label := _destination_button_text(
		action, run_label, room_number
	) + (" — %d avertissement(s)" % unacknowledged if unacknowledged > 0 else "")
	destination_integrate_button.text = integrate_label
	# Le libellé complet reste lisible en infobulle : il ne doit pas imposer
	# sa largeur à l'inspecteur, sinon la colonne déborde en 1280 × 720.
	var integrate_reason := "Lancer les vérifications automatiques puis intégrer."
	if not blockers.is_empty():
		integrate_reason = "\n".join(blockers.map(func(value):
			return str((value as Dictionary).get("message", "Blocage technique"))
		))
	destination_integrate_button.tooltip_text = "%s\n%s" % [
		integrate_label, integrate_reason,
	]
	if destination_resolve_button != null:
		destination_resolve_button.visible = bool(resolution.get("required", false))
		destination_resolve_button.tooltip_text = str(resolution.get(
			"explanation", "Examiner et résoudre le dossier existant."
		))


func _mark_destination_plan_obsolete() -> void:
	_destination_last_plan = {
		"ok": false,
		"error": "La calibration a changé ; le plan doit être recalculé.",
		"obsolete": true,
	}
	if destination_summary_label != null:
		destination_summary_label.text = "Plan d'intégration obsolète — calibration modifiée"
	if destination_details_text != null:
		destination_details_text.text = (
			"La version en cours a changé. Ouvrez l'étape Destination pour recalculer"
			+ "les certificats et la production."
		)
	if destination_integrate_button != null:
		destination_integrate_button.disabled = true


func _destination_button_text(action: StringName, run_label: String, room_number: int) -> String:
	match action:
		ArenaProductionAttachmentService.NONE:
			return "Vérifier et produire sans intégrer"
		ArenaProductionAttachmentService.UPDATE:
			return "Vérifier et intégrer dans %s — Mettre à jour salle %d" % [run_label, room_number]
		ArenaProductionAttachmentService.REPLACE:
			return "Vérifier et intégrer dans %s — Remplacer salle %d" % [run_label, room_number]
		ArenaProductionAttachmentService.APPEND:
			return "Vérifier et intégrer dans %s — Créer salle %d" % [run_label, room_number]
		ArenaProductionAttachmentService.INSERT_BEFORE:
			return "Vérifier et intégrer dans %s — Insérer avant salle %d" % [run_label, room_number]
		ArenaProductionAttachmentService.INSERT_AFTER:
			return "Vérifier et intégrer dans %s — Insérer après salle %d" % [run_label, room_number]
	return "Vérifier et intégrer à la partie"


func _open_destination_bundle_resolver() -> void:
	show_production_wizard()
	if production_tabs != null:
		production_tabs.current_tab = 3


func _on_destination_run_selected(_index: int) -> void:
	if not _destination_syncing:
		destination_room_option.select(0)
		_refresh_destination_panel()


func _selected_destination_run() -> RunData:
	if destination_run_option == null or destination_run_option.selected < 0 \
			or destination_run_option.selected >= _destination_runs.size():
		return null
	return _destination_runs[destination_run_option.selected]


func _selected_destination_action() -> StringName:
	if destination_action_option == null or destination_action_option.selected < 0:
		return ArenaProductionAttachmentService.UPDATE
	return StringName(destination_action_option.get_item_metadata(
		destination_action_option.selected
	))


func _selected_destination_room_index() -> int:
	var run_data := _selected_destination_run()
	if run_data == null:
		return -1
	if _selected_destination_action() == ArenaProductionAttachmentService.APPEND:
		return run_data.rooms.size()
	return destination_room_option.selected


func _destination_candidate() -> ArenaDefinition:
	if arena == null:
		return null
	var candidate := RoomIntegrationFieldPolicy.merge_arena_into_room(arena, arena)
	if candidate == null:
		return null
	ArenaRuntimeBridge.sync_runtime_resources(candidate)
	return candidate


func _blocking_context_domains() -> PackedStringArray:
	var result := PackedStringArray()
	if project_context == null:
		return result
	for domain_value in project_context.dirty_domains().keys():
		var domain := StringName(domain_value)
		if domain != &"arena":
			result.append(str(domain))
	return result


func _integration_gate_options(
		candidate: ArenaDefinition,
		target_run: RunData = null
	) -> Dictionary:
	var fingerprint := ArenaSnapshotService.arena_fingerprint(candidate) \
		if candidate != null else ""
	var manual_result := ArenaDirectTestService.matching_runtime_result(candidate)
	var manual_performed := not manual_result.is_empty()
	var run_conflict := target_run != null and run_authoring != null \
		and run_authoring.is_dirty() \
		and run_authoring.source_path == target_run.resource_path
	return {
		"validation_profile": ArenaIntegrationGatePolicy.Profile.PRODUCTION,
		"accepted_warnings": edit_session.accepted_design_warnings(fingerprint) \
			if edit_session != null else [],
		"manual_test_performed": manual_performed,
		"runtime_scene_result": manual_result,
		"art_alignment_confirmed": false,
		"external_source_conflict": edit_session != null \
			and edit_session.has_external_conflict(),
		"run_conflict": run_conflict,
		"unrelated_dirty_domains": Array(_blocking_context_domains()),
	}


func _unacknowledged_gate_warnings(plan: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var gate := plan.get("gate_report", {}) as Dictionary
	for value in gate.get("acknowledgement_warnings", []):
		var issue := value as Dictionary
		if not bool(issue.get("acknowledged", false)):
			result.append(issue.duplicate(true))
	return result


func _gate_blocking_text(plan: Dictionary) -> String:
	var gate := plan.get("gate_report", {}) as Dictionary
	var messages := PackedStringArray()
	for value in gate.get("blocking_errors", []):
		messages.append(str((value as Dictionary).get(
			"message", (value as Dictionary).get("code", "Blocage technique")
		)))
	return "\n".join(messages)


func _on_integrate_destination_pressed() -> void:
	_refresh_destination_panel()
	if not _destination_last_plan.get("can_integrate", false):
		_set_status("Intégration impossible : %s" % _gate_blocking_text(
			_destination_last_plan
		), true)
		return
	var warnings := _unacknowledged_gate_warnings(_destination_last_plan)
	if not warnings.is_empty():
		_show_integration_warning_confirmation(warnings, &"destination")
		return
	_continue_destination_integration()


func _continue_destination_integration() -> void:
	var action := _selected_destination_action()
	if action == ArenaProductionAttachmentService.REPLACE:
		integration_replace_dialog.dialog_text = (
			"Cette action remplace toute la référence de la salle. L’ancien fichier restera sur disque, "
			+ "mais les données suivantes ne seront pas reprises :\n\n"
			+ "\n".join(_destination_last_plan.get("abandoned_gameplay", []))
			+ "\n\nPréférez « Mettre à jour l’arène » pour conserver le gameplay."
		)
		integration_replace_dialog.popup_centered()
		return
	_run_destination_integration()


func _show_integration_warning_confirmation(
		warnings: Array[Dictionary],
		flow: StringName
	) -> void:
	_pending_integration_warning_flow = flow
	_pending_integration_warnings = warnings.duplicate(true)
	var lines := PackedStringArray([
		"[b]%d point(s) de conception sont à vérifier.[/b]" % warnings.size(),
		"",
	])
	for issue in warnings:
		lines.append("• %s" % issue.get("message", issue.get("code", "Avertissement")))
	lines.append("")
	lines.append("Ces points ne sont pas des erreurs techniques. Donnez une justification liée à cette version de l'arène.")
	integration_warning_text.text = "\n".join(lines)
	integration_warning_justification.text = ""
	integration_warning_dialog.popup_centered()


func _on_integration_warnings_confirmed() -> void:
	var justification := integration_warning_justification.text.strip_edges()
	if justification.is_empty():
		_set_status("Une justification est requise pour accepter ce choix de conception.", true)
		call_deferred("_reopen_integration_warning_dialog")
		return
	if edit_session != null:
		for issue in _pending_integration_warnings:
			edit_session.accept_design_warning(issue, justification)
	var flow := _pending_integration_warning_flow
	_pending_integration_warning_flow = &""
	_pending_integration_warnings.clear()
	if flow == &"production":
		call_deferred("_run_confirmed_production")
	else:
		call_deferred("_continue_destination_integration")


func _reopen_integration_warning_dialog() -> void:
	integration_warning_dialog.popup_centered()


func _run_destination_integration() -> void:
	if _integration_running:
		return
	_integration_running = true
	_refresh_destination_panel()
	integrate_room_requested.emit(_destination_last_plan.duplicate(true))
	var candidate := _destination_candidate()
	var before := arena.to_snapshot().duplicate(true) if arena != null else {}
	await _perform_room_integration(
		candidate, before, _selected_destination_run(), _selected_destination_action(),
		_selected_destination_room_index(), ArenaProductionService.suggested_destination(candidate)
	)
	_integration_running = false
	_refresh_destination_panel()


func _show_guided_tour() -> void:
	if guided_tour != null:
		guided_tour.start(&"destination" if destination_tour_button != null \
			and destination_tour_button.has_focus() else &"")


func _build_dynamic_palette() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "DynamicConstructionPalette"
	box.add_child(_section_label("CONSTRUCTION DYNAMIQUE"))
	dynamic_document_label = Label.new()
	dynamic_document_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(dynamic_document_label)
	hybrid_floor_policy_panel = VBoxContainer.new()
	hybrid_floor_policy_panel.name = "HybridFloorPolicyPanel"
	hybrid_floor_policy_panel.add_child(_section_label("SOL HYBRIDE"))
	hybrid_floor_policy_option = OptionButton.new()
	hybrid_floor_policy_option.name = "HybridFloorPolicyOption"
	hybrid_floor_policy_option.tooltip_text = (
		"Choisit quelles dalles tactiques restent au-dessus du décor. "
		+ "Toutes les dalles tactiques inclut normal/stone avec stone.png."
	)
	_populate_hybrid_floor_policy_options(hybrid_floor_policy_option)
	hybrid_floor_policy_option.item_selected.connect(_on_hybrid_floor_policy_selected)
	hybrid_floor_policy_panel.add_child(hybrid_floor_policy_option)
	var floor_help := Label.new()
	floor_help.text = "Le décor reste en arrière-plan ; cette option ne change pas le gameplay."
	floor_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hybrid_floor_policy_panel.add_child(floor_help)
	box.add_child(hybrid_floor_policy_panel)
	var terrain_button := Button.new()
	terrain_button.text = "Terrain"
	terrain_button.tooltip_text = "Peindre le terrain — une action annulable par trait"
	terrain_button.pressed.connect(func(): _select_dynamic_tool(ArenaStudioCanvas.Tool.TERRAIN))
	box.add_child(terrain_button)
	dynamic_terrain_option = OptionButton.new()
	dynamic_terrain_option.tooltip_text = "Terrain appliqué par le pinceau"
	dynamic_terrain_option.item_selected.connect(func(_index):
		canvas.set_brush_preview_terrain(StringName(
			dynamic_terrain_option.get_selected_metadata()
		))
		_select_dynamic_tool(ArenaStudioCanvas.Tool.TERRAIN)
	)
	box.add_child(dynamic_terrain_option)
	var base_label := Label.new()
	base_label.text = "Sol de base modulaire / hybride"
	box.add_child(base_label)
	dynamic_base_terrain_option = OptionButton.new()
	for terrain_id in [&"stone", &"neutral"]:
		var entry := ArenaTerrainRegistry.get_entry(terrain_id)
		dynamic_base_terrain_option.add_item(str(entry.get("name", terrain_id)))
		dynamic_base_terrain_option.set_item_metadata(
			dynamic_base_terrain_option.item_count - 1, terrain_id
		)
	dynamic_base_terrain_option.item_selected.connect(_on_dynamic_base_terrain_selected)
	box.add_child(dynamic_base_terrain_option)
	var wall_button := Button.new()
	wall_button.text = "Mur"
	wall_button.tooltip_text = "Placer un vrai mur normal, de feu ou de glace"
	wall_button.pressed.connect(func(): _select_dynamic_tool(ArenaStudioCanvas.Tool.OBSTACLE))
	box.add_child(wall_button)
	dynamic_wall_option = OptionButton.new()
	for wall_id in [&"normal", &"fire", &"ice"]:
		var entry := ArenaWallRegistry.get_entry(wall_id)
		dynamic_wall_option.add_item(str(entry.get("name", wall_id)))
		dynamic_wall_option.set_item_metadata(dynamic_wall_option.item_count - 1, wall_id)
	dynamic_wall_option.add_item("Supprimer le mur")
	dynamic_wall_option.set_item_metadata(dynamic_wall_option.item_count - 1, &"remove")
	dynamic_wall_option.item_selected.connect(func(_index):
		_select_dynamic_tool(ArenaStudioCanvas.Tool.OBSTACLE)
	)
	box.add_child(dynamic_wall_option)
	box.add_child(_section_label("INTERACTIFS"))
	var special_button := Button.new()
	special_button.text = "Spawn / objectif / décoration"
	special_button.tooltip_text = "Placer un élément spécial sur une cellule praticable"
	special_button.pressed.connect(func(): _select_dynamic_tool(ArenaStudioCanvas.Tool.SPAWN))
	box.add_child(special_button)
	dynamic_special_option = OptionButton.new()
	for entry in [
		["Spawn héros", &"hero"], ["Spawn ennemi", &"enemy"],
		["Objectif", &"objective"], ["Décoration", &"decoration"],
		["Réseau de vortex — 1, 2 ou plusieurs sorties", &"vortex_network"],
		["Zone d'invocation", &"summon"], ["Supprimer le spécial", &"remove"],
	]:
		dynamic_special_option.add_item(entry[0])
		dynamic_special_option.set_item_metadata(dynamic_special_option.item_count - 1, entry[1])
	dynamic_special_option.item_selected.connect(func(_index):
		_clear_pending_vortex()
		_select_dynamic_tool(ArenaStudioCanvas.Tool.SPAWN)
	)
	box.add_child(dynamic_special_option)
	box.add_child(_section_label("Document"))
	var resize_grid := GridContainer.new()
	resize_grid.columns = 2
	dynamic_width_spin = SpinBox.new()
	dynamic_width_spin.prefix = "Largeur  "
	dynamic_width_spin.min_value = 1
	dynamic_width_spin.max_value = 64
	dynamic_width_spin.step = 1
	resize_grid.add_child(dynamic_width_spin)
	dynamic_height_spin = SpinBox.new()
	dynamic_height_spin.prefix = "Hauteur  "
	dynamic_height_spin.min_value = 1
	dynamic_height_spin.max_value = 64
	dynamic_height_spin.step = 1
	resize_grid.add_child(dynamic_height_spin)
	box.add_child(resize_grid)
	var resize_button := Button.new()
	resize_button.text = "Redimensionner le document"
	resize_button.tooltip_text = "Redimensionner la version en cours (annulable)"
	resize_button.pressed.connect(_resize_dynamic_document)
	box.add_child(resize_button)
	return box


func _build_surface_preview_palette() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_child(_section_label("SIMULER UN SORT DE TERRAIN"))
	var note := Label.new()
	note.text = (
		"Vue Jeu · vrai sort et vraie durée · copie de test uniquement\n"
		+ "Boule de feu : croix rayon 2 · lave 3 tours · 15 dégâts à l'entrée"
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var buttons := HFlowContainer.new()
	box.add_child(buttons)
	_add_button(buttons, "Appliquer · Boule de feu", func():
		_simulate_runtime_terrain_spell(TERRAIN_SIM_FIREBALL)
	)
	_add_button(buttons, "Appliquer · Mur de glace", func():
		_simulate_runtime_terrain_spell(TERRAIN_SIM_ICE_WALL)
	)
	_add_button(buttons, "Appliquer · Eau (exemple)", func():
		_simulate_runtime_water_fixture()
	)
	_add_button(buttons, "Avancer d'un tour", func():
		_advance_runtime_terrain_tick()
	)
	_add_button(buttons, "Déplacer l’exemple", func():
		_move_runtime_terrain_fixture()
	)
	_add_button(buttons, "Effacer les surfaces", func():
		_clear_runtime_terrain_surfaces()
	)
	_add_button(buttons, "Réinitialiser", func():
		_reset_runtime_terrain_simulation()
	)
	return box


func _build_transform_panel() -> Control:
	var box := VBoxContainer.new()
	transform_panel = box
	box.add_child(_section_label("Transformation de la grille"))
	var transform_button := Button.new()
	transform_button.text = "Transformer la grille"
	transform_button.tooltip_text = "Sélectionne la calibration sans rendre le fond déplaçable."
	transform_button.pressed.connect(func():
		_select_tool_and_preset(ArenaStudioCanvas.Tool.TRANSFORM_GRID, 0)
	)
	box.add_child(transform_button)
	var flags := GridContainer.new()
	flags.columns = 1
	var snap := CheckButton.new()
	snap.text = "Aimantation"
	snap.button_pressed = true
	snap.tooltip_text = "Ctrl inverse temporairement l'aimantation pendant un geste."
	snap.toggled.connect(func(value): canvas.snap_enabled = value)
	flags.add_child(snap)
	transform_controls["snap_enabled"] = snap
	var fine := Label.new()
	fine.text = "Shift : precision fine"
	flags.add_child(fine)
	var preserve := CheckButton.new()
	preserve.text = "Conserver la longueur des axes"
	preserve.toggled.connect(func(value): canvas.preserve_axis_length = value)
	flags.add_child(preserve)
	transform_controls["preserve_axis_length"] = preserve
	var preserve_angle := CheckButton.new()
	preserve_angle.text = "Conserver la direction de l'axe glissé"
	preserve_angle.toggled.connect(func(value): canvas.preserve_axis_angle = value)
	flags.add_child(preserve_angle)
	transform_controls["preserve_axis_angle"] = preserve_angle
	var symmetry := CheckButton.new()
	symmetry.text = "Symétrie des axes libres"
	symmetry.toggled.connect(func(value): canvas.mirror_axes = value)
	flags.add_child(symmetry)
	transform_controls["mirror_axes"] = symmetry
	angle_mode_option = OptionButton.new()
	angle_mode_option.tooltip_text = "Comportement de la poignée Angle de la grille"
	for label in ["Symétrique", "Conserver X", "Conserver Y"]:
		angle_mode_option.add_item(label)
	angle_mode_option.item_selected.connect(func(index):
		canvas.set_angle_mode(index)
		_refresh_transform_inspector()
	)
	flags.add_child(angle_mode_option)
	var keep_size := CheckButton.new()
	keep_size.text = "Conserver taille globale"
	keep_size.toggled.connect(func(value): canvas.lock_scale = value)
	flags.add_child(keep_size)
	transform_controls["lock_scale"] = keep_size
	var independent := CheckButton.new()
	independent.text = "Axes independants"
	independent.button_pressed = true
	independent.toggled.connect(func(value):
		canvas.mirror_axes = not value
		symmetry.set_pressed_no_signal(not value)
	)
	flags.add_child(independent)
	transform_controls["independent_axes"] = independent
	for definition in [
		["Verrouiller position", "lock_translation"],
		["Verrouiller rotation", "lock_rotation"],
		["Verrouiller axe X", "lock_axis_x"],
		["Verrouiller axe Y", "lock_axis_y"],
	]:
		var lock := CheckButton.new()
		lock.text = definition[0]
		var property_name: String = definition[1]
		lock.toggled.connect(func(value): canvas.set(property_name, value))
		flags.add_child(lock)
		transform_controls[property_name] = lock
	box.add_child(flags)
	var snap_values := GridContainer.new()
	snap_values.columns = 1
	for definition in [
		["Position 1 px", 1.0, 0.1, 20.0, 0.1, "position_snap"],
		["Angle 0.25 deg", 0.25, 0.05, 45.0, 0.05, "angle_snap_degrees"],
		["Échelle 0.5 %", 0.005, 0.001, 0.25, 0.001, "scale_snap"],
	]:
		var snap_spin := SpinBox.new()
		snap_spin.prefix = definition[0] + "  "
		snap_spin.value = definition[1]
		snap_spin.min_value = definition[2]
		snap_spin.max_value = definition[3]
		snap_spin.step = definition[4]
		var property_name: String = definition[5]
		snap_spin.value_changed.connect(func(value): canvas.set(property_name, value))
		snap_values.add_child(snap_spin)
	box.add_child(snap_values)
	var pivot_actions := HBoxContainer.new()
	var center_pivot := Button.new()
	center_pivot.text = "Centrer pivot"
	center_pivot.tooltip_text = "Placer le pivot d'éditeur au centre logique — ne modifie pas la carte"
	center_pivot.pressed.connect(func():
		canvas.center_editor_pivot()
		_refresh_transform_inspector()
	)
	pivot_actions.add_child(center_pivot)
	var origin_pivot := Button.new()
	origin_pivot.text = "Pivot sur O"
	origin_pivot.tooltip_text = "Placer le pivot d'éditeur sur l'origine O — ne marque pas la carte comme modifiée"
	origin_pivot.pressed.connect(func():
		canvas.place_editor_pivot_on_origin()
		_refresh_transform_inspector()
	)
	pivot_actions.add_child(origin_pivot)
	box.add_child(pivot_actions)
	compare_button = CheckButton.new()
	compare_button.text = "Comparer à la sauvegarde"
	compare_button.toggled.connect(func(value):
		canvas.show_saved_comparison = value
		canvas.queue_redraw()
	)
	box.add_child(compare_button)
	last_operation_label = Label.new()
	last_operation_label.text = "Dernière opération : aucune"
	last_operation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	last_operation_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.94))
	box.add_child(last_operation_label)
	box.hide()
	return box


func _build_layers_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_child(_section_label("Calques"))
	var grid := GridContainer.new()
	grid.columns = 3
	for heading in ["Visible", "Verrou", "Calque"]:
		var label := Label.new()
		label.text = heading
		grid.add_child(label)
	var definitions := [
		["background", "Image de fond", true, true],
		["calibration", "Calibration de la grille", true, true],
		["gameplay", "Cellules gameplay", true, false],
		["details", "Obstacles et terrains", true, false],
		["spawns", "Spawns", true, false],
		["foreground", "Foreground et occlusion", true, true],
	]
	for definition in definitions:
		var visible := CheckBox.new()
		visible.button_pressed = definition[2]
		var locked := CheckBox.new()
		locked.button_pressed = definition[3]
		var label := Label.new()
		label.text = definition[1]
		var key: String = definition[0]
		visible.toggled.connect(func(value):
			canvas.set_layer_state(key, value, bool(canvas.layer_locks.get(key, false)))
		)
		locked.toggled.connect(func(value):
			canvas.set_layer_state(key, bool(canvas.layer_visibility.get(key, true)), value)
		)
		grid.add_child(visible)
		grid.add_child(locked)
		grid.add_child(label)
		layer_controls[key] = {"visible": visible, "locked": locked}
	box.add_child(grid)
	var background_opacity := HSlider.new()
	background_opacity.min_value = 0.1
	background_opacity.max_value = 1.0
	background_opacity.step = 0.05
	background_opacity.value = 1.0
	background_opacity.tooltip_text = "Opacité du fond (préférence d'éditeur)"
	background_opacity.value_changed.connect(func(value):
		canvas.background_opacity = value
		canvas.queue_redraw()
	)
	box.add_child(background_opacity)
	var grid_opacity := HSlider.new()
	grid_opacity.min_value = 0.1
	grid_opacity.max_value = 1.0
	grid_opacity.step = 0.05
	grid_opacity.value = 1.0
	grid_opacity.tooltip_text = "Opacité de la grille (préférence d'éditeur)"
	grid_opacity.value_changed.connect(func(value):
		canvas.grid_opacity = value
		canvas.queue_redraw()
	)
	box.add_child(grid_opacity)
	return box


func _build_restore_points_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_child(_section_label("Points de restauration"))
	restore_name_edit = LineEdit.new()
	restore_name_edit.placeholder_text = "Nom du point"
	box.add_child(restore_name_edit)
	var buttons := GridContainer.new()
	buttons.columns = 2
	_add_button(buttons, "Créer", create_restore_point)
	_add_button(buttons, "Restaurer", restore_selected_point)
	_add_button(buttons, "Renommer", rename_selected_restore_point)
	_add_button(buttons, "Supprimer", delete_selected_restore_point)
	box.add_child(buttons)
	restore_points_list = ItemList.new()
	restore_points_list.custom_minimum_size.y = 72
	box.add_child(restore_points_list)
	var reset_menu := MenuButton.new()
	reset_menu.text = "Réinitialiser ▾"
	for definition in [
		["Restaurer la calibration sauvegardée", 0],
		["Réinitialiser seulement la position", 1],
		["Réinitialiser seulement les axes", 2],
		["Réinitialiser la rotation vers la sauvegarde", 3],
	]:
		reset_menu.get_popup().add_item(definition[0], definition[1])
	reset_menu.get_popup().id_pressed.connect(_on_reset_requested)
	box.add_child(reset_menu)
	return box


## Le tiroir de validation presente des cartes actionnables. `validation_list`
## reste construite comme modele interne : le code d'orchestration et les
## runners existants continuent de la lire, mais elle n'est plus l'interface.
func _build_validation_panel() -> Control:
	validation_title = Label.new()
	validation_title.name = "TerrainValidationTitle"
	validation_title.text = "Validation — cliquez une carte pour localiser le problème"
	validation_title.visible = false
	add_child(validation_title)
	validation_list = ItemList.new()
	validation_list.name = "TerrainValidationModel"
	validation_list.visible = false
	validation_list.item_selected.connect(_on_validation_item_selected)
	add_child(validation_list)
	validation_panel = TerrainValidationPanel.new()
	validation_panel.show_requested.connect(_on_validation_show)
	validation_panel.select_cell_requested.connect(_on_validation_select)
	validation_panel.auto_fix_requested.connect(_on_validation_auto_fix)
	return validation_panel


func _build_bottom_drawer() -> VBoxContainer:
	var drawer := VBoxContainer.new()
	drawer.custom_minimum_size.y = 34
	var header := HBoxContainer.new()
	drawer.add_child(header)
	bottom_drawer_button = Button.new()
	bottom_drawer_button.text = "✓ Validation fermee • Historique • Rapport • Console • Analyse   ▲"
	bottom_drawer_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_drawer_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bottom_drawer_button.pressed.connect(_toggle_bottom_drawer)
	header.add_child(bottom_drawer_button)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size.y = 96
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer.add_child(tabs)
	bottom_drawer_content = tabs
	var validation := _build_validation_panel()
	validation.name = "Validation"
	tabs.add_child(validation)
	var history := RichTextLabel.new()
	history.name = "Historique"
	history.text = "L'historique actif est accessible depuis la barre globale."
	tabs.add_child(history)
	var report := RichTextLabel.new()
	report.name = "Rapport"
	report.text = "Validez ou produisez la salle pour générer un rapport."
	tabs.add_child(report)
	var console := RichTextLabel.new()
	console.name = "Console de test"
	console.text = _last_test_log
	tabs.add_child(console)
	var analysis := RichTextLabel.new()
	analysis.name = "Analyse"
	analysis.text = "Déplacements, ligne de vue et cohérence aperçu / jeu réel."
	tabs.add_child(analysis)
	tabs.hide()
	return drawer


func _build_dialogs() -> void:
	new_dialog = ConfirmationDialog.new()
	new_dialog.title = "Nouvelle arène — informations et point de départ"
	new_dialog.size = Vector2i(720, 590)
	new_dialog.ok_button_text = "Continuer vers la calibration"
	new_dialog.confirmed.connect(_create_from_wizard)
	add_child(new_dialog)
	var wizard := VBoxContainer.new()
	new_dialog.add_child(wizard)
	wizard.add_child(_section_label("Étape 1 — Informations"))
	new_name_edit = _labeled_line(wizard, "Nom visible", "Nouvelle arène")
	new_id_edit = _labeled_line(wizard, "Identifiant propose", "nouvelle_arene")
	new_name_edit.text_changed.connect(func(value):
		new_id_edit.text = ArenaDefinition.sanitize_id(value)
	)
	new_image_edit = _labeled_line(wizard, "Image de fond", "")
	_add_button(wizard, "Choisir ou importer une image…", _show_image_dialog)
	new_visual_mode_option = OptionButton.new()
	new_visual_mode_option.tooltip_text = "Le mode modulaire crée immédiatement toutes les dalles."
	for label in ["Type : Peinte", "Type : Modulaire", "Type : Hybride"]:
		new_visual_mode_option.add_item(label)
	wizard.add_child(new_visual_mode_option)
	var dimensions := HBoxContainer.new()
	wizard.add_child(dimensions)
	new_width_spin = _spin(dimensions, "Largeur", 10, 1, 256)
	new_height_spin = _spin(dimensions, "Hauteur", 8, 1, 256)
	new_orientation_option = OptionButton.new()
	for label in ["Héros en bas à gauche", "Héros en bas à droite", "Héros en haut à gauche", "Héros en haut à droite"]:
		new_orientation_option.add_item(label)
	wizard.add_child(new_orientation_option)
	wizard.add_child(_section_label("Étape 2 — Point de départ"))
	new_template_option = OptionButton.new()
	for label in ["Partir d'une carte vide", "Copier la calibration de la forêt", "Copier la calibration du volcan", "Copier la calibration de l'espace"]:
		new_template_option.add_item(label)
	wizard.add_child(new_template_option)
	var step3 := Label.new()
	step3.text = "Étape 3 — Trois clics sur l'image\n1. Case de référence  2. Voisine bas-droite  3. Voisine bas-gauche"
	step3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wizard.add_child(step3)

	image_dialog = FileDialog.new()
	image_dialog.title = "Choisir l'image peinte"
	image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	image_dialog.size = Vector2i(960, 680)
	image_dialog.file_selected.connect(func(path):
		new_image_edit.text = path
		if creation_wizard != null:
			creation_wizard.set_image_path(path)
	)
	add_child(image_dialog)
	_build_painted_dynamic_dialog()
	_build_lab_import_dialog()

	open_dialog = FileDialog.new()
	open_dialog.title = "Ouvrir une arène"
	open_dialog.access = FileDialog.ACCESS_RESOURCES
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.filters = PackedStringArray(["*.tres ; Arène du Studio"])
	open_dialog.current_dir = ArenaSerializer.CANONICAL_ROOT
	open_dialog.file_selected.connect(_open_canonical)
	add_child(open_dialog)

	art_manifest_dialog = FileDialog.new()
	art_manifest_dialog.title = "Importer le manifeste du décor"
	art_manifest_dialog.access = FileDialog.ACCESS_FILESYSTEM
	art_manifest_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	art_manifest_dialog.filters = PackedStringArray(["arena_art_manifest.json ; Manifeste Arena Studio 2.0"])
	art_manifest_dialog.size = Vector2i(960, 680)
	art_manifest_dialog.file_selected.connect(_prepare_art_reimport)
	add_child(art_manifest_dialog)
	art_reimport_dialog = ConfirmationDialog.new()
	art_reimport_dialog.title = "IMPORTER LE DÉCOR DE L’ARÈNE"
	art_reimport_dialog.ok_button_text = "Attacher sans recalibrer"
	art_reimport_dialog.cancel_button_text = "Annuler"
	art_reimport_dialog.confirmed.connect(_apply_art_reimport)
	var art_policy_box := VBoxContainer.new()
	art_policy_box.add_child(_section_label("DALLES AU-DESSUS DU DÉCOR"))
	art_floor_policy_option = OptionButton.new()
	art_floor_policy_option.name = "ArtFloorPolicyOption"
	art_floor_policy_option.tooltip_text = (
		"Toutes les dalles tactiques conserve notamment la pierre normale visible "
		+ "au-dessus du fond importé."
	)
	_populate_hybrid_floor_policy_options(art_floor_policy_option)
	art_policy_box.add_child(art_floor_policy_option)
	art_reimport_dialog.add_child(art_policy_box)
	add_child(art_reimport_dialog)

	restore_delete_dialog = ConfirmationDialog.new()
	restore_delete_dialog.title = "Supprimer le point de restauration"
	restore_delete_dialog.dialog_text = (
		"Ce point sera supprimé de la sauvegarde locale. La carte et son historique ne seront pas modifiés."
	)
	restore_delete_dialog.ok_button_text = "Supprimer"
	restore_delete_dialog.confirmed.connect(_confirm_delete_restore_point)
	add_child(restore_delete_dialog)
	recovery_restore_dialog = ConfirmationDialog.new()
	recovery_restore_dialog.title = "RESTAURER LA RÉCUPÉRATION CONTEXTUELLE"
	recovery_restore_dialog.ok_button_text = "Restaurer cette récupération"
	recovery_restore_dialog.cancel_button_text = "Annuler"
	recovery_restore_dialog.size = Vector2i(720, 460)
	recovery_restore_dialog.confirmed.connect(_confirm_restore_recovery)
	add_child(recovery_restore_dialog)

	guided_tour = ArenaStudioGuidedTour.new()
	add_child(guided_tour)
	# La visite complete devient une aide consultable : le parcours nominal est
	# desormais porte par le rail d'etapes et le guidage contextuel.
	glossary_dialog = AcceptDialog.new()
	glossary_dialog.name = "TerrainGlossaryDialog"
	glossary_dialog.title = "Glossaire du Studio Terrain"
	glossary_dialog.min_size = Vector2i(640, 460)
	glossary_dialog.ok_button_text = "Fermer"
	var glossary_box := VBoxContainer.new()
	glossary_box.custom_minimum_size = Vector2(600, 380)
	glossary_dialog.add_child(glossary_box)
	var glossary_text := RichTextLabel.new()
	glossary_text.name = "TerrainGlossaryText"
	glossary_text.bbcode_enabled = true
	glossary_text.fit_content = false
	glossary_text.scroll_active = true
	glossary_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	glossary_text.text = "%s\n\n[b]Aide détaillée[/b]\nLa visite complète reste disponible ci-dessous pour approfondir chaque notion." % (
		TerrainVocabulary.glossary_markdown()
	)
	glossary_box.add_child(glossary_text)
	var glossary_tour_button := Button.new()
	glossary_tour_button.name = "TerrainGlossaryOpenTour"
	glossary_tour_button.text = "Ouvrir l'aide détaillée"
	glossary_tour_button.tooltip_text = (
		"Ouvrir la visite complète : elle explique chaque notion en détail."
	)
	glossary_tour_button.pressed.connect(func():
		glossary_dialog.hide()
		_show_guided_tour()
	)
	glossary_box.add_child(glossary_tour_button)
	add_child(glossary_dialog)
	integration_replace_dialog = ConfirmationDialog.new()
	integration_replace_dialog.title = "REMPLACER TOUTE LA SALLE — MODE AVANCÉ"
	integration_replace_dialog.ok_button_text = "Remplacer toute la salle"
	integration_replace_dialog.cancel_button_text = "Conserver la salle"
	integration_replace_dialog.confirmed.connect(_run_destination_integration)
	add_child(integration_replace_dialog)
	integration_warning_dialog = ConfirmationDialog.new()
	integration_warning_dialog.title = "AVERTISSEMENTS DE CONCEPTION"
	integration_warning_dialog.ok_button_text = "Accepter ce choix et continuer"
	integration_warning_dialog.cancel_button_text = "Annuler"
	integration_warning_dialog.size = Vector2i(720, 460)
	integration_warning_dialog.confirmed.connect(_on_integration_warnings_confirmed)
	add_child(integration_warning_dialog)
	var warning_box := VBoxContainer.new()
	warning_box.custom_minimum_size = Vector2(680, 340)
	integration_warning_dialog.add_child(warning_box)
	integration_warning_text = RichTextLabel.new()
	integration_warning_text.bbcode_enabled = true
	integration_warning_text.fit_content = false
	integration_warning_text.custom_minimum_size.y = 260
	warning_box.add_child(integration_warning_text)
	integration_warning_justification = LineEdit.new()
	integration_warning_justification.placeholder_text = (
		"Justification du choix de conception pour cette version de l'arène"
	)
	warning_box.add_child(integration_warning_justification)

	_build_production_dialog()
	_build_migration_dialog()


func _build_painted_dynamic_dialog() -> void:
	painted_dynamic_dialog = ConfirmationDialog.new()
	painted_dynamic_dialog.title = "CONSTRUCTION DYNAMIQUE SUR UNE CARTE PEINTE"
	painted_dynamic_dialog.dialog_text = (
		"Le fond peint représente actuellement le sol principal.\n\n"
		+ "Le choix historique affiche seulement les terrains différents de la pierre.\n"
		+ "TOUTES LES DALLES TACTIQUES conserve aussi normal/stone avec le vrai asset pierre.\n\n"
		+ "Aucune ressource canonique ne sera écrite."
	)
	painted_dynamic_dialog.ok_button_text = "Hybride — terrains spéciaux"
	painted_dynamic_dialog.cancel_button_text = "Annuler"
	painted_dynamic_dialog.add_button(
		"Hybride — TOUTES LES DALLES TACTIQUES", false, "hybrid_all"
	)
	painted_dynamic_dialog.add_button("Créer une copie modulaire", false, "modular")
	painted_dynamic_dialog.add_button("Modifier uniquement la logique", false, "logic_only")
	painted_dynamic_dialog.confirmed.connect(_convert_painted_to_hybrid)
	painted_dynamic_dialog.custom_action.connect(func(action):
		painted_dynamic_dialog.hide()
		if action == "hybrid_all":
			_convert_painted_to_hybrid_all()
		elif action == "modular":
			_convert_painted_to_modular()
		elif action == "logic_only":
			_enter_painted_logic_only()
	)
	add_child(painted_dynamic_dialog)


func _build_lab_import_dialog() -> void:
	lab_import_dialog = ConfirmationDialog.new()
	lab_import_dialog.title = "CARTE REÇUE DU LABORATOIRE"
	lab_import_dialog.size = Vector2i(720, 620)
	lab_import_dialog.ok_button_text = "Ouvrir comme version en cours"
	lab_import_dialog.cancel_button_text = "Annuler"
	lab_import_dialog.add_button("Importer comme nouvelle arène", false, "import_new")
	lab_import_dialog.add_button("Supprimer", false, "delete")
	lab_import_dialog.confirmed.connect(func(): _open_pending_lab_transfer(false))
	lab_import_dialog.custom_action.connect(func(action):
		lab_import_dialog.hide()
		if action == "import_new":
			_open_pending_lab_transfer(true)
		elif action == "delete":
			_delete_pending_lab_transfer()
	)
	var content := VBoxContainer.new()
	lab_import_dialog.add_child(content)
	lab_import_thumbnail = TextureRect.new()
	lab_import_thumbnail.custom_minimum_size = Vector2(640, 260)
	lab_import_thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lab_import_thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(lab_import_thumbnail)
	lab_import_summary = RichTextLabel.new()
	lab_import_summary.bbcode_enabled = true
	lab_import_summary.fit_content = true
	lab_import_summary.custom_minimum_size.y = 220
	content.add_child(lab_import_summary)
	add_child(lab_import_dialog)


func _convert_painted_to_hybrid() -> void:
	_convert_painted_working_copy(ArenaDefinition.VisualMode.HYBRID)


func _convert_painted_to_hybrid_all() -> void:
	_convert_painted_working_copy(
		ArenaDefinition.VisualMode.HYBRID,
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)


func _convert_painted_to_modular() -> void:
	_convert_painted_working_copy(ArenaDefinition.VisualMode.MODULAR)


func _convert_painted_working_copy(
		target_mode: int,
		hybrid_policy := ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS
	) -> void:
	if arena == null or edit_session == null:
		return
	var before := arena.to_snapshot().duplicate(true)
	arena.visual_mode = target_mode
	if arena.modular_visual_profile == null:
		arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = arena.theme_id
	arena.modular_visual_profile.base_terrain_id = &"stone"
	arena.modular_visual_profile.hybrid_floor_policy = hybrid_policy
	_painted_logic_only_active = false
	_commit_change(
		"Créer une version en cours %s" % (
			"hybride" if target_mode == ArenaDefinition.VisualMode.HYBRID else "modulaire"
		),
		before,
		arena.to_snapshot()
	)
	canvas.set_arena(arena)
	_enter_dynamic_construction()
	if target_mode == ArenaDefinition.VisualMode.HYBRID \
			and hybrid_policy == ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED:
		_set_status(
			"TOUTES LES DALLES TACTIQUES : normal/stone utilisent stone.png au-dessus du décor."
		)


func _enter_painted_logic_only() -> void:
	_painted_logic_only_active = true
	canvas.set_painted_logic_only(true)
	_enter_dynamic_construction()


func _populate_hybrid_floor_policy_options(option: OptionButton) -> void:
	if option == null:
		return
	option.clear()
	for item in [
		["Décor seul — aucune dalle", ArenaModularVisualProfile.HybridFloorPolicy.NONE],
		["Terrains spéciaux — pierre masquée", ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS],
		["TOUTES LES DALLES TACTIQUES — pierre incluse", ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED],
	]:
		option.add_item(item[0])
		option.set_item_metadata(option.item_count - 1, item[1])


func _hybrid_floor_policy_option_index(option: OptionButton, policy: int) -> int:
	if option == null:
		return -1
	for index in range(option.item_count):
		if int(option.get_item_metadata(index)) == policy:
			return index
	return -1


func _hybrid_floor_policy_display_name(policy: int) -> String:
	match policy:
		ArenaModularVisualProfile.HybridFloorPolicy.NONE:
			return "décor seul"
		ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS:
			return "terrains spéciaux — pierre masquée"
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED:
			return "TOUTES LES DALLES TACTIQUES — pierre incluse"
	return "politique inconnue"


func _on_hybrid_floor_policy_selected(index: int) -> void:
	if hybrid_floor_policy_option == null or index < 0 \
			or index >= hybrid_floor_policy_option.item_count:
		return
	set_hybrid_floor_policy(int(hybrid_floor_policy_option.get_item_metadata(index)))


func _on_dynamic_base_terrain_selected(index: int) -> void:
	if dynamic_base_terrain_option == null or index < 0 \
			or index >= dynamic_base_terrain_option.item_count:
		return
	set_dynamic_base_terrain(StringName(
		dynamic_base_terrain_option.get_item_metadata(index)
	))


func set_dynamic_base_terrain(terrain_id: StringName) -> bool:
	if arena == null or edit_session == null \
			or arena.visual_mode == ArenaDefinition.VisualMode.PAINTED \
			or terrain_id not in [&"stone", &"neutral"]:
		return false
	var before := arena.to_snapshot().duplicate(true)
	if arena.modular_visual_profile == null:
		arena.modular_visual_profile = ArenaModularVisualProfile.new()
		arena.modular_visual_profile.theme_id = arena.theme_id
	if arena.modular_visual_profile.base_terrain_id == terrain_id:
		return true
	arena.modular_visual_profile.base_terrain_id = terrain_id
	if not arena.modular_visual_profile.terrain_ids.has(terrain_id):
		arena.modular_visual_profile.terrain_ids.append(terrain_id)
	ArenaTerrainRenderPlanService.clear_cache()
	_commit_change("Choisir le sol de base %s" % terrain_id, before, arena.to_snapshot())
	_refresh_all()
	return true


func set_hybrid_floor_policy(policy: int) -> bool:
	if arena == null or edit_session == null \
			or arena.visual_mode != ArenaDefinition.VisualMode.HYBRID:
		return false
	policy = clampi(
		policy,
		ArenaModularVisualProfile.HybridFloorPolicy.NONE,
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	var before := arena.to_snapshot().duplicate(true)
	var profile_was_missing := arena.modular_visual_profile == null
	if arena.modular_visual_profile == null:
		arena.modular_visual_profile = ArenaModularVisualProfile.new()
		arena.modular_visual_profile.theme_id = arena.theme_id
	if not profile_was_missing and arena.modular_visual_profile.hybrid_floor_policy == policy:
		return true
	arena.modular_visual_profile.hybrid_floor_policy = policy
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	_commit_change(
		"Sol hybride : %s" % _hybrid_floor_policy_display_name(policy),
		before,
		arena.to_snapshot()
	)
	_refresh_all()
	var plan := ArenaTerrainRenderPlanService.build(arena)
	_set_status("Sol hybride : %s • %d dalle(s) tactique(s) rendue(s)." % [
		_hybrid_floor_policy_display_name(policy),
		int(plan.expected_terrain_cell_count),
	])
	return true


func _build_production_dialog() -> void:
	production_dialog = ConfirmationDialog.new()
	production_dialog.title = "INTÉGRER LA SALLE — production guidée et transactionnelle"
	production_dialog.size = Vector2i(920, 680)
	production_dialog.ok_button_text = "Intégrer à la partie"
	production_dialog.cancel_button_text = "Annuler"
	production_dialog.confirmed.connect(_production_confirmed)
	add_child(production_dialog)
	production_tabs = TabContainer.new()
	production_tabs.custom_minimum_size = Vector2(880, 570)
	production_dialog.add_child(production_tabs)
	var identity := _production_tab("1 — Identité")
	identity.add_child(_section_label("ÉTAPE 1 — IDENTITÉ"))
	production_summary_text = _production_text(150)
	identity.add_child(production_summary_text)
	production_name_edit = _labeled_line(identity, "Nom", "Nom visible")
	production_id_edit = _labeled_line(identity, "Identifiant", "identifiant_stable")
	production_theme_edit = _labeled_line(identity, "Biome / thème", "dynamic_default")
	production_name_edit.text_changed.connect(func(_text): call_deferred("_refresh_production_wizard"))
	production_id_edit.text_changed.connect(func(_text): call_deferred("_refresh_production_wizard"))
	production_theme_edit.text_changed.connect(func(_text): call_deferred("_refresh_production_wizard"))
	production_mode_option = OptionButton.new()
	for label in VISUAL_MODE_LABELS:
		production_mode_option.add_item(label)
	production_mode_option.item_selected.connect(func(_index): call_deferred("_refresh_production_wizard"))
	identity.add_child(Label.new())
	(identity.get_child(identity.get_child_count() - 1) as Label).text = "Mode visuel"
	identity.add_child(production_mode_option)
	production_destination_edit = _labeled_line(
		identity, "Chemin de destination", ArenaProductionService.DEFAULT_ROOT
	)
	production_destination_edit.text_changed.connect(func(_text): call_deferred("_refresh_production_wizard"))
	identity.add_child(_section_label("DESTINATION DE LA SALLE"))
	production_run_option = OptionButton.new()
	production_run_option.item_selected.connect(func(_index): _refresh_production_wizard())
	identity.add_child(production_run_option)
	production_action_option = OptionButton.new()
	for entry in [
		["Mettre à jour l’arène de cette salle — recommandé", ArenaProductionAttachmentService.UPDATE],
		["Créer une nouvelle salle", ArenaProductionAttachmentService.APPEND],
		["Insérer la salle avant", ArenaProductionAttachmentService.INSERT_BEFORE],
		["Insérer la salle après", ArenaProductionAttachmentService.INSERT_AFTER],
		["Remplacer toute la salle — avancé", ArenaProductionAttachmentService.REPLACE],
		["Produire sans intégrer", ArenaProductionAttachmentService.NONE],
	]:
		production_action_option.add_item(entry[0])
		production_action_option.set_item_metadata(
			production_action_option.item_count - 1, entry[1]
		)
	production_action_option.item_selected.connect(func(_index): _refresh_production_wizard())
	identity.add_child(production_action_option)
	production_index_spin = _spin(identity, "Index de salle", 0, 0, 999)
	production_index_spin.value_changed.connect(func(_value): _refresh_production_wizard())
	var identity_note := Label.new()
	identity_note.text = "Aucun fichier n'est écrit avant le clic « Intégrer à la partie »."
	identity_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(identity_note)
	var validation_tab := _production_tab("2 — Validation")
	validation_tab.add_child(_section_label("ÉTAPE 2 — VALIDATION"))
	production_validation_text = _production_text()
	validation_tab.add_child(production_validation_text)
	var preview_tab := _production_tab("3 — Aperçu")
	preview_tab.add_child(_section_label("ÉTAPE 3 — APERÇU DU JEU RÉEL"))
	production_preview_text = _production_text()
	preview_tab.add_child(production_preview_text)
	var preview_buttons := HBoxContainer.new()
	preview_tab.add_child(preview_buttons)
	_add_button(preview_buttons, "Logique", func(): set_preview_view(ArenaRuntimePreview.ViewMode.LOGIC))
	_add_button(preview_buttons, "Art", func(): set_preview_view(ArenaRuntimePreview.ViewMode.ART))
	_add_button(preview_buttons, "Jeu", func(): set_preview_view(ArenaRuntimePreview.ViewMode.GAME))
	_add_button(preview_buttons, "Exporter le kit artistique", _export_art_kit_from_wizard)
	_add_button(preview_buttons, "Importer le décor...", _show_art_reimport_dialog)
	var plan_tab := _production_tab("4 — Production")
	plan_tab.add_child(_section_label("ÉTAPE 4 — FICHIERS ET CONFLITS"))
	production_plan_text = _production_text()
	plan_tab.add_child(production_plan_text)
	production_resolution_text = _production_text(190)
	plan_tab.add_child(production_resolution_text)
	var resolution_actions := HFlowContainer.new()
	resolution_actions.name = "BundleResolutionActions"
	plan_tab.add_child(resolution_actions)
	for entry in [
		["Reprendre", ArenaBundleResolutionService.RESUME_INTERRUPTED],
		["Archiver puis reconstruire", ArenaBundleResolutionService.ARCHIVE_AND_REBUILD],
		["Nouvelle version à côté", ArenaBundleResolutionService.VERSION_ALONGSIDE],
		["Retirer du projet", ArenaBundleResolutionService.REMOVE_FROM_PROJECT],
		["Examiner les fichiers", ArenaBundleResolutionService.EXAMINE_FILES],
	]:
		var action_id := StringName(entry[1])
		var action_button := _add_button(
			resolution_actions, str(entry[0]),
			_on_bundle_resolution_action.bind(action_id)
		)
		action_button.name = "BundleResolution%sButton" % str(action_id).to_pascal_case()
		action_button.visible = false
		production_resolution_buttons[action_id] = action_button
	var refresh_button := _add_button(plan_tab, "Recalculer le plan", _refresh_production_wizard)
	refresh_button.tooltip_text = "Lecture seule : recalcule créations, modifications et conflits."
	var dashboard_tab := _production_tab("5 — Productions et récupérations")
	dashboard_tab.add_child(_section_label("PRODUCTIONS ET RÉCUPÉRATIONS"))
	production_dashboard_text = _production_text()
	dashboard_tab.add_child(production_dashboard_text)
	var dashboard_refresh := _add_button(dashboard_tab, "Actualiser l’inventaire", _refresh_production_dashboard)
	dashboard_refresh.tooltip_text = "Lecture seule : aucune suppression ni archive n'est déclenchée."
	var sandbox_button := _add_button(dashboard_tab, "Démarrer l’exercice d’entraînement", _start_guided_sandbox)
	sandbox_button.tooltip_text = "Crée une arène et une partie d'essai uniquement dans la sauvegarde locale du Studio."
	var result_tab := _production_tab("6 — Résultat")
	result_tab.add_child(_section_label("ÉTAPE 5 — RÉSULTAT"))
	production_result_text = _production_text()
	result_tab.add_child(production_result_text)
	bundle_resolution_dialog = ConfirmationDialog.new()
	bundle_resolution_dialog.title = "Résoudre le dossier de production"
	bundle_resolution_dialog.ok_button_text = "Confirmer l’action"
	bundle_resolution_dialog.cancel_button_text = "Annuler"
	bundle_resolution_dialog.confirmed.connect(_confirm_bundle_resolution_action)
	add_child(bundle_resolution_dialog)
	bundle_resolution_confirmation_text = _production_text(260)
	bundle_resolution_dialog.add_child(bundle_resolution_confirmation_text)


func _production_tab(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	production_tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return content


func _production_text(minimum_height := 410) -> RichTextLabel:
	var value := RichTextLabel.new()
	value.bbcode_enabled = true
	value.fit_content = false
	value.scroll_active = true
	value.size_flags_vertical = Control.SIZE_EXPAND_FILL
	value.custom_minimum_size.y = minimum_height
	return value


func _build_migration_dialog() -> void:
	migration_dialog = ConfirmationDialog.new()
	migration_dialog.title = "Migration de l'arène requise"
	migration_dialog.dialog_text = (
		"Ce document utilise un ancien schéma.\n\n"
		+ "Migrer crée une version en cours v2 et une action annulable. "
		+ "Ouvrir en lecture seule conserve exactement les données anciennes."
	)
	migration_dialog.ok_button_text = "Migrer la version en cours"
	migration_dialog.cancel_button_text = "Annuler"
	migration_dialog.add_button("Ouvrir en lecture seule", false, "read_only")
	migration_dialog.confirmed.connect(_confirm_pending_migration)
	migration_dialog.custom_action.connect(func(action):
		if action == "read_only":
			_open_pending_migration_read_only()
	)
	add_child(migration_dialog)
	_build_terrain_replace_dialog()
	_build_backdrop_dialog()
	_build_vortex_dialog()


func _quick_terrain_ids() -> Array[StringName]:
	return [
		&"stone", &"neutral", &"water", &"ice", &"lava", &"poison",
		&"steam", &"electrified_water",
	]


func _build_terrain_replace_dialog() -> void:
	terrain_replace_dialog = ConfirmationDialog.new()
	terrain_replace_dialog.title = "Remplacement global de terrain"
	terrain_replace_dialog.size = Vector2i(620, 300)
	terrain_replace_dialog.ok_button_text = "Remplacer — une action annulable"
	terrain_replace_dialog.confirmed.connect(_confirm_terrain_replacement)
	add_child(terrain_replace_dialog)
	var box := VBoxContainer.new()
	terrain_replace_dialog.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	terrain_replace_from = OptionButton.new()
	terrain_replace_to = OptionButton.new()
	for terrain_id in _quick_terrain_ids():
		var name := str(ArenaTerrainRegistry.get_entry(terrain_id).get("name", terrain_id))
		terrain_replace_from.add_item(name)
		terrain_replace_from.set_item_metadata(terrain_replace_from.item_count - 1, terrain_id)
		terrain_replace_to.add_item(name)
		terrain_replace_to.set_item_metadata(terrain_replace_to.item_count - 1, terrain_id)
	row.add_child(terrain_replace_from)
	var arrow := Label.new()
	arrow.text = " → "
	row.add_child(arrow)
	row.add_child(terrain_replace_to)
	terrain_replace_summary = Label.new()
	terrain_replace_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(terrain_replace_summary)
	terrain_replace_from.item_selected.connect(func(_index): _refresh_terrain_replace_summary())
	terrain_replace_to.item_selected.connect(func(_index): _refresh_terrain_replace_summary())


func _show_terrain_replace_dialog() -> void:
	if arena == null:
		return
	_refresh_terrain_replace_summary()
	terrain_replace_dialog.popup_centered()


func _refresh_terrain_replace_summary() -> void:
	if arena == null or terrain_replace_summary == null:
		return
	var from_id := StringName(terrain_replace_from.get_selected_metadata())
	var to_id := StringName(terrain_replace_to.get_selected_metadata())
	var count := ArenaStrokeBatchService.replacement_cells(arena, from_id).size()
	terrain_replace_summary.text = (
		"Aperçu : %d cellule(s). %s → %s.\nEffet cible : %s\n"
		+ "La topologie, les spawns et les vortex restent inchangés."
	) % [count, from_id, to_id, _terrain_palette_summary(to_id)]
	terrain_replace_dialog.get_ok_button().disabled = count == 0 or from_id == to_id


func _confirm_terrain_replacement() -> void:
	if arena == null:
		return
	var from_id := StringName(terrain_replace_from.get_selected_metadata())
	var to_id := StringName(terrain_replace_to.get_selected_metadata())
	var cells := ArenaStrokeBatchService.replacement_cells(arena, from_id)
	if cells.is_empty() or from_id == to_id:
		return
	stroke_batch.begin_stroke(arena)
	var changed := stroke_batch.apply_terrain_cells(cells, to_id)
	var result := stroke_batch.finish()
	if changed.is_empty():
		return
	_commit_change(
		"Remplacer %s par %s — %d case(s)" % [from_id, to_id, changed.size()],
		result.get("before", {}), result.get("after", {})
	)
	canvas.update_terrain_cells(changed)
	_refresh_all(false)
	_select_quick_terrain(to_id)
	_set_status("Remplacement terminé : %d cellule(s), une synchronisation et une action annulable." % changed.size())


func _build_backdrop_dialog() -> void:
	backdrop_dialog = ConfirmationDialog.new()
	backdrop_dialog.title = "DÉCOR DE L’ARÈNE"
	backdrop_dialog.size = Vector2i(680, 500)
	backdrop_dialog.ok_button_text = "Appliquer à la version en cours"
	backdrop_dialog.confirmed.connect(_confirm_backdrop_change)
	backdrop_dialog.canceled.connect(_close_backdrop_preview)
	backdrop_dialog.close_requested.connect(_close_backdrop_preview)
	add_child(backdrop_dialog)
	backdrop_dialog.get_cancel_button().text = "Annuler et fermer"
	var box := VBoxContainer.new()
	backdrop_dialog.add_child(box)
	backdrop_state_label = Label.new()
	backdrop_state_label.text = "APERÇU — VERSION EN COURS NON MODIFIÉE"
	backdrop_state_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.34))
	box.add_child(backdrop_state_label)
	var source_label := Label.new()
	source_label.text = "Source du décor"
	box.add_child(source_label)
	backdrop_source_option = OptionButton.new()
	backdrop_source_option.item_selected.connect(func(_index): _refresh_backdrop_summary())
	box.add_child(backdrop_source_option)
	var mode_label := Label.new()
	mode_label.text = "Éléments à adopter"
	box.add_child(mode_label)
	backdrop_mode_option = OptionButton.new()
	for entry in [
		["Fond uniquement", ArenaBackdropTransactionService.CopyMode.BACKGROUND_ONLY],
		["Décor + calibration + caméra (recommandé)", ArenaBackdropTransactionService.CopyMode.DECOR_CALIBRATION_CAMERA],
		["Pack visuel complet", ArenaBackdropTransactionService.CopyMode.FULL_VISUAL_PACK],
	]:
		backdrop_mode_option.add_item(entry[0])
		backdrop_mode_option.set_item_metadata(backdrop_mode_option.item_count - 1, entry[1])
	backdrop_mode_option.select(1)
	backdrop_mode_option.item_selected.connect(func(_index): _refresh_backdrop_summary())
	box.add_child(backdrop_mode_option)
	var actions := HFlowContainer.new()
	box.add_child(actions)
	_add_button(actions, "Importer une image…", func(): backdrop_image_dialog.popup_centered())
	_add_button(actions, "Annuler le dernier changement de décor", _restore_previous_backdrop)
	var compare_row := HBoxContainer.new()
	box.add_child(compare_row)
	var old_label := Label.new()
	old_label.text = "Ancien"
	compare_row.add_child(old_label)
	backdrop_compare_slider = HSlider.new()
	backdrop_compare_slider.min_value = 0.0
	backdrop_compare_slider.max_value = 1.0
	backdrop_compare_slider.step = 0.05
	backdrop_compare_slider.value = 1.0
	backdrop_compare_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backdrop_compare_slider.tooltip_text = "Comparer avant/après par opacité du nouveau fond"
	backdrop_compare_slider.value_changed.connect(func(value):
		if canvas != null:
			canvas.background_opacity = float(value)
			canvas.queue_redraw()
		if backdrop_compare_value_label != null:
			backdrop_compare_value_label.text = "%d %%" % roundi(float(value) * 100.0)
	)
	compare_row.add_child(backdrop_compare_slider)
	var new_label := Label.new()
	new_label.text = "Nouveau"
	compare_row.add_child(new_label)
	backdrop_compare_value_label = Label.new()
	backdrop_compare_value_label.text = "100 %"
	backdrop_compare_value_label.custom_minimum_size.x = 54
	compare_row.add_child(backdrop_compare_value_label)
	backdrop_summary = Label.new()
	backdrop_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	backdrop_summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(backdrop_summary)
	backdrop_image_dialog = FileDialog.new()
	backdrop_image_dialog.title = "Importer une image de fond dans la zone de préparation"
	backdrop_image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	backdrop_image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	backdrop_image_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	backdrop_image_dialog.file_selected.connect(_stage_external_backdrop)
	add_child(backdrop_image_dialog)


func _show_backdrop_dialog() -> void:
	if arena == null:
		return
	backdrop_state_label.text = "APERÇU — VERSION EN COURS NON MODIFIÉE"
	backdrop_compare_slider.value = 1.0
	_backdrop_sources = ArenaBackdropCatalogService.discover()
	backdrop_source_option.clear()
	for index in range(_backdrop_sources.size()):
		var source := _backdrop_sources[index]
		backdrop_source_option.add_item(source.display_name)
		backdrop_source_option.set_item_metadata(index, index)
		if source.source_id == &"greece":
			backdrop_source_option.select(index)
	_refresh_backdrop_summary()
	backdrop_dialog.popup_centered()


func _selected_backdrop_source() -> ArenaBackdropSourceDefinition:
	if backdrop_source_option == null or backdrop_source_option.selected < 0:
		return null
	var index := int(backdrop_source_option.get_selected_metadata())
	return _backdrop_sources[index] if index >= 0 and index < _backdrop_sources.size() else null


func _refresh_backdrop_summary() -> void:
	var source := _selected_backdrop_source()
	if arena == null or source == null:
		backdrop_summary.text = "Aucune source de décor compatible découverte."
		backdrop_dialog.get_ok_button().disabled = true
		_close_backdrop_preview()
		return
	var mode := int(backdrop_mode_option.get_selected_metadata())
	var inspection := backdrop_transaction.inspect(arena, source, mode)
	backdrop_dialog.get_ok_button().disabled = not bool(inspection.get("ok", false))
	var source_kind := "catalogue Arena Studio"
	if source.background_path.begins_with("user://dungeon_draft_studio/backdrop_staging/"):
		source_kind = "import local (zone de préparation temporaire)"
	elif not source.source_run_path.is_empty():
		source_kind = "une autre partie"
	elif not source.source_arena_path.is_empty():
		source_kind = "une autre arène"
	var adopts_calibration := mode >= ArenaBackdropTransactionService.CopyMode.DECOR_CALIBRATION_CAMERA \
		and source.calibration_available
	var adopts_camera := mode >= ArenaBackdropTransactionService.CopyMode.DECOR_CALIBRATION_CAMERA
	canvas.set_backdrop_preview(
		source.background_path,
		source.source_image_size,
		source.image_offset if adopts_calibration else arena.image_offset,
		source.image_scale if adopts_calibration else arena.image_scale
	)
	backdrop_summary.text = (
		"Image : %s\nSource : %s — %s\nAncien fond : %s\nNouveau fond : %s\n"
		+ "Calibration adoptée : %s\nCaméra adoptée : %s\nTopologie : inchangée\n"
		+ "Le gameplay, les terrains, spawns, objectifs et vortex seront vérifiés avant application."
	) % [
		source.background_path.get_file(), source_kind, source.display_name,
		arena.source_image_size, source.source_image_size,
		"oui" if adopts_calibration else "non",
		"oui" if adopts_camera else "non",
	]
	backdrop_summary.tooltip_text = "Chemin technique : %s" % source.background_path


func _close_backdrop_preview() -> void:
	if canvas != null:
		canvas.clear_backdrop_preview()


func _confirm_backdrop_change() -> void:
	var source := _selected_backdrop_source()
	if arena == null or source == null:
		return
	var mode := int(backdrop_mode_option.get_selected_metadata())
	var result := backdrop_transaction.apply(arena, source, mode)
	if not bool(result.get("ok", false)):
		_set_status("Décor refusé : %s" % result.get("error", "inconnu"), true)
		return
	_commit_change("Changer le décor — %s" % source.display_name, result.before, result.after)
	_close_backdrop_preview()
	canvas.set_arena(arena)
	_refresh_all(false)
	_set_status("APPLIQUÉ À LA VERSION EN COURS — NON SAUVEGARDÉ. Gameplay inchangé ; Annuler/Rétablir disponible.")


func _restore_previous_backdrop() -> void:
	if arena == null:
		return
	var action_name := history_undo_name()
	if history_can_undo() and "décor" in action_name.to_lower():
		history_undo()
		_set_status("Dernier changement de décor annulé via l'historique Arena.")
	else:
		_set_status("Aucun changement de décor immédiatement annulable dans l'historique.", true)


func _stage_external_backdrop(path: String) -> void:
	var staged := ArenaBackdropTransactionService.stage_external_image(path)
	if not bool(staged.get("ok", false)):
		_set_status("Import du décor refusé : %s" % staged.get("error", "inconnu"), true)
		return
	var image := Image.load_from_file(ProjectSettings.globalize_path(str(staged.staged_path)))
	if image == null or image.is_empty():
		_set_status("Image de décor illisible après préparation.", true)
		return
	var source := ArenaBackdropSourceDefinition.from_arena(arena)
	source.source_id = StringName("external_%s" % str(staged.sha256).left(12))
	source.display_name = "Image importée — %s" % path.get_file()
	source.background_path = str(staged.staged_path)
	source.source_image_size = image.get_size()
	_backdrop_sources.append(source)
	backdrop_source_option.add_item(source.display_name)
	backdrop_source_option.set_item_metadata(backdrop_source_option.item_count - 1, _backdrop_sources.size() - 1)
	backdrop_source_option.select(backdrop_source_option.item_count - 1)
	_refresh_backdrop_summary()


func _build_vortex_dialog() -> void:
	vortex_dialog = ConfirmationDialog.new()
	vortex_dialog.title = "VORTEX — réseaux"
	vortex_dialog.size = Vector2i(640, 420)
	vortex_dialog.ok_button_text = "Fermer"
	add_child(vortex_dialog)
	var box := VBoxContainer.new()
	vortex_dialog.add_child(box)
	vortex_network_option = OptionButton.new()
	vortex_network_option.item_selected.connect(_on_vortex_network_selected)
	box.add_child(vortex_network_option)
	var actions := HFlowContainer.new()
	box.add_child(actions)
	_add_button(actions, "Nouveau réseau", _create_vortex_network)
	_add_button(actions, "Ajouter une dalle", _activate_vortex_network_tool)
	_add_button(actions, "Retirer : clic droit", _activate_vortex_network_tool)
	vortex_name_edit = LineEdit.new()
	vortex_name_edit.placeholder_text = "Nom du réseau"
	actions.add_child(vortex_name_edit)
	_add_button(actions, "Renommer", _rename_vortex_network)
	_add_button(actions, "Supprimer", _delete_vortex_network)
	vortex_summary = Label.new()
	vortex_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(vortex_summary)


func _show_vortex_dialog() -> void:
	if arena == null:
		return
	ArenaVortexNetworkService.migrate_legacy_pairs(arena)
	_refresh_vortex_dialog()
	vortex_dialog.popup_centered()


func _refresh_vortex_dialog() -> void:
	if vortex_network_option == null or arena == null:
		return
	vortex_network_option.clear()
	var selected_index := -1
	for index in range(arena.vortex_networks.size()):
		var network := arena.vortex_networks[index]
		if network == null:
			continue
		vortex_network_option.add_item("%s — %d sortie(s)" % [network.display_name, network.unique_cells().size()])
		vortex_network_option.set_item_metadata(vortex_network_option.item_count - 1, network.network_id)
		if network.network_id == _active_vortex_network_id:
			selected_index = vortex_network_option.item_count - 1
	if selected_index < 0 and vortex_network_option.item_count > 0:
		selected_index = 0
	if selected_index >= 0:
		vortex_network_option.select(selected_index)
		_active_vortex_network_id = StringName(vortex_network_option.get_item_metadata(selected_index))
	_refresh_vortex_summary()


func _on_vortex_network_selected(index: int) -> void:
	if index >= 0 and index < vortex_network_option.item_count:
		_active_vortex_network_id = StringName(vortex_network_option.get_item_metadata(index))
	_refresh_vortex_summary()


func _refresh_vortex_summary() -> void:
	var network := ArenaVortexNetworkService.network_by_id(arena, _active_vortex_network_id)
	if network == null:
		vortex_summary.text = "Aucun réseau. Créez-en un, puis cliquez ses dalles sur le canvas."
		return
	var count := network.unique_cells().size()
	var probability := ""
	if count >= 3:
		probability = "\nChaque autre sortie valide : %.1f %% avant filtrage occupation/VOID." % (100.0 / float(count - 1))
	vortex_summary.text = "%s\nID : %s\n%s%s" % [
		network.display_name, network.network_id,
		ArenaVortexNetworkService.behavior_summary(network), probability,
	]
	vortex_name_edit.text = network.display_name


func _create_vortex_network() -> void:
	if arena == null:
		return
	var before := arena.to_snapshot()
	var network := ArenaVortexNetworkService.create_network(arena)
	_active_vortex_network_id = network.network_id
	_commit_change("Créer un réseau de vortex", before, arena.to_snapshot())
	_refresh_vortex_dialog()
	_activate_vortex_network_tool()


func _rename_vortex_network() -> void:
	var network := ArenaVortexNetworkService.network_by_id(arena, _active_vortex_network_id)
	var name := vortex_name_edit.text.strip_edges()
	if network == null or name.is_empty() or network.display_name == name:
		return
	var before := arena.to_snapshot()
	network.display_name = name
	_commit_change("Renommer le réseau de vortex", before, arena.to_snapshot())
	_refresh_vortex_dialog()


func _delete_vortex_network() -> void:
	if arena == null:
		return
	var before := arena.to_snapshot()
	if not ArenaVortexNetworkService.delete_network(arena, _active_vortex_network_id):
		return
	_active_vortex_network_id = &""
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	_commit_change("Supprimer le réseau de vortex", before, arena.to_snapshot())
	_refresh_vortex_dialog()
	canvas.queue_redraw()


func _activate_vortex_network_tool() -> void:
	if arena == null:
		return
	if ArenaVortexNetworkService.network_by_id(arena, _active_vortex_network_id) == null:
		_create_vortex_network()
		return
	for index in range(dynamic_special_option.item_count):
		if StringName(dynamic_special_option.get_item_metadata(index)) == &"vortex_network":
			dynamic_special_option.select(index)
			break
	_select_dynamic_tool(ArenaStudioCanvas.Tool.SPAWN)
	_set_status("Réseau actif %s : clic ajoute, clic droit retire." % _active_vortex_network_id)


func _connect_canvas() -> void:
	canvas.stroke_started.connect(_on_stroke_started)
	canvas.cells_edit_requested.connect(_on_cells_edit_requested)
	canvas.stroke_finished.connect(_on_stroke_finished)
	canvas.stroke_cancelled.connect(_on_stroke_cancelled)
	canvas.calibration_requested.connect(_on_calibration_requested)
	canvas.calibration_preview_requested.connect(_on_calibration_preview)
	canvas.anchors_preview_requested.connect(_on_anchors_preview)
	canvas.transform_commit_requested.connect(_on_transform_commit_requested)
	canvas.hovered_cell_changed.connect(_on_hovered_cell_changed)
	canvas.verification_cell_requested.connect(_on_verification_cell_requested)
	canvas.terrain_pick_requested.connect(_on_terrain_pick_requested)


func _set_arena(value: ArenaDefinition, mark_dirty: bool, key := "") -> void:
	if value == null:
		return
	if canvas != null and canvas.has_method("cancel_active_gesture"):
		canvas.cancel_active_gesture()
	var session_key := key if not key.is_empty() else (
		value.resource_path if not value.resource_path.is_empty() else str(value.arena_id)
	)
	var next_session := ArenaEditSession.new()
	if not next_session.open(value, value.resource_path, mark_dirty, session_key):
		_set_status("La version en cours de l'arène n'a pas pu être créée.", true)
		return
	_sessions[session_key] = next_session
	_activate_session(next_session)


func _activate_session(next_session: ArenaEditSession) -> void:
	_save_session_editor_state()
	if edit_session != null:
		if edit_session.history.history_changed.is_connected(_on_history_changed):
			edit_session.history.history_changed.disconnect(_on_history_changed)
		if edit_session.history.dirty_state_changed.is_connected(_on_dirty_state_changed):
			edit_session.history.dirty_state_changed.disconnect(_on_dirty_state_changed)
	edit_session = next_session
	arena = edit_session.working_arena
	_painted_logic_only_active = false
	_fallback_undo = edit_session.history.undo_redo
	edit_session.history.history_changed.connect(_on_history_changed)
	edit_session.history.dirty_state_changed.connect(_on_dirty_state_changed)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	canvas.set_arena(arena)
	_clear_pending_vortex()
	canvas.set_painted_logic_only(false)
	canvas.set_saved_transform(edit_session.saved_transform())
	_restore_session_editor_state()
	_verification_source = GridTransformService.INVALID_CELL
	validation_report = null
	validation_list.clear()
	_sync_advanced_values()
	_refresh_title()
	_refresh_calibration_label()
	_refresh_inspector(GridTransformService.INVALID_CELL)
	_refresh_restore_points()
	_refresh_dynamic_palette()
	_refresh_destination_panel()
	if runtime_preview != null:
		runtime_preview.set_runtime_context(
			project_context.active_run if project_context != null else null
		)
		runtime_preview.set_arena(arena)
	_tested_once = false
	_draft_saved = ArenaDraftSaveService.has_draft(arena.arena_id) if arena != null else false
	_integration_label = ""
	_remember_recent_document()
	_refresh_workflow()
	history_state_changed.emit()


func _show_new_dialog() -> void:
	new_name_edit.text = "Nouvelle arène"
	new_id_edit.text = "nouvelle_arene"
	new_image_edit.text = ""
	if new_visual_mode_option != null:
		new_visual_mode_option.select(ArenaDefinition.VisualMode.PAINTED)
	new_dialog.popup_centered()


func _show_image_dialog() -> void:
	image_dialog.popup_centered()


func _show_open_dialog() -> void:
	open_dialog.popup_centered()


func _create_from_wizard() -> void:
	var requested_id := ArenaDefinition.sanitize_id(new_id_edit.text)
	var created: ArenaDefinition
	if new_template_option.selected > 0:
		var template_id: StringName = LEGACY_CALIBRATION_TEMPLATES[new_template_option.selected - 1][1]
		var template := ArenaLegacyImporter.import_production(template_id)
		created = ArenaLegacyImporter.copy_template(template, new_name_edit.text)
		created.arena_id = StringName(requested_id)
	else:
		created = ArenaDefinition.new()
		created.set_identity(new_name_edit.text, requested_id)
		created.grid_size = Vector2i(int(new_width_spin.value), int(new_height_spin.value))
	created.camp_orientation = new_orientation_option.selected
	created.visual_mode = new_visual_mode_option.selected \
		if new_visual_mode_option != null else ArenaDefinition.VisualMode.PAINTED
	if created.visual_mode in [
		ArenaDefinition.VisualMode.MODULAR,
		ArenaDefinition.VisualMode.HYBRID,
	]:
		created.theme_id = &"dynamic_default"
		created.modular_visual_profile = ArenaModularVisualProfile.new()
		created.modular_visual_profile.theme_id = created.theme_id
		created.modular_visual_profile.hybrid_floor_policy = (
			ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS
		)
		for y in range(created.grid_size.y):
			for x in range(created.grid_size.x):
				ArenaTerrainRegistry.configure_cell(
					created.ensure_cell(Vector2i(x, y)), &"stone"
				)
	if not new_image_edit.text.strip_edges().is_empty():
		var imported_path := _import_image(new_image_edit.text, requested_id)
		if imported_path.is_empty():
			_set_status("L'image n'a pas pu être importée dans le projet.", true)
			return
		created.background_path = imported_path
		var texture := load(imported_path) as Texture2D
		if texture != null:
			created.source_image_size = Vector2i(texture.get_size())
	_set_arena(created, true, "new:%s:%d" % [requested_id, Time.get_ticks_usec()])
	_autosave()
	if created.visual_mode == ArenaDefinition.VisualMode.MODULAR:
		show_dynamic_construction()
		_set_status("Carte modulaire créée : les dalles sont visibles et prêtes à peindre.")
	else:
		start_calibration()
		_set_status("Cliquez trois centres de cases pour aligner la grille.")


## Creation depuis l'assistant a trois cartes. La configuration recue est deja
## traduite en intention utilisateur ; le mode visuel technique n'est calcule
## qu'ici.
func _create_from_wizard_config(config: Dictionary) -> void:
	var requested_id := ArenaDefinition.sanitize_id(str(config.get("arena_id", "")))
	if requested_id.is_empty():
		requested_id = ArenaDefinition.sanitize_id(str(config.get("display_name", "terrain")))
	var visual_mode := int(config.get("visual_mode", ArenaDefinition.VisualMode.MODULAR))
	var created: ArenaDefinition
	var template_index := int(config.get("template_index", 0))
	if template_index > 0 and template_index <= LEGACY_CALIBRATION_TEMPLATES.size():
		var template_id: StringName = LEGACY_CALIBRATION_TEMPLATES[template_index - 1][1]
		var template := ArenaLegacyImporter.import_production(template_id)
		created = ArenaLegacyImporter.copy_template(template, str(config.display_name))
		created.arena_id = StringName(requested_id)
	else:
		created = ArenaDefinition.new()
		created.set_identity(str(config.display_name), requested_id)
		created.grid_size = Vector2i(int(config.width), int(config.height))
	created.camp_orientation = int(config.get("camp_orientation", 0))
	created.visual_mode = visual_mode
	if visual_mode in [
		ArenaDefinition.VisualMode.MODULAR,
		ArenaDefinition.VisualMode.HYBRID,
	]:
		created.theme_id = &"dynamic_default"
		created.modular_visual_profile = ArenaModularVisualProfile.new()
		created.modular_visual_profile.theme_id = created.theme_id
		created.modular_visual_profile.hybrid_floor_policy = (
			ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS
		)
		for y in range(created.grid_size.y):
			for x in range(created.grid_size.x):
				ArenaTerrainRegistry.configure_cell(
					created.ensure_cell(Vector2i(x, y)), &"stone"
				)
	var image_path := str(config.get("image_path", "")).strip_edges()
	if not image_path.is_empty():
		var imported_path := _import_image(image_path, requested_id)
		if imported_path.is_empty():
			_set_status("L'illustration n'a pas pu être importée dans le projet.", true)
			return
		created.background_path = imported_path
		var texture := load(imported_path) as Texture2D
		if texture != null:
			created.source_image_size = Vector2i(texture.get_size())
	_set_arena(created, true, "new:%s:%d" % [requested_id, Time.get_ticks_usec()])
	_autosave()
	show_editor()
	if bool(config.get("needs_image", false)):
		set_current_step(TerrainWorkflowService.Step.SCENERY)
		start_calibration()
		_set_status(
			"Terrain créé. Cliquez trois centres de cases pour aligner la grille sur l'illustration."
		)
	else:
		set_current_step(TerrainWorkflowService.Step.FLOORS)
		_set_status("Terrain créé : choisissez un sol et peignez directement sur la grille.")


func _import_image(source: String, arena_id: String) -> String:
	if source.begins_with("res://"):
		return source
	if not FileAccess.file_exists(source):
		return ""
	var file_name := source.get_file()
	var target_dir := "res://asset/map/painted".path_join(arena_id)
	var target := target_dir.path_join(file_name)
	var absolute_dir := ProjectSettings.globalize_path(target_dir)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return ""
	var error := DirAccess.copy_absolute(source, ProjectSettings.globalize_path(target))
	if error != OK:
		return ""
	if editor_interface != null:
		editor_interface.get_resource_filesystem().scan()
	return target


func _open_canonical(path: String) -> void:
	if _sessions.has(path):
		_activate_session(_sessions[path] as ArenaEditSession)
		show_editor()
		_set_status("Terrain repris : %s" % arena.display_name)
		return
	var loaded := ArenaSerializer.load_canonical(path)
	if loaded == null:
		_set_status("Ce fichier n'est pas un terrain valide du Studio.", true)
		return
	if loaded.schema_version < ArenaDefinition.CURRENT_SCHEMA_VERSION:
		_prompt_migration(loaded, path)
		return
	_set_arena(loaded, false, path)
	show_editor()
	set_current_step(TerrainWorkflowService.Step.SHAPE)
	_set_status("Terrain ouvert : %s" % loaded.display_name)


func pending_lab_transfer_count() -> int:
	return ArenaLabTransferService.pending_transfers().size()


func open_standalone_lab() -> bool:
	const LAB_SCENE := "res://tools/labs/dynamic_arena/DynamicArenaLab.tscn"
	if editor_interface == null or not ResourceLoader.exists(LAB_SCENE):
		_set_status("Ouvrez la scène DynamicArenaLab.tscn pour lancer le laboratoire autonome.", true)
		return false
	editor_interface.open_scene_from_path(LAB_SCENE)
	editor_interface.play_current_scene()
	_set_status("Laboratoire autonome lancé dans sa scène dédiée.")
	return true


func show_lab_import_dialog() -> bool:
	var transfers := ArenaLabTransferService.pending_transfers()
	if transfers.is_empty():
		_set_status("Aucun transfert du laboratoire n'attend d'être importé.")
		return false
	_pending_lab_transfer_id = str(transfers[0].get("transfer_id", ""))
	var loaded := ArenaLabTransferService.load_transfer(_pending_lab_transfer_id)
	if not bool(loaded.get("ok", false)):
		_set_status("Transfert du laboratoire corrompu : %s" % loaded.get("error", "erreur"), true)
		return false
	_pending_lab_arena = loaded.arena as ArenaDefinition
	_pending_lab_manifest = (loaded.manifest as Dictionary).duplicate(true)
	var counts := _pending_lab_manifest.get("terrain_counts", {}) as Dictionary
	lab_import_summary.text = (
		"[b]%s[/b]\n\n"
		+ "Taille : %s\nMode : %s\nTerrains : %s\n"
		+ "Murs : %d   Spawns : %d   Objectifs : %d\n"
		+ "Validation : %s\nEmpreinte : %s"
	) % [
		_pending_lab_manifest.get("name", _pending_lab_arena.display_name),
		str(_pending_lab_manifest.get("grid_size", _pending_lab_manifest.get("size", []))),
		VISUAL_MODE_LABELS[clampi(
			int(_pending_lab_manifest.get("visual_mode", _pending_lab_arena.visual_mode)), 0, 2
		)],
		JSON.stringify(counts),
		int(_pending_lab_manifest.get("wall_count", 0)),
		int(_pending_lab_manifest.get("spawn_count", 0)),
		int(_pending_lab_manifest.get("objective_count", 0)),
		str(_pending_lab_manifest.get("validation_verdict", "INCONNU")),
		str(_pending_lab_manifest.get("arena_fingerprint", "")).left(16),
	]
	lab_import_thumbnail.texture = null
	var thumbnail_path := str(loaded.directory).path_join(
		str(_pending_lab_manifest.get("thumbnail_path", "thumbnail.png"))
	)
	if FileAccess.file_exists(thumbnail_path):
		var thumbnail := Image.load_from_file(ProjectSettings.globalize_path(thumbnail_path))
		if thumbnail != null and not thumbnail.is_empty():
			lab_import_thumbnail.texture = ImageTexture.create_from_image(thumbnail)
	lab_import_dialog.popup_centered()
	return true


func _open_pending_lab_transfer(as_new: bool) -> void:
	if _pending_lab_arena == null or _pending_lab_transfer_id.is_empty():
		return
	var expected := str(_pending_lab_manifest.get(
		"arena_fingerprint", _pending_lab_manifest.get("fingerprint", "")
	))
	var received := ArenaDefinition.new()
	if not received.restore_snapshot(_pending_lab_arena.to_snapshot()):
		_set_status("Le transfert du laboratoire ne peut pas créer de version en cours.", true)
		return
	if as_new:
		received.set_identity(
			_pending_lab_arena.display_name + " (import laboratoire)",
			str(_pending_lab_arena.arena_id) + "_lab_import"
		)
	_set_arena(
		received,
		true,
		"lab_transfer:%s:%s" % [_pending_lab_transfer_id, "new" if as_new else "working"]
	)
	var actual := ArenaEditSession.fingerprint(arena.to_snapshot())
	if not as_new and actual != expected:
		_set_status("Import du laboratoire refusé : l'empreinte de la version en cours diffère.", true)
		return
	ArenaLabTransferService.mark_imported(_pending_lab_transfer_id)
	_set_status(
		"Transfert du laboratoire ouvert sans perte : %d terrains, %d murs, %d spawns." % [
			int(_pending_lab_manifest.get("terrain_count_total", 0)),
			int(_pending_lab_manifest.get("wall_count", 0)),
			int(_pending_lab_manifest.get("spawn_count", 0)),
		]
	)
	_pending_lab_arena = null
	_pending_lab_manifest = {}
	_pending_lab_transfer_id = ""


func _delete_pending_lab_transfer() -> void:
	if _pending_lab_transfer_id.is_empty():
		return
	var transfer_id := _pending_lab_transfer_id
	if ArenaLabTransferService.delete_transfer(transfer_id):
		_set_status("Transfert du laboratoire supprimé : %s" % transfer_id)
	else:
		_set_status("Le transfert du laboratoire n'a pas pu être supprimé.", true)
	_pending_lab_arena = null
	_pending_lab_manifest = {}
	_pending_lab_transfer_id = ""


func import_latest_lab_transfer() -> bool:
	var transfers := ArenaLabTransferService.pending_transfers()
	if transfers.is_empty():
		_set_status("Aucun nouveau transfert du laboratoire ; activation de Construction dynamique.")
		return false
	var transfer_id := str(transfers[0].get("transfer_id", ""))
	var loaded := ArenaLabTransferService.load_transfer(transfer_id)
	if not bool(loaded.get("ok", false)):
		_set_status("Transfert du laboratoire corrompu : %s" % loaded.get("error", "erreur"), true)
		return true
	var transferred := loaded.arena as ArenaDefinition
	if transferred == null:
		_set_status("Le transfert du laboratoire ne contient aucune arène.", true)
		return true
	if transferred.schema_version < ArenaDefinition.CURRENT_SCHEMA_VERSION:
		_pending_migration_transfer_id = transfer_id
		_prompt_migration(transferred, "lab_transfer:%s" % transfer_id)
		return true
	_set_arena(transferred, true, "lab_transfer:%s" % transfer_id)
	ArenaLabTransferService.mark_imported(transfer_id)
	_set_status(
		"Transfert du laboratoire importé et vérifié : %s (%d × %d)." % [
			transferred.display_name, transferred.grid_size.x, transferred.grid_size.y,
		]
	)
	return true


func _poll_lab_transfers() -> void:
	var transfers := ArenaLabTransferService.pending_transfers()
	if transfers.is_empty():
		_announced_transfer_id = ""
		return
	var latest_id := str(transfers[0].get("transfer_id", ""))
	if latest_id == _announced_transfer_id:
		return
	_announced_transfer_id = latest_id
	_set_status(
		"Transfert du laboratoire détecté : cliquez sur « Laboratoire » pour l'importer."
	)


func _prompt_migration(value: ArenaDefinition, key: String) -> void:
	_pending_migration_arena = value
	_pending_migration_key = key
	if migration_dialog != null:
		migration_dialog.dialog_text = (
			"Le document '%s' utilise le schéma v%d.\n\n"
			+ "Migrer crée une version en cours v%d et une action annulable. "
			+ "Ouvrir en lecture seule ne modifie jamais la ressource source."
		) % [value.display_name, value.schema_version, ArenaDefinition.CURRENT_SCHEMA_VERSION]
		migration_dialog.popup_centered()


func _confirm_pending_migration() -> void:
	if _pending_migration_arena == null:
		return
	var original := _pending_migration_arena
	var before := original.to_snapshot().duplicate(true)
	var result := ArenaSchemaMigrator.migrate_snapshot(before)
	if not bool(result.get("ok", false)):
		_set_status("Migration impossible : %s" % result.get("error", "erreur"), true)
		_clear_pending_migration()
		return
	_set_arena(original, false, _pending_migration_key)
	if edit_session == null:
		_clear_pending_migration()
		return
	edit_session.apply_snapshot(result.snapshot)
	arena = edit_session.working_arena
	edit_session.commit(
		"Migrer l'arène v%d vers v%d" % [result.from_version, result.to_version],
		before, arena.to_snapshot()
	)
	canvas.set_arena(arena)
	_refresh_all()
	if not _pending_migration_transfer_id.is_empty():
		ArenaLabTransferService.mark_imported(_pending_migration_transfer_id)
	_set_status("Migration v2 appliquée à la version en cours ; la source reste inchangée.")
	_clear_pending_migration()


func _open_pending_migration_read_only() -> void:
	if _pending_migration_arena == null:
		return
	_set_arena(_pending_migration_arena, false, _pending_migration_key)
	_set_status("Ancien schéma ouvert en lecture seule ; sauvegarde et production bloquées.")
	migration_dialog.hide()
	_clear_pending_migration()


func _clear_pending_migration() -> void:
	_pending_migration_arena = null
	_pending_migration_key = ""
	_pending_migration_transfer_id = ""


## Ecriture canonique. Elle suit desormais le meme contrat transactionnel que
## la production : plan, conflit externe, recuperation, sauvegardes de secours,
## ecriture, relecture sans cache, verification d'empreinte et rollback complet.
func save_arena(options := {}) -> Dictionary:
	if arena == null or edit_session == null:
		return {"ok": false, "error": "no_arena"}
	var report := validate_arena()
	var result := ArenaCanonicalSaveTransactionService.save(
		arena, edit_session,
		(options as Dictionary).merged({"validation": report}, true)
	)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("message", "Sauvegarde refusée.")), true)
		return result
	var published_snapshot := result.get("published_snapshot", {}) as Dictionary
	if not published_snapshot.is_empty():
		edit_session.apply_snapshot(published_snapshot)
		arena = edit_session.working_arena
		canvas.set_arena(arena)
	edit_session.mark_saved(str(result.path))
	canvas.set_saved_transform(edit_session.saved_transform())
	_refresh_all()
	_refresh_title()
	_refresh_recovery_button()
	_set_status(str(result.get("message", "Terrain enregistré.")))
	return result


func prepare_automatically() -> void:
	if arena == null:
		return
	var before := arena.to_snapshot()
	var result := ArenaEditingService.prepare_automatically(arena)
	_commit_change("Préparer automatiquement la carte", before, arena.to_snapshot())
	_refresh_all()
	_set_status(
		"Préparation terminée — %d cases jouables, %d bordures, %d cases accessibles. Vérifiez les spawns proposés." % [
			result.get("playable", 0), result.get("border", 0), result.get("connected", 0),
		]
	)


func create_safety_border() -> void:
	if arena == null:
		return
	var before := arena.to_snapshot()
	var count := ArenaEditingService.apply_safety_border(arena, arena.border_thickness)
	_commit_change("Créer la bordure de sécurité", before, arena.to_snapshot())
	_refresh_all()
	_set_status("Bordure de sécurité créée : %d cases conservées visuellement et exclues du gameplay." % count)


func start_calibration() -> void:
	if arena == null or arena.background_path.is_empty():
		_set_status("Ajoutez d'abord une image de fond.", true)
		return
	canvas.begin_three_click_calibration()
	_set_status("Calibration : cliquez la référence, puis ses voisines bas-droite et bas-gauche.")


func fit_multipoint_calibration() -> void:
	if arena == null:
		return
	# Lecture d'un champ derive : elle passe par la projection runtime, jamais
	# par la working copy metier.
	var projection := edit_session.runtime_projection() if edit_session != null else null
	var previous_visual := projection.painted_map_visual_data if projection != null else null
	var old_rms := previous_visual.calibration_rms() if previous_visual != null else INF
	var old_max := previous_visual.calibration_max_error() if previous_visual != null else INF
	var fitted := GridTransformService.fit_affine(
		arena.calibration_cells, arena.calibration_pixels, arena.grid_size
	)
	if not bool(fitted.get("ok", false)):
		_set_status(str(fitted.get("error", "Calibration multipoint impossible.")), true)
		return
	var before := arena.to_snapshot()
	arena.grid_origin = fitted.origin
	arena.axis_x = fitted.axis_x
	arena.axis_y = fitted.axis_y
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	_commit_change(
		"Ajuster la grille à %d ancres" % arena.calibration_cells.size(),
		before, arena.to_snapshot()
	)
	_refresh_all()
	_set_status(
		"Ajustement appliqué : RMS %.2f → %.2f px, erreur max %.2f → %.2f px." % [
			old_rms, fitted.rms_error, old_max, fitted.max_error
		]
	)


func validate_arena() -> ArenaValidationReport:
	# La working copy d'une map ouverte porte volontairement le meme identifiant
	# que sa source. Le conflit de destination est controle au moment de sauver.
	validation_report = ArenaValidator.validate(arena, false)
	validation_list.clear()
	for entry in validation_report.messages:
		var prefix: String = ["ERREUR", "ATTENTION", "INFO"][entry.severity]
		validation_list.add_item("%s — %s" % [prefix, entry.message])
		validation_list.set_item_metadata(validation_list.item_count - 1, entry)
	validation_title.text = "%s — %d erreur(s), %d avertissement(s)" % [
		"Données Arena valides" if validation_report.is_valid() \
		else "Données Arena à corriger",
		validation_report.error_count(), validation_report.warning_count(),
	]
	_refresh_workflow()
	_set_status(
		"Données Arena valides. Le jeu réel reste un contrôle séparé." \
		if validation_report.is_valid() \
		else "Les données Arena doivent être corrigées avant le test dans le jeu réel.",
		not validation_report.is_valid()
	)
	return validation_report


func show_production_wizard() -> void:
	if arena == null or production_dialog == null:
		_set_status("Aucune arène n'est ouverte.", true)
		return
	production_name_edit.text = arena.display_name
	production_id_edit.text = str(arena.arena_id)
	production_theme_edit.text = str(arena.theme_id)
	production_mode_option.select(arena.visual_mode)
	production_destination_edit.text = ArenaProductionService.suggested_destination(arena)
	_refresh_production_targets()
	production_result_text.text = "[b]EN ATTENTE[/b]\n\nLa production n'a pas encore été confirmée."
	production_dialog.get_ok_button().show()
	production_tabs.current_tab = 0
	_refresh_production_wizard()
	production_dialog.popup_centered()


func _refresh_production_targets() -> void:
	if production_run_option == null:
		return
	var destination_run := _selected_destination_run()
	var active_path := destination_run.resource_path if destination_run != null else (
		project_context.active_run.resource_path \
		if project_context != null and project_context.active_run != null else ""
	)
	_production_runs.clear()
	production_run_option.clear()
	production_run_option.add_item("Aucune partie — produire seulement")
	production_run_option.set_item_tooltip(0, "La production ne modifiera aucune partie.")
	var selected := 0
	for run_data in RunContentCatalogService.discover_runs():
		if run_data == null or run_data.resource_path.is_empty():
			continue
		_production_runs.append(run_data)
		production_run_option.add_item("%s · %s" % [run_data.run_name, run_data.resource_path.get_file()])
		production_run_option.set_item_tooltip(
			production_run_option.item_count - 1, run_data.resource_path
		)
		if run_data.resource_path == active_path:
			selected = production_run_option.item_count - 1
	production_run_option.select(selected)
	# "Aucune partie" is a complete destination choice, not only a label. Keeping
	# UPDATE selected with no run made the primary production action appear
	# disabled even when the production-only gate was green.
	var destination_action := ArenaProductionAttachmentService.NONE \
		if selected == 0 else _selected_destination_action()
	for index in range(production_action_option.item_count):
		if StringName(production_action_option.get_item_metadata(index)) == destination_action:
			production_action_option.select(index)
			break
	production_index_spin.value = float(
		_selected_destination_room_index() if destination_run != null else (
			project_context.active_room_index if project_context != null else 0
		)
	)


func _selected_production_run() -> RunData:
	if production_run_option == null or production_run_option.selected <= 0:
		return null
	var index := production_run_option.selected - 1
	return _production_runs[index] if index >= 0 and index < _production_runs.size() else null


func _selected_production_action() -> StringName:
	if production_action_option == null or production_action_option.selected < 0:
		return ArenaProductionAttachmentService.NONE
	return StringName(production_action_option.get_item_metadata(
		production_action_option.selected
	))


func _production_candidate() -> ArenaDefinition:
	if arena == null:
		return null
	var candidate := RoomIntegrationFieldPolicy.merge_arena_into_room(arena, arena)
	if candidate == null:
		return null
	candidate.set_identity(production_name_edit.text, production_id_edit.text)
	candidate.theme_id = StringName(production_theme_edit.text.strip_edges())
	candidate.visual_mode = production_mode_option.selected
	if candidate.visual_mode in [
		ArenaDefinition.VisualMode.MODULAR, ArenaDefinition.VisualMode.HYBRID,
	] and candidate.modular_visual_profile == null:
		candidate.modular_visual_profile = ArenaModularVisualProfile.new()
		candidate.modular_visual_profile.theme_id = candidate.theme_id
	var battle_path := ArenaDefinition.MODULAR_BATTLE_SCENE \
		if candidate.visual_mode == ArenaDefinition.VisualMode.MODULAR \
		else ArenaDefinition.DEFAULT_BATTLE_SCENE
	candidate.battle_scene = load(battle_path) as PackedScene \
		if ResourceLoader.exists(battle_path) else null
	ArenaRuntimeBridge.sync_runtime_resources(candidate)
	return candidate


func _refresh_production_wizard() -> void:
	if production_dialog == null:
		return
	var candidate := _production_candidate()
	var destination := production_destination_edit.text.strip_edges()
	var target_run := _selected_production_run()
	var attachment_action := _selected_production_action()
	var integration_plan := ArenaIntegrationService.plan(
		candidate, target_run, attachment_action, int(production_index_spin.value),
		destination, shared_reference_graph,
		_integration_gate_options(candidate, target_run)
	)
	_production_last_plan = integration_plan
	_refresh_production_dashboard()
	if not bool(integration_plan.get("ok", false)):
		production_summary_text.text = "[b]Vous allez :[/b]\n\n[color=red]Le plan doit être corrigé avant toute écriture.[/color]"
		production_validation_text.text = "[color=red]Plan impossible : %s[/color]" % integration_plan.get("error", "erreur")
		production_plan_text.text = production_validation_text.text
		production_dialog.get_ok_button().disabled = true
		return
	var production_plan := integration_plan.production as Dictionary
	var bundle_resolution := production_plan.get("bundle_resolution", {}) as Dictionary
	var report := production_plan.validation as ArenaValidationReport
	var visual_report := production_plan.visual_report as ArenaVisualAssemblyReport
	var attachment_plan := integration_plan.attachment as Dictionary
	if attachment_action != ArenaProductionAttachmentService.NONE and target_run == null:
		attachment_plan = {
			"ok": false,
			"error": "Choisissez une partie cible ou Produire sans intégrer.",
		}
	if target_run != null:
		production_index_spin.max_value = maxi(0, target_run.rooms.size())
	var target_index := int(production_index_spin.value)
	var action_label := _production_action_human(attachment_action)
	var target_label := target_run.run_name if target_run != null else "aucune partie"
	var preserves_gameplay := bool(attachment_plan.get("preserves_gameplay", false))
	var existing_inspection := ArenaBundleInspectionService.inspect(
		str(production_plan.get("destination", destination)), shared_reference_graph
	)
	var archive_count := 1 if existing_inspection.get("state", &"") \
			== ArenaBundleInspectionService.OWNED_INCOMPLETE \
			and not bool(existing_inspection.get("referenced", false)) else 0
	var summary_lines := PackedStringArray([
		"[b]Vous allez :[/b]", "",
		"• %s%s" % [action_label, " de la salle %d" % (target_index + 1) \
			if attachment_action != ArenaProductionAttachmentService.NONE else ""],
		"• %s la rencontre, les vagues et les récompenses" % (
			"Conserver" if preserves_gameplay else "Remplacer explicitement"
		),
		"• %s" % ("Conserver la salle à l’index %d" % (target_index + 1) \
			if attachment_action == ArenaProductionAttachmentService.UPDATE \
			else "Appliquer l’action à l’index %d" % (target_index + 1)),
		"• %s" % ("Créer une copie spécifique à la partie %s" % target_label \
			if bool(attachment_plan.get("shared", false)) else "Cibler la partie %s" % target_label),
		"• Produire 1 dossier de salle prêt pour le jeu",
		"• %s" % ("Archiver 1 ancienne production incomplète après confirmation" \
			if archive_count == 1 else "Ne déplacer aucune production existante"),
	])
	production_summary_text.text = "\n".join(summary_lines)
	if project_context != null:
		project_context.persisted_ui["production_target"] = "%s — %s" % [
			target_label, action_label,
		]
	var gate := integration_plan.get("gate_report", {}) as Dictionary
	var readiness := integration_plan.get("readiness_report") as ArenaReadinessReport
	var gate_blockers: Array = gate.get("blocking_errors", [])
	var gate_warnings: Array = gate.get("acknowledgement_warnings", [])
	var validation_lines := PackedStringArray([
		"[b]%s[/b]" % gate.get("summary", report.verdict()),
		"%d erreur(s) bloquante(s), %d avertissement(s), %d information(s)" % [
			gate_blockers.size(), gate_warnings.size(),
			(gate.get("information", []) as Array).size(),
		],
		"",
	])
	if readiness != null:
		validation_lines.append("Données Arena : %s" % readiness.data_report.state_name())
		validation_lines.append("Jeu réel : %s" % readiness.runtime_scene_report.state_name())
		validation_lines.append("Production : %s" % readiness.production_report.state_name())
		validation_lines.append("Intégration : %s" % readiness.integration_report.state_name())
		validation_lines.append("")
	if not gate_blockers.is_empty():
		validation_lines.append("[color=red][b]Pourquoi l'intégration est-elle indisponible ?[/b][/color]")
		for issue in gate_blockers:
			validation_lines.append("[color=red]✕ %s[/color]" % (issue as Dictionary).get("message", "Blocage technique"))
	for issue in gate_warnings:
		var accepted := bool((issue as Dictionary).get("acknowledged", false))
		validation_lines.append("[color=%s]• %s%s[/color]" % [
			"green" if accepted else "orange",
			(issue as Dictionary).get("message", "Avertissement"),
			" — choix accepté" if accepted else "",
		])
	if gate_blockers.is_empty():
		validation_lines.append("[color=green]✓ Projection, assemblage et vraie scène de jeu vérifiés.[/color]")
	production_validation_text.text = "\n".join(validation_lines)
	production_preview_text.text = (
		"[b]Même chaîne que le jeu réel[/b]\n\n"
		+ "• Grille logique et calcul des déplacements identiques au jeu\n"
		+ "• Assemblage visuel partagé avec les combats peints et modulaires\n"
		+ "• Personnages et statistiques réels en vue Jeu\n"
		+ "• Premier plan et occlusion réels\n\n"
		+ "Les trois vues seront capturées en 1280 × 720 lors de la production.\n\n"
		+ "[b]Preuve d'assemblage[/b]\n"
		+ "%d dalles attendues / %d rendues\n%d murs attendus / %d rendus\n%s" % [
			visual_report.expected_terrain_cell_count,
			visual_report.rendered_terrain_node_count,
			visual_report.expected_wall_count,
			visual_report.rendered_wall_count,
			"ASSEMBLAGE VALIDE" if visual_report.valid else "ASSEMBLAGE INCOMPLET",
		]
	)
	var plan_lines := PackedStringArray([
		"[b]Destination[/b]  %s" % production_plan.destination,
		"",
		"[b]Fichiers créés (%d)[/b]" % production_plan.creates.size(),
	])
	for path in production_plan.creates:
		plan_lines.append("+ %s" % path)
	plan_lines.append("\n[b]Fichiers mis à jour (%d)[/b]" % production_plan.modifies.size())
	for path in production_plan.modifies:
		plan_lines.append("~ %s" % path)
	plan_lines.append("\n[b]Conflits (%d)[/b]" % production_plan.conflicts.size())
	for path in production_plan.conflicts:
		plan_lines.append("[color=red]! %s[/color]" % path)
	if production_plan.conflicts.is_empty():
		plan_lines.append("Aucun conflit.")
	plan_lines.append("\n[b]Intégration à la partie[/b]")
	if attachment_plan.get("ok", false):
		plan_lines.append("Partie : %s" % attachment_plan.get("run_path", "aucune"))
		plan_lines.append("Action : %s" % attachment_plan.get("action", &"NONE"))
		plan_lines.append("Index exact : %d" % int(attachment_plan.get("target_index", -1)))
		plan_lines.append("Nombre de salles : %d → %d" % [
			int(attachment_plan.get("before_count", 0)),
			int(attachment_plan.get("after_count", 0)),
		])
		var replaced_path := str(attachment_plan.get("replaced_path", ""))
		if not replaced_path.is_empty():
			plan_lines.append("Salle cible actuelle : %s" % replaced_path)
		plan_lines.append("Terrain final : %s" % attachment_plan.get("integrated_room_path", ""))
		plan_lines.append("Gameplay conservé : %s" % ("oui" if attachment_plan.get("preserves_gameplay", false) else "non"))
		plan_lines.append("Salle partagée : %s" % ("oui — copie spécifique" if attachment_plan.get("shared", false) else "non"))
	else:
		plan_lines.append("[color=red]Plan impossible : %s[/color]" % attachment_plan.get("error", "erreur"))
	var run_conflict := target_run != null and run_authoring.is_dirty() \
		and run_authoring.source_path == target_run.resource_path
	if run_conflict:
		plan_lines.append("[color=red]La partie ciblée a déjà des modifications non sauvegardées.[/color]")
	var blocking_domains := _blocking_context_domains()
	if not blocking_domains.is_empty():
		plan_lines.append("[color=light_blue]Documents hors transaction conservés : %s[/color]" % ", ".join(blocking_domains))
	production_plan_text.text = "\n".join(plan_lines)
	_render_bundle_resolution(bundle_resolution)
	var unacknowledged := int(gate.get("unacknowledged_warning_count", 0))
	production_dialog.get_ok_button().text = "Vérifier et produire sans intégrer" \
		if attachment_action == ArenaProductionAttachmentService.NONE \
		else "Vérifier et intégrer dans %s — %s salle %d" % [
			target_label, action_label, target_index + 1,
		]
	if unacknowledged > 0:
		production_dialog.get_ok_button().text += " — %d avertissement(s)" % unacknowledged
	production_dialog.get_ok_button().disabled = not gate_blockers.is_empty()


func _production_action_human(action: StringName) -> String:
	match action:
		ArenaProductionAttachmentService.UPDATE:
			return "Mettre à jour l’arène"
		ArenaProductionAttachmentService.REPLACE:
			return "Remplacer toute la salle"
		ArenaProductionAttachmentService.INSERT_BEFORE:
			return "Insérer avant"
		ArenaProductionAttachmentService.INSERT_AFTER:
			return "Insérer après"
		ArenaProductionAttachmentService.APPEND:
			return "Créer une nouvelle salle"
		_:
			return "Produire sans intégrer"


func _render_bundle_resolution(resolution: Dictionary) -> void:
	if production_resolution_text == null:
		return
	var lines := PackedStringArray([
		"[b]RÉSOLUTION DU DOSSIER EXISTANT[/b]",
		str(resolution.get("state_label", "Destination non inspectée")),
		str(resolution.get("explanation", "Aucune information.")),
	])
	var files := resolution.get("files", []) as Array
	if not files.is_empty():
		lines.append("")
		lines.append("[b]Fichiers présents (%d)[/b]" % files.size())
		for value in files:
			var file := value as Dictionary
			lines.append("• %s — %d octets — SHA-256 %s…" % [
				file.get("path", ""), int(file.get("size", 0)),
				str(file.get("sha256", "")).left(16),
			])
	var references := resolution.get("references", {}) as Dictionary
	var canonical := references.get("canonical_references", []) as Array
	if canonical.is_empty():
		lines.append("✓ Aucune partie ni ressource ne référence arena.tres.")
	else:
		lines.append("[color=red][b]%d référence(s) canonique(s)[/b][/color]" % canonical.size())
		for value in canonical:
			var usage := value as Dictionary
			lines.append("• %s — %s%s" % [
				usage.get("from", ""), usage.get("relation", "RESOURCE"),
				" — salle %d" % int(usage.get("room_number", 0)) \
					if int(usage.get("room_number", 0)) > 0 else "",
			])
	if bool(resolution.get("required", false)):
		lines.append("")
		lines.append("Action recommandée : [b]%s[/b]" % resolution.get(
			"recommended_label", "Examiner les fichiers"
		))
	else:
		lines.append("[color=green]Aucune résolution préalable n'est requise.[/color]")
	production_resolution_text.text = "\n".join(lines)
	for action_id in production_resolution_buttons:
		var button := production_resolution_buttons[action_id] as Button
		var action_plan := _bundle_resolution_action(resolution, StringName(action_id))
		button.visible = bool(resolution.get("required", false)) \
			and not action_plan.is_empty()
		button.disabled = not bool(action_plan.get("enabled", false))
		button.tooltip_text = str(action_plan.get("reason", "Action indisponible."))


func _bundle_resolution_action(
		resolution: Dictionary,
		action: StringName
	) -> Dictionary:
	for value in resolution.get("actions", []):
		var candidate := value as Dictionary
		if StringName(candidate.get("id", &"")) == action:
			return candidate
	return {}


func _on_bundle_resolution_action(action: StringName) -> void:
	var candidate := _production_candidate()
	var destination := production_destination_edit.text.strip_edges()
	var resolution := (_production_last_plan.get("production", {}) as Dictionary).get(
		"bundle_resolution", {}
	) as Dictionary
	var action_plan := _bundle_resolution_action(resolution, action)
	if action_plan.is_empty() or not bool(action_plan.get("enabled", false)):
		_set_status("Cette action de résolution n'est pas disponible.", true)
		return
	if action == ArenaBundleResolutionService.VERSION_ALONGSIDE:
		var version := ArenaBundleResolutionService.execute(
			action, candidate, destination, shared_reference_graph
		)
		if not bool(version.get("ok", false)):
			_set_status("Le nouveau chemin versionné ne peut pas être choisi.", true)
			return
		production_destination_edit.text = str(version.get("destination", destination))
		_set_status("Nouvelle version choisie : %s. Le dossier existant reste inchangé." % production_destination_edit.text)
		_refresh_production_wizard()
		return
	if action == ArenaBundleResolutionService.EXAMINE_FILES:
		var examination := ArenaBundleResolutionService.execute(
			action, candidate, destination, shared_reference_graph
		)
		if bool(examination.get("ok", false)):
			OS.shell_show_in_file_manager(str(examination.get("absolute_path", "")), true)
			_set_status("Dossier ouvert en lecture : %s" % destination)
		return
	_pending_bundle_resolution_action = action
	var lines := PackedStringArray([
		"[b]%s[/b]" % action_plan.get("label", "Résoudre le dossier de production"),
		str(action_plan.get("reason", "")),
		"",
		"Destination : %s" % destination,
		"Fichiers concernés : %d" % (resolution.get("files", []) as Array).size(),
		"Références canoniques : %d" % int((resolution.get("references", {}) as Dictionary).get("canonical_count", 0)),
		"",
		"Cette action est explicite et sera vérifiée par SHA-256. Annuler ne modifie rien.",
	])
	bundle_resolution_confirmation_text.text = "\n".join(lines)
	bundle_resolution_dialog.popup_centered(Vector2i(720, 420))


func _confirm_bundle_resolution_action() -> void:
	if _pending_bundle_resolution_action.is_empty():
		return
	var action := _pending_bundle_resolution_action
	_pending_bundle_resolution_action = &""
	var destination := production_destination_edit.text.strip_edges()
	var result := ArenaBundleResolutionService.execute(
		action, _production_candidate(), destination, shared_reference_graph,
		"Action confirmée dans Arena Studio : %s" % action
	)
	if not bool(result.get("ok", false)):
		_set_status("Résolution refusée : %s" % result.get("error", "échec de vérification"), true)
		_refresh_production_wizard()
		return
	if action == ArenaBundleResolutionService.RESUME_INTERRUPTED:
		_set_status("Production interrompue reprise et manifeste vérifié. Le plan est recalculé.")
	else:
		_set_status("Ancien dossier de production archivé sous %s. Le plan est recalculé." % result.get("archive", "user://"))
	_refresh_production_wizard()


func _refresh_production_dashboard() -> void:
	if production_dashboard_text == null:
		return
	var report := ArenaProductionDashboardService.scan(shared_reference_graph)
	production_dashboard_text.text = ArenaProductionDashboardService.format_human(report)


func _start_guided_sandbox() -> void:
	var created := ArenaGuidedSandboxService.create_fixture()
	if not created.get("ok", false):
		_set_status("Exercice d’entraînement impossible : %s" % created.get("error", "erreur"), true)
		return
	var fixture := created.get("arena") as ArenaDefinition
	if fixture == null:
		_set_status("L’arène d’entraînement n’a pas pu être rechargée.", true)
		return
	_set_arena(fixture, false, "sandbox:%s" % created.get("root", ""))
	if guided_tour != null:
		guided_tour.start(&"sandbox")
	_set_status("Exercice d’entraînement prêt sous %s. Aucune partie officielle n’a été modifiée." % created.get("root", ""))


func _production_confirmed() -> void:
	call_deferred("_request_confirmed_production")


func _request_confirmed_production() -> void:
	_refresh_production_wizard()
	if not bool(_production_last_plan.get("can_integrate", false)):
		_show_production_failure("Intégration impossible : %s" % _gate_blocking_text(
			_production_last_plan
		))
		return
	var warnings := _unacknowledged_gate_warnings(_production_last_plan)
	if not warnings.is_empty():
		_show_integration_warning_confirmation(warnings, &"production")
		return
	_run_confirmed_production()


func _run_confirmed_production() -> void:
	if edit_session == null or arena == null:
		return
	var candidate := _production_candidate()
	var before := arena.to_snapshot().duplicate(true)
	await _perform_room_integration(
		candidate, before, _selected_production_run(), _selected_production_action(),
		int(production_index_spin.value), production_destination_edit.text.strip_edges()
	)


func _perform_room_integration(
		candidate: ArenaDefinition,
		before: Dictionary,
		target_run: RunData,
		action: StringName,
		target_index: int,
		destination: String
	) -> Dictionary:
	if candidate == null or edit_session == null:
		_show_production_failure("La version en cours ne peut pas être préparée.")
		return {"ok": false, "error": "candidate_missing"}
	if edit_session.has_external_conflict():
		_show_production_failure("La source a changé sur disque : intégration bloquée.")
		return {"ok": false, "error": "external_conflict"}
	var pipeline_files: Array = []
	if target_run != null and not target_run.resource_path.is_empty():
		pipeline_files.append(target_run.resource_path)
	if not destination.is_empty():
		pipeline_files.append(destination.path_join("arena.tres"))
	var pipeline_fingerprints := {
		"working_arena": ArenaSnapshotService.arena_fingerprint(candidate),
		"working_gameplay": ArenaSnapshotService.gameplay_fingerprint(candidate),
	}
	var pipeline_monitor := ArenaGuidedPipelineDiagnosticsService.new({
		"context": {
			"arena_id": str(candidate.arena_id),
			"run_path": target_run.resource_path if target_run != null else "",
			"action": str(action),
			"requested_index": target_index,
			"destination": destination,
			"source": "ArenaStudioMain",
		},
	})
	pipeline_monitor.begin_step(
		&"UI_GATE_PLAN", {}, pipeline_files, pipeline_fingerprints,
		pipeline_monitor.timeout_for(&"UI_GATE_PLAN")
	)
	var gate_options := _integration_gate_options(candidate, target_run)
	var final_plan := ArenaIntegrationService.plan(
		candidate, target_run, action, target_index, destination,
		shared_reference_graph, gate_options
	)
	var ui_plan_checkpoint := pipeline_monitor.end_step(
		&"UI_GATE_PLAN",
		bool(final_plan.get("can_integrate", false)),
		"integration_gate_blocked" \
			if not bool(final_plan.get("can_integrate", false)) else "",
		{"affected_files": final_plan.get("affected_files", [])}
	)
	if bool(ui_plan_checkpoint.get("timed_out", false)) \
			or bool(ui_plan_checkpoint.get("interrupted", false)):
		_show_production_failure(
			"Le calcul du plan d'intégration a dépassé son délai. Diagnostic : %s" \
			% ui_plan_checkpoint.get("diagnostic_dump_path", "")
		)
		return {
			"ok": false,
			"error": ui_plan_checkpoint.get("error", "ui_gate_plan_timeout"),
			"plan": final_plan,
			"pipeline": pipeline_monitor.summary(),
		}
	if not bool(final_plan.get("can_integrate", false)):
		_show_production_failure("Intégration impossible : %s" % _gate_blocking_text(
			final_plan
		))
		return {
			"ok": false,
			"error": "integration_gate_blocked",
			"plan": final_plan,
			"pipeline": pipeline_monitor.summary(),
		}
	pipeline_monitor.begin_step(
		&"PREVIEW_CAPTURE", {}, pipeline_files, pipeline_fingerprints,
		pipeline_monitor.timeout_for(&"PREVIEW_CAPTURE")
	)
	var preview_result: Dictionary = await _capture_runtime_preview_images(
		candidate, pipeline_monitor,
		pipeline_monitor.timeout_for(&"PREVIEW_CAPTURE")
	)
	if not bool(preview_result.get("ok", false)):
		pipeline_monitor.request_interrupt(
			str(preview_result.get("error", "preview_capture_failed"))
		)
	var preview_checkpoint := pipeline_monitor.end_step(
		&"PREVIEW_CAPTURE",
		bool(preview_result.get("ok", false)),
		str(preview_result.get("error", "preview_capture_failed")) \
			if not bool(preview_result.get("ok", false)) else "",
		{
			"captured_files": (preview_result.get("images", {}) as Dictionary).keys(),
			"failed_view": preview_result.get("failed_view", ""),
		}
	)
	if not bool(preview_checkpoint.get("ok", false)):
		if str(preview_checkpoint.get("diagnostic_dump_path", "")).is_empty():
			pipeline_monitor.dump_diagnostic(
				str(preview_checkpoint.get("error", "preview_capture_failed")),
				{"preview_result": preview_result}
			)
		_show_production_failure(
			"L'aperçu n'a pas pu être capturé : le rendu n'a jamais été déclaré prêt. Diagnostic : %s" \
			% pipeline_monitor.diagnostic_dump_path
		)
		return {
			"ok": false,
			"error": preview_checkpoint.get("error", "preview_capture_failed"),
			"plan": final_plan,
			"preview": preview_result,
			"pipeline": pipeline_monitor.summary(),
		}
	var preview_images: Dictionary = preview_result.get("images", {}) as Dictionary
	var integration := ArenaIntegrationService.integrate_with_options(
		candidate, target_run, action, target_index, destination,
		shared_reference_graph, preview_images, {
			"gate_options": gate_options,
			"pipeline_monitor": pipeline_monitor,
		}
	)
	if not bool(integration.get("ok", false)):
		var production := integration.get("production", {}) as Dictionary
		var failed_visual := production.get("visual_report") as ArenaVisualAssemblyReport
		var visual_details := ""
		if failed_visual != null:
			visual_details = "\n%d dalle(s) rendue(s) sur %d attendue(s)." % [
				failed_visual.rendered_terrain_node_count,
				failed_visual.expected_terrain_cell_count,
			]
		var message := "%s%s" % [
			integration.get("error", "erreur inconnue"), visual_details,
		]
		if integration.get("status", &"") == &"ROOM_PRODUCED_NOT_INTEGRATED":
			production_result_text.text = (
				"[font_size=24][b][color=orange]SALLE PRODUITE — INTÉGRATION REFUSÉE[/color][/b][/font_size]\n\n"
				+ "%s\n\nLa partie et la salle canonique ont été restaurées. " % message
				+ "Le dossier produit reste disponible pour diagnostic."
			)
			production_tabs.current_tab = 4
			production_dialog.get_ok_button().hide()
			production_dialog.popup_centered()
			_set_status("Production prête, mais transaction d’intégration refusée.", true)
		else:
			_show_production_failure("Intégration refusée : %s" % message)
		return integration
	var production := integration.get("production", {}) as Dictionary
	var attachment := integration.get("attachment", {}) as Dictionary
	var integrated_room := integration.get("reloaded_room") as ArenaDefinition
	if integrated_room == null:
		integrated_room = ResourceLoader.load(
			str(production.get("arena_path", "")), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as ArenaDefinition
	if integrated_room == null:
		_show_production_failure("La ressource finale n'a pas pu être rechargée.")
		return {"ok": false, "error": "integrated_reload_failed"}
	edit_session.apply_snapshot(integrated_room.to_snapshot())
	arena = edit_session.working_arena
	edit_session.commit(
		"Produire la salle" if action == ArenaProductionAttachmentService.NONE \
		else "Intégrer la salle à la partie",
		before, arena.to_snapshot()
	)
	edit_session.mark_saved(str(integration.get("integrated_room_path", "")))
	if project_context != null:
		project_context.set_dirty(&"arena", false)
	canvas.set_arena(arena)
	canvas.set_saved_transform(edit_session.saved_transform())
	if runtime_preview != null:
		runtime_preview.set_arena(arena)
	# Etat permanent : le bandeau du domaine doit pouvoir dire « Intégré dans
	# Principale · Salle 2 » sans que l'utilisateur relise le rapport.
	if action != ArenaProductionAttachmentService.NONE and target_run != null:
		var run_label := str(target_run.run_name) if not str(target_run.run_name).is_empty() \
			else target_run.resource_path.get_file().get_basename()
		_integration_label = "%s · Salle %d" % [
			run_label, int(attachment.get("target_index", target_index)) + 1,
		]
	_refresh_all()
	var final_visual := production.get("visual_report") as ArenaVisualAssemblyReport
	var produced_only := action == ArenaProductionAttachmentService.NONE
	production_result_text.text = (
		("[font_size=28][b][color=green]SALLE PRODUITE ET RECHARGÉE[/color][/b][/font_size]\n\n" \
		if produced_only else \
		"[font_size=28][b][color=green]SALLE INTÉGRÉE ET RECHARGÉE[/color][/b][/font_size]\n\n")
		+ "✓ %d dalles attendues / %d rendues\n" % [
			final_visual.expected_terrain_cell_count,
			final_visual.rendered_terrain_node_count,
		]
		+ "✓ Terrains : %s\n" % JSON.stringify(final_visual.rendered_by_terrain_id)
		+ "✓ %d murs attendus / %d rendus\n" % [
			final_visual.expected_wall_count, final_visual.rendered_wall_count,
		]
		+ "✓ Définition valide\n✓ Grille valide\n✓ Déplacements valides\n"
		+ "✓ Spawns valides\n✓ Aperçu Art valide\n✓ Aperçu Jeu valide\n"
		+ "✓ Ressources rechargées\n✓ Test direct disponible\n"
		+ ("✓ Partie inchangée — production sans intégrer\n\n" \
			if attachment.get("action", &"NONE") == ArenaProductionAttachmentService.NONE \
			else "✓ Intégrée à %s, index %d (%d → %d salles)\n" % [
				attachment.get("run_path", ""), int(attachment.get("target_index", -1)),
				int(attachment.get("before_count", 0)), int(attachment.get("after_count", 0)),
			] + ("✓ Gameplay de la salle conservé\n" if attachment.get("preserved_gameplay", false) else "")
			+ ("✓ Copie spécifique créée pour protéger la salle partagée\n" if attachment.get("copy_on_write", false) else "")
			+ "\n")
		+ "[b]%s[/b]\nJournal : %s" % [
			integration.get("integrated_room_path", ""), integration.get("journal_path", ""),
		]
	)
	if attachment.get("reloaded_run") is RunData and project_context != null:
		var reloaded_run := attachment.reloaded_run as RunData
		run_authoring.open(reloaded_run, shared_reference_graph)
		var selection := project_context.request_selection({
			"run": reloaded_run,
			"room_index": int(attachment.get("target_index", 0)),
		}, &"arena")
		if not selection.get("ok", false):
			production_result_text.text += "\n[color=orange]Salle intégrée, mais sélection en attente : %s[/color]" % selection.get("status", "")
	production_tabs.current_tab = 4
	production_dialog.get_ok_button().hide()
	production_dialog.popup_centered()
	_set_status(
		"SALLE PRODUITE — dossier vérifié, aucune partie modifiée." if produced_only \
		else "SALLE INTÉGRÉE — transaction vérifiée et destination sélectionnée."
	)
	history_state_changed.emit()
	return integration


func _capture_runtime_preview_images(
		candidate: ArenaDefinition,
		monitor: ArenaGuidedPipelineDiagnosticsService = null,
		timeout_ms := GUIDED_PREVIEW_TIMEOUT_MS
	) -> Dictionary:
	var images := {}
	if runtime_preview == null or candidate == null:
		return {"ok": true, "images": images, "render_ready": false}
	var original_arena := arena
	var original_view := preview_view
	var deadline_msec := Time.get_ticks_msec() + maxi(1, timeout_ms)
	for entry in [
		["preview_logic.png", ArenaRuntimePreview.ViewMode.LOGIC],
		["preview_art.png", ArenaRuntimePreview.ViewMode.ART],
		["preview_game.png", ArenaRuntimePreview.ViewMode.GAME],
	]:
		runtime_preview.set_view_mode(entry[1])
		runtime_preview.set_arena(candidate)
		runtime_preview.rebuild_now()
		await get_tree().process_frame
		if monitor != null:
			monitor.record_signal(&"SceneTree.process_frame", {"view": str(entry[0])})
		var remaining_ms := deadline_msec - Time.get_ticks_msec()
		var frame_result: Dictionary = await _wait_for_preview_frame(
			maxi(1, remaining_ms), monitor, str(entry[0])
		)
		if not bool(frame_result.get("ok", false)) \
				or Time.get_ticks_msec() >= deadline_msec:
			_restore_runtime_preview_after_capture(original_arena, original_view)
			return {
				"ok": false,
				"error": "preview_frame_timeout",
				"failed_view": entry[0],
				"images": images,
				"render_ready": false,
				"frame_result": frame_result,
			}
		if runtime_preview.viewport != null:
			var image := runtime_preview.viewport.get_texture().get_image()
			if image != null and not image.is_empty():
				image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
				images[entry[0]] = image
	images["thumbnail.png"] = images.get("preview_game.png")
	images["map_reference.png"] = images.get("preview_art.png")
	images["map_clean.png"] = images.get("preview_art.png")
	images["map_logic.png"] = images.get("preview_logic.png")
	images["map_grid.png"] = images.get("preview_logic.png")
	images["map_game_preview.png"] = images.get("preview_game.png")
	_restore_runtime_preview_after_capture(original_arena, original_view)
	return {
		"ok": true,
		"images": images,
		"render_ready": images.has("preview_game.png"),
	}


func _wait_for_preview_frame(
		timeout_ms: int,
		monitor: ArenaGuidedPipelineDiagnosticsService,
		view_name: String
	) -> Dictionary:
	var state := {"received": false}
	var callback := func() -> void:
		state["received"] = true
		if monitor != null:
			monitor.record_signal(
				&"RenderingServer.frame_post_draw", {"view": view_name}
			)
	RenderingServer.frame_post_draw.connect(callback, CONNECT_ONE_SHOT)
	var started_msec := Time.get_ticks_msec()
	var deadline_msec := started_msec + maxi(1, timeout_ms)
	while not bool(state.received) and Time.get_ticks_msec() < deadline_msec:
		var remaining_seconds := float(
			deadline_msec - Time.get_ticks_msec()
		) / 1000.0
		await get_tree().create_timer(
			minf(0.05, maxf(0.001, remaining_seconds)), true, false, true
		).timeout
	if not bool(state.received) \
			and RenderingServer.frame_post_draw.is_connected(callback):
		RenderingServer.frame_post_draw.disconnect(callback)
	return {
		"ok": bool(state.received),
		"signal": "RenderingServer.frame_post_draw",
		"view": view_name,
		"duration_ms": Time.get_ticks_msec() - started_msec,
	}


func _restore_runtime_preview_after_capture(
		original_arena: ArenaDefinition,
		original_view: int
	) -> void:
	if runtime_preview == null:
		return
	runtime_preview.set_view_mode(original_view)
	runtime_preview.set_arena(original_arena)


func _show_production_failure(message: String) -> void:
	production_result_text.text = "[font_size=24][b][color=red]SALLE NON PRODUITE[/color][/b][/font_size]\n\n%s" % message
	production_tabs.current_tab = 4
	production_dialog.get_ok_button().show()
	production_dialog.popup_centered()
	_set_status(message, true)


func _export_art_kit_from_wizard() -> void:
	var candidate := _production_candidate()
	var report := ArenaValidator.validate(candidate, false)
	var destination := production_destination_edit.text.strip_edges().path_join("art_kit_manual")
	var result := ArenaArtKitExporter.export_kit(candidate, destination, report)
	if bool(result.get("ok", false)):
		_set_status("Kit artistique exporté dans %s" % destination)
	else:
		_set_status("Le kit artistique n'a pas pu être exporté : %s" % result.get("error", "erreur"), true)


func _show_art_reimport_dialog() -> void:
	if arena == null:
		_set_status("Aucune arène n'est ouverte.", true)
		return
	art_manifest_dialog.popup_centered()


func _prepare_art_floor_policy_choice() -> void:
	if art_floor_policy_option == null or arena == null:
		return
	var policy := ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS
	if arena.visual_mode == ArenaDefinition.VisualMode.MODULAR:
		# Ajouter un décor à une map entièrement modulaire conserve visuellement
		# le sol existant par défaut, sans changer le défaut historique du profil.
		policy = ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	elif arena.modular_visual_profile != null:
		policy = arena.modular_visual_profile.hybrid_floor_policy
	var index := _hybrid_floor_policy_option_index(art_floor_policy_option, policy)
	if index >= 0:
		art_floor_policy_option.select(index)


func _selected_art_floor_policy() -> int:
	if art_floor_policy_option == null or art_floor_policy_option.selected < 0:
		return ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS
	return int(art_floor_policy_option.get_selected_metadata())


func _prepare_art_reimport(manifest_path: String) -> void:
	_pending_art_directory = manifest_path.get_base_dir()
	_prepare_art_floor_policy_choice()
	var inspection := ArenaArtRoundTripService.inspect_reimport(
		arena, _pending_art_directory
	)
	if not inspection.get("ok", false):
		art_reimport_dialog.title = "IMPORT À VÉRIFIER"
		art_reimport_dialog.dialog_text = (
			"%s\n\nCode : %s\nRésolution attendue : %s\nRésolution reçue : %s\n"
			+ "Calibration de secours conservée : %s\n\nAnnulez pour corriger le fichier, importer une version différente ou utiliser la calibration de secours. Aucune correction ne sera appliquée silencieusement."
		) % [
			inspection.get("error", "Décor incompatible."), inspection.get("code", "INCOMPATIBLE"),
			inspection.get("expected_resolution", "—"), inspection.get("actual_resolution", "—"),
			inspection.get("fallback", arena.background_path),
		]
		art_reimport_dialog.get_ok_button().disabled = true
		art_reimport_dialog.popup_centered()
		_set_status("Réimport artistique refusé : %s" % inspection.get("code", "incompatible"), true)
		return
	art_reimport_dialog.title = "IMPORTER LE DÉCOR DE L’ARÈNE"
	art_reimport_dialog.dialog_text = (
		"AVANT\n%s\n\nAPRÈS\n%s\n\n"
		+ "Empreinte, résolution, recadrage, grille et ancres correspondent. "
		+ "grid_origin, axis_x et axis_y resteront strictement inchangés ; "
		+ "le décor sera placé sous les dalles tactiques choisies ci-dessous."
	) % [arena.background_path, inspection.get("source_image", "")]
	art_reimport_dialog.get_ok_button().disabled = false
	art_reimport_dialog.popup_centered()


func _apply_art_reimport() -> void:
	if arena == null or _pending_art_directory.is_empty():
		return
	var before := arena.to_snapshot().duplicate(true)
	var destination := "res://data/arenas/art_imports/%s/background.png" % arena.arena_id
	var result := ArenaArtRoundTripService.apply_reimport(
		arena,
		_pending_art_directory,
		destination,
		"background.png",
		_selected_art_floor_policy()
	)
	if not result.get("ok", false):
		_set_status("Le décor n'a pas été importé : %s" % result.get("error", "erreur"), true)
		return
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	_commit_change("Réimporter le décor sans recalibrer", before, arena.to_snapshot())
	_refresh_all()
	_set_status("Décor réimporté sans recalibration : %s • %s." % [
		destination,
		_hybrid_floor_policy_display_name(
			arena.modular_visual_profile.hybrid_floor_policy
		),
	])


func test_arena() -> void:
	var report := validate_arena()
	if not report.is_valid():
		return
	var run_context := (
		project_context.active_run
		if project_context != null else null
	)
	var preparation := ArenaDirectTestService.prepare(
		arena,
		run_context,
		StringName(TEST_CONFIGURATIONS[test_configuration_option.selected][1])
	)
	if not bool(preparation.get("ok", false)):
		_set_status(
			"Le test direct n'a pas pu être préparé : %s" % preparation.get(
				"error", "erreur inconnue"
			),
			true
		)
		return
	_last_test_log = "Test direct demandé pour %s via %s" % [arena.arena_id, TEST_RUNNER_SCENE]
	_tested_once = true
	_refresh_workflow()
	if editor_interface != null:
		editor_interface.play_custom_scene(TEST_RUNNER_SCENE)
		_set_status("Version en cours lancée dans le combat réel. Aucune sauvegarde de production n'a été effectuée ; F8 revient à l'éditeur.")
	else:
		_set_status("Configuration de test direct préparée.")


func export_report() -> void:
	var report := validation_report if validation_report != null else validate_arena()
	var result := ArenaReportExporter.export_report(arena, report, _last_test_log)
	if not bool(result.get("ok", false)):
		_set_status("Échec de l'export : %s" % result.get("error", "erreur"), true)
		return
	await _export_previews(str(result.directory))
	_set_status("Rapport et aperçus exportés dans %s" % result.directory)


func copy_report_for_codex() -> void:
	var report := validation_report if validation_report != null else validate_arena()
	ArenaReportExporter.copy_for_codex(report)
	_set_status("Le rapport de validation a été copié dans le presse-papiers.")


func restore_latest_recovery() -> void:
	var selection := ArenaRecoveryContextSelectionService.scan(
		_recovery_context()
	)
	if not bool(selection.get("ok", false)):
		_set_status(
			"Aucune récupération compatible avec l’arène et le contexte actifs.",
			true
		)
		return
	_pending_recovery_candidate = (
		selection.get("selected", {}) as Dictionary
	).duplicate(true)
	recovery_restore_dialog.dialog_text = (
		"Vérifiez la provenance avant restauration. Aucune récupération étrangère "
		+ "n’est appliquée automatiquement.\n\n"
		+ ArenaRecoveryContextSelectionService.describe(
			_pending_recovery_candidate
		)
	)
	recovery_restore_dialog.popup_centered(Vector2i(720, 460))


func _confirm_restore_recovery() -> void:
	if _pending_recovery_candidate.is_empty():
		return
	var path := str(_pending_recovery_candidate.get("path", ""))
	_pending_recovery_candidate.clear()
	var restored := ArenaSerializer.load_recovery(path)
	if restored != null:
		if edit_session != null and arena != null \
				and restored.arena_id == arena.arena_id:
			var before := arena.to_snapshot()
			edit_session.apply_snapshot(restored.to_snapshot())
			arena = edit_session.working_arena
			_commit_change(
				"Restaurer la sauvegarde de récupération",
				before,
				arena.to_snapshot(),
			)
			_refresh_all()
		else:
			_set_arena(restored, true, "recovery:%s" % restored.arena_id)
		_set_status("Sauvegarde de récupération restaurée. Utilisez Sauvegarder pour la rendre canonique.")
	else:
		_set_status("La récupération sélectionnée est devenue illisible.", true)


func create_restore_point() -> void:
	if arena == null or edit_session == null:
		return
	var result := ArenaRestorePointService.create_point(
		arena, restore_name_edit.text, edit_session.source_fingerprint
	)
	if not bool(result.get("ok", false)):
		_set_status("Le point n'a pas pu être créé : %s" % result.get("error", "erreur"), true)
		return
	restore_name_edit.clear()
	_refresh_restore_points()
	_set_status("Point de restauration créé : %s" % result.get("name", "Calibration"))


func restore_selected_point() -> void:
	if arena == null or restore_points_list == null or restore_points_list.get_selected_items().is_empty():
		return
	var index: int = restore_points_list.get_selected_items()[0]
	var path := str(restore_points_list.get_item_metadata(index))
	var result := ArenaRestorePointService.load_point(path, arena.arena_id)
	if not bool(result.get("ok", false)):
		_set_status("Restauration refusée : %s" % result.get("error", "erreur"), true)
		return
	_apply_transform_snapshot(
		result.get("snapshot") as GridTransformSnapshot,
		"Restaurer le point %s" % restore_points_list.get_item_text(index)
	)


func rename_selected_restore_point() -> void:
	if restore_points_list == null or restore_points_list.get_selected_items().is_empty():
		return
	if restore_name_edit.text.strip_edges().is_empty():
		_set_status("Saisissez le nouveau nom du point.", true)
		return
	var index: int = restore_points_list.get_selected_items()[0]
	var path := str(restore_points_list.get_item_metadata(index))
	var error := ArenaRestorePointService.rename_point(path, restore_name_edit.text)
	if error != OK:
		_set_status("Le point n'a pas pu être renommé.", true)
		return
	restore_name_edit.clear()
	_refresh_restore_points()
	_set_status("Point de restauration renommé.")


func delete_selected_restore_point() -> void:
	if restore_points_list == null or restore_points_list.get_selected_items().is_empty():
		return
	var index: int = restore_points_list.get_selected_items()[0]
	_pending_restore_delete_path = str(restore_points_list.get_item_metadata(index))
	restore_delete_dialog.popup_centered()


func _confirm_delete_restore_point() -> void:
	if _pending_restore_delete_path.is_empty():
		return
	var error := ArenaRestorePointService.delete_point(_pending_restore_delete_path)
	_pending_restore_delete_path = ""
	if error != OK:
		_set_status("Le point n'a pas pu être supprimé.", true)
		return
	_refresh_restore_points()
	_set_status("Point de restauration supprimé.")


func restore_saved_calibration() -> void:
	if edit_session == null:
		return
	_apply_transform_snapshot(
		edit_session.saved_transform(), "Restaurer la calibration sauvegardée"
	)


func _on_reset_requested(id: int) -> void:
	if arena == null or edit_session == null:
		return
	var current := GridTransformSnapshot.from_arena(arena)
	var saved := edit_session.saved_transform()
	match id:
		0:
			_apply_transform_snapshot(saved, "Restaurer la calibration sauvegardée")
		1:
			current.origin = saved.origin
			_apply_transform_snapshot(current, "Réinitialiser la position sauvegardée")
		2:
			current.axis_x = saved.axis_x
			current.axis_y = saved.axis_y
			_apply_transform_snapshot(current, "Réinitialiser les axes sauvegardés")
		3:
			var pivot := GridTransformService.logical_grid_center(current, arena.grid_size)
			var angle := current.axis_x.angle_to(saved.axis_x)
			_apply_transform_snapshot(
				GridTransformService.rotate_around(current, pivot, angle),
				"Réinitialiser la rotation vers la sauvegarde"
			)


func _apply_transform_snapshot(snapshot: GridTransformSnapshot, action_name: String) -> void:
	if arena == null or snapshot == null:
		return
	var validation := GridTransformService.validate_snapshot(snapshot)
	if not bool(validation.get("ok", false)):
		_set_status("Calibration refusée : %s" % validation.get("error", "invalide"), true)
		return
	var before := arena.to_snapshot()
	snapshot.apply_to(arena)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	_commit_change(action_name, before, arena.to_snapshot())
	_refresh_all()


func _refresh_restore_points() -> void:
	if restore_points_list == null:
		return
	restore_points_list.clear()
	if arena == null:
		return
	for point in ArenaRestorePointService.list_points(arena.arena_id):
		var created := Time.get_datetime_string_from_unix_time(
			int(float(point.get("created_unix", 0.0))), true
		)
		restore_points_list.add_item("%s  -  %s" % [point.get("name", "Calibration"), created])
		restore_points_list.set_item_metadata(
			restore_points_list.item_count - 1, point.get("path", "")
		)


func _on_stroke_started(_action_name: String) -> void:
	if arena == null:
		return
	_stroke_before = arena.to_snapshot()
	_stroke_changed = false
	_stroke_cell_count = 0
	_stroke_transform_commit = false
	stroke_batch.begin_stroke(arena)


func _on_cells_edit_requested(cells: Array[Vector2i], erase: bool) -> void:
	if arena == null:
		return
	for cell in cells:
		var changed := false
		if workspace_mode == WorkspaceMode.DYNAMIC_CONSTRUCTION:
			changed = _apply_dynamic_cell_edit(cell, erase)
			if changed:
				_stroke_changed = true
				_stroke_cell_count += 1
			continue
		match canvas.active_tool:
			ArenaStudioCanvas.Tool.ADD_CELL:
				changed = ArenaEditingService.set_cell_state(arena, cell, &"remove" if erase else &"add")
			ArenaStudioCanvas.Tool.REMOVE_CELL:
				changed = ArenaEditingService.set_cell_state(arena, cell, &"add" if erase else &"remove")
			ArenaStudioCanvas.Tool.BORDER:
				changed = ArenaEditingService.set_cell_state(arena, cell, &"playable" if erase else &"border")
			ArenaStudioCanvas.Tool.OBSTACLE:
				changed = ArenaEditingService.clear_obstacle(arena, cell) if erase \
					else ArenaEditingService.set_obstacle(arena, cell, obstacle_option.selected)
			ArenaStudioCanvas.Tool.TERRAIN:
				var terrain_id := &"void" if erase else StringName(
					terrain_option.get_selected_metadata()
				)
				changed = not stroke_batch.apply_terrain_cells([cell], terrain_id).is_empty()
			ArenaStudioCanvas.Tool.SPAWN:
				if erase:
					for spawn in arena.spawns_at(cell):
						arena.spawns.erase(spawn)
					changed = true
				else:
					changed = ArenaEditingService.place_spawn(arena, cell, spawn_option.selected)
		if changed:
			_stroke_changed = true
			_stroke_cell_count += 1
	if canvas.active_tool != ArenaStudioCanvas.Tool.TERRAIN:
		ArenaRuntimeBridge.sync_runtime_resources(arena)
	if edit_session != null and canvas.active_tool != ArenaStudioCanvas.Tool.TERRAIN:
		edit_session.history.notify_preview_changed()
	canvas.update_terrain_cells(cells)
	_refresh_inspector(cells[-1] if not cells.is_empty() else GridTransformService.INVALID_CELL)


func _apply_dynamic_cell_edit(cell: Vector2i, erase: bool) -> bool:
	match canvas.active_tool:
		ArenaStudioCanvas.Tool.ADD_CELL:
			return ArenaEditingService.set_cell_state(arena, cell, &"remove" if erase else &"add")
		ArenaStudioCanvas.Tool.REMOVE_CELL:
			return ArenaEditingService.set_cell_state(arena, cell, &"add" if erase else &"remove")
		ArenaStudioCanvas.Tool.TERRAIN:
			var terrain_id := &"void" if erase else StringName(
				dynamic_terrain_option.get_selected_metadata()
			)
			return not stroke_batch.apply_terrain_cells([cell], terrain_id).is_empty()
		ArenaStudioCanvas.Tool.OBSTACLE:
			var wall_id := &"remove" if erase else StringName(
				dynamic_wall_option.get_selected_metadata()
			)
			return ArenaDynamicEditingService.place_wall(arena, cell, wall_id)
		ArenaStudioCanvas.Tool.SPAWN:
			var selected_special := StringName(dynamic_special_option.get_selected_metadata())
			if selected_special == &"vortex_network":
				return _edit_vortex_network_cell(cell, erase)
			var special_id := &"remove" if erase else selected_special
			match special_id:
				&"hero": return ArenaDynamicEditingService.place_spawn(
					arena, cell, ArenaSpawnDefinition.Kind.HERO_1
				)
				&"enemy": return ArenaDynamicEditingService.place_spawn(
					arena, cell, ArenaSpawnDefinition.Kind.ENEMY
				)
				&"summon": return ArenaDynamicEditingService.place_spawn(
					arena, cell, ArenaSpawnDefinition.Kind.SUMMON_ZONE
				)
				&"objective": return ArenaDynamicEditingService.place_objective(arena, cell)
				&"decoration": return ArenaDynamicEditingService.place_decoration(arena, cell)
				&"remove":
					_clear_pending_vortex()
					return ArenaDynamicEditingService.remove_special(arena, cell)
	return false


func _edit_vortex_network_cell(cell: Vector2i, erase: bool) -> bool:
	var network := ArenaVortexNetworkService.network_by_id(arena, _active_vortex_network_id)
	if network == null:
		network = ArenaVortexNetworkService.create_network(arena)
		_active_vortex_network_id = network.network_id
	var changed := ArenaVortexNetworkService.remove_cell(
		arena, network.network_id, cell
	) if erase else ArenaVortexNetworkService.add_cell(arena, network.network_id, cell)
	if changed:
		ArenaRuntimeBridge.sync_runtime_resources(arena)
		_refresh_vortex_dialog()
		_set_status(ArenaVortexNetworkService.behavior_summary(network))
	return changed


func _place_vortex_endpoint(cell: Vector2i) -> bool:
	if not ArenaDynamicEditingService.is_valid_vortex_cell(arena, cell):
		_set_status(
			"Vortex refusé : choisissez une dalle définie, praticable, hors bordure et non bloquée.",
			true
		)
		return false
	if _pending_vortex_cell == GridTransformService.INVALID_CELL:
		_pending_vortex_cell = cell
		canvas.set_pending_vortex_cell(cell)
		_set_status("Entrée du vortex choisie en (%d, %d). Choisissez sa sortie." % [cell.x, cell.y])
		return false
	var entry := _pending_vortex_cell
	var changed := ArenaDynamicEditingService.place_vortex_pair(arena, entry, cell)
	if changed:
		_clear_pending_vortex()
		_set_status("Paire de vortex créée : jeu réel, déplacements et IA actifs.")
	else:
		_set_status("Paire refusée : cellules distinctes et libres requises.", true)
	return changed


func _clear_pending_vortex() -> void:
	_pending_vortex_cell = GridTransformService.INVALID_CELL
	if canvas != null:
		canvas.set_pending_vortex_cell(_pending_vortex_cell)


func _on_stroke_finished(action_name: String) -> void:
	if arena == null:
		return
	if not _stroke_changed:
		stroke_batch.cancel()
		_stroke_before = {}
		_stroke_cell_count = 0
		_stroke_transform_commit = false
		return
	var was_transform_commit := _stroke_transform_commit
	if was_transform_commit:
		stroke_batch.cancel()
		_last_stroke_result = {"changed": true, "kind": "grid_transform"}
	else:
		_last_stroke_result = stroke_batch.finish() if stroke_batch.is_active() else {}
	var final_name := action_name
	if _stroke_cell_count > 0:
		final_name = "%s — %d case(s)" % [action_name, _stroke_cell_count]
	var after_snapshot := _grid_transform_snapshot_after(_stroke_before) \
		if was_transform_commit else arena.to_snapshot()
	_history_refresh_suppressed = was_transform_commit
	_commit_change(final_name, _stroke_before, after_snapshot, was_transform_commit)
	_history_refresh_suppressed = false
	if not _stroke_before.is_empty():
		last_operation_label.text = _describe_transform_operation(
			final_name, _stroke_before, after_snapshot
		)
	_stroke_before = {}
	_stroke_changed = false
	_stroke_transform_commit = false
	if was_transform_commit:
		_refresh_after_transform_commit()
	else:
		_refresh_all(false)


func _on_stroke_cancelled() -> void:
	if _stroke_changed and edit_session != null and not _stroke_before.is_empty():
		edit_session.apply_snapshot(_stroke_before)
		arena = edit_session.working_arena
	stroke_batch.cancel()
	_stroke_before = {}
	_stroke_changed = false
	_stroke_cell_count = 0
	_stroke_transform_commit = false
	if canvas != null:
		canvas.arena = arena
		canvas.refresh_terrain_plan()
		canvas.queue_redraw()
	_sync_advanced_values()
	_refresh_title()
	_refresh_calibration_label()
	history_state_changed.emit()


func _on_calibration_requested(origin: Vector2, axis_x: Vector2, axis_y: Vector2) -> void:
	var before := arena.to_snapshot()
	arena.grid_origin = origin
	arena.axis_x = axis_x
	arena.axis_y = axis_y
	arena.calibration_cells = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]
	arena.calibration_pixels = [origin, origin + axis_x, origin + axis_y]
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	_commit_change("Calibrer la grille en trois clics", before, arena.to_snapshot())
	_refresh_all()
	_set_status("Grille calibree. Utilisez les trois poignées colorees pour l'ajuster visuellement.")


func _on_calibration_preview(origin: Vector2, axis_x: Vector2, axis_y: Vector2) -> void:
	if not GridTransformService.is_invertible(axis_x, axis_y):
		return
	# Le canvas possÃ¨de la preview : le contrÃ´leur ne touche jamais la Resource
	# canonique ni l'historique pendant un geste continu.


func _on_anchors_preview(cells: Array[Vector2i], pixels: Array[Vector2]) -> void:
	if arena == null or cells.size() != pixels.size():
		return
	var unique := {}
	for index in range(cells.size()):
		if not arena.is_in_bounds(cells[index]) or unique.has(cells[index]) \
				or not GridTransformService.is_vector_finite(pixels[index]):
			return
		unique[cells[index]] = true
	# Validation lÃ©gÃ¨re uniquement ; la mutation est rÃ©servÃ©e au commit final.


func _on_transform_commit_requested(
		snapshot: GridTransformSnapshot,
		cells: Array[Vector2i],
		pixels: Array[Vector2]
	) -> void:
	if arena == null or snapshot == null or cells.size() != pixels.size():
		return
	var validation := GridTransformService.validate_snapshot(
		snapshot,
		GridTransformService.determinant(arena.axis_x, arena.axis_y)
	)
	if not bool(validation.get("ok", false)):
		return
	var unique := {}
	for index in range(cells.size()):
		if not arena.is_in_bounds(cells[index]) or unique.has(cells[index]) \
				or not GridTransformService.is_vector_finite(pixels[index]):
			return
		unique[cells[index]] = true
	snapshot.apply_to(arena)
	arena.calibration_cells = cells.duplicate()
	arena.calibration_pixels = pixels.duplicate()
	ArenaRuntimeBridge.sync_runtime_resources(
		arena, ArenaRuntimeBridge.SyncScope.GRID_TRANSFORM
	)
	_stroke_changed = true
	_stroke_transform_commit = true


func _on_hovered_cell_changed(cell: Vector2i) -> void:
	_last_hovered_cell = cell
	_refresh_inspector(cell)


func _on_verification_cell_requested(cell: Vector2i) -> void:
	if _verification_source == GridTransformService.INVALID_CELL:
		_verification_source = cell
		var grid := ArenaRuntimeBridge.build_grid(arena)
		var reachable: Array[Vector2i] = []
		if grid != null:
			for value in Pathfinder.new(grid).get_reachable(
				cell, arena.grid_size.x * arena.grid_size.y
			):
				reachable.append(value)
		reachable.append(cell)
		canvas.set_verification_overlay(reachable, [], [], false, GridTransformService.INVALID_CELL)
		_set_status("Source choisie en (%d, %d). Choisissez maintenant la cible." % [cell.x, cell.y])
		return
	var grid := ArenaRuntimeBridge.build_grid(arena)
	var pathfinder := Pathfinder.new(grid)
	if verification_option.selected == 0:
		var path: Array[Vector2i] = []
		for value in pathfinder.find_path(_verification_source, cell):
			path.append(value)
		canvas.set_verification_overlay(canvas.reachable_cells, path, [], false, GridTransformService.INVALID_CELL)
		_set_status("Chemin trouve : %d PM." % maxi(0, path.size() - 1) if not path.is_empty() else "Aucun chemin disponible.")
	else:
		var line := pathfinder.trace_line(_verification_source, cell)
		var blocker := pathfinder.first_line_blocker(_verification_source, cell, true)
		var blocked := blocker != Vector2i(-1, -1)
		canvas.set_verification_overlay([], [], line, blocked, blocker if blocked else GridTransformService.INVALID_CELL)
		_set_status(
			"Ligne de vue bloquée — premier obstacle en (%d, %d), regle : bloque les projectiles." % [blocker.x, blocker.y]
			if blocked else "Ligne de vue libre."
		)
	_verification_source = GridTransformService.INVALID_CELL


func _commit_change(
		action_name: String,
		before: Dictionary,
		after: Dictionary,
		topology_unchanged := false
	) -> void:
	if edit_session == null or before == after:
		return
	edit_session.commit(action_name, before, after, topology_unchanged)
	_autosave()
	_refresh_title()
	history_state_changed.emit()


func _grid_transform_snapshot_after(before: Dictionary) -> Dictionary:
	var after := before.duplicate(false)
	after["grid_origin"] = [arena.grid_origin.x, arena.grid_origin.y]
	after["axis_x"] = [arena.axis_x.x, arena.axis_x.y]
	after["axis_y"] = [arena.axis_y.x, arena.axis_y.y]
	after["calibration_cells"] = arena.calibration_cells.map(
		func(value): return [value.x, value.y]
	)
	after["calibration_pixels"] = arena.calibration_pixels.map(
		func(value): return [value.x, value.y]
	)
	return after


func _restore_snapshot(snapshot: Dictionary) -> void:
	if edit_session == null:
		return
	edit_session.apply_snapshot(snapshot)
	arena = edit_session.working_arena
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	if runtime_preview != null:
		runtime_preview.set_arena(arena)
	_refresh_all()


func _autosave() -> void:
	if arena != null and _recovery_timer != null:
		_recovery_timer.start()


func _flush_recovery() -> void:
	if arena != null and dirty:
		ArenaSerializer.save_recovery(arena, _recovery_context())
	_refresh_recovery_button()


func _recovery_context() -> Dictionary:
	var context := {
		"domain": &"arena",
		"arena_id": str(arena.arena_id) if arena != null else "",
		"source": edit_session.source_path if edit_session != null else "",
		"transaction": "arena_autosave",
		"status": "RECOVERABLE",
	}
	if project_context != null:
		var snapshot := project_context.snapshot()
		for key in [
			"run_path", "run_name", "room_path", "room_name", "room_index",
		]:
			context[key] = snapshot.get(key)
	return context


func _refresh_all(sync_runtime := true) -> void:
	if sync_runtime:
		ArenaRuntimeBridge.sync_runtime_resources(arena)
	canvas.refresh_terrain_plan()
	canvas.queue_redraw()
	if runtime_preview != null and runtime_preview.visible:
		runtime_preview.set_arena(arena)
	_sync_advanced_values()
	_refresh_title()
	_refresh_calibration_label()
	_refresh_dynamic_palette()
	_refresh_destination_panel()
	_autosave()


func _refresh_after_transform_commit() -> void:
	canvas.queue_redraw()
	if runtime_preview != null and runtime_preview.visible:
		runtime_preview.set_arena(arena)
	_sync_advanced_values()
	_refresh_title()
	_refresh_calibration_label()
	_refresh_transform_inspector()
	_mark_destination_plan_obsolete()
	_autosave()


func _refresh_title() -> void:
	if title_label != null:
		title_label.text = "%s — %s%s" % [
			TerrainVocabulary.TAB_TITLE,
			arena.display_name if arena != null else "Aucun terrain",
			" • non enregistré" if dirty else "",
		]
	_refresh_workflow()


func _on_history_changed() -> void:
	if edit_session == null:
		return
	if _history_refresh_suppressed:
		history_state_changed.emit()
		return
	arena = edit_session.working_arena
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	canvas.arena = arena
	canvas.refresh_terrain_plan()
	canvas.queue_redraw()
	_sync_advanced_values()
	_refresh_title()
	_refresh_calibration_label()
	_refresh_transform_inspector()
	_refresh_dynamic_palette()
	_refresh_destination_panel()
	history_state_changed.emit()


func _on_dirty_state_changed(_is_dirty: bool) -> void:
	if project_context != null:
		project_context.set_dirty(&"arena", dirty, {
			"document": history_document_name(),
			"source_path": edit_session.source_path if edit_session != null else "",
		})
	_refresh_title()
	history_state_changed.emit()


func history_can_undo() -> bool:
	return edit_session != null and edit_session.history.can_undo()


func history_can_redo() -> bool:
	return edit_session != null and edit_session.history.can_redo()


func history_undo() -> bool:
	return edit_session != null and edit_session.history.undo()


func history_redo() -> bool:
	return edit_session != null and edit_session.history.redo()


func history_undo_name() -> String:
	return edit_session.history.get_undo_action_name() if edit_session != null else ""


func history_redo_name() -> String:
	return edit_session.history.get_redo_action_name() if edit_session != null else ""


func history_entries() -> Array[Dictionary]:
	return edit_session.history.get_history_entries() if edit_session != null else []


func history_current_index() -> int:
	return edit_session.history.get_current_index() if edit_session != null else 0


func history_jump_to(index: int) -> bool:
	if canvas != null and canvas.has_method("has_active_gesture") \
			and canvas.has_active_gesture():
		return false
	return edit_session != null and edit_session.history.jump_to(index)


func history_is_at_saved_state() -> bool:
	return edit_session != null and not edit_session.is_dirty()


func history_opening_is_saved() -> bool:
	if edit_session == null:
		return false
	var entries := edit_session.history.get_history_entries()
	if entries.is_empty():
		return edit_session.history.is_at_saved_state()
	return str(entries[0].get("before_fingerprint", "")) \
		== edit_session.history.get_saved_fingerprint()


func history_document_name() -> String:
	return arena.display_name if arena != null else "Aucune carte"


func cancel_active_gesture() -> bool:
	return canvas != null and canvas.cancel_active_gesture()


func _refresh_calibration_label() -> void:
	if arena == null:
		return
	var count := mini(arena.calibration_cells.size(), arena.calibration_pixels.size())
	if count < 3:
		calibration_label.text = "Alignement à vérifier"
		return
	var sum_squared := 0.0
	var maximum := 0.0
	for index in range(count):
		var predicted := GridTransformService.cell_to_position(
			arena.calibration_cells[index], arena.grid_origin, arena.axis_x, arena.axis_y
		)
		var anchor_error := predicted.distance_to(arena.calibration_pixels[index])
		sum_squared += anchor_error * anchor_error
		maximum = maxf(maximum, anchor_error)
	var error := sqrt(sum_squared / float(count))
	var quality := GridTransformService.calibration_quality(
		error, count
	)
	calibration_label.text = {
		&"excellent": "Alignement excellent",
		&"acceptable": "Alignement correct",
		&"check": "Alignement à vérifier",
		&"insufficient": "Calibration insuffisante",
	}.get(quality, "Alignement à vérifier") \
		+ "  -  RMS %.2f px / max %.2f px" % [error, maximum]


func _refresh_transform_inspector() -> void:
	if arena == null or inspector_label == null:
		return
	# Les mesures affines n'apparaissent que si l'outil concerné est vraiment
	# actif : sinon elles écrasaient la fiche de la case survolée, y compris en
	# mode guidé, à chaque changement d'historique.
	if canvas == null or canvas.active_tool not in [
		ArenaStudioCanvas.Tool.TRANSFORM_GRID,
		ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS,
	]:
		if angle_mode_option != null and canvas != null:
			angle_mode_option.select(canvas.angle_mode)
		return
	var axis_angle := rad_to_deg(GridTransformService.angle_between_axes(
		arena.axis_x, arena.axis_y
	))
	var determinant_value := GridTransformService.determinant(arena.axis_x, arena.axis_y)
	var relative := GridTransformService.relative_determinant(arena.axis_x, arena.axis_y)
	var pivot := canvas.current_editor_pivot()
	var average_scale := 1.0
	if edit_session != null:
		var saved := edit_session.saved_transform()
		average_scale = 0.5 * (
			arena.axis_x.length() / maxf(saved.axis_x.length(), 0.00001)
			+ arena.axis_y.length() / maxf(saved.axis_y.length(), 0.00001)
		)
	var mode_label: String = ["Symétrique", "Conserver X", "Conserver Y"][canvas.angle_mode]
	inspector_label.text = (
		"GRILLE AFFINE SÉLECTIONNÉE\n"
		+ "Position : %.2f, %.2f px\n" % [arena.grid_origin.x, arena.grid_origin.y]
		+ "Axe X : %.2f px / %.2f deg\n" % [arena.axis_x.length(), rad_to_deg(arena.axis_x.angle())]
		+ "Axe Y : %.2f px / %.2f deg\n" % [arena.axis_y.length(), rad_to_deg(arena.axis_y.angle())]
		+ "Rotation globale : %.2f deg\n" % rad_to_deg(
			GridTransformService.approximate_global_rotation(arena.axis_x, arena.axis_y)
		)
		+ "Ouverture : %.2f deg • %s\n" % [axis_angle, mode_label]
		+ "Échelle moyenne : %.2f %%\n" % (average_scale * 100.0)
		+ "Pivot : %.2f, %.2f • %s\n" % [pivot.x, pivot.y, canvas.editor_pivot_mode()]
		+ "Inversibilité : %.6f • det %.3f" % [relative, determinant_value]
	)
	if angle_mode_option != null:
		angle_mode_option.select(canvas.angle_mode)


func _describe_transform_operation(
		action_name: String,
		before_data: Dictionary,
		after_data: Dictionary
	) -> String:
	var before := GridTransformSnapshot.from_dictionary({
		"origin": before_data.get("grid_origin", [0.0, 0.0]),
		"axis_x": before_data.get("axis_x", [0.0, 0.0]),
		"axis_y": before_data.get("axis_y", [0.0, 0.0]),
	})
	var after := GridTransformSnapshot.from_dictionary({
		"origin": after_data.get("grid_origin", [0.0, 0.0]),
		"axis_x": after_data.get("axis_x", [0.0, 0.0]),
		"axis_y": after_data.get("axis_y", [0.0, 0.0]),
	})
	var delta := after.origin - before.origin
	var rotation := rad_to_deg(before.axis_x.angle_to(after.axis_x))
	var scale := after.axis_x.length() / maxf(before.axis_x.length(), 0.00001)
	return "Dernière opération : %s\nX %+0.2f px  Y %+0.2f px  Angle %+0.2f°  Échelle %.2f %%" % [
		action_name, delta.x, delta.y, rotation, scale * 100.0
	]


func _update_layer_controls() -> void:
	for key in layer_controls:
		var controls: Dictionary = layer_controls[key]
		var locked := controls.get("locked") as CheckBox
		var visible := controls.get("visible") as CheckBox
		if locked != null:
			locked.set_pressed_no_signal(bool(canvas.layer_locks.get(key, false)))
		if visible != null:
			visible.set_pressed_no_signal(bool(canvas.layer_visibility.get(key, true)))


func _update_transform_controls() -> void:
	var values := {
		"snap_enabled": canvas.snap_enabled,
		"preserve_axis_length": canvas.preserve_axis_length,
		"preserve_axis_angle": canvas.preserve_axis_angle,
		"mirror_axes": canvas.mirror_axes,
		"lock_translation": canvas.lock_translation,
		"lock_rotation": canvas.lock_rotation,
		"lock_scale": canvas.lock_scale,
		"lock_axis_x": canvas.lock_axis_x,
		"lock_axis_y": canvas.lock_axis_y,
		"independent_axes": not canvas.mirror_axes,
	}
	for key in values:
		var control := transform_controls.get(key) as CheckButton
		if control != null:
			control.set_pressed_no_signal(bool(values[key]))
	if angle_mode_option != null:
		angle_mode_option.select(canvas.angle_mode)


func _save_session_editor_state() -> void:
	if edit_session == null or canvas == null:
		return
	edit_session.editor_state = canvas.get_editor_state()


func _restore_session_editor_state() -> void:
	if edit_session == null or canvas == null:
		return
	canvas.apply_editor_state(edit_session.editor_state)
	_update_layer_controls()
	_update_transform_controls()


func _refresh_inspector(cell: Vector2i) -> void:
	if canvas != null and canvas.active_tool in [
		ArenaStudioCanvas.Tool.TRANSFORM_GRID,
		ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS,
	]:
		_refresh_transform_inspector()
		return
	if arena == null or cell == GridTransformService.INVALID_CELL:
		inspector_label.text = "Survolez une case."
		return
	var definition := arena.get_cell_definition(cell)
	if definition == null:
		inspector_label.text = "Cellule (%d, %d)\nNon définie" % [cell.x, cell.y]
		return
	var state := "Bordure" if definition.border else ("Jouable" if definition.playable else "Non jouable")
	var obstacle := arena.obstacle_at(cell)
	inspector_label.text = "Cellule (%d, %d)\n%s\nTerrain : %s\nObstacle : %s\nSpawns : %d" % [
		cell.x, cell.y, state, str(definition.terrain_id),
		"aucun" if obstacle == null else ["Mur complet", "Obstacle bas", "Décor traversable", "Falaise"][obstacle.preset],
		arena.spawns_at(cell).size(),
	]


func _sync_advanced_values() -> void:
	if arena == null or advanced_values.size() != 6:
		return
	var values := [arena.grid_origin.x, arena.grid_origin.y, arena.axis_x.x, arena.axis_x.y, arena.axis_y.x, arena.axis_y.y]
	for index in range(6):
		advanced_values[index].value = values[index]


func _apply_advanced_values() -> void:
	if arena == null:
		return
	var next_origin := Vector2(advanced_values[0].value, advanced_values[1].value)
	var next_axis_x := Vector2(advanced_values[2].value, advanced_values[3].value)
	var next_axis_y := Vector2(advanced_values[4].value, advanced_values[5].value)
	if not GridTransformService.is_invertible(next_axis_x, next_axis_y):
		_set_status("Les axes saisis sont colinéaires : la modification est refusée.", true)
		return
	var before := arena.to_snapshot()
	arena.grid_origin = next_origin
	arena.axis_x = next_axis_x
	arena.axis_y = next_axis_y
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	_commit_change("Modifier la calibration avancée", before, arena.to_snapshot())
	_refresh_all()


## Compatibilite : l'ancien selecteur Creation / Verification / Avance est
## remplace par l'interrupteur Mode guide / Mode avance. Les rares appelants
## historiques sont redirges vers le nouveau contrat.
func _on_mode_selected(index: int) -> void:
	if index == 2:
		set_guided(false)
		return
	set_guided(true)
	if index == 1:
		set_current_step(TerrainWorkflowService.Step.VERIFY)
		validate_arena()
	else:
		canvas.clear_overlays()
	canvas.queue_redraw()


func _on_library_activated(index: int) -> void:
	if project_context != null:
		project_context.request_room(index, &"arena")
	elif index >= 0 and index < LEGACY_CALIBRATION_TEMPLATES.size():
		load_production(LEGACY_CALIBRATION_TEMPLATES[index][1])


func _on_context_run_changed(_run_data: RunData) -> void:
	if _run_data != null:
		run_authoring.open(_run_data, shared_reference_graph)
	_refresh_run_browser()


func _on_context_room_changed(_room_index: int, room: RoomData) -> void:
	_refresh_run_browser()
	if room != null:
		_open_context_room(room)


func _refresh_run_browser() -> void:
	if library_list == null:
		return
	library_list.clear()
	if project_context == null or project_context.active_run == null:
		for entry in LEGACY_CALIBRATION_TEMPLATES:
			library_list.add_item(entry[0])
		return
	var displayed_run := run_authoring.working_run \
		if run_authoring.working_run != null else project_context.active_run
	for index in range(displayed_run.rooms.size()):
		var room := displayed_run.rooms[index]
		library_list.add_item("%02d  %s" % [
			index + 1, room.room_name if room != null else "Salle absente",
		])
		library_list.set_item_tooltip(
			index, room.resource_path if room != null else "Référence nulle"
		)
	if project_context.active_room_index >= 0 \
			and project_context.active_room_index < library_list.item_count:
		library_list.select(project_context.active_room_index)


func _open_context_room(room: RoomData) -> bool:
	if room == null:
		return false
	var imported := room as ArenaDefinition
	if imported == null and not room.resource_path.is_empty():
		imported = ArenaLegacyImporter.import_room(room.resource_path)
	if imported == null:
		_set_status(
			"La salle %s ne possède pas encore de grille Arena modifiable." % room.room_name,
			true
		)
		return false
	var key := "run-room:%s" % room.resource_path
	if _sessions.has(key):
		_activate_session(_sessions[key] as ArenaEditSession)
	else:
		_set_arena(imported, false, key)
	_set_status("Salle ouverte depuis la partie active : %s" % room.room_name)
	return true


func _context_save() -> Dictionary:
	save_arena()
	return {
		"ok": not dirty,
		"error": "La sauvegarde Arena n'a pas validé le document." if dirty else "",
	}


func _context_draft() -> Dictionary:
	_flush_recovery()
	return {"ok": arena != null}


func _context_discard() -> Dictionary:
	if edit_session == null or edit_session.source_arena == null:
		return {"ok": false, "error": "Aucune source Arena à recharger."}
	var source := edit_session.source_arena
	var source_path := edit_session.source_path
	var key := edit_session.session_key
	var replacement := ArenaEditSession.new()
	if not replacement.open(source, source_path, false, key):
		return {"ok": false, "error": "La source Arena n'a pas pu être rechargée."}
	_sessions[key] = replacement
	_activate_session(replacement)
	if project_context != null:
		project_context.set_dirty(&"arena", false)
	return {"ok": true}


func _context_is_dirty() -> bool:
	return dirty


func _context_snapshot() -> Dictionary:
	return edit_session.working_arena.to_snapshot().duplicate(true) \
		if edit_session != null and edit_session.working_arena != null else {}


func _context_restore(snapshot: Dictionary) -> Dictionary:
	if edit_session == null or snapshot.is_empty():
		return {"ok": false, "error": "Instantané Arena absent."}
	edit_session.apply_snapshot(snapshot)
	arena = edit_session.working_arena
	_on_history_changed()
	return {"ok": true}


func _on_run_authoring_changed(_report: Dictionary) -> void:
	if project_context != null:
		project_context.set_dirty(&"arena_run", run_authoring.is_dirty(), {
			"run_path": run_authoring.source_path,
			"room_count": run_authoring.working_run.rooms.size() \
				if run_authoring.working_run != null else 0,
		})
	_refresh_run_browser()


func _selected_run_room_index() -> int:
	var selected := library_list.get_selected_items() if library_list != null else PackedInt32Array()
	return selected[0] if not selected.is_empty() else (
		project_context.active_room_index if project_context != null else -1
	)


func _saved_current_arena_room() -> RoomData:
	if edit_session == null or edit_session.source_path.is_empty() \
			or not ResourceLoader.exists(edit_session.source_path):
		return null
	return ResourceLoader.load(
		edit_session.source_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RoomData


func _attach_current_arena(insert: bool) -> void:
	var room := _saved_current_arena_room()
	if room == null:
		_set_status("Sauvegardez d'abord l'arène dans res://data avant de l'attacher à la partie.", true)
		return
	var index := _selected_run_room_index()
	var result := run_authoring.insert_room(index + 1, room) \
		if insert else run_authoring.replace_room(index, room)
	_set_status(
		"Plan d'attachement préparé à l'index %d." % int(result.get("index", index))
		if result.get("ok", false) else str(result.get("error", "Attachement refusé.")),
		not result.get("ok", false)
	)


func _duplicate_run_room() -> void:
	var result := run_authoring.duplicate_room(_selected_run_room_index())
	_set_status("Salle dupliquée ; choisissez un chemin avant la sauvegarde." \
		if result.get("ok", false) else str(result.get("error", "Duplication refusée.")),
		not result.get("ok", false))


func _make_run_room_specific() -> void:
	var index := _selected_run_room_index()
	if run_authoring.working_run == null or index < 0 \
			or index >= run_authoring.working_run.rooms.size():
		_set_status("Sélectionnez une salle à copier.", true)
		return
	var room := run_authoring.working_run.rooms[index]
	var run_id := ArenaDefinition.sanitize_id(run_authoring.working_run.run_name)
	var room_id := ArenaDefinition.sanitize_id(room.room_name if room != null else "salle")
	var path := "res://data/arenas/run_specific/%s/%02d_%s.tres" % [
		run_id, index + 1, room_id,
	]
	var result := run_authoring.make_room_run_specific(index, path)
	_set_status("Copie spécifique créée : %s" % path \
		if result.get("ok", false) else str(result.get("error", "Copie refusée.")),
		not result.get("ok", false))


func _move_run_room(offset: int) -> void:
	var index := _selected_run_room_index()
	var result := run_authoring.move_room(index, index + offset)
	if not result.get("ok", false):
		_set_status(str(result.get("error", "Déplacement refusé.")), true)


func _remove_run_room() -> void:
	var result := run_authoring.remove_room(_selected_run_room_index())
	_set_status("Référence retirée ; aucun fichier n'a été supprimé." \
		if result.get("ok", false) else str(result.get("error", "Retrait refusé.")),
		not result.get("ok", false))


func _save_run_sequence() -> void:
	var result := run_authoring.save()
	if result.get("ok", false) and project_context != null:
		project_context.set_dirty(&"arena_run", false)
		if shared_reference_graph != null:
			shared_reference_graph.scan(true)
	_set_status("Séquence de partie sauvegardée et relue." \
		if result.get("ok", false) else str(result.get("error", "Sauvegarde refusée.")),
		not result.get("ok", false))


func _reload_run_sequence() -> void:
	var ok := run_authoring.reload()
	if project_context != null and ok:
		project_context.set_dirty(&"arena_run", false)
	_set_status("Séquence rechargée." if ok else "Rechargement de la partie impossible.", not ok)


func _context_run_save() -> Dictionary:
	return run_authoring.save()


func _context_run_draft() -> Dictionary:
	return run_authoring.write_draft()


func _context_run_discard() -> Dictionary:
	var ok := run_authoring.reload()
	return {"ok": ok, "error": "La partie n'a pas pu être rechargée." if not ok else ""}


func _on_tool_selected(index: int) -> void:
	if index != ArenaStudioCanvas.Tool.SPAWN:
		_clear_pending_vortex()
	var dynamic_tool := index in [
		ArenaStudioCanvas.Tool.ADD_CELL,
		ArenaStudioCanvas.Tool.REMOVE_CELL,
		ArenaStudioCanvas.Tool.TERRAIN,
		ArenaStudioCanvas.Tool.OBSTACLE,
		ArenaStudioCanvas.Tool.SPAWN,
	]
	var preserve_dynamic := workspace_mode == WorkspaceMode.DYNAMIC_CONSTRUCTION and dynamic_tool
	_show_editor_canvas(preserve_dynamic)
	canvas.set_tool(index)
	_refresh_active_tool_contract(index)
	canvas.set_dynamic_construction_mode(preserve_dynamic)
	canvas.layer_locks["calibration"] = index not in [
		ArenaStudioCanvas.Tool.TRANSFORM_GRID,
		ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS,
	]
	_update_layer_controls()
	obstacle_option.visible = not preserve_dynamic and index == ArenaStudioCanvas.Tool.OBSTACLE
	terrain_option.visible = not preserve_dynamic and index == ArenaStudioCanvas.Tool.TERRAIN \
		and not guided
	spawn_option.visible = not preserve_dynamic and index == ArenaStudioCanvas.Tool.SPAWN
	verification_option.visible = index == ArenaStudioCanvas.Tool.VERIFY
	if dynamic_palette != null:
		dynamic_palette.visible = preserve_dynamic
	if tool_palette != null:
		tool_palette.set_active_tool(index)
	var tool_step := _step_for_tool(index)
	if tool_step >= 0 and tool_step != current_step:
		current_step = tool_step
		if workflow_rail != null:
			workflow_rail.set_current_step(current_step)
		if tool_palette != null:
			tool_palette.set_active_step(current_step)
		if inspector_panel != null:
			inspector_panel.set_context(current_step, guided)
		_refresh_workflow()
	if transform_panel != null:
		transform_panel.visible = index == ArenaStudioCanvas.Tool.TRANSFORM_GRID
	calibration_label.visible = index in [
		ArenaStudioCanvas.Tool.TRANSFORM_GRID,
		ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS,
	]
	canvas.layer_visibility["calibration"] = index in [
		ArenaStudioCanvas.Tool.TRANSFORM_GRID,
		ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS,
	]
	shape_option.visible = index in [
		ArenaStudioCanvas.Tool.ADD_CELL,
		ArenaStudioCanvas.Tool.REMOVE_CELL,
		ArenaStudioCanvas.Tool.BORDER,
		ArenaStudioCanvas.Tool.OBSTACLE,
		ArenaStudioCanvas.Tool.TERRAIN,
		ArenaStudioCanvas.Tool.SPAWN,
	]
	if index == ArenaStudioCanvas.Tool.TRANSFORM_GRID:
		_refresh_transform_inspector()
		_set_status("Grille sélectionnée : glissez son corps ou une poignée. Échap ou clic droit annule le geste.")
	elif index == ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS:
		_refresh_transform_inspector()
		_set_status("Ancres : cliquez pour ajouter, glissez pour déplacer, clic droit pour supprimer.")
	elif preserve_dynamic:
		_refresh_dynamic_palette()
		_set_status("Construction dynamique — un seul outil traite le canvas.")


func _refresh_active_tool_contract(index: int) -> void:
	if index < 0 or index >= TOOL_LABELS.size():
		return
	var help: Array = TOOL_HELP[index]
	var contract := (
		"OUTIL ACTIF  ◉ %s\nRaccourci : %s\nClic gauche : %s\nClic droit : %s"
	) % [TOOL_LABELS[index], help[0], help[1], help[2]]
	if active_tool_label != null:
		active_tool_label.text = contract
	if tool_palette != null:
		tool_palette.set_contract_text(contract)


func _on_verification_kind_selected(index: int) -> void:
	canvas.verification_kind = &"path" if index == 0 else &"line_of_sight"
	_verification_source = GridTransformService.INVALID_CELL
	canvas.clear_overlays()


func _select_tool_and_preset(tool: int, preset: int) -> void:
	tool_list.select(tool)
	_on_tool_selected(tool)
	if tool == ArenaStudioCanvas.Tool.SPAWN:
		spawn_option.select(preset)


func _select_verification(kind: int) -> void:
	set_current_step(TerrainWorkflowService.Step.VERIFY)
	tool_list.select(ArenaStudioCanvas.Tool.VERIFY)
	_on_tool_selected(ArenaStudioCanvas.Tool.VERIFY)
	verification_option.select(kind)
	_on_verification_kind_selected(kind)


func _on_validation_item_selected(index: int) -> void:
	var entry := validation_list.get_item_metadata(index) as ArenaValidationMessage
	if entry != null and entry.cell != GridTransformService.INVALID_CELL:
		canvas.center_on_cell(entry.cell)
		_refresh_inspector(entry.cell)


func _refresh_recovery_button() -> void:
	if recovery_button != null:
		recovery_button.visible = bool(
			ArenaRecoveryContextSelectionService.scan(_recovery_context()).get(
				"ok", false
			)
		)


func _export_previews(directory: String) -> void:
	var previous_grid := canvas.show_grid
	var previous_spawns := canvas.show_spawns
	canvas.show_grid = false
	canvas.show_spawns = false
	canvas.queue_redraw()
	await _save_canvas_capture(directory.path_join("preview_clean.png"))
	canvas.show_grid = true
	canvas.queue_redraw()
	await _save_canvas_capture(directory.path_join("preview_grid.png"))
	canvas.show_spawns = true
	canvas.queue_redraw()
	await _save_canvas_capture(directory.path_join("preview_spawns.png"))
	canvas.show_grid = previous_grid
	canvas.show_spawns = previous_spawns
	canvas.queue_redraw()


func _save_canvas_capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return
	var rect := canvas.get_global_rect()
	var region := Rect2i(Vector2i(rect.position), Vector2i(rect.size)).intersection(
		Rect2i(Vector2i.ZERO, image.get_size())
	)
	if region.has_area():
		image = image.get_region(region)
	image.save_png(ProjectSettings.globalize_path(path))


func _set_status(message: String, error := false) -> void:
	status_label.text = message
	status_label.add_theme_color_override(
		"font_color", Color(1.0, 0.46, 0.38) if error else Color(0.76, 0.88, 0.96)
	)


func _add_button(parent: Node, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.50, 0.82, 0.98))
	return label


func _plain_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _labeled_line(parent: Node, label_text: String, placeholder: String) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	parent.add_child(edit)
	return edit


func _spin(parent: Node, label_text: String, value: float, minimum: float, maximum: float) -> SpinBox:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(group)
	var label := Label.new()
	label.text = label_text
	group.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = value
	spin.allow_greater = true
	group.add_child(spin)
	return spin


## L'hote decide si la barre historique existe encore ; le mode guide decide si
## elle est montree. Les deux conditions doivent etre vraies pour l'afficher.
func set_shell_toolbar_visible(value: bool) -> void:
	_shell_toolbar_allowed = value
	if top_bar != null:
		top_bar.visible = value and not guided and size.y >= 760.0


func _toggle_bottom_drawer() -> void:
	if bottom_drawer_content == null:
		return
	bottom_drawer_content.visible = not bottom_drawer_content.visible
	bottom_drawer_button.text = (
		"Validation • Historique • Rapport • Console • Analyse   ▼"
		if bottom_drawer_content.visible else
		"✓ Validation fermée • Historique • Rapport • Console • Analyse   ▲"
	)
	_sync_drawer_split()
	# Sur un écran court, guidage et tiroir ne tiennent pas ensemble au-dessus
	# du canvas. Le guidage s'efface le temps de lire le tiroir, puis revient :
	# la préférence de l'utilisateur n'est pas modifiée.
	if guidance_panel == null:
		return
	if bottom_drawer_content.visible and size.y < 760.0 and guidance_visible:
		_guidance_hidden_for_drawer = true
		guidance_panel.visible = false
	elif _guidance_hidden_for_drawer and not bottom_drawer_content.visible:
		_guidance_hidden_for_drawer = false
		guidance_panel.visible = guidance_visible


func toggle_focus_map() -> bool:
	set_focus_map(not focus_map_enabled)
	return focus_map_enabled


func set_focus_map(value: bool) -> void:
	if focus_map_enabled == value:
		return
	# Le mode Focus doit rendre la carte au plein panneau : le guidage, la
	# palette contextuelle et l'en-tête du domaine s'effacent aussi, et leur
	# visibilité exacte est restaurée au retour.
	if value:
		_pre_focus_state = {
			"left": left_panel.visible,
			"right": right_panel.visible,
			"drawer": bottom_drawer_content.visible,
			"navigation": canvas_navigation.visible,
			"guidance": guidance_panel.visible if guidance_panel != null else false,
			"palette": palette_scroll.visible if palette_scroll != null else false,
			"header": header_bar.visible if header_bar != null else false,
			"home": home_panel.visible if home_panel != null else false,
			"wizard": creation_wizard.visible if creation_wizard != null else false,
		}
		# Agrandir la carte n'a de sens que sur l'écran d'édition : s'il est
		# fermé, Focus l'ouvre, et le retour rétablit l'écran précédent.
		if editor_screen != null and not editor_screen.visible:
			home_panel.hide()
			creation_wizard.hide()
			editor_screen.show()
		left_panel.hide()
		right_panel.hide()
		bottom_drawer_content.hide()
		canvas_navigation.hide()
		if guidance_panel != null:
			guidance_panel.hide()
		if palette_scroll != null:
			palette_scroll.hide()
		if header_bar != null:
			header_bar.hide()
	else:
		left_panel.visible = bool(_pre_focus_state.get("left", true))
		right_panel.visible = bool(_pre_focus_state.get("right", true))
		bottom_drawer_content.visible = bool(_pre_focus_state.get("drawer", false))
		canvas_navigation.visible = bool(_pre_focus_state.get("navigation", true))
		if guidance_panel != null:
			guidance_panel.visible = bool(_pre_focus_state.get("guidance", true))
		if palette_scroll != null:
			palette_scroll.visible = bool(_pre_focus_state.get("palette", true))
		if header_bar != null:
			header_bar.visible = bool(_pre_focus_state.get("header", true))
		var restored_home := bool(_pre_focus_state.get("home", false))
		var restored_wizard := bool(_pre_focus_state.get("wizard", false))
		if restored_home or restored_wizard:
			home_panel.visible = restored_home
			creation_wizard.visible = restored_wizard
			editor_screen.hide()
	focus_map_enabled = value
	_apply_responsive_layout()


func apply_workspace_preset(index: int) -> void:
	workspace_preset = clampi(index, 0, 3)
	if focus_map_enabled:
		set_focus_map(false)
	match workspace_preset:
		0:
			left_panel.show()
			right_panel.show()
			bottom_drawer_content.hide()
			_show_editor_canvas()
		1:
			left_panel.show()
			right_panel.show()
			bottom_drawer_content.show()
			_show_editor_canvas()
			_select_tool_and_preset(ArenaStudioCanvas.Tool.TRANSFORM_GRID, 0)
		2:
			left_panel.show()
			right_panel.show()
			bottom_drawer_content.show()
			_show_editor_canvas()
			_select_verification(0)
		3:
			left_panel.hide()
			right_panel.hide()
			bottom_drawer_content.hide()
			set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
	_apply_responsive_layout()


func set_preview_view(index: int) -> void:
	preview_view = clampi(index, ArenaRuntimePreview.ViewMode.LOGIC, ArenaRuntimePreview.ViewMode.GAME)
	if preview_option != null and preview_option.selected != preview_view:
		preview_option.select(preview_view)
	TerrainStudioUiStateService.set_value("preview_view", preview_view)
	cancel_active_gesture()
	workspace_mode = WorkspaceMode.PREVIEW
	canvas.set_dynamic_construction_mode(false)
	canvas.hide()
	if dynamic_palette != null:
		dynamic_palette.hide()
	if dynamic_mode_button != null:
		dynamic_mode_button.set_pressed_no_signal(false)
	runtime_preview.show()
	runtime_preview.set_runtime_context(
		project_context.active_run if project_context != null else null
	)
	runtime_preview.set_view_mode(preview_view)
	runtime_preview.set_arena(arena)


func _simulate_runtime_surface(surface: int) -> void:
	if arena == null or runtime_preview == null:
		_set_status("Aucune arène disponible pour la simulation.", true)
		return
	var cell := _last_hovered_cell
	if not arena.is_in_bounds(cell) or arena.get_cell_definition(cell) == null:
		var playable := arena.playable_cells()
		cell = playable[0] if not playable.is_empty() else GridTransformService.INVALID_CELL
	if cell == GridTransformService.INVALID_CELL:
		_set_status("Aucune cellule praticable à simuler.", true)
		return
	if not runtime_preview.visible or runtime_preview.runtime_state == null \
			or runtime_preview.arena != arena:
		set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
		if not runtime_preview.rebuild_now():
			_set_status("La projection vers le jeu réel n'a pas pu être construite.", true)
			return
	if surface == CellSurfaceState.DynamicSurface.NONE:
		runtime_preview.clear_runtime_surface(cell)
		_set_status("Surface temporaire retirée en %s ; sol de base restauré." % cell)
		return
	var result := runtime_preview.update_runtime_surface(cell, surface)
	_set_status(
		"Surface %s simulée en %s sur la copie du jeu ; arène inchangée." % [
			CellSurfaceState.DynamicSurface.keys()[surface], cell,
		],
		 not result.get("handled", false)
	)


func _simulate_runtime_terrain_spell(resource_path: String) -> void:
	if not _ensure_runtime_terrain_preview():
		return
	var spell := load(resource_path) as Spell
	if spell == null or spell.terrain_effect == null:
		_set_status("Le sort de terrain est introuvable : %s" % resource_path, true)
		return
	var cell := _runtime_terrain_target_cell()
	if cell == GridTransformService.INVALID_CELL:
		_set_status("Aucune cellule praticable à simuler.", true)
		return
	var result := runtime_preview.simulate_terrain_spell(spell, cell)
	var trigger_name: String = str(
		TerrainEffectData.Trigger.keys()[spell.terrain_effect.trigger]
	)
	_set_status(
		(
			"%s · source %s (%s) · cible %s · zone %d · modifiées %d · "
			+ "surface %s/%s · durée %d · déclenchement %s · dégâts terrain %d · "
			+ "Arène inchangée."
		) % [
			spell.spell_name,
			str(result.get("source_name", "fixture")),
			str(result.get("source_contract", "explicit_fixture")),
			cell,
			(result.get("requested_cells", []) as Array).size(),
			(result.get("terrain_changed", []) as Array).size(),
			str(result.get("surface_id", &"none")),
			str(result.get("visual_terrain_id", &"")),
			int(result.get("duration", 0)),
			trigger_name,
			int(result.get("terrain_damage", 0)),
		],
		not bool(result.get("handled", false))
	)


func _simulate_runtime_water_fixture() -> void:
	var effect := load(TERRAIN_SIM_WATER) as TerrainEffectData
	if effect == null:
		_set_status("L’exemple d’eau réel est introuvable.", true)
		return
	var spell := Spell.new()
	spell.spell_id = &"studio_water_terrain_fixture"
	spell.spell_name = "Exemple d’eau (aucun sort de production)"
	spell.can_target_free_cell = true
	spell.aoe_shape = Spell.AoeShape.SINGLE
	spell.aoe_size = 0
	spell.terrain_effect = effect
	if not _ensure_runtime_terrain_preview():
		return
	var cell := _runtime_terrain_target_cell()
	var result := runtime_preview.simulate_terrain_spell(spell, cell)
	_set_status(
		"Eau temporaire · cible %s · durée %d issue de eau.tres · surface water/water · arène inchangée." % [
			cell, int(result.get("duration", 0)),
		],
		not bool(result.get("handled", false))
	)


func _advance_runtime_terrain_tick() -> void:
	if not _ensure_runtime_terrain_preview():
		return
	runtime_preview.advance_runtime_surface_tick()
	var active := runtime_preview.runtime_state.terrain_effects.runtime_service \
		.active_surface_cells()
	_set_status("Tour de terrain avancé · %d surface(s) active(s) dans le jeu." % active.size())


func _move_runtime_terrain_fixture() -> void:
	if not _ensure_runtime_terrain_preview():
		return
	var cell := _runtime_terrain_target_cell()
	var report := runtime_preview.simulate_fixture_enter_surface(cell)
	_set_status(
		"Exemple déplacé en %s · dégâts d'entrée reçus : %d." % [
			cell, int(report.get("damage_received", 0)),
		],
		not bool(report.get("handled", false))
	)


func _clear_runtime_terrain_surfaces() -> void:
	if not _ensure_runtime_terrain_preview():
		return
	runtime_preview.clear_all_runtime_surfaces()
	_set_status("Toutes les surfaces temporaires sont retirées ; sols de base restaurés.")


func _reset_runtime_terrain_simulation() -> void:
	if not _ensure_runtime_terrain_preview():
		return
	var rebuilt := runtime_preview.rebuild_now()
	_set_status(
		"Simulation terrain réinitialisée depuis la version en cours inchangée.",
		not rebuilt
	)


func _ensure_runtime_terrain_preview() -> bool:
	if arena == null or runtime_preview == null:
		_set_status("Aucune arène disponible pour la simulation.", true)
		return false
	if not runtime_preview.visible or runtime_preview.runtime_state == null \
			or runtime_preview.arena != arena:
		set_preview_view(ArenaRuntimePreview.ViewMode.GAME)
		if not runtime_preview.rebuild_now():
			_set_status("La projection vers le jeu réel n'a pas pu être construite.", true)
			return false
	return true


func _runtime_terrain_target_cell() -> Vector2i:
	var cell := _last_hovered_cell
	if arena != null and arena.is_in_bounds(cell) \
			and arena.get_cell_definition(cell) != null:
		return cell
	var playable := arena.playable_cells() if arena != null else []
	return playable[0] if not playable.is_empty() \
		else GridTransformService.INVALID_CELL


func show_dynamic_construction() -> void:
	if edit_session == null or arena == null:
		_set_status("Aucune arène active pour la construction dynamique.", true)
		return
	if workspace_mode == WorkspaceMode.DYNAMIC_CONSTRUCTION \
			and dynamic_mode_button != null and not dynamic_mode_button.button_pressed:
		_show_editor_canvas(false)
		_select_tool_and_preset(ArenaStudioCanvas.Tool.SELECT, 0)
		_set_status("Construction dynamique quittée — document et historique conservés.")
		return
	if arena.visual_mode == ArenaDefinition.VisualMode.PAINTED \
			and not _painted_logic_only_active:
		_show_editor_canvas(false)
		painted_dynamic_dialog.popup_centered()
		if dynamic_mode_button != null:
			dynamic_mode_button.set_pressed_no_signal(false)
		return
	_enter_dynamic_construction()


func _enter_dynamic_construction() -> void:
	cancel_active_gesture()
	workspace_mode = WorkspaceMode.DYNAMIC_CONSTRUCTION
	canvas.show()
	runtime_preview.hide()
	canvas.set_dynamic_construction_mode(true)
	canvas.set_painted_logic_only(_painted_logic_only_active)
	canvas.refresh_terrain_plan()
	if dynamic_palette != null:
		dynamic_palette.show()
	if dynamic_mode_button != null:
		dynamic_mode_button.set_pressed_no_signal(true)
	_refresh_dynamic_palette()
	_select_dynamic_tool(ArenaStudioCanvas.Tool.TERRAIN)
	_set_status(
		"Édition logique d'une carte peinte : le fond peint fait foi, les couleurs sont des repères." \
		if _painted_logic_only_active else
		"Construction dynamique — vraies dalles, même session d'édition et même historique."
	)


func _show_editor_canvas(preserve_dynamic_mode := false) -> void:
	if canvas == null:
		return
	canvas.show()
	if runtime_preview != null:
		runtime_preview.hide()
	if preview_option != null and preview_option.selected != ArenaRuntimePreview.ViewMode.LOGIC:
		preview_option.select(ArenaRuntimePreview.ViewMode.LOGIC)
	if not preserve_dynamic_mode:
		workspace_mode = WorkspaceMode.EDITOR
		canvas.set_dynamic_construction_mode(false)
		if dynamic_palette != null:
			dynamic_palette.hide()
		if dynamic_mode_button != null:
			dynamic_mode_button.set_pressed_no_signal(false)


func _select_dynamic_tool(tool: int) -> void:
	if workspace_mode != WorkspaceMode.DYNAMIC_CONSTRUCTION:
		show_dynamic_construction()
		return
	tool_list.select(tool)
	_on_tool_selected(tool)
	if tool == ArenaStudioCanvas.Tool.TERRAIN:
		canvas.set_brush_preview_terrain(
			_selected_enabled_terrain_id(dynamic_terrain_option)
		)


func _refresh_dynamic_palette() -> void:
	_refresh_permanent_terrain_options()
	if dynamic_document_label == null or arena == null:
		return
	var mode_name: String = VISUAL_MODE_LABELS[arena.visual_mode]
	dynamic_document_label.text = "%s • %d × %d • %s • %s" % [
		arena.display_name, arena.grid_size.x, arena.grid_size.y,
		mode_name,
		"non enregistrée" if dirty else "enregistrée",
	]
	var hybrid_policy := ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS
	if arena.modular_visual_profile != null:
		hybrid_policy = arena.modular_visual_profile.hybrid_floor_policy
	if dynamic_base_terrain_option != null:
		dynamic_base_terrain_option.visible = arena.visual_mode != ArenaDefinition.VisualMode.PAINTED
		var base_id := arena.modular_visual_profile.base_terrain_id \
			if arena.modular_visual_profile != null else &"stone"
		for index in range(dynamic_base_terrain_option.item_count):
			if StringName(dynamic_base_terrain_option.get_item_metadata(index)) == base_id:
				dynamic_base_terrain_option.select(index)
				break
	if hybrid_floor_policy_panel != null:
		hybrid_floor_policy_panel.visible = arena.visual_mode == ArenaDefinition.VisualMode.HYBRID
	if arena.visual_mode == ArenaDefinition.VisualMode.HYBRID:
		dynamic_document_label.text += "\nSol hybride : %s" % (
			_hybrid_floor_policy_display_name(hybrid_policy)
		)
		var policy_index := _hybrid_floor_policy_option_index(
			hybrid_floor_policy_option, hybrid_policy
		)
		if policy_index >= 0:
			hybrid_floor_policy_option.select(policy_index)
	if _painted_logic_only_active:
		dynamic_document_label.text += (
			"\nATTENTION : les dalles modulaires ne seront pas rendues ; "
			+ "le sol peint fait foi."
		)
	if dynamic_width_spin != null:
		dynamic_width_spin.set_value_no_signal(arena.grid_size.x)
	if dynamic_height_spin != null:
		dynamic_height_spin.set_value_no_signal(arena.grid_size.y)


func _refresh_permanent_terrain_options() -> void:
	var entries := ArenaPermanentTerrainPaintService \
		.get_paintable_permanent_terrains(arena, true)
	if floor_palette != null:
		floor_palette.set_entries(entries)
	for option_value in [terrain_option, dynamic_terrain_option]:
		var option := option_value as OptionButton
		if option == null:
			continue
		var preferred := _selected_terrain_id(option)
		option.clear()
		var preferred_index := -1
		var first_enabled := -1
		for entry in entries:
			var terrain_id := StringName(entry.stable_id)
			if terrain_id == &"stone":
				option.add_separator("SOLS SANS EFFET")
			elif terrain_id == &"water":
				option.add_separator("TERRAINS À EFFET")
			elif terrain_id == &"void":
				option.add_separator("TOPOLOGIE")
			var enabled := bool(entry.enabled)
			var state := "outil Retirer / clic droit" if terrain_id == &"void" \
				else (_terrain_palette_summary(terrain_id) if enabled else str(entry.reason))
			option.add_item("%s • %s • %s" % [
				entry.display_name, terrain_id, state,
			])
			var index := option.item_count - 1
			option.set_item_metadata(index, terrain_id)
			option.set_item_disabled(index, not enabled)
			option.set_item_tooltip(index, str(entry.reason))
			if enabled and first_enabled < 0:
				first_enabled = index
			if enabled and terrain_id == preferred:
				preferred_index = index
		var selected_index := preferred_index \
			if preferred_index >= 0 else first_enabled
		if selected_index < 0 and option.item_count > 0:
			selected_index = 0
		if selected_index >= 0:
			option.select(selected_index)
	if canvas != null:
		canvas.set_brush_preview_terrain(_selected_enabled_terrain_id(
			dynamic_terrain_option if workspace_mode == WorkspaceMode.DYNAMIC_CONSTRUCTION \
			else terrain_option
		))


func _terrain_palette_summary(terrain_id: StringName) -> String:
	return {
		&"stone": "praticable • aucun effet",
		&"neutral": "praticable • aucun effet",
		&"water": "praticable • applique Mouillé",
		&"ice": "praticable • applique Gelé",
		&"lava": "praticable • applique Brûlure",
		&"poison": "praticable • applique Poison",
		&"steam": "praticable • bloque la vision",
		&"electrified_water": "praticable • applique Mouillé et Choc",
	}.get(terrain_id, "praticable")


func _select_quick_terrain(terrain_id: StringName) -> void:
	var option := dynamic_terrain_option \
		if workspace_mode == WorkspaceMode.DYNAMIC_CONSTRUCTION else terrain_option
	if option == null:
		return
	for index in range(option.item_count):
		if StringName(option.get_item_metadata(index)) == terrain_id \
				and not option.is_item_disabled(index):
			option.select(index)
			break
	tool_list.select(ArenaStudioCanvas.Tool.TERRAIN)
	_on_tool_selected(ArenaStudioCanvas.Tool.TERRAIN)
	canvas.set_brush_preview_terrain(terrain_id)
	_recent_terrain_ids.erase(terrain_id)
	_recent_terrain_ids.push_front(terrain_id)
	while _recent_terrain_ids.size() > 3:
		_recent_terrain_ids.pop_back()
	if floor_palette != null:
		floor_palette.select_terrain(terrain_id)
	var definition := ArenaCatalogService.terrain(terrain_id)
	_set_status("Sol actif : %s — Alt+clic prélève le sol sous le curseur." % (
		definition.display_name if definition != null else str(terrain_id)
	))


func _on_terrain_pick_requested(cell: Vector2i) -> void:
	if arena == null:
		return
	var definition := arena.get_cell_definition(cell)
	if definition == null or definition.terrain_id == &"":
		_set_status("Aucun terrain prélevable sur cette cellule.", true)
		return
	_select_quick_terrain(definition.terrain_id)
	_set_status("Terrain prélevé en (%d, %d) : %s." % [cell.x, cell.y, definition.terrain_id])


func _selected_terrain_id(option: OptionButton) -> StringName:
	if option == null or option.selected < 0 or option.selected >= option.item_count:
		return &"stone"
	return StringName(str(option.get_item_metadata(option.selected)))


func _selected_enabled_terrain_id(option: OptionButton) -> StringName:
	if option == null or option.selected < 0 or option.selected >= option.item_count \
			or option.is_item_disabled(option.selected):
		return &""
	return StringName(str(option.get_item_metadata(option.selected)))


func _resize_dynamic_document() -> void:
	if arena == null or edit_session == null:
		return
	var before := arena.to_snapshot()
	var requested := Vector2i(int(dynamic_width_spin.value), int(dynamic_height_spin.value))
	if not ArenaDynamicEditingService.resize_document(arena, requested):
		return
	_commit_change("Redimensionner l'arène dynamique", before, arena.to_snapshot())
	canvas.set_arena(arena)
	_refresh_dynamic_palette()
	_refresh_all()


## Sous 1 180 px, l'inspecteur cesse d'occuper une colonne mais reste
## atteignable : un bouton permanent l'ouvre en tiroir par-dessus le canvas.
## Aucune action essentielle n'est masquee sans acces de remplacement.
func _apply_responsive_layout() -> void:
	if left_panel == null or right_panel == null:
		return
	if focus_map_enabled or workspace_preset == 3:
		left_panel.hide()
		right_panel.hide()
		bottom_drawer_content.hide()
		if inspector_drawer_button != null:
			inspector_drawer_button.visible = false
		if palette_scroll != null and focus_map_enabled:
			palette_scroll.visible = false
		# Un tiroir fermé ne doit pas continuer à réserver sa hauteur : sinon
		# le mode Focus rendrait moins de place à la carte qu'annoncé.
		_sync_drawer_split()
		return
	left_panel.custom_minimum_size.x = 196
	right_panel.custom_minimum_size.x = 300 if size.x >= 1500 else 280
	_compact_layout = size.x < 1180.0
	if _compact_layout:
		right_panel.visible = _inspector_forced_open
	else:
		_inspector_forced_open = false
		right_panel.show()
	if inspector_panel != null:
		inspector_panel.set_drawer_mode(_compact_layout)
	if inspector_drawer_button != null:
		inspector_drawer_button.visible = _compact_layout \
			and editor_screen != null and editor_screen.visible
		inspector_drawer_button.text = "Fermer l'inspecteur ◂" if _inspector_forced_open \
			else "Ouvrir l'inspecteur ▸"
	# Sur un écran court, la palette défile dans moins de place plutôt que de
	# repousser le canvas ou le tiroir hors de la fenêtre. Le tiroir reste
	# fermé par défaut, mais il n'est jamais refermé de force.
	if palette_scroll != null:
		palette_scroll.custom_minimum_size.y = 76.0 if size.y < 760.0 else 132.0
	# La barre historique du Studio duplique l'en-tête Terrain et le shell :
	# sur un écran court elle disparaît, sans qu'aucune action ne soit perdue
	# (Préparer, Enregistrer et Glossaire vivent aussi dans le parcours).
	if top_bar != null:
		top_bar.visible = _shell_toolbar_allowed and not guided and size.y >= 760.0


func get_workspace_state() -> Dictionary:
	return {
		"focus_map": focus_map_enabled,
		"preset": workspace_preset,
		"preview_view": preview_view,
		"guided": guided,
		"step": current_step,
		"guidance_visible": guidance_visible,
		"inspector_drawer_open": _inspector_forced_open,
		"home_visible": is_home_visible(),
		"workspace_mode": workspace_mode,
		"active_tool": canvas.active_tool if canvas != null else ArenaStudioCanvas.Tool.SELECT,
		"left_visible": left_panel.visible if left_panel != null else true,
		"right_visible": right_panel.visible if right_panel != null else true,
		"drawer_visible": bottom_drawer_content.visible \
			if bottom_drawer_content != null else false,
		"horizontal_split": horizontal_split.split_offset \
			if horizontal_split != null else 188,
		"right_split": center_and_right_split.split_offset \
			if center_and_right_split != null else -324,
		"drawer_split": vertical_split.split_offset if vertical_split != null else -42,
	}


func apply_workspace_state(state: Dictionary) -> void:
	if horizontal_split == null:
		return
	horizontal_split.split_offset = int(state.get("horizontal_split", 58))
	center_and_right_split.split_offset = int(state.get("right_split", -324))
	vertical_split.split_offset = int(state.get("drawer_split", -42))
	workspace_preset = clampi(int(state.get("preset", 0)), 0, 3)
	preview_view = clampi(int(state.get("preview_view", 0)), 0, 2)
	workspace_mode = clampi(
		int(state.get("workspace_mode", WorkspaceMode.EDITOR)),
		WorkspaceMode.EDITOR, WorkspaceMode.PREVIEW
	)
	left_panel.visible = bool(state.get("left_visible", true))
	right_panel.visible = bool(state.get("right_visible", true))
	bottom_drawer_content.visible = bool(state.get("drawer_visible", false))
	if bool(state.get("focus_map", false)):
		set_focus_map(true)
	var restored_tool := clampi(
		int(state.get("active_tool", ArenaStudioCanvas.Tool.SELECT)),
		ArenaStudioCanvas.Tool.SELECT, ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS
	)
	if workspace_mode == WorkspaceMode.DYNAMIC_CONSTRUCTION and edit_session != null:
		workspace_mode = WorkspaceMode.EDITOR
		show_dynamic_construction()
	else:
		tool_list.select(restored_tool)
		_on_tool_selected(restored_tool)
	set_guided(bool(state.get("guided", guided)))
	set_guidance_visible(bool(state.get("guidance_visible", guidance_visible)))
	set_current_step(int(state.get("step", current_step)))
	_inspector_forced_open = bool(state.get("inspector_drawer_open", false))
	if bool(state.get("home_visible", false)):
		show_home()
	_apply_responsive_layout()


func canvas_occupation_ratio() -> Vector2:
	if view_stack == null or size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(view_stack.size.x / size.x, view_stack.size.y / size.y)
