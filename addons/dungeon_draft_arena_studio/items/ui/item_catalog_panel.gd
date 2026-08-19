@tool
class_name ItemCatalogPanel
extends VBoxContainer

signal entry_requested(entry: Dictionary)
signal filters_changed(filters: Dictionary)

const ACCENT_COLOR := Color(0.48, 0.86, 1.0)
const MUTED_COLOR := Color(0.72, 0.77, 0.84)
const BADGE_SIZE := 12
const NEUTRAL_BADGE := Color(0.38, 0.44, 0.52)
const REWARD_BADGE := Color(0.36, 0.78, 1.0)
const STATUS_BADGES := {
	&"DRAFT": Color(0.98, 0.72, 0.28),
	&"INVALID": Color(1.0, 0.42, 0.36),
	&"LEGACY": Color(0.62, 0.66, 0.74),
}
const STATUS_LABELS := {
	&"SHARED": "Production",
	&"DRAFT": "Brouillon",
	&"LEGACY": "Legacy",
	&"INVALID": "Invalide",
}

static var _badge_textures := {}

var search_edit: LineEdit
var category_filter: OptionButton
var rarity_filter: OptionButton
var slot_filter: OptionButton
var hero_filter: OptionButton
var reward_filter: OptionButton
var status_filter: OptionButton
var sort_option: OptionButton
var item_list: ItemList
var count_label: Label
var filters_fold: FoldableContainer
var _entries: Array[Dictionary] = []


func _ready() -> void:
	custom_minimum_size.x = 264
	add_theme_constant_override("separation", 0)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	content.add_child(_build_header())
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Nom, item_id ou tag…"
	search_edit.tooltip_text = "Recherche dans le nom, l’identifiant, les tags et le chemin"
	search_edit.clear_button_enabled = true
	search_edit.text_changed.connect(func(_value): _refresh())
	content.add_child(search_edit)
	content.add_child(_build_filters())
	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.custom_minimum_size.y = 260
	item_list.select_mode = ItemList.SELECT_SINGLE
	item_list.fixed_icon_size = Vector2i(BADGE_SIZE, BADGE_SIZE)
	item_list.add_theme_constant_override("v_separation", 7)
	item_list.add_theme_constant_override("icon_margin", 6)
	item_list.item_selected.connect(_on_item_selected)
	content.add_child(item_list)


func set_entries(entries: Array[Dictionary]) -> void:
	_entries = entries.duplicate(false)
	_refresh()


func snapshot_filters() -> Dictionary:
	return {
		"search": search_edit.text if search_edit != null else "",
		"category": category_filter.selected if category_filter != null else 0,
		"rarity": rarity_filter.selected if rarity_filter != null else 0,
		"slot": slot_filter.selected if slot_filter != null else 0,
		"hero": hero_filter.selected if hero_filter != null else 0,
		"reward": reward_filter.selected if reward_filter != null else 0,
		"status": status_filter.selected if status_filter != null else 0,
		"sort": sort_option.selected if sort_option != null else 0,
	}


func restore_filters(state: Dictionary) -> void:
	if search_edit == null:
		return
	search_edit.text = str(state.get("search", ""))
	for pair in [
		[category_filter, "category"], [rarity_filter, "rarity"],
		[slot_filter, "slot"], [hero_filter, "hero"],
		[reward_filter, "reward"], [status_filter, "status"],
		[sort_option, "sort"],
	]:
		var option := pair[0] as OptionButton
		option.select(clampi(int(state.get(pair[1], 0)), 0, option.item_count - 1))
	_refresh()


func select_path(path: String) -> bool:
	for index in range(item_list.item_count):
		var entry := item_list.get_item_metadata(index) as Dictionary
		if str(entry.get("path", "")) == path:
			item_list.select(index)
			item_list.ensure_current_is_visible()
			return true
	return false


func _build_header() -> Control:
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "CATALOGUE"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	count_label = Label.new()
	count_label.add_theme_color_override("font_color", MUTED_COLOR)
	count_label.tooltip_text = "Objets affichés sur objets connus du catalogue"
	header.add_child(count_label)
	return header


func _build_filters() -> Control:
	filters_fold = FoldableContainer.new()
	filters_fold.title = "Filtres"
	filters_fold.folded = true
	filters_fold.tooltip_text = "Afficher ou masquer les filtres du catalogue"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 8)
	filters_fold.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	category_filter = _filter(box, ["Toutes catégories", "Arme", "Armure", "Accessoire", "Consommable", "Parchemin", "Relique"])
	rarity_filter = _filter(box, ["Toutes raretés", "common", "uncommon", "rare"])
	slot_filter = _filter(box, ["Tous emplacements", "Aucun", "Arme", "Armure", "Accessoire"])
	hero_filter = _filter(box, ["Tous les héros", "Elfe", "Mage", "Guerrier", "Universel"])
	reward_filter = _filter(box, ["Récompenses : toutes", "Éligibles", "Non éligibles"])
	status_filter = _filter(box, ["Tous statuts", "Production", "Brouillon", "Legacy", "Invalide"])
	box.add_child(HSeparator.new())
	sort_option = _filter(box, ["Tri : nom", "Tri : item_id", "Tri : rareté", "Tri : catégorie", "Tri : chemin"])
	var reset := Button.new()
	reset.text = "Réinitialiser les filtres"
	reset.tooltip_text = "Rétablir la recherche, les filtres et le tri par défaut"
	reset.pressed.connect(_reset_filters)
	box.add_child(reset)
	return filters_fold


