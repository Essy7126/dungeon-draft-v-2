extends MarginContainer
## Compose the class-owned deck before the cinematic and threshold.
signal hero_selected(index: int)
signal launch_requested
signal back_requested
const PAGE := preload("res://ui/selection/cards_choice_page.gd")
const PREVIEW := preload("res://ui/characters/CharacterPreview3D.tscn")
const Catalog := preload("res://core/expedition/class_card_catalog.gd")
const Starters := preload("res://core/expedition/class_starter_catalog.gd")
const CardSkin := preload("res://ui/expedition/catabase_card_skin.gd")
const STEPS := ["Apparence", "Classe", "Cartes", "Difficulté", "Départ"]
var selection := Catalog.preset()
var difficulty := "normal"
var step := 0
var reached := 0
var hero := 2
var entries: Array[Dictionary] = []
var start_button: Button
var status: Label
var _nav: VBoxContainer
var _page: VBoxContainer
var _preview: CharacterPreview3D
var _hero_name: Label
var _class_label: Label
var _panel: PanelContainer
var _stage: VBoxContainer
var _inspected := ""
var _drafts: Dictionary = { }


func configure(value: Array[Dictionary]) -> void:
	entries = value
	hero = mini(2, entries.size() - 1)
	theme = preload("res://ui/expedition/catabase_ui_theme.gd").get_theme()
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 20)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	PAGE.text(root, "C A T A B A S E   /   L A   V O I E   D E S   C A R T E S", 14).modulate = Color(
		"d7bd87"
	)
	PAGE.text(root, "Façonnez votre traversée", 32)
	PAGE.text(
		root,
		"Une classe. Votre manière de combattre. Dix cartes choisies avant le premier pas.",
		16,
	)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)
	_nav = VBoxContainer.new()
	_nav.custom_minimum_size.x = 154
	_nav.add_theme_constant_override("separation", 8)
	columns.add_child(_nav)
	var stage := VBoxContainer.new()
	_stage = stage
	stage.custom_minimum_size.x = 205
	columns.add_child(stage)
	_hero_name = PAGE.text(stage, "", 26)
	_class_label = PAGE.text(stage, "", 18)
	var framing := AspectRatioContainer.new()
	framing.ratio = .6
	framing.stretch_mode = AspectRatioContainer.STRETCH_FIT
	framing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(framing)
	_preview = PREVIEW.instantiate()
	_preview.custom_minimum_size = Vector2.ZERO
	framing.add_child(_preview)
	_preview.set_showcase_mode(true)
	PAGE.text(stage, "L'apparence vous représente.\nLa classe définit votre jeu.", 14)
	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_panel)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 10)
	_panel.add_child(_page)
	status = PAGE.text(root, "", 14)
	status.name = "CardsSetupStatus"
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)
	var back := Button.new()
	back.name = "SetupBack"
	back.text = "← Retour"
	back.custom_minimum_size = Vector2(154, 46)
	back.pressed.connect(
		func():
			if step == 0:
				back_requested.emit()
			else:
				step -= 1
				_render(),
	)
	footer.add_child(back)
	start_button = Button.new()
	start_button.name = "StartAdventure"
	start_button.custom_minimum_size.y = 46
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.pressed.connect(
		func():
			if step >= 2 and not Catalog.valid_departure(selection):
				return
			if step == 4:
				launch_requested.emit()
			else:
				step += 1
				reached = maxi(reached, step)
				_render(),
	)
	footer.add_child(start_button)
	_update_hero()
	resized.connect(_resize_stage)
	_resize_stage()
	_render()


func _resize_stage() -> void:
	_stage.custom_minimum_size.x = clampf(size.x * .18, 205, 340)


func payload() -> Dictionary:
	var result := selection.duplicate(true)
	result.difficulty_id = difficulty
	result.deck_selected = true
	return result


func _update_hero() -> void:
	var entry := entries[hero]
	_hero_name.text = str(entry.display_name)
	_preview.configure(entry.unit)
	for clip in [&"idle_S", &"idle_E"]:
		if _preview.has_clip(clip):
			_preview.play_clip(clip)
			break
	hero_selected.emit(hero)


func _accent() -> Color:
	return Catalog.Ecology.CLASS_COLORS[selection.class_id]


