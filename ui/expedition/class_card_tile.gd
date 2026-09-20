extends Button
const Presentation := preload("res://ui/expedition/class_card_presentation.gd")
const Ecology := preload("res://core/expedition/card_ecosystem_catalog.gd")


func configure(spell: Spell, actor: Unit, subtitle: String) -> void:
	toggle_mode = true
	custom_minimum_size = Vector2(140, 270)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preload("res://ui/expedition/spell_hover_card.gd").attach(self, spell, actor, null, subtitle)
	accessibility_name = preload("res://ui/expedition/catabase_card_text.gd").details(spell, actor)
	var row := preload("res://core/expedition/class_card_catalog.gd").row(
		str(spell.spell_id).trim_prefix("class_")
	)
	var accent: Color = Ecology.CLASS_COLORS[str(row[1])]
	preload("res://ui/expedition/catabase_card_skin.gd").icon_button(self, accent)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	margin.add_child(box)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	var tier := Ecology.tier(str(row[0]))
	var rarity_stripe := ColorRect.new()
	rarity_stripe.color = Ecology.TIER_COLORS[tier]
	rarity_stripe.custom_minimum_size.y = 3
	rarity_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rarity_stripe)
	Presentation.label(box, "%s · %s" % [preload("res://core/expedition/class_card_catalog.gd").CLASSES[row[1]][0], Ecology.TIER_NAMES[tier]], 12).modulate = Ecology.TIER_COLORS[tier]
	var artwork := Presentation.icon(box, spell.icon, 64)
	artwork.name = "DeckCardArtwork"
	artwork.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Presentation.label(box, spell.spell_name, 16)
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.y = 38
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var badges := HBoxContainer.new()
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(badges)
	Presentation.label(badges, "%d PA" % actor.get_spell_ap_cost(spell), 15).modulate = Color(
		"ffe0a0"
	)
	var reach := Presentation.label(
		badges,
		"PO " + preload("res://ui/expedition/catabase_card_text.gd").range_text(spell, actor),
		14,
	)
	reach.name = "CardRange"
	reach.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reach.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Presentation.label(box, str(row[9]), 13).modulate = Ecology.role_color(str(row[9]))
	var impact := Presentation.label(box, Presentation.numbers(spell, actor) + "\n" + Presentation.rule(spell), 13)
	impact.max_lines_visible = 3
	impact.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
