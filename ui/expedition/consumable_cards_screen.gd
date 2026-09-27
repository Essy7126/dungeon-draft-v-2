extends Control
## Profile presentation: commands commit through the checkpoint owner before
## this view can publish units, cards or rewards. No rules live in the widgets.
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Profile := preload("res://core/expedition/consumable_cards_profile.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")
const Spells := preload("res://core/expedition/consumable_card_spells.gd")
const Presenter := preload("res://ui/expedition/consumable_cards_presenter.gd")
const CardSkin := preload("res://ui/expedition/catabase_card_skin.gd")
const Page := preload("res://ui/selection/cards_choice_page.gd")
const UnitView := preload("res://battle/unit_view.gd")
const GOLD := Color("d7bd87")
var run
var selection := Catalog.preset()
var appearance := {"achilles": "passe_rive"}
var _root: VBoxContainer
var _body: VBoxContainer
var _notice: Label
var _detail: Label
var _grid_view: IsoGridView
var _viewport: SubViewport
var _tab := "Préparation"
var _page := 0
var _query := ""
var _filter := "Toutes"
var _inspected := ""
var _selected: Dictionary = {}
var _options: Dictionary = {}
var _sell: Array[String] = []
var _trade_family := "n01"
var _respec_from := ""
var _respec_to := "n01"
var _advancing := false
var _last_message := ""


func _ready() -> void:
	theme = preload("res://ui/expedition/catabase_ui_theme.gd").get_theme()
	var backdrop := ColorRect.new()
	backdrop.color = Color("0b1515")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 10)
	margin.add_child(_root)
	_render()
	_advance.call_deferred()


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _text(parent: Node, text: String, font_size := 17) -> Label:
	var label := Page.text(parent, text, font_size)
	if parent is HBoxContainer: label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _button(parent: Node, title: String, callback: Callable, disabled := false) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(clampf(title.length() * 8 + 20, 36, 250), 36)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = title
	button.disabled = disabled
	CardSkin.icon_button(button, GOLD)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button


func _scroll(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	return content


func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", CardSkin.surface(GOLD, false, 12))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	return content


func _render() -> void:
	_clear(_root)
	_grid_view = null
	_detail = null
	var header := HBoxContainer.new()
	_root.add_child(header)
	var title := _text(header, "CATABASE  /  CARTES V2", 26)
	title.modulate = GOLD
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "Menu principal", _leave)
	_notice = _text(_root, _last_message, 16)
	_notice.modulate = Color("efcc94")
	_notice.visible = not _last_message.is_empty()
	if run != null and run.checkpoint.blocked:
		_text(_root, "L'action a été annulée. Votre dernière sauvegarde reste intacte.")
		_button(_root, "Réessayer la sauvegarde", func():
			if run.checkpoint.retry(): _last_message = "Sauvegarde rétablie. Vous pouvez refaire votre action."
			_render()
			_advance.call_deferred())
		return
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_root.add_child(_body)
	if run == null:
		_setup()
		return
	var cards = run.cards
	var state: Dictionary = run.checkpoint.state
	var hp := int(state.route.get("hero_hp", 110))
	var maximum := int(state.route.get("hero_max_hp", 110))
	if run.battle != null:
		hp = run.battle.hero.current_hp
		maximum = run.battle.hero.max_hp.get_int()
	_text(_body, "%s  ·  Niveau %d  ·  %d / %d PV  ·  %d or  ·  Profondeur %d / 20" % [Catalog.class_row(cards.primary_class).name, cards.level, hp, maximum, cards.gold, int(state.route.get("depth", 0))], 19)
	if state.phase == "combat":
		_combat()
		return
	if state.phase == "complete":
		_result()
		return
	if state.phase == "reward":
		var reward: Dictionary = state.route.get("reward", {})
		_text(_body, "Victoire · +%d XP · +%d or · %d copies dans la réserve · %d objets · %d reliques" % [int(reward.get("xp", 0)), int(reward.get("gold", 0)), reward.get("copies", []).size(), reward.get("equipment", []).size(), reward.get("relics", []).size()], 18)
	var nav := HBoxContainer.new()
	_body.add_child(nav)
	for tab in ["Préparation", "Progression", "Équipement", "Parcours"]:
		_button(nav, tab, func(): _tab = tab; _render()).button_pressed = _tab == tab
	if not str(state.route.get("merchant", "")).is_empty() and state.phase == "halt":
		_button(nav, "Marchand", func(): _tab = "Marchand"; _render())
	elif _tab == "Marchand": _tab = "Préparation"
	match _tab:
		"Préparation": _inventory()
		"Progression": _progression()
		"Équipement": _equipment()
		"Marchand": _market()
		"Parcours": _route()
	var footer := HBoxContainer.new()
	_body.add_child(footer)
	_button(footer, "Abandonner", _ask_abandon)
	var next := _button(footer, "Franchir le seuil" if state.phase == "preparation" else _next_destination(), func(): _act({"kind": "depart" if run.checkpoint.state.phase == "preparation" else "continue"}))
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _setup() -> void:
	_text(_body, "QUINZE CARTES POUR ENTRER. CHAQUE COPIE JOUÉE DISPARAÎT.", 22).modulate = GOLD
	_text(_body, "4 PA · 3 PM · main complétée à 5 · une utilisation par famille et par tour. Attaque et garde de secours restent disponibles sans carte.")
	var choices := HBoxContainer.new()
	_body.add_child(choices)
	for row in Catalog.data().classes:
		var box := _panel(choices)
		_button(box, row.name, func(): selection = Catalog.preset(row.id); _render())
		_text(box, row.passive, 15)
		if selection.class_id == row.id: _text(box, "CLASSE CHOISIE", 14).modulate = GOLD
	var identity := HBoxContainer.new()
	_body.add_child(identity)
	_text(identity, "Apparence :")
	for row in [{"name": "Achille", "id": ""}, {"name": "Achille peint", "id": "painted_g"}, {"name": "Passe-rive", "id": "passe_rive"}]:
		_button(identity, row.name + (" ✓" if appearance.get("achilles", "") == row.id else ""), func(): appearance = {} if row.id.is_empty() else {"achilles": row.id}; _render())
	var list := _scroll(_body)
	_text(list, "Personnalisez vos %d / 15 copies · trois maximum par famille" % selection.card_families.size(), 20)
	for family in Catalog.pool(selection.class_id, "normal", true):
		var row := Catalog.card(family)
		var line := HBoxContainer.new()
		list.add_child(line)
		var copies: int = selection.card_families.count(family)
		var text := _text(line, "%s · %d PA · %s" % [row.name, int(row.ap), row.baseText], 16)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(line, "−", func(): selection.card_families.erase(family); _render(), copies == 0)
		_text(line, str(copies), 19)
		_button(line, "+", func(): selection.card_families.append(family); _render(), copies >= 3 or selection.card_families.size() >= 15)
	var footer := HBoxContainer.new()
	_body.add_child(footer)
	_button(footer, "Rétablir la proposition", func(): selection = Catalog.preset(selection.class_id); _render())
	_button(footer, "Préparer cette traversée", _start, not Catalog.valid_departure(selection)).size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _start() -> void:
	# Reference harness only. A test must inject its own isolated model.
	_last_message = "Banc de référence interne. Pour jouer, lancez le mode Cartes depuis le menu principal."
	_render()


