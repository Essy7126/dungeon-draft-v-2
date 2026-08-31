@tool
class_name ItemCatalogPanel
extends VBoxContainer

signal entry_requested(entry: Dictionary)
signal filters_changed(filters: Dictionary)
signal reward_bulk_apply_requested(changes: Array[Dictionary])

const ACCENT_COLOR := Color(0.48, 0.86, 1.0)
const MUTED_COLOR := Color(0.72, 0.77, 0.84)
const BADGE_SIZE := 12
const NEUTRAL_BADGE := Color(0.38, 0.44, 0.52)
const REWARD_BADGE := Color(0.36, 0.78, 1.0)
const PENDING_BACKGROUND := Color(1.0, 0.75, 0.41, 0.16)
const NO_BACKGROUND := Color(0.0, 0.0, 0.0, 0.0)
# ItemList n'a pas d'élément cochable natif (cette API appartient à PopupMenu) :
# l'unique icône de ligne devient une texture composite [case][pastille], et le
# clic ne bascule que dans la bande de gauche. Voir _on_item_list_gui_input.
const CHECK_SIZE := 12
const ICON_GAP := 4
const ROW_ICON_WIDTH := CHECK_SIZE + ICON_GAP + BADGE_SIZE
const CHECK_NONE := 0
const CHECK_OFF := 1
const CHECK_ON := 2
const CHECK_ON_COLOR := Color(0.36, 0.78, 1.0)
const CHECK_OFF_COLOR := Color(0.55, 0.60, 0.68)
const PENDING_COLOR := Color(1.0, 0.75, 0.41)
const REWARD_COLUMN_TOOLTIP := "Un objet coché peut apparaître comme récompense en début de partie. Décoché, il reste dans le catalogue mais n’est jamais tiré — rien n’est supprimé."
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
var reward_header: Label
var apply_bar: HBoxContainer
var apply_button: Button
var cancel_button: Button
var _entries: Array[Dictionary] = []
var _hero_entries: Array[Dictionary] = []
# Chemin de ressource -> état de récompense voulu, tant qu'il diffère du fichier.
# Une entrée disparaît d'elle-même dès que le disque rattrape l'intention.
var _pending_rewards := {}


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
	content.add_child(_build_reward_column_header())
	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Plancher volontairement bas : c’est lui qui limite jusqu’où la poignée du
	# VSplitContainer peut agrandir le panneau d’analyse. La liste s’étend déjà
	# d’elle-même (SIZE_EXPAND_FILL) dès qu’il y a de la place.
	item_list.custom_minimum_size.y = 120
	item_list.select_mode = ItemList.SELECT_SINGLE
	item_list.fixed_icon_size = Vector2i(ROW_ICON_WIDTH, BADGE_SIZE)
	item_list.add_theme_constant_override("v_separation", 7)
	item_list.add_theme_constant_override("icon_margin", 6)
	item_list.item_selected.connect(_on_item_selected)
	# Le signal gui_input est émis avant que l'ItemList ne traite l'événement
	# lui-même : c'est le seul point où l'on peut intercepter un clic sur la case
	# à cocher et l'empêcher de sélectionner la ligne (donc d'ouvrir l'objet).
	item_list.gui_input.connect(_on_item_list_gui_input)
	content.add_child(item_list)
	content.add_child(_build_apply_bar())
	_rebuild_hero_filter()
	_refresh_pending_indicators()


func set_entries(entries: Array[Dictionary]) -> void:
	_entries = entries.duplicate(false)
	_reconcile_pending_rewards()
	_refresh()


func set_hero_entries(entries: Array[Dictionary]) -> void:
	_hero_entries = entries.duplicate(false)
	if hero_filter == null:
		return
	_rebuild_hero_filter()
	_refresh()


