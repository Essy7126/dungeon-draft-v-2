extends "res://ui/expedition/consumable_cards_workshop.gd"
## Public player dossier. Transactions remain owned by the existing workshop/rules.
const D := preload("res://ui/expedition/player_dossier_skin.gd")
const Receipt := preload("res://ui/expedition/consumable_loot_receipt.gd")
const Language := preload("res://ui/expedition/card_player_language.gd")
const Presenter := preload("res://ui/expedition/consumable_cards_presenter.gd")
const Icons := preload("res://core/expedition/class_icon_catalog.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")
const BuildPreview := preload("res://ui/expedition/consumable_build_preview.gd")
const Symbols := preload("res://ui/expedition/player_stat_symbols.gd")
const DeckInventory := preload("res://ui/expedition/consumable_deck_inventory.gd")
signal class_requested
const HoverCard := preload("res://ui/expedition/spell_hover_card.gd")
const CardView := preload("res://ui/expedition/consumable_combat_card_view.gd")
var _deck_lane_active := "deck"
var _filters_open := false
var _card_window: AcceptDialog
var _card_window_open := false
var _card_detail_tab := 0
var sort_order := 0
var rarity_filter := 0
var affinity_filter := 0
var _card_tiles: Array[Button] = []
var _deck_scroll := 0
var _reserve_scroll := 0
var selected_family := ""
var selected_item := ""
var card_filter := 0
var item_filter := 0
var slot_filter := ""
var item_query := ""
signal allocation_requested
var _recent_cards: Dictionary = { }
var _recent_items: Dictionary = { }
var _content: Node
var _detail: VBoxContainer
var _tiles: Dictionary = { }
var section := ""
var _quick_actions: HBoxContainer


func _text(value: String, extent := 16) -> Label:
	return D.label(_content if is_instance_valid(_content) else self, value, extent)


func _button(parent: Node, value: String, action: Callable, locked := false) -> Button:
	var target := _content if parent == self and is_instance_valid(_content) else parent
	var node := super._button(target, value, action, locked)
	D.button(node)
	return node


func _render() -> void:
	name = "ConsumablePlayerDossier"
	_content = null
	_card_window = null
	_tiles.clear()
	_card_tiles.clear()
	_recent_cards.clear()
	_recent_items.clear()
	if Integration.enabled(GameManager.expedition):
		for record in Receipt.latest_records(GameManager.expedition):
			if record.kind == "card":
				_recent_cards[record.id] = record.count
			else:
				_recent_items[record.id] = record.count
	add_theme_constant_override("separation", 12)
	super._render()
	if read_only:
		D.label(
			self,
			"Consultation en combat · les changements seront disponibles après le combat.",
			14,
			D.MUTED,
		)


func _columns() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "DossierColumns"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	return row