func _act(command: Dictionary) -> void:
	if run == null: return
	var result: Dictionary = run.act(command)
	_last_message = "" if result.success else Presenter.reason(str(result.get("reason", "")))
	if result.success:
		_selected.clear()
		_options.clear()
		_sell = _sell.filter(func(uid): return not run.cards.copy_for(uid).is_empty())
	_render()
	_advance.call_deferred()


func _advance() -> void:
	if _advancing or run == null: return
	_advancing = true
	while is_inside_tree() and run != null and run.battle != null and run.battle.phase != "hero" and not run.checkpoint.blocked:
		await get_tree().create_timer(.32).timeout
		if not is_inside_tree(): break
		var result: Dictionary = run.act({"kind": "next_actor"})
		if not result.success:
			_last_message = Presenter.reason(str(result.get("reason", "")))
			_render()
			break
		_render()
	_advancing = false


func _leave() -> void:
	# Every visible action is already saved. Leaving does not reset the checkpoint.
	GameManager.cleanup_run_state()
	get_tree().change_scene_to_file("res://ui/TitreEcran.tscn")


func _ask_abandon() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Terminer cette traversée et conserver son bilan ?"
	add_child(dialog)
	dialog.confirmed.connect(func(): _act({"kind": "abandon"}); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()


func _next_destination() -> String:
	var depth := int(run.checkpoint.state.route.get("depth", 0)) + 1
	for row in Catalog.data().route:
		if int(row.depth) == depth: return "Continuer → Combat %d · %s" % [int(row.index), _map_name(row.map)]
	return "Continuer → Halte · profondeur %d" % depth


func _map_name(id: String) -> String:
	return str({"plain": "Seuil", "pillars": "Piliers", "forge": "Forge", "garden": "Jardin", "convoy": "Convoi", "hourglass": "Sablier", "reservoir": "Réservoirs"}.get(id, id.capitalize()))


func _inventory() -> void:
	var cards = run.cards
	_text(_body, "PRÉPARÉES %d / 30  ·  RÉSERVE %d  ·  CONSOMMÉES %d" % [cards.active.size(), cards.copies.size() - cards.active.size(), cards.consumed.size()], 19).modulate = GOLD
	var controls := HBoxContainer.new()
	_body.add_child(controls)
	var search := LineEdit.new()
	search.placeholder_text = "Rechercher une famille…"
	search.text = _query
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(search)
	_button(controls, "Rechercher", func(): _query = search.text; _page = 0; _render())
	search.text_submitted.connect(func(value): _query = value; _page = 0; _render())
	for filter in ["Toutes", "Préparées", "Réserve", "Suivies"]:
		_button(controls, filter, func(): _filter = filter; _page = 0; _render())
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	_body.add_child(columns)
	var list := _scroll(columns)
	var matches: Array = cards.copies.filter(func(copy):
		return (_query.is_empty() or _query.to_lower() in str(Catalog.card(copy.family).name).to_lower()) and (_filter == "Toutes" or (_filter == "Préparées" and copy.id in cards.active) or (_filter == "Réserve" and copy.id not in cards.active) or (_filter == "Suivies" and copy.family in cards.followed_families)))
	_page = clampi(_page, 0, maxi(0, ceili(matches.size() / 12.0) - 1))
	for copy in matches.slice(_page * 12, (_page + 1) * 12):
		var row := Catalog.card(copy.family)
		var label: String = ("◆ " if copy.id in cards.active else "◇ ") + str(row.name)
		if copy.id in cards.opening: label += " · OUVERTURE"
		if copy.family in cards.upgraded_ids: label += " · AMÉLIORÉE"
		var button := _button(list, label + "  /  " + str(copy.id).right(4), func(): _inspected = copy.id; _render())
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = str(row.baseText)
	var pages := HBoxContainer.new()
	list.add_child(pages)
	_button(pages, "←", func(): _page -= 1; _render(), _page == 0)
	_text(pages, "%d / %d · %d copies" % [_page + 1, maxi(1, ceili(matches.size() / 12.0)), matches.size()])
	_button(pages, "→", func(): _page += 1; _render(), (_page + 1) * 12 >= matches.size())
	var details := _panel(columns)
	details.get_parent().custom_minimum_size.x = 360
	var copy: Dictionary = cards.copy_for(_inspected)
	if copy.is_empty():
		_text(details, "Chaque copie a son propre usage.", 22)
		_text(details, "Choisissez une copie pour la préparer, la réserver ou garantir sa présence en ouverture. Les copies de la réserve ne sont pas piochées.")
		_text(details, "Vous pouvez partir avec zéro copie préparée. Les deux actions de secours restent disponibles.")
		return
	var row := Catalog.card(copy.family)
	_card_detail(details, copy.family)
	_text(details, "Origine : " + str({"initial": "départ", "loot": "butin", "purchase": "marchand", "trade": "troc"}.get(copy.origin, copy.origin)), 14)
	_button(details, "Mettre en réserve" if copy.id in cards.active else "Préparer cette copie", func(): _act({"kind": "prepare", "uid": copy.id}))
	if copy.id in cards.active and row.rarity == "normal":
		_button(details, "Retirer l'ouverture" if copy.id in cards.opening else "Garantir cette copie en ouverture", func(): _act({"kind": "opening", "uid": "" if copy.id in run.cards.opening else copy.id}))
	_button(details, "Ne plus suivre" if copy.family in cards.followed_families else "Suivre cette famille (2 max.)", func(): _act({"kind": "follow", "family": copy.family}))
	if run.checkpoint.state.phase == "halt" and not str(run.checkpoint.state.route.get("merchant", "")).is_empty():
		_button(details, "Retirer du lot marchand" if copy.id in _sell else "Ajouter au lot marchand", func():
			if copy.id in _sell: _sell.erase(copy.id)
			else: _sell.append(copy.id)
			_render())
		_text(details, "%d copies sélectionnées pour vendre ou troquer, dans l'onglet Marchand." % _sell.size(), 15)


func _spell_values(spell: Spell) -> Dictionary:
	if run != null and run.battle != null:
		var battle = run.battle
		return {
			"cost": battle.hero.get_spell_ap_cost(spell),
			"minimum": battle.caster.get_effective_spell_minimum_range(battle.hero, spell),
			"maximum": battle.caster.get_effective_spell_range(battle.hero, spell),
		}
	return {"cost": spell.ap_cost, "minimum": spell.minimum_range, "maximum": spell.spell_range}


func _card_detail(parent: Node, family: String) -> void:
	var improved: bool = run != null and family in run.cards.upgraded_ids
	var spell := Spells.make_spell(family, improved)
	var row := Spells.definition(family, improved)
	_text(parent, spell.spell_name, 23).modulate = GOLD
	var icon := TextureRect.new()
	icon.texture = spell.icon
	icon.custom_minimum_size = Vector2(70, 70)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(icon)
	var values := _spell_values(spell)
	_text(parent, "%d PA · Portée %d–%d · %s" % [values.cost, values.minimum, values.maximum, "Magique" if row.type == "magic" else "Physique"], 16)
	if run == null or run.battle == null:
		_text(parent, "Valeurs de base, avant les bonus d'équipement et de reliques.", 13)
	_text(parent, spell.description, 17)
	if not row.get("fallback", false) and not improved: _text(parent, "Amélioration : " + str(row.get("upgradeText", "")), 15)


func _progression() -> void:
	var list := _scroll(_body)
	var cards = run.cards
	var remaining := floori(float(cards.level) / 2) - int(cards.attributes.power) - int(cards.attributes.vitality) - int(cards.attributes.resolve)
	_text(list, "Attributs : %d point(s) disponible(s)" % remaining, 22)
	for row in [{"id": "power", "name": "Puissance", "effect": "+5 % de prouesse"}, {"id": "vitality", "name": "Vitalité", "effect": "+6 % de PV de base"}, {"id": "resolve", "name": "Résolution", "effect": "+2 % de résistance physique, +5 % de garde"}]:
		_button(list, "%s (%d)  ·  %s" % [row.name, int(cards.attributes[row.id]), row.effect], func(): _act({"kind": "attribute", "id": row.id}), remaining <= 0)
	_text(list, "Spécialisation au niveau 4", 22)
	for id in Catalog.class_row(cards.primary_class).specs:
		_button(list, str(Presenter.SPECS[id]) + (" ✓" if cards.specialization == id else "") + " · " + str(Catalog.data().specs[id]), func(): _act({"kind": "specialization", "id": id}), cards.level < 4 or not cards.specialization.is_empty())
	_text(list, "Familles améliorées : %d / 3 · %d point(s) disponible(s)" % [cards.upgraded_ids.size(), cards.points()], 22)
	_text(list, "Un point aux niveaux 4, 8 et 12. L'amélioration s'applique à toutes les copies présentes et futures de la famille.")
	for row in Catalog.data().cards:
		_button(list, str(row.name) + (" ✓" if row.id in cards.upgraded_ids else "") + " · " + str(row.upgradeText), func(): _act({"kind": "upgrade", "family": row.id}), cards.points() <= 0 or row.id in cards.upgraded_ids)


func _equipment() -> void:
	var list := _scroll(_body)
	var cards = run.cards
	_text(list, "Équipement · six emplacements", 22)
	_text(list, "Changer d'équipement conserve votre proportion de PV. Les objets acquis restent en réserve.")
	for slot in Presenter.SLOTS:
		var id := str(cards.equipped.get(slot, ""))
		_text(list, str(Presenter.SLOTS[slot]) + " : " + ("vide" if id.is_empty() else str(Presenter.item(id).name)), 19).modulate = GOLD
		if not id.is_empty(): _button(list, "Retirer", func(): _act({"kind": "equipment", "slot": slot, "uid": ""}))
		for item in cards.equipment_copies:
			var definition := Presenter.item(item.definition)
			if definition.slot != slot: continue
			_button(list, str(definition.name) + " · " + Presenter.item_text(definition), func(): _act({"kind": "equipment", "slot": slot, "uid": item.id}), id == item.definition)
	_text(list, "Reliques · %d / 2 actives" % cards.active_relics.size(), 22)
	var displayed := {}
	for id in cards.owned_relics:
		if displayed.has(id): continue
		displayed[id] = true
		var row := Presenter.item(id)
		_button(list, ("✓ " if id in cards.active_relics else "◇ ") + str(row.name) + " · " + str(row.rule), func(): _act({"kind": "relic", "id": id}), id not in cards.active_relics and cards.active_relics.size() >= 2)


func _purchase(value: Dictionary) -> void:
	value["id"] = "%s/%d" % [run.checkpoint.state.run_id, int(run.checkpoint.state.action_seq) + 1]
	_act({"kind": "purchase", "purchase": value})


func _family_picker(parent: Node, families: Array, selected: String, callback: Callable) -> void:
	var picker := OptionButton.new()
	parent.add_child(picker)
	for family in families:
		picker.add_item(str(Catalog.card(family).name))
		if family == selected: picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(index): callback.call(str(families[index])))


