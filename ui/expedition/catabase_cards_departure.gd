extends VBoxContainer
## One preparation screen: equipment remains outside the ten-card deck.
var session: ExpeditionSession
var commit: Callable
var selection := CatabasePreparationCatalog.preset("marteau")
var difficulty := "normal"
var _scroll: ScrollContainer


func configure(value: ExpeditionSession, action: Callable) -> void:
	session = value
	commit = action
	selection["card_families"] = CatabaseCards.starter_families(selection)
	_render()


func _label(parent: Node, text: String, size := 17) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _choice(parent: Node, title: String, values: Array, names: Array, current: String, action: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(row, title)
	label.custom_minimum_size.x = 165
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var select := OptionButton.new()
	select.name = title.validate_node_name()
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.custom_minimum_size.y = 40
	for text in names: select.add_item(str(text))
	select.select(maxi(0, values.find(current)))
	select.item_selected.connect(func(index): action.call(values[index]))
	row.add_child(select)


func _render() -> void:
	var scroll_position := _scroll.scroll_vertical if is_instance_valid(_scroll) else 0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label(self, "RUN CARTES · Construire mon deck", 27)
	_label(self, "Deux gestes d'arme toujours disponibles. Dix manœuvres, quatre cartes piochées par tour. Les PM et les objets restent hors du deck.")
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.set_deferred("scroll_vertical", scroll_position)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	_choice(body, "Arme", CatabasePreparationCatalog.WEAPONS.keys(), CatabasePreparationCatalog.WEAPONS.values().map(func(row): return row[0]), selection.weapon, func(value):
		selection = CatabasePreparationCatalog.preset(value)
		selection["card_families"] = CatabaseCards.starter_families(selection)
		_render())
	var weapon: Array = CatabasePreparationCatalog.WEAPONS[selection.weapon]
	for id in [weapon[2], weapon[3]]:
		var spell := session.build.catalog.get_spell(str(id))
		_label(body, "Geste fixe · %s — %s" % [spell.spell_name, spell.description], 15)
	_label(body, "MON DECK · 5 familles × 2 copies", 20)
	var names := CatabasePreparationCatalog.TECHNIQUES.map(func(id): return session.build.catalog.get_spell(id).spell_name)
	for index in 5:
		var family: String = selection.card_families[index]
		_choice(body, "Manœuvre %d ×2" % (index + 1), CatabasePreparationCatalog.TECHNIQUES, names, family, func(value):
			selection.card_families[index] = value
			_render())
		_label(body, session.build.catalog.get_spell(family).description, 15)
	_label(body, "ÉQUIPEMENT · hors du deck", 20)
	for key in ["armor", "relic", "supply"]:
		var catalog: Dictionary = {"armor": CatabasePreparationCatalog.ARMORS, "relic": CatabasePreparationCatalog.RELICS, "supply": CatabasePreparationCatalog.SUPPLIES}[key]
		_choice(body, {"armor": "Protection", "relic": "Relique", "supply": "Objet"}[key], catalog.keys(), catalog.values().map(func(row): return row[0]), selection[key], func(value):
			selection[key] = value
			_render())
		_label(body, str(catalog[selection[key]][4 if key == "armor" else 1]), 15)
	_choice(body, "Difficulté", ["normal", "easy"], ["Normal", "Facile"], difficulty, func(value): difficulty = value)
	var valid := CatabasePreparationCatalog.valid(selection)
	var status := Label.new()
	status.name = "CardsDepartureStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Vous pourrez ajouter, remplacer ou améliorer des manœuvres pendant la descente." if valid else "Choisissez cinq familles différentes. Répercussion nécessite l'Urne de bronze."
	add_child(status)
	var start := Button.new()
	start.name = "ConfirmCatabaseDeparture"
	start.text = "Partir avec ce deck · 10 cartes  →"
	start.custom_minimum_size.y = 46
	start.disabled = not valid
	add_child(start)
	start.pressed.connect(func():
		start.disabled = true
		var payload := selection.duplicate(true)
		payload.difficulty_id = difficulty
		var result: Dictionary = commit.call(payload)
		status.text = str(result.get("message", ""))
		if not result.get("success", false): start.disabled = false)
