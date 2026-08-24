@tool
class_name TerrainFinalizePanel
extends VBoxContainer

## Etape finale « Tester et integrer ». Elle est le seul endroit du Studio ou
## la destination de salle, les chemins et les fichiers de production
## apparaissent : pendant la construction, l'inspecteur reste libre.
##
## Le panneau explique en permanence la difference entre les trois contrats :
## enregistrer le brouillon, tester, integrer a la partie.

signal draft_requested
signal test_requested
signal integrate_requested

const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)
const CARD_BACKGROUND := Color(0.137, 0.153, 0.184)

const CONTRACTS := [
	[
		"Enregistrer le brouillon",
		"Garde votre travail dans votre dossier personnel. La partie n'est pas modifiée.",
	],
	[
		"Tester",
		"Lance un vrai combat sur la version en cours. Rien n'est publié.",
	],
	[
		"Intégrer à la partie",
		"Publie le terrain dans une salle. Un résumé est affiché avant toute écriture.",
	],
]

var readiness_label: Label = null
var draft_button: Button = null
var test_button: Button = null
var integrate_button: Button = null
var test_host: VBoxContainer = null
var destination_host: VBoxContainer = null

var _built := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "TerrainFinalizePanel"
	add_theme_constant_override("separation", 5)
	var title := Label.new()
	title.text = "TESTER ET INTÉGRER"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", ACCENT)
	add_child(title)
	readiness_label = Label.new()
	readiness_label.name = "TerrainFinalizeReadiness"
	readiness_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(readiness_label)
	for contract in CONTRACTS:
		add_child(_contract_card(contract[0], contract[1]))
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 4)
	add_child(actions)
	draft_button = _action(actions, "TerrainFinalizeDraft", "Enregistrer le brouillon")
	draft_button.pressed.connect(func(): draft_requested.emit())
	test_button = _action(actions, "TerrainFinalizeTest", "Tester")
	test_button.pressed.connect(func(): test_requested.emit())
	integrate_button = _action(actions, "TerrainFinalizeIntegrate", "Intégrer à la partie")
	integrate_button.pressed.connect(func(): integrate_requested.emit())
	var test_title := Label.new()
	test_title.text = "CONFIGURATION DU COMBAT DE TEST"
	test_title.add_theme_font_size_override("font_size", 13)
	test_title.add_theme_color_override("font_color", ACCENT)
	add_child(test_title)
	test_host = VBoxContainer.new()
	test_host.name = "TerrainFinalizeTestHost"
	add_child(test_host)
	destination_host = VBoxContainer.new()
	destination_host.name = "TerrainFinalizeDestinationHost"
	destination_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(destination_host)


func host_test_control(control: Control) -> void:
	_build()
	_reparent(control, test_host)


func host_destination_control(control: Control) -> void:
	_build()
	_reparent(control, destination_host)


func set_readiness(readiness: String, detail := "") -> void:
	_build()
	readiness_label.text = readiness if detail.is_empty() \
		else "%s — %s" % [readiness, detail]
	var color := TerrainWorkflowService.state_color(TerrainWorkflowService.STATE_TODO)
	match readiness:
		TerrainWorkflowService.READINESS_INTEGRABLE:
			color = TerrainWorkflowService.state_color(TerrainWorkflowService.STATE_DONE)
		TerrainWorkflowService.READINESS_TESTABLE:
			color = TerrainWorkflowService.state_color(TerrainWorkflowService.STATE_DOING)
		TerrainWorkflowService.READINESS_INCOMPLETE:
			color = TerrainWorkflowService.state_color(TerrainWorkflowService.STATE_ERROR)
	readiness_label.add_theme_color_override("font_color", color)
	test_button.disabled = readiness == TerrainWorkflowService.READINESS_INCOMPLETE
	integrate_button.disabled = readiness == TerrainWorkflowService.READINESS_INCOMPLETE


func _reparent(control: Control, host: Node) -> void:
	if control == null:
		return
	if control.get_parent() != null:
		control.get_parent().remove_child(control)
	host.add_child(control)


func _action(parent: Node, node_name: String, label: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = _tooltip_for(label)
	parent.add_child(button)
	return button


func _tooltip_for(label: String) -> String:
	for contract in CONTRACTS:
		if str(contract[0]) == label:
			return str(contract[1])
	return label


func _contract_card(title_text: String, description: String) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BACKGROUND
	style.set_corner_radius_all(5)
	style.border_width_left = 3
	style.border_color = ACCENT
	style.set_content_margin_all(7)
	style.content_margin_left = 11
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	card.add_child(box)
	var heading := Label.new()
	heading.text = title_text
	heading.add_theme_color_override("font_color", ACCENT)
	box.add_child(heading)
	var body := Label.new()
	body.text = description
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", MUTED)
	box.add_child(body)
	return card