func _market() -> void:
	var visit := str(run.checkpoint.state.route.get("merchant", ""))
	var stock: Dictionary = run.cards.stocks[visit]
	var list := _scroll(_body)
	_text(list, "Le marchand · achats et butins sont sauvegardés immédiatement", 22)
	_button(list, "Sac de six copies normales · 36 or · %d restant(s)" % stock.bags.size(), func(): _purchase({"kind": "bag"}), stock.bags.is_empty() or run.cards.gold < 36)
	_button(list, "Soin de 30 % des PV maximaux · 25 or", func(): _purchase({"kind": "heal"}), int(stock.heal) == 0 or run.cards.gold < 25)
	_text(list, "Normales à l'unité · un exemplaire de chaque famille", 20)
	for family in stock.singles:
		_button(list, str(Catalog.card(family).name) + " · 8 or", func(): _purchase({"kind": "single", "family": family}), int(stock.singles[family]) == 0 or run.cards.gold < 8)
	_text(list, "Vente et troc · sélectionnez vos copies dans Préparation", 20)
	var value := 0
	for uid in _sell: value += int(Catalog.data().rules.economy.sell[Catalog.card(run.cards.copy_for(uid).family).rarity])
	_button(list, "Vendre %d copies · recevoir %d or" % [_sell.size(), value], func(): _purchase({"kind": "sell", "copies": _sell.duplicate()}), _sell.is_empty())
	var families := Catalog.pool(run.cards.primary_class, "normal", true)
	if _trade_family not in families: _trade_family = families[0]
	_family_picker(list, families, _trade_family, func(id): _trade_family = id)
	_button(list, "Troquer trois normales pour la famille choisie · %d troc(s) restant(s)" % int(stock.trades), func(): _purchase({"kind": "trade", "copies": _sell.duplicate(), "family": _trade_family}), _sell.size() != 3 or int(stock.trades) == 0)
	_text(list, "Équipement et reliques", 20)
	for key in ["equipment", "relics"]:
		for id in stock[key]:
			var row := Presenter.item(id)
			_button(list, "%s · %d or · %s" % [row.name, int(row.price), Presenter.item_text(row)], func(): _purchase({"kind": "equipment" if key == "equipment" else "relic", "item": id}), run.cards.gold < int(row.price))
	if not run.cards.upgraded_ids.is_empty():
		_text(list, "Réattribuer une amélioration · 35 or", 20)
		if _respec_from not in run.cards.upgraded_ids: _respec_from = run.cards.upgraded_ids[0]
		_family_picker(list, run.cards.upgraded_ids, _respec_from, func(id): _respec_from = id)
		_family_picker(list, Catalog.pool(), _respec_to, func(id): _respec_to = id)
		_button(list, "Réattribuer", func(): _purchase({"kind": "respec", "from": _respec_from, "family": _respec_to}), int(stock.respec) == 0 or run.cards.gold < 35)


