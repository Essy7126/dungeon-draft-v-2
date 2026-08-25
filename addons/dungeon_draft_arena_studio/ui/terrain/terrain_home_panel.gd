@tool
class_name TerrainHomePanel
extends PanelContainer

## Ecran d'accueil du domaine Terrain. Les trois intentions nominales partent
## d'ici sans assistant plein ecran : ouvrir, creer depuis une illustration ou
## creer directement avec des tuiles.

signal create_from_image_requested
signal create_with_tiles_requested
signal open_requested
signal recent_selected(entry: Dictionary)

const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)
const CARD_BACKGROUND := Color(0.137, 0.153, 0.184)

var image_card: Button = null
var tiles_card: Button = null
var open_card: Button = null
var recents_list: ItemList = null
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

	open_card = _card(
		root, "TerrainHomeOpen",
		"Ouvrir un terrain existant",
		"Reprendre un terrain déjà enregistré dans le projet."
	)
	open_card.pressed.connect(func(): open_requested.emit())

	image_card = _card(
		root, "TerrainHomeCreateFromImage",
		"Créer depuis une illustration",
		"Choisir immédiatement une image, puis ajuster une grille 3 × 3 dessus."
	)
	image_card.pressed.connect(func(): create_from_image_requested.emit())

	tiles_card = _card(
		root, "TerrainHomeCreateWithTiles",
		"Créer avec des tuiles",
		"Ouvrir immédiatement un terrain 10 × 8 prêt à peindre."
	)
	tiles_card.pressed.connect(func(): create_with_tiles_requested.emit())

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
