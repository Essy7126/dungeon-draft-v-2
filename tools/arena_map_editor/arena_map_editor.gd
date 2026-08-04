class_name ArenaMapEditor
extends Node2D

const EXAMPLE_PATH := "res://tools/arena_map_editor/examples/reference_arena.json"
const HISTORY_LIMIT := 100

@onready var canvas: ArenaMapCanvas = $ArenaMapCanvas
@onready var camera: Camera2D = $Camera2D
@onready var map_id_edit: LineEdit = $UI/LeftPanel/Margin/VBox/MapId
@onready var display_name_edit: LineEdit = $UI/LeftPanel/Margin/VBox/DisplayName
@onready var kind_option: OptionButton = $UI/LeftPanel/Margin/VBox/Kind
@onready var theme_edit: LineEdit = $UI/LeftPanel/Margin/VBox/Theme
@onready var width_spin: SpinBox = $UI/LeftPanel/Margin/VBox/SizeRow/Width
@onready var height_spin: SpinBox = $UI/LeftPanel/Margin/VBox/SizeRow/Height
@onready var layer_option: OptionButton = $UI/LeftPanel/Margin/VBox/Layer
@onready var palette: ItemList = $UI/LeftPanel/Margin/VBox/Palette
@onready var prompt_edit: TextEdit = $UI/RightPanel/Margin/VBox/DecorPrompt
@onready var counts_label: Label = $UI/RightPanel/Margin/VBox/Counts
@onready var inspector_label: Label = $UI/RightPanel/Margin/VBox/Inspector
@onready var output_label: Label = $UI/RightPanel/Margin/VBox/Output
@onready var status_label: Label = $UI/StatusBar/Margin/Status
@onready var save_dialog: FileDialog = $UI/SaveDialog
@onready var open_dialog: FileDialog = $UI/OpenDialog

var document: ArenaMapDocument = null
var current_layer := ArenaMapDocument.EditLayer.BASE
var current_value := ArenaMapDocument.BaseTile.STONE
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _stroke_before: Dictionary = {}
var _stroke_changed := false
var _last_hovered := Vector2i(-1, -1)
var _grid_visible := true
var _exporter := ArenaMapExporter.new()


func _ready() -> void:
	# FileDialog est un sous-fenetrage modal. Le masquer explicitement evite
	# qu'un backend d'affichage ne considere sa valeur par defaut comme ouverte
	# et n'assombrisse l'editeur au premier rendu.
	save_dialog.hide()
	open_dialog.hide()
	_setup_controls()
	_connect_controls()
	var initial := ArenaMapSerializer.load_json(EXAMPLE_PATH)
	if initial == null:
		initial = ArenaMapDocument.new(Vector2i(12, 10))
	_configure_document(initial)
	_update_palette()
	call_deferred("_center_camera")


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.ctrl_pressed and key.keycode == KEY_Z:
		undo()
	elif key.ctrl_pressed and key.keycode == KEY_Y:
		redo()
	elif key.ctrl_pressed and key.keycode == KEY_S:
		quick_save()
	elif key.ctrl_pressed and key.keycode == KEY_E:
		export_current_map()
	elif key.keycode == KEY_G:
		_toggle_grid()
	elif key.keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		layer_option.select(int(key.keycode - KEY_1))
		_on_layer_selected(layer_option.selected)
	elif key.keycode == KEY_F:
		_fill_current_layer()


func _setup_controls() -> void:
	for kind in ["reference", "special", "boss", "puzzle"]:
		kind_option.add_item(kind.capitalize())
		kind_option.set_item_metadata(kind_option.item_count - 1, kind)
	for layer_name in ArenaMapDocument.LAYER_NAMES:
		layer_option.add_item(layer_name)
	layer_option.select(ArenaMapDocument.EditLayer.BASE)
	save_dialog.current_dir = ArenaMapSerializer.MAP_ROOT
	open_dialog.current_dir = ArenaMapSerializer.MAP_ROOT


func _connect_controls() -> void:
	canvas.set_editor_camera(camera)
	canvas.stroke_started.connect(_on_stroke_started)
	canvas.stroke_finished.connect(_on_stroke_finished)
	canvas.paint_requested.connect(_on_paint_requested)
	canvas.eyedrop_requested.connect(_on_eyedrop_requested)
	canvas.hovered_cell_changed.connect(_on_hovered_cell_changed)
	layer_option.item_selected.connect(_on_layer_selected)
	palette.item_selected.connect(_on_palette_selected)
	$UI/LeftPanel/Margin/VBox/New.pressed.connect(_new_map)
	$UI/LeftPanel/Margin/VBox/SizeRow/Resize.pressed.connect(_resize_map)
	$UI/LeftPanel/Margin/VBox/Fill.pressed.connect(_fill_current_layer)
	$UI/TopBar/Margin/Buttons/Undo.pressed.connect(undo)
	$UI/TopBar/Margin/Buttons/Redo.pressed.connect(redo)
	$UI/TopBar/Margin/Buttons/Grid.pressed.connect(_toggle_grid)
	$UI/TopBar/Margin/Buttons/Center.pressed.connect(_center_camera)
	$UI/RightPanel/Margin/VBox/Actions/Save.pressed.connect(quick_save)
	$UI/RightPanel/Margin/VBox/Actions/SaveAs.pressed.connect(_open_save_dialog)
	$UI/RightPanel/Margin/VBox/Actions/Open.pressed.connect(_open_load_dialog)
	$UI/RightPanel/Margin/VBox/Export.pressed.connect(export_current_map)
	save_dialog.file_selected.connect(_save_to_path)
	open_dialog.file_selected.connect(_load_from_path)


