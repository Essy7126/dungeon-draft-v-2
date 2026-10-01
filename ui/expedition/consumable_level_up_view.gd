extends VBoxContainer
## Celebration and navigation only. Allocation and card editing live in their own windows.
signal allocation_requested
signal cards_requested
signal class_requested
signal continue_requested

const D := preload("res://ui/expedition/player_dossier_skin.gd")
const Symbols := preload("res://ui/expedition/player_stat_symbols.gd")
const Summary := preload("res://ui/expedition/consumable_level_summary.gd")
const Rules := preload("res://core/expedition/consumable_progression_v1.gd")
var session
var read_only := false


class Halo:
	extends Control

	func _draw() -> void:
		var center := size * .5
		var radius := minf(size.x, size.y) * .43
		for i in range(24):
			var direction := Vector2.from_angle(TAU * i / 24.0)
			draw_line(
				center + direction * radius * .78,
				center + direction * radius,
				Color("695039"),
				2,
				true,
			)
		draw_arc(center, radius * .7, 0, TAU, 96, Color("806446"), 1, true)
		draw_circle(center, radius * .64, Color("342a21"))


func _ready() -> void:
	name = "LevelUpCelebration"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	var gains := Summary.read(session.cards, session.advancement_from_level)
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", D.framed_surface(12))
	add_child(banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	banner.add_child(row)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(200, 210)
	row.add_child(stage)
	var halo := Halo.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(halo)
	halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	halo.resized.connect(halo.queue_redraw)
	var portrait := preload("res://ui/characters/CharacterPreview3D.tscn").instantiate()
	stage.add_child(portrait)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.configure(session.character.unit.character_data)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 6)
	row.add_child(words)
	D.label(words, "VOTRE HÉROS PROGRESSE", 14, D.GOLD)
	D.label(words, "NIVEAU %d" % gains.level, 44, D.PAPER).name = "LevelAnnouncement"
	D.label(
		words,
		"%d → %d  ·  %d niveau%s gagné%s"
		% [
			gains.before,
			gains.level,
			gains.gained,
			"x" if gains.gained > 1 else "",
			"s" if gains.gained > 1 else "",
		],
		17,
		D.MUTED,
	)
	var automatic := HBoxContainer.new()
	automatic.add_theme_constant_override("separation", 12)
	words.add_child(automatic)
	Symbols.stat_tile(automatic, "hp", "PV de base", "+%d" % gains.hp)
	Symbols.stat_tile(automatic, "power", "Puissance de base", "+%d" % gains.power)
	D.label(words, "Ces gains sont déjà appliqués à votre personnage.", 13, D.MUTED)
	var choices := HBoxContainer.new()
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 12)
	add_child(choices)
	var stats := _choice(choices, Symbols.icon("power"), "Caractéristiques", Symbols.color("power"))
	var point_gains: Array[String] = []
	if gains.elements_gained > 0:
		point_gains.append("+%d points élémentaires" % gains.elements_gained)
	if gains.aptitudes_gained > 0:
		point_gains.append(
			"+%d point%s d'aptitude"
			% [gains.aptitudes_gained, "s" if gains.aptitudes_gained > 1 else ""]
		)
	D.label(
		stats,
		"\n".join(point_gains) if not point_gains.is_empty() else "Vos points en réserve",
		16,
		D.GAIN,
	)
	var available: int = gains.elements_left + gains.aptitudes_left
	D.label(
		stats,
		"%d point%s à répartir au total\nRenforcez vos éléments ou vos défenses."
		% [available, "s" if available != 1 else ""],
		14,
		D.MUTED,
	)
	_action(stats, "Répartir mes points", "OpenStatAllocation", allocation_requested)
	var spells := _choice(
		choices,
		preload("res://assets/catabase/cards_drawn_v1/deck.png"),
		"Cartes & sorts",
		Symbols.color("water"),
	)
	D.label(
		spells,
		(
			"+%d amélioration%s"
			% [gains.training_gained, "s" if gains.training_gained != 1 else ""]
			if gains.training_gained > 0
			else "Votre deck vous attend"
		),
		16,
		D.GAIN if gains.training_gained > 0 else D.PAPER,
	)
	D.label(
		spells,
		(
			"%d amélioration%s disponible%s"
			% [
				gains.training_left,
				"s" if gains.training_left != 1 else "",
				"s" if gains.training_left != 1 else "",
			]
			if gains.training_left > 0
			else "Aucune amélioration à dépenser"
		)
		+ "\nExaminez vos cartes et leurs évolutions.",
		14,
		D.MUTED,
	)
	_action(spells, "Voir mes cartes", "OpenLevelDeck", cards_requested)
	var required: bool = gains.specialization_required
	var class_art := preload("res://core/expedition/class_icon_catalog.gd").icon(
		session.cards.primary_class
	)
	var path := _choice(choices, class_art, "Ma classe", D.GOLD)
	D.label(
		path,
		(
			"Spécialisation débloquée"
			if required
			else (
				"Votre spécialisation"
				if not session.cards.specialization.is_empty()
				else "Prochain choix : niveau %d" % Rules.specialization_level()
			)
		),
		16,
		D.GOLD,
	)
	D.label(
		path,
		"Choisissez votre spécialisation pour poursuivre la run." if required else "Retrouvez les bonus et les choix propres à votre classe.",
		14,
		D.MUTED,
	)
	_action(
		path,
		"Choisir ma spécialisation" if required else "Consulter ma classe",
		"OpenRequiredSpecialization" if required else "OpenLevelClass",
		class_requested,
	)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 20)
	add_child(footer)
	var hint := D.label(
		footer,
		"Vos points restent disponibles.\nVous pourrez les utiliser plus tard.",
		14,
		D.MUTED,
	)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var next := Button.new()
	next.name = "ConsumableProgressionContinue"
	next.text = "Spécialisation à choisir" if required else "Continuer"
	next.custom_minimum_size = Vector2(230, 44)
	next.disabled = required or read_only
	D.primary_button(next)
	footer.add_child(next)
	next.pressed.connect(continue_requested.emit)


func _choice(parent: Node, art: Texture2D, title: String, tint: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := D.surface(false, 12)
	style.border_color = tint.darkened(.45)
	style.border_width_top = 3
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	column.add_child(heading)
	D.image(heading, art, 34)
	var label := D.label(heading, title, 21, tint)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return column


func _action(parent: Node, title: String, id: String, action: Signal) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	var button := Button.new()
	button.name = id
	button.text = title
	button.custom_minimum_size.y = 42
	D.button(button)
	parent.add_child(button)
	button.pressed.connect(action.emit)
