@tool
class_name ArenaStudioMain
extends Control

signal history_state_changed

const TEST_RUNNER_SCENE := "res://addons/dungeon_draft_arena_studio/test/arena_studio_test_runner.tscn"
const TEST_REQUEST := "user://arena_studio/test_request.json"
const TEST_WORK_ROOT := "user://dungeon_draft_studio/arena_studio/tests"
const TOOL_LABELS := [
	"Selection", "Deplacement de vue", "Ajouter une case", "Retirer une case",
	"Bordure", "Obstacle", "Terrain", "Spawn", "Verification",
	"Transformer la grille",
	"Ancres de calibration",
]
const PRODUCTION_LIBRARY := [
	["Foret — Gue forestier", &"room_01_forest"],
	["Volcan — Caldeira", &"room_05_volcano"],
	["Espace — Station orbitale", &"room_06_space"],
]
const TEST_CONFIGURATIONS := [
	["Sans personnages", &"no_characters"],
	["Trio de heros", &"hero_trio"],
	["Rencontre reelle", &"real_encounter"],
	["Test des clics", &"clicks"],
	["Test des spawns", &"spawns"],
	["Test de l'occlusion", &"occlusion"],
	["Deplacement", &"movement"],
	["Vue", &"view"],
	["Ligne de vue", &"line_of_sight"],
	["Obstacles", &"obstacles"],
	["Terrains", &"terrains"],
	["Spawns", &"spawns"],
	["Y-sort / occlusion", &"y_sort"],
	["Partie complete", &"full_run"],
]

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
var dynamic_lab: DynamicArenaLab
var dynamic_lab_container: SubViewportContainer
var dynamic_lab_viewport: SubViewport
var title_label: Label
var status_label: Label
var mode_option: OptionButton
var library_list: ItemList
var tool_list: ItemList
var shape_option: OptionButton
var obstacle_option: OptionButton
var terrain_option: OptionButton
var spawn_option: OptionButton
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
var _pending_restore_delete_path := ""
var layer_controls := {}
var transform_controls := {}
var new_dialog: ConfirmationDialog
var new_name_edit: LineEdit
var new_id_edit: LineEdit
var new_image_edit: LineEdit
var new_width_spin: SpinBox
var new_height_spin: SpinBox
var new_orientation_option: OptionButton
var new_template_option: OptionButton
var image_dialog: FileDialog
var open_dialog: FileDialog
var production_dialog: ConfirmationDialog
var production_tabs: TabContainer
var production_name_edit: LineEdit
var production_id_edit: LineEdit
var production_theme_edit: LineEdit
var production_mode_option: OptionButton
var production_destination_edit: LineEdit
var production_validation_text: RichTextLabel
var production_preview_text: RichTextLabel
var production_plan_text: RichTextLabel
var production_result_text: RichTextLabel
var migration_dialog: ConfirmationDialog
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
var _pre_focus_state := {}

var _fallback_undo := UndoRedo.new()
var _sessions: Dictionary = {}
var _stroke_before := {}
var _stroke_changed := false
var _stroke_cell_count := 0
var _verification_source := GridTransformService.INVALID_CELL
var _last_test_log := "Aucun test direct lance depuis cette session."
var _recovery_timer: Timer
var _transfer_poll_timer: Timer
var _announced_transfer_id := ""


func setup(host_editor_interface, undo_manager) -> void:
	editor_interface = host_editor_interface
	editor_undo_redo = undo_manager


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
	ensure_initial_arena_loaded()
	call_deferred("_poll_lab_transfers")


func ensure_initial_arena_loaded() -> void:
	if arena != null:
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
		_set_status("Session de map reprise avec son historique.")
		return true
	var imported := ArenaLegacyImporter.import_production(arena_id)
	if imported == null:
		_set_status("Impossible d'ouvrir la map de production demandee.", true)
		return false
	_set_arena(imported, false, session_key)
	_set_status("Map de production ouverte sans modifier ses ressources sources.")
	return true


func _build_interface() -> void:
	root_container = VBoxContainer.new()
	root_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_container.add_theme_constant_override("separation", 4)
	add_child(root_container)
	top_bar = _build_top_bar()
	root_container.add_child(top_bar)

	vertical_split = VSplitContainer.new()
	vertical_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vertical_split.split_offset = -42
	root_container.add_child(vertical_split)

	horizontal_split = HSplitContainer.new()
	horizontal_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_split.split_offset = 58
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

	status_label = Label.new()
	status_label.text = "Initialisation d'Arena Studio..."
	status_label.custom_minimum_size.y = 28
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.76, 0.86, 0.94))
	root_container.add_child(status_label)
	resized.connect(_apply_responsive_layout)
	call_deferred("_apply_responsive_layout")


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 42
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	panel.add_child(bar)
	title_label = Label.new()
	title_label.text = "DUNGEON DRAFT ARENA STUDIO"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.52, 0.88, 1.0))
	title_label.custom_minimum_size.x = 260
	bar.add_child(title_label)
	var new_button := _add_button(bar, "+ Nouvelle", _show_new_dialog)
	new_button.tooltip_text = "Créer une nouvelle arène"
	_add_button(bar, "Ouvrir", _show_open_dialog)
	_add_button(bar, "Sauvegarder", save_arena)
	var prepare_button := _add_button(bar, "Préparer", prepare_automatically)
	prepare_button.tooltip_text = "Préparer automatiquement la map"
	_add_button(bar, "Valider", validate_arena)
	var test_button := _add_button(bar, "▶ Tester", test_arena)
	test_button.tooltip_text = "Tester la working copy dans la vraie scène"
	mode_option = OptionButton.new()
	mode_option.tooltip_text = "Creation masque les informations techniques."
	for label in ["Création", "Vérification", "Avancé"]:
		mode_option.add_item(label)
	mode_option.item_selected.connect(_on_mode_selected)
	bar.add_child(mode_option)
	return panel


func _build_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 56
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 54
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	dynamic_mode_button = Button.new()
	dynamic_mode_button.text = "DYN"
	dynamic_mode_button.tooltip_text = "Construction dynamique — outils du Dynamic Arena Lab"
	dynamic_mode_button.custom_minimum_size = Vector2(52, 42)
	dynamic_mode_button.pressed.connect(show_dynamic_construction)
	box.add_child(dynamic_mode_button)
	library_list = ItemList.new()
	for entry in PRODUCTION_LIBRARY:
		library_list.add_item(entry[0])
	library_list.item_activated.connect(_on_library_activated)
	tool_list = ItemList.new()
	tool_list.custom_minimum_size = Vector2(54, 440)
	tool_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tool_list.fixed_column_width = 50
	tool_list.same_column_width = true
	var compact_labels := ["SEL", "PAN", "+CASE", "-CASE", "BORD", "MUR", "SOL", "SPAWN", "CHECK", "GRILLE", "ANCRE"]
	for index in range(TOOL_LABELS.size()):
		tool_list.add_item(compact_labels[index])
		tool_list.set_item_tooltip(index, "%s — raccourci %d" % [TOOL_LABELS[index], index + 1])
	tool_list.select(ArenaStudioCanvas.Tool.SELECT)
	tool_list.item_selected.connect(_on_tool_selected)
	box.add_child(tool_list)
	shape_option = OptionButton.new()
	for label in ["Pinceau continu", "Rectangle", "Remplissage contigu", "Selection multiple"]:
		shape_option.add_item(label)
	shape_option.item_selected.connect(func(index): canvas.brush_shape = index)
	obstacle_option = OptionButton.new()
	for label in ["Mur complet", "Obstacle bas", "Decor traversable", "Falaise"]:
		obstacle_option.add_item(label)
	terrain_option = OptionButton.new()
	for label in ["Normal", "Mur", "Trou", "Lave", "Glace", "Ombre", "Rune"]:
		terrain_option.add_item(label)
	spawn_option = OptionButton.new()
	for label in ["Heros 1 — Elfe", "Heros 2 — Mage", "Heros 3 — Guerrier", "Ennemi", "Groupe ennemi", "Zone d'invocation"]:
		spawn_option.add_item(label)
	verification_option = OptionButton.new()
	verification_option.add_item("Verifier les deplacements")
	verification_option.add_item("Tester une ligne de vue")
	verification_option.item_selected.connect(_on_verification_kind_selected)
	test_configuration_option = OptionButton.new()
	for configuration in TEST_CONFIGURATIONS:
		test_configuration_option.add_item(configuration[0])
	return panel


