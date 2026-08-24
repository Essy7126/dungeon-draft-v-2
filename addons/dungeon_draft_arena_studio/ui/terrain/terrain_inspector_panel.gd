@tool
class_name TerrainInspectorPanel
extends PanelContainer

## Inspecteur contextuel du Studio Terrain. Il n'affiche que les proprietes
## utiles a l'etape, l'outil ou la selection en cours ; la destination de
## salle, les chemins et les fichiers de production n'y apparaissent plus
## pendant la construction.
##
## Chaque section est declaree une fois puis alimentee par ArenaStudioMain, qui
## y reparent ses controles existants. La visibilite est calculee ici, a partir
## de l'etape et du mode guide.

signal close_requested

const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)

## Sections et etapes qui les affichent. `advanced` marque celles qui
## disparaissent completement en mode guide.
const SECTIONS := [
	{
		"id": &"selection",
		"title": "CASE SURVOLÉE",
		"steps": [0, 1, 2, 3, 4, 5, 6],
		"advanced": false,
	},
	{
		"id": &"shape",
		"title": "FORME DE LA ZONE",
		"steps": [TerrainWorkflowService.Step.SHAPE],
		"advanced": false,
	},
	{
		"id": &"floors",
		"title": "SOL ACTIF",
		"steps": [TerrainWorkflowService.Step.FLOORS],
		"advanced": false,
	},
	{
		"id": &"content",
		"title": "OBSTACLES ET POINTS DE DÉPART",
		"steps": [TerrainWorkflowService.Step.CONTENT],
		"advanced": false,
	},
	{
		"id": &"scenery",
		"title": "DÉCOR",
		"steps": [TerrainWorkflowService.Step.SCENERY],
		"advanced": false,
	},
	{
		"id": &"verify",
		"title": "VÉRIFICATION",
		"steps": [TerrainWorkflowService.Step.VERIFY],
		"advanced": false,
	},
	{
		"id": &"finalize",
		"title": "",
		"steps": [TerrainWorkflowService.Step.FINALIZE],
		"advanced": false,
	},
	{
		"id": &"calibration",
		"title": "CALIBRATION NUMÉRIQUE",
		"steps": [TerrainWorkflowService.Step.SCENERY],
		"advanced": true,
	},
	{
		"id": &"layers",
		"title": "CALQUES ET OPACITÉS",
		"steps": [TerrainWorkflowService.Step.SCENERY, TerrainWorkflowService.Step.VERIFY],
		"advanced": true,
	},
	{
		"id": &"simulation",
		"title": "SIMULATIONS TECHNIQUES",
		"steps": [TerrainWorkflowService.Step.VERIFY],
		"advanced": true,
	},
	{
		"id": &"run",
		"title": "SÉQUENCE DE LA PARTIE",
		"steps": [TerrainWorkflowService.Step.FINALIZE],
		"advanced": true,
	},
	{
		"id": &"recovery",
		"title": "OUTILS DE RÉCUPÉRATION",
		"steps": [0, 1, 2, 3, 4, 5, 6],
		"advanced": true,
	},
]

var sections := {}
var header_label: Label = null
var empty_label: Label = null
var close_button: Button = null
var scroll: ScrollContainer = null

var _built := false
var _step := 0
var _guided := true
var _drawer_mode := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "TerrainInspectorPanel"
	custom_minimum_size.x = 300
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	header_label = Label.new()
	header_label.name = "TerrainInspectorTitle"
	header_label.text = "INSPECTEUR"
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_label.add_theme_font_size_override("font_size", 14)
	header_label.add_theme_color_override("font_color", ACCENT)
	header.add_child(header_label)
	close_button = Button.new()
	close_button.name = "TerrainInspectorClose"
	close_button.text = "Fermer"
	close_button.tooltip_text = "Refermer le tiroir de l'inspecteur."
	close_button.visible = false
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.pressed.connect(func(): close_requested.emit())
	header.add_child(close_button)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	scroll.add_child(box)
	for definition in SECTIONS:
		var section := VBoxContainer.new()
		section.name = "TerrainInspectorSection_%s" % definition.id
		section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section.add_theme_constant_override("separation", 3)
		box.add_child(section)
		var title := str(definition.title)
		if not title.is_empty():
			var label := Label.new()
			label.text = title
			label.add_theme_font_size_override("font_size", 13)
			label.add_theme_color_override("font_color", ACCENT)
			section.add_child(label)
		sections[definition.id] = {
			"container": section,
			"steps": definition.steps,
			"advanced": bool(definition.advanced),
		}
	empty_label = Label.new()
	empty_label.name = "TerrainInspectorEmpty"
	empty_label.text = "Choisissez un outil ou survolez une case pour voir ses propriétés ici."
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.add_theme_color_override("font_color", MUTED)
	box.add_child(empty_label)


func host_control(section_id: StringName, control: Control) -> void:
	_build()
	if control == null or not sections.has(section_id):
		return
	if control.get_parent() != null:
		control.get_parent().remove_child(control)
	((sections[section_id] as Dictionary).container as Node).add_child(control)


func set_context(step: int, guided: bool) -> void:
	_build()
	_step = clampi(step, 0, TerrainWorkflowService.STEP_COUNT - 1)
	_guided = guided
	var visible_count := 0
	for section_id in sections:
		var entry := sections[section_id] as Dictionary
		var container := entry.container as Control
		var allowed: Array = entry.steps
		var shown := allowed.has(_step) and (not bool(entry.advanced) or not guided)
		container.visible = shown and container.get_child_count() > 0
		if container.visible:
			visible_count += 1
	empty_label.visible = visible_count == 0
	header_label.text = "INSPECTEUR — %s" % TerrainWorkflowService.step_label(_step)


func set_drawer_mode(value: bool) -> void:
	_build()
	_drawer_mode = value
	close_button.visible = value


func is_drawer_mode() -> bool:
	return _drawer_mode