func _select(parent: Node, text: String, action: Callable, active := false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 38
	D.button(node, active)
	node.pressed.connect(action)
	parent.add_child(node)
	return node


func _summary(cards) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	D.metric(row, "DECK PRÉPARÉ", "%d / 30" % cards.active.size())
	D.metric(row, "EN RÉSERVE", str(cards.copies.size() - cards.active.size()), D.PAPER)
	D.metric(row, "MAIN", "%d cartes" % cards.hand_capacity, D.PAPER)
	D.metric(row, "AMÉLIORATIONS", str(cards.points()), D.GREEN)


func _deck(cards) -> void:
	var inventory := DeckInventory.partition(cards.copies, cards.active)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	var search := LineEdit.new()
	search.name = "DossierSearch"
	search.placeholder_text = "Rechercher un sort…"
	search.text = query
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.y = 38
	search.add_theme_font_override("font", D.FONT)
	search.add_theme_font_size_override("font_size", 16)
	bar.add_child(search)
	var filters_toggle := _select(
		bar,
		"Filtres",
		func():
			_filters_open = not _filters_open
			find_child("DeckAdvancedFilters", true, false).visible = _filters_open,
	)
	filters_toggle.name = "ToggleDeckFilters"
	var filters := HBoxContainer.new()
	filters.name = "DeckAdvancedFilters"
	filters.visible = _filters_open
	filters.add_theme_constant_override("separation", 8)
	add_child(filters)
	var filter := _deck_filter(
		filters,
		"DossierCardFilter",
		[
			"Tous les rôles",
			"Attaque",
			"Protection",
			"Ma classe",
			"Autres classes",
			"Dernier butin",
			"Déplacement",
			"Contrôle",
			"Terrain",
			"Soin",
			"Pioche",
		],
		card_filter,
	)
	var affinity := _deck_filter(
		filters,
		"DossierAffinityFilter",
		["Toutes affinités", "Commune", "Assassin", "Gardien", "Arpenteur", "Thaumaturge"],
		affinity_filter,
	)
	var rarity := _deck_filter(
		filters,
		"DossierRarityFilter",
		["Toutes raretés"] + Receipt.RARITY_NAMES.values(),
		rarity_filter,
	)

	var sorting := _deck_filter(bar, "DossierSort", ["Coût ↑", "Nom A–Z", "Rareté ↓"], sort_order)
	sorting.tooltip_text = "Trier séparément le deck préparé et la réserve."
	sorting.item_selected.connect(
		func(index):
			sort_order = index
			_sort_card_lanes(),
	)
	var guide := _select(filters, "Comprendre les cartes", _deck_guide)
	guide.name = "DeckIdentityHelp"
	var tabs := HBoxContainer.new()
	tabs.name = "DeckCollectionTabs"
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	for lane in ["deck", "reserve"]:
		var label := "Mon deck · %d / 30" % inventory.deck_count if lane == "deck" else "Réserve · %d" % inventory.reserve_count
		var tab := _select(
			tabs,
			label,
			func():
				_switch_deck_lane(lane),
			lane == _deck_lane_active,
		)
		tab.name = "ShowPreparedDeck" if lane == "deck" else "ShowCardReserve"
		D.navigation_button(tab, lane == _deck_lane_active)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var class_button := _select(
		tabs,
		"Classe & améliorations →",
		func():
			class_requested.emit(),
	)
	class_button.name = "OpenDeckClassProgression"
	var columns := _columns()
	_deck_lane(columns, cards, inventory, true)
	_deck_lane(columns, cards, inventory, false)
	_switch_deck_lane(_deck_lane_active)
	var empty := D.label(
		self,
		"Aucun sort ne correspond aux filtres. Effacez la recherche ou changez les filtres.",
		15,
		D.GOLD,
	)
	empty.name = "EmptyCollection"
	var update := func():
		var visible_counts := { "deck": 0, "reserve": 0 }
		for tile in _card_tiles:
			var id := str(tile.get_meta("family"))
			var row := Catalog.card(id)
			var matches := query.is_empty() or query.to_lower() in str(row.name).to_lower()
			var roles := {
				1: "Attaque",
				2: "Protection",
				6: "Déplacement",
				7: "Contrôle",
				8: "Terrain",
				9: "Soin",
				10: "Pioche",
			}
			if roles.has(card_filter):
				matches = matches and Language.role(row) == roles[card_filter]
			if card_filter == 3:
				matches = matches and row.affinity in [cards.primary_class, "shared"]
			if card_filter == 4:
				matches = matches and row.affinity not in [cards.primary_class, "shared"]
			if card_filter == 5:
				matches = matches and _recent_cards.has(id)
			if rarity_filter > 0:
				matches = matches and row.rarity == Catalog.RARITIES[rarity_filter - 1]
			if affinity_filter > 0:
				matches = (
					matches
					and row.affinity
					== ["shared", "assassin", "gardien", "arpenteur", "thaumaturge"][
						affinity_filter - 1
					]
				)
			tile.visible = matches
			tile.get_parent().visible = matches
			if matches:
				visible_counts[str(tile.get_meta("lane"))] += 1
		for lane in ["deck", "reserve"]:
			find_child(lane + "Empty", true, false).visible = visible_counts[lane] == 0
			find_child(lane + "Shown", true, false).text = "%d / %d sorts affichés" % [
				visible_counts[lane],
				inventory[lane].size(),
			]
		empty.visible = visible_counts.deck + visible_counts.reserve == 0
		_select_visible(cards, false)
	search.text_changed.connect(
		func(value):
			query = value
			update.call(),
	)
	filter.item_selected.connect(
		func(index):
			card_filter = index
			update.call(),
	)
	affinity.item_selected.connect(
		func(index):
			affinity_filter = index
			update.call(),
	)
	rarity.item_selected.connect(
		func(index):
			rarity_filter = index
			update.call(),
	)
	_sort_card_lanes()
	update.call()
	if _card_window_open and not selected_family.is_empty():
		_show_family.call_deferred(cards)
	D.label(
		self,
		"Survolez pour lire les effets · Cliquez pour examiner une carte · Main de %d cartes"
		% cards.hand_capacity,
		14,
		D.MUTED,
	)


func _sort_card_lanes() -> void:
	for lane in ["deck", "reserve"]:
		var tiles := _card_tiles.filter(
			func(tile):
				return tile.get_meta("lane") == lane,
		)
		tiles.sort_custom(
			func(a, b):
				var left := Catalog.card(str(a.get_meta("family")))
				var right := Catalog.card(str(b.get_meta("family")))
				if sort_order == 2 and left.rarity != right.rarity:
					return Catalog.RARITIES.find(left.rarity) > Catalog.RARITIES.find(right.rarity)
				if sort_order == 0 and left.ap != right.ap:
					return left.ap < right.ap
				return str(left.name).naturalnocasecmp_to(str(right.name)) < 0,
		)
		for index in tiles.size():
			var stack: Node = tiles[index].get_parent()
			stack.get_parent().move_child(stack, index)


func _deck_filter(parent: Node, node_name: String, titles: Array, selected: int) -> OptionButton:
	var choice := OptionButton.new()
	choice.name = node_name
	for title in titles:
		choice.add_item(str(title))
	choice.selected = selected
	D.button(choice)
	parent.add_child(choice)
	return choice


func _deck_lane(parent: Node, cards, inventory: Dictionary, prepared: bool) -> void:
	var lane := "deck" if prepared else "reserve"
	var body := D.column(parent, 290, false)
	body.get_parent().name = "PreparedDeckPanel" if prepared else "ReservePanel"
	var heading := HBoxContainer.new()
	body.add_child(heading)
	var title := D.label(
		heading,
		"DECK PRÉPARÉ" if prepared else "RÉSERVE",
		19,
		D.GOLD if prepared else Color("b1c1c8"),
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var metric := D.label(
		heading,
		"%d / 30" % inventory.deck_count if prepared else str(inventory.reserve_count),
		23,
		D.PAPER,
	)
	metric.autowrap_mode = TextServer.AUTOWRAP_OFF
	D.label(
		body,
		"Ces cartes peuvent être piochées." if prepared else "Stockées, jamais piochées en combat.",
		14,
		D.MUTED,
	)
	if prepared:
		D.label(body, DeckInventory.cost_summary(inventory.costs), 14, D.GOLD)
	else:
		D.label(body, "Ajoutez les cartes que vous souhaitez piocher.", 14, D.GOLD)
	var scroll := ScrollContainer.new()
	scroll.name = "PreparedDeckScroll" if prepared else "ReserveScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "PreparedDeckGallery" if prepared else "ReserveGallery"
	grid.columns = 5
	grid.resized.connect(
		func():
			grid.columns = maxi(2, int(grid.size.x / 195.0)),
	)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var ids: Array = inventory[lane].keys()
	ids.sort_custom(
		func(a, b):
			var left := Catalog.card(a)
			var right := Catalog.card(b)
			return left.ap < right.ap if left.ap != right.ap else str(left.name) < str(right.name),
	)
	for id in ids:
		var stack := VBoxContainer.new()
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_theme_constant_override("separation", 2)
		grid.add_child(stack)
		var tile := _card_tile(
			stack,
			Receipt.card_record(id, id in cards.upgraded_ids),
			cards,
			prepared,
			inventory[lane][id].size(),
		)
		_card_tiles.append(tile)
		if not _tiles.has(id):
			_tiles[id] = tile
		var uid := str(inventory[lane][id][0])
		var full: bool = (
			not prepared and (cards.active.size() >= 30 or inventory.deck.get(id, []).size() >= 3)
		)
		var transfer := _button(
			stack,
			"−1 vers la réserve" if prepared else "+1 au deck",
			func():
				return cards.move_card(uid),
			full,
		)
		transfer.name = ("ReserveOne_" if prepared else "PrepareOne_") + str(id)
		transfer.custom_minimum_size.y = 30
		transfer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		transfer.add_theme_font_size_override("font_size", 14)
		transfer.tooltip_text = "Le deck contient déjà 3 exemplaires de ce sort, ou 30 cartes au total." if full else "Retire un exemplaire du deck vers la réserve." if prepared else "Ajoute un exemplaire de la réserve au deck."
		if selected_family.is_empty():
			selected_family = id
	var empty := D.label(
		body,
		(
			"Deck vide : ajoutez des cartes de la réserve."
			if prepared and inventory.deck_count == 0
			else (
				"Aucune carte en réserve."
				if not prepared and inventory.reserve_count == 0
				else "Aucun résultat avec ces filtres."
			)
		),
		16,
		D.MUTED,
	)
	empty.name = lane + "Empty"
	D.label(body, "", 13, D.MUTED).name = lane + "Shown"
	scroll.set_deferred("scroll_vertical", _deck_scroll if prepared else _reserve_scroll)
	scroll.get_v_scroll_bar().value_changed.connect(
		func(value):
			if prepared:
				_deck_scroll = int(value)
			else:
				_reserve_scroll = int(value),
	)


func _deck_guide() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Classe, famille, rôle : les repères"
	dialog.dialog_text = "AFFINITÉ — Assassin, Gardien, Arpenteur, Thaumaturge ou Commune. Elle indique l'origine du sort. Les cartes d'autres classes reçues pendant la run peuvent rejoindre votre deck. Votre bonus de classe reste celui choisi au départ.\n\nÉLÉMENTS — Terre, Eau, Feu, Vent, Nuit, Soleil. Chaque composante chiffrée indique ses éléments et leurs proportions. Vos maîtrises renforcent ces composantes, quelle que soit votre classe. Les effets utilitaires neutres restent fixes.\n\nRÔLE — Attaque, protection, contrôle… Il décrit l'utilité du sort.\n\nRARETÉ — Normale, Élite, Rare, Légendaire, Divine, Immortelle. Elle indique sa rareté de butin ; le coût et les effets restent écrits sur la fiche.\n\nFAMILLE DE SORT — Tous les exemplaires d'un même sort. 3 cartes Estoc = 3 utilisations dans la run, mais une seule par tour. Améliorer Estoc les renforce toutes."
	dialog.ok_button_text = "Compris"
	dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.get_label().custom_minimum_size.x = 570
	dialog.get_label().add_theme_font_size_override("font_size", 17)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(620, 480))


func _copies(cards, id: String, prepared: bool) -> Array:
	return cards.copies.filter(
		func(copy):
			return copy.family == id and (not prepared or copy.id in cards.active),
	)


func _card_tile(parent: Node, record: Dictionary, cards, prepared: bool, count: int) -> Button:
	var id := str(record.id)
	var node := _select(
		parent,
		"",
		func():
			selected_family = id
			_card_detail_tab = 0
			_show_family(cards),
		id == selected_family,
	)
	node.name = ("DeckFamily_" if prepared else "ReserveFamily_") + id
	node.set_meta("family", id)
	node.set_meta("lane", "deck" if prepared else "reserve")
	node.set_meta("count", count)
	node.set_meta("rarity", record.rarity)
	node.custom_minimum_size = Vector2(176, 220)
	D.card_material(node)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	node.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_right = -8
	box.offset_top = 6
	box.offset_bottom = -6
	box.add_theme_constant_override("separation", 4)
	D.image(box, record.icon, 86)
	var words := box
	var title := D.label(words, str(record.title), 16)
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.y = 42
	D.label(
		words,
		"%d PA · %s" % [record.row.ap, Receipt.RARITY_NAMES[record.rarity]],
		13,
		Color(Receipt.COLORS[record.rarity]),
	)
	D.label(words, DeckInventory.affinity(record.row), 13, D.MUTED)
	var badge := "×%d" % count
	if prepared and not cards.opening.is_empty() and cards.copy_for(cards.opening[0]).get("family") == id:
		badge += " ★"
	if id in cards.upgraded_ids:
		badge += " · ↑"
	var quantity := D.label(box if prepared else words, badge, 15, D.GOLD)
	quantity.autowrap_mode = TextServer.AUTOWRAP_OFF
	quantity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.accessibility_name = "%s · %s · %s · %d exemplaires dans %s" % [
		record.title,
		Receipt.RARITY_NAMES[record.rarity],
		DeckInventory.affinity(record.row),
		count,
		"le deck" if prepared else "la réserve",
	]
	HoverCard.attach(
		node,
		cards.family_spell(id),
		GameManager.expedition.character.unit,
		node,
		"Deck ×%d · Réserve ×%d"
		% [
			_copies(cards, id, true).size(),
			_copies(cards, id, false).size() - _copies(cards, id, true).size(),
		],
	)
	D.passive(box)
	_card_style(node, id == selected_family)
	return node


func _card_style(tile: Button, selected: bool) -> void:
	D.button(tile, selected)
	var style := D.surface(selected, 6)
	style.border_color = Color(Receipt.COLORS[tile.get_meta("rarity")])
	style.border_width_left = 4
	style.shadow_color = Color(0, 0, 0, .22)
	style.shadow_size = 2
	style.border_width_bottom = 2 if selected else 1
	tile.add_theme_stylebox_override("normal", style)


func _switch_deck_lane(lane: String) -> void:
	_deck_lane_active = lane
	find_child("PreparedDeckPanel", true, false).visible = lane == "deck"
	find_child("ReservePanel", true, false).visible = lane == "reserve"
	for entry in [["ShowPreparedDeck", "deck"], ["ShowCardReserve", "reserve"]]:
		D.navigation_button(find_child(entry[0], true, false), lane == entry[1])
	for hover in get_tree().get_nodes_in_group("passive_spell_hover"):
		hover._hide()


func _show_family(cards) -> void:
	if selected_family.is_empty():
		return
	if is_instance_valid(_card_window):
		remove_child(_card_window)
		_card_window.queue_free()
	_card_window_open = true
	_card_window = preload("res://ui/expedition/deck_card_window.gd").new()
	_card_window.name = "DeckCardInspection"
	_card_window.title = str(Catalog.card(selected_family).name)
	_card_window.theme = D.interface_theme()
	_card_window.ok_button_text = "Retour aux cartes"
	D.button(_card_window.get_ok_button())
	_card_window.confirmed.connect(
		func():
			_card_window_open = false,
	)
	_card_window.canceled.connect(
		func():
			_card_window_open = false,
	)
	add_child(_card_window)
	var tabs := TabContainer.new()
	tabs.name = "CardInspectionTabs"
	_card_window.add_child(tabs)
	var card_page := VBoxContainer.new()
	card_page.name = "Carte"
	tabs.add_child(card_page)
	var reading := D.column(card_page, 0)
	reading.get_parent().get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel := PanelContainer.new()
	reading.add_child(panel)
	var owned := _copies(cards, selected_family, false).size()
	var prepared := _copies(cards, selected_family, true).size()
	CardView.hover(
		panel,
		cards.family_spell(selected_family),
		GameManager.expedition.character.unit,
		"Deck ×%d · Réserve ×%d" % [prepared, owned - prepared],
	)
	var actions := VBoxContainer.new()
	actions.name = "Organiser et améliorer"
	tabs.add_child(actions)
	_detail = D.column(actions)
	_detail.get_parent().get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.name = "CardInspector"
	_quick_actions = HBoxContainer.new()
	_quick_actions.name = "CardQuickActions"
	actions.add_child(_quick_actions)
	_build_family_management(cards)
	tabs.current_tab = _card_detail_tab
	tabs.tab_changed.connect(
		func(index):
			_card_detail_tab = index,
	)
	_card_window.popup_centered(Vector2i(640, mini(640, int(get_viewport_rect().size.y) - 60)))
	_card_window.get_ok_button().grab_focus()


func _build_family_management(cards) -> void:
	var record := Receipt.card_record(selected_family, selected_family in cards.upgraded_ids)
	var hero: Unit = GameManager.expedition.character.unit
	D.label(_detail, record.title, 23, D.GOLD)
	D.label(
		_detail,
		"Choisissez ici comment utiliser vos exemplaires et vos points d’amélioration.",
		15,
		D.MUTED,
	)
	if not record.upgraded:
		var evolution := D.column(_detail, 0, false)
		D.label(evolution, "AMÉLIORATION · 1 POINT", 13, D.GREEN)
		D.label(
			evolution,
			Language.effect(
				Catalog.card(selected_family, true),
				hero.attack_power.get_value(),
				cards,
			),
			16,
		)
	D.label(_detail, "DÉVELOPPER CE SORT", 13, D.GOLD)
	_family_actions(cards, selected_family, _detail)
	if Integration.is_market(GameManager.expedition):
		_content = _detail
		_market(cards)
		_content = null


func _gear(cards) -> void:
	var columns := _columns()
	var identity := D.column(columns, 320, false)
	identity.get_parent().size_flags_stretch_ratio = 1.15
	var hero: Unit = GameManager.expedition.character.unit
	D.label(identity, hero.unit_name, 26, D.GOLD)
	D.label(
		identity,
		"%s · Niveau %d" % [Catalog.class_row(cards.primary_class).name, cards.level],
		17,
		D.MUTED,
	)
	var stage := HBoxContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	identity.add_child(stage)
	var left := VBoxContainer.new()
	stage.add_child(left)
	var scene := Control.new()
	scene.name = "HeroEquipmentPreview"
	scene.custom_minimum_size = Vector2(144, 210)
	scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(scene)
	var backdrop := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://ui/expedition/dossier_sanctuary.gdshader")
	backdrop.material = material
	scene.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview := preload("res://ui/characters/CharacterPreview3D.tscn").instantiate()
	scene.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.configure(hero.character_data)
	var right := VBoxContainer.new()
	stage.add_child(right)
	var slots := ["head", "body", "weapon", "amulet", "belt", "feet"]
	var indices := [3, 1, 0, 2, 4, 5]
	for index in slots.size():
		var slot: String = slots[index]
		var id := str(cards.equipped.get(slot, ""))
		var side := left if index < 3 else right
		var tile := _select(
			side,
			"",
			func():
				if not id.is_empty():
					selected_item = id
					_show_item(cards),
		)
		tile.name = "Slot_" + slot
		tile.custom_minimum_size = Vector2(64, 64)
		tile.icon = Icons.empty_slot(indices[index])
		if not id.is_empty():
			var equipped_record := Receipt.item_record(id, "equipment")
			tile.icon = equipped_record.icon
		else:
			tile.add_theme_color_override("icon_normal_color", Color("d2bca2"))
		tile.expand_icon = true
		tile.add_theme_constant_override("icon_max_width", 44)
		tile.tooltip_text = Presenter.SLOTS[slot] + " · " + (
			"Vide" if id.is_empty() else str(Presenter.item(id).name)
		)
		var caption := D.label(side, Presenter.SLOTS[slot], 13, D.MUTED)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	D.label(identity, "RELIQUES ACTIVES · %d / 2" % cards.active_relics.size(), 14, D.GOLD)
	var relics := HBoxContainer.new()
	identity.add_child(relics)
	for index in 2:
		var id := str(cards.active_relics[index]) if index < cards.active_relics.size() else ""
		var tile := _select(
			relics,
			"Emplacement libre" if id.is_empty() else "",
			func():
				if not id.is_empty():
					selected_item = id
					_show_item(cards),
		)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size.y = 56
		tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not id.is_empty():
			tile.icon = Receipt.item_record(id, "relics").icon
			tile.expand_icon = true
			tile.add_theme_constant_override("icon_max_width", 42)
			tile.tooltip_text = str(Presenter.item(id).name)
	D.label(
		identity,
		"%d / %d PV     ·     %d oboles" % [hero.current_hp, hero.max_hp.get_int(), cards.gold],
		17,
		D.GREEN,
	)
	var bag := D.column(columns, 302, false)
	D.label(bag, "VOTRE INVENTAIRE", 15, D.GOLD)
	var filter := OptionButton.new()
	filter.name = "DossierItemFilter"
	for label in ["Tous les objets", "Équipements", "Reliques", "Dernier butin"]:
		filter.add_item(label)
	filter.selected = item_filter
	D.button(filter)
	bag.add_child(filter)
	var search := LineEdit.new()
	search.name = "DossierItemSearch"
	search.placeholder_text = "Rechercher un objet…"
	search.text = item_query
	search.custom_minimum_size.y = 36
	search.add_theme_font_override("font", D.FONT)
	bag.add_child(search)
	var slots_filter := OptionButton.new()
	slots_filter.name = "DossierSlotFilter"
	var slot_keys := [""] + Presenter.SLOTS.keys()
	slots_filter.add_item("Tous les emplacements")
	for key in Presenter.SLOTS:
		slots_filter.add_item(Presenter.SLOTS[key])
	slots_filter.selected = maxi(0, slot_keys.find(slot_filter))
	D.button(slots_filter)
	bag.add_child(slots_filter)
	var scroller := ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag.add_child(scroller)
	var grid := GridContainer.new()
	grid.name = "InventoryGallery"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroller.add_child(grid)
	var owned := { }
	for copy in cards.equipment_copies:
		owned[str(copy.definition)] = int(owned.get(str(copy.definition), 0)) + 1
	for id in cards.owned_relics:
		owned[str(id)] = 1
	for id in owned:
		var relic: bool = str(id) in cards.owned_relics
		var record := Receipt.item_record(id, "relics" if relic else "equipment")
		var tile := _select(
			grid,
			"",
			func():
				selected_item = id
				_show_item(cards),
		)
		tile.name = "Item_" + id
		tile.custom_minimum_size = Vector2(64, 76)
		tile.icon = record.icon
		tile.expand_icon = true
		tile.add_theme_constant_override("icon_max_width", 48)
		tile.tooltip_text = str(record.title) + " · " + str(record.category)
		tile.accessibility_name = tile.tooltip_text
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var equipped: bool = id in cards.equipped.values() or id in cards.active_relics
		var badge := D.label(
			tile,
			"✓" if equipped else "×%d" % int(owned[id]),
			16,
			D.GREEN if equipped else D.PAPER,
		)
		badge.position = Vector2(5, 1)
		badge.autowrap_mode = TextServer.AUTOWRAP_OFF
		badge.add_theme_constant_override("outline_size", 4)
		badge.add_theme_color_override("font_outline_color", D.INK)
		D.passive(badge)
		if _recent_items.has(id):
			var recent := D.label(tile, "BUTIN", 12, D.GOLD)
			recent.position = Vector2(5, 57)
			recent.autowrap_mode = TextServer.AUTOWRAP_OFF
			recent.add_theme_constant_override("outline_size", 4)
			recent.add_theme_color_override("font_outline_color", D.INK)
			D.passive(recent)
		tile.set_meta("relic", relic)
		tile.set_meta("definition", id)
		_tiles[id] = tile
	var empty := D.label(
		bag,
		"Aucun objet dans cette catégorie. Le butin des combats apparaîtra ici.",
		17,
		D.MUTED,
	)
	var update := func():
		var count := 0
		for tile in _tiles.values():
			var id: String = tile.get_meta("definition")
			var definition := Presenter.item(id)
			tile.visible = (
				(
					item_filter == 0
					or (item_filter in [1, 2] and tile.get_meta("relic") == (item_filter == 2))
					or (item_filter == 3 and _recent_items.has(id))
				)
				and (slot_filter.is_empty() or definition.get("slot", "") == slot_filter)
				and (
					item_query.is_empty()
					or item_query.to_lower() in str(definition.name).to_lower()
				)
			)
			if tile.visible:
				count += 1
		empty.visible = count == 0
		_select_visible(cards, true)
	filter.item_selected.connect(
		func(index):
			item_filter = index
			update.call(),
	)
	search.text_changed.connect(
		func(value):
			item_query = value
			update.call(),
	)
	slots_filter.item_selected.connect(
		func(index):
			slot_filter = slot_keys[index]
			update.call(),
	)
	D.label(
		bag,
		"✓ Équipé ou actif · BUTIN : dernier combat\nLes objets vendus ne figurent plus dans le sac.",
		14,
		D.MUTED,
	)
	var inspector := D.column(columns, 280, false)
	var reading := ScrollContainer.new()
	reading.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reading.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reading.follow_focus = true
	inspector.add_child(reading)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	reading.add_child(_detail)
	_detail.name = "ItemInspector"
	_quick_actions = HBoxContainer.new()
	_quick_actions.name = "ItemQuickActions"
	inspector.add_child(_quick_actions)
	if not owned.has(selected_item):
		selected_item = "" if owned.is_empty() else str(owned.keys()[0])
	_show_item(cards)
	update.call()


func _select_visible(cards, equipment: bool) -> void:
	if not equipment:
		var first := ""
		for tile in _card_tiles:
			if not tile.visible:
				continue
			var id := str(tile.get_meta("family"))
			if id == selected_family:
				return
			if first.is_empty():
				first = id
		selected_family = first
		return
	var selected := selected_item if equipment else selected_family
	if _tiles.has(selected) and _tiles[selected].visible:
		return
	selected = ""
	for id in _tiles:
		if _tiles[id].visible:
			selected = str(id)
			break
	if equipment:
		selected_item = selected
		_show_item(cards)
	else:
		selected_family = selected
		_show_family(cards)


func _show_item(cards) -> void:
	for child in _quick_actions.get_children():
		_quick_actions.remove_child(child)
		child.queue_free()
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	for id in _tiles:
		D.button(_tiles[id], id == selected_item)
	if selected_item.is_empty():
		D.image(_detail, Icons.icon("relic_obole"), 100)
		if not _tiles.is_empty():
			D.label(_detail, "Aucun objet sélectionné", 23, D.GOLD)
			D.label(
				_detail,
				"Modifiez la recherche ou les filtres pour retrouver vos objets.",
				17,
				D.MUTED,
			)
			return
		D.label(_detail, "Écrivez votre légende", 25, D.GOLD)
		D.label(
			_detail,
			"Vous partez sans équipement. Chaque combat peut vous apporter de nouveaux objets et reliques.",
			18,
		)
		D.label(_detail, "6 emplacements d'équipement\n2 reliques actives différentes", 16, D.MUTED)
		return
	var id := selected_item
	var row := Presenter.item(id)
	var relic: bool = id in cards.owned_relics
	var record := Receipt.item_record(id, "relics" if relic else "equipment")
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	_detail.add_child(heading)
	D.image(heading, record.icon, 64)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(titles)
	D.label(titles, str(record.category).to_upper(), 13, D.MUTED)
	D.label(titles, record.title, 22, D.GOLD)
	if _recent_items.has(id):
		D.label(_detail, "Dernier combat : +%d · reçu dans le sac" % _recent_items[id], 14, D.GOLD)
	if not relic:
		_comparison(cards, id)
	D.label(_detail, "EFFETS DE L'OBJET", 13, D.GOLD)
	if relic:
		D.label(_detail, row.rule, 18)
		var active: bool = id in cards.active_relics
		D.label(
			_detail,
			"Relique active" if active else "Relique conservée dans l'inventaire",
			15,
			D.GREEN,
		)
		var relic_action := _button(
			_quick_actions,
			"Désactiver la relique" if active else "Activer la relique",
			func():
				if active:
					cards.active_relics.erase(id)
				elif cards.active_relics.size() < 2:
					cards.active_relics.append(id)
				else:
					return false
				return true,
			not active and cards.active_relics.size() >= 2,
		)
		if not active:
			D.primary_button(relic_action)
		if not active and cards.active_relics.size() >= 2:
			D.label(_detail, "Désactivez une relique pour libérer un emplacement.", 15, D.MUTED)
	else:
		for key in row.mods:
			D.label(_detail, Presenter.item_text({ "mods": { key: row.mods[key] } }), 18, D.GREEN)
		var equipped := str(cards.equipped.get(row.slot, ""))
		var active := equipped == id
		if not active and not equipped.is_empty():
			_detail.add_child(HSeparator.new())
			D.label(_detail, "REMPLACE", 13, D.MUTED)
			D.label(_detail, str(Presenter.item(equipped).name), 18, D.GOLD)
			D.label(_detail, Presenter.item_text(Presenter.item(equipped)), 16)
			D.label(_detail, "L'ancien objet restera dans votre inventaire.", 14, D.MUTED)
		var equip_action := _button(
			_quick_actions,
			"Retirer cet équipement" if active else "Équiper cet objet",
			func():
				if active:
					cards.equipped.erase(row.slot)
				else:
					cards.equipped[row.slot] = id
				return true,
		)
		if not active:
			D.primary_button(equip_action)
	D.label(_detail, "Les modifications sont enregistrées immédiatement.", 14, D.MUTED)


func _comparison(cards, id: String) -> void:
	var preview := BuildPreview.compare(cards, id)
	var box := D.column(_detail, 0, false)
	box.name = "EquipmentComparison"
	D.label(box, "APRÈS RETRAIT" if preview.removing else "APRÈS ÉQUIPEMENT", 13, D.GOLD)
	for row in preview.rows:
		_comparison_row(
			box,
			row.title,
			BuildPreview.value(row.key, row.before),
			BuildPreview.value(row.key, row.after),
			float(row.after) - float(row.before),
		)
	for effect in preview.effects:
		var key: String = effect.key
		var number_format := "%.0f %%"
		var factor := 100.0
		if key in ["range", "mp", "hand"]:
			number_format = "%.0f"
			factor = 1
		elif key in ["openingShield", "firstHitReduction"]:
			number_format = "%.0f %% de Puissance"
		_comparison_row(
			box,
			"Bonus de portée" if key == "range" else Presenter.MODS.get(key, key),
			(number_format % (float(effect.before) * factor)).replace(".", ","),
			(number_format % (float(effect.after) * factor)).replace(".", ","),
			float(effect.after) - float(effect.before),
		)
	if preview.rows.is_empty() and preview.effects.is_empty():
		D.label(box, "Aucune variation de statistiques.", 15, D.MUTED)
	for cap in preview.caps:
		D.label(box, cap, 14, D.GOLD)
	D.label(
		box,
		"Valeurs permanentes. Les PV actuels gardent la même proportion : équiper ne soigne pas.",
		14,
		D.MUTED,
	)


func _comparison_row(
	parent: Node,
	title: String,
	before: String,
	after: String,
	delta: float,
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var label := D.label(row, title, 15, D.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tint := D.GAIN if delta > 0 else D.LOSS if delta < 0 else D.PAPER
	var values := D.label(row, before + " → " + after, 18, tint)
	values.tooltip_text = title + (
		" : augmente" if delta > 0 else " : diminue" if delta < 0 else " : inchangé"
	)
	values.name = "ComparisonValue"
	values.autowrap_mode = TextServer.AUTOWRAP_OFF
	values.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _progression(cards) -> void:
	if section == "attributes":
		var stats := preload("res://ui/expedition/player_statistics_view.gd").new()
		stats.session = GameManager.expedition
		stats.read_only = read_only
		stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stats.allocation_requested.connect(
			func():
				allocation_requested.emit(),
		)
		add_child(stats)
		return
	if section in ["allocation", "progression"] and cards.prototype_revision == 1:
		_attribute_choices(self, cards)
		return
	var columns := _columns()
	var decisions := D.column(columns, 430)
	if section in ["allocation", "progression"]:
		_attribute_choices(decisions, cards)
	else:
		_class_choices(decisions, cards)


func _family_actions(cards, id: String, row: VBoxContainer) -> void:
	var session = GameManager.expedition
	var merchant: bool = Integration.is_market(session)
	var owned: Array = cards.copies.filter(
		func(copy):
			return copy.family == id,
	)
	var prepared: Array = owned.filter(
		func(copy):
			return copy.id in cards.active,
	)
	var reserved: Array = owned.filter(
		func(copy):
			return copy.id not in cards.active,
	)
	var add_action := _button(
		_quick_actions,
		"+1 au deck (%d/3)" % prepared.size(),
		func():
			return cards.move_card(str(reserved[0].id)),
		reserved.is_empty() or prepared.size() >= 3 or cards.active.size() >= 30,
	)
	D.primary_button(add_action)
	_button(
		_quick_actions,
		"−1 réserve",
		func():
			return cards.move_card(str(prepared[-1].id)),
		prepared.is_empty(),
	)
	if cards.rarity(id) == 0 and not prepared.is_empty():
		var opening: bool = (
			not cards.opening.is_empty() and cards.copy_for(cards.opening[0]).get("family") == id
		)
		_button(
			row,
			"Retirer l'ouverture" if opening else "Choisir en ouverture",
			func():
				return cards.set_opening("" if opening else str(prepared[0].id)),
		)
	_button(
		row,
		"Sort amélioré" if id in cards.upgraded_ids else "Améliorer le sort",
		func():
			return cards.upgrade_copy(id),
		cards.points() <= 0 or id in cards.upgraded_ids,
	)
	_button(
		row,
		"Ne plus suivre" if id in cards.followed_families else "Suivre ce sort",
		func():
			if id in cards.followed_families:
				cards.followed_families.erase(id)
			elif cards.followed_families.size() < 2:
				cards.followed_families.append(id)
			else:
				return false
			return true,
	)
	if merchant:
		Economy.market(
			cards,
			session.route.current_node_id,
			int(Integration.encounter(session).index),
		)
		_button(
			row,
			"Vendre une carte en réserve",
			func():
				return Economy.transact(cards, session.route.current_node_id, {
					"id": "sell:" + str(reserved[0].id),
					"kind": "sell",
					"copies": [str(reserved[0].id)],
				}).get("success", false),
			reserved.is_empty(),
		)
		var tradable: Array = reserved.filter(
			func(copy):
				return copy.id not in trade_copies,
		)
		_button(
			row,
			"Ajouter une copie à l'échange",
			func():
				trade_copies.append(str(tradable[0].id))
				return true,
			cards.rarity(id) != 0 or tradable.is_empty() or trade_copies.size() >= 3,
		)


func _market(cards) -> void:
	var session = GameManager.expedition
	var stock := Economy.market(
		cards,
		session.route.current_node_id,
		int(Integration.encounter(session).index),
	)
	trade_copies = trade_copies.filter(
		func(uid):
			return not cards.copy_for(uid).is_empty(),
	)
	_text(
		"Échange · %d / 3 cartes normales sélectionnées · %d échange(s) restant(s)"
		% [trade_copies.size(), int(stock.trades)]
	)
	var targets := Catalog.pool(cards.primary_class, "normal", true)
	var choice := OptionButton.new()
	for id in targets:
		choice.add_item(str(Catalog.card(id).name))
	_content.add_child(choice)
	_button(
		self,
		"Échanger ces 3 cartes contre le sort choisi",
		func():
			var result := Economy.transact(
				cards,
				session.route.current_node_id,
				{
					"id": "trade:%d" % cards.receipts.size(),
					"kind": "trade",
					"copies": trade_copies.duplicate(),
					"family": targets[choice.selected],
				},
			)
			if result.get("success", false):
				trade_copies.clear()
			return result.get("success", false),
		trade_copies.size() != 3 or int(stock.trades) <= 0,
	)
	_button(
		self,
		"Annuler la sélection d'échange",
		func():
			trade_copies.clear()
			return true,
		trade_copies.is_empty(),
	)


func _attribute_choices(parent: VBoxContainer, cards) -> void:
	if cards.prototype_revision == 1:
		var editor := preload("res://ui/expedition/consumable_progression_editor.gd").new()
		editor.session = GameManager.expedition
		editor.read_only = read_only
		editor.committed.connect(_commit)
		parent.add_child(editor)
		return
	D.label(parent, "Renforcer votre personnage", 25, D.GOLD)
	D.label(
		parent,
		"%d point%s à répartir"
		% [cards.attribute_points(), "s" if cards.attribute_points() != 1 else ""],
		19,
		D.GREEN,
	)
	D.label(
		parent,
		"Chaque point améliore une caractéristique pour toute la run. La valeur suivante tient compte de votre équipement.",
		16,
		D.MUTED,
	)
	var mods := Math.equipment_mods(cards.equipped)
	var current := Math.stats(cards.level, cards.attributes, mods)
	for entry in [
		["power", "Puissance", "assassin"],
		["vitality", "Vitalité", "gardien"],
		["resolve", "Résolution", "thaumaturge"],
	]:
		var id := str(entry[0])
		var attributes: Dictionary = cards.attributes.duplicate()
		attributes[id] += 1
		var next := Math.stats(cards.level, attributes, mods)
		var panel := D.column(parent, 0, false)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		D.image(row, Icons.icon(entry[2]), 48)
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(body)
		D.label(
			body,
			"%s · %d point%s investi%s"
			% [
				entry[1],
				cards.attributes[id],
				"s" if cards.attributes[id] != 1 else "",
				"s" if cards.attributes[id] != 1 else "",
			],
			18,
		)
		var change := "%.1f → %.1f de Puissance" % [current.power, next.power]
		if id == "vitality":
			change = "%d → %d PV maximum" % [int(current.hp), int(next.hp)]
		if id == "resolve":
			change = "Résistance physique %.0f → %.0f %%\nBonus de garde %.0f → %.0f %%" % [
				current.physical * 100,
				next.physical * 100,
				current.guard * 100,
				next.guard * 100,
			]
		D.label(body, change, 17, D.GREEN)
		var add := _button(
			row,
			"+1",
			func():
				return cards.spend_attribute(id),
			cards.attribute_points() <= 0,
		)
		add.name = "Attribute_" + id
		add.size_flags_horizontal = Control.SIZE_SHRINK_END
		add.custom_minimum_size.x = 52
		add.tooltip_text = "Investir 1 point en " + str(entry[1]) + ". " + change
	if section == "progression":
		_class_choices(parent, cards)


func _class_choices(parent: VBoxContainer, cards) -> void:
	var allocate := _select(
		parent,
		"Répartir mes points · %d disponibles" % cards.attribute_points(),
		func():
			allocation_requested.emit(),
	)
	allocate.name = "OpenStatAllocation"
	allocate.disabled = read_only
	D.primary_button(allocate)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 14)
	parent.add_child(identity)
	D.image(identity, Icons.icon(cards.primary_class), 60)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(title)
	D.label(title, Catalog.class_row(cards.primary_class).name, 27, D.GOLD)
	D.label(title, "PASSIF DE CLASSE", 13, D.MUTED)
	D.label(parent, Language.CLASSES[cards.primary_class][0], 20, D.GOLD)
	D.label(parent, Language.CLASSES[cards.primary_class][1], 17)
	_rules(parent, Language.PASSIVES[cards.primary_class])
	if cards.prototype_revision == 1:
		var basic: Spell = cards.family_spell("fallback_strike")
		D.label(parent, "ATTAQUE PERMANENTE · " + basic.spell_name, 16, D.GOLD)
		_rules(
			parent,
			Language.effect(
				preload("res://core/expedition/consumable_card_spells.gd").definition(
					"fallback_strike",
					false,
					cards.primary_class,
				),
				GameManager.expedition.character.unit.attack_power.get_value(),
				cards,
			),
		)
	D.label(parent, "SPÉCIALISATION · NIVEAU 4", 14, D.GOLD)
	if cards.level < 4:
		D.label(parent, "Au niveau 4, choisissez l'une de ces deux voies.", 16, D.MUTED)
	for id in Catalog.class_row(cards.primary_class).specs:
		var panel := D.column(parent, 0, false)
		D.label(
			panel,
			Presenter.SPECS[id] + (" · Choisie" if cards.specialization == id else ""),
			20,
			D.GREEN if cards.specialization == id else D.GOLD,
		)
		_rules(panel, Language.SPECIALIZATIONS[id])
		if cards.level >= 4 and cards.specialization.is_empty():
			var choose := _button(
				panel,
				"Choisir " + str(Presenter.SPECS[id]),
				func():
					return cards.specialize(id),
			)
			choose.name = "Specialize_" + id
	D.label(parent, "AMÉLIORATIONS DE CARTES · %d POINT(S)" % cards.points(), 14, D.GOLD)
	D.label(
		parent,
		"Améliorer un sort renforce toutes ses cartes, déjà possédées ou reçues plus tard. Retrouvez son aperçu dans Sorts & deck.",
		16,
		D.MUTED,
	)
	var families := Catalog.pool()
	if cards.prototype_revision == 1:
		families = families.filter(
			func(id):
				return cards.copies.any(
					func(copy):
						return copy.family == id,
				),
		)
	var choice := OptionButton.new()
	choice.name = "UpgradeFamilyChoice"
	for id in families:
		choice.add_item(
			str(Catalog.card(id).name) + (" · Améliorée" if id in cards.upgraded_ids else "")
		)
	D.button(choice)
	parent.add_child(choice)
	_button(
		parent,
		"Améliorer ce sort · 1 point",
		func():
			return cards.upgrade_copy(families[choice.selected]),
		cards.points() <= 0 or families.is_empty(),
	)
	var session = GameManager.expedition
	if cards.prototype_revision == 1:
		D.label(
			parent,
			"Les emplacements peuvent être libérés puis réaffectés gratuitement entre les combats. Aucune carte n'est rendue.",
			15,
			D.MUTED,
		)
		for id in cards.upgraded_ids:
			var release := _button(
				parent,
				"Libérer · " + str(Catalog.card(id).name),
				func():
					return cards.release_upgrade(id),
			)
			release.name = "ReleaseUpgrade_" + str(id)
		return
	if Integration.is_market(session) and not cards.upgraded_ids.is_empty():
		var stock := Economy.market(
			cards,
			session.route.current_node_id,
			int(Integration.encounter(session).index),
		)
		var from := OptionButton.new()
		for id in cards.upgraded_ids:
			from.add_item(str(Catalog.card(id).name))
		D.button(from)
		parent.add_child(from)
		_button(
			parent,
			"Réaffecter l'amélioration · 35 oboles",
			func():
				return Economy.transact(cards, session.route.current_node_id, {
					"id": "respec",
					"kind": "respec",
					"from": cards.upgraded_ids[from.selected],
					"family": families[choice.selected],
				}).get("success", false),
			int(stock.respec) <= 0 or cards.gold < 35,
		)


func _rules(parent: Node, value: String) -> void:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_override("normal_font", D.FONT)
	text.add_theme_font_size_override("normal_font_size", 18)
	text.add_theme_color_override("default_color", D.PAPER)
	var rule := Language.plain(value).replace("[", "[lb]")
	for word in [
		"marque",
		"Marque",
		"garde",
		"Garde",
		"Stase",
		"Brûlure",
		"brûlure",
		"saignement",
		"Parade",
		"parade",
		"Riposte",
		"riposte",
	]:
		rule = rule.replace(word, "[color=#dbb98f]" + word + "[/color]")
	text.text = rule
	parent.add_child(text)
