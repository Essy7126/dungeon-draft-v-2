extends Control
const Catalog = preload("res://tools/run_explorer/route_explorer_catalog.gd")
var route := Catalog.AuditRoute.new()
var selected: Dictionary = { }
var description: Dictionary = { }
var seed_field: SpinBox
var destinations: OptionButton
var canvas: ExpeditionMapCanvas
var map_host: Control
var preview: TextureRect
var floor_preview: FloorPreview
var heading: Label
var details: RichTextLabel
var status: Label
var play_button: Button
var art_button: Button
var da_button: Button
var node_ids: Array[String] = []
var last_launch_output := ""
var show_floor := false
var aftermath_button: Button


class FloorPreview extends Control:
	var cells: Array = []


	func _draw() -> void:
		if cells.is_empty():
			return
		var bounds := Rect2()
		var points: Array[Vector2] = []
		for cell in cells:
			var p := Vector2(
				float(cell[0]) - float(cell[1]),
				(float(cell[0]) + float(cell[1])) * 0.5,
			)
			points.append(p)
			bounds = Rect2(p, Vector2.ZERO) if points.size() == 1 else bounds.expand(p)
		bounds = bounds.grow(1.2)
		var scale_value := minf(size.x / bounds.size.x, size.y / bounds.size.y)
		var offset := (size - bounds.size * scale_value) * 0.5 - bounds.position * scale_value
		for point in points:
			var p := offset + point * scale_value
			draw_colored_polygon(
				PackedVector2Array(
					[
						p + Vector2(0, -0.46) * scale_value,
						p + Vector2(0.92, 0) * scale_value,
						p + Vector2(0, 0.46) * scale_value,
						p + Vector2(-0.92, 0) * scale_value,
					]
				),
				Color("a5b7b4"),
			)


func _ready() -> void:
	get_window().title = "Catabase — Explorateur de run"
	var background := ColorRect.new()
	background.color = Color("161c20")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var title := Label.new()
	title.text = "EXPLORATEUR DE RUN"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(title)
	var seed_label := Label.new()
	seed_label.text = "Graine"
	top.add_child(seed_label)
	seed_field = SpinBox.new()
	seed_field.max_value = 2147483647
	seed_field.value = 2401
	seed_field.custom_minimum_size.x = 130
	top.add_child(seed_field)
	_button(top, "Actualiser", refresh)
	_button(
		top,
		"Entrée des Enfers",
		func():
			select_destination("entry"),
	)
	destinations = OptionButton.new()
	destinations.size_flags_horizontal = SIZE_EXPAND_FILL
	destinations.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	destinations.item_selected.connect(
		func(index: int):
			select_destination(node_ids[index]),
	)
	root.add_child(destinations)
	var split := HSplitContainer.new()
	split.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(split)
	map_host = Control.new()
	map_host.custom_minimum_size = Vector2(580, 450)
	map_host.size_flags_horizontal = SIZE_EXPAND_FILL
	split.add_child(map_host)
	canvas = ExpeditionMapCanvas.new()
	canvas.subtitle_text = "Audit : vingt étapes, toutes les branches et tous les secrets."
	canvas.footer_text = "Sélectionnez une destination pour voir son décor et la jouer."
	canvas.name = "ExplorerRouteMap"
	canvas.node_selected.connect(select_destination)
	map_host.add_child(canvas)
	map_host.resized.connect(_resize_map)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 440
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	split.add_child(right)
	heading = Label.new()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 20)
	right.add_child(heading)
	var image_host := Control.new()
	image_host.custom_minimum_size.y = 200
	image_host.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(image_host)
	preview = TextureRect.new()
	preview.name = "DecorPreview"
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	image_host.add_child(preview)
	floor_preview = FloorPreview.new()
	floor_preview.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	floor_preview.resized.connect(floor_preview.queue_redraw)
	image_host.add_child(floor_preview)
	details = RichTextLabel.new()
	details.custom_minimum_size.y = 165
	details.selection_enabled = true
	right.add_child(details)
	var actions := HFlowContainer.new()
	right.add_child(actions)
	play_button = _button(
		actions,
		"Jouer cette destination",
		func():
			launch("play"),
	)
	da_button = _button(
		actions,
		"Examiner la DA",
		func():
			launch("art"),
	)
	art_button = _button(actions, "Ouvrir la peinture", _open_art)
	aftermath_button = _button(
		actions,
		"Après le combat",
		func():
			launch("aftermath"),
	)
	_button(
		actions,
		"Décor / dalles",
		func():
			show_floor = not show_floor
			select_destination(str(selected.id)),
	)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Vue d'audit sans brouillard · Essais séparés · F8 ferme l'essai et retrouve cet explorateur."
	root.add_child(status)
	refresh()
	_resize_map.call_deferred()


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func refresh() -> void:
	var previous := str(selected.get("id", "d01_0"))
	route.initialize(int(seed_field.value))
	canvas.set_route(route)
	destinations.clear()
	node_ids.clear()
	var entries: Array[Dictionary] = [Catalog.entry()]
	var ordered := route.nodes.duplicate(true)
	ordered.sort_custom(
		func(a: Dictionary, b: Dictionary):
			return (
				int(a.depth) < int(b.depth)
				or (int(a.depth) == int(b.depth) and int(a.lane) < int(b.lane))
			),
	)
	entries.append_array(ordered)
	for node in entries:
		node_ids.append(str(node.id))
		destinations.add_item(
			"%02d · %s · %s%s"
			% [
				int(node.depth),
				Catalog.KINDS.get(str(node.kind), node.kind),
				node.title,
				" [secret]" if bool(node.get("hidden", false)) else "",
			]
		)
	select_destination(previous if previous in node_ids else "d01_0")


