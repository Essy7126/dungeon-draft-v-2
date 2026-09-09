extends Control

const Clips := preload("res://addons/dungeon_draft_arena_studio/services/sprite_clip_service.gd")
const Preview := preload("res://tools/sprite_workshop/clip_preview.gd")

var document: Dictionary = { }
var document_path := Clips.SOURCE_ROOT + "sentinelle_attack_e.json"
var selected := 0
var elapsed_ms := 0.0
var playing := true
var playback_speed := 1.0
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var saved_fingerprint := ""
var updating := false
var path_input: LineEdit
var frame_list: ItemList
var duration_input: SpinBox
var offset_x: SpinBox
var offset_y: SpinBox
var anchor_x: SpinBox
var anchor_y: SpinBox
var arrival_input: SpinBox
var event_input: LineEdit
var reviewer_input: LineEdit
var note_input: LineEdit
var timeline: HSlider
var status_label: RichTextLabel
var intent_label: Label
var timing_label: Label
var review_label: Label
var play_button: Button
var onion_button: CheckButton
var preview_reference: Control
var preview_original: Control
var preview_candidate: Control
var file_dialog: FileDialog
var confirm_dialog: ConfirmationDialog
var file_action := "open"
var pending_load := ""


func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_window().title = "Dungeon Draft · Atelier de sprites"
	get_window().min_size = Vector2i(1200, 800)
	_build_ui()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--clip="):
			document_path = argument.trim_prefix("--clip=")
	load_clip(document_path)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101923")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var heading := _label(root, "ATELIER DE SPRITES", 25)
	heading.add_theme_color_override("font_color", Color("edbe73"))
	_label(root, "Comparer les dessins • régler le mouvement • conserver les sources", 15)
	var path_row := _row(root)
	path_input = LineEdit.new()
	path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(path_input)
	_button(
		path_row,
		"Charger",
		func() -> void:
			request_load(path_input.text),
	)
	_button(
		path_row,
		"Parcourir…",
		func() -> void:
			choose_file("open"),
	)
	_button(path_row, "Enregistrer", save_clip)
	_button(
		path_row,
		"Copie…",
		func() -> void:
			choose_file("save"),
	)
	_button(path_row, "Exporter la revue", export_review)
	var examples := _row(root)
	_button(
		examples,
		"Sentinelle · attaque",
		func() -> void:
			request_load(Clips.SOURCE_ROOT + "sentinelle_attack_e.json"),
	)
	_button(
		examples,
		"Achille · ruée",
		func() -> void:
			request_load(Clips.SOURCE_ROOT + "achille_dash_e.json"),
	)
	review_label = _label(examples, "Revue visuelle à faire", 14)
	review_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	review_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	intent_label = _label(root, "", 15)
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var work := HBoxContainer.new()
	work.size_flags_vertical = Control.SIZE_EXPAND_FILL
	work.add_theme_constant_override("separation", 14)
	root.add_child(work)
	var sequence := VBoxContainer.new()
	sequence.custom_minimum_size.x = 225
	work.add_child(sequence)
	_label(sequence, "DESSINS DU CANDIDAT", 14)
	frame_list = ItemList.new()
	frame_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_list.custom_minimum_size.y = 150
	frame_list.item_selected.connect(select_frame)
	sequence.add_child(frame_list)
	var order := _row(sequence)
	_button(
		order,
		"↑",
		func() -> void:
			move_frame(-1),
	)
	_button(
		order,
		"↓",
		func() -> void:
			move_frame(1),
	)
	_button(order, "Dupliquer", duplicate_frame)
	_button(order, "−", remove_frame)
	_button(
		sequence,
		"Remplacer par un PNG…",
		func() -> void:
			choose_file("replace"),
	)
	var history := _row(sequence)
	_button(history, "Annuler", undo_edit)
	_button(history, "Rétablir", redo_edit)
	var comparison := VBoxContainer.new()
	comparison.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work.add_child(comparison)
	var stages := HBoxContainer.new()
	stages.add_theme_constant_override("separation", 10)
	stages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	comparison.add_child(stages)
	preview_reference = _preview(stages, "RÉFÉRENCE · repos")
	preview_original = _preview(stages, "ORIGINAL · conservé")
	preview_candidate = _preview(stages, "CANDIDAT · en cours")
	var playback := _row(comparison)
	play_button = _button(playback, "Pause", toggle_playback)
	_button(
		playback,
		"Recommencer",
		func() -> void:
			elapsed_ms = 0.0,
	)
	var speeds := OptionButton.new()
	for text_value in ["Vitesse ×1", "Vitesse ×0,5", "Vitesse ×0,25"]:
		speeds.add_item(text_value)
	speeds.item_selected.connect(
		func(index: int) -> void:
			playback_speed = [1.0, 0.5, 0.25][index],
	)
	playback.add_child(speeds)
	var zooms := OptionButton.new()
	zooms.add_item("Taille jeu")
	zooms.add_item("Agrandir ×2")
	zooms.item_selected.connect(
		func(index: int) -> void:
			for preview in [preview_reference, preview_original, preview_candidate]:
				preview.zoom = 1.0 if index == 0 else 2.0
				preview.queue_redraw(),
	)
	playback.add_child(zooms)
	var onion := CheckButton.new()
	onion_button = onion
	onion.text = "Images voisines"
	onion.toggled.connect(
		func(enabled: bool) -> void:
			preview_candidate.onion = enabled
			preview_candidate.queue_redraw(),
	)
	playback.add_child(onion)
	timeline = HSlider.new()
	timeline.step = 1
	timeline.value_changed.connect(
		func(value: float) -> void:
			if not updating:
				elapsed_ms = value
				playing = false
				play_button.text = "Lire",
	)
	comparison.add_child(timeline)
	timing_label = _label(comparison, "", 14)
	var fields := GridContainer.new()
	fields.columns = 6
	fields.add_theme_constant_override("h_separation", 12)
	root.add_child(fields)
	duration_input = _number(
		fields,
		"Durée pose (ms)",
		1,
		10000,
		func(value: float) -> void:
			edit_frame("duration_ms", value),
	)
	offset_x = _number(
		fields,
		"Décalage X (px)",
		-1024,
		1024,
		func(value: float) -> void:
			edit_offset(0, int(value)),
	)
	offset_y = _number(
		fields,
		"Décalage Y (px)",
		-1024,
		1024,
		func(value: float) -> void:
			edit_offset(1, int(value)),
	)
	anchor_x = _number(
		fields,
		"Ancre sol X (px)",
		0,
		1024,
		func(value: float) -> void:
			edit_anchor(0, int(value)),
	)
	anchor_y = _number(
		fields,
		"Ancre sol Y (px)",
		0,
		1024,
		func(value: float) -> void:
			edit_anchor(1, int(value)),
	)
	arrival_input = _number(fields, "Arrivée simulée (ms)", 1, 10000, edit_arrival)
	var event_row := _row(root)
	_label(event_row, "Événements au début de la pose", 14)
	event_input = LineEdit.new()
	event_input.placeholder_text = "release, impact…"
	event_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_row.add_child(event_input)
	_button(event_row, "Appliquer", edit_events)
	var review := _row(root)
	reviewer_input = LineEdit.new()
	reviewer_input.placeholder_text = "Auteur de la revue"
	reviewer_input.custom_minimum_size.x = 190
	review.add_child(reviewer_input)
	note_input = LineEdit.new()
	note_input.placeholder_text = "Observations à taille jeu : identité, équipement, appuis, geste, transitions…"
	note_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	review.add_child(note_input)
	_button(review, "Valider le visuel", approve_visual)
	status_label = RichTextLabel.new()
	status_label.custom_minimum_size.y = 86
	status_label.scroll_active = true
	root.add_child(status_label)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.file_selected.connect(file_selected)
	add_child(file_dialog)
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Des modifications ne sont pas enregistrées. Les abandonner ?"
	confirm_dialog.confirmed.connect(
		func() -> void:
			if pending_load == "QUIT":
				get_tree().quit()
			else:
				load_clip(pending_load),
	)
	add_child(confirm_dialog)