func _route() -> void:
	var list := _scroll(_body)
	var history: Dictionary = run.checkpoint.state.get("chronicle", {"families": [], "runs": []})
	_text(list, "%d / 48 familles découvertes · aucune puissance conservée entre les traversées" % history.families.size(), 18).modulate = GOLD
	for row in Catalog.data().route:
		var names: Array[String] = []
		for kind in row.roster: names.append(str(Catalog.data().enemyTypes[kind].name))
		_text(list, "Profondeur %02d · Combat %d · %s\n%s%s" % [int(row.depth), int(row.index), _map_name(row.map), ", ".join(names), " → Marchand" if row.shopAfter else " → Refuge" if row.refugeAfter else ""], 18)
	_text(list, "Dernières traversées", 20)
	for row in history.runs: _text(list, "%s · niveau %d · profondeur %d · %s" % [row.class_id, int(row.level), int(row.depth), row.outcome], 16)


func _result() -> void:
	var list := _scroll(_body)
	var outcome := str(run.checkpoint.state.route.get("outcome", ""))
	_text(list, str({"victory": "Pâris est tombé.", "defeat": "La traversée s'arrête ici.", "timeout": "La pression a refermé le passage.", "abandoned": "Traversée abandonnée."}.get(outcome, "Fin de traversée")), 32).modulate = GOLD
	_text(list, "%d copies utilisées · %d copies conservées · %d or\nNiveau %d · %s" % [run.cards.consumed.size(), run.cards.copies.size(), run.cards.gold, run.cards.level, Presenter.SPECS.get(run.cards.specialization, "Sans spécialisation")], 21)
	var last: Dictionary = run.checkpoint.state.route.get("last_combat", {})
	_text(list, "Dernier combat : %d · %d tours.\nLa pression commence au tour 9 et augmente à chaque tour. Les copies non jouées restent disponibles pour la suite." % [int(last.get("encounter", 0)), int(last.get("turns", 0))])
	_button(list, "Préparer une nouvelle traversée", func():
		GameManager.cleanup_run_state()
		run = null
		_last_message = ""
		_render())