func _build_canvas_panel() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var navigation := HBoxContainer.new()
	canvas_navigation = navigation
	_add_button(navigation, "Recentrer", func(): canvas.recenter_grid())
	_add_button(navigation, "Adapter a l'image", func(): canvas.fit_to_image())
	_add_button(navigation, "Calibration en 3 clics", start_calibration)
	var hint := Label.new()
	hint.text = "Molette : zoom • Clic milieu : deplacer"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	navigation.add_child(hint)
	box.add_child(navigation)
	view_stack = Control.new()
	view_stack.name = "ViewStack"
	view_stack.custom_minimum_size = Vector2(640, 420)
	view_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(view_stack)
	canvas = ArenaStudioCanvas.new()
	canvas.custom_minimum_size = Vector2(640, 420)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_stack.add_child(canvas)
	runtime_preview = ArenaRuntimePreview.new()
	runtime_preview.name = "ArenaRuntimePreview"
	runtime_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	runtime_preview.hide()
	view_stack.add_child(runtime_preview)
	dynamic_lab_container = SubViewportContainer.new()
	dynamic_lab_container.name = "DynamicLabContainer"
	dynamic_lab_container.stretch = true
	dynamic_lab_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dynamic_lab_container.hide()
	view_stack.add_child(dynamic_lab_container)
	dynamic_lab_viewport = SubViewport.new()
	dynamic_lab_viewport.name = "DynamicLabViewport"
	dynamic_lab_viewport.size = Vector2i(1280, 720)
	dynamic_lab_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	dynamic_lab_container.add_child(dynamic_lab_viewport)
	var lab_scene := load("res://tools/labs/dynamic_arena/DynamicArenaLab.tscn") as PackedScene
	if lab_scene != null:
		dynamic_lab = lab_scene.instantiate() as DynamicArenaLab
		dynamic_lab.name = "IntegratedDynamicArenaLab"
		dynamic_lab.document_changed.connect(_on_dynamic_lab_document_changed)
		dynamic_lab_viewport.add_child(dynamic_lab)
	return box


func _build_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 295
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 0
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(_section_label("Document et contexte"))
	library_list.custom_minimum_size.y = 78
	box.add_child(library_list)
	box.add_child(_section_label("Pinceau et propriete active"))
	box.add_child(shape_option)
	box.add_child(obstacle_option)
	box.add_child(terrain_option)
	box.add_child(spawn_option)
	box.add_child(verification_option)
	box.add_child(_section_label("Test direct"))
	box.add_child(test_configuration_option)
	box.add_child(_section_label("Inspecteur contextuel"))
	inspector_label = Label.new()
	inspector_label.text = "Survolez une case."
	inspector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_label.custom_minimum_size = Vector2(0, 78)
	inspector_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(inspector_label)
	calibration_label = Label.new()
	calibration_label.text = "Alignement a verifier"
	calibration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	calibration_label.custom_minimum_size.y = 40
	calibration_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28))
	box.add_child(calibration_label)
	box.add_child(_build_transform_panel())
	box.add_child(_build_layers_panel())
	box.add_child(_section_label("Actions"))
	_add_button(box, "Preparer automatiquement la map", prepare_automatically)
	_add_button(box, "Placer les heros", func(): _select_tool_and_preset(ArenaStudioCanvas.Tool.SPAWN, 0))
	_add_button(box, "Placer les ennemis", func(): _select_tool_and_preset(ArenaStudioCanvas.Tool.SPAWN, 4))
	_add_button(box, "Verifier les deplacements", func(): _select_verification(0))
	_add_button(box, "Tester une ligne de vue", func(): _select_verification(1))
	_add_button(box, "Exporter le rapport", export_report)
	_add_button(box, "Copier le rapport pour Codex", copy_report_for_codex)
	recovery_button = _add_button(box, "Restaurer le recovery", restore_latest_recovery)
	recovery_button.tooltip_text = "Restaurer la sauvegarde automatique de récupération"
	box.add_child(_build_restore_points_panel())
	advanced_panel = VBoxContainer.new()
	advanced_panel.add_child(_section_label("Informations techniques"))
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
	box.add_child(advanced_panel)
	advanced_panel.visible = false
	return panel


func _build_transform_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_child(_section_label("Transformation de la grille"))
	var transform_button := Button.new()
	transform_button.text = "Transformer la grille"
	transform_button.tooltip_text = "Selectionne la calibration sans rendre le fond deplacable."
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
	preserve.text = "Longueur des axes"
	preserve.toggled.connect(func(value): canvas.preserve_axis_length = value)
	flags.add_child(preserve)
	transform_controls["preserve_axis_length"] = preserve
	var preserve_angle := CheckButton.new()
	preserve_angle.text = "Angle des axes"
	preserve_angle.toggled.connect(func(value): canvas.preserve_axis_angle = value)
	flags.add_child(preserve_angle)
	transform_controls["preserve_axis_angle"] = preserve_angle
	var symmetry := CheckButton.new()
	symmetry.text = "Symetrie isometrique"
	symmetry.toggled.connect(func(value): canvas.mirror_axes = value)
	flags.add_child(symmetry)
	transform_controls["mirror_axes"] = symmetry
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
		["Verrouiller axe droit", "lock_axis_x"],
		["Verrouiller axe gauche", "lock_axis_y"],
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
		["Echelle 0.5 %", 0.005, 0.001, 0.25, 0.001, "scale_snap"],
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
	compare_button = CheckButton.new()
	compare_button.text = "Comparer à la sauvegarde"
	compare_button.toggled.connect(func(value):
		canvas.show_saved_comparison = value
		canvas.queue_redraw()
	)
	box.add_child(compare_button)
	last_operation_label = Label.new()
	last_operation_label.text = "Derniere operation : aucune"
	last_operation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	last_operation_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.94))
	box.add_child(last_operation_label)
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
	background_opacity.tooltip_text = "Opacite du fond (preference d'editeur)"
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
	grid_opacity.tooltip_text = "Opacite de la grille (preference d'editeur)"
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
	_add_button(buttons, "Creer", create_restore_point)
	_add_button(buttons, "Restaurer", restore_selected_point)
	_add_button(buttons, "Renommer", rename_selected_restore_point)
	_add_button(buttons, "Supprimer", delete_selected_restore_point)
	box.add_child(buttons)
	restore_points_list = ItemList.new()
	restore_points_list.custom_minimum_size.y = 72
	box.add_child(restore_points_list)
	var reset_menu := MenuButton.new()
	reset_menu.text = "Reinitialiser ▾"
	for definition in [
		["Restaurer la calibration sauvegardee", 0],
		["Reinitialiser seulement la position", 1],
		["Reinitialiser seulement les axes", 2],
		["Reinitialiser la rotation vers la sauvegarde", 3],
	]:
		reset_menu.get_popup().add_item(definition[0], definition[1])
	reset_menu.get_popup().id_pressed.connect(_on_reset_requested)
	box.add_child(reset_menu)
	return box


