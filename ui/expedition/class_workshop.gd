extends VBoxContainer
## One selected object, persistent detail pane, explicit acquisition/equipment state.
signal transaction_completed
const Catalog := preload("res://core/expedition/class_card_catalog.gd")
const Text := preload("res://ui/expedition/catabase_card_text.gd")
const CardSkin := preload("res://ui/expedition/catabase_card_skin.gd")
var mode := "deck"
var read_only := false
var selected_id := ""
var filter := "deck"
var notice := ""
var cards
var detail: VBoxContainer


func _ready() -> void:
	name = "ClassWorkshop"
	cards = GameManager.expedition.cards
	_render()


func _label(parent: Node, text: String, size := 18) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 42
	b.disabled = disabled
	CardSkin.action(b)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _commit(ok: bool) -> void:
	notice = "Choix enregistré." if ok else "Ce choix n'est pas disponible."
	if ok and not GameManager.save_expedition():
		notice = "Choix appliqué ; sauvegarde impossible. Réessayez avant de quitter."
	transaction_completed.emit()
	_render()


func _render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 12)
	var session: ExpeditionSession = cards.owner()
	read_only = read_only or session.route.phase == "combat"
	_label(
		self,
		("MON DECK  ·  " if mode == "deck" and filter != "gear" else "")
		+ "%s · niveau %d · %d points de perfection"
		% [
			Catalog.CLASSES[cards.primary_class][0],
			session.character.champion_progression.current_level,
			cards.points(),
		],
		25,
	)
	if mode == "progression":
		_progression()
		return
	if mode == "loot":
		_label(self, session.last_message, 19)
		_label(
			self,
			"Butin acquis. Les cartes vont dans votre réserve ; les objets dans l'inventaire. Survolez ou sélectionnez une icône pour lire ses effets. Équiper et remplacer restent des choix volontaires.",
			16,
		)
		filter = "loot"
	else:
		_label(
			self,
			"10 cartes au deck · 2 copies maximum par famille · main de 4. Deux gestes de secours restent toujours disponibles. Les cartes étrangères fonctionnent dès la maîtrise 0.",
			16,
		)
		var tabs := HBoxContainer.new()
		add_child(tabs)
		for entry in [
			["deck", "Deck · 10"],
			["reserve", "Réserve · %d" % (cards.copies.size() - 10)],
			["gear", "Équipement & objets"],
		]:
			var b := _button(
				tabs,
				("✓ " if filter == entry[0] else "") + entry[1],
				func():
					filter = entry[0]
					selected_id = ""
					_render(),
			)
			b.toggle_mode = true
			b.button_pressed = filter == entry[0]
	if not notice.is_empty():
		_label(self, notice, 16)
	if filter == "gear":
		var slots := HFlowContainer.new()
		add_child(slots)
		for slot in EquipmentLoadout.EQUIPMENT_SLOTS:
			var worn := session.character.equipment_loadout.get_item(slot)
			var title := EquipmentLoadout.get_slot_display_name(slot) + " · "
			title += (
				session \
						.card_inventory \
						.get_catalog() \
						.get_definition(worn.definition_id) \
						.display_name
				if worn != null
				else "vide"
			)
			_button(
				slots,
				title,
				func():
					selected_id = str(worn.instance_id)
					_show_detail(),
				worn == null,
			)
	if mode != "loot":
		var stock: Array = cards.shop()
		if not stock.is_empty():
			_label(self, "Marchand de cartes · stock conservé à cette halte", 20)
			for i in stock.size():
				var offer: Dictionary = stock[i]
				var price: int = cards.BUY[cards.rarity(offer.family)]
				_button(
					self,
					"%s · %d oboles%s"
					% [
						cards.family_spell(offer.family).spell_name,
						price,
						" · acheté" if offer.sold else "",
					],
					func():
						_commit(cards.buy(i)),
					read_only or offer.sold or session.gold < price,
				)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	columns.custom_minimum_size.y = clampf(get_viewport_rect().size.y - 290, 300, 680)
	add_child(columns)
	var list_scroll := ScrollContainer.new()
	list_scroll.name = "CardListScroll"
	list_scroll.follow_focus = true
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_stretch_ratio = 1.5
	columns.add_child(list_scroll)
	var grid := GridContainer.new()
	grid.columns = 3 if get_viewport_rect().size.x >= 1500 or filter == "gear" else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_stretch_ratio = 1.5
	list_scroll.add_child(grid)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "CardDetailScroll"
	detail_scroll.follow_focus = true
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(detail_scroll)
	var pane := PanelContainer.new()
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.size_flags_stretch_ratio = 1.0
	pane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pane.add_theme_stylebox_override("panel", CardSkin.frame(true))
	detail_scroll.add_child(pane)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 10)
	pane.add_child(detail)
	var available: Array[String] = []
	for card in cards.copies:
		if (
			(filter == "deck" and card.id not in cards.active)
			or (filter == "reserve" and card.id in cards.active) or filter == "gear"
			or (filter == "loot" and card.id not in cards.last_drops)
		):
			continue
		available.append(card.id)
		var spell: Spell = cards.spells_for(card.id)[0]
		_tile(
			grid,
			str(card.id),
			spell.spell_name,
			spell.icon,
			Text.details(spell, session.character.unit),
		)
	if filter in ["gear", "loot"]:
		var inventory: RunInventory = session.card_inventory
		if inventory != null:
			for item in inventory.get_slots() + session \
					.character \
					.equipment_loadout \
					.get_equipped_items():
				if item == null:
					continue
				if filter == "loot" and str(item.definition_id) not in cards.loot_items.get(
						session.route.current_node_id,
						[],
					):
					continue
				var definition := inventory.get_catalog().get_definition(item.definition_id)
				available.append(str(item.instance_id))
				_tile(
					grid,
					str(item.instance_id),
					definition.display_name,
					definition.icon,
					definition.description,
				)
	if selected_id not in available:
		selected_id = available[0] if not available.is_empty() else ""
	if available.is_empty():
		_label(grid, "Aucun objet ici pour le moment.")
	_show_detail()
	if not cards.pending_items.is_empty():
		_label(
			self,
			"%d objet(s) attendent une place dans l'inventaire. Ils sont conservés dans le butin en attente."
			% cards.pending_items.size(),
		)
		_button(
			self,
			"Récupérer le butin en attente",
			func():
				cards.collect_pending()
				_commit(true),
			read_only,
		)


