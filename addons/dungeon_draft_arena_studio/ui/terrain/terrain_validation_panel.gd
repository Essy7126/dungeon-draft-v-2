@tool
class_name TerrainValidationPanel
extends VBoxContainer

## Panneau de validation sous forme de cartes actionnables. Chaque probleme
## indique ce qui ne va pas, pourquoi c'est important, l'emplacement concerne,
## et propose « Me montrer », « Sélectionner la case » et, uniquement pour une
## correction deterministe, sure et annulable, « Corriger automatiquement ».
##
## Aucune carte ne modifie le gameplay : les corrections proposees sont des
## operations d'edition classiques, enregistrees dans l'historique.

signal show_requested(message: ArenaValidationMessage)
signal select_cell_requested(message: ArenaValidationMessage)
signal auto_fix_requested(message: ArenaValidationMessage)

const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)
const CARD_BACKGROUND := Color(0.137, 0.153, 0.184)

const SEVERITY_GLYPHS := ["!", "⚠", "i"]
const SEVERITY_WORDS := ["Bloquant", "À vérifier", "Information"]
const SEVERITY_COLORS := [
	Color(1.0, 0.47, 0.40),
	Color(0.98, 0.78, 0.35),
	Color(0.68, 0.78, 0.88),
]

var readiness_label: Label = null
var summary_label: Label = null
var cards_box: VBoxContainer = null
var empty_label: Label = null
var external_error_label: Label = null

var _built := false
var _show_information := false
var _report: ArenaValidationReport = null
var _readiness := TerrainWorkflowService.READINESS_INCOMPLETE


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "Validation"
	add_theme_constant_override("separation", 4)
	readiness_label = Label.new()
	readiness_label.name = "TerrainValidationReadiness"
	readiness_label.add_theme_font_size_override("font_size", 15)
	add_child(readiness_label)
	summary_label = Label.new()
	summary_label.name = "TerrainValidationSummary"
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_color_override("font_color", MUTED)
	add_child(summary_label)
	external_error_label = Label.new()
	external_error_label.name = "TerrainValidationExternalError"
	external_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	external_error_label.add_theme_color_override("font_color", SEVERITY_COLORS[0])
	external_error_label.visible = false
	add_child(external_error_label)
	var options := HBoxContainer.new()
	add_child(options)
	var information_toggle := CheckButton.new()
	information_toggle.name = "TerrainValidationShowInformation"
	information_toggle.text = "Afficher aussi les informations"
	information_toggle.tooltip_text = (
		"Les informations décrivent le terrain ; elles n'empêchent rien."
	)
	information_toggle.toggled.connect(func(value):
		_show_information = value
		_rebuild_cards()
	)
	options.add_child(information_toggle)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 48
	add_child(scroll)
	cards_box = VBoxContainer.new()
	cards_box.name = "TerrainValidationCards"
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_box.add_theme_constant_override("separation", 4)
	scroll.add_child(cards_box)
	empty_label = Label.new()
	empty_label.name = "TerrainValidationEmpty"
	empty_label.text = "Lancez « Vérifier le terrain » pour obtenir la liste des problèmes."
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.add_theme_color_override("font_color", MUTED)
	cards_box.add_child(empty_label)


func set_report(report: ArenaValidationReport, readiness: String) -> void:
	_build()
	# Le panneau est rafraichi a chaque trait de pinceau : ne reconstruire les
	# cartes que lorsque le rapport ou l'etat de preparation change reellement.
	if _report == report and _readiness == readiness:
		return
	_report = report
	_readiness = readiness
	readiness_label.text = readiness
	readiness_label.add_theme_color_override("font_color", _readiness_color(readiness))
	if report == null:
		summary_label.text = "Le terrain n'a pas encore été vérifié."
	else:
		summary_label.text = "%d problème(s) bloquant(s) · %d point(s) à vérifier · %d information(s)." % [
			report.error_count(), report.warning_count(), report.info_count(),
		]
	_rebuild_cards()


func show_important_error(message: String) -> void:
	_build()
	external_error_label.text = "Bloquant — %s" % message
	external_error_label.visible = not message.strip_edges().is_empty()


func card_count() -> int:
	_build()
	var count := 0
	for child in cards_box.get_children():
		if child is PanelContainer:
			count += 1
	return count