func _configure_document(new_document: ArenaMapDocument) -> void:
	if document != null and document.changed.is_connected(_on_document_changed):
		document.changed.disconnect(_on_document_changed)
	document = new_document
	document.changed.connect(_on_document_changed)
	canvas.configure(document)
	canvas.set_display_mode(ArenaMapCanvas.DisplayMode.EDITOR)
	_sync_controls_from_document()
	_undo_stack.clear()
	_redo_stack.clear()
	_update_all_ui()
	_set_status("Map chargee : %s" % document.display_name)


func _sync_controls_from_document() -> void:
	map_id_edit.text = document.map_id
	display_name_edit.text = document.display_name
	theme_edit.text = document.theme_id
	prompt_edit.text = document.decor_prompt
	width_spin.value = document.grid_size.x
	height_spin.value = document.grid_size.y
	for index in range(kind_option.item_count):
		if str(kind_option.get_item_metadata(index)) == document.map_kind:
			kind_option.select(index)
			break


func _apply_metadata_from_controls() -> void:
	document.set_metadata(
		map_id_edit.text,
		display_name_edit.text,
		str(kind_option.get_item_metadata(kind_option.selected)),
		theme_edit.text,
		prompt_edit.text
	)
	map_id_edit.text = document.map_id
	theme_edit.text = document.theme_id


func _new_map() -> void:
	var size := Vector2i(int(width_spin.value), int(height_spin.value))
	var fresh := ArenaMapDocument.new(size)
	fresh.map_id = "new_arena"
	fresh.display_name = "Nouvelle arene"
	_configure_document(fresh)
	_center_camera()


func _resize_map() -> void:
	var next := Vector2i(int(width_spin.value), int(height_spin.value))
	if next == document.grid_size:
		return
	_push_undo(document.snapshot())
	document.resize(next)
	_redo_stack.clear()
	_center_camera()
	_update_all_ui()
	_set_status("Grille redimensionnee : %d x %d" % [next.x, next.y])


func _on_layer_selected(index: int) -> void:
	current_layer = index
	_update_palette()


func _update_palette() -> void:
	palette.clear()
	var names: Array = []
	match current_layer:
		ArenaMapDocument.EditLayer.BASE:
			names = ArenaMapDocument.BASE_NAMES
		ArenaMapDocument.EditLayer.SURFACE:
			names = ArenaMapDocument.SURFACE_NAMES
		ArenaMapDocument.EditLayer.SPECIAL:
			names = ArenaMapDocument.SPECIAL_NAMES
		ArenaMapDocument.EditLayer.WALL:
			names = ArenaMapDocument.WALL_NAMES
	for index in range(names.size()):
		palette.add_item(str(names[index]).replace("_", " "))
		palette.set_item_metadata(index, index)
	current_value = 1 if names.size() > 1 else 0
	palette.select(current_value)
	_set_status("Pinceau : %s / %s" % [
		ArenaMapDocument.LAYER_NAMES[current_layer], names[current_value],
	])


func _on_palette_selected(index: int) -> void:
	current_value = int(palette.get_item_metadata(index))
	_set_status("Pinceau : %s / %s" % [
		ArenaMapDocument.LAYER_NAMES[current_layer], palette.get_item_text(index),
	])


func _on_stroke_started() -> void:
	_stroke_before = document.snapshot()
	_stroke_changed = false


func _on_paint_requested(cell: Vector2i, erase: bool) -> void:
	var value := current_value
	if erase:
		value = ArenaMapDocument.BaseTile.VOID \
				if current_layer == ArenaMapDocument.EditLayer.BASE else 0
	if document.set_layer(cell, current_layer, value):
		_stroke_changed = true
		_update_inspector(cell)


func _on_stroke_finished() -> void:
	if _stroke_changed:
		_push_undo(_stroke_before)
		_redo_stack.clear()
	_stroke_before = {}
	_stroke_changed = false


func _on_eyedrop_requested(cell: Vector2i) -> void:
	var state := document.get_cell(cell)
	var field: String = ["base", "surface", "special", "wall"][current_layer]
	current_value = int(state[field])
	palette.select(current_value)
	_set_status("Valeur prelevee en %s : %s" % [cell, palette.get_item_text(current_value)])


