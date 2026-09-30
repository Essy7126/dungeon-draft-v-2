extends VBoxContainer
## One draft and one atomic allocation; the existing dossier owns saving.
const Rules := preload("res://core/expedition/consumable_progression_v1.gd")
const Integration := preload("res://core/expedition/consumable_cards_integration.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")
const Words := preload("res://ui/expedition/card_player_language.gd")
const Symbols := preload("res://ui/expedition/player_stat_symbols.gd")
const D := preload("res://ui/expedition/player_dossier_skin.gd")
signal committed(success: bool)
var session
var read_only := false
var masteries: Dictionary
var aptitudes: Dictionary
var _values := { }
var _budget: Label
var _preview: Label
var _commit: Button


func _ready() -> void:
	name = "PrototypeV1Progression"
	masteries = session.cards.masteries.duplicate()
	aptitudes = session.cards.aptitudes.duplicate()
	read_only = read_only or not Integration.can_edit_progression(session)
	add_theme_constant_override("separation", 8)
	D.label(self, "Développer mon personnage · niv. %d" % session.cards.level, 24, D.GOLD)
	_budget = D.label(self, "", 18, D.GREEN)
	var tabs := TabContainer.new()
	tabs.name = "ProgressionCategories"
	tabs.add_theme_font_override("font", D.FONT)
	tabs.add_theme_font_size_override("font_size", 17)
	add_child(tabs)
	var elemental := VBoxContainer.new()
	elemental.name = "Éléments"
	elemental.add_theme_constant_override("separation", 6)
	tabs.add_child(elemental)
	D.label(
		elemental,
		"Renforcez les éléments de vos sorts. Le bonus suivant est indiqué avant de dépenser vos points.",
		15,
		D.MUTED,
	)
	for id in Rules.ELEMENTS:
		_allocation(elemental, id, str(Rules.ELEMENT_NAMES[id]), masteries, 26)
	var talents := VBoxContainer.new()
	talents.name = "Aptitudes"
	talents.add_theme_constant_override("separation", 8)
	tabs.add_child(talents)
	D.label(talents, "1 point aux niveaux 3, 6 et 9. Jusqu'à 3 rangs par aptitude.", 15, D.MUTED)
	for id in Rules.APTITUDES:
		_allocation(talents, id, str(Rules.APTITUDE_NAMES[id]), aptitudes, 3)
	D.label(
		talents,
		"Vitalité : PV maximum. Protection : garde créée. Contact : dégâts directs à 1 case. Distance : dégâts directs à 3 cases ou plus.",
		15,
		D.MUTED,
	)
	_preview = D.label(self, "", 16, D.GREEN)
	_commit = Button.new()
	_commit.name = "ApplyPrototypeAllocation"
	_commit.text = "Appliquer cette répartition"
	D.primary_button(_commit)
	add_child(_commit)
	move_child(_commit, _preview.get_index())
	_commit.pressed.connect(
		func():
			committed.emit(Integration.allocate_progression(session, masteries, aptitudes)),
	)
	D.label(self, "Réorientation", 20, D.GOLD)
	D.label(
		self,
		"Répartition libre avant le premier combat. À chaque halte : jusqu'à 2 points élémentaires déplacés en une validation. Réorientation complète : une fois, aux refuges de profondeur 11, 16 ou 19.",
		15,
		D.MUTED,
	)
	var reset := Button.new()
	reset.name = "FullPrototypeReorientation"
	reset.text = (
		"Réorientation complète · disponible"
		if Integration.full_reorientation_available(session)
		else "Réorientation complète · utilisée" if session.cards.full_reorientation_used else "Réorientation complète · refuge requis, niveau 8"
	)
	reset.disabled = read_only or not Integration.full_reorientation_available(session)
	D.button(reset)
	add_child(reset)
	reset.pressed.connect(
		func():
			committed.emit(Integration.full_reorientation(session)),
	)
	_refresh()


