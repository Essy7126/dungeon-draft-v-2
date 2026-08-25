@tool
class_name TerrainLibraryPanel
extends PanelContainer

## Bibliothèque visuelle commune. Elle filtre et présente les descripteurs
## fournis par TerrainPlaceableCatalogService sans interpréter leur payload.

signal placeable_selected(entry: Dictionary)
signal card_action_requested(action: StringName, entry: Dictionary)
signal state_changed(state: Dictionary)

const FILTERS := [
	["Tous", -1],
	["Sols", TerrainPlaceableDefinition.Family.FLOOR],
	["Obstacles", TerrainPlaceableDefinition.Family.OBSTACLE],
	["Départs", TerrainPlaceableDefinition.Family.SPAWN],
	["Interactifs", TerrainPlaceableDefinition.Family.INTERACTIVE],
	["Décor", TerrainPlaceableDefinition.Family.DECORATION],
	["Récents", -2],
	["Favoris", -3],
]
const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)

var search_edit: LineEdit = null
var filter_buttons: Array[Button] = []
var cards: HFlowContainer = null
var empty_label: Label = null

var _entries: Array[Dictionary] = []
var _filter := -1
var _selected_id: StringName = &""
var _recents: Array[StringName] = []
var _favorites: Array[StringName] = []
var _built := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "TerrainLibraryPanel"
	custom_minimum_size.y = 160
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 4)
	filters.add_theme_constant_override("v_separation", 3)
	root.add_child(filters)
	for index in range(FILTERS.size()):
		var definition: Array = FILTERS[index]
		var button := Button.new()
		button.name = "TerrainLibraryFilter%d" % index
		button.text = str(definition[0])
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_filter_pressed.bind(int(definition[1])))
		filters.add_child(button)
		filter_buttons.append(button)
	filter_buttons[0].set_pressed_no_signal(true)
	search_edit = LineEdit.new()
	search_edit.name = "TerrainLibrarySearch"
	search_edit.placeholder_text = "Rechercher un sol, un obstacle, un départ…"
	search_edit.clear_button_enabled = true
	search_edit.text_changed.connect(func(_value): _refresh_cards())
	root.add_child(search_edit)
	var scroll := ScrollContainer.new()
	scroll.name = "TerrainLibraryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	cards = HFlowContainer.new()
	cards.name = "TerrainLibraryCards"
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 5)
	cards.add_theme_constant_override("v_separation", 5)
	scroll.add_child(cards)
	empty_label = Label.new()
	empty_label.text = "Aucun élément ne correspond à ce filtre."
	empty_label.add_theme_color_override("font_color", MUTED)
	empty_label.visible = false
	root.add_child(empty_label)


func set_entries(entries: Array[Dictionary]) -> void:
	_build()
	_entries = entries.duplicate(true)
	_refresh_cards()


func select_entry(stable_id: StringName, remember := true) -> void:
	_selected_id = stable_id
	if remember and stable_id != &"":
		_recents.erase(stable_id)
		_recents.push_front(stable_id)
		while _recents.size() > 8:
			_recents.pop_back()
	_refresh_cards()
	state_changed.emit(get_state())


func selected_id() -> StringName:
	return _selected_id


func get_state() -> Dictionary:
	return {
		"filter": _filter,
		"selected_id": _selected_id,
		"recents": _recents.duplicate(),
		"favorites": _favorites.duplicate(),
	}


func apply_state(state: Dictionary) -> void:
	_build()
	_filter = int(state.get("filter", -1))
	_selected_id = StringName(state.get("selected_id", &""))
	_recents.assign(state.get("recents", []))
	_favorites.assign(state.get("favorites", []))
	_refresh_filter_buttons()
	_refresh_cards()


func _on_filter_pressed(value: int) -> void:
	_filter = value
	_refresh_filter_buttons()
	_refresh_cards()
	state_changed.emit(get_state())


func _refresh_filter_buttons() -> void:
	for index in range(filter_buttons.size()):
		filter_buttons[index].set_pressed_no_signal(int(FILTERS[index][1]) == _filter)


func _refresh_cards() -> void:
	if cards == null:
		return
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	var query := search_edit.text.strip_edges().to_lower() if search_edit != null else ""
	var visible_count := 0
	for entry in _entries:
		if not _matches(entry, query):
			continue
		cards.add_child(_card(entry))
		visible_count += 1
	empty_label.visible = visible_count == 0


func _matches(entry: Dictionary, query: String) -> bool:
	var stable_id := StringName(entry.get("stable_id", &""))
	if _filter >= 0 and int(entry.get("family", -1)) != _filter:
		return false
	if _filter == -2 and not _recents.has(stable_id):
		return false
	if _filter == -3 and not _favorites.has(stable_id):
		return false
	if query.is_empty():
		return true
	var searchable := "%s %s %s" % [
		entry.get("display_name", ""), entry.get("family_label", ""),
		" ".join(entry.get("badges", PackedStringArray())),
	]
	return searchable.to_lower().contains(query)


func _card(entry: Dictionary) -> Control:
	var stable_id := StringName(entry.get("stable_id", &""))
	var node_id := str(stable_id).replace(":", "_")
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(204, 42)
	row.add_theme_constant_override("separation", 2)
	var button := Button.new()
	button.name = "TerrainLibraryCard_%s" % node_id
	button.toggle_mode = true
	button.button_pressed = stable_id == _selected_id
	button.disabled = not bool(entry.get("enabled", false))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(148, 42)
	button.add_theme_constant_override("icon_max_width", 28)
	button.icon = entry.get("thumbnail") as Texture2D
	var badges: PackedStringArray = entry.get("badges", PackedStringArray())
	button.text = "%s\n%s" % [
		entry.get("display_name", stable_id),
		" · ".join(badges) if not badges.is_empty() else entry.get("family_label", ""),
	]
	button.tooltip_text = str(entry.get("tooltip", ""))
	var disabled_reason := str(entry.get("disabled_reason", ""))
	if button.disabled and not disabled_reason.is_empty():
		button.tooltip_text += "\nIndisponible : %s" % disabled_reason
	button.pressed.connect(func():
		select_entry(stable_id)
		placeable_selected.emit(entry)
	)
	row.add_child(button)
	var favorite := Button.new()
	favorite.name = "TerrainLibraryFavorite_%s" % node_id
	favorite.text = "★" if _favorites.has(stable_id) else "☆"
	favorite.tooltip_text = "Retirer des favoris" if _favorites.has(stable_id) \
		else "Ajouter aux favoris"
	favorite.focus_mode = Control.FOCUS_ALL
	favorite.pressed.connect(func(): _toggle_favorite(stable_id))
	row.add_child(favorite)
	if int(entry.get("family", -1)) == TerrainPlaceableDefinition.Family.FLOOR:
		var menu := MenuButton.new()
		menu.name = "TerrainLibraryMenu_%s" % node_id
		menu.text = "⋮"
		menu.tooltip_text = "Actions pour ce type de tuile"
		menu.focus_mode = Control.FOCUS_ALL
		menu.get_popup().add_item("Modifier ce type de tuile…", 0)
		menu.get_popup().add_item("Remplacer partout ce sol…", 1)
		menu.get_popup().id_pressed.connect(func(id: int):
			card_action_requested.emit(
				&"edit_terrain_type" if id == 0 else &"replace_terrain",
				entry
			)
		)
		row.add_child(menu)
	return row


func _toggle_favorite(stable_id: StringName) -> void:
	if _favorites.has(stable_id):
		_favorites.erase(stable_id)
	else:
		_favorites.append(stable_id)
	_refresh_cards()
	state_changed.emit(get_state())
