extends VBoxContainer
## Mounted in the existing inventory, collection and progression windows.
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Integration := preload("res://core/expedition/consumable_cards_integration.gd")
const Economy := preload("res://core/expedition/consumable_card_economy.gd")
const CardSkin := preload("res://ui/expedition/catabase_card_skin.gd")
signal transaction_completed
var mode := "deck"
var read_only := false
var page := 0
var query := ""
var notice := ""
var trade_copies: Array[String] = []


func _ready() -> void:
	_render()


func _text(value: String, size := 16) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	add_child(label)
	return label


func _button(parent: Node, value: String, action: Callable, locked := false) -> Button:
	var button := Button.new()
	button.text = value
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 38
	button.disabled = read_only or locked
	CardSkin.action(button)
	button.pressed.connect(
		func():
			_commit(action.call()),
	)
	parent.add_child(button)
	return button


func _commit(ok: bool) -> void:
	if ok:
		Integration.rebuild(GameManager.expedition, mode == "gear")
		notice = "Enregistré." if GameManager.save_expedition() else "Sauvegarde impossible : réessayez avant de quitter."
	else:
		notice = "Cette action n'est pas disponible."
	transaction_completed.emit()
	_render()


func _render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var session = GameManager.expedition
	if not Integration.enabled(session):
		return
	var cards = session.cards
	read_only = read_only or session.route.phase == "combat"
	if not notice.is_empty():
		_text(notice)
	if mode == "progression":
		_progression(cards)
	elif mode == "gear":
		_gear(cards)
	else:
		_deck(cards)


func _progression(cards) -> void:
	_text("%s · Niveau %d" % [Catalog.class_row(cards.primary_class).name, cards.level], 24)
	_text(Catalog.class_row(cards.primary_class).passive)
	_text(
		"%d point(s) d'attribut · %d amélioration(s) de famille"
		% [cards.attribute_points(), cards.points()]
	)
	for entry in [
		["power", "Puissance", "+5 % de P de base"],
		["vitality", "Vitalité", "+6 % de PV de base"],
		["resolve", "Résolution", "+2 % de résistance physique et +5 % de garde"],
	]:
		_button(
			self,
			"%s : %d · %s" % [entry[1], cards.attributes[entry[0]], entry[2]],
			func():
				return cards.spend_attribute(entry[0]),
			cards.attribute_points() <= 0,
		)
	_text("Spécialisation · niveau 4", 20)
	for id in Catalog.class_row(cards.primary_class).specs:
		_button(
			self,
			("✓ " if cards.specialization == id else "")
			+ str(preload("res://ui/expedition/consumable_cards_presenter.gd").SPECS[id])
			+ " · " + str(Catalog.data().specs[id]),
			func():
				return cards.specialize(id),
			cards.level < 4 or not cards.specialization.is_empty(),
		)
	_text(
		"Les améliorations de famille se choisissent dans Sorts & deck. Elles s'appliquent aux copies actuelles et futures."
	)
	var families := Catalog.pool()
	var choice := OptionButton.new()
	for id in families:
		choice.add_item(str(Catalog.card(id).name))
	add_child(choice)
	_button(
		self,
		"Améliorer cette famille · 1 point",
		func():
			return cards.upgrade_copy(families[choice.selected]),
		cards.points() <= 0,
	)
	var session = GameManager.expedition
	if (Integration.is_market(session) and not cards.upgraded_ids.is_empty()):
		var stock := Economy.market(
			cards,
			session.route.current_node_id,
			int(Integration.encounter(session).index),
		)
		var from := OptionButton.new()
		for id in cards.upgraded_ids:
			from.add_item(str(Catalog.card(id).name))
		add_child(from)
		_button(
			self,
			"Réaffecter cette amélioration vers la famille choisie · 35 oboles",
			func():
				return Economy.transact(cards, session.route.current_node_id, {
					"id": "respec",
					"kind": "respec",
					"from": cards.upgraded_ids[from.selected],
					"family": families[choice.selected],
				}).get("success", false),
			int(stock.respec) <= 0 or cards.gold < 35,
		)