func _tile(
	parent: Control,
	id: String,
	title: String,
	texture: Texture2D,
	description: String,
) -> void:
	var copy: Dictionary = cards.copy_for(id)
	if not copy.is_empty():
		var tile := preload("res://ui/expedition/class_card_tile.gd").new()
		tile.name = "ClassChoice_" + id
		var native: bool = Catalog.row(copy.family)[1] == cards.primary_class
		var location := "au deck" if id in cards.active else "réserve"
		if cards.owner().route.phase == "combat" and id in cards.active:
			location = "en main" if id in cards.hand else "défausse" if id in cards.discard else "épuisée" if id in cards.exhausted else "pioche"
		tile.configure(
			cards.spells_for(id)[0],
			cards.owner().character.unit,
			("Classe principale" if native else "Carte étrangère") + " · " + location,
		)
		parent.add_child(tile)
		tile.pressed.connect(
			func():
				selected_id = id
				_show_detail(),
		)
		tile.focus_entered.connect(
			func():
				selected_id = id
				_show_detail(),
		)
		return
	var b := Button.new()
	b.name = "ClassChoice_" + id
	b.text = title
	b.icon = texture
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 52)
	b.custom_minimum_size = Vector2(165, 90)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.tooltip_text = description
	CardSkin.action(b)
	parent.add_child(b)
	b.pressed.connect(
		func():
			selected_id = id
			_show_detail(),
	)
	b.focus_entered.connect(
		func():
			selected_id = id
			_show_detail(),
	)


