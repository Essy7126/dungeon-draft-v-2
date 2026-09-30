extends RefCounted
## Static illustrated showcase for the public classic run only.

const SHEET := preload(
	"res://asset/ui/character_selection/selection_appearances_illustrated_v1.png"
)
const DECOR := preload("res://asset/Background/catabase_character_selection_decor_v1.png")
const HEADING := preload("res://asset/ui/recraft_hud_v1/fonts/cinzel/Cinzel-Variable.ttf")
const GOLD := Color("dfbd77")
const TEXT := Color("e8e2d5")
const MUTED := Color("abaea8")
const EDGE := Color("475755")


static func illustration(id: StringName, portrait: bool = false) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = SHEET
	texture.filter_clip = true
	match id:
		&"achilles_painted_g":
			texture.region = Rect2(710, 20, 245, 240) if portrait else Rect2(618, 0, 534, 941)
		&"achilles_passe_rive":
			texture.region = Rect2(1210, 80, 255, 240) if portrait else Rect2(1152, 0, 519, 941)
		_:
			texture.region = Rect2(175, 20, 245, 240) if portrait else Rect2(0, 0, 618, 941)
	return texture


static func _style(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	return style


static func style_button(button: Button, selected: bool = false) -> void:
	var role: StringName = button.get_meta("classic_presentation", &"button")
	var primary := role == &"primary"
	var quiet := role == &"tab" or role == &"navigation"
	var fill := Color(0.055, 0.085, 0.09, 0.70)
	if primary:
		fill = Color(0.24, 0.20, 0.12, 0.82)
	elif quiet:
		fill = Color.TRANSPARENT
	var edge := GOLD if selected or primary else EDGE
	if quiet:
		edge = Color.TRANSPARENT
	button.add_theme_stylebox_override(
		"normal",
		_style(fill, edge, 2 if selected or primary else 1),
	)
	button.add_theme_stylebox_override("hover", _style(Color(0.13, 0.17, 0.17, 0.8), GOLD))
	button.add_theme_stylebox_override("pressed", _style(fill, edge if quiet else GOLD, 2))
	button.add_theme_stylebox_override(
		"hover_pressed",
		_style(Color(0.13, 0.17, 0.17, 0.8), edge if quiet else GOLD, 2),
	)
	button.add_theme_stylebox_override("disabled", _style(Color(0.06, 0.08, 0.09, 0.6), EDGE))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, GOLD, 2))
	button.add_theme_color_override("font_color", GOLD if selected or primary else TEXT)
	button.add_theme_color_override("font_hover_color", Color("fff0ce"))
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_hover_pressed_color", GOLD)
	button.add_theme_color_override("font_focus_color", GOLD)
	var underline := button.get_node_or_null("ActiveUnderline") as ColorRect
	if underline != null:
		underline.visible = selected


func _button(
	screen: CharacterSelectionScreen,
	parent: Node,
	caption: String,
	rect: Rect2,
	role: StringName = &"button",
) -> Button:
	var button := Button.new()
	parent.add_child(button)
	button.text = caption
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("classic_presentation", role)
	button.add_theme_font_override("font", HEADING)
	button.add_theme_font_size_override("font_size", 24 if role == &"primary" else 18)
	style_button(button)
	return button