func _build_validation_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 148
	var box := VBoxContainer.new()
	panel.add_child(box)
	validation_title = Label.new()
	validation_title.text = "Validation — cliquez un message pour localiser le probleme"
	validation_title.add_theme_font_size_override("font_size", 15)
	box.add_child(validation_title)
	validation_list = ItemList.new()
	validation_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	validation_list.item_selected.connect(_on_validation_item_selected)
	box.add_child(validation_list)
	return panel


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
	tabs.custom_minimum_size.y = 180
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
	report.text = "Validez ou produisez la salle pour generer un rapport."
	tabs.add_child(report)
	var console := RichTextLabel.new()
	console.name = "Console de test"
	console.text = _last_test_log
	tabs.add_child(console)
	var analysis := RichTextLabel.new()
	analysis.name = "Analyse"
	analysis.text = "Pathfinding, LOS et parite preview/runtime."
	tabs.add_child(analysis)
	tabs.hide()
	return drawer


func _build_dialogs() -> void:
	new_dialog = ConfirmationDialog.new()
	new_dialog.title = "Nouvelle arene — informations et point de depart"
	new_dialog.size = Vector2i(720, 590)
	new_dialog.ok_button_text = "Continuer vers la calibration"
	new_dialog.confirmed.connect(_create_from_wizard)
	add_child(new_dialog)
	var wizard := VBoxContainer.new()
	new_dialog.add_child(wizard)
	wizard.add_child(_section_label("Etape 1 — Informations"))
	new_name_edit = _labeled_line(wizard, "Nom visible", "Nouvelle arene")
	new_id_edit = _labeled_line(wizard, "Identifiant propose", "nouvelle_arene")
	new_name_edit.text_changed.connect(func(value):
		new_id_edit.text = ArenaDefinition.sanitize_id(value)
	)
	new_image_edit = _labeled_line(wizard, "Image de fond", "")
	_add_button(wizard, "Choisir ou importer une image...", _show_image_dialog)
	var dimensions := HBoxContainer.new()
	wizard.add_child(dimensions)
	new_width_spin = _spin(dimensions, "Largeur", 10, 1, 256)
	new_height_spin = _spin(dimensions, "Hauteur", 8, 1, 256)
	new_orientation_option = OptionButton.new()
	for label in ["Heros en bas a gauche", "Heros en bas a droite", "Heros en haut a gauche", "Heros en haut a droite"]:
		new_orientation_option.add_item(label)
	wizard.add_child(new_orientation_option)
	wizard.add_child(_section_label("Etape 2 — Point de depart"))
	new_template_option = OptionButton.new()
	for label in ["Partir d'une map vide", "Copier la calibration de la foret", "Copier la calibration du volcan", "Copier la calibration de l'espace"]:
		new_template_option.add_item(label)
	wizard.add_child(new_template_option)
	var step3 := Label.new()
	step3.text = "Etape 3 — Trois clics sur l'image\n1. Case de reference  2. Voisine bas-droite  3. Voisine bas-gauche"
	step3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wizard.add_child(step3)

	image_dialog = FileDialog.new()
	image_dialog.title = "Choisir l'image peinte"
	image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	image_dialog.size = Vector2i(960, 680)
	image_dialog.file_selected.connect(func(path): new_image_edit.text = path)
	add_child(image_dialog)

	open_dialog = FileDialog.new()
	open_dialog.title = "Ouvrir une ArenaDefinition"
	open_dialog.access = FileDialog.ACCESS_RESOURCES
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.filters = PackedStringArray(["*.tres ; Arena Studio"])
	open_dialog.current_dir = ArenaSerializer.CANONICAL_ROOT
	open_dialog.file_selected.connect(_open_canonical)
	add_child(open_dialog)

	restore_delete_dialog = ConfirmationDialog.new()
	restore_delete_dialog.title = "Supprimer le point de restauration"
	restore_delete_dialog.dialog_text = (
		"Ce point sera supprime de user://. La map et son historique ne seront pas modifies."
	)
	restore_delete_dialog.ok_button_text = "Supprimer"
	restore_delete_dialog.confirmed.connect(_confirm_delete_restore_point)
	add_child(restore_delete_dialog)

	_build_production_dialog()
	_build_migration_dialog()


func _build_production_dialog() -> void:
	production_dialog = ConfirmationDialog.new()
	production_dialog.title = "PRODUIRE LA SALLE — assistant déterministe"
	production_dialog.size = Vector2i(920, 680)
	production_dialog.ok_button_text = "Produire maintenant"
	production_dialog.cancel_button_text = "Annuler"
	production_dialog.confirmed.connect(_production_confirmed)
	add_child(production_dialog)
	production_tabs = TabContainer.new()
	production_tabs.custom_minimum_size = Vector2(880, 570)
	production_dialog.add_child(production_tabs)
	var identity := VBoxContainer.new()
	identity.name = "1 — Identité"
	production_tabs.add_child(identity)
	identity.add_child(_section_label("ÉTAPE 1 — IDENTITÉ"))
	production_name_edit = _labeled_line(identity, "Nom", "Nom visible")
	production_id_edit = _labeled_line(identity, "Identifiant", "identifiant_stable")
	production_theme_edit = _labeled_line(identity, "Biome / thème", "dynamic_default")
	production_mode_option = OptionButton.new()
	for label in ["PAINTED", "MODULAR", "HYBRID"]:
		production_mode_option.add_item(label)
	identity.add_child(Label.new())
	(identity.get_child(identity.get_child_count() - 1) as Label).text = "Mode visuel"
	identity.add_child(production_mode_option)
	production_destination_edit = _labeled_line(
		identity, "Chemin de destination", ArenaProductionService.DEFAULT_ROOT
	)
	var identity_note := Label.new()
	identity_note.text = "Aucun fichier n'est écrit avant le clic « Produire maintenant »."
	identity_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(identity_note)
	var validation_tab := VBoxContainer.new()
	validation_tab.name = "2 — Validation"
	production_tabs.add_child(validation_tab)
	validation_tab.add_child(_section_label("ÉTAPE 2 — VALIDATION"))
	production_validation_text = _production_text()
	validation_tab.add_child(production_validation_text)
	var preview_tab := VBoxContainer.new()
	preview_tab.name = "3 — Aperçu"
	production_tabs.add_child(preview_tab)
	preview_tab.add_child(_section_label("ÉTAPE 3 — APERÇU RUNTIME"))
	production_preview_text = _production_text()
	preview_tab.add_child(production_preview_text)
	var preview_buttons := HBoxContainer.new()
	preview_tab.add_child(preview_buttons)
	_add_button(preview_buttons, "Logique", func(): set_preview_view(ArenaRuntimePreview.ViewMode.LOGIC))
	_add_button(preview_buttons, "Art", func(): set_preview_view(ArenaRuntimePreview.ViewMode.ART))
	_add_button(preview_buttons, "Jeu", func(): set_preview_view(ArenaRuntimePreview.ViewMode.GAME))
	_add_button(preview_buttons, "Exporter le kit artistique", _export_art_kit_from_wizard)
	var plan_tab := VBoxContainer.new()
	plan_tab.name = "4 — Production"
	production_tabs.add_child(plan_tab)
	plan_tab.add_child(_section_label("ÉTAPE 4 — FICHIERS ET CONFLITS"))
	production_plan_text = _production_text()
	plan_tab.add_child(production_plan_text)
	var refresh_button := _add_button(plan_tab, "Recalculer le plan", _refresh_production_wizard)
	refresh_button.tooltip_text = "Lecture seule : recalcule créations, modifications et conflits."
	var result_tab := VBoxContainer.new()
	result_tab.name = "5 — Résultat"
	production_tabs.add_child(result_tab)
	result_tab.add_child(_section_label("ÉTAPE 5 — RÉSULTAT"))
	production_result_text = _production_text()
	result_tab.add_child(production_result_text)


