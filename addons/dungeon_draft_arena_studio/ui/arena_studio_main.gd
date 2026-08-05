@tool
class_name ArenaStudioMain
extends Control

const TEST_RUNNER_SCENE := "res://addons/dungeon_draft_arena_studio/test/arena_studio_test_runner.tscn"
const TEST_REQUEST := "user://arena_studio/test_request.json"
const TOOL_LABELS := [
	"Selection", "Deplacement de vue", "Ajouter une case", "Retirer une case",
	"Bordure", "Obstacle", "Terrain", "Spawn", "Verification",
]
const PRODUCTION_LIBRARY := [
	["Foret — Gue forestier", &"room_01_forest"],
	["Volcan — Caldeira", &"room_05_volcano"],
	["Espace — Station orbitale", &"room_06_space"],
]
const TEST_CONFIGURATIONS := [
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
var validation_report: ArenaValidationReport = null
var editor_interface = null
var editor_undo_redo = null
var dirty := false

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
var _stroke_before := {}
var _stroke_changed := false
var _stroke_cell_count := 0
var _verification_source := GridTransformService.INVALID_CELL
var _last_test_log := "Aucun test direct lance depuis cette session."


func setup(host_editor_interface, undo_manager) -> void:
	editor_interface = host_editor_interface
	editor_undo_redo = undo_manager


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	_build_dialogs()
	_connect_canvas()
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
	var imported := ArenaLegacyImporter.import_production(arena_id)
	if imported == null:
		_set_status("Impossible d'ouvrir la map de production demandee.", true)
		return false
	_set_arena(imported, false)
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
	box.add_child(_section_label("Actions"))
	_add_button(box, "Preparer automatiquement la map", prepare_automatically)
	_add_button(box, "Placer les heros", func(): _select_tool_and_preset(ArenaStudioCanvas.Tool.SPAWN, 0))
	_add_button(box, "Placer les ennemis", func(): _select_tool_and_preset(ArenaStudioCanvas.Tool.SPAWN, 4))
	_add_button(box, "Verifier les deplacements", func(): _select_verification(0))
	_add_button(box, "Tester une ligne de vue", func(): _select_verification(1))
	_add_button(box, "Exporter le rapport", export_report)
	_add_button(box, "Copier le rapport pour Codex", copy_report_for_codex)
	recovery_button = _add_button(box, "Restaurer la sauvegarde de recuperation", restore_latest_recovery)
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
	canvas.calibration_requested.connect(_on_calibration_requested)
	canvas.calibration_preview_requested.connect(_on_calibration_preview)
	canvas.hovered_cell_changed.connect(_on_hovered_cell_changed)
	canvas.verification_cell_requested.connect(_on_verification_cell_requested)


func _set_arena(value: ArenaDefinition, mark_dirty: bool) -> void:
	arena = value
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	dirty = mark_dirty
	canvas.set_arena(arena)
	_verification_source = GridTransformService.INVALID_CELL
	validation_report = null
	validation_list.clear()
	_sync_advanced_values()
	_refresh_title()
	_refresh_calibration_label()
	_refresh_inspector(GridTransformService.INVALID_CELL)


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
	_set_arena(created, true)
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
	var loaded := ArenaSerializer.load_canonical(path)
	if loaded == null:
		_set_status("Cette ressource n'est pas une arene Arena Studio valide.", true)
		return
	_set_arena(loaded, false)
	_set_status("Arene ouverte : %s" % loaded.display_name)


func save_arena() -> void:
	if arena == null:
		return
	var path := arena.resource_path if arena.resource_path.begins_with("res://data/arenas/") \
		else ArenaSerializer.suggested_path(arena)
	var error := ArenaSerializer.save_canonical(arena, path)
	if error == OK:
		dirty = false
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
	_commit_change("Ajuster la calibration multipoint", before, arena.to_snapshot())
	_refresh_all()
	_set_status("Calibration multipoint appliquee — erreur RMS %.2f px." % fitted.rms_error)


func validate_arena() -> ArenaValidationReport:
	validation_report = ArenaValidator.validate(arena)
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
	if dirty or arena.resource_path.is_empty():
		save_arena()
	if dirty or arena.resource_path.is_empty():
		return
	var absolute := ProjectSettings.globalize_path(TEST_REQUEST)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(TEST_REQUEST, FileAccess.WRITE)
	if file == null:
		_set_status("La configuration de test n'a pas pu etre creee.", true)
		return
	file.store_string(JSON.stringify({
		"arena_path": arena.resource_path,
		"configuration": str(TEST_CONFIGURATIONS[test_configuration_option.selected][1]),
		"heroes": [
			"res://data/units/alliés/elfe.tres",
			"res://data/units/alliés/mage.tres",
			"res://data/units/alliés/Guerrier.tres",
		],
	}, "  "))
	_last_test_log = "Test direct demande pour %s via %s" % [arena.arena_id, TEST_RUNNER_SCENE]
	if editor_interface != null:
		editor_interface.play_custom_scene(TEST_RUNNER_SCENE)
		_set_status("Test direct lance avec le runtime reel. F8 permet de revenir a l'editeur.")
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
		_set_arena(restored, true)
		_set_status("Sauvegarde de recuperation restauree. Utilisez Sauvegarder pour la rendre canonique.")


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
	dirty = true
	canvas.queue_redraw()
	_refresh_inspector(cells[-1] if not cells.is_empty() else GridTransformService.INVALID_CELL)


func _on_stroke_finished(action_name: String) -> void:
	if arena == null or not _stroke_changed and _stroke_before.is_empty():
		return
	var final_name := action_name
	if _stroke_cell_count > 0:
		final_name = "%s — %d case(s)" % [action_name, _stroke_cell_count]
	_commit_change(final_name, _stroke_before, arena.to_snapshot())
	_stroke_before = {}
	_stroke_changed = false
	_refresh_all()


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
	if arena.calibration_cells.size() == 3:
		arena.calibration_pixels = [origin, origin + axis_x, origin + axis_y]
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	_stroke_changed = true
	dirty = true
	canvas.queue_redraw()
	_sync_advanced_values()


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
	if before == after:
		return
	var manager = editor_undo_redo if editor_undo_redo != null else _fallback_undo
	manager.create_action(action_name)
	if manager == _fallback_undo:
		manager.add_do_method(Callable(self, "_restore_snapshot").bind(after))
		manager.add_undo_method(Callable(self, "_restore_snapshot").bind(before))
	else:
		manager.add_do_method(self, "_restore_snapshot", after)
		manager.add_undo_method(self, "_restore_snapshot", before)
	manager.commit_action()
	dirty = true
	_autosave()
	_refresh_title()


func _restore_snapshot(snapshot: Dictionary) -> void:
	if arena == null:
		arena = ArenaDefinition.new()
	arena.restore_snapshot(snapshot)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	dirty = true
	canvas.set_arena(arena)
	_refresh_all()


func _autosave() -> void:
	if arena != null:
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


func _refresh_calibration_label() -> void:
	if arena == null or arena.calibration_cells.size() < 3:
		calibration_label.text = "Alignement a verifier"
		return
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var error := arena.painted_map_visual_data.calibration_rms()
	calibration_label.text = "Alignement excellent" if error <= 1.0 \
		else ("Alignement correct" if error <= 3.0 else "Alignement a verifier")


func _refresh_inspector(cell: Vector2i) -> void:
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
	obstacle_option.visible = index == ArenaStudioCanvas.Tool.OBSTACLE
	terrain_option.visible = index == ArenaStudioCanvas.Tool.TERRAIN
	spawn_option.visible = index == ArenaStudioCanvas.Tool.SPAWN
	verification_option.visible = index == ArenaStudioCanvas.Tool.VERIFY


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
