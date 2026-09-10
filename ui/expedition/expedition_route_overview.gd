extends Control
## Full-viewport inspection. Only the route view can commit a destination.
signal destination_selected(node_id: String)
signal closed

const ART_THEME := preload("res://ui/expedition/catabase_ui_theme.gd")
const MAP_CANVAS := preload("res://ui/expedition/expedition_map_canvas.gd")
const LEGEND := [
	["normal", "Combat"],
	["elite", "Épreuve élite"],
	["boss", "Gardien final"],
	["hub", "Refuge / repos"],
	["merchant", "Marchand / équipement"],
	["sanctuary", "Sanctuaire / branche"],
	["lore", "Mémoire / passage"],
	["event", "Rencontre"],
	["cache", "Cache"],
	["unknown", "Écho inconnu"],
	["hidden", "Passage découvert"],
]

var route: ExpeditionRouteState
var selected_id := ""
var _canvas: ExpeditionMapCanvas
var _map_host: Control
var _title: Label
var _status: Label
var _close: Button
var _previous_focus: Control


func _ready() -> void:
	name = "FullRouteOverview"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_previous_focus = get_viewport().gui_get_focus_owner()
	ART_THEME.apply(self)
	var background := ColorRect.new()
	background.color = ART_THEME.INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var heading := _label(header, "CATABASE  /  LA DESCENTE", 23, ART_THEME.GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.name = "CloseFullRoute"
	close.text = "Replier la carte  ×"
	close.custom_minimum_size = Vector2(210, 42)
	close.tooltip_text = "Revenir à la carte détaillée · Échap"
	ART_THEME.apply_button(close)
	header.add_child(close)
	close.pressed.connect(_close_overview)
	_close = close
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	_map_host = Control.new()
	_map_host.name = "OverviewMapArea"
	_map_host.custom_minimum_size = Vector2(580, 440)
	_map_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_map_host)
	_canvas = MAP_CANVAS.new()
	_canvas.name = "OverviewMapCanvas"
	_canvas.set_overview_height(440)
	_map_host.add_child(_canvas)
	_canvas.set_route(route)
	_canvas.select_node(selected_id)
	_canvas.node_selected.connect(_select_destination)
	_map_host.resized.connect(_resize_map)
	var sidebar := VBoxContainer.new()
	sidebar.name = "FullRouteLegend"
	sidebar.custom_minimum_size.x = 240
	sidebar.add_theme_constant_override("separation", 5)
	body.add_child(sidebar)
	_label(sidebar, "LÉGENDE", 18, ART_THEME.GOLD)
	for entry in LEGEND:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		sidebar.add_child(row)
		var icon := TextureRect.new()
		icon.name = "LegendIcon_" + entry[0]
		icon.texture = CatabasePaintedIconCatalog.map_icon(entry[0])
		icon.modulate = ART_THEME.GOLD
		icon.custom_minimum_size = Vector2(25, 25)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		_label(row, entry[1], 14, ART_THEME.TEXT)
	_label(sidebar, "━━  Parcours accompli", 14, Color("d5917c"))
	_label(sidebar, "━━  Voies sélectionnées", 14, ART_THEME.TEAL)
	_label(sidebar, "┄┄  Chemins possibles", 14, ART_THEME.MUTED)
	_label(sidebar, "Cercle : sélection / position\nGrisé : autre chemin", 13, ART_THEME.MUTED)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(spacer)
	_title = _label(sidebar, "", 18, ART_THEME.GOLD)
	_title.custom_minimum_size.x = 240
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status = _label(sidebar, "", 13, ART_THEME.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_select_destination(selected_id)
	_resize_map.call_deferred()
	close.grab_focus()


func _resize_map() -> void:
	if not is_instance_valid(_canvas):
		return
	_canvas.set_overview_height(_map_host.size.y)
	_canvas.size = Vector2(minf(_map_host.size.x, maxf(580, _map_host.size.y)), _map_host.size.y)
	_canvas.position.x = (_map_host.size.x - _canvas.size.x) * 0.5


func _select_destination(node_id: String) -> void:
	if route == null:
		return
	for node in route.get_visible_nodes():
		if str(node.id) != node_id:
			continue
		selected_id = node_id
		_title.text = "SEUIL %02d\n%s" % [int(node.depth), str(node.title)]
		_status.text = "À choisir · repliez pour confirmer." if bool(node.available) else "Consultation · aucun déplacement."
		var consequence := str(route.get_choice_preview(node_id).get("summary", ""))
		if not consequence.is_empty():
			_status.text += "\n\n" + consequence
		destination_selected.emit(node_id)
		return


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_overview()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		# Keep keyboard traversal inside this full-screen overlay.
		var controls: Array[Control] = [_close]
		for button in _canvas.find_children("Destination_*", "Button", true, false):
			controls.append(button)
		var current := controls.find(get_viewport().gui_get_focus_owner())
		var step := -1 if event.shift_pressed else 1
		controls[posmod(current + step, controls.size())].grab_focus()
		get_viewport().set_input_as_handled()


func _close_overview() -> void:
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	closed.emit()


func _label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(label)
	return label