func _production_text() -> RichTextLabel:
	var value := RichTextLabel.new()
	value.bbcode_enabled = true
	value.fit_content = false
	value.scroll_active = true
	value.size_flags_vertical = Control.SIZE_EXPAND_FILL
	value.custom_minimum_size.y = 410
	return value


func _build_migration_dialog() -> void:
	migration_dialog = ConfirmationDialog.new()
	migration_dialog.title = "Migration ArenaDefinition requise"
	migration_dialog.dialog_text = (
		"Ce document utilise un ancien schéma.\n\n"
		+ "Migrer crée une working copy v2 et une action annulable. "
		+ "Ouvrir en lecture seule conserve exactement les données anciennes."
	)
	migration_dialog.ok_button_text = "Migrer la working copy"
	migration_dialog.cancel_button_text = "Annuler"
	migration_dialog.add_button("Ouvrir en lecture seule", false, "read_only")
	migration_dialog.confirmed.connect(_confirm_pending_migration)
	migration_dialog.custom_action.connect(func(action):
		if action == "read_only":
			_open_pending_migration_read_only()
	)
	add_child(migration_dialog)


func _connect_canvas() -> void:
	canvas.stroke_started.connect(_on_stroke_started)
	canvas.cells_edit_requested.connect(_on_cells_edit_requested)
	canvas.stroke_finished.connect(_on_stroke_finished)
	canvas.stroke_cancelled.connect(_on_stroke_cancelled)
	canvas.calibration_requested.connect(_on_calibration_requested)
	canvas.calibration_preview_requested.connect(_on_calibration_preview)
	canvas.anchors_preview_requested.connect(_on_anchors_preview)
	canvas.hovered_cell_changed.connect(_on_hovered_cell_changed)
	canvas.verification_cell_requested.connect(_on_verification_cell_requested)


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
		_set_status("La copie de travail de l'arene n'a pas pu etre creee.", true)
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
	_fallback_undo = edit_session.history.undo_redo
	edit_session.history.history_changed.connect(_on_history_changed)
	edit_session.history.dirty_state_changed.connect(_on_dirty_state_changed)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	canvas.set_arena(arena)
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
	if dynamic_lab != null:
		dynamic_lab.bind_session(edit_session, true)
	if runtime_preview != null:
		runtime_preview.set_arena(arena)
	history_state_changed.emit()


func _show_new_dialog() -> void:
	new_name_edit.text = "Nouvelle arene"
	new_id_edit.text = "nouvelle_arene"
	new_image_edit.text = ""
	new_dialog.popup_centered()


func _show_image_dialog() -> void:
	image_dialog.popup_centered()


func _show_open_dialog() -> void:
	open_dialog.popup_centered()


func _create_from_wizard() -> void:
	var requested_id := ArenaDefinition.sanitize_id(new_id_edit.text)
	var created: ArenaDefinition
	if new_template_option.selected > 0:
		var template_id: StringName = PRODUCTION_LIBRARY[new_template_option.selected - 1][1]
		var template := ArenaLegacyImporter.import_production(template_id)
		created = ArenaLegacyImporter.copy_template(template, new_name_edit.text)
		created.arena_id = StringName(requested_id)
	else:
		created = ArenaDefinition.new()
		created.set_identity(new_name_edit.text, requested_id)
		created.grid_size = Vector2i(int(new_width_spin.value), int(new_height_spin.value))
	created.camp_orientation = new_orientation_option.selected
	if not new_image_edit.text.strip_edges().is_empty():
		var imported_path := _import_image(new_image_edit.text, requested_id)
		if imported_path.is_empty():
			_set_status("L'image n'a pas pu etre importee dans le projet.", true)
			return
		created.background_path = imported_path
		var texture := load(imported_path) as Texture2D
		if texture != null:
			created.source_image_size = Vector2i(texture.get_size())
	_set_arena(created, true, "new:%s:%d" % [requested_id, Time.get_ticks_usec()])
	start_calibration()
	_autosave()
	_set_status("Cliquez trois centres de cases pour aligner la grille.")


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
		_set_status("Session reprise : %s" % arena.display_name)
		return
	var loaded := ArenaSerializer.load_canonical(path)
	if loaded == null:
		_set_status("Cette ressource n'est pas une arene Arena Studio valide.", true)
		return
	if loaded.schema_version < ArenaDefinition.CURRENT_SCHEMA_VERSION:
		_prompt_migration(loaded, path)
		return
	_set_arena(loaded, false, path)
	_set_status("Arene ouverte : %s" % loaded.display_name)