func _combat() -> void:
	var battle = run.battle
	var cards = run.cards
	Presenter.apply_visuals(battle, run.checkpoint.state.visual_variant)
	var hero: Unit = battle.hero
	_text(_body, "Combat %d · %s · Tour %d / 24   |   %d PA · %d PM · %d garde · P %.1f" % [int(battle.encounter.index), _map_name(battle.encounter.map), cards.round_index, hero.current_ap, hero.current_mp, hero.current_shield, hero.attack_power.get_value()], 19).modulate = GOLD
	var pressure := Math.pressure(hero.max_hp.get_int(), cards.round_index)
	_text(_body, "Pression en fin de tour : %d PV, ignore la garde." % pressure if pressure > 0 else "Pression à partir du tour 9. Copies jouées définitivement consommées ; main complétée à 5 au début du tour.", 15)
	if cards.round_index >= 8: _text(_body, "Tour suivant : %d PV de pression si le combat continue." % Math.pressure(hero.max_hp.get_int(), cards.round_index + 1), 15)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	_body.add_child(columns)
	var container := SubViewportContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(580, 220)
	container.stretch = true
	columns.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(760, 460)
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)
	_viewport.size_changed.connect(_fit_grid)
	_grid_view = IsoGridView.new()
	_grid_view.name = "ConsumableGrid"
	_grid_view.set_render_options(true, true, false, false)
	_viewport.add_child(_grid_view)
	_grid_view.setup(battle.grid)
	_render_board(battle)
	_grid_view.cell_clicked.connect(_cell_clicked)
	_grid_view.cell_hovered.connect(_cell_hovered)
	container.resized.connect(_fit_grid)
	_fit_grid.call_deferred()
	var actors: Array = [hero]
	actors.append_array(battle.enemies)
	for unit in actors:
		if not unit.is_alive: continue
		var view := UnitView.new()
		_grid_view.add_child(view)
		view.setup(unit, false)
		for bar in [view._hp_bar, view._shield_bar]:
			var background := StyleBoxFlat.new()
			background.bg_color = Color("172423")
			background.set_corner_radius_all(2)
			bar.add_theme_stylebox_override("background", background)
			bar.size = Vector2(48, 4)
		view._hp_bar.position.y = -88
		view._shield_bar.position.y = -94
		view.position = _grid_view.grid_to_local(unit.grid_pos)
		view.z_index = unit.grid_pos.x + unit.grid_pos.y + 1
	var sidebar := _scroll(columns)
	sidebar.get_parent().custom_minimum_size.x = 310
	sidebar.get_parent().size_flags_horizontal = Control.SIZE_FILL
	_text(sidebar, Presenter.room_text(battle), 15)
	_button(sidebar, "Consulter cartes et combattants", _combat_dossier)
	_detail = _text(sidebar, "Sélectionnez une carte puis une cible. Sans carte sélectionnée, cliquez sur une case pour marcher.", 16)
	if battle.phase != "hero":
		_text(sidebar, "Les ennemis agissent…", 23).modulate = GOLD
	else:
		if not cards.pending_choice.is_empty(): _pending(sidebar)
		else:
			if not _selected.is_empty():
				var family := str(_selected.get("family", cards.copy_for(str(_selected.get("uid", ""))).get("family", "")))
				_card_detail(sidebar, family)
				var definition := Spells.definition(family, family in cards.upgraded_ids)
				if definition.get("chooseSacrifice", false):
					_text(sidebar, "Garde à sacrifier :", 15)
					var choice := SpinBox.new()
					choice.min_value = 0
					choice.max_value = floori(minf(hero.current_shield, .8 * hero.attack_power.get_value()))
					choice.value = int(_options.get("sacrifice", 0))
					_options["sacrifice"] = int(choice.value)
					sidebar.add_child(choice)
					choice.value_changed.connect(func(n): _options["sacrifice"] = int(n); _highlight())
				if definition.get("choosePull", false):
					_options["pull"] = int(_options.get("pull", 1))
					for n in [1, 2]: _button(sidebar, "Tirer de %d case(s)%s" % [n, " ✓" if _options.pull == n else ""], func(): _options.pull = n; _render())
				_button(sidebar, "Annuler le ciblage", func(): _selected.clear(); _options.clear(); _render())
			_button(sidebar, "Retour à l'ancre · 1 PM", func(): _act({"kind": "anchor"}), not cards.anchor_available or cards.anchor_used or hero.current_mp < 1)
			_room_buttons(sidebar)
			_button(sidebar, "Terminer le tour", func(): _act({"kind": "end_turn"}))
	var hand := HBoxContainer.new()
	hand.add_theme_constant_override("separation", 6)
	_body.add_child(hand)
	for uid in cards.hand:
		var copy: Dictionary = cards.copy_for(uid)
		_hand_card(hand, copy.family, {"kind": "card", "uid": uid})
	var actions := HBoxContainer.new()
	_body.add_child(actions)
	_text(actions, "%d préparées · %d en pioche · %d en défausse · %d consommées" % [cards.active.size(), cards.draw_pile.size(), cards.discard.size(), cards.consumed.size()], 15).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for family in ["fallback_strike", "fallback_guard"]:
		var spell: Spell = cards.family_spell(family)
		_button(actions, spell.spell_name + " · 1 PA", func(): _selected = {"kind": "fallback", "family": family}; _options.clear(); _render(), battle.phase != "hero" or not cards.can_use_family(family) or hero.current_ap < 1)
	_highlight()


