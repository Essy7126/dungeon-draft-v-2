extends Button
## Miniature physical card in the loot row; the full sheet uses the same art.
const Language := preload("res://ui/expedition/card_player_language.gd")
const Receipt := preload("res://ui/expedition/consumable_loot_receipt.gd")
const CardSkin := preload("res://ui/expedition/catabase_card_skin.gd")
const P := preload("res://ui/expedition/class_card_presentation.gd")
const D := preload("res://ui/expedition/player_dossier_skin.gd")
var record: Dictionary


func configure(value: Dictionary) -> void:
	record = value
	name = "LootReceipt_" + str(record.id)
	var card: bool = record.kind == "card"
	custom_minimum_size = Vector2(58, 82 if card else 58)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var accent := Color(Receipt.COLORS[record.rarity]) if card else Color("d3ba84")
	D.button(self)
	var style := D.surface(false, 4)
	style.border_color = accent
	add_theme_stylebox_override("normal", style)
	accessibility_name = "%s, %s, quantité %d. %s" % [
		record.title,
		record.category,
		record.count,
		record.body,
	]
	var art := TextureRect.new()
	art.texture = record.icon
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 5
	art.offset_right = -5
	art.offset_top = 12 if card else 4
	art.offset_bottom = -17 if card else -4
	if card:
		var rim := Panel.new()
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frame := D.surface(false, 0)
		frame.bg_color = Color.TRANSPARENT
		frame.border_color = accent
		frame.set_border_width_all(2)
		rim.add_theme_stylebox_override("panel", frame)
		add_child(rim)
		move_child(rim, 0)
		rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var cost := _badge("%d PA" % int(record.row.ap), 11, accent)
		cost.position = Vector2(6, 4)
		var footer := _badge(Receipt.RARITY_NAMES[record.rarity], 10, accent)
		footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		footer.offset_top = -18
		footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var quantity := _badge("×%d" % int(record.count), 15, Color("fff1cb"))
	quantity.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	quantity.offset_left = -23
	quantity.offset_top = -6


func _badge(value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", CardSkin.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color("081411"))
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)
	return label


static func detail(value: Dictionary, actor: Unit) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "LootEnlargedCard"
	panel.custom_minimum_size.x = 330
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card: bool = value.kind == "card"
	var accent := Color(Receipt.COLORS[value.rarity]) if card else Color("d3ba84")
	var style := D.surface(false, 18)
	style.border_color = accent
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	panel.add_child(body)
	var title := P.label(body, value.title, 23)
	title.add_theme_color_override("font_color", accent)
	P.label(
		body,
		("CARTE · " + str(Receipt.RARITY_NAMES[value.rarity]) + " · " if card else "")
		+ str(value.category),
		15,
	)
	var art := P.icon(body, value.icon, 90)
	if value.get("upgraded", false):
		var improved := P.label(body, "Sort amélioré · bonus déjà inclus", 14)
		improved.add_theme_color_override("font_color", accent)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if card:
		var row: Dictionary = value.row
		P.label(
			body,
			"%d PA     ·     Portée de base %s"
			% [
				int(row.ap),
				"soi-même" if int(row.max) == 0 else "%d–%d cases" % [int(row.min), int(row.max)],
			],
			18,
		)
		var shapes := {
			"single": "Cible unique",
			"cross": "Croix",
			"radius2": "Zone de rayon 2",
			"line3_perpendicular": "Ligne de 3 cases",
		}
		P.label(
			body,
			"%s · %s" % [shapes.get(row.shape, str(row.shape)), Language.identity(row)],
			15,
		)
	body.add_child(HSeparator.new())
	P.label(body, "EFFETS", 13).add_theme_color_override("font_color", accent)
	var rules := RichTextLabel.new()
	rules.name = "LootEffects"
	rules.bbcode_enabled = true
	rules.fit_content = true
	rules.scroll_active = false
	rules.custom_minimum_size.x = 294
	rules.add_theme_font_override("normal_font", CardSkin.FONT)
	rules.add_theme_font_size_override("normal_font_size", 17)
	var description := (
		Language.effect(value.row, actor.attack_power.get_value())
		if card
		else Language.plain(str(value.body))
	)
	var text := description.replace("[", "[lb]")
	for word in [
		"Marque",
		"marque",
		"Garde",
		"garde",
		"Brûlure",
		"brûlure",
		"Stase",
		"saignement",
		"Parade",
		"parade",
		"Riposte",
		"riposte",
	]:
		text = text.replace(word, "[color=#f0d99c]" + word + "[/color]")
	rules.text = text
	body.add_child(rules)
	if card:
		P.label(body, Language.power_reference(actor.attack_power.get_value()), 14)
		P.label(body, Language.USE_RULE, 14)
	P.label(body, "×%d reçu%s · déjà ajouté%s à votre %s"
	% [
		int(value.count),
		"s" if int(value.count) > 1 else "",
		"s" if int(value.count) > 1 else "",
		"réserve" if card else "inventaire",
	], 14).add_theme_color_override("font_color", Color("9dc9b5"))
	_ignore_mouse(panel)
	return panel


static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if node is Label:
		# Measure wrapping at the final text width, never at the initial zero width.
		node.custom_minimum_size.x = 294
		node.size.x = 294
	for child in node.get_children():
		_ignore_mouse(child)