func _fill_current_layer() -> void:
	var before := document.snapshot()
	var changed_count := document.fill_layer(current_layer, current_value)
	if changed_count > 0:
		_push_undo(before)
		_redo_stack.clear()
	_set_status("Remplissage : %d cellules modifiees" % changed_count)


func undo() -> void:
	if _undo_stack.is_empty():
		_set_status("Rien a annuler.")
		return
	_redo_stack.append(document.snapshot())
	var snapshot := _undo_stack.pop_back() as Dictionary
	document.restore_snapshot(snapshot)
	_sync_controls_from_document()
	_update_all_ui()
	_set_status("Modification annulee.")


func redo() -> void:
	if _redo_stack.is_empty():
		_set_status("Rien a retablir.")
		return
	_undo_stack.append(document.snapshot())
	var snapshot := _redo_stack.pop_back() as Dictionary
	document.restore_snapshot(snapshot)
	_sync_controls_from_document()
	_update_all_ui()
	_set_status("Modification retablie.")


func _push_undo(snapshot: Dictionary) -> void:
	_undo_stack.append(snapshot.duplicate(true))
	if _undo_stack.size() > HISTORY_LIMIT:
		_undo_stack.pop_front()


func quick_save() -> void:
	_apply_metadata_from_controls()
	var path := ArenaMapSerializer.suggested_map_path(document)
	_save_to_path(path)


func _open_save_dialog() -> void:
	_apply_metadata_from_controls()
	save_dialog.current_file = document.map_id + ".json"
	save_dialog.popup_centered_ratio(0.72)


func _open_load_dialog() -> void:
	open_dialog.popup_centered_ratio(0.72)


func _save_to_path(path: String) -> void:
	_apply_metadata_from_controls()
	var error := ArenaMapSerializer.save_json(document, path)
	if error == OK:
		output_label.text = "Sauvegarde\n%s" % path
		_set_status("Map sauvegardee.")
	else:
		_set_status("Echec sauvegarde : %s" % error_string(error))


func _load_from_path(path: String) -> void:
	var loaded := ArenaMapSerializer.load_json(path)
	if loaded == null:
		_set_status("Impossible de charger %s" % path)
		return
	_configure_document(loaded)
	_center_camera()
	output_label.text = "Chargee\n%s" % path


func export_current_map() -> void:
	_apply_metadata_from_controls()
	_set_status("Export 1920 x 1080 en cours...")
	var result: Dictionary = await _exporter.export_pack(self, document)
	if bool(result.ok):
		output_label.text = "Pack Nano Banana\n%s" % result.directory
		_set_status("Pack exporte : reference, clean, logic, debug, JSON et brief.")
	else:
		_set_status("Echec export : %s" % result.error)


func _toggle_grid() -> void:
	_grid_visible = not _grid_visible
	canvas.set_grid_visible(_grid_visible)
	_set_status("Grille %s" % ("visible" if _grid_visible else "masquee"))


func _center_camera() -> void:
	if canvas == null or camera == null:
		return
	var bounds := canvas.get_map_bounds().grow(110)
	camera.position = bounds.get_center()
	var fit := minf(860.0 / maxf(bounds.size.x, 1.0), 650.0 / maxf(bounds.size.y, 1.0))
	fit = clampf(fit, 0.25, 1.8)
	camera.zoom = Vector2.ONE * fit


func _on_hovered_cell_changed(cell: Vector2i) -> void:
	_last_hovered = cell
	_update_inspector(cell)


func _on_document_changed(cell: Vector2i, _previous: Dictionary, _current: Dictionary) -> void:
	_update_counts()
	if cell == _last_hovered or cell == canvas.selected_cell:
		_update_inspector(cell)


func _update_all_ui() -> void:
	_update_counts()
	_update_inspector(canvas.selected_cell)


func _update_counts() -> void:
	var counts := document.counts()
	counts_label.text = (
		"%d x %d  •  %d dalles\nVOID %d  •  effets %d\nmurs %d  •  speciales %d"
	) % [
		document.grid_size.x, document.grid_size.y, counts.active,
		counts.void, counts.surfaces, counts.walls, counts.specials,
	]


func _update_inspector(cell: Vector2i) -> void:
	if document == null or not document.is_valid_cell(cell):
		inspector_label.text = "Cellule\n—"
		return
	var state := document.get_cell(cell)
	inspector_label.text = (
		"Cellule %d,%d\nSol %s\nEffet %s\nSpecial %s\nMur %s"
	) % [
		cell.x, cell.y,
		ArenaMapDocument.BASE_NAMES[int(state.base)],
		ArenaMapDocument.SURFACE_NAMES[int(state.surface)],
		ArenaMapDocument.SPECIAL_NAMES[int(state.special)],
		ArenaMapDocument.WALL_NAMES[int(state.wall)],
	]


func _set_status(message: String) -> void:
	status_label.text = message