func _hand_card(parent: Node, family: String, command: Dictionary) -> void:
	var spell: Spell = run.cards.family_spell(family)
	var panel := _panel(parent)
	panel.get_parent().custom_minimum_size.x = 112
	var selected: bool = _selected.get("uid", "") == command.uid
	panel.get_parent().add_theme_stylebox_override("panel", CardSkin.surface(GOLD, selected, 6))
	var name_label := _text(panel, spell.spell_name, 15)
	name_label.custom_minimum_size.y = 38
	var accessible: int = run.cards.copies.filter(func(copy): return copy.family == family and copy.id in run.cards.active).size()
	var values := _spell_values(spell)
	_text(panel, "Portée %d–%d · %d copie(s)" % [values.minimum, values.maximum, accessible], 12)
	var icon := TextureRect.new()
	icon.texture = spell.icon
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.tooltip_text = spell.description
	panel.add_child(icon)
	var cost: int = values.cost
	var unavailable: bool = run.battle.phase != "hero" or not run.cards.can_use_family(family) or run.battle.hero.current_ap < cost
	var action := _button(panel, "%d PA · Jouer" % cost, func(): _selected = command.duplicate(true); _options.clear(); _render(), unavailable)
	action.tooltip_text = spell.description


func _combat_dossier() -> AcceptDialog:
	var dialog := AcceptDialog.new()
	dialog.title = "État du combat · consultation"
	dialog.ok_button_text = "Revenir au combat"
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	var list := _scroll(dialog)
	list.get_parent().custom_minimum_size = Vector2(660, 490)
	_text(list, Presenter.unit_text(run.battle.hero), 17)
	for enemy in run.battle.enemies:
		if enemy.is_alive: _text(list, Presenter.unit_text(enemy), 16)
	_text(list, "Copies disponibles", 23).modulate = GOLD
	for family in Catalog.data().cards:
		var counts := {"Main": 0, "Pioche": 0, "Défausse": 0, "Réserve": 0}
		for copy in run.cards.copies:
			if copy.family != family.id: continue
			var zone := "Main" if copy.id in run.cards.hand else "Pioche" if copy.id in run.cards.draw_pile else "Défausse" if copy.id in run.cards.discard else "Réserve"
			counts[zone] += 1
		if counts.values().any(func(n): return n > 0):
			_text(list, "%s · Main %d · Pioche %d · Défausse %d · Réserve %d\n%s" % [family.name, counts.Main, counts.Pioche, counts["Défausse"], counts["Réserve"], run.cards.family_spell(family.id).description], 15)
	_text(list, "Équipement actif", 22).modulate = GOLD
	for id in run.cards.equipped.values(): _text(list, str(Presenter.item(id).name) + " · " + Presenter.item_text(Presenter.item(id)), 15)
	for id in run.cards.active_relics: _text(list, str(Presenter.item(id).name) + " · " + Presenter.item_text(Presenter.item(id)), 15)
	dialog.popup_centered(Vector2i(700, 570))
	return dialog