func _render() -> void:
	for parent in [_nav, _page]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("121820f2")
	style.border_color = _accent().darkened(.25)
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_corner_radius_all(9)
	for side in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 16.)
	_panel.add_theme_stylebox_override("panel", style)
	_class_label.text = Catalog.CLASSES[selection.class_id][0]
	_class_label.modulate = _accent()
	CardSkin.icon_button(start_button, _accent())
	for index in STEPS.size():
		var button := Button.new()
		button.name = "SetupStep_%d" % index
		button.text = ("✓  " if index < reached else "%02d  " % (index + 1)) + STEPS[index]
		button.custom_minimum_size.y = 43
		button.toggle_mode = true
		button.button_pressed = step == index
		button.disabled = index > reached or (index > 2 and not Catalog.valid_departure(selection))
		CardSkin.icon_button(button, _accent())
		button.pressed.connect(
			func():
				step = index
				_render(),
		)
		_nav.add_child(button)
	PAGE.text(_nav, "VOTRE DECK", 13).modulate = _accent()
	PAGE.text(_nav, "%d / 10 cartes" % (selection.card_families.size() * 2), 19)
	PAGE.text(_nav, "4 en main\n2 gestes de secours\nÉquipement en butin", 14)
	start_button.text = (
		"Commencer avec %s →" % entries[hero].display_name
		if step == 4
		else "Confirmer · " + STEPS[step + 1] + " →"
	)
	start_button.disabled = step >= 2 and not Catalog.valid_departure(selection)
	status.text = "Étape %d / 5 · %s · %d techniques choisies, 2 copies chacune." % [
		step + 1,
		Catalog.CLASSES[selection.class_id][0],
		selection.card_families.size(),
	]
	if step == 1:
		_render_classes()
	elif step == 2:
		_render_cards()
	elif step == 4:
		_render_review()
	else:
		_render_choice()


func _render_classes() -> void:
	PAGE.text(_page, "Choisir une voie", 27)
	PAGE.text(
		_page,
		"Quatre styles de combat. Chaque classe possède sept cartes d'initiation distinctes.",
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
	PAGE.text(body, Catalog.CLASSES[selection.class_id][1], 21)
	PAGE.text(body, Catalog.CLASSES[selection.class_id][2], 18)
	PAGE.text(body, "VOTRE PREMIÈRE COMBINAISON", 13).modulate = _accent()
	PAGE.text(body, Starters.LOOPS[selection.class_id], 17)
	PAGE.text(body, "ÉVOLUTIONS AU NIVEAU 4", 13).modulate = _accent()
	for spec in Catalog.SPECS[selection.class_id]:
		PAGE.text(body, spec[1] + "  ·  " + spec[2], 15)
	PAGE.text(
		body,
		"L'initiation ne gagne pas de puissance avec la maîtrise. Les cartes trouvées pendant la run ouvriront de nouvelles possibilités.",
		14,
	)


func _scroll_body(parent: Control, node_name := "Details") -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	return body


func _render_cards() -> void:
	PAGE.text(_page, "Composer votre deck", 27)
	PAGE.text(
		_page,
		"Choisissez 5 techniques parmi 7. Consultez une carte, puis ajoutez ou retirez ses 2 copies.",
		15,
	)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(columns)
	var list := _scroll_body(columns, "StarterCatalogue")
	var pool := Catalog.starter_pool(selection.class_id)
	if _inspected not in pool:
		_inspected = pool[0]
	for id in pool:
		var spell := Catalog.make_spell(id, 2)
		var button := Button.new()
		button.name = "Starter_" + id
		button.text = ("✓  " if id in selection.card_families else "+  ") + spell.spell_name + "\n%d PA  ·  %s  ·  %s" % [
			spell.ap_cost,
			_range(spell),
			Catalog.row(id)[9],
		]
		button.icon = spell.icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 42)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(225, 72)
		button.toggle_mode = true
		button.button_pressed = _inspected == id
		button.tooltip_text = "2 copies dans le deck" if id in selection.card_families else "Disponible pour votre deck"
		CardSkin.icon_button(button, _accent())
		button.pressed.connect(
			func():
				_inspected = id
				_render(),
		)
		list.add_child(button)
	var inspection := VBoxContainer.new()
	inspection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspection.add_theme_constant_override("separation", 10)
	columns.add_child(inspection)
	var detail := _scroll_body(inspection, "ChoiceImpact")
	var selected_spell := Catalog.make_spell(_inspected, 2)
	var art := TextureRect.new()
	art.texture = selected_spell.icon
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(100, 100)
	detail.add_child(art)
	PAGE.text(detail, Catalog.CLASSES[selection.class_id][0] + "  /  INITIATION", 13).modulate = _accent()
	PAGE.text(detail, selected_spell.spell_name, 23)
	PAGE.text(detail, "%d PA  ·  %s" % [selected_spell.ap_cost, _range(selected_spell)], 18)
	var actor := Unit.from_data(entries[hero].unit)
	PAGE.text(
		detail,
		preload("res://ui/expedition/class_card_presentation.gd").numbers(selected_spell, actor),
		18,
	)
	PAGE.text(detail, selected_spell.description.split("\n", true, 1)[1], 16)
	var toggle := Button.new()
	toggle.name = "ToggleStarter"
	var included: bool = _inspected in selection.card_families
	toggle.text = "Retirer ces 2 copies" if included else "Ajouter ces 2 copies"
	toggle.custom_minimum_size.y = 46
	toggle.disabled = not included and selection.card_families.size() >= 5
	CardSkin.icon_button(toggle, _accent())
	toggle.pressed.connect(
		func():
			if _inspected in selection.card_families:
				selection.card_families.erase(_inspected)
			elif selection.card_families.size() < 5:
				selection.card_families.append(_inspected)
			_render(),
	)
	inspection.add_child(toggle)
	if not included and selection.card_families.size() >= 5:
		PAGE.text(
			inspection,
			"Deck complet : retirez une technique avant d'en ajouter une autre.",
			14,
		)
	PAGE.text(
		detail,
		"Valeurs au départ, avant les protections de la cible et les bonus conditionnels.",
		13,
	)
	PAGE.text(_page, "DANS VOTRE DECK  ·  " + _deck_titles(), 14).modulate = _accent()