func _rebuild_hero_filter() -> void:
	if hero_filter == null:
		return
	var selected_key := _selected_hero_filter_key()
	hero_filter.clear()
	hero_filter.add_item("Tous les héros")
	hero_filter.set_item_metadata(0, &"ALL")
	for entry in _hero_entries:
		var hero_id := StringName(entry.get("id", &""))
		if hero_id == &"":
			continue
		hero_filter.add_item(str(entry.get("display_name", hero_id)))
		hero_filter.set_item_metadata(hero_filter.item_count - 1, hero_id)
	hero_filter.add_item("Universel")
	hero_filter.set_item_metadata(hero_filter.item_count - 1, &"UNIVERSAL")
	_select_hero_filter_key(selected_key)


func snapshot_filters() -> Dictionary:
	return {
		"search": search_edit.text if search_edit != null else "",
		"category": category_filter.selected if category_filter != null else 0,
		"rarity": rarity_filter.selected if rarity_filter != null else 0,
		"slot": slot_filter.selected if slot_filter != null else 0,
		"hero": str(_selected_hero_filter_key()),
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
		[slot_filter, "slot"],
		[reward_filter, "reward"], [status_filter, "status"],
		[sort_option, "sort"],
	]:
		var option := pair[0] as OptionButton
		option.select(clampi(int(state.get(pair[1], 0)), 0, option.item_count - 1))
	var saved_hero = state.get("hero", "ALL")
	if saved_hero is String or saved_hero is StringName:
		_select_hero_filter_key(StringName(saved_hero))
	else:
		# Migration des snapshots V1, qui persistaient l'index de la liste fixe
		# Tous / Elfe / Mage / Guerrier / Universel.
		var legacy_keys: Array[StringName] = [
			&"ALL", &"elf", &"mage", &"warrior", &"UNIVERSAL",
		]
		var legacy_index := int(saved_hero)
		_select_hero_filter_key(
			legacy_keys[legacy_index]
			if legacy_index >= 0 and legacy_index < legacy_keys.size()
			else &"ALL"
		)
	_refresh()


func select_path(path: String) -> bool:
	for index in range(item_list.item_count):
		var entry := item_list.get_item_metadata(index) as Dictionary
		if str(entry.get("path", "")) == path:
			item_list.select(index)
			item_list.ensure_current_is_visible()
			return true
	return false


func pending_reward_changes() -> Array[Dictionary]:
	# On parcourt _entries et non les lignes affichées : une case cochée puis
	# masquée par un filtre reste un changement en attente à part entière.
	var changes: Array[Dictionary] = []
	for entry in _entries:
		var path := str(entry.get("path", ""))
		if not _pending_rewards.has(path):
			continue
		changes.append({
			"path": path,
			"enabled": bool(_pending_rewards[path]),
			"definition": entry.get("definition"),
			"status": StringName(entry.get("status", &"")),
			"display_name": str(entry.get("display_name", "Objet")),
		})
	return changes


func clear_pending_rewards() -> void:
	if _pending_rewards.is_empty():
		return
	_pending_rewards.clear()
	_refresh()


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


func _build_reward_column_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	reward_header = Label.new()
	reward_header.text = "Récompense ?"
	reward_header.add_theme_font_size_override("font_size", 11)
	reward_header.add_theme_color_override("font_color", MUTED_COLOR)
	reward_header.tooltip_text = REWARD_COLUMN_TOOLTIP
	# Un Label ignore la souris par défaut : sans ce filtre, son info-bulle ne
	# s'afficherait jamais. clip_text évite qu'il impose sa largeur au panneau.
	reward_header.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_header.clip_text = true
	reward_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(reward_header)
	return header