func _fit_grid() -> void:
	if not is_instance_valid(_grid_view) or not is_instance_valid(_viewport): return
	var available := Vector2(_viewport.size)
	var factor := minf(available.x / 500.0, available.y / 355.0)
	_grid_view.scale = Vector2.ONE * factor
	_grid_view.position = Vector2(available.x * .5, 70 * factor)


func _render_board(battle) -> void:
	var arena := preload("res://core/expedition/consumable_cards_content.gd").arena(str(battle.encounter.map))
	var floor_layer := Node2D.new()
	floor_layer.z_index = -10
	_grid_view.add_child(floor_layer)
	var renderer := ArenaTerrainVisualRenderer.new()
	_grid_view.add_child(renderer)
	renderer.configure(_grid_view, floor_layer)
	renderer.render_plan(ArenaTerrainRenderPlanService.build(arena))
	_grid_view.draw_base_cells = false
	for obstacle in arena.obstacles:
		var wall = preload("res://tools/labs/dynamic_arena/DynamicWall.tscn").instantiate()
		wall.setup(obstacle.cell, 0, ArenaWallRegistry.config_for(obstacle.wall_id))
		wall.position = _grid_view.grid_to_local(obstacle.cell)
		wall.z_index = obstacle.cell.x + obstacle.cell.y + 1
		_grid_view.add_child(wall)
	var danger: Array = battle.danger_cells()
	for enemy in battle.enemies:
		if enemy.is_alive:
			for point in enemy.get_meta("cc2_intent", {}).get("cells", []): danger.append(Vector2i(point[0], point[1]))
	for cell in danger: _board_label(cell, "!", Color("ffc4a0"))
	match str(battle.encounter.map):
		"forge", "hourglass", "convoy": _board_label(Vector2i(0,3), "LEVIER", GOLD)
		"reservoir":
			_board_label(Vector2i(0,3), "◈ %d" % int(battle.room.charges[0]), GOLD)
			_board_label(Vector2i(6,3), "◈ %d" % int(battle.room.charges[1]), GOLD)
	if battle.encounter.map == "convoy": _board_label(Vector2i(3,0), "RELAIS", GOLD)
	for index in 7:
		_board_label(Vector2i(index, 6), str(index), Color("a3b4ac"), Vector2(20,10))
		_board_label(Vector2i(6, index), str(index), Color("a3b4ac"), Vector2(-30,10))


func _board_label(cell: Vector2i, value: String, color: Color, offset := Vector2(-8,-10)) -> void:
	var label := Label.new()
	label.text = value
	label.position = _grid_view.grid_to_local(cell) + offset
	label.z_index = 25
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12 if value.length() > 2 else 17)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("101718"))
	label.add_theme_constant_override("outline_size", 4)
	_grid_view.add_child(label)


func _request_for(cell: Vector2i) -> Dictionary:
	var request := _selected.duplicate(true) if not _selected.is_empty() else {"kind": "move"}
	request["cell"] = [cell.x, cell.y]
	if not _options.is_empty(): request["options"] = _options.duplicate(true)
	return request


func _cell_clicked(cell: Vector2i) -> void:
	if run == null or run.battle == null or run.battle.phase != "hero" or not run.cards.pending_choice.is_empty(): return
	_act(_request_for(cell))