func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row


func _label(parent: Node, text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _number(
	parent: Node,
	title: String,
	minimum: float,
	maximum: float,
	action: Callable,
) -> SpinBox:
	_label(parent, title, 14)
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = 1
	field.custom_minimum_size.x = 110
	field.value_changed.connect(
		func(value: float) -> void:
			if not updating:
				action.call(value),
	)
	parent.add_child(field)
	return field


func _preview(parent: Node, title: String) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	parent.add_child(column)
	_label(column, title, 14)
	var preview := Preview.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(200, 220)
	column.add_child(preview)
	return preview


func dirty() -> bool:
	return (
		not document.is_empty()
		and JSON.stringify(document, "", true).sha256_text() != saved_fingerprint
	)


func request_load(path: String) -> void:
	if dirty():
		pending_load = path
		confirm_dialog.popup_centered()
	else:
		load_clip(path)


func load_clip(path: String) -> void:
	var result := Clips.read_document(path)
	if not result.ok:
		show_report(result)
		return
	var check := Clips.validate(result.document)
	if not check.ok:
		show_report(check)
		return
	document = result.document
	document_path = path
	saved_fingerprint = JSON.stringify(document, "", true).sha256_text()
	path_input.text = path
	selected = 0
	elapsed_ms = 0
	undo_stack.clear()
	redo_stack.clear()
	rebuild()


func rebuild() -> void:
	if document.is_empty():
		return
	updating = true
	selected = clampi(selected, 0, document.frames.size() - 1)
	frame_list.clear()
	for index in document.frames.size():
		var frame: Dictionary = document.frames[index]
		var markers := PackedStringArray()
		for event in document.events:
			if event.frame == frame.id:
				markers.append(event.name)
		frame_list.add_item(
			"%02d  ·  %s  ·  %.0f ms%s"
			% [
				index + 1,
				frame.id,
				frame.duration_ms,
				"  ◆ " + ", ".join(markers) if not markers.is_empty() else "",
			]
		)
	frame_list.select(selected)
	var cache := { }
	for pair in [[preview_original, document.baseline], [preview_candidate, document]]:
		pair[0].frames.clear()
		for frame in pair[1].frames:
			pair[0].frames.append(
				ImageTexture.create_from_image(Clips.frame_image(frame, document.canvas, cache))
			)
		pair[0].anchor = Vector2(pair[1].anchor[0], pair[1].anchor[1])
		pair[0].display_scale = pair[1].display_scale
	preview_reference.frames.clear()
	if document.has("reference"):
		preview_reference.frames.append(
			ImageTexture.create_from_image(
				Clips.frame_image(document.reference, document.canvas, cache)
			)
		)
	preview_reference.anchor = Vector2(document.baseline.anchor[0], document.baseline.anchor[1])
	preview_reference.display_scale = document.baseline.display_scale
	preview_reference.queue_redraw()
	intent_label.text = str(document.title) + "  —  " + str(document.intent)
	timeline.max_value = maxf(
		Clips.duration(document),
		Clips.duration(document.baseline, _shared_arrival()),
	)
	anchor_x.value = document.anchor[0]
	anchor_y.value = document.anchor[1]
	arrival_input.editable = document.playback.mode == "arrival"
	arrival_input.value = document.playback.get("arrival_preview_ms", 500)
	review_label.text = "Visuel approuvé · combat à vérifier" if Clips.review_current(document) else "Visuel à examiner · combat à vérifier"
	updating = false
	show_frame_fields()
	show_report(Clips.validate(document))


func show_frame_fields() -> void:
	updating = true
	var frame: Dictionary = document.frames[selected]
	duration_input.value = frame.duration_ms
	offset_x.value = frame.offset[0]
	offset_y.value = frame.offset[1]
	var names := PackedStringArray()
	for event in document.events:
		if event.frame == frame.id:
			names.append(event.name)
	event_input.text = ", ".join(names)
	updating = false


func select_frame(index: int) -> void:
	selected = index
	frame_list.select(index)
	playing = false
	play_button.text = "Lire"
	elapsed_ms = 0.0
	for preceding in index:
		elapsed_ms += Clips.frame_duration(document, preceding)
	show_frame_fields()


func _process(delta: float) -> void:
	if document.is_empty():
		return
	if playing:
		elapsed_ms += delta * 1000.0 * playback_speed
		if elapsed_ms > timeline.max_value + 350:
			elapsed_ms = 0.0
	preview_original.frame = Clips.sample(document.baseline, elapsed_ms, _shared_arrival())
	preview_candidate.frame = Clips.sample(document, elapsed_ms)
	preview_original.queue_redraw()
	preview_candidate.queue_redraw()
	updating = true
	timeline.value = elapsed_ms
	updating = false
	timing_label.text = "%d ms  ·  original %d / %d  ·  candidat %d / %d%s" % [
		elapsed_ms,
		preview_original.frame + 1,
		document.baseline.frames.size(),
		preview_candidate.frame + 1,
		document.frames.size(),
		"  ·  arrivée simulée" if document.playback.mode == "arrival" else "",
	]


func _shared_arrival() -> float:
	if document.playback.mode == "arrival" and document.baseline.playback.mode == "arrival":
		return float(document.playback.arrival_preview_ms)
	return -1.0


func toggle_playback() -> void:
	playing = not playing
	play_button.text = "Pause" if playing else "Lire"


func checkpoint() -> void:
	undo_stack.append(document.duplicate(true))
	if undo_stack.size() > 50:
		undo_stack.pop_front()
	redo_stack.clear()


func accept_edit() -> void:
	var report := Clips.validate(document)
	if not report.ok:
		document = undo_stack.pop_back()
		rebuild()
		show_report(report)
		return
	rebuild()
	select_frame(selected)


func edit_frame(key: String, value: Variant) -> void:
	if document.is_empty():
		return
	checkpoint()
	document.frames[selected][key] = value
	accept_edit()


func edit_offset(axis: int, value: int) -> void:
	if document.is_empty():
		return
	var offset: Array = document.frames[selected].offset.duplicate()
	offset[axis] = value
	edit_frame("offset", offset)


func edit_anchor(axis: int, value: int) -> void:
	if document.is_empty():
		return
	checkpoint()
	document.anchor[axis] = value
	accept_edit()


func edit_arrival(value: float) -> void:
	if document.is_empty() or document.playback.mode != "arrival":
		return
	checkpoint()
	document.playback.arrival_preview_ms = value
	accept_edit()


func move_frame(offset: int) -> void:
	if document.is_empty() or selected + offset < 0 or selected + offset >= document.frames.size():
		return
	checkpoint()
	var frame: Dictionary = document.frames.pop_at(selected)
	selected += offset
	document.frames.insert(selected, frame)
	accept_edit()


func duplicate_frame() -> void:
	if document.is_empty():
		return
	checkpoint()
	var frame: Dictionary = document.frames[selected].duplicate(true)
	var ids: Array = document.frames.map(
		func(item: Dictionary) -> String:
			return item.id,
	)
	var suffix := 1
	while ("pose_%03d" % suffix) in ids:
		suffix += 1
	frame.id = "pose_%03d" % suffix
	selected += 1
	document.frames.insert(selected, frame)
	accept_edit()


func remove_frame() -> void:
	if document.is_empty() or document.frames.size() <= 1:
		return
	var frame_id: String = document.frames[selected].id
	for event in document.events:
		if event.frame == frame_id:
			show_report(
				Clips.failure(
					"Déplacer ou supprimer les événements de cette pose avant de la retirer."
				)
			)
			return
	checkpoint()
	document.frames.remove_at(selected)
	accept_edit()


func edit_events() -> void:
	if document.is_empty():
		return
	checkpoint()
	var frame_id: String = document.frames[selected].id
	document.events = document.events.filter(
		func(event: Dictionary) -> bool:
			return event.frame != frame_id,
	)
	for name_value in event_input.text.split(",", false):
		var event_name := name_value.strip_edges()
		if not event_name.is_empty():
			document.events.append({ "name": event_name, "frame": frame_id })
	accept_edit()


func undo_edit() -> void:
	if not undo_stack.is_empty():
		redo_stack.append(document.duplicate(true))
		document = undo_stack.pop_back()
		rebuild()


func redo_edit() -> void:
	if not redo_stack.is_empty():
		undo_stack.append(document.duplicate(true))
		document = redo_stack.pop_back()
		rebuild()


func choose_file(action: String) -> void:
	file_action = action
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if action == "save" else FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = (
		PackedStringArray(["*.png ; Dessin PNG normalisé"])
		if action == "replace"
		else PackedStringArray(["*.json ; Clip de sprites"])
	)
	file_dialog.current_dir = "res://art/source/" if action == "replace" else Clips.SOURCE_ROOT
	file_dialog.show_hidden_files = true
	file_dialog.popup_centered_ratio(0.75)


func file_selected(path: String) -> void:
	match file_action:
		"open":
			request_load(path)
		"save":
			if document.is_empty():
				return
			var copy := document.duplicate(true)
			copy.id = path.get_file().get_basename()
			var result := Clips.validate(copy)
			if result.ok:
				result = Clips.write_json(path, copy)
			show_report(result)
			if result.ok:
				load_clip(path)
		"replace":
			if document.is_empty() or not Clips.project_path(path):
				return
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			if image == null or image.get_size() != Vector2i(document.canvas[0], document.canvas[1]):
				show_report(
					Clips.failure(
						"Choisir un PNG normalisé au canevas %s, sans redimensionnement automatique."
						% str(document.canvas)
					)
				)
				return
			checkpoint()
			var frame: Dictionary = document.frames[selected]
			frame.source = path
			frame.sha256 = FileAccess.get_sha256(path)
			frame.region = [0, 0, image.get_width(), image.get_height()]
			frame.placement = [0, 0]
			frame.offset = [0, 0]
			accept_edit()


func save_clip() -> void:
	if document.is_empty():
		return
	var result := Clips.validate(document)
	if result.ok:
		result = Clips.write_json(document_path, document)
	if result.ok:
		saved_fingerprint = JSON.stringify(document, "", true).sha256_text()
	show_report(result)


func export_review() -> void:
	if not document.is_empty():
		show_report(Clips.export_clip(document))


func approve_visual() -> void:
	if document.is_empty():
		return
	checkpoint()
	var result := Clips.approve_visual(document, reviewer_input.text, note_input.text)
	if not result.ok:
		undo_stack.pop_back()
	else:
		rebuild()
	show_report(result)


func show_report(report: Dictionary) -> void:
	var lines := PackedStringArray()
	lines.append("Contrôle terminé." if report.ok else "Correction nécessaire :")
	for error in report.get("errors", []):
		lines.append(str(error))
	for warning in report.get("warnings", []):
		lines.append(str(warning))
	for question in report.get("open_questions", []):
		lines.append("À tester : " + str(question))
	if report.has("directory"):
		lines.append("Export : " + str(report.directory))
	if report.has("path"):
		lines.append("Enregistré : " + str(report.path))
	status_label.text = "\n".join(lines)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if dirty():
			pending_load = "QUIT"
			confirm_dialog.popup_centered()
		else:
			get_tree().quit()
