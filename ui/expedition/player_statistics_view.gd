extends VBoxContainer
## Read-only inspection. Allocation is a separate window owned by ExpeditionScreen.
const D := preload("res://ui/expedition/player_dossier_skin.gd")
const Symbols := preload("res://ui/expedition/player_stat_symbols.gd")
const Preview := preload("res://ui/expedition/consumable_build_preview.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Presenter := preload("res://ui/expedition/consumable_cards_presenter.gd")
const Icons := preload("res://core/expedition/class_icon_catalog.gd")
signal allocation_requested
var session
var read_only := false


func _ready() -> void:
	name = "PlayerStatistics"
	add_theme_constant_override("separation", 12)
	var cards = session.cards
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 12)
	add_child(identity)
	D.image(identity, Icons.icon(cards.primary_class), 48)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(names)
	D.label(names, session.character.unit.unit_name, 22, D.GOLD)
	D.label(
		names,
		"%s · Niveau %d" % [Catalog.class_row(cards.primary_class).name, cards.level],
		15,
	)
	var hp := HBoxContainer.new()
	hp.add_theme_constant_override("separation", 8)
	identity.add_child(hp)
	D.image(hp, Symbols.icon("hp"), 30)
	var life := D.label(
		hp,
		"%d / %d PV" % [session.character.unit.current_hp, session.character.unit.max_hp.get_int()],
		20,
		Symbols.color("hp"),
	)
	life.autowrap_mode = TextServer.AUTOWRAP_OFF
	life.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tabs := TabContainer.new()
	tabs.name = "StatisticsTabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	_summary(_page(tabs, "Résumé"), cards)
	_details(_page(tabs, "Détails"), cards)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	add_child(footer)
	var count := D.label(
		footer,
		"%d point%s disponible%s"
		% [
			cards.attribute_points(),
			"s" if cards.attribute_points() != 1 else "",
			"s" if cards.attribute_points() != 1 else "",
		],
		16,
		D.GOLD,
	)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var allocate := Button.new()
	allocate.name = "OpenStatAllocation"
	allocate.text = "Répartir mes points"
	allocate.disabled = read_only
	allocate.tooltip_text = "Disponible hors combat." if read_only else "Ouvrir la répartition. Aucun point n’est dépensé en consultant cette fiche."
	D.primary_button(allocate)
	footer.add_child(allocate)
	allocate.pressed.connect(
		func():
			allocation_requested.emit(),
	)


func _page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	return content


func _heading(parent: Node, title: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	D.label(row, title, 14, D.GOLD).autowrap_mode = TextServer.AUTOWRAP_OFF
	var line := HSeparator.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)


