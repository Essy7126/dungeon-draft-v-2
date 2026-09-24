extends MarginContainer
## Compose the class-owned deck before the cinematic and threshold.
signal hero_selected(index: int)
signal launch_requested
signal back_requested
signal refuge_requested
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
var _nav: HBoxContainer
var _page: VBoxContainer
var _preview: CharacterPreview3D
var _hero_name: Label
var _class_label: Label
var _panel: PanelContainer
var _stage: VBoxContainer
var _inspected := ""
var _drafts: Dictionary = { }
var _summary: Label
var _crest: TextureRect
var _deck_strip: HBoxContainer
var _facing := 2
var _pose := "idle"
var _pose_buttons: Array[Button] = []
const GOLD := Color("d7bd87")
const HEADING := preload("res://asset/ui/character_selection/selection_title_font.tres")


func configure(value: Array[Dictionary]) -> void:
	entries = value
	hero = mini(2, entries.size() - 1)
	theme = preload("res://ui/expedition/catabase_ui_theme.gd").get_theme()
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 24)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var brand := PAGE.text(header, "CATABASE", 30)
	brand.add_theme_font_override("font", HEADING)
	brand.modulate = GOLD
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mode_label := PAGE.text(header, "NOUVELLE DESCENTE  /  CARTES", 14)
	mode_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	mode_label.modulate = GOLD
	var refuge := _action(header, "Sanctuaire", "SetupRefuge")
	refuge.pressed.connect(func(): refuge_requested.emit())
	_nav = HBoxContainer.new()
	_nav.add_theme_constant_override("separation", 8)
	root.add_child(_nav)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)
	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_panel)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 12)
	_panel.add_child(_page)
	var stage := VBoxContainer.new()
	_stage = stage
	stage.add_theme_constant_override("separation", 8)
	columns.add_child(stage)
	var identity := PanelContainer.new()
	identity.add_theme_stylebox_override("panel", CardSkin.surface(GOLD, false, 12))
	stage.add_child(identity)
	var title_row := HBoxContainer.new()
	identity.add_child(title_row)
	_crest = _art(title_row, null, 58)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(names)
	_hero_name = PAGE.text(names, "", 26)
	_hero_name.add_theme_font_override("font", HEADING)
	_class_label = PAGE.text(names, "", 16)
	_preview = PREVIEW.instantiate()
	_preview.custom_minimum_size = Vector2.ZERO
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(_preview)
	_preview.set_showcase_mode(true)
	var poses := HBoxContainer.new()
	poses.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_child(poses)
	_action(poses, "‹", "SetupRotateLeft").pressed.connect(_rotate.bind(-1))
	for index in 3:
		var pose_button := _action(poses, ["Repos", "Marche", "Attaque"][index], "SetupPose_%d" % index)
		pose_button.add_theme_font_size_override("font_size", 14)
		pose_button.toggle_mode = true
		pose_button.pressed.connect(func():
			_pose = ["idle", "walk", "attack"][index]
			_play_pose()
		)
		_pose_buttons.append(pose_button)
	_action(poses, "›", "SetupRotateRight").pressed.connect(_rotate.bind(1))
	var summary_panel := PanelContainer.new()
	summary_panel.add_theme_stylebox_override("panel", CardSkin.surface(GOLD, false, 12))
	stage.add_child(summary_panel)
	var summary_body := VBoxContainer.new()
	summary_body.add_theme_constant_override("separation", 8)
	summary_panel.add_child(summary_body)
	PAGE.text(summary_body, "VOTRE DÉPART", 13).modulate = GOLD
	_summary = PAGE.text(summary_body, "", 15)
	_deck_strip = HBoxContainer.new()
	_deck_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_body.add_child(_deck_strip)
	status = PAGE.text(root, "", 15)
	status.name = "CardsSetupStatus"
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)
	var back := Button.new()
	back.name = "SetupBack"
	back.text = "← Retour"
	back.custom_minimum_size = Vector2(154, 46)
	back.pressed.connect(go_back)
	footer.add_child(back)
	CardSkin.icon_button(back, GOLD)
	start_button = Button.new()
	start_button.name = "StartAdventure"
	start_button.custom_minimum_size.y = 56
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
	_stage.custom_minimum_size.x = clampf(size.x * .34, 340, 560)