func _range(spell: Spell) -> String:
	return (
		"sur soi"
		if spell.spell_range == 0
		else "portée %d–%d" % [spell.minimum_range, spell.spell_range]
	)


func _deck_titles() -> String:
	var titles: PackedStringArray = []
	for id in selection.card_families:
		titles.append(Catalog.row(id)[2])
	return "  /  ".join(titles)


func _render_review() -> void:
	PAGE.text(_page, "Prêt pour la descente", 27)
	var body := _scroll_body(_page, "ChoiceImpact")
	PAGE.text(body, "%s · %s" % [entries[hero].display_name, Catalog.CLASSES[selection.class_id][0]], 23).modulate = _accent()
	PAGE.text(
		body,
		"Difficulté %s · 10 cartes · 4 en main"
		% ("normale" if difficulty == "normal" else "facile"),
		17,
	)
	for id in selection.card_families:
		var spell := Catalog.make_spell(id, 2)
		PAGE.text(
			body,
			"2 × %s  ·  %d PA  ·  %s" % [spell.spell_name, spell.ap_cost, Catalog.row(id)[9]],
			17,
		)
	PAGE.text(
		body,
		"Votre deck est prêt. Il sera utilisé dès le premier combat, sans nouvelle sélection au seuil.",
		18,
	)
	PAGE.text(
		body,
		"Pendant la run, les cartes tombent avec les objets et rejoignent votre réserve. Adaptez votre deck entre les combats.",
		15,
	)


func _render_choice() -> void:
	var options: Array = []
	var current := str(hero) if step == 0 else difficulty
	if step == 0:
		for index in entries.size():
			options.append(
				{
					"id": str(index),
					"title": entries[index].display_name,
					"impact": entries[index].appearance,
					"details": "Cette apparence vous suit en combat, quelle que soit votre classe.",
				}
			)
	else:
		options = [
			{ "id": "normal", "title": "Normale", "impact": "Ennemis à leur puissance habituelle." },
			{
				"id": "easy",
				"title": "Facile",
				"impact": "Ennemis : −10 % PV et −20 % dégâts. Soin au refuge : 40 % au lieu de 30 %.",
			},
		]
	var page := PAGE.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(page)
	page.configure(
		STEPS[step],
		"Choisissez votre apparence." if step == 0 else "Choisissez la résistance de votre traversée.",
		options,
		current,
	)
	page.chosen.connect(
		func(id):
			if step == 0:
				hero = int(id)
				_update_hero()
			else:
				difficulty = id
			_render(),
	)
