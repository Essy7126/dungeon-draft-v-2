extends Control
## Free preparation around the hero. Rules and departure remain catalog-owned.
signal hero_selected(index: int)
signal launch_requested
signal back_requested
signal refuge_requested
const PAGE := preload("res://ui/selection/cards_choice_page.gd")
const PREVIEW := preload("res://ui/characters/CharacterPreview3D.tscn")
const Catalog := preload("res://ui/selection/consumable_departure_catalog.gd")
const CardSkin := preload("res://ui/expedition/catabase_card_skin.gd")
const D := preload("res://ui/expedition/player_dossier_skin.gd")
const Readability := preload("res://ui/selection/departure_readability.gd")
const Language := preload("res://ui/expedition/card_player_language.gd")
const Art := preload("res://ui/selection/classic_selection_presentation.gd")
const Symbols := preload("res://ui/expedition/player_stat_symbols.gd")
const SanctuarySkin := preload("res://ui/selection/cards_sanctuary_skin.gd")
const Socle := preload("res://ui/selection/cards_preparation_socle.gd")
const GOLD := Art.GOLD
const HEADING := Art.HEADING
var selection := Catalog.preset()
var difficulty := "normal"
var hero := 2
var entries: Array[Dictionary] = []
var start_button: Button
var status: Label
var _page: VBoxContainer
var _preview: CharacterPreview3D
var _hero_name: Label
var _hero_art: TextureRect
var _hero_socle: TextureRect
var _panel: Panel
var _main: Control
var _overlay: Control
var _modal := ""
var _origin := ""
var _inspected := ""
var _show_deck_help := false
var _show_scaling := false
var _show_class_details := false
var _drafts: Dictionary = { }
var _summary: VBoxContainer
var _socles: Dictionary = { }
var _portraits: Array[Button] = []
var _main_focus: Dictionary = { }
var _help_overlay: Control
var _help_focus: Dictionary = { }


