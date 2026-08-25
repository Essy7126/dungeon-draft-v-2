@tool
class_name TerrainToolPalette
extends PanelContainer

## Rail permanent par categories. Les comportements precis de pose sont
## actives par la bibliotheque ; le rail ne duplique donc jamais Sol,
## Obstacle ou Placement sous des boutons generiques.

signal tool_requested(tool: int)
signal action_requested(action: StringName)

const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)

const CATEGORY_SELECTION := &"selection"
const CATEGORY_GRID := &"grid"
const CATEGORY_ELEMENTS := &"elements"
const CATEGORY_ILLUSTRATION := &"illustration"

var tool_buttons := {}
var advanced_buttons: Array[Button] = []
var category_buttons := {}
var category_panels := {}
var contract_label: Label = null
var compatibility_host: VBoxContainer = null
var _active_tool := ArenaStudioCanvas.Tool.SELECT
var _active_category := CATEGORY_SELECTION
var _built := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "TerrainToolPalette"
	custom_minimum_size.x = 136
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	var title := Label.new()
	title.text = "TERRAIN"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)
	box.add_child(_category_button(
		CATEGORY_SELECTION, "Sélectionner",
		"Inspecter et modifier ce qui existe déjà."
	))
	var separator := HSeparator.new()
	box.add_child(separator)
	var caption := Label.new()
	caption.text = "CATÉGORIES"
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", MUTED)
	box.add_child(caption)
	box.add_child(_category_button(
		CATEGORY_GRID, "Grille",
		"Modifier la forme, la position, les dimensions et l'alignement de la grille."
	))
	var grid_panel := VBoxContainer.new()
	grid_panel.add_theme_constant_override("separation", 2)
	grid_panel.add_child(_tool_button(
		ArenaStudioCanvas.Tool.ADD_CELL, "Ajouter des cases", "3",
		"Agrandir la forme jouable."
	))
	grid_panel.add_child(_tool_button(
		ArenaStudioCanvas.Tool.REMOVE_CELL, "Retirer des cases", "4",
		"Retirer des cases de la forme."
	))
	grid_panel.add_child(_tool_button(
		ArenaStudioCanvas.Tool.BORDER, "Tracer la bordure", "5",
		"Entourer la zone tactique d'une bordure."
	))
	grid_panel.add_child(_tool_button(
		ArenaStudioCanvas.Tool.TRANSFORM_GRID, "Ajuster la grille", "0",
		"Modifier directement sa position, ses dimensions, sa rotation, son échelle ou son inclinaison."
	))
	var multipoint := _tool_button(
		ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS, "Calibration multipoint", "A",
		"Ces points corrigent précisément l'alignement de la grille sur une illustration lorsque l'ajustement normal ne suffit pas."
	)
	multipoint.visible = false
	advanced_buttons.append(multipoint)
	grid_panel.add_child(multipoint)
	box.add_child(grid_panel)
	category_panels[CATEGORY_GRID] = grid_panel
	box.add_child(_category_button(
		CATEGORY_ELEMENTS, "Éléments",
		"Choisir sols, obstacles, départs, interactifs ou décor dans la bibliothèque."
	))
	box.add_child(_category_button(
		CATEGORY_ILLUSTRATION, "Illustration",
		"Choisir ou remplacer uniquement l'image de fond."
	))
	var illustration_panel := VBoxContainer.new()
	illustration_panel.add_theme_constant_override("separation", 2)
	illustration_panel.add_child(_action_button(
		"Changer l'image", &"choose_backdrop",
		"Choisir immédiatement une autre illustration."
	))
	box.add_child(illustration_panel)
	category_panels[CATEGORY_ILLUSTRATION] = illustration_panel
	compatibility_host = VBoxContainer.new()
	compatibility_host.visible = false
	box.add_child(compatibility_host)
	contract_label = Label.new()
	contract_label.name = "ActiveToolContract"
	contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contract_label.add_theme_color_override("font_color", MUTED)
	contract_label.visible = false
	box.add_child(contract_label)
	_set_active_category(CATEGORY_SELECTION)


func host_control(_step: int, control: Control) -> void:
	_build()
	if control == null:
		return
	if control.get_parent() != null:
		control.get_parent().remove_child(control)
	compatibility_host.add_child(control)


func host_wide_control(step: int, control: Control) -> void:
	host_control(step, control)


func add_action_button(
		_step: int,
		action: StringName,
		label: String,
		tooltip: String
	) -> Button:
	_build()
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.pressed.connect(func(): action_requested.emit(action))
	compatibility_host.add_child(button)
	return button


func set_active_step(_step: int) -> void:
	pass


func active_step() -> int:
	return -1


func set_active_tool(tool: int) -> void:
	_build()
	_active_tool = tool
	for key in tool_buttons:
		(tool_buttons[key] as Button).set_pressed_no_signal(int(key) == tool)
	if tool == ArenaStudioCanvas.Tool.SELECT:
		_set_active_category(CATEGORY_SELECTION)
	elif tool in [
		ArenaStudioCanvas.Tool.ADD_CELL,
		ArenaStudioCanvas.Tool.REMOVE_CELL,
		ArenaStudioCanvas.Tool.BORDER,
	]:
		_set_active_category(CATEGORY_GRID)
	elif tool in [ArenaStudioCanvas.Tool.TRANSFORM_GRID, ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS]:
		_set_active_category(CATEGORY_GRID)
	elif tool in [
		ArenaStudioCanvas.Tool.TERRAIN,
		ArenaStudioCanvas.Tool.OBSTACLE,
		ArenaStudioCanvas.Tool.SPAWN,
	]:
		_set_active_category(CATEGORY_ELEMENTS)


func set_advanced(value: bool) -> void:
	_build()
	contract_label.visible = false
	for button in advanced_buttons:
		button.visible = value


func set_contract_text(value: String) -> void:
	_build()
	contract_label.text = value


func _category_button(category: StringName, label: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = "TerrainCategory_%s" % category
	button.text = label
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = tooltip
	button.pressed.connect(_on_category_pressed.bind(category))
	category_buttons[category] = button
	return button


func _tool_button(tool: int, label: String, shortcut: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = "TerrainTool_%d" % tool
	button.text = label
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = "%s — raccourci %s\n%s" % [label, shortcut, tooltip]
	button.pressed.connect(func(): tool_requested.emit(tool))
	button.set_pressed_no_signal(tool == _active_tool)
	tool_buttons[tool] = button
	return button


func _action_button(label: String, action: StringName, tooltip: String) -> Button:
	var button := Button.new()
	button.text = label
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = tooltip
	button.pressed.connect(func(): action_requested.emit(action))
	return button


func _on_category_pressed(category: StringName) -> void:
	_set_active_category(category)
	match category:
		CATEGORY_SELECTION:
			tool_requested.emit(ArenaStudioCanvas.Tool.SELECT)
		CATEGORY_ELEMENTS:
			action_requested.emit(&"show_elements")
		CATEGORY_ILLUSTRATION:
			action_requested.emit(&"show_illustration")
		CATEGORY_GRID:
			action_requested.emit(&"show_grid")


func _set_active_category(category: StringName) -> void:
	_active_category = category
	for key in category_buttons:
		(category_buttons[key] as Button).set_pressed_no_signal(key == category)
	for key in category_panels:
		(category_panels[key] as Control).visible = key == category
