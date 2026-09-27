extends "res://ui/expedition/consumable_cards_workshop.gd"
## Public player dossier. Transactions remain owned by the existing workshop/rules.
const D := preload("res://ui/expedition/player_dossier_skin.gd")
const Receipt := preload("res://ui/expedition/consumable_loot_receipt.gd")
const Presenter := preload("res://ui/expedition/consumable_cards_presenter.gd")
const Icons := preload("res://core/expedition/class_icon_catalog.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")
var selected_family := ""
var selected_item := ""
var card_filter := 0
var item_filter := 0
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
	_tiles.clear()
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
	_summary(cards)
	var columns := _columns()
	var library := D.column(columns, 430, false)
	var bar := HBoxContainer.new()
	library.add_child(bar)
	var search := LineEdit.new()
	search.name = "DossierSearch"
	search.placeholder_text = "Rechercher une carte…"
	search.text = query
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.y = 38
	search.add_theme_font_override("font", D.FONT)
	search.add_theme_font_size_override("font_size", 17)
	search.add_theme_stylebox_override("normal", D.surface(false, 9))
	search.add_theme_stylebox_override("focus", D.surface(true, 9))
	bar.add_child(search)
	var filter := OptionButton.new()
	filter.name = "DossierCardFilter"
	for title in ["Toutes", "Préparées", "En réserve", "Ma classe", "Autres classes"]:
		filter.add_item(title)
	filter.selected = card_filter
	D.button(filter)
	bar.add_child(filter)
	var scroll := ScrollContainer.new()
	scroll.name = "DossierCollectionScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	library.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "CardGallery"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	scroll.add_child(grid)
	var seen := { }
	for copy in cards.copies:
		var id := str(copy.family)
		if seen.has(id):
			continue
		seen[id] = true
		var record := Receipt.card_record(id, id in cards.upgraded_ids)
		var tile := _card_tile(grid, record, cards)
		_tiles[id] = tile
		if selected_family.is_empty():
			selected_family = id
	var empty := D.label(library, "Aucune carte ne correspond à ces filtres.", 17, D.MUTED)
	empty.name = "EmptyCollection"
	var update := func():
		var count := 0
		for id in _tiles:
			var row := Catalog.card(id)
			var owned := _copies(cards, id, false)
			var prepared := _copies(cards, id, true)
			var matches := query.is_empty() or query.to_lower() in str(row.name).to_lower()
			matches = (
				matches
				and (
					card_filter == 0 or (card_filter == 1 and not prepared.is_empty())
					or (card_filter == 2 and owned.size() > prepared.size())
					or (card_filter == 3 and row.affinity in [cards.primary_class, "shared"])
					or (card_filter == 4 and row.affinity not in [cards.primary_class, "shared"])
				)
			)
			_tiles[id].visible = matches
			if matches:
				count += 1
		empty.visible = count == 0
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
	var inspector := D.column(columns, 342, false)
	var reading := ScrollContainer.new()
	reading.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reading.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reading.follow_focus = true
	inspector.add_child(reading)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	reading.add_child(_detail)
	_detail.name = "CardInspector"
	_quick_actions = HBoxContainer.new()
	_quick_actions.name = "CardQuickActions"
	_quick_actions.add_theme_constant_override("separation", 6)
	inspector.add_child(_quick_actions)
	if not seen.has(selected_family):
		selected_family = "" if seen.is_empty() else str(seen.keys()[0])
	_show_family(cards)
	update.call()
	D.label(
		self,
		"Une copie jouée est consommée. 3 copies maximum par famille. Sélectionnez une carte pour la préparer ou l'améliorer.",
		14,
		D.MUTED,
	)


func _copies(cards, id: String, prepared: bool) -> Array:
	return cards.copies.filter(
		func(copy):
			return copy.family == id and (not prepared or copy.id in cards.active),
	)