func build(screen: CharacterSelectionScreen) -> void:
	screen._canvas = Control.new()
	screen._canvas.name = "SelectionLayout"
	screen._canvas.size = screen.REFERENCE
	screen._canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(screen._canvas)
	var canvas := screen._canvas
	var background := screen._texture(canvas, DECOR, Rect2(0, 0, 1600, 900))
	background.name = "ClassicDecor"
	background.stretch_mode = TextureRect.STRETCH_SCALE
	screen._label(canvas, "C A T A B A S E", Rect2(45, 22, 390, 45), 30, GOLD, HEADING)
	var refuge := _button(screen, canvas, "Sanctuaire", Rect2(1300, 20, 140, 40), &"navigation")
	refuge.name = "Sanctuary"
	refuge.pressed.connect(screen.open_refuge)
	screen._line(canvas, Rect2(1452, 28, 1, 24), EDGE)
	var back := _button(screen, canvas, "Accueil", Rect2(1465, 20, 100, 40), &"navigation")
	back.name = "BackToTitle"
	back.pressed.connect(
		func():
			screen.request_back.call_deferred(),
	)
	for index in screen._entries.size():
		var entry: Dictionary = screen._entries[index]
		var button := _button(screen, canvas, "", Rect2(45, 128 + index * 120, 367, 103), &"roster")
		button.name = "Hero_%d_%s" % [index, entry.id]
		button.toggle_mode = true
		button.tooltip_text = str(entry.display_name)
		button.pressed.connect(screen.select_character.bind(index))
		screen._roster_buttons.append(button)
		screen._texture(button, illustration(entry.id, true), Rect2(10, 2, 103, 99))
		screen._label(button, entry.display_name, Rect2(128, 13, 229, 77), 22, TEXT, HEADING)
	screen._name = screen._label(
		canvas,
		"",
		Rect2(420, 86, 685, 60),
		32,
		TEXT,
		HEADING,
		HORIZONTAL_ALIGNMENT_CENTER,
	)
	screen._hero_art = screen._texture(canvas, null, Rect2(464, 140, 598, 616))
	screen._hero_art.name = "HeroIllustration"
	# Hidden compatibility labels are kept for shared selection updates.
	screen._hero_counter = _hidden_label(screen, canvas)
	screen._role = _hidden_label(screen, canvas)
	screen._chapter = _hidden_label(screen, canvas)
	screen._party_note = _hidden_label(screen, canvas)
	screen._appearance = _hidden_label(screen, canvas)
	screen._orientation = _hidden_label(screen, canvas)
	screen._zoom_label = _hidden_label(screen, canvas)
	screen._preview = screen.PREVIEW.instantiate() as CharacterPreview3D
	canvas.add_child(screen._preview)
	screen._preview.hide()
	_build_folio(screen)
	screen._status = screen._label(canvas, "", Rect2(1140, 701, 380, 48), 16, GOLD)
	screen._status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.start_button = _button(
		screen,
		canvas,
		"INCARNER ACHILLE",
		Rect2(1170, 765, 395, 65),
		&"primary",
	)
	screen.start_button.name = "StartAdventure"
	screen.start_button.pressed.connect(screen._start_adventure)
	screen.show_details(0)


func _hidden_label(screen: CharacterSelectionScreen, parent: Node) -> Label:
	var label := screen._label(parent, "", Rect2(), 14, MUTED)
	label.hide()
	return label