func _show_detail() -> void:
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	if selected_id.is_empty():
		_label(detail, "Sélectionnez une carte ou un objet.")
		return
	var card: Dictionary = cards.copy_for(selected_id)
	if not card.is_empty():
		_card_detail(card)
		return
	var session: ExpeditionSession = cards.owner()
	var inventory: RunInventory = session.card_inventory
	var item := inventory.get_instance(StringName(selected_id))
	var equipped := false
	if item == null:
		for worn in session.character.equipment_loadout.get_equipped_items():
			if str(worn.instance_id) == selected_id:
				item = worn
				equipped = true
				break
	if item == null:
		return
	var definition := inventory.get_catalog().get_definition(item.definition_id)
	_label(detail, definition.display_name, 23)
	_label(detail, "Équipé" if equipped else "Dans votre inventaire", 16)
	_label(detail, definition.description)
	if str(definition.item_id).begins_with("ct_supply_"):
		_label(
			detail,
			"Relique éphémère : à activer dans l'onglet Objets pendant votre tour de combat.",
			16,
		)
	elif definition.is_relic():
		_label(
			detail,
			"Relique active automatiquement tant qu'elle reste dans votre inventaire. La vendre retire son effet.",
			16,
		)
	if item.rune_id != &"":
		var rune := inventory.get_catalog().get_definition(item.rune_id)
		_label(detail, "Rune sertie : " + rune.display_name + "\n" + rune.description, 16)
	if definition.category == ItemDefinition.Category.RUNE:
		var candidates: Array[ItemInstance] = []
		var selector := OptionButton.new()
		detail.add_child(selector)
		for target in inventory.get_slots() + session \
				.character \
				.equipment_loadout \
				.get_equipped_items():
			if target == null or target.rune_id != &"":
				continue
			var target_def := inventory.get_catalog().get_definition(target.definition_id)
			if target_def.is_equippable():
				candidates.append(target)
				selector.add_item(target_def.display_name)
		_button(
			detail,
			"Sertir définitivement cette rune",
			func():
				_commit(
					cards.socket_rune(item.instance_id, candidates[selector.selected].instance_id)
				),
			read_only or candidates.is_empty(),
		)
	if definition.is_equippable():
		var old := session.character.equipment_loadout.get_item(definition.equipment_slot)
		_label(
			detail,
			"Emplacement : " + EquipmentLoadout.get_slot_display_name(definition.equipment_slot),
			16,
		)
		if old != null and not equipped:
			var old_def := inventory.get_catalog().get_definition(old.definition_id)
			_label(detail, "Remplace : " + old_def.display_name + "\n" + old_def.description, 16)
		var service := EquipmentService.new()
		service.initialize(inventory.get_catalog())
		_button(
			detail,
			"Retirer cet équipement" if equipped else "Équiper cet objet",
			func():
				var result: Dictionary = (
					service.unequip(inventory, session.character, definition.equipment_slot)
					if equipped
					else service.equip(
						inventory,
						session.character,
						item.instance_id,
						definition.equipment_slot,
					)
				)
				_commit(bool(result.get("success", false))),
			read_only,
		)
	if not equipped:
		var price := preload("res://ui/expedition/class_card_presentation.gd").item_sale_price(
			definition
		)
		_button(
			detail,
			"Vendre · %d oboles" % price,
			func():
				var removed := inventory.take_instance(item.instance_id)
				if removed.get("success", false):
					session.gold += price
				_commit(bool(removed.get("success", false))),
			read_only,
		)


