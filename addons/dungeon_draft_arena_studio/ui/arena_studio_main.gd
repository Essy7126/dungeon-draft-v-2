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
var layer_controls := {}
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

var _fallback_undo := UndoRedo.new()
var _sessions: Dictionary = {}
var _stroke_before := {}
var _stroke_changed := false
var _stroke_cell_count := 0
var _verification_source := GridTransformService.INVALID_CELL
var _last_test_log := "Aucun test direct lance depuis cette session."
var _recovery_timer: Timer


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
	_refresh_recovery_button()
	ensure_initial_arena_loaded()


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
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	root.add_child(_build_top_bar())

	var vertical_split := VSplitContainer.new()
	vertical_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vertical_split.split_offset = -130
	root.add_child(vertical_split)

	var horizontal_split := HSplitContainer.new()
	horizontal_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_split.split_offset = 246
	vertical_split.add_child(horizontal_split)
	horizontal_split.add_child(_build_left_panel())

	var center_and_right := HSplitContainer.new()
	center_and_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_and_right.split_offset = -310
	horizontal_split.add_child(center_and_right)
	center_and_right.add_child(_build_canvas_panel())
	center_and_right.add_child(_build_right_panel())
	vertical_split.add_child(_build_validation_panel())

	status_label = Label.new()
	status_label.text = "Initialisation d'Arena Studio..."
	status_label.custom_minimum_size.y = 28
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.76, 0.86, 0.94))
	root.add_child(status_label)


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 52
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	panel.add_child(bar)
	title_label = Label.new()
	title_label.text = "DUNGEON DRAFT ARENA STUDIO"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.52, 0.88, 1.0))
	title_label.custom_minimum_size.x = 310
	bar.add_child(title_label)
	_add_button(bar, "+ Nouvelle arene", _show_new_dialog)
	_add_button(bar, "Ouvrir", _show_open_dialog)
	_add_button(bar, "Sauvegarder", save_arena)
	_add_button(bar, "Preparer automatiquement", prepare_automatically)
	_add_button(bar, "Valider", validate_arena)
	_add_button(bar, "▶ Tester la map", test_arena)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	mode_option = OptionButton.new()
	mode_option.tooltip_text = "Creation masque les informations techniques."
	for label in ["Mode Creation", "Mode Verification", "Mode Avance"]:
		mode_option.add_item(label)
	mode_option.item_selected.connect(_on_mode_selected)
	bar.add_child(mode_option)
	return panel


func _build_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 238
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	box.add_child(_section_label("Bibliotheque"))
	library_list = ItemList.new()
	library_list.custom_minimum_size.y = 92
	for entry in PRODUCTION_LIBRARY:
		library_list.add_item(entry[0])
	library_list.item_activated.connect(_on_library_activated)
	box.add_child(library_list)
	box.add_child(_section_label("Outils"))
	tool_list = ItemList.new()
	tool_list.custom_minimum_size.y = 224
	tool_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for label in TOOL_LABELS:
		tool_list.add_item(label)
	tool_list.select(ArenaStudioCanvas.Tool.SELECT)
	tool_list.item_selected.connect(_on_tool_selected)
	box.add_child(tool_list)
	box.add_child(_section_label("Forme du pinceau"))
	shape_option = OptionButton.new()
	for label in ["Pinceau continu", "Rectangle", "Remplissage contigu", "Selection multiple"]:
		shape_option.add_item(label)
	shape_option.item_selected.connect(func(index): canvas.brush_shape = index)
	box.add_child(shape_option)
	obstacle_option = OptionButton.new()
	for label in ["Mur complet", "Obstacle bas", "Decor traversable", "Falaise"]:
		obstacle_option.add_item(label)
	box.add_child(obstacle_option)
	terrain_option = OptionButton.new()
	for label in ["Normal", "Mur", "Trou", "Lave", "Glace", "Ombre", "Rune"]:
		terrain_option.add_item(label)
	box.add_child(terrain_option)
	spawn_option = OptionButton.new()
	for label in ["Heros 1 — Elfe", "Heros 2 — Mage", "Heros 3 — Guerrier", "Ennemi", "Groupe ennemi", "Zone d'invocation"]:
		spawn_option.add_item(label)
	box.add_child(spawn_option)
	verification_option = OptionButton.new()
	verification_option.add_item("Verifier les deplacements")
	verification_option.add_item("Tester une ligne de vue")
	verification_option.item_selected.connect(_on_verification_kind_selected)
	box.add_child(verification_option)
	box.add_child(_section_label("Test direct"))
	test_configuration_option = OptionButton.new()
	for configuration in TEST_CONFIGURATIONS:
		test_configuration_option.add_item(configuration[0])
	box.add_child(test_configuration_option)
	_add_button(box, "Creer la bordure de securite", create_safety_border)
	return panel


func _build_canvas_panel() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var navigation := HBoxContainer.new()
	_add_button(navigation, "Recentrer", func(): canvas.recenter_grid())
	_add_button(navigation, "Adapter a l'image", func(): canvas.fit_to_image())
	_add_button(navigation, "Calibration en 3 clics", start_calibration)
	var hint := Label.new()
	hint.text = "Molette : zoom • Clic milieu : deplacer"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	navigation.add_child(hint)
	box.add_child(navigation)
	canvas = ArenaStudioCanvas.new()
	canvas.custom_minimum_size = Vector2(450, 300)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(canvas)
	return box


