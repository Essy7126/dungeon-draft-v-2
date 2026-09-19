extends VBoxContainer
const CardText = preload("res://ui/expedition/catabase_card_text.gd")
const CardSkin = preload("res://ui/expedition/catabase_card_skin.gd")
signal transaction_completed
var loot_only := false
var read_only := false
var _notice := ""
var _cards: CatabaseCards


func _ready() -> void:
	name = "CatabaseCardCollection"
	_render()


func _exit_tree() -> void:
	if _cards != null: _cards.sale_undo.clear()


func _label(parent: Node, value: String, color := Color("e5dcc7")) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if loot_only: label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, value: String, action: Callable, locked := false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 34
	button.disabled = locked or read_only
	CardSkin.action(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _commit(ok: bool) -> void:
	if ok:
		_notice = "Enregistré." if GameManager.save_expedition() else "Action appliquée ; sauvegarde impossible. Réessayez avant de quitter."
	else: _notice = "Action impossible : vérifiez le solde, les deux copies par famille et les huit cartes minimum."
	transaction_completed.emit()
	_render()


func _render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var session = GameManager.expedition
	if session == null or session.cards == null: return
	if session.cards.rules_revision == 3:
		var view := preload("res://ui/expedition/class_workshop.gd").new()
		view.mode = "loot" if loot_only else "deck"
		view.read_only = read_only
		view.transaction_completed.connect(func(): transaction_completed.emit())
		add_child(view)
		return
	var cards: CatabaseCards = session.cards
	_cards = cards
	read_only = read_only or session.route.phase == "combat"
	# The reward screen already explains acquisition; avoid repeating its header.
	if not loot_only:
		_label(self, "DECK & RÉSERVE · %d cartes actives · %d oboles" % [cards.active.size(), session.gold], Color("e6ba62")).add_theme_font_size_override("font_size", 22)
		_label(self, "8 cartes minimum · 2 copies par famille · main de 4. Les deux gestes d'arme sont toujours disponibles, hors pioche.")
		if cards.copies.any(func(card): return card.family == CatabaseCards.GESTURE):
			_label(self, "Ancienne run convertie : vos Gestes sont archivés, vos manœuvres supplémentaires restent en réserve. Aucun butin acquis n'a été supprimé.")
	if not _notice.is_empty(): _label(self, _notice, Color("7bd3c0"))
	if not loot_only: _render_shop(cards)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	# New loot and reserves come first; one panel per family, not per copy.
	var ids: Array[String] = cards.last_drops.duplicate()
	if not loot_only:
		for card in cards.copies:
			if card.id not in cards.active and card.id not in ids: ids.append(str(card.id))
		for id in cards.active:
			if id not in ids: ids.append(id)
	if loot_only:
		var loot_families := {}
		for id in ids:
			var copy := cards.copy_for(id)
			if not copy.is_empty(): loot_families[copy.family] = true
		grid.columns = clampi(loot_families.size(), 1, 3)
	var displayed := {}
	for id in ids:
		var card := cards.copy_for(id)
		if card.is_empty() or card.family == CatabaseCards.GESTURE or displayed.has(card.family): continue
		displayed[card.family] = true
		var owned: Array = cards.copies.filter(func(copy): return copy.family == card.family)
		var in_deck: Array = owned.filter(func(copy): return copy.id in cards.active)
		var reserve: Array = owned.filter(func(copy): return copy.id not in cards.active)
		var sellable: Array = reserve.filter(func(copy): return not copy.bound and not copy.favorite)
		var rank := cards.rarity(str(card.family))
		var panel := PanelContainer.new()
		panel.custom_minimum_size.x = 220
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := CardSkin.frame(id in cards.active)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", style)
		grid.add_child(panel)
		var column := VBoxContainer.new()
		panel.add_child(column)
		panel.name = "CardFamily_" + str(card.family)
		_label(column, cards.title_for(id) + " ×%d" % owned.size(), CatabaseCards.COLORS[rank]).add_theme_font_size_override("font_size", 18)
		_label(column, "%s · niv. effectif %d" % [CatabaseCards.NAMES[rank], session.character.champion_progression.current_level])
		var new_count := owned.filter(func(copy): return copy.id in cards.last_drops).size()
		_label(column, "%d au deck · %d en réserve%s" % [in_deck.size(), reserve.size(), " · +%d reçue(s)" % new_count if new_count > 0 else ""], Color("7bd3c0") if new_count > 0 else Color("e5dcc7"))
		var spells := cards.spells_for(id)
		for spell in spells:
			var family: String = session.build.catalog.get_spell_family(str(spell.spell_id))
			var variants := cards.known_forms(family)
			if variants.size() < 2: continue
			var form := OptionButton.new()
			form.disabled = read_only
			for variant in variants: form.add_item("Forme : " + variant.spell_name)
			form.select(variants.find(spell))
			form.tooltip_text = "Choisit la forme de toutes les copies de cette famille pour le prochain combat."
			form.item_selected.connect(func(index): _commit(cards.choose_form(family, str(variants[index].spell_id))))
			column.add_child(form)
		if not loot_only and not spells.is_empty() and spells[0].icon != null:
			var icon := TextureRect.new()
			icon.texture = spells[0].icon
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size.y = 48
			column.add_child(icon)
		var text := ""
		for spell in spells: text += CardText.details(spell, session.character.unit) + "\n"
		panel.tooltip_text = text
		var owned_count := owned.size()
		panel.tooltip_text += "\n%d copie(s) possédée(s) · revente %d oboles" % [owned_count, 0 if card.bound else CatabaseCards.SELL[rank]]
		for spell in spells:
			_label(column, spell.spell_name + " · " + CardText.effect(spell, session.character.unit))
		if not reserve.is_empty():
			_render_replacement(column, cards, str(reserve[0].id))
			_button(column, "Vendre 1 · %d oboles" % CatabaseCards.SELL[rank] if not sellable.is_empty() else "Copies liées ou protégées", func(): _commit(cards.sell(str(sellable[0].id))), sellable.is_empty())
		var details := _button(column, "Lire les effets et conditions", func(): _show_details(cards.title_for(id), text))
		details.disabled = false
		if not in_deck.is_empty():
			_button(column, "Retirer 1 du deck", func(): _commit(cards.move_card(str(in_deck[-1].id))), cards.active.size() <= CatabaseCards.MIN_DECK)
		if not loot_only:
			var all_protected := owned.all(func(copy): return copy.favorite)
			_button(column, "★ Déprotéger la famille" if all_protected else "☆ Protéger la famille", func():
				for copy in owned: copy.favorite = not all_protected
				_commit(true))
	for id in cards.sale_undo:
		_button(self, "Annuler la vente · " + str(cards.sale_undo[id].family), func(): _commit(cards.undo_sale(id)))


func _show_details(title: String, text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(mini(720, int(get_viewport_rect().size.x) - 60), 360))


func _render_replacement(column: VBoxContainer, cards: CatabaseCards, incoming: String) -> void:
	var replacement := OptionButton.new()
	replacement.name = "CardReplacementTarget"
	replacement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replacement.add_item("Ajouter 1 sans remplacer")
	var options: Array[String] = [""]
	var families := {}
	for id in cards.active:
		var family := str(cards.copy_for(id).family)
		if families.has(family): continue
		families[family] = true
		options.append(id)
		replacement.add_item("Remplacer 1 : " + cards.title_for(id))
		replacement.set_item_tooltip(options.size() - 1, "\n".join(cards.spells_for(id).map(func(spell): return CardText.details(spell, cards.owner().character.unit))))
	replacement.disabled = read_only
	column.add_child(replacement)
	var comparison := _label(column, "")
	var move := _button(column, "Ajouter cette copie", func(): _commit(cards.move_card(incoming, options[replacement.selected])))
	move.name = "ApplyCardReplacement"
	var refresh := func():
		var outgoing := options[replacement.selected]
		var candidate := cards.active.duplicate()
		candidate.erase(outgoing)
		candidate.append(incoming)
		move.disabled = read_only or not cards.valid_deck(candidate)
		move.text = "Remplacer cette copie" if not outgoing.is_empty() else "Ajouter cette copie"
		comparison.text = "%d → %d cartes. " % [cards.active.size(), candidate.size()]
		if outgoing.is_empty(): comparison.text += "Dilue les autres familles du deck."
		else:
			comparison.text += "Sort : " + cards.title_for(outgoing) + "\n"
			for spell in cards.spells_for(outgoing): comparison.text += CardText.effect(spell, cards.owner().character.unit) + "\n"
		if move.disabled and not read_only: comparison.text += "\nLimite de copies ou taille de deck atteinte. Choisissez un remplacement."
	replacement.item_selected.connect(func(_index): refresh.call())
	refresh.call()


func _render_shop(cards: CatabaseCards) -> void:
	var stock := cards.shop()
	if stock.is_empty(): return
	_label(self, "L’ÉTAL DES CARTES · stock unique de cette halte", Color("e6ba62")).add_theme_font_size_override("font_size", 20)
	for index in stock.size():
		var offer: Dictionary = stock[index]
		var family := str(offer.family)
		var spell := cards.family_spell(family)
		var title := "Geste d’arme" if family == CatabaseCards.GESTURE else spell.spell_name
		var price: int = CatabaseCards.BUY[cards.rarity(family)]
		var purchase := _button(self, "%s · %s · %d oboles%s" % [title, CatabaseCards.NAMES[cards.rarity(family)], price, " · acheté" if offer.sold else ""], func(): _commit(cards.buy(index)), offer.sold or cards.owner().gold < price)
		purchase.name = "BuyCard_%d" % index
		purchase.tooltip_text = "Une copie, deux gestes possibles selon votre arme ; jouer l’un consomme la carte." if family == CatabaseCards.GESTURE else spell.description