func import_latest_lab_transfer() -> bool:
	var transfers := ArenaLabTransferService.pending_transfers()
	if transfers.is_empty():
		_set_status("Aucun nouveau transfert Lab ; ouverture du Lab intégré.")
		return false
	var transfer_id := str(transfers[0].get("transfer_id", ""))
	var loaded := ArenaLabTransferService.load_transfer(transfer_id)
	if not bool(loaded.get("ok", false)):
		_set_status("Transfert Lab corrompu : %s" % loaded.get("error", "erreur"), true)
		return true
	var transferred := loaded.arena as ArenaDefinition
	if transferred == null:
		_set_status("Le transfert Lab ne contient aucune ArenaDefinition.", true)
		return true
	if transferred.schema_version < ArenaDefinition.CURRENT_SCHEMA_VERSION:
		_pending_migration_transfer_id = transfer_id
		_prompt_migration(transferred, "lab_transfer:%s" % transfer_id)
		return true
	_set_arena(transferred, true, "lab_transfer:%s" % transfer_id)
	ArenaLabTransferService.mark_imported(transfer_id)
	_set_status(
		"Transfert Lab importé et vérifié : %s (%d × %d)." % [
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
		"Transfert Dynamic Arena Lab détecté : cliquez sur « Lab » pour l'importer."
	)


func _prompt_migration(value: ArenaDefinition, key: String) -> void:
	_pending_migration_arena = value
	_pending_migration_key = key
	if migration_dialog != null:
		migration_dialog.dialog_text = (
			"Le document '%s' utilise le schéma v%d.\n\n"
			+ "Migrer crée une working copy v%d et une action annulable. "
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
		"Migrer ArenaDefinition v%d vers v%d" % [result.from_version, result.to_version],
		before, arena.to_snapshot()
	)
	canvas.set_arena(arena)
	_refresh_all()
	if not _pending_migration_transfer_id.is_empty():
		ArenaLabTransferService.mark_imported(_pending_migration_transfer_id)
	_set_status("Migration v2 appliquée à la working copy ; la source reste inchangée.")
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


func save_arena() -> void:
	if arena == null or edit_session == null:
		return
	var report := validate_arena()
	if not report.is_valid():
		_set_status("Sauvegarde refusee : corrigez les erreurs de validation.", true)
		return
	if edit_session.has_external_conflict():
		_set_status("La ressource a change sur disque. Rechargez ou resolvez le conflit avant de sauvegarder.", true)
		return
	var writes_production_visual := edit_session.source_is_visual \
		and not arena.source_visual_path.is_empty()
	var path := arena.source_visual_path if writes_production_visual else (
		edit_session.source_path \
		if edit_session.source_path.begins_with("res://data/arenas/") \
		else ArenaSerializer.suggested_path(arena)
	)
	if not writes_production_visual and edit_session.source_path.is_empty() \
			and ResourceLoader.exists(path):
		_set_status(
			"Sauvegarde refusee : une map canonique utilise deja cet identifiant.", true
		)
		return
	var recovery_error := ArenaSerializer.save_recovery(arena)
	if recovery_error != OK:
		_set_status(
			"Sauvegarde refusee : la copie de recuperation n'a pas pu etre creee.",
			true
		)
		return
	var error := ArenaSerializer.save_production_calibration(arena, path) \
		if writes_production_visual else ArenaSerializer.save_canonical(arena, path)
	if error == OK:
		var verified_ok := ArenaSerializer.production_visual_matches(arena, path) \
			if writes_production_visual else false
		if not writes_production_visual:
			var verified := ResourceLoader.load(
				path, "", ResourceLoader.CACHE_MODE_IGNORE
			) as ArenaDefinition
			verified_ok = verified != null \
				and ArenaEditSession.fingerprint(verified.to_snapshot()) \
				== ArenaEditSession.fingerprint(arena.to_snapshot())
		if not verified_ok:
			_set_status("La verification apres sauvegarde a echoue.", true)
			return
		edit_session.mark_saved(path)
		ArenaSerializer.remove_recovery(arena.arena_id)
		canvas.set_saved_transform(edit_session.saved_transform())
		_refresh_title()
		_refresh_recovery_button()
		_set_status("Map sauvegardee sans reecrire sa topologie : %s" % path)
	else:
		_set_status("La map n'a pas pu etre sauvegardee : %s" % error_string(error), true)


func prepare_automatically() -> void:
	if arena == null:
		return
	var before := arena.to_snapshot()
	var result := ArenaEditingService.prepare_automatically(arena)
	_commit_change("Preparer automatiquement la map", before, arena.to_snapshot())
	_refresh_all()
	_set_status(
		"Preparation terminee — %d cases jouables, %d bordures, %d cases accessibles. Verifiez les spawns proposes." % [
			result.get("playable", 0), result.get("border", 0), result.get("connected", 0),
		]
	)


func create_safety_border() -> void:
	if arena == null:
		return
	var before := arena.to_snapshot()
	var count := ArenaEditingService.apply_safety_border(arena, arena.border_thickness)
	_commit_change("Creer la bordure de securite", before, arena.to_snapshot())
	_refresh_all()
	_set_status("Bordure de securite creee : %d cases conservees visuellement et exclues du gameplay." % count)


func start_calibration() -> void:
	if arena == null or arena.background_path.is_empty():
		_set_status("Ajoutez d'abord une image de fond.", true)
		return
	canvas.begin_three_click_calibration()
	_set_status("Calibration : cliquez la reference, puis ses voisines bas-droite et bas-gauche.")


func fit_multipoint_calibration() -> void:
	if arena == null:
		return
	var old_rms := arena.painted_map_visual_data.calibration_rms() \
		if arena.painted_map_visual_data != null else INF
	var old_max := arena.painted_map_visual_data.calibration_max_error() \
		if arena.painted_map_visual_data != null else INF
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
		"Ajuster la grille a %d ancres" % arena.calibration_cells.size(),
		before, arena.to_snapshot()
	)
	_refresh_all()
	_set_status(
		"Ajustement applique : RMS %.2f -> %.2f px, erreur max %.2f -> %.2f px." % [
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
		"Map prete" if validation_report.is_valid() else "Map a corriger",
		validation_report.error_count(), validation_report.warning_count(),
	]
	_set_status(
		"Map prete." if validation_report.is_valid() \
		else "La map ne peut pas etre testee : corrigez les erreurs affichees.",
		not validation_report.is_valid()
	)
	return validation_report


func show_production_wizard() -> void:
	if arena == null or production_dialog == null:
		_set_status("Aucune ArenaDefinition n'est ouverte.", true)
		return
	production_name_edit.text = arena.display_name
	production_id_edit.text = str(arena.arena_id)
	production_theme_edit.text = str(arena.theme_id)
	production_mode_option.select(arena.visual_mode)
	production_destination_edit.text = ArenaProductionService.suggested_destination(arena)
	production_result_text.text = "[b]EN ATTENTE[/b]\n\nLa production n'a pas encore été confirmée."
	production_dialog.get_ok_button().show()
	production_tabs.current_tab = 0
	_refresh_production_wizard()
	production_dialog.popup_centered()


func _production_candidate() -> ArenaDefinition:
	if arena == null:
		return null
	var candidate := ArenaDefinition.new()
	if not candidate.restore_snapshot(arena.to_snapshot()):
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
	var production_plan := ArenaProductionService.plan(candidate, destination)
	if not bool(production_plan.get("ok", false)):
		production_validation_text.text = "[color=red]Plan impossible : %s[/color]" % production_plan.get("error", "erreur")
		production_plan_text.text = production_validation_text.text
		production_dialog.get_ok_button().disabled = true
		return
	var report := production_plan.validation as ArenaValidationReport
	var validation_lines := PackedStringArray([
		"[b]%s[/b]" % report.verdict(),
		"%d erreur(s), %d avertissement(s), %d information(s)" % [
			report.error_count(), report.warning_count(), report.info_count(),
		],
		"",
	])
	for entry in report.messages:
		var color: String = ["red", "orange", "light_blue"][entry.severity]
		validation_lines.append("[color=%s]• %s[/color]" % [color, entry.message])
	production_validation_text.text = "\n".join(validation_lines)
	production_preview_text.text = (
		"[b]Même chaîne que le runtime[/b]\n\n"
		+ "• ArenaRuntimeBridge → GridData → Pathfinder\n"
		+ "• ArenaVisualAssembler partagé avec painted_battle/modular_battle\n"
		+ "• UnitView et UnitData réels en vue Jeu\n"
		+ "• foreground et occlusion réels\n\n"
		+ "Les trois vues seront capturées en 1280 × 720 lors de la production."
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
	production_plan_text.text = "\n".join(plan_lines)
	production_dialog.get_ok_button().disabled = not bool(production_plan.can_produce) \
		or (edit_session != null and edit_session.has_external_conflict())


func _production_confirmed() -> void:
	call_deferred("_run_confirmed_production")


func _run_confirmed_production() -> void:
	if edit_session == null or arena == null:
		return
	if edit_session.has_external_conflict():
		_show_production_failure("La source a changé sur disque : production bloquée.")
		return
	var candidate := _production_candidate()
	var before := arena.to_snapshot().duplicate(true)
	var preview_images: Dictionary = await _capture_runtime_preview_images(candidate)
	var result := ArenaProductionService.produce(
		candidate, production_destination_edit.text.strip_edges(), preview_images
	)
	if not bool(result.get("ok", false)):
		_show_production_failure("Production refusée : %s" % result.get("error", "erreur inconnue"))
		return
	var produced := ResourceLoader.load(
		str(result.arena_path), "", ResourceLoader.CACHE_MODE_IGNORE
	) as ArenaDefinition
	if produced == null:
		_show_production_failure("La ressource finale n'a pas pu être rechargée.")
		return
	edit_session.apply_snapshot(produced.to_snapshot())
	arena = edit_session.working_arena
	edit_session.commit("Produire la working copy", before, arena.to_snapshot())
	edit_session.mark_saved(str(result.arena_path))
	canvas.set_arena(arena)
	canvas.set_saved_transform(edit_session.saved_transform())
	if dynamic_lab != null:
		dynamic_lab.bind_session(edit_session, true)
	if runtime_preview != null:
		runtime_preview.set_arena(arena)
	_refresh_all()
	production_result_text.text = (
		"[font_size=28][b][color=green]SALLE PRÊTE[/color][/b][/font_size]\n\n"
		+ "✓ Définition valide\n✓ Grille valide\n✓ Pathfinding valide\n"
		+ "✓ Spawns valides\n✓ Rendu valide\n✓ Preview runtime valide\n"
		+ "✓ Ressources rechargées\n✓ Test direct disponible\n\n"
		+ "[b]%s[/b]" % result.directory
	)
	production_tabs.current_tab = 4
	production_dialog.get_ok_button().hide()
	production_dialog.popup_centered()
	_set_status("SALLE PRÊTE — ressources produites et rechargées dans %s" % result.directory)
	history_state_changed.emit()


func _capture_runtime_preview_images(candidate: ArenaDefinition) -> Dictionary:
	var images := {}
	if runtime_preview == null or candidate == null:
		return images
	var original_arena := arena
	var original_view := preview_view
	for entry in [
		["preview_logic.png", ArenaRuntimePreview.ViewMode.LOGIC],
		["preview_art.png", ArenaRuntimePreview.ViewMode.ART],
		["preview_game.png", ArenaRuntimePreview.ViewMode.GAME],
	]:
		runtime_preview.set_view_mode(entry[1])
		runtime_preview.set_arena(candidate)
		runtime_preview.rebuild_now()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
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
	runtime_preview.set_view_mode(original_view)
	runtime_preview.set_arena(original_arena)
	return images


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


func test_arena() -> void:
	var report := validate_arena()
	if not report.is_valid():
		return
	var context_id := "%s_%d" % [arena.arena_id, Time.get_ticks_usec()]
	var context_root := TEST_WORK_ROOT.path_join(context_id)
	var test_arena_path := context_root.path_join("arena.tres")
	var test_arena_copy := ArenaDefinition.new()
	if not test_arena_copy.restore_snapshot(arena.to_snapshot()):
		_set_status("La copie de travail n'a pas pu etre preparee pour le test.", true)
		return
	ArenaRuntimeBridge.sync_runtime_resources(test_arena_copy)
	var context_absolute := ProjectSettings.globalize_path(context_root)
	var directory_error := DirAccess.make_dir_recursive_absolute(context_absolute)
	if directory_error != OK:
		_set_status("Le contexte temporaire du test n'a pas pu etre cree.", true)
		return
	var save_error := ResourceSaver.save(test_arena_copy, test_arena_path)
	if save_error != OK:
		_set_status("La working copy du test n'a pas pu etre serialisee : %s" % error_string(save_error), true)
		return
	var absolute := ProjectSettings.globalize_path(TEST_REQUEST)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(TEST_REQUEST, FileAccess.WRITE)
	if file == null:
		_set_status("La configuration de test n'a pas pu etre creee.", true)
		return
	file.store_string(JSON.stringify({
		"arena_path": test_arena_path,
		"configuration": str(TEST_CONFIGURATIONS[test_configuration_option.selected][1]),
		"context_root": context_root,
		"cleanup_on_load": true,
		"result_path": context_root.path_join("launch_result.json"),
		"heroes": [
			"res://data/units/alliés/elfe.tres",
			"res://data/units/alliés/mage.tres",
			"res://data/units/alliés/Guerrier.tres",
		],
	}, "  "))
	file.close()
	_last_test_log = "Test direct demande pour %s via %s" % [arena.arena_id, TEST_RUNNER_SCENE]
	if editor_interface != null:
		editor_interface.play_custom_scene(TEST_RUNNER_SCENE)
		_set_status("Working copy lancee dans le combat reel. Aucune sauvegarde de production n'a ete effectuee ; F8 revient a l'editeur.")
	else:
		_set_status("Configuration de test direct preparee.")


func export_report() -> void:
	var report := validation_report if validation_report != null else validate_arena()
	var result := ArenaReportExporter.export_report(arena, report, _last_test_log)
	if not bool(result.get("ok", false)):
		_set_status("Echec de l'export : %s" % result.get("error", "erreur"), true)
		return
	await _export_previews(str(result.directory))
	_set_status("Rapport et apercus exportes dans %s" % result.directory)


func copy_report_for_codex() -> void:
	var report := validation_report if validation_report != null else validate_arena()
	ArenaReportExporter.copy_for_codex(report)
	_set_status("Le rapport de validation a ete copie dans le presse-papiers.")


func restore_latest_recovery() -> void:
	var files := ArenaSerializer.recovery_files()
	if files.is_empty():
		return
	var restored := ArenaSerializer.load_recovery(files[files.size() - 1])
	if restored != null:
		if edit_session != null and arena != null \
				and restored.arena_id == arena.arena_id:
			var before := arena.to_snapshot()
			edit_session.apply_snapshot(restored.to_snapshot())
			arena = edit_session.working_arena
			_commit_change(
				"Restaurer la sauvegarde de recuperation",
				before,
				arena.to_snapshot(),
			)
			_refresh_all()
		else:
			_set_arena(restored, true, "recovery:%s" % restored.arena_id)
		_set_status("Sauvegarde de recuperation restauree. Utilisez Sauvegarder pour la rendre canonique.")


func create_restore_point() -> void:
	if arena == null or edit_session == null:
		return
	var result := ArenaRestorePointService.create_point(
		arena, restore_name_edit.text, edit_session.source_fingerprint
	)
	if not bool(result.get("ok", false)):
		_set_status("Le point n'a pas pu etre cree : %s" % result.get("error", "erreur"), true)
		return
	restore_name_edit.clear()
	_refresh_restore_points()
	_set_status("Point de restauration cree : %s" % result.get("name", "Calibration"))


func restore_selected_point() -> void:
	if arena == null or restore_points_list == null or restore_points_list.get_selected_items().is_empty():
		return
	var index: int = restore_points_list.get_selected_items()[0]
	var path := str(restore_points_list.get_item_metadata(index))
	var result := ArenaRestorePointService.load_point(path, arena.arena_id)
	if not bool(result.get("ok", false)):
		_set_status("Restauration refusee : %s" % result.get("error", "erreur"), true)
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
		_set_status("Le point n'a pas pu etre renomme.", true)
		return
	restore_name_edit.clear()
	_refresh_restore_points()
	_set_status("Point de restauration renomme.")


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
		_set_status("Le point n'a pas pu etre supprime.", true)
		return
	_refresh_restore_points()
	_set_status("Point de restauration supprime.")


func restore_saved_calibration() -> void:
	if edit_session == null:
		return
	_apply_transform_snapshot(
		edit_session.saved_transform(), "Restaurer la calibration sauvegardee"
	)


func _on_reset_requested(id: int) -> void:
	if arena == null or edit_session == null:
		return
	var current := GridTransformSnapshot.from_arena(arena)
	var saved := edit_session.saved_transform()
	match id:
		0:
			_apply_transform_snapshot(saved, "Restaurer la calibration sauvegardee")
		1:
			current.origin = saved.origin
			_apply_transform_snapshot(current, "Reinitialiser la position sauvegardee")
		2:
			current.axis_x = saved.axis_x
			current.axis_y = saved.axis_y
			_apply_transform_snapshot(current, "Reinitialiser les axes sauvegardes")
		3:
			var pivot := GridTransformService.logical_grid_center(current, arena.grid_size)
			var angle := current.axis_x.angle_to(saved.axis_x)
			_apply_transform_snapshot(
				GridTransformService.rotate_around(current, pivot, angle),
				"Reinitialiser la rotation vers la sauvegarde"
			)


func _apply_transform_snapshot(snapshot: GridTransformSnapshot, action_name: String) -> void:
	if arena == null or snapshot == null:
		return
	var validation := GridTransformService.validate_snapshot(snapshot)
	if not bool(validation.get("ok", false)):
		_set_status("Calibration refusee : %s" % validation.get("error", "invalide"), true)
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


func _on_cells_edit_requested(cells: Array[Vector2i], erase: bool) -> void:
	if arena == null:
		return
	for cell in cells:
		var changed := false
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
				changed = ArenaEditingService.set_terrain(
					arena, cell, GridData.CellType.NORMAL if erase else terrain_option.selected
				)
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
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	if edit_session != null:
		edit_session.history.notify_preview_changed()
	canvas.queue_redraw()
	_refresh_inspector(cells[-1] if not cells.is_empty() else GridTransformService.INVALID_CELL)


func _on_stroke_finished(action_name: String) -> void:
	if arena == null or not _stroke_changed and _stroke_before.is_empty():
		return
	var final_name := action_name
	if _stroke_cell_count > 0:
		final_name = "%s — %d case(s)" % [action_name, _stroke_cell_count]
	_commit_change(final_name, _stroke_before, arena.to_snapshot())
	if not _stroke_before.is_empty():
		last_operation_label.text = _describe_transform_operation(
			final_name, _stroke_before, arena.to_snapshot()
		)
	_stroke_before = {}
	_stroke_changed = false
	_refresh_all()


func _on_stroke_cancelled() -> void:
	if edit_session != null and not _stroke_before.is_empty():
		edit_session.apply_snapshot(_stroke_before)
		arena = edit_session.working_arena
		ArenaRuntimeBridge.sync_runtime_resources(arena)
	_stroke_before = {}
	_stroke_changed = false
	_stroke_cell_count = 0
	if canvas != null:
		canvas.arena = arena
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
	_set_status("Grille calibree. Utilisez les trois poignees colorees pour l'ajuster visuellement.")


func _on_calibration_preview(origin: Vector2, axis_x: Vector2, axis_y: Vector2) -> void:
	if not GridTransformService.is_invertible(axis_x, axis_y):
		return
	arena.grid_origin = origin
	arena.axis_x = axis_x
	arena.axis_y = axis_y
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	_stroke_changed = true
	if edit_session != null:
		edit_session.history.notify_preview_changed()
	canvas.queue_redraw()
	_sync_advanced_values()
	_refresh_transform_inspector()


func _on_anchors_preview(cells: Array[Vector2i], pixels: Array[Vector2]) -> void:
	if arena == null or cells.size() != pixels.size():
		return
	var unique := {}
	for index in range(cells.size()):
		if not arena.is_in_bounds(cells[index]) or unique.has(cells[index]) \
				or not GridTransformService.is_vector_finite(pixels[index]):
			return
		unique[cells[index]] = true
	arena.calibration_cells = cells.duplicate()
	arena.calibration_pixels = pixels.duplicate()
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	_stroke_changed = true
	if edit_session != null:
		edit_session.history.notify_preview_changed()
	canvas.queue_redraw()
	_refresh_calibration_label()


func _on_hovered_cell_changed(cell: Vector2i) -> void:
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
			"Ligne de vue bloquee — premier obstacle en (%d, %d), regle : bloque les projectiles." % [blocker.x, blocker.y]
			if blocked else "Ligne de vue libre."
		)
	_verification_source = GridTransformService.INVALID_CELL


func _commit_change(action_name: String, before: Dictionary, after: Dictionary) -> void:
	if edit_session == null or before == after:
		return
	edit_session.commit(action_name, before, after)
	_autosave()
	_refresh_title()
	history_state_changed.emit()


func _restore_snapshot(snapshot: Dictionary) -> void:
	if edit_session == null:
		return
	edit_session.apply_snapshot(snapshot)
	arena = edit_session.working_arena
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	if dynamic_lab != null:
		dynamic_lab.bind_session(edit_session, true)
	if runtime_preview != null:
		runtime_preview.set_arena(arena)
	_refresh_all()


func _autosave() -> void:
	if arena != null and _recovery_timer != null:
		_recovery_timer.start()


func _flush_recovery() -> void:
	if arena != null and dirty:
		ArenaSerializer.save_recovery(arena)
	_refresh_recovery_button()


func _refresh_all() -> void:
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	canvas.queue_redraw()
	if runtime_preview != null and runtime_preview.visible:
		runtime_preview.set_arena(arena)
	_sync_advanced_values()
	_refresh_title()
	_refresh_calibration_label()
	_autosave()


func _refresh_title() -> void:
	if title_label == null:
		return
	title_label.text = "ARÈNES — %s%s" % [
		arena.display_name if arena != null else "Aucune map",
		" • non enregistree" if dirty else "",
	]


func _on_history_changed() -> void:
	if edit_session == null:
		return
	arena = edit_session.working_arena
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	canvas.arena = arena
	canvas.queue_redraw()
	_sync_advanced_values()
	_refresh_title()
	_refresh_calibration_label()
	_refresh_transform_inspector()
	history_state_changed.emit()


func _on_dirty_state_changed(_is_dirty: bool) -> void:
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
	return arena.display_name if arena != null else "Aucune map"


func cancel_active_gesture() -> bool:
	return canvas != null and canvas.cancel_active_gesture()


func _refresh_calibration_label() -> void:
	if arena == null or arena.calibration_cells.size() < 3:
		calibration_label.text = "Alignement a verifier"
		return
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var error := arena.painted_map_visual_data.calibration_rms()
	var maximum := arena.painted_map_visual_data.calibration_max_error()
	var quality := GridTransformService.calibration_quality(
		error, arena.calibration_cells.size()
	)
	calibration_label.text = {
		&"excellent": "Alignement excellent",
		&"acceptable": "Alignement correct",
		&"check": "Alignement a verifier",
		&"insufficient": "Calibration insuffisante",
	}.get(quality, "Alignement a verifier") \
		+ "  -  RMS %.2f px / max %.2f px" % [error, maximum]


func _refresh_transform_inspector() -> void:
	if arena == null or inspector_label == null:
		return
	var axis_angle := absf(rad_to_deg(arena.axis_x.angle_to(arena.axis_y)))
	var determinant_value := GridTransformService.determinant(arena.axis_x, arena.axis_y)
	var relative := GridTransformService.relative_determinant(arena.axis_x, arena.axis_y)
	inspector_label.text = (
		"Grille selectionnee\n"
		+ "Position : %.2f, %.2f px\n" % [arena.grid_origin.x, arena.grid_origin.y]
		+ "Droite : %.2f px / %.2f deg\n" % [arena.axis_x.length(), rad_to_deg(arena.axis_x.angle())]
		+ "Gauche : %.2f px / %.2f deg\n" % [arena.axis_y.length(), rad_to_deg(arena.axis_y.angle())]
		+ "Angle entre axes : %.2f deg\n" % axis_angle
		+ "Determinant : %.3f / stabilite %.6f" % [determinant_value, relative]
	)


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
	return "Derniere operation : %s\nX %+0.2f px  Y %+0.2f px  Angle %+0.2f deg  Echelle %.2f %%" % [
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
		inspector_label.text = "Cellule (%d, %d)\nNon definie" % [cell.x, cell.y]
		return
	var state := "Bordure" if definition.border else ("Jouable" if definition.playable else "Non jouable")
	var obstacle := arena.obstacle_at(cell)
	inspector_label.text = "Cellule (%d, %d)\n%s\nTerrain : %s\nObstacle : %s\nSpawns : %d" % [
		cell.x, cell.y, state, str(definition.terrain_id),
		"aucun" if obstacle == null else ["Mur complet", "Obstacle bas", "Decor traversable", "Falaise"][obstacle.preset],
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
		_set_status("Les axes saisis sont colineaires : la modification est refusee.", true)
		return
	var before := arena.to_snapshot()
	arena.grid_origin = next_origin
	arena.axis_x = next_axis_x
	arena.axis_y = next_axis_y
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	_commit_change("Modifier la calibration avancee", before, arena.to_snapshot())
	_refresh_all()


func _on_mode_selected(index: int) -> void:
	advanced_panel.visible = index == 2
	canvas.show_technical = index == 2
	if index == 1:
		_select_verification(0)
		validate_arena()
	elif index == 0:
		canvas.clear_overlays()
	canvas.queue_redraw()


func _on_library_activated(index: int) -> void:
	load_production(PRODUCTION_LIBRARY[index][1])


func _on_tool_selected(index: int) -> void:
	_show_editor_canvas()
	canvas.set_tool(index)
	canvas.layer_locks["calibration"] = index not in [
		ArenaStudioCanvas.Tool.TRANSFORM_GRID,
		ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS,
	]
	_update_layer_controls()
	obstacle_option.visible = index == ArenaStudioCanvas.Tool.OBSTACLE
	terrain_option.visible = index == ArenaStudioCanvas.Tool.TERRAIN
	spawn_option.visible = index == ArenaStudioCanvas.Tool.SPAWN
	verification_option.visible = index == ArenaStudioCanvas.Tool.VERIFY
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
		_set_status("Grille selectionnee : glissez son corps ou une poignee. Echap ou clic droit annule le geste.")
	elif index == ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS:
		_refresh_transform_inspector()
		_set_status("Ancres : cliquez pour ajouter, glissez pour deplacer, clic droit pour supprimer.")


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
	mode_option.select(1)
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
		recovery_button.visible = not ArenaSerializer.recovery_files().is_empty()


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


func set_shell_toolbar_visible(value: bool) -> void:
	if top_bar != null:
		top_bar.visible = value


func _toggle_bottom_drawer() -> void:
	if bottom_drawer_content == null:
		return
	bottom_drawer_content.visible = not bottom_drawer_content.visible
	bottom_drawer_button.text = (
		"Validation • Historique • Rapport • Console • Analyse   ▼"
		if bottom_drawer_content.visible else
		"✓ Validation fermee • Historique • Rapport • Console • Analyse   ▲"
	)
	vertical_split.split_offset = -220 if bottom_drawer_content.visible else -42


func toggle_focus_map() -> bool:
	set_focus_map(not focus_map_enabled)
	return focus_map_enabled


func set_focus_map(value: bool) -> void:
	if focus_map_enabled == value:
		return
	if value:
		_pre_focus_state = {
			"left": left_panel.visible,
			"right": right_panel.visible,
			"drawer": bottom_drawer_content.visible,
			"navigation": canvas_navigation.visible,
		}
		left_panel.hide()
		right_panel.hide()
		bottom_drawer_content.hide()
		canvas_navigation.hide()
	else:
		left_panel.visible = bool(_pre_focus_state.get("left", true))
		right_panel.visible = bool(_pre_focus_state.get("right", true))
		bottom_drawer_content.visible = bool(_pre_focus_state.get("drawer", false))
		canvas_navigation.visible = bool(_pre_focus_state.get("navigation", true))
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
	canvas.hide()
	dynamic_lab_container.hide()
	runtime_preview.show()
	runtime_preview.set_view_mode(preview_view)
	runtime_preview.set_arena(arena)


func show_dynamic_construction() -> void:
	if dynamic_lab == null or edit_session == null:
		_set_status("Le Dynamic Arena Lab integre n'est pas disponible.", true)
		return
	canvas.hide()
	runtime_preview.hide()
	dynamic_lab_container.show()
	dynamic_lab.bind_session(edit_session, true)
	dynamic_mode_button.button_pressed = true
	_set_status("Construction dynamique : chaque geste modifie la working copy ArenaDefinition.")


func _show_editor_canvas() -> void:
	if canvas == null:
		return
	canvas.show()
	if runtime_preview != null:
		runtime_preview.hide()
	if dynamic_lab_container != null:
		dynamic_lab_container.hide()
	if dynamic_mode_button != null:
		dynamic_mode_button.button_pressed = false


func _on_dynamic_lab_document_changed(value: ArenaDefinition, _dirty: bool) -> void:
	if edit_session == null or value != edit_session.working_arena:
		return
	arena = value
	canvas.set_arena(arena)
	canvas.queue_redraw()
	validation_report = null
	_refresh_title()
	_refresh_inspector(GridTransformService.INVALID_CELL)
	if runtime_preview != null:
		runtime_preview.set_arena(arena)
	history_state_changed.emit()


func _resize_dynamic_lab_viewport() -> void:
	if dynamic_lab_viewport == null or dynamic_lab_container == null:
		return
	if dynamic_lab != null:
		dynamic_lab.call_deferred("_fit_camera")


func _apply_responsive_layout() -> void:
	if left_panel == null or right_panel == null:
		return
	if focus_map_enabled or workspace_preset == 3:
		left_panel.hide()
		right_panel.hide()
		bottom_drawer_content.hide()
		return
	left_panel.custom_minimum_size.x = 56
	right_panel.custom_minimum_size.x = 300 if size.x >= 1500 else 280
	if size.x < 1180:
		right_panel.hide()
	else:
		right_panel.show()
	if size.y < 760:
		bottom_drawer_content.hide()


func get_workspace_state() -> Dictionary:
	return {
		"focus_map": focus_map_enabled,
		"preset": workspace_preset,
		"preview_view": preview_view,
		"left_visible": left_panel.visible if left_panel != null else true,
		"right_visible": right_panel.visible if right_panel != null else true,
		"drawer_visible": bottom_drawer_content.visible \
			if bottom_drawer_content != null else false,
		"horizontal_split": horizontal_split.split_offset \
			if horizontal_split != null else 58,
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
	left_panel.visible = bool(state.get("left_visible", true))
	right_panel.visible = bool(state.get("right_visible", true))
	bottom_drawer_content.visible = bool(state.get("drawer_visible", false))
	if bool(state.get("focus_map", false)):
		set_focus_map(true)
	_apply_responsive_layout()


func canvas_occupation_ratio() -> Vector2:
	if view_stack == null or size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(view_stack.size.x / size.x, view_stack.size.y / size.y)
