@tool
class_name TerrainToolPalette
extends PanelContainer

## Rail permanent des outils spatiaux. Il ne dépend plus d'une étape : tous les
## outils de construction restent disponibles pendant l'édition du canvas.

signal tool_requested(tool: int)
signal action_requested(action: StringName)

const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)

const TOOL_BUTTONS := [
	[ArenaStudioCanvas.Tool.SELECT, "Sélection", "1", "Sélectionner une case ou un élément placé."],
	[ArenaStudioCanvas.Tool.PAN, "Déplacer la vue", "2", "Déplacer la vue sans modifier le terrain."],
	[ArenaStudioCanvas.Tool.ADD_CELL, "Ajouter des cases", "3", "Agrandir la forme jouable."],
	[ArenaStudioCanvas.Tool.REMOVE_CELL, "Retirer des cases", "4", "Retirer des cases de la forme."],
	[ArenaStudioCanvas.Tool.BORDER, "Peindre la bordure", "5", "Fermer la zone tactique."],
	[ArenaStudioCanvas.Tool.TERRAIN, "Peindre", "7", "Utiliser le sol choisi dans la bibliothèque."],
	[ArenaStudioCanvas.Tool.OBSTACLE, "Obstacle", "6", "Utiliser l'obstacle choisi dans la bibliothèque."],
	[ArenaStudioCanvas.Tool.SPAWN, "Placer", "8", "Utiliser le départ, l'interactif ou le décor choisi."],
	[ArenaStudioCanvas.Tool.TRANSFORM_GRID, "Ajuster le décor", "0", "Déplacer, tourner, agrandir ou incliner la grille."],
]

const ADVANCED_TOOL_BUTTONS := [
	[ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS, "Ancres", "A", "Modifier les points de repère avancés."],
]

var tool_buttons := {}
var advanced_buttons: Array[Button] = []
var contract_label: Label = null
var compatibility_host: VBoxContainer = null
var _active_tool := ArenaStudioCanvas.Tool.SELECT
var _built := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "TerrainToolPalette"
	custom_minimum_size.x = 164
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	var title := Label.new()
	title.text = "OUTILS"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)
	for entry in TOOL_BUTTONS:
		box.add_child(_tool_button(entry, false))
	for entry in ADVANCED_TOOL_BUTTONS:
		box.add_child(_tool_button(entry, true))
	compatibility_host = VBoxContainer.new()
	compatibility_host.visible = false
	box.add_child(compatibility_host)
	contract_label = Label.new()
	contract_label.name = "ActiveToolContract"
	contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contract_label.add_theme_color_override("font_color", MUTED)
	contract_label.visible = false
	box.add_child(contract_label)


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


func set_advanced(value: bool) -> void:
	_build()
	contract_label.visible = value
	for button in advanced_buttons:
		button.visible = value


func set_contract_text(value: String) -> void:
	_build()
	contract_label.text = value


func _tool_button(entry: Array, advanced: bool) -> Button:
	var tool := int(entry[0])
	var button := Button.new()
	button.name = "TerrainTool_%d" % tool
	button.text = str(entry[1])
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = "%s — raccourci %s\n%s" % [entry[1], entry[2], entry[3]]
	button.pressed.connect(func(): tool_requested.emit(tool))
	button.set_pressed_no_signal(tool == _active_tool)
	tool_buttons[tool] = button
	if advanced:
		button.visible = false
		advanced_buttons.append(button)
	return button