func _gear(cards) -> void:
	_text("Équipement · 6 emplacements · 2 reliques distinctes", 24)
	for slot in ["weapon", "body", "head", "feet", "belt", "amulet"]:
		var equipped := str(cards.equipped.get(slot, ""))
		_text(
			{
				"weapon": "Arme",
				"body": "Armure",
				"head": "Tête",
				"feet": "Pieds",
				"belt": "Ceinture",
				"amulet": "Amulette",
			}[slot],
			20,
		)
		if not equipped.is_empty():
			_button(
				self,
				"Retirer l'objet équipé",
				func():
					cards.equipped.erase(slot)
					return true,
			)
		var seen := { }
		for copy in cards.equipment_copies:
			if seen.has(copy.definition):
				continue
			seen[copy.definition] = true
			for item in Catalog.data().equipment:
				if item.id != copy.definition or item.slot != slot:
					continue
				_button(
					self,
					("✓ " if equipped == item.id else "Équiper · ") + str(item.name) + " · "
					+ preload("res://ui/expedition/consumable_cards_presenter.gd").item_text(item),
					func():
						cards.equipped[slot] = item.id
						return true,
					equipped == item.id,
				)
	_text("Reliques", 20)
	for item in Catalog.data().relics:
		if item.id not in cards.owned_relics:
			continue
		_button(
			self,
			("✓ " if item.id in cards.active_relics else "Activer · ")
			+ str(item.name) + " · " + str(item.rule),
			func():
				if item.id in cards.active_relics:
					cards.active_relics.erase(item.id)
				elif cards.active_relics.size() < 2:
					cards.active_relics.append(str(item.id))
				else:
					return false
				return true,
		)
	if cards.equipment_copies.is_empty() and cards.owned_relics.is_empty():
		_text("Les objets trouvés et achetés apparaîtront ici.")


func _deck(cards) -> void:
	_text(
		"%d copies préparées · %d en réserve · %d consommées"
		% [cards.active.size(), cards.copies.size() - cards.active.size(), cards.consumed.size()],
		22,
	)
	_text(
		"0 à 30 copies préparées, 3 par famille. Main de %d. Chaque copie jouée est consommée définitivement. Les deux secours restent disponibles."
		% cards.hand_capacity
	)
	if mode == "loot":
		_text(
			"%d copie(s) reçue(s) après ce combat. Retrouvez également vos objets dans l'inventaire."
			% cards.last_drops.size()
		)
		var report: Dictionary = cards.battle_results.get(GameManager.expedition.route.current_node_id, {})
		var lost: Array = report.get("enemies", {}).get("forfeited", [])
		if not lost.is_empty(): _text("%d porteur(s) sacrifié(s) : leur butin a été perdu à l'autel." % lost.size())
	var session = GameManager.expedition
	var merchant: bool = Integration.is_market(session)
	if merchant:
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
		add_child(choice)
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
	var search := LineEdit.new()
	search.placeholder_text = "Rechercher une famille"
	search.text = query
	search.text_submitted.connect(
		func(value):
			query = value
			page = 0
			_render(),
	)
	add_child(search)
	var families: Array[String] = []
	for copy in cards.copies:
		if (
			copy.family not in families
			and (query.is_empty()
			or query.to_lower() in str(Catalog.card(copy.family).name).to_lower())
		):
			families.append(str(copy.family))
	if mode == "loot":
		families = families.filter(
			func(id):
				return cards.last_drops.any(
					func(uid):
						return cards.copy_for(uid).get("family") == id,
				),
		)
	page = clampi(page, 0, maxi(0, ceili(families.size() / 8.0) - 1))
	var navigation := HBoxContainer.new()
	add_child(navigation)
	for direction in [-1, 1]:
		var button := Button.new()
		button.text = "←" if direction < 0 else "→"
		button.disabled = page + direction < 0 or (page + direction) * 8 >= families.size()
		button.pressed.connect(
			func():
				page += direction
				_render(),
		)
		navigation.add_child(button)
	var count := Label.new()
	count.text = "Page %d / %d" % [page + 1, maxi(1, ceili(families.size() / 8.0))]
	navigation.add_child(count)
	for id in families.slice(page * 8, page * 8 + 8):
		var spell: Spell = cards.family_spell(id)
		_text(spell.spell_name + " · %d PA" % spell.ap_cost, 20).name = "Family_" + id
		_text(spell.description)
		var row := HFlowContainer.new()
		add_child(row)
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
			row,
			"Préparer (%d / 3)" % prepared.size(),
			func():
				return cards.move_card(str(reserved[0].id)),
			reserved.is_empty() or prepared.size() >= 3 or cards.active.size() >= 30,
		)
		_button(
			row,
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