func select_destination(id: String) -> void:
	selected = Catalog.entry() if id == "entry" else { }
	for node in route.nodes:
		if str(node.id) == id:
			selected = node.duplicate(true)
	if selected.is_empty():
		return
	description = Catalog.describe(selected)
	if description.is_empty():
		status.text = "La ressource de cette destination est introuvable."
		play_button.disabled = true
		da_button.disabled = true
		return
	destinations.select(node_ids.find(id))
	aftermath_button.visible = id == "d01_0"
	canvas.select_node(id)
	heading.text = "%02d · %s" % [int(selected.depth), selected.title]
	var image_path := str(description.image)
	preview.texture = (
		load(image_path) as Texture2D
		if (not image_path.is_empty() and ResourceLoader.exists(image_path))
		else null
	)
	preview.visible = preview.texture != null and not show_floor
	floor_preview.cells = description.geometry.get("floor_cells", [])
	floor_preview.visible = preview.texture == null or show_floor
	floor_preview.queue_redraw()
	var pack: Dictionary = description.pack
	var visual := (
		"Peinture source — le rendu animé se voit dans l'essai."
		if preview.texture != null
		else (
			"Plan des dalles — décor peint non produit." if not str(description.room).is_empty() else "Halte sur l'écran générique — aucun décor dédié."
		)
	)
	var lines: Array[String] = [str(selected.title) + " · " + str(description.kind), visual]
	if not str(description.intent).is_empty():
		lines.append(str(description.intent))
	if not pack.is_empty():
		lines.append(str(pack.get("name", "")) + " : " + str(pack.get("summary", "")))
	else:
		lines.append(str(selected.get("hint", "")))
	lines.append("Sorties : " + ", ".join(selected.get("edges", [])))
	lines.append(
		"Source : "
		+ str(description.room if not str(description.room).is_empty() else description.manifest)
	)
	lines.append(
		"Essai : chemin valide préparé, victoires précédentes simulées, attributs en vitalité, kit initial conservé."
	)
	details.text = "\n\n".join(lines)
	art_button.disabled = preview.texture == null
	play_button.disabled = false
	da_button.disabled = not ExpeditionRouteCatalog.is_combat(str(selected.kind))
	da_button.tooltip_text = "Rendu de combat sans personnages ni HUD" if not da_button.disabled else "Pour ce lieu, utiliser Jouer cette destination."


func _resize_map() -> void:
	if not is_instance_valid(canvas):
		return
	canvas.set_overview_height(maxf(450, map_host.size.y))
	canvas.size = map_host.size


func _open_art() -> void:
	if not str(description.get("image", "")).is_empty():
		OS.shell_open(ProjectSettings.globalize_path(str(description.image)))


func launch(mode: String, capture_and_exit := false) -> int:
	if selected.is_empty() or mode not in ["play", "art", "aftermath"]:
		return -1
	var folder := "res://artifacts/dev/run-explorer-%d-%d" % [
		Time.get_unix_time_from_system(),
		Time.get_ticks_usec(),
	]
	var absolute := ProjectSettings.globalize_path(folder)
	last_launch_output = folder
	if DirAccess.make_dir_recursive_absolute(absolute.path_join("userdata")) != OK:
		status.text = "Impossible de créer le dossier de l'essai."
		return -1
	var args := PackedStringArray(
		[
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--rendering-method",
			"gl_compatibility",
			"--resolution",
			"1280x720",
			"--log-file",
			absolute.path_join("engine.log"),
			"res://tools/run_explorer/RunExplorerPreview.tscn",
			"--",
			"--explorer-output=" + folder,
			"--explorer-node=" + str(selected.id),
			"--explorer-seed=" + str(int(seed_field.value)),
			"--explorer-mode=" + mode,
		]
	)
	if capture_and_exit:
		args.append("--explorer-capture")
	var old_env := { }
	for key in ["APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME"]:
		old_env[key] = { "exists": OS.has_environment(key), "value": OS.get_environment(key) }
		OS.set_environment(key, absolute.path_join("userdata"))
	var pid := OS.create_process(OS.get_executable_path(), args)
	for key in old_env:
		if old_env[key].exists:
			OS.set_environment(key, old_env[key].value)
		else:
			OS.unset_environment(key)
	status.text = "Essai lancé · F8 pour fermer · Rapports : " + folder if pid > 0 else "Le lancement de Godot a échoué."
	return pid
