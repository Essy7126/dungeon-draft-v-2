@tool
class_name EncounterDiagnosticCard
extends PanelContainer

## G5 — une carte de diagnostic compréhensible sans vocabulaire technique.
## Elle ne lit et n'affiche que ce que StudioValidationMessage/EncounterPresentation
## lui donnent : elle n'invente jamais une erreur ni une correction absente
## des données. « Voir » et « Corriger » sont deux boutons distincts, jamais
## déclenchés par une sélection ou un double-clic.

signal view_requested
signal fix_requested
signal details_requested

## G6 — couleurs partagées avec le reste du Studio de rencontres, voir
## EncounterVisualConstants (système visuel local unique, pas de couleur
## brute dupliquée par composant).
const SEVERITY_SYMBOLS := {
	StudioValidationMessage.Severity.ERROR: "✖",
	StudioValidationMessage.Severity.WARNING: "▲",
	StudioValidationMessage.Severity.INFO: "ℹ",
}

var message: StudioValidationMessage = null
var fix_button: Button = null
var view_button: Button = null


func setup(msg: StudioValidationMessage, can_view: bool, can_fix: bool) -> void:
	message = msg
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.border_color = EncounterVisualConstants.severity_color(msg.severity)
	style.set_border_width_all(1)
	style.set_border_width(SIDE_LEFT, 4)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(EncounterVisualConstants.CARD_CORNER_RADIUS)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	box.add_child(header)
	var symbol := Label.new()
	symbol.text = SEVERITY_SYMBOLS.get(msg.severity, "•")
	symbol.add_theme_color_override("font_color", EncounterVisualConstants.severity_color(msg.severity))
	header.add_child(symbol)
	var severity_label := Label.new()
	severity_label.text = msg.severity_label()
	severity_label.add_theme_color_override("font_color", EncounterVisualConstants.severity_color(msg.severity))
	header.add_child(severity_label)
	var title_label := Label.new()
	title_label.text = EncounterPresentation.validation_title(msg)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title_label)

	var explanation_label := Label.new()
	explanation_label.text = EncounterPresentation.validation_explanation(msg)
	explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(explanation_label)

	var consequence_label := Label.new()
	consequence_label.text = "Effet : %s" % EncounterPresentation.validation_consequence(msg)
	consequence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consequence_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	box.add_child(consequence_label)

	var location := _location_text(msg)
	if not location.is_empty():
		var location_label := Label.new()
		location_label.text = location
		location_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		box.add_child(location_label)

	var action_label := Label.new()
	action_label.text = "À faire : %s" % EncounterPresentation.validation_action(msg)
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(action_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	if can_view:
		view_button = Button.new()
		view_button.text = "Voir"
		view_button.tooltip_text = "Ouvrir cet endroit dans le Studio, sans rien modifier."
		view_button.custom_minimum_size = Vector2(96, EncounterVisualConstants.BUTTON_MIN_HEIGHT)
		view_button.pressed.connect(func(): view_requested.emit())
		actions.add_child(view_button)
	if can_fix:
		fix_button = Button.new()
		fix_button.text = "Corriger"
		fix_button.tooltip_text = EncounterPresentation.validation_action(msg)
		fix_button.custom_minimum_size = Vector2(96, EncounterVisualConstants.BUTTON_MIN_HEIGHT)
		fix_button.pressed.connect(func(): fix_requested.emit())
		actions.add_child(fix_button)
	var details_button := Button.new()
	details_button.text = "Détails techniques"
	details_button.custom_minimum_size = Vector2(96, EncounterVisualConstants.BUTTON_MIN_HEIGHT)
	details_button.pressed.connect(func(): details_requested.emit())
	actions.add_child(details_button)


static func _location_text(msg: StudioValidationMessage) -> String:
	var parts := PackedStringArray()
	if msg.room_index >= 0:
		parts.append("Salle %d" % (msg.room_index + 1))
	if msg.wave_index >= 0:
		parts.append("Affrontement %d" % (msg.wave_index + 1))
	if msg.cell != Vector2i(-1, -1):
		parts.append("Case (%d, %d)" % [msg.cell.x, msg.cell.y])
	return "Concerne : %s" % " • ".join(parts) if not parts.is_empty() else ""