func _allocation(parent: Node, id: String, title: String, allocation: Dictionary, cap: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	D.image(row, Symbols.icon(id), 28)
	var label := D.label(row, title, 17, Symbols.color(id))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var input := SpinBox.new()
	input.name = "Allocation_" + id
	input.min_value = 0
	input.max_value = cap
	input.step = 1
	input.value = allocation[id]
	input.editable = not read_only
	input.custom_minimum_size.x = 85
	input.get_line_edit().add_theme_font_override("font", D.FONT)
	input.get_line_edit().add_theme_font_size_override("font_size", 16)
	input.get_line_edit().add_theme_stylebox_override("normal", D.surface(false, 5))
	input.get_line_edit().add_theme_stylebox_override("focus", D.surface(true, 5))
	row.add_child(input)
	_values[id] = D.label(row, "", 14, Symbols.color(id))
	_values[id].custom_minimum_size.x = 145
	input.value_changed.connect(
		func(value):
			allocation[id] = int(value)
			_refresh(),
	)


func _refresh() -> void:
	if _commit == null:
		return
	var cards = session.cards
	var elemental_left := Rules.element_budget(cards.level) - Rules.spent(masteries)
	var aptitude_left := Rules.aptitude_budget(cards.level) - Rules.spent(aptitudes)
	var returned := Rules.refunded(cards.masteries, masteries)
	var initial := Integration.before_first_combat(session)
	var allowed := (
		initial or returned == 0 or (returned <= 2 and Integration.correction_available(session))
	)
	allowed = allowed and (initial or Rules.refunded(cards.aptitudes, aptitudes) == 0)
	_budget.text = "%d point%s élémentaire%s · %d point%s d’aptitude" % [
		elemental_left,
		"s" if elemental_left > 1 else "",
		"s" if elemental_left > 1 else "",
		aptitude_left,
		"s" if aptitude_left > 1 else "",
	]
	if not allowed:
		_budget.text += "\nCette réaffectation nécessite une halte disponible ou une réorientation complète."
	for id in Rules.ELEMENTS:
		_values[id].text = "+%.0f %% · suivant +%.0f %%" % [
			Rules.mastery(masteries[id]) * 100,
			(Rules.mastery(masteries[id] + 1) - Rules.mastery(masteries[id])) * 100,
		]
	for id in Rules.APTITUDES:
		_values[id].text = "+%.0f %%" % (int(aptitudes[id]) * Rules.APTITUDE_GAINS[id] * 100)
	_commit.disabled = (
		read_only or not allowed or elemental_left < 0 or aptitude_left < 0
		or (masteries == cards.masteries and aptitudes == cards.aptitudes)
	)
	var candidate = Integration.Cards.new()
	candidate.prototype_revision = 1
	candidate.level = cards.level
	candidate.primary_class = cards.primary_class
	candidate.masteries = masteries.duplicate()
	candidate.aptitudes = aptitudes.duplicate()
	candidate.equipped = cards.equipped.duplicate()
	var current := Math.stats(
		cards.level,
		cards.attributes,
		Math.equipment_mods(cards.equipped),
		cards,
	)
	var next := Math.stats(cards.level, { }, Math.equipment_mods(cards.equipped), candidate)
	var lines: PackedStringArray = [
		"PV maximum : %d → %d · Puissance : %.0f" % [current.hp, next.hp, next.power]
	]
	var seen := { }
	for copy in cards.copies:
		if seen.has(copy.family):
			continue
		seen[copy.family] = true
		var card := Integration.Catalog.card(copy.family, copy.family in cards.upgraded_ids)
		var component := "damage" if float(card.damage) > 0 else "amount"
		if not card.get("elements", { }).has(component):
			continue
		var kind := (
			"direct"
			if component == "damage"
			else (
				"guard"
				if card.op in ["guard", "counter"]
				else "mark" if card.op == "mark" else "heal" if card.op in ["heal", "renew"] else "periodic"
			)
		)
		var hp_based: bool = component == "amount" and card.op == "renew"
		var before := Math.rounded(
			Math.component(card, component, current.hp if hp_based else current.power, cards, kind)
		)
		var after := Math.rounded(
			Math.component(card, component, next.hp if hp_based else next.power, candidate, kind)
		)
		lines.append(
			"%s · %s : %d → %d"
			% [card.name, "dégâts" if component == "damage" else "effet", before, after]
		)
		if lines.size() >= 5:
			break
	lines.append(
		"Aperçu hors conditions de portée, passifs et défenses. Les PV actuels restent proportionnels."
	)
	_preview.text = "\n".join(lines)
