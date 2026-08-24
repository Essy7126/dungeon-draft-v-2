@tool
class_name TerrainToolPalette
extends PanelContainer

## Palette contextuelle placee immediatement au-dessus du canvas. Elle remplace
## la liste plate de onze outils par des groupes d'intention : Forme, Sols,
## Obstacles, Points de depart, Decor et Verification.
##
## La palette ne contient aucune regle metier : elle demande un outil ou une
## action, et accueille les controles deja construits par ArenaStudioMain pour
## que leur cablage existant reste intact.

signal tool_requested(tool: int)
signal action_requested(action: StringName)

const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)

## Un outil par intention. Le raccourci affiche ici est celui reellement
## implemente par ArenaStudioMain._unhandled_key_input().
const TOOL_BUTTONS := {
	TerrainWorkflowService.Step.SHAPE: [
		[ArenaStudioCanvas.Tool.ADD_CELL, "Ajouter des cases", "3", "Dessiner la zone jouable."],
		[ArenaStudioCanvas.Tool.REMOVE_CELL, "Retirer des cases", "4", "Enlever une case du terrain."],
		[ArenaStudioCanvas.Tool.BORDER, "Bordure", "5", "Peindre la bordure qui referme la zone."],
	],
	TerrainWorkflowService.Step.FLOORS: [
		[ArenaStudioCanvas.Tool.TERRAIN, "Peindre un sol", "7", "Appliquer le sol choisi dans la palette."],
	],
	TerrainWorkflowService.Step.CONTENT: [
		[ArenaStudioCanvas.Tool.OBSTACLE, "Murs et obstacles", "6", "Murs, falaises et éléments bloquants."],
		[ArenaStudioCanvas.Tool.SPAWN, "Points de départ", "8", "Héros, ennemis, objectifs et invocations."],
	],
	TerrainWorkflowService.Step.SCENERY: [
		[ArenaStudioCanvas.Tool.SELECT, "Sélection", "1", "Examiner une case sans la modifier."],
	],
	TerrainWorkflowService.Step.VERIFY: [
		[ArenaStudioCanvas.Tool.VERIFY, "Vérification", "9", "Tester un déplacement ou une ligne de vue."],
	],
}

## Outils reserves au mode avance, ajoutes au groupe Decor.
const ADVANCED_TOOL_BUTTONS := {
	TerrainWorkflowService.Step.SCENERY: [
		[ArenaStudioCanvas.Tool.TRANSFORM_GRID, "Transformer la grille", "0", "Déplacer, tourner ou étirer la grille."],
		[ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS, "Ancres", "A", "Poser des points de repère de calibration."],
	],
}

const GROUP_TITLES := {
	TerrainWorkflowService.Step.START: "DÉPART",
	TerrainWorkflowService.Step.SHAPE: "FORME",
	TerrainWorkflowService.Step.FLOORS: "SOLS",
	TerrainWorkflowService.Step.CONTENT: "OBSTACLES ET POINTS DE DÉPART",
	TerrainWorkflowService.Step.SCENERY: "DÉCOR",
	TerrainWorkflowService.Step.VERIFY: "VÉRIFICATION",
	TerrainWorkflowService.Step.FINALIZE: "TESTER ET INTÉGRER",
}

var groups := {}
var tool_buttons := {}
var advanced_buttons: Array[Button] = []
var contract_label: Label = null

var _built := false
var _active_step := 0
var _active_tool := ArenaStudioCanvas.Tool.SELECT
var _advanced := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "TerrainToolPalette"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	for step in range(TerrainWorkflowService.STEP_COUNT):
		var group := VBoxContainer.new()
		group.name = "TerrainPaletteGroup%d" % step
		group.add_theme_constant_override("separation", 3)
		box.add_child(group)
		var title := Label.new()
		title.text = str(GROUP_TITLES.get(step, ""))
		title.add_theme_font_size_override("font_size", 13)
		title.add_theme_color_override("font_color", ACCENT)
		group.add_child(title)
		var row := HFlowContainer.new()
		row.name = "TerrainPaletteRow%d" % step
		row.add_theme_constant_override("h_separation", 4)
		row.add_theme_constant_override("v_separation", 4)
		group.add_child(row)
		for entry in TOOL_BUTTONS.get(step, []):
			row.add_child(_tool_button(entry, false))
		for entry in ADVANCED_TOOL_BUTTONS.get(step, []):
			row.add_child(_tool_button(entry, true))
		var host := HFlowContainer.new()
		host.name = "TerrainPaletteHost%d" % step
		host.add_theme_constant_override("h_separation", 4)
		host.add_theme_constant_override("v_separation", 4)
		group.add_child(host)
		# Emplacement pleine largeur : un HFlowContainer réduit ses enfants à
		# leur largeur minimale, ce qui replierait la palette des sols en deux
		# colonnes au lieu de la déployer sur toute la largeur disponible.
		var wide := VBoxContainer.new()
		wide.name = "TerrainPaletteWideHost%d" % step
		wide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wide.add_theme_constant_override("separation", 3)
		group.add_child(wide)
		groups[step] = {"group": group, "row": row, "host": host, "wide": wide}
		group.visible = false
	contract_label = Label.new()
	contract_label.name = "ActiveToolContract"
	contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contract_label.add_theme_color_override("font_color", MUTED)
	box.add_child(contract_label)


## Accueille un controle deja construit par ArenaStudioMain sans le recreer.
func host_control(step: int, control: Control) -> void:
	_build()
	if not groups.has(step) or control == null:
		return
	var host := (groups[step] as Dictionary).host as HFlowContainer
	if control.get_parent() != null:
		control.get_parent().remove_child(control)
	host.add_child(control)


## Accueille un controle qui doit occuper toute la largeur de la palette.
func host_wide_control(step: int, control: Control) -> void:
	_build()
	if not groups.has(step) or control == null:
		return
	var wide := (groups[step] as Dictionary).wide as VBoxContainer
	if control.get_parent() != null:
		control.get_parent().remove_child(control)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wide.add_child(control)


func add_action_button(
		step: int,
		action: StringName,
		label: String,
		tooltip: String
	) -> Button:
	_build()
	var button := Button.new()
	button.name = "TerrainPaletteAction_%s" % action
	button.text = label
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(func(): action_requested.emit(action))
	host_control(step, button)
	return button


func set_active_step(step: int) -> void:
	_build()
	_active_step = clampi(step, 0, TerrainWorkflowService.STEP_COUNT - 1)
	for key in groups:
		((groups[key] as Dictionary).group as Control).visible = int(key) == _active_step


func active_step() -> int:
	return _active_step


func set_active_tool(tool: int) -> void:
	_build()
	_active_tool = tool
	for key in tool_buttons:
		(tool_buttons[key] as Button).set_pressed_no_signal(int(key) == tool)


func set_advanced(value: bool) -> void:
	_build()
	_advanced = value
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
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = "%s — raccourci %s\n%s" % [entry[1], entry[2], entry[3]]
	button.pressed.connect(func(): tool_requested.emit(tool))
	tool_buttons[tool] = button
	if advanced:
		button.visible = false
		advanced_buttons.append(button)
	return button