func payload() -> Dictionary:
	var result := selection.duplicate(true)
	result.difficulty_id = difficulty
	result.deck_selected = true
	return result


func _update_hero() -> void:
	var entry := entries[hero]
	_hero_name.text = str(entry.display_name)
	_preview.configure(entry.unit)
	_play_pose()
	hero_selected.emit(hero)


func _accent() -> Color:
	return Catalog.Ecology.CLASS_COLORS[selection.class_id]


func _render() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focus_name := str(focused.name) if focused != null and is_ancestor_of(focused) else ""
	for parent in [_nav, _page]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101e1bf2")
	style.border_color = GOLD.darkened(.3)
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_corner_radius_all(9)
	for side in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 16.)
	_panel.add_theme_stylebox_override("panel", style)
	_class_label.text = Catalog.CLASSES[selection.class_id][0] + "  ·  Niveau 1"
	_class_label.modulate = _accent()
	_crest.texture = Catalog.icon(selection.class_id)
	_summary.text = "%s · %d / 10 cartes\n4 en main · équipement à trouver" % ["Difficulté normale" if difficulty == "normal" else "Difficulté facile", selection.card_families.size() * 2]
	for child in _deck_strip.get_children():
		_deck_strip.remove_child(child)
		child.queue_free()
	for id in selection.card_families:
		var card := _art(_deck_strip, Catalog.make_spell(id, 2).icon, 42)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var spell := Catalog.make_spell(id, 2)
		card.tooltip_text = "2 × %s · %d PA · %s\n%s" % [spell.spell_name, spell.ap_cost, _range(spell), spell.description]
	CardSkin.icon_button(start_button, GOLD)
	var launch_style := CardSkin.surface(GOLD, true, 10)
	launch_style.bg_color = Color("315a45")
	start_button.add_theme_stylebox_override("normal", launch_style)
	start_button.add_theme_font_size_override("font_size", 22)
	for index in STEPS.size():
		var button := Button.new()
		button.name = "SetupStep_%d" % index
		button.text = ("✓  " if index < reached else "%02d  " % (index + 1)) + STEPS[index]
		button.custom_minimum_size.y = 43
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	start_button.text = (
		"ENTRER DANS LES ENFERS  →"
		if step == 4
		else "Confirmer · " + STEPS[step + 1] + " →"
	)
	start_button.disabled = step >= 2 and not Catalog.valid_departure(selection)
	status.text = "Choisissez 5 techniques pour continuer (%d / 5)." % selection.card_families.size() if start_button.disabled else "Étape %d / 5  ·  %s  ·  Vos choix restent modifiables avant le départ." % [step + 1, STEPS[step]]
	if step == 1:
		_render_classes()
	elif step == 2:
		_render_cards()
	elif step == 4:
		_render_review()
	else:
		_render_choice()
	_restore_focus.call_deferred(focus_name)


func go_back() -> void:
	if step == 0:
		back_requested.emit()
	else:
		step -= 1
		_render()


func _restore_focus(node_name: String) -> void:
	if node_name.is_empty():
		return
	var control := find_child(node_name, true, false) as Control
	if control != null and not (control is BaseButton and control.disabled):
		control.grab_focus()
	else:
		get_node_or_null(".").find_child("SetupBack", true, false).grab_focus()


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
	PAGE.text(body, "BONUS DE CLASSE", 13).modulate = GOLD
	PAGE.text(body, Catalog.CLASSES[selection.class_id][2], 18)
	PAGE.text(body, "À PRENDRE EN COMPTE", 13).modulate = GOLD
	PAGE.text(body, Catalog.CLASSES[selection.class_id][3], 16)
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
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		body.add_child(row)
		_art(row, spell.icon, 48)
		var card_label := PAGE.text(
			row,
			"2 × %s  ·  %d PA  ·  %s" % [spell.spell_name, spell.ap_cost, Catalog.row(id)[9]],
			17,
		)
		card_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	if step == 0:
		_render_appearances()
		return
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