func _build_apply_bar() -> Control:
	apply_bar = HBoxContainer.new()
	apply_bar.add_theme_constant_override("separation", 6)
	apply_button = Button.new()
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.clip_text = true
	apply_button.tooltip_text = "Écrire le tag de récompense dans le fichier de chaque objet modifié"
	apply_button.pressed.connect(_emit_bulk_apply)
	apply_bar.add_child(apply_button)
	cancel_button = Button.new()
	cancel_button.text = "Annuler"
	cancel_button.tooltip_text = "Oublier les cases modifiées et revenir à l’état des fichiers"
	cancel_button.pressed.connect(clear_pending_rewards)
	apply_bar.add_child(cancel_button)
	return apply_bar


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
	hero_filter = _filter(box, ["Tous les héros", "Universel"])
	hero_filter.set_item_metadata(0, &"ALL")
	hero_filter.set_item_metadata(1, &"UNIVERSAL")
	reward_filter = _filter(box, ["Récompense : tous", "Oui", "Non"])
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
		item_list.set_item_icon(index, _row_icon_for(entry))
		item_list.set_item_metadata(index, entry)
		item_list.set_item_tooltip(index, _entry_tooltip(entry))
		item_list.set_item_custom_bg_color(
			index,
			PENDING_BACKGROUND if _pending_rewards.has(str(entry.get("path", ""))) else NO_BACKGROUND,
		)
	_refresh_counters(filtered.size())
	_refresh_pending_indicators()
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


func _refresh_pending_indicators() -> void:
	if apply_bar == null:
		return
	var count := _pending_rewards.size()
	apply_bar.visible = count > 0
	apply_button.text = "Appliquer à %d objet%s" % [count, "s" if count > 1 else ""]


func _active_filter_count() -> int:
	var active := 0
	for option in [
		category_filter, rarity_filter, slot_filter,
		hero_filter, reward_filter, status_filter,
	]:
		if option != null and (option as OptionButton).selected > 0:
			active += 1
	return active


func _is_reward_capable(entry: Dictionary) -> bool:
	var definition := entry.get("definition") as ItemDefinition
	return definition != null and (definition.is_equippable() or definition.is_relic())


func _reward_state(entry: Dictionary) -> bool:
	var path := str(entry.get("path", ""))
	if _pending_rewards.has(path):
		return bool(_pending_rewards[path])
	return bool(entry.get("reward_eligible", false))


func _reconcile_pending_rewards() -> void:
	# Après une écriture réussie le catalogue relu porte déjà l'état voulu : le
	# changement en attente s'efface tout seul. Celui d'un objet resté en
	# mémoire (document ouvert, non sauvegardé) survit, ce qui est exact.
	if _pending_rewards.is_empty():
		return
	var known := {}
	for entry in _entries:
		known[str(entry.get("path", ""))] = bool(entry.get("reward_eligible", false))
	for path in _pending_rewards.keys():
		if not known.has(path) or bool(_pending_rewards[path]) == bool(known[path]):
			_pending_rewards.erase(path)


func _toggle_reward(index: int) -> void:
	var entry := item_list.get_item_metadata(index) as Dictionary
	if entry.is_empty() or not _is_reward_capable(entry):
		return
	var path := str(entry.get("path", ""))
	if path.is_empty():
		return
	var desired := not _reward_state(entry)
	if desired == bool(entry.get("reward_eligible", false)):
		_pending_rewards.erase(path)
	else:
		_pending_rewards[path] = desired
	item_list.set_item_icon(index, _row_icon_for(entry))
	item_list.set_item_custom_bg_color(
		index,
		PENDING_BACKGROUND if _pending_rewards.has(path) else NO_BACKGROUND,
	)
	item_list.set_item_tooltip(index, _entry_tooltip(entry))
	_refresh_pending_indicators()


func _emit_bulk_apply() -> void:
	var changes := pending_reward_changes()
	if changes.is_empty():
		return
	reward_bulk_apply_requested.emit(changes)


func _on_item_list_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed \
			or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var index := item_list.get_item_at_position(mouse_event.position, true)
	if index < 0:
		return
	var entry := item_list.get_item_metadata(index) as Dictionary
	# Seuls les équipements et les reliques peuvent rejoindre le pool : ailleurs
	# la ligne ne dessine pas de case, donc le clic doit rester une ouverture.
	if entry.is_empty() or not _is_reward_capable(entry):
		return
	if not _is_inside_checkbox(index, mouse_event.position):
		return
	_toggle_reward(index)
	# Consommer l'événement empêche l'ItemList de sélectionner la ligne, donc
	# d'émettre item_selected, donc d'ouvrir l'objet dans l'éditeur.
	item_list.accept_event()