func _card_tile(parent: Node, record: Dictionary, cards) -> Button:
	var id := str(record.id)
	var node := _select(
		parent,
		"",
		func():
			selected_family = id
			_show_family(cards),
		id == selected_family,
	)
	node.name = "Family_" + id
	node.custom_minimum_size = Vector2(122, 176)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	node.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 9
	box.offset_right = -9
	box.offset_top = 8
	box.offset_bottom = -8
	box.add_theme_constant_override("separation", 3)
	var rarity := Color(Receipt.COLORS[record.rarity])
	var label := D.label(
		box,
		"%d PA · %s" % [int(record.row.ap), Receipt.RARITY_NAMES[record.rarity]],
		13,
		rarity,
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	D.image(box, record.icon, 72)
	label = D.label(box, str(record.title), 16)
	label.custom_minimum_size.y = 40
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var prepared := _copies(cards, id, true).size()
	var owned := _copies(cards, id, false).size()
	label = D.label(
		box,
		"%d prête%s · %d réserve" % [prepared, "s" if prepared != 1 else "", owned - prepared],
		13,
		D.GREEN if prepared > 0 else D.MUTED,
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.accessibility_name = "%s. %d PA. %s. %d préparées, %d en réserve." % [
		record.title,
		int(record.row.ap),
		Receipt.RARITY_NAMES[record.rarity],
		prepared,
		owned - prepared,
	]
	D.passive(box)
	return node


func _show_family(cards) -> void:
	for child in _quick_actions.get_children():
		_quick_actions.remove_child(child)
		child.queue_free()
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	for id in _tiles:
		D.button(_tiles[id], id == selected_family)
	if selected_family.is_empty():
		D.label(_detail, "Votre collection est vide", 23, D.GOLD)
		D.label(_detail, "Les cartes reçues en combat et achetées rejoindront votre réserve.")
		return
	var record := Receipt.card_record(selected_family, selected_family in cards.upgraded_ids)
	var accent := Color(Receipt.COLORS[record.rarity])
	D.label(_detail, "CARTE · " + str(Receipt.RARITY_NAMES[record.rarity]).to_upper(), 13, accent)
	D.label(_detail, record.title, 25, D.GOLD)
	D.label(
		_detail,
		record.category + (" · Améliorée" if record.upgraded else " · Forme de base"),
		15,
		D.MUTED,
	)
	var header := HBoxContainer.new()
	_detail.add_child(header)
	D.image(header, record.icon, 80)
	var values := VBoxContainer.new()
	values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(values)
	var spell: Spell = cards.family_spell(selected_family)
	var hero: Unit = GameManager.expedition.character.unit
	D.label(values, "%d PA" % hero.get_spell_ap_cost(spell), 25, D.GOLD)
	D.label(
		values,
		"Portée " + preload("res://ui/expedition/catabase_card_text.gd").range_text(spell, hero),
		17,
	)
	D.label(values, "Physique" if record.row.type == "physical" else "Magique", 15, D.MUTED)
	var shapes := {
		"single": "Cible unique",
		"cross": "Croix",
		"radius2": "Rayon de 2 cases",
		"line3_perpendicular": "Ligne de 3 cases",
	}
	D.label(values, shapes.get(record.row.shape, ""), 14, D.MUTED)
	_detail.add_child(HSeparator.new())
	D.label(_detail, "EFFET DE LA CARTE", 13, accent)
	_rules(_detail, record.body)
	D.label(
		_detail,
		"P = %.1f de puissance · avant résistances et bonus conditionnels."
		% hero.attack_power.get_value(),
		14,
		D.MUTED,
	)
	if not record.upgraded:
		var evolution := D.column(_detail, 0, false)
		D.label(evolution, "AMÉLIORATION · 1 POINT", 13, D.GREEN)
		D.label(evolution, Catalog.card(selected_family).upgradeText, 16)
	D.label(_detail, "DÉVELOPPER CETTE FAMILLE", 13, D.GOLD)
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
	for label in ["Tous les objets", "Équipements", "Reliques"]:
		filter.add_item(label)
	filter.selected = item_filter
	D.button(filter)
	bag.add_child(filter)
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
		tile.set_meta("relic", relic)
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
			tile.visible = item_filter == 0 or tile.get_meta("relic") == (item_filter == 2)
			if tile.visible:
				count += 1
		empty.visible = count == 0
	filter.item_selected.connect(
		func(index):
			item_filter = index
			update.call(),
	)
	update.call()
	D.label(bag, "✓ Équipé ou actif\nSélectionnez un objet pour le comparer.", 14, D.MUTED)
	_detail = D.column(columns, 280)
	_detail.name = "ItemInspector"
	if not owned.has(selected_item):
		selected_item = "" if owned.is_empty() else str(owned.keys()[0])
	_show_item(cards)


func _show_item(cards) -> void:
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	for id in _tiles:
		D.button(_tiles[id], id == selected_item)
	if selected_item.is_empty():
		D.image(_detail, Icons.icon("relic_obole"), 100)
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
	D.label(_detail, str(record.category).to_upper(), 13, D.MUTED)
	D.label(_detail, record.title, 24, D.GOLD)
	D.image(_detail, record.icon, 124)
	D.label(_detail, "EFFETS", 13, D.GOLD)
	if relic:
		D.label(_detail, row.rule, 18)
		var active: bool = id in cards.active_relics
		D.label(
			_detail,
			"Relique active" if active else "Relique conservée dans l'inventaire",
			15,
			D.GREEN,
		)
		_button(
			_detail,
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
		_button(
			_detail,
			"Retirer cet équipement" if active else "Équiper cet objet",
			func():
				if active:
					cards.equipped.erase(row.slot)
				else:
					cards.equipped[row.slot] = id
				return true,
		)
	D.label(_detail, "Les modifications sont enregistrées immédiatement.", 14, D.MUTED)


func _progression(cards) -> void:
	var columns := _columns()
	var stats := D.column(columns, 300)
	var hero: Unit = GameManager.expedition.character.unit
	D.label(stats, "VOTRE PERSONNAGE", 13, D.MUTED)
	D.label(stats, hero.unit_name, 28, D.GOLD)
	D.label(
		stats,
		"%s · Niveau %d" % [Catalog.class_row(cards.primary_class).name, cards.level],
		19,
	)
	var life := ProgressBar.new()
	life.custom_minimum_size.y = 18
	life.max_value = hero.max_hp.get_int()
	life.value = hero.current_hp
	life.show_percentage = false
	var fill := D.surface(false, 0)
	fill.bg_color = Color("a8835e")
	life.add_theme_stylebox_override("fill", fill)
	life.add_theme_stylebox_override("background", D.surface(false, 0))
	stats.add_child(life)
	D.label(stats, "%d / %d points de vie" % [hero.current_hp, hero.max_hp.get_int()], 19, D.GREEN)
	stats.add_child(HSeparator.new())
	D.label(stats, "COMBAT", 13, D.GOLD)
	for entry in [
		["Points d'action", str(hero.max_ap.get_int()) + " PA"],
		["Points de mouvement", str(hero.max_mp.get_int()) + " PM"],
		["Puissance des cartes", "%.1f P" % hero.attack_power.get_value()],
		["Résistance physique", "%.0f %%" % minf(40, hero.armure.get_value())],
		["Résistance magique", "%.0f %%" % minf(40, hero.resist_magique.get_value())],
		["Taille de main", "%d cartes" % cards.hand_capacity],
	]:
		var row := HBoxContainer.new()
		stats.add_child(row)
		var label := D.label(row, entry[0], 17, D.MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label = D.label(row, entry[1], 18)
		label.custom_minimum_size.x = 68
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_child(HSeparator.new())
	D.label(stats, "BONUS D'ÉQUIPEMENT", 13, D.GOLD)
	var mods := Math.equipment_mods(cards.equipped)
	if mods.is_empty():
		D.label(stats, "Aucun équipement actif.", 16, D.MUTED)
	for key in mods:
		D.label(stats, Presenter.item_text({ "mods": { key: mods[key] } }), 16, D.GREEN)
	D.label(
		stats,
		"Valeurs actuelles, équipement inclus. Les bonus conditionnels s'appliquent lors de l'action.",
		14,
		D.MUTED,
	)
	var decisions := D.column(columns, 430)
	if section in ["attributes", "progression"]:
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
	_button(
		_quick_actions,
		"Préparer (%d / 3)" % prepared.size(),
		func():
			return cards.move_card(str(reserved[0].id)),
		reserved.is_empty() or prepared.size() >= 3 or cards.active.size() >= 30,
	)
	_button(
		_quick_actions,
		"Mettre en réserve",
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
		"Famille améliorée" if id in cards.upgraded_ids else "Améliorer la famille",
		func():
			return cards.upgrade_copy(id),
		cards.points() <= 0 or id in cards.upgraded_ids,
	)
	_button(
		row,
		"Ne plus suivre" if id in cards.followed_families else "Suivre cette famille",
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
			"Vendre une copie en réserve",
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
		"Échange · %d / 3 copies normales sélectionnées · %d échange(s) restant(s)"
		% [trade_copies.size(), int(stock.trades)]
	)
	var targets := Catalog.pool(cards.primary_class, "normal", true)
	var choice := OptionButton.new()
	for id in targets:
		choice.add_item(str(Catalog.card(id).name))
	_content.add_child(choice)
	_button(
		self,
		"Échanger ces 3 copies contre la famille choisie",
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
		var change := "%.1f → %.1f P" % [current.power, next.power]
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
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 14)
	parent.add_child(identity)
	D.image(identity, Icons.icon(cards.primary_class), 60)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(title)
	D.label(title, Catalog.class_row(cards.primary_class).name, 27, D.GOLD)
	D.label(title, "PASSIF DE CLASSE", 13, D.MUTED)
	_rules(parent, Catalog.class_row(cards.primary_class).passive)
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
		_rules(panel, str(Catalog.data().specs[id]))
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
		"Une amélioration s'applique à toutes les copies actuelles et futures de la famille. Retrouvez son aperçu dans Sorts & deck.",
		16,
		D.MUTED,
	)
	var families := Catalog.pool()
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
		"Améliorer cette famille · 1 point",
		func():
			return cards.upgrade_copy(families[choice.selected]),
		cards.points() <= 0,
	)
	var session = GameManager.expedition
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
	var rule := value.replace("[", "[lb]")
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
