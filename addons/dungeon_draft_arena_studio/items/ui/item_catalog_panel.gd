@tool
class_name ItemCatalogPanel
extends VBoxContainer

signal entry_requested(entry: Dictionary)
signal filters_changed(filters: Dictionary)

var search_edit: LineEdit
var category_filter: OptionButton
var rarity_filter: OptionButton
var slot_filter: OptionButton
var hero_filter: OptionButton
var reward_filter: OptionButton
var status_filter: OptionButton
var sort_option: OptionButton
var item_list: ItemList
var _entries: Array[Dictionary] = []


func _ready() -> void:
	custom_minimum_size.x = 250
	var title := Label.new()
	title.text = "CATALOGUE DES OBJETS"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Nom, item_id ou tag…"
	search_edit.tooltip_text = "Recherche dans le nom, l’identifiant, les tags et le chemin"
	search_edit.text_changed.connect(func(_value): _refresh())
	add_child(search_edit)
	category_filter = _filter(["Toutes catégories", "Arme", "Armure", "Accessoire", "Consommable", "Parchemin"])
	rarity_filter = _filter(["Toutes raretés", "common", "uncommon", "rare"])
	slot_filter = _filter(["Tous emplacements", "Aucun", "Arme", "Armure", "Accessoire"])
	hero_filter = _filter(["Tous les héros", "Elfe", "Mage", "Guerrier", "Universel"])
	reward_filter = _filter(["Récompenses : toutes", "Éligibles", "Non éligibles"])
	status_filter = _filter(["Tous statuts", "Production", "Brouillon", "Legacy", "Invalide"])
	sort_option = _filter(["Tri : nom", "Tri : item_id", "Tri : rareté", "Tri : catégorie", "Tri : chemin"])
	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.select_mode = ItemList.SELECT_SINGLE
	item_list.item_selected.connect(_on_item_selected)
	add_child(item_list)


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


func _filter(labels: Array[String]) -> OptionButton:
	var option := OptionButton.new()
	for label in labels:
		option.add_item(label)
	option.item_selected.connect(func(_index): _refresh())
	add_child(option)
	return option


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
		var badge := ""
		if StringName(entry.get("status", &"")) == ItemStudioCatalogService.DRAFT_STATUS:
			badge = " [BROUILLON]"
		elif StringName(entry.get("status", &"")) == ItemStudioCatalogService.INVALID_STATUS:
			badge = " [ERREUR]"
		elif bool(entry.get("reward_eligible", false)):
			badge = " [RÉCOMPENSE]"
		var index := item_list.add_item("%s%s\n%s" % [
			entry.get("display_name", "Objet"), badge, entry.get("item_id", "")
		])
		item_list.set_item_metadata(index, entry)
		item_list.set_item_tooltip(index, str(entry.get("path", "")))
	filters_changed.emit(snapshot_filters())


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