func _build_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 295
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 270
	scroll.add_child(box)
	box.add_child(_section_label("Inspecteur simplifie"))
	inspector_label = Label.new()
	inspector_label.text = "Aucune cellule selectionnee."
	inspector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_label.custom_minimum_size.y = 78
	box.add_child(inspector_label)
	calibration_label = Label.new()
	calibration_label.text = "Alignement a verifier"
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
	recovery_button = _add_button(box, "Restaurer la sauvegarde de recuperation", restore_latest_recovery)
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
	var fine := Label.new()
	fine.text = "Shift : precision fine"
	flags.add_child(fine)
	var preserve := CheckButton.new()
	preserve.text = "Longueur des axes"
	preserve.toggled.connect(func(value): canvas.preserve_axis_length = value)
	flags.add_child(preserve)
	var symmetry := CheckButton.new()
	symmetry.text = "Symetrie isometrique"
	symmetry.toggled.connect(func(value): canvas.mirror_axes = value)
	flags.add_child(symmetry)
	var keep_size := CheckButton.new()
	keep_size.text = "Conserver taille globale"
	keep_size.toggled.connect(func(value): canvas.lock_scale = value)
	flags.add_child(keep_size)
	var independent := CheckButton.new()
	independent.text = "Axes independants"
	independent.button_pressed = true
	independent.toggled.connect(func(value):
		canvas.mirror_axes = not value
		symmetry.set_pressed_no_signal(not value)
	)
	flags.add_child(independent)
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
	compare_button.text = "Comparer a la derniere sauvegarde"
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
	var buttons := HBoxContainer.new()
	_add_button(buttons, "Creer", create_restore_point)
	_add_button(buttons, "Restaurer", restore_selected_point)
	_add_button(buttons, "Supprimer", delete_selected_restore_point)
	box.add_child(buttons)
	restore_points_list = ItemList.new()
	restore_points_list.custom_minimum_size.y = 72
	box.add_child(restore_points_list)
	_add_button(box, "Restaurer la calibration sauvegardee", restore_saved_calibration)
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
	_set_arena(loaded, false, path)
	_set_status("Arene ouverte : %s" % loaded.display_name)


func save_arena() -> void:
	if arena == null or edit_session == null:
		return
	if edit_session.has_external_conflict():
		_set_status("La ressource a change sur disque. Rechargez ou resolvez le conflit avant de sauvegarder.", true)
		return
	var path := edit_session.source_path if edit_session.source_path.begins_with("res://data/arenas/") \
		else ArenaSerializer.suggested_path(arena)
	if edit_session.source_path.is_empty() and ResourceLoader.exists(path):
		_set_status(
			"Sauvegarde refusee : une map canonique utilise deja cet identifiant.", true
		)
		return
	var error := ArenaSerializer.save_canonical(arena, path)
	if error == OK:
		var verified := ResourceLoader.load(
			path, "", ResourceLoader.CACHE_MODE_IGNORE
		) as ArenaDefinition
		if verified == null or ArenaEditSession.fingerprint(verified.to_snapshot()) \
				!= ArenaEditSession.fingerprint(arena.to_snapshot()):
			_set_status("La verification apres sauvegarde a echoue.", true)
			return
		edit_session.mark_saved(path)
		canvas.set_saved_transform(edit_session.saved_transform())
		_refresh_title()
		_refresh_recovery_button()
		_set_status("Map sauvegardee : %s" % path)
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
		arena.calibration_cells, arena.calibration_pixels
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


func delete_selected_restore_point() -> void:
	if restore_points_list == null or restore_points_list.get_selected_items().is_empty():
		return
	var index: int = restore_points_list.get_selected_items()[0]
	var path := str(restore_points_list.get_item_metadata(index))
	var error := ArenaRestorePointService.delete_point(path)
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
	_sync_advanced_values()
	_refresh_title()
	_refresh_calibration_label()
	_autosave()


func _refresh_title() -> void:
	if title_label == null:
		return
	title_label.text = "ARENA STUDIO — %s%s" % [
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
	if canvas != null and canvas.has_method("is_transforming") \
			and canvas.is_transforming():
		return false
	return edit_session != null and edit_session.history.jump_to(index)


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
	calibration_label.text = (
		"Alignement excellent" if error <= 1.0 \
		else ("Alignement correct" if error <= 3.0 else "Alignement a verifier")
	) + "  -  RMS %.2f px / max %.2f px" % [error, maximum]


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


func _save_session_editor_state() -> void:
	if edit_session == null or canvas == null:
		return
	edit_session.editor_state = canvas.get_editor_state()


func _restore_session_editor_state() -> void:
	if edit_session == null or canvas == null:
		return
	canvas.apply_editor_state(edit_session.editor_state)
	_update_layer_controls()


func _refresh_inspector(cell: Vector2i) -> void:
	if canvas != null and canvas.active_tool in [
		ArenaStudioCanvas.Tool.TRANSFORM_GRID,
		ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS,
	]:
		_refresh_transform_inspector()
		return
	if arena == null or cell == GridTransformService.INVALID_CELL:
		inspector_label.text = "Survolez une case pour afficher ses proprietes."
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