func _row(parent: Node, id: String, title: String, value: String, hint := "") -> void:
	var row := HBoxContainer.new()
	row.name = "Stat_" + id
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 32
	row.add_theme_constant_override("separation", 8)
	row.tooltip_text = hint
	parent.add_child(row)
	D.image(row, Symbols.icon(id), 23)
	var label := D.label(row, title, 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var number := D.label(row, value, 19, Symbols.color(id))
	number.name = "Value"
	number.autowrap_mode = TextServer.AUTOWRAP_OFF
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _summary(parent: Node, cards) -> void:
	var mods := Math.equipment_mods(cards.equipped)
	var stats := Math.stats(cards.level, cards.attributes, mods, cards)
	D.label(parent, "Valeurs permanentes · équipement inclus", 14, D.MUTED)
	_heading(parent, "COMBAT")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	for entry in [
		["ap", "Points d’action", "PA disponibles à chaque tour."],
		["mp", "Mouvement", "Cases de déplacement disponibles à chaque tour."],
		["power", "Puissance", "Base des dégâts, de la garde et des soins de vos sorts."],
		["hand", "Cartes en main", "Nombre de cartes piochées pour votre main."],
		["physical", "Rés. physique", "Réduction des dégâts physiques. Maximum : 40 %."],
		["magic", "Rés. magique", "Réduction des dégâts magiques. Maximum : 40 %."],
	]:
		_row(grid, entry[0], entry[1], Preview.value(entry[0], stats[entry[0]]), entry[2])
	if cards.prototype_revision == 1:
		_heading(parent, "ÉLÉMENTS")
		D.label(parent, "Bonus aux effets de vos sorts du même élément.", 14, D.MUTED)
		var elements := GridContainer.new()
		elements.columns = 2
		elements.add_theme_constant_override("h_separation", 28)
		parent.add_child(elements)
		for id in Math.Progression.ELEMENTS:
			var total := Math.Progression.mastery(int(cards.masteries[id])) + float(
				mods.get("mastery_" + id, 0)
			)
			_row(elements, id, Math.Progression.ELEMENT_NAMES[id], "+%.0f %%" % (total * 100))


func _table(parent: Node, headers: Array) -> GridContainer:
	var table := GridContainer.new()
	table.columns = headers.size()
	table.add_theme_constant_override("h_separation", 14)
	table.add_theme_constant_override("v_separation", 10)
	parent.add_child(table)
	for index in headers.size():
		_cell(table, headers[index], index == 0, D.MUTED)
	return table


func _cell(table: GridContainer, text: String, first: bool, tint: Color = D.PAPER) -> void:
	var label := D.label(table, text, 15, tint)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if first else HORIZONTAL_ALIGNMENT_RIGHT
	if first:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		label.custom_minimum_size.x = 66


func _details(parent: Node, cards) -> void:
	parent.name = "StatSources"
	D.label(parent, "Origine des valeurs permanentes", 18, D.GOLD)
	var table := _table(
		parent,
		[
			"Statistique",
			"Base",
			"Aptitudes" if cards.prototype_revision == 1 else "Attributs",
			"Équip.",
			"Total",
		],
	)
	for entry in Preview.sources(cards):
		_cell(table, entry.title, true)
		for key in ["base", "attributes", "equipment", "total"]:
			_cell(
				table,
				Preview.value(entry.key, entry[key]),
				false,
				D.GOLD if key == "total" else D.PAPER,
			)
	D.label(
		parent,
		"Valeurs après plafonds : résistances 40 %, mouvement 5 PM, main 7 cartes. Hors effets temporaires du combat.",
		13,
		D.MUTED,
	)
	var mods := Math.equipment_mods(cards.equipped)
	if cards.prototype_revision == 1:
		_heading(parent, "MAÎTRISES ÉLÉMENTAIRES")
		var elements := _table(parent, ["Élément", "Points", "Maîtrise", "Équip.", "Total"])
		for id in Math.Progression.ELEMENTS:
			var trained := Math.Progression.mastery(int(cards.masteries[id])) * 100
			var equipped := float(mods.get("mastery_" + id, 0)) * 100
			_cell(elements, Math.Progression.ELEMENT_NAMES[id], true, Symbols.color(id))
			for value in [
				str(cards.masteries[id]),
				"+%.0f %%" % trained,
				"+%.0f %%" % equipped,
				"+%.0f %%" % (trained + equipped),
			]:
				_cell(elements, value, false)
		_heading(parent, "APTITUDES")
		var effects := {
			"vitality": "PV maximum",
			"protection": "garde créée",
			"contact": "dégâts directs à 1 case",
			"distance": "dégâts directs à 3 cases ou plus",
		}
		for id in Math.Progression.APTITUDES:
			var rank := int(cards.aptitudes[id])
			var effect_label := D.label(
				parent,
				"%s · %d / 3 : +%.0f %% %s"
				% [
					Math.Progression.APTITUDE_NAMES[id],
					rank,
					rank * Math.Progression.APTITUDE_GAINS[id] * 100,
					effects[id],
				],
				15,
			)
			effect_label.name = "Aptitude_" + id
	_heading(parent, "EFFETS DE L’ÉQUIPEMENT")
	if mods.is_empty():
		D.label(parent, "Aucun équipement actif.", 15, D.MUTED)
	for key in mods:
		D.label(parent, Presenter.item_text({ "mods": { key: mods[key] } }), 15)
	D.label(
		parent,
		"Les effets conditionnels s’appliquent uniquement lorsque leur condition est remplie.",
		13,
		D.MUTED,
	)
