extends RefCounted
## Read-only faces and explanations for the actual V2 Spell instance.
const Language := preload("res://ui/expedition/card_player_language.gd")
const D := preload("res://ui/expedition/player_dossier_skin.gd")
const Text := preload("res://ui/expedition/catabase_card_text.gd")
const Receipt := preload("res://ui/expedition/consumable_loot_receipt.gd")
const CardModifier := preload("res://core/expedition/consumable_card_modifier.gd")
const Symbols := preload("res://ui/expedition/player_stat_symbols.gd")
const Inventory := preload("res://ui/expedition/consumable_deck_inventory.gd")
const TERMS := {
	"marque": "Marque : renforce le prochain impact direct puis est consommée.",
	"garde": "Garde : absorbe les dégâts avant les PV ; la garde produite expire à votre prochain tour.",
	"brûlure": "Brûlure : dégâts au début des tours de la cible, avant résistance magique.",
	"saignement": "Saignement : dégâts au début des tours de la cible, avant résistance physique.",
	"stase": "Stase : saute la prochain tour et annule l’attaque annoncée. La cible devient ensuite temporairement immunisée.",
}


static func definition(spell: Spell) -> Dictionary:
	for modifier in spell.modifiers:
		if modifier is CardModifier:
			return modifier.card
	return { }


static func face(button: Button, spell: Spell, actor: Unit, cost: int) -> void:
	var row := definition(spell)
	var fallback: bool = row.get("fallback", false)
	var reach_text := "Soi" if spell.is_self_only() else "PO " + Text.range_text(spell, actor)
	D.button(button)
	var rarity_id := str(row.get("rarity", "normal"))
	var accent := Color(Receipt.COLORS.get(rarity_id, "b8c8b5"))
	if not fallback:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := D.surface(state in ["hover", "pressed"], 6)
			style.border_color = accent
			style.border_width_top = 3
			button.add_theme_stylebox_override(state, style)
	# Button children are passive; the full illustration remains a single hit area.
	button.accessibility_name = "%s · %d PA · portée %s" % [
		spell.spell_name,
		cost,
		Text.range_text(spell, actor),
	]
	button.custom_minimum_size.y = 62 if fallback else 190
	var content: BoxContainer = HBoxContainer.new() if fallback else VBoxContainer.new()
	button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 6
	content.offset_right = -6
	content.offset_top = 5
	content.offset_bottom = -5
	content.add_theme_constant_override("separation", 3)
	if fallback:
		D.image(content, spell.icon, 32)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(words)
		var title := D.label(words, str(row.name), 15)
		title.name = "CardTitle"
		title.max_lines_visible = 1
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		D.label(words, "%d PA · %s" % [cost, reach_text], 13, D.GOLD)
	else:
		var badges := HBoxContainer.new()
		content.add_child(badges)
		var price := D.label(badges, "%d PA" % cost, 16, D.GOLD)
		price.autowrap_mode = TextServer.AUTOWRAP_OFF
		var reach := D.label(badges, reach_text, 14, D.PAPER)
		reach.name = "CardRange"
		reach.autowrap_mode = TextServer.AUTOWRAP_OFF
		reach.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reach.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var art := D.image(content, spell.icon, 52)
		art.name = "CardArtwork"
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var title := D.label(content, spell.spell_name, 15)
		title.name = "CardTitle"
		title.custom_minimum_size.y = 36
		title.max_lines_visible = 2
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var affinity := D.label(content, Inventory.affinity(row), 12, D.MUTED)
		affinity.name = "CardAffinity"
		affinity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		affinity.autowrap_mode = TextServer.AUTOWRAP_OFF
		var rarity_name := D.label(content, Receipt.RARITY_NAMES[rarity_id], 12, accent)
		rarity_name.name = "CardRarityName"
		rarity_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		var elements := Symbols.element_strip(content, row, true)
		elements.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var rarity := Color(str(Receipt.COLORS.get(row.get("rarity", "normal"), "b8c8b5")))
		var rule := ColorRect.new()
		rule.name = "CardRarity"
		rule.color = rarity
		rule.custom_minimum_size.y = 2
		content.add_child(rule)
		button.accessibility_name += " · %s · %s · %s" % [
			Inventory.affinity(row),
			Receipt.RARITY_NAMES[rarity_id],
			Language.identity(row),
		]
	D.passive(content)
	content.modulate = Color("b5aaa0") if button.disabled else Color.WHITE


static func hover(panel: PanelContainer, spell: Spell, actor: Unit, context: String) -> void:
	var row := definition(spell)
	var fallback: bool = row.get("fallback", false)
	var improved: bool = (
		not fallback and spell.description.get_slice("\n", 0) == str(row.get("upgradeText", ""))
	)
	panel.custom_minimum_size.x = 480
	panel.add_theme_stylebox_override("panel", D.surface(true, 16))
	var box := VBoxContainer.new()
	box.size = Vector2(448, 0)
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	D.image(header, spell.icon, 48)
	var titles := VBoxContainer.new()
	titles.custom_minimum_size.x = 388
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_fixed_label(titles, spell.spell_name.trim_suffix(" •"), 22, D.PAPER, 388)
	var rarity: String = str(row.get("rarity", "normal"))
	var category := (
		"Toutes classes"
		if row.get("affinity", "shared") == "shared"
		else str(row.affinity).capitalize()
	)
	_fixed_label(
		titles,
		(
			"Secours · hors deck"
			if fallback
			else category + " · " + str(Receipt.RARITY_NAMES.get(rarity, rarity))
			+ (" · Améliorée" if improved else "")
		),
		15,
		D.GOLD,
		388,
	)
	_fixed_label(
		box,
		"%d PA    ·    Portée %s" % [actor.get_spell_ap_cost(spell), Text.range_text(spell, actor)],
		19,
		D.GOLD,
	)
	var targeting := "Sur soi" if spell.can_target_self and spell.spell_range == 0 else "Ligne de vue requise" if spell.needs_line_of_sight else "Sans ligne de vue"
	_fixed_label(box, targeting, 15, D.MUTED)
	_fixed_label(box, Language.identity(row), 15, D.GOLD)
	Symbols.element_strip(box, row)
	var description := Language.effect(
		row,
		actor.attack_power.get_value(),
		CatabaseCards.for_actor(actor),
	)
	var effect := RichTextLabel.new()
	effect.name = "SpellHoverEffects"
	effect.custom_minimum_size.x = 448
	effect.size.x = 448
	effect.fit_content = true
	effect.scroll_active = false
	effect.bbcode_enabled = true
	effect.add_theme_font_override("normal_font", D.FONT)
	effect.add_theme_font_size_override("normal_font_size", 17)
	effect.add_theme_color_override("default_color", D.PAPER)
	var highlighted := description.replace("[", "[lb]")
	# These terms refer to V2 rules, never the legacy class-card glossary.
	for term in TERMS:
		for word in [str(term), str(term).capitalize()]:
			highlighted = highlighted.replace(word, "[color=#dbb98f]" + word + "[/color]")
	effect.text = highlighted
	box.add_child(effect)
	_fixed_label(
		box,
		"Réutilisable · une fois par tour." if fallback else Language.USE_RULE,
		15,
		D.GOLD,
	)
	if not context.is_empty():
		_fixed_label(box, context, 16, Color("f0ba8b"))
	D.passive(panel)


static func _fixed_label(
	parent: Node,
	value: String,
	extent: int,
	tint: Color,
	width := 448,
) -> Label:
	var label := D.label(parent, value, extent, tint)
	label.custom_minimum_size.x = width
	label.size.x = width
	return label
