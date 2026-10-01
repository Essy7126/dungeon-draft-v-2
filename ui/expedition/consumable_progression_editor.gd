extends VBoxContainer
## One draft and one atomic allocation; the existing dossier owns saving.
const Rules := preload("res://core/expedition/consumable_progression_v1.gd")
const Integration := preload("res://core/expedition/consumable_cards_integration.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")
const Preview := preload("res://ui/expedition/consumable_allocation_preview.gd")
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
var _effects: VBoxContainer
var _reset_confirmation: ConfirmationDialog


func _ready() -> void:
	name = "PrototypeV1Progression"
	masteries = session.cards.masteries.duplicate()
	aptitudes = session.cards.aptitudes.duplicate()
	read_only = read_only or not Integration.can_edit_progression(session)
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_budget = D.label(self, "", 18, D.GREEN)
	var columns := HBoxContainer.new()
	columns.name = "AllocationColumns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	add_child(columns)
	var choices := D.column(columns, 430)
	var preview := D.column(columns, 260)
	var tabs := TabContainer.new()
	tabs.name = "ProgressionCategories"
	tabs.add_theme_font_override("font", D.FONT)
	tabs.add_theme_font_size_override("font_size", 17)
	choices.add_child(tabs)
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
	D.label(preview, "AVANT DE VALIDER", 15, D.GOLD)
	D.label(preview, "Vos changements restent un aperçu jusqu’à la confirmation.", 15, D.MUTED)
	_preview = D.label(preview, "", 16, D.PAPER)
	_effects = VBoxContainer.new()
	_effects.add_theme_constant_override("separation", 8)
	preview.add_child(_effects)
	_commit = Button.new()
	_commit.name = "ApplyPrototypeAllocation"
	_commit.text = "Appliquer cette répartition"
	D.primary_button(_commit)
	add_child(_commit)
	_commit.pressed.connect(
		func():
			committed.emit(Integration.allocate_progression(session, masteries, aptitudes)),
	)
	var reorient := VBoxContainer.new()
	reorient.visible = false
	var reveal := Button.new()
	reveal.name = "ShowReorientation"
	reveal.text = "Réorienter mes points…"
	D.button(reveal)
	preview.add_child(reveal)
	preview.add_child(reorient)
	reveal.pressed.connect(
		func():
			reorient.visible = not reorient.visible,
	)
	D.label(
		reorient,
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
	reorient.add_child(reset)
	reset.pressed.connect(_request_reorientation)
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
	_budget.text = "À répartir : %d point%s élémentaire%s · %d point%s d’aptitude" % [
		elemental_left,
		"s" if elemental_left > 1 else "",
		"s" if elemental_left > 1 else "",
		aptitude_left,
		"s" if aptitude_left > 1 else "",
	]
	_budget.add_theme_color_override(
		"font_color",
		D.LOSS if elemental_left < 0 or aptitude_left < 0 or not allowed else D.GREEN,
	)
	if elemental_left < 0 or aptitude_left < 0:
		_budget.text += "\nPoints insuffisants : réduisez votre sélection avant de valider."
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
	_preview.text = "PV maximum : %d → %d\nPuissance : %.0f" % [current.hp, next.hp, next.power]
	for id in Rules.APTITUDES:
		if int(aptitudes[id]) != int(cards.aptitudes[id]):
			_preview.text += "\n%s : +%.0f %% → +%.0f %%" % [
				Rules.APTITUDE_NAMES[id],
				int(cards.aptitudes[id]) * Rules.APTITUDE_GAINS[id] * 100,
				int(aptitudes[id]) * Rules.APTITUDE_GAINS[id] * 100,
			]
	for child in _effects.get_children():
		_effects.remove_child(child)
		child.queue_free()
	var rows := Preview.rows(cards, candidate)
	D.label(_effects, "EFFETS DANS VOTRE DECK", 14, D.GOLD)
	if rows.is_empty():
		D.label(_effects, "Aucun effet chiffré à comparer dans le deck préparé.", 15, D.MUTED)
	for index in mini(4, rows.size()):
		var row: Dictionary = rows[index]
		var box := D.column(_effects, 0, false)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		box.add_child(line)
		var description := VBoxContainer.new()
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(description)
		D.label(description, row.name, 16, D.PAPER)
		var context: String = " · à %d case%s" % [row.distance, "s" if row.distance > 1 else ""] if row.distance > 0 else ""
		D.label(description, row.caption + context, 14, D.MUTED)
		var delta := D.label(
			line,
			"%d → %d" % [row.before, row.after],
			19,
			D.GAIN if row.after > row.before else D.LOSS if row.changed else D.PAPER,
		)
		delta.autowrap_mode = TextServer.AUTOWRAP_OFF
		delta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if rows.size() > 4:
		D.label(
			_effects,
			"4 exemples sur %d · effets modifiés en premier." % rows.size(),
			14,
			D.MUTED,
		)
	D.label(
		_effects,
		"Valeurs de base, avant les défenses ennemies et les bonus conditionnels. Les PV actuels restent proportionnels.",
		14,
		D.MUTED,
	)


func _request_reorientation() -> void:
	if read_only or not Integration.full_reorientation_available(session):
		return
	if _reset_confirmation == null:
		_reset_confirmation = preload("res://ui/expedition/player_reorientation_confirmation.gd").new()
		_reset_confirmation.name = "ConfirmFullReorientation"
		_reset_confirmation.title = "Réorientation complète"
		_reset_confirmation.theme = D.interface_theme()
		_reset_confirmation.min_size = Vector2i(580, 320)
		_reset_confirmation.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_reset_confirmation.get_label().custom_minimum_size.x = 530
		_reset_confirmation.get_ok_button().text = "Confirmer la réorientation"
		_reset_confirmation.get_cancel_button().text = "Garder ma répartition"
		D.primary_button(_reset_confirmation.get_ok_button())
		D.button(_reset_confirmation.get_cancel_button())
		add_child(_reset_confirmation)
		_reset_confirmation.confirmed.connect(
			func():
				if not read_only:
					committed.emit(Integration.full_reorientation(session)),
		)
	_reset_confirmation.dialog_text = "Points récupérés : %d élémentaires · %d d’aptitude.\n\nVotre spécialisation sera également effacée et devra être choisie à nouveau.\nLe brouillon en cours sera abandonné.\n\nCette réorientation n’est disponible qu’une fois par run.\nElle sera appliquée et enregistrée dès votre confirmation." % [
		Rules.spent(session.cards.masteries),
		Rules.spent(session.cards.aptitudes),
	]
	_reset_confirmation.popup_centered()
	_reset_confirmation.get_cancel_button().grab_focus()