func _filter(parent: Control, labels: Array[String]) -> OptionButton:
	var option := OptionButton.new()
	for label in labels:
		option.add_item(label)
	option.fit_to_longest_item = false
	option.clip_text = true
	option.item_selected.connect(func(_index): _refresh())
	parent.add_child(option)
	return option


func _reset_filters() -> void:
	search_edit.text = ""
	for option in [
		category_filter, rarity_filter, slot_filter,
		hero_filter, reward_filter, status_filter, sort_option,
	]:
		(option as OptionButton).select(0)
	_refresh()


func _refresh() -> void:
	if item_list == null:
		return
	item_list.clear()
	var filtered: Array[Dictionary] = []
	for entry in _entries:
		if _matches(entry):
			filtered.append(entry)
	_sort_entries(filtered)
	for entry in filtered:
		var index := item_list.add_item(str(entry.get("display_name", "Objet")))
		item_list.set_item_icon(index, _badge_texture(_badge_color(entry)))
		item_list.set_item_metadata(index, entry)
		item_list.set_item_tooltip(index, _entry_tooltip(entry))
	_refresh_counters(filtered.size())
	filters_changed.emit(snapshot_filters())


func _refresh_counters(visible_count: int) -> void:
	if count_label != null:
		count_label.text = "%d objet%s" % [visible_count, "s" if visible_count > 1 else ""] \
			if visible_count == _entries.size() \
			else "%d / %d" % [visible_count, _entries.size()]
	if filters_fold == null:
		return
	var active := _active_filter_count()
	filters_fold.title = "Filtres" if active == 0 else "Filtres (%d)" % active


func _active_filter_count() -> int:
	var active := 0
	for option in [
		category_filter, rarity_filter, slot_filter,
		hero_filter, reward_filter, status_filter,
	]:
		if option != null and (option as OptionButton).selected > 0:
			active += 1
	return active


func _badge_color(entry: Dictionary) -> Color:
	var status := StringName(entry.get("status", &""))
	if STATUS_BADGES.has(status):
		return STATUS_BADGES[status]
	if bool(entry.get("reward_eligible", false)):
		return REWARD_BADGE
	return NEUTRAL_BADGE


func _entry_tooltip(entry: Dictionary) -> String:
	var status := StringName(entry.get("status", &""))
	var lines: Array[String] = []
	lines.append("%s · %s" % [entry.get("display_name", "Objet"), entry.get("item_id", "")])
	lines.append("Statut : %s%s" % [
		STATUS_LABELS.get(status, str(status)),
		" · éligible aux récompenses" if bool(entry.get("reward_eligible", false)) else "",
	])
	lines.append(str(entry.get("path", "")))
	return "\n".join(lines)


static func _badge_texture(color: Color) -> ImageTexture:
	var key := color.to_html(false)
	if _badge_textures.has(key):
		return _badge_textures[key]
	var image := Image.create_empty(BADGE_SIZE, BADGE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center := (BADGE_SIZE - 1) * 0.5
	var radius := BADGE_SIZE * 0.5 - 1.0
	for y in BADGE_SIZE:
		for x in BADGE_SIZE:
			var coverage := clampf(radius - Vector2(x - center, y - center).length() + 0.5, 0.0, 1.0)
			if coverage > 0.0:
				image.set_pixel(x, y, Color(color.r, color.g, color.b, coverage))
	var texture := ImageTexture.create_from_image(image)
	_badge_textures[key] = texture
	return texture


func _matches(entry: Dictionary) -> bool:
	var search := search_edit.text.strip_edges().to_lower()
	if not search.is_empty():
		var haystack := "%s %s %s %s" % [
			entry.get("display_name", ""), entry.get("item_id", ""),
			" ".join(_strings(entry.get("tags", []) as Array)), entry.get("path", ""),
		]
		if not haystack.to_lower().contains(search):
			return false
	if category_filter.selected > 0 and int(entry.get("category", -1)) != category_filter.selected - 1:
		return false
	if rarity_filter.selected > 0 and str(entry.get("rarity", "")) != rarity_filter.get_item_text(rarity_filter.selected):
		return false
	if slot_filter.selected > 0:
		var expected_slot := slot_filter.selected - 2
		if int(entry.get("slot", -99)) != expected_slot:
			return false
	if hero_filter.selected > 0:
		var ids := entry.get("compatible_character_ids", []) as Array
		if hero_filter.selected == 4 and not ids.is_empty():
			return false
		if hero_filter.selected < 4:
			var expected: StringName = [&"elf", &"mage", &"warrior"][hero_filter.selected - 1]
			if not ids.is_empty() and expected not in ids:
				return false
	if reward_filter.selected == 1 and not bool(entry.get("reward_eligible", false)):
		return false
	if reward_filter.selected == 2 and bool(entry.get("reward_eligible", false)):
		return false
	if status_filter.selected > 0:
		var expected_status: StringName = [&"SHARED", &"DRAFT", &"LEGACY", &"INVALID"][status_filter.selected - 1]
		if StringName(entry.get("status", &"")) != expected_status:
			return false
	return true


func _sort_entries(entries: Array[Dictionary]) -> void:
	var keys := ["display_name", "item_id", "rarity", "category", "path"]
	var key: String = keys[sort_option.selected]
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get(key, "")).naturalnocasecmp_to(str(b.get(key, ""))) < 0
	)


func _on_item_selected(index: int) -> void:
	entry_requested.emit(item_list.get_item_metadata(index) as Dictionary)


func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
