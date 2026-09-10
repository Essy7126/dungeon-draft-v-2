@tool
class_name PaintedHaltStudio
extends Control

signal history_state_changed

const Service := preload(
	"res://addons/dungeon_draft_arena_studio/halts/services/painted_halt_manifest_service.gd"
)
const DEFAULT_MAP := "res://data/halts/emerald_sanctuary_v1.json"
const RECOVERY_DIR := "user://dungeon_draft/painted_halts"

var document := PaintedHaltDocument.new()
var canvas: PaintedHaltCanvas
var auto_load := true
var catalog: OptionButton
var shape_list: ItemList
var inspector: VBoxContainer
var status: Label
var help: Label
var undo_button: Button
var redo_button: Button
var preview_overlay: PanelContainer
var preview_runtime: Node
var _effect_timer: Timer
var _recovery_timer: Timer
var _source_dialog: FileDialog
var _new_dialog: ConfirmationDialog
var _new_id: LineEdit
var _new_title: LineEdit
var _new_kind: OptionButton
var _copy_geometry: CheckBox
var _image: Image
var _refreshing := false
var _editing_field := false
var _refreshing_inspector := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	# The shared shell restores UI state before a map is opened.
	canvas.set_document(document)
	document.changed.connect(_on_document_changed)
	document.history.history_changed.connect(_on_history_changed)
	_recovery_timer = Timer.new()
	_recovery_timer.one_shot = true
	_recovery_timer.wait_time = 0.5
	_recovery_timer.timeout.connect(_flush_recovery)
	add_child(_recovery_timer)
	_effect_timer = Timer.new()
	_effect_timer.one_shot = true
	_effect_timer.wait_time = 0.4
	_effect_timer.timeout.connect(_refresh_material_preview)
	add_child(_effect_timer)
	_refresh_catalog()
	if auto_load:
		open_manifest(DEFAULT_MAP)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("142329")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 9)
	margin.add_child(root)
	var heading := HBoxContainer.new()
	root.add_child(heading)
	var title := Label.new()
	title.text = "HALTES PEINTES"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("d7ca9b"))
	heading.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "  Planifier  →  Illustrer  →  Calibrer  →  Explorer"
	subtitle.add_theme_color_override("font_color", Color("91aeb3"))
	heading.add_child(subtitle)
	var toolbar := HFlowContainer.new()
	root.add_child(toolbar)
	catalog = OptionButton.new()
	catalog.custom_minimum_size.x = 265
	catalog.item_selected.connect(
		func(index):
			open_manifest(str(catalog.get_item_metadata(index))),
	)
	toolbar.add_child(catalog)
	_button(toolbar, "Nouveau plan / version", _show_new_dialog)
	_button(
		toolbar,
		"Joindre l’original…",
		func():
			_source_dialog.popup_centered_ratio(0.7),
	)
	_button(toolbar, "Exporter le plan", export_spatial_plan)
	_button(toolbar, "Enregistrer / préparer", save_document)
	_button(toolbar, "▶ Explorer", play_preview)
	undo_button = _button(toolbar, "↶", history_undo)
	redo_button = _button(toolbar, "↷", history_redo)
	var content := HSplitContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.split_offset = 208
	root.add_child(content)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 185
	content.add_child(left)
	_label(left, "CALQUES", Color("91aeb3"))
	canvas = PaintedHaltCanvas.new()
	for index in PaintedHaltDocument.LAYERS.size():
		var row := HBoxContainer.new()
		left.add_child(row)
		var visibility := CheckBox.new()
		visibility.button_pressed = true
		visibility.tooltip_text = "Afficher ce calque"
		var layer: String = PaintedHaltDocument.LAYERS[index]
		visibility.toggled.connect(
			func(value):
				canvas.visible_layers[layer] = value
				canvas.queue_redraw(),
		)
		row.add_child(visibility)
		var select := _button(
			row,
			PaintedHaltDocument.LABELS[index],
			func():
				if document.manifest.is_empty():
					return
				canvas.set_layer(layer)
				_refresh_selection(),
		)
		select.flat = true
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select.alignment = HORIZONTAL_ALIGNMENT_LEFT
		select.add_theme_color_override("font_color", PaintedHaltCanvas.COLORS[index])
	_label(left, "ZONES DU CALQUE", Color("91aeb3"))
	shape_list = ItemList.new()
	shape_list.custom_minimum_size.y = 105
	shape_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shape_list.item_selected.connect(
		func(index):
			canvas.selected_shape = index
			canvas.selected_vertex = -1
			canvas.queue_redraw()
			_refresh_inspector(),
	)
	left.add_child(shape_list)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(center)
	var tools := HFlowContainer.new()
	center.add_child(tools)
	_button(
		tools,
		"+ Dessiner / placer",
		func():
			if not document.manifest.is_empty():
				canvas.begin_shape(),
	)
	_button(
		tools,
		"Terminer",
		func():
			canvas.finish_shape(),
	)
	_button(
		tools,
		"Supprimer",
		func():
			canvas.delete_selection(),
	)
	_button(
		tools,
		"Cadrer",
		func():
			canvas.fit(),
	)
	var art := CheckBox.new()
	art.text = "Illustration"
	art.button_pressed = true
	art.toggled.connect(
		func(value):
			canvas.show_art = value
			canvas.queue_redraw(),
	)
	tools.add_child(art)
	var effects := CheckBox.new()
	effects.text = "Animer les matières"
	effects.button_pressed = true
	effects.toggled.connect(
		func(value):
			canvas.set_effects_enabled(value),
	)
	tools.add_child(effects)
	var scale_guide := CheckBox.new()
	scale_guide.text = "Repère Achille"
	scale_guide.button_pressed = true
	scale_guide.toggled.connect(
		func(value):
			canvas.show_scale_reference = value
			canvas.queue_redraw(),
	)
	tools.add_child(scale_guide)
	var center_split := HSplitContainer.new()
	center_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(center_split)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.selection_changed.connect(_refresh_selection)
	canvas.help_changed.connect(
		func(value):
			help.text = value,
	)
	center_split.add_child(canvas)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 235
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center_split.add_child(scroll)
	inspector = VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 8)
	scroll.add_child(inspector)
	help = _label(
		root,
		"Glisser un sommet · Double clic sur une arête : insérer · Suppr : retirer · Molette : zoom · Clic milieu : déplacer",
		Color("91aeb3"),
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status = _label(root, "Choisir une halte ou créer son plan.", Color("c7d8d6"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_source_dialog = FileDialog.new()
	_source_dialog.title = "Joindre l’image originale à cette nouvelle version"
	_source_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_source_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_source_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Images"])
	_source_dialog.file_selected.connect(attach_original)
	add_child(_source_dialog)
	_build_new_dialog()


func _button(parent: Node, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _label(parent: Node, text_value: String, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _refresh_catalog(selected_path := "") -> void:
	catalog.clear()
	for entry: Dictionary in Service.list_maps():
		catalog.add_item(str(entry.title))
		catalog.set_item_metadata(catalog.item_count - 1, str(entry.path))
		if str(entry.path) == selected_path:
			catalog.select(catalog.item_count - 1)


func open_manifest(path: String) -> bool:
	if document.is_dirty() and not _flush_recovery().ok:
		return false
	canvas.cancel_gesture()
	var result := Service.load_manifest(path)
	if not result.ok:
		_report(result)
		return false
	_refreshing = true
	document.load_working_copy(result.manifest, path, str(result.get("manifest_sha256", "")))
	_image = result.get("source_image")
	canvas.set_document(document, _image)
	_refreshing = false
	var recovered := false
	var recovery_path := _recovery_path(path)
	if FileAccess.file_exists(recovery_path):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(recovery_path))
		if raw is Dictionary and raw.get("manifest") is Dictionary and str(raw.get("path")) == path:
			var before := document.manifest.duplicate(true)
			document.manifest = raw.manifest.duplicate(true)
			document.source_hash = str(raw.get("source_hash", document.source_hash))
			document.commit(before, "Restaurer le travail en cours")
			recovered = true
	_effect_timer.start()
	_refresh_catalog(path)
	_refresh_selection()
	_on_history_changed()
	_set_status(
		"Travail en cours restauré. Enregistrer vérifie que la source n’a pas changé." if recovered else "Version chargée · Les changements restent dans la copie de travail jusqu’à Enregistrer."
	)
	return true


func _on_document_changed() -> void:
	if _refreshing:
		return
	if not _editing_field:
		_refresh_selection()
	_on_history_changed()
	if _recovery_timer != null and is_inside_tree():
		_recovery_timer.start()
	if _effect_timer != null and is_inside_tree():
		_effect_timer.start()


func _on_history_changed() -> void:
	if undo_button != null:
		undo_button.disabled = not history_can_undo()
		redo_button.disabled = not history_can_redo()
	history_state_changed.emit()


func _refresh_selection() -> void:
	if shape_list == null or document.manifest.is_empty():
		return
	shape_list.clear()
	for index in document.shapes(canvas.layer).size():
		var entry: Variant = document.shapes(canvas.layer)[index]
		var name_value := "%s %d" % [
			PaintedHaltDocument.LABELS[PaintedHaltDocument.LAYERS.find(canvas.layer)],
			index + 1,
		]
		if entry is Dictionary:
			name_value = str(entry.get("title", entry.get("id", name_value)))
		shape_list.add_item(name_value)
	if canvas.selected_shape >= 0 and canvas.selected_shape < shape_list.item_count:
		shape_list.select(canvas.selected_shape)
	_refresh_inspector()


func _refresh_inspector() -> void:
	_refreshing_inspector = true
	for child in inspector.get_children():
		inspector.remove_child(child)
		child.queue_free()
	if document.manifest.is_empty():
		_refreshing_inspector = false
		return
	_label(inspector, "VERSION", Color("d7ca9b"))
	_label(inspector, str(document.manifest.get("id", "")), Color("91aeb3"))
	_text_field("Titre", ["title"], str(document.manifest.get("title", "")))
	_number_field(
		"Largeur du monde",
		["world", "width"],
		float(document.manifest.get("world", { }).get("width", 2200)),
		640,
		8000,
		20,
	)
	_label(inspector, "Hauteur d’Achille / image", Color("91aeb3"))
	var height_field := SpinBox.new()
	height_field.name = "PlayerHeightPercent"
	var height_percent: float = canvas.ScaleReference.height_ratio(document.manifest) * 100
	var legacy_out_of_range: bool = (
		not document.manifest.world.has("player_height_ratio") and (
			height_percent < 6 or height_percent > 35
		)
	)
	height_field.min_value = minf(6, height_percent) if legacy_out_of_range else 6
	height_field.max_value = maxf(35, height_percent) if legacy_out_of_range else 35
	height_field.editable = not legacy_out_of_range
	height_field.step = 0.1
	height_field.suffix = " %"
	height_field.value = height_percent
	height_field.tooltip_text = "Pieds au sommet de la silhouette (lance comprise), indépendant du zoom et de la largeur du monde. Alt+clic place le repère près d’un objet."
	height_field.value_changed.connect(
		func(value):
			_commit_field(["world", "player_height_ratio"], value / 100),
	)
	inspector.add_child(height_field)
	if legacy_out_of_range:
		_label(inspector, "Échelle historique conservée", Color("91aeb3"))
		_button(
			inspector,
			"Recalibrer l’échelle",
			func():
				document.set_property(["world", "player_height_ratio"], 0.22),
		)
	_number_field(
		"Marge des pieds",
		["world", "foot_clearance"],
		float(document.manifest.get("world", { }).get("foot_clearance", 12)),
		0,
		100,
		1,
	)
	_number_field(
		"Vitesse d’Achille",
		["world", "speed"],
		float(document.manifest.get("world", { }).get("speed", 195)),
		40,
		500,
		5,
	)
	var layer := canvas.layer
	var index := canvas.selected_shape
	if index < 0 or index >= document.shapes(layer).size():
		_refreshing_inspector = false
		return
	_label(
		inspector,
		PaintedHaltDocument.LABELS[PaintedHaltDocument.LAYERS.find(layer)].to_upper(),
		Color("d7ca9b"),
	)
	var entry: Variant = document.shapes(layer)[index]
	if layer == "landmarks":
		_text_field("Identifiant", [layer, index, "id"], str(entry.get("id", "")))
		_text_field("Nom du lieu", [layer, index, "title"], str(entry.get("title", "")))
		var kind := OptionButton.new()
		for item in ["dialogue", "sanctuary", "merchant", "rest", "exit"]:
			kind.add_item(item)
		var selected := ["dialogue", "sanctuary", "merchant", "rest", "exit"].find(
			str(entry.get("action", "dialogue"))
		)
		kind.select(maxi(selected, 0))
		kind.item_selected.connect(
			func(item):
				_commit_field([layer, index, "action"], kind.get_item_text(item)),
		)
		inspector.add_child(kind)
		_text_field(
			"Texte du lieu",
			[layer, index, "description"],
			str(entry.get("description", "")),
		)
		_number_field(
			"Portée de clic",
			[layer, index, "radius"],
			float(entry.get("radius", 0.045)),
			0.005,
			0.2,
			0.005,
		)
		var focus: Array = entry.get("focus", entry.point)
		_number_field(
			"Objet : position X",
			[layer, index, "focus", 0],
			float(focus[0]),
			0,
			1,
			0.005,
		)
		_number_field(
			"Objet : position Y",
			[layer, index, "focus", 1],
			float(focus[1]),
			0,
			1,
			0.005,
		)
		var interaction_note := _label(
			inspector,
			"Cercle : point d’approche au sol.\nCroix : objet cliquable dans le décor.",
			Color("91aeb3"),
		)
		interaction_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif layer == "torches":
		_number_field(
			"Flamme",
			[layer, index, "flame_strength"],
			float(entry.get("flame_strength", 1.0)),
			0,
			2,
			0.05,
		)
		_number_field(
			"Lumière",
			[layer, index, "light_strength"],
			float(entry.get("light_strength", 1.0)),
			0,
			2,
			0.05,
		)
		_number_field(
			"Fumée",
			[layer, index, "smoke_strength"],
			float(entry.get("smoke_strength", 1.0)),
			0,
			2,
			0.05,
		)
		_number_field(
			"Rayon horizontal",
			[layer, index, "radius", 0],
			float(entry.radius[0]),
			0.001,
			0.08,
			0.001,
		)
		_number_field(
			"Rayon vertical",
			[layer, index, "radius", 1],
			float(entry.radius[1]),
			0.001,
			0.12,
			0.001,
		)
	elif layer == "cascades":
		_number_field(
			"Projection (pixels)",
			[layer, index, "width"],
			float(entry.get("width", 20)),
			1,
			120,
			1,
		)
		_label(inspector, "Croix blanche : impact de l’eau", Color("91aeb3"))
	elif layer == "foreground":
		var note := _label(
			inspector,
			"Croix blanche : pied du volume.\nAchille passe derrière au-dessus\nde cette ligne de profondeur.",
			Color("91aeb3"),
		)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif layer == "water":
		_label(inspector, "Teinte de l’eau", Color("91aeb3"))
		var tint := ColorPickerButton.new()
		tint.color = Color(str(document.manifest.water.get("tint", "#48d896")))
		tint.edit_alpha = false
		tint.color_changed.connect(
			func(value):
				_commit_field(["water", "tint"], "#" + value.to_html(false)),
		)
		inspector.add_child(tint)
		var regions: Array = document.manifest.get("water", { }).get("regions", [])
		var region_index := document.water_region_index(index)
		if region_index >= 0:
			_number_field(
				"Courant horizontal",
				["water", "regions", region_index, "direction", 0],
				float(regions[region_index].get("direction", [1, 0])[0]),
				-1,
				1,
				0.05,
			)
			_number_field(
				"Courant vertical",
				["water", "regions", region_index, "direction", 1],
				float(regions[region_index].get("direction", [1, 0])[1]),
				-1,
				1,
				0.05,
			)
			_number_field(
				"Vitesse du courant",
				["water", "regions", region_index, "speed"],
				float(regions[region_index].get("speed", 1)),
				0,
				3,
				0.05,
			)
		else:
			_button(
				inspector,
				"Définir un courant ici",
				func():
					document.create_water_region(index),
			)
	_refreshing_inspector = false


func _commit_field(path: Array, value: Variant) -> void:
	if _refreshing_inspector or _refreshing:
		return
	_editing_field = true
	if (
		path.size() >= 4 and path[0] == "landmarks" and path[2] == "focus"
		and not document.shapes("landmarks")[path[1]].has("focus")
	):
		var before := document.manifest.duplicate(true)
		document.shapes("landmarks")[path[1]].focus = document.shapes("landmarks")[path[1]] \
				.point \
				.duplicate()
		document.shapes("landmarks")[path[1]].focus[path[3]] = value
		document.commit(before, "Déplacer le point d’interaction")
	else:
		document.set_property(path, value)
	_editing_field = false


func _text_field(label: String, path: Array, value: String) -> void:
	_label(inspector, label, Color("91aeb3"))
	var field := LineEdit.new()
	field.text = value
	field.text_submitted.connect(
		func(text_value):
			_commit_field(path, text_value),
	)
	field.focus_exited.connect(
		func():
			if is_instance_valid(field) and field.text != value:
				_commit_field(path, field.text),
	)
	inspector.add_child(field)


func _number_field(
	label: String,
	path: Array,
	value: float,
	low: float,
	high: float,
	step: float,
) -> void:
	_label(inspector, label, Color("91aeb3"))
	var field := SpinBox.new()
	field.min_value = low
	field.max_value = high
	field.step = step
	field.value = value
	field.value_changed.connect(
		func(next):
			_commit_field(path, next),
	)
	inspector.add_child(field)


func save_document() -> bool:
	if document.manifest.is_empty():
		return false
	canvas.cancel_gesture()
	var manifest := document.manifest.duplicate(true)
	var result: Dictionary
	if str(manifest.get("source", { }).get("image", "")).is_empty():
		result = Service.save_plan(document.source_path, manifest, document.source_hash)
	else:
		manifest.stage = "playable_study"
		result = Service.save_and_prepare(document.source_path, manifest, document.source_hash)
	if not result.ok:
		_report(result)
		return false
	document.manifest = manifest
	document.source_hash = str(
		result.get("manifest_sha256", Service.manifest_hash(document.source_path))
	)
	document.history.set_saved_fingerprint(document.fingerprint())
	_flush_recovery()
	_set_status(
		"Version enregistrée et masques préparés." if manifest.stage == "playable_study" else "Plan enregistré. Exportez-le pour guider l’illustration."
	)
	return true


func validate_document() -> bool:
	var result := Service.validate(document.manifest, true)
	_report(result, "Structure et coordonnées valides. Explorer permet de vérifier les trajets.")
	return bool(result.ok)


func play_preview() -> void:
	if document.manifest.is_empty():
		return
	canvas.cancel_gesture()
	var definition := document.manifest.duplicate(true)
	definition.stage = "playable_study"
	var checked := Service.validate(definition)
	if not checked.ok:
		_report(checked)
		return
	if Engine.is_editor_hint():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RECOVERY_DIR))
		var snapshot := RECOVERY_DIR.path_join("preview_%s.json" % Time.get_ticks_usec())
		var file := FileAccess.open(snapshot, FileAccess.WRITE)
		if file == null:
			_set_status("Impossible de préparer l’aperçu isolé.", true)
			return
		file.store_string(JSON.stringify(definition, "  "))
		file.close()
		var pid := OS.create_process(
			OS.get_executable_path(),
			PackedStringArray(
				[
					"--path",
					ProjectSettings.globalize_path("res://"),
					"res://addons/dungeon_draft_arena_studio/halts/HaltePreview.tscn",
					"--",
					"--halt-preview-draft=" + ProjectSettings.globalize_path(snapshot),
				]
			),
		)
		_set_status(
			"Aperçu lancé avec votre copie de travail." if pid > 0 else "Le processus d’aperçu n’a pas pu démarrer.",
			pid <= 0,
		)
		return
	var prepared := Service.prepare_images(definition)
	if not prepared.ok:
		_report(prepared)
		return
	close_preview()
	preview_overlay = PanelContainer.new()
	preview_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_overlay.z_index = 30
	add_child(preview_overlay)
	var column := VBoxContainer.new()
	preview_overlay.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	_label(bar, "APERÇU DE LA COPIE DE TRAVAIL · Cliquer pour marcher / interagir")
	_button(bar, "Retour à la calibration", close_preview)
	var preview_area := Control.new()
	preview_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(preview_area)
	var container := SubViewportContainer.new()
	container.size = Vector2(1280, 720)
	preview_area.add_child(container)
	var fit_preview := func():
		var factor := minf(preview_area.size.x / 1280.0, preview_area.size.y / 720.0)
		container.scale = Vector2.ONE * maxf(factor, 0.01)
		container.position = (preview_area.size - Vector2(1280, 720) * factor) * 0.5
	preview_area.resized.connect(fit_preview)
	fit_preview.call_deferred()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.handle_input_locally = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var runtime = load("res://hub/painted_halt/living_halt.gd").new()
	runtime.definition_override = definition
	runtime.preview_materials = prepared.materials
	runtime.preview_flow = prepared.flow
	runtime.preview_mode = true
	preview_runtime = runtime
	viewport.add_child(runtime)


func close_preview() -> void:
	if is_instance_valid(preview_overlay):
		remove_child(preview_overlay)
		preview_overlay.queue_free()
	preview_overlay = null
	preview_runtime = null


func _build_new_dialog() -> void:
	_new_dialog = ConfirmationDialog.new()
	_new_dialog.title = "Plan de halte · Nouvelle version explicite"
	_new_dialog.ok_button_text = "Créer le plan"
	_new_dialog.dialog_hide_on_ok = false
	add_child(_new_dialog)
	var form := VBoxContainer.new()
	form.custom_minimum_size.x = 430
	_new_dialog.add_child(form)
	_label(form, "Identifiant inédit, par exemple forge_bronze_v2")
	_new_id = LineEdit.new()
	_new_id.placeholder_text = "ma_halte_v1"
	form.add_child(_new_id)
	_label(form, "Titre du lieu")
	_new_title = LineEdit.new()
	form.add_child(_new_title)
	_new_kind = OptionButton.new()
	for kind in ["sanctuary", "forge", "merchant", "hub", "lore"]:
		_new_kind.add_item(kind)
	form.add_child(_new_kind)
	_copy_geometry = CheckBox.new()
	_copy_geometry.text = "Reprendre les zones du document actuel"
	form.add_child(_copy_geometry)
	_label(
		form,
		"L’original existant reste versionné.\nJoignez ensuite l’image à cette nouvelle version.",
		Color("91aeb3"),
	)
	_new_dialog.confirmed.connect(_create_new_plan)


func _show_new_dialog() -> void:
	_copy_geometry.disabled = document.manifest.is_empty()
	_new_dialog.popup_centered()


func _create_new_plan() -> void:
	if document.is_dirty() and not _flush_recovery().ok:
		return
	var result := Service.create_plan(
		_new_id.text.strip_edges(),
		_new_title.text.strip_edges(),
		_new_kind.get_item_text(_new_kind.selected),
	)
	if not result.ok:
		_report(result)
		return
	if _copy_geometry.button_pressed and not document.manifest.is_empty():
		var next: Dictionary = result.manifest
		for field in [
			"world",
			"navigation",
			"landmarks",
			"water",
			"cascades",
			"torches",
			"foliage",
			"bounce",
			"foreground",
			"mist",
			"review",
		]:
			if document.manifest.has(field):
				next[field] = (
					document.manifest[field].duplicate(true)
					if (document.manifest[field] is Dictionary or document.manifest[field] is Array)
					else document.manifest[field]
				)
		result = Service.save_plan(str(result.path), next, str(result.manifest_sha256))
		if not result.ok:
			_report(result)
			return
	_new_dialog.hide()
	open_manifest(str(result.path))
	_set_status(
		"Nouveau plan créé. Dessinez les allées et les accès, puis exportez le plan avant d’illustrer."
	)


func attach_original(image_path: String) -> bool:
	if document.manifest.is_empty():
		return false
	var result := Service.attach_source(
		document.source_path,
		document.manifest,
		image_path,
		document.source_hash,
	)
	if not result.ok:
		_report(result)
		return false
	# Attached source is a committed new calibration; obsolete recovery must not shadow it.
	document.history.set_saved_fingerprint(document.fingerprint())
	_remove_recovery()
	open_manifest(document.source_path)
	_set_status("Original conservé sans retouche. Calibrez les zones puis préparez cette version.")
	return true


func export_spatial_plan() -> void:
	if document.manifest.is_empty():
		return
	var path := "res://art/source/halts/%s/spatial_plan.svg" % str(document.manifest.id)
	var result := Service.export_plan(document.manifest, path)
	if bool(result.ok):
		document.set_property(["spatial_plan"], path)
	_report(result, "Plan exporté : %s" % path)
	if bool(result.ok) and not DisplayServer.get_name() == "headless":
		OS.shell_open(ProjectSettings.globalize_path(path))


func _recovery_path(path: String) -> String:
	return RECOVERY_DIR.path_join(path.sha256_text() + ".json")


func _remove_recovery() -> void:
	var path := _recovery_path(document.source_path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _flush_recovery() -> Dictionary:
	if document.source_path.is_empty():
		return { "ok": true }
	if not document.is_dirty():
		_remove_recovery()
		return { "ok": true }
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(RECOVERY_DIR)
	)
	if directory_error != OK:
		return { "ok": false }
	var path := _recovery_path(document.source_path)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		_set_status(
			"La copie de récupération n’a pas pu être écrite. Conservez l’éditeur ouvert.",
			true,
		)
		return { "ok": false }
	file.store_string(
		JSON.stringify(
			{
				"path": document.source_path,
				"source_hash": document.source_hash,
				"manifest": document.manifest,
			},
			"  ",
		)
	)
	file.close()
	var error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(path + ".tmp"),
		ProjectSettings.globalize_path(path),
	)
	if error != OK:
		_set_status("La copie de récupération n’a pas pu être installée.", true)
	return { "ok": error == OK }


func prepare_for_close() -> Dictionary:
	canvas.cancel_gesture()
	close_preview()
	return _flush_recovery()


func _exit_tree() -> void:
	if canvas != null:
		canvas.cancel_gesture()
	_flush_recovery()


func _notification(what: int) -> void:
	# Detaching the Studio reparents this control: exit_tree must preserve history.
	if what == NOTIFICATION_PREDELETE and document != null:
		if document.history.history_changed.is_connected(_on_history_changed):
			document.history.history_changed.disconnect(_on_history_changed)
		document.history.clear()
		document.history.configure(Callable(), Callable())
		if is_instance_valid(document.history.undo_redo):
			document.history.undo_redo.free()


func _report(result: Dictionary, success := "") -> void:
	_set_status(
		(
			success
			if bool(result.get("ok", false))
			else " · ".join(result.get("errors", ["Opération impossible."]))
		),
		not bool(result.get("ok", false)),
	)


func _set_status(text_value: String, error := false) -> void:
	if status == null:
		return
	status.text = text_value
	status.add_theme_color_override("font_color", Color("ffae93") if error else Color("c7d8d6"))


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or preview_overlay != null:
		return
	if event is InputEventKey and event.pressed and event.is_command_or_control_pressed():
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		match event.keycode:
			KEY_Z:
				if event.shift_pressed:
					history_redo()
				else:
					history_undo()
			KEY_Y:
				history_redo()
			KEY_S:
				save_document()
			_:
				return
		get_viewport().set_input_as_handled()


func history_can_undo() -> bool:
	return document.history.can_undo()


func history_can_redo() -> bool:
	return document.history.can_redo()


func history_undo() -> void:
	canvas.cancel_gesture()
	document.history.undo()
	_on_history_changed()


func history_redo() -> void:
	canvas.cancel_gesture()
	document.history.redo()
	_on_history_changed()


func history_undo_name() -> String:
	return document.history.get_undo_action_name()


func history_redo_name() -> String:
	return document.history.get_redo_action_name()


func history_document_name() -> String:
	return str(document.manifest.get("title", "Aucune halte"))


func history_current_index() -> int:
	return document.history.get_current_index()


func history_entries() -> Array[Dictionary]:
	return document.history.get_history_entries()


func history_jump_to(index: int) -> void:
	document.history.jump_to(index)


func history_is_at_saved_state() -> bool:
	return not document.is_dirty()


func get_state_snapshot() -> Dictionary:
	return { "path": document.source_path, "layer": canvas.layer }


func apply_state_snapshot(state: Dictionary) -> void:
	if not str(state.get("path", "")).is_empty():
		open_manifest(str(state.path))
	if str(state.get("layer", "outline")) in PaintedHaltDocument.LAYERS:
		canvas.set_layer(str(state.get("layer", "outline")))


func _refresh_material_preview() -> void:
	if _image == null or _image.is_empty() or document.manifest.is_empty():
		return
	var definition := document.manifest.duplicate(true)
	definition.stage = "playable_study"
	var prepared := Service.prepare_images(definition)
	if bool(prepared.get("ok", false)):
		canvas.update_material_preview(definition, prepared)