func _card_detail(card: Dictionary) -> void:
	var spell: Spell = cards.spells_for(card.id)[0]
	_label(detail, spell.spell_name, 23)
	var native: bool = Catalog.row(card.family)[1] == cards.primary_class
	_label(
		detail,
		("Classe principale" if native else "Carte étrangère · maîtrise plafonnée à 2")
		+ (" · au deck" if card.id in cards.active else " · en réserve"),
		16,
	)
	_label(detail, Text.details(spell, cards.owner().character.unit), 17)
	if card.id not in cards.active:
		var replacement := OptionButton.new()
		replacement.name = "ClassReplacement"
		for id in cards.active:
			replacement.add_item(cards.title_for(id))
		detail.add_child(replacement)
		_button(
			detail,
			"Remplacer la copie sélectionnée",
			func():
				_commit(cards.move_card(card.id, cards.active[replacement.selected])),
			read_only,
		)
		_button(
			detail,
			"Vendre · %d oboles" % cards.SELL[cards.rarity(card.family)],
			func():
				_commit(cards.sell(card.id)),
			read_only or card.bound or card.favorite,
		)
	var class_id: String = Catalog.row(card.family)[1]
	_label(
		detail,
		"Amélioration : "
		+ (
			"garde sur 2 activations"
			if Catalog.row(card.family)[7] == "guard"
			else "franchit les obstacles"
			if Catalog.row(card.family)[7] == "move"
			else "ignore la ligne de vue" if spell.spell_range > 1 else "+1 portée"
		)
		+ ". Coût : 2 points, maîtrise 3 requise. Par exemplaire.",
		16,
	)
	_button(
		detail,
		"Améliorer cet exemplaire · 2 points",
		func():
			_commit(cards.upgrade_copy(card.id)),
		read_only or cards.points() < 2 or int(cards.masteries[class_id]) < 3
		or card.get("upgraded", false),
	)


func _progression() -> void:
	_label(
		self,
		"Les points sont gagnés aux niveaux pairs. Vous pouvez les conserver. Monter une maîtrise augmente les dégâts et la garde de toutes ses cartes ; améliorer une carte ne transforme que cet exemplaire.",
		17,
	)
	if not notice.is_empty():
		_label(self, notice, 16)
	if cards.can_correct():
		_label(
			self,
			"Première halte : une correction gratuite. Rend les points de maîtrise et d'amélioration, retire les améliorations et réouvre la spécialisation. Les objets et cartes vendus restent vendus.",
			16,
		)
		_button(
			self,
			"Réinitialiser ces investissements",
			func():
				_commit(cards.correct_build()),
			read_only,
		)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	add_child(grid)
	for id in Catalog.CLASSES:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", CardSkin.frame(id == cards.primary_class))
		grid.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		_label(
			box,
			"%s · maîtrise %d / %d"
			% [Catalog.CLASSES[id][0], cards.masteries[id], 4 if id == cards.primary_class else 2],
			22,
		)
		_label(
			box,
			"+%d %% dégâts et garde. Les coûts, déplacements et contrôles restent fixes."
			% (int(cards.masteries[id]) * 10),
			16,
		)
		var cost: int = cards.mastery_cost(id)
		_button(
			box,
			(
				"Plafond atteint"
				if cost < 0
				else "Maîtrise %d → %d · %d points"
				% [cards.masteries[id], int(cards.masteries[id]) + 1, cost]
			),
			func():
				_commit(cards.train(id)),
			read_only or cost < 0 or cards.points() < cost,
		)
	var level: int = cards.owner().character.champion_progression.current_level
	_label(self, "Spécialisation · niveau 4", 23)
	_label(
		self,
		"Remplace votre passif initial. Elle s'applique aussi aux cartes empruntées qui remplissent sa condition.",
		16,
	)
	for spec in Catalog.SPECS[cards.primary_class]:
		_button(
			self,
			("✓ " if cards.specialization == spec[0] else "") + spec[1] + " — " + spec[2],
			func():
				_commit(cards.specialize(spec[0])),
			read_only or level < 4 or not cards.specialization.is_empty(),
		)
	if level < 4:
		_label(self, "Passif actuel : " + Catalog.CLASSES[cards.primary_class][2], 16)
	else:
		for spec in Catalog.SPECS[cards.primary_class]:
			if spec[0] == cards.specialization:
				_label(self, "Passif actuel : " + spec[2], 16)
