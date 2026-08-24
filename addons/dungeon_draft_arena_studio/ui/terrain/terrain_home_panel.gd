@tool
class_name TerrainHomePanel
extends PanelContainer

## Ecran d'accueil du domaine Terrain. C'est le seul point d'entree du
## parcours : il rend visibles « modifier la salle active », « creer »,
## « ouvrir », l'exercice d'entrainement et les terrains recents, sans
## dependre de la barre interne que l'hote masque.

signal edit_active_room_requested
signal create_requested
signal open_requested
signal sandbox_requested
signal recent_selected(entry: Dictionary)
signal glossary_requested

const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)
const CARD_BACKGROUND := Color(0.137, 0.153, 0.184)

var active_card: Button = null
var create_card: Button = null
var open_card: Button = null
var sandbox_button: Button = null
var glossary_button: Button = null
var recents_list: ItemList = null
var active_summary: Label = null
var recents_empty_label: Label = null

var _built := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "TerrainHomePanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	scroll.add_child(root)

	var title := Label.new()
	title.name = "TerrainHomeTitle"
	title.text = TerrainVocabulary.TAB_TITLE
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", ACCENT)
	root.add_child(title)
	var subtitle := Label.new()
	subtitle.name = "TerrainHomeSubtitle"
	subtitle.text = TerrainVocabulary.TAB_SUBTITLE
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", MUTED)
	root.add_child(subtitle)

	var intro := Label.new()
	intro.text = (
		"Un terrain est la zone tactique d'une salle : sa grille, ses sols, "
		+ "ses obstacles et ses points de départ. Choisissez par quoi commencer."
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", MUTED)
	root.add_child(intro)

	active_card = _card(
		root, "TerrainHomeEditActiveRoom",
		"Modifier le terrain de la salle active",
		"Reprendre la salle déjà sélectionnée dans la partie en cours."
	)
	active_card.pressed.connect(func(): edit_active_room_requested.emit())
	active_summary = Label.new()
	active_summary.name = "TerrainHomeActiveSummary"
	active_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_summary.add_theme_color_override("font_color", MUTED)
	root.add_child(active_summary)

	create_card = _card(
		root, "TerrainHomeCreate",
		"Créer un nouveau terrain",
		"Trois façons de commencer : illustration, tuiles, ou les deux."
	)
	create_card.pressed.connect(func(): create_requested.emit())

	open_card = _card(
		root, "TerrainHomeOpen",
		"Ouvrir un terrain existant",
		"Reprendre un terrain déjà enregistré dans le projet."
	)
	open_card.pressed.connect(func(): open_requested.emit())

	var secondary := HFlowContainer.new()
	secondary.add_theme_constant_override("h_separation", 8)
	root.add_child(secondary)
	sandbox_button = Button.new()
	sandbox_button.name = "TerrainHomeSandbox"
	sandbox_button.text = "Faire l'exercice d'entraînement"
	sandbox_button.tooltip_text = (
		"Un terrain d'essai complet dans votre dossier personnel. "
		+ "Aucune partie officielle n'est modifiée."
	)
	sandbox_button.pressed.connect(func(): sandbox_requested.emit())
	secondary.add_child(sandbox_button)
	glossary_button = Button.new()
	glossary_button.name = "TerrainHomeGlossary"
	glossary_button.text = "Que veulent dire ces mots ?"
	glossary_button.tooltip_text = "Ouvrir le glossaire du Studio Terrain."
	glossary_button.pressed.connect(func(): glossary_requested.emit())
	secondary.add_child(glossary_button)

	var recents_title := Label.new()
	recents_title.text = "TERRAINS RÉCEMMENT OUVERTS"
	recents_title.add_theme_font_size_override("font_size", 14)
	recents_title.add_theme_color_override("font_color", ACCENT)
	root.add_child(recents_title)
	recents_empty_label = Label.new()
	recents_empty_label.name = "TerrainHomeRecentsEmpty"
	recents_empty_label.text = (
		"Aucun terrain ouvert pour l'instant. Les prochains apparaîtront ici."
	)
	recents_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recents_empty_label.add_theme_color_override("font_color", MUTED)
	root.add_child(recents_empty_label)
	recents_list = ItemList.new()
	recents_list.name = "TerrainHomeRecents"
	recents_list.custom_minimum_size.y = 116
	recents_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recents_list.item_activated.connect(_on_recent_activated)
	recents_list.item_selected.connect(_on_recent_activated)
	root.add_child(recents_list)


func refresh(context := {}) -> void:
	_build()
	var label := str(context.get("active_room_label", ""))
	var available := bool(context.get("active_room_available", false))
	active_card.disabled = not available
	if available:
		active_summary.text = "Salle active : %s" % label
	else:
		active_summary.text = (
			"Aucune salle active pour l'instant. Créez un terrain, ouvrez-en un, "
			+ "ou choisissez une partie dans la barre de contexte au-dessus."
		)
	var entries: Array = context.get("recents", [])
	recents_list.clear()
	for value in entries:
		var entry := value as Dictionary
		var display := str(entry.get("label", ""))
		if display.strip_edges().is_empty():
			display = str(entry.get("session_key", "terrain"))
		recents_list.add_item(display)
		recents_list.set_item_metadata(recents_list.item_count - 1, entry)
		recents_list.set_item_tooltip(
			recents_list.item_count - 1,
			"Ouvert le %s" % entry.get("opened_at", "—")
		)
	recents_list.visible = recents_list.item_count > 0
	recents_empty_label.visible = recents_list.item_count == 0


func _on_recent_activated(index: int) -> void:
	if index < 0 or index >= recents_list.item_count:
		return
	var entry = recents_list.get_item_metadata(index)
	if entry is Dictionary:
		recent_selected.emit(entry as Dictionary)


func _card(
		parent: Node,
		node_name: String,
		title_text: String,
		description: String
	) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = "%s\n%s" % [title_text, description]
	button.tooltip_text = description
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 58)
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
	parent.add_child(button)
	return button