func configure(value: Array[Dictionary]) -> void:
	entries = value
	hero = mini(2, entries.size() - 1)
	selection.masteries = Symbols.Rules.empty_elements()
	theme = D.interface_theme(preload("res://ui/expedition/catabase_ui_theme.gd").get_theme())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main = Control.new()
	_main.size = Vector2(1440, 810)
	_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_main)
	_image(_main, Art.DECOR, Rect2(0, 0, 1440, 810)).stretch_mode = TextureRect.STRETCH_SCALE
	_label(_main, "C A T A B A S E", Rect2(190, 18, 820, 34), 23, GOLD, true).add_theme_font_override(
		"font",
		HEADING,
	)
	_label(_main, "CARTES", Rect2(190, 52, 820, 25), 17, Art.TEXT, true).add_theme_font_override(
		"font",
		HEADING,
	)
	_fixed_action(_main, "Sanctuaire", "SetupRefuge", Rect2(1140, 27, 155, 44)).pressed.connect(
		func():
			emit_signal.call_deferred("refuge_requested"),
	)
	_fixed_action(_main, "← Retour", "SetupBack", Rect2(1295, 27, 120, 44)).pressed.connect(go_back)
	for index in entries.size():
		var button := _fixed_action(
			_main,
			"",
			"Choice_%d" % index,
			Rect2(34, 162 + index * 92, 78, 82),
		)
		button.set_meta("classic_presentation", &"roster")
		button.toggle_mode = true
		button.tooltip_text = str(entries[index].display_name)
		_image(button, Art.illustration(entries[index].id, true), Rect2(5, 4, 68, 74))
		button.pressed.connect(
			func():
				hero = index
				_update_hero()
				_refresh_summary(),
		)
		_portraits.append(button)
	_hero_name = _label(_main, "", Rect2(190, 83, 820, 40), 37, Art.TEXT, true)
	_hero_name.add_theme_font_override("font", HEADING)
	SanctuarySkin.rule(_main, Rect2(443, 127, 314, 10))
	_hero_socle = _image(_main, SanctuarySkin.platform(), Rect2(306, 623, 614, 137))
	_hero_art = _image(_main, null, Rect2(294, 150, 638, 500))
	_hero_art.name = "CardsHeroIllustration"
	# Compatibility with the shared screen API, with no animated preview loading.
	_preview = PREVIEW.instantiate()
	add_child(_preview)
	_preview.hide()
	var folio := _surface(_main, "CardsDepartureSummary", Rect2(1055, 115, 349, 615))
	folio.add_theme_stylebox_override("panel", SanctuarySkin.frame())
	_summary = VBoxContainer.new()
	_summary.position = Vector2(23, 18)
	_summary.size = Vector2(303, 579)
	_summary.add_theme_constant_override("separation", 6)
	folio.add_child(_summary)
	for index in 4:
		var key: String = ["class", "deck", "elements", "difficulty"][index]
		var button := _fixed_action(
			_main,
			"",
			"Socle_" + key,
			Rect2(166 + index * 218, [544, 560, 556, 546][index], 218, 184),
		)
		var object := Socle.new()
		object.kind = key
		object.name = "Object"
		object.size = Vector2(218, 153)
		button.add_child(object)
		var state := _label(button, "", Rect2(0, 153, 218, 27), 18, Art.TEXT, true)
		state.name = "ChoiceState"
		state.add_theme_font_override("font", HEADING)
		button.pressed.connect(open_window.bind(key))
		_socles[key] = button
	status = _label(_main, "", Rect2(1055, 739, 349, 65), 16, GOLD)
	status.name = "CardsSetupStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = _fixed_action(
		_main,
		"FRANCHIR LE SEUIL",
		"StartAdventure",
		Rect2(385, 752, 430, 55),
		true,
	)
	SanctuarySkin.primary(start_button)
	start_button.pressed.connect(
		func():
			if _modal.is_empty() and Catalog.valid_departure(payload()):
				emit_signal.call_deferred("launch_requested"),
	)
	_overlay = Control.new()
	_overlay.name = "PreparationOverlay"
	_overlay.size = Vector2(1440, 810)
	add_child(_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.015, 0.02, .58)
	shade.size = _overlay.size
	_overlay.add_child(shade)
	_panel = Panel.new()
	_panel.name = "PreparationWindow"
	_panel.add_theme_stylebox_override("panel", _window_style())
	_overlay.add_child(_panel)
	var header := HBoxContainer.new()
	header.name = "WindowHeader"
	_panel.add_child(header)
	var title := PAGE.text(header, "", 26)
	title.name = "WindowTitle"
	title.add_theme_font_override("font", HEADING)
	title.modulate = Art.TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action(header, "×", "ClosePreparation").pressed.connect(close_window)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 12)
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.clip_contents = true
	_panel.add_child(_page)
	SanctuarySkin.rule(_panel, Rect2(30, 63, 980, 6)).name = "WindowRule"
	var footer := HBoxContainer.new()
	footer.name = "WindowFooter"
	_panel.add_child(footer)
	var counter := PAGE.text(footer, "", 18)
	counter.name = "PreparationCounter"
	counter.modulate = GOLD
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var confirm := _action(footer, "CONFIRMER", "ConfirmPreparation")
	SanctuarySkin.primary(confirm)
	confirm.custom_minimum_size = Vector2(180, 46)
	confirm.pressed.connect(close_window)
	_panel.resized.connect(_layout_window)
	_overlay.hide()
	_update_hero()
	_refresh_summary()
	_restore_focus.call_deferred("Choice_%d" % hero)


func payload() -> Dictionary:
	var result := selection.duplicate(true)
	result.difficulty_id = difficulty
	result.deck_selected = true
	return result


func _update_hero() -> void:
	_hero_name.text = str(entries[hero].display_name).to_upper()
	_hero_art.texture = Art.illustration(entries[hero].id)
	for index in _portraits.size():
		_portraits[index].set_pressed_no_signal(index == hero)
		Art.style_button(_portraits[index], index == hero)
	hero_selected.emit(hero)


