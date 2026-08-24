@tool
class_name TerrainCreationWizard
extends PanelContainer

## Assistant de creation d'un terrain. Il remplace le formulaire technique par
## trois intentions illustrees, puis ne demande que les informations
## necessaires a l'intention choisie.
##
## En mode guide, aucun mode visuel technique, aucun identifiant stable, aucun
## chemin et aucun manifeste n'est visible : ces reglages restent disponibles
## dans « Réglages avancés ».

signal create_confirmed(config: Dictionary)
signal cancelled
signal image_requested

const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)
const ERROR_COLOR := Color(1.0, 0.47, 0.40)
const CARD_BACKGROUND := Color(0.137, 0.153, 0.184)

const SCREEN_CHOICE := 0
const SCREEN_DETAILS := 1

## Calibrations reutilisables proposees en mode avance. La liste reste locale
## pour eviter une dependance circulaire avec ArenaStudioMain, qui instancie
## cet assistant.
const CALIBRATION_TEMPLATES := [
	"Forêt — Gué forestier",
	"Volcan — Caldeira",
	"Espace — Station orbitale",
]

var choice_screen: VBoxContainer = null
var details_screen: VBoxContainer = null
var choice_buttons: Array[Button] = []
var name_edit: LineEdit = null
var width_spin: SpinBox = null
var height_spin: SpinBox = null
var orientation_option: OptionButton = null
var image_row: HBoxContainer = null
var image_edit: LineEdit = null
var image_button: Button = null
var advanced_box: VBoxContainer = null
var id_edit: LineEdit = null
var template_option: OptionButton = null
var confirm_button: Button = null
var back_button: Button = null
var cancel_button: Button = null
var summary_label: Label = null
var blocking_label: Label = null
var choice_title: Label = null

var _built := false
var _choice := 1
var _screen := SCREEN_CHOICE
var _advanced := false
var _id_edited := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "TerrainCreationWizard"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	scroll.add_child(root)
	var title := Label.new()
	title.text = "CRÉER UN NOUVEAU TERRAIN"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ACCENT)
	root.add_child(title)
	choice_screen = _build_choice_screen()
	root.add_child(choice_screen)
	details_screen = _build_details_screen()
	root.add_child(details_screen)
	var footer := HFlowContainer.new()
	footer.add_theme_constant_override("h_separation", 6)
	root.add_child(footer)
	cancel_button = Button.new()
	cancel_button.name = "TerrainWizardCancel"
	cancel_button.text = "Revenir à l'accueil"
	cancel_button.focus_mode = Control.FOCUS_ALL
	cancel_button.pressed.connect(func(): cancelled.emit())
	footer.add_child(cancel_button)
	back_button = Button.new()
	back_button.name = "TerrainWizardBack"
	back_button.text = "Changer de méthode"
	back_button.focus_mode = Control.FOCUS_ALL
	back_button.pressed.connect(func(): _go_to(SCREEN_CHOICE))
	footer.add_child(back_button)
	confirm_button = Button.new()
	confirm_button.name = "TerrainWizardConfirm"
	confirm_button.focus_mode = Control.FOCUS_ALL
	confirm_button.pressed.connect(_on_confirm)
	footer.add_child(confirm_button)
	blocking_label = Label.new()
	blocking_label.name = "TerrainWizardBlocking"
	blocking_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blocking_label.add_theme_color_override("font_color", ERROR_COLOR)
	root.add_child(blocking_label)
	_go_to(SCREEN_CHOICE)


func start() -> void:
	_build()
	_id_edited = false
	name_edit.text = "Nouveau terrain"
	id_edit.text = ArenaDefinition.sanitize_id(name_edit.text)
	image_edit.text = ""
	width_spin.value = 10
	height_spin.value = 8
	orientation_option.select(0)
	template_option.select(0)
	_choice = 1
	_go_to(SCREEN_CHOICE)


func set_advanced(value: bool) -> void:
	_build()
	_advanced = value
	advanced_box.visible = value
	_refresh_details()


func set_image_path(path: String) -> void:
	_build()
	image_edit.text = path
	_refresh_details()


func selected_choice() -> int:
	return _choice


func current_screen() -> int:
	return _screen


func _build_choice_screen() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "TerrainWizardChoiceScreen"
	box.add_theme_constant_override("separation", 6)
	choice_title = Label.new()
	choice_title.text = "Comment voulez-vous construire ce terrain ?"
	choice_title.add_theme_color_override("font_color", MUTED)
	choice_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(choice_title)
	for index in range(TerrainVocabulary.CREATION_CHOICES.size()):
		var choice := TerrainVocabulary.creation_choice(index)
		var button := Button.new()
		button.name = "TerrainWizardChoice%d" % index
		button.text = "%s\n%s\n%s" % [
			choice.display_title, choice.summary, choice.detail,
		]
		button.tooltip_text = str(choice.detail)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 74)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		var style := StyleBoxFlat.new()
		style.bg_color = CARD_BACKGROUND
		style.set_corner_radius_all(6)
		style.border_width_left = 3
		style.border_color = ACCENT
		style.set_content_margin_all(10)
		style.content_margin_left = 14
		button.add_theme_stylebox_override("normal", style)
		button.pressed.connect(_on_choice_pressed.bind(index))
		box.add_child(button)
		choice_buttons.append(button)
	return box


