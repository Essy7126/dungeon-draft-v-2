extends RefCounted
const Catalog := preload("res://core/expedition/class_card_catalog.gd")
const CardSkin := preload("res://ui/expedition/catabase_card_skin.gd")


static func section(parent: Node, width := 0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", CardSkin.surface())
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box


static func numbers(spell: Spell, actor: Unit) -> String:
	var parts: Array[String] = []
	if spell.get_scaled_damage(actor) > 0:
		parts.append("%d dégâts" % spell.get_scaled_damage(actor))
	if spell.get_scaled_shield(actor) > 0:
		parts.append("%d garde" % spell.get_scaled_shield(actor))
	parts.append(
		"Portée " + preload("res://ui/expedition/catabase_card_text.gd").range_text(spell, actor)
	)
	return " · ".join(parts)


static func rule(spell: Spell) -> String:
	var row := Catalog.row(str(spell.spell_id).trim_prefix("class_"))
	if row.is_empty():
		return "Toujours disponible · hors pioche"
	var rules := {
		"blink": "Traverse les obstacles",
		"root": "−%d PM · prochaine activation" % int(row[8]),
		"disrupt": "−%d PA · prochaine activation" % int(row[8]),
		"lure": "Attire de 2 cases · −1 PA",
		"stasis": "Cible marquée : passe son tour · immunité ensuite",
		"fire_field": "Braises · 2 tours · affecte les deux camps",
		"ice_field": "Dalles gelées · 2 tours · ralentissent à l'entrée",
		"mark": "Marque la cible · 1 tour",
		"marked": "Bonus contre une cible marquée",
		"bleed": "Saignement · 2 tours",
		"burn": "Brûlure · 2 tours",
		"move": "Se déplace sans dépenser de PM",
		"guard": "Garde · %d tour(s)" % spell.shield_duration_activations,
		"push": "Repousse de %d case(s)" % int(row[8]),
		"pull": "Attire de %d case(s)" % int(row[8]),
		"slow": "−1 PM · prochain tour",
		"frost": "−1 PM · prochain tour",
		"ice_area": "Croix · −1 PM",
		"weaken": "Réduit les dégâts de la cible",
		"moved": "Bonus après un déplacement",
		"execute": "Bonus sous 35 % de vie",
		"guarded": "Bonus si vous avez de la garde",
		"wounded": "Bonus après une perte de vie",
		"displaced": "Bonus si la cible a été déplacée",
		"cross": "Croix · plusieurs ennemis",
		"fire": "Feu en croix · plusieurs ennemis",
	}
	return rules.get(row[7], "Dégâts directs · " + str(row[9]))


static func label(parent: Node, value: String, size := 17) -> Label:
	var result := Label.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_override("font", CardSkin.FONT)
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", Color("f4ead6"))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Autowrapped labels have no intrinsic width. In horizontal rows this would
	# collapse them to one character and make the whole results table grow tall.
	if parent is HBoxContainer or parent is HFlowContainer:
		for line in value.split("\n"):
			result.custom_minimum_size.x = maxf(
				result.custom_minimum_size.x,
				ceilf(CardSkin.FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x),
			)
	parent.add_child(result)
	return result


static func icon(parent: Node, texture: Texture2D, extent := 56) -> TextureRect:
	var result := TextureRect.new()
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	result.texture = texture
	result.custom_minimum_size = Vector2(extent, extent)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result


static func item_sale_price(item: ItemDefinition) -> int:
	return 24 if item.rarity == &"rare" else 12


static func item_badge(item: ItemDefinition) -> String:
	if item.category == ItemDefinition.Category.RUNE:
		return "R"
	if str(item.item_id).begins_with("class_gear_"):
		return { "common": "I", "uncommon": "II", "rare": "III" }.get(str(item.rarity), "")
	return ""


static func item_description(item: ItemDefinition) -> String:
	var rarity: String = {
		"common": "Commun",
		"uncommon": "Inhabituel",
		"rare": "Rare",
		"epic": "Épique",
	}.get(str(item.rarity), str(item.rarity))
	var slot := EquipmentLoadout.get_slot_display_name(item.equipment_slot) if item.is_equippable() else "Objet"
	return "%s · %s\n%s\n\nValeur de vente : %d oboles." % [
		slot,
		rarity,
		item.description,
		item_sale_price(item),
	]


static func tooltip(title: String, texture: Texture2D, body: String) -> Control:
	var panel := PanelContainer.new()
	panel.name = "CardTooltip"
	panel.custom_minimum_size.x = 350
	panel.add_theme_stylebox_override("panel", CardSkin.frame(true))
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_theme_constant_override("separation", 12)
	var header := HBoxContainer.new()
	box.add_child(header)
	icon(header, texture, 64)
	var name := label(header, title, 22)
	name.custom_minimum_size.x = 240
	var description := label(box, body, 17)
	description.custom_minimum_size.x = 310
	description.size.x = 310
	return panel