func _accent() -> Color:
	return Catalog.Ecology.CLASS_COLORS[selection.class_id].lightened(.25)


func _refresh_summary() -> void:
	_clear(_summary)
	if not selection.has("masteries"):
		selection.masteries = Symbols.Rules.empty_elements()
	PAGE.text(_summary, "VOTRE TRAVERSÉE", 20).add_theme_font_override("font", HEADING)
	var identity := HBoxContainer.new()
	_summary.add_child(identity)
	_art(identity, Catalog.icon(selection.class_id), 42)
	var class_title := PAGE.text(identity, Catalog.CLASSES[selection.class_id][0] + " · Niv. 1", 23)
	class_title.modulate = GOLD
	class_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_heading("BONUS DE CLASSE")
	var bonus := PAGE.text(_summary, Language.PASSIVES[selection.class_id].split(". ")[0] + ".", 17)
	bonus.tooltip_text = Language.PASSIVES[selection.class_id]
	_summary_heading("CARACTÉRISTIQUES INITIALES")
	PAGE.text(_summary, Readability.stats_text(), 18)
	_summary_heading("DECK PRÉPARÉ")
	PAGE.text(_summary, Readability.deck_text(selection.card_families), 17)
	var common := 0
	for id in selection.card_families:
		if Catalog.Rules.card(id).affinity == "shared":
			common += 1
	PAGE.text(
		_summary,
		"%d communes · %d de classe · 5 en main" % [common, selection.card_families.size() - common],
		16,
	)
	_summary_heading("MAÎTRISES ÉLÉMENTAIRES")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 5)
	_summary.add_child(grid)
	for id in Symbols.Rules.ELEMENTS:
		var row := HBoxContainer.new()
		grid.add_child(row)
		_art(row, Symbols.icon(id), 23).tooltip_text = Symbols.Rules.ELEMENT_NAMES[id]
		var amount := PAGE.text(row, "+%d %%" % roundi(100 * Symbols.Rules.mastery(
					selection.masteries[id]
				)), 16)
		amount.modulate = Symbols.color(id)
		amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	var remaining := 4 - Symbols.Rules.spent(selection.masteries)
	PAGE.text(_summary, "%d point(s) disponible(s)" % remaining, 16).modulate = Art.MUTED
	_summary_heading("DIFFICULTÉ")
	PAGE.text(_summary, "Normale" if difficulty == "normal" else "Facile", 18)
	(_socles["class"].get_node("ChoiceState") as Label).text = "Classe · " + Catalog.CLASSES[
		selection.class_id
	][0]
	_socles["class"].get_node("Object").set("class_id", selection.class_id)
	_socles["class"].get_node("Object").queue_redraw()
	(_socles["deck"].get_node("ChoiceState") as Label).text = "Deck · %d / 15" % selection \
			.card_families \
			.size()
	(_socles["elements"].get_node("ChoiceState") as Label).text = "Éléments · %d point(s)" % remaining
	(_socles["difficulty"].get_node("ChoiceState") as Label).text = "Difficulté · " + (
		"Normale" if difficulty == "normal" else "Facile"
	)
	start_button.disabled = not Catalog.valid_departure(payload())
	status.text = "" if not start_button.disabled else "Préparez 15 cartes autorisées, avec au plus 3 exemplaires par sort."


func _summary_heading(caption: String) -> void:
	PAGE.text(_summary, caption, 13).modulate = GOLD