func _rebuild_cards() -> void:
	for child in cards_box.get_children():
		if child == empty_label:
			continue
		cards_box.remove_child(child)
		child.queue_free()
	var messages: Array[ArenaValidationMessage] = []
	if _report != null:
		for message in _report.messages:
			if message == null:
				continue
			if message.severity == ArenaValidationMessage.Severity.INFO \
					and not _show_information:
				continue
			messages.append(message)
	messages.sort_custom(func(left, right): return left.severity < right.severity)
	empty_label.visible = messages.is_empty()
	if messages.is_empty():
		empty_label.text = "Aucun problème à corriger." if _report != null \
			else "Lancez « Vérifier le terrain » pour obtenir la liste des problèmes."
	for message in messages:
		cards_box.add_child(_build_card(message))


func _build_card(message: ArenaValidationMessage) -> PanelContainer:
	var severity := clampi(message.severity, 0, 2)
	var card := PanelContainer.new()
	card.name = "TerrainValidationCard_%s" % message.code
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BACKGROUND
	style.set_corner_radius_all(5)
	style.border_width_left = 3
	style.border_color = SEVERITY_COLORS[severity]
	style.set_content_margin_all(8)
	style.content_margin_left = 12
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var header := Label.new()
	header.text = "%s %s — %s" % [
		SEVERITY_GLYPHS[severity], SEVERITY_WORDS[severity], message.message,
	]
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_color_override("font_color", SEVERITY_COLORS[severity])
	box.add_child(header)
	var why := Label.new()
	why.text = "Pourquoi c'est important : %s" % _why_text(message)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.add_theme_color_override("font_color", MUTED)
	box.add_child(why)
	var location := Label.new()
	location.text = _location_text(message)
	location.add_theme_color_override("font_color", MUTED)
	box.add_child(location)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 4)
	box.add_child(actions)
	var localizable := message.cell != GridTransformService.INVALID_CELL
	var show_button := Button.new()
	show_button.name = "TerrainValidationShow_%s" % message.code
	show_button.text = "Me montrer"
	show_button.tooltip_text = "Recentrer la vue sur l'endroit concerné."
	show_button.disabled = not localizable
	show_button.focus_mode = Control.FOCUS_ALL
	show_button.pressed.connect(func(): show_requested.emit(message))
	actions.add_child(show_button)
	var select_button := Button.new()
	select_button.name = "TerrainValidationSelect_%s" % message.code
	select_button.text = "Sélectionner la case"
	select_button.tooltip_text = "Sélectionner la case pour la corriger à la main."
	select_button.disabled = not localizable
	select_button.focus_mode = Control.FOCUS_ALL
	select_button.pressed.connect(func(): select_cell_requested.emit(message))
	actions.add_child(select_button)
	if ArenaValidationFixService.can_fix(message):
		var fix_button := Button.new()
		fix_button.name = "TerrainValidationFix_%s" % message.code
		fix_button.text = "Corriger automatiquement"
		fix_button.tooltip_text = "%s\n%s\nCette correction est annulable." % [
			ArenaValidationFixService.fix_label(message),
			ArenaValidationFixService.fix_explanation(message),
		]
		fix_button.focus_mode = Control.FOCUS_ALL
		fix_button.pressed.connect(func(): auto_fix_requested.emit(message))
		actions.add_child(fix_button)
	return card


func _why_text(message: ArenaValidationMessage) -> String:
	if not message.why.strip_edges().is_empty():
		return message.why
	match message.severity:
		ArenaValidationMessage.Severity.ERROR:
			return "Tant que ce point n'est pas corrigé, la salle ne peut pas être testée ni intégrée."
		ArenaValidationMessage.Severity.WARNING:
			return "La salle fonctionnera, mais ce point peut rendre le combat étrange."
	return "Information sur le terrain ; aucune action n'est nécessaire."


func _location_text(message: ArenaValidationMessage) -> String:
	if message.cell != GridTransformService.INVALID_CELL:
		return "Emplacement : case (%d, %d)" % [message.cell.x, message.cell.y]
	if not str(message.subject_id).is_empty():
		return "Emplacement : %s" % message.subject_id
	return "Emplacement : terrain entier"


func _readiness_color(readiness: String) -> Color:
	match readiness:
		TerrainWorkflowService.READINESS_INTEGRABLE:
			return TerrainWorkflowService.state_color(TerrainWorkflowService.STATE_DONE)
		TerrainWorkflowService.READINESS_TESTABLE:
			return TerrainWorkflowService.state_color(TerrainWorkflowService.STATE_DOING)
	return TerrainWorkflowService.state_color(TerrainWorkflowService.STATE_ERROR)
