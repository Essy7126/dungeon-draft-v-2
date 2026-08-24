@tool
class_name TerrainHeaderBar
extends PanelContainer

signal home_requested
signal create_requested
signal open_requested
signal guided_toggled(value: bool)
signal preview_selected(index: int)

var home_button: Button
var new_terrain_button: Button
var open_terrain_button: Button
var guided_toggle: CheckButton
var preview_option: OptionButton
var document_state_label: Label


func _init() -> void:
	name = "TerrainHeaderBar"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 5)
	box.add_child(actions)

	var domain_title := Label.new()
	domain_title.name = "TerrainDomainTitle"
	domain_title.text = TerrainVocabulary.TAB_TITLE
	domain_title.add_theme_font_size_override("font_size", 16)
	domain_title.add_theme_color_override("font_color", Color(0.52, 0.88, 1.0))
	domain_title.tooltip_text = TerrainVocabulary.TAB_SUBTITLE
	actions.add_child(domain_title)

	var domain_subtitle := Label.new()
	domain_subtitle.name = "TerrainDomainSubtitle"
	domain_subtitle.text = TerrainVocabulary.TAB_SUBTITLE
	domain_subtitle.add_theme_color_override("font_color", Color(0.72, 0.77, 0.84))
	actions.add_child(domain_subtitle)

	home_button = _action(actions, "TerrainHomeButton", "Accueil",
		"Revenir à l'écran d'accueil des terrains")
	home_button.pressed.connect(home_requested.emit)
	new_terrain_button = _action(actions, "TerrainNewButton", "+ Nouveau terrain",
		"Créer un nouveau terrain")
	new_terrain_button.pressed.connect(create_requested.emit)
	open_terrain_button = _action(actions, "TerrainOpenButton", "Ouvrir…",
		"Ouvrir un terrain déjà enregistré")
	open_terrain_button.pressed.connect(open_requested.emit)

	guided_toggle = CheckButton.new()
	guided_toggle.name = "TerrainGuidedToggle"
	guided_toggle.text = "Mode guidé"
	guided_toggle.button_pressed = true
	guided_toggle.focus_mode = Control.FOCUS_ALL
	guided_toggle.tooltip_text = (
		"Le mode guidé masque les réglages techniques et affiche les consignes. "
		+ "Le mode avancé rend tout accessible."
	)
	guided_toggle.toggled.connect(guided_toggled.emit)
	actions.add_child(guided_toggle)

	preview_option = OptionButton.new()
	preview_option.name = "TerrainPreviewOption"
	preview_option.focus_mode = Control.FOCUS_ALL
	preview_option.tooltip_text = "Choisir ce que montre la zone centrale"
	for index in range(TerrainVocabulary.PREVIEW_LABELS.size()):
		preview_option.add_item(TerrainVocabulary.PREVIEW_LABELS[index])
		preview_option.set_item_tooltip(index, TerrainVocabulary.PREVIEW_TOOLTIPS[index])
	preview_option.item_selected.connect(preview_selected.emit)
	actions.add_child(preview_option)

	document_state_label = Label.new()
	document_state_label.name = "TerrainDocumentState"
	document_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	document_state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(document_state_label)


func _action(
		parent: Control,
		control_name: String,
		label: String,
		tooltip: String
	) -> Button:
	var button := Button.new()
	button.name = control_name
	button.text = label
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	parent.add_child(button)
	return button