func _build_details_screen() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "TerrainWizardDetailsScreen"
	box.add_theme_constant_override("separation", 5)
	summary_label = Label.new()
	summary_label.name = "TerrainWizardSummary"
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_color_override("font_color", MUTED)
	box.add_child(summary_label)
	var name_label := Label.new()
	name_label.text = "Nom visible du terrain"
	box.add_child(name_label)
	name_edit = LineEdit.new()
	name_edit.name = "TerrainWizardName"
	name_edit.placeholder_text = "Nouveau terrain"
	name_edit.text = "Nouveau terrain"
	name_edit.text_changed.connect(_on_name_changed)
	box.add_child(name_edit)
	var size_label := Label.new()
	size_label.text = "Taille en cases"
	box.add_child(size_label)
	var sizes := HBoxContainer.new()
	box.add_child(sizes)
	width_spin = _spin(sizes, "Largeur  ", 10)
	width_spin.name = "TerrainWizardWidth"
	height_spin = _spin(sizes, "Hauteur  ", 8)
	height_spin.name = "TerrainWizardHeight"
	var orientation_label := Label.new()
	orientation_label.text = "De quel côté arrivent les héros ?"
	box.add_child(orientation_label)
	orientation_option = OptionButton.new()
	orientation_option.name = "TerrainWizardOrientation"
	orientation_option.focus_mode = Control.FOCUS_ALL
	for label in TerrainVocabulary.CAMP_ORIENTATIONS:
		orientation_option.add_item(label)
	box.add_child(orientation_option)
	image_row = HBoxContainer.new()
	image_row.name = "TerrainWizardImageRow"
	box.add_child(image_row)
	image_edit = LineEdit.new()
	image_edit.name = "TerrainWizardImage"
	image_edit.placeholder_text = "Aucune illustration choisie"
	image_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_edit.editable = false
	image_row.add_child(image_edit)
	image_button = Button.new()
	image_button.name = "TerrainWizardChooseImage"
	image_button.text = "Choisir une illustration…"
	image_button.focus_mode = Control.FOCUS_ALL
	image_button.pressed.connect(func(): image_requested.emit())
	image_row.add_child(image_button)
	advanced_box = VBoxContainer.new()
	advanced_box.name = "TerrainWizardAdvanced"
	advanced_box.visible = false
	box.add_child(advanced_box)
	var advanced_title := Label.new()
	advanced_title.text = "RÉGLAGES AVANCÉS"
	advanced_title.add_theme_font_size_override("font_size", 13)
	advanced_title.add_theme_color_override("font_color", ACCENT)
	advanced_box.add_child(advanced_title)
	var id_label := Label.new()
	id_label.text = "Identifiant stable"
	advanced_box.add_child(id_label)
	id_edit = LineEdit.new()
	id_edit.name = "TerrainWizardId"
	id_edit.text_changed.connect(func(_value): _id_edited = true)
	advanced_box.add_child(id_edit)
	var template_label := Label.new()
	template_label.text = "Reprendre une calibration existante"
	advanced_box.add_child(template_label)
	template_option = OptionButton.new()
	template_option.name = "TerrainWizardTemplate"
	template_option.add_item("Partir d'un terrain vide")
	for entry in CALIBRATION_TEMPLATES:
		template_option.add_item("Copier la calibration : %s" % entry)
	advanced_box.add_child(template_option)
	return box


func _spin(parent: Node, prefix: String, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.prefix = prefix
	spin.min_value = 1
	spin.max_value = 64
	spin.step = 1
	spin.value = value
	spin.value_changed.connect(func(_v): _refresh_details())
	parent.add_child(spin)
	return spin


func _on_choice_pressed(index: int) -> void:
	_choice = index
	_go_to(SCREEN_DETAILS)


func _on_name_changed(value: String) -> void:
	if not _id_edited:
		id_edit.text = ArenaDefinition.sanitize_id(value)
	_refresh_details()


func _go_to(screen: int) -> void:
	_screen = screen
	choice_screen.visible = screen == SCREEN_CHOICE
	details_screen.visible = screen == SCREEN_DETAILS
	back_button.visible = screen == SCREEN_DETAILS
	confirm_button.visible = screen == SCREEN_DETAILS
	blocking_label.visible = screen == SCREEN_DETAILS
	for index in range(choice_buttons.size()):
		choice_buttons[index].set_pressed_no_signal(index == _choice)
	_refresh_details()


func _refresh_details() -> void:
	if summary_label == null:
		return
	var choice := TerrainVocabulary.creation_choice(_choice)
	summary_label.text = "%s — %s" % [choice.display_title, choice.detail]
	image_row.visible = bool(choice.needs_image)
	confirm_button.text = str(choice.confirm_label)
	confirm_button.tooltip_text = (
		"Créer le terrain puis ouvrir directement l'étape suivante."
	)
	var blocking := _blocking_reason(choice)
	blocking_label.text = blocking
	confirm_button.disabled = not blocking.is_empty()


func _blocking_reason(choice: Dictionary) -> String:
	if name_edit.text.strip_edges().is_empty():
		return "Donnez d'abord un nom visible à ce terrain."
	if bool(choice.needs_image) and image_edit.text.strip_edges().is_empty():
		return "Choisissez une illustration : cette méthode en a besoin."
	return ""


func _on_confirm() -> void:
	var choice := TerrainVocabulary.creation_choice(_choice)
	if not _blocking_reason(choice).is_empty():
		return
	create_confirmed.emit({
		"visual_mode": int(choice.visual_mode),
		"display_name": name_edit.text.strip_edges(),
		"arena_id": ArenaDefinition.sanitize_id(
			id_edit.text if _advanced and not id_edit.text.strip_edges().is_empty()
			else name_edit.text
		),
		"width": int(width_spin.value),
		"height": int(height_spin.value),
		"camp_orientation": orientation_option.selected,
		"image_path": image_edit.text.strip_edges(),
		"template_index": template_option.selected if _advanced else 0,
		"needs_image": bool(choice.needs_image),
	})