func _build_folio(screen: CharacterSelectionScreen) -> void:
	var card := Panel.new()
	screen._canvas.add_child(card)
	card.name = "CharacterFolio"
	card.position = Vector2(1170, 112)
	card.size = Vector2(395, 586)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel",
		_style(Color(0.025, 0.052, 0.06, 0.80), Color("a78c55")),
	)
	for i in range(2):
		var tab := _button(
			screen,
			card,
			["Caractéristiques", "Histoire"][i],
			Rect2(20 + i * 177, 12, 177, 42),
			&"tab",
		)
		tab.toggle_mode = true
		tab.pressed.connect(screen.show_details.bind(i))
		screen._tab_buttons.append(tab)
		screen._line(tab, Rect2(10, 40, 157, 2), GOLD).name = "ActiveUnderline"
	screen._line(card, Rect2(30, 54, 335, 1), EDGE)
	screen._details = Control.new()
	card.add_child(screen._details)
	screen._details.position = Vector2(30, 72)
	screen._details.size = Vector2(335, 495)
	var details := screen._details
	for i in range(3):
		screen.stats_labels[["hp", "ap", "mp"][i]] = screen._label(
			details,
			"",
			Rect2(i * 112, 8, 110, 45),
			39,
			TEXT,
			HEADING,
			HORIZONTAL_ALIGNMENT_CENTER,
		)
		screen._label(
			details,
			["Vitalité", "PA", "Mouvement"][i],
			Rect2(i * 112, 58, 110, 30),
			17,
			TEXT,
			HEADING,
			HORIZONTAL_ALIGNMENT_CENTER,
		)
		if i > 0:
			screen._line(details, Rect2(i * 112, 15, 1, 67), EDGE)
	screen._line(details, Rect2(0, 112, 335, 1), EDGE)
	screen._label(details, "Initiative", Rect2(25, 131, 90, 30), 17, MUTED)
	screen.stats_labels["initiative"] = screen._label(
		details,
		"",
		Rect2(114, 131, 40, 30),
		18,
		TEXT,
	)
	screen._line(details, Rect2(167, 136, 1, 22), EDGE)
	screen._label(details, "Armure", Rect2(205, 131, 75, 30), 17, MUTED)
	screen.stats_labels["armor"] = screen._label(details, "", Rect2(285, 131, 50, 30), 18, TEXT)
	screen.stats_labels["prowess"] = _hidden_label(screen, details)
	screen.stats_labels["level"] = _hidden_label(screen, details)
	screen._line(details, Rect2(0, 186, 335, 1), EDGE)
	for i in range(4):
		var spell := _button(screen, details, "", Rect2(i * 86, 208, 76, 72))
		spell.name = "Spell_%d" % i
		spell.toggle_mode = true
		spell.pressed.connect(screen.select_spell.bind(i))
		screen._texture(spell, null, Rect2(8, 6, 60, 60)).name = "Icon"
		screen._spell_buttons.append(spell)
	screen._spell_title = screen._label(details, "", Rect2(0, 296, 335, 39), 25, TEXT, HEADING)
	screen._spell_title.clip_text = true
	screen._spell_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	screen._spell_cost = screen._label(details, "", Rect2(0, 335, 335, 28), 17, MUTED)
	screen._spell_scroll = ScrollContainer.new()
	details.add_child(screen._spell_scroll)
	screen._spell_scroll.name = "SpellDescriptionScroll"
	screen._spell_scroll.position = Vector2(0, 370)
	screen._spell_scroll.size = Vector2(335, 67)
	screen._spell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen._spell_description = screen._label(
		screen._spell_scroll,
		"",
		Rect2(0, 0, 319, 60),
		17,
		TEXT,
	)
	screen._spell_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen._spell_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	screen._spell_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen._spell_limit = _hidden_label(screen, details)
	screen._line(details, Rect2(0, 444, 335, 1), EDGE)
	var masteries := _button(screen, details, "Explorer les maîtrises", Rect2(67, 458, 215, 38))
	masteries.name = "ExploreMasteries"
	masteries.pressed.connect(screen.open_spell_tree)
	screen._lore = Control.new()
	card.add_child(screen._lore)
	screen._lore.position = Vector2(30, 72)
	screen._lore.size = Vector2(335, 495)
	screen._lore_body = screen._label(screen._lore, "", Rect2(0, 12, 335, 167), 20, TEXT)
	screen._lore_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen._lore_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	screen._line(screen._lore, Rect2(0, 194, 335, 1), EDGE)
	screen._label(screen._lore, "Voies de progression", Rect2(0, 211, 335, 35), 22, GOLD, HEADING)
	screen._discipline_list = VBoxContainer.new()
	screen._lore.add_child(screen._discipline_list)
	screen._discipline_list.position = Vector2(0, 262)
	screen._discipline_list.size = Vector2(335, 170)
	screen._discipline_list.add_theme_constant_override("separation", 18)
	var lore_masteries := _button(
		screen,
		screen._lore,
		"Explorer les maîtrises",
		Rect2(67, 458, 215, 38),
	)
	lore_masteries.name = "ExploreMasteriesFromLore"
	lore_masteries.pressed.connect(screen.open_spell_tree)