func _cell_hovered(cell: Vector2i) -> void:
	if not is_instance_valid(_detail) or run == null or run.battle == null: return
	var target: Unit = run.battle.grid.get_unit(cell)
	var info := "Case (%d,%d)" % [cell.x, cell.y]
	if target != null:
		info += " · %s\n%d / %d PV · %d garde · %d attaque · portée %d" % [target.unit_name, target.current_hp, target.max_hp.get_int(), target.current_shield, target.attack_power.get_int(), target.maximum_range]
		var states: Dictionary = target.get_meta("cc2_effects", {})
		for key in states: info += "\n%s : %.1f · %d activation(s)" % [key, float(states[key].amount), int(states[key].duration)]
	if run.battle.phase == "hero" and run.cards.pending_choice.is_empty():
		var preview: Dictionary = run.preview(_request_for(cell))
		if preview.success:
			for row in preview.units:
				if int(row.hp_delta) != 0 or int(row.guard_delta) != 0:
					info += "\n→ %s : %+d PV, %+d garde" % [row.name, int(row.hp_delta), int(row.guard_delta)]
			info += "\nAprès l'action : %d PA · %d PM" % [int(preview.ap), int(preview.mp)]
		else: info += "\n" + Presenter.reason(str(preview.get("reason", "")))
	_detail.text = info


func _highlight() -> void:
	if not is_instance_valid(_grid_view) or run.battle == null: return
	var battle = run.battle
	_grid_view.clear_highlights()
	_grid_view.highlight(battle.danger_cells(), Color("c86d5380"))
	# Intent cells are the persisted cells, including across Pâris's phase change.
	for enemy in battle.enemies:
		if not enemy.is_alive: continue
		for value in enemy.get_meta("cc2_intent", {}).get("cells", []):
			_grid_view.highlight([Vector2i(value[0], value[1])], Color("bc62558f"))
	for x in 7:
		for y in 7:
			var cell := Vector2i(x, y)
			var surface: CellSurfaceState = battle.terrain.runtime_service.get_state(cell)
			if surface != null and surface.gameplay_flags.has("cc2_group"):
				var color := Color(str({"water": "388ab166", "ice": "99dbea77", "fire": "ef782b77", "steam": "b6c0bc88"}.get(str(surface.surface_id), "607c7166")))
				_grid_view.highlight([cell], color)
	if battle.phase != "hero" or not run.cards.pending_choice.is_empty(): return
	var cells: Array = []
	if _selected.is_empty():
		for x in 7:
			for y in 7:
				var path: Array = battle.pathfinder.find_path(battle.hero.grid_pos, Vector2i(x, y), battle.hero)
				if path.size() > 1 and path.size() - 1 <= battle.hero.current_mp: cells.append(Vector2i(x, y))
	else:
		var family := str(_selected.get("family", run.cards.copy_for(str(_selected.get("uid", ""))).get("family", "")))
		var spell: Spell = run.cards.family_spell(family)
		# Preparation options are transient targeting state, never committed here.
		run.cards.action_options = _options.duplicate(true)
		for x in 7:
			for y in 7:
				if battle.caster.get_cast_failure_reason(battle.hero, spell, Vector2i(x, y)) == &"": cells.append(Vector2i(x, y))
		run.cards.action_options.clear()
	_grid_view.highlight(cells, Color("67b69a55"))


func _pending(parent: Node) -> void:
	var pending: Dictionary = run.cards.pending_choice
	if pending.kind == "retain":
		_text(parent, "Conserver une copie pour le prochain tour", 20)
		for uid in run.cards.hand:
			_button(parent, str(Catalog.card(run.cards.copy_for(uid).family).name), func(): _act({"kind": "retain", "uid": uid}))
		_button(parent, "Ne rien conserver", func(): _act({"kind": "retain", "uid": ""}))
	elif pending.kind == "relay":
		_text(parent, "Relais · transférer la marque", 20)
		var origin := Vector2i(pending.cell[0], pending.cell[1])
		for enemy in run.battle.enemies:
			if enemy.is_alive and run.battle.grid.manhattan(origin, enemy.grid_pos) <= 2:
				var uid := str(enemy.unit_id)
				_button(parent, enemy.unit_name + " (%d,%d)" % [enemy.grid_pos.x, enemy.grid_pos.y], func(): _act({"kind": "relay", "target": uid}))
		_button(parent, "Ne pas transférer", func(): _act({"kind": "relay", "target": ""}))


func _room_buttons(parent: Node) -> void:
	match str(run.battle.encounter.map):
		"forge":
			for rail in [1, 3, 5]: _button(parent, "Levier → ligne %d · 1 PA" % rail, func(): _act({"kind": "room", "mode": "forge", "value": rail}))
		"hourglass": _button(parent, "Retarder le sablier · 1 PA", func(): _act({"kind": "room", "mode": "delay"}))
		"convoy": _button(parent, "Sceller le relais · 2 PA", func(): _act({"kind": "room", "mode": "seal"}))
		"reservoir":
			for index in 2: _button(parent, "Décharger %s · 1 PA" % ("gauche" if index == 0 else "droite"), func(): _act({"kind": "room", "mode": "discharge", "value": index}))