func open_window(key: String) -> void:
	if key not in _socles or not _modal.is_empty():
		return
	_modal = key
	_hero_art.position.x = -64
	_hero_socle.position.x = -52
	_origin = "Socle_" + key
	for control in _main.find_children("*", "Control", true, false):
		if control.focus_mode != Control.FOCUS_NONE:
			_main_focus[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
	_overlay.show()
	_render()
	_restore_focus.call_deferred("ClosePreparation")


func close_window() -> void:
	if _show_deck_help:
		return
	_modal = ""
	_hero_art.position.x = 294
	_hero_socle.position.x = 306
	_overlay.hide()
	_clear(_page)
	for control in _main_focus:
		if is_instance_valid(control):
			control.focus_mode = _main_focus[control]
	_main_focus.clear()
	_refresh_summary()
	_restore_focus.call_deferred(_origin)


func go_back() -> void:
	if _show_deck_help:
		_close_deck_help()
	elif not _modal.is_empty():
		close_window()
	else:
		emit_signal.call_deferred("back_requested")


func _input(event: InputEvent) -> void:
	if not _modal.is_empty() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()


func _render() -> void:
	_refresh_summary()
	if _modal.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var focus_name := str(focused.name) if focused != null and _panel.is_ancestor_of(focused) else "ClosePreparation"
	_clear(_page)
	_panel.size = Vector2.ZERO
	var rect: Rect2 = {
		"class": Rect2(330, 120, 1040, 575),
		"deck": Rect2(370, 136, 1040, 615),
		"elements": Rect2(420, 155, 940, 520),
		"difficulty": Rect2(620, 230, 725, 360),
	}[_modal]
	_panel.position = rect.position
	_panel.size = rect.size
	find_child("WindowTitle", true, false).text = {
		"class": "CHOISIR UNE CLASSE",
		"deck": "COMPOSER LE DECK",
		"elements": "MAÎTRISES ÉLÉMENTAIRES",
		"difficulty": "DIFFICULTÉ",
	}[_modal]
	find_child("PreparationCounter", true, false).text = (
		"%d / 15 cartes"
		% selection \
				.card_families \
				.size()
		if _modal == "deck"
		else "Vos choix sont conservés à la fermeture."
	)
	match _modal:
		"class":
			_render_classes()
		"deck":
			_render_cards()
		"elements":
			_render_initial_masteries(_scroll_body(_page, "ElementsScroll"))
		"difficulty":
			_render_difficulty()
	for button in _page.find_children("*", "Button", true, false):
		D.button(button, button.button_pressed)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for button in _page.find_children("Starter_*", "Button", true, false):
		button.add_theme_stylebox_override("normal", CardSkin.frame(button.button_pressed))
		button.add_theme_stylebox_override("hover", CardSkin.frame(true))
		button.add_theme_stylebox_override("pressed", CardSkin.frame(true))
		button.add_theme_stylebox_override("hover_pressed", CardSkin.frame(true))
	var add_card := find_child("ToggleStarter", true, false) as Button
	if add_card != null:
		SanctuarySkin.primary(add_card)
	_restore_focus.call_deferred(focus_name)
	_trap_focus.call_deferred()
	_layout_window.call_deferred()


func _layout_window() -> void:
	var header := _panel.get_node("WindowHeader") as Control
	header.position = Vector2(22, 16)
	header.size = Vector2(_panel.size.x - 44, 44)
	_page.position = Vector2(22, 76)
	_page.size = Vector2(_panel.size.x - 44, _panel.size.y - 142)
	var footer := _panel.get_node("WindowFooter") as Control
	var divider := _panel.get_node("WindowRule") as Control
	divider.position = Vector2(30, 63)
	divider.size = Vector2(_panel.size.x - 60, 6)
	divider.queue_redraw()
	footer.position = Vector2(22, _panel.size.y - 56)
	footer.size = Vector2(_panel.size.x - 44, 46)


func _trap_focus() -> void:
	var controls: Array[Control] = []
	var scope: Control = _help_overlay if _show_deck_help else _panel
	for control in scope.find_children("*", "Control", true, false):
		if (
			control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE
			and not (control is BaseButton and control.disabled)
		):
			controls.append(control)
	for i in controls.size():
		var previous := controls[posmod(i - 1, controls.size())]
		var next := controls[(i + 1) % controls.size()]
		controls[i].focus_previous = controls[i].get_path_to(previous)
		controls[i].focus_next = controls[i].get_path_to(next)


func _restore_focus(node_name: String) -> void:
	var control := find_child(node_name, true, false) as Control
	if (
		control != null and control.is_visible_in_tree()
		and control.focus_mode != Control.FOCUS_NONE
		and not (control is BaseButton and control.disabled)
	):
		control.grab_focus()
	elif _show_deck_help:
		find_child("CloseDeckHelp", true, false).grab_focus()
	elif not _modal.is_empty():
		find_child("ClosePreparation", true, false).grab_focus()


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _window_style() -> StyleBoxTexture:
	return SanctuarySkin.frame()


func _surface(parent: Node, node_name: String, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	parent.add_child(panel)
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", Art._style(Color("08191ed9"), Color("9e8358")))
	return panel


func _fixed_action(
	parent: Node,
	caption: String,
	node_name: String,
	rect: Rect2,
	primary := false,
) -> Button:
	var button := Button.new()
	parent.add_child(button)
	button.name = node_name
	button.text = caption
	button.position = rect.position
	button.size = rect.size
	button.set_meta("classic_presentation", &"primary" if primary else &"navigation")
	button.add_theme_font_override("font", HEADING)
	button.add_theme_font_size_override("font_size", 24 if primary else 17)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Art.style_button(button)
	return button


func _label(
	parent: Node,
	caption: String,
	rect: Rect2,
	font_size: int,
	color: Color,
	centered := false,
) -> Label:
	var label := Label.new()
	parent.add_child(label)
	label.text = caption
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _image(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	parent.add_child(image)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = texture
	image.position = rect.position
	image.size = rect.size
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return image


func _render_classes() -> void:
	PAGE.text(_page, "Choisir une voie", 27)
	PAGE.text(
		_page,
		"Quatre styles de combat. Composez votre départ avec les cartes normales de votre classe et les cartes communes.",
		16,
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_page.add_child(row)
	for id in Catalog.CLASSES:
		var button := Button.new()
		button.name = "Choice_" + id
		button.text = Catalog.CLASSES[id][0]
		button.icon = Catalog.icon(id)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 26)
		button.custom_minimum_size.y = 60
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_pressed = id == selection.class_id
		CardSkin.icon_button(button, Catalog.Ecology.CLASS_COLORS[id])
		button.pressed.connect(
			func():
				_drafts[selection.class_id] = selection.duplicate(true)
				selection = _drafts.get(id, Catalog.preset(id)).duplicate(true)
				_inspected = ""
				_render(),
		)
		row.add_child(button)
	var body := _scroll_body(_page, "ChoiceImpact")
	PAGE.text(body, Catalog.CLASSES[selection.class_id][0], 32).modulate = _accent()
	PAGE.text(body, Language.CLASSES[selection.class_id][0], 21).modulate = GOLD
	PAGE.text(body, Language.CLASSES[selection.class_id][1], 18)
	var bonus_box := D.column(body, 0, false)
	PAGE.text(bonus_box, "VOTRE BONUS DE CLASSE", 13).modulate = GOLD
	PAGE.text(bonus_box, Language.PASSIVES[selection.class_id], 17)
	var combo_box := D.column(body, 0, false)
	PAGE.text(combo_box, "UNE COMBINAISON À ESSAYER", 13).modulate = GOLD
	PAGE.text(combo_box, Language.CLASSES[selection.class_id][2], 17)
	PAGE.text(body, Catalog.CLASSES[selection.class_id][3], 15)
	var advanced := _action(
		body,
		"Spécialisations au niveau 4  " + ("−" if _show_class_details else "+"),
		"ClassDetailsToggle",
	)
	advanced.pressed.connect(
		func():
			_show_class_details = not _show_class_details
			_render(),
	)
	if _show_class_details:
		for spec in Catalog.specs(selection.class_id):
			var spec_box := D.column(body, 0, false)
			PAGE.text(spec_box, spec[1], 18).modulate = GOLD
			PAGE.text(spec_box, Language.SPECIALIZATIONS[spec[0]], 16)
		PAGE.text(
			body,
			"Améliorez un sort aux niveaux 4, 8 et 12 : toutes ses cartes en bénéficient.",
			15,
		)


func _scroll_body(parent: Control, node_name := "Details") -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	return body


func _render_cards() -> void:
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	_page.add_child(columns)
	var hint := HBoxContainer.new()
	_page.add_child(hint)
	var rule := PAGE.text(
		hint,
		"15 cartes · 3 exemplaires par sort. Une carte jouée est consommée pour la traversée.",
		14,
	)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action(hint, "Aide", "DeckHelpToggle").pressed.connect(_open_deck_help)
	var scroll := ScrollContainer.new()
	scroll.name = "StarterCatalogue"
	scroll.custom_minimum_size.x = 566
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	columns.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var pool := Catalog.starter_pool(selection.class_id)
	if _inspected not in pool:
		_inspected = pool[0]
	var ordered: Array[String] = []
	for affinity in [selection.class_id, "shared"]:
		for id in pool:
			if Catalog.Rules.card(id).affinity == affinity:
				ordered.append(id)
	for id in ordered:
		var row := Catalog.Rules.card(id)
		var spell := Catalog.make_spell(id)
		var button := Button.new()
		button.name = "Starter_" + id
		button.custom_minimum_size = Vector2(176, 200)
		button.toggle_mode = true
		button.button_pressed = _inspected == id
		button.tooltip_text = spell.spell_name + "\n" + Readability.category(id) + "\n" + Language.effect(
			row,
			float(Readability.Math.Progression.POWER[0]),
			_preview_cards(),
		)
		grid.add_child(button)
		_image(button, spell.icon, Rect2(17, 26, 142, 96))
		var medallion := Panel.new()
		medallion.position = Vector2(8, 7)
		medallion.size = Vector2(32, 32)
		medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var metal := Art._style(Color("dfbd77"), Color("765933"), 2)
		metal.set_corner_radius_all(16)
		medallion.add_theme_stylebox_override("panel", metal)
		button.add_child(medallion)
		_label(medallion, str(spell.ap_cost), Rect2(0, 0, 32, 32), 23, Color("1a201d"), true).add_theme_font_override(
			"font",
			HEADING,
		)
		_label(button, "◆", Rect2(142, 8, 24, 24), 17, GOLD, true)
		var title := _label(button, spell.spell_name, Rect2(12, 124, 152, 37), 16, Art.TEXT, true)
		title.add_theme_font_override("font", HEADING)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label(button, _range(spell), Rect2(8, 161, 160, 18), 12, GOLD, true)
		_label(
			button,
			"%d / 3" % selection.card_families.count(id),
			Rect2(8, 179, 83, 21),
			17,
			Art.TEXT,
			true,
		).add_theme_font_override("font", HEADING)
		_label(
			button,
			"Commune" if row.affinity == "shared" else "Classe",
			Rect2(89, 181, 80, 18),
			12,
			Art.MUTED,
			true,
		)
		button.pressed.connect(
			func():
				_inspected = id
				_show_scaling = false
				_render(),
		)
	var inspection := VBoxContainer.new()
	inspection.add_theme_constant_override("separation", 10)
	inspection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(inspection)
	var detail := _scroll_body(inspection, "ChoiceImpact")
	var selected_spell := Catalog.make_spell(_inspected)
	var category := PAGE.text(detail, Readability.category(_inspected), 15)
	category.name = "StarterCategory"
	category.modulate = GOLD
	var heading := HBoxContainer.new()
	detail.add_child(heading)
	_art(heading, selected_spell.icon, 60)
	PAGE.text(heading, selected_spell.spell_name, 24).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PAGE.text(detail, "%d PA · %s" % [selected_spell.ap_cost, _range(selected_spell)], 19)
	var selected_row := Catalog.Rules.card(_inspected)
	Symbols.element_strip(detail, selected_row)
	PAGE.text(detail, Language.identity(selected_row), 15).modulate = GOLD
	PAGE.text(
		detail,
		Language.effect(
			selected_row,
			float(Readability.Math.Progression.POWER[0]),
			_preview_cards(),
		),
		19,
	)
	var scaling := _action(
		detail,
		"Lien avec la Puissance " + ("−" if _show_scaling else "+"),
		"CardScalingToggle",
	)
	scaling.pressed.connect(
		func():
			_show_scaling = not _show_scaling
			_render(),
	)
	if _show_scaling:
		PAGE.text(detail, Language.scaling(selected_row), 16).name = "CardPowerDetails"
	PAGE.text(detail, "Valeurs au départ, avant protections et bonus conditionnels.", 14)
	var add := _action(
		inspection,
		"Ajouter un exemplaire (%d / 3)" % selection.card_families.count(_inspected),
		"ToggleStarter",
	)
	add.disabled = selection.card_families.size() >= 15 or selection.card_families.count(_inspected) >= 3
	add.pressed.connect(
		func():
			if (
				selection.card_families.size() < 15 and selection.card_families.count(_inspected) < 3
				and _inspected in Catalog.starter_pool(selection.class_id)
			):
				selection.card_families.append(_inspected)
			_render(),
	)
	var remove := _action(inspection, "Retirer un exemplaire", "RemoveStarter")
	remove.disabled = _inspected not in selection.card_families
	remove.pressed.connect(
		func():
			selection.card_families.erase(_inspected)
			_render(),
	)
	if selection.card_families.size() >= 15:
		PAGE \
				.text(
			inspection,
			"Deck complet : retirez un exemplaire avant d'en ajouter un autre.",
			15,
		) \
				.modulate = GOLD


func _render_difficulty() -> void:
	var page := PAGE.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(page)
	page.configure(
		"",
		"Choisissez la résistance de votre traversée.",
		[
			{
				"id": "normal",
				"title": "Normale",
				"impact": "Ennemis à leur puissance habituelle. Soin au refuge : 30 %.",
			},
			{
				"id": "easy",
				"title": "Facile",
				"impact": "Ennemis : −10 % PV et −20 % dégâts. Soin au refuge : 40 % au lieu de 30 %.",
			},
		],
		difficulty,
	)
	page.chosen.connect(
		func(id):
			difficulty = id
			_render(),
	)


func _range(spell: Spell) -> String:
	return (
		"sur soi"
		if spell.spell_range == 0
		else "portée %d–%d" % [spell.minimum_range, spell.spell_range]
	)


func _preview_cards():
	var cards = preload("res://core/expedition/consumable_cards_state.gd").new()
	cards.prototype_revision = 1
	cards.primary_class = selection.class_id
	cards.masteries = selection.get("masteries", cards.masteries).duplicate(true)
	return cards


func _render_initial_masteries(parent: Node) -> void:
	var rules = preload("res://core/expedition/consumable_progression_v1.gd")
	if not selection.has("masteries"):
		selection.masteries = rules.empty_elements()
	PAGE.text(parent, "4 points de départ · +3 % de maîtrise par point", 21).modulate = GOLD
	var remaining := PAGE.text(
		parent,
		"%d point(s) restant(s)" % (4 - rules.spent(selection.masteries)),
		16,
	)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	parent.add_child(grid)
	for id in rules.ELEMENTS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)
		grid.add_child(row)
		_art(row, Symbols.icon(id), 34)
		var label := PAGE.text(row, str(rules.ELEMENT_NAMES[id]), 18)
		label.modulate = Symbols.color(id)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size.x = 80
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var input := SpinBox.new()
		input.name = "DepartureMastery_" + str(id)
		input.max_value = 4
		input.value = selection.masteries[id]
		input.custom_minimum_size.x = 88
		input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(input)
		input.value_changed.connect(
			func(value):
				var available := 4 - rules.spent(selection.masteries) + int(selection.masteries[id])
				selection.masteries[id] = mini(int(value), available)
				input.set_value_no_signal(selection.masteries[id])
				remaining.text = "%d point(s) restant(s) · +3 %% de maîtrise par point" % (
					4 - rules.spent(selection.masteries)
				)
				_refresh_mastery_preview()
				_refresh_summary(),
		)
	var basic := Catalog.Spells.definition("fallback_strike", false, selection.class_id)
	var label := PAGE.text(
		parent,
		"Attaque permanente : " + str(basic.name) + "\n"
		+ Language.effect(basic, float(rules.POWER[0]), _preview_cards()),
		16,
	)
	label.name = "DepartureBasicAttack"
	PAGE.text(
		parent,
		"Les points non dépensés restent disponibles après le combat. Les éléments renforcent seulement les composantes indiquées sur les sorts.",
		14,
	)


func _refresh_mastery_preview() -> void:
	var cards = _preview_cards()
	var power := float(Readability.Math.Progression.POWER[0])
	var basic := Catalog.Spells.definition("fallback_strike", false, selection.class_id)
	var label := find_child("DepartureBasicAttack", true, false) as Label
	if label != null:
		label.text = "Attaque permanente : " + str(basic.name) + "\n" + Language.effect(
			basic,
			power,
			cards,
		)


func _action(parent: Control, title: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = title
	button.custom_minimum_size = Vector2(38, 40)
	CardSkin.icon_button(button, GOLD)
	parent.add_child(button)
	return button


func _art(parent: Control, texture: Texture2D, side: int) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.custom_minimum_size = Vector2(side, side)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art


func _open_deck_help() -> void:
	if _show_deck_help:
		return
	_show_deck_help = true
	for control in _panel.find_children("*", "Control", true, false):
		if control.focus_mode != Control.FOCUS_NONE:
			_help_focus[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
	_help_overlay = Control.new()
	_help_overlay.name = "DeckHelpDialog"
	_help_overlay.size = Vector2(1440, 810)
	add_child(_help_overlay)
	var shade := ColorRect.new()
	shade.size = _help_overlay.size
	shade.color = Color(0, 0, 0, .3)
	_help_overlay.add_child(shade)
	var panel := _surface(_help_overlay, "DeckHelpPanel", Rect2(470, 135, 750, 540))
	panel.add_theme_stylebox_override("panel", Art._style(Color("10191c"), Color("9e8358")))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_label(panel, "COMPRENDRE VOTRE DECK", Rect2(24, 20, 702, 38), 24, GOLD).add_theme_font_override(
		"font",
		HEADING,
	)
	var body := Control.new()
	body.position = Vector2(24, 75)
	body.size = Vector2(702, 375)
	panel.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var text := PAGE.text(
		scroll,
		Language.DECK_HELP
		+ "\n\nLes cartes non jouées reviennent dans la pioche.\n\nLa classe donne votre bonus et vos cartes de départ. Les cartes communes servent à toutes les classes.\n\nLes rôles indiquent à quoi sert un sort : attaquer, protéger, déplacer ou contrôler. Feu, eau et givre peuvent transformer le terrain.",
		20,
	)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := _fixed_action(
		panel,
		"Compris · revenir au deck",
		"CloseDeckHelp",
		Rect2(185, 470, 380, 46),
		true,
	)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(_close_deck_help)
	close.grab_focus.call_deferred()
	_trap_focus.call_deferred()


func _close_deck_help() -> void:
	_show_deck_help = false
	remove_child(_help_overlay)
	_help_overlay.queue_free()
	for control in _help_focus:
		if is_instance_valid(control):
			control.focus_mode = _help_focus[control]
	_help_focus.clear()
	_restore_focus.call_deferred("DeckHelpToggle")
	_trap_focus.call_deferred()