func _render_appearances() -> void:
	PAGE.text(_page, "Qui franchira le seuil ?", 29).add_theme_font_override("font", HEADING)
	PAGE.text(_page, "Trois apparences pour votre héros. Choisissez ensuite sa classe et ses cartes.", 17)
	var body := _scroll_body(_page, "ChoiceImpact")
	var roster := HBoxContainer.new()
	roster.add_theme_constant_override("separation", 12)
	body.add_child(roster)
	for index in entries.size():
		var button := Button.new()
		button.name = "Choice_%d" % index
		button.custom_minimum_size.y = 212
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_pressed = index == hero
		button.tooltip_text = str(entries[index].appearance)
		CardSkin.icon_button(button, GOLD)
		roster.add_child(button)
		var contents := VBoxContainer.new()
		button.add_child(contents)
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_left = 10
		contents.offset_right = -10
		contents.offset_top = 10
		contents.offset_bottom = -10
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var unit: UnitData = entries[index].unit
		var portrait: Texture2D = unit.portrait_texture_override
		if portrait == null and unit.preview_sprite_frames != null:
			var frames := unit.preview_sprite_frames
			if frames.has_animation(unit.preview_sprite_animation):
				portrait = frames.get_frame_texture(unit.preview_sprite_animation, 0)
		if portrait == null:
			portrait = load("res://asset/ui/character_selection/portraits/achilles_illustrated_v2.png")
		var art := _art(contents, portrait, 120)
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var title := PAGE.text(contents, str(entries[index].display_name), 17)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tag := PAGE.text(contents, "SÉLECTIONNÉ" if hero == index else "APPARENCE", 12)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.modulate = GOLD if hero == index else Color("a3b7ac")
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.pressed.connect(func():
			hero = index
			_update_hero()
			_render()
		)
	PAGE.text(body, entries[hero].display_name, 25).modulate = GOLD
	PAGE.text(body, entries[hero].description, 17)
	PAGE.text(body, "LIBRE DE CHOISIR VOTRE CLASSE", 13).modulate = GOLD
	PAGE.text(body, "Assassin, Gardien, Arpenteur ou Thaumaturge : chaque apparence peut suivre chacune de ces voies. Ce choix visuel ne modifie pas vos statistiques.", 16)


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


func _rotate(direction: int) -> void:
	_facing = posmod(_facing + direction, 4)
	_play_pose()


func _clip(pose: String) -> StringName:
	if _preview.is_using_sprite_preview():
		return StringName(pose + "_" + ["N", "E", "S", "W"][_facing])
	var unit: UnitData = entries[hero].unit
	if unit.animation_set != null:
		var action := CharacterVisual3D.ACTION_IDLE
		if pose == "walk": action = CharacterVisual3D.ACTION_WALK
		elif pose == "attack": action = CharacterVisual3D.ACTION_CAST
		return unit.animation_set.get_animation_name(action)
	return &""


func _play_pose() -> void:
	if not _preview.is_using_sprite_preview():
		var visual := _preview.get_visual_instance()
		if visual != null: visual.rotation_degrees.y = (_facing - 1) * 90.0
	if not _preview.has_clip(_clip(_pose)):
		_pose = "idle"
	if _preview.has_clip(_clip(_pose)):
		_preview.play_clip(_clip(_pose))
	for index in _pose_buttons.size():
		var pose: String = ["idle", "walk", "attack"][index]
		_pose_buttons[index].disabled = not _preview.has_clip(_clip(pose))
		_pose_buttons[index].set_pressed_no_signal(_pose == pose)