func _is_inside_checkbox(index: int, position: Vector2) -> bool:
	var rect := item_list.get_item_rect(index, false)
	return position.x >= rect.position.x \
		and position.x <= rect.position.x + _checkbox_zone_width()


func _checkbox_zone_width() -> float:
	# Bande cliquable : la marge d'icône, la case, et la moitié de l'écart qui la
	# sépare de la pastille de statut. Le texte commence bien après.
	return float(item_list.get_theme_constant(&"icon_margin", &"ItemList")) \
		+ float(CHECK_SIZE) + float(ICON_GAP) * 0.5


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
	var path := str(entry.get("path", ""))
	if _pending_rewards.has(path):
		lines.append("Récompense : %s — en attente d’application" % [
			"à cocher" if bool(_pending_rewards[path]) else "à décocher",
		])
	lines.append(path)
	return "\n".join(lines)


func _row_icon_for(entry: Dictionary) -> ImageTexture:
	var state := CHECK_NONE
	var color := CHECK_OFF_COLOR
	if _is_reward_capable(entry):
		var checked := _reward_state(entry)
		state = CHECK_ON if checked else CHECK_OFF
		if _pending_rewards.has(str(entry.get("path", ""))):
			color = PENDING_COLOR
		else:
			color = CHECK_ON_COLOR if checked else CHECK_OFF_COLOR
	return _row_icon(state, color, _badge_color(entry))


static func _row_icon(check_state: int, check_color: Color, badge_color: Color) -> ImageTexture:
	var key := "%d|%s|%s" % [check_state, check_color.to_html(true), badge_color.to_html(true)]
	if _badge_textures.has(key):
		return _badge_textures[key]
	var image := Image.create_empty(ROW_ICON_WIDTH, BADGE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_paint_checkbox(image, check_state, check_color)
	_paint_badge(image, CHECK_SIZE + ICON_GAP, badge_color)
	var texture := ImageTexture.create_from_image(image)
	_badge_textures[key] = texture
	return texture


static func _paint_checkbox(image: Image, check_state: int, color: Color) -> void:
	if check_state == CHECK_NONE:
		return
	for y in CHECK_SIZE:
		for x in CHECK_SIZE:
			var on_border := x == 0 or y == 0 or x == CHECK_SIZE - 1 or y == CHECK_SIZE - 1
			var on_fill := check_state == CHECK_ON \
				and x >= 3 and x <= CHECK_SIZE - 4 \
				and y >= 3 and y <= CHECK_SIZE - 4
			if on_border or on_fill:
				image.set_pixel(x, y, color)


static func _paint_badge(image: Image, offset_x: int, color: Color) -> void:
	var center := (BADGE_SIZE - 1) * 0.5
	var radius := BADGE_SIZE * 0.5 - 1.0
	for y in BADGE_SIZE:
		for x in BADGE_SIZE:
			var coverage := clampf(radius - Vector2(x - center, y - center).length() + 0.5, 0.0, 1.0)
			if coverage > 0.0:
				image.set_pixel(offset_x + x, y, Color(color.r, color.g, color.b, coverage))


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
	var hero_key := _selected_hero_filter_key()
	if hero_key != &"ALL":
		var ids := entry.get("compatible_character_ids", []) as Array
		if hero_key == &"UNIVERSAL" and not ids.is_empty():
			return false
		if hero_key != &"UNIVERSAL":
			if not ids.is_empty() and hero_key not in ids:
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


func _selected_hero_filter_key() -> StringName:
	if hero_filter == null or hero_filter.item_count == 0 or hero_filter.selected < 0:
		return &"ALL"
	var metadata = hero_filter.get_item_metadata(hero_filter.selected)
	return StringName(metadata) if metadata != null else &"ALL"


func _select_hero_filter_key(key: StringName) -> void:
	if hero_filter == null or hero_filter.item_count == 0:
		return
	for index in hero_filter.item_count:
		if StringName(hero_filter.get_item_metadata(index)) == key:
			hero_filter.select(index)
			return
	hero_filter.select(0)


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
